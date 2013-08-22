#!/bin/bash 
set -e
echo -e "\n START: SubcorticalProcessing"

AtlasSpaceFolder="$1"
ROIFolder="$2"
FinalfMRIResolution="$3"
ResultsFolder="$4"
NameOffMRI="$5"
SmoothingFWHM="$6"
BrainOrdinatesResolution="$7"

VolumefMRI="${ResultsFolder}/${NameOffMRI}"
Sigma=`echo "$SmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`

unset POSIXLY_CORRECT

if [ 1 -eq `echo "$BrainOrdinatesResolution == $FinalfMRIResolution" | bc -l` ] ; then
  ${CARET7DIR}/wb_command -volume-parcel-resampling "$VolumefMRI".nii.gz "$ROIFolder"/ROIs."$BrainOrdinatesResolution".nii.gz "$ROIFolder"/Atlas_ROIs."$BrainOrdinatesResolution".nii.gz $Sigma "$VolumefMRI"_AtlasSubcortical_s"$SmoothingFWHM".nii.gz -fix-zeros
else
  applywarp --interp=nn -i "$AtlasSpaceFolder"/wmparc.nii.gz -r "$VolumefMRI".nii.gz -o "$ResultsFolder"/wmparc."$FinalfMRIResolution".nii.gz
  ${CARET7DIR}/wb_command -volume-label-import "$ResultsFolder"/wmparc."$FinalfMRIResolution".nii.gz ${HCPPIPEDIR_Config}/FreeSurferSubcorticalLabelTableLut.txt "$ResultsFolder"/ROIs."$FinalfMRIResolution".nii.gz -discard-others
  ${CARET7DIR}/wb_command -volume-parcel-resampling-generic "$VolumefMRI".nii.gz "$ResultsFolder"/ROIs."$FinalfMRIResolution".nii.gz "$ROIFolder"/Atlas_ROIs."$BrainOrdinatesResolution".nii.gz $Sigma "$VolumefMRI"_AtlasSubcortical_s"$SmoothingFWHM".nii.gz -fix-zeros
  rm "$ResultsFolder"/wmparc."$FinalfMRIResolution".nii.gz
fi  
echo " END: SubcorticalProcessing"

