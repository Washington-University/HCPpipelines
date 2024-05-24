#!/bin/bash
set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/tempfiles.shlib" "$@"
g_matlab_default_mode=1

#description to use in usage - syntax of parameters is now explained automatically
opts_SetScriptDescription "the spatial ICA reclean pipeline (per subject)"

#mandatory (mrfix name must be specified if applicable, so including it here despite being mechanically optional)
#general inputs
opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder that contains all subjects"
opts_AddMandatory '--subject' 'Subject' '100206' "one subject ID"
opts_AddMandatory '--fmri-names' 'fMRINames' 'rfMRI_REST1_LR@rfMRI_REST1_RL...' "list of fmri run names separated by @s" #Needs to be the single fMRI run names only (for DVARS and GS code) for MR+FIX, is also the SR+FIX input names
opts_AddOptional '--mrfix-concat-name' 'MRFixConcatName' 'rfMRI_REST' "if multi-run FIX was used, you must specify the concat name with this option"
opts_AddMandatory '--fix-high-pass' 'HighPass' 'integer' 'the high pass value that was used when running FIX' '--melodic-high-pass'
opts_AddMandatory '--fmri-resolution' 'fMRIResolution' 'string' "resolution of data, like '2' or '1.60'"
opts_AddMandatory '--subject-expected-timepoints' 'subjectExpectedTimepoints' 'string' "output spectra size for sICA individual projection, RunsXNumTimePoints, like '4800'"
opts_AddConfigMandatory '--low-res' 'LowResMesh' 'LowResMesh' 'meshnum' "mesh resolution, like '32' for 32k_fs_LR"
opts_AddOptional '--python-singularity' 'PythonSingularity' 'string' "the file path of the singularity, specify empty string to use native environment instead" ""
opts_AddOptional '--python-singularity-mount-path' 'PythonSingularityMountPath' 'string' "the file path of the mount path for singularity" ""
opts_AddOptional '--python-interpreter' 'PythonInterpreter' 'string' "the python interpreter path" ""
opts_AddOptional '--model-folder' 'ModelFolder' 'string' "the folder path of the trained models" "$HCPPIPEDIR/ICAFIX/rclean_models"
opts_AddOptional '--model-to-use' 'ModelToUse' 'string' "the models to use separated by '@'" "RandomForest@MLP"
opts_AddOptional '--vote-threshold' 'VoteThresh' 'integer' "a decision threshold for determing reclassifications, should be less than to equal to the number of models to use" ""
opts_AddOptional '--matlab-run-mode' 'MatlabMode' '0, 1, or 2' "defaults to $g_matlab_default_mode

0 = compiled MATLAB
1 = interpreted MATLAB
2 = Octave" "$g_matlab_default_mode"
opts_ParseArguments "$@"

#display the parsed/default values
opts_ShowValues

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

case "$MatlabMode" in
    (0)
        if [[ "${MATLAB_COMPILER_RUNTIME:-}" == "" ]]
        then
            log_Err_Abort "to use compiled matlab, you must set and export the variable MATLAB_COMPILER_RUNTIME"
        fi
        ;;
    (1)
        #NOTE: figure() is required by the spectra option, and -nojvm prevents using figure()
        matlab_interpreter=(matlab -nodisplay -nosplash)
        ;;
    (2)
        matlab_interpreter=(octave-cli -q --no-window-system)
        ;;
    (*)
        log_Err_Abort "unrecognized matlab mode '$MatlabMode', use 0, 1, or 2"
        ;;
esac

ReclassifyAsSignalFile="ReclassifyAsSignalRecleanVote${VoteThresh}.txt"
ReclassifyAsNoiseFile="ReclassifyAsNoiseRecleanVote${VoteThresh}.txt"

# compute addtional features, inference by new base learners, produce reclassify files
log_Msg "Begin to run the reclean pipeline..."
"$HCPPIPEDIR"/ICAFIX/scripts/RecleanClassify.sh \
    --study-folder="$StudyFolder" \
    --subject="$Subject" \
    --fmri-names="$fMRINames" \
    --mrfix-concat-name="$MRFixConcatName" \
    --fix-high-pass="$HighPass" \
    --fmri-resolution="$fMRIResolution" \
    --subject-expected-timepoints="$subjectExpectedTimepoints" \
    --surf-reg-name="MSMAll" \
    --low-res="${LowResMesh}" \
    --python-singularity="${PythonSingularity}" \
    --python-singularity-mount-path="${PythonSingularityMountPath}" \
    --python-interpreter="${PythonInterpreter}" \
    --model-to-use="$ModelToUse" \
    --vote-threshold="$VoteThresh" \
    --reclassify-as-signal-file="$ReclassifyAsSignalFile" \
    --reclassify-as-noise-file="$ReclassifyAsNoiseFile" \
    --matlab-run-mode="$MatlabMode"

IFS='@' read -a fMRINamesArray <<<"$fMRINames"

# reapply fix
log_Msg "Begin to reapply FIX..."

# default params
# motion regression or not
MotionReg=FALSE

# clean up intermediates
DeleteIntermediates=FALSE

# reapply fix main processing + add rclean substring
if [ -z ${MRFixConcatName} ]; then
    # Single Run
    for fMRIName in "${fMRINamesArray[@]}"; do

        # apply the reclassification results
        "$HCPPIPEDIR"/ICAFIX/ApplyHandReClassifications.sh \
        --study-folder="$StudyFolder" \
        --subject="$Subject" \
        --fmri-name="$fMRIName" \
        --high-pass="$HighPass" \
        --reclassify-as-signal-file="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${ReclassifyAsSignalFile}" \
        --reclassify-as-noise-file="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${ReclassifyAsNoiseFile}" \
        --matlab-run-mode="$MatlabMode"

        # MSMAll
        "$HCPPIPEDIR"/ICAFIX/ReApplyFixPipeline.sh \
            --path="$StudyFolder" \
            --subject="$Subject" \
            --fmri-name="$fMRIName" \
            --high-pass="$HighPass" \
            --reg-name="MSMAll" \
            --low-res-mesh="$LowResMesh" \
            --matlab-run-mode="$MatlabMode" \
            --motion-regression="${MotionReg}" \
            --delete-intermediates="${DeleteIntermediates}" \
            --clean-substring="clean_rclean"

        # Volume+MSMSulc
        "$HCPPIPEDIR"/ICAFIX/ReApplyFixPipeline.sh \
            --path="$StudyFolder" \
            --subject="$Subject" \
            --fmri-name="$fMRIName" \
            --high-pass="$HighPass" \
            --reg-name="NONE" \
            --low-res-mesh="$LowResMesh" \
            --matlab-run-mode="$MatlabMode" \
            --motion-regression="${MotionReg}" \
            --delete-intermediates="${DeleteIntermediates}" \
            --clean-substring="clean_rclean"

    done
else 
    # apply the reclassification results
    "$HCPPIPEDIR"/ICAFIX/ApplyHandReClassifications.sh \
        --study-folder="$StudyFolder" \
        --subject="$Subject" \
        --fmri-name="$MRFixConcatName" \
        --high-pass="$HighPass" \
        --reclassify-as-signal-file="${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${ReclassifyAsSignalFile}" \
        --reclassify-as-noise-file="${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${ReclassifyAsNoiseFile}" \
        --matlab-run-mode="$MatlabMode"

    #MR FIX config support for non-HCP settings
    config=""
    processingmode="HCPStyleData"

    fMRINamesExist=()
    for fMRIName in "${fMRINamesArray[@]}"; do
        if [[ -e "$StudyFolder/$Subject/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas_MSMAll.dtseries.nii" ]]; then
            fMRINamesExist+=("$fMRIName")
        fi
    done
    SubjfMRINames="$(IFS='@'; echo "${fMRINamesExist[*]}")"

    # Multi-Run
    # MSMAll
    "$HCPPIPEDIR"/ICAFIX/ReApplyFixMultiRunPipeline.sh \
        --path="$StudyFolder" \
        --subject="$Subject" \
        --fmri-names="$SubjfMRINames" \
        --high-pass="$HighPass" \
        --reg-name="MSMAll" \
        --concat-fmri-name="$MRFixConcatName" \
        --low-res-mesh="$LowResMesh" \
        --matlab-run-mode="$MatlabMode" \
        --motion-regression="$MotionReg" \
        --config="$config" \
        --processing-mode="$processingmode" \
        --clean-substring="clean_rclean"
    
    # Volume+MSMSulc
    "$HCPPIPEDIR"/ICAFIX/ReApplyFixMultiRunPipeline.sh \
        --path="$StudyFolder" \
        --subject="$Subject" \
        --fmri-names="$SubjfMRINames" \
        --high-pass="$HighPass" \
        --reg-name="NONE" \
        --concat-fmri-name="$MRFixConcatName" \
        --low-res-mesh="$LowResMesh" \
        --matlab-run-mode="$MatlabMode" \
        --motion-regression="$MotionReg" \
        --config="$config" \
        --processing-mode="$processingmode" \
        --clean-substring="clean_rclean"
fi
