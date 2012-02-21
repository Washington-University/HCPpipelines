#!/bin/bash -e

echo -e "\n ACPCAlignment"

WorkingDirectory="$1"
Input="$2"
Reference="$3"
Output="$4"
OutputMatrix="$5"
StandardFOV="$6"
PipelineComponents="$7"


cd "$WorkingDirectory"

flirt -interp spline -in "$Input" -ref "$Reference" -omat "$WorkingDirectory"/initial.mat -out "$WorkingDirectory"/initial.nii.gz -searchrx -30 30 -searchry -30 30 -searchrz -30 30
convert_xfm -omat "$WorkingDirectory"/initial_inv.mat -inverse "$WorkingDirectory"/initial.mat
applywarp --interp=nn -i "$StandardFOV" -r "$Input" --premat="$WorkingDirectory"/initial_inv.mat -o "$WorkingDirectory"/fov.nii.gz
fslmaths "$Input" -mas "$WorkingDirectory"/fov.nii.gz "$WorkingDirectory"/maskedfov.nii.gz
flirt -interp spline -in "$WorkingDirectory"/maskedfov.nii.gz -ref "$Reference" -omat "$WorkingDirectory"/final.mat -out "$WorkingDirectory"/acpc_final.nii.gz -searchrx -30 30 -searchry -30 30 -searchrz -30 30
python "$PipelineComponents"/aff2rigid.py "$WorkingDirectory"/final.mat "$OutputMatrix"
applywarp --interp=spline -i "$Input" -r "$Reference" --premat="$OutputMatrix" -o "$Output"

echo -e "\n END: ACPCAlignment"
