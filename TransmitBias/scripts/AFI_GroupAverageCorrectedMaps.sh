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

opts_SetScriptDescription "average final AFI outputs"

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject-list' 'SubjectSTR' 'subject1@subject2...' "list of subjects separated by @"
opts_AddMandatory '--group-average-name' 'GroupAverageName' 'name' "output folder (e.g. S900)"
opts_AddMandatory '--transmit-group-name' 'TransmitGroupName' 'name' "name for the subgroup of subjects that have good AFI data (e.g. Partial)"
opts_AddMandatory '--afi-tr-one' 'TRone' 'number' "TR of first AFI frame"
opts_AddMandatory '--afi-tr-two' 'TRtwo' 'number' "TR of second AFI frame"
opts_AddMandatory '--target-flip-angle' 'TargetFlipAngle' 'number' "the target flip angle of the AFI sequence"
opts_AddMandatory '--reg-name' 'RegName' 'string' "surface registration to use, like MSMAll"
opts_AddMandatory '--low-res-mesh' 'LowResMesh' 'number' "resolution for cifti mesh, like 32"
opts_AddMandatory '--voltages' 'VoltagesFile' 'file' "text file of scanner calibrated transmit voltages for each subject"
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

source "$HCPPIPEDIR"/TransmitBias/scripts/mergeavg.shlib

GoodSubjArray=()
GoodVoltagesArray=()

StatsFile="${GroupAtlasFolder}/AFI_stats.txt"
CSFStatsFile="${GroupAtlasFolder}/AFI_CSFStats.txt"

rm -f "$StatsFile" "$CSFStatsFile"

#read stops at newline, doesn't like empty string for line delimiter, mac doesn't have readarray/mapfile
read -a VoltagesArray <<<"$(cat "$VoltagesFile" | tr $'\n' ' ')"

for ((i = 0; i < ${#SubjArray[@]}; ++i))
do
    Subject="${SubjArray[$i]}"
    #test the same file as the first group average script
    if [[ -f "${StudyFolder}/${Subject}/MNINonLinear/fsaverage_LR${LowResMesh}k/${Subject}.AFI_orig${RegString}.${LowResMesh}k_fs_LR.dscalar.nii" ]]
    then
        GoodSubjArray+=("$Subject")
        GoodVoltagesArray+=("${VoltagesArray[$i]}")
        
        cat "${StudyFolder}/${Subject}/T1w/AFI_stats.txt" >> "$StatsFile"
        cat "${StudyFolder}/${Subject}/MNINonLinear/AFI_CSFStats.txt" >> "$CSFStatsFile"
    fi
done
avg_setSubjects "${GoodSubjArray[@]}"
avg_setStudyFolder "$StudyFolder"

#some filename conventions
AvgMyelinVolFile="${GroupAtlasFolder}/${TransmitGroupName}.T1wDividedByT2w_Atlas.nii.gz"
AvgReceiveCorrVolFile="${GroupAtlasFolder}/${TransmitGroupName}.ReceiveFieldCorrection_Atlas.nii.gz"
AvgFlipVolFile="${GroupAtlasFolder}/${TransmitGroupName}.AFI_FlipAngle_Atlas.nii.gz"
MyelinVolCorrOutFile="${GroupAtlasFolder}/${TransmitGroupName}.T1wDividedByT2w_GroupCorr_Atlas.nii.gz"
fitParamsFile="${GroupAtlasFolder}/${TransmitGroupName}.AFI_groupfit.txt"
AvgIndCorrMyelin="${GroupAtlasFolder}/fsaverage_LR${LowResMesh}k/${TransmitGroupName}.MyelinMap_IndCorr${RegString}.${LowResMesh}k_fs_LR.dscalar.nii"
IndCorrMyelinAll="${GroupAtlasFolder}/fsaverage_LR${LowResMesh}k/${TransmitGroupName}.All.MyelinMap_IndCorr${RegString}.${LowResMesh}k_fs_LR.dscalar.nii"
rAFI="${GroupAtlasFolder}/fsaverage_LR${LowResMesh}k/${TransmitGroupName}.All.rAFI${RegString}.${LowResMesh}k_fs_LR.dscalar.nii"

tempfiles_create AFImerge_XXXXXX.nii.gz afimergetemp
tempfiles_add "$afimergetemp"_2.nii.gz "$afimergetemp"_3.nii.gz "$afimergetemp"_4.nii.gz
#extra arguments on the end are added per-file
volmergeavg "MNINonLinear/AFI_orig_Atlas.nii.gz" "$afimergetemp" "$afimergetemp"_3.nii.gz -subvolume 1 &
volmergeavg "MNINonLinear/AFI_orig_Atlas.nii.gz" "$afimergetemp"_2.nii.gz "$afimergetemp"_4.nii.gz -subvolume 2 &

volmergeavg "MNINonLinear/T1wDividedByT2w_Atlas.nii.gz" \
    "${GroupAtlasFolder}/${TransmitGroupName}.All.T1wDividedByT2w_Atlas.nii.gz" \
    "$AvgMyelinVolFile" &

volmergeavg "MNINonLinear/AFI_Atlas.nii.gz" \
    "${GroupAtlasFolder}/${TransmitGroupName}.All.AFI_Atlas.nii.gz" \
    "${GroupAtlasFolder}/${TransmitGroupName}.AFI_Atlas.nii.gz" &

ciftimergeavgsubj "MNINonLinear/fsaverage_LR${LowResMesh}k" "rAFI${RegString}.${LowResMesh}k_fs_LR.dscalar.nii" \
    "$rAFI" \
    "${GroupAtlasFolder}/fsaverage_LR${LowResMesh}k/${TransmitGroupName}.rAFI${RegString}.${LowResMesh}k_fs_LR.dscalar.nii" &

volmergeavg "MNINonLinear/rAFI_Atlas.nii.gz" \
    "${GroupAtlasFolder}/${TransmitGroupName}.All.rAFI_Atlas.nii.gz" \
    "${GroupAtlasFolder}/${TransmitGroupName}.rAFI_Atlas.nii.gz" &

ciftimergeavgsubj "MNINonLinear/fsaverage_LR${LowResMesh}k" "MyelinMap_Corr${RegString}.${LowResMesh}k_fs_LR.dscalar.nii" \
    "$IndCorrMyelinAll" \
    "$AvgIndCorrMyelin" &

volmergeavg "MNINonLinear/T1wDividedByT2w_Corr_Atlas.nii.gz" \
    "${GroupAtlasFolder}/${TransmitGroupName}.All.T1wDividedByT2w_IndCorr_Atlas.nii.gz" \
    "${GroupAtlasFolder}/${TransmitGroupName}.T1wDividedByT2w_IndCorr_Atlas.nii.gz" &

wait

wb_command -volume-merge "${GroupAtlasFolder}/${TransmitGroupName}.AFI_orig_Atlas.nii.gz" \
    -volume "$afimergetemp"_3.nii.gz \
    -volume "$afimergetemp"_4.nii.gz

wb_command -volume-math "180 / PI * acos(($TRtwo / $TRone * frametwo / frameone - 1) / ($TRtwo / $TRone - frametwo / frameone))" "$AvgFlipVolFile" \
    -var frameone "${GroupAtlasFolder}/${TransmitGroupName}.AFI_orig_Atlas.nii.gz" -subvolume 1 \
    -var frametwo "${GroupAtlasFolder}/${TransmitGroupName}.AFI_orig_Atlas.nii.gz" -subvolume 2

#individual T1wDivT2w file already has receive correction
#do the _Atlas group myelin correction math
read slope intercept < "$fitParamsFile"
wb_command -volume-math "myelin / (afi / $TargetFlipAngle * $slope + $intercept)" "$MyelinVolCorrOutFile" \
    -var myelin "$AvgMyelinVolFile" \
    -var afi "$AvgFlipVolFile"

#matlab output filenames
AvgIndCorrMyelinAsymmOut="${GroupAtlasFolder}/fsaverage_LR${LowResMesh}k/${TransmitGroupName}.MyelinMap_IndCorr_LRDIFF${RegString}.${LowResMesh}k_fs_LR.dscalar.nii"
CovariatesOut="${GroupAtlasFolder}/fsaverage_LR${LowResMesh}k/Covariates.csv"
RegressedMyelinOutFile="${GroupAtlasFolder}/fsaverage_LR${LowResMesh}k/${TransmitGroupName}.All.MyelinMap_IndCorr_Reg${RegString}.${LowResMesh}k_fs_LR.dscalar.nii"

tempfiles_create transmit_goodvoltages_XXXXXX.txt GoodVoltagesFile
(IFS=$'\n'; echo "${GoodVoltagesArray[*]}") > "$GoodVoltagesFile"

argvarlist=(AvgIndCorrMyelin AvgIndCorrMyelinAsymmOut \
    IndCorrMyelinAll GoodVoltagesFile rAFI StatsFile CSFStatsFile \
    RegressedMyelinOutFile CovariatesOut)

case "$MatlabMode" in
    (0)
        arglist=()
        for var in "${argvarlist[@]}"
        do
            arglist+=("${!var}")
        done
        "$this_script_dir"/Compiled_AFI_GroupAverageCorrectedMaps/run_AFI_GroupAverageCorrectedMaps.sh "$MATLAB_COMPILER_RUNTIME" "${arglist[@]}"
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

        matlabcode+="AFI_GroupAverageCorrectedMaps(${matlabargs});"
        
        echo "running matlab code: $matlabcode"
        "${matlab_interpreter[@]}" <<<"$matlabcode"
        echo
        ;;
esac

