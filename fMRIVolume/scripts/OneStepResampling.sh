#!/bin/bash 
set -e

# Requirements for this script
#  installed versions of: FSL5.0.1 or higher 
#  environment: FSLDIR

################################################ SUPPORT FUNCTIONS ##################################################

Usage() {
  echo "`basename $0`: Script to combine warps and affine transforms together and do a single resampling, with specified output resolution"
  echo " "
  echo "Usage: `basename $0` --workingdir=<working dir>"
  echo "             --infmri=<input fMRI 4D image>"
  echo "             --t1=<input T1w restored image>"
  echo "             --fmriresout=<output resolution for images, typically the fmri resolution>"
  echo "             --atlasspacedir=<output directory for several resampled images>"
  echo "             --fmri2structin=<input fMRI to T1w warp>"
  echo "             --struct2std=<input T1w to MNI warp>"
  echo "             --owarp=<output fMRI to MNI warp>"
  echo "             --motionmatdir=<input motion correcton matrix directory>"
  echo "             --motionmatprefix=<input motion correcton matrix filename prefix>"
  echo "             --ofmri=<input fMRI 4D image>"
  echo "             --freesurferbrainmask=<input FreeSurfer brain mask, nifti format in T1w space>"
  echo "             --biasfield=<input biasfield image, in T1w space>"
  echo "             --gdfield=<input warpfield for gradient non-linearity correction>"
  echo "             --scoutin=<input scout image (EPI pre-sat, before gradient non-linearity distortion correction)>"
  echo "             --oscout=<output transformed + distortion corrected scout image>"
  echo "             --jacobianin=<input Jacobian image>"
  echo "             --ojacobian=<output transformed + distortion corrected Jacobian image>"
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

# Outputs (in $WD): 
#         NB: all these images are in standard space 
#             but at the specified resolution (to match the fMRI - i.e. low-res)
#     ${T1wImageFile}${FinalfMRIResolution}  
#     ${FreeSurferBrainMaskFile}.${FinalfMRIResolution}
#     ${BiasFieldFile}.${FinalfMRIResolution}  
#     Scout_gdc_MNI_warp     : a warpfield from original (distorted) scout to low-res MNI
#
# Outputs (in ${AtlasSpaceFolder}):  - as above just copied into this folder
#     ${T1wImageFile}${FinalfMRIResolution}
#     ${FreeSurferBrainMaskFile}.${FinalfMRIResolution}
#     ${BiasFieldFile}.${FinalfMRIResolution}

# Outputs (not in either of the above):
#     ${OutputTransform}  : the warpfield from fMRI to standard (low-res)
#     ${OutputfMRI}       
#     ${JacobianOut}
#     ${ScoutOutput}
#          NB: last three images are all in low-res standard space

################################################## OPTION PARSING #####################################################

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options
if [ $# -lt 12 ] ; then Usage; exit 1; fi

# parse arguments
WD=`getopt1 "--workingdir" $@`  # "$1"
InputfMRI=`getopt1 "--infmri" $@`  # "$2"
T1wImage=`getopt1 "--t1" $@`  # "$3"
FinalfMRIResolution=`getopt1 "--fmriresout" $@`  # "$4"
AtlasSpaceFolder=`getopt1 "--atlasspacedir" $@`  # "$5"
fMRIToStructuralInput=`getopt1 "--fmri2structin" $@`  # "$6"
StructuralToStandard=`getopt1 "--struct2std" $@`  # "$7"
OutputTransform=`getopt1 "--owarp" $@`  # "$8"
MotionMatrixFolder=`getopt1 "--motionmatdir" $@`  # "$9"
MotionMatrixPrefix=`getopt1 "--motionmatprefix" $@`  # "${10}"
OutputfMRI=`getopt1 "--ofmri" $@`  # "${11}"
FreeSurferBrainMask=`getopt1 "--freesurferbrainmask" $@`  # "${12}"
BiasField=`getopt1 "--biasfield" $@`  # "${13}"
GradientDistortionField=`getopt1 "--gdfield" $@`  # "${14}"
ScoutInput=`getopt1 "--scoutin" $@`  # "${15}"
ScoutOutput=`getopt1 "--oscout" $@`  # "${16}"
JacobianIn=`getopt1 "--jacobianin" $@`  # "${17}"
JacobianOut=`getopt1 "--ojacobian" $@`  # "${18}"

BiasFieldFile=`basename "$BiasField"`
T1wImageFile=`basename $T1wImage`
FreeSurferBrainMaskFile=`basename "$FreeSurferBrainMask"`

echo " "
echo " START: OneStepResampling"

mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt


########################################## DO WORK ########################################## 

#Save TR for later
TR_vol=`${FSLDIR}/bin/fslval ${InputfMRI} pixdim4 | cut -d " " -f 1`
NumFrames=`${FSLDIR}/bin/fslval ${InputfMRI} dim4`

# Create fMRI resolution standard space files for T1w image, wmparc, and brain mask
#   NB: don't use FLIRT to do spline interpolation with -applyisoxfm for the 
#       2mm and 1mm cases because it doesn't know the peculiarities of the 
#       MNI template FOVs
if [ ${FinalfMRIResolution} = "2" ] ; then
    ResampRefIm=$FSLDIR/data/standard/MNI152_T1_2mm
elif [ ${FinalfMRIResolution} = "1" ] ; then
    ResampRefIm=$FSLDIR/data/standard/MNI152_T1_1mm
else
  ${FSLDIR}/bin/flirt -interp spline -in ${T1wImage} -ref ${T1wImage} -applyisoxfm $FinalfMRIResolution -out ${WD}/${T1wImageFile}${FinalfMRIResolution}
    ResampRefIm=${WD}/${T1wImageFile}${FinalfMRIResolution} 
fi
  ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${T1wImage} -r ${ResampRefIm} --premat=$FSLDIR/etc/flirtsch/ident.mat -o ${WD}/${T1wImageFile}${FinalfMRIResolution}

# Create brain masks in this space from the FreeSurfer output (changing resolution)
${FSLDIR}/bin/applywarp --rel --interp=nn -i ${FreeSurferBrainMask}.nii.gz -r ${WD}/${T1wImageFile}${FinalfMRIResolution} --premat=$FSLDIR/etc/flirtsch/ident.mat -o ${WD}/${FreeSurferBrainMaskFile}.${FinalfMRIResolution}.nii.gz
${FSLDIR}/bin/fslmaths ${WD}/${T1wImageFile}${FinalfMRIResolution} -mas ${WD}/${FreeSurferBrainMaskFile}.${FinalfMRIResolution}.nii.gz ${WD}/${FreeSurferBrainMaskFile}.${FinalfMRIResolution}.nii.gz

# Create versions of the biasfield (changing resolution)
# MJ QUERY : Do we want spline interpolation of the bias field?!  Surely trilinear would be better here to avoid ringing in case any small discontinuities snuck through
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${BiasField} -r ${WD}/${FreeSurferBrainMaskFile}.${FinalfMRIResolution}.nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o ${WD}/${BiasFieldFile}.${FinalfMRIResolution}
${FSLDIR}/bin/fslmaths ${WD}/${BiasFieldFile}.${FinalfMRIResolution} -thr 0.1 ${WD}/${BiasFieldFile}.${FinalfMRIResolution}

# Downsample warpfield (fMRI to standard) to increase speed 
#   NB: warpfield resolution is 10mm, so 1mm to fMRIres downsample loses no precision
${FSLDIR}/bin/convertwarp --relout --rel --warp1=${fMRIToStructuralInput} --warp2=${StructuralToStandard} --ref=${WD}/${T1wImageFile}${FinalfMRIResolution} --out=${OutputTransform}

# Copy warped T1w images and masks into the AtlasSpaceFolder
#  NB: as this only needs to be done once (not per task) it uses a "lock" file 
#      to prevent parallel invocations  (but not critical if multiple copies occurs)
if [ ! -e ${AtlasSpaceFolder}/ISCOPYING ] ; then  
  touch ${AtlasSpaceFolder}/ISCOPYING
  cp ${WD}/${T1wImageFile}${FinalfMRIResolution}.nii.gz ${AtlasSpaceFolder}/${T1wImageFile}${FinalfMRIResolution}.nii.gz
  cp ${WD}/${FreeSurferBrainMaskFile}.${FinalfMRIResolution}.nii.gz ${AtlasSpaceFolder}/${FreeSurferBrainMaskFile}.${FinalfMRIResolution}.nii.gz
  cp ${WD}/${BiasFieldFile}.${FinalfMRIResolution}.nii.gz ${AtlasSpaceFolder}/${BiasFieldFile}.${FinalfMRIResolution}.nii.gz
  rm ${AtlasSpaceFolder}/ISCOPYING
fi

mkdir -p ${WD}/prevols
mkdir -p ${WD}/postvols

# Apply combined transformations to fMRI (combines gradient non-linearity distortion, motion correction, and registration to T1w space, but keeping fMRI resolution)
${FSLDIR}/bin/fslsplit ${InputfMRI} ${WD}/prevols/vol -t
FrameMergeSTRING=""
k=0
while [ $k -lt $NumFrames ] ; do
  vnum=`${FSLDIR}/bin/zeropad $k 4`
  ${FSLDIR}/bin/convertwarp --relout --rel --ref=${WD}/prevols/vol${vnum}.nii.gz --warp1=${GradientDistortionField} --postmat=${MotionMatrixFolder}/${MotionMatrixPrefix}${vnum} --out=${MotionMatrixFolder}/${MotionMatrixPrefix}${vnum}_gdc_warp.nii.gz
  ${FSLDIR}/bin/convertwarp --relout --rel --ref=${WD}/${T1wImageFile}${FinalfMRIResolution} --warp1=${MotionMatrixFolder}/${MotionMatrixPrefix}${vnum}_gdc_warp.nii.gz --warp2=${OutputTransform} --out=${MotionMatrixFolder}/${MotionMatrixPrefix}${vnum}_all_warp.nii.gz
  ${FSLDIR}/bin/applywarp --rel --interp=spline --in=${WD}/prevols/vol${vnum}.nii.gz --warp=${MotionMatrixFolder}/${MotionMatrixPrefix}${vnum}_all_warp.nii.gz --ref=${WD}/${T1wImageFile}${FinalfMRIResolution} --out=${WD}/postvols/vol${k}.nii.gz
  FrameMergeSTRING="${FrameMergeSTRING}${WD}/postvols/vol${k}.nii.gz " 
  k=`echo "$k + 1" | bc`
done
# Merge together results and restore the TR (saved beforehand)
${FSLDIR}/bin/fslmerge -tr ${OutputfMRI} $FrameMergeSTRING $TR_vol

# Combine transformations: gradient non-linearity distortion + fMRI_dc to standard
${FSLDIR}/bin/convertwarp --relout --rel --ref=${WD}/${T1wImageFile}${FinalfMRIResolution} --warp1=${GradientDistortionField} --warp2=${OutputTransform} --out=${WD}/Scout_gdc_MNI_warp.nii.gz
${FSLDIR}/bin/applywarp --rel --interp=spline --in=${ScoutInput} -w ${WD}/Scout_gdc_MNI_warp.nii.gz -r ${WD}/${T1wImageFile}${FinalfMRIResolution} -o ${ScoutOutput}
# Create spline interpolated version of Jacobian  (T1w space, fMRI resolution)
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${JacobianIn} -r ${WD}/${T1wImageFile}${FinalfMRIResolution} -w ${StructuralToStandard} -o ${JacobianOut}

echo " "
echo "END: OneStepResampling"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ########################################## 

if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# Check registrations to low-res standard space" >> $WD/qa.txt
echo "fslview ${WD}/${T1wImageFile}${FinalfMRIResolution} ${WD}/${FreeSurferBrainMaskFile}.${FinalfMRIResolution} ${WD}/${BiasFieldFile}.${FinalfMRIResolution} ${OutputfMRI}" >> $WD/qa.txt

##############################################################################################


