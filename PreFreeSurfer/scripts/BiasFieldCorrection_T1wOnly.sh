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

opts_SetScriptDescription "Tool for bias field correction based on T1w image only"

opts_AddMandatory '--workingdir' 'WD' 'path' 'working directory'

opts_AddMandatory '--T1im' 'T1wImage' 'image' "input T1 image"

opts_AddMandatory '--T1brain' 'T1wBrain' 'image' "input T1 brain"

#optional args 
opts_AddOptional '--obias' 'oBias' 'image' "output bias field image"

opts_AddOptional '--oT1im' 'OutputT1wRestoredImage' 'image' "output corrected T1 image"

opts_AddOptional '--oT1brain' 'OutputT1wRestoredBrainImage' ' ' "output corrected T1 brain"

opts_AddOptional '--bfsigma' 'BiasFieldSmoothingSigma' 'value' "Bias field smoothing Sigma (Default 20)" "20"

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

log_Check_Env_Var FSLDIR

################################################### OUTPUT FILES #####################################################

# Output images and files (in $WD):
# T1.nii.gz                         T1_fast_bias_vol2.nii.gz          T1_initfast2_brain_mask2.nii.gz
# T1_biascorr.nii.gz                T1_fast_bias_vol32.nii.gz         T1_initfast2_maskedrestore.nii.gz
# T1_biascorr_brain.nii.gz          T1_fast_restore.nii.gz            T1_initfast2_restore.nii.gz
# T1_biascorr_brain_mask.nii.gz     T1_fast_seg.nii.gz                lesionmask.nii.gz
# T1_fast_bias.nii.gz               T1_fast_totbias.nii.gz            lesionmaskinv.nii.gz
# T1_fast_bias_idxmask.nii.gz       T1_initfast2_brain.nii.gz         log.txt
# T1_fast_bias_init.nii.gz          T1_initfast2_brain_mask.nii.gz


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

if [ ! -z ${OutputT1wRestoredImage} ] ; then 
  ${FSLDIR}/bin/imcp ${WDir}/T1_biascorr ${OutputT1wRestoredImage}
  verbose_echo " --> Copied T1_biascorr.nii.gz to ${OutputT1wRestoredImage}.nii.gz"
fi

if [ ! -z ${OutputT1wRestoredBrainImage} ] ; then
  ${FSLDIR}/bin/imcp ${WDir}/T1_biascorr_brain ${OutputT1wRestoredBrainImage}
  verbose_echo " --> Copied T1_biascorr_brain.nii.gz to ${OutputT1wRestoredBrainImage}.nii.gz"
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

