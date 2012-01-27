#!/bin/bash

WorkingDirectory="$1"
T1wRestore="$2"
T1wRestoreBrain="$3"
T2wImage="$4"
T2wRestore="$5"
OutputT2wImage="$6"
OutputT2wImageRestore="$7"
OutputT2wImageRestoreBrain="$8"
InputMatrix="$9"
OutputMatrix="${10}"
Bias="${11}"
OutputT1wT2wProduct="${12}"

cd "$WorkingDirectory"
epi_reg "$T2wRestore" "$T1wRestore" "$T1wRestoreBrain" "$WorkingDirectory"/T2w2T1wRE
convert_xfm -omat "$OutputMatrix" -concat "$WorkingDirectory"/T2w2T1wRE.mat "$InputMatrix"
applywarp --interp=spline --in="$T2wImage" --ref="$T1wRestore" --premat="$OutputMatrix" --out="$OutputT2wImage"
fslmaths "$OutputT2wImage" -add 1 "$OutputT2wImage" -odt float
fslmaths "$OutputT2wImage" -div "$Bias" "$OutputT2wImageRestore"
fslmaths "$OutputT2wImageRestore" -mas "$T1wRestoreBrain" "$OutputT2wImageRestoreBrain"
fslmaths "$T1wRestore" -mul "$OutputT2wImageRestore" "$OutputT1wT2wProduct"

