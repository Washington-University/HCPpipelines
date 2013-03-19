#!/bin/bash 
set -e

echo " "
echo " START: T2w2T1Reg"

WD="$1"
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

cp "$T1wImageBrain".nii.gz "$WD"/"$T1wImageBrainFile".nii.gz
${FSLDIR}/bin/epi_reg --epi="$T2wImageBrain" --t1="$T1wImage" --t1brain="$WD"/"$T1wImageBrainFile" --out="$WD"/T2w2T1w
${FSLDIR}/bin/applywarp --rel --interp=spline --in="$T2wImage" --ref="$T1wImage" --premat="$WD"/T2w2T1w.mat --out="$WD"/T2w2T1w
${FSLDIR}/bin/fslmaths "$WD"/T2w2T1w -add 1 "$WD"/T2w2T1w -odt float
cp "$T1wImage".nii.gz "$OutputT1wImage".nii.gz
cp "$T1wImageBrain".nii.gz "$OutputT1wImageBrain".nii.gz
${FSLDIR}/bin/fslmerge -t $OutputT1wTransform "$T1wImage".nii.gz "$T1wImage".nii.gz "$T1wImage".nii.gz
${FSLDIR}/bin/fslmaths $OutputT1wTransform -mul 0 $OutputT1wTransform
cp "$WD"/T2w2T1w.nii.gz "$OutputT2wImage".nii.gz
${FSLDIR}/bin/convertwarp --relout --rel -r "$OutputT2wImage".nii.gz -w $OutputT1wTransform --postmat="$WD"/T2w2T1w.mat --out="$OutputT2wTransform"

echo " "
echo " START: T2w2T1Reg"
