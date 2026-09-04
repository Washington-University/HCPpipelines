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
opts_SetScriptDescription "Wrapper for preparing for MMORF registration"
opts_AddMandatory '--study-folder' 'StudyFolder' 'folder' 'Path to the study folder containing session folders'
opts_AddMandatory '--session' 'Session' 'subject ID' "(e.g. 100610)"
opts_AddMandatory '--t1-template' 'T1wTemplate' 'image' 'Path to the T1w template image'
opts_AddMandatory '--lowest-shell-threshold' 'Threshold' 'value' 'Threshold for bvals for filtering diffusion data to only include the lowest shell, used for dtifit - the nominal shell value plus 200 will usually work'


opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

opts_ShowValues

log_Check_Env_Var FSLDIR


T1wImage="T1w"
T1wFolderName="T1w"
T2wImage="T2w"
T2wFolderName="T2w"
AtlasSpaceFolderName="HCPMultiModalNonLinear"

T1wFolder="${StudyFolder}/${Session}/${T1wFolderName}"
AtlasSpaceFolder="${StudyFolder}/${Session}/${AtlasSpaceFolderName}"
Diffusion="${T1wFolder}/Diffusion"

echo "Launching Pre MMORF registration for session ${Session}"


brainmask_fs=${T1wFolder}/brainmask_fs.nii.gz
T1wRestore=${T1wFolder}/${T1wImage}_acpc_dc_restore



T1wRestoreBasename=`remove_ext $T1wRestore`;
T1wRestoreBasename=`basename $T1wRestoreBasename`;
#T1wRestoreBrainBasename=`remove_ext $T1wRestoreBrain`;
#T1wRestoreBrainBasename=`basename $T1wRestoreBrainBasename`;


mkdir -p "$AtlasSpaceFolder"
mkdir -p "$AtlasSpaceFolder/xfms"
mkdir -p "$AtlasSpaceFolder/Diffusion"

# Record the input options in a log file
echo "$0 $@" >> "$AtlasSpaceFolder/xfms/log.txt"
echo "Pwd = `pwd`" >> "$AtlasSpaceFolder/xfms/log.txt"
echo "date: `date`" >> "$AtlasSpaceFolder/xfms/log.txt"
echo " " >> "$AtlasSpaceFolder/xfms/log.txt"

${HCPPIPEDIR}/MMORF/scripts/MMORFPreprossDiffusion.sh "${Diffusion}" "${AtlasSpaceFolder}/TMP" "${Threshold}"

#transform brain mask to fit with the MMORF alogrithm
${FSLDIR}/bin/fslmaths ${brainmask_fs} -mul 7 -add 1 -div 8 "${AtlasSpaceFolder}/TMP/brainmask_fs_transformed.nii.gz"

# Linear registration to MMORF
verbose_echo " --> Linear registration to MMORF"
${FSLDIR}/bin/flirt -interp spline -in ${T1wRestore} -ref ${T1wTemplate} -omat "${AtlasSpaceFolder}/xfms/acpc2MMORFLinear.mat" -out "${AtlasSpaceFolder}/xfms/${T1wRestoreBasename}_to_MMORFLinear"