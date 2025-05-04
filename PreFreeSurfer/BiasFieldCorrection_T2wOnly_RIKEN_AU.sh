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

${script_name}: Tool for bias field correction based on T2w image only

Usage: ${script_name}
  --workingdir=<working directory> 
  --T2im=<input T2 image> 
  [--oT2im=<output T2 image>] 
  [--oT2brain=<output T2 brain>] 
  [--bfsigma=<input T2 image>]
  [--strongbias=<TRUE or NONE (default)>]
  
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
# T2.nii.gz                         T2_fast_bias_vol2.nii.gz          T2_initfast2_brain_mask2.nii.gz
# T2_biascorr.nii.gz                T2_fast_bias_vol32.nii.gz         T2_initfast2_maskedrestore.nii.gz
# T2_biascorr_brain.nii.gz          T2_fast_restore.nii.gz            T2_initfast2_restore.nii.gz
# T2_biascorr_brain_mask.nii.gz     T2_fast_seg.nii.gz                lesionmask.nii.gz
# T2_fast_bias.nii.gz               T2_fast_totbias.nii.gz            lesionmaskinv.nii.gz
# T2_fast_bias_idxmask.nii.gz       T2_initfast2_brain.nii.gz         log.txt
# T2_fast_bias_init.nii.gz          T2_initfast2_brain_mask.nii.gz

################################################## OPTION PARSING #####################################################

# parse arguments
WD=`getopt1 "--workingdir" $@`  
T1wImage=`getopt1 "--T2im" $@`  
T2wBrain=`getopt1 "--T2brain" $@`  
oBias=`getopt1 "--obias" $@`  
oT2wImage=`getopt1 "--oT2im" $@`  
oT2wBrain=`getopt1 "--oT2brain" $@`  
BiasFieldSmoothingSigma=`getopt1 "--bfsigma" $@`
StrongBias=`getopt1 "--strongbias" $@`
if [[ $StrongBias = TRUE ]] ; then
	StrongBiasFlag="--strongbias"
else
	StrongBias=NONE
	StrongBiasFlag=""
fi

# A default value of 20 for bias smoothing sigma is the recommended default by FSL 
BiasFieldSmoothingSigma=`defaultopt $BiasFieldSmoothingSigma 20` 
WDir="$WD.anat"

log_Msg " START: T2wBiasFieldCorrection"

verbose_echo "  "
verbose_red_echo " ===> Running T2w Bias Field Correction"
verbose_echo " "

log_Msg " StrongBias: $StrongBias"
mkdir -p $WDir

# Record the input options in a log file
echo "$0 $@" >> $WDir/log.txt
echo "PWD = `pwd`" >> $WDir/log.txt
echo "date: `date`" >> $WDir/log.txt
echo " " >> $WDir/log.txt

########################################## DO WORK ##########################################

# Compute T1w Bias Normalization using fsl_anat function
fslmaths $T2wBrain -abs ${T2wBrain}_abs # TH - avoid error of Fasf if included negative values (e.g. due to spline interpolation)

#${FSLDIR}/bin/fsl_anat -i $T1wImage -o $WD --noreorient --clobber --nocrop --noreg --nononlinreg --noseg --nosubcortseg -s ${BiasFieldSmoothingSigma} --nocleanup $StrongBiasFlag
${FSLDIR}/bin/fsl_anat -i ${T2wBrain}_abs -o $WD --nobet --noreorient --clobber --nocrop --noreg --nononlinreg --noseg --nosubcortseg -s ${BiasFieldSmoothingSigma} --nocleanup $StrongBiasFlag -t T2

# Use existing brain mask if one is provided

if [ ! -z ${T2wBrain} ] ; then
  ${FSLDIR}/bin/fslmaths ${WDir}/T2_biascorr -mas ${T2wBrain} ${WDir}/T2_biascorr_brain  
  verbose_echo " --> masked T2_biascorr.nii.gz using ${T2wBrain}"
fi

# Copy data out if output targets provided

if [ ! -z ${oT2wImage} ] ; then 
  ${FSLDIR}/bin/imcp ${WDir}/T2_biascorr ${oT2wImage}
  verbose_echo " --> Copied T2_biascorr.nii.gz to ${oT2wImage}.nii.gz"
fi

if [ ! -z ${oT2wBrain} ] ; then
  ${FSLDIR}/bin/imcp ${WDir}/T2_biascorr_brain ${oT2wBrain}
  verbose_echo " --> Copied T2_biascorr_brain.nii.gz to ${oT2wBrain}.nii.gz"
fi 

if [ ! -z ${oBias} ] ; then
  ${FSLDIR}/bin/imcp ${WDir}/T2_fast_bias ${oBias}
  verbose_echo " --> Copied T2_fast_bias.nii.gz to ${oBias}.nii.gz"
fi

verbose_green_echo "---> Finished T1w Bias Field Correction"
verbose_echo " "

log_Msg " END: T1w BiasFieldCorrection"
echo " END: `date`" >> $WDir/log.txt

########################################## QA STUFF ##########################################
if [ -e $WDir/qa.txt ] ; then rm -f $WDir/qa.txt ; fi
echo "cd `pwd`" >> $WDir/qa.txt
echo "# Look at the quality of the bias corrected output (T1w is brain only)" >> $WDir/qa.txt
echo "fslview $WDir/T2_biascorr_brain.nii.gz" >> $WDir/qa.txt

##############################################################################################

