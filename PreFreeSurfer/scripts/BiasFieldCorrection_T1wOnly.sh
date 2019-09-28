#!/bin/bash
set -e
# source ${HCPPIPEDIR}/global/scripts/debug.shlib # Debugging functions

# Requirements for this script
#  installed versions of: FSL (version 5.0.6)
#  environment: FSLDIR

# ------------------------------------------------------------------------------
#  Verify required environment variables are set
# ------------------------------------------------------------------------------

if [ -z "${FSLDIR}" ]; then
  echo "$(basename ${0}): ABORTING: FSLDIR environment variable must be set"
  exit 1
else
  echo "$(basename ${0}): FSLDIR: ${FSLDIR}"
fi

################################################ SUPPORT FUNCTIONS ##################################################

Usage() {
  echo "`basename $0`: Tool for bias field correction based on T1w image only"
  echo " "
  echo "Usage: `basename $0` --workingdir=<working directory> --T1im=<input T1 image> [--oT1im=<output T1 image>] [-oT1brain=<output T1 brain>] [--bfsigma=<input T1 image>]"
}

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

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options
if [ $# -lt 2 ] ; then Usage; exit 1; fi

# parse arguments
WD=`getopt1 "--workingdir" $@`  
T1wImage=`getopt1 "--T1im" $@`  
T1wBrain=`getopt1 "--T1brain" $@`  
oBias=`getopt1 "--obias" $@`  
oT1wImage=`getopt1 "--oT1im" $@`  
oT1wBrain=`getopt1 "--oT1brain" $@`  
BiasFieldSmoothingSigma=`getopt1 "--bfsigma" $@`

# default parameters
BiasFieldSmoothingSigma=`defaultopt $BiasFieldSmoothingSigma 20` 
WDir="$WD.anat"

echo " "
echo " START: T1w BiasFieldCorrection"

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
  echo " --> masked T1_biascorr.nii.gz using ${T1wBrain}"
fi

# Copy data out if output targets provided

if [ ! -z ${oT1wImage} ] ; then 
  cp ${WDir}/T1_biascorr.nii.gz ${oT1wImage}.nii.gz
  echo " --> Copied T1_biascorr.nii.gz to ${oT1wImage}.nii.gz"
fi

if [ ! -z ${oT1wBrain} ] ; then
  cp ${WDir}/T1_biascorr_brain.nii.gz ${oT1wBrain}.nii.gz
  echo " --> Copied T1_biascorr_brain.nii.gz to ${oT1wBrain}.nii.gz"
fi 

if [ ! -z ${oBias} ] ; then
  cp ${WDir}/T1_fast_bias.nii.gz ${oBias}.nii.gz
  echo " --> Copied T1_fast_bias.nii.gz to ${oBias}.nii.gz"
fi

echo " "
echo " END: T1w BiasFieldCorrection"
echo " END: `date`" >> $WDir/log.txt

########################################## QA STUFF ##########################################
if [ -e $WDir/qa.txt ] ; then rm -f $WDir/qa.txt ; fi
echo "cd `pwd`" >> $WDir/qa.txt
echo "# Look at the quality of the bias corrected output (T1w is brain only)" >> $WDir/qa.txt
echo "fslview $WDir/T1_biascorr_brain.nii.gz" >> $WDir/qa.txt

##############################################################################################
