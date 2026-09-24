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

opts_SetScriptDescription "classifies tICA components as signal or noise using a trained model, writing Noise.txt for CleanData"

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--out-group-name' 'GroupAverageName' 'string' 'name to use for the group output folder'
opts_AddMandatory '--fmri-output-name' 'OutputfMRIName' 'string' "name for the output fMRI data, like 'rfMRI_REST_7T'"
opts_AddMandatory '--ica-dim' 'tICAdim' 'integer' "number of temporal ICA components"
opts_AddOptional '--singularity-image' 'PythonSingularity' 'string' "the file path of the classifier singularity container, instead of using native python" ""
opts_AddOptional '--singularity-mount-path' 'PythonSingularityMountPath' 'string' "the --bind argument to get the data mounted into singularity" ""
opts_AddOptional '--python-interpreter' 'PythonInterpreter' 'string' "the python executable, default 'python3' (from PATH)" "python3"
opts_AddOptional '--model-folder' 'ModelFolder' 'string' "folder containing the converted .onnx tICA classifier models" "$HCPPIPEDIR/tICA/classify_models"
opts_AddOptional '--keep-features-json' 'KeepFeaturesJson' 'string' "feature column config used at training time" "$HCPPIPEDIR/global/config/tICA/keep_features_v1.json"
opts_AddOptional '--threshold' 'Threshold' 'number' "decision threshold for signal vs noise" "0.5"
opts_AddOptional '--noise-file-name' 'NoiseFileName' 'string' "output file name (within the tICA_d<dim> folder) for the noise component list, defaults to Noise.txt -- override for testing so you don't overwrite the file CleanData expects" "Noise.txt"

opts_ParseArguments "$@"

opts_ShowValues

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

if [[ "$PythonSingularity" != "" ]]; then
    if [[ ! -f "$PythonSingularity" ]]; then
        log_Err_Abort "the singularity container doesn't exist: $PythonSingularity"
    fi
    if ! command -v singularity &> /dev/null; then
        log_Err_Abort "Singularity is not installed or not in PATH."
    fi
    bindArgs=()
    if [[ "$PythonSingularityMountPath" != "" ]]; then
        bindArgs=(--bind "$PythonSingularityMountPath")
    fi
    PythonCmd=(singularity exec "${bindArgs[@]+"${bindArgs[@]}"}" "$PythonSingularity" python3)
else
    if ! command -v "$PythonInterpreter" &> /dev/null; then
        log_Err_Abort "python interpreter not found: $PythonInterpreter"
    fi
    PythonCmd=("$PythonInterpreter")
fi

OutputFolder="$StudyFolder/$GroupAverageName/MNINonLinear/Results/$OutputfMRIName/tICA_d$tICAdim"
FeaturesCsv="$OutputFolder/features.csv"
NoiseFile="$OutputFolder/$NoiseFileName"
ProbaCsv="$OutputFolder/tICAClassify_prediction_proba.csv"

if [[ ! -e "$FeaturesCsv" ]]; then
    log_Err_Abort "$FeaturesCsv doesn't exist, make sure ComputeTICAFeatures has been run for this group"
fi

this_script_dir=$(dirname "$0")
pythonCode=(
    "$this_script_dir/TICAClassifierInference.py"
    --input_csv="$FeaturesCsv"
    --keep_features_json="$KeepFeaturesJson"
    --model_folder="$ModelFolder"
    --threshold="$Threshold"
    --output_noise_file="$NoiseFile"
    --output_proba_csv="$ProbaCsv"
)

PythonLaunchCommand=("${PythonCmd[@]}" "${pythonCode[@]}")

log_Msg "Run tICA classification..."
log_Msg "${PythonLaunchCommand[@]}"
"${PythonLaunchCommand[@]}"

log_Msg "wrote $NoiseFile"
