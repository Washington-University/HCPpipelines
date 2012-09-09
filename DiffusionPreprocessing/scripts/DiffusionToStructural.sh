#!/bin/bash

set -e
echo -e "\n START: DiffusionToStructural"


WorkingDirectory="$1"
DiffusionInput="$2"
T1wImage="$3"
T1wRestoreImage="$4"
T1wBrainImage="$5"
InputAtlasTransform="$6"
OutputTransform="$7"
OutputInvTransform="$8"
OutputAtlasTransform="$9"
OutputInvAtlasTransform="${10}"
BiasField="${11}"
FreeSurferSubjectFolder="${12}"
FreeSurferSubjectID="${13}"
RegOutput="${14}"
QAImage="${15}"
InputBrainMask="${16}"
OutputBrainMask="${17}"
GlobalScripts="${18}"

T1wBrainImageFile=`basename $T1wBrainImage`


cp "$T1wBrainImage".nii.gz "$WorkingDirectory"/"$T1wBrainImageFile".nii.gz

##b0 FLIRT BBR and bbregister to T1w
regimg="nodif"
fslroi "$DiffusionInput" "$WorkingDirectory"/"$regimg" 0 1

"$GlobalScripts"/scripts/epi_reg.sh "$WorkingDirectory"/"$regimg" "$T1wImage" "$WorkingDirectory"/"$T1wBrainImageFile" "$WorkingDirectory"/"$regimg"2T1w_initII
applywarp --interp=spline  -i "$WorkingDirectory"/"$regimg" -r "$T1wImage" --premat="$WorkingDirectory"/"$regimg"2T1w_initII_init.mat -o "$WorkingDirectory"/"$regimg"2T1w_init.nii.gz
applywarp --interp=spline -i "$WorkingDirectory"/"$regimg" -r "$T1wImage" --premat="$WorkingDirectory"/"$regimg"2T1w_initII.mat -o "$WorkingDirectory"/"$regimg"2T1w_initII.nii.gz
fslmaths "$WorkingDirectory"/"$regimg"2T1w_initII.nii.gz -div "$BiasField" "$WorkingDirectory"/"$regimg"2T1w_restore_initII.nii.gz

SUBJECTS_DIR="$FreeSurferSubjectFolder"
export SUBJECTS_DIR
bbregister --s "$FreeSurferSubjectID" --mov "$WorkingDirectory"/"$regimg"2T1w_restore_initII.nii.gz --surf white.deformed --init-reg "$FreeSurferSubjectFolder"/"$FreeSurferSubjectID"/mri/transforms/eye.dat --bold --reg "$WorkingDirectory"/EPItoT1w.dat --o "$WorkingDirectory"/"$regimg"2T1w.nii.gz
tkregister2 --noedit --reg "$WorkingDirectory"/EPItoT1w.dat --mov "$WorkingDirectory"/"$regimg"2T1w_restore_initII.nii.gz --targ "$T1wImage".nii.gz --fslregout "$WorkingDirectory"/diff2str_fs.mat
convert_xfm -omat "$WorkingDirectory"/diff2str.mat -concat "$WorkingDirectory"/diff2str_fs.mat "$WorkingDirectory"/"$regimg"2T1w_initII.mat
applywarp --interp=spline -i "$WorkingDirectory"/"$regimg" -r "$T1wImage".nii.gz --premat="$WorkingDirectory"/diff2str.mat -o "$WorkingDirectory"/"$regimg"2T1w
fslmaths "$WorkingDirectory"/"$regimg"2T1w -div "$BiasField" "$WorkingDirectory"/"$regimg"2T1w_restore

cp "$WorkingDirectory"/diff2str.mat $OutputTransform
convert_xfm -omat $OutputInvTransform -inverse "$WorkingDirectory"/diff2str.mat
convertwarp --premat="$WorkingDirectory"/diff2str.mat --warp1="$InputAtlasTransform" --ref="$T1wImage" --out="$OutputAtlasTransform"
invwarp -w "$OutputAtlasTransform" -o "$OutputInvAtlasTransform" -r "$T1wImage"

cp "$WorkingDirectory"/"$regimg"2T1w_restore.nii.gz "$RegOutput".nii.gz

fslmaths "$T1wRestoreImage".nii.gz -mul "$WorkingDirectory"/"$regimg"2T1w_restore.nii.gz -sqrt "$QAImage"_"$regimg".nii.gz

applywarp --interp=nn -i "$InputBrainMask" -r "$WorkingDirectory"/"$regimg" --premat=$OutputInvTransform -o "$OutputBrainMask"

##FA FLIRT 6 dof
regimg="data_FA"
dtifit -k "$DiffusionInput" -m "$OutputBrainMask" -b "$WorkingDirectory"/../data/bvals -r "$WorkingDirectory"/../data/bvecs -o "$WorkingDirectory"/data
flirt -dof 6 -in "$WorkingDirectory"/"$regimg" -ref "$WorkingDirectory"/"$T1wBrainImageFile" -omat "$WorkingDirectory"/"$regimg"2T1w.mat
applywarp --interp=spline -i "$WorkingDirectory"/nodif -r "$WorkingDirectory"/"$T1wBrainImageFile" --premat="$WorkingDirectory"/"$regimg"2T1w.mat -o "$WorkingDirectory"/"$regimg"2T1w
fslmaths "$WorkingDirectory"/"$regimg"2T1w -div "$BiasField" "$WorkingDirectory"/"$regimg"2T1w_restore

fslmaths "$T1wRestoreImage".nii.gz -mul "$WorkingDirectory"/"$regimg"2T1w_restore.nii.gz -sqrt "$QAImage"_"$regimg".nii.gz

echo " END: DiffusionToStructural"
