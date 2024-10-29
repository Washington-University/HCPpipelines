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

opts_SetScriptDescription "group average initial AFI outputs"

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject-list' 'SubjectSTR' 'subject1@subject2...' "list of subjects separated by @"
opts_AddMandatory '--group-average-name' 'GroupAverageName' 'name' "output folder (e.g. S900)"
opts_AddMandatory '--transmit-group-name' 'TransmitGroupName' 'name' "name for the subgroup of subjects that have good AFI data (e.g. Partial)"
opts_AddMandatory '--manual-receive' 'useRCfilesStr' 'TRUE or FALSE' "whether Phase1 used unprocessed scans to correct for not using PSN when acquiring scans"
opts_AddMandatory '--gmwm-template-out' 'GMWMtemplate' 'file' "output file for GM+WM volume ROI"
opts_AddMandatory '--afi-tr-one' 'TRone' 'number' "TR of first AFI frame"
opts_AddMandatory '--afi-tr-two' 'TRtwo' 'number' "TR of second AFI frame"
opts_AddMandatory '--target-flip-angle' 'TargetFlipAngle' 'number' "the target flip angle of the AFI sequence"
opts_AddMandatory '--average-myelin-out' 'myelinavg' 'file' "output cifti file for group average of receive-corrected myelin"
opts_AddOptional '--all-myelin-out' 'myelinall' 'file' "output cifti file for concatenated receive-corrected myelin"
opts_AddMandatory '--reg-name' 'RegName' 'string' "surface registration to use, like MSMAll"
opts_AddMandatory '--low-res-mesh' 'LowResMesh' 'number' "resolution of grayordinates mesh"
opts_AddMandatory '--grayordinates-res' 'lowvolres' 'number' "resolution of grayordinates to use"
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

GroupAtlasFolder="$StudyFolder"/"$GroupAverageName"/MNINonLinear

#allow this to work before doing a MakeAverageDataset, because why not
mkdir -p "$GroupAtlasFolder"/fsaverage_LR"$LowResMesh"k

source "$HCPPIPEDIR"/TransmitBias/scripts/mergeavg.shlib

AFIOrigCIFTIAvg=()
GoodSubjArray=()

for Subject in "${SubjArray[@]}"
do
    #check the _orig cifti version, since we are going to use it in the -cifti-average
    if [[ -f "$StudyFolder"/"$Subject"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$Subject".AFI_orig"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii ]]
    then
        GoodSubjArray+=("$Subject")
        AFIOrigCIFTIAvg+=(-cifti "$StudyFolder"/"$Subject"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$Subject".AFI_orig"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii)
    fi
done
avg_setSubjects "${GoodSubjArray[@]}"
avg_setStudyFolder "$StudyFolder"

#NOTE: NOT merge/reduce, because 2 maps
wb_command -cifti-average "${GroupAtlasFolder}/fsaverage_LR${LowResMesh}k/${TransmitGroupName}.AFI_orig${RegString}.${LowResMesh}k_fs_LR.dscalar.nii" "${AFIOrigCIFTIAvg[@]}" -cifti-read-memory &
#_Atlas versions are done in phase 4

#some filename conventions
AvgFlipFile="${GroupAtlasFolder}/fsaverage_LR${LowResMesh}k/${TransmitGroupName}.AFI_FlipAngle${RegString}.${LowResMesh}k_fs_LR.dscalar.nii"

#outputs from matlab code
MyelinAsymmOutFile="${GroupAtlasFolder}/fsaverage_LR${LowResMesh}k/${TransmitGroupName}.MyelinMap_LRDIFF${RegString}.${LowResMesh}k_fs_LR.dscalar.nii"
FlipAsymmOutFile="${GroupAtlasFolder}/fsaverage_LR${LowResMesh}k/${TransmitGroupName}.AFI_orig_LRDIFF${RegString}.${LowResMesh}k_fs_LR.dscalar.nii"

MyelinCorrOutFile="${GroupAtlasFolder}/fsaverage_LR${LowResMesh}k/${TransmitGroupName}.MyelinMap_GroupCorr${RegString}.${LowResMesh}k_fs_LR.dscalar.nii"
MyelinCorrAsymOutFile="${GroupAtlasFolder}/fsaverage_LR${LowResMesh}k/${TransmitGroupName}.MyelinMap_GroupCorr_LRDIFF${RegString}.${LowResMesh}k_fs_LR.dscalar.nii"
fitParamsOutFile="${GroupAtlasFolder}/${TransmitGroupName}.AFI_groupfit.txt"

#GMWM template, to find agreement on gray matter
tempfiles_create GMWMmerge_XXXXXX.nii.gz gmwmtemp
tempfiles_add "$gmwmtemp"_avg.nii.gz
volmergeavg "MNINonLinear/GMWMTemplate.nii.gz" "$gmwmtemp" "$gmwmtemp"_avg.nii.gz
wb_command -volume-math 'x > 0.5' "$GMWMtemplate" -var x "$gmwmtemp"_avg.nii.gz

if [[ "$myelinall" == "" ]]
then
    tempfiles_create TransmitBias_myelin_All_XXXXXX.dscalar.nii myelinall
fi

if ((useRCfiles))
then
    ciftimergeavgsubj "TransmitBias" "MyelinMap_onlyRC${RegString}.${LowResMesh}k_fs_LR.dscalar.nii" \
        "$myelinall" \
        "$myelinavg" &
else
    ciftimergeavgsubj "MNINonLinear/fsaverage_LR${LowResMesh}k" "MyelinMap${RegString}.${LowResMesh}k_fs_LR.dscalar.nii" \
        "$myelinall" \
        "$myelinavg" &
fi

volmergeavg "MNINonLinear/AFI_orig.$lowvolres.nii.gz" \
    "${GroupAtlasFolder}/${TransmitGroupName}.All.AFI_orig1.nii.gz" \
    "${GroupAtlasFolder}/${TransmitGroupName}.AFI_orig1.nii.gz" -subvolume 1 &
volmergeavg "MNINonLinear/AFI_orig.$lowvolres.nii.gz" \
    "${GroupAtlasFolder}/${TransmitGroupName}.All.AFI_orig2.nii.gz" \
    "${GroupAtlasFolder}/${TransmitGroupName}.AFI_orig2.nii.gz" -subvolume 2 &

ciftimergeavgsubj MNINonLinear/fsaverage_LR"$LowResMesh"k AFI"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii \
    "$GroupAtlasFolder"/fsaverage_LR"$LowResMesh"k/"$TransmitGroupName".All.AFI"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii \
    "$GroupAtlasFolder"/fsaverage_LR"$LowResMesh"k/"$TransmitGroupName".AFI"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii &

wait

wb_command -cifti-math "180 / PI * acos(($TRtwo / $TRone * frametwo / frameone - 1) / ($TRtwo / $TRone - frametwo / frameone))" "$AvgFlipFile" -var frameone "${GroupAtlasFolder}/fsaverage_LR${LowResMesh}k/${TransmitGroupName}.AFI_orig${RegString}.${LowResMesh}k_fs_LR.dscalar.nii" -select 1 1 -var frametwo "${GroupAtlasFolder}/fsaverage_LR${LowResMesh}k/${TransmitGroupName}.AFI_orig${RegString}.${LowResMesh}k_fs_LR.dscalar.nii" -select 1 2

wb_command -volume-math "180 / PI * acos(($TRtwo / $TRone * frametwo / frameone - 1) / ($TRtwo / $TRone - frametwo / frameone))" "${GroupAtlasFolder}/${TransmitGroupName}.AFI_orig.nii.gz" \
    -var frameone "${GroupAtlasFolder}/${TransmitGroupName}.AFI_orig1.nii.gz" \
    -var frametwo "${GroupAtlasFolder}/${TransmitGroupName}.AFI_orig2.nii.gz"

argvarlist=(myelinavg MyelinAsymmOutFile \
    AvgFlipFile TargetFlipAngle FlipAsymmOutFile \
    MyelinCorrOutFile MyelinCorrAsymOutFile \
    fitParamsOutFile)

case "$MatlabMode" in
    (0)
        arglist=()
        for var in "${argvarlist[@]}"
        do
            arglist+=("${!var}")
        done
        "$this_script_dir"/Compiled_AFI_GroupAverage/run_AFI_GroupAverage.sh "$MATLAB_COMPILER_RUNTIME" "${arglist[@]}"
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

        matlabcode+="AFI_GroupAverage(${matlabargs});"
        
        echo "running matlab code: $matlabcode"
        "${matlab_interpreter[@]}" <<<"$matlabcode"
        echo
        ;;
esac

