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

opts_SetScriptDescription "adjust individual transmit correction based on group average fit"

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject' 'Subject' 'subject ID' "(e.g. 100610)"
opts_AddMandatory '--reg-name' 'RegName' 'string' "surface registration to use, like MSMAll"
opts_AddMandatory '--mode' 'mode' 'string' "what type of transmit bias correction to apply, options and required inputs are:
AFI - actual flip angle sequence with two different echo times, requires --afi-tr-one, --afi-tr-two, --target-flip-angle, and --group-corrected-myelin

B1Tx - b1 transmit sequence magnitude/phase pair, requires --group-corrected-myelin

PseudoTransmit - use spin echo fieldmaps, SBRef, and a template transmit-corrected myelin map to derive empirical correction, requires --myelin-template, --group-uncorrected-myelin, and --reference-value"
opts_AddOptional '--manual-receive' 'useRCfilesStr' 'TRUE or FALSE' "whether Phase1 used unprocessed scans to correct for not using PSN when acquiring scans" 'false'
opts_AddMandatory '--gmwm-template' 'GMWMtemplate' 'file' "file containing GM+WM volume ROI"

#AFI or B1Tx
opts_AddOptional '--group-corrected-myelin' 'GroupCorrected' 'file' "the group-corrected myelin file from AFI or B1Tx"

#AFI-specific
opts_AddOptional '--afi-tr-one' 'AFITRone' 'number' "TR of first AFI frame"
opts_AddOptional '--afi-tr-two' 'AFITRtwo' 'number' "TR of second AFI frame"
opts_AddOptional '--afi-angle' 'AFITargFlipAngle' 'number' "the target flip angle of the AFI sequence"

#PseudoTransmit-specific
opts_AddOptional '--myelin-template' 'ReferenceTemplate' 'file' "expected transmit-corrected group-average myelin pattern (for testing correction parameters)"
opts_AddOptional '--group-uncorrected-myelin' 'GroupUncorrectedMyelin' 'file' "the group-average uncorrected myelin file (to set the appropriate scaling of the myelin template)"
opts_AddOptional '--pt-reference-value-file' 'PseudoTransmitReferenceValueFile' 'file' "text file containing the value in the pseudotransmit map where the flip angle best matches the intended angle, from the Phase2 group script"

#generic other settings
opts_AddOptional '--low-res-mesh' 'LowResMesh' 'number' "resolution of grayordinates mesh, default '32'" '32'
opts_AddOptional '--grayordinates-res' 'grayordRes' 'number' "resolution used in PostFreeSurfer for grayordinates, default '2'" '2' '--grayordinatesres'
opts_AddOptional '--transmit-res' 'transmitRes' 'number' "resolution to use for transmit field, default equal to --grayordinates-res"
opts_AddOptional '--matlab-run-mode' 'MatlabMode' '0, 1, or 2' "defaults to 1
0 = compiled MATLAB
1 = interpreted MATLAB
2 = Octave" '1'

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

useRCfiles=$(opts_StringToBool "$useRCfilesStr")

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

#check the arguments before running commands
case "$mode" in
    (AFI)
        if [[ "$AFITRone" == "" || "$AFITRtwo" == "" || "$AFITargFlipAngle" == "" || "$GroupCorrected" == "" ]]
        then
            log_Err_Abort "$mode transmit correction mode requires --afi-tr-one, --afi-tr-two, --target-flip-angle, and --group-corrected-myelin"
        fi
        ;;
    (B1Tx)
        if [[ "$GroupCorrected" == "" ]]
        then
            log_Err_Abort "$mode transmit correction mode requires --group-corrected-myelin"
        fi
        ;;
    (PseudoTransmit)
        if [[ "$ReferenceTemplate" == "" || "$GroupUncorrectedMyelin" == "" || "$PseudoTransmitReferenceValueFile" == "" ]]
        then
            log_Err_Abort "$mode transmit correction mode requires --myelin-template, --group-uncorrected-myelin, and --pt-reference-value-file"
        fi
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

function indvolToAtlas()
{
    indata="$1"
    volout="$2"
    tempfiles_create indvolToAtlas_XXXXXX.nii.gz masktemp
    tempfiles_add "$masktemp"_dilate.nii.gz
    wb_command -volume-math '(mask > 0) * data' "$masktemp" -var mask "$AtlasFolder"/GMWMTemplate.nii.gz -subvolume 1 -repeat -var data "$indata"
    wb_command -volume-dilate "$masktemp" 10 WEIGHTED "$masktemp"_dilate.nii.gz -data-roi "$GMWMtemplate"
    wb_command -volume-math '(mask > 0) * data' "$volout" -var mask "$GMWMtemplate" -subvolume 1 -repeat -var data "$masktemp"_dilate.nii.gz
}

#do method-independent stuff first
if ((useRCfiles))
then
    indvolToAtlas "$AtlasFolder"/ReceiveFieldCorrection.nii.gz "$AtlasFolder"/ReceiveFieldCorrection_Atlas.nii.gz
fi
tempfiles_create TransmitBias_T1divT2atlas_XXXXXX.nii.gz t1divt2temp
indvolToAtlas "$AtlasFolder"/T1wDividedByT2w.nii.gz "$t1divt2temp"

tempfiles_add "$t1divt2temp"_2.nii.gz
wb_command -volume-math "x * (x > 0) * (x < 10)" "$t1divt2temp"_2.nii.gz -var x "$t1divt2temp" -fixnan 0
wb_command -volume-dilate "$t1divt2temp"_2.nii.gz 4 WEIGHTED "$AtlasFolder"/T1wDividedByT2w_Atlas.nii.gz -data-roi "$GMWMtemplate"

case "$mode" in
    (AFI)
        "$scriptsdir"/AFI_IndividualFitCorrection.sh \
            --study-folder="$StudyFolder" \
            --subject="$Subject" \
            --manual-receive="$useRCfiles" \
            --gmwm-template="$GMWMtemplate" \
            --group-corrected-myelin="$GroupCorrected" \
            --afi-tr-one="$AFITRone" \
            --afi-tr-two="$AFITRtwo" \
            --target-flip-angle="$AFITargFlipAngle" \
            --grayordinates-res="$grayordRes" \
            --transmit-res="$transmitRes" \
            --reg-name="$RegName" \
            --low-res-mesh="$LowResMesh" \
            --matlab-run-mode="$MatlabMode"
        ;;
    (B1Tx)
        "$scriptsdir"/B1Tx_IndividualFitCorrection.sh \
            --study-folder="$StudyFolder" \
            --subject="$Subject" \
            --manual-receive="$useRCfiles" \
            --gmwm-template="$GMWMtemplate" \
            --group-corrected-myelin="$GroupCorrected" \
            --grayordinates-res="$grayordRes" \
            --transmit-res="$transmitRes" \
            --reg-name="$RegName" \
            --low-res-mesh="$LowResMesh" \
            --matlab-run-mode="$MatlabMode"
        ;;
    (PseudoTransmit)
        "$scriptsdir"/PseudoTransmit_IndividualFitCorrection.sh \
            --study-folder="$StudyFolder" \
            --subject="$Subject" \
            --manual-receive="$useRCfiles" \
            --gmwm-template="$GMWMtemplate" \
            --myelin-template="$ReferenceTemplate" \
            --group-uncorrected-myelin="$GroupUncorrectedMyelin" \
            --reference-value=$(cat "$PseudoTransmitReferenceValueFile") \
            --grayordinates-res="$grayordRes" \
            --transmit-res="$transmitRes" \
            --reg-name="$RegName" \
            --low-res-mesh="$LowResMesh" \
            --matlab-run-mode="$MatlabMode"
        ;;
    (*)
        log_Err_Abort "internal script error, mode $mode implementation not handled"
        ;;
esac

