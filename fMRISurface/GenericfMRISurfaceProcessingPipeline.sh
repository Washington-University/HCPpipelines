#!/bin/bash -e

Path="$1"
Subject="$2"
NameOffMRI="$3"
DownSampleNameI="$4"
FinalfMRIResolution="$5"
SmoothingFWHM="$6"
Caret5_Command="$7"
Caret7_Command="$8"
PipelineScripts="$9"
AtlasParcellation="${10}"
AtlasSurfaceROI="${11}"
BrainOrdinatesResolution="${12}" #Could be "SAME" or "DIFFERENT"
SubcorticalBrainOrdinatesLabels="${13}"

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
ROIFolder="$AtlasSpaceFolder"/"$ROIFolder"

#Make fMRI Ribbon
#Noisy Voxel Outlier Exclusion
#Ribbon-based Volume to Surface mapping and resampling to standard surface
#Alternates Could Be Trilinear (interpolated voxel) or NearestNeighbor (enclosing voxel)
mkdir -p "$ResultsFolder"/RibbonVolumeToSurfaceMapping
"$PipelineScripts"/RibbonVolumeToSurfaceMapping.sh "$ResultsFolder"/RibbonVolumeToSurfaceMapping "$ResultsFolder"/"$NameOffMRI" "$Subject" "$AtlasSpaceFolder"/"$NativeFolder" "$AtlasSpaceFolder"/"$DownSampleFolder" "$AtlasSpaceFolder"/"$T1wAtlasName""$FinalfMRIResolution" "$DownSampleNameI" "$Caret5_Command" "$Caret7_Command" "$AtlasSurfaceROI"

#Surface Smoothing
"$PipelineScripts"/SurfaceSmoothing.sh "$ResultsFolder"/"$NameOffMRI" "$Subject" "$AtlasSpaceFolder"/"$DownSampleFolder" "$DownSampleNameI" "$SmoothingFWHM" "$Caret7_Command"

#Subcortical Processing
mkdir -p "$ResultsFolder"/SubcorticalProcessing 
"$PipelineScripts"/SubcorticalProcessing.sh "$ResultsFolder"/SubcorticalProcessing "$AtlasSpaceFolder" "$ROIFolder" "$AtlasParcellation" "$FinalfMRIResolution" "$DownSampleNameI" "$ResultsFolder"/"$NameOffMRI" "$SmoothingFWHM" "$Caret7_Command" "$SubcorticalBrainOrdinatesLabels" "$T1wAtlasName"

#Generation of Dense Timeseries
"$PipelineScripts"/CreateDenseTimeseries.sh "$AtlasSpaceFolder"/"$DownSampleFolder" "$Subject" "$DownSampleNameI" "$ResultsFolder"/"$NameOffMRI" "$SmoothingFWHM" "$FinalfMRIResolution" "$ROIFolder" "$ResultsFolder"/"$OutputDenseTimeseries" "$ResultsFolder"/"$OutputAtlasDenseTimeseries" "$Caret7_Command"

