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

opts_SetScriptDescription "average final transmit field files"

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject-list' 'SubjectSTR' 'subject1@subject2...' "list of subjects separated by @"
opts_AddMandatory '--reg-name' 'RegName' 'string' "surface registration to use, like MSMAll"
opts_AddMandatory '--mode' 'mode' 'string' "what type of transmit bias correction to apply, options and required inputs are:
AFI - actual flip angle sequence with two different echo times, requires --afi-tr-one, --afi-tr-two, --afi-angle, and --transmit-group-name

B1Tx - b1 transmit sequence magnitude/phase pair, requires --transmit-group-name

PseudoTransmit - use spin echo fieldmaps, SBRef, and a template transmit-corrected myelin map to derive empirical correction, requires --average-myelin"
opts_AddMandatory '--group-average-name' 'GroupAverageName' 'name' "output folder (e.g. S900)"
opts_AddOptional '--transmit-group-name' 'TransmitGroupName' 'name' "name for the subgroup of subjects that have good transmit data (e.g. Partial)"
opts_AddMandatory '--voltages' 'VoltagesFile' 'file' "text file of scanner calibrated transmit voltages for each subject"

#AFI-specific
opts_AddOptional '--afi-tr-one' 'AFITRone' 'number' "TR of first AFI frame"
opts_AddOptional '--afi-tr-two' 'AFITRtwo' 'number' "TR of second AFI frame"
opts_AddOptional '--afi-angle' 'AFIangle' 'number' "target flip angle of AFI sequence"

#PseudoTransmit-specific
opts_AddOptional '--average-myelin' 'myelinCiftiAvg' 'file' "cifti file of group average of uncorrected myelin"

#general
opts_AddOptional '--low-res-mesh' 'LowResMesh' 'number' "resolution of grayordinates mesh, default '32'" '32'
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

scriptsdir="$HCPPIPEDIR"/TransmitBias/scripts

case "$mode" in
    (AFI)
        if [[ "$AFITRone" == "" || "$AFITRtwo" == "" || "$AFIangle" == "" || "$TransmitGroupName" == "" ]]
        then
            log_Err_Abort "$mode transmit correction mode requires --afi-tr-one, --afi-tr-two, --afi-angle, and --transmit-group-name"
        fi
        "$scriptsdir"/AFI_GroupAverageCorrectedMaps.sh \
            --study-folder="$StudyFolder" \
            --subject-list="$SubjectSTR" \
            --group-average-name="$GroupAverageName" \
            --transmit-group-name="$TransmitGroupName" \
            --voltages="$VoltagesFile" \
            --afi-tr-one="$AFITRone" \
            --afi-tr-two="$AFITRtwo" \
            --target-flip-angle="$AFIangle" \
            --reg-name="$RegName" \
            --low-res-mesh="$LowResMesh" \
            --matlab-run-mode="$MatlabMode"
        ;;
    (B1Tx)
        if [[ "$TransmitGroupName" == "" ]]
        then
            log_Err_Abort "$mode transmit correction mode requires --transmit-group-name"
        fi
        "$scriptsdir"/B1Tx_GroupAverageCorrectedMaps.sh \
            --study-folder="$StudyFolder" \
            --subject-list="$SubjectSTR" \
            --group-average-name="$GroupAverageName" \
            --transmit-group-name="$TransmitGroupName" \
            --voltages="$VoltagesFile" \
            --reg-name="$RegName" \
            --low-res-mesh="$LowResMesh" \
            --matlab-run-mode="$MatlabMode"
        ;;
    (PseudoTransmit)
        if [[ "$myelinCiftiAvg" == "" ]]
        then
            log_Err_Abort "$mode transmit correction mode requires --fmri-names and --average-myelin"
        fi
        "$scriptsdir"/PseudoTransmit_GroupAverageCorrectedMaps.sh \
            --study-folder="$StudyFolder" \
            --subject-list="$SubjectSTR" \
            --group-average-name="$GroupAverageName" \
            --voltages="$VoltagesFile" \
            --average-myelin="$myelinCiftiAvg" \
            --reg-name="$RegName" \
            --low-res-mesh="$LowResMesh" \
            --matlab-run-mode="$MatlabMode"
        ;;
    (*)
        log_Err_Abort "unrecognized transmit correction mode $mode"
        ;;
esac

