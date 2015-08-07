#!/bin/bash
set -e
# Requirements for this script
#  installed versions of: FSL (version 5.0.6), HCP-gradunwarp (HCP version 1.0.2)
#  environment: FSLDIR and PATH for gradient_unwarp.py

SCRIPT_NAME="DistortionCorrect.sh"

# -----------------------------------------------------------------------------------
#  Constants for specification of Averaging and Readout Distortion Correction Method
# -----------------------------------------------------------------------------------

SIEMENS_METHOD_OPT="SiemensFieldMap"
SPIN_ECHO_METHOD_OPT="TOPUP"
GENERAL_ELECTRIC_METHOD_OPT="GeneralElectricFieldMap"
FIELDMAP_METHOD_OPT="FIELDMAP"

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
  echo "            [--fmapgeneralelectric=<input General Electric field map (two volumes: 1. field map in deg, 2. magnitude)>]"
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
  echo "            --method=<method used for readout distortion correction>"
  echo ""
  echo "                ${FIELDMAP_METHOD_OPT}"
  echo "                  equivalent to ${SIEMENS_METHOD_OPT} (see below)"
  echo "                  ${SIEMENS_METHOD_OPT} is preferred. This option is maintained for"
  echo "                  backward compatibility."
  echo "                ${SPIN_ECHO_METHOD_OPT}"
  echo "                  use Spin Echo Field Maps for readout distortion correction"
  echo "                ${GENERAL_ELECTRIC_METHOD_OPT}"
  echo "                  use General Electric specific Gradient Echo Field Maps for"
  echo "                  readout distortion correction"
  echo "                ${SIEMENS_METHOD_OPT}"
  echo "                  use Siemens specific Gradient Echo Field Maps for readout"
  echo "                  distortion correction"
  echo ""
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
#

################################################## OPTION PARSING #####################################################

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options
if [ $# -lt 11 ] ; then Usage; exit 1; fi

# parse arguments
WD=`getopt1 "--workingdir" $@`
T1wImage=`getopt1 "--t1" $@`
T1wImageBrain=`getopt1 "--t1brain" $@`
MagnitudeInputName=`getopt1 "--fmapmag" $@`
PhaseInputName=`getopt1 "--fmapphase" $@`
GEB0InputName=`getopt1 "--fmapgeneralelectric" $@`
TE=`getopt1 "--echodiff" $@`
SpinEchoPhaseEncodeNegative=`getopt1 "--SEPhaseNeg" $@`
SpinEchoPhaseEncodePositive=`getopt1 "--SEPhasePos" $@`
DwellTime=`getopt1 "--echospacing" $@`
SEUnwarpDir=`getopt1 "--seunwarpdir" $@`
T1wSampleSpacing=`getopt1 "--t1sampspacing" $@`
UnwarpDir=`getopt1 "--unwarpdir" $@`
OutputT1wImage=`getopt1 "--ot1" $@`
OutputT1wImageBrain=`getopt1 "--ot1brain" $@`
OutputT1wTransform=`getopt1 "--ot1warp" $@`
DistortionCorrection=`getopt1 "--method" $@`
TopupConfig=`getopt1 "--topupconfig" $@`
GradientDistortionCoeffs=`getopt1 "--gdcoeffs" $@`
T1wImageReg=`getopt1 "--t1reg" $@`
T1wImageBrainReg=`getopt1 "--t1brainreg" $@`
OutputT1wImageReg=`getopt1 "--ot1reg" $@`
OutputT1wImageBrainReg=`getopt1 "--ot1brainreg" $@`
SmoothFillNonPos=`getopt1 "--smoothfillnonpos" $@`

UseRegImages="FALSE"
[[ -n $T1wImageReg ]] && [[ -n $T1wImageBrainReg ]] && UseRegImages="TRUE"

# default parameters
WD=`defaultopt $WD .`
SmoothFillNonPos=`defaultopt $SmoothFillNonPos "TRUE"`

T1wImage=`${FSLDIR}/bin/remove_ext $T1wImage`
T1wImageBrain=`${FSLDIR}/bin/remove_ext $T1wImageBrain`
if [[ UseRegImages = "TRUE" ]] ; then
  T1wImageReg=`${FSLDIR}/bin/remove_ext $T1wImageReg`
  T1wImageBrainReg=`${FSLDIR}/bin/remove_ext $T1wImageBrainReg`
fi

T1wImageBrainBasename=`basename "$T1wImageBrain"`
T1wImageBasename=`basename "$T1wImage"`
if [[ UseRegImages = "TRUE" ]] ; then
  T1wImageBasenameReg=`basename "$T1wImageReg"`
  T1wImageBrainBasenameReg=`basename "$T1wImageBrainReg"`
fi

echo " "
echo " START: ${SCRIPT_NAME}"

mkdir -p $WD
mkdir -p ${WD}/FieldMap

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt


########################################## DO WORK ##########################################

case $DistortionCorrection in

    ${FIELDMAP_METHOD_OPT} | ${SIEMENS_METHOD_OPT})

        # --------------------------------------
        # -- Siemens Gradient Echo Field Maps --
        # --------------------------------------

        ### Create fieldmaps (and apply gradient non-linearity distortion correction)
        echo " "
        echo " "
        echo " "

        ${HCPPIPEDIR_Global}/SiemensFieldMapPreprocessingAll.sh \
            --workingdir=${WD}/FieldMap \
            --fmapmag=${MagnitudeInputName} \
            --fmapphase=${PhaseInputName} \
            --echodiff=${TE} \
            --ofmapmag=${WD}/Magnitude \
            --ofmapmagbrain=${WD}/Magnitude_brain \
            --ofmap=${WD}/FieldMap \
            --gdcoeffs=${GradientDistortionCoeffs}

        ;;

    ${GENERAL_ELECTRIC_METHOD_OPT})

        # -----------------------------------------------
        # -- General Electric Gradient Echo Field Maps --
        # -----------------------------------------------

        ### Create fieldmaps (and apply gradient non-linearity distortion correction)
        echo " "
        echo " "
        echo " "

        ${HCPPIPEDIR_Global}/GeneralElectricFieldMapPreprocessingAll.sh \
            --workingdir=${WD}/FieldMap \
            --fmap=${GEB0InputName} \
            --ofmapmag=${WD}/Magnitude \
            --ofmapmagbrain=${WD}/Magnitude_brain \
            --ofmap=${WD}/FieldMap \
            --gdcoeffs=${GradientDistortionCoeffs}

        ;;

    ${SPIN_ECHO_METHOD_OPT})

        # --------------------------
        # -- Spin Echo Field Maps --
        # --------------------------

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

        ;;

    *)
        echo "${SCRIPT_NAME} - ERROR - Unable to create FSL-suitable readout distortion correction field map"
        echo "${SCRIPT_NAME}           Unrecognized distortion correction method: ${DistortionCorrection}"
        exit 1
esac


# Forward warp the fieldmap magnitude and register to T1w image (transform phase image too)
${FSLDIR}/bin/fugue --loadfmap=${WD}/FieldMap --dwell=${T1wSampleSpacing} --saveshift=${WD}/FieldMap_ShiftMapT1w.nii.gz
${FSLDIR}/bin/convertwarp --relout --rel --ref=${WD}/Magnitude --shiftmap=${WD}/FieldMap_ShiftMapT1w.nii.gz --shiftdir=${UnwarpDir} --out=${WD}/FieldMap_WarpT1w.nii.gz

# estimate registration based on original (e.g. T1wImage) or dedicated images (e.g. T1wImageReg)
if [[ $UseRegImages = "TRUE" ]] ; then

  case $DistortionCorrection in

      ${FIELDMAP_METHOD_OPT} | ${SIEMENS_METHOD_OPT} | ${GENERAL_ELECTRIC_METHOD_OPT})
          ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/Magnitude -r ${WD}/Magnitude -w ${WD}/FieldMap_WarpT1w.nii.gz -o ${WD}/Magnitude_warppedT1w
          ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/Magnitude_warppedT1w -ref ${T1wImageReg} -out ${WD}/Magnitude_warppedT1w2${T1wImageBasenameReg} -omat ${WD}/Fieldmap2${T1wImageBasenameReg}.mat -searchrx -30 30 -searchry -30 30 -searchrz -30 30
          ${FSLDIR}/bin/imcp ${WD}/Magnitude_warppedT1w2${T1wImageBasenameReg} ${WD}/Magnitude_warppedT1w2${T1wImageBasename}
          cp ${WD}/Fieldmap2${T1wImageBasenameReg}.mat ${WD}/Fieldmap2${T1wImageBasename}.mat
          ;;

      ${SPIN_ECHO_METHOD_OPT})
          ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/Magnitude_brain -r ${WD}/Magnitude_brain -w ${WD}/FieldMap_WarpT1w.nii.gz -o ${WD}/Magnitude_brain_warppedT1w
          ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/Magnitude_brain_warppedT1w -ref ${T1wImageBrainReg} -out ${WD}/Magnitude_brain_warppedT1w2${T1wImageBasenameReg} -omat ${WD}/Fieldmap2${T1wImageBasenameReg}.mat -searchrx -30 30 -searchry -30 30 -searchrz -30 30
          ${FSLDIR}/bin/imcp ${WD}/Magnitude_brain_warppedT1w2${T1wImageBasenameReg} ${WD}/Magnitude_brain_warppedT1w2${T1wImageBasename}
          cp ${WD}/Fieldmap2${T1wImageBasenameReg}.mat ${WD}/Fieldmap2${T1wImageBasename}.mat
          ;;

      *)
          echo "${SCRIPT_NAME} - ERROR - Unable to apply readout distortion correction"
          echo "${SCRIPT_NAME}           Unrecognized distortion correction method: ${DistortionCorrection}"
          exit 1
  esac

else

  case $DistortionCorrection in

      ${FIELDMAP_METHOD_OPT} | ${SIEMENS_METHOD_OPT} | ${GENERAL_ELECTRIC_METHOD_OPT})
          ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/Magnitude -r ${WD}/Magnitude -w ${WD}/FieldMap_WarpT1w.nii.gz -o ${WD}/Magnitude_warppedT1w
          ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/Magnitude_warppedT1w -ref ${T1wImage} -out ${WD}/Magnitude_warppedT1w2${T1wImageBasename} -omat ${WD}/Fieldmap2${T1wImageBasename}.mat -searchrx -30 30 -searchry -30 30 -searchrz -30 30
          ;;

      ${SPIN_ECHO_METHOD_OPT})
          ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/Magnitude_brain -r ${WD}/Magnitude_brain -w ${WD}/FieldMap_WarpT1w.nii.gz -o ${WD}/Magnitude_brain_warppedT1w
          ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/Magnitude_brain_warppedT1w -ref ${T1wImageBrain} -out ${WD}/Magnitude_brain_warppedT1w2${T1wImageBasename} -omat ${WD}/Fieldmap2${T1wImageBasename}.mat -searchrx -30 30 -searchry -30 30 -searchrz -30 30
          ;;

      *)
          echo "${SCRIPT_NAME} - ERROR - Unable to apply readout distortion correction"
          echo "${SCRIPT_NAME}           Unrecognized distortion correction method: ${DistortionCorrection}"
          exit 1
  esac

fi

${FSLDIR}/bin/flirt -in ${WD}/FieldMap.nii.gz -ref ${T1wImage} -applyxfm -init ${WD}/Fieldmap2${T1wImageBasename}.mat -out ${WD}/FieldMap2${T1wImageBasename}

# Convert to shift map then to warp field and unwarp the T1w
${FSLDIR}/bin/fugue --loadfmap=${WD}/FieldMap2${T1wImageBasename} --dwell=${T1wSampleSpacing} --saveshift=${WD}/FieldMap2${T1wImageBasename}_ShiftMap.nii.gz
${FSLDIR}/bin/convertwarp --relout --rel --ref=${T1wImageBrain} --shiftmap=${WD}/FieldMap2${T1wImageBasename}_ShiftMap.nii.gz --shiftdir=${UnwarpDir} --out=${WD}/FieldMap2${T1wImageBasename}_Warp.nii.gz
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${T1wImage} -r ${T1wImage} -w ${WD}/FieldMap2${T1wImageBasename}_Warp.nii.gz -o ${WD}/${T1wImageBasename}

# smooth inter-/extrapolate the non-positive values in the images
[[ $SmoothFillNonPos = "TRUE" ]] && $HCPPIPEDIR_PreFS/SmoothFill.sh --in=${WD}/${T1wImageBasename}

# Make a brain image (transform to make a mask, then apply it)
${FSLDIR}/bin/applywarp --rel --interp=nn -i ${T1wImageBrain} -r ${T1wImageBrain} -w ${WD}/FieldMap2${T1wImageBasename}_Warp.nii.gz -o ${WD}/${T1wImageBrainBasename}
${FSLDIR}/bin/fslmaths ${WD}/${T1wImageBasename} -mas ${WD}/${T1wImageBrainBasename} ${WD}/${T1wImageBrainBasename}

# Copy files to specified destinations
${FSLDIR}/bin/imcp ${WD}/FieldMap2${T1wImageBasename}_Warp ${OutputT1wTransform}
${FSLDIR}/bin/imcp ${WD}/${T1wImageBasename} ${OutputT1wImage}
${FSLDIR}/bin/imcp ${WD}/${T1wImageBrainBasename} ${OutputT1wImageBrain}

# apply the same warping to the registration images
if [[ $UseRegImages = "TRUE" ]] ; then
  ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${T1wImageReg} -r ${T1wImage} -w ${WD}/FieldMap2${T1wImageBasename}_Warp.nii.gz -o ${WD}/${T1wImageBasenameReg}
  [[ $SmoothFillNonPos = "TRUE" ]] && $HCPPIPEDIR_PreFS/SmoothFill.sh --in=${WD}/${T1wImageBasenameReg}
  ${FSLDIR}/bin/fslmaths ${WD}/${T1wImageBasenameReg} -mas ${WD}/${T1wImageBrainBasename} ${WD}/${T1wImageBrainBasenameReg}
  ${FSLDIR}/bin/imcp ${WD}/${T1wImageBasenameReg} ${OutputT1wImageReg}
  ${FSLDIR}/bin/imcp ${WD}/${T1wImageBrainBasenameReg} ${OutputT1wImageBrainReg}
fi

echo " "
echo " END: ${SCRIPT_NAME}"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ##########################################

if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# Compare pre- and post-distortion correction for T1w" >> $WD/qa.txt
echo "fslview ${T1wImage} ${OutputT1wImage}" >> $WD/qa.txt

##############################################################################################
