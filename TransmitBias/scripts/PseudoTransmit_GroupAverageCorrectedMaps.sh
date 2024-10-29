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

opts_SetScriptDescription "average final PseudoTransmit outputs"

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject-list' 'SubjectSTR' 'subject1@subject2...' "list of subjects separated by @"
opts_AddMandatory '--group-average-name' 'GroupAverageName' 'name' "output folder (e.g. S900)"
opts_AddMandatory '--average-myelin' 'myelinCiftiAvg' 'file' "cifti file of group average of receive-corrected myelin"
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

source "$HCPPIPEDIR"/TransmitBias/scripts/mergeavg.shlib

GoodSubjArray=()
GoodVoltageArray=()

StatsFile="$StudyFolder"/"$GroupAverageName"/MNINonLinear/PseudoTransmit_stats.txt
CSFStatsFile="$StudyFolder"/"$GroupAverageName"/MNINonLinear/PseudoTransmit_CSFStats.txt

rm -f "$StatsFile" "$CSFStatsFile"

#Expect Phase2 to have rejected a list containing bad subjects, don't recheck
for ((i = 0; i < ${#SubjArray[@]}; ++i))
do
    Subject="${SubjArray[$i]}"
    cat "$StudyFolder"/"$Subject"/MNINonLinear/PseudoTransmit_CSFStats.txt >> "$CSFStatsFile"
    cat "$StudyFolder"/"$Subject"/T1w/PseudoTransmit_stats.txt >> "$StatsFile"
done
avg_setSubjects "${SubjArray[@]}"
avg_setStudyFolder "$StudyFolder"

#second pass
ciftimergeavgsubj MNINonLinear/fsaverage_LR"$LowResMesh"k PseudoTransmitField_Norm"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$GroupAverageName".All.PseudoTransmitField_Norm"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$GroupAverageName".PseudoTransmitField_Norm"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii &

volmergeavg MNINonLinear/PseudoTransmitField_Norm_Atlas.nii.gz \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/"$GroupAverageName".All.PseudoTransmitField_Norm_Atlas.nii.gz \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/"$GroupAverageName".PseudoTransmitField_Norm_Atlas.nii.gz &

ciftimergeavgsubj MNINonLinear/fsaverage_LR"$LowResMesh"k rPseudoTransmitField_Norm"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$GroupAverageName".All.rPseudoTransmitField_Norm"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$GroupAverageName".rPseudoTransmitField_Norm"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii &

volmergeavg MNINonLinear/rPseudoTransmitField_Norm_Atlas.nii.gz \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/"$GroupAverageName".All.rPseudoTransmitField_Norm_Atlas.nii.gz \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/"$GroupAverageName".rPseudoTransmitField_Norm_Atlas.nii.gz &

volmergeavg MNINonLinear/PseudoTransmitField_Raw_Atlas.nii.gz \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/"$GroupAverageName".All.PseudoTransmitField_Raw_Atlas.dscalar.nii \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/"$GroupAverageName".PseudoTransmitField_Raw_Atlas.dscalar.nii &

volmergeavg MNINonLinear/T1wDividedByT2w_Atlas.nii.gz \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/"$GroupAverageName".All.T1wDividedByT2w_Atlas.dscalar.nii \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/"$GroupAverageName".T1wDividedByT2w_Atlas.nii.gz &

#NOTE: PseudoCorr -> IndPseudoCorr
ciftimergeavgsubj MNINonLinear/fsaverage_LR"$LowResMesh"k MyelinMap_PseudoCorr"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$GroupAverageName".All.MyelinMap_IndPseudoCorr"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$GroupAverageName".MyelinMap_IndPseudoCorr"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii &

volmergeavg MNINonLinear/T1wDividedByT2w_PseudoCorr_Atlas.nii.gz \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/"$GroupAverageName".All.T1wDividedByT2w_IndPseudoCorr_Atlas.nii.gz \
    "$StudyFolder"/"$GroupAverageName"/MNINonLinear/"$GroupAverageName".T1wDividedByT2w_IndPseudoCorr_Atlas.nii.gz &

wait

myelinAsymmOutFile="$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$GroupAverageName".MyelinMap_LRDIFF"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii
avgPTFieldFile="$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$GroupAverageName".PseudoTransmitField_Raw"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii
AvgPTFieldAsymmOutFile="$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$GroupAverageName".PseudoTransmitField_Raw_LRDIFF"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii
GCorrMyelinOutFile="$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$GroupAverageName".MyelinMap_GroupTFCorr"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii
GCorrMyelinAsymmOutFile="$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$GroupAverageName".MyelinMap_GroupTFCorr_LRDIFF"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii
AvgICorrMyelinFile="$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$GroupAverageName".MyelinMap_IndPseudoCorr"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii
ICorrMyelinAllFile="$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$GroupAverageName".All.MyelinMap_IndPseudoCorr"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii
AvgICorrMyelinAsymmOutFile="$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$GroupAverageName".MyelinMap_IndPseudoCorr_LRDIFF"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii
PTStatsFile="$StudyFolder"/"$GroupAverageName"/MNINonLinear/PseudoTransmit_stats.txt
rPTNormFile="$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$GroupAverageName".All.rPseudoTransmitField_Norm"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii
CSFStatsFile="$StudyFolder"/"$GroupAverageName"/MNINonLinear/PseudoTransmit_CSFStats.txt
RegCorrMyelinOutFile="$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$GroupAverageName".All.MyelinMap_IndPseudoCorr_Reg"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii
CovariatesOutFile="$StudyFolder"/"$GroupAverageName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/Covariates.csv

argvarlist=(myelinCiftiAvg myelinAsymmOutFile \
    avgPTFieldFile AvgPTFieldAsymmOutFile \
    GCorrMyelinOutFile GCorrMyelinAsymmOutFile \
    AvgICorrMyelinFile AvgICorrMyelinAsymmOutFile \
    ICorrMyelinAllFile VoltagesFile PTStatsFile rPTNormFile CSFStatsFile \
    RegCorrMyelinOutFile CovariatesOutFile)

case "$MatlabMode" in
    (0)
        arglist=()
        for var in "${argvarlist[@]}"
        do
            arglist+=("${!var}")
        done
        "$this_script_dir"/Compiled_PseudoTransmit_GroupAverageCorrectedMaps/run_PseudoTransmit_GroupAverageCorrectedMaps.sh "$MATLAB_COMPILER_RUNTIME" "${arglist[@]}"
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

        matlabcode+="PseudoTransmit_GroupAverageCorrectedMaps(${matlabargs});"
        
        echo "running matlab code: $matlabcode"
        "${matlab_interpreter[@]}" <<<"$matlabcode"
        echo
        ;;
esac

