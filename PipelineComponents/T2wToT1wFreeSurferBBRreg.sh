#!/bin/bash

SubjectID="$1"
SubjectDIR="$2"
T1wImage="$3" #T1w FreeSurfer Input (Full Resolution)
T2wImage="$4" #T2w FreeSurfer Input (Full Resolution)
PipelineComponents="$5"

export SUBJECTS_DIR="$SubjectDIR"

cd "$SubjectDIR"/"$SubjectID"/mri

echo "$SubjectID" > transforms/eye.dat
echo "1" >> transforms/eye.dat
echo "1" >> transforms/eye.dat
echo "1" >> transforms/eye.dat
echo "1 0 0 0" >> transforms/eye.dat
echo "0 1 0 0" >> transforms/eye.dat
echo "0 0 1 0" >> transforms/eye.dat
echo "0 0 0 1" >> transforms/eye.dat
echo "round" >> transforms/eye.dat

bbregister --s "$SubjectID" --mov T2w_hires.nii.gz --surf white.deformed --init-reg transforms/eye.dat --t2 --reg transforms/T2wtoT1w.dat --o T2w2T1w.nii.gz
tkregister2 --noedit --reg transforms/T2wtoT1w.dat --mov T2w_hires.nii.gz --targ T1w_hires.nii.gz --fslregout transforms/T2wtoT1w.mat
applywarp --interp=spline -i T2w_hires.nii.gz -r T1w_hires.nii.gz --premat=transforms/T2wtoT1w.mat -o T2w2T1w.nii.gz
fslmaths T1w_hires.nii.gz -mul T2w2T1w.nii.gz -sqrt T1wMulT2w.nii.gz


mridir=$SubjectDIR/$SubjectID/mri
surfdir=$SubjectDIR/$SubjectID/surf

reg=$mridir/transforms/hires21mm.dat
regII=$mridir/transforms/1mm2hires.dat
cp "$T1wImage" "$mridir"/T1w_hires.nii.gz
hires="$mridir"/T1w_hires.nii.gz

mri_surf2surf --s $SubjectID --sval-xyz pial --reg $reg "$mridir"/T1w_hires.nii.gz --tval-xyz --tval pial.hires --hemi lh
mri_surf2surf --s $SubjectID --sval-xyz pial --reg $reg "$mridir"/T1w_hires.nii.gz --tval-xyz --tval pial.hires --hemi rh

cp $SubjectDIR/$SubjectID/surf/lh.pial $SubjectDIR/$SubjectID/surf/lh.pial.prehires
cp $SubjectDIR/$SubjectID/surf/rh.pial $SubjectDIR/$SubjectID/surf/rh.pial.prehires

#deform the surfaces
"$PipelineComponents"/mris_make_surfaces -white NOWRITE -aseg aseg.hires -orig white.deformed -filled filled.hires -wm wm.hires -sdir $SubjectDIR -T1 T1w_hires.masked.norm -orig_pial pial.hires -output .deformed -w 0 $SubjectID lh
"$PipelineComponents"/mris_make_surfaces -white NOWRITE -aseg aseg.hires -orig white.deformed -filled filled.hires -wm wm.hires -sdir $SubjectDIR -T1 T1w_hires.masked.norm -orig_pial pial.hires -output .deformed -w 0 $SubjectID rh

mri_surf2surf --s $SubjectID --sval-xyz pial.deformed --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi lh
mri_surf2surf --s $SubjectID --sval-xyz pial.deformed --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi rh

cp $SubjectDIR/$SubjectID/surf/lh.thickness $SubjectDIR/$SubjectID/surf/lh.thickness.prehires
cp $SubjectDIR/$SubjectID/surf/rh.thickness $SubjectDIR/$SubjectID/surf/rh.thickness.prehires

mv $SubjectDIR/$SubjectID/surf/lh.thickness.deformed $SubjectDIR/$SubjectID/surf/lh.thickness
mv $SubjectDIR/$SubjectID/surf/rh.thickness.deformed $SubjectDIR/$SubjectID/surf/rh.thickness
