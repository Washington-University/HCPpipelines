#!/bin/bash 
set -e

# Requirements for this script
#  installed versions of: FSL5.0.1 and FreeSurfer 5.1 or later versions
#  environment: FSLDIR, FREESURFER_HOME + others

################################################ SUPPORT FUNCTIONS ##################################################

Usage() {
  echo "`basename $0`: Script to register EPI to T1w, with distortion correction"
  echo " "
  echo "Usage: `basename $0` [--workingdir=<working dir>]"
  echo "             --scoutin=<input scout image (pre-sat EPI)>"
  echo "             --t1=<input T1-weighted image>"
  echo "             --t1restore=<input bias-corrected T1-weighted image>"
  echo "             --t1brain=<input bias-corrected, brain-extracted T1-weighted image>"
  echo "             --fmapmag=<input fieldmap magnitude image>"
  echo "             --fmapphase=<input fieldmap phase image>"
  echo "             --echodiff=<difference of echo times for fieldmap, in milliseconds>"
  echo "             --echospacing=<effective echo spacing of fMRI image, in seconds>"
  echo "             --unwarpdir=<unwarping direction: x/y/z/-x/-y/-z>"
  echo "             --owarp=<output filename for warp of EPI to T1w>"
  echo "             --biasfield=<input bias field estimate image, in fMRI space>"
  echo "             --oregim=<output registered image (EPI to T1w)>"
  echo "             --freesurferfolder=<directory of FreeSurfer folder>"
  echo "             --freesurfersubjectid=<FreeSurfer Subject ID>"
  echo "             --gdcoeffs=<gradient non-linearity distortion coefficients (Siemens format)>"
  echo "             --t2restore=<input bias-corrected T2-weighted image>"
  echo "             [--fnirtconfig=<FNIRT config file>]"
  echo "             [--qaimage=<output name for QA image>]"
  echo "             --method=<method used for distortion correction: FIELDMAP or TOPUP>"
  echo "             [--topupconfig=<topup config file>]"
  echo "             --ojacobian=<output filename for Jacobian image (in T1w space)>"

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
#  
#    FIELDMAP section only: 
#      Magnitude  Magnitude_brain  FieldMap
#
#    FIELDMAP and TOPUP sections: 
#      Jacobian2T1w
#      ${ScoutInputFile}_undistorted  
#      ${ScoutInputFile}_undistorted2T1w_init   
#      ${ScoutInputFile}_undistorted_warp
#
#    FreeSurfer section: 
#      fMRI2str.mat  fMRI2str
#      ${ScoutInputFile}_undistorted2T1w  
#
#    Fnirt (z-blip correction) only:  
#      fMRI_zblip2str
#      ${ScoutInputFile}_undistorted2T1w_zblip
#      ${ScoutInputFile}_undistorted2T1w_zblip_warp
#
# Outputs (not in $WD):
#
#       ${RegOutput}  ${OutputTransform}  ${JacobianOut}  ${QAImage}



################################################## OPTION PARSING #####################################################

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options
if [ $# -lt 21 ] ; then Usage; exit 1; fi

# parse arguments
WD=`getopt1 "--workingdir" $@`  # "$1"
ScoutInputName=`getopt1 "--scoutin" $@`  # "$2"
# MJ QUERY: Is the T1wImage necessary if we have a restored version?!?
T1wImage=`getopt1 "--t1" $@`  # "$3"
T1wRestoreImage=`getopt1 "--t1restore" $@`  # "$4"
T1wBrainImage=`getopt1 "--t1brain" $@`  # "$5"
MagnitudeInputName=`getopt1 "--fmapmag" $@`  # "$6"
PhaseInputName=`getopt1 "--fmapphase" $@`  # "$7"
TE=`getopt1 "--echodiff" $@`  # "$8"
DwellTime=`getopt1 "--echospacing" $@`  # "$9"
UnwarpDir=`getopt1 "--unwarpdir" $@`  # "${10}"
OutputTransform=`getopt1 "--owarp" $@`  # "${11}"
BiasField=`getopt1 "--biasfield" $@`  # "${12}"
RegOutput=`getopt1 "--oregim" $@`  # "${13}"
FreeSurferSubjectFolder=`getopt1 "--freesurferfolder" $@`  # "${14}"
FreeSurferSubjectID=`getopt1 "--freesurfersubjectid" $@`  # "${15}"
#GlobalScripts=`getopt1 "--globalscripts" $@`  # "${16}"
GradientDistortionCoeffs=`getopt1 "--gdcoeffs" $@`  # "${17}"
T2wRestoreImage=`getopt1 "--t2restore" $@`  # "${18}"
FNIRTConfig=`getopt1 "--fnirtconfig" $@`  # "${19}"
QAImage=`getopt1 "--qaimage" $@`  # "${20}"
DistortionCorrection=`getopt1 "--method" $@`  # "${21}"
TopupConfig=`getopt1 "--topupconfig" $@`  # "${22}"
JacobianOut=`getopt1 "--ojacobian" $@`  # "${23}"
#GlobalBinaries=`getopt1 "--globalbinaries" $@`  # "${24}"

ScoutInputFile=`basename $ScoutInputName`
T1wBrainImageFile=`basename $T1wBrainImage`


# default parameters
RegOutput=`$FSLDIR/bin/remove_ext $RegOutput`
WD=`defaultopt $WD ${RegOutput}.wdir`
GlobalScripts=${HCPPIPEDIR_Global}
GlobalBinaries=${HCPPIPEDIR_Bin}
FNIRTConfig=`defaultopt $FNIRTConfig "NONE"`   # NONE = turn off z-blip corrections!
TopupConfig=`defaultopt $TopupConfig ${HCPPIPEDIR_Config}/b02b0.cnf`
UseJacobian=false

echo " "
echo " START: DistortionCorrectionEpiToT1wReg_FLIRTBBRAndFreeSurferBBRBased"

mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt

if [ ! -e ${WD}/FieldMap ] ; then
  mkdir ${WD}/FieldMap
fi

########################################## DO WORK ########################################## 

cp ${T1wBrainImage}.nii.gz ${WD}/${T1wBrainImageFile}.nii.gz

###### FIELDMAP VERSION (GE FIELDMAPS) ######
if [ $DistortionCorrection = "FIELDMAP" ] ; then
  # process fieldmap with gradient non-linearity distortion correction
  ${GlobalScripts}/FieldMapPreprocessingAll.sh \
      --workingdir=${WD}/FieldMap \
      --fmapmag=${MagnitudeInputName} \
      --fmapphase=${PhaseInputName} \
      --echodiff=${TE} \
      --ofmapmag=${WD}/Magnitude \
      --ofmapmagbrain=${WD}/Magnitude_brain \
      --ophase=${WD}/Phase \
      --ofmap=${WD}/FieldMap \
      --gdcoeffs=${GradientDistortionCoeffs}
  # register scout to T1w image using fieldmap
  ${FSLDIR}/bin/epi_reg --epi=${ScoutInputName} --t1=${T1wImage} --t1brain=${WD}/${T1wBrainImageFile} --out=${WD}/${ScoutInputFile}_undistorted --fmap=${WD}/FieldMap.nii.gz --fmapmag=${WD}/Magnitude.nii.gz --fmapmagbrain=${WD}/Magnitude_brain.nii.gz --echospacing=${DwellTime} --pedir=${UnwarpDir}
  # convert epi_reg warpfield from abs to rel convention (NB: this is the current convention for epi_reg but it may change in the future, or take an option)
  ${FSLDIR}/bin/immv ${WD}/${ScoutInputFile}_undistorted_warp ${WD}/${ScoutInputFile}_undistorted_warp_abs
  ${FSLDIR}/bin/convertwarp --relout --abs -r ${WD}/${ScoutInputFile}_undistorted_warp_abs -w ${WD}/${ScoutInputFile}_undistorted_warp_abs -o ${WD}/${ScoutInputFile}_undistorted_warp
  # create spline interpolated output for scout to T1w + apply bias field correction
  ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${ScoutInputName} -r ${T1wImage} -w ${WD}/${ScoutInputFile}_undistorted_warp.nii.gz -o ${WD}/${ScoutInputFile}_undistorted_1vol.nii.gz
  ${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFile}_undistorted_1vol.nii.gz -div ${BiasField} ${WD}/${ScoutInputFile}_undistorted_1vol.nii.gz
  ${FSLDIR}/bin/immv ${WD}/${ScoutInputFile}_undistorted_1vol.nii.gz ${WD}/${ScoutInputFile}_undistorted2T1w_init.nii.gz
  ###Jacobian Volume FAKED for Regular Fieldmaps (all ones) ###
  ${FSLDIR}/bin/fslmaths ${T1wImage} -abs -add 1 -bin ${WD}/Jacobian2T1w.nii.gz
    
###### TOPUP VERSION (SE FIELDMAPS) ######
elif [ $DistortionCorrection = "TOPUP" ] ; then
  # MJ QUERY : Why is the following command commented out?
  #PhaseEncodeOne is MagnitudeInputName, PhaseEncodeTwo is PhaseInputName
  #${GlobalScripts}/TopupPreprocessingAll.sh ${WD}/FieldMap ${MagnitudeInputName} ${PhaseInputName} ${DwellTime} ${UnwarpDir} ${WD}/Magnitude ${WD}/Magnitude_brain ${WD}/TopupField ${WD}/FieldMap ${GradientDistortionCoeffs} ${GlobalScripts} ${TopupConfig}
  # Use topup to distortion correct the scout scans
  #    using a blip-reversed SE pair "fieldmap" sequence
  ${GlobalScripts}/TopupPreprocessingAll.sh \
      --workingdir=${WD}/FieldMap \
      --phaseone=${MagnitudeInputName} \
      --phasetwo=${PhaseInputName} \
      --scoutin=${ScoutInputName} \
      --echospacing=${DwellTime} \
      --unwarpdir=${UnwarpDir} \
      --owarp=${WD}/WarpField \
      --ojacobian=${WD}/Jacobian \
      --gdcoeffs=${GradientDistortionCoeffs} \
      --topupconfig=${TopupConfig}
#      ${GlobalScripts} \
#      ${GlobalBinaries}

  # create a spline interpolated image of scout (distortion corrected in same space)
  ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${ScoutInputName} -r ${ScoutInputName} -w ${WD}/WarpField.nii.gz -o ${WD}/${ScoutInputFile}_undistorted
  # apply Jacobian correction to scout image (optional)
  if [ $UseJacobian = true ] ; then
      ${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFile}_undistorted -mul ${WD}/Jacobian.nii.gz ${WD}/${ScoutInputFile}_undistorted
  fi
  # register undistorted scout image to T1w
  ${FSLDIR}/bin/epi_reg --epi=${WD}/${ScoutInputFile}_undistorted --t1=${T1wImage} --t1brain=${WD}/${T1wBrainImageFile} --out=${WD}/${ScoutInputFile}_undistorted
  # generate combined warpfields and spline interpolated images + apply bias field correction
  ${FSLDIR}/bin/convertwarp --relout --rel -r ${T1wImage} --warp1=${WD}/WarpField.nii.gz --postmat=${WD}/${ScoutInputFile}_undistorted.mat -o ${WD}/${ScoutInputFile}_undistorted_warp
  ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/Jacobian.nii.gz -r ${T1wImage} --premat=${WD}/${ScoutInputFile}_undistorted.mat -o ${WD}/Jacobian2T1w.nii.gz
  ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${ScoutInputName} -r ${T1wImage} -w ${WD}/${ScoutInputFile}_undistorted_warp -o ${WD}/${ScoutInputFile}_undistorted
  # apply Jacobian correction to scout image (optional)
  if [ $UseJacobian = true ] ; then
      ${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFile}_undistorted -div ${BiasField} -mul ${WD}/Jacobian2T1w.nii.gz ${WD}/${ScoutInputFile}_undistorted2T1w_init.nii.gz 
  else
      ${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFile}_undistorted -div ${BiasField} ${WD}/${ScoutInputFile}_undistorted2T1w_init.nii.gz 
  fi
else
  echo "UNKNOWN DISTORTION CORRECTION METHOD"
  exit
fi

# MJ QUERY : Why is this commented out now?
#Robust way to get ${WD}/Magnitude_brain
#${FSLDIR}/bin/epi_reg --epi=${WD}/Magnitude --t1=${T1wImage} --t1brain=${WD}/${T1wBrainImageFile} --out=${WD}/Magnitude2str
#${FSLDIR}/bin/convert_xfm -omat ${WD}/str2Magnitude.mat -inverse ${WD}/Magnitude2str.mat
#${FSLDIR}/bin/applywarp --rel --interp=nn -i ${WD}/${T1wBrainImageFile} -r ${WD}/Magnitude --premat=${WD}/str2Magnitude.mat -o ${WD}/Magnitude_brain
#${FSLDIR}/bin/fslmaths ${WD}/Magnitude -mas ${WD}/Magnitude_brain ${WD}/Magnitude_brain


### FREESURFER BBR - found to be an improvement, probably due to better GM/WM boundary
SUBJECTS_DIR=${FreeSurferSubjectFolder}
export SUBJECTS_DIR
${FREESURFER_HOME}/bin/bbregister --s ${FreeSurferSubjectID} --mov ${WD}/${ScoutInputFile}_undistorted2T1w_init.nii.gz --surf white.deformed --init-reg ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}/mri/transforms/eye.dat --bold --reg ${WD}/EPItoT1w.dat --o ${WD}/${ScoutInputFile}_undistorted2T1w.nii.gz
# Create FSL-style matrix and then combine with existing warp fields
${FREESURFER_HOME}/bin/tkregister2 --noedit --reg ${WD}/EPItoT1w.dat --mov ${WD}/${ScoutInputFile}_undistorted2T1w_init.nii.gz --targ ${T1wImage}.nii.gz --fslregout ${WD}/fMRI2str.mat
${FSLDIR}/bin/convertwarp --relout --rel --warp1=${WD}/${ScoutInputFile}_undistorted_warp.nii.gz --ref=${T1wImage} --postmat=${WD}/fMRI2str.mat --out=${WD}/fMRI2str.nii.gz
# Create warped image with spline interpolation, bias correction and (optional) Jacobian modulation
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${ScoutInputName} -r ${T1wImage}.nii.gz -w ${WD}/fMRI2str.nii.gz -o ${WD}/${ScoutInputFile}_undistorted2T1w
if [ $UseJacobian = true ] ; then
    ${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFile}_undistorted2T1w -div ${BiasField} -mul ${WD}/Jacobian2T1w.nii.gz ${WD}/${ScoutInputFile}_undistorted2T1w
else
    ${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFile}_undistorted2T1w -div ${BiasField} ${WD}/${ScoutInputFile}_undistorted2T1w
fi


# Perform z-blip distortion correction via non-linear registration if an appropriate FNIRT configuration is provided  (ideally this should not be necessary as reconstruction/fieldmap-correction should already correct for this, but it was initially found that the traditional fieldmaps failed to adequately cope with this - possibly an interaction with the strong gradient non-linearities)
if [ ${FNIRTConfig} != "NONE" ] ; then
  # Generate mask from current scout image (in T1w space)
  #     based on threshold = mean - 1.0*std
  Mean=`${FSLDIR}/bin/fslstats ${WD}/${ScoutInputFile}_undistorted2T1w -k ${T1wBrainImage}.nii.gz -M`
  Std=`${FSLDIR}/bin/fslstats ${WD}/${ScoutInputFile}_undistorted2T1w -k ${T1wBrainImage}.nii.gz -S`
  Lower=`echo ${Mean - $Std} | bc -l`
  ${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFile}_undistorted2T1w -thr $Lower -bin ${WD}/inmask.nii.gz
  ${FSLDIR}/bin/fslmaths ${T1wBrainImage}.nii.gz -bin ${WD}/refmask.nii.gz
  ${FSLDIR}/bin/fslmaths ${WD}/inmask.nii.gz -mas ${WD}/refmask.nii.gz ${WD}/inmask.nii.gz
  ${FSLDIR}/bin/fslmaths ${WD}/refmask.nii.gz -mas ${WD}/inmask.nii.gz ${WD}/refmask.nii.gz
  # main fnirt call for non-linear registration of scout (already "undistorted") to the subject's T2w scan
  ${FSLDIR}/bin/fnirt --in=${WD}/${ScoutInputFile}_undistorted2T1w --ref=${T2wRestoreImage} --inmask=${WD}/inmask.nii.gz --refmask=${WD}/refmask.nii.gz --applyinmask=1 --applyrefmask=1 --config=${FNIRTConfig} --iout=${WD}/${ScoutInputFile}_undistorted2T1w_zblip.nii.gz --fout=${WD}/${ScoutInputFile}_undistorted2T1w_zblip_warp.nii.gz
  # make combined warpfield, do spline interpolation, bias field correction and Jacobian modulation (optional)
  ${FSLDIR}/bin/convertwarp --relout --rel --ref=${WD}/${ScoutInputFile}_undistorted2T1w_zblip.nii.gz --warp1=${WD}/fMRI2str.nii.gz --warp2=${WD}/${ScoutInputFile}_undistorted2T1w_zblip_warp.nii.gz --out=${WD}/fMRI_zblip2str.nii.gz
  ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${ScoutInputName} -r ${T1wImage}.nii.gz -w ${WD}/fMRI_zblip2str.nii.gz -o ${WD}/${ScoutInputFile}_undistorted2T1w_zblip.nii.gz
  if [ $UseJacobian = true ] ; then  # Jacobian modulation
      ${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFile}_undistorted2T1w_zblip.nii.gz -div ${BiasField} -mul ${WD}/Jacobian2T1w.nii.gz ${WD}/${ScoutInputFile}_undistorted2T1w_zblip.nii.gz
  else # Jacobian
      ${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFile}_undistorted2T1w_zblip.nii.gz -div ${BiasField} ${WD}/${ScoutInputFile}_undistorted2T1w_zblip.nii.gz
  fi  # Jacobian
  cp ${WD}/${ScoutInputFile}_undistorted2T1w_zblip.nii.gz ${RegOutput}.nii.gz
  cp ${WD}/fMRI_zblip2str.nii.gz ${OutputTransform}.nii.gz
else
  # Copy files to specified outputs if not doing z-blip non-linear correction
  cp ${WD}/${ScoutInputFile}_undistorted2T1w.nii.gz ${RegOutput}.nii.gz
  cp ${WD}/fMRI2str.nii.gz ${OutputTransform}.nii.gz
  cp ${WD}/Jacobian2T1w.nii.gz ${JacobianOut}.nii.gz
fi


# QA image (sqrt of EPI * T1w)
${FSLDIR}/bin/fslmaths ${T1wRestoreImage}.nii.gz -mul ${RegOutput}.nii.gz -sqrt ${QAImage}.nii.gz

echo " "
echo " END: DistortionCorrectionEpiToT1wReg_FLIRTBBRAndFreeSurferBBRBased"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ########################################## 

if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# Check registration of EPI to T1w (with all corrections applied)" >> $WD/qa.txt
echo "fslview ${T1wRestoreImage} ${RegOutput} ${QAImage}" >> $WD/qa.txt
echo "# Check undistortion of the scout image" >> $WD/qa.txt
echo "fslview `dirname ${ScoutInputName}`/GradientDistortionUnwarp/Scout ${WD}/${ScoutInputFile}_undistorted" >> $WD/qa.txt

if [ ${FNIRTConfig} != "NONE" ] ; then
    echo "# Check (optional) z-blip correction output" >> $WD/qa.txt
    echo "fslview ${WD}/${ScoutInputFile}_undistorted2T1w ${WD}/${ScoutInputFile}_undistorted2T1w_zblip" >> $WD/qa.txt
fi
##############################################################################################

