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
TOPUP_MISMATCHED_METHOD_OPT="TOPUP_MISMATCHED"
INHOMOGENEITY_FIELDMAP_METHOD_OPT="INHOMOGENEITY_FIELDMAP"
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

        '${TOPUP_MISMATCHED_METHOD_OPT}'
             use a pair of Spin Echo EPI images ('Spin Echo Field Maps') for SDC when
             SE fieldmaps have different acquisition parameters than the fMRI data.
             Requires --seechospacing and --seunwarpdir.

        '${GE_HEALTHCARE_LEGACY_METHOD_OPT}'
             use GE HealthCare Legacy specific Gradient Echo Field Maps for SDC (field map in Hz and magnitude image in a single NIfTI file, via --fmapcombined argument).
             This option is maintained for backward compatibility.

        '${GE_HEALTHCARE_METHOD_OPT}'
             use GE HealthCare specific Gradient Echo Field Maps for SDC (field map in Hz and magnitude image in two separate NIfTI files, via --fmapphase and --fmapmag).

        '${PHILIPS_METHOD_OPT}'
             use Philips specific Gradient Echo Field Maps for SDC

        '${INHOMOGENEITY_FIELDMAP_METHOD_OPT}'
             use a pre-computed inhomogeneity fieldmap in Hz (e.g., from TOPUP --fout on
             diffusion B0 images, UKB style). Requires --inhomfmap.

        '${NONE_METHOD_OPT}'
             do not use any SDC"


#Optional Args
opts_AddOptional '--workingdir' 'WD' 'path' 'working dir'

opts_AddOptional '--echospacing' 'EchoSpacing' 'spacing (seconds)' "*effective* echo spacing of fMRI input, in seconds"

opts_AddOptional '--unwarpdir' 'UnwarpDir' '{x,y,z,x-,y-,z-} or {i,j,k,i-,j-,k-}>]' "PE direction for unwarping according to the *voxel* axes. Polarity matters! If your distortions are twice as bad as in the original images, try using the opposite polarity for --unwarpdir."

opts_AddOptional '--SEPhaseNeg' 'SpinEchoPhaseEncodeNegative' 'number' "'negative' polarity SE-EPI image"

opts_AddOptional '--SEPhasePos' 'SpinEchoPhaseEncodePositive' 'number' "'positive' polarity SE-EPI image"

opts_AddOptional '--topupconfig' 'TopupConfig' 'file' "topup config file"

opts_AddOptional '--sessionfolder' 'SessionFolder' 'path' "session processing folder"

opts_AddOptional '--fmapmag' 'MagnitudeInputName' 'field_map' "field map magnitude images (@-separated)"

opts_AddOptional '--fmapphase' 'PhaseInputName' 'image' "fieldmap phase images in radians (Siemens/Philips) or in Hz (GE HealthCare)"

opts_AddOptional '--echodiff' 'deltaTE' 'number (milliseconds)' "difference of echo times for fieldmap, in milliseconds"

opts_AddOptional '--fmapcombined' 'GEB0InputName' 'image' "GE HealthCare Legacy field map only (two volumes: 1. field map in Hz  and 2. magnitude image)" '' '--fmap'

opts_AddOptional '--dof' 'dof' '6 OR 9 OR 12' "degrees of freedom for EPI to T1 registration" '6'

opts_AddOptional '--qaimage' 'QAImage' 'name' "output name for QA image" "T1wMulEPI"

opts_AddOptional '--preregistertool' 'PreregisterTool' "'epi_reg' OR 'flirt'" "'epi_reg' (default) OR 'flirt'" "epi_reg"

opts_AddOptional '--fmriname' 'NameOffMRI' 'name' "name of fmri run"

opts_AddOptional '--is-longitudinal' 'IsLongitudinal' "longitudinal processing" "0"

opts_AddOptional '--t1w-cross2long-xfm' 'T1wCross2LongXfm' ".mat Affine transform from cross-sectional T1w_acpc_dc space to longitudinal template space. Mandatory if is-longitudinal is set." "NONE"

opts_AddOptional '--seechospacing' 'SEEchoSpacing' 'spacing (seconds)' "effective echo spacing of SE fieldmaps, in seconds. Required for --method=${TOPUP_MISMATCHED_METHOD_OPT}."

opts_AddOptional '--seunwarpdir' 'SEUnwarpDir' '{x,y,z,x-,y-,z-} or {i,j,k,i-,j-,k-}' "PE direction of SE fieldmaps according to the *voxel* axes. Required for --method=${TOPUP_MISMATCHED_METHOD_OPT}. Can differ from --unwarpdir."

opts_AddOptional '--inhomfmap' 'InhomFieldMap' 'image' "pre-computed inhomogeneity fieldmap in Hz (e.g., from TOPUP --fout on diffusion B0 images). Required for --method=${INHOMOGENEITY_FIELDMAP_METHOD_OPT}."

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

IsLongitudinal=$(opts_StringToBool "$IsLongitudinal")

if (( $IsLongitudinal )); then
    if [ ! -f "$T1wCross2LongXfm" ]; then
        log_Err_Abort "--t1w-cross2long-xfm must point to a valid file when --is-longitudinal is used"
    fi
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
        if [[ "$DistortionCorrection" != "${SPIN_ECHO_METHOD_OPT}" && "$DistortionCorrection" != "${TOPUP_MISMATCHED_METHOD_OPT}" ]]
        then
            log_Err_Abort "--biascorrection=SEBASED is only available with --method=${SPIN_ECHO_METHOD_OPT} or --method=${TOPUP_MISMATCHED_METHOD_OPT}"
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

ScoutInputFile=$(basename $ScoutInputName)
T1wBrainImageFile=$(basename $T1wBrainImage)
RegOutput=$($FSLDIR/bin/remove_ext $RegOutput)
GlobalScripts=${HCPPIPEDIR_Global}

if [[ $WD == "" ]]
then
    WD="${RegOutput}.wdir"
fi

log_Msg "START"

#ScoutExtension must initialize for both cross-sectional and longitudinal modes.

case $DistortionCorrection in
	${FIELDMAP_METHOD_OPT} | ${SIEMENS_METHOD_OPT} | ${GE_HEALTHCARE_LEGACY_METHOD_OPT} | ${GE_HEALTHCARE_METHOD_OPT} | ${PHILIPS_METHOD_OPT} | ${SPIN_ECHO_METHOD_OPT} | ${TOPUP_MISMATCHED_METHOD_OPT} | ${INHOMOGENEITY_FIELDMAP_METHOD_OPT} )
		ScoutExtension="_undistorted"
	;;
	${NONE_METHOD_OPT})
		ScoutExtension="_nosdc"
	;;
esac


if (( ! IsLongitudinal )); then

    mkdir -p $WD

    # Record the input options in a log file
    echo "$0 $@" >> $WD/log.txt
    echo "PWD = $(pwd)" >> $WD/log.txt
    echo "date: $(date)" >> $WD/log.txt
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

            # Test if Magnitude Brain and T1w Brain Are Similar in Size, if not, assume Magnitude Brain Extraction
            # Failed and Must Be Retried After Removing Bias Field
            MagnitudeBrainSize=$(${FSLDIR}/bin/fslstats ${WD}/Magnitude_brain -V | cut -d " " -f 2)
            T1wBrainSize=$(${FSLDIR}/bin/fslstats ${WD}/${T1wBrainImageFile} -V | cut -d " " -f 2)

            if [[ "$(echo "((${MagnitudeBrainSize} / ${T1wBrainSize}) > 1.25) || ((${MagnitudeBrainSize} / ${T1wBrainSize}) < 0.75)" | bc -l)" == 1* ]] ; then
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
            ReferenceImage=${SessionFolder}/T1w/T1w_acpc_dc.nii.gz
            for File in ${Files}
            do
                #NOTE: this relies on TopupPreprocessingAll generating _jac versions of the files
                if ((UseJacobian))
                then
                    ${FSLDIR}/bin/applywarp --interp=spline -i "${WD}/FieldMap/${File}_jac" -r ${ReferenceImage} --premat=${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init.mat -o ${WD}/${File}
                else
                    ${FSLDIR}/bin/applywarp --interp=spline -i "${WD}/FieldMap/${File}" -r ${ReferenceImage} --premat=${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init.mat -o ${WD}/${File}
                fi
            done

            #correct filename is already set in UseBiasField, but we have to compute it if using SEBASED
            #we compute it in this script because it needs outputs from topup, and because it should be applied to the scout image
            if [[ "$BiasCorrection" == "SEBASED" ]]
            then
                mkdir -p "$WD/ComputeSpinEchoBiasField"
                "${HCPPIPEDIR_fMRIVol}/ComputeSpinEchoBiasField.sh" \
                    --workingdir="$WD/ComputeSpinEchoBiasField" \
                    --subjectfolder="$SessionFolder" \
                    --fmriname="$NameOffMRI" \
                    --corticallut="$HCPPIPEDIR/global/config/FreeSurferCorticalLabelTableLut.txt" \
                    --subcorticallut="$HCPPIPEDIR/global/config/FreeSurferSubcorticalLabelTableLut.txt" \
                    --smoothingfwhm="2" \
                    --inputdir="$WD"
            fi


            ;;

        ${TOPUP_MISMATCHED_METHOD_OPT})

            # -----------------------------------------------
            # -- Mismatched Spin Echo Field Maps for fMRI  --
            # -----------------------------------------------
            # SE fieldmaps may differ from BOLD in echo spacing, resolution, PE direction, and matrix.
            # Approach: run topup on the SE pair alone to estimate the B0 field map,
            # then recompute the warp for BOLD acquisition parameters (echo spacing, PE direction).
            # Adapted from T2wToT1wDistortionCorrectAndReg.sh structural pipeline method.

            log_Msg "---> Mismatched SE distortion correction"

            # 1/ Select SE scout based on SE unwarp direction polarity
            if [[ ${SEUnwarpDir} = [xyij] ]] ; then
                SEScoutInputName="${SpinEchoPhaseEncodePositive}"
            elif [[ ${SEUnwarpDir} = -[xyij] || ${SEUnwarpDir} = [xyij]- ]] ; then
                SEScoutInputName="${SpinEchoPhaseEncodeNegative}"
            else
                log_Err_Abort "Invalid entry for --seunwarpdir ($SEUnwarpDir)"
            fi

            # 2/ Run topup on SE pair to estimate B0 field map
            log_Msg "Running TopupPreprocessingAll with SE parameters"
            ${GlobalScripts}/TopupPreprocessingAll.sh \
                --workingdir=${WD}/FieldMap \
                --phaseone=${SpinEchoPhaseEncodeNegative} \
                --phasetwo=${SpinEchoPhaseEncodePositive} \
                --scoutin=${SEScoutInputName} \
                --echospacing=${SEEchoSpacing} \
                --unwarpdir=${SEUnwarpDir} \
                --ofmapmag=${WD}/Magnitude \
                --ofmapmagbrain=${WD}/Magnitude_brain \
                --ofmap=${WD}/FieldMap \
                --ojacobian=${WD}/Jacobian_SE \
                --gdcoeffs=${GradientDistortionCoeffs} \
                --topupconfig=${TopupConfig} \
                --usejacobian=${UseJacobian}

            # 3/ Convert BOLD UnwarpDir to trailing-minus format for convertwarp --shiftdir
            # (UnwarpDir is in leading-minus format from earlier conversion, e.g., "-x")
            UnwarpDirShift=${UnwarpDir}
            if [ "${UnwarpDirShift}" = "-x" ] ; then UnwarpDirShift="x-" ; fi
            if [ "${UnwarpDirShift}" = "-y" ] ; then UnwarpDirShift="y-" ; fi
            if [ "${UnwarpDirShift}" = "-z" ] ; then UnwarpDirShift="z-" ; fi

            # 4/ Compute BOLD shift/warp from topup field map using BOLD echo spacing
            # The field map (rad/s) represents B0 inhomogeneity independent of acquisition.
            # Using BOLD dwell time (EchoSpacing) produces the correct distortion for BOLD data.
            log_Msg "Computing BOLD warp from SE-derived field map"
            ${FSLDIR}/bin/fugue --loadfmap=${WD}/FieldMap --dwell=${EchoSpacing} --saveshift=${WD}/FieldMap_ShiftMapBOLD.nii.gz
            ${FSLDIR}/bin/convertwarp --relout --rel --ref=${WD}/Magnitude --shiftmap=${WD}/FieldMap_ShiftMapBOLD.nii.gz --shiftdir=${UnwarpDirShift} --out=${WD}/FieldMap_WarpBOLD.nii.gz

            # 5/ Warp SE magnitude brain with BOLD warp to simulate BOLD distortion, then register to BOLD scout
            log_Msg "Registering warped SE magnitude to BOLD scout"
            ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/Magnitude_brain -r ${WD}/Magnitude_brain -w ${WD}/FieldMap_WarpBOLD.nii.gz -o ${WD}/Magnitude_brain_warpedBOLD
            ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/Magnitude_brain_warpedBOLD -ref ${ScoutInputName} -omat ${WD}/Fieldmap2Scout.mat -out ${WD}/Magnitude_brain_warpedBOLD2Scout -searchrx -30 30 -searchry -30 30 -searchrz -30 30

            # 6/ Transform field map to BOLD space
            log_Msg "Transforming field map to BOLD space"
            ${FSLDIR}/bin/flirt -in ${WD}/FieldMap.nii.gz -ref ${ScoutInputName} -applyxfm -init ${WD}/Fieldmap2Scout.mat -out ${WD}/FieldMap2Scout

            # 7/ Create final BOLD warp field from transformed field map
            log_Msg "Creating final BOLD WarpField"
            ${FSLDIR}/bin/fugue --loadfmap=${WD}/FieldMap2Scout --dwell=${EchoSpacing} --saveshift=${WD}/FieldMap2Scout_ShiftMap.nii.gz
            ${FSLDIR}/bin/convertwarp --relout --rel --ref=${ScoutInputName} --shiftmap=${WD}/FieldMap2Scout_ShiftMap.nii.gz --shiftdir=${UnwarpDirShift} --out=${WD}/WarpField.nii.gz

            # 8/ Compute Jacobian from BOLD WarpField
            log_Msg "Computing Jacobian"
            ${FSLDIR}/bin/convertwarp --rel -w ${WD}/WarpField.nii.gz -r ${WD}/WarpField.nii.gz --jacobian=${WD}/Jacobian2T1w.nii.gz -o ${WD}/junk_warp
            ${FSLDIR}/bin/fslmaths ${WD}/Jacobian2T1w.nii.gz -Tmean ${WD}/Jacobian2T1w.nii.gz
            ${FSLDIR}/bin/imcp ${WD}/Jacobian2T1w.nii.gz ${WD}/Jacobian.nii.gz

            # 9/ Apply warp to BOLD scout for undistorted image
            log_Msg "Applying warp to BOLD scout"
            ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${ScoutInputName} -r ${ScoutInputName} -w ${WD}/WarpField.nii.gz -o ${WD}/${ScoutInputFile}${ScoutExtension}

            # 10/ Optional Jacobian correction to scout
            if ((UseJacobian))
            then
                log_Msg "Applying Jacobian correction to scout image"
                ${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFile}${ScoutExtension} -mul ${WD}/Jacobian.nii.gz ${WD}/${ScoutInputFile}${ScoutExtension}
            fi

            # 11/ Register undistorted scout to T1w
            log_Msg "Registering undistorted scout to T1w"
            if [ "$PreregisterTool" = "epi_reg" ] ; then
                log_Msg "... running epi_reg (dof ${dof})"
                ${HCPPIPEDIR_Global}/epi_reg_dof --dof=${dof} --epi=${WD}/${ScoutInputFile}${ScoutExtension} --t1=${T1wImage} --t1brain=${WD}/${T1wBrainImageFile} --out=${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init
            elif [ "$PreregisterTool" = "flirt" ] ; then
                log_Msg "... running flirt"
                ${FSLDIR}/bin/flirt -in ${WD}/${ScoutInputFile}${ScoutExtension} -ref ${WD}/${T1wBrainImageFile} -out ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init -omat ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init.mat -dof ${dof}
            else
                log_Err_Abort "--preregistertool=${PreregisterTool} is not a valid setting."
            fi

            # 12/ Generate combined warpfields and spline interpolated images
            log_Msg "Generating combined warpfields"
            ${FSLDIR}/bin/convertwarp --relout --rel -r ${T1wImage} --warp1=${WD}/WarpField.nii.gz --postmat=${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init.mat -o ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init_warp
            ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/Jacobian.nii.gz -r ${T1wImage} --premat=${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init.mat -o ${WD}/Jacobian2T1w.nii.gz
            # 1-step resample from input (gdc) scout
            ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${ScoutInputName} -r ${T1wImage} -w ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init_warp -o ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init

            # SEBASED bias field support for mismatched SE
            # SE images must be registered to T1w space to match BOLD SBRef resolution
            # for ComputeSpinEchoBiasField.sh (which requires all inputs in the same voxel grid)

            # Register SE magnitude to undistorted BOLD space
            log_Msg "Registering SE magnitude to undistorted BOLD space"
            ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/Magnitude_brain -ref ${WD}/${ScoutInputFile}${ScoutExtension} -omat ${WD}/SE2BOLD_undistorted.mat -searchrx -30 30 -searchry -30 30 -searchrz -30 30

            # Compose SE->T1w transform: SE -> BOLD_undistorted -> T1w
            ${FSLDIR}/bin/convert_xfm -omat ${WD}/SE2T1w_init.mat -concat ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init.mat ${WD}/SE2BOLD_undistorted.mat

            # Resample SE phase images and BOLD SBRef to T1w space
            ReferenceImage=${SessionFolder}/T1w/T1w_acpc_dc.nii.gz
            Files="PhaseOne_gdc_dc PhaseTwo_gdc_dc"
            for File in ${Files}
            do
                if ((UseJacobian))
                then
                    ${FSLDIR}/bin/applywarp --interp=spline -i "${WD}/FieldMap/${File}_jac" -r ${ReferenceImage} --premat=${WD}/SE2T1w_init.mat -o ${WD}/${File}
                else
                    ${FSLDIR}/bin/applywarp --interp=spline -i "${WD}/FieldMap/${File}" -r ${ReferenceImage} --premat=${WD}/SE2T1w_init.mat -o ${WD}/${File}
                fi
            done
            # SBRef_dc: use the undistorted BOLD scout resampled to T1w
            if ((UseJacobian))
            then
                ${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init -mul 1 ${WD}/SBRef_dc
            else
                # Without Jacobian, resample the original scout to T1w space
                ${FSLDIR}/bin/applywarp --interp=spline -i ${ScoutInputName} -r ${ReferenceImage} -w ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init_warp -o ${WD}/SBRef_dc
            fi

            # Compute SEBASED bias field if requested
            if [[ "$BiasCorrection" == "SEBASED" ]]
            then
                mkdir -p "$WD/ComputeSpinEchoBiasField"
                "${HCPPIPEDIR_fMRIVol}/ComputeSpinEchoBiasField.sh" \
                    --workingdir="$WD/ComputeSpinEchoBiasField" \
                    --subjectfolder="$SessionFolder" \
                    --fmriname="$NameOffMRI" \
                    --corticallut="$HCPPIPEDIR/global/config/FreeSurferCorticalLabelTableLut.txt" \
                    --subcorticallut="$HCPPIPEDIR/global/config/FreeSurferSubcorticalLabelTableLut.txt" \
                    --smoothingfwhm="2" \
                    --inputdir="$WD"
            fi

            ;;

        ${INHOMOGENEITY_FIELDMAP_METHOD_OPT})

            # -----------------------------------------------------------
            # -- Pre-computed Inhomogeneity Fieldmap (UKB style)       --
            # -----------------------------------------------------------
            # The input is a pre-computed B0 inhomogeneity fieldmap in Hz,
            # e.g., from TOPUP --fout on reverse-PE diffusion B0 images.
            # This is registered to T1w space and used directly for distortion
            # correction via epi_reg_dof. No phase images or delta TE needed.

            log_Msg "---> Inhomogeneity Fieldmap distortion correction"

            # 1/ Convert fieldmap from Hz to rad/s (FUGUE/epi_reg expect rad/s)
            log_Msg "Converting fieldmap from Hz to rad/s"
            ${FSLDIR}/bin/fslmaths ${InhomFieldMap} -mul 6.2832 ${WD}/FieldMap_rads_orig -odt float

            # 2/ Register fieldmap to T1w space
            # Use abs(fieldmap) as a registerable proxy (has tissue contrast from B0 inhomogeneity pattern)
            log_Msg "Registering fieldmap to T1w space"
            ${FSLDIR}/bin/fslmaths ${WD}/FieldMap_rads_orig -abs ${WD}/FieldMap_abs
            ${FSLDIR}/bin/bet ${WD}/FieldMap_abs ${WD}/FieldMap_abs_brain -f 0.35 -m
            ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/FieldMap_abs_brain -ref ${WD}/${T1wBrainImageFile} -omat ${WD}/fmap2T1w.mat -out ${WD}/FieldMap_abs2T1w -searchrx -30 30 -searchry -30 30 -searchrz -30 30

            # Apply registration to the actual fieldmap (rad/s)
            ${FSLDIR}/bin/flirt -in ${WD}/FieldMap_rads_orig -ref ${T1wImage} -applyxfm -init ${WD}/fmap2T1w.mat -out ${WD}/FieldMap_rads2T1w

            # 3/ Brain-mask the registered fieldmap using T1w brain mask
            log_Msg "Brain-masking and extrapolating fieldmap"
            ${FSLDIR}/bin/fslmaths ${WD}/${T1wBrainImageFile} -abs -bin ${WD}/FieldMap_T1w_brain_mask
            ${FSLDIR}/bin/fslmaths ${WD}/FieldMap_rads2T1w -mas ${WD}/FieldMap_T1w_brain_mask ${WD}/FieldMap_rads2T1w_brain

            # 4/ Extrapolate fieldmap beyond mask to avoid edge effects (fugue --unmaskfmap)
            # and demean to avoid spurious voxel shifts (following Philips method pattern)
            ${FSLDIR}/bin/fugue --loadfmap=${WD}/FieldMap_rads2T1w_brain --mask=${WD}/FieldMap_T1w_brain_mask --unmaskfmap --savefmap=${WD}/FieldMap_rads2T1w_unmasked --unwarpdir=${UnwarpDir}

            # Demean: subtract median within brain mask
            fmap_median=$(${FSLDIR}/bin/fslstats ${WD}/FieldMap_rads2T1w_unmasked -k ${WD}/FieldMap_T1w_brain_mask -P 50)
            ${FSLDIR}/bin/fslmaths ${WD}/FieldMap_rads2T1w_unmasked -sub ${fmap_median} ${WD}/FieldMap

            # 5/ Copy scout image
            cp ${ScoutInputName}.nii.gz ${WD}/Scout.nii.gz

            # Test if T1w Brain is much larger, suggesting poor fieldmap-based brain extraction;
            # check if NHP (FreeSurferNHP) — if so, create brain-extracted scout for registration
            MagnitudeBrainSize=$(${FSLDIR}/bin/fslstats ${WD}/${T1wBrainImageFile} -V | cut -d " " -f 2)
            if [ -e ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}_1mm ] ; then
                # NHP case: extract scout brain for registration
                ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/Scout.nii.gz -ref ${T1wImage} -omat "$WD"/Scout2T1w.mat -out ${WD}/Scout2T1w.nii.gz -searchrx -30 30 -searchry -30 30 -searchrz -30 30
                ${FSLDIR}/bin/convert_xfm -omat "$WD"/T1w2Scout.mat -inverse "$WD"/Scout2T1w.mat
                ${FSLDIR}/bin/applywarp --interp=nn -i ${WD}/${T1wBrainImageFile} -r ${WD}/Scout.nii.gz --premat="$WD"/T1w2Scout.mat -o ${WD}/Scout_brain_mask.nii.gz
                fslmaths ${WD}/Scout_brain_mask.nii.gz -bin ${WD}/Scout_brain_mask.nii.gz
                fslmaths ${WD}/Scout.nii.gz -mas ${WD}/Scout_brain_mask.nii.gz ${WD}/Scout_brain.nii.gz

                # register scout to T1w using fieldmap (fieldmap already in T1w space, so --nofmapreg)
                ${HCPPIPEDIR_Global}/epi_reg_dof --dof=${dof} --epi=${WD}/Scout_brain.nii.gz --t1=${T1wImage} --t1brain=${WD}/${T1wBrainImageFile} --out=${WD}/${ScoutInputFile}${ScoutExtension} --fmap=${WD}/FieldMap.nii.gz --fmapmag=${T1wImage} --fmapmagbrain=${WD}/${T1wBrainImageFile} --echospacing=${EchoSpacing} --pedir=${UnwarpDir} --nofmapreg
            else
                # register scout to T1w using fieldmap (fieldmap already in T1w space, so --nofmapreg)
                ${HCPPIPEDIR_Global}/epi_reg_dof --dof=${dof} --epi=${WD}/Scout.nii.gz --t1=${T1wImage} --t1brain=${WD}/${T1wBrainImageFile} --out=${WD}/${ScoutInputFile}${ScoutExtension} --fmap=${WD}/FieldMap.nii.gz --fmapmag=${T1wImage} --fmapmagbrain=${WD}/${T1wBrainImageFile} --echospacing=${EchoSpacing} --pedir=${UnwarpDir} --nofmapreg
            fi

            # 6/ Create spline interpolated output for scout to T1w + apply bias field correction
            ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${ScoutInputName} -r ${T1wImage} -w ${WD}/${ScoutInputFile}${ScoutExtension}_warp.nii.gz -o ${WD}/${ScoutInputFile}${ScoutExtension}_1vol.nii.gz
            ${FSLDIR}/bin/immv ${WD}/${ScoutInputFile}${ScoutExtension}_1vol.nii.gz ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init.nii.gz
            ${FSLDIR}/bin/immv ${WD}/${ScoutInputFile}${ScoutExtension}_warp.nii.gz ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init_warp.nii.gz
            cp "${WD}/${ScoutInputFile}${ScoutExtension}_init.mat" "${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init.mat"

            # 7/ Compute Jacobian of the distortion correction warp (from epi_reg_dof)
            ${FSLDIR}/bin/convertwarp --rel -w ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init_warp.nii.gz -r ${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init_warp.nii.gz --jacobian=${WD}/Jacobian2T1w.nii.gz -o ${WD}/junk_warp
            ${FSLDIR}/bin/fslmaths ${WD}/Jacobian2T1w.nii.gz -Tmean ${WD}/Jacobian2T1w.nii.gz
            ${FSLDIR}/bin/imcp ${WD}/Jacobian2T1w.nii.gz ${WD}/Jacobian.nii.gz

            #jacobian and bias field are applied outside the case, as they are done the same as other fieldmap methods
            ;;

        ${NONE_METHOD_OPT})

                # NOTE: To work with later code a uniform Jacobian is created.

                log_Msg "---> No distortion correction"
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

    res=$(fslorient -getsform $ScoutImage | cut -d " " -f 1 | cut -d "-" -f 2)
    oldsform=$(fslorient -getsform $ScoutImage)
    newsform=""
    i=1
    while [ $i -le 12 ] ; do
        oldelement=$(echo $oldsform | cut -d " " -f $i)
        newelement=$(echo "scale=1; $oldelement / $res" | bc -l)
        newsform=$(echo "$newsform""$newelement"" ")
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
    newsform=$(echo "$newsform""0 0 0 1" | sed 's/  / /g')

    cp "$ScoutImage" "$ScoutImageFile"_1mm.nii.gz
    fslorient -setsform $newsform "$ScoutImageFile"_1mm.nii.gz
    fslhd -x "$ScoutImageFile"_1mm.nii.gz | sed s/"dx = '${res}'"/"dx = '1'"/g | sed s/"dy = '${res}'"/"dy = '1'"/g | sed s/"dz = '${res}'"/"dz = '1'"/g | fslcreatehd - "$ScoutImageFile"_1mm_head.nii.gz
    fslmaths "$ScoutImageFile"_1mm_head.nii.gz -add "$ScoutImageFile"_1mm.nii.gz "$ScoutImageFile"_1mm.nii.gz
    fslorient -copysform2qform "$ScoutImageFile"_1mm.nii.gz
    rm "$ScoutImageFile"_1mm_head.nii.gz
    dimex=$(fslval "$ScoutImageFile"_1mm dim1)
    dimey=$(fslval "$ScoutImageFile"_1mm dim2)
    dimez=$(fslval "$ScoutImageFile"_1mm dim3)
    padx=$(echo "(256 - $dimex) / 2" | bc)
    pady=$(echo "(256 - $dimey) / 2" | bc)
    padz=$(echo "(256 - $dimez) / 2" | bc)
    fslcreatehd $padx $dimey $dimez 1 1 1 1 1 0 0 0 16 "$ScoutImageFile"_1mm_padx
    fslmerge -x "$ScoutImageFile"_1mm "$ScoutImageFile"_1mm_padx "$ScoutImageFile"_1mm "$ScoutImageFile"_1mm_padx
    fslcreatehd 256 $pady $dimez 1 1 1 1 1 0 0 0 16 "$ScoutImageFile"_1mm_pady
    fslmerge -y "$ScoutImageFile"_1mm "$ScoutImageFile"_1mm_pady "$ScoutImageFile"_1mm "$ScoutImageFile"_1mm_pady
    fslcreatehd 256 256 $padz 1 1 1 1 1 0 0 0 16 "$ScoutImageFile"_1mm_padz
    fslmerge -z "$ScoutImageFile"_1mm "$ScoutImageFile"_1mm_padz "$ScoutImageFile"_1mm "$ScoutImageFile"_1mm_padz
    fslorient -setsformcode 1 "$ScoutImageFile"_1mm
    fslorient -setsform -1 0 0 $(echo "$originx + $padx" | bc -l) 0 1 0 $(echo "$originy - $pady" | bc -l) 0 0 1 $(echo "$originz - $padz" | bc -l) 0 0 0 1 "$ScoutImageFile"_1mm
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
else # IsLongitudinal=1

    ${FSLDIR}/bin/convert_xfm -omat ${WD}/fMRI2str_refinement-long.mat -concat "$T1wCross2LongXfm" ${WD}/fMRI2str_refinement.mat
    cp ${WD}/fMRI2str_refinement-long.mat ${WD}/fMRI2str_refinement.mat
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
    ReferenceImage=${SessionFolder}/T1w/T1w_acpc_dc.nii.gz

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
            --subjectfolder="$SessionFolder" \
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
            #${FSLDIR}/bin/imcp ${WD}/${File}_unbias ${SessionFolder}/T1w/Results/${NameOffMRI}/${NameOffMRI}_${File}
        done

		#required in longitudinal mode
		mkdir -p "$SessionFolder/T1w/Results/$NameOffMRI"

        #copy recieve field, pseudo transmit field, and dropouts, etc to results dir
        ${FSLDIR}/bin/imcp "$WD/ComputeSpinEchoBiasField/${NameOffMRI}_dropouts" "$SessionFolder/T1w/Results/$NameOffMRI/${NameOffMRI}_dropouts"
        ${FSLDIR}/bin/imcp "$WD/ComputeSpinEchoBiasField/${NameOffMRI}_sebased_bias" "$SessionFolder/T1w/Results/$NameOffMRI/${NameOffMRI}_sebased_bias"
        ${FSLDIR}/bin/imcp "$WD/ComputeSpinEchoBiasField/${NameOffMRI}_sebased_reference" "$SessionFolder/T1w/Results/$NameOffMRI/${NameOffMRI}_sebased_reference"
        ${FSLDIR}/bin/imcp "$WD/ComputeSpinEchoBiasField/${NameOffMRI}_pseudo_transmit_raw" "$SessionFolder/T1w/Results/$NameOffMRI/${NameOffMRI}_pseudo_transmit_raw"
        ${FSLDIR}/bin/imcp "$WD/ComputeSpinEchoBiasField/${NameOffMRI}_pseudo_transmit_field" "$SessionFolder/T1w/Results/$NameOffMRI/${NameOffMRI}_pseudo_transmit_field"
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
            #${FSLDIR}/bin/imcp ${WD}/${File}_unbias ${SessionFolder}/T1w/Results/${NameOffMRI}/${NameOffMRI}_${File}
        done
    fi
fi

if [[ $DistortionCorrection == $TOPUP_MISMATCHED_METHOD_OPT ]]
then
    # resample SE field maps using refined registration for TOPUP_MISMATCHED
    # SE images are in SE space, so compose: SE -> BOLD_undistorted -> T1w (refined)
    ${FSLDIR}/bin/convert_xfm -omat ${WD}/SE2T1w.mat -concat ${WD}/fMRI2str.mat ${WD}/SE2BOLD_undistorted.mat

    ReferenceImage=${SessionFolder}/T1w/T1w_acpc_dc.nii.gz

    Files="PhaseOne_gdc_dc PhaseTwo_gdc_dc"
    for File in ${Files}
    do
        if ((UseJacobian))
        then
            ${FSLDIR}/bin/applywarp --interp=spline -i "${WD}/FieldMap/${File}_jac" -r ${ReferenceImage} --premat=${WD}/SE2T1w.mat -o ${WD}/${File}
        else
            ${FSLDIR}/bin/applywarp --interp=spline -i "${WD}/FieldMap/${File}" -r ${ReferenceImage} --premat=${WD}/SE2T1w.mat -o ${WD}/${File}
        fi
    done
    # SBRef_dc: resample BOLD scout to T1w using refined fMRI2str warp
    ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${ScoutInputName} -r ${ReferenceImage} -w ${WD}/fMRI2str.nii.gz -o ${WD}/SBRef_dc

    if [[ $BiasCorrection == "SEBASED" ]]
    then
        # final bias field computation with refined registration
        "${HCPPIPEDIR_fMRIVol}/ComputeSpinEchoBiasField.sh" \
            --workingdir="$WD/ComputeSpinEchoBiasField" \
            --subjectfolder="$SessionFolder" \
            --fmriname="$NameOffMRI" \
            --corticallut="$HCPPIPEDIR/global/config/FreeSurferCorticalLabelTableLut.txt" \
            --subcorticallut="$HCPPIPEDIR/global/config/FreeSurferSubcorticalLabelTableLut.txt" \
            --smoothingfwhm="2" \
            --inputdir="$WD"

        Files="PhaseOne_gdc_dc PhaseTwo_gdc_dc"
        for File in ${Files}
        do
            ${FSLDIR}/bin/fslmaths ${WD}/${File} -div "$UseBiasField" ${WD}/${File}_unbias
        done

        mkdir -p "$SessionFolder/T1w/Results/$NameOffMRI"

        ${FSLDIR}/bin/imcp "$WD/ComputeSpinEchoBiasField/${NameOffMRI}_dropouts" "$SessionFolder/T1w/Results/$NameOffMRI/${NameOffMRI}_dropouts"
        ${FSLDIR}/bin/imcp "$WD/ComputeSpinEchoBiasField/${NameOffMRI}_sebased_bias" "$SessionFolder/T1w/Results/$NameOffMRI/${NameOffMRI}_sebased_bias"
        ${FSLDIR}/bin/imcp "$WD/ComputeSpinEchoBiasField/${NameOffMRI}_sebased_reference" "$SessionFolder/T1w/Results/$NameOffMRI/${NameOffMRI}_sebased_reference"
        ${FSLDIR}/bin/imcp "$WD/ComputeSpinEchoBiasField/${NameOffMRI}_pseudo_transmit_raw" "$SessionFolder/T1w/Results/$NameOffMRI/${NameOffMRI}_pseudo_transmit_raw"
        ${FSLDIR}/bin/imcp "$WD/ComputeSpinEchoBiasField/${NameOffMRI}_pseudo_transmit_field" "$SessionFolder/T1w/Results/$NameOffMRI/${NameOffMRI}_pseudo_transmit_field"
    else
        Files="PhaseOne_gdc_dc PhaseTwo_gdc_dc"
        for File in ${Files}
        do
            if [[ $UseBiasField ]]
            then
                ${FSLDIR}/bin/fslmaths ${WD}/${File} -div "$UseBiasField" ${WD}/${File}_unbias
            else
                ${FSLDIR}/bin/imcp ${WD}/${File} ${WD}/${File}_unbias
            fi
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

