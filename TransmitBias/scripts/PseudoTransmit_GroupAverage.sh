#!/bin/bash
set -euE

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/tempfiles.shlib" "$@"

opts_SetScriptDescription "group average initial pseudotransmit correction and find the group reference value"

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject-list' 'SubjectSTR' 'subject1@subject2...' "list of subjects separated by @"
opts_AddMandatory '--group-average-name' 'GroupAverageName' 'name' "output folder (e.g. S900)"
opts_AddMandatory '--manual-receive' 'useRCfilesStr' 'TRUE or FALSE' "whether Phase1 used unprocessed scans to correct for not using PSN when acquiring scans"
opts_AddMandatory '--reference-value-out' 'ReferenceValOutFile' 'file' "output text file for PseudoTransmit reference value"
opts_AddMandatory '--gmwm-template-out' 'GMWMtemplate' 'file' "output file for GM+WM volume ROI"
opts_AddMandatory '--average-myelin-out' 'myelinCiftiAvg' 'file' "output cifti file for group average of receive-corrected myelin"
opts_AddOptional '--all-myelin-out' 'myelinCiftiAll' 'file' "output cifti file for concatenated receive-corrected myelin"
opts_AddMandatory '--reg-name' 'RegName' 'string' "surface registration to use, like MSMAll"
opts_AddOptional '--low-res-mesh' 'LowResMesh' 'number' "resolution of grayordinates mesh, default '32'" '32'
opts_AddOptional '--grayordinates-res' 'lowvolres' 'number' "resolution of grayordinates to use, default '2'" '2'
opts_AddOptional '--matlab-run-mode' 'MatlabMode' '0, 1, or 2' "defaults to 0
0 = compiled MATLAB
1 = interpreted MATLAB
2 = Octave" '0'

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

useRCfiles=$(opts_StringToBool "$useRCfilesStr")

case "$MatlabMode" in
    (0)
        if [[ "${MATLAB_COMPILER_RUNTIME:-}" == "" ]]
        then
            log_Err_Abort "To use compiled matlab, you must set and export the variable MATLAB_COMPILER_RUNTIME"
        fi
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

this_script_dir=$(dirname -- "$0")

IFS=' @' read -a SubjArray <<<"$SubjectSTR"

if [[ "$RegName" == "" || "$RegName" == "MSMSulc" ]]
then
    RegString=""
else
    RegString="_$RegName"
fi

source "$HCPPIPEDIR"/TransmitBias/scripts/mergeavg.shlib

for Subject in "${SubjArray[@]}"
do
    #original code doesn't have a separate group name for the good subjects (AFI used "Partial"), so it isn't clear what to do
    #so, probably error for any bad subject as long as Patial. isn't supported
    if [[ ! -f "$StudyFolder"/"$Subject"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$Subject".PseudoTransmitField_Raw"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii ]]
    then
        log_Err_Abort "subject $Subject does not appear to have completed Phase1 for PseudoTransmit"
    fi
done
avg_setSubjects "${SubjArray[@]}"
avg_setStudyFolder "$StudyFolder"

mkdir -p "$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k

tempfiles_create GMWMmerge_XXXXXX.nii.gz gmwmtemp
tempfiles_add "$gmwmtemp"_avg.nii.gz
volmergeavg "MNINonLinear/GMWMTemplate.nii.gz" "$gmwmtemp" "$gmwmtemp"_avg.nii.gz
wb_command -volume-math 'x > 0.5' "$GMWMtemplate" -var x "$gmwmtemp"_avg.nii.gz

volmergeavg MNINonLinear/PseudoTransmitField_Raw."$lowvolres".nii.gz \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/"$GroupAverageName".All.PseudoTransmitField_Raw."$lowvolres".nii.gz \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/"$GroupAverageName".PseudoTransmitField_Raw."$lowvolres".nii.gz &

ciftimergeavgsubjnooutliers MNINonLinear/fsaverage_LR"$LowResMesh"k PseudoTransmitField_Raw"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$GroupAverageName".All.PseudoTransmitField_Raw"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$GroupAverageName".PseudoTransmitField_Raw"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii &

if [[ "$myelinCiftiAll" == "" ]]
then
    tempfiles_create TransmitBias_myelin_All_XXXXXX.dscalar.nii myelinCiftiAll
fi

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

wait

avgPTFieldFile="$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$GroupAverageName".PseudoTransmitField_Raw"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii

argvarlist=(myelinCiftiAvg avgPTFieldFile ReferenceValOutFile)

case "$MatlabMode" in
    (0)
        arglist=()
        for var in "${argvarlist[@]}"
        do
            arglist+=("${!var}")
        done
        "$this_script_dir"/Compiled_PseudoTransmit_GroupAverage/run_PseudoTransmit_GroupAverage.sh "$MATLAB_COMPILER_RUNTIME" "${arglist[@]}"
        ;;
    (1 | 2)
        matlabargs=""
        matlabcode="
        addpath('$HCPPIPEDIR/global/fsl/etc/matlab');
        addpath('$HCPCIFTIRWDIR');
        addpath('$HCPPIPEDIR/global/matlab');
        addpath('$this_script_dir');
        "
        for var in "${argvarlist[@]}"
        do
            #NOTE: the newline before the closing quote is important, to avoid the 4KB stdin line limit
            matlabcode+="$var = '${!var}';
            "
            
            if [[ "$matlabargs" != "" ]]; then matlabargs+=", "; fi
            matlabargs+="$var"
        done

        matlabcode+="PseudoTransmit_GroupAverage(${matlabargs});"
        
        echo "running matlab code: $matlabcode"
        "${matlab_interpreter[@]}" <<<"$matlabcode"
        echo
        ;;
esac

