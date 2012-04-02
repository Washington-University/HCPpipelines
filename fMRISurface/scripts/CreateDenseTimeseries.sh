#!/bin/bash -e
echo -e "\n START: CreateDenseTimeSeries"

DownSampleFolder="$1"
Subject="$2"
DownSampleNameI="$3"
NameOffMRI="$4"
SmoothingFWHM="$5"
FinalfMRIResolution="$6"
ROIFolder="$7"
OutputDenseTimeseries="$8"
OutputAtlasDenseTimeseries="${9}"
Caret7_Command="${10}"

TR_vol=`fslval "$NameOffMRI" pixdim4 | cut -d " " -f 1`

#Some way faster and more concise code:

"$Caret7_Command" -cifti-create-dense-timeseries "$OutputAtlasDenseTimeseries".dtseries.nii -volume "$NameOffMRI"_AtlasSubcortical_s"$SmoothingFWHM".nii.gz "$ROIFolder"/Atlas_ROIs."$FinalfMRIResolution".nii.gz -left-metric "$NameOffMRI"_s"$SmoothingFWHM".atlasroi.L."$DownSampleNameI"k_fs_LR.func.gii -roi-left "$DownSampleFolder"/"$Subject".L.atlasroi."$DownSampleNameI"k_fs_LR.shape.gii -right-metric "$NameOffMRI"_s"$SmoothingFWHM".atlasroi.R."$DownSampleNameI"k_fs_LR.func.gii -roi-right "$DownSampleFolder"/"$Subject".R.atlasroi."$DownSampleNameI"k_fs_LR.shape.gii -timestep "$TR_vol"
"$Caret7_Command" -cifti-create-dense-timeseries "$OutputDenseTimeseries".dtseries.nii -volume "$NameOffMRI"_Subcortical_s"$SmoothingFWHM".nii.gz "$ROIFolder"/ROIs."$FinalfMRIResolution".nii.gz -left-metric "$NameOffMRI"_s"$SmoothingFWHM".roi.L."$DownSampleNameI"k_fs_LR.func.gii -roi-left "$DownSampleFolder"/"$Subject".L.roi."$DownSampleNameI"k_fs_LR.shape.gii -right-metric "$NameOffMRI"_s"$SmoothingFWHM".roi.R."$DownSampleNameI"k_fs_LR.func.gii -roi-right "$DownSampleFolder"/"$Subject".R.roi."$DownSampleNameI"k_fs_LR.shape.gii -timestep "$TR_vol"

echo " END: CreateDenseTimeSeries"
