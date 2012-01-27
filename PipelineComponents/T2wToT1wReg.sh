#!/bin/bash

WorkingDirectory="$1"
T1wImage="$2"
T1wImageBrain="$3"
T2wImage="$4"
OutputImage="$5"
OutputMatrix="$6"

cd "$WorkingDirectory"
epi_reg "$T2wImage" "$T1wImage" "$T1wImageBrain" "$WorkingDirectory"/T2w2T1w
applywarp --interp=spline --in="$T2wImage" --ref="$T1wImage" --premat="$WorkingDirectory"/T2w2T1w.mat --out="$WorkingDirectory"/T2w2T1w
fslmaths "$WorkingDirectory"/T2w2T1w -add 1 "$WorkingDirectory"/T2w2T1w -odt float
cp "$WorkingDirectory"/T2w2T1w.mat "$OutputMatrix"
cp "$WorkingDirectory"/T2w2T1w.nii.gz "$OutputImage".nii.gz


