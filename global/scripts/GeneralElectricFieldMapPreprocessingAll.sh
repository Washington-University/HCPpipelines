#!/bin/bash 

set -e

# Requirements for this script
#  installed versions of: FSL5.0.1 or higher, gradunwarp python package (from MGH)
#  environment: as in SetUpHCPPipeline.sh  (or individually: FSLDIR, HCPPIPEDIR_Global and PATH for gradient_unwarp.py)

################################################ SUPPORT FUNCTIONS ##################################################

Usage() {
  echo "`basename $0`: Script for generating a fieldmap suitable for FSL from General Electric Gradient Echo field map,"
  echo "               and also do gradient non-linearity distortion correction of these"
  echo " "
  echo "Usage: `basename $0` "
  echo "            [--workingdir=<working directory>]"
  echo "            --fmap=<input General Electric fieldmap with fieldmap in deg and magnitude image>"
  echo "            --ofmapmag=<output distortion corrected fieldmap magnitude image>"
  echo "            --ofmapmagbrain=<output distortion-corrected brain-extracted fieldmap magnitude image>"
  echo "            --ofmap=<output distortion corrected fieldmap image (rad/s)>"
  echo "            [--gdcoeffs=<input gradient distortion coefficients file>]"
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
#         Plus the following if gradient distortion correction is run:
#                         Magnitude_gdc Magnitude_gdc_warp  Magnitude_brain_gdc FieldMap_gdc  
# Output images (not in $WD):  ${MagnitudeOutput}  ${MagnitudeBrainOutput}  ${FieldMapOutput}

################################################## OPTION PARSING #####################################################

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options
if [ $# -lt 5 ] ; then Usage; exit 1; fi

# parse arguments
WD=`getopt1 "--workingdir" $@`
GEB0InputName=`getopt1 "--fmap" $@`
MagnitudeOutput=`getopt1 "--ofmapmag" $@`
MagnitudeBrainOutput=`getopt1 "--ofmapmagbrain" $@`
FieldMapOutput=`getopt1 "--ofmap" $@`
GradientDistortionCoeffs=`getopt1 "--gdcoeffs" $@`

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

${FSLDIR}/bin/fslsplit ${GEB0InputName}     # split image into vol0000=fieldmap and vol0001=magnitude
mv vol0000.nii.gz ${WD}/FieldMap_deg.nii.gz
mv vol0001.nii.gz ${WD}/Magnitude.nii.gz
${FSLDIR}/bin/bet ${WD}/Magnitude ${WD}/Magnitude_brain -f 0.35 -m #Brain extract the magnitude image
${FSLDIR}/bin/fslmaths ${WD}/FieldMap_deg.nii.gz -mul 6.28 ${WD}/FieldMap.nii.gz

echo "DONE: preparing General Electric fieldmap"

if [ ! $GradientDistortionCoeffs = "NONE" ] ; then
  ${GlobalScripts}/GradientDistortionUnwarp.sh \
      --workingdir=${WD} \
      --coeffs=${GradientDistortionCoeffs} \
      --in=${WD}/Magnitude \
      --out=${WD}/Magnitude_gdc \
      --owarp=${WD}/Magnitude_gdc_warp
      
  ${FSLDIR}/bin/applywarp --rel --interp=nn -i ${WD}/Magnitude_brain -r ${WD}/Magnitude_brain -w ${WD}/Magnitude_gdc_warp -o ${WD}/Magnitude_brain_gdc
  ${FSLDIR}/bin/fslmaths ${WD}/Magnitude_gdc -mas ${WD}/Magnitude_brain_gdc ${WD}/Magnitude_brain_gdc
  ${FSLDIR}/bin/fslmaths ${WD}/Magnitude_brain_gdc -bin -ero -ero ${WD}/Magnitude_brain_gdc_ero
  ${FSLDIR}/bin/fslmaths ${WD}/FieldMap -mas ${WD}/Magnitude_brain_gdc_ero -dilM -dilM -dilM -dilM -dilM ${WD}/FieldMap_dil
  ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/FieldMap_dil -r ${WD}/FieldMap_dil -w ${WD}/Magnitude_gdc_warp -o ${WD}/FieldMap_gdc
  ${FSLDIR}/bin/fslmaths ${WD}/FieldMap_gdc -mas ${WD}/Magnitude_brain_gdc ${WD}/FieldMap_gdc

  ${FSLDIR}/bin/imcp ${WD}/Magnitude_gdc ${MagnitudeOutput}
  ${FSLDIR}/bin/imcp ${WD}/Magnitude_brain_gdc ${MagnitudeBrainOutput}
  cp ${WD}/FieldMap_gdc.nii.gz ${FieldMapOutput}.nii.gz
else
  ${FSLDIR}/bin/imcp ${WD}/Magnitude ${MagnitudeOutput}
  ${FSLDIR}/bin/imcp ${WD}/Magnitude_brain ${MagnitudeBrainOutput}
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

