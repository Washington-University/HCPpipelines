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

#Helper function here to correct for temp_dir for mountpoint. This has to be done. After experimenting, CHPC only allows read+write in using temp directory mounts.
#No short cut can be exploted here.
emit() {
    local line="$1"
    if [[ "$line" == ${mountPoint}/* ]]; then
        printf '%s\n' "\$temp_dir/${line#${mountPoint}/}"
    else
        printf '%s\n' "$line"
    fi
}


source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source "${HCPPIPEDIR}/global/scripts/newopts.shlib" "$@"

opts_SetScriptDescription "Tool for non-linearly registering DTI, T1w, T2w to MMORF space. Need to have T1w, T2w in the same space"


#Used
opts_AddMandatory '--t1rest' 'T1wRestore' 'image' 'bias corrected t1w image'

#Used
opts_AddMandatory '--brainmask_fs' 'brainmask_fs' 'mask' 'Brainmask for t1w or t2w image'

#Used
opts_AddMandatory '--ref' 'Reference' 'image' 'reference image'


#Used
opts_AddMandatory "--Diffusion" "Diffusion" "image" "Diffusion including bvecs, bvals, and data.nii.gz"


#Used
opts_AddOptional '--workingdir' 'WD' 'path' 'working directory' "."




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

mkdir -p $WD
mkdir -p $WD/xfms
mkdir -p $WD/Diffusion

# Record the input options in a log file
echo "$0 $@" >> $WD/xfms/log.txt
echo "PWD = `pwd`" >> $WD/xfms/log.txt
echo "date: `date`" >> $WD/xfms/log.txt
echo " " >> $WD/xfms/log.txt

########################################## DO WORK ##########################################


##I should filter it here.
${HCPPIPEDIR}/MMORF/scripts/MMORFPreprossDiffusion.sh "${Diffusion}" "${WD}/TMP" "${FSLDIR}"




#transform brain mask to fit with the MMORF alogrithm
${FSLDIR}/bin/fslmaths ${brainmask_fs} -mul 7 -add 1 -div 8 "${WD}/TMP/brainmask_fs_transformed.nii.gz"

# Linear then non-linear registration to MMORF
verbose_echo " --> Linear then non-linear registration to MMORF"
${FSLDIR}/bin/flirt -interp spline -in ${T1wRestore} -ref ${Reference} -omat "${WD}/xfms/acpc2MMORFLinear.mat" -out "${WD}/xfms/${T1wRestoreBasename}_to_MMORFLinear"