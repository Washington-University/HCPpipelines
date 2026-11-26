#!/bin/bash
set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

# Load function libraries
source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"    # Debugging functions; also sources log.shlib
source "${HCPPIPEDIR}/global/scripts/newopts.shlib" "$@"  # Command line option functions


# Perform the steps of the HCP Diffusion Preprocessing Pipeline
opts_SetScriptDescription "Prepare the data to run Tractography"

opts_AddMandatory '--path' 'StudyFolder' 'Path' "path to session's data folder"
opts_AddMandatory '--subject' 'Subject' 'subject ID' ""
opts_AddMandatory '--diffresmesh' 'DiffResMesh' 'number' 'diffusion res mesh number'
opts_AddOptional '--bpxdirs' 'BedpostXFolders' 'folder@folder' "names of folders containing fiber estimations, default Diffusion.bedpostX" "Diffusion.bedpostX"
opts_AddMandatory '--regname' 'RegName' 'Name of Registration' 'RegName such as MSMAll'
opts_AddMandatory '--volume-space' 'volspace' 'string' "which volume space to generate the tractography outputs in, must be T1w, or MMORFNonLinear"
opts_AddOptional '--whimmask' 'WhimMask' 'path' "binary mask of voxels included in the WHIM orientations"
opts_AddOptional '--groupname' 'GroupName' 'string' "Average Group Name"



opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

opts_ShowValues

"$HCPPIPEDIR"/show_version

# ------------------------------------------------------------------------------
#  Verify required environment variables are set and log value
# ------------------------------------------------------------------------------

log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FSLDIR
log_Check_Env_Var CARET7DIR

log_Msg "Platform Information Follows: "
uname -a

if [[ "$volspace" != "T1w" && "$volspace" != "MMORFNonLinear" ]]; then
    log_Err_Abort "--volume-space must be T1w or MMORFNonLinear"
fi

if [[ "$volspace" == "T1w" && -n "$WhimMask" ]]; then
    log_Err_Abort "--whimmask cannot be used when --volume-space is T1w, because rigid alignment is not sufficient for a meaningful human cross-subject white matter space"
fi

if [[ "$volspace" == "MMORFNonLinear" && -z "$WhimMask" ]]; then
    log_Err_Abort "--whimmask must be provided when --volume-space is MMORFNonLinear, so that WHIM can allow combining data across subjects"
fi


# Setup PATHS
PipelineScripts=${HCPPIPEDIR_dMRITract}

WholeBrainTrajectoryLabels=${HCPPIPEDIR_Config}/WholeBrainFreeSurferTrajectoryLabelTableLut.txt
LeftCerebralTrajectoryLabels=${HCPPIPEDIR_Config}/LeftCerebralFreeSurferTrajectoryLabelTableLut.txt 
RightCerebralTrajectoryLabels=${HCPPIPEDIR_Config}/RightCerebralFreeSurferTrajectoryLabelTableLut.txt
WholeBrainSubcorticalLabels=${HCPPIPEDIR_Config}/WholeBrainSubcorticalFreeSurferTrajectoryLabelTableLut.txt
LeftSubcorticalLabels=${HCPPIPEDIR_Config}/LeftSubcorticalFreeSurferTrajectoryLabelTableLut.txt 
RightSubcorticalLabels=${HCPPIPEDIR_Config}/RightSubcorticalFreeSurferTrajectoryLabelTableLut.txt
WholeBrainWhiteLabels=${HCPPIPEDIR_Config}/WholeBrainWhiteFreeSurferTrajectoryLabelTableLut.txt
FreeSurferLabels=${HCPPIPEDIR_Config}/FreeSurferAllLut.txt


T1wDiffusionFolder="${StudyFolder}/${Subject}/T1w/Diffusion"
DiffusionResolution=`${FSLDIR}/bin/fslval ${T1wDiffusionFolder}/data pixdim1`
DiffusionResolution=`printf "%0.2f" ${DiffusionResolution}`

log_Msg "MakeTrajectorySpace"


${PipelineScripts}/MakeTrajectorySpace.sh \
    --path="$StudyFolder" --subject="$Subject" \
    --wholebrainlabels="$WholeBrainTrajectoryLabels" \
    --volume-space="${volspace}" \
    --leftcerebrallabels="$LeftCerebralTrajectoryLabels" \
    --rightcerebrallabels="$RightCerebralTrajectoryLabels" \
    --wholebrainsubcorticallabels="$WholeBrainSubcorticalLabels" \
    --leftsubcorticallabels="$LeftSubcorticalLabels" \
    --rightsubcorticallabels="$RightSubcorticalLabels" \
    --wholebrainwhitelabels="$WholeBrainWhiteLabels" \
    --diffresol="${DiffusionResolution}" \
    --freesurferlabels="${FreeSurferLabels}" \
    --whimmask="${WhimMask}"

log_Msg "MakeWorkbenchUODFs"

${PipelineScripts}/MakeWorkbenchUODFs.sh --path="${StudyFolder}" --subject="${Subject}" --volume-space="${volspace}" --diffresol="${DiffusionResolution}" --bpxfoldername="${BedpostXFolders}" --whimmask="${WhimMask}"

log_Msg "MakeSeeds"
${PipelineScripts}/MakeSeeds.sh --path="${StudyFolder}" --subject="${Subject}" --volume-space="${volspace}" --diffresmesh="${DiffResMesh}" --diffresol="${DiffusionResolution}" --regname="${RegName}" --whimmask="${WhimMask}" --groupname="$GroupName"

log_Msg "Completed"

