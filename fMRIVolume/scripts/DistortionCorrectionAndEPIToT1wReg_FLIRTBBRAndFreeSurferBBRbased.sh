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

# NHP-specific options
opts_AddOptional '--bbr' 'BBR' "NONE or T1w or T2w" "BBR registration method. Use T1w for MION data, T2w for BOLD fMRI (default), or NONE to skip BBR." "T2w"

opts_AddOptional '--wmprojabs' 'WMProjAbs' 'number' "White matter projection absolute value for FreeSurfer BBR (used when --bbr=T2w)" ""

opts_AddOptional '--SEPhaseNeg2' 'SpinEchoPhaseEncodeNegative2' 'image' "Second 'negative' polarity SE-EPI image for TOPUP (NHP-specific)"

opts_AddOptional '--SEPhasePos2' 'SpinEchoPhaseEncodePositive2' 'image' "Second 'positive' polarity SE-EPI image for TOPUP (NHP-specific)"

opts_AddOptional '--SEPhaseZero' 'SpinEchoPhaseEncodeZero' 'image' "Zero phase encoding SE-EPI image for TOPUP (NHP-specific)" "NONE"

opts_AddOptional '--scannerpatientposition' 'ScannerPatientPosition' 'position' "Scanner patient position (NHP-specific)" ""

opts_AddOptional '--truepatientposition' 'TruePatientPosition' 'position' "True patient position (NHP-specific)" ""

opts_AddOptional '--initworldmat' 'InitWorldMat' 'matrix' "Initial world matrix for registration (NHP-specific)" ""

opts_AddOptional '--SEPhaseZeroFSBrainmask' 'SpinEchoPhaseEncodeZeroFSBrainmask' 'mask' "FreeSurfer brain mask for SEPhaseZero (NHP-specific)" ""

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
	${FIELDMAP_METHOD_OPT} | ${SIEMENS_METHOD_OPT} | ${GE_HEALTHCARE_LEGACY_METHOD_OPT} | ${GE_HEALTHCARE_METHOD_OPT} | ${PHILIPS_METHOD_OPT} | ${SPIN_ECHO_METHOD_OPT} )
		ScoutExtension="_undistorted" 
	;;
	${NONE_METHOD_OPT})
		ScoutExtension="_nosdc" 
	;;
esac


if [[ ! $IsLongitudinal || $SPECIES != "Human" ]]; then # - for NHP TH 2017-2024
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
                if [ "$SPECIES" != "Human" && "$BBR" == "NONE" ] ; then # - for NHP TH 2017-2024
				    # when EPI data does not have clear contrat between gray/white bbr is not be effective - Takuya Hayashi inserted for NHP
                    log_Msg "Run epi_reg_dof_nobbr"
					${HCPPIPEDIR_Global}/epi_reg_dof_nobbr --dof=${dof} --epi=${WD}/Scout_brain.nii.gz --t1=${T1wImage} --t1brain=${WD}/${T1wBrainImageFile} --out=${WD}/${ScoutInputFile}${ScoutExtension} --fmap=${WD}/FieldMap.nii.gz --fmapmag=${WD}/Magnitude.nii.gz --fmapmagbrain=${WD}/Magnitude_brain.nii.gz --echospacing=${EchoSpacing} --pedir=${UnwarpDir}
				else
				    ${HCPPIPEDIR_Global}/epi_reg_dof --dof=${dof} --epi=${WD}/Scout_brain.nii.gz --t1=${T1wImage} --t1brain=${WD}/${T1wBrainImageFile} --out=${WD}/${ScoutInputFile}${ScoutExtension} --fmap=${WD}/FieldMap.nii.gz --fmapmag=${WD}/Magnitude.nii.gz --fmapmagbrain=${WD}/Magnitude_brain.nii.gz --echospacing=${EchoSpacing} --pedir=${UnwarpDir}
                fi
            else
			    if [ "$SPECIES" != "Human" && "$BBR" == "NONE" ] ; then # - for NHP TH 2017-2024
                    log_Msg "Brain Extract of Scout using BET"
                    bet ${WD}/Scout.nii.gz ${WD}/Scout_brain.nii.gz -f 0.3
                    log_Msg "Run epi_reg_dof_nobbr"
                    ${HCPPIPEDIR_Global}/epi_reg_dof_nobbr --dof=${dof} --epi=${WD}/Scout_brain.nii.gz --t1=${T1wImage} --t1brain=${WD}/${T1wBrainImageFile} --out=${WD}/${ScoutInputFile}_undistorted --fmap=${WD}/FieldMap.nii.gz --fmapmag=${WD}/Magnitude.nii.gz --fmapmagbrain=${WD}/Magnitude_brain.nii.gz --echospacing=${EchoSpacing} --pedir=${UnwarpDir}
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
                --phaseone2=${SpinEchoPhaseEncodeNegative2} \
                --phasetwo2=${SpinEchoPhaseEncodePositive2} \
                --phasezero=${SpinEchoPhaseEncodeZero}  \
                --phasezerobrainmask=${SpinEchoPhaseEncodeZeroFSBrainmask} \
                --scoutin=${ScoutInputName} \
                --echospacing=${EchoSpacing} \
                --unwarpdir=${UnwarpDir} \
                --owarp=${WD}/WarpField \
                --ojacobian=${WD}/Jacobian \
                --gdcoeffs=${GradientDistortionCoeffs} \
                --topupconfig=${TopupConfig} \
				--scannerpatientposition=${ScannerPatientPosition} \
                --truepatientposition=${TruePatientPosition} \
                --initworldmat=${InitWorldMat} \
                --usejacobian=${UseJacobian}
            
            if [ $SPECIES != "Human"]; then # - for NHP TH 2017-2024
				########################################
				Scout="Magnitude"
				ScoutInputFileSE="SEFieldmag"
				ScoutInputFileGE="$ScoutInputFile"
				########################################

				log_Msg "use undistorted SE field magnitude as a scout for registration using FLIRT"
				${FSLDIR}/bin/fslmaths ${WD}/FieldMap/${Scout} ${WD}/${ScoutInputFileSE}_undistorted
				${FSLDIR}/bin/fslmaths ${WD}/${T1wBrainImageFile} -bin -dilM -dilM ${WD}/${T1wBrainImageFile}_mask_dil

				initcoord=""
				if [ $SpinEchoPhaseEncodeZero != "NONE" ] ; then
					log_Msg "reading coordinates from SE field magnitude"
					${CARET7DIR}/wb_command -convert-affine -from-world ${FSLDIR}/etc/flirtsch/ident.mat -to-flirt ${WD}/${ScoutInputFileSE}_undistorted2T1w_init_tmp.mat ${WD}/${ScoutInputFileSE}_undistorted.nii.gz ${WD}/../../T1w/T1w.nii.gz
					${FSLDIR}/bin/convert_xfm -omat ${WD}/${ScoutInputFileSE}_undistorted2T1w_init0.mat -concat ${WD}/../../T1w/xfms/acpc.mat ${WD}/${ScoutInputFileSE}_undistorted2T1w_init_tmp.mat
					initcoord="-init ${WD}/${ScoutInputFileSE}_undistorted2T1w_init0.mat"
					convert_xfm -omat ${WD}/${ScoutInputFileSE}_undistorted2T1w_init0_inv.mat -inverse ${WD}/${ScoutInputFileSE}_undistorted2T1w_init0.mat
					
					# pre-masking undistorted fMRI to remove eye ball - TH Sep 2025
					flirt -in ${WD}/../../T1w/T1w_acpc_brain_mask.nii.gz -ref ${WD}/${ScoutInputFileSE}_undistorted.nii.gz -applyxfm -init ${WD}/${ScoutInputFileSE}_undistorted2T1w_init0_inv.mat -o ${WD}/${ScoutInputFileSE}_undistorted_fov -interp trilinear
					fslmaths ${WD}/${ScoutInputFileSE}_undistorted_fov -thr 0.5 -bin ${WD}/${ScoutInputFileSE}_undistorted_fov
					fMRIRes=$(fslval ${WD}/${ScoutInputFileSE}_undistorted pixdim1)
					DilateDistance=$(echo "$fMRIRes * 2" | bc) 
					${CARET7DIR}/wb_command -volume-dilate ${WD}/${ScoutInputFileSE}_undistorted_fov.nii.gz $DilateDistance NEAREST ${WD}/${ScoutInputFileSE}_undistorted_fov_dilate.nii.gz
					fslmaths ${WD}/${ScoutInputFileSE}_undistorted.nii.gz -mas ${WD}/${ScoutInputFileSE}_undistorted_fov_dilate.nii.gz ${WD}/${ScoutInputFileSE}_undistorted.nii.gz
					rm ${WD}/${ScoutInputFileSE}_undistorted2T1w_init_tmp.mat
				fi
				
				log_Msg "brain extraction with bet4animal and initialize registraton"
				if   [ $betspecieslabel = 0 ] ; then 
					betfraction=0.2
				elif [ $betspecieslabel = 1 ] ; then 
					betfraction=0.3
				elif [ $betspecieslabel = 2 ] ; then 
					betfraction=0.4
				elif [ $betspecieslabel = 3 ] ; then 
					betfraction=0.5
				elif [ $betspecieslabel -gt 3 ] ; then 
					betfraction=0.6
				fi             
				
				log_Msg "bet command: bet4animal ${WD}/${ScoutInputFileSE}_undistorted.nii.gz ${WD}/${ScoutInputFileSE}_undistorted_brain.nii.gz -m -f ${betfraction} -z ${betspecieslabel}"
				$FSLDIR/bin/bet4animal ${WD}/${ScoutInputFileSE}_undistorted.nii.gz ${WD}/${ScoutInputFileSE}_undistorted_brain.nii.gz -m -f ${betfraction} -z ${betspecieslabel}
				flirt -in ${WD}/${ScoutInputFileSE}_undistorted_brain.nii.gz $initcoord -ref ${WD}/${T1wBrainImageFile} -dof 6 -o ${WD}/${ScoutInputFileSE}_undistorted2T1w_initI.nii.gz -omat ${WD}/${ScoutInputFileSE}_undistorted2T1w_initI.mat

				# initialize with 6-dof and default cost function of corratio with brain mask as an inweight
				${FSLDIR}/bin/flirt -in ${WD}/${ScoutInputFileSE}_undistorted2T1w_initI -ref ${WD}/${T1wBrainImageFile} -omat ${WD}/${ScoutInputFileSE}_undistorted2T1w_initII.mat -interp spline -dof 6 -nosearch -o ${WD}/${ScoutInputFileSE}_undistorted2T1w_initII
				${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFileSE}_undistorted2T1w_initII -mas ${WD}/${T1wBrainImageFile}_mask_dil ${WD}/${ScoutInputFileSE}_undistorted2T1w_initII

				# fine tuning with FSL-BBR between fieldmap and T1w_acpc
		
				if [ $BBR = "T1w" ] ; then
					# Note that BBR=T1w is done using brain outer boundary using flipped slope. Note that using grey/white boundary
					# does not result in stable registration because blood USPIO concentration is significantly changes the 
					# grey/white contrast (e.g., btw higher and lower than 12mg/kg i.v. in macaque at 3T)- TH 2023
					BBRslope=0.5 # positive=t1w contrast, negative=t2w contrast

					log_Msg "register T1w contrast scout to T1w struc with FSL-BBR"
					# calculate outer brain boundary for FSL-BBR
					${FSLDIR}/bin/fslmaths ${SubjectFolder}/T1w/brainmask_fs.nii.gz -bin ${WD}/brainmask_fs
					# use flipped bbrslope and brain boundary
					${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/${ScoutInputFileSE}_undistorted2T1w_initII -ref ${WD}/${T1wBrainImageFile} -omat ${WD}/${ScoutInputFileSE}_undistorted2T1w_initIII.mat -wmseg ${WD}/brainmask_fs -cost bbr -schedule ${FSLDIR}/etc/flirtsch/bbr.sch -bbrslope $BBRslope -out ${WD}/${ScoutInputFileSE}_undistorted2T1w_initIII
					${FSLDIR}/bin/flirt -in ${WD}/${ScoutInputFileSE}_undistorted2T1w_initII -ref ${WD}/${T1wBrainImageFile} -init ${WD}/${ScoutInputFileSE}_undistorted2T1w_initIII.mat -wmseg ${WD}/brainmask_fs -cost bbr -schedule ${FSLDIR}/etc/flirtsch/measurecost1.sch -bbrslope 0.5 | awk 'NR==1 {print $1}' > ${WD}/${ScoutInputFileSE}_undistorted2T1w_initIII.mat.mincost
				
				elif [ $BBR = "T2w" ] ; then
					BBRslope=-0.5 # positive=t1w contrast, negative=t2w contrast

					log_Msg "register T2w contrast scout to T1w struc with FSL BBR"
					#${HCPPIPEDIR_Global}/epi_reg_dof --dof=${dof} --epi=${WD}/${ScoutInputFile}${ScoutExtension} --t1=${T1wImage} --t1brain=${WD}/${T1wBrainImageFile} --out=${WD}/${ScoutInputFile}${ScoutExtension}2T1w_init
					${HCPPIPEDIR_Global}/epi_reg_dof --dof=${dof} --epi=${WD}/${ScoutInputFileSE}_undistorted2T1w_initII --t1=${T1wImage} --t1brain=${WD}/${T1wBrainImageFile} --out=${WD}/${ScoutInputFileSE}_undistorted2T1w_initIII
					${FSLDIR}/bin/flirt -in ${WD}/${ScoutInputFileSE}_undistorted2T1w_initII -ref ${WD}/${T1wBrainImageFile} -init ${WD}/${ScoutInputFileSE}_undistorted2T1w_initIII.mat -wmseg ${WD}/${ScoutInputFileSE}_undistorted2T1w_initIII_fast_wmseg -cost bbr -schedule ${FSLDIR}/etc/flirtsch/measurecost1.sch -bbrslope $BBRslope | awk 'NR==1 {print $1}' > ${WD}/${ScoutInputFileSE}_undistorted2T1w_initIII.mat.mincost

				elif [ $BBR = "NONE" ] ; then
				
					log_Msg "register scout to T1w with cost function of normmi" 
					${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/${ScoutInputFileSE}_undistorted2T1w_initII -ref ${WD}/${T1wBrainImageFile} -omat ${WD}/${ScoutInputFileSE}_undistorted2T1w_initIII.mat -out ${WD}/${ScoutInputFileSE}_undistorted2T1w_initIII -nosearch

				fi

				# combine initial registraion (Fieldmap2T1w_acpc.mat) and fine tune registration (/${ScoutInputFileSE}_undistorted2T1w_init_TMP.mat) to generate second init registration
				${FSLDIR}/bin/convert_xfm -omat ${WD}/${ScoutInputFileSE}_undistorted2T1w_initI+II.mat -concat ${WD}/${ScoutInputFileSE}_undistorted2T1w_initII.mat ${WD}/${ScoutInputFileSE}_undistorted2T1w_initI.mat

				${FSLDIR}/bin/convert_xfm -omat ${WD}/${ScoutInputFileSE}_undistorted2T1w_init.mat -concat ${WD}/${ScoutInputFileSE}_undistorted2T1w_initIII.mat ${WD}/${ScoutInputFileSE}_undistorted2T1w_initI+II.mat

				# copy the initial registration into the final affine's filename, as it is pretty good
				# we need something to get between the spaces to compute an initial bias field
				cp "${WD}/${ScoutInputFileSE}_undistorted2T1w_init.mat" "${WD}/fMRI2str.mat"

        

				# generate combined warpfields and spline interpolated images + apply bias field correction
				log_Msg "generate combined warpfields and spline interpolated images and apply bias field correction"
				${FSLDIR}/bin/convertwarp --relout --rel -r ${T1wImage} --warp1=${WD}/WarpField.nii.gz --postmat="${WD}/${ScoutInputFileSE}_undistorted2T1w_init.mat" -o ${WD}/${ScoutInputFileSE}_undistorted2T1w_init_warp
				${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/Jacobian.nii.gz -r ${T1wImage} --premat="${WD}/${ScoutInputFileSE}_undistorted2T1w_init.mat" -o ${WD}/Jacobian2T1w.nii.gz

				# 1-step resample from input (gdc) scout - NOTE: no longer includes jacobian correction, if specified
				# Use SE filed magnitude for input of FS-BBR registration
				log_Msg "use undistorted SE field mag as a scout for registration with FS-BBR in NHP"
				${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/FieldMap/Magnitude -r ${T1wImage} --premat="${WD}/${ScoutInputFileSE}_undistorted2T1w_init.mat" -o ${WD}/${ScoutInputFileSE}_undistorted2T1w_init

            else # for Human
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
    if [ "$SPECIES" != "Human" ] ; then # - for NHP TH 2017-2024
	    if [ "$BBR" = "T1w" ]; then
	        BBRopt="--t1 --${dof}"
            BBRopt+="--wm-proj-abs 1.1 --gm-proj-abs 0.2 "  # macaque MION EPI/pial surface registration. TO DO: marmoset MION  - TH 2023
            BBRopt+="--brute1max 2 --brute1delta 2 "        # limited coarse search in NHP - TH Nov 2024
			
			SUBJECTS_DIR=${FreeSurferSubjectFolder}
			export SUBJECTS_DIR
			log_Msg "Use \"hidden\" bbregister DOF options"
			
			${FREESURFER_HOME}/bin/bbregister --s ${FreeSurferSubjectID} --mov ${WD}/${ScoutInputFileSE}_undistorted2T1w_init.nii.gz --surf pial.deformed --init-reg ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}/mri/transforms/eye.dat ${BBRopt} --reg ${WD}/SEEPItoT1w.dat 
			
			${FREESURFER_HOME}/bin/tkregister2 --noedit --reg ${WD}/SEEPItoT1w.dat --mov ${WD}/${ScoutInputFileSE}_undistorted2T1w_init.nii.gz --targ ${T1wImage}.nii.gz --fslregout ${WD}/SEEPItoT1w.mat
			
			${FSLDIR}/bin/applywarp -i ${WD}/${ScoutInputFileSE}_undistorted2T1w_init.nii.gz -r ${T1wImage}.nii.gz --premat=${WD}/SEEPItoT1w.mat -o ${WD}/${ScoutInputFileSE}_undistorted2T1w_init_FSBBR.nii.gz

	    elif [ "$BBR" = "T2w" ]; then
			BBRopt="--t2 "
			BBRopt+="--${dof} --wm-proj-abs ${WMProjAbs} "
			BBRopt+="--brute1max 2 --brute1delta 2 " # limited coarse search in NHP - TH Nov 2024
            log_Msg "Run FreeSurfer bbregister" 

			# Run Normally
			log_Msg "Use \"hidden\" bbregister DOF options"			
			# Use "hidden" bbregister DOF options
			${FREESURFER_HOME}/bin/bbregister --s ${FreeSurferSubjectID} --mov ${WD}/${ScoutInputFileSE}_undistorted2T1w_init.nii.gz --surf white.deformed --init-reg ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}/mri/transforms/eye.dat ${BBRopt} --reg ${WD}/SEEPItoT1w.dat 

			# Create FSL-style matrix and then combine with existing warp fields
			log_Msg "Create FSL-style matrix and then combine with existing warp fields"
			${FREESURFER_HOME}/bin/tkregister2 --noedit --reg ${WD}/SEEPItoT1w.dat --mov ${WD}/${ScoutInputFileSE}_undistorted2T1w_init.nii.gz --targ ${T1wImage}.nii.gz --fslregout ${WD}/SEEPItoT1w.mat

			${FSLDIR}/bin/applywarp -i ${WD}/${ScoutInputFileSE}_undistorted2T1w_init.nii.gz -r ${T1wImage}.nii.gz --premat=${WD}/SEEPItoT1w.mat -o ${WD}/${ScoutInputFileSE}_undistorted2T1w_init_FSBBR.nii.gz

	    elif [ "$BBR" = "NONE" ]; then
		    log_Msg "Use refined registration with EPI and T1w"
		    flirt -in ${WD}/${ScoutInputFileSE}_undistorted2T1w_init.nii.gz -ref ${WD}/${T1wBrainImageFile} -dof 6 -nosearch -omat ${WD}/SEEPItoT1w.mat -o ${WD}/${ScoutInputFileSE}_undistorted2T1w.nii.gz
        fi

        if [[ ! $DistortionCorrection == $SPIN_ECHO_METHOD_OPT ]]; then
            cp ${WD}/SEEPItoT1w.mat ${WD}/fMRI2str_refinement.mat
            ${FSLDIR}/bin/convertwarp --relout --rel --warp1=${WD}/${ScoutInputFileSE}_undistorted2T1w_init_warp.nii.gz --ref=${T1wImage} --postmat=${WD}/fMRI2str_refinement.mat --out=${WD}/fMRI2str.nii.gz

        else # SPIN_ECHO_METHOD_OPT
		    ## SBRef2SEFieldByT1w - tune up registration betweeen SBRef and SEFieldmap by way of T1w. This will update SBRef2Warpfield.mat by performing 3-step, 1) simulate distorted T1w based on topup, 2) BBR registration btw distorted SBRef and distorted T1w volume, and 3) BBR registration btw undistorted SBRef and T1w_acpc. This step may be effective if SBRef to SEFieldmap registration (in TopupPreprocessingAll.sh) does not work well (e.g. quality of single-band SBRef is not very good) - TH Oct 2023
			SBRef2SEFieldByT1=FALSE  # TRUE or FALSE
			
			## SBRef2StrucBBR - tune up BBR between Scout_gdc (SBRef) and structure. This step will update fMRI to T1w registration by using SBRef and BBR. This step may be effective if the contrast of SBRef is good enough (e.g. contrast of single-band SBRef is very good) - TH 2024
			if [[ "$BBR" = T1w ]] ; then
			    SBRef2StrucBBR=TRUE     # FALSE or TRUE 
			else
			    SBRef2StrucBBR=FALSE    # FALSE or TRUE. BBR for BOLD fMRI in NHP does not robustly work
			fi

        if [[ "${SBRef2SEFieldByT1w}" = TRUE ]] ; then
            # simulate distorted T1w volume in SEFieldmap space in order to tune up regitration of SBRef-to-SEField magnitude
			log_Msg "Simulate distorted T1w volume and white matter segment in SEFieldmap space"
			hires=$(${FSLDIR}/bin/fslval $T1wRestoreImage pixdim1)
			${FSLDIR}/bin/convert_xfm -omat ${WD}/fMRI2str.mat -concat ${WD}/SEEPItoT1w.mat ${WD}/${ScoutInputFileSE}_undistorted2T1w_init.mat	
			${FSLDIR}/bin/convert_xfm -omat ${WD}/str2fMRI.mat -inverse ${WD}/fMRI2str.mat
   		    ${FSLDIR}/bin/invwarp -w ${WD}/WarpField.nii.gz -r ${WD}/${ScoutInputFileSE}_undistorted.nii.gz -o ${WD}/WarpField_inv --rel
    	    ${FSLDIR}/bin/flirt -in ${WD}/${ScoutInputFileSE}_undistorted -ref ${WD}/${ScoutInputFileSE}_undistorted -applyisoxfm $hires -o ${WD}/${ScoutInputFileSE}_undistorted_hires  
    	    ${FSLDIR}/bin/applywarp --rel -i ${WD}/${T1wBrainImageFile}.nii.gz --premat=${WD}/str2fMRI.mat -w ${WD}/WarpField_inv -r ${WD}/${ScoutInputFileSE}_undistorted_hires -o ${WD}/${T1wBrainImageFile}2Fieldmap
    	    ${FSLDIR}/bin/fslmaths ${SubjectFolder}/T1w/wmparc -thr 2 -uthr 2 -bin -mul 39 -add ${SubjectFolder}/T1w/wmparc -thr 41 -uthr 41 -bin ${WD}/wmseg_acpc_dc
    	    ${FSLDIR}/bin/applywarp --rel -i ${WD}/wmseg_acpc_dc --premat=${WD}/str2fMRI.mat -w ${WD}/WarpField_inv -r ${WD}/SEFieldmag_undistorted_hires -o  ${WD}/wmseg_acpc_dc2Fieldmap --interp=trilinear
    	    ${FSLDIR}/bin/fslmaths ${WD}/wmseg_acpc_dc2Fieldmap -thr 0.05 -bin ${WD}/wmseg_acpc_dc2Fieldmap_thr0.05

    	    # estimate distorted sigloss map in SEFieldmap space
    	    log_Msg "Estimate distorted sigloss map in SEFieldmap space"
    	    siglossthr=99 # default threshold (in percent) for sigloss. 
    	    SiglossTHR=$(echo "$siglossthr / 100" | bc -l)
    	    ${FSLDIR}/bin/applywarp --rel -i ${WD}/${T1wBrainImageFile}_mask_dil --premat=${WD}/str2fMRI.mat -w ${WD}/WarpField_inv -r ${WD}/${ScoutInputFileSE}_undistorted -o ${WD}/${T1wBrainImageFile}_mask_dil2Fieldmap --interp=nn
    	    ${FSLDIR}/bin/sigloss -i ${WD}/FieldMap/TopupField.nii.gz -s ${WD}/FieldMap/TopupSigloss.nii.gz --te=0.03 -d z
    	    ${FSLDIR}/bin/applywarp --rel -i ${WD}/FieldMap/TopupSigloss.nii.gz -r ${WD}/${ScoutInputFileSE}_undistorted -w ${WD}/WarpField_inv -o ${WD}/${ScoutInputFileSE}_distorted_sigloss --interp=trilinear
    	    ${FSLDIR}/bin/fslmaths ${WD}/FieldMap/TopupSigloss.nii.gz -thr $SiglossTHR -bin ${WD}/FieldMap/TopupSiglossweight
    	    ${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFileSE}_distorted_sigloss -thr $SiglossTHR -bin -mas ${WD}/${T1wBrainImageFile}_mask_dil2Fieldmap ${WD}/${ScoutInputFileSE}_distorted_siglossweight

    	    # 1st registration of distorted SBRef to distorted SEField copied from TopupPreprocessingAll
    	    if [[ $UnwarpDir = [xyij] ]] ; then 
    	        VolumeNumber=$(${FSLDIR}/bin/fslval ${WD}/FieldMap/PhaseOne dim4)
                vnum=$(${FSLDIR}/bin/zeropad $((VolumeNumber + 1)) 2)
                PhaseVol=Two
            elif [[ $UnwarpDir = [xyij]- || $UnwarpDir = -[xyij] ]] ; then            
                VolumeNumber=0
                vnum=$(${FSLDIR}/bin/zeropad $((VolumeNumber + 1)) 2)
                PhaseVol=One
            fi
            cp ${WD}/FieldMap/SBRef2Warpfield.mat ${WD}/FieldMap/SBRef2Warpfield_initI.mat
            ${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFileSE}_distorted_siglossweight -dilM ${WD}/${ScoutInputFileSE}_distorted_siglossweight_dil

            # 2nd registration of distorted SBRef to distorted T1w (in Fieldmap space) with cost fuction corratio and sigloss weight
            log_Msg "registration between distorted SBRef and distorted T1w with cost function of corratio"
            ${FSLDIR}/bin/flirt -dof 6 -interp spline -in ${WD}/FieldMap/SBRef -ref ${WD}/${T1wBrainImageFile}2Fieldmap -init ${WD}/FieldMap/SBRef2Warpfield_initI.mat -inweight ${WD}/${ScoutInputFileSE}_distorted_siglossweight_dil -nosearch -omat ${WD}/FieldMap/SBRef2Warpfield_initII.mat -out ${WD}/FieldMap/SBRef2Warpfield_initII

            # 3rd registration of distorted SBRef-to-SEField with FS-BBR
            if [ $BBR = "T1w" ]; then
                log_Msg "registeration of distorted T1w-contrast SBRef to distorted T1w with T1w-BBR"
                # create brain ourter surface boundary
                ${FSLDIR}/bin/applywarp --rel -i ${WD}/brainmask_fs --premat=${WD}/str2fMRI.mat -w ${WD}/WarpField_inv -r ${WD}/SEFieldmag_undistorted_hires -o  ${WD}/brainmask_fs2Fieldmap --interp=trilinear
                ${FSLDIR}/bin/fslmaths ${WD}/brainmask_fs2Fieldmap -thr 0.5 -bin ${WD}/brainmask_fs2Fieldmap

                # use flipped bbrslope
                ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/FieldMap/SBRef -ref ${WD}/${T1wBrainImageFile}2Fieldmap -init ${WD}/FieldMap/SBRef2Warpfield_initII.mat -wmseg ${WD}/brainmask_fs2Fieldmap -cost bbr -schedule ${FSLDIR}/etc/flirtsch/bbr.sch -bbrslope 0.5 -omat ${WD}/FieldMap/SBRef2Warpfield.mat -o ${WD}/FieldMap/SBRef2Warpfield -inweight ${WD}/${ScoutInputFileSE}_distorted_siglossweight_dil 
                ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/FieldMap/SBRef -ref ${WD}/${T1wBrainImageFile}2Fieldmap -wmseg ${WD}/brainmask_fs2Fieldmap -cost bbr -schedule ${FSLDIR}/etc/flirtsch/measurecost1.sch -bbrslope 0.5 -init ${WD}/FieldMap/SBRef2Warpfield.mat  | awk 'NR==1 {print $1}' > ${WD}/SBRef2Warpfield.mincost
          
            elif [ $BBR = "T2w" ]; then
                log_Msg "registration of distorted SBRef to distorted T1w with T2w-BBR"
                ${FSLDIR}/bin/flirt -in ${WD}/FieldMap/SBRef -dof 6 -ref ${WD}/${T1wBrainImageFile}2Fieldmap -cost bbr -schedule $FSLDIR/etc/flirtsch/bbr.sch -wmseg ${WD}/wmseg_acpc_dc2Fieldmap_thr0.05 -init ${WD}/FieldMap/SBRef2Warpfield_initII.mat -omat ${WD}/FieldMap/SBRef2Warpfield.mat -o ${WD}/FieldMap/SBRef2Warpfield -inweight ${WD}/${ScoutInputFileSE}_distorted_siglossweight_dil 
                ${FSLDIR}/bin/flirt -in ${WD}/FieldMap/SBRef -ref ${WD}/${T1wBrainImageFile}2Fieldmap -init ${WD}/FieldMap/SBRef2Warpfield.mat -wmseg ${WD}/wmseg_acpc_dc2Fieldmap_thr0.05 -cost bbr -schedule ${FSLDIR}/etc/flirtsch/measurecost1.sch -bbrslope -0.5 | awk 'NR==1 {print $1}' > ${WD}/FieldMap/SBRef2Warpfield.mincost

            elif [ $BBR = "NONE" ]; then
                log_Msg "registration between distorted SBRef and distorted T1w volume"
                RefVolume=${WD}/${T1wBrainImageFile}2Fieldmap
                ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/FieldMap/SBRef -ref $RefVolume -inweight ${WD}/${ScoutInputFileSE}_distorted_siglossweight_dil -init ${WD}/FieldMap/SBRef2Warpfield_initII.mat -omat ${WD}/FieldMap/SBRef2Warpfield.mat -out ${WD}/FieldMap/SBRef2Warpfield -cost normmi -nosearch #-init "$WD"/Scout2T1w.mat
            fi

            # Recreate undistortion warpfield
            log_Msg "recreating warpfield for SBRef"
            imcp ${WD}/WarpField ${WD}/WarpField_init
            ${FSLDIR}/bin/convertwarp --relout --rel -r ${WD}/FieldMap/Phase${PhaseVol}_gdc_one --premat=${WD}/FieldMap/SBRef2WarpField.mat --warp1=${WD}/FieldMap/WarpField_${vnum} --out=${WD}/WarpField

            # Recreate SBRef_dc and SBRef_dc_jac
            log_Msg "recreating SBRef_dc and SBRef_jac in FieldMap"
            ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/FieldMap/SBRef.nii.gz -r ${WD}/FieldMap/SBRef.nii.gz -w ${WD}/WarpField -o ${WD}/FieldMap/SBRef_dc.nii.gz
            ${FSLDIR}/bin/fslmaths ${WD}/FieldMap/SBRef_dc -mul ${WD}/FieldMap/Jacobian ${WD}/FieldMap/SBRef_dc_jac
        fi  
        ## Finish SBRef2SEFieldByT1w

        cp ${WD}/${ScoutInputFileSE}_undistorted2T1w_init.mat ${WD}/${ScoutInputFileGE}_undistorted2T1w_init.mat
        ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/FieldMap/SBRef_dc -r ${T1wImage} --premat=${WD}/${ScoutInputFileGE}_undistorted2T1w_init.mat --postmat=${WD}/SEEPItoT1w.mat -o ${WD}/${ScoutInputFileGE}_undistorted2T1w_init.nii.gz

        if [[ $UseJacobian == "true" ]] ; then
            log_Msg "apply Jacobian correction to scout image"
            if [[ "$UseBiasField" != "" ]]; then
                ${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFileGE}_undistorted2T1w_init -div ${UseBiasField} -mul ${WD}/Jacobian2T1w.nii.gz ${WD}/${ScoutInputFileGE}_undistorted2T1w_init.nii.gz
            else
                ${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFileGE}_undistorted2T1w_init -mul ${WD}/Jacobian2T1w.nii.gz ${WD}/${ScoutInputFileGE}_undistorted2T1w_init.nii.gz
            fi
        else
            log_Msg "do not apply Jacobian correction to scout image"
            if [[ "$UseBiasField" != "" ]]; then
                log_Msg "apply bias field correction to scout image"
                ${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFileGE}_undistorted2T1w_init -div ${UseBiasField} ${WD}/${ScoutInputFileGE}_undistorted2T1w_init
            fi
        fi

        ## SBRef2strucBBR 
        if [[ "${SBRef2StrucBBR}" = TRUE ]] ; then 
            if [[ "$BBR" = T1w ]]; then
                # use FSL-BBR
                # use flipped bbrslope and brain boundary
                ${FSLDIR}/bin/fslmaths ${SubjectFolder}/T1w/brainmask_fs.nii.gz -bin ${WD}/brainmask_fs
                ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/${ScoutInputFileGE}_undistorted2T1w_init -ref ${WD}/${T1wBrainImageFile} -omat ${WD}/GEEPItoT1w_FSLBBR.mat -wmseg ${WD}/brainmask_fs -cost bbr -schedule ${FSLDIR}/etc/flirtsch/bbr.sch -bbrslope 0.5 -out ${WD}/${ScoutInputFileGE}_undistorted2T1w_FSLBBR
                ${FSLDIR}/bin/flirt -in ${WD}/${ScoutInputFileGE}_undistorted2T1w_init -ref ${WD}/${T1wBrainImageFile} -init ${WD}/GEEPItoT1w_FSLBBR.mat -wmseg ${WD}/brainmask_fs -cost bbr -schedule ${FSLDIR}/etc/flirtsch/measurecost1.sch -bbrslope 0.5 | awk 'NR==1 {print $1}' > ${WD}/GEEPItoT1w_FSLBBR.mat.mincost
                log_Msg "Run FreeSurfer bbregister" 
                ### FREESURFER BBR - found to be an improvement, probably due to better GM/WM boundary
                SUBJECTS_DIR=${FreeSurferSubjectFolder}
                export SUBJECTS_DIR
                BBRopt="--t1 --${dof} --wm-proj-abs 1.1 --gm-proj-abs 0.2 "  # Macaque MION data 
                BBRopt+="--brute1max 2 --brute1delta 2 "
                log_Msg "Run Normally"      
                # Use "hidden" bbregister DOF options
                log_Msg "Use \"hidden\" bbregister DOF options"
                ${FREESURFER_HOME}/bin/bbregister --s ${FreeSurferSubjectID} --mov ${WD}/${ScoutInputFileGE}_undistorted2T1w_FSLBBR.nii.gz --surf pial.deformed --init-reg ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}/mri/transforms/eye.dat ${BBRopt} --reg ${WD}/GEEPItoT1w_FSBBR.dat 

                # Create FSL-style matrix and then combine with existing warp fields
                log_Msg "Create FSL-style matrix and then combine with existing warp fields"
                ${FREESURFER_HOME}/bin/tkregister2 --noedit --reg ${WD}/GEEPItoT1w_FSBBR.dat --mov ${WD}/${ScoutInputFileGE}_undistorted2T1w_init.nii.gz --targ ${T1wImage}.nii.gz --fslregout ${WD}/GEEPItoT1w_FSBBR.mat

                # Combine xfms of FSL-BBR and FS-BBR
                log_Msg "Combine xfms of FSL-BBR and FS-BBR"
                ${FSLDIR}/bin/convert_xfm -omat ${WD}/GEEPItoT1w.mat -concat ${WD}/GEEPItoT1w_FSBBR.mat ${WD}/GEEPItoT1w_FSLBBR.mat
 

            elif [[ "$BBR" = T2w ]]; then

                log_Msg "Run FSL BBR with FLIRT"
                ${FSLDIR}/bin/fslmaths ${SubjectFolder}/T1w/wmparc -thr 2 -uthr 2 -bin -mul 39 -add ${SubjectFolder}/T1w/wmparc -thr 41 -uthr 41 -bin ${WD}/wmseg_acpc_dc
                ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/${ScoutInputFileGE}_undistorted2T1w_init -ref ${WD}/${T1wBrainImageFile} -omat ${WD}/GEEPItoT1w_FSLBBR.mat -wmseg ${WD}/wmseg_acpc_dc -cost bbr -schedule ${FSLDIR}/etc/flirtsch/bbr.sch -bbrslope -0.5  -out ${WD}/${ScoutInputFileGE}_undistorted2T1w
                ${FSLDIR}/bin/flirt -in ${WD}/${ScoutInputFileGE}_undistorted2T1w_init -ref ${WD}/${T1wBrainImageFile} -init ${WD}/GEEPItoT1w_FSLBBR.mat -wmseg ${WD}/wmseg_acpc_dc -cost bbr -schedule ${FSLDIR}/etc/flirtsch/measurecost1.sch -bbrslope -0.5 | awk 'NR==1 {print $1}' > ${WD}/GEEPItoT1w_FSLBBR.mat.mincost

                BBRopt="--t2 --${dof} --wm-proj-abs ${WMProjAbs} "
                BBRopt+="--brute1max 2 --brute1delta 2 "
                log_Msg "Run FreeSurfer bbregister" 
                ### FREESURFER BBR - found to be an improvement, probably due to better GM/WM boundary
                SUBJECTS_DIR=${FreeSurferSubjectFolder}
                export SUBJECTS_DIR

                # Run Normally
                log_Msg "Run Normally"
                # Use "hidden" bbregister DOF options
      
	            log_Msg "Use \"hidden\" bbregister DOF options"
                ${FREESURFER_HOME}/bin/bbregister --s ${FreeSurferSubjectID} --mov ${WD}/${ScoutInputFileGE}_undistorted2T1w_init.nii.gz --surf white.deformed --init-reg  ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}/mri/transforms/eye.dat ${BBRopt} --reg ${WD}/GEEPItoT1w_FSBBR.dat --o ${WD}/${ScoutInputFileGE}_undistorted2T1w.nii.gz

                # Create FSL-style matrix and then combine with existing warp fields
                log_Msg "Create FSL-style matrix and then combine with existing warp fields"
                ${FREESURFER_HOME}/bin/tkregister2 --noedit --reg ${WD}/GEEPItoT1w.dat --mov ${WD}/${ScoutInputFileGE}_undistorted2T1w_init.nii.gz --targ ${T1wImage}.nii.gz --fslregout ${WD}/GEEPItoT1w_FSBBR.mat
 
                # Combine xfms of FSL-BBR and FS-BBR
                log_Msg "Combine xfms of FSL-BBR and FS-BBR"
                ${FSLDIR}/bin/convert_xfm -omat ${WD}/GEEPItoT1w.mat -concat ${WD}/GEEPItoT1w_FSBBR.mat ${WD}/GEEPItoT1w_FSLBBR.mat
 
            elif [[ "$BBR" = NONE ]]; then 
                log_Msg "Use refined registration with EPI and T1w"
                applywarp -i ${WD}/FieldMap/TopupSiglossweight -r ${WD}/${ScoutInputFileGE}_undistorted2T1w_init.nii.gz --premat=${WD}/${ScoutInputFileGE}_undistorted2T1w_init.mat -o ${WD}/${ScoutInputFileGE}_undistorted_siglossweight --interp=trilinear
                fslmaths ${WD}/${ScoutInputFileGE}_undistorted_siglossweight -thr 0.5 -bin ${WD}/${ScoutInputFileGE}_undistorted_siglossweight
                fslmaths ${WD}/${ScoutInputFileGE}_undistorted_siglossweight -dil ${WD}/${ScoutInputFileGE}_undistorted_siglossweight_dil
                flirt -in ${WD}/${ScoutInputFileGE}_undistorted2T1w_init.nii.gz -ref ${WD}/${T1wBrainImageFile} -dof 6 -nosearch -omat ${WD}/GEEPItoT1w.mat -inweight ${WD}/${ScoutInputFileGE}_undistorted_siglossweight_dil
            fi
        fi
        ## Finish SBRef2strucBBR

        if [ -e ${WD}/GEEPItoT1w.mat ] ; then
            ${FSLDIR}/bin/convert_xfm -omat ${WD}/fMRI2str_refinement.mat -concat ${WD}/GEEPItoT1w.mat ${WD}/SEEPItoT1w.mat
        else
            cp ${WD}/SEEPItoT1w.mat ${WD}/fMRI2str_refinement.mat
        fi

        log_Msg "recalculating fMRI2str.mat"  
        ${FSLDIR}/bin/convert_xfm -omat ${WD}/fMRI2str.mat -concat ${WD}/fMRI2str_refinement.mat ${WD}/${ScoutInputFileGE}_undistorted2T1w_init.mat
        log_Msg "calculating init warpfield of SBRef2T1w (Scout_gdc_undistorted2T1w_init_warp.nii.gz)"
        ${FSLDIR}/bin/convertwarp --relout --rel -r ${T1wImage} --warp1=${WD}/WarpField --postmat=${WD}/${ScoutInputFileGE}_undistorted2T1w_init.mat -o ${WD}/${ScoutInputFileGE}_undistorted2T1w_init_warp
        log_Msg "calculating final warpfield of SBRef2T1w (fMRI2str.nii.gz)"
        ${FSLDIR}/bin/convertwarp --relout --rel --warp1=${WD}/${ScoutInputFileGE}_undistorted2T1w_init_warp.nii.gz --ref=${T1wImage} --postmat=${WD}/fMRI2str_refinement.mat --out=${WD}/fMRI2str.nii.gz

    else # Human
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

if [[ $DistortionCorrection == $SPIN_ECHO_METHOD_OPT ]]; then
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

    if [[ $BiasCorrection == "SEBASED" ]]; then
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
else
    
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

