#!/bin/bash 

# Requirements for this script
#  installed versions of: FSL, gradunwarp (HCP version)
#  environment: HCPPIPEDIR, FSLDIR, HCPPIPEDIR_Global, PATH for gradient_unwarp.py

# -----------------------------------------------------------------------------------
#  Constants for specification of Averaging and Readout Distortion Correction Method
# -----------------------------------------------------------------------------------

SIEMENS_METHOD_OPT="SiemensFieldMap"
SPIN_ECHO_METHOD_OPT="TOPUP"
# For GE HealthCare Fieldmap Distortion Correction methods 
# see explanations in global/scripts/FieldMapPreprocessingAll.sh
GE_HEALTHCARE_LEGACY_METHOD_OPT="GEHealthCareLegacyFieldMap" 
GE_HEALTHCARE_METHOD_OPT="GEHealthCareFieldMap"
PHILIPS_METHOD_OPT="PhilipsFieldMap"
FIELDMAP_METHOD_OPT="FIELDMAP"

# ------------------------------------------------------------------------------
#  Usage Description Function
# ------------------------------------------------------------------------------


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

opts_SetScriptDescription "Script for performing gradient-nonlinearity and susceptibility-induced distortion correction on T1w and T2w images, then also registering T2w to T1w"

opts_AddMandatory '--t1' 'T1wImage' 'image' "input T1w image"

opts_AddMandatory '--t1brain' 'T1wImageBrain' 'image' "input T1w brain-extracted image"

opts_AddMandatory '--t2' 'T2wImage' 'image' "input T2w image"

opts_AddMandatory '--t2brain' 'T2wImageBrain' 'image' "input T2w brain-extracted image"

opts_AddMandatory '--t1sampspacing' 'T1wSampleSpacing' 'value (seconds)' "sample spacing (readout direction) of T1w image - in seconds"

opts_AddMandatory '--t2sampspacing' 'T2wSampleSpacing' 'value (seconds)' "sample spacing (readout direction) of T2w image - in seconds"

opts_AddMandatory '--unwarpdir' 'UnwarpDir' '{x,y,z,x-,y-,z-} OR {i,j,k,i-,j-,k-}' "direction of distortion of T1 and T2 according to *voxel* axes (post fslreorient2std)"

opts_AddMandatory '--ot1' 'OutputT1wImage' 'image' "output corrected T1w image"

opts_AddMandatory '--ot1brain' 'OutputT1wImageBrain' 'image' "output corrected, brain-extracted T1w image"

opts_AddMandatory '--ot1warp' 'OutputT1wTransform' 'image' "output warpfield for distortion correction of T1w image"

opts_AddMandatory '--ot2' 'OutputT2wImage' 'image' "output corrected T2w image"

opts_AddMandatory '--ot2warp' 'OutputT2wTransform' 'warpfield' "output warpfield for distortion correction of T2w image"

opts_AddMandatory '--method' 'DistortionCorrection' 'method' "method used for readout distortion correction:
    '${SPIN_ECHO_METHOD_OPT}'
        use Spin Echo Field Maps for readout distortion correction

    '${PHILIPS_METHOD_OPT}'
        use Philips specific Gradient Echo Field Maps for readout distortion correction
    
    '${GE_HEALTHCARE_LEGACY_METHOD_OPT}'
        use GE HealthCare Legacy specific Gradient Echo Field Maps for SDC (i.e., field map in Hz and magnitude image in a single NIfTI file, via --fmapcombined argument).
        This option is maintained for backward compatibility.

    '${GE_HEALTHCARE_METHOD_OPT}'
        use GE HealthCare specific Gradient Echo Field Maps for SDC (i.e., field map in Hz and magnitude image in two separate NIfTI files, via --fmapphase and --fmapmag).

    '${SIEMENS_METHOD_OPT}'
        use Siemens specific Gradient Echo Field Maps for readout distortion correction

    '${FIELDMAP_METHOD_OPT}'
        equivalent to ${SIEMENS_METHOD_OPT} (preferred)
        This option is maintained for backward compatibility."

#optional args 

opts_AddOptional '--workingdir' 'WD' 'path' "working directory" "."

opts_AddOptional '--fmapmag' 'MagnitudeInputName' 'image' "input fieldmap magnitude images (@-separated)"

opts_AddOptional '--fmapphase' 'PhaseInputName' 'image' "input fieldmap phase images in radians (Siemens/Philips) or in Hz (GE HealthCare)"

opts_AddOptional '--fmapcombined' 'GEB0InputName' 'image' "input GE HealthCare Legacy field map only (two volumes: 1. field map in Hz and 2. magnitude image)" '' '--fmap'

opts_AddOptional '--echodiff' 'DeltaTE' 'value (milliseconds)' "echo time difference for fieldmap images (in milliseconds)"

opts_AddOptional '--SEPhaseNeg' 'SpinEchoPhaseEncodeNegative' 'image' "input spin echo negative phase encoding image"

opts_AddOptional '--SEPhasePos' 'SpinEchoPhaseEncodePositive' 'image' "input spin echo positive phase encoding image"

opts_AddOptional '--seechospacing' 'SEEchoSpacing' 'value (seconds)' "effective echo spacing of SEPhaseNeg and SEPhasePos or in seconds"

opts_AddOptional '--seunwarpdir' 'SEUnwarpDir' '{x,y,x-,y-} OR {i,j,i-,j-}' "direction of distortion of the SEPhase images according to *voxel* axes"

opts_AddOptional '--topupconfig' 'TopupConfig' 'file' "topup config file"

opts_AddOptional '--gdcoeffs' 'GradientDistortionCoeffs' 'file' "gradient distortion coefficients (SIEMENS file)"

opts_AddOptional '--truepatientposition' 'TruePatientPosition' 'string' "HFS (head-first-spine), HFSx (head-first-sphinx) - TH 2023"

opts_AddOptional '--scannerpatientposition' 'ScannerPatientPosition' 'string' "HFS, HFP, FFS or FFP"

opts_AddOptional '--SEPhaseNeg2' 'SpinEchoPhaseEncodeNegative2' 'image' "input spin echo negative phase encoding image 2"

opts_AddOptional '--SEPhasePos2' 'SpinEchoPhaseEncodePositive2' 'image' "input spin echo positive phase encoding image 2"

opts_AddOptional '--SEPhaseZero' 'SpinEchoPhaseEncodeZero' 'image' "input spin echo zero phase encoding image"

opts_AddOptional '--species' 'SPECIES' 'string' "Species (default: Human)" "Human"
#Tim special parsing 
opts_AddOptional '--usejacobian' 'UseJacobian' 'true or false' "Use jacobian" 

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

log_Check_Env_Var FSLDIR
log_Check_Env_Var HCPPIPEDIR_Global

# ################################################### OUTPUT FILES #####################################################

# For distortion correction:
#
# Output files (in $WD): Magnitude  Magnitude_brain  Phase  FieldMap
#                        Magnitude_brain_warpedT1w  Magnitude_brain_warpedT1w2${TXwImageBrainBasename}
#                        fieldmap2${T1wImageBrainBasename}.mat   FieldMap2${T1wImageBrainBasename}
#                        FieldMap2${T1wImageBrainBasename}_ShiftMap
#                        FieldMap2${T1wImageBrainBasename}_Warp ${T1wImageBasename}  ${T1wImageBrainBasename}
#        Plus the versions with T1w -> T2w
#
# Output files (not in $WD):  ${OutputT1wTransform}   ${OutputT1wImage}  ${OutputT1wImageBrain}
#        Note that these outputs are actually copies of the last three entries in the $WD list
#
#
# For registration:
#
# Output images (in $WD/T2w2T1w):  sqrtT1wbyT2w  T2w_reg.mat  T2w_reg_init.mat
#                                  T2w_dc_reg  (the warp field)
#                                  T2w_reg     (the warped image)
# Output images (not in $WD):  ${OutputT2wTransform}   ${OutputT2wImage}
#        Note that these outputs are copies of the last two images (respectively) from the T2w2T1w subdirectory

################################################## OPTION PARSING #####################################################

T1wImage=`${FSLDIR}/bin/remove_ext $T1wImage`
T1wImageBrain=`${FSLDIR}/bin/remove_ext $T1wImageBrain`
T2wImage=`${FSLDIR}/bin/remove_ext $T2wImage`
T2wImageBrain=`${FSLDIR}/bin/remove_ext $T2wImageBrain`

T1wImageBrainBasename=`basename "$T1wImageBrain"`
T1wImageBasename=`basename "$T1wImage"`
T2wImageBrainBasename=`basename "$T2wImageBrain"`
T2wImageBasename=`basename "$T2wImage"`

Modalities="T1w T2w"

log_Msg "START"

verbose_echo "  "
verbose_red_echo " ===> Running T2WToT1wDistortionCorrectAndReg"
verbose_echo "  "
verbose_echo "  Parameters"
verbose_echo "                           WD          (workingdir): $WD"
verbose_echo "                     T1wImage                  (t1): $T1wImage"
verbose_echo "                T1wImageBrain             (t1brain): $T1wImageBrain"
verbose_echo "                     T2wImage                  (t2): $T2wImage"
verbose_echo "                T2wImageBrain             (t2brain): $T2wImageBrain"
verbose_echo "           MagnitudeInputName             (fmapmag): $MagnitudeInputName"
verbose_echo "               PhaseInputName           (fmapphase): $PhaseInputName"
verbose_echo "                GEB0InputName        (fmapcombined): $GEB0InputName"
verbose_echo "                      DeltaTE            (echodiff): $DeltaTE"
verbose_echo "  SpinEchoPhaseEncodeNegative          (SEPhaseNeg): $SpinEchoPhaseEncodeNegative"
verbose_echo "  SpinEchoPhaseEncodePositive          (SEPhasePos): $SpinEchoPhaseEncodePositive"
verbose_echo "               SEEchoSpacing        (seechospacing): $SEEchoSpacing"
verbose_echo "                  SEUnwarpDir         (seunwarpdir): $SEUnwarpDir"
verbose_echo "             T1wSampleSpacing       (t1sampspacing): $T1wSampleSpacing"
verbose_echo "             T2wSampleSpacing       (t2sampspacing): $T2wSampleSpacing"
verbose_echo "                    UnwarpDir           (unwarpdir): $UnwarpDir"
verbose_echo "               OutputT1wImage                 (ot1): $OutputT1wImage"
verbose_echo "          OutputT1wImageBrain            (ot1brain): $OutputT1wImageBrain"
verbose_echo "           OutputT1wTransform             (ot1warp): $OutputT1wTransform"
verbose_echo "               OutputT2wImage                 (ot2): $OutputT2wImage"
verbose_echo "           OutputT2wTransform             (ot2warp): $OutputT2wTransform"
verbose_echo "         DistortionCorrection              (method): $DistortionCorrection"
verbose_echo "                  TopupConfig         (topupconfig): $TopupConfig"
verbose_echo "     GradientDistortionCoeffs            (gdcoeffs): $GradientDistortionCoeffs"
verbose_echo "                  UseJacobian         (usejacobian): $UseJacobian"
verbose_echo " "


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

        ${HCPPIPEDIR_Global}/FieldMapPreprocessingAll.sh \
            --workingdir=${WD}/FieldMap \
            --method="SiemensFieldMap" \
            --fmapmag=${MagnitudeInputName} \
            --fmapphase=${PhaseInputName} \
            --echodiff=${DeltaTE} \
            --ofmapmag=${WD}/Magnitude \
            --ofmapmagbrain=${WD}/Magnitude_brain \
            --ofmap=${WD}/FieldMap \
            --gdcoeffs=${GradientDistortionCoeffs}

        ;;

    ${GE_HEALTHCARE_LEGACY_METHOD_OPT})

        # ---------------------------------------------------
        # -- GE HealthCare Legacy Gradient Echo Field Maps --
        # ---------------------------------------------------

        ### Create fieldmaps (and apply gradient non-linearity distortion correction)
        echo " "
        echo " "
        echo " " 

        ${HCPPIPEDIR_Global}/FieldMapPreprocessingAll.sh \
            --workingdir=${WD}/FieldMap \
            --method="GEHealthCareLegacyFieldMap" \
            --fmapcombined=${GEB0InputName} \
            --echodiff=${DeltaTE} \
            --ofmapmag=${WD}/Magnitude \
            --ofmapmagbrain=${WD}/Magnitude_brain \
            --ofmap=${WD}/FieldMap \
            --gdcoeffs=${GradientDistortionCoeffs}

        ;;

    ${GE_HEALTHCARE_METHOD_OPT})

        # -------------------------------------------
        # -- GE HealthCare Gradient Echo Field Maps --
        # --------------------------------------------

        ### Create fieldmaps (and apply gradient non-linearity distortion correction)
        echo " "
        echo " "
        echo " " 

        ${HCPPIPEDIR_Global}/FieldMapPreprocessingAll.sh \
            --workingdir=${WD}/FieldMap \
            --method="GEHealthCareFieldMap" \
            --fmapmag=${MagnitudeInputName} \
            --fmapphase=${PhaseInputName} \
            --echodiff=${DeltaTE} \
            --ofmapmag=${WD}/Magnitude \
            --ofmapmagbrain=${WD}/Magnitude_brain \
            --ofmap=${WD}/FieldMap \
            --gdcoeffs=${GradientDistortionCoeffs}

        ;;

    ${PHILIPS_METHOD_OPT})

        # --------------------------------------
        # -- Philips Gradient Echo Field Maps --
        # --------------------------------------

        ### Create fieldmaps (and apply gradient non-linearity distortion correction)
        echo " "
        echo " "
        echo " "

        ${HCPPIPEDIR_Global}/FieldMapPreprocessingAll.sh \
            --workingdir=${WD}/FieldMap \
            --method="PhilipsFieldMap" \
            --fmapmag=${MagnitudeInputName} \
            --fmapphase=${PhaseInputName} \
            --echodiff=${DeltaTE} \
            --ofmapmag=${WD}/Magnitude \
            --ofmapmagbrain=${WD}/Magnitude_brain \
            --ofmap=${WD}/FieldMap \
            --gdcoeffs=${GradientDistortionCoeffs}

        ;;

    ${SPIN_ECHO_METHOD_OPT})

        # --------------------------
        # -- Spin Echo Field Maps --
        # --------------------------

        if [[ ${SEUnwarpDir} = [xyij] ]] ; then
            ScoutInputName="${SpinEchoPhaseEncodePositive}"
        elif [[ ${SEUnwarpDir} = -[xyij] || ${SEUnwarpDir} = [xyij]- ]] ; then
            ScoutInputName="${SpinEchoPhaseEncodeNegative}"
        else
            log_Err_Abort "Invalid entry for --seunwarpdir ($SEUnwarpDir)"
        fi

        # Use topup to distortion correct the scout scans
        #    using a blip-reversed SE pair "fieldmap" sequence
        ${HCPPIPEDIR_Global}/TopupPreprocessingAll.sh \
            --workingdir=${WD}/FieldMap \
            --phaseone=${SpinEchoPhaseEncodeNegative} \
            --phasetwo=${SpinEchoPhaseEncodePositive} \
            --phaseone2=${SpinEchoPhaseEncodeNegative2} \
            --phasetwo2=${SpinEchoPhaseEncodePositive2} \
            --phasezero=${SpinEchoPhaseEncodeZero}  \
            --scoutin=${ScoutInputName} \
            --seechospacing=${SEEchoSpacing} \
            --unwarpdir=${SEUnwarpDir} \
            --ofmapmag=${WD}/Magnitude \
            --ofmapmagbrain=${WD}/Magnitude_brain \
            --ofmap=${WD}/FieldMap \
            --ojacobian=${WD}/Jacobian \
            --gdcoeffs=${GradientDistortionCoeffs} \
            --topupconfig=${TopupConfig} \
            --usejacobian=${UseJacobian}  \
            --truepatientposition="$TruePatientPosition" \
            --scannerpatientposition="$ScannerPatientPosition"

        ;;

    *)
        log_Err "Unable to create FSL-suitable readout distortion correction field map"
        log_Err_Abort "Unrecognized distortion correction method: ${DistortionCorrection}"
esac

# FSL's naming convention for 'convertwarp --shiftdir' is {x,y,z,x-,y-,z-}
# So, swap out any {i,j,k} for {x,y,z} (using bash pattern replacement)
# and then make sure any '-' sign is trailing
UnwarpDir=${UnwarpDir//i/x}
UnwarpDir=${UnwarpDir//j/y}
UnwarpDir=${UnwarpDir//k/z}
if [ "${UnwarpDir}" = "-x" ] ; then
    UnwarpDir="x-"
fi
if [ "${UnwarpDir}" = "-y" ] ; then
    UnwarpDir="y-"
fi
if [ "${UnwarpDir}" = "-z" ] ; then
    UnwarpDir="z-"
fi

### LOOP over available modalities ###
verbose_echo ""
verbose_red_echo " ---> Looping over modalities"

for TXw in $Modalities ; do

    # set up required variables
    if [ $TXw = T1w ] ; then
        TXwImage=$T1wImage
        TXwImageBrain=$T1wImageBrain
        TXwSampleSpacing=$T1wSampleSpacing
        TXwImageBasename=$T1wImageBasename
        TXwImageBrainBasename=$T1wImageBrainBasename
    else
        TXwImage=$T2wImage
        TXwImageBrain=$T2wImageBrain
        TXwSampleSpacing=$T2wSampleSpacing
        TXwImageBasename=$T2wImageBasename
        TXwImageBrainBasename=$T2wImageBrainBasename
    fi

    if [ "${TXwImage}" = "NONE" ] ; then
        verbose_echo "      ... Skipping $TXw"
        continue
    else
        verbose_echo "      ... $TXw"
    fi

    # Forward warp the fieldmap magnitude and register to TXw image (transform phase image too)

    verbose_echo "      ... Forward warping fieldmap"
    ${FSLDIR}/bin/fugue --loadfmap=${WD}/FieldMap --dwell=${TXwSampleSpacing} --saveshift=${WD}/FieldMap_ShiftMap${TXw}.nii.gz
    ${FSLDIR}/bin/convertwarp --relout --rel --ref=${WD}/Magnitude --shiftmap=${WD}/FieldMap_ShiftMap${TXw}.nii.gz --shiftdir=${UnwarpDir} --out=${WD}/FieldMap_Warp${TXw}.nii.gz

    case $DistortionCorrection in

        ${FIELDMAP_METHOD_OPT} | ${SIEMENS_METHOD_OPT} | ${GE_HEALTHCARE_LEGACY_METHOD_OPT} | ${GE_HEALTHCARE_METHOD_OPT} | ${PHILIPS_METHOD_OPT})
            ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/Magnitude -r ${WD}/Magnitude -w ${WD}/FieldMap_Warp${TXw}.nii.gz -o ${WD}/Magnitude_warpped${TXw}
            if [[ "$SPECIES" == "Human" ]] ; then
            ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/Magnitude_warpped${TXw} -ref ${TXwImage} -out ${WD}/Magnitude_warpped${TXw}2${TXwImageBasename} -omat ${WD}/Fieldmap2${TXwImageBasename}.mat -searchrx -30 30 -searchry -30 30 -searchrz -30 30
            else
                if [[ ! $SPECIES == *Marmoset* ]] ; then
                    ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/Magnitude_warpped${TXw} -ref ${TXwImage}.nii.gz -out ${WD}/Magnitude_warpped${TXw}2${TXwImageBasename} -omat ${WD}/Fieldmap2${TXwImageBasename}.mat -searchrx -30 30 -searchry -30 30 -searchrz -30 30
                else            
                    ${CARET7DIR}/wb_command -convert-affine -from-world ${FSLDIR}/etc/flirtsch/ident.mat -to-flirt ${WD}/Fieldmap2${TXw}.mat ${WD}/Magnitude.nii.gz ${WD}/../../${TXw}/${TXw}.nii.gz
                    ${FSLDIR}/bin/convert_xfm -omat ${WD}/Fieldmap2${TXwImageBasename}_init.mat -concat ${WD}/../../${TXw}/xfms/acpc.mat ${WD}/Fieldmap2${TXw}.mat
                    ${FSLDIR}/bin/flirt -in  ${WD}/Magnitude_warpped${TXw} -ref ${TXwImage} -applyxfm -init ${WD}/Fieldmap2${TXwImageBasename}_init.mat -interp spline -out ${WD}/Magnitude_warpped${TXw}2${TXwImageBasename}_init
                    ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/Magnitude_warpped${TXw}2${TXwImageBasename}_init -ref ${TXwImage} -out ${WD}/Magnitude_warpped${TXw}2${TXwImageBasename} -omat ${WD}/Fieldmap2${TXwImageBasename}_tmp.mat -finesearch 2
                    ${FSLDIR}/bin/convert_xfm -omat ${WD}/Fieldmap2${TXwImageBasename}.mat -concat ${WD}/Fieldmap2${TXwImageBasename}_tmp.mat  ${WD}/Fieldmap2${TXwImageBasename}_init.mat
                    rm -f ${WD}/Fieldmap2${TXwImageBasename}_tmp.mat                        
                fi
            fi
            ;;

        ${SPIN_ECHO_METHOD_OPT})
            if [[ ! $SPECIES == *Marmoset* ]] ; then
                ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/Magnitude_brain -r ${WD}/Magnitude_brain -w ${WD}/FieldMap_Warp${TXw}.nii.gz -o ${WD}/Magnitude_brain_warped${TXw}
                ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/Magnitude_brain_warped${TXw} -ref ${TXwImageBrain} -out ${WD}/Magnitude_brain_warped${TXw}2${TXwImageBasename} -omat ${WD}/Fieldmap2${TXwImageBasename}.mat -searchrx -30 30 -searchry -30 30 -searchrz -30 30
            else  # Marmoset data does not work well for BET-based brain extraction, thus start from the head image and scanner coordinates
                ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/Magnitude -r ${WD}/Magnitude -w ${WD}/FieldMap_Warp${TXw}.nii.gz -o ${WD}/Magnitude_warpped${TXw}
                # Register fieldmap to ACPC space assuming that head is not much moving during scans between SEfield and structure
                ${CARET7DIR}/wb_command -convert-affine -from-world ${FSLDIR}/etc/flirtsch/ident.mat -to-flirt ${WD}/Fieldmap2${TXw}.mat ${WD}/Magnitude.nii.gz ${WD}/../../${TXw}/${TXw}.nii.gz
                ${FSLDIR}/bin/convert_xfm -omat ${WD}/Fieldmap2${TXwImageBasename}_init.mat -concat ${WD}/../../${TXw}/xfms/acpc.mat ${WD}/Fieldmap2${TXw}.mat
                ${FSLDIR}/bin/flirt -in ${WD}/Magnitude_warpped${TXw} -ref ${TXwImage} -applyxfm -init ${WD}/Fieldmap2${TXwImageBasename}_init.mat -interp spline -out ${WD}/Magnitude_warpped${TXw}2${TXwImageBasename}_init

                # Brain extract fieldmap assuming that head is not much moving during scans between SEField and structure
                ${FSLDIR}/bin/fslmaths ${TXwImageBrain} -bin -dilM -dilM -dilM ${WD}/${TXw}_acpc_brain_mask_dil
                ${FSLDIR}/bin/fslmaths ${WD}/Magnitude_warpped${TXw}2${TXwImageBasename}_init -mas ${WD}/${TXw}_acpc_brain_mask_dil ${WD}/Magnitude_warpped${TXw}2${TXwImageBasename}_init_brain

                # Register fieldmap magnitude (head) to structure
                ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/Magnitude_warpped${TXw}2${TXwImageBasename}_init -ref ${TXwImage} -out ${WD}/Magnitude_warpped${TXw}2${TXwImageBasename}_TMP1 -omat ${WD}/Fieldmap2${TXwImageBasename}_TMP1.mat -nosearch

                ${FSLDIR}/bin/flirt -in ${WD}/Magnitude_warpped${TXw}2${TXwImageBasename}_init -ref ${TXwImage} -schedule $FSLDIR/etc/flirtsch/measurecost1.sch -init ${WD}/Fieldmap2${TXwImageBasename}_TMP1.mat $Cost | head -1 | cut -f1 -d' ' >  ${WD}/Magnitude_warpped${TXw}2${TXwImageBasename}_cost.txt
                ${FSLDIR}/bin/flirt -in ${WD}/Magnitude_warpped${TXw}2${TXwImageBasename}_init_brain -ref ${TXwImageBrain} -schedule $FSLDIR/etc/flirtsch/measurecost1.sch -init ${WD}/Fieldmap2${TXwImageBasename}_TMP1.mat $Cost | head -1 | cut -f1 -d' ' >>  ${WD}/Magnitude_warpped${TXw}2${TXwImageBasename}_cost.txt
                # Register fieldmap magnitude (brain) to structure
                ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/Magnitude_warpped${TXw}2${TXwImageBasename}_init_brain -ref ${TXwImageBrain} -out ${WD}/Magnitude_warpped${TXw}2${TXwImageBasename}_TMP2 -omat ${WD}/Fieldmap2${TXwImageBasename}_TMP2.mat -nosearch $Cost $Schedule
                ${FSLDIR}/bin/flirt -in ${WD}/Magnitude_warpped${TXw}2${TXwImageBasename}_init -ref ${TXwImage} -schedule $FSLDIR/etc/flirtsch/measurecost1.sch -init ${WD}/Fieldmap2${TXwImageBasename}_TMP2.mat $Cost | head -1 | cut -f1 -d' ' >>  ${WD}/Magnitude_warpped${TXw}2${TXwImageBasename}_cost.txt
                ${FSLDIR}/bin/flirt -in ${WD}/Magnitude_warpped${TXw}2${TXwImageBasename}_init_brain -ref ${TXwImageBrain} -schedule $FSLDIR/etc/flirtsch/measurecost1.sch -init ${WD}/Fieldmap2${TXwImageBasename}_TMP2.mat $Cost | head -1 | cut -f1 -d' ' >>  ${WD}/Magnitude_warpped${TXw}2${TXwImageBasename}_cost.txt
                # Find smaller mincost registration matrix between those for brain and head and use it to concat matrices
                MinCost=($(cat ${WD}/Magnitude_warpped${TXw}2${TXwImageBasename}_cost.txt))
                if [[ $(echo "${MinCost[1]} < ${MinCost[3]}" | bc ) == 1 ]] ; then
                    MinMat=${WD}/Fieldmap2${TXwImageBasename}_TMP1.mat
                else
                    MinMat=${WD}/Fieldmap2${TXwImageBasename}_TMP2.mat
                fi
                ${FSLDIR}/bin/convert_xfm -omat ${WD}/Fieldmap2${TXwImageBasename}.mat -concat ${MinMat}  ${WD}/Fieldmap2${TXwImageBasename}_init.mat
                # Resampling with the concat matrix
                ${FSLDIR}/bin/flirt -in ${WD}/Magnitude_warpped${TXw} -ref ${TXwImage} -applyxfm -init ${WD}/Fieldmap2${TXwImageBasename}.mat -interp spline -out ${WD}/Magnitude_warpped${TXw}2${TXwImageBasename}
            fi
            ;;

        *)
            log_Err "Unable to apply readout distortion correction"
            log_Err_Abort "Unrecognized distortion correction method: ${DistortionCorrection}"
      
    esac

    ${FSLDIR}/bin/flirt -in ${WD}/FieldMap.nii.gz -ref ${TXwImage} -applyxfm -init ${WD}/Fieldmap2${TXwImageBasename}.mat -out ${WD}/FieldMap2${TXwImageBasename}

    # Convert to shift map then to warp field and unwarp the TXw
    verbose_echo "      ... Converting to shift map, to warp field and unwarping $TXw"
    ${FSLDIR}/bin/fugue --loadfmap=${WD}/FieldMap2${TXwImageBasename} --dwell=${TXwSampleSpacing} --saveshift=${WD}/FieldMap2${TXwImageBasename}_ShiftMap.nii.gz
    ${FSLDIR}/bin/convertwarp --relout --rel --ref=${TXwImageBrain} --shiftmap=${WD}/FieldMap2${TXwImageBasename}_ShiftMap.nii.gz --shiftdir=${UnwarpDir} --out=${WD}/FieldMap2${TXwImageBasename}_Warp.nii.gz
    ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${TXwImage} -r ${TXwImage} -w ${WD}/FieldMap2${TXwImageBasename}_Warp.nii.gz -o ${WD}/${TXwImageBasename}

    # Make a brain image (transform to make a mask, then apply it)

    verbose_echo "      ... Making a brain image"
    ${FSLDIR}/bin/applywarp --rel --interp=nn -i ${TXwImageBrain} -r ${TXwImageBrain} -w ${WD}/FieldMap2${TXwImageBasename}_Warp.nii.gz -o ${WD}/${TXwImageBrainBasename}
    ${FSLDIR}/bin/fslmaths ${WD}/${TXwImageBasename} -mas ${WD}/${TXwImageBrainBasename} ${WD}/${TXwImageBrainBasename}

    # Copy files to specified destinations

    verbose_echo "      ... Copying files"
    if [ $TXw = T1w ] ; then
        ${FSLDIR}/bin/imcp ${WD}/FieldMap2${TXwImageBasename}_Warp ${OutputT1wTransform}
        ${FSLDIR}/bin/imcp ${WD}/${TXwImageBasename} ${OutputT1wImage}
        ${FSLDIR}/bin/imcp ${WD}/${TXwImageBrainBasename} ${OutputT1wImageBrain}
    fi

done

### END LOOP over modalities ###

if [ "${T2wImage}" == "NONE" ] ; then
    verbose_echo ""
    verbose_red_echo " ---> Skipping T2w to T1w registration"

else
        
    verbose_echo ""
    verbose_red_echo " ---> Running T2w to T1w registration"
    if [[ "$SPECIES" != "Human" ]] ; then
        ### Create tentative biasfield corrected image to improve T2w-to-T1w registration - TH Jan 2021
        mkdir -p ${WD}/T2w2T1w
        PipelineScripts=${HCPPIPEDIR_PreFS}
        if [ ! -z ${BiasFieldSmoothingSigma} ] ; then
            BiasFieldSmoothingSigma="--bfsigma=${BiasFieldSmoothingSigma}"
        fi
        ${PipelineScripts}/BiasFieldCorrection_sqrtT1wXT2w.sh \
            --workingdir=${WD}/T2w2T1w/BiasFieldCorrection_sqrtT1wXT2w \
            --T1im=${WD}/${T1wImageBasename} \
            --T1brain=${WD}/${T1wImageBrainBasename} \
            --T2im=${WD}/${T2wImageBasename} \
            --obias=${WD}/T2w2T1w/BiasField_acpc \
            --oT1im=${WD}/${T1wImageBasename}_restore \
            --oT1brain=${WD}/${T1wImageBasename}_restore_brain \
            --oT2im=${WD}/${T2wImageBasename}_restore \
            --oT2brain=${WD}/${T2wImageBasename}_restore_brain \
            ${BiasFieldSmoothingSigma}
    fi
    ### Now do T2w to T1w registration
    mkdir -p ${WD}/T2w2T1w

    # Main registration: between corrected T2w and corrected T1w
    verbose_echo "      ... Corrected T2w to T1w"
    if [ "$SPECIES" != "Human" ] ; then
        ${FSLDIR}/bin/epi_reg --epi=${WD}/${T2wImageBasename}_restore_brain --t1=${WD}/${T1wImageBasename}_restore --t1brain=${WD}/${T1wImageBasename}_restore_brain --out=${WD}/T2w2T1w/T2w_reg  
    else
        ${FSLDIR}/bin/epi_reg --epi=${WD}/${T2wImageBrainBasename} --t1=${WD}/${T1wImageBasename} --t1brain=${WD}/${T1wImageBrainBasename} --out=${WD}/T2w2T1w/T2w_reg
    fi
    # Make a warpfield directly from original (non-corrected) T2w to corrected T1w  (and apply it)
    verbose_echo "      ... Making a warpfield from original"
    ${FSLDIR}/bin/convertwarp --relout --rel --ref=${T1wImage} --warp1=${WD}/FieldMap2${T2wImageBasename}_Warp.nii.gz --postmat=${WD}/T2w2T1w/T2w_reg.mat -o ${WD}/T2w2T1w/T2w_dc_reg
    verbose_echo "      ... Applying warpfield"
    ${FSLDIR}/bin/applywarp --rel --interp=spline --in=${T2wImage} --ref=${T1wImage} --warp=${WD}/T2w2T1w/T2w_dc_reg --out=${WD}/T2w2T1w/T2w_reg

    # Add 1 to avoid exact zeros within the image (a problem for myelin mapping?)
    ${FSLDIR}/bin/fslmaths ${WD}/T2w2T1w/T2w_reg.nii.gz -add 1 ${WD}/T2w2T1w/T2w_reg.nii.gz -odt float

    # QA image
    verbose_echo "      ... Creating QA image"
    if [ "$SPECIES" != "Human" ] ; then
        ${FSLDIR}/bin/fslmaths ${WD}/T2w2T1w/T2w_reg -mul ${WD}/${T1wImageBasename}_restore -sqrt ${WD}/T2w2T1w/sqrtT1wbyT2w -odt float
    else
        ${FSLDIR}/bin/fslmaths ${WD}/T2w2T1w/T2w_reg -mul ${T1wImage} -sqrt ${WD}/T2w2T1w/sqrtT1wbyT2w -odt float    
    fi
    # Copy files to specified destinations
    verbose_echo "      ... Copying files"
    ${FSLDIR}/bin/imcp ${WD}/T2w2T1w/T2w_dc_reg ${OutputT2wTransform}
    ${FSLDIR}/bin/imcp ${WD}/T2w2T1w/T2w_reg ${OutputT2wImage}
fi

verbose_green_echo "---> Finished T2w To T1w Distortion Correction and Registration"

log_Msg "END"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ########################################## 

if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# View registration result of corrected T2w to corrected T1w image: showing both images + sqrt(T1w*T2w)" >> $WD/qa.txt
echo "fslview ${OutputT1wImage} ${OutputT2wImage} ${WD}/T2w2T1w/sqrtT1wbyT2w" >> $WD/qa.txt
echo "# Compare pre- and post-distortion correction for T1w" >> $WD/qa.txt
echo "fslview ${T1wImage} ${OutputT1wImage}" >> $WD/qa.txt
echo "# Compare pre- and post-distortion correction for T2w" >> $WD/qa.txt
echo "fslview ${T2wImage} ${WD}/${T2wImageBasename}" >> $WD/qa.txt

##############################################################################################


