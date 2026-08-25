#!/bin/bash

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
source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"          # Debugging functions; also sources log.shlib
source "${HCPPIPEDIR}/global/scripts/newopts.shlib" "$@"
source "${HCPPIPEDIR}/global/scripts/processingmodecheck.shlib" # Check processing mode requirements

opts_SetScriptDescription "Run hippocampal fMRISurface processing"

opts_AddMandatory '--studyfolder' 'Path' 'path' "folder containing all subjects" "--path"

opts_AddMandatory '--subject' 'Subject' 'subject ID' ""

opts_AddMandatory '--fmriname' 'NameOffMRI' 'string' 'fMRI run name, for example rfMRI_REST1_LR'

opts_AddOptional '--procstring' 'ProcString' 'string' 'processing suffix appended to the 4D fMRI filename; include the leading underscore' ""

opts_AddMandatory '--smoothingFWHM' 'SmoothingFWHM' 'number' 'smoothing FWHM (mm)'

opts_AddOptional '--fmri-qc' 'QCMode' 'YES OR NO OR ONLY' "Controls whether to generate a QC scene and snapshots (default=YES). ONLY executes just the QC script." "YES"

opts_AddOptional '--output-directory' 'OutputDirectory' 'path' 'Directory where pipeline outputs will be written' ""

opts_AddOptional '--goodvoxel' 'doGoodVoxels' 'YES OR NO' "Controls whether to do goodVoxel procedure (default = YES)" "YES"

opts_AddOptional '--factor' 'factor' 'number' "Scaling factor for eliminating high COV voxels"

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

QCMode="$(echo "${QCMode}" | tr '[:upper:]' '[:lower:]')"

doProcessing=1
doQC=1

case "${QCMode}" in
    yes)
        ;;
    no)
        doQC=0
        ;;
    only)
        doProcessing=0
        log_Warn "Only generating fMRI QC scene and snapshots from existing data"
        ;;
    *)
        log_Err_Abort "Unrecognized value '${QCMode}' for --fmri-qc; use YES, NO, or ONLY"
        ;;
esac


# ------------------------------------------------------------------------------
# Set up paths
# ------------------------------------------------------------------------------

PipelineScripts="${HCPPIPEDIR_fMRISurf}"

MainSubjectFolder="${Path}/${Subject}"
AtlasSpaceFolder="${MainSubjectFolder}/MNINonLinear"
InputResultsFolder="${AtlasSpaceFolder}/Results/${NameOffMRI}"
ResultsFolderName="Results"

if [ -n "${OutputDirectory}" ]; then
    ResultsFolder="${OutputDirectory}/${Subject}/${NameOffMRI}"
else
    ResultsFolder="${AtlasSpaceFolder}/${ResultsFolderName}/${NameOffMRI}"
fi

WorkingDirectory="${ResultsFolder}/tmp"

mkdir -p "${WorkingDirectory}"

VolumefMRI="${InputResultsFolder}/${NameOffMRI}${ProcString}"

SBRef="${InputResultsFolder}/${NameOffMRI}_SBRef.nii.gz"

HippUnfoldFolder="${AtlasSpaceFolder}/HippUnfold"

if [ ! -f "${VolumefMRI}.nii.gz" ]; then
    log_Err_Abort "Cannot find selected fMRI file: ${VolumefMRI}.nii.gz"
fi

if [ ! -f "${SBRef}" ]; then
    log_Err_Abort "Cannot find selected SBRef file: ${SBRef}"
fi

log_Msg "Selected fMRI file: ${VolumefMRI}.nii.gz"
log_Msg "Selected SBRef file: ${SBRef}"

# ------------------------------------------------------------------------------
# Generate fMRI time series within ROIs
# ------------------------------------------------------------------------------

if ((doProcessing)); then

    # Make fMRI ribbon
    log_Msg "Make fMRI Ribbon"
    log_Msg "mkdir -p ${WorkingDirectory}"

    log_Msg "Hippocampal Volume To Surface Mapping"
    "${PipelineScripts}/HippocampalVolumeToSurfaceMapping.sh" \
            "${WorkingDirectory}" \
            "${Subject}" \
            "${HippUnfoldFolder}" \
            "${VolumefMRI}" \
            "${SBRef}" \
            "${doGoodVoxels}" \
            "${factor}"

#Surface Smoothing
 # ------------------------------------------------------------------------------
# Hippocampal Surface Smoothing
# ------------------------------------------------------------------------------

    log_Msg "Hippocampal Surface Smoothing"

    Sigma=`echo "$SmoothingFWHM / (2 * sqrt(2 * l(2)))" | bc -l`

    Meshes=(native 512 2k 8k 18k)
    Structures=(hipp dentate)

    for Mesh in "${Meshes[@]}"; do
        for Structure in "${Structures[@]}"; do
            for Hemisphere in L R; do
                "${CARET7DIR}/wb_command" -metric-smoothing \
                    "${HippUnfoldFolder}/${Mesh}/${Subject}.${Hemisphere}.${Structure}_midthickness.${Mesh}.surf.gii" \
                    "${WorkingDirectory}/${Subject}.${Hemisphere}.${Structure}_fMRI.${Mesh}.func.gii" \
                    "${Sigma}" \
                    "${WorkingDirectory}/${Subject}.${Hemisphere}.${Structure}_fMRI_s${SmoothingFWHM}.${Mesh}.func.gii" \
                    -roi "${WorkingDirectory}/${Subject}.${Hemisphere}.${Structure}_ones.${Mesh}.func.gii"
            done
        done
    done
# ------------------------------------------------------------------------------
# Combining ROIs into a single CIFTI file
# ------------------------------------------------------------------------------


    for Mesh in ${Meshes[@]}; do
        "${CARET7DIR}/wb_command" -cifti-create-dense-timeseries \
            "${ResultsFolder}/${NameOffMRI}_AtlasHipp_${ProcString}.${Mesh}.dtseries.nii" \
            -metric HIPPOCAMPUS_LEFT "${WorkingDirectory}/${Subject}.L.hipp_fMRI_s${SmoothingFWHM}.${Mesh}.func.gii" \
                -roi "${WorkingDirectory}/${Subject}.L.hipp_ones.${Mesh}.func.gii" \
            -metric HIPPOCAMPUS_RIGHT "${WorkingDirectory}/${Subject}.R.hipp_fMRI_s${SmoothingFWHM}.${Mesh}.func.gii" \
                -roi "${WorkingDirectory}/${Subject}.R.hipp_ones.${Mesh}.func.gii" \
            -metric HIPPOCAMPUS_DENTATE_LEFT "${WorkingDirectory}/${Subject}.L.dentate_fMRI_s${SmoothingFWHM}.${Mesh}.func.gii" \
                -roi "${WorkingDirectory}/${Subject}.L.dentate_ones.${Mesh}.func.gii" \
            -metric HIPPOCAMPUS_DENTATE_RIGHT "${WorkingDirectory}/${Subject}.R.dentate_fMRI_s${SmoothingFWHM}.${Mesh}.func.gii" \
                -roi "${WorkingDirectory}/${Subject}.R.dentate_ones.${Mesh}.func.gii"

            log_Msg "Generated fMRI time series Cifti file: "${ResultsFolder}/${Subject}.${NameOffMRI}"_AtlasHipp_${ProcString}.${Mesh}.dtseries.nii"
    done
fi

#Uncomment if want to remove the subfoler with intermediate files
#rm -rf "${WorkingDirectory}"

# if ((doQC)); then
#     log_Msg "Generating fMRI QC scene and snapshots"
#     "${PipelineScripts}/GenerateFMRIScenes.sh" \
#         --study-folder="${Path}" \
#         --subject="${Subject}" \
#         --fmriname="${NameOffMRI}${ProcString}" \
#         --output-folder="${ResultsFolder}/fMRIQC"
# fi

log_Msg "Completed!"