#!/bin/bash
set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/tempfiles.shlib" "$@"

opts_SetScriptDescription "align transmit bias and myelin-related scans and fine-tune receive bias"

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject' 'Subject' 'subject ID' "(e.g. 100610)"
opts_AddMandatory '--reg-name' 'RegName' 'string' "surface registration to use, like MSMAll"
opts_AddMandatory '--mode' 'mode' 'string' "what type of transmit bias correction to apply, options and required inputs are:
AFI - actual flip angle sequence with two different echo times, requires --afi-image, --afi-tr-one, and --afi-tr-two

B1Tx - b1 transmit sequence magnitude/phase pair, requires --b1tx-magnitude and --b1tx-phase

PseudoTransmit - use spin echo fieldmaps, SBRef, and a template transmit-corrected myelin map to derive empirical correction, requires --pt-fmri-names"

#AFI-specific
opts_AddOptional '--afi-image' 'AFIImage' 'file' "two-frame AFI image"
opts_AddOptional '--afi-tr-one' 'AFITRone' 'number' "TR of first AFI frame"
opts_AddOptional '--afi-tr-two' 'AFITRtwo' 'number' "TR of second AFI frame"
#angle is only needed in later phases

#B1Tx-specific
opts_AddOptional '--b1tx-magnitude' 'B1TxMag' 'file' "B1Tx magnitude image (for alignment)"
opts_AddOptional '--b1tx-phase' 'B1TxPhase' 'file' "B1Tx phase image"
opts_AddOptional '--b1tx-phase-divisor' 'B1TxDiv' 'number' "what to divide the phase map by to obtain proportion of intended flip angle, default 800" '800'

#PseudoTransmit-specific
opts_AddOptional '--pt-fmri-names' 'fMRINames' 'rfMRI_REST1_LR@rfMRI_REST1_RL...' "fmri runs to use SE/SBRef files from, separated by @"
opts_AddOptional '--pt-bbr-threshold' 'ptbbrthresh' 'number' "mincost threshold for reinitializing fMRI bbregister with flirt (may need to be increased for aging-related reduction of gray/white contrast), default 0.5" '0.5'

#receive correction
opts_AddOptional '--unproc-t1w-list' 'T1wunprocstr' 'image1@image2...' "list of unprocessed T1w images, for correcting non-PSN data"
opts_AddOptional '--unproc-t2w-list' 'T2wunprocstr' 'image1@image2...' "list of unprocessed T2w images, for correcting non-PSN data"
opts_AddOptional '--receive-bias-body-coil' 'biasBCin' 'file' "image acquired with body coil receive, to be used with --receive-bias-head-coil"
opts_AddOptional '--receive-bias-head-coil' 'biasHCin' 'file' "matched image acquired with head coil receive"
opts_AddOptional '--raw-psn-t1w' 'rawT1wPSN' 'file' "the bias-corrected version of the T1w image acquired with pre-scan normalize, which was used to generate the original myelin maps"
opts_AddOptional '--raw-nopsn-t1w' 'rawT1wBiased' 'file' "the uncorrected version of the --raw-psn-t1w image"

#generic other settings
opts_AddOptional '--scanner-grad-coeffs' 'GradientDistortionCoeffs' 'file' "Siemens gradient coefficients file" '' '--gdcoeffs'
opts_AddOptional '--low-res-mesh' 'LowResMesh' 'number' "resolution of grayordinates mesh, default '32'" '32'
#MFG: T1w/ outputs should use transmit resolution, MNINonLinear/ use grayordinates
#MFG: should add default of 2 to PostFS if we have a default here
opts_AddOptional '--grayordinates-res' 'grayordRes' 'number' "resolution used in PostFreeSurfer for grayordinates, default '2'" '2' '--grayordinatesres'
opts_AddOptional '--transmit-res' 'transmitRes' 'number' "resolution to use for transmit field, default equal to --grayordinates-res"
opts_AddOptional '--myelin-mapping-fwhm' 'MyelinMappingFWHM' 'number' "fwhm value to use in -myelin-style, default 5" '5'
opts_AddOptional '--old-myelin-mapping' 'oldmappingStr' 'TRUE or FALSE' "if myelin mapping was done using version 1.2.3 or earlier of wb_command, set this to true" 'false'

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

oldmapping=$(opts_StringToBool "$oldmappingStr")

if [[ "$transmitRes" == "" ]]
then
    transmitRes="$grayordRes"
fi

if [[ "$RegName" == "" || "$RegName" == "MSMSulc" ]]
then
    RegString=""
else
    RegString="_$RegName"
fi

case "$mode" in
    (AFI)
        if [[ "$AFIImage" == "" || "$AFITRone" == "" || "$AFITRtwo" == "" ]]
        then
            log_Err_Abort "$mode transmit correction mode requires --afi-image, --afi-tr-one, and --afi-tr-two"
        fi
        ;;
    (B1Tx)
        if [[ "$B1TxMag" == "" || "$B1TxPhase" == "" ]]
        then
            log_Err_Abort "$mode transmit correction mode requires --b1tx-magnitude and --b1tx-phase"
        fi
        ;;
    (PseudoTransmit)
        if [[ "$fMRINames" == "" ]]
        then
            log_Err_Abort "$mode transmit correction mode requires --pt-fmri-names"
        fi
        #support different resolutions for processing spin echo/SBRef versus outputting to MNI lowres, even here
        ;;
    (*)
        log_Err_Abort "unrecognized transmit correction mode $mode"
        ;;
esac

WorkingDIR="$StudyFolder"/"$Subject"/TransmitBias

mkdir -p "$WorkingDIR"

#Build Paths
T1wFolder="$StudyFolder"/"$Subject"/T1w
AtlasFolder="$StudyFolder"/"$Subject"/MNINonLinear
T1wResultsFolder="$T1wFolder"/Results
ResultsFolder="$AtlasFolder"/Results
T1wDownSampleFolder="$T1wFolder"/fsaverage_LR"$LowResMesh"k
DownSampleFolder="$AtlasFolder"/fsaverage_LR"$LowResMesh"k

scriptsdir="$HCPPIPEDIR"/TransmitBias/scripts

#sanity check grayordinates argument
log_File_Must_Exist "$AtlasFolder"/T1w_restore."$grayordRes".nii.gz

#check for 0 or NaN in myelin, and dilate if needed
tempfiles_create TransmitBias_zeroscheck_XXXXXX.dscalar.nii zerocheck
wb_command -cifti-math 'x != x || x == 0' "$zerocheck" \
    -fixnan 1 \
    -var x "$DownSampleFolder"/"$Subject".MyelinMap"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii

numbad=$(wb_command -cifti-stats "$zerocheck" -reduce COUNT_NONZERO)

if [[ "$numbad" != 0 ]]
then
    log_Msg "check for zeros/NaNs in myelin map returned '$numbad', dilating"

    wb_command -cifti-dilate "$DownSampleFolder"/"$Subject".MyelinMap"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii COLUMN 5 5 \
        "$DownSampleFolder"/"$Subject".MyelinMap"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii \
        -left-surface "$T1wDownSampleFolder"/"$Subject".L.midthickness"$RegString"."$LowResMesh"k_fs_LR.surf.gii \
        -right-surface "$T1wDownSampleFolder"/"$Subject".R.midthickness"$RegString"."$LowResMesh"k_fs_LR.surf.gii \
        -bad-brainordinate-roi "$zerocheck"
fi

#NOTE: this script also generates T1w/T1w_acpc_dc_restore."$transmitRes".nii.gz
"$scriptsdir"/CreateTransmitBiasROIs.sh \
    --study-folder="$StudyFolder" \
    --subject="$Subject" \
    --grayordinates-res="$grayordRes" \
    --transmit-res="$transmitRes"

#generic receive field handling
#NOTE: ReceiveField.2.nii.gz used to be in the individual method folder
#PT needs receive bias volume file, and needs to know that it should be applied to phases and sbref
#AFI is an interleaved 3D scan, can't have interpretable motion between TRs in image space, but can use it for alignment
#B1Tx is phase-based, but magnitude is used for alignment

#"T1w/ReceiveFieldCorrection.nii.gz" filename isn't obviously myelin-related, but the contents are
#MFG: stuck, already packaged
ReceiveBias=""
if [[ "$T1wunprocstr" != "" ]]
then
    ReceiveBias="$WorkingDIR"/ReceiveField."$transmitRes".nii.gz
    RFWD="$T1wFolder"/CalculateReceiveField
    #doesn't generate MNI space outputs, so doesn't need to know fMRI resolution
    "$scriptsdir"/CalculateReceiveField.sh \
        --study-folder="$StudyFolder" \
        --subject="$Subject" \
        --workingdir="$RFWD" \
        --transmit-res="$transmitRes" \
        --scanner-grad-coeffs="$GradientDistortionCoeffs" \
        --bodycoil="$biasBCin" \
        --headcoil="$biasHCin" \
        --psn-t1w-image="$rawT1wPSN" \
        --nopsn-t1w-image="$rawT1wBiased" \
        --unproc-t1w-list="$T1wunprocstr" \
        --unproc-t2w-list="$T2wunprocstr" \
        --low-res-mesh="$LowResMesh" \
        --reg-name="$RegName" \
        --bias-image-out="$ReceiveBias" \
        --myelin-correction-field-out="$T1wFolder"/ReceiveFieldCorrection.nii.gz \
        --t1w-corrected-out="$WorkingDIR"/T1w_acpc_dc_newreceive.nii.gz \
        --t2w-corrected-out="$WorkingDIR"/T2w_acpc_dc_newreceive.nii.gz \
        --myelin-surface-correction-out="$DownSampleFolder"/"$Subject".ReceiveFieldCorrection"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii

    #these files are in the package definitions
    cp "$RFWD"/ReceiveFieldCorrection."$transmitRes".nii.gz "$T1wFolder"/ReceiveFieldCorrection."$transmitRes".nii.gz
    cp "$RFWD"/L.ReceiveFieldCorrection"$RegString"."$LowResMesh"k_fs_LR.func.gii "$DownSampleFolder"/"$Subject".L.ReceiveFieldCorrection"$RegString"."$LowResMesh"k_fs_LR.func.gii
    cp "$RFWD"/R.ReceiveFieldCorrection"$RegString"."$LowResMesh"k_fs_LR.func.gii "$DownSampleFolder"/"$Subject".R.ReceiveFieldCorrection"$RegString"."$LowResMesh"k_fs_LR.func.gii
    
    #shouldn't use a low res volume in -fnirt for structural warp
    acpc2mni=(-warp "$AtlasFolder"/xfms/acpc_dc2standard.nii.gz -fnirt "$AtlasFolder"/T1w_restore.nii.gz)
    
    #MFG: cross subject comparison
    wb_command -volume-resample "$T1wFolder"/ReceiveFieldCorrection.nii.gz \
        "$AtlasFolder"/T1w_restore."$transmitRes".nii.gz \
        TRILINEAR \
        "$AtlasFolder"/ReceiveFieldCorrection."$transmitRes".nii.gz \
        "${acpc2mni[@]}"
    
    #ditto at structural resolution
    wb_command -volume-resample "$T1wFolder"/ReceiveFieldCorrection.nii.gz \
        "$AtlasFolder"/T1w_restore.nii.gz \
        TRILINEAR \
        "$AtlasFolder"/ReceiveFieldCorrection.nii.gz \
        "${acpc2mni[@]}"

    #generate receive-corrected myelin, to simplify and improve the group averaging, etc code
    #NOTE: some later phases need to know whether receive bias correction was done
    wb_command -cifti-math 'myelin / receivecorr' "$WorkingDIR"/"$Subject".MyelinMap_onlyRC"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii \
        -var myelin "$DownSampleFolder"/"$Subject".MyelinMap"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii \
        -var receivecorr "$DownSampleFolder"/"$Subject".ReceiveFieldCorrection"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii
    
    #MFG: just clamp 100 here, leave dilation for _Atlas
    #because the RC convention is division, we may need to replace any zeros, so add the "== 0" test to RC
    wb_command -volume-math "clamp(origmyelin / (RC + (RC == 0)), 0, 100)" "$WorkingDIR"/T1wDividedByT2w_onlyRC.nii.gz -fixnan 0 \
        -var origmyelin "$T1wFolder"/T1wDividedByT2w.nii.gz \
        -var RC "$T1wFolder"/ReceiveFieldCorrection.nii.gz

    #NOTE: MNINonLinear/T1wDivT2w will always be RC-corrected, but T1w/T1wDivT2w won't (already existed, also _ribbon version...)
    wb_command -volume-math "clamp(T1w / T2w / (RC + (RC == 0)), 0, 100)" "$AtlasFolder"/T1wDividedByT2w.nii.gz -fixnan 0 \
        -var T1w "$AtlasFolder"/T1w.nii.gz \
        -var T2w "$AtlasFolder"/T2w.nii.gz \
        -var RC "$AtlasFolder"/ReceiveFieldCorrection.nii.gz
        
    #we will generate corrected _ribbon outputs (later) by masking full volume, ignoring the clamping difference of previous files
else
    wb_command -volume-math 'clamp(T1w / T2w, 0, 100)' "$AtlasFolder"/T1wDividedByT2w.nii.gz -fixnan 0 \
        -var T1w "$AtlasFolder"/T1w.nii.gz \
        -var T2w "$AtlasFolder"/T2w.nii.gz
fi

case "$mode" in
    (AFI)
        "$scriptsdir"/AFI_IndividualAlignRawAndInitialMaps.sh \
            --study-folder="$StudyFolder" \
            --subject="$Subject" \
            --working-dir="$WorkingDIR"/AFI \
            --receive-bias="$ReceiveBias" \
            --t1w-receive-corrected="$WorkingDIR"/T1w_acpc_dc_newreceive.nii.gz \
            --afi-input="$AFIImage" \
            --afi-tr-one="$AFITRone" \
            --afi-tr-two="$AFITRtwo" \
            --scanner-grad-coeffs="$GradientDistortionCoeffs" \
            --reg-name="$RegName" \
            --low-res-mesh="$LowResMesh" \
            --grayordinates-res="$grayordRes" \
            --transmit-res="$transmitRes" \
            --myelin-mapping-fwhm="$MyelinMappingFWHM" \
            --old-myelin-mapping="$oldmapping"
        ;;
    (B1Tx)
        "$scriptsdir"/B1Tx_IndividualAlignRawAndInitialMaps.sh \
            --study-folder="$StudyFolder" \
            --subject="$Subject" \
            --working-dir="$WorkingDIR"/B1Tx \
            --receive-bias="$ReceiveBias" \
            --t2w-receive-corrected="$WorkingDIR"/T2w_acpc_dc_newreceive.nii.gz \
            --b1tx-mag="$B1TxMag" \
            --b1tx-phase="$B1TxPhase" \
            --b1tx-phase-divisor="$B1TxDiv" \
            --scanner-grad-coeffs="$GradientDistortionCoeffs" \
            --reg-name="$RegName" \
            --low-res-mesh="$LowResMesh" \
            --grayordinates-res="$grayordRes" \
            --transmit-res="$transmitRes" \
            --myelin-mapping-fwhm="$MyelinMappingFWHM" \
            --old-myelin-mapping="$oldmapping"
        ;;
    (PseudoTransmit)
        "$scriptsdir"/PseudoTransmit_IndividualAlignRawAndInitialMaps.sh \
            --study-folder="$StudyFolder" \
            --subject="$Subject" \
            --working-dir="$WorkingDIR"/PseudoTransmit \
            --receive-bias="$ReceiveBias" \
            --t2w-receive-corrected="$WorkingDIR"/T2w_acpc_dc_newreceive.nii.gz \
            --fmri-names="$fMRINames" \
            --bbr-threshold="$ptbbrthresh" \
            --reg-name="$RegName" \
            --low-res-mesh="$LowResMesh" \
            --grayordinates-res="$grayordRes" \
            --transmit-res="$transmitRes" \
            --myelin-mapping-fwhm="$MyelinMappingFWHM" \
            --old-myelin-mapping="$oldmapping"
        ;;
    (*)
        log_Err_Abort "internal script error, mode $mode implementation not handled"
        ;;
esac

