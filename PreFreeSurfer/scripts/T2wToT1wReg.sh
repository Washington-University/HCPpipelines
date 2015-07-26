#!/bin/bash
set -e
# Requirements for this script
#  installed versions of: FSL (version 5.0.6), HCP-gradunwarp (HCP version 1.0.2)
#  environment: FSLDIR and PATH for gradient_unwarp.py

################################################ SUPPORT FUNCTIONS ##################################################

Usage() {
  echo "`basename $0`: Script for registering T2w to T1w"
  echo " "
  echo "Usage: `basename $0` [--workingdir=<working directory>]"
  echo "            --t1=<input T1w image>"
  echo "            --t1brain=<input T1w brain-extracted image>"
  echo "            --t2=<input T2w image>"
  echo "            --t2brain=<input T2w brain-extracted image>"
  echo "            [--t1reg=<registration T1w image>]"
  echo "            [--t1brainreg=<registration T1w brain-extracted image>]"
  echo "            [--t2reg=<registration T2w image>]"
  echo "            [--t2brainreg=<registration T2w brain-extracted image>]"
  echo "            --ot1=<output corrected T1w image>"
  echo "            --ot1brain=<output corrected, brain-extracted T1w image>"
  echo "            --ot1warp=<output warpfield for distortion correction of T1w image>"
  echo "            --ot2=<output corrected T2w image>"
  echo "            --ot2brain=<output corrected, brain-extracted T2w image>"
  echo "            --ot2warp=<output warpfield for distortion correction of T2w image>"
  echo "            [--ot1reg=<output corrected registration T1w image>]"
  echo "            [--ot1brainreg=<output corrected registration T1w brain-extracted image>]"
  echo "            [--ot2reg=<output corrected registration T2w image>]"
  echo "            [--ot2brainreg=<output corrected registration T2w brain-extracted image>]"
  echo "            [--smoothfillnonpos=<TRUE (default), FALSE>]"
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

################################################## OPTION PARSING #####################################################

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options
if [ $# -lt 13 ] ; then Usage; exit 1; fi

# parse arguments
WD=`getopt1 "--workingdir" $@`  # "$1"
T1wImage=`getopt1 "--t1" $@`  # "$2"
T1wImageBrain=`getopt1 "--t1brain" $@`  # "$3"
T2wImage=`getopt1 "--t2" $@`  # "$4"
T2wImageBrain=`getopt1 "--t2brain" $@`  # "$5"
OutputT1wImage=`getopt1 "--ot1" $@`  # "${12}"
OutputT1wImageBrain=`getopt1 "--ot1brain" $@`  # "${13}"
OutputT1wTransform=`getopt1 "--ot1warp" $@`  # "${14}"
OutputT2wImage=`getopt1 "--ot2" $@`  # "${15}"
OutputT2wImageBrain=`getopt1 "--ot2brain" $@`  # "${15}"
OutputT2wTransform=`getopt1 "--ot2warp" $@`  # "${16}"
T1wImageReg=`getopt1 "--t1reg" $@`  # "$2"
T1wImageBrainReg=`getopt1 "--t1brainreg" $@`  # "$3"
T2wImageReg=`getopt1 "--t2brainreg" $@`  # "$5"
T2wImageBrainReg=`getopt1 "--t2brainreg" $@`  # "$5"
OutputT1wImageReg=`getopt1 "--ot1reg" $@`  # "${12}"
OutputT1wImageBrainReg=`getopt1 "--ot1brainreg" $@`  # "${13}"
OutputT2wImageReg=`getopt1 "--ot2reg" $@`  # "${15}"
OutputT2wImageBrainReg=`getopt1 "--ot2brainreg" $@`  # "${15}"
SmoothFillNonPos=`getopt1 "--smoothfillnonpos" $@`  # "$23"

# default parameters
WD=`defaultopt $WD .`
SmoothFillNonPos=`defaultopt $SmoothFillNonPos "TRUE"`

flg_regimage="FALSE"
[[ -n $T1wImageReg ]] && [[ -n $T1wImageBrainReg ]] && [[ -n $T2wImageBrainReg ]] && flg_regimage="TRUE"

T1wImageBrain=`${FSLDIR}/bin/remove_ext $T1wImageBrain`
T1wImageBrainBasename=`basename "$T1wImageBrain"`
if [[ $flg_regimage = "TRUE" ]] ; then
  T1wImageBrainReg=`${FSLDIR}/bin/remove_ext $T1wImageBrainReg`
  T1wImageBrainBasenameReg=`basename "$T1wImageBrainReg"`
fi

echo " "
echo " START: T2w2T1Reg"

mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt


########################################## DO WORK ##########################################

# estimate registration based on original (e.g. T1wImage) or dedicated images (e.g. T1wImageReg)
if [[ $flg_regimage = "TRUE" ]] ; then
  ${FSLDIR}/bin/imcp "$T1wImageBrain" "$WD"/"$T1wImageBrainBasename"
  ${FSLDIR}/bin/imcp "$T1wImageBrainReg" "$WD"/"$T1wImageBrainBasenameReg"
  ${FSLDIR}/bin/epi_reg --epi="$T2wImageBrainReg" --t1="$T1wImageReg" --t1brain="$WD"/"$T1wImageBrainBasenameReg" --out="$WD"/T2w2T1w
else
  ${FSLDIR}/bin/imcp "$T1wImageBrain" "$WD"/"$T1wImageBrainBasename"
  ${FSLDIR}/bin/epi_reg --epi="$T2wImageBrain" --t1="$T1wImage" --t1brain="$WD"/"$T1wImageBrainBasename" --out="$WD"/T2w2T1w
fi

# apply the transformation matrix on the original input images
${FSLDIR}/bin/applywarp --rel --interp=spline --in="$T2wImage" --ref="$T1wImage" --premat="$WD"/T2w2T1w.mat --out="$WD"/T2w2T1w

# Add 1 to avoid exact zeros within the image (a problem for myelin mapping?)
${FSLDIR}/bin/fslmaths "$WD"/T2w2T1w -add 1 "$WD"/T2w2T1w -odt float

# smooth inter-/extrapolate the non-positive values in the images
[[ $SmoothFillNonPos = "TRUE" ]] && $HCPPIPEDIR_PreFS/SmoothFill.sh --in="$WD"/T2w2T1w

# Boring overhead (including faking a warp field)
${FSLDIR}/bin/imcp "$T1wImage" "$OutputT1wImage"
${FSLDIR}/bin/imcp "$T1wImageBrain" "$OutputT1wImageBrain"
${FSLDIR}/bin/fslmerge -t $OutputT1wTransform "$T1wImage".nii.gz "$T1wImage".nii.gz "$T1wImage".nii.gz
${FSLDIR}/bin/fslmaths $OutputT1wTransform -mul 0 $OutputT1wTransform
${FSLDIR}/bin/imcp "$WD"/T2w2T1w "$OutputT2wImage"
${FSLDIR}/bin/convertwarp --relout --rel -r "$OutputT2wImage".nii.gz -w $OutputT1wTransform --postmat="$WD"/T2w2T1w.mat --out="$OutputT2wTransform"

# apply the same warping to the registration images
if [[ $flg_regimage = "TRUE" ]] ; then
  ${FSLDIR}/bin/applywarp --rel --interp=spline --in="$T2wImageReg" --ref="$OutputT1wImage" --premat="$WD"/T2w2T1w.mat --out="$OutputT2wImageReg"
  ${FSLDIR}/bin/fslmaths ${OutputT2wImageReg} -add 1 ${OutputT2wImageReg} -odt float
  [[ $SmoothFillNonPos = "TRUE" ]] && $HCPPIPEDIR_PreFS/SmoothFill.sh --in=${OutputT2wImageReg}
  ${FSLDIR}/bin/fslmaths ${OutputT2wImageReg} -mas ${OutputT1wImageBrain} ${OutputT2wImageBrainReg}
fi

echo " "
echo " END: T2w2T1Reg"
echo " END: `date`" >> $WD/log.txt


########################################## QA STUFF ##########################################

if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# View registration result of corrected T2w to corrected T1w image" >> $WD/qa.txt
echo "fslview ${OutputT1wImage} ${OutputT2wImage}" >> $WD/qa.txt


##############################################################################################
