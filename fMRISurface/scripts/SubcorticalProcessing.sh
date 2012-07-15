#!/bin/bash 
set -e
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
BrainOrdinatesResolution="${12}"

Sigma=`echo "$SmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`

if [ ! -e "$ROIFolder"/wmparc."$FinalfMRIResolution".nii.gz ] ; then
  applywarp --interp=nn -i "$AtlasSpaceFolder"/wmparc.nii.gz -r "$AtlasSpaceFolder"/"$T1wImageFile""$FinalfMRIResolution" -o "$ROIFolder"/wmparc."$FinalfMRIResolution"
fi

if [ ! -e "$ROIFolder"/Atlas_wmparc."$BrainOrdinatesResolution".nii.gz ] ; then
  if [ `echo "$BrainOrdinatesResolution == $FinalfMRIResolution" | bc -l` -eq 1 ] ; then 
    applywarp --interp=nn -i "$AtlasParcellation" -r "$AtlasSpaceFolder"/"$T1wImageFile""$BrainOrdinatesResolution" -o "$ROIFolder"/Atlas_wmparc."$BrainOrdinatesResolution"
  else
    flirt -interp spline -in "$AtlasSpaceFolder"/"$T1wImageFile" -ref "$AtlasSpaceFolder"/"$T1wImageFile" -applyisoxfm "$BrainOrdinatesResolution" -out "$AtlasSpaceFolder"/"$T1wImageFile""$BrainOrdinatesResolution"
    applywarp --interp=spline -i "$AtlasSpaceFolder"/"$T1wImageFile" -r "$AtlasSpaceFolder"/"$T1wImageFile""$BrainOrdinatesResolution" -o "$AtlasSpaceFolder"/"$T1wImageFile""$BrainOrdinatesResolution"
    applywarp --interp=nn -i "$AtlasParcellation" -r "$AtlasSpaceFolder"/"$T1wImageFile""$BrainOrdinatesResolution" -o "$ROIFolder"/Atlas_wmparc."$BrainOrdinatesResolution"
  fi
fi

#Some way faster and more concise code:

"$Caret7_Command" -volume-label-import "$ROIFolder"/wmparc."$FinalfMRIResolution".nii.gz "$SubcorticalBrainOrdinatesLabels" "$ROIFolder"/ROIs."$FinalfMRIResolution".nii.gz -discard-others
"$Caret7_Command" -volume-label-import "$ROIFolder"/Atlas_wmparc."$BrainOrdinatesResolution".nii.gz "$SubcorticalBrainOrdinatesLabels" "$ROIFolder"/Atlas_ROIs."$BrainOrdinatesResolution".nii.gz -discard-others

"$Caret7_Command" -volume-parcel-smoothing "$VolumefMRI".nii.gz "$ROIFolder"/ROIs."$FinalfMRIResolution".nii.gz $Sigma "$VolumefMRI"_Subcortical_s"$SmoothingFWHM".nii.gz -fix-zeros
if [ `echo "$BrainOrdinatesResolution == $FinalfMRIResolution" | bc -l` -eq 1  ] ; then
  "$Caret7_Command" -volume-parcel-resampling "$VolumefMRI".nii.gz "$ROIFolder"/ROIs."$FinalfMRIResolution".nii.gz "$ROIFolder"/Atlas_ROIs."$BrainOrdinatesResolution".nii.gz $Sigma "$VolumefMRI"_AtlasSubcortical_s"$SmoothingFWHM".nii.gz -fix-zeros
else
  "$Caret7_Command" -volume-parcel-resampling-generic "$VolumefMRI".nii.gz "$ROIFolder"/ROIs."$FinalfMRIResolution".nii.gz "$ROIFolder"/Atlas_ROIs."$BrainOrdinatesResolution".nii.gz $Sigma "$VolumefMRI"_AtlasSubcortical_s"$SmoothingFWHM".nii.gz -fix-zeros
fi  
echo " END: SubcorticalProcessing"

