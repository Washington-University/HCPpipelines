#!/bin/bash 

# Requirements for this script
#  installed versions of: FSL
#  environment: HCPPIPEDIR, FSLDIR

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

script_name=$(basename "${0}")

show_usage() {
	cat <<EOF

${script_name}: Script to combine warps and affine transforms together and do a single resampling, with specified output resolution

Usage: ${script_name} [options]

  --workingdir=<working dir>
  --infmri=<input fMRI 4D image>
  --t1=<input T1w restored image>
  --fmriresout=<output resolution for images, typically the fmri resolution>
  --fmrifolder=<fMRI processing folder>
  --fmri2structin=<input fMRI to T1w warp>
  --struct2std=<input T1w to MNI warp>
  --owarp=<output fMRI to MNI warp>
  --oiwarp=<output MNI to fMRI warp>
  --motionmatdir=<input motion correcton matrix directory>
  --motionmatprefix=<input motion correcton matrix filename prefix>
  --ofmri=<input fMRI 4D image>
  --freesurferbrainmask=<input FreeSurfer brain mask, nifti format in atlas (MNI152) space>
  --biasfield=<input biasfield image, in atlas (MNI152) space>
  --gdfield=<input warpfield for gradient non-linearity correction>
  --scoutin=<input scout image (EPI pre-sat, before gradient non-linearity distortion correction)>
  --scoutgdcin=<input scout gradient nonlinearity distortion corrected image (EPI pre-sat)>
  --oscout=<output transformed + distortion corrected scout image>
  --ojacobian=<output transformed + distortion corrected Jacobian image>
  [--fmrirefpath=<path to an external BOLD reference or NONE (default)>]
  [--fmrirefreg=<whether to do 'linear', 'nonlinear' or no ('NONE', default) registration to external BOLD reference image>]

EOF
}

# Allow script to return a Usage statement, before any other output or checking
if [ "$#" = "0" ]; then
    show_usage
    exit 1
fi

# ------------------------------------------------------------------------------
#  Check that HCPPIPEDIR is defined and Load Function Libraries
# ------------------------------------------------------------------------------

if [ -z "${HCPPIPEDIR}" ]; then
  echo "${script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
  exit 1
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source ${HCPPIPEDIR}/global/scripts/opts.shlib                 # Command line option functions
source ${HCPPIPEDIR}/global/scripts/tempfiles.shlib

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
	show_usage
	exit 0
fi

# ------------------------------------------------------------------------------
#  Verify required environment variables are set and log value
# ------------------------------------------------------------------------------

log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FSLDIR

################################################ SUPPORT FUNCTIONS ##################################################

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
#     ${T1wImageFile}.${FinalfMRIResolution}
#     ${FreeSurferBrainMaskFile}.${FinalfMRIResolution}
#     ${BiasFieldFile}.${FinalfMRIResolution}
#     Scout_gdc_MNI_warp     : a warpfield from original (distorted) scout to low-res MNI
#
# Outputs (not in either of the above):
#     ${OutputTransform}  : the warpfield from fMRI to standard (low-res)
#     ${OutputfMRI}
#     ${JacobianOut}
#     ${ScoutOutput}
#          NB: last three images are all in low-res standard space

################################################## OPTION PARSING #####################################################

# parse arguments
WD=`getopt1 "--workingdir" $@`  # "$1"
InputfMRI=`getopt1 "--infmri" $@`  # "$2"
T1wImage=`getopt1 "--t1" $@`  # "$3"
FinalfMRIResolution=`getopt1 "--fmriresout" $@`  # "$4"
fMRIFolder=`getopt1 "--fmrifolder" $@`
fMRIToStructuralInput=`getopt1 "--fmri2structin" $@`  # "$6"
StructuralToStandard=`getopt1 "--struct2std" $@`  # "$7"
OutputTransform=`getopt1 "--owarp" $@`  # "$8"
OutputInvTransform=`getopt1 "--oiwarp" $@`
MotionMatrixFolder=`getopt1 "--motionmatdir" $@`  # "$9"
MotionMatrixPrefix=`getopt1 "--motionmatprefix" $@`  # "${10}"
OutputfMRI=`getopt1 "--ofmri" $@`  # "${11}"
FreeSurferBrainMask=`getopt1 "--freesurferbrainmask" $@`  # "${12}"
BiasField=`getopt1 "--biasfield" $@`  # "${13}"
GradientDistortionField=`getopt1 "--gdfield" $@`  # "${14}"
ScoutInput=`getopt1 "--scoutin" $@`  # "${15}"
ScoutInputgdc=`getopt1 "--scoutgdcin" $@`  # "${15}"
ScoutOutput=`getopt1 "--oscout" $@`  # "${16}"
JacobianOut=`getopt1 "--ojacobian" $@`  # "${18}"
fMRIReferencePath=`getopt1 "--fmrirefpath" $@` # "${19}"
fMRIReferenceReg=`getopt1 "--fmrirefreg" $@`  # "${20}"

#hidden: toggle for unreleased new resampling command, default off
useWbResample=`getopt1 "--wb-resample" $@`
useWbResample="${useWbResample:-0}"
#with wb_command -volume-resample, the warpfields and per-frame motion affines do not need to be combined in advance,
#and the timeseries can be resampled without splitting into one-frame files, resulting in much less file IO

case "$(echo "$useWbResample" | tr '[:upper:]' '[:lower:]')" in
    (yes | true | 1)
        useWbResample=1
        ;;
    (no | false | 0)
        useWbResample=0
        ;;
    (*)
        log_Err_Abort "unrecognized boolean '$useWbResample', please use yes/no, true/false, or 1/0"
        ;;
esac

# defaults
fMRIReferencePath=${fMRIReferencePath:-NONE}
fMRIReferenceReg=${fMRIReferenceReg:-NONE}

# --- Report arguments

verbose_echo "  "
verbose_red_echo " ===> Running OneStepResampling"
verbose_echo " "
verbose_echo " Using parameters ..."
verbose_echo "         --workingdir: ${WD}"
verbose_echo "             --infmri: ${InputfMRI}"
verbose_echo "                 --t1: ${T1wImage}"
verbose_echo "         --fmriresout: ${FinalfMRIResolution}"
verbose_echo "         --fmrifolder: ${fMRIFolder}"
verbose_echo "      --fmri2structin: ${fMRIToStructuralInput}"
verbose_echo "         --struct2std: ${StructuralToStandard}"
verbose_echo "              --owarp: ${OutputTransform}"
verbose_echo "             --oiwarp: ${OutputInvTransform}"
verbose_echo "       --motionmatdir: ${MotionMatrixFolder}"
verbose_echo "    --motionmatprefix: ${MotionMatrixPrefix}"
verbose_echo "              --ofmri: ${OutputfMRI}"
verbose_echo "--freesurferbrainmask: ${FreeSurferBrainMask}"
verbose_echo "          --biasfield: ${BiasField}"
verbose_echo "            --gdfield: ${GradientDistortionField}"
verbose_echo "            --scoutin: ${ScoutInput}"
verbose_echo "         --scoutgdcin: ${ScoutInputgdc}"
verbose_echo "             --oscout: ${ScoutOutput}"
verbose_echo "          --ojacobian: ${JacobianOut}"
verbose_echo "        --fmrirefpath: ${fMRIReferencePath}"
verbose_echo "         --fmrirefreg: ${fMRIReferenceReg}"
verbose_echo " "

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
if [[ $(echo "${FinalfMRIResolution} == 2" | bc) == "1" ]] ; then
    ResampRefIm=$FSLDIR/data/standard/MNI152_T1_2mm
elif [[ $(echo "${FinalfMRIResolution} == 1" | bc) == "1" ]] ; then
    ResampRefIm=$FSLDIR/data/standard/MNI152_T1_1mm
else
  ${FSLDIR}/bin/flirt -interp spline -in ${T1wImage} -ref ${T1wImage} -applyisoxfm $FinalfMRIResolution -out ${WD}/${T1wImageFile}.${FinalfMRIResolution}
  ResampRefIm=${WD}/${T1wImageFile}.${FinalfMRIResolution}
fi
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${T1wImage} -r ${ResampRefIm} --premat=$FSLDIR/etc/flirtsch/ident.mat -o ${WD}/${T1wImageFile}.${FinalfMRIResolution}

# Create brain masks in this space from the FreeSurfer output (changing resolution)
${FSLDIR}/bin/applywarp --rel --interp=nn -i ${FreeSurferBrainMask}.nii.gz -r ${WD}/${T1wImageFile}.${FinalfMRIResolution} --premat=$FSLDIR/etc/flirtsch/ident.mat -o ${WD}/${FreeSurferBrainMaskFile}.${FinalfMRIResolution}.nii.gz

# Create versions of the biasfield (changing resolution)
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${BiasField} -r ${WD}/${FreeSurferBrainMaskFile}.${FinalfMRIResolution}.nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o ${WD}/${BiasFieldFile}.${FinalfMRIResolution}
${FSLDIR}/bin/fslmaths ${WD}/${BiasFieldFile}.${FinalfMRIResolution} -thr 0.1 ${WD}/${BiasFieldFile}.${FinalfMRIResolution}

# Downsample warpfield (fMRI to standard) to increase speed
#   NB: warpfield resolution is 10mm, so 1mm to fMRIres downsample loses no precision

# Create a combined warp if nonlinear registration to reference is used
if [ "$fMRIReferenceReg" == "nonlinear" ]; then
  # Note that the name of the post motion correction warp is hard-coded in MotionCorrection.sh
  ${FSLDIR}/bin/convertwarp --relout --rel --warp1=${MotionMatrixFolder}/postmc2fmriref_warp --warp2=${fMRIToStructuralInput} --ref=${WD}/${T1wImageFile}.${FinalfMRIResolution} --out=${WD}/postmc2struct_warp
  ${FSLDIR}/bin/convertwarp --relout --rel --warp1=${WD}/postmc2struct_warp --warp2=${StructuralToStandard} --ref=${WD}/${T1wImageFile}.${FinalfMRIResolution} --out=${OutputTransform}
else
  ${FSLDIR}/bin/convertwarp --relout --rel --warp1=${fMRIToStructuralInput} --warp2=${StructuralToStandard} --ref=${WD}/${T1wImageFile}.${FinalfMRIResolution} --out=${OutputTransform}
fi

# Add stuff for estimating RMS motion
invwarp -w ${OutputTransform} -o ${OutputInvTransform} -r ${ScoutInputgdc}
applywarp --rel --interp=nn -i ${FreeSurferBrainMask}.nii.gz -r ${ScoutInputgdc} -w ${OutputInvTransform} -o ${ScoutInputgdc}_mask.nii.gz
if [ -e ${fMRIFolder}/Movement_RelativeRMS.txt ] ; then
  /bin/rm ${fMRIFolder}/Movement_RelativeRMS.txt
fi
if [ -e ${fMRIFolder}/Movement_AbsoluteRMS.txt ] ; then
  /bin/rm ${fMRIFolder}/Movement_AbsoluteRMS.txt
fi
if [ -e ${fMRIFolder}/Movement_RelativeRMS_mean.txt ] ; then
  /bin/rm ${fMRIFolder}/Movement_RelativeRMS_mean.txt
fi
if [ -e ${fMRIFolder}/Movement_AbsoluteRMS_mean.txt ] ; then
  /bin/rm ${fMRIFolder}/Movement_AbsoluteRMS_mean.txt
fi

# Copy some files from ${WD} (--workingdir arg) to ${fMRIFolder} (--fmrifolder arg)
${FSLDIR}/bin/imcp ${WD}/${T1wImageFile}.${FinalfMRIResolution} ${fMRIFolder}/${T1wImageFile}.${FinalfMRIResolution}
${FSLDIR}/bin/imcp ${WD}/${FreeSurferBrainMaskFile}.${FinalfMRIResolution} ${fMRIFolder}/${FreeSurferBrainMaskFile}.${FinalfMRIResolution}
${FSLDIR}/bin/imcp ${WD}/${BiasFieldFile}.${FinalfMRIResolution} ${fMRIFolder}/${BiasFieldFile}.${FinalfMRIResolution}

if ((useWbResample))
then
    affseries="$(tempfiles_create OneStepResampleAffSeries_XXXXXX.txt)"
    
    for ((k=0; k < $NumFrames; k++))
    do
        vnum=`${FSLDIR}/bin/zeropad $k 4`
        
        #use unquoted $() to change whitespace to spaces
        echo $(cat "$MotionMatrixFolder/${MotionMatrixPrefix}$vnum") >> "$affseries"

        # Add stuff for estimating RMS motion
        rmsdiff ${MotionMatrixFolder}/${MotionMatrixPrefix}${vnum} ${MotionMatrixFolder}/${MotionMatrixPrefix}0000 ${ScoutInputgdc} ${ScoutInputgdc}_mask.nii.gz | tail -n 1 >> ${fMRIFolder}/Movement_AbsoluteRMS.txt
        if [ $k -eq 0 ] ; then
            echo "0" >> ${fMRIFolder}/Movement_RelativeRMS.txt
        else
            rmsdiff ${MotionMatrixFolder}/${MotionMatrixPrefix}${vnum} $prevmatrix ${ScoutInputgdc} ${ScoutInputgdc}_mask.nii.gz | tail -n 1 >> ${fMRIFolder}/Movement_RelativeRMS.txt
        fi
        prevmatrix="${MotionMatrixFolder}/${MotionMatrixPrefix}${vnum}"
    done
    
    #gdc warp space is input to input, affine is input to input, OutputTransform is input to MNI
    xfmargs=(-warp "$GradientDistortionField".nii.gz -fnirt "$InputfMRI"
             -affine-series "$affseries" -flirt "$InputfMRI" "$InputfMRI"
             -warp "$OutputTransform".nii.gz -fnirt "$InputfMRI")
    
    wb_command -volume-resample "$InputfMRI" "$WD/$T1wImageFile.$FinalfMRIResolution".nii.gz CUBIC "$OutputfMRI".nii.gz "${xfmargs[@]}" -nifti-output-datatype INT32
    
    #resample all-ones volume series with enclosing voxel to determine FOV coverage
    #yes, this is the entire length of the timeseries on purpose
    fovcheck="$(tempfiles_create OneStepResampleFovCheck_XXXXXX.nii.gz)"
    wb_command -volume-math '1' "$fovcheck" -var x "$InputfMRI"
    #fsl's "nn" interpolation is just as pessimistic about the FoV as non-extrapolating interpolation
    #so, in wb_command, use trilinear here instead of enclosing voxel to get the same FoV behavior as CUBIC
    #still doesn't match FSL's "nn" (and the FoV edge on "spline" isn't the same as wb_command CUBIC), not sure why
    wb_command -volume-resample "$fovcheck" "$WD/$T1wImageFile.$FinalfMRIResolution".nii.gz TRILINEAR "$OutputfMRI"_mask.nii.gz "${xfmargs[@]}" -nifti-output-datatype INT32

else
    mkdir -p ${WD}/prevols
    mkdir -p ${WD}/postvols

    # Apply combined transformations to fMRI in a one-step resampling
    # (combines gradient non-linearity distortion, motion correction, and registration to atlas (MNI152) space, but keeping fMRI resolution)
    ${FSLDIR}/bin/fslsplit ${InputfMRI} ${WD}/prevols/vol -t
    FrameMergeSTRING=""
    FrameMergeSTRINGII=""
    for ((k=0; k < $NumFrames; k++)); do
      vnum=`${FSLDIR}/bin/zeropad $k 4`

      # Add stuff for estimating RMS motion
      rmsdiff ${MotionMatrixFolder}/${MotionMatrixPrefix}${vnum} ${MotionMatrixFolder}/${MotionMatrixPrefix}0000 ${ScoutInputgdc} ${ScoutInputgdc}_mask.nii.gz | tail -n 1 >> ${fMRIFolder}/Movement_AbsoluteRMS.txt
      if [ $k -eq 0 ] ; then
        echo "0" >> ${fMRIFolder}/Movement_RelativeRMS.txt
      else
        rmsdiff ${MotionMatrixFolder}/${MotionMatrixPrefix}${vnum} $prevmatrix ${ScoutInputgdc} ${ScoutInputgdc}_mask.nii.gz | tail -n 1 >> ${fMRIFolder}/Movement_RelativeRMS.txt
      fi
      prevmatrix="${MotionMatrixFolder}/${MotionMatrixPrefix}${vnum}"

      # Combine GCD with motion correction
      ${FSLDIR}/bin/convertwarp --relout --rel --ref=${WD}/prevols/vol${vnum}.nii.gz --warp1=${GradientDistortionField} --postmat=${MotionMatrixFolder}/${MotionMatrixPrefix}${vnum} --out=${MotionMatrixFolder}/${MotionMatrixPrefix}${vnum}_gdc_warp.nii.gz
      # Add in the warp to MNI152
      ${FSLDIR}/bin/convertwarp --relout --rel --ref=${WD}/${T1wImageFile}.${FinalfMRIResolution} --warp1=${MotionMatrixFolder}/${MotionMatrixPrefix}${vnum}_gdc_warp.nii.gz --warp2=${OutputTransform} --out=${MotionMatrixFolder}/${MotionMatrixPrefix}${vnum}_all_warp.nii.gz
      # Apply one-step warp, using spline interpolation
      ${FSLDIR}/bin/applywarp --rel --interp=spline --in=${WD}/prevols/vol${vnum}.nii.gz --warp=${MotionMatrixFolder}/${MotionMatrixPrefix}${vnum}_all_warp.nii.gz --ref=${WD}/${T1wImageFile}.${FinalfMRIResolution} --out=${WD}/postvols/vol${vnum}.nii.gz

      # Generate a mask for keeping track of spatial coverage (use nearest neighbor interpolation here)
      ${FSLDIR}/bin/fslmaths ${WD}/prevols/vol${vnum}.nii.gz -mul 0 -add 1 ${WD}/prevols/vol${vnum}_mask.nii.gz
      ${FSLDIR}/bin/applywarp --rel --interp=nn --in=${WD}/prevols/vol${vnum}_mask.nii.gz --warp=${MotionMatrixFolder}/${MotionMatrixPrefix}${vnum}_all_warp.nii.gz --ref=${WD}/${T1wImageFile}.${FinalfMRIResolution} --out=${WD}/postvols/vol${vnum}_mask.nii.gz

      # Create strings for merging
      FrameMergeSTRING+="${WD}/postvols/vol${vnum}.nii.gz " 
      FrameMergeSTRINGII+="${WD}/postvols/vol${vnum}_mask.nii.gz "

      #Do Basic Cleanup
      rm ${MotionMatrixFolder}/${MotionMatrixPrefix}${vnum}_gdc_warp.nii.gz
      rm ${MotionMatrixFolder}/${MotionMatrixPrefix}${vnum}_all_warp.nii.gz
    done

    verbose_red_echo "---> Merging results"
    # Merge together results and restore the TR (saved beforehand)
    ${FSLDIR}/bin/fslmerge -tr ${OutputfMRI} $FrameMergeSTRING $TR_vol
    ${FSLDIR}/bin/fslmerge -tr ${OutputfMRI}_mask $FrameMergeSTRINGII $TR_vol

    # Do Basic Cleanup
    rm -r ${WD}/postvols
    rm -r ${WD}/prevols
fi

# Generate a spatial coverage mask that captures the voxels that have data available at *ALL* time points
# (gets applied in IntensityNormalization.sh; so don't change name here without changing it in that script as well).
fslmaths ${OutputfMRI}_mask -Tmin ${OutputfMRI}_mask

if [ ${fMRIReferencePath} = "NONE" ] ; then
  # Combine transformations: gradient non-linearity distortion + fMRI_dc to standard
  ${FSLDIR}/bin/convertwarp --relout --rel --ref=${WD}/${T1wImageFile}.${FinalfMRIResolution} --warp1=${GradientDistortionField} --warp2=${OutputTransform} --out=${WD}/Scout_gdc_MNI_warp.nii.gz
  ${FSLDIR}/bin/applywarp --rel --interp=spline --in=${ScoutInput} -w ${WD}/Scout_gdc_MNI_warp.nii.gz -r ${WD}/${T1wImageFile}.${FinalfMRIResolution} -o ${ScoutOutput}
fi

# Create trilinear interpolated version of Jacobian (T1w space, fMRI resolution)
#${FSLDIR}/bin/applywarp --rel --interp=trilinear -i ${JacobianIn} -r ${WD}/${T1wImageFile}.${FinalfMRIResolution} -w ${StructuralToStandard} -o ${JacobianOut}
#fMRI2Struct is from gdc space to T1w space (optionally through an external reference), ie, only fieldmap-based distortions (like topup)
#output jacobian is both gdc and topup/fieldmap jacobian, but not the to MNI jacobian
#JacobianIn was removed from inputs, now we just compute it from the combined warpfield of gdc and dc (NOT MNI)
#compute combined warpfield, but don't use jacobian output because it has 8 frames for no apparent reason
#NOTE: convertwarp always requires -o anyway
if [ "$fMRIReferenceReg" == "nonlinear" ]; then
  ${FSLDIR}/bin/convertwarp --relout --rel --ref=${WD}/postmc2struct_warp --warp1=${GradientDistortionField} --warp2=${WD}/postmc2struct_warp -o ${WD}/gdc_dc_warp --jacobian=${WD}/gdc_dc_jacobian
else
  ${FSLDIR}/bin/convertwarp --relout --rel --ref=${fMRIToStructuralInput} --warp1=${GradientDistortionField} --warp2=${fMRIToStructuralInput} -o ${WD}/gdc_dc_warp --jacobian=${WD}/gdc_dc_jacobian
fi
#but, convertwarp's jacobian is 8 frames - each combination of one-sided differences, so average them
${FSLDIR}/bin/fslmaths ${WD}/gdc_dc_jacobian -Tmean ${WD}/gdc_dc_jacobian

#and resample it to MNI space
# Note that trilinear instead of spline interpolation is used with the purpose to minimize the ringing artefacts that occur 
# with downsampling of the jacobian field and are then propagated to the BOLD image itself.
${FSLDIR}/bin/applywarp --rel --interp=trilinear -i ${WD}/gdc_dc_jacobian -r ${WD}/${T1wImageFile}.${FinalfMRIResolution} -w ${StructuralToStandard} -o ${JacobianOut}

# Compute average motion across frames
cat ${fMRIFolder}/Movement_RelativeRMS.txt | awk '{ sum += $1} END { print sum / NR }' >> ${fMRIFolder}/Movement_RelativeRMS_mean.txt
cat ${fMRIFolder}/Movement_AbsoluteRMS.txt | awk '{ sum += $1} END { print sum / NR }' >> ${fMRIFolder}/Movement_AbsoluteRMS_mean.txt

verbose_green_echo "---> Finished OneStepResampling"

echo " "
echo "END: OneStepResampling"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ##########################################

if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# Check registrations to low-res standard space" >> $WD/qa.txt
echo "fslview ${WD}/${T1wImageFile}.${FinalfMRIResolution} ${WD}/${FreeSurferBrainMaskFile}.${FinalfMRIResolution} ${WD}/${BiasFieldFile}.${FinalfMRIResolution} ${OutputfMRI}" >> $WD/qa.txt

##############################################################################################


