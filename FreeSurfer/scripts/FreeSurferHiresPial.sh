#!/bin/bash
set -e
echo -e "\n START: FreeSurferHighResPial"

SubjectID="$1"
SubjectDIR="$2"
T1wImage="$3" #T1w FreeSurfer Input (Full Resolution)
T2wImage="$4" #T2w FreeSurfer Input (Full Resolution)

Sigma="5" #in mm

export SUBJECTS_DIR="$SubjectDIR"

mridir=$SubjectDIR/$SubjectID/mri
surfdir=$SubjectDIR/$SubjectID/surf

reg=$mridir/transforms/hires21mm.dat
regII=$mridir/transforms/1mm2hires.dat
hires="$mridir"/T1w_hires.nii.gz
T2="$mridir"/T2w_hires.norm.mgz
Ratio="$mridir"/T1wDividedByT2w_sqrt.nii.gz

mri_convert "$mridir"/wm.hires.mgz "$mridir"/wm.hires.nii.gz
fslmaths "$mridir"/wm.hires.nii.gz -thr 110 -uthr 110 "$mridir"/wm.hires.nii.gz
wmMean=`fslstats "$mridir"/T1w_hires.nii.gz -k "$mridir"/wm.hires.nii.gz -M`
fslmaths "$mridir"/T1w_hires.nii.gz -div $wmMean -mul 110 "$mridir"/T1w_hires.norm.nii.gz
mri_convert "$mridir"/T1w_hires.norm.nii.gz "$mridir"/T1w_hires.norm.mgz

fslmaths "$mridir"/T2w_hires.nii.gz -div `fslstats "$mridir"/T2w_hires.nii.gz -k "$mridir"/wm.hires.nii.gz -M` -mul 57 "$mridir"/T2w_hires.norm.nii.gz -odt float
mri_convert "$mridir"/T2w_hires.norm.nii.gz "$mridir"/T2w_hires.norm.mgz

#Check if FreeSurfer is version 5.2.0 or not.  If it is not, use new -first_wm_peak mris_make_surfaces flag
if [ -z `cat ${FREESURFER_HOME}/build-stamp.txt | grep v5.2.0` ] ; then
  VARIABLESIGMA="8"
else
  VARIABLESIGMA="4"
fi

mris_make_surfaces -variablesigma ${VARIABLESIGMA} -white NOWRITE -aseg aseg.hires -orig white.deformed -filled filled.hires -wm wm.hires -sdir $SubjectDIR -mgz -T1 T1w_hires.norm "$SubjectID" lh
mris_make_surfaces -variablesigma ${VARIABLESIGMA} -white NOWRITE -aseg aseg.hires -orig white.deformed -filled filled.hires -wm wm.hires -sdir $SubjectDIR -mgz -T1 T1w_hires.norm "$SubjectID" rh


cp $SubjectDIR/$SubjectID/surf/lh.pial $SubjectDIR/$SubjectID/surf/lh.pial.preT2
cp $SubjectDIR/$SubjectID/surf/rh.pial $SubjectDIR/$SubjectID/surf/rh.pial.preT2


#For mris_make_surface with correct arguments #Could go from 3 to 2 potentially...
mris_make_surfaces -nsigma_above 2 -nsigma_below 3 -aseg aseg.hires -filled filled.hires -wm wm.hires -mgz -sdir $SubjectDIR -orig white.deformed -nowhite -orig_white white.deformed -orig_pial pial -T2dura "$mridir"/T2w_hires.norm -T1 T1w_hires.norm -output .T2 $SubjectID lh
mris_make_surfaces -nsigma_above 2 -nsigma_below 3 -aseg aseg.hires -filled filled.hires -wm wm.hires -mgz -sdir $SubjectDIR -orig white.deformed -nowhite -orig_white white.deformed -orig_pial pial -T2dura "$mridir"/T2w_hires.norm -T1 T1w_hires.norm -output .T2 $SubjectID rh

mri_surf2surf --s $SubjectID --sval-xyz pial.T2 --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi lh
mri_surf2surf --s $SubjectID --sval-xyz pial.T2 --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi rh

MatrixX=`mri_info $mridir/brain.finalsurfs.mgz | grep "c_r" | cut -d "=" -f 5 | sed s/" "/""/g`
MatrixY=`mri_info $mridir/brain.finalsurfs.mgz | grep "c_a" | cut -d "=" -f 5 | sed s/" "/""/g`
MatrixZ=`mri_info $mridir/brain.finalsurfs.mgz | grep "c_s" | cut -d "=" -f 5 | sed s/" "/""/g`
echo "1 0 0 ""$MatrixX" > $mridir/c_ras.mat
echo "0 1 0 ""$MatrixY" >> $mridir/c_ras.mat
echo "0 0 1 ""$MatrixZ" >> $mridir/c_ras.mat
echo "0 0 0 1" >> $mridir/c_ras.mat

mris_convert "$surfdir"/lh.white "$surfdir"/lh.white.surf.gii
${CARET7DIR}/wb_command -set-structure "$surfdir"/lh.white.surf.gii CORTEX_LEFT 
${CARET7DIR}/wb_command -surface-apply-affine "$surfdir"/lh.white.surf.gii $mridir/c_ras.mat "$surfdir"/lh.white.surf.gii
${CARET7DIR}/wb_command -create-signed-distance-volume "$surfdir"/lh.white.surf.gii "$mridir"/T1w_hires.nii.gz "$surfdir"/lh.white.nii.gz

mris_convert "$surfdir"/lh.pial "$surfdir"/lh.pial.surf.gii
${CARET7DIR}/wb_command -set-structure "$surfdir"/lh.pial.surf.gii CORTEX_LEFT 
${CARET7DIR}/wb_command -surface-apply-affine "$surfdir"/lh.pial.surf.gii $mridir/c_ras.mat "$surfdir"/lh.pial.surf.gii
${CARET7DIR}/wb_command -create-signed-distance-volume "$surfdir"/lh.pial.surf.gii "$mridir"/T1w_hires.nii.gz "$surfdir"/lh.pial.nii.gz

mris_convert "$surfdir"/rh.white "$surfdir"/rh.white.surf.gii
${CARET7DIR}/wb_command -set-structure "$surfdir"/rh.white.surf.gii CORTEX_RIGHT 
${CARET7DIR}/wb_command -surface-apply-affine "$surfdir"/rh.white.surf.gii $mridir/c_ras.mat "$surfdir"/rh.white.surf.gii
${CARET7DIR}/wb_command -create-signed-distance-volume "$surfdir"/rh.white.surf.gii "$mridir"/T1w_hires.nii.gz "$surfdir"/rh.white.nii.gz

mris_convert "$surfdir"/rh.pial "$surfdir"/rh.pial.surf.gii
${CARET7DIR}/wb_command -set-structure "$surfdir"/rh.pial.surf.gii CORTEX_RIGHT 
${CARET7DIR}/wb_command -surface-apply-affine "$surfdir"/rh.pial.surf.gii $mridir/c_ras.mat "$surfdir"/rh.pial.surf.gii
${CARET7DIR}/wb_command -create-signed-distance-volume "$surfdir"/rh.pial.surf.gii "$mridir"/T1w_hires.nii.gz "$surfdir"/rh.pial.nii.gz

fslmaths "$surfdir"/lh.white.nii.gz -mul "$surfdir"/lh.pial.nii.gz -uthr 0 -mul -1 -bin "$mridir"/lh.ribbon.nii.gz
fslmaths "$surfdir"/rh.white.nii.gz -mul "$surfdir"/rh.pial.nii.gz -uthr 0 -mul -1 -bin "$mridir"/rh.ribbon.nii.gz
fslmaths "$mridir"/lh.ribbon.nii.gz -add "$mridir"/rh.ribbon.nii.gz -bin "$mridir"/ribbon.nii.gz
fslcpgeom "$mridir"/T1w_hires.norm.nii.gz "$mridir"/ribbon.nii.gz

fslmaths "$mridir"/ribbon.nii.gz -s $Sigma "$mridir"/ribbon_s"$Sigma".nii.gz
fslmaths "$mridir"/T1w_hires.norm.nii.gz -mas "$mridir"/ribbon.nii.gz "$mridir"/T1w_hires.norm_ribbon.nii.gz
greymean=`fslstats "$mridir"/T1w_hires.norm_ribbon.nii.gz -M`
fslmaths "$mridir"/ribbon.nii.gz -sub 1 -mul -1 "$mridir"/ribbon_inv.nii.gz
fslmaths "$mridir"/T1w_hires.norm_ribbon.nii.gz -s $Sigma -div "$mridir"/ribbon_s"$Sigma".nii.gz -div $greymean -mas "$mridir"/ribbon.nii.gz -add "$mridir"/ribbon_inv.nii.gz "$mridir"/T1w_hires.norm_ribbon_myelin.nii.gz

fslmaths "$surfdir"/lh.white.nii.gz -uthr 0 -mul -1 -bin "$mridir"/lh.white.nii.gz
fslmaths "$surfdir"/rh.white.nii.gz -uthr 0 -mul -1 -bin "$mridir"/rh.white.nii.gz
fslmaths "$mridir"/lh.white.nii.gz -add "$mridir"/rh.white.nii.gz -bin "$mridir"/white.nii.gz
rm "$mridir"/lh.white.nii.gz "$mridir"/rh.white.nii.gz
fslmaths "$mridir"/T1w_hires.norm_ribbon_myelin.nii.gz -mas "$mridir"/ribbon.nii.gz -add "$mridir"/white.nii.gz -uthr 1.9 "$mridir"/T1w_hires.norm_grey_myelin.nii.gz
fslmaths "$mridir"/T1w_hires.norm_grey_myelin.nii.gz -dilM -dilM -dilM -dilM -dilM "$mridir"/T1w_hires.norm_grey_myelin.nii.gz
fslmaths "$mridir"/T1w_hires.norm_grey_myelin.nii.gz -binv "$mridir"/dilribbon_inv.nii.gz
fslmaths "$mridir"/T1w_hires.norm_grey_myelin.nii.gz -add "$mridir"/dilribbon_inv.nii.gz "$mridir"/T1w_hires.norm_grey_myelin.nii.gz

fslmaths "$mridir"/T1w_hires.norm.nii.gz -div "$mridir"/T1w_hires.norm_ribbon_myelin.nii.gz "$mridir"/T1w_hires.greynorm_ribbon.nii.gz
fslmaths "$mridir"/T1w_hires.norm.nii.gz -div "$mridir"/T1w_hires.norm_grey_myelin.nii.gz "$mridir"/T1w_hires.greynorm.nii.gz

mri_convert "$mridir"/T1w_hires.greynorm.nii.gz "$mridir"/T1w_hires.greynorm.mgz

cp $SubjectDIR/$SubjectID/surf/lh.pial $SubjectDIR/$SubjectID/surf/lh.pial.one
cp $SubjectDIR/$SubjectID/surf/rh.pial $SubjectDIR/$SubjectID/surf/rh.pial.one

#Check if FreeSurfer is version 5.2.0 or not.  If it is not, use new -first_wm_peak mris_make_surfaces flag
if [ -z `cat ${FREESURFER_HOME}/build-stamp.txt | grep v5.2.0` ] ; then
  VARIABLESIGMA="4"
else
  VARIABLESIGMA="2"
fi

mris_make_surfaces -variablesigma ${VARIABLESIGMA} -white NOWRITE -aseg aseg.hires -orig white.deformed -filled filled.hires -wm wm.hires -sdir $SubjectDIR -mgz -T1 T1w_hires.greynorm "$SubjectID" lh
mris_make_surfaces -variablesigma ${VARIABLESIGMA} -white NOWRITE -aseg aseg.hires -orig white.deformed -filled filled.hires -wm wm.hires -sdir $SubjectDIR -mgz -T1 T1w_hires.greynorm "$SubjectID" rh

cp $SubjectDIR/$SubjectID/surf/lh.pial $SubjectDIR/$SubjectID/surf/lh.pial.preT2.two
cp $SubjectDIR/$SubjectID/surf/rh.pial $SubjectDIR/$SubjectID/surf/rh.pial.preT2.two

#Could go from 3 to 2 potentially...
mris_make_surfaces -nsigma_above 2 -nsigma_below 3 -aseg aseg.hires -filled filled.hires -wm wm.hires -mgz -sdir $SubjectDIR -orig white.deformed -nowhite -orig_white white.deformed -orig_pial pial -T2dura "$mridir"/T2w_hires.norm -T1 T1w_hires.norm -output .T2.two $SubjectID lh
mris_make_surfaces -nsigma_above 2 -nsigma_below 3 -aseg aseg.hires -filled filled.hires -wm wm.hires -mgz -sdir $SubjectDIR -orig white.deformed -nowhite -orig_white white.deformed -orig_pial pial -T2dura "$mridir"/T2w_hires.norm -T1 T1w_hires.norm -output .T2.two $SubjectID rh

mri_surf2surf --s $SubjectID --sval-xyz pial.T2.two --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi lh
mri_surf2surf --s $SubjectID --sval-xyz pial.T2.two --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi rh

cp $SubjectDIR/$SubjectID/surf/lh.thickness $SubjectDIR/$SubjectID/surf/lh.thickness.preT2
cp $SubjectDIR/$SubjectID/surf/rh.thickness $SubjectDIR/$SubjectID/surf/rh.thickness.preT2

cp $SubjectDIR/$SubjectID/surf/lh.thickness.T2.two $SubjectDIR/$SubjectID/surf/lh.thickness
cp $SubjectDIR/$SubjectID/surf/rh.thickness.T2.two $SubjectDIR/$SubjectID/surf/rh.thickness

cp $SubjectDIR/$SubjectID/surf/lh.area.pial.T2.two $SubjectDIR/$SubjectID/surf/lh.area.pial
cp $SubjectDIR/$SubjectID/surf/rh.area.pial.T2.two $SubjectDIR/$SubjectID/surf/rh.area.pial

cp $SubjectDIR/$SubjectID/surf/lh.curv.pial.T2.two $SubjectDIR/$SubjectID/surf/lh.curv.pial
cp $SubjectDIR/$SubjectID/surf/rh.curv.pial.T2.two $SubjectDIR/$SubjectID/surf/lh.curv.pial

echo -e "\n END: FreeSurferHighResPial"
