#!/bin/bash

WorkingDirectory="$1"
InputCoefficents="$2"
InputFile="$3"
OutputFile="$4"
OutputTransform="$5"

DIR=`pwd`
cd $WorkingDirectory
gradient_unwarp.py "$InputFile".nii.gz trilinear.nii.gz siemens -g "$InputCoefficents" -n
convertwarp --ref=trilinear.nii.gz --premat=shiftMatrix.mat --warp1=fullWarp.nii.gz --out="$OutputTransform"
applywarp --interp=spline -i "$InputFile" -r "$InputFile" -w "$OutputTransform" -o "$OutputFile"
cd $DIR

