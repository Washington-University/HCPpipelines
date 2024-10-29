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

opts_SetScriptDescription "average final B1Tx outputs"

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject-list' 'SubjectSTR' 'subject1@subject2...' "list of subjects separated by @"
opts_AddMandatory '--group-average-name' 'GroupAverageName' 'name' "output folder (e.g. S900)"
#optional?
opts_AddMandatory '--transmit-group-name' 'TransmitGroupName' 'name' "name for the subgroup of subjects that have good B1Tx data (e.g. Partial)"
opts_AddMandatory '--reg-name' 'RegName' 'string' "surface registration to use, like MSMAll"
opts_AddOptional '--low-res-mesh' 'LowResMesh' 'number' "resolution of grayordinates mesh, default '32'" '32'
opts_AddMandatory '--voltages' 'VoltageFile' 'file' "text file of scanner calibrated transmit voltages for each subject"
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

source "$HCPPIPEDIR"/TransmitBias/scripts/mergeavg.shlib

GoodSubjArray=()
GoodVoltageArray=()

StatsFile="${StudyFolder}/${GroupAverageName}/MNINonLinear/B1Tx_stats.txt"
CSFStatsFile="${StudyFolder}/${GroupAverageName}/MNINonLinear/CSFStats.txt"
rm -f "$StatsFile" "$CSFStatsFile"

#read stops at newline, doesn't like empty string for line delimiter, mac doesn't have readarray/mapfile
read -a VoltageArray <<<"$(cat "$VoltageFile" | tr $'\n' ' ')"

i=0
for ((i = 0; i < ${#SubjArray[@]}; ++i))
do
    Subject="${SubjArray[$i]}"
    if [[ -f "$StudyFolder"/"$Subject"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$Subject".B1Tx_phase"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii ]]
    then
        GoodSubjArray+=("$Subject")
        GoodVoltageArray+=("${VoltageArray[$i]}")
        
        cat "${StudyFolder}/${Subject}/T1w/B1Tx_stats.txt" >> "$StatsFile"
        cat "${StudyFolder}/${Subject}/MNINonLinear/B1Tx_CSFStats.txt" >> "$CSFStatsFile"
    fi
    i=$((i + 1))
done

avg_setSubjects "${GoodSubjArray[@]}"
avg_setStudyFolder "$StudyFolder"

#naming conventions for things used in matlab
IndCorrMyelinAvgFile="$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$TransmitGroupName".MyelinMap_IndCorr"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii
IndCorrAllMyelinFile="$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$TransmitGroupName".All.MyelinMap_IndCorr"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii
SB1TxFile="$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$TransmitGroupName".All.rB1Tx"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii

ciftimergeavgsubj MNINonLinear/fsaverage_LR"$LowResMesh"k rB1Tx"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii \
    "$SB1TxFile" \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$TransmitGroupName".rB1Tx"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii

#NOTE: name change from _Corr to _IndCorr
ciftimergeavgsubj MNINonLinear/fsaverage_LR"$LowResMesh"k MyelinMap_Corr"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii \
    "$IndCorrAllMyelinFile" \
    "$IndCorrMyelinAvgFile"

#_Atlas volumes
volmergeavg MNINonLinear/B1Tx_phase_Atlas.nii.gz \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/"$TransmitGroupName".All.B1Tx_phase_Atlas.nii.gz \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/"$TransmitGroupName".B1Tx_phase_Atlas.nii.gz

volmergeavg MNINonLinear/rB1Tx_Atlas.nii.gz \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/"$TransmitGroupName".All.rB1Tx_Atlas.nii.gz \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/"$TransmitGroupName".rB1Tx_Atlas.nii.gz

volmergeavg MNINonLinear/T1wDividedByT2w_Atlas.nii.gz \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/"$TransmitGroupName".All.T1wDividedByT2w_Atlas.nii.gz \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/"$TransmitGroupName".T1wDividedByT2w_Atlas.nii.gz

volmergeavg MNINonLinear/T1wDividedByT2w_Corr_Atlas.nii.gz \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/"$TransmitGroupName".All.T1wDividedByT2w_IndCorr_Atlas.nii.gz \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/"$TransmitGroupName".T1wDividedByT2w_IndCorr_Atlas.nii.gz

#apply slope/intercept to myelin _Atlas volume (because _Atlas files weren't available until now)
read slope intercept < "$StudyFolder"/"$GroupAverageName"/MNINonLinear/"$TransmitGroupName".B1Tx_groupfit.txt
wb_command -volume-math "myelin / (b1tx * $slope + $intercept)" "$StudyFolder"/"$GroupAverageName"/MNINonLinear/"$TransmitGroupName".T1wDividedByT2w_GroupCorr_Atlas.dscalar.nii -fixnan 0 \
    -var myelin "$StudyFolder"/"$GroupAverageName"/MNINonLinear/"$TransmitGroupName".T1wDividedByT2w_Atlas.nii.gz \
    -var b1tx "$StudyFolder"/"$GroupAverageName"/MNINonLinear/"$TransmitGroupName".B1Tx_phase_Atlas.nii.gz

#matlab output naming
IndCorrMyelinAsymmOutFile="$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$TransmitGroupName".MyelinMap_IndCorr_LRDIFF."$LowResMesh"k_fs_LR.dscalar.nii
CovariatesOutFile="${StudyFolder}/${GroupAverageName}/MNINonLinear/fsaverage_LR${LowResMesh}k/Covariates.csv"
RegressedMyelinOutFile="${StudyFolder}/${GroupAverageName}/MNINonLinear/fsaverage_LR${LowResMesh}k/${TransmitGroupName}.All.MyelinMap_IndCorr_Reg${RegString}.${LowResMesh}k_fs_LR.dscalar.nii"

tempfiles_create transmit_goodvoltages_XXXXXX.txt GoodVoltagesFile
(IFS=$'\n'; echo "${GoodVoltageArray[*]}") > "$GoodVoltagesFile"

argvarlist=(IndCorrMyelinAvgFile IndCorrMyelinAsymmOutFile \
    IndCorrAllMyelinFile GoodVoltagesFile SB1TxFile StatsFile CSFStatsFile \
    RegressedMyelinOutFile CovariatesOutFile)

case "$MatlabMode" in
    (0)
        arglist=()
        for var in "${argvarlist[@]}"
        do
            arglist+=("${!var}")
        done
        "$this_script_dir"/Compiled_B1Tx_GroupAverageCorrectedMaps/run_B1Tx_GroupAverageCorrectedMaps.sh "$MATLAB_COMPILER_RUNTIME" "${arglist[@]}"
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

        matlabcode+="B1Tx_GroupAverageCorrectedMaps(${matlabargs});"
        
        echo "running matlab code: $matlabcode"
        "${matlab_interpreter[@]}" <<<"$matlabcode"
        echo
        ;;
esac

