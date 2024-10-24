#!/bin/bash
set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/tempfiles.shlib" "$@"

opts_SetScriptDescription "group average initial B1Tx outputs"

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject-list' 'SubjectSTR' 'subject1@subject2...' "list of subjects separated by @"
opts_AddMandatory '--group-average-name' 'GroupAverageName' 'name' "output folder (e.g. S900)"
opts_AddMandatory '--transmit-group-name' 'TransmitGroupName' 'name' "name for the subgroup of subjects that have good B1Tx data (e.g. Partial)"
opts_AddMandatory '--manual-receive' 'useRCfilesStr' 'TRUE or FALSE' "whether Phase1 used unprocessed scans to correct for not using PSN when acquiring scans"
opts_AddMandatory '--gmwm-template-out' 'GMWMtemplate' 'file' "output file for GM+WM volume ROI"
opts_AddMandatory '--average-myelin-out' 'myelinCiftiAvg' 'file' "output cifti file for group average of receive-corrected myelin"
opts_AddOptional '--all-myelin-out' 'myelinCiftiAll' 'file' "output cifti file for concatenated receive-corrected myelin"
opts_AddMandatory '--reg-name' 'RegName' 'string' "surface registration to use, like MSMAll"
opts_AddOptional '--low-res-mesh' 'LowResMesh' 'number' "resolution of grayordinates mesh, default '32'" '32'
opts_AddOptional '--grayordinates-res' 'lowvolres' 'number' "resolution of grayordinates to use, default '2'" '2'
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

this_script_dir=$(dirname "$0")

useRCfiles=$(opts_StringToBool "$useRCfilesStr")

IFS=' @' read -a SubjArray <<<"$SubjectSTR"

if [[ "$RegName" == "" || "$RegName" == "MSMSulc" ]]
then
    RegString=""
else
    RegString="_$RegName"
fi

case "$MatlabMode" in
    (0)
        if [[ "${MATLAB_COMPILER_RUNTIME:-}" == "" ]]
        then
            log_Err_Abort "To use compiled matlab, you must set and export the variable MATLAB_COMPILER_RUNTIME"
        fi
        log_Err_Abort "compiled matlab not implemented"
        ;;
    (1)
        matlab_interpreter=(matlab -nodisplay -nosplash)
        ;;
    (2)
        matlab_interpreter=(octave-cli -q --no-window-system)
        ;;
    (*)
        log_Err_Abort "unrecognized matlab mode '$MatlabMode', use 0, 1, or 2"
        ;;
esac

#allow this to work before doing a MakeAverageDataset, because why not
mkdir -p "${StudyFolder}/${GroupAverageName}/MNINonLinear/fsaverage_LR${LowResMesh}k"

#some naming conventions
phaseCiftiAvg="$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$TransmitGroupName".B1Tx_phase"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii

source "$HCPPIPEDIR"/TransmitBias/scripts/mergeavg.shlib

GoodSubjArray=()
for Subject in "${SubjArray[@]}"
do
    if [[ -f "$StudyFolder"/"$Subject"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$Subject".B1Tx_phase"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii ]]
    then
        GoodSubjArray+=("$Subject")
    fi
done
avg_setSubjects "${GoodSubjArray[@]}"
avg_setStudyFolder "$StudyFolder"

volmergeavg MNINonLinear/B1Tx_mag."$lowvolres".nii.gz \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/"$TransmitGroupName".All.B1Tx_mag."$lowvolres".nii.gz \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/"$TransmitGroupName".B1Tx_mag."$lowvolres".nii.gz &
volmergeavg MNINonLinear/B1Tx_phase."$lowvolres".nii.gz \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/"$TransmitGroupName".All.B1Tx_phase."$lowvolres".nii.gz \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/"$TransmitGroupName".B1Tx_phase."$lowvolres".nii.gz &

ciftimergeavgsubj MNINonLinear/fsaverage_LR"$LowResMesh"k B1Tx_phase"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$TransmitGroupName".All.B1Tx_phase"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii \
    "$phaseCiftiAvg" &

if [[ "$myelinCiftiAll" == "" ]]
then
    tempfiles_create TransmitBias_myelin_All_XXXXXX.dscalar.nii myelinCiftiAll
fi

#NOTE: _onlyRC is only in Phase1's $WorkingDIR
if ((useRCfiles))
then
    ciftimergeavgsubj TransmitBias MyelinMap_onlyRC"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii \
        "$myelinCiftiAll" \
        "$myelinCiftiAvg" &
else
    ciftimergeavgsubj MNINonLinear/fsaverage_LR"$LowResMesh"k MyelinMap"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii \
        "$myelinCiftiAll" \
        "$myelinCiftiAvg" &
fi

#GMWM template, to find agreement on gray matter
tempfiles_create GMWMmerge_XXXXXX.nii.gz gmwmtemp
tempfiles_add "$gmwmtemp"_avg.nii.gz
volmergeavg "MNINonLinear/GMWMTemplate.nii.gz" "$gmwmtemp" "$gmwmtemp"_avg.nii.gz &

wait

wb_command -volume-math 'x > 0.5' "$GMWMtemplate" -var x "$gmwmtemp"_avg.nii.gz

myelinAsymmOutFile="$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$TransmitGroupName".MyelinMap_LRDIFF"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii
phaseAsymmOutFile="$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$TransmitGroupName".B1Tx_phase_LRDIFF"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii
myelinCorrOutFile="$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$TransmitGroupName".MyelinMap_GroupCorr"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii
myelinCorrAsymmOutFile="$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$TransmitGroupName".MyelinMap_GroupCorr_LRDIFF"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii
fitParamsOutFile="$StudyFolder"/"$GroupAverageName"/MNINonLinear/"$TransmitGroupName".B1Tx_groupfit.txt

#B1Tx notes.m
case "$MatlabMode" in
    (0)
        log_Err_Abort "compiled matlab not yet implemented"
        ;;
    (1 | 2)
        mlcode="
            addpath('$HCPPIPEDIR/global/fsl/etc/matlab');
            addpath('$HCPCIFTIRWDIR');
            addpath('$HCPPIPEDIR/global/matlab');
            addpath('$this_script_dir');
            
            AvgMyelinFile = '$myelinCiftiAvg';
            myelinAsymmOutFile = '$myelinAsymmOutFile';
            phaseCiftiAvg = '$phaseCiftiAvg';
            phaseAsymmOutFile = '$phaseAsymmOutFile';
            myelinCorrOutFile = '$myelinCorrOutFile';
            myelinCorrAsymmOutFile = '$myelinCorrAsymmOutFile';
            fitParamsOutFile = '$fitParamsOutFile';
            
            B1Tx_GroupAverage(AvgMyelinFile, myelinAsymmOutFile, phaseCiftiAvg, phaseAsymmOutFile, myelinCorrOutFile, myelinCorrAsymmOutFile, fitParamsOutFile);"
        
        echo "running matlab code: $mlcode"
        "${matlab_interpreter[@]}" <<<"$mlcode"
        echo
        ;;
esac

