#!/bin/bash 

# Requirements for this script
#  installed versions of: FSL
#  environment: HCPPIPEDIR, FSLDIR

# ------------------------------------------------------------------------------
#  Usage Description Function
# ------------------------------------------------------------------------------

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
opts_AddMandatory '--study-folder' 'StudyFolder' 'Path to the study folder containing session folders' ""
opts_AddMandatory '--session' 'Session' 'Subject ID' ""
opts_AddMandatory '--t1-template' 'T1wTemplate' 'Path to the T1w template image' ""
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
    T1wFolder_T2wImageWithPath_acpc_dc="${T1wFolder}/${T2wImage}_acpc_dc"
    Diffusion="${T1wFolder}/Diffusion"


    echo "Launching MMORF registration for session ${Session}"

        ${HCPPIPEDIR}/MMORF/scripts/MMORFPostProcessing.sh \
          --workingdir="${AtlasSpaceFolder}" \
          --t1="${T1wFolder}/${T1wImage}_acpc_dc" \
          --t1rest="${T1wFolder}/${T1wImage}_acpc_dc_restore" \
          --t1restbrain="${T1wFolder}/${T1wImage}_acpc_dc_restore_brain" \
          --t2="${T1wFolder_T2wImageWithPath_acpc_dc}" \
          --t2rest="${T1wFolder}/${T2wImage}_acpc_dc_restore" \
          --t2restbrain="${T1wFolder}/${T2wImage}_acpc_dc_restore_brain" \
          --ref="${T1wTemplate}" \
          --Diffusion="${Diffusion}" \
          --owarp="${AtlasSpaceFolder}/xfms/acpc_dc2mmorf.nii.gz" \
          --oinvwarp="${AtlasSpaceFolder}/xfms/mmorf2acpc_dc.nii.gz" \
          --ot1="${AtlasSpaceFolder}/${T1wImage}" \
          --ot1rest="${AtlasSpaceFolder}/${T1wImage}_restore" \
          --ot1restbrain="${AtlasSpaceFolder}/${T1wImage}_restore_brain" \
          --ot2="${AtlasSpaceFolder}/${T2wImage}" \
          --ot2rest="${AtlasSpaceFolder}/${T2wImage}_restore" \
          --ot2restbrain="${AtlasSpaceFolder}/${T2wImage}_restore_brain" \