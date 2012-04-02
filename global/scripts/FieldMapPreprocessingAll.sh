#!/bin/bash 
set -e

echo -e "\n START: Field Map Preprocessing and Gradient Unwarping"

WorkingDirectory="$1"
MagnitudeInputName="$2"
PhaseInputName="$3"
TE="$4"
MagnitudeOutput="$5"
MagnitudeBrainOutput="$6"
PhaseOutput="$7"
FieldMapOutput="$8"
GradientDistortionCoeffs="$9"
GlobalScripts="${10}"


fslmaths "$MagnitudeInputName" -Tmean "$WorkingDirectory"/Magnitude.nii.gz
bet "$WorkingDirectory"/Magnitude.nii.gz "$WorkingDirectory"/Magnitude_brain.nii.gz -f .35 -m #Brain extract the magnitude image
cp "$PhaseInputName" "$WorkingDirectory"/Phase.nii.gz
"$GlobalScripts"/fmrib_prepare_fieldmap.sh SIEMENS "$WorkingDirectory"/Phase.nii.gz "$WorkingDirectory"/Magnitude_brain.nii.gz "$WorkingDirectory"/FieldMap.nii.gz "$TE"

if [ ! $GradientDistortionCoeffs = "NONE" ] ; then
  "$GlobalScripts"/GradientDistortionUnwarp.sh "$WorkingDirectory" "$GradientDistortionCoeffs" "$WorkingDirectory"/Magnitude "$WorkingDirectory"/Magnitude_gdc "$WorkingDirectory"/Magnitude_gdc_warp
  "$GlobalScripts"/GradientDistortionUnwarp.sh "$WorkingDirectory" "$GradientDistortionCoeffs" "$WorkingDirectory"/Magnitude_brain "$WorkingDirectory"/Magnitude_brain_gdc "$WorkingDirectory"/Magnitude_brain_gdc_warp
  "$GlobalScripts"/GradientDistortionUnwarp.sh "$WorkingDirectory" "$GradientDistortionCoeffs" "$WorkingDirectory"/Phase "$WorkingDirectory"/Phase_gdc "$WorkingDirectory"/Phase_gdc_warp
  "$GlobalScripts"/GradientDistortionUnwarp.sh "$WorkingDirectory" "$GradientDistortionCoeffs" "$WorkingDirectory"/FieldMap "$WorkingDirectory"/FieldMap_gdc "$WorkingDirectory"/FieldMap_gdc_warp

  Lower=`fslstats "$WorkingDirectory"/Magnitude_brain.nii.gz -r | cut -d " " -f 1`
  fslmaths "$WorkingDirectory"/Magnitude_brain_gdc.nii.gz -thr $Lower -ero -dilD "$WorkingDirectory"/Magnitude_brain_gdc.nii.gz

  cp "$WorkingDirectory"/Magnitude_gdc.nii.gz "$MagnitudeOutput".nii.gz
  cp "$WorkingDirectory"/Magnitude_brain_gdc.nii.gz "$MagnitudeBrainOutput".nii.gz
  cp "$WorkingDirectory"/Phase_gdc.nii.gz "$PhaseOutput".nii.gz
  cp "$WorkingDirectory"/FieldMap_gdc.nii.gz "$FieldMapOutput".nii.gz
else
  cp "$WorkingDirectory"/Magnitude.nii.gz "$MagnitudeOutput".nii.gz
  cp "$WorkingDirectory"/Magnitude_brain.nii.gz "$MagnitudeBrainOutput".nii.gz
  cp "$WorkingDirectory"/Phase.nii.gz "$PhaseOutput".nii.gz
  cp "$WorkingDirectory"/FieldMap.nii.gz "$FieldMapOutput".nii.gz
fi
echo -e "\n END: Field Map Preprocessing and Gradient Unwarping"

