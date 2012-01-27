#!/bin/bash

Path="$1"
Subject="$2"
NameOffMRI="$3"
DownSampleNameI="$4"
FinalfMRIResolution="$5"
SmoothingFWHM="$6"
Caret7_Command="$7"
PipelineComponents="$8"
AtlasParcellation="$9"
AtlasSurfaceROI="${10}"

#Naming Conventions
AtlasSpaceFolder="MNINonLinear"
NativeFolder="Native"
ResultsFolder="Results"
T1wAtlasName="T1w_restore"
DownSampleFolder="fsaverage_LR${DownSampleNameI}k"
ROIFolder="ROIs"
OutputDenseTimeseries="${NameOffMRI}"
OutputAtlasDenseTimeseries="${NameOffMRI}_Atlas"

AtlasSpaceFolder="$Path"/"$Subject"/"$AtlasSpaceFolder"
ResultsFolder="$AtlasSpaceFolder"/"$ResultsFolder"/"$NameOffMRI"

#Make fMRI Ribbon
#Noisy Voxel Outlier Exclusion
#Ribbon-based Volume to Surface mapping and resampling to standard surface
#Alternates Could Be Trilinear (interpolated voxel) or NearestNeighbor (enclosing voxel)
mkdir "$ResultsFolder"/RibbonVolumeToSurfaceMapping
"$PipelineComponents"/RibbonVolumeToSurfaceMapping.sh "$ResultsFolder"/RibbonVolumeToSurfaceMapping "$ResultsFolder"/"$NameOffMRI" "$Subject" "$AtlasSpaceFolder"/"$NativeFolder" "$AtlasSpaceFolder"/"$DownSampleFolder" "$AtlasSpaceFolder"/"$T1wAtlasName""$FinalfMRIResolution" "$DownSampleNameI" "$Caret7_Command" "$AtlasSurfaceROI"

#Surface Smoothing
"$PipelineComponents"/SurfaceSmoothing.sh "$ResultsFolder"/"$NameOffMRI" "$Subject" "$AtlasSpaceFolder"/"$DownSampleFolder" "$DownSampleNameI" "$SmoothingFWHM" "$Caret7_Command"

#Subcortical Processing
mkdir "$ResultsFolder"/SubcorticalProcessing 
"$PipelineComponents"/SubcorticalProcessing.sh "$ResultsFolder"/SubcorticalProcessing "$AtlasSpaceFolder" "$AtlasSpaceFolder"/"$ROIFolder" "$AtlasParcellation" "$FinalfMRIResolution" "$DownSampleNameI" "$ResultsFolder"/"$NameOffMRI" "$SmoothingFWHM"

#Generation of Dense Timeseries
"$PipelineComponents"/CreateDenseTimeseries.sh "$AtlasSpaceFolder"/"$DownSampleFolder" "$Subject" "$DownSampleNameI" "$ResultsFolder"/"$NameOffMRI" "$SmoothingFWHM" "$FinalfMRIResolution" "$AtlasSpaceFolder"/"$ROIFolder" "$ResultsFolder"/"$OutputDenseTimeseries" "$ResultsFolder"/"$OutputAtlasDenseTimeseries"

