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

opts_AddMandatory '--t1' 'T1wImage' 'image' 't1w image'

opts_AddMandatory '--t1rest' 'T1wRestore' 'image' 'bias corrected t1w image'

opts_AddMandatory '--t1restbrain' 'T1wRestoreBrain' 'image' 'bias corrected brain extracted t1w image'

opts_AddMandatory '--t2' 'T2wImage' 't2w image' 't2w image'

opts_AddMandatory '--t2rest' 'T2wRestore' 'image' 'bias corrected t2w image'

opts_AddMandatory '--t2restbrain' 'T2wRestoreBrain' 'image' 'bias corrected, brain extracted t2w image'

opts_AddMandatory '--brainmask_fs' 'brainmask_fs' 'mask' 'Brainmask for t1w or t2w image'

opts_AddMandatory '--ref' 'Reference' 'image' 'reference image'

#opts_AddMandatory '--refbrain' 'ReferenceBrain' 'image' 'reference brain image'

opts_AddMandatory '--ref2' 'Reference2' 'image' 'reference image 2'

#opts_AddMandatory '--ref2brain' 'Reference2Brain' 'image' 'reference image brain 2'

opts_AddMandatory '--refmask' 'ReferenceMask' 'mask' 'reference brain mask'

opts_AddMandatory "--Diffusion" "Diffusion" "image" "Diffusion including bvecs, bvals, and data.nii.gz"

opts_AddMandatory "--DTImask" "DTImask" "image" "Mask for DTI"


opts_AddMandatory '--DTIref' 'DTIref' 'mask' 'reference for DTI'


opts_AddMandatory '--DTIrefmask' 'DTIrefMask' 'mask' 'reference brain mask for DTI'

opts_AddMandatory '--owarp' 'OutputTransform' 'number' 'output warp'

opts_AddMandatory '--oinvwarp' 'OutputInvTransform' 'inverse' 'output inverse warp'

opts_AddMandatory '--ot1' 'OutputT1wImage' 'image' 'output t1w to MNI'

opts_AddMandatory '--ot1rest' 'OutputT1wImageRestore' 'image' 'output bias corrected t1w to MNI'

opts_AddMandatory '--ot1restbrain' 'OutputT1wImageRestoreBrain' 'image' 'output bias corrected, brain extracted t1w to MNI'

opts_AddMandatory '--ot2' 'OutputT2wImage' 'image' 'output t2w to MNI'

opts_AddMandatory '--ot2rest' 'OutputT2wImageRestore' 'image' 'output bias corrected t2w to MNI'

opts_AddMandatory '--ot2restbrain' 'OutputT2wImageRestoreBrain' 'image' 'output bias corrected, brain extracted t2w to MNI'

opts_AddMandatory '--runlocally' 'runlocally' 'bool' 'If there is local GPU and is powerful enough'



##optional args
opts_AddOptional '--ref1mm' 'Reference1mm' 'image' 'reference 1mm image' "${HCPPIPEDIR_Templates}/MMORF_T1_1mm.nii.gz"

opts_AddOptional '--workingdir' 'WD' 'path' 'working directory' "."

opts_AddOptional '--mountPoint' 'mountPoint' 'mount point for CHPC' ""

opts_AddOptional '--Host' 'Host' 'Host for CHPC access' ""

opts_AddOptional '--CHPCHeader' 'CHPCHeader' 'The header to generate the .sh file' ""

opts_AddOptional '--LocalHost' 'LocalHost' 'The name of the local machine we are mounting to, make sure sshfs is set up.' ""

opts_AddOptional "--ClusterHomeDirectory" "ClusterHomeDirectory" "The directory of Cluster Home" ""


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