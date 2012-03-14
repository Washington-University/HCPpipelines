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

#mri_surf2surf --s $SubjectID --sval-xyz pial --reg $reg "$mridir"/T1w_hires.nii.gz --tval-xyz --tval pial.hires --hemi lh
#mri_surf2surf --s $SubjectID --sval-xyz pial --reg $reg "$mridir"/T1w_hires.nii.gz --tval-xyz --tval pial.hires --hemi rh

#cp $SubjectDIR/$SubjectID/surf/lh.pial $SubjectDIR/$SubjectID/surf/lh.pial.prehires
#cp $SubjectDIR/$SubjectID/surf/rh.pial $SubjectDIR/$SubjectID/surf/rh.pial.prehires

#deform the surfaces
########Consider: Normalize 1/T2w using white surface
########Consider: Use 1/T2w for initial pial surface at full resolution, if it doesn't work, at least generate pial surface with fullres data to reduce partial voluming in sulci
########Consider: Remove T1w adjustment step
########Consider: Then Run T2w adjustment step if needed
########Consider: Finally Run T1w/T2w adjustment step
#max=`fslstats "$mridir"/T2w_hires.nii.gz -R | cut -d " " -f 2`
#fslmaths "$mridir"/T2w_hires.nii.gz -mul -1 -add $max "$mridir"/invT2w_hires.nii.gz

#dim=`fslval $hires pixdim3`
#dim=`echo "scale=2; $var / 1" | bc -l`
#mri_mask "$mridir"/invT2w_hires.nii.gz $mridir/brain.hires.mgz $mridir/invT2w_hires.masked.mgz
#"$PipelineComponents"/mri_normalize -erode 1 -f $SubjectDIR/$SubjectID/scripts/control.hires.dat -min_dist 0$dim -surface "$surfdir"/lh.white identity.nofile -surface "$surfdir"/rh.white identity.nofile $mridir/invT2w_hires.masked.mgz $mridir/invT2w_hires.masked.norm.mgz
#mri_convert $mridir/invT2w_hires.masked.norm.mgz $mridir/invT2w_hires.masked.norm.nii.gz
#fslmaths $mridir/invT2w_hires.masked.norm.nii.gz -uthr 110 $mridir/invT2w_hires.masked.norm.nii.gz
#mri_convert $mridir/invT2w_hires.masked.norm.nii.gz $mridir/invT2w_hires.masked.norm.mgz 

#"$PipelineComponents"/mris_make_surfaces -white NOWRITE -aseg aseg.hires -orig white -filled filled.hires -wm wm.hires -sdir $SubjectDIR -mgz -T1 invT2w_hires.masked.norm "$SubjectID" lh
#"$PipelineComponents"/mris_make_surfaces -white NOWRITE -aseg aseg.hires -orig white -filled filled.hires -wm wm.hires -sdir $SubjectDIR -mgz -T1 invT2w_hires.masked.norm "$SubjectID" rh

"$PipelineBinaries"/mris_make_surfaces -white NOWRITE -aseg aseg.hires -orig white.deformed -filled filled.hires -wm wm.hires -sdir $SubjectDIR -mgz -T1 T1w_hires.masked.norm "$SubjectID" lh
"$PipelineBinaries"/mris_make_surfaces -white NOWRITE -aseg aseg.hires -orig white.deformed -filled filled.hires -wm wm.hires -sdir $SubjectDIR -mgz -T1 T1w_hires.masked.norm "$SubjectID" rh

#mri_surf2surf --s $SubjectID --sval-xyz pial --reg $reg "$mridir"/T1w_hires.nii.gz --tval-xyz --tval pial.hires --hemi lh
#mri_surf2surf --s $SubjectID --sval-xyz pial --reg $reg "$mridir"/T1w_hires.nii.gz --tval-xyz --tval pial.hires --hemi rh

cp $SubjectDIR/$SubjectID/surf/lh.pial $SubjectDIR/$SubjectID/surf/lh.pial.preT2
cp $SubjectDIR/$SubjectID/surf/rh.pial $SubjectDIR/$SubjectID/surf/rh.pial.preT2


#"$PipelineComponents"/mri_normalize -erode 1 -f $SubjectDIR/$SubjectID/scripts/control.hires.dat -min_dist 2 -surface "$surfdir"/lh.white.deformed identity.nofile -surface "$surfdir"/rh.white.deformed identity.nofile $mridir/T1w_hires.masked.mgz $mridir/T1w_hires.masked.norm.pial.mgz

"$PipelineBinaries"/mris_make_surfaces -nsigma_above 3 -nsigma_below 1.25 -sdir $SUBJECTS_DIR -orig white.deformed -nowhite -sdir $SUBJECTS_DIR -orig_white white.deformed -orig_pial pial -T2dura $T2 -T1 T1w_hires.masked.norm -output .T2 $SubjectID lh
"$PipelineBinaries"/mris_make_surfaces -nsigma_above 3 -nsigma_below 1.25 -sdir $SUBJECTS_DIR -orig white.deformed -nowhite -sdir $SUBJECTS_DIR -orig_white white.deformed -orig_pial pial -T2dura $T2 -T1 T1w_hires.masked.norm -output .T2 $SubjectID rh

#"$PipelineComponents"/mris_make_surfaces_bugged -nsigma_above 1.25 -nsigma_below 2 -sdir $SUBJECTS_DIR -orig white.deformed -nowhite -sdir $SUBJECTS_DIR -orig_white white.deformed -orig_pial pial -T2dura $T2 -T1 T1w_hires.masked.norm -output .T2 $SubjectID lh
#"$PipelineComponents"/mris_make_surfaces_bugged -nsigma_above 1.25 -nsigma_below 2 -sdir $SUBJECTS_DIR -orig white.deformed -nowhite -sdir $SUBJECTS_DIR -orig_white white.deformed -orig_pial pial -T2dura $T2 -T1 T1w_hires.masked.norm -output .T2 $SubjectID rh


mri_surf2surf --s $SubjectID --sval-xyz pial.T2 --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi lh
mri_surf2surf --s $SubjectID --sval-xyz pial.T2 --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi rh

cp $SubjectDIR/$SubjectID/surf/lh.thickness $SubjectDIR/$SubjectID/surf/lh.thickness.preT2
cp $SubjectDIR/$SubjectID/surf/rh.thickness $SubjectDIR/$SubjectID/surf/rh.thickness.preT2

cp $SubjectDIR/$SubjectID/surf/lh.thickness.T2 $SubjectDIR/$SubjectID/surf/lh.thickness
cp $SubjectDIR/$SubjectID/surf/rh.thickness.T2 $SubjectDIR/$SubjectID/surf/rh.thickness

cp $SubjectDIR/$SubjectID/surf/lh.area.pial.T2 $SubjectDIR/$SubjectID/surf/lh.area.pial
cp $SubjectDIR/$SubjectID/surf/rh.area.pial.T2 $SubjectDIR/$SubjectID/surf/rh.area.pial

cp $SubjectDIR/$SubjectID/surf/lh.curv.pial.T2 $SubjectDIR/$SubjectID/surf/lh.curv.pial
cp $SubjectDIR/$SubjectID/surf/rh.curv.pial.T2 $SubjectDIR/$SubjectID/surf/lh.curv.pial

echo -e "\n END: FreeSurferHighResPial"
