#!/bin/bash 
set -e

# Requirements for this script
#  installed versions of: FSL (version 5.0.6), caret7 (a.k.a. Connectome Workbench) (version 1.0)
#  environment: FSLDIR  CARET7DIR

################################################ SUPPORT FUNCTIONS ##################################################

Usage() {
  echo "`basename $0`: Tool for bias field correction based on square root of T1w * T2w"
  echo " "
  echo "Usage: `basename $0` --workingdir=<working directory> --T1im=<input T1 image> --T1brain=<input T1 brain> --T2im=<input T2 image> --obias=<output bias field image> --oT1im=<output corrected T1 image> --oT1brain=<output corrected T1 brain> --oT2im=<output corrected T2 image> --oT2brain=<output corrected T2 brain>"
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

# Output images (in $WD): 
#      T1wmulT2w  T1wmulT2w_brain  T1wmulT2w_brain_norm  
#      SmoothNorm_sX  T1wmulT2w_brain_norm_sX  
#      T1wmulT2w_brain_norm_modulate  T1wmulT2w_brain_norm_modulate_mask  bias_raw   
# Output images (not in $WD): 
#      $OutputBiasField 
#      $OutputT1wRestoredBrainImage $OutputT1wRestoredImage 
#      $OutputT2wRestoredBrainImage $OutputT2wRestoredImage

################################################## OPTION PARSING #####################################################

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options
if [ $# -lt 8 ] ; then Usage; exit 1; fi

# parse arguments
WD=`getopt1 "--workingdir" $@`  # "$1"
T1wImage=`getopt1 "--T1im" $@`  # "$2"
T1wImageBrain=`getopt1 "--T1brain" $@`  # "$3"
T2wImage=`getopt1 "--T2im" $@`  # "$4"
OutputBiasField=`getopt1 "--obias" $@`  # "$5"
OutputT1wRestoredImage=`getopt1 "--oT1im" $@`  # "$6"
OutputT1wRestoredBrainImage=`getopt1 "--oT1brain" $@`  # "$7"
OutputT2wRestoredImage=`getopt1 "--oT2im" $@`  # "$8"
OutputT2wRestoredBrainImage=`getopt1 "--oT2brain" $@`  # "$9"
BiasFieldSmoothingSigma=`getopt1 "--bfsigma" $@`  # "$9"

# default parameters
WD=`defaultopt $WD .`
Factor="0.5" #Leave this at 0.5 for now it is the number of standard deviations below the mean to threshold the non-brain tissues at
BiasFieldSmoothingSigma=`defaultopt $BiasFieldSmoothingSigma 5` #Leave this at 5mm for now


echo " "
echo " START: BiasFieldCorrection"

mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt

########################################## DO WORK ########################################## 

# Form sqrt(T1w*T2w), mask this and normalise by the mean
${FSLDIR}/bin/fslmaths $T1wImage -mul $T2wImage -abs -sqrt $WD/T1wmulT2w.nii.gz -odt float
${FSLDIR}/bin/fslmaths $WD/T1wmulT2w.nii.gz -mas $T1wImageBrain $WD/T1wmulT2w_brain.nii.gz
meanbrainval=`${FSLDIR}/bin/fslstats $WD/T1wmulT2w_brain.nii.gz -M`
${FSLDIR}/bin/fslmaths $WD/T1wmulT2w_brain.nii.gz -div $meanbrainval $WD/T1wmulT2w_brain_norm.nii.gz

# Smooth the normalised sqrt image, using within-mask smoothing : s(Mask*X)/s(Mask)
${FSLDIR}/bin/fslmaths $WD/T1wmulT2w_brain_norm.nii.gz -bin -s $BiasFieldSmoothingSigma $WD/SmoothNorm_s${BiasFieldSmoothingSigma}.nii.gz
${FSLDIR}/bin/fslmaths $WD/T1wmulT2w_brain_norm.nii.gz -s $BiasFieldSmoothingSigma -div $WD/SmoothNorm_s${BiasFieldSmoothingSigma}.nii.gz $WD/T1wmulT2w_brain_norm_s${BiasFieldSmoothingSigma}.nii.gz

# Divide normalised sqrt image by smoothed version (to do simple bias correction)
${FSLDIR}/bin/fslmaths $WD/T1wmulT2w_brain_norm.nii.gz -div $WD/T1wmulT2w_brain_norm_s$BiasFieldSmoothingSigma.nii.gz $WD/T1wmulT2w_brain_norm_modulate.nii.gz

# Create a mask using a threshold at Mean - 0.5*Stddev, with filling of holes to remove any non-grey/white tissue.
STD=`${FSLDIR}/bin/fslstats $WD/T1wmulT2w_brain_norm_modulate.nii.gz -S`
echo $STD
MEAN=`${FSLDIR}/bin/fslstats $WD/T1wmulT2w_brain_norm_modulate.nii.gz -M`
echo $MEAN
Lower=`echo "$MEAN - ($STD * $Factor)" | bc -l`
echo $Lower
${FSLDIR}/bin/fslmaths $WD/T1wmulT2w_brain_norm_modulate -thr $Lower -bin -ero -mul 255 $WD/T1wmulT2w_brain_norm_modulate_mask
${CARET7DIR}/wb_command -volume-remove-islands $WD/T1wmulT2w_brain_norm_modulate_mask.nii.gz $WD/T1wmulT2w_brain_norm_modulate_mask.nii.gz

# Extrapolate normalised sqrt image from mask region out to whole FOV
${FSLDIR}/bin/fslmaths $WD/T1wmulT2w_brain_norm.nii.gz -mas $WD/T1wmulT2w_brain_norm_modulate_mask.nii.gz -dilall $WD/bias_raw.nii.gz -odt float
${FSLDIR}/bin/fslmaths $WD/bias_raw.nii.gz -s $BiasFieldSmoothingSigma $OutputBiasField

# Use bias field output to create corrected images
${FSLDIR}/bin/fslmaths $T1wImage -div $OutputBiasField -mas $T1wImageBrain $OutputT1wRestoredBrainImage -odt float
${FSLDIR}/bin/fslmaths $T1wImage -div $OutputBiasField $OutputT1wRestoredImage -odt float
${FSLDIR}/bin/fslmaths $T2wImage -div $OutputBiasField -mas $T1wImageBrain $OutputT2wRestoredBrainImage -odt float
${FSLDIR}/bin/fslmaths $T2wImage -div $OutputBiasField $OutputT2wRestoredImage -odt float

echo " "
echo " END: BiasFieldCorrection"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ########################################## 
if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# Look at the quality of the bias corrected output (T1w is brain only)" >> $WD/qa.txt
echo "fslview $T1wImageBrain $OutputT1wRestoredBrainImage" >> $WD/qa.txt
echo "fslview $T2wImage $OutputT2wRestoredImage" >> $WD/qa.txt
echo "# Optional debugging (multiplied image + masked + normalised versions)" >> $WD/qa.txt
echo "fslview $WD/T1wmulT2w.nii.gz $WD/T1wmulT2w_brain_norm.nii.gz $WD/T1wmulT2w_brain_norm_modulate_mask -l Red -t 0.5" >> $WD/qa.txt
echo "# Optional debugging (smoothed version, extrapolated version)" >> $WD/qa.txt
echo "fslview $WD/T1wmulT2w_brain_norm_s${BiasFieldSmoothingSigma}.nii.gz $WD/bias_raw" >> $WD/qa.txt


##############################################################################################
