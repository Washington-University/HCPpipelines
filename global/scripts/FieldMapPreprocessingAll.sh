#!/bin/bash -e

# Requirements for this script
#  installed versions of: FSL5.0.1 or higher, gradunwarp python package (from MGH)
#  environment: as in SetUpHCPPipeline.sh  (or individually: FSLDIR, HCPPIPEDIR_Global and PATH for gradient_unwarp.py)

################################################ SUPPORT FUNCTIONS ##################################################

Usage() {
  echo "`basename $0`: Script for generating a fieldmap suitable for FSL, and also do gradient non-linearity distortion correction of these"
  echo " "
  echo "Usage: `basename $0` [--workingdir=<working directory>]"
  echo "            --fmapmag=<input fieldmap magnitude image - can be a 4D containing more than one>"
  echo "            --fmapphase=<input fieldmap phase image - in radians>"
  echo "            --echodiff=<echo time difference for fieldmap images (in milliseconds)>"
  echo "            --ofmapmag=<output distortion corrected fieldmap magnitude image>"
  echo "            --ofmapmagbrain=<output distortion-corrected brain-extracted fieldmap magnitude image>"
  echo "            --ophase=<output distortion corrected fieldmap phase image>"
  echo "            --ofmap=<output distortion corrected fieldmap image (rad/s)>"
  echo "            [--gdcoeffs=<gradient distortion coefficients (SIEMENS file)>]"
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

# Output images (in $WD): Magnitude  Magnitude_brain Magnitude_brain_mask FieldMap  
#         Plus the following is gradient distortion correction is run:
#                         Magnitude_gdc Magnitude_gdc_warp  Magnitude_brain_gdc  Magnitude_brain_gdc_warp  
#                         Phase_gdc  Phase_gdc_warp  FieldMap_gdc  FieldMap_gdc_warp
# Output images (not in $WD):  ${MagnitudeOutput}  ${MagnitudeBrainOutput}  ${PhaseOutput}  ${FieldMapOutput}

################################################## OPTION PARSING #####################################################

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options
if [ $# -lt 5 ] ; then Usage; exit 1; fi

# parse arguments
WD=`getopt1 "--workingdir" $@` # "$1"
MagnitudeInputName=`getopt1 "--fmapmag" $@`  # "$2"
PhaseInputName=`getopt1 "--fmapphase" $@`  # "$3"
TE=`getopt1 "--echodiff" $@`  # "$4"
MagnitudeOutput=`getopt1 "--ofmapmag" $@`  # "$5"
MagnitudeBrainOutput=`getopt1 "--ofmapmagbrain" $@`  # "$6"
PhaseOutput=`getopt1 "--ophase" $@`  # "$7"
FieldMapOutput=`getopt1 "--ofmap" $@`  # "$8"
GradientDistortionCoeffs=`getopt1 "--gdcoeffs" $@`  # "$9"
#GlobalScripts="${10}"

# default parameters
GlobalScripts=${HCPPIPEDIR_Global}
WD=`defaultopt $WD .`
GradientDistortionCoeffs=`defaultopt $GradientDistortionCoeffs "NONE"`

echo " "
echo " START: Field Map Preprocessing and Gradient Unwarping"

mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt

########################################## DO WORK ########################################## 

${FSLDIR}/bin/fslmaths ${MagnitudeInputName} -Tmean ${WD}/Magnitude.nii.gz
# MJ QUERY: Change the BET parameter below to make it more conservative for the fieldmap processing?
${FSLDIR}/bin/bet ${WD}/Magnitude.nii.gz ${WD}/Magnitude_brain.nii.gz -f 0.35 -m #Brain extract the magnitude image
cp ${PhaseInputName} ${WD}/Phase.nii.gz
${FSLDIR}/bin/fsl_prepare_fieldmap SIEMENS ${WD}/Phase.nii.gz ${WD}/Magnitude_brain.nii.gz ${WD}/FieldMap.nii.gz ${TE}

echo "DONE: fmrib_prepare_fieldmap.sh"

if [ ! $GradientDistortionCoeffs = "NONE" ] ; then
  ${GlobalScripts}/GradientDistortionUnwarp.sh \
      --workingdir=${WD} \
      --coeffs=${GradientDistortionCoeffs} \
      --in=${WD}/Magnitude \
      --out=${WD}/Magnitude_gdc \
      --owarp=${WD}/Magnitude_gdc_warp
  ${GlobalScripts}/GradientDistortionUnwarp.sh \
      --workingdir=${WD} \
      --coeffs=${GradientDistortionCoeffs} \
      --in=${WD}/Magnitude_brain \
      --out=${WD}/Magnitude_brain_gdc \
      --owarp=${WD}/Magnitude_brain_gdc_warp
  ${GlobalScripts}/GradientDistortionUnwarp.sh \
      --workingdir=${WD} \
      --coeffs=${GradientDistortionCoeffs} \
      --in=${WD}/Phase \
      --out=${WD}/Phase_gdc \
      --owarp=${WD}/Phase_gdc_warp
  ${GlobalScripts}/GradientDistortionUnwarp.sh \
      --workingdir=${WD} \
      --coeffs=${GradientDistortionCoeffs} \
      --in=${WD}/FieldMap \
      --out=${WD}/FieldMap_gdc \
      --owarp=${WD}/FieldMap_gdc_warp

  # MJ QUERY: This lower bound (the lower robust range) is quite low, so this could potentially be an over-large mask.  Why not change to the standard FSL threshold of 0.1*(robust range) + robust min  ?   And why erode and dilate?!?  Is this to fill holes?
  Lower=`${FSLDIR}/bin/fslstats ${WD}/Magnitude_brain.nii.gz -r | cut -d " " -f 1`
  ${FSLDIR}/bin/fslmaths ${WD}/Magnitude_brain_gdc.nii.gz -thr $Lower -ero -dilF ${WD}/Magnitude_brain_gdc.nii.gz

  ${FSLDIR}/bin/imcp ${WD}/Magnitude_gdc ${MagnitudeOutput}
  ${FSLDIR}/bin/imcp ${WD}/Magnitude_brain_gdc ${MagnitudeBrainOutput}
  ${FSLDIR}/bin/imcp ${WD}/Phase_gdc ${PhaseOutput}
  cp ${WD}/FieldMap_gdc.nii.gz ${FieldMapOutput}.nii.gz
else
  ${FSLDIR}/bin/imcp ${WD}/Magnitude ${MagnitudeOutput}
  ${FSLDIR}/bin/imcp ${WD}/Magnitude_brain ${MagnitudeBrainOutput}
  ${FSLDIR}/bin/imcp ${WD}/Phase ${PhaseOutput}
  cp ${WD}/FieldMap.nii.gz ${FieldMapOutput}.nii.gz
fi

echo " "
echo " END: Field Map Preprocessing and Gradient Unwarping"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ########################################## 

if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# Check the brain extraction and distortion correction of the fieldmap magnitude image" >> $WD/qa.txt
echo "fslview ${WD}/Magnitude ${MagnitudeOutput} ${MagnitudeBrainOutput} -l Red -t 0.5" >> $WD/qa.txt
echo "# Check the range (largish values around 600 rad/s) and general smoothness/look of fieldmap (should be large in inferior/temporal areas mainly)" >> $WD/qa.txt
echo "fslview ${FieldMapOutput}" >> $WD/qa.txt

##############################################################################################

