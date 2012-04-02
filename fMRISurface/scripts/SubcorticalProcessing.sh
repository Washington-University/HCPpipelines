#!/bin/bash -e
echo -e "\n START: SubcorticalProcessing"

WorkingDirectory="$1"
AtlasSpaceFolder="$2"
ROIFolder="$3"
AtlasParcellation="$4"
FinalfMRIResolution="$5"
DownSampleNameI="$6"
VolumefMRI="$7"
SmoothingFWHM="$8"
Caret7_Command="$9"
SubcorticalBrainOrdinatesLabels="${10}"
T1wImageFile="${11}"

Sigma=`echo "$SmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`

if [ ! -e "$ROIFolder"/wmparc."$FinalfMRIResolution".nii.gz ] ; then
  applywarp --interp=nn -i "$AtlasSpaceFolder"/wmparc.nii.gz -r "$AtlasSpaceFolder"/"$T1wImageFile""$FinalfMRIResolution" -o "$ROIFolder"/wmparc."$FinalfMRIResolution"
fi

if [ ! -e "$ROIFolder"/Atlas_wmparc."$FinalfMRIResolution".nii.gz ] ; then
  applywarp --interp=nn -i "$AtlasParcellation" -r "$AtlasSpaceFolder"/"$T1wImageFile""$FinalfMRIResolution" -o "$ROIFolder"/Atlas_wmparc."$FinalfMRIResolution"
fi

#Some way faster and more concise code:

"$Caret7_Command" -volume-label-import "$ROIFolder"/wmparc."$FinalfMRIResolution".nii.gz "$SubcorticalBrainOrdinatesLabels" "$ROIFolder"/ROIs."$FinalfMRIResolution".nii.gz -discard-others
"$Caret7_Command" -volume-label-import "$ROIFolder"/Atlas_wmparc."$FinalfMRIResolution".nii.gz "$SubcorticalBrainOrdinatesLabels" "$ROIFolder"/Atlas_ROIs."$FinalfMRIResolution".nii.gz -discard-others

"$Caret7_Command" -volume-parcel-smoothing "$VolumefMRI".nii.gz "$ROIFolder"/ROIs."$FinalfMRIResolution".nii.gz $Sigma "$VolumefMRI"_Subcortical_s"$SmoothingFWHM".nii.gz -fix-zeros
"$Caret7_Command" -volume-parcel-resampling "$VolumefMRI".nii.gz "$ROIFolder"/ROIs."$FinalfMRIResolution".nii.gz "$ROIFolder"/Atlas_ROIs."$FinalfMRIResolution".nii.gz $Sigma "$VolumefMRI"_AtlasSubcortical_s"$SmoothingFWHM".nii.gz -fix-zeros

echo " END: SubcorticalProcessing"

