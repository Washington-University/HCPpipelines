#!/bin/bash 
set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi


source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source "${HCPPIPEDIR}/global/scripts/newopts.shlib" "$@"

opts_SetScriptDescription "Tool for non-linearly registering DTI, T1w, T2w to MMORF space. Need to have T1w, T2w in the same space"


opts_AddMandatory '--t1rest' 'T1wRestore' 'image' 'bias corrected t1w image'
opts_AddMandatory '--brainmask_fs' 'brainmask_fs' 'mask' 'Brainmask for t1w or t2w image'
opts_AddMandatory '--ref' 'Reference' 'image' 'reference image'
opts_AddMandatory "--diffusion" "Diffusion" "image" "Diffusion including bvecs, bvals, and data.nii.gz"
opts_AddMandatory '--outputfolder' 'Output' 'path' 'target folder for output'

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues


log_Check_Env_Var FSLDIR

T1wRestoreBasename=`remove_ext $T1wRestore`;
T1wRestoreBasename=`basename $T1wRestoreBasename`;
#T1wRestoreBrainBasename=`remove_ext $T1wRestoreBrain`;
#T1wRestoreBrainBasename=`basename $T1wRestoreBrainBasename`;

log_Msg "START: AtlasRegistration to MNMORF"

verbose_echo " "
verbose_red_echo " ===> Running Atlas Registration to MMORF"
verbose_echo " "

mkdir -p $Output
mkdir -p $Output/xfms
mkdir -p $Output/Diffusion

# Record the input options in a log file
echo "$0 $@" >> $Output/xfms/log.txt
echo "POutput = `pOutput`" >> $Output/xfms/log.txt
echo "date: `date`" >> $Output/xfms/log.txt
echo " " >> $Output/xfms/log.txt

########################################## DO WORK ##########################################


##I should filter it here.
${HCPPIPEDIR}/MMORF/scripts/MMORFPreprossDiffusion.sh "${Diffusion}" "${Output}/TMP" "${FSLDIR}"




#transform brain mask to fit with the MMORF alogrithm
${FSLDIR}/bin/fslmaths ${brainmask_fs} -mul 7 -add 1 -div 8 "${Output}/TMP/brainmask_fs_transformed.nii.gz"

# Linear then non-linear registration to MMORF
verbose_echo " --> Linear then non-linear registration to MMORF"
${FSLDIR}/bin/flirt -interp spline -in ${T1wRestore} -ref ${Reference} -omat "${Output}/xfms/acpc2MMORFLinear.mat" -out "${Output}/xfms/${T1wRestoreBasename}_to_MMORFLinear"