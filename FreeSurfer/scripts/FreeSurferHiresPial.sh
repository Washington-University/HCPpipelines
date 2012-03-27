#!/bin/bash
set -e
echo -e "\n START: FreeSurferHighResPial"

SubjectID="$1"
SubjectDIR="$2"
T1wImage="$3" #T1w FreeSurfer Input (Full Resolution)
T2wImage="$4" #T2w FreeSurfer Input (Full Resolution)
PipelineBinaries="$5"

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
#"$PipelineBinaries"/mris_make_surfaces -nsigma_above 3 -nsigma_below 1.25 -aseg aseg.hires -filled filled.hires -wm wm.hires -mgz -sdir $SubjectDIR -orig white.deformed -nowhite -orig_white white.deformed -orig_pial pial -T2dura $T2 -T1 T1w_hires.norm -output .T2 $SubjectID lh
#"$PipelineBinaries"/mris_make_surfaces -nsigma_above 3 -nsigma_below 1.25 -aseg aseg.hires -filled filled.hires -wm wm.hires -mgz -sdir $SubjectDIR -orig white.deformed -nowhite -orig_white white.deformed -orig_pial pial -T2dura $T2 -T1 T1w_hires.norm -output .T2 $SubjectID rh

#For mris_make_surface with correct arguments
"$PipelineBinaries"/mris_make_surfaces -nsigma_above 2 -nsigma_below 4 -aseg aseg.hires -filled filled.hires -wm wm.hires -mgz -sdir $SubjectDIR -orig white.deformed -nowhite -orig_white white.deformed -orig_pial pial -T2dura $T2 -T1 T1w_hires.norm -output .T2 $SubjectID lh
"$PipelineBinaries"/mris_make_surfaces -nsigma_above 2 -nsigma_below 4 -aseg aseg.hires -filled filled.hires -wm wm.hires -mgz -sdir $SubjectDIR -orig white.deformed -nowhite -orig_white white.deformed -orig_pial pial -T2dura $T2 -T1 T1w_hires.norm -output .T2 $SubjectID rh

cp $SubjectDIR/$SubjectID/surf/lh.pial.T2 $SubjectDIR/$SubjectID/surf/lh.pial.preRatio
cp $SubjectDIR/$SubjectID/surf/rh.pial.T2 $SubjectDIR/$SubjectID/surf/rh.pial.preRatio

fslmaths "$mridir"/T1w_hires.nii.gz -div "$mridir"/T2w_hires.nii.gz -sqrt "$mridir"/T1wDividedByT2w_sqrt.nii.gz

"$PipelineBinaries"/mris_make_surfaces -nsigma_above 3.5 -nsigma_below 0.75 -aseg aseg.hires -filled filled.hires -wm wm.hires -mgz -sdir $SubjectDIR -orig white.deformed -nowhite -orig_white white.deformed -orig_pial pial.T2 -T2dura $Ratio -T1 T1w_hires.norm -output .Ratio $SubjectID lh
"$PipelineBinaries"/mris_make_surfaces -nsigma_above 3.5 -nsigma_below 0.75 -aseg aseg.hires -filled filled.hires -wm wm.hires -mgz -sdir $SubjectDIR -orig white.deformed -nowhite -orig_white white.deformed -orig_pial pial.T2 -T2dura $Ratio -T1 T1w_hires.norm -output .Ratio $SubjectID rh

#mri_surf2surf --s $SubjectID --sval-xyz pial.T2 --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi lh
#mri_surf2surf --s $SubjectID --sval-xyz pial.T2 --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi rh

mri_surf2surf --s $SubjectID --sval-xyz pial.Ratio --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi lh
mri_surf2surf --s $SubjectID --sval-xyz pial.Ratio --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi rh

cp $SubjectDIR/$SubjectID/surf/lh.thickness $SubjectDIR/$SubjectID/surf/lh.thickness.preT2
cp $SubjectDIR/$SubjectID/surf/rh.thickness $SubjectDIR/$SubjectID/surf/rh.thickness.preT2

cp $SubjectDIR/$SubjectID/surf/lh.thickness.T2 $SubjectDIR/$SubjectID/surf/lh.thickness
cp $SubjectDIR/$SubjectID/surf/rh.thickness.T2 $SubjectDIR/$SubjectID/surf/rh.thickness

cp $SubjectDIR/$SubjectID/surf/lh.area.pial.T2 $SubjectDIR/$SubjectID/surf/lh.area.pial
cp $SubjectDIR/$SubjectID/surf/rh.area.pial.T2 $SubjectDIR/$SubjectID/surf/rh.area.pial

cp $SubjectDIR/$SubjectID/surf/lh.curv.pial.T2 $SubjectDIR/$SubjectID/surf/lh.curv.pial
cp $SubjectDIR/$SubjectID/surf/rh.curv.pial.T2 $SubjectDIR/$SubjectID/surf/lh.curv.pial

echo -e "\n END: FreeSurferHighResPial"
