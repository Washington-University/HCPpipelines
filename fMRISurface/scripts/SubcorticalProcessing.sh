#!/bin/bash 
set -e
script_name="SubcorticalProcessing.sh"
echo "${script_name}: START"

AtlasSpaceFolder="$1"
echo "${script_name}: AtlasSpaceFolder: ${AtlasSpaceFolder}"

ROIFolder="$2"
echo "${script_name}: ROIFolder: ${ROIFolder}"

FinalfMRIResolution="$3"
echo "${script_name}: FinalfMRIResolution: ${FinalfMRIResolution}"

ResultsFolder="$4"
echo "${script_name}: ResultsFolder: ${ResultsFolder}"

NameOffMRI="$5"
echo "${script_name}: NameOffMRI: ${NameOfffMRI}"

SmoothingFWHM="$6"
echo "${script_name}: SmoothingFWHM: ${SmoothingFWHM}"

BrainOrdinatesResolution="$7"
echo "${script_name}: BrainOrdinatesResolution: ${BrainOrdinatesResolution}"

VolumefMRI="${ResultsFolder}/${NameOffMRI}"
echo "${script_name}: VolumefMRI: ${volumefMRI}"

Sigma=`echo "$SmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`
echo "${script_name}: Sigma: ${Sigma}"

unset POSIXLY_CORRECT

if [ 1 -eq `echo "$BrainOrdinatesResolution == $FinalfMRIResolution" | bc -l` ] ; then
	echo "${script_name}: Doing volume parcel resampling without first applying warp"
	${CARET7DIR}/wb_command -volume-parcel-resampling "$VolumefMRI".nii.gz "$ROIFolder"/ROIs."$BrainOrdinatesResolution".nii.gz "$ROIFolder"/Atlas_ROIs."$BrainOrdinatesResolution".nii.gz $Sigma "$VolumefMRI"_AtlasSubcortical_s"$SmoothingFWHM".nii.gz -fix-zeros
else
	echo "${script_name}: Doing applywarp and volume label import"
	applywarp --interp=nn -i "$AtlasSpaceFolder"/wmparc.nii.gz -r "$VolumefMRI".nii.gz -o "$ResultsFolder"/wmparc."$FinalfMRIResolution".nii.gz
	${CARET7DIR}/wb_command -volume-label-import "$ResultsFolder"/wmparc."$FinalfMRIResolution".nii.gz ${HCPPIPEDIR_Config}/FreeSurferSubcorticalLabelTableLut.txt "$ResultsFolder"/ROIs."$FinalfMRIResolution".nii.gz -discard-others
	echo "${script_name}: Doing volume parcel resampling after applying warp and doing a volume label import"
	${CARET7DIR}/wb_command -volume-parcel-resampling-generic "$VolumefMRI".nii.gz "$ResultsFolder"/ROIs."$FinalfMRIResolution".nii.gz "$ROIFolder"/Atlas_ROIs."$BrainOrdinatesResolution".nii.gz $Sigma "$VolumefMRI"_AtlasSubcortical_s"$SmoothingFWHM".nii.gz -fix-zeros
	rm "$ResultsFolder"/wmparc."$FinalfMRIResolution".nii.gz
fi
echo "${script_name}: END"

