#!/bin/bash 

# Requirements for this script
#  installed versions of: FSL, Connectome Workbench (wb_command)
#  environment: HCPPIPEDIR, FSLDIR, CARET7DIR

########################################## PIPELINE OVERVIEW ##########################################

# TODO

########################################## OUTPUT DIRECTORIES ##########################################

# TODO

################################################ SUPPORT FUNCTIONS ##################################################

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

script_name=$(basename "${0}")

show_usage() {
	cat <<EOF

${script_name}: Run fMRISurface processing pipeline

Usage: ${script_name} [options]

Usage information To Be Written

EOF
}

# Allow script to return a Usage statement, before any other output or checking
if [ "$#" = "0" ]; then
    show_usage
    exit 1
fi

# ------------------------------------------------------------------------------
#  Check that HCPPIPEDIR is defined and Load Function Libraries
# ------------------------------------------------------------------------------

if [ -z "${HCPPIPEDIR}" ]; then
  echo "${script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
  exit 1
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source ${HCPPIPEDIR}/global/scripts/opts.shlib                 # Command line option functions

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
	show_usage
	exit 0
fi

${HCPPIPEDIR}/show_version

# ------------------------------------------------------------------------------
#  Verify required environment variables are set and log value
# ------------------------------------------------------------------------------

log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FSLDIR
log_Check_Env_Var CARET7DIR

# ------------------------------------------------------------------------------
#  Parse Command Line Options
# ------------------------------------------------------------------------------

log_Msg "Platform Information Follows: "
uname -a

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

if [ -z "${RegName}" ]; then
    RegName="MSMSulc"
fi

RUN=`opts_GetOpt1 "--printcom" $@`  # use ="echo" for just printing everything and not running the commands (default is to run)

log_Msg "Path: ${Path}"
log_Msg "Subject: ${Subject}"
log_Msg "NameOffMRI: ${NameOffMRI}"
log_Msg "LowResMesh: ${LowResMesh}"
log_Msg "FinalfMRIResolution: ${FinalfMRIResolution}"
log_Msg "SmoothingFWHM: ${SmoothingFWHM}"
log_Msg "GrayordinatesResolution: ${GrayordinatesResolution}"
log_Msg "RegName: ${RegName}"
log_Msg "RUN: ${RUN}"

if [ "${RegName}" = "FS" ] ; then
  log_Warn "WARNING: FreeSurfer's surface registration (based on cortical folding) is deprecated in the"
  log_Warn "         HCP Pipelines as it results in poorer cross-subject functional and cortical areal "
  log_Warn "         alignment relative to MSMSulc. Additionally, FreeSurfer registration results in "
  log_Warn "         dramatically higher surface distortion (both isotropic and anisotropic). These things"
  log_Warn "         occur because FreeSurfer's registration has too little regularization of folding patterns"
  log_Warn "         that are imperfectly correlated with function and cortical areas, resulting in overfitting"
  log_Warn "         of folding patterns. See Robinson et al 2014, 2018 Neuroimage, and Coalson et al 2018 PNAS"
  log_Warn "         for more details."
fi

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

log_Msg "Completed!"
