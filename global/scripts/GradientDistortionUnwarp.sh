#!/bin/bash

WorkingDirectory="$1"
InputCoefficents="$2"
InputFile="$3"
OutputFile="$4"
OutputTransform="$5"

DIR=`pwd`
cd $WorkingDirectory
fslroi "$InputFile".nii.gz "$InputFile"_vol1.nii.gz 0 1
echo "gradient_unwarp.py "$InputFile"_vol1.nii.gz trilinear.nii.gz siemens -g "$InputCoefficents" -n"
gradient_unwarp.py "$InputFile"_vol1.nii.gz trilinear.nii.gz siemens -g "$InputCoefficents" -n
convertwarp --ref=trilinear.nii.gz --premat=shiftMatrix.mat --warp1=fullWarp.nii.gz --out="$OutputTransform"
applywarp --interp=spline -i "$InputFile" -r "$InputFile"_vol1.nii.gz -w "$OutputTransform" -o "$OutputFile"
cd $DIR

