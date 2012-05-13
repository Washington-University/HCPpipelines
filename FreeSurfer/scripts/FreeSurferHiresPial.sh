#!/bin/bash
set -e
echo -e "\n START: FreeSurferHighResPial"

SubjectID="$1"
SubjectDIR="$2"
T1wImage="$3" #T1w FreeSurfer Input (Full Resolution)
T2wImage="$4" #T2w FreeSurfer Input (Full Resolution)
PipelineBinaries="$5"
Caret5_Command="$6"
Caret7_Command="$7"

Sigma="5" #in mm

export SUBJECTS_DIR="$SubjectDIR"

mridir=$SubjectDIR/$SubjectID/mri
surfdir=$SubjectDIR/$SubjectID/surf

reg=$mridir/transforms/hires21mm.dat
regII=$mridir/transforms/1mm2hires.dat
hires="$mridir"/T1w_hires.nii.gz
T2="$mridir"/T2w_hires.nii.gz
Ratio="$mridir"/T1wDividedByT2w_sqrt.nii.gz

mri_convert "$mridir"/wm.hires.mgz "$mridir"/wm.hires.nii.gz
fslmaths "$mridir"/wm.hires.nii.gz -thr 110 -uthr 110 "$mridir"/wm.hires.nii.gz
wmMean=`fslstats "$mridir"/T1w_hires.nii.gz -k "$mridir"/wm.hires.nii.gz -M`
fslmaths "$mridir"/T1w_hires.nii.gz -div $wmMean -mul 110 "$mridir"/T1w_hires.norm.nii.gz
mri_convert "$mridir"/T1w_hires.norm.nii.gz "$mridir"/T1w_hires.norm.mgz

#"$PipelineBinaries"/mris_make_surfaces -white NOWRITE -aseg aseg.hires -orig white.deformed -filled filled.hires -wm wm.hires -sdir $SubjectDIR -mgz -T1 T1w_hires.masked.norm "$SubjectID" lh
#"$PipelineBinaries"/mris_make_surfaces -white NOWRITE -aseg aseg.hires -orig white.deformed -filled filled.hires -wm wm.hires -sdir $SubjectDIR -mgz -T1 T1w_hires.masked.norm "$SubjectID" rh

"$PipelineBinaries"/mris_make_surfaces -white NOWRITE -aseg aseg.hires -orig white.deformed -filled filled.hires -wm wm.hires -sdir $SubjectDIR -mgz -T1 T1w_hires.norm "$SubjectID" lh
"$PipelineBinaries"/mris_make_surfaces -white NOWRITE -aseg aseg.hires -orig white.deformed -filled filled.hires -wm wm.hires -sdir $SubjectDIR -mgz -T1 T1w_hires.norm "$SubjectID" rh


cp $SubjectDIR/$SubjectID/surf/lh.pial $SubjectDIR/$SubjectID/surf/lh.pial.preT2
cp $SubjectDIR/$SubjectID/surf/rh.pial $SubjectDIR/$SubjectID/surf/rh.pial.preT2


#For mris_make_surfaces with reversed arguments
#"$PipelineBinaries"/mris_make_surfaces_T2 -nsigma_above 3 -nsigma_below 1.25 -aseg aseg.hires -filled filled.hires -wm wm.hires -mgz -sdir $SubjectDIR -orig white.deformed -nowhite -orig_white white.deformed -orig_pial pial -T2dura $T2 -T1 T1w_hires.norm -output .T2 $SubjectID lh
#"$PipelineBinaries"/mris_make_surfaces_T2 -nsigma_above 3 -nsigma_below 1.25 -aseg aseg.hires -filled filled.hires -wm wm.hires -mgz -sdir $SubjectDIR -orig white.deformed -nowhite -orig_white white.deformed -orig_pial pial -T2dura $T2 -T1 T1w_hires.norm -output .T2 $SubjectID rh

#For mris_make_surface with correct arguments
"$PipelineBinaries"/mris_make_surfaces_T2 -nsigma_above 2 -nsigma_below 4 -aseg aseg.hires -filled filled.hires -wm wm.hires -mgz -sdir $SubjectDIR -orig white.deformed -nowhite -orig_white white.deformed -orig_pial pial -T2dura $T2 -T1 T1w_hires.norm -output .T2 $SubjectID lh
"$PipelineBinaries"/mris_make_surfaces_T2 -nsigma_above 2 -nsigma_below 4 -aseg aseg.hires -filled filled.hires -wm wm.hires -mgz -sdir $SubjectDIR -orig white.deformed -nowhite -orig_white white.deformed -orig_pial pial -T2dura $T2 -T1 T1w_hires.norm -output .T2 $SubjectID rh

#cp $SubjectDIR/$SubjectID/surf/lh.pial.T2 $SubjectDIR/$SubjectID/surf/lh.pial.preRatio
#cp $SubjectDIR/$SubjectID/surf/rh.pial.T2 $SubjectDIR/$SubjectID/surf/rh.pial.preRatio

#fslmaths "$mridir"/T1w_hires.nii.gz -div "$mridir"/T2w_hires.nii.gz -sqrt "$mridir"/T1wDividedByT2w_sqrt.nii.gz

#"$PipelineBinaries"/mris_make_surfaces_T2 -nsigma_above 4 -nsigma_below 0.75 -aseg aseg.hires -filled filled.hires -wm wm.hires -mgz -sdir $SubjectDIR -orig white.deformed -nowhite -orig_white white.deformed -orig_pial pial.T2 -T2dura $Ratio -T1 T1w_hires.norm -output .Ratio $SubjectID lh
#"$PipelineBinaries"/mris_make_surfaces_T2 -nsigma_above 4 -nsigma_below 0.75 -aseg aseg.hires -filled filled.hires -wm wm.hires -mgz -sdir $SubjectDIR -orig white.deformed -nowhite -orig_white white.deformed -orig_pial pial.T2 -T2dura $Ratio -T1 T1w_hires.norm -output .Ratio $SubjectID rh

mri_surf2surf --s $SubjectID --sval-xyz pial.T2 --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi lh
mri_surf2surf --s $SubjectID --sval-xyz pial.T2 --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi rh

#mri_surf2surf --s $SubjectID --sval-xyz pial.Ratio --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi lh
#mri_surf2surf --s $SubjectID --sval-xyz pial.Ratio --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi rh

MatrixX=`mri_info $mridir/brain.finalsurfs.mgz | grep "c_r" | cut -d "=" -f 5 | sed s/" "/""/g`
MatrixY=`mri_info $mridir/brain.finalsurfs.mgz | grep "c_a" | cut -d "=" -f 5 | sed s/" "/""/g`
MatrixZ=`mri_info $mridir/brain.finalsurfs.mgz | grep "c_s" | cut -d "=" -f 5 | sed s/" "/""/g`
Matrix1=`echo "1 0 0 ""$MatrixX"`
Matrix2=`echo "0 1 0 ""$MatrixY"`
Matrix3=`echo "0 0 1 ""$MatrixZ"`
Matrix4=`echo "0 0 0 1"`
Matrix=`echo "$Matrix1"" ""$Matrix2"" ""$Matrix3"" ""$Matrix4"`

$Caret5_Command -file-convert -sc -is FSS "$surfdir"/lh.white -os CARET "$surfdir"/lh.white.coord.gii "$surfdir"/lh.white.topo.gii FIDUCIAL CLOSED
$Caret5_Command -surface-apply-transformation-matrix "$surfdir"/lh.white.coord.gii "$surfdir"/lh.white.topo.gii "$surfdir"/lh.white.coord.gii -matrix $Matrix
$Caret5_Command -file-convert -sc -is CARET "$surfdir"/lh.white.coord.gii "$surfdir"/lh.white.topo.gii -os GS "$surfdir"/lh.white.surf.gii
$Caret7_Command -set-structure "$surfdir"/lh.white.surf.gii CORTEX_LEFT 
rm "$surfdir"/lh.white.coord.gii "$surfdir"/lh.white.topo.gii

$Caret5_Command -file-convert -sc -is FSS "$surfdir"/rh.white -os CARET "$surfdir"/rh.white.coord.gii "$surfdir"/rh.white.topo.gii FIDUCIAL CLOSED
$Caret5_Command -surface-apply-transformation-matrix "$surfdir"/rh.white.coord.gii "$surfdir"/rh.white.topo.gii "$surfdir"/rh.white.coord.gii -matrix $Matrix
$Caret5_Command -file-convert -sc -is CARET "$surfdir"/rh.white.coord.gii "$surfdir"/rh.white.topo.gii -os GS "$surfdir"/rh.white.surf.gii
$Caret7_Command -set-structure "$surfdir"/rh.white.surf.gii CORTEX_RIGHT 
rm "$surfdir"/rh.white.coord.gii "$surfdir"/rh.white.topo.gii

$Caret5_Command -file-convert -sc -is FSS "$surfdir"/lh.pial -os CARET "$surfdir"/lh.pial.coord.gii "$surfdir"/lh.pial.topo.gii FIDUCIAL CLOSED
$Caret5_Command -surface-apply-transformation-matrix "$surfdir"/lh.pial.coord.gii "$surfdir"/lh.pial.topo.gii "$surfdir"/lh.pial.coord.gii -matrix $Matrix
$Caret5_Command -file-convert -sc -is CARET "$surfdir"/lh.pial.coord.gii "$surfdir"/lh.pial.topo.gii -os GS "$surfdir"/lh.pial.surf.gii
$Caret7_Command -set-structure "$surfdir"/lh.pial.surf.gii CORTEX_LEFT 
rm "$surfdir"/lh.pial.coord.gii "$surfdir"/lh.pial.topo.gii

$Caret5_Command -file-convert -sc -is FSS "$surfdir"/rh.pial -os CARET "$surfdir"/rh.pial.coord.gii "$surfdir"/rh.pial.topo.gii FIDUCIAL CLOSED
$Caret5_Command -surface-apply-transformation-matrix "$surfdir"/rh.pial.coord.gii "$surfdir"/rh.pial.topo.gii "$surfdir"/rh.pial.coord.gii -matrix $Matrix
$Caret5_Command -file-convert -sc -is CARET "$surfdir"/rh.pial.coord.gii "$surfdir"/rh.pial.topo.gii -os GS "$surfdir"/rh.pial.surf.gii
$Caret7_Command -set-structure "$surfdir"/rh.pial.surf.gii CORTEX_RIGHT 
rm "$surfdir"/rh.pial.coord.gii "$surfdir"/rh.pial.topo.gii

$Caret7_Command -create-signed-distance-volume "$surfdir"/lh.white.surf.gii "$mridir"/T1w_hires.nii.gz "$surfdir"/lh.white.nii.gz
$Caret7_Command -create-signed-distance-volume "$surfdir"/rh.white.surf.gii "$mridir"/T1w_hires.nii.gz "$surfdir"/rh.white.nii.gz
$Caret7_Command -create-signed-distance-volume "$surfdir"/lh.pial.surf.gii "$mridir"/T1w_hires.nii.gz "$surfdir"/lh.pial.nii.gz
$Caret7_Command -create-signed-distance-volume "$surfdir"/rh.pial.surf.gii "$mridir"/T1w_hires.nii.gz "$surfdir"/rh.pial.nii.gz

fslmaths "$surfdir"/lh.white.nii.gz -mul "$surfdir"/lh.pial.nii.gz -uthr 0 -mul -1 -bin "$mridir"/lh.ribbon.nii.gz
fslmaths "$surfdir"/rh.white.nii.gz -mul "$surfdir"/rh.pial.nii.gz -uthr 0 -mul -1 -bin "$mridir"/rh.ribbon.nii.gz
fslmaths "$mridir"/lh.ribbon.nii.gz -add "$mridir"/rh.ribbon.nii.gz -bin "$mridir"/ribbon.nii.gz

fslmaths "$mridir"/ribbon.nii.gz -s $Sigma "$mridir"/ribbon_s"$Sigma".nii.gz
fslmaths "$mridir"/T1w_hires.norm.nii.gz -mas "$mridir"/ribbon.nii.gz "$mridir"/T1w_hires.norm_ribbon.nii.gz
greymean=`fslstats "$mridir"/T1w_hires.norm_ribbon.nii.gz -M`
fslmaths "$mridir"/ribbon.nii.gz -sub 1 -mul -1 "$mridir"/ribbon_inv.nii.gz
fslmaths "$mridir"/T1w_hires.norm_ribbon.nii.gz -s $Sigma -div "$mridir"/ribbon_s"$Sigma".nii.gz -div $greymean -mas "$mridir"/ribbon.nii.gz -add "$mridir"/ribbon_inv.nii.gz "$mridir"/T1w_hires.norm_ribbon_myelin.nii.gz

fslmaths "$mridir"/T1w_hires.norm.nii.gz -div "$mridir"/T1w_hires.norm_ribbon_myelin.nii.gz "$mridir"/T1w_hires.greynorm.nii.gz
mri_convert "$mridir"/T1w_hires.greynorm.nii.gz "$mridir"/T1w_hires.greynorm.mgz

cp $SubjectDIR/$SubjectID/surf/lh.pial $SubjectDIR/$SubjectID/surf/lh.pial.one
cp $SubjectDIR/$SubjectID/surf/rh.pial $SubjectDIR/$SubjectID/surf/rh.pial.one

"$PipelineBinaries"/mris_make_surfacesII -white NOWRITE -aseg aseg.hires -orig white.deformed -filled filled.hires -wm wm.hires -sdir $SubjectDIR -mgz -T1 T1w_hires.greynorm "$SubjectID" lh
"$PipelineBinaries"/mris_make_surfacesII -white NOWRITE -aseg aseg.hires -orig white.deformed -filled filled.hires -wm wm.hires -sdir $SubjectDIR -mgz -T1 T1w_hires.greynorm "$SubjectID" rh

cp $SubjectDIR/$SubjectID/surf/lh.pial $SubjectDIR/$SubjectID/surf/lh.pial.preT2.two
cp $SubjectDIR/$SubjectID/surf/rh.pial $SubjectDIR/$SubjectID/surf/rh.pial.preT2.two

"$PipelineBinaries"/mris_make_surfaces_T2 -nsigma_above 2 -nsigma_below 4 -aseg aseg.hires -filled filled.hires -wm wm.hires -mgz -sdir $SubjectDIR -orig white.deformed -nowhite -orig_white white.deformed -orig_pial pial -T2dura $T2 -T1 T1w_hires.norm -output .T2.two $SubjectID lh
"$PipelineBinaries"/mris_make_surfaces_T2 -nsigma_above 2 -nsigma_below 4 -aseg aseg.hires -filled filled.hires -wm wm.hires -mgz -sdir $SubjectDIR -orig white.deformed -nowhite -orig_white white.deformed -orig_pial pial -T2dura $T2 -T1 T1w_hires.norm -output .T2.two $SubjectID rh

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
