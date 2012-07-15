#!/bin/bash 
set -e

if [ $# -lt 6 ] ; then
  echo "Usage: `basename $0` <working dir> <input image> <reference image> <output image> <output matrix> <script directory> [brainsize]"
  exit 1;
fi

echo -e "\n START: ACPCAlignment"

WorkingDirectory="$1"
Input="$2"
Reference="$3"
Output="$4"
OutputMatrix="$5"
GlobalScripts="$6"
BrainSizeOpt="$7"

robustfov -i "$Input" -m "$WorkingDirectory"/roi2full.mat -r "$WorkingDirectory"/robustroi.nii.gz -b $BrainSizeOpt
convert_xfm -omat "$WorkingDirectory"/full2roi.mat -inverse "$WorkingDirectory"/roi2full.mat
flirt -interp spline -in "$WorkingDirectory"/robustroi.nii.gz -ref "$Reference" -omat "$WorkingDirectory"/roi2std.mat -out "$WorkingDirectory"/acpc_final.nii.gz -searchrx -30 30 -searchry -30 30 -searchrz -30 30
convert_xfm -omat "$WorkingDirectory"/full2std.mat -concat "$WorkingDirectory"/roi2std.mat "$WorkingDirectory"/full2roi.mat
python "$GlobalScripts"/aff2rigid.py "$WorkingDirectory"/full2std.mat "$OutputMatrix"
applywarp --interp=spline -i "$Input" -r "$Reference" --premat="$OutputMatrix" -o "$Output"

echo -e "\n END: ACPCAlignment"
