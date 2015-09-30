#!/bin/bash
set -e

# Requirements for this script
#  installed versions of: FSL (version 5.0.6), caret7 (a.k.a. Connectome Workbench) (version 1.0)
#  environment: FSLDIR  CARET7DIR

################################################ SUPPORT FUNCTIONS ##################################################

Usage() {
  echo "`basename $0`: Tool for bias field correction based on FAST (not on the square root of T1w * T2w)"
  echo " "
  echo "Usage: `basename $0` --workingdir=<working directory>"
  echo "      --T1im=<input T1 image>"
  echo "      --T1brain=<input T1 brain>"
  echo "      [--T2im=<input T2 image>]"
  echo "      [--T2brain=<input T2 brain>]"
  echo "      --T1imest=<input T1 image for estimation only>"
  echo "      --T1brainest=<input T1 brain for estimation only>"
  echo "      [--T2imest=<input T2 image for estimation only>]"
  echo "      [--T2brainest=<input T2 brain for estimation only>]"
  echo "      --obias=<output bias field image>"
  echo "      --oT1im=<output corrected T1 image>"
  echo "      --oT1brain=<output corrected T1 brain>"
  echo "      [--oT2im=<output corrected T2 image>]"
  echo "      [--oT2brain=<output corrected T2 brain>]"
  echo "      [--BiasFieldSmoothingSigma=<sigma of bias field smoothing in mm>]"
  echo "      [--fastmethod={ROBUST,SINGLE}]"
  echo "      [--smoothfillnonpos={TRUE (default), FALSE}]"
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
if [ $# -lt 6 ] ; then Usage; exit 1; fi

# parse arguments
WD=`getopt1 "--workingdir" $@`  # "$1"
T1wImage=`getopt1 "--T1im" $@`  # "$2"
T1wImageBrain=`getopt1 "--T1brain" $@`  # "$3"
T2wImage=`getopt1 "--T2im" $@`  # "$2"
T2wImageBrain=`getopt1 "--T2brain" $@`  # "$3"
T1wImageEst=`getopt1 "--T1imest" $@`  # "$2"
T1wImageBrainEst=`getopt1 "--T1brainest" $@`  # "$3"
T2wImageEst=`getopt1 "--T2imest" $@`  # "$2"
T2wImageBrainEst=`getopt1 "--T2brainest" $@`  # "$3"
OutputBiasField=`getopt1 "--obias" $@`  # "$4"
OutputT1wRestoredImage=`getopt1 "--oT1im" $@`  # "$5"
OutputT1wRestoredBrainImage=`getopt1 "--oT1brain" $@`  # "$6"
OutputT2wRestoredImage=`getopt1 "--oT2im" $@`  # "$5"
OutputT2wRestoredBrainImage=`getopt1 "--oT2brain" $@`  # "$6"
BiasFieldSmoothingSigma=`getopt1 "--bfsigma" $@`  # "$7"
FASTMethod=`getopt1 "--fastmethod" $@`  # "$8"
SmoothFillNonPos=`getopt1 "--smoothfillnonpos" $@`  # "$10"

# default parameters
WD=`defaultopt $WD .`
BiasFieldSmoothingSigma=`defaultopt $BiasFieldSmoothingSigma 5` #Leave this at 5mm for now
FASTMethod=`defaultopt $FASTMethod "ROBUST"`
SmoothFillNonPos=`defaultopt $SmoothFillNonPos "TRUE"`

# if no special estimation images are supplied, just the standard ones
[[ -z $T1wImageEst ]] && T1wImageEst=$T1wImage
[[ -z $T1wImageBrainEst ]] && T1wImageBrainEst=$T1wImageBrain
[[ -z $T2wImageEst ]] && T2wImageEst=$T1wImage
[[ -z $T2wImageBrainEst ]] && T2wImageBrainEst=$T1wImageBrain

Modalities="T1w"
[[ -n $T2wImage ]] && [[ -n $OutputT2wRestoredImage ]] && [[ -n $OutputT2wRestoredBrainImage ]] && Modalities="T1w T2w"

# ensure that the working directory exists
mkdir -p $WD

# reporting
echo " "
echo " START: BiasFieldCorrection_FAST_$FASTMethod"
echo "Modalities: $Modalities"

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt

########################################## DO WORK ##########################################

# convert sigma to FWHM
FWHM=$(echo "2.3548 * $BiasFieldSmoothingSigma" | bc)

# loop over modalities
for TXw in ${Modalities} ; do
  # set up appropriate input variables
  if [[ $TXw = "T1w" ]] ; then
      X=1
      TXwImage=${T1wImage}
      TXwImageBrain=${T1wImageBrain}
      TXwImageEst=${T1wImageEst}
      TXwImageBrainEst=${T1wImageBrainEst}
      TXwOutputBiasField=${OutputBiasField}
      OutputTXwRestoredImage=${OutputT1wRestoredImage}
      OutputTXwRestoredBrainImage=${OutputT1wRestoredBrainImage}
  else
      X=2
      TXwImage=${T2wImage}
      TXwImageBrain=${T2wImageBrain}
      TXwImageEst=${T2wImageEst}
      TXwImageBrainEst=${T2wImageBrainEst}
      TXwOutputBiasField=${OutputBiasField}_$TXw
      OutputTXwRestoredImage=${OutputT2wRestoredImage}
      OutputTXwRestoredBrainImage=${OutputT2wRestoredBrainImage}
      if [[ $FASTMethod != "ROBUST" ]] ; then
        # T2w brain extracted image does not yet exist
        [[ ! -r ${T2wImageBrain} ]] && ${FSLDIR}/bin/fslmaths ${T2wImage} -mas ${T1wImageBrain} ${TXwImageBrain}
        [[ ! -r ${T2wImageBrainEst} ]] && ${FSLDIR}/bin/fslmaths ${T2wImageEst} -mas ${T1wImageBrainEst} ${TXwImageBrainEst}
      fi
  fi

  # use robust or standard FAST to estimate the bias field
  if [[ $FASTMethod = "ROBUST" ]] ; then
    TXwImageBasename=`${FSLDIR}/bin/remove_ext "$TXwImage"`
    TXwImageBasename=`basename "$TXwImageBasename"`
    # do robust bias correction based on the fsl_anat pipeline
    $HCPPIPEDIR_PreFS/RobustBiasCorr.sh --in=${TXwImageEst} --workingdir=$WD --brainmask=${T1wImageBrain} --basename=${TXwImageBasename} --FWHM=$FWHM --type=$X --smoothfillnonpos=$SmoothFillNonPos --fslreorient2std="FALSE" --robustfov="FALSE" --betrestore="FALSE"
    ${FSLDIR}/bin/immv $WD/${TXwImageBasename}_bias ${TXwOutputBiasField}
  else
    TXwImageBrainBasename=`${FSLDIR}/bin/remove_ext "$TXwImageBrain"`
    TXwImageBrainBasename=`basename "$TXwImageBrainBasename"`
    # use standard FAST
    ${FSLDIR}/bin/fast -b -l $FWHM -t $X --iter=5 --nopve --fixed=0 -o $WD/${TXwImageBrainBasename} $TXwImageBrainEst
    ${FSLDIR}/bin/immv $WD/${TXwImageBrainBasename}_bias ${TXwOutputBiasField}
    # clean up redundant images
    rm $WD/${TXwImageBrainBasename}_mix* $WD/${TXwImageBrainBasename}_seg*
  fi

  # Use bias field output to create corrected images
  ${FSLDIR}/bin/fslmaths $TXwImage -div ${TXwOutputBiasField} $OutputTXwRestoredImage -odt float
  # smooth inter-/extrapolate the non-positive values in the images
  [[ $SmoothFillNonPos = "TRUE" ]] && $HCPPIPEDIR_PreFS/SmoothFill.sh --in=$OutputTXwRestoredImage
  # extract brain
  ${FSLDIR}/bin/fslmaths $OutputTXwRestoredImage -mas $T1wImageBrain $OutputTXwRestoredBrainImage -odt float

done

# reporting
echo " "
echo " END: BiasFieldCorrection_FAST_$FASTMethod"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ##########################################
if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# Look at the quality of the bias corrected output (T1w is brain only)" >> $WD/qa.txt
echo "fslview $T1wImageBrain $OutputT1wRestoredBrainImage" >> $WD/qa.txt
[[ $Modalities = "T1w T2w" ]] && echo "fslview $T2wImage $OutputT2wRestoredImage" >> $WD/qa.txt
#echo "# Optional debugging (multiplied image + masked + normalised versions)" >> $WD/qa.txt
#echo "fslview $WD/T1wmulT2w.nii.gz $WD/T1wmulT2w_brain_norm.nii.gz $WD/T1wmulT2w_brain_norm_modulate_mask -l Red -t 0.5" >> $WD/qa.txt
#echo "# Optional debugging (smoothed version, extrapolated version)" >> $WD/qa.txt
#echo "fslview $WD/T1wmulT2w_brain_norm_s${BiasFieldSmoothingSigma}.nii.gz $WD/bias_raw" >> $WD/qa.txt


##############################################################################################
