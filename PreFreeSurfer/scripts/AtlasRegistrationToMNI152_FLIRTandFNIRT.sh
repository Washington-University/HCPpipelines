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


source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"

opts_SetScriptDescription "Tool for non-linearly registering T1w and T2w to MNI space (T1w and T2w must already be registered together)"

opts_AddMandatory '--t1' 'T1wImage' 'image' 't1w image'

opts_AddMandatory '--t1rest' 'T1wRestore' 'image' 'bias corrected t1w image'

opts_AddMandatory '--t1restbrain' 'T1wRestoreBrain' 'image' 'bias corrected brain extracted t1w image'

opts_AddMandatory '--t2' 'T2wImage' 't2w image' 'image'

opts_AddMandatory '--t2rest' 'T2wRestore' 'image' 'bias corrected t2w image'

opts_AddMandatory '--t2restbrain' 'T2wRestoreBrain' 'image' 'bias corrected, brain extracted t2w image'

opts_AddMandatory '--ref' 'Reference' 'image' 'reference image'

opts_AddMandatory '--refbrain' 'ReferenceBrain' 'image' 'reference brain image'

opts_AddMandatory '--refmask' 'ReferenceMask' 'mask' 'reference brain mask'

opts_AddMandatory '--owarp' 'OutputTransform' 'number' 'output warp'

opts_AddMandatory '--oinvwarp' 'OutputInvTransform' 'inverse' 'output inverse warp'

opts_AddMandatory '--ot1' 'OutputT1wImage' 'image' 'output t1w to MNI'

opts_AddMandatory '--ot1rest' 'OutputT1wImageRestore' 'image' 'output bias corrected t1w to MNI'

opts_AddMandatory '--ot1restbrain' 'OutputT1wImageRestoreBrain' 'image' 'output bias corrected, brain extracted t1w to MNI'

opts_AddMandatory '--ot2' 'OutputT2wImage' 'image' 'output t2w to MNI'

opts_AddMandatory '--ot2rest' 'OutputT2wImageRestore' 'image' 'output bias corrected t2w to MNI'

opts_AddMandatory '--ot2restbrain' 'OutputT2wImageRestoreBrain' 'image' 'output bias corrected, brain extracted t2w to MNI'

##optional args
opts_AddOptional '--workingdir' 'WD' 'path' 'working directory' "."

opts_AddOptional '--ref2mm' 'Reference2mm' 'image' 'reference 2mm image' "${HCPPIPEDIR_Templates}/MNI152_T1_2mm.nii.gz"

opts_AddOptional '--ref2mmmask' 'Reference2mmMask' 'mask' 'reference 2mm brain mask' "${HCPPIPEDIR_Templates}/MNI152_T1_2mm_brain_mask_dil.nii.gz"

opts_AddOptional '--fnirtconfig' 'FNIRTConfig' 'file' 'FNIRT configuration file' "${HCPPIPEDIR_Config}/T1_2_MNI152_2mm.cnf"

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
T1wRestoreBrainBasename=`remove_ext $T1wRestoreBrain`;
T1wRestoreBrainBasename=`basename $T1wRestoreBrainBasename`;

log_Msg "START: AtlasRegistration to MNI152"

verbose_echo " "
verbose_red_echo " ===> Running Atlas Registration to MNI152"
verbose_echo " "

mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/xfms/log.txt
echo "PWD = `pwd`" >> $WD/xfms/log.txt
echo "date: `date`" >> $WD/xfms/log.txt
echo " " >> $WD/xfms/log.txt

########################################## DO WORK ##########################################

# Linear then non-linear registration to MNI
verbose_echo " --> Linear then non-linear registration to MNI"
${FSLDIR}/bin/flirt -interp spline -dof 12 -in ${T1wRestoreBrain} -ref ${ReferenceBrain} -omat ${WD}/xfms/acpc2MNILinear.mat -out ${WD}/xfms/${T1wRestoreBrainBasename}_to_MNILinear

${FSLDIR}/bin/fnirt --in=${T1wRestore} --ref=${Reference2mm} --aff=${WD}/xfms/acpc2MNILinear.mat --refmask=${Reference2mmMask} --fout=${OutputTransform} --jout=${WD}/xfms/NonlinearRegJacobians.nii.gz --refout=${WD}/xfms/IntensityModulatedT1.nii.gz --iout=${WD}/xfms/2mmReg.nii.gz --logout=${WD}/xfms/NonlinearReg.txt --intout=${WD}/xfms/NonlinearIntensities.nii.gz --cout=${WD}/xfms/NonlinearReg.nii.gz --config=${FNIRTConfig}

# Input and reference spaces are the same, using 2mm reference to save time
verbose_echo " --> Computing 2mm warp"
${FSLDIR}/bin/invwarp -w ${OutputTransform} -o ${OutputInvTransform} -r ${Reference2mm}

# T1w set of warped outputs (brain/whole-head + restored/orig)
verbose_echo " --> Generarting T1w set of warped outputs"
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${T1wImage} -r ${Reference} -w ${OutputTransform} -o ${OutputT1wImage}
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${T1wRestore} -r ${Reference} -w ${OutputTransform} -o ${OutputT1wImageRestore}
${FSLDIR}/bin/applywarp --rel --interp=nn -i ${T1wRestoreBrain} -r ${Reference} -w ${OutputTransform} -o ${OutputT1wImageRestoreBrain}
${FSLDIR}/bin/fslmaths ${OutputT1wImageRestore} -mas ${OutputT1wImageRestoreBrain} ${OutputT1wImageRestoreBrain}

# T2w set of warped outputs (brain/whole-head + restored/orig)
if [ ! "${T2wImage}" = "NONE" ] ; then
  verbose_echo " --> Creating T2w set of warped outputs"
  ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${T2wImage} -r ${Reference} -w ${OutputTransform} -o ${OutputT2wImage}
  ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${T2wRestore} -r ${Reference} -w ${OutputTransform} -o ${OutputT2wImageRestore}
  ${FSLDIR}/bin/applywarp --rel --interp=nn -i ${T2wRestoreBrain} -r ${Reference} -w ${OutputTransform} -o ${OutputT2wImageRestoreBrain}
  ${FSLDIR}/bin/fslmaths ${OutputT2wImageRestore} -mas ${OutputT2wImageRestoreBrain} ${OutputT2wImageRestoreBrain}
else
  verbose_echo " ... skipping T2w processing"
fi

verbose_green_echo "---> Finished Atlas Registration to MNI152"
verbose_echo " "

log_Msg "END: AtlasRegistration to MNI152"
echo " END: `date`" >> $WD/xfms/log.txt

########################################## QA STUFF ##########################################

if [ -e $WD/xfms/qa.txt ] ; then rm -f $WD/xfms/qa.txt ; fi
echo "cd `pwd`" >> $WD/xfms/qa.txt
echo "# Check quality of alignment with MNI image" >> $WD/xfms/qa.txt
echo "fslview ${Reference} ${OutputT1wImageRestore}" >> $WD/xfms/qa.txt
echo "fslview ${Reference} ${OutputT2wImageRestore}" >> $WD/xfms/qa.txt

##############################################################################################
