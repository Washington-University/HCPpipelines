#!/bin/bash

# Requirements for this script
# installed versions of: FSL, Connectome Workbench (wb_command)
# environment: HCPPIPEDIR, FSLDIR, CARET7DIR

########################################## PIPELINE OVERVIEW ##########################################

# This script maps fMRI data to the left and right hippocampus and dentate gyrus,
# resamples to the target mesh (2k), and combines the four structures into CIFTI files.
#
# The script creates:
#   1. Mean fMRI intensity maps using selected voxels and all ribbon voxels.
#   2. Coefficient of variation (COV) maps using selected voxels and all ribbon voxels.
#   3. Good-voxel maps when good-voxel processing is enabled.
#   4. fMRI timeseries, with optional surface smoothing on the target mesh.
#   5. Variance normalization (VN) maps, without surface smoothing.

########################################## OUTPUT DIRECTORIES ##########################################

# ResultsFolder:
#   Final target-mesh outputs:
#       ${NameOffMRI}_AtlasHipp_s${SmoothingFWHM}${ProcString}.dtseries.nii
#       ${NameOffMRI}_AtlasHipp${ProcString}_vn.dscalar.nii
#
# WorkingDirectory (HippocampalVolumeToSurfaceMapping):
#   Mapping intermediates and CIFTIs for Mesh=native and Mesh=${TargetMesh}:
#       ${Session}_mean.${Mesh}.dscalar.nii
#       ${Session}_mean_all.${Mesh}.dscalar.nii
#       ${Session}_cov.${Mesh}.dscalar.nii
#       ${Session}_cov_all.${Mesh}.dscalar.nii
#       ${Session}_goodvoxels.${Mesh}.dscalar.nii  # Only when enabled
#       ${Session}.${Mesh}.dtseries.nii
#       ${Session}_fMRI_vn.${Mesh}.dscalar.nii
#
#   Target-mesh timeseries after the smoothing step:
#       ${Session}_s${SmoothingFWHM}.${TargetMesh}.dtseries.nii
################################################ SUPPORT FUNCTIONS ##################################################
set -eu
pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    # Fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"          # Debugging functions; also sources log.shlib
source "${HCPPIPEDIR}/global/scripts/newopts.shlib" "$@"
source "${HCPPIPEDIR}/global/scripts/processingmodecheck.shlib" # Check processing mode requirements

opts_SetScriptDescription "Run hippocampal fMRISurface processing"

opts_AddMandatory '--studyfolder' 'Path' 'path' "folder containing all sessions (eg subjects)" "--path"

opts_AddMandatory '--session' 'Session' 'session (eg subject) ID' ""

opts_AddMandatory '--fmriname' 'NameOffMRI' 'string' 'fMRI run name, for example rfMRI_REST1_LR'

opts_AddOptional '--procstring' 'ProcString' 'string' 'processing suffix appended to the 4D fMRI filename; include the leading underscore' ""

opts_AddMandatory '--smoothingFWHM' 'SmoothingFWHM' 'number' 'smoothing FWHM (mm)'

opts_AddOptional '--goodvoxel' 'doGoodVoxels' 'YES OR NO' "Controls whether to do goodVoxel procedure (default = YES)" "YES"

opts_AddOptional '--factor' 'factor' 'number' "Scaling factor for eliminating high COV voxels (default = 1.5)" "1.5"

opts_AddOptional '--target_mesh' 'TargetMesh' 'string' "target mesh resolution. Values include: 512, 2k, 8k, 18k " "2k"

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set; first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

opts_ShowValues

"${HCPPIPEDIR}/show_version"

# ------------------------------------------------------------------------------
# Verify required environment variables are set
# ------------------------------------------------------------------------------

log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FSLDIR
log_Check_Env_Var CARET7DIR

HCPPIPEDIR_fMRISurf="${HCPPIPEDIR}/fMRISurface/scripts"

# ------------------------------------------------------------------------------
# Parse command-line options
# ------------------------------------------------------------------------------

log_Msg "Platform Information Follows:"
uname -a

# ------------------------------------------------------------------------------
# Set up paths
# ------------------------------------------------------------------------------

MainSessionFolder="${Path}/${Session}"
AtlasSpaceFolder="${MainSessionFolder}/MNINonLinear"
InputResultsFolder="${AtlasSpaceFolder}/Results/${NameOffMRI}"
ResultsFolder="${AtlasSpaceFolder}/Results/${NameOffMRI}"

WorkingDirectory="${ResultsFolder}/HippocampalVolumeToSurfaceMapping"
mkdir -p "${WorkingDirectory}"

VolumefMRI="${InputResultsFolder}/${NameOffMRI}${ProcString}.nii.gz"

SBRef="${InputResultsFolder}/${NameOffMRI}_SBRef.nii.gz"

HippUnfoldFolder="${AtlasSpaceFolder}/HippUnfold"

if [ ! -f "${VolumefMRI}" ]; then
    log_Err_Abort "Cannot find selected fMRI file: ${VolumefMRI}"
fi

if [ ! -f "${SBRef}" ]; then
    log_Err_Abort "Cannot find selected SBRef file: ${SBRef}"
fi


log_Msg "Selected fMRI file: ${VolumefMRI}"
log_Msg "Selected SBRef file: ${SBRef}"

# ------------------------------------------------------------------------------
# Combining ROIs into a single CIFTI time series and vn file
# ------------------------------------------------------------------------------

log_Msg "mkdir -p ${WorkingDirectory}"
log_Msg "Hippocampal Volume To Surface Mapping"


# Generate fMRI time series for each of the hippocampal structures: L hipp, R hipp, L dentate, R dentate
"${HCPPIPEDIR_fMRISurf}/HippocampalVolumeToSurfaceMapping.sh" "${ResultsFolder}" "${WorkingDirectory}" "${Session}" "${HippUnfoldFolder}" "${VolumefMRI}" "${SBRef}" "${doGoodVoxels}" "${factor}" "${TargetMesh}"

#Surface Smoothing of each hippocampal structure
"${HCPPIPEDIR_fMRISurf}/HippocampalSmoothing.sh" "${HippUnfoldFolder}" "${WorkingDirectory}" "${Session}" "${SmoothingFWHM}" "${TargetMesh}"

# Copy final timeseries and VN into the run's Results folder.
OutputBase="${ResultsFolder}/${NameOffMRI}_AtlasHipp_s${SmoothingFWHM}${ProcString}"
cp "${WorkingDirectory}/${Session}_s${SmoothingFWHM}.${TargetMesh}.dtseries.nii" "${OutputBase}.dtseries.nii"
cp "${WorkingDirectory}/${Session}_fMRI_vn.${TargetMesh}.dscalar.nii" "${ResultsFolder}/${NameOffMRI}_AtlasHipp${ProcString}_vn.dscalar.nii"

log_Msg "GenericHippocampusfMRISurfaceProcessingPipeline Completed!"

