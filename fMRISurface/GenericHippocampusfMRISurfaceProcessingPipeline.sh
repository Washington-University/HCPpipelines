#!/bin/bash
set -eu
# Requirements for this script
# installed versions of: FSL, Connectome Workbench (wb_command)
# environment: HCPPIPEDIR, FSLDIR, CARET7DIR

########################################## PIPELINE OVERVIEW ##########################################

# TODO

########################################## OUTPUT DIRECTORIES ##########################################

# TODO

################################################ SUPPORT FUNCTIONS ##################################################

set -eu
pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    # Fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

#comment the line back in when done
#source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"          # Debugging functions; also sources log.shlib
source "${HCPPIPEDIR}/global/scripts/log.shlib" "$@"          # Debugging functions; also sources log.shlib

source "${HCPPIPEDIR}/global/scripts/newopts.shlib" "$@"
source "${HCPPIPEDIR}/global/scripts/processingmodecheck.shlib" # Check processing mode requirements

opts_SetScriptDescription "Run hippocampal fMRISurface processing"

opts_AddMandatory '--studyfolder' 'Path' 'path' "folder containing all subjects" "--path"

opts_AddMandatory '--subject' 'Subject' 'subject ID' ""

opts_AddMandatory '--fmriname' 'NameOffMRI' 'string' 'fMRI run name, for example rfMRI_REST1_LR'

opts_AddOptional '--procstring' 'ProcString' 'string' 'processing suffix appended to the 4D fMRI filename; include the leading underscore' ""

opts_AddMandatory '--smoothingFWHM' 'SmoothingFWHM' 'number' 'smoothing FWHM (mm)'

opts_AddOptional '--goodvoxel' 'doGoodVoxels' 'YES OR NO' "Controls whether to do goodVoxel procedure (default = YES)" "YES"

opts_AddOptional '--factor' 'factor' 'number' "Scaling factor for eliminating high COV voxels (default = 1.5)" "1.5"

opts_AddOptional '--resample_mesh' 'MeshString' 'string' 'Resample native mesh to: 512, 2k, 8k, or 18k. Use quote for multiple meshes, e.g. "512 2k 8k"' "512 2k 8k 18k"
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

MainSubjectFolder="${Path}/${Subject}"
AtlasSpaceFolder="${MainSubjectFolder}/MNINonLinear"
InputResultsFolder="${AtlasSpaceFolder}/Results/${NameOffMRI}"
ResultsFolder="${AtlasSpaceFolder}/Results/${NameOffMRI}"

WorkingDirectory="${ResultsFolder}/HippocampalVolumeToSurfaceMapping" #should 'HippocampalVolumeToSurfaceMapping' be a parameter?'
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

#Parse MeshString into a mesh array
for Mesh in ${MeshString}; do
    if [[ " 512 2k 8k 18k " != *" ${Mesh} "* ]]; then
        log_Err_Abort "Invalid mesh: ${Mesh}"
    fi
done
Meshes="native ${MeshString}"

log_Msg "Selected fMRI file: ${VolumefMRI}"
log_Msg "Selected SBRef file: ${SBRef}"

# ------------------------------------------------------------------------------
# Combining ROIs into a single CIFTI time series and vn file
# ------------------------------------------------------------------------------

log_Msg "mkdir -p ${WorkingDirectory}"
log_Msg "Hippocampal Volume To Surface Mapping"


# Generate fMRI time series for each of the hippocampal structures: L hipp, R hipp, L dentate, R dentate
"${HCPPIPEDIR_fMRISurf}/HippocampalVolumeToSurfaceMapping.sh" "${ResultsFolder}" "${Subject}" "${HippUnfoldFolder}" "${VolumefMRI}" "${SBRef}" "${doGoodVoxels}" "${factor}" "${Meshes}"

#Surface Smoothing of each hippocampal structure
"${HCPPIPEDIR_fMRISurf}/HippocampalSmoothing.sh" "${HippUnfoldFolder}" "${ResultsFolder}" "${WorkingDirectory}" "${Subject}" "${SmoothingFWHM}" "${Meshes}"

#Integration of the 4 hippocampal structures into single CIFTI timeseries and vn files
"${HCPPIPEDIR_fMRISurf}/CreateHippocampalCIFTIs.sh" "${ResultsFolder}" "${Subject}" "${NameOffMRI}" "${ProcString}" "${SmoothingFWHM}" "${Meshes}"

log_Msg "GenericHippocampusfMRISurfaceProcessingPipeline Completed!"

