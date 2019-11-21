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

${script_name}: Tool for bias field correction based on T1w image only

Usage: ${script_name}
  --workingdir=<working directory> 
  --T1im=<input T1 image> 
  [--oT1im=<output T1 image>] 
  [--oT1brain=<output T1 brain>] 
  [--bfsigma=<input T1 image>]

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

# Output images and files (in $WD):
# T1.nii.gz                         T1_fast_bias_vol2.nii.gz          T1_initfast2_brain_mask2.nii.gz
# T1_biascorr.nii.gz                T1_fast_bias_vol32.nii.gz         T1_initfast2_maskedrestore.nii.gz
# T1_biascorr_brain.nii.gz          T1_fast_restore.nii.gz            T1_initfast2_restore.nii.gz
# T1_biascorr_brain_mask.nii.gz     T1_fast_seg.nii.gz                lesionmask.nii.gz
# T1_fast_bias.nii.gz               T1_fast_totbias.nii.gz            lesionmaskinv.nii.gz
# T1_fast_bias_idxmask.nii.gz       T1_initfast2_brain.nii.gz         log.txt
# T1_fast_bias_init.nii.gz          T1_initfast2_brain_mask.nii.gz

################################################## OPTION PARSING #####################################################

# parse arguments
WD=`getopt1 "--workingdir" $@`  
T1wImage=`getopt1 "--T1im" $@`  
T1wBrain=`getopt1 "--T1brain" $@`  
oBias=`getopt1 "--obias" $@`  
oT1wImage=`getopt1 "--oT1im" $@`  
oT1wBrain=`getopt1 "--oT1brain" $@`  
BiasFieldSmoothingSigma=`getopt1 "--bfsigma" $@`

# A default value of 20 for bias smoothing sigma is the recommended default by FSL 
BiasFieldSmoothingSigma=`defaultopt $BiasFieldSmoothingSigma 20` 
WDir="$WD.anat"

log_Msg " START: T1wBiasFieldCorrection"

verbose_echo "  "
verbose_red_echo " ===> Running T1w Bias Field Correction"
verbose_echo " "

mkdir -p $WDir

# Record the input options in a log file
echo "$0 $@" >> $WDir/log.txt
echo "PWD = `pwd`" >> $WDir/log.txt
echo "date: `date`" >> $WDir/log.txt
echo " " >> $WDir/log.txt

########################################## DO WORK ##########################################

# Compute T1w Bias Normalization using fsl_anat function

${FSLDIR}/bin/fsl_anat -i $T1wImage -o $WD --noreorient --clobber --nocrop --noreg --nononlinreg --noseg --nosubcortseg -s ${BiasFieldSmoothingSigma} --nocleanup

# Use existing brain mask if one is provided

if [ ! -z ${T1wBrain} ] ; then
  ${FSLDIR}/bin/fslmaths ${WDir}/T1_biascorr -mas ${T1wBrain} ${WDir}/T1_biascorr_brain  
  verbose_echo " --> masked T1_biascorr.nii.gz using ${T1wBrain}"
fi

# Copy data out if output targets provided

if [ ! -z ${oT1wImage} ] ; then 
  ${FSLDIR}/bin/imcp ${WDir}/T1_biascorr ${oT1wImage}
  verbose_echo " --> Copied T1_biascorr.nii.gz to ${oT1wImage}.nii.gz"
fi

if [ ! -z ${oT1wBrain} ] ; then
  ${FSLDIR}/bin/imcp ${WDir}/T1_biascorr_brain ${oT1wBrain}
  verbose_echo " --> Copied T1_biascorr_brain.nii.gz to ${oT1wBrain}.nii.gz"
fi 

if [ ! -z ${oBias} ] ; then
  ${FSLDIR}/bin/imcp ${WDir}/T1_fast_bias ${oBias}
  verbose_echo " --> Copied T1_fast_bias.nii.gz to ${oBias}.nii.gz"
fi

verbose_green_echo "---> Finished T1w Bias Field Correction"
verbose_echo " "

log_Msg " END: T1w BiasFieldCorrection"
echo " END: `date`" >> $WDir/log.txt

########################################## QA STUFF ##########################################
if [ -e $WDir/qa.txt ] ; then rm -f $WDir/qa.txt ; fi
echo "cd `pwd`" >> $WDir/qa.txt
echo "# Look at the quality of the bias corrected output (T1w is brain only)" >> $WDir/qa.txt
echo "fslview $WDir/T1_biascorr_brain.nii.gz" >> $WDir/qa.txt

##############################################################################################

