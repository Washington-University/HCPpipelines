#!/bin/bash 
set -e
echo -e "\n START: CreateDenseTimeSeries"

DownSampleFolder="$1"
Subject="$2"
LowResMesh="$3"
NameOffMRI="$4"
SmoothingFWHM="$5"
ROIFolder="$6"
OutputAtlasDenseTimeseries="$7"
GrayordinatesResolution="$8"

TR_vol=`fslval "$NameOffMRI" pixdim4 | cut -d " " -f 1`

#Some way faster and more concise code:

${CARET7DIR}/wb_command -cifti-create-dense-timeseries "$OutputAtlasDenseTimeseries".dtseries.nii -volume "$NameOffMRI"_AtlasSubcortical_s"$SmoothingFWHM".nii.gz "$ROIFolder"/Atlas_ROIs."$GrayordinatesResolution".nii.gz -left-metric "$NameOffMRI"_s"$SmoothingFWHM".atlasroi.L."$LowResMesh"k_fs_LR.func.gii -roi-left "$DownSampleFolder"/"$Subject".L.atlasroi."$LowResMesh"k_fs_LR.shape.gii -right-metric "$NameOffMRI"_s"$SmoothingFWHM".atlasroi.R."$LowResMesh"k_fs_LR.func.gii -roi-right "$DownSampleFolder"/"$Subject".R.atlasroi."$LowResMesh"k_fs_LR.shape.gii -timestep "$TR_vol"

echo " END: CreateDenseTimeSeries"
