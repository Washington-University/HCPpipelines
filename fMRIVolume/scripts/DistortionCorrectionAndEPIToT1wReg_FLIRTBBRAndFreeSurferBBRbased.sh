#!/bin/bash 

# Requirements for this script
#  installed versions of: FSL, FreeSurfer
#  environment: HCPPIPEDIR, FSLDIR, FREESURFER_HOME, HCPPIPEDIR_Global 

# ---------------------------------------------------------------------------
#  Constants for specification of susceptibility distortion Correction Method
# ---------------------------------------------------------------------------

FIELDMAP_METHOD_OPT="FIELDMAP"
SIEMENS_METHOD_OPT="SiemensFieldMap"
# For GE HealthCare Fieldmap Distortion Correction methods 
# see explanations in global/scripts/FieldMapPreprocessingAll.sh
GE_HEALTHCARE_LEGACY_METHOD_OPT="GEHealthCareLegacyFieldMap" 
GE_HEALTHCARE_METHOD_OPT="GEHealthCareFieldMap"
PHILIPS_METHOD_OPT="PhilipsFieldMap"
SPIN_ECHO_METHOD_OPT="TOPUP"
NONE_METHOD_OPT="NONE"

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"

opts_SetScriptDescription "Script to register EPI to T1w, with distortion correction"

opts_AddMandatory '--scoutin' 'ScoutInputName' 'image' "input scout image (pre-sat EPI)"

opts_AddMandatory '--t1' 'T1wImage' 'image' "input T1-weighted image"

opts_AddMandatory '--t1restore' 'T1wRestoreImage' 'image' "input bias-corrected T1-weighted image"

opts_AddMandatory '--t1brain' 'T1wBrainImage' 'image' "input bias-corrected, brain-extracted T1-weighted image"

opts_AddMandatory '--biasfield' 'BiasField' 'image' "input T1w bias field estimate image or in fMRI space"

opts_AddMandatory '--freesurferfolder' 'FreeSurferSubjectFolder' 'path' "directory of FreeSurfer folder"

opts_AddMandatory '--freesurfersubjectid' 'FreeSurferSubjectID' 'id' "FreeSurfer Subject ID"

opts_AddMandatory '--owarp' 'OutputTransform' 'name' "output filename for warp of EPI to T1w"

opts_AddMandatory '--ojacobian' 'JacobianOut' 'name' "output filename for Jacobian image (in T1w space)"

opts_AddMandatory '--oregim' 'RegOutput' 'name' "output registered image (EPI to T1w)"

opts_AddMandatory '--usejacobian' 'UseJacobian' 'true or false' "apply jacobian correction to distortion-corrected SBRef and other files"

opts_AddMandatory '--gdcoeffs' 'GradientDistortionCoeffs' 'coefficients (Siemens Format)' "Gradient non-linearity distortion coefficients (Siemens format), set to "NONE" to skip gradient non-linearity distortion correction (GDC)."

opts_AddMandatory '--biascorrection' 'BiasCorrection' 'SEBASED OR LEGACY OR NONE' "Method to use for receive coil bias field correction: 
        'SEBASED'
             use bias field derived from spin echo images, must also use --method='${SPIN_ECHO_METHOD_OPT}'
             Note: --fmriname=<name of fmri run> required for 'SEBASED' bias correction method

        'LEGACY'
             use the bias field derived from T1w and T2w images, same as was used in
             pipeline version 3.14.1 or older. No longer recommended.

        'NONE'
             don't do bias correction"

opts_AddMandatory '--method' 'DistortionCorrection' 'method' "method to use for susceptibility distortion correction (SDC)
        '${FIELDMAP_METHOD_OPT}'
            equivalent to '${SIEMENS_METHOD_OPT}' (see below)

        '${SIEMENS_METHOD_OPT}'
             use Siemens specific Gradient Echo Field Maps for SDC

        '${SPIN_ECHO_METHOD_OPT}'
             use a pair of Spin Echo EPI images ('Spin Echo Field Maps') acquired with
             opposing polarity for SDC

        '${GE_HEALTHCARE_LEGACY_METHOD_OPT}'
             use GE HealthCare Legacy specific Gradient Echo Field Maps for SDC (field map in Hz and magnitude image in a single NIfTI file, via --fmapcombined argument).
             This option is maintained for backward compatibility.

        '${GE_HEALTHCARE_METHOD_OPT}'
             use GE HealthCare specific Gradient Echo Field Maps for SDC (field map in Hz and magnitude image in two separate NIfTI files, via --fmapphase and --fmapmag).

        '${PHILIPS_METHOD_OPT}'
             use Philips specific Gradient Echo Field Maps for SDC

        '${NONE_METHOD_OPT}'
             do not use any SDC"


#Optional Args 
opts_AddOptional '--workingdir' 'WD' 'path' 'working dir'

opts_AddOptional '--echospacing' 'EchoSpacing' 'spacing (seconds)' "*effective* echo spacing of fMRI input, in seconds"

opts_AddOptional '--unwarpdir' 'UnwarpDir' '{x,y,z,x-,y-,z-} or {i,j,k,i-,j-,k-}>]' "PE direction for unwarping according to the *voxel* axes. Polarity matters! If your distortions are twice as bad as in the original images, try using the opposite polarity for --unwarpdir."

opts_AddOptional '--SEPhaseNeg' 'SpinEchoPhaseEncodeNegative' 'number' "'negative' polarity SE-EPI image"

opts_AddOptional '--SEPhasePos' 'SpinEchoPhaseEncodePositive' 'number' "'positive' polarity SE-EPI image"

opts_AddOptional '--topupconfig' 'TopupConfig' 'file' "topup config file"

opts_AddOptional '--subjectfolder' 'SubjectFolder' 'path' "subject processing folder"

opts_AddOptional '--fmapmag' 'MagnitudeInputName' 'field_map' "field map magnitude image"

opts_AddOptional '--fmapphase' 'PhaseInputName' 'image' "fieldmap phase images in radians (Siemens/Philips) or in Hz (GE HealthCare)"

opts_AddOptional '--echodiff' 'deltaTE' 'number (milliseconds)' "difference of echo times for fieldmap, in milliseconds"

opts_AddOptional '--fmapcombined' 'GEB0InputName' 'image' "GE HealthCare Legacy field map only (two volumes: 1. field map in Hz  and 2. magnitude image)" '' '--fmap'

opts_AddOptional '--dof' 'dof' '6 OR 9 OR 12' "degrees of freedom for EPI to T1 registration" '6'

opts_AddOptional '--qaimage' 'QAImage' 'name' "output name for QA image" "T1wMulEPI"

opts_AddOptional '--preregistertool' 'PreregisterTool' "'epi_reg' OR 'flirt'" "'epi_reg' (default) OR 'flirt'" "epi_reg"

opts_AddOptional '--fmriname' 'NameOffMRI' 'name' "name of fmri run"

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

log_Check_Env_Var FSLDIR
log_Check_Env_Var FREESURFER_HOME
log_Check_Env_Var HCPPIPEDIR_Global

UseJacobian=$(opts_StringToBool "$UseJacobian")

HCPPIPEDIR_fMRIVol="$HCPPIPEDIR"/fMRIVolume/scripts

if [[ "$TopupConfig" == "" ]]
then
    TopupConfig="$HCPPIPEDIR"/global/config/b02b0.cnf
fi

################################################### OUTPUT FILES #####################################################

# Outputs (in $WD):
#
#    FIELDMAP, SiemensFieldMap, GeneralElectricFieldMap, and PhilipsFieldMap:
#      Magnitude  Magnitude_brain  FieldMap
#
#    FIELDMAP and TOPUP sections:
#      Jacobian2T1w
#      ${ScoutInputFile}_undistorted
#      ${ScoutInputFile}_undistorted2T1w_init
#      ${ScoutInputFile}_undistorted_warp
#
#   NO Distortion Correction Method
#      Jacobian2T1w
#      ${ScoutInputFile}
#      ${ScoutInputFile}2T1w_init
#      ${ScoutInputFile}_warp     
#
#    FreeSurfer section:
#      fMRI2str.mat  fMRI2str
#      ${ScoutInputFile}_undistorted2T1w
#
# Outputs (not in $WD):
#
#       ${RegOutput}  ${OutputTransform}  ${JacobianOut}  ${QAImage}

#error check bias correction opt
case "$BiasCorrection" in
    NONE)
        UseBiasField=""
    ;;

    LEGACY)
        UseBiasField="${BiasField}"
    ;;

    SEBASED)
        if [[ "$DistortionCorrection" != "${SPIN_ECHO_METHOD_OPT}" ]]
        then
            log_Err_Abort "--biascorrection=SEBASED is only available with --method=${SPIN_ECHO_METHOD_OPT}"
        fi
		if [ -z ${NameOffMRI} ]; then
			log_Err_Abort "--fmriname required when using --biascorrection=SEBASED"
		fi
        #note, this file doesn't exist yet, gets created by ComputeSpinEchoBiasField.sh
        UseBiasField="${WD}/ComputeSpinEchoBiasField/${NameOffMRI}_sebased_bias.nii.gz"
    ;;

    "")
        log_Err_Abort "--biascorrection option not specified"
    ;;

    *)
        log_Err_Abort "unrecognized value for bias correction: $BiasCorrection"
esac


ScoutInputFile=`basename $ScoutInputName`
T1wBrainImageFile=`basename $T1wBrainImage`
RegOutput=`$FSLDIR/bin/remove_ext $RegOutput`
GlobalScripts=${HCPPIPEDIR_Global}

if [[ $WD == "" ]]
then
    WD="${RegOutput}.wdir"
fi

log_Msg "START"

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

if [ ! "$DistortionCorrection" = ${NONE_METHOD_OPT} ]; then

  # Explicit check on the allowed values of UnwarpDir
  if [[ ${UnwarpDir} != [xyzijk] && ${UnwarpDir} != -[xyzijk] && ${UnwarpDir} != [xyzijk]- ]]; then
    log_Err_Abort "Error: Invalid entry for --unwarpdir ($UnwarpDir)"
  fi
    
  # FSL's naming convention for 'epi_reg --pedir' is {x,y,z,-x,-y,-z}
  # So, swap out any {i,j,k} for {x,y,z} (using bash pattern replacement)
  # and then make sure any '-' sign is preceding
  UnwarpDir=${UnwarpDir//i/x}
  UnwarpDir=${UnwarpDir//j/y}
  UnwarpDir=${UnwarpDir//k/z}
  if [ "${UnwarpDir}" = "x-" ] ; then
    UnwarpDir="-x"
  fi
  if [ "${UnwarpDir}" = "y-" ] ; then
    UnwarpDir="-y"
  fi
  if [ "${UnwarpDir}" = "z-" ] ; then
    UnwarpDir="-z"
  fi

fi

case $DistortionCorrection in

    ${FIELDMAP_METHOD_OPT} | ${SIEMENS_METHOD_OPT} | ${GE_HEALTHCARE_LEGACY_METHOD_OPT} | ${GE_HEALTHCARE_METHOD_OPT} | ${PHILIPS_METHOD_OPT})

        if [ $DistortionCorrection = "${FIELDMAP_METHOD_OPT}" ] || [ $DistortionCorrection = "${SIEMENS_METHOD_OPT}" ] ; then
            # --------------------------------------
            # -- Siemens Gradient Echo Field Maps --
            # --------------------------------------

            # process fieldmap with gradient non-linearity distortion correction
            ${GlobalScripts}/FieldMapPreprocessingAll.sh \
                --workingdir=${WD}/FieldMap \
                --method="SiemensFieldMap" \
                --fmapmag=${MagnitudeInputName} \
                --fmapphase=${PhaseInputName} \
                --echodiff=${deltaTE} \
                --ofmapmag=${WD}/Magnitude \
                --ofmapmagbrain=${WD}/Magnitude_brain \
                --ofmap=${WD}/FieldMap \
                --gdcoeffs=${GradientDistortionCoeffs}

        elif [ $DistortionCorrection = "${GE_HEALTHCARE_LEGACY_METHOD_OPT}" ] ; then
            # ---------------------------------------------------
            # -- GE HealthCare Legacy Gradient Echo Field Maps --
            # ---------------------------------------------------

            # process fieldmap with gradient non-linearity distortion correction
            ${GlobalScripts}/FieldMapPreprocessingAll.sh \
                --workingdir=${WD}/FieldMap \
                --method="GEHealthCareLegacyFieldMap" \
                --fmapcombined=${GEB0InputName} \
                --echodiff=${deltaTE} \
                --ofmapmag=${WD}/Magnitude \
                --ofmapmagbrain=${WD}/Magnitude_brain \
                --ofmap=${WD}/FieldMap \
                --gdcoeffs=${GradientDistortionCoeffs}
        
        elif [ $DistortionCorrection = "${GE_HEALTHCARE_METHOD_OPT}" ] ; then
            # --------------------------------------------
            # -- GE HealthCare Gradient Echo Field Maps --
            # --------------------------------------------

            # process fieldmap with gradient non-linearity distortion correction
            ${GlobalScripts}/FieldMapPreprocessingAll.sh \
                --workingdir=${WD}/FieldMap \
                --method="GEHealthCareFieldMap" \
                --fmapmag=${MagnitudeInputName} \
                --fmapphase=${PhaseInputName} \
                --echodiff=${deltaTE} \
                --ofmapmag=${WD}/Magnitude \
                --ofmapmagbrain=${WD}/Magnitude_brain \
                --ofmap=${WD}/FieldMap \
                --gdcoeffs=${GradientDistortionCoeffs}

        elif [ $DistortionCorrection = "${PHILIPS_METHOD_OPT}" ] ; then
            # --------------------------------------
            # -- Philips Gradient Echo Field Maps --
            # --------------------------------------

            # process fieldmap with gradient non-linearity distortion correction
            ${GlobalScripts}/FieldMapPreprocessingAll.sh \
                --workingdir=${WD}/FieldMap \
                --method="PhilipsFieldMap" \
                --fmapmag=${MagnitudeInputName} \
                --fmapphase=${PhaseInputName} \
                --echodiff=${deltaTE} \
                --ofmapmag=${WD}/Magnitude \
                --ofmapmagbrain=${WD}/Magnitude_brain \
                --ofmap=${WD}/FieldMap \
                --gdcoeffs=${GradientDistortionCoeffs}

        else
            log_Err_Abort "Script programming error. Unhandled Distortion Correction Method: ${DistortionCorrection}"            
        fi

        cp ${ScoutInputName}.nii.gz ${WD}/Scout.nii.gz
        ScoutExtension="_undistorted"

        # Test if Magnitude Brain and T1w Brain Are Similar in Size, if not, assume Magnitude Brain Extraction
        # Failed and Must Be Retried After Removing Bias Field
        MagnitudeBrainSize=`${FSLDIR}/bin/fslstats ${WD}/Magnitude_brain -V | cut -d " " -f 2`
        T1wBrainSize=`${FSLDIR}/bin/fslstats ${WD}/${T1wBrainImageFile} -V | cut -d " " -f 2`

        if [[ X`echo "if ( (${MagnitudeBrainSize} / ${T1wBrainSize}) > 1.25 ) {1}" | bc -l` = X1 || X`echo "if ( (${MagnitudeBrainSize} / ${T1wBrainSize}) < 0.75 ) {1}" | bc -l` = X1 ]] ; then
            ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/Magnitude.nii.gz -ref ${T1wImage} -omat "$WD"/Mag2T1w.mat -out ${WD}/Magnitude2T1w.nii.gz -searchrx -30 30 -searchry -30 30 -searchrz -30 30
            ${FSLDIR}/bin/convert_xfm -omat "$WD"/T1w2Mag.mat -inverse "$WD"/Mag2T1w.mat
            ${FSLDIR}/bin/applywarp --interp=nn -i ${WD}/${T1wBrainImageFile} -r ${WD}/Magnitude.nii.gz --premat="$WD"/T1w2Mag.mat -o ${WD}/Magnitude_brain_mask.nii.gz
            fslmaths ${WD}/Magnitude_brain_mask.nii.gz -bin ${WD}/Magnitude_brain_mask.nii.gz
            fslmaths ${WD}/Magnitude.nii.gz -mas ${WD}/Magnitude_brain_mask.nii.gz ${WD}/Magnitude_brain.nii.gz

            ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/Scout.nii.gz -ref ${T1wImage} -omat "$WD"/Scout2T1w.mat -out ${WD}/Scout2T1w.nii.gz -searchrx -30 30 -searchry -30 30 -searchrz -30 30
            ${FSLDIR}/bin/convert_xfm -omat "$WD"/T1w2Scout.mat -inverse "$WD"/Scout2T1w.mat
            ${FSLDIR}/bin/applywarp --interp=nn -i ${WD}/${T1wBrainImageFile} -r ${WD}/Scout.nii.gz --premat="$WD"/T1w2Scout.mat -o ${WD}/Scout_brain_mask.nii.gz
            fslmaths ${WD}/Scout_brain_mask.nii.gz -bin ${WD}/Scout_brain_mask.nii.gz
            fslmaths ${WD}/Scout.nii.gz -mas ${WD}/Scout_brain_mask.nii.gz ${WD}/Scout_brain.nii.gz

            # register scout to T1w image using fieldmap
            ${HCPPIPEDIR_Global}/epi_reg_dof --dof=${dof} --epi=${WD}/Scout_brain.nii.gz --t1=${T1wImage} --t1brain=${WD}/${T1wBrainImageFile} --out=${WD}/${ScoutInputFile}${ScoutExtension} --fmap=${WD}/FieldMap.nii.gz --fmapmag=${WD}/Magnitude.nii.gz --fmapmagbrain=${WD}/Magnitude_brain.nii.gz --echospacing=${EchoSpacing} --pedir=${UnwarpDir}

        else
            # register scout to T1w image using fieldmap
            ${HCPPIPEDIR_Global}/epi_reg_dof --dof=${dof} --epi=${WD}/Scout.nii.gz --t1=${T1wImage} --t1brain=${WD}/${T1wBrainImageFile} --out=${WD}/${ScoutInputFile}${ScoutExtension} --fmap=${WD}/FieldMap.nii.gz --fmapmag=${WD}/Magnitude.nii.gz --fmapmagbrain=${WD}/Magnitude_brain.nii.gz --echospacing=${EchoSpacing} --pedir=${UnwarpDir}

        fi

        # create spline interpolated output for scout to T1w + apply bias field correction
        ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${ScoutInputName} -r ${T1wImage} -w ${WD}/${ScoutInputFile}${ScoutExtension}_warp.nii.gz -o ${WD}/${ScoutInputFile}${ScoutExtension}_1vol.nii.gz
        ${FSLDIR}/bin/immv ${WD}/${ScoutInputFile}${ScoutExtension}_1vol.nii.gz ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init.nii.gz
        ${FSLDIR}/bin/immv ${WD}/${ScoutInputFile}${ScoutExtension}_warp.nii.gz ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init_warp.nii.gz
        cp "${WD}/${ScoutInputFile}${ScoutExtension}_init.mat" "${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init.mat"
        #real jacobian, of just fieldmap warp (from epi_reg_dof)
        #NOTE: convertwarp requires an output argument regardless
        ${FSLDIR}/bin/convertwarp --rel -w ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init_warp.nii.gz -r ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init_warp.nii.gz --jacobian=${WD}/Jacobian2T1w.nii.gz -o ${WD}/junk_warp
        #but, convertwarp's --jacobian output has 8 volumes, as it outputs all combinations of one-sided differences
        #so, average them together
        ${FSLDIR}/bin/fslmaths ${WD}/Jacobian2T1w.nii.gz -Tmean ${WD}/Jacobian2T1w.nii.gz
        ${FSLDIR}/bin/imcp ${WD}/Jacobian2T1w.nii.gz ${WD}/Jacobian.nii.gz

        #jacobian and bias field are applied outside the case, as they are done the same as topup
        ;;

    ${SPIN_ECHO_METHOD_OPT})

        # --------------------------
        # -- Spin Echo Field Maps --
        # --------------------------

        # Use topup to distortion correct the scout scans
        # using a blip-reversed SE pair "fieldmap" sequence
        ${GlobalScripts}/TopupPreprocessingAll.sh \
            --workingdir=${WD}/FieldMap \
            --phaseone=${SpinEchoPhaseEncodeNegative} \
            --phasetwo=${SpinEchoPhaseEncodePositive} \
            --scoutin=${ScoutInputName} \
            --echospacing=${EchoSpacing} \
            --unwarpdir=${UnwarpDir} \
            --owarp=${WD}/WarpField \
            --ojacobian=${WD}/Jacobian \
            --gdcoeffs=${GradientDistortionCoeffs} \
            --topupconfig=${TopupConfig} \
            --usejacobian=${UseJacobian}

        ScoutExtension="_undistorted"

        #If NHP, brain extract scout for registration
        if [ -e ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}_1mm ] ; then
            cp ${ScoutInputName}.nii.gz ${WD}/Scout.nii.gz
            ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/Scout.nii.gz -ref ${T1wImage} -omat "$WD"/Scout2T1w.mat -out ${WD}/Scout2T1w.nii.gz -searchrx -30 30 -searchry -30 30 -searchrz -30 30
            ${FSLDIR}/bin/convert_xfm -omat "$WD"/T1w2Scout.mat -inverse "$WD"/Scout2T1w.mat
            ${FSLDIR}/bin/applywarp --interp=nn -i ${WD}/${T1wBrainImageFile} -r ${ScoutInputName} --premat="$WD"/T1w2Scout.mat -o ${WD}/Scout_brain_mask.nii.gz
            fslmaths ${WD}/Scout_brain_mask.nii.gz -bin ${WD}/Scout_brain_mask.nii.gz
            fslmaths ${WD}/Scout.nii.gz -mas ${WD}/Scout_brain_mask.nii.gz ${WD}/Scout_brain.nii.gz

            # create a spline interpolated image of scout (distortion corrected in same space)
            log_Msg "create a spline interpolated image of scout (distortion corrected in same space)"
            ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/Scout_brain.nii.gz -r ${WD}/Scout_brain.nii.gz -w ${WD}/WarpField.nii.gz -o ${WD}/${ScoutInputFile}${ScoutExtension}
        else
            # create a spline interpolated image of scout (distortion corrected in same space)
            log_Msg "create a spline interpolated image of scout (distortion corrected in same space)"
            ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${ScoutInputName} -r ${ScoutInputName} -w ${WD}/WarpField.nii.gz -o ${WD}/${ScoutInputFile}${ScoutExtension}
        fi

        # apply Jacobian correction to scout image (optional)
        # gdc jacobian is already applied in main script, where the gdc call for the scout is
        if ((UseJacobian))
        then
            log_Msg "apply Jacobian correction to scout image"
            ${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFile}${ScoutExtension} -mul ${WD}/Jacobian.nii.gz ${WD}/${ScoutInputFile}${ScoutExtension}
        fi

        # register undistorted scout image to T1w
        # this is just an initial registration, refined later in this script, but it is actually pretty good
        log_Msg "register undistorted scout image to T1w"

        if [ $PreregisterTool = "epi_reg" ] ; then
          log_Msg "... running epi_reg (dof ${dof})"
          ${HCPPIPEDIR_Global}/epi_reg_dof --dof=${dof} --epi=${WD}/${ScoutInputFile}${ScoutExtension} --t1=${T1wImage} --t1brain=${WD}/${T1wBrainImageFile} --out=${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init
        elif [ $PreregisterTool = "flirt" ] ; then
          log_Msg "... running flirt"
          ${FSLDIR}/bin/flirt -in ${WD}/${ScoutInputFile}${ScoutExtension} -ref ${WD}/${T1wBrainImageFile} -out ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init -omat ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init.mat -dof ${dof}
        else
          log_Err_Abort "--preregistertool=${PreregisterTool} is not a valid setting."
        fi

        #copy the initial registration into the final affine's filename, as it is pretty good
        #we need something to get between the spaces to compute an initial bias field
        cp "${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init.mat" "${WD}/fMRI2str.mat"

        # generate combined warpfields and spline interpolated images + apply bias field correction
        log_Msg "generate combined warpfields and spline interpolated images and apply bias field correction"
        ${FSLDIR}/bin/convertwarp --relout --rel -r ${T1wImage} --warp1=${WD}/WarpField.nii.gz --postmat=${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init.mat -o ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init_warp
        ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/Jacobian.nii.gz -r ${T1wImage} --premat=${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init.mat -o ${WD}/Jacobian2T1w.nii.gz
        #1-step resample from input (gdc) scout - NOTE: no longer includes jacobian correction, if specified
        ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${ScoutInputName} -r ${T1wImage} -w ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init_warp -o ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init

        #resample phase images to T1w space
        #these files were obtained by the import script from the FieldMap directory, save them into the package and resample them
        #we don't have the final transform to actual T1w space yet, that occurs later in this script
        #but, we need the T1w segmentation to make the bias field, so use the initial registration above, then compute the bias field again at the end
        Files="PhaseOne_gdc_dc PhaseTwo_gdc_dc SBRef_dc"
        ReferenceImage=${SubjectFolder}/T1w/T1w_acpc_dc.nii.gz
        for File in ${Files}
        do
            #NOTE: this relies on TopupPreprocessingAll generating _jac versions of the files
            if ((UseJacobian))
            then
                ${FSLDIR}/bin/applywarp --interp=spline -i "${WD}/FieldMap/${File}_jac" -r ${ReferenceImage} --premat=${WD}/fMRI2str.mat -o ${WD}/${File}
            else
                ${FSLDIR}/bin/applywarp --interp=spline -i "${WD}/FieldMap/${File}" -r ${ReferenceImage} --premat=${WD}/fMRI2str.mat -o ${WD}/${File}
            fi
        done

        #correct filename is already set in UseBiasField, but we have to compute it if using SEBASED
        #we compute it in this script because it needs outputs from topup, and because it should be applied to the scout image
        if [[ "$BiasCorrection" == "SEBASED" ]]
        then
            mkdir -p "$WD/ComputeSpinEchoBiasField"
            "${HCPPIPEDIR_fMRIVol}/ComputeSpinEchoBiasField.sh" \
                --workingdir="$WD/ComputeSpinEchoBiasField" \
                --subjectfolder="$SubjectFolder" \
                --fmriname="$NameOffMRI" \
                --corticallut="$HCPPIPEDIR/global/config/FreeSurferCorticalLabelTableLut.txt" \
                --subcorticallut="$HCPPIPEDIR/global/config/FreeSurferSubcorticalLabelTableLut.txt" \
                --smoothingfwhm="2" \
                --inputdir="$WD"
        fi


        ;;

    ${NONE_METHOD_OPT})

            # NOTE: To work with later code a uniform Jacobian is created.

            log_Msg "---> No distortion correction"

            ScoutExtension="_nosdc"

            log_Msg "---> Copy Scout image"
            ${FSLDIR}/bin/imcp ${ScoutInputName} ${WD}/${ScoutInputFile}${ScoutExtension}
            
            log_Msg "---> Creating uniform Jacobian Volume"
            # Create fake Jacobian Volume for Regular Fieldmaps (all ones)
            ${FSLDIR}/bin/fslmaths ${T1wImage} -mul 0 -add 1 -bin ${WD}/Jacobian.nii.gz
            
            log_Msg "---> register scout image to T1w"
            # register scout image to T1w
            # this is just an initial registration, refined later in this script, but it is actually pretty good
            if [ "$PreregisterTool" = "epi_reg" ] ; then
                log_Msg "... running epi_reg (dof ${dof})"
                ${HCPPIPEDIR_Global}/epi_reg_dof --dof=${dof} --epi=${WD}/${ScoutInputFile}${ScoutExtension} --t1=${T1wImage} --t1brain=${WD}/${T1wBrainImageFile} --out=${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init
            elif [ "$PreregisterTool" = "flirt" ] ; then
                log_Msg "... running flirt"
                ${FSLDIR}/bin/flirt -in ${WD}/${ScoutInputFile}${ScoutExtension} -ref ${WD}/${T1wBrainImageFile} -out ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init -omat ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init.mat -dof 6
            fi

            # In the NONE condition, we have no distortion Warpfield.  Convert the Scout2T1 registration (affine)
            # to its warp field equivalent, since we need "${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init_warp" later            
            # generate Scout2T1 warpfield and spline interpolated images
            log_Msg "generate combined warpfields and spline interpolated images"
            ${FSLDIR}/bin/convertwarp --relout --rel -r ${T1wImage} --premat=${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init.mat -o ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init_warp
            ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/Jacobian.nii.gz -r ${T1wImage} --premat=${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init.mat -o ${WD}/Jacobian2T1w.nii.gz
            # 1-step resample from input (gdc) scout - NOTE: no longer includes jacobian correction, if specified
            ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${ScoutInputName} -r ${T1wImage} -w ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init_warp -o ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init

        ;;
    *)

        log_Err_Abort "UNKNOWN DISTORTION CORRECTION METHOD: ${DistortionCorrection}"

esac

# apply Jacobian correction and bias correction options to scout image
if ((UseJacobian)) ; then
    log_Msg "apply Jacobian correction to scout image"
    if [[ "$UseBiasField" != "" ]]
    then
        ${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init -div ${UseBiasField} -mul ${WD}/Jacobian2T1w.nii.gz ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init.nii.gz
    else
        ${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init -mul ${WD}/Jacobian2T1w.nii.gz ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init.nii.gz
    fi
else
    log_Msg "do not apply Jacobian correction to scout image"
    if [[ "$UseBiasField" != "" ]]
    then
        ${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init -div ${UseBiasField} ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init.nii.gz
    fi
    #these all overwrite the input, no 'else' needed for "do nothing"
fi


### FREESURFER BBR - found to be an improvement, probably due to better GM/WM boundary
SUBJECTS_DIR=${FreeSurferSubjectFolder}
export SUBJECTS_DIR
#Check to see if FreeSurferNHP.sh was used
log_Msg "Check to see if FreeSurferNHP.sh was used"
if [ -e ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}_1mm ] ; then
  #Perform Registration in FreeSurferNHP 1mm Space
  log_Msg "${FreeSurferSubjectFolder}/${FreeSurferSubjectID}_1mm exists. FreeSurferNHP.sh was used."
  log_Msg "Perform Registration in FreeSurferNHP 1mm Space"
  ScoutImage="${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init.nii.gz"
  ScoutImageFile="${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init"

  res=`fslorient -getsform $ScoutImage | cut -d " " -f 1 | cut -d "-" -f 2`
  oldsform=`fslorient -getsform $ScoutImage`
  newsform=""
  i=1
  while [ $i -le 12 ] ; do
    oldelement=`echo $oldsform | cut -d " " -f $i`
    newelement=`echo "scale=1; $oldelement / $res" | bc -l`
    newsform=`echo "$newsform""$newelement"" "`
    if [ $i -eq 4 ] ; then
      originx="$newelement"
    fi
    if [ $i -eq 8 ] ; then
      originy="$newelement"
    fi
    if [ $i -eq 12 ] ; then
      originz="$newelement"
    fi
    i=$(($i+1))
  done
  newsform=`echo "$newsform""0 0 0 1" | sed 's/  / /g'`

  cp "$ScoutImage" "$ScoutImageFile"_1mm.nii.gz
  fslorient -setsform $newsform "$ScoutImageFile"_1mm.nii.gz
  fslhd -x "$ScoutImageFile"_1mm.nii.gz | sed s/"dx = '${res}'"/"dx = '1'"/g | sed s/"dy = '${res}'"/"dy = '1'"/g | sed s/"dz = '${res}'"/"dz = '1'"/g | fslcreatehd - "$ScoutImageFile"_1mm_head.nii.gz
  fslmaths "$ScoutImageFile"_1mm_head.nii.gz -add "$ScoutImageFile"_1mm.nii.gz "$ScoutImageFile"_1mm.nii.gz
  fslorient -copysform2qform "$ScoutImageFile"_1mm.nii.gz
  rm "$ScoutImageFile"_1mm_head.nii.gz
  dimex=`fslval "$ScoutImageFile"_1mm dim1`
  dimey=`fslval "$ScoutImageFile"_1mm dim2`
  dimez=`fslval "$ScoutImageFile"_1mm dim3`
  padx=`echo "(256 - $dimex) / 2" | bc`
  pady=`echo "(256 - $dimey) / 2" | bc`
  padz=`echo "(256 - $dimez) / 2" | bc`
  fslcreatehd $padx $dimey $dimez 1 1 1 1 1 0 0 0 16 "$ScoutImageFile"_1mm_padx
  fslmerge -x "$ScoutImageFile"_1mm "$ScoutImageFile"_1mm_padx "$ScoutImageFile"_1mm "$ScoutImageFile"_1mm_padx
  fslcreatehd 256 $pady $dimez 1 1 1 1 1 0 0 0 16 "$ScoutImageFile"_1mm_pady
  fslmerge -y "$ScoutImageFile"_1mm "$ScoutImageFile"_1mm_pady "$ScoutImageFile"_1mm "$ScoutImageFile"_1mm_pady
  fslcreatehd 256 256 $padz 1 1 1 1 1 0 0 0 16 "$ScoutImageFile"_1mm_padz
  fslmerge -z "$ScoutImageFile"_1mm "$ScoutImageFile"_1mm_padz "$ScoutImageFile"_1mm "$ScoutImageFile"_1mm_padz
  fslorient -setsformcode 1 "$ScoutImageFile"_1mm
  fslorient -setsform -1 0 0 `echo "$originx + $padx" | bc -l` 0 1 0 `echo "$originy - $pady" | bc -l` 0 0 1 `echo "$originz - $padz" | bc -l` 0 0 0 1 "$ScoutImageFile"_1mm
  rm "$ScoutImageFile"_1mm_padx.nii.gz "$ScoutImageFile"_1mm_pady.nii.gz "$ScoutImageFile"_1mm_padz.nii.gz

  # Use "hidden" bbregister DOF options (--6 (default), --9, or --12 are supported)
  log_Msg "Use \"hidden\" bbregister DOF options"
  ${FREESURFER_HOME}/bin/bbregister --s "${FreeSurferSubjectID}_1mm" --mov ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init_1mm.nii.gz --surf white.deformed --init-reg ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}_1mm/mri/transforms/eye.dat --bold --reg ${WD}/EPItoT1w.dat --${dof} --o ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_1mm.nii.gz
  tkregister2 --noedit --reg ${WD}/EPItoT1w.dat --mov ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init_1mm.nii.gz --targ ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}_1mm/mri/T1w_hires.nii.gz --fslregout ${WD}/fMRI2str_1mm.mat
  applywarp --interp=spline -i ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init_1mm.nii.gz -r ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}_1mm/mri/T1w_hires.nii.gz --premat=${WD}/fMRI2str_1mm.mat -o ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_1mm.nii.gz

  convert_xfm -omat ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}_1mm/mri/transforms/temp.mat -concat ${WD}/fMRI2str_1mm.mat ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}_1mm/mri/transforms/real2fs.mat
  convert_xfm -omat ${WD}/fMRI2str_refinement.mat -concat ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}_1mm/mri/transforms/fs2real.mat ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}_1mm/mri/transforms/temp.mat
  rm ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}_1mm/mri/transforms/temp.mat

else
  log_Msg "${FreeSurferSubjectFolder}/${FreeSurferSubjectID}_1mm does not exist. FreeSurferNHP.sh was not used."

  # Run Normally
  log_Msg "Run Normally" 
  # Use "hidden" bbregister DOF options (--6 (default), --9, or --12 are supported)
  log_Msg "Use \"hidden\" bbregister DOF options"
  ${FREESURFER_HOME}/bin/bbregister --s ${FreeSurferSubjectID} --mov ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init.nii.gz --surf white.deformed --init-reg ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}/mri/transforms/eye.dat --bold --reg ${WD}/EPItoT1w.dat --${dof} --o ${WD}/${ScoutInputFile}${ScoutExtension}2T1w.nii.gz
  # Create FSL-style matrix and then combine with existing warp fields
  log_Msg "Create FSL-style matrix and then combine with existing warp fields"
  ${FREESURFER_HOME}/bin/tkregister2 --noedit --reg ${WD}/EPItoT1w.dat --mov ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init.nii.gz --targ ${T1wImage}.nii.gz --fslregout ${WD}/fMRI2str_refinement.mat
fi
${FSLDIR}/bin/convertwarp --relout --rel --warp1=${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init_warp.nii.gz --ref=${T1wImage} --postmat=${WD}/fMRI2str_refinement.mat --out=${WD}/fMRI2str.nii.gz

#create final affine from undistorted fMRI space to T1w space, will need it if it making SEBASED bias field
#overwrite old version of ${WD}/fMRI2str.mat, as it was just the initial registration
#${WD}/${ScoutInputFile}${ScoutExtension}_initT1wReg.mat is from the above epi_reg_dof, initial registration from fMRI space to T1 space
${FSLDIR}/bin/convert_xfm -omat ${WD}/fMRI2str.mat -concat ${WD}/fMRI2str_refinement.mat ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init.mat

if [[ $DistortionCorrection == $SPIN_ECHO_METHOD_OPT ]]
then
    #resample SE field maps, so we can copy to results directories
    #the MNI space versions get made in OneStepResampling, but they aren't actually 1-step resampled
    #we need them before the final bias field computation

    # Set up reference image
    ReferenceImage=${SubjectFolder}/T1w/T1w_acpc_dc.nii.gz

    Files="PhaseOne_gdc_dc PhaseTwo_gdc_dc SBRef_dc"
    for File in ${Files}
    do
        if ((UseJacobian))
        then
            ${FSLDIR}/bin/applywarp --interp=spline -i "${WD}/FieldMap/${File}_jac" -r ${ReferenceImage} --premat=${WD}/fMRI2str.mat -o ${WD}/${File}
        else
            ${FSLDIR}/bin/applywarp --interp=spline -i "${WD}/FieldMap/${File}" -r ${ReferenceImage} --premat=${WD}/fMRI2str.mat -o ${WD}/${File}
        fi
    done

    if [[ $BiasCorrection == "SEBASED" ]]
    then
        #final bias field computation

        #run bias field computation script, go ahead and reuse the same working dir as previous run
        "${HCPPIPEDIR_fMRIVol}/ComputeSpinEchoBiasField.sh" \
            --workingdir="$WD/ComputeSpinEchoBiasField" \
            --subjectfolder="$SubjectFolder" \
            --fmriname="$NameOffMRI" \
            --corticallut="$HCPPIPEDIR/global/config/FreeSurferCorticalLabelTableLut.txt" \
            --subcorticallut="$HCPPIPEDIR/global/config/FreeSurferSubcorticalLabelTableLut.txt" \
            --smoothingfwhm="2" \
            --inputdir="$WD"

        #don't need to do anything more with scout, it is 1-step resampled and bias correction, jacobians reapplied
        Files="PhaseOne_gdc_dc PhaseTwo_gdc_dc"
        for File in ${Files}
        do
            #we need to apply the new bias field to them for output
            ${FSLDIR}/bin/fslmaths ${WD}/${File} -div "$UseBiasField" ${WD}/${File}_unbias

            #don't need the T1w versions
            #${FSLDIR}/bin/imcp ${WD}/${File}_unbias ${SubjectFolder}/T1w/Results/${NameOffMRI}/${NameOffMRI}_${File}
        done
        
        #copy recieve field, pseudo transmit field, and dropouts, etc to results dir
        ${FSLDIR}/bin/imcp "$WD/ComputeSpinEchoBiasField/${NameOffMRI}_dropouts" "$SubjectFolder/T1w/Results/$NameOffMRI/${NameOffMRI}_dropouts"
        ${FSLDIR}/bin/imcp "$WD/ComputeSpinEchoBiasField/${NameOffMRI}_sebased_bias" "$SubjectFolder/T1w/Results/$NameOffMRI/${NameOffMRI}_sebased_bias"
        ${FSLDIR}/bin/imcp "$WD/ComputeSpinEchoBiasField/${NameOffMRI}_sebased_reference" "$SubjectFolder/T1w/Results/$NameOffMRI/${NameOffMRI}_sebased_reference"
        ${FSLDIR}/bin/imcp "$WD/ComputeSpinEchoBiasField/${NameOffMRI}_pseudo_transmit_raw" "$SubjectFolder/T1w/Results/$NameOffMRI/${NameOffMRI}_pseudo_transmit_raw"
        ${FSLDIR}/bin/imcp "$WD/ComputeSpinEchoBiasField/${NameOffMRI}_pseudo_transmit_field" "$SubjectFolder/T1w/Results/$NameOffMRI/${NameOffMRI}_pseudo_transmit_field"
    else
        #don't need to do anything more with scout, it is 1-step resampled and bias correction, jacobians reapplied
        Files="PhaseOne_gdc_dc PhaseTwo_gdc_dc"
        for File in ${Files}
        do
            if [[ $UseBiasField ]]
            then
                #we need to apply the bias field to them for output (really only the phase images, but whatever)
                ${FSLDIR}/bin/fslmaths ${WD}/${File} -div "$UseBiasField" ${WD}/${File}_unbias
            else
                ${FSLDIR}/bin/imcp ${WD}/${File} ${WD}/${File}_unbias
            fi
            #don't need the T1w versions
            #${FSLDIR}/bin/imcp ${WD}/${File}_unbias ${SubjectFolder}/T1w/Results/${NameOffMRI}/${NameOffMRI}_${File}
        done
    fi
fi

# Create warped image with spline interpolation, bias correction and (optional) Jacobian modulation
# NOTE: Jacobian2T1w should be only the topup or fieldmap warpfield's jacobian, not including the gdc warp
# the input scout is the gdc scout, which should already have had the gdc jacobian applied by the main script
log_Msg "Create warped image with spline interpolation, bias correction and (optional) Jacobian modulation"
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${ScoutInputName} -r ${T1wImage}.nii.gz -w ${WD}/fMRI2str.nii.gz -o ${WD}/${ScoutInputFile}${ScoutExtension}2T1w

# resample fieldmap jacobian with new registration
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/Jacobian.nii.gz -r ${T1wImage} --premat=${WD}/fMRI2str.mat -o ${WD}/Jacobian2T1w.nii.gz

if ((UseJacobian))
then
    log_Msg "applying Jacobian modulation"
    if [[ "$UseBiasField" != "" ]]
    then
        ${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFile}${ScoutExtension}2T1w -div ${UseBiasField} -mul ${WD}/Jacobian2T1w.nii.gz ${WD}/${ScoutInputFile}${ScoutExtension}2T1w
    else
        ${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFile}${ScoutExtension}2T1w -mul ${WD}/Jacobian2T1w.nii.gz ${WD}/${ScoutInputFile}${ScoutExtension}2T1w
    fi
else
    log_Msg "not applying Jacobian modulation"
    if [[ "$UseBiasField" != "" ]]
    then
        ${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFile}${ScoutExtension}2T1w -div ${UseBiasField} ${WD}/${ScoutInputFile}${ScoutExtension}2T1w
    fi
    #no else, the commands are overwriting their input
fi

log_Msg "cp ${WD}/${ScoutInputFile}${ScoutExtension}2T1w.nii.gz ${RegOutput}.nii.gz"
cp ${WD}/${ScoutInputFile}${ScoutExtension}2T1w.nii.gz ${RegOutput}.nii.gz

OutputTransformDir=$(dirname ${OutputTransform})
if [ ! -e ${OutputTransformDir} ] ; then
    log_Msg "mkdir -p ${OutputTransformDir}"
    mkdir -p ${OutputTransformDir}
fi

log_Msg "cp ${WD}/fMRI2str.nii.gz ${OutputTransform}.nii.gz"
cp ${WD}/fMRI2str.nii.gz ${OutputTransform}.nii.gz

log_Msg "cp ${WD}/Jacobian2T1w.nii.gz ${JacobianOut}.nii.gz"
cp ${WD}/Jacobian2T1w.nii.gz ${JacobianOut}.nii.gz

# QA image (sqrt of EPI * T1w)
log_Msg 'generating QA image (sqrt of EPI * T1w)'
${FSLDIR}/bin/fslmaths ${T1wRestoreImage}.nii.gz -mul ${RegOutput}.nii.gz -sqrt ${QAImage}.nii.gz

log_Msg "END"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ##########################################

if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# Check registration of EPI to T1w (with all corrections applied)" >> $WD/qa.txt
echo "fslview ${T1wRestoreImage} ${RegOutput} ${QAImage}" >> $WD/qa.txt
echo "# Check undistortion of the scout image" >> $WD/qa.txt
echo "fslview `dirname ${ScoutInputName}`/GradientDistortionUnwarp/Scout ${WD}/${ScoutInputFile}${ScoutExtension}" >> $WD/qa.txt

##############################################################################################

