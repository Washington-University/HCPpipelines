#!/bin/bash 
set -e
echo -e "\n START: IntensityNormalization"

#Option to apply biasfield to fMRI

InputfMRI="$1"
BiasField="$2"
BrainMask="$3"
OutputfMRI="$4"
ScoutInput="${5}"
ScoutOutput="${6}"


fslmaths "$InputfMRI" -div "$BiasField" -mas "$BrainMask" -inm 10000 "$OutputfMRI" -odt float

fslmaths "$ScoutInput" -div "$BiasField" -mas "$BrainMask" -inm 10000 "$ScoutOutput" -odt float

echo "END: IntensityNormalization"
