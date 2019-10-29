#!/bin/bash 

# Requirements for this script
#  installed versions of: FSL
#  environment: HCPPIPEDIR, FSLDIR

# ------------------------------------------------------------------------------
#  Usage Description Function
# ------------------------------------------------------------------------------

script_name=$(basename "${0}")

Usage() {
	cat <<EOF

${script_name}: Tool for non-linearly registering T1w and T2w to MNI space (T1w and T2w must already be registered together)

Usage: ${script_name}
  [--workingdir=<working dir>]
  --t1=<t1w image>
  --t1rest=<bias corrected t1w image>
  --t1restbrain=<bias corrected, brain extracted t1w image>
  --t2=<t2w image>
  --t2rest=<bias corrected t2w image>
  --t2restbrain=<bias corrected, brain extracted t2w image>
  --ref=<reference image>
  --refbrain=<reference brain image>
  --refmask=<reference brain mask>
  [--ref2mm=<reference 2mm image>]
  [--ref2mmmask=<reference 2mm brain mask>]
  --owarp=<output warp>
  --oinvwarp=<output inverse warp>
  --ot1=<output t1w to MNI>
  --ot1rest=<output bias corrected t1w to MNI>
  --ot1restbrain=<output bias corrected, brain extracted t1w to MNI>
  --ot2=<output t2w to MNI>
  --ot2rest=<output bias corrected t2w to MNI>
  --ot2restbrain=<output bias corrected, brain extracted t2w to MNI>
  [--fnirtconfig=<FNIRT configuration file>]

EOF
}

# Allow script to return a Usage statement, before any other output or checking
if [ "$#" = "0" ]; then
    Usage
    exit 1
fi

# ------------------------------------------------------------------------------
#  Check that HCPPIPEDIR is defined and Load Function Libraries
# ------------------------------------------------------------------------------

if [ -z "${HCPPIPEDIR}" ]; then
  echo "${script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
  exit 1
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib

# ------------------------------------------------------------------------------
#  Verify required environment variables are set and log value
# ------------------------------------------------------------------------------

log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FSLDIR

################################################ SUPPORT FUNCTIONS ##################################################

# function for parsing options
getopt1() {
    sopt="$1"
    shift 1
    for fn in $@ ; do
  if [ `echo $fn | grep -- "^${sopt}=" | wc -w` -gt 0 ] ; then
      echo $fn | sed "s/^${sopt}=//"
      return 0
  fi
    done
}

defaultopt() {
    echo $1
}

################################################### OUTPUT FILES #####################################################

# Outputs (in $WD):  xfms/acpc2MNILinear.mat
#                    xfms/${T1wRestoreBrainBasename}_to_MNILinear
#                    xfms/IntensityModulatedT1.nii.gz  xfms/NonlinearRegJacobians.nii.gz
#                    xfms/IntensityModulatedT1.nii.gz  xfms/2mmReg.nii.gz
#                    xfms/NonlinearReg.txt  xfms/NonlinearIntensities.nii.gz
#                    xfms/NonlinearReg.nii.gz
# Outputs (not in $WD): ${OutputTransform} ${OutputInvTransform}
#                       ${OutputT1wImage} ${OutputT1wImageRestore}
#                       ${OutputT1wImageRestoreBrain}
#                       ${OutputT2wImage}  ${OutputT2wImageRestore}
#                       ${OutputT2wImageRestoreBrain}

################################################## OPTION PARSING #####################################################

# parse arguments
WD=`getopt1 "--workingdir" $@`  # "$1"
T1wImage=`getopt1 "--t1" $@`  # "$2"
T1wRestore=`getopt1 "--t1rest" $@`  # "$3"
T1wRestoreBrain=`getopt1 "--t1restbrain" $@`  # "$4"
T2wImage=`getopt1 "--t2" $@`  # "$5"
T2wRestore=`getopt1 "--t2rest" $@`  # "$6"
T2wRestoreBrain=`getopt1 "--t2restbrain" $@`  # "$7"
Reference=`getopt1 "--ref" $@`  # "$8"
ReferenceBrain=`getopt1 "--refbrain" $@`  # "$9"
ReferenceMask=`getopt1 "--refmask" $@`  # "${10}"
Reference2mm=`getopt1 "--ref2mm" $@`  # "${11}"
Reference2mmMask=`getopt1 "--ref2mmmask" $@`  # "${12}"
OutputTransform=`getopt1 "--owarp" $@`  # "${13}"
OutputInvTransform=`getopt1 "--oinvwarp" $@`  # "${14}"
OutputT1wImage=`getopt1 "--ot1" $@`  # "${15}"
OutputT1wImageRestore=`getopt1 "--ot1rest" $@`  # "${16}"
OutputT1wImageRestoreBrain=`getopt1 "--ot1restbrain" $@`  # "${17}"
OutputT2wImage=`getopt1 "--ot2" $@`  # "${18}"
OutputT2wImageRestore=`getopt1 "--ot2rest" $@`  # "${19}"
OutputT2wImageRestoreBrain=`getopt1 "--ot2restbrain" $@`  # "${20}"
FNIRTConfig=`getopt1 "--fnirtconfig" $@`  # "${21}"

# default parameters
WD=`defaultopt $WD .`
Reference2mm=`defaultopt $Reference2mm ${HCPPIPEDIR_Templates}/MNI152_T1_2mm.nii.gz`
Reference2mmMask=`defaultopt $Reference2mmMask ${HCPPIPEDIR_Templates}/MNI152_T1_2mm_brain_mask_dil.nii.gz`
FNIRTConfig=`defaultopt $FNIRTConfig ${HCPPIPEDIR_Config}/T1_2_MNI152_2mm.cnf`

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
