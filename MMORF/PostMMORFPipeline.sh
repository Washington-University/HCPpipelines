#!/bin/bash 

set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
opts_SetScriptDescription "Run MMORF registration for multiple sessions in parallel"
opts_AddMandatory '--study-folder' 'StudyFolder' 'folder' 'Path to the study folder containing session folders'
opts_AddMandatory '--session' 'Session' 'subject ID' "(e.g. 100610)"
opts_AddMandatory '--t1-template' 'T1wTemplate' 'Image' "Path to the T1w template image"
opts_AddOptional '--hiresmesh' 'HighResMesh' 'High resolution mesh, default 164' '164'
opts_AddMandatory '--lowresmesh' 'LowResMeshes' 'Low resolution meshes delimited by @, like 32@59'
opts_AddOptional '--regname' 'RegName' 'Registration name, default MSMAll' "MSMAll"
opts_AddOptional '--regnameorig' 'RegNameOrig' 'Registration name for original, default MSMSulc' "MSMSulc"
opts_AddOptional '--inflatescale' 'InflateExtraScale' 'Additional scaling beyond linear to deal with a lowres mesh greater than 32k, default 1 (linear)' "1"
opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

opts_ShowValues

${HCPPIPEDIR}/MMORF/scripts/MMORFPostProcessingConvert.sh \
    --study-folder="${StudyFolder}" \
    --session="${Session}" \
    --t1-template="${T1wTemplate}"

${HCPPIPEDIR}/MMORF/scripts/PostMMORFConvert.sh \
    --study-folder="${StudyFolder}" \
    --subject="${Session}" \
    --high-res-mesh="${HighResMesh}" \
    --low-res-meshes="${lowResMeshes}" \
    --regname="${regName}" \
    --regnameorig="${regNameOrig}" \
    --inflatescale="${inflateExtraScale}"