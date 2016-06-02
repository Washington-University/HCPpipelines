#!/bin/bash 
set -e

# Requirements for this script
#  installed versions of: FSL (version 5.0.6), HCP-gradunwarp (version 1.0.2)
#  environment: as in SetUpHCPPipeline.sh  (or individually: FSLDIR, HCPPIPEDIR_Global, HCPPIPEDIR_Bin and PATH for gradient_unwarp.py)

################################################ SUPPORT FUNCTIONS ##################################################

# --------------------------------------------------------------------------------
#  Load Function Libraries
# --------------------------------------------------------------------------------

source $HCPPIPEDIR_Global/log.shlib # Logging related functions

Usage() {
  echo "`basename $0`: Script for using topup to do distortion correction for EPI (scout)"
  echo " "
  echo "Usage: `basename $0` [--workingdir=<working directory>]"
  echo "            --phaseone=<first set of SE EPI images: with -x PE direction (LR)>"
  echo "            --phasetwo=<second set of SE EPI images: with x PE direction (RL)>"
  echo "            --scoutin=<scout input image: should be corrected for gradient non-linear distortions>"
  echo "            --echospacing=<effective echo spacing of EPI>"
  echo "            --unwarpdir=<PE direction for unwarping: x/y/z/-x/-y/-z>"
  echo "            [--owarp=<output warpfield image: scout to distortion corrected SE EPI>]"
  echo "            [--ofmapmag=<output 'Magnitude' image: scout to distortion corrected SE EPI>]" 
  echo "            [--ofmapmagbrain=<output 'Magnitude' brain image: scout to distortion corrected SE EPI>]"   
  echo "            [--ofmap=<output scaled topup field map image>]"
  echo "            [--ojacobian=<output Jacobian image>]"
  echo "            --gdcoeffs=<gradient non-linearity distortion coefficients (Siemens format)>"
  echo "            [--topupconfig=<topup config file>]"
  echo "            --usejacobian=<\"true\" or \"false\">"
  echo " "
  echo "   Note: the input SE EPI images should not be distortion corrected (for gradient non-linearities)"
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

# --------------------------------------------------------------------------------
#  Establish tool name for logging
# --------------------------------------------------------------------------------

log_SetToolName "TopupPreprocessingAll.sh"

################################################### OUTPUT FILES #####################################################

# Output images (in $WD): 
#          BothPhases      (input to topup - combines both pe direction data, plus masking)
#          SBRef2PhaseOne_gdc.mat SBRef2PhaseOne_gdc   (linear registration result)
#          PhaseOne_gdc  PhaseTwo_gdc
#          PhaseOne_gdc_dc  PhaseOne_gdc_dc_jac  PhaseTwo_gdc_dc  PhaseTwo_gdc_dc_jac
#          SBRef_dc   SBRef_dc_jac
#          WarpField  Jacobian
# Output images (not in $WD): 
#          ${DistortionCorrectionWarpFieldOutput}  ${JacobianOutput}

################################################## OPTION PARSING #####################################################

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options
if [ $# -lt 7 ] ; then Usage; exit 1; fi

# parse arguments
WD=`getopt1 "--workingdir" $@`  # "$1"
PhaseEncodeOne=`getopt1 "--phaseone" $@`  # "$2" #SCRIPT REQUIRES LR/X-/-1 VOLUME FIRST (SAME IS TRUE OF AP/PA)
PhaseEncodeTwo=`getopt1 "--phasetwo" $@`  # "$3" #SCRIPT REQUIRES RL/X/1 VOLUME SECOND (SAME IS TRUE OF AP/PA)
ScoutInputName=`getopt1 "--scoutin" $@`  # "$4"
DwellTime=`getopt1 "--echospacing" $@`  # "$5"
UnwarpDir=`getopt1 "--unwarpdir" $@`  # "$6"
DistortionCorrectionWarpFieldOutput=`getopt1 "--owarp" $@`  # "$7"
DistortionCorrectionMagnitudeOutput=`getopt1 "--ofmapmag" $@`
DistortionCorrectionMagnitudeBrainOutput=`getopt1 "--ofmapmagbrain" $@`
DistortionCorrectionFieldOutput=`getopt1 "--ofmap" $@`
JacobianOutput=`getopt1 "--ojacobian" $@`  # "$8"
GradientDistortionCoeffs=`getopt1 "--gdcoeffs" $@`  # "$9"
TopupConfig=`getopt1 "--topupconfig" $@`  # "${11}"
UseJacobian=`getopt1 "--usejacobian" $@`

if [[ -n $HCPPIPEDEBUG ]]
then
    set -x
fi

#sanity check the jacobian option
if [[ "$UseJacobian" != "true" && "$UseJacobian" != "false" ]]
then
    log_Msg "the --usejacobian option must be 'true' or 'false'"
    exit 1
fi

GlobalScripts=${HCPPIPEDIR_Global}

# default parameters #Breaks when --owarp becomes optional
#DistortionCorrectionWarpFieldOutput=`$FSLDIR/bin/remove_ext $DistortionCorrectionWarpFieldOutput`
#WD=`defaultopt $WD ${DistortionCorrectionWarpFieldOutput}.wdir`

log_Msg "START: Topup Field Map Generation and Gradient Unwarping"

mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt

########################################## DO WORK ########################################## 

#check dimensions of phase versus sbref images
#should we also check spacing info? could be off by tiny fractions, so probably not
if [[ `fslhd $PhaseEncodeOne | grep '^dim[123]'` != `fslhd $ScoutInputName | grep '^dim[123]'` ]]
then
    log_Msg "Error: Spin echo fieldmap has different dimensions than scout image, this requires a manual fix"
    exit 1
fi
#for kicks, check that the spin echo images match
if [[ `fslhd $PhaseEncodeOne | grep '^dim[123]'` != `fslhd $PhaseEncodeTwo | grep '^dim[123]'` ]]
then
    log_Msg "Error: Spin echo fieldmap images have different dimensions!"
    exit 1
fi

# PhaseOne and PhaseTwo are sets of SE EPI images with opposite phase encodes
${FSLDIR}/bin/imcp $PhaseEncodeOne ${WD}/PhaseOne.nii.gz
${FSLDIR}/bin/imcp $PhaseEncodeTwo ${WD}/PhaseTwo.nii.gz
${FSLDIR}/bin/imcp $ScoutInputName ${WD}/SBRef.nii.gz

# Apply gradient non-linearity distortion correction to input images (SE pair)
if [ ! $GradientDistortionCoeffs = "NONE" ] ; then
  ${GlobalScripts}/GradientDistortionUnwarp.sh \
      --workingdir=${WD} \
      --coeffs=${GradientDistortionCoeffs} \
      --in=${WD}/PhaseOne \
      --out=${WD}/PhaseOne_gdc \
      --owarp=${WD}/PhaseOne_gdc_warp
  ${GlobalScripts}/GradientDistortionUnwarp.sh \
      --workingdir=${WD} \
      --coeffs=${GradientDistortionCoeffs} \
      --in=${WD}/PhaseTwo \
      --out=${WD}/PhaseTwo_gdc \
      --owarp=${WD}/PhaseTwo_gdc_warp

  if [[ $UseJacobian == "true" ]]
  then
    ${FSLDIR}/bin/fslmaths ${WD}/PhaseOne_gdc -mul ${WD}/PhaseOne_gdc_warp_jacobian ${WD}/PhaseOne_gdc
    ${FSLDIR}/bin/fslmaths ${WD}/PhaseTwo_gdc -mul ${WD}/PhaseTwo_gdc_warp_jacobian ${WD}/PhaseTwo_gdc
  fi
  #overwrites inputs, no else needed
  
  #in the below stuff, the jacobians for both phases and sbref are applied unconditionally to a separate _jac image
  #NOTE: "SBref" is actually the input scout, which is actually the _gdc scout, with gdc jacobian applied if applicable

  # Make a dilated mask in the distortion corrected space
  ${FSLDIR}/bin/fslmaths ${WD}/PhaseOne -abs -bin -dilD ${WD}/PhaseOne_mask
  ${FSLDIR}/bin/applywarp --rel --interp=nn -i ${WD}/PhaseOne_mask -r ${WD}/PhaseOne_mask -w ${WD}/PhaseOne_gdc_warp -o ${WD}/PhaseOne_mask_gdc
  ${FSLDIR}/bin/fslmaths ${WD}/PhaseTwo -abs -bin -dilD ${WD}/PhaseTwo_mask
  ${FSLDIR}/bin/applywarp --rel --interp=nn -i ${WD}/PhaseTwo_mask -r ${WD}/PhaseTwo_mask -w ${WD}/PhaseTwo_gdc_warp -o ${WD}/PhaseTwo_mask_gdc

  # Make a conservative (eroded) intersection of the two masks
  ${FSLDIR}/bin/fslmaths ${WD}/PhaseOne_mask_gdc -mas ${WD}/PhaseTwo_mask_gdc -ero -bin ${WD}/Mask
  # Merge both sets of images
  ${FSLDIR}/bin/fslmerge -t ${WD}/BothPhases ${WD}/PhaseOne_gdc ${WD}/PhaseTwo_gdc
else 
  cp ${WD}/PhaseOne.nii.gz ${WD}/PhaseOne_gdc.nii.gz
  cp ${WD}/PhaseTwo.nii.gz ${WD}/PhaseTwo_gdc.nii.gz
  fslmerge -t ${WD}/BothPhases ${WD}/PhaseOne_gdc ${WD}/PhaseTwo_gdc
  fslmaths ${WD}/PhaseOne_gdc.nii.gz -mul 0 -add 1 ${WD}/Mask
fi


# Set up text files with all necessary parameters
txtfname=${WD}/acqparams.txt
if [ -e $txtfname ] ; then
  rm $txtfname
fi

dimtOne=`${FSLDIR}/bin/fslval ${WD}/PhaseOne dim4`
dimtTwo=`${FSLDIR}/bin/fslval ${WD}/PhaseTwo dim4`

# Calculate the readout time and populate the parameter file appropriately
# X direction phase encode
if [[ $UnwarpDir = "x" || $UnwarpDir = "x-" || $UnwarpDir = "-x" ]] ; then
  dimx=`${FSLDIR}/bin/fslval ${WD}/PhaseOne dim1`
  nPEsteps=$(($dimx - 1))
  #Total_readout=Echo_spacing*(#of_PE_steps-1)
  #Note: the above calculation implies full k-space acquisition for SE EPI. In case of partial Fourier/k-space acquisition (though not recommended), $dimx-1 does not equal to nPEsteps. 
  ro_time=`echo "scale=6; ${DwellTime} * ${nPEsteps}" | bc -l` #Compute Total_readout in secs with up to 6 decimal places
  log_Msg "Total readout time is $ro_time secs"
  i=1
  while [ $i -le $dimtOne ] ; do
    echo "-1 0 0 $ro_time" >> $txtfname
    ShiftOne="x-"
    i=`echo "$i + 1" | bc`
  done
  i=1
  while [ $i -le $dimtTwo ] ; do
    echo "1 0 0 $ro_time" >> $txtfname
    ShiftTwo="x"
    i=`echo "$i + 1" | bc`
  done
# Y direction phase encode
elif [[ $UnwarpDir = "y" || $UnwarpDir = "y-" || $UnwarpDir = "-y" ]] ; then
  dimy=`${FSLDIR}/bin/fslval ${WD}/PhaseOne dim2`
  nPEsteps=$(($dimy - 1))
  #Total_readout=Echo_spacing*(#of_PE_steps-1)
  ro_time=`echo "scale=6; ${DwellTime} * ${nPEsteps}" | bc -l` #Compute Total_readout in secs with up to 6 decimal places
  i=1
  while [ $i -le $dimtOne ] ; do
    echo "0 -1 0 $ro_time" >> $txtfname
    ShiftOne="y-"
    i=`echo "$i + 1" | bc`
  done
  i=1
  while [ $i -le $dimtTwo ] ; do
    echo "0 1 0 $ro_time" >> $txtfname
    ShiftTwo="y"
    i=`echo "$i + 1" | bc`
  done
fi

#Pad in Z by one slice if odd so that topup does not complain (slice consists of zeros that will be dilated by following step)
numslice=`fslval ${WD}/BothPhases dim3`
if [ ! $(($numslice % 2)) -eq "0" ] ; then
  log_Msg "Padding Z by one slice"
  for Image in ${WD}/BothPhases ${WD}/Mask ; do
    fslroi ${Image} ${WD}/slice.nii.gz 0 -1 0 -1 0 1 0 -1
    fslmaths ${WD}/slice.nii.gz -mul 0 ${WD}/slice.nii.gz
    fslmerge -z ${Image} ${Image} ${WD}/slice.nii.gz
    rm ${WD}/slice.nii.gz
  done
fi

# Extrapolate the existing values beyond the mask (adding 1 just to avoid smoothing inside the mask)
${FSLDIR}/bin/fslmaths ${WD}/BothPhases -abs -add 1 -mas ${WD}/Mask -dilM -dilM -dilM -dilM -dilM ${WD}/BothPhases

# RUN TOPUP
# Needs FSL (version 5.0.6)
${FSLDIR}/bin/topup --imain=${WD}/BothPhases --datain=$txtfname --config=${TopupConfig} --out=${WD}/Coefficents --iout=${WD}/Magnitudes --fout=${WD}/TopupField --dfout=${WD}/WarpField --rbmout=${WD}/MotionMatrix --jacout=${WD}/Jacobian -v 

#Remove Z slice padding if needed
if [ ! $(($numslice % 2)) -eq "0" ] ; then
  log_Msg "Removing Z slice padding"
  for Image in ${WD}/BothPhases ${WD}/Mask ${WD}/Coefficents_fieldcoef ${WD}/Magnitudes ${WD}/TopupField* ${WD}/WarpField* ${WD}/Jacobian* ; do
    fslroi ${Image} ${Image} 0 -1 0 -1 0 ${numslice} 0 -1
  done
fi

# UNWARP DIR = x,y
if [[ $UnwarpDir = "x" || $UnwarpDir = "y" ]] ; then
  # select the first volume from PhaseTwo
  VolumeNumber=$(($dimtOne + 1))
  vnum=`${FSLDIR}/bin/zeropad $VolumeNumber 2`
  # register scout to SE input (PhaseTwo) + combine motion and distortion correction
  ${FSLDIR}/bin/flirt -dof 6 -interp spline -in ${WD}/SBRef.nii.gz -ref ${WD}/PhaseTwo_gdc -omat ${WD}/SBRef2PhaseTwo_gdc.mat -out ${WD}/SBRef2PhaseTwo_gdc
  ${FSLDIR}/bin/convert_xfm -omat ${WD}/SBRef2WarpField.mat -concat ${WD}/MotionMatrix_${vnum}.mat ${WD}/SBRef2PhaseTwo_gdc.mat
  ${FSLDIR}/bin/convertwarp --relout --rel -r ${WD}/PhaseTwo_gdc --premat=${WD}/SBRef2WarpField.mat --warp1=${WD}/WarpField_${vnum} --out=${WD}/WarpField.nii.gz
  ${FSLDIR}/bin/imcp ${WD}/Jacobian_${vnum}.nii.gz ${WD}/Jacobian.nii.gz
  SBRefPhase=Two
# UNWARP DIR = -x,-y
elif [[ $UnwarpDir = "x-" || $UnwarpDir = "-x" || $UnwarpDir = "y-" || $UnwarpDir = "-y" ]] ; then
  # select the first volume from PhaseOne
  VolumeNumber=$((0 + 1))
  vnum=`${FSLDIR}/bin/zeropad $VolumeNumber 2`
  # register scout to SE input (PhaseOne) + combine motion and distortion correction
  ${FSLDIR}/bin/flirt -dof 6 -interp spline -in ${WD}/SBRef.nii.gz -ref ${WD}/PhaseOne_gdc -omat ${WD}/SBRef2PhaseOne_gdc.mat -out ${WD}/SBRef2PhaseOne_gdc
  ${FSLDIR}/bin/convert_xfm -omat ${WD}/SBRef2WarpField.mat -concat ${WD}/MotionMatrix_${vnum}.mat ${WD}/SBRef2PhaseOne_gdc.mat
  ${FSLDIR}/bin/convertwarp --relout --rel -r ${WD}/PhaseOne_gdc --premat=${WD}/SBRef2WarpField.mat --warp1=${WD}/WarpField_${vnum} --out=${WD}/WarpField.nii.gz
  ${FSLDIR}/bin/imcp ${WD}/Jacobian_${vnum}.nii.gz ${WD}/Jacobian.nii.gz
  SBRefPhase=One
fi

# PhaseTwo (first vol) - warp and Jacobian modulate to get distortion corrected output
VolumeNumber=$(($dimtOne + 1))
  vnum=`${FSLDIR}/bin/zeropad $VolumeNumber 2`
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/PhaseTwo_gdc -r ${WD}/PhaseTwo_gdc --premat=${WD}/MotionMatrix_${vnum}.mat -w ${WD}/WarpField_${vnum} -o ${WD}/PhaseTwo_gdc_dc
${FSLDIR}/bin/fslmaths ${WD}/PhaseTwo_gdc_dc -mul ${WD}/Jacobian_${vnum} ${WD}/PhaseTwo_gdc_dc_jac
# PhaseOne (first vol) - warp and Jacobian modulate to get distortion corrected output
VolumeNumber=$((0 + 1))
  vnum=`${FSLDIR}/bin/zeropad $VolumeNumber 2`
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/PhaseOne_gdc -r ${WD}/PhaseOne_gdc --premat=${WD}/MotionMatrix_${vnum}.mat -w ${WD}/WarpField_${vnum} -o ${WD}/PhaseOne_gdc_dc
${FSLDIR}/bin/fslmaths ${WD}/PhaseOne_gdc_dc -mul ${WD}/Jacobian_${vnum} ${WD}/PhaseOne_gdc_dc_jac

# Scout - warp and Jacobian modulate to get distortion corrected output
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/SBRef.nii.gz -r ${WD}/SBRef.nii.gz -w ${WD}/WarpField.nii.gz -o ${WD}/SBRef_dc.nii.gz
${FSLDIR}/bin/fslmaths ${WD}/SBRef_dc.nii.gz -mul ${WD}/Jacobian.nii.gz ${WD}/SBRef_dc_jac.nii.gz

# Calculate Equivalent Field Map
${FSLDIR}/bin/fslmaths ${WD}/TopupField -mul 6.283 ${WD}/TopupField
${FSLDIR}/bin/fslmaths ${WD}/Magnitudes.nii.gz -Tmean ${WD}/Magnitude.nii.gz
${FSLDIR}/bin/bet ${WD}/Magnitude ${WD}/Magnitude_brain -f 0.35 -m #Brain extract the magnitude image

# copy images to specified outputs
if [ ! -z ${DistortionCorrectionWarpFieldOutput} ] ; then
  ${FSLDIR}/bin/imcp ${WD}/WarpField.nii.gz ${DistortionCorrectionWarpFieldOutput}.nii.gz
fi
if [ ! -z ${JacobianOutput} ] ; then
  ${FSLDIR}/bin/imcp ${WD}/Jacobian.nii.gz ${JacobianOutput}.nii.gz
fi
if [ ! -z ${DistortionCorrectionFieldOutput} ] ; then
  ${FSLDIR}/bin/imcp ${WD}/TopupField.nii.gz ${DistortionCorrectionFieldOutput}.nii.gz
fi
if [ ! -z ${DistortionCorrectionMagnitudeOutput} ] ; then
  ${FSLDIR}/bin/imcp ${WD}/Magnitude.nii.gz ${DistortionCorrectionMagnitudeOutput}.nii.gz
fi
if [ ! -z ${DistortionCorrectionMagnitudeBrainOutput} ] ; then
  ${FSLDIR}/bin/imcp ${WD}/Magnitude_brain.nii.gz ${DistortionCorrectionMagnitudeBrainOutput}.nii.gz
fi

log_Msg "END: Topup Field Map Generation and Gradient Unwarping"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ########################################## 

if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# Inspect results of various corrections (phase one)" >> $WD/qa.txt
echo "fslview ${WD}/PhaseOne ${WD}/PhaseOne_gdc ${WD}/PhaseOne_gdc_dc ${WD}/PhaseOne_gdc_dc_jac" >> $WD/qa.txt
echo "# Inspect results of various corrections (phase two)" >> $WD/qa.txt
echo "fslview ${WD}/PhaseTwo ${WD}/PhaseTwo_gdc ${WD}/PhaseTwo_gdc_dc ${WD}/PhaseTwo_gdc_dc_jac" >> $WD/qa.txt
echo "# Check linear registration of Scout to SE EPI" >> $WD/qa.txt
echo "fslview ${WD}/Phase${SBRefPhase}_gdc ${WD}/SBRef2Phase${SBRefPhase}_gdc" >> $WD/qa.txt
echo "# Inspect results of various corrections to scout" >> $WD/qa.txt
echo "fslview ${WD}/SBRef ${WD}/SBRef_dc ${WD}/SBRef_dc_jac" >> $WD/qa.txt
echo "# Visual check of warpfield and Jacobian" >> $WD/qa.txt
echo "fslview ${DistortionCorrectionWarpFieldOutput} ${JacobianOutput}" >> $WD/qa.txt


##############################################################################################



