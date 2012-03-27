#!/bin/bash -e
echo -e "\n START: IntensityNormalization"

#Option to apply biasfield to fMRI

InputfMRI="$1"
BiasField="$2"
BrainMask="$3"
OutputfMRI="$4"

fslmaths "$InputfMRI" -div "$BiasField" -mas "$BrainMask" -inm 10000 "$OutputfMRI" -odt float

echo "END: IntensityNormalization"
