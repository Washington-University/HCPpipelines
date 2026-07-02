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

#Helper function here to correct for temp_dir for mountpoint. This has to be done. After experimenting, CHPC only allows read+write in using temp directory mounts.
#No short cut can be exploted here.

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



# ==========================
# Loop over sessions
# ==========================

    T1wFolder="${StudyFolder}/${Session}/${T1wFolderName}"
    AtlasSpaceFolder="${StudyFolder}/${Session}/${AtlasSpaceFolderName}"
    Diffusion="${T1wFolder}/Diffusion"

    echo "Launching MMORF registration for session ${Session}"


${HCPPIPEDIR}/MMORF/scripts/PreMMORFFilePrepV1.sh \
        --workingdir="${AtlasSpaceFolder}" \
        --t1rest="${T1wFolder}/${T1wImage}_acpc_dc_restore" \
        --brainmask_fs="${T1wFolder}/brainmask_fs.nii.gz" \
        --ref="${T1wTemplate}" \
        --Diffusion="${Diffusion}" \
