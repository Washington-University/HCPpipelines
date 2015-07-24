#!/bin/bash
set -e
# Requirements for this script
#  installed versions of: FSL (version 5.0.6), HCP-gradunwarp (HCP version 1.0.2)
#  environment: FSLDIR and PATH for gradient_unwarp.py

################################################ SUPPORT FUNCTIONS ##################################################

Usage() {
  echo "`basename $0`: Script for performing gradient-nonlinearity and susceptibility-inducted distortion correction on T1w images"
  echo " "
  echo "Usage: `basename $0` [--workingdir=<working directory>]"
  echo "            --t1=<input T1w image>"
  echo "            --t1brain=<input T1w brain-extracted image>"
  echo "            [--t1reg=<registration T1w image>]"
  echo "            [--t1brainreg=<registration T1w brain-extracted image>]"
  echo "            [--fmapmag=<input fieldmap magnitude image>]"
  echo "            [--fmapphase=<input fieldmap phase images (single 4D image containing 2x3D volumes)>]"
  echo "            [--echodiff=<echo time difference for fieldmap images (in milliseconds)>]"
  echo "            [--SEPhaseNeg=<input spin echo negative phase encoding image>]"
  echo "            [--SEPhasePos=<input spin echo positive phase encoding image>]"
  echo "            [--echospacing=<effective echo spacing of fMRI image, in seconds>]"
  echo "            [--seunwarpdir=<direction of distortion according to voxel axes>]"
  echo "            --t1sampspacing=<sample spacing (readout direction) of T1w image - in seconds>"
  echo "            --unwarpdir=<direction of distortion according to voxel axes (post reorient2std)>"
  echo "            --ot1=<output corrected T1w image>"
  echo "            --ot1brain=<output corrected, brain-extracted T1w image>"
  echo "            --ot1warp=<output warpfield for distortion correction of T1w image>"
  echo "            [--ot1reg=<output corrected registration T1w image>]"
  echo "            [--ot1brainreg=<output corrected registration T1w brain-extracted image>]"
  echo "            --method=<method used for distortion correction: FIELDMAP or TOPUP>"
  echo "            [--topupconfig=<topup config file>]"
  echo "            [--gdcoeffs=<gradient distortion coefficients (SIEMENS file)>]"
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

################################################### OUTPUT FILES #####################################################

# For distortion correction:
#
# Output files (in $WD): Magnitude  Magnitude_brain  Phase  FieldMap
#                        Magnitude_brain_warppedT1w  Magnitude_brain_warppedT1w2${T1wImageBrainBasename}
#                        fieldmap2${T1wImageBrainBasename}.mat   FieldMap2${T1wImageBrainBasename}
#                        FieldMap2${T1wImageBrainBasename}_ShiftMap
#                        FieldMap2${T1wImageBrainBasename}_Warp ${T1wImageBasename}  ${T1wImageBrainBasename}
#
# Output files (not in $WD):  ${OutputT1wTransform}   ${OutputT1wImage}  ${OutputT1wImageBrain}
#        Note that these outputs are actually copies of the last three entries in the $WD list

################################################## OPTION PARSING #####################################################

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options
if [ $# -lt 8 ] ; then Usage; exit 1; fi

# parse arguments
WD=`getopt1 "--workingdir" $@`  # "$1"
T1wImage=`getopt1 "--t1" $@`  # "$2"
T1wImageBrain=`getopt1 "--t1brain" $@`  # "$3"
MagnitudeInputName=`getopt1 "--fmapmag" $@`  # "$6"
PhaseInputName=`getopt1 "--fmapphase" $@`  # "$7"
TE=`getopt1 "--echodiff" $@`  # "$8"
SpinEchoPhaseEncodeNegative=`getopt1 "--SEPhaseNeg" $@`  # "$7"
SpinEchoPhaseEncodePositive=`getopt1 "--SEPhasePos" $@`  # "$5"
DwellTime=`getopt1 "--echospacing" $@`  # "$9"
SEUnwarpDir=`getopt1 "--seunwarpdir" $@`  # "${11}"
T1wSampleSpacing=`getopt1 "--t1sampspacing" $@`  # "$9"
UnwarpDir=`getopt1 "--unwarpdir" $@`  # "${11}"
OutputT1wImage=`getopt1 "--ot1" $@`  # "${12}"
OutputT1wImageBrain=`getopt1 "--ot1brain" $@`  # "${13}"
OutputT1wTransform=`getopt1 "--ot1warp" $@`  # "${14}"
DistortionCorrection=`getopt1 "--method" $@`  # "${21}"
TopupConfig=`getopt1 "--topupconfig" $@`  # "${22}"
GradientDistortionCoeffs=`getopt1 "--gdcoeffs" $@`  # "${18}"
T1wImageReg=`getopt1 "--t1reg" $@`  # "$2"
T1wImageBrainReg=`getopt1 "--t1brainreg" $@`  # "$3"
OutputT1wImageReg=`getopt1 "--ot1reg" $@`  # "${12}"
OutputT1wImageBrainReg=`getopt1 "--ot1brainreg" $@`  # "${13}"
SmoothFillNonPos=`getopt1 "--smoothfillnonpos" $@`  # "$23"

flg_regimage="FALSE"
[[ -n $T1wImageReg ]] && [[ -n $T1wImageBrainReg ]] && flg_regimage="TRUE"

# default parameters
WD=`defaultopt $WD .`
SmoothFillNonPos=`defaultopt $SmoothFillNonPos "TRUE"`

T1wImage=`${FSLDIR}/bin/remove_ext $T1wImage`
T1wImageBrain=`${FSLDIR}/bin/remove_ext $T1wImageBrain`
if [[ $flg_regimage = "TRUE" ]] ; then
  T1wImageReg=`${FSLDIR}/bin/remove_ext $T1wImageReg`
  T1wImageBrainReg=`${FSLDIR}/bin/remove_ext $T1wImageBrainReg`
fi

T1wImageBasename=`basename "$T1wImage"`
T1wImageBrainBasename=`basename "$T1wImageBrain"`
T1wImageBasenameReg=`basename "$T1wImageReg"`
T1wImageBrainBasenameReg=`basename "$T1wImageBrainReg"`

echo " "
echo " START: DistortionCorrection"

mkdir -p $WD
mkdir -p ${WD}/FieldMap

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt


########################################## DO WORK ##########################################

###### FIELDMAP VERSION (GE FIELDMAPS) ######
if [ $DistortionCorrection = "FIELDMAP" ] ; then
  ### Create fieldmaps (and apply gradient non-linearity distortion correction)
  echo " "
  echo " "
  echo " "
  #echo ${HCPPIPEDIR_Global}/FieldMapPreprocessingAll.sh ${WD}/FieldMap ${MagnitudeInputName} ${PhaseInputName} ${TE} ${WD}/Magnitude ${WD}/Magnitude_brain ${WD}/Phase ${WD}/FieldMap ${GradientDistortionCoeffs} ${GlobalScripts}

  ${HCPPIPEDIR_Global}/FieldMapPreprocessingAll.sh \
    --workingdir=${WD}/FieldMap \
    --fmapmag=${MagnitudeInputName} \
    --fmapphase=${PhaseInputName} \
    --echodiff=${TE} \
    --ofmapmag=${WD}/Magnitude \
    --ofmapmagbrain=${WD}/Magnitude_brain \
    --ofmap=${WD}/FieldMap \
    --gdcoeffs=${GradientDistortionCoeffs}

###### TOPUP VERSION (SE FIELDMAPS) ######
elif [ $DistortionCorrection = "TOPUP" ] ; then
  if [[ ${SEUnwarpDir} = "x" || ${SEUnwarpDir} = "y" ]] ; then
    ScoutInputName="${SpinEchoPhaseEncodePositive}"
  elif [[ ${SEUnwarpDir} = "-x" || ${SEUnwarpDir} = "-y" || ${SEUnwarpDir} = "x-" || ${SEUnwarpDir} = "y-" ]] ; then
    ScoutInputName="${SpinEchoPhaseEncodeNegative}"
  fi
  # Use topup to distortion correct the scout scans
  #    using a blip-reversed SE pair "fieldmap" sequence
  ${HCPPIPEDIR_Global}/TopupPreprocessingAll.sh \
      --workingdir=${WD}/FieldMap \
      --phaseone=${SpinEchoPhaseEncodeNegative} \
      --phasetwo=${SpinEchoPhaseEncodePositive} \
      --scoutin=${ScoutInputName} \
      --echospacing=${DwellTime} \
      --unwarpdir=${SEUnwarpDir} \
      --ofmapmag=${WD}/Magnitude \
      --ofmapmagbrain=${WD}/Magnitude_brain \
      --ofmap=${WD}/FieldMap \
      --ojacobian=${WD}/Jacobian \
      --gdcoeffs=${GradientDistortionCoeffs} \
      --topupconfig=${TopupConfig}
fi

# Forward warp the fieldmap magnitude and register to T1w image (transform phase image too)
${FSLDIR}/bin/fugue --loadfmap=${WD}/FieldMap --dwell=${T1wSampleSpacing} --saveshift=${WD}/FieldMap_ShiftMapT1w.nii.gz
${FSLDIR}/bin/convertwarp --relout --rel --ref=${WD}/Magnitude --shiftmap=${WD}/FieldMap_ShiftMapT1w.nii.gz --shiftdir=${UnwarpDir} --out=${WD}/FieldMap_WarpT1w.nii.gz

# estimate registration based on original (e.g. T1wImage) or dedicated images (e.g. T1wImageReg)
if [[ $flg_regimage = "TRUE" ]] ; then
  if [ $DistortionCorrection = "FIELDMAP" ] ; then
    ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/Magnitude -r ${WD}/Magnitude -w ${WD}/FieldMap_WarpT1w.nii.gz -o ${WD}/Magnitude_warppedT1w
    ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/Magnitude_warppedT1w -ref ${T1wImageReg} -out ${WD}/Magnitude_warppedT1w2${T1wImageBasenameReg} -omat ${WD}/Fieldmap2${T1wImageBasenameReg}.mat -searchrx -30 30 -searchry -30 30 -searchrz -30 30
    ${FSLDIR}/bin/imcp ${WD}/Magnitude_warppedT1w2${T1wImageBasenameReg} ${WD}/Magnitude_warppedT1w2${T1wImageBasename}
    cp ${WD}/Fieldmap2${T1wImageBasenameReg}.mat ${WD}/Fieldmap2${T1wImageBasename}.mat
  elif [ $DistortionCorrection = "TOPUP" ] ; then
    ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/Magnitude_brain -r ${WD}/Magnitude_brain -w ${WD}/FieldMap_WarpT1w.nii.gz -o ${WD}/Magnitude_brain_warppedT1w
    ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/Magnitude_brain_warppedT1w -ref ${T1wImageBrainReg} -out ${WD}/Magnitude_brain_warppedT1w2${T1wImageBasenameReg} -omat ${WD}/Fieldmap2${T1wImageBasenameReg}.mat -searchrx -30 30 -searchry -30 30 -searchrz -30 30
    ${FSLDIR}/bin/imcp ${WD}/Magnitude_brain_warppedT1w2${T1wImageBasenameReg} ${WD}/Magnitude_brain_warppedT1w2${T1wImageBasename}
    cp ${WD}/Fieldmap2${T1wImageBasenameReg}.mat ${WD}/Fieldmap2${T1wImageBasename}.mat
  fi
else
  if [ $DistortionCorrection = "FIELDMAP" ] ; then
    ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/Magnitude -r ${WD}/Magnitude -w ${WD}/FieldMap_WarpT1w.nii.gz -o ${WD}/Magnitude_warppedT1w
    ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/Magnitude_warppedT1w -ref ${T1wImage} -out ${WD}/Magnitude_warppedT1w2${T1wImageBasename} -omat ${WD}/Fieldmap2${T1wImageBasename}.mat -searchrx -30 30 -searchry -30 30 -searchrz -30 30
  elif [ $DistortionCorrection = "TOPUP" ] ; then
    ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/Magnitude_brain -r ${WD}/Magnitude_brain -w ${WD}/FieldMap_WarpT1w.nii.gz -o ${WD}/Magnitude_brain_warppedT1w
    ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/Magnitude_brain_warppedT1w -ref ${T1wImageBrain} -out ${WD}/Magnitude_brain_warppedT1w2${T1wImageBasename} -omat ${WD}/Fieldmap2${T1wImageBasename}.mat -searchrx -30 30 -searchry -30 30 -searchrz -30 30
  fi
fi

${FSLDIR}/bin/flirt -in ${WD}/FieldMap.nii.gz -ref ${T1wImage} -applyxfm -init ${WD}/Fieldmap2${T1wImageBasename}.mat -out ${WD}/FieldMap2${T1wImageBasename}

# Convert to shift map then to warp field and unwarp the T1w
${FSLDIR}/bin/fugue --loadfmap=${WD}/FieldMap2${T1wImageBasename} --dwell=${T1wSampleSpacing} --saveshift=${WD}/FieldMap2${T1wImageBasename}_ShiftMap.nii.gz
${FSLDIR}/bin/convertwarp --relout --rel --ref=${T1wImageBrain} --shiftmap=${WD}/FieldMap2${T1wImageBasename}_ShiftMap.nii.gz --shiftdir=${UnwarpDir} --out=${WD}/FieldMap2${T1wImageBasename}_Warp.nii.gz
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${T1wImage} -r ${T1wImage} -w ${WD}/FieldMap2${T1wImageBasename}_Warp.nii.gz -o ${WD}/${T1wImageBasename}

# smooth inter-/extrapolate the non-positive values in the images
[[ $SmoothFillNonPos = "TRUE" ]] && $HCPPIPEDIR_PreFS/SmoothFill.sh --in=${WD}/${TXwImageBasename}

# Make a brain image (transform to make a mask, then apply it)
${FSLDIR}/bin/applywarp --rel --interp=nn -i ${T1wImageBrain} -r ${T1wImageBrain} -w ${WD}/FieldMap2${T1wImageBasename}_Warp.nii.gz -o ${WD}/${T1wImageBrainBasename}
${FSLDIR}/bin/fslmaths ${WD}/${T1wImageBasename} -mas ${WD}/${T1wImageBrainBasename} ${WD}/${T1wImageBrainBasename}

# Copy files to specified destinations
${FSLDIR}/bin/imcp ${WD}/FieldMap2${T1wImageBasename}_Warp ${OutputT1wTransform}
${FSLDIR}/bin/imcp ${WD}/${T1wImageBasename} ${OutputT1wImage}
${FSLDIR}/bin/imcp ${WD}/${T1wImageBrainBasename} ${OutputT1wImageBrain}

# apply the same warping to the registration images
if [[ $flg_regimage = "TRUE" ]] ; then
  ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${T1wImageReg} -r ${T1wImage} -w ${WD}/FieldMap2${T1wImageBasename}_Warp.nii.gz -o ${WD}/${T1wImageBasenameReg}
  [[ $SmoothFillNonPos = "TRUE" ]] && $HCPPIPEDIR_PreFS/SmoothFill.sh --in=${WD}/${T1wImageBasenameReg}
  ${FSLDIR}/bin/fslmaths ${WD}/${T1wImageBasenameReg} -mas ${WD}/${T1wImageBrainBasename} ${WD}/${T1wImageBrainBasenameReg}
  ${FSLDIR}/bin/imcp ${WD}/${T1wImageBasenameReg} ${OutputT1wImageReg}
  ${FSLDIR}/bin/imcp ${WD}/${T1wImageBrainBasenameReg} ${OutputT1wImageBrainReg}
fi

echo " "
echo " END: DistortionCorrection"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ##########################################

if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# Compare pre- and post-distortion correction for T1w" >> $WD/qa.txt
echo "fslview ${T1wImage} ${OutputT1wImage}" >> $WD/qa.txt

##############################################################################################
