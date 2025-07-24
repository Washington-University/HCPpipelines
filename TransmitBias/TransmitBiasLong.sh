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
source "$HCPPIPEDIR/global/scripts/parallel.shlib" "$@"

opts_SetScriptDescription "Longitudinal multi-session wrapper for RunIndividualOnly.sh"

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all sessions"
opts_AddMandatory '--subject' 'Subject' 'subject ID' "longitudinal subject ID"
opts_AddMandatory '--sessions' 'SessionList' 'session IDs' "@ separated sessions string"
opts_AddMandatory '--longitudinal-template' 'TemplateLong' 'Template ID' 'longitudinal base template ID'
opts_AddMandatory '--mode' 'mode' 'string' "what type of transmit bias correction to apply, options and required inputs are:
AFI - actual flip angle sequence with two different echo times, requires --afi-image, --afi-tr-one, --afi-tr-two, --afi-angle, and --group-corrected-myelin

B1Tx - b1 transmit sequence magnitude/phase pair, requires --b1tx-magnitude, --b1tx-phase, and --group-corrected-myelin

PseudoTransmit - use spin echo fieldmaps, SBRef, and a template transmit-corrected myelin map to derive empirical correction, requires --pt-fmri-names, --myelin-template, --group-uncorrected-myelin, and --reference-value"
opts_AddMandatory '--gmwm-template' 'GMWMtemplate' 'file' "file containing GM+WM volume ROI"

#AFI or B1Tx
opts_AddOptional '--group-corrected-myelin' 'GroupCorrected' 'file' "the group-corrected myelin file from AFI or B1Tx"

#AFI-specific. Should be the same as in the corresponding cross-sectional calls.
#Commented parameters are re-used from cross-sectional calls.
#opts_AddOptional '--afi-image' 'AFIImage' 'file' "two-frame AFI image"
opts_AddOptional '--afi-tr-one' 'AFITRone' 'number' "TR of first AFI frame"
opts_AddOptional '--afi-tr-two' 'AFITRtwo' 'number' "TR of second AFI frame"
opts_AddOptional '--afi-angle' 'AFITargFlipAngle' 'number' "target flip angle of AFI sequence"

#B1Tx-specific. Should be the same as in the corresponding cross-sectional calls.
#Commented parameters are re-used from cross-sectional calls.
#opts_AddOptional '--b1tx-magnitude' 'B1TxMag' 'file' "B1Tx magnitude image (for alignment)"
#opts_AddOptional '--b1tx-phase' 'B1TxPhase' 'file' "B1Tx phase image"
opts_AddOptional '--b1tx-phase-divisor' 'B1TxDiv' 'number' "what to divide the phase map by to obtain proportion of intended flip angle, default 800" '800'

#PseudoTransmit-specific. Should be the same as in the corresponding cross-sectional calls.
opts_AddOptional '--pt-fmri-names' 'fMRINames' 'rfMRI_REST1_LR@rfMRI_REST1_RL...' "fmri runs to use SE/SBRef files from, separated by @"
opts_AddOptional '--pt-bbr-threshold' 'ptbbrthresh' 'number' "mincost threshold for reinitializing fMRI bbregister with flirt (may need to be increased for aging-related reduction of gray/white contrast), default 0.5" '0.5'
opts_AddOptional '--myelin-template' 'ReferenceTemplate' 'file' "expected transmit-corrected group-average myelin pattern (for testing correction parameters)"
opts_AddOptional '--group-uncorrected-myelin' 'GroupUncorrectedMyelin' 'file' "the group-average uncorrected myelin file (to set the appropriate scaling of the myelin template)"
opts_AddOptional '--pt-reference-value-file' 'PseudoTransmitReferenceValueFile' 'file' "text file containing the value in the pseudotransmit map where the flip angle best matches the intended angle, from the Phase2 group script"

#receive correction - these are re-used from cross-sectional sessions.
#opts_AddOptional '--unproc-t1w-list' 'T1wunprocstr' 'image1@image2...' "list of unprocessed T1w images, for correcting non-PSN data"
#opts_AddOptional '--unproc-t2w-list' 'T2wunprocstr' 'image1@image2...' "list of unprocessed T2w images, for correcting non-PSN data"
#opts_AddOptional '--receive-bias-body-coil' 'biasBCin' 'file' "image acquired with body coil receive, to be used with --receive-bias-head-coil"
#opts_AddOptional '--receive-bias-head-coil' 'biasHCin' 'file' "matched image acquired with head coil receive"
#opts_AddOptional '--raw-psn-t1w' 'rawT1wPSN' 'file' "the bias-corrected version of the T1w image acquired with pre-scan normalize, which was used to generate the original myelin maps"
#opts_AddOptional '--raw-nopsn-t1w' 'rawT1wBiased' 'file' "the uncorrected version of the --raw-psn-t1w image"

#generic other settings
opts_AddOptional '--scanner-grad-coeffs' 'GradientDistortionCoeffs' 'file' "Siemens gradient coefficients file" '' '--gdcoeffs'
#could be optional?
#MFG: stay mandatory
opts_AddMandatory '--reg-name' 'RegName' 'string' "surface registration to use, like MSMAll"
opts_AddOptional '--low-res-mesh' 'LowResMesh' 'number' "resolution of grayordinates mesh, default '32'" '32'
#MFG: T1w/ outputs should use transmit resolution, MNINonLinear/ use grayordinates
#MFG: should add default of 2 to PostFS if we have a default here
opts_AddOptional '--grayordinates-res' 'grayordRes' 'number' "resolution used in PostFreeSurfer for grayordinates, default '2'" '2'
opts_AddOptional '--transmit-res' 'transmitRes' 'number' "resolution to use for transmit field, default equal to --grayordinates-res"
opts_AddOptional '--myelin-mapping-fwhm' 'MyelinMappingFWHM' 'number' "fwhm value to use in -myelin-style, default 5" '5'
opts_AddOptional '--old-myelin-mapping' 'oldmappingStr' 'TRUE or FALSE' "if myelin mapping was done using version 1.2.3 or earlier of wb_command, set this to true" 'false'
opts_AddOptional '--matlab-run-mode' 'MatlabMode' '0, 1, or 2' "defaults to 1
0 = compiled MATLAB
1 = interpreted MATLAB
2 = Octave" '1'

#parallel mode options
opts_AddOptional '--parallel-mode' 'parallel_mode' 'string' "parallel mode, one of FSLSUB, BUILTIN, NONE [BUILTIN]" 'BUILTIN'
opts_AddOptional '--fslsub-queue' 'fslsub_queue' 'name' "FSLSUB queue name" ""
opts_AddOptional '--max-jobs' 'max_jobs' 'number' "Maximum number of concurrent processes in BUILTIN mode. Set to -1 to auto-detect [-1]." -1

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

IFS=@ read -r -a Sessions <<< "${SessionList}"

#Run Transmit Bias for all sessions, wait for them to finish.
for Session in "${Sessions[@]}"; do
    cmd=(${HCPPIPEDIR}/TransmitBias/RunIndividualOnly.sh    \
        --study-folder="$StudyFolder"                       \
        --session="$Session"                                \
        --mode="$mode"                                      \
        --gmwm-template="$GMWMtemplate"                     \
        --group-corrected-myelin="$GroupCorrected"          \
        --afi-tr-one="$AFITRone"                            \
        --afi-tr-two="$AFITRtwo"                            \
        --afi-angle="$AFITargFlipAngle"                     \
        --b1tx-phase-divisor="$B1TxDiv"                     \
        --pt-fmri-names="$fMRINames"                        \
        --pt-bbr-threshold="$ptbbrthresh"                   \
        --myelin-template="$ReferenceTemplate"              \
        --group-uncorrected-myelin="$GroupUncorrectedMyelin" \
        --pt-reference-value-file="$PseudoTransmitReferenceValueFile" \
        --is-longitudinal="TRUE"                            \
        --longitudinal-template="$TemplateLong"             \
        --scanner-grad-coeffs="$GradientDistortionCoeffs"   \
        --reg-name="$RegName"                               \
        --low-res-mesh="$LowResMesh"                        \
        --grayordinates-res="$grayordRes"                   \
        --transmit-res="$transmitRes"                       \
        --myelin-mapping-fwhm="$MyelinMappingFWHM"          \
        --old-myelin-mapping="$oldmappingStr"               \
        --matlab-run-mode="$MatlabMode"                     
    )
    par_add_job_to_stage "$parallel_mode" "$fslsub_queue" "${cmd[@]}"
done
par_finalize_stage "$parallel_mode" "$max_jobs"

#Average the resulting myelin maps in the template directory
T1wDivT2wCorrArray=()
T1wDivT2wCorrAtlasArray=()
MyelinMapCorrArray=()

TemplateSession="$Subject.long.$TemplateLong"
AtlasFolderTemplate="$StudyFolder/$TemplateSession/MNINonLinear"

case "$mode" in
    AFI) suffix="Corr"; suffix1="Corr" ;;
    PseudoTransmit) suffix="PseudoCorr"; suffix1="PseudoCorr_${RegName}" ;;
    B1Tx) suffix="Corr"; suffix1="Corr" ;;
    *)  log_Err_Abort "Unrecognized transmit correction mode: $mode" ;;
esac

for Session in "${Sessions[@]}"; do
    SessionLong="$Session".long."$TemplateLong"
    AtlasFolder="$StudyFolder/$SessionLong/MNINonLinear"
    T1wDivT2wCorrArray+=(-volume "$AtlasFolder/T1wDividedByT2w_${suffix}.nii.gz")
    T1wDivT2wCorrAtlasArray+=(-volume "$AtlasFolder/T1wDividedByT2w_${suffix}_Atlas.nii.gz")
    MyelinMapCorrArray+=(-cifti "$AtlasFolder/fsaverage_LR32k/${SessionLong}.MyelinMap_${suffix1}.32k_fs_LR.dscalar.nii")
done

tempfiles_create T1wDivT2wCorrXXXX.nii temp_T1wDivT2wCorr
wb_command -volume-merge "$temp_T1wDivT2wCorr" "${T1wDivT2wCorrArray[@]}"
wb_command -volume-reduce "$temp_T1wDivT2wCorr" MEAN "$AtlasFolderTemplate"/"T1wDividedByT2w_${suffix}.nii.gz"
    
tempfiles_create T1wDivT2wCorrAtlasXXXX.nii temp_T1wDivT2wCorrAtlas
wb_command -volume-merge "$temp_T1wDivT2wCorrAtlas" "${T1wDivT2wCorrAtlasArray[@]}"
wb_command -volume-reduce "$temp_T1wDivT2wCorrAtlas" MEAN "$AtlasFolderTemplate"/"T1wDividedByT2w_${suffix}_Atlas.nii.gz"

wb_command -cifti-average "$AtlasFolderTemplate/fsaverage_LR32k/$TemplateSession.MyelinMap_${suffix1}.32k_fs_LR.dscalar.nii" \
   "${MyelinMapCorrArray[@]}"

log_Msg "Completed TransmitBiasLong.sh"