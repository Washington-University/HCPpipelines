#!/bin/bash -e

FieldMapImageFolder="$1"
MagnitudeInputName="$2"
FieldMapInputName="$3"
FieldMapOutputName="$4"
MagnitudeOutputName="$5"
MagnitudeBrainOutputName="$6"
TE="$7"


fslmaths "$MagnitudeInputName" -Tmean "$FieldMapImageFolder"/"$MagnitudeOutputName".nii.gz
bet "$FieldMapImageFolder"/"$MagnitudeOutputName".nii.gz "$FieldMapImageFolder"/"$MagnitudeBrainOutputName".nii.gz -f .35 -m #Brain extract the magnitude image
fslmaths "$FieldMapImageFolder"/"$MagnitudeBrainOutputName".nii.gz -ero "$FieldMapImageFolder"/"$MagnitudeBrainOutputName".nii.gz
fslmaths "$FieldMapInputName" -div 4096 -mul 3.14159265 -sub 3.14159265 -mas "$FieldMapImageFolder"/"$MagnitudeBrainOutputName".nii.gz "$FieldMapImageFolder"/"$FieldMapOutputName"_Wrapped.nii.gz -odt float #Rescale Phase Image
prelude -a "$FieldMapImageFolder"/"$MagnitudeOutputName".nii.gz -p "$FieldMapImageFolder"/"$FieldMapOutputName"_Wrapped.nii.gz -m "$FieldMapImageFolder"/"$MagnitudeBrainOutputName".nii.gz -o "$FieldMapImageFolder"/"$FieldMapOutputName"_UnWrapped.nii.gz #Unwrap phase image
fslmaths "$FieldMapImageFolder"/"$FieldMapOutputName"_UnWrapped.nii.gz -div $TE -mas "$FieldMapImageFolder"/"$MagnitudeBrainOutputName".nii.gz "$FieldMapImageFolder"/"$FieldMapOutputName" #Create field map from phase image
FieldMapMean=`fslstats "$FieldMapImageFolder"/"$FieldMapOutputName" -M` #Determine if there is a non-zero field map mean (i.e. a bulk translation)
fslmaths "$FieldMapImageFolder"/"$FieldMapOutputName" -sub $FieldMapMean -mas "$FieldMapImageFolder"/"$MagnitudeBrainOutputName".nii.gz -dilM -dilM -dilM -dilM -dilM -dilM -dilM -dilM -dilM -dilM -dilM -dilM -dilM -dilM -dilM -dilM -dilM -dilM -dilM -dilM -dilM -dilM -dilM -dilM -dilM -dilM -dilM -dilM -dilM -dilM "$FieldMapImageFolder"/"$FieldMapOutputName" #Remove non-zero field map mean to avoid bulk translation


