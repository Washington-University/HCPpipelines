#!/bin/bash -e

echo -e "\n START: T2w2T1Reg"

WorkingDirectory="$1"
T1wImage="$2"
T1wImageBrain="$3"
T2wImage="$4"
T2wImageBrain="$5"
OutputT1wImage="$6"
OutputT1wImageBrain="$7"
OutputT1wTransform="$8"
OutputT2wImage="$9"
OutputT2wTransform="${10}"

T1wImageBrainFile=`basename "$T1wImageBrain"`

cd "$WorkingDirectory"
cp "$T1wImageBrain".nii.gz "$WorkingDirectory"/"$T1wImageBrainFile".nii.gz
epi_reg "$T2wImageBrain" "$T1wImage" "$WorkingDirectory"/"$T1wImageBrainFile" "$WorkingDirectory"/T2w2T1w
applywarp --interp=spline --in="$T2wImage" --ref="$T1wImage" --premat="$WorkingDirectory"/T2w2T1w.mat --out="$WorkingDirectory"/T2w2T1w
fslmaths "$WorkingDirectory"/T2w2T1w -add 1 "$WorkingDirectory"/T2w2T1w -odt float
cp "$T1wImage".nii.gz "$OutputT1wImage".nii.gz
cp "$T1wImageBrain".nii.gz "$OutputT1wImageBrain".nii.gz
fslmerge -t $OutputT1wTransform "$T1wImage".nii.gz "$T1wImage".nii.gz "$T1wImage".nii.gz
fslmaths $OutputT1wTransform -mul 0 $OutputT1wTransform
cp "$WorkingDirectory"/T2w2T1w.nii.gz "$OutputT2wImage".nii.gz
convertwarp -r "$OutputT2wImage".nii.gz -w $OutputT1wTransform --postmat="$WorkingDirectory"/T2w2T1w.mat --out="$OutputT2wTransform"

echo -e "\n START: T2w2T1Reg"
