#!/bin/bash
set -e

# Requirements for this script
#  installed versions of: FSL (version 5.0.6), FreeSurfer (version 5.3.0-HCP) , gradunwarp (HCP version 1.0.2)
#  environment: use SetUpHCPPipeline.sh  (or individually set FSLDIR, FREESURFER_HOME, HCPPIPEDIR, PATH - for gradient_unwarp.py)

########################################## PIPELINE OVERVIEW ##########################################

# TODO

########################################## OUTPUT DIRECTORIES ##########################################

# TODO

# --------------------------------------------------------------------------------
#  Load Function Libraries
# --------------------------------------------------------------------------------

source ${HCPPIPEDIR}/global/scripts/log.shlib   # Logging related functions
source ${HCPPIPEDIR}/global/scripts/opts.shlib  # Command line option functions

################################################ SUPPORT FUNCTIONS ##################################################

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

show_usage() {
    echo "Usage information To Be Written"
    exit 1
}

# --------------------------------------------------------------------------------
#   Establish tool name for logging
# --------------------------------------------------------------------------------
log_SetToolName "GenericfMRISurfaceProcessingPipeline.sh"

################################################## OPTION PARSING #####################################################

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
    show_usage
fi

log_Msg "Parsing Command Line Options"

# parse arguments
Path=`opts_GetOpt1 "--path" $@`  # "$1"
Subject=`opts_GetOpt1 "--subject" $@`  # "$2"
NameOffMRI=`opts_GetOpt1 "--fmriname" $@`  # "$6"
LowResMesh=`opts_GetOpt1 "--lowresmesh" $@`  # "$6"
FinalfMRIResolution=`opts_GetOpt1 "--fmrires" $@`  # "${14}"
SmoothingFWHM=`opts_GetOpt1 "--smoothingFWHM" $@`  # "${14}"
GrayordinatesResolution=`opts_GetOpt1 "--grayordinatesres" $@`  # "${14}"
RegName=`opts_GetOpt1 "--regname" $@`

if [ "${RegName}" = "" ]; then
    RegName="FS"
fi

RUN=`opts_GetOpt1 "--printcom" $@`  # use ="echo" for just printing everything and not running the commands (default is to run)

# ------------------------------------------------------------------------------
#  Check MMP Version
# ------------------------------------------------------------------------------

Compliance="hcp"
MPPVersion=`opts_GetOpt1 "--mppversion" $@`
MPPVersion=`opts_DefaultOpt $MPPVersion "hcp"`

if [ "${MPPVersion}" = "legacy" ] ; then
  log_Msg "Legacy Minimal Preprocessing Pipelines: fMRISurface v.XX"
  log_Msg "NOTICE: You are using MPP version that enables processing of images that do not"
  log_Msg "        conform to the HCP specification as described in Glasser et al. (2013)!"
  log_Msg "        Be aware that if the HCP requirements are not met, the level of data quality"
  log_Msg "        can not be guaranteed and the Glasser et al. (2013) paper should not be used"
  log_Msg "        in support of this workflow. A mnauscript with comprehensive evaluation for"
  log_Msg "        the Legacy MPP workflow is in active preparation and should be appropriately"
  log_Msg "        cited when published."
else
  log_Msg "HCP Minimal Preprocessing Pipelines: fMRISurface v.XX"
fi

# -- Final evaluation

if [ "${MPPVersion}" = "legacy" ] ; then
  if [ "${Compliance}" = "legacy" ] ; then
    log_Msg "Processing will continue using Legacy MPP."
  else
    log_Msg "All conditions for the use of HCP MPP are met. Consider using HCP MPP instead of Legacy MPP."
    log_Msg "Processing will continue using Legacy MPP."
  fi
else
  if [ "${Compliance}" = "legacy" ] ; then
    log_Msg "User requested HCP MPP. However, compliance check for use of HCP MPP failed."
    log_Msg "Aborting execution."
    exit 1
  else
    log_Msg "Conditions for the use of HCP MPP are met."
    log_Msg "Processing will continue using HCP MPP."
  fi
fi

# --- END MPP Version Check


log_Msg "Path: ${Path}"
log_Msg "Subject: ${Subject}"
log_Msg "NameOffMRI: ${NameOffMRI}"
log_Msg "LowResMesh: ${LowResMesh}"
log_Msg "FinalfMRIResolution: ${FinalfMRIResolution}"
log_Msg "SmoothingFWHM: ${SmoothingFWHM}"
log_Msg "GrayordinatesResolution: ${GrayordinatesResolution}"
log_Msg "RegName: ${RegName}"
log_Msg "RUN: ${RUN}"

# Setup PATHS
PipelineScripts=${HCPPIPEDIR_fMRISurf}

#Naming Conventions
AtlasSpaceFolder="MNINonLinear"
T1wFolder="T1w"
NativeFolder="Native"
ResultsFolder="Results"
DownSampleFolder="fsaverage_LR${LowResMesh}k"
ROIFolder="ROIs"
OutputAtlasDenseTimeseries="${NameOffMRI}_Atlas"

AtlasSpaceFolder="$Path"/"$Subject"/"$AtlasSpaceFolder"
T1wFolder="$Path"/"$Subject"/"$T1wFolder"
ResultsFolder="$AtlasSpaceFolder"/"$ResultsFolder"/"$NameOffMRI"
ROIFolder="$AtlasSpaceFolder"/"$ROIFolder"

#Make fMRI Ribbon
#Noisy Voxel Outlier Exclusion
#Ribbon-based Volume to Surface mapping and resampling to standard surface

log_Msg "Make fMRI Ribbon"
log_Msg "mkdir -p ${ResultsFolder}/RibbonVolumeToSurfaceMapping"
mkdir -p "$ResultsFolder"/RibbonVolumeToSurfaceMapping
"$PipelineScripts"/RibbonVolumeToSurfaceMapping.sh "$ResultsFolder"/RibbonVolumeToSurfaceMapping "$ResultsFolder"/"$NameOffMRI" "$Subject" "$AtlasSpaceFolder"/"$DownSampleFolder" "$LowResMesh" "$AtlasSpaceFolder"/"$NativeFolder" "${RegName}"

#Surface Smoothing
log_Msg "Surface Smoothing"
"$PipelineScripts"/SurfaceSmoothing.sh "$ResultsFolder"/"$NameOffMRI" "$Subject" "$AtlasSpaceFolder"/"$DownSampleFolder" "$LowResMesh" "$SmoothingFWHM"

#Subcortical Processing
log_Msg "Subcortical Processing"
"$PipelineScripts"/SubcorticalProcessing.sh "$AtlasSpaceFolder" "$ROIFolder" "$FinalfMRIResolution" "$ResultsFolder" "$NameOffMRI" "$SmoothingFWHM" "$GrayordinatesResolution"

#Generation of Dense Timeseries
log_Msg "Generation of Dense Timeseries"
"$PipelineScripts"/CreateDenseTimeseries.sh "$AtlasSpaceFolder"/"$DownSampleFolder" "$Subject" "$LowResMesh" "$ResultsFolder"/"$NameOffMRI" "$SmoothingFWHM" "$ROIFolder" "$ResultsFolder"/"$OutputAtlasDenseTimeseries" "$GrayordinatesResolution"

log_Msg "Completed"
