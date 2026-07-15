#!/bin/bash 
set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
opts_SetScriptDescription "Run MMORF registration for multiple sessions in parallel"
opts_AddMandatory '--study-folder' 'StudyFolder' 'folder' 'Path to the study folder containing session folders'
opts_AddMandatory '--subject' 'Session' 'subject ID' "(e.g. 100610)"
opts_AddMandatory '--t1-template' 'T1wTemplate' 'image' 'Path to the T1w template image'

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

opts_ShowValues

T1wImage="T1w"
T1wFolderName="T1w"
T2wImage="T2w"
T2wFolderName="T2w"
AtlasSpaceFolderName="MMORFNonLinear"

T1wFolder="${StudyFolder}/${Session}/${T1wFolderName}"
AtlasSpaceFolder="${StudyFolder}/${Session}/${AtlasSpaceFolderName}"
Diffusion="${T1wFolder}/Diffusion"

echo "Launching Pre MMORF registration for session ${Session}"


${HCPPIPEDIR}/MMORF/scripts/PreMMORFFilePrep.sh \
    --workingdir="${AtlasSpaceFolder}" \
    --t1rest="${T1wFolder}/${T1wImage}_acpc_dc_restore" \
    --brainmask_fs="${T1wFolder}/brainmask_fs.nii.gz" \
    --ref="${T1wTemplate}" \
    --diffusion="${Diffusion}" \
