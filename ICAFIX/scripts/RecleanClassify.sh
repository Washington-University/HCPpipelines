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
source "$HCPPIPEDIR/global/scripts/parallel.shlib" "$@"
g_matlab_default_mode=1

#description to use in usage - syntax of parameters is now explained automatically
opts_SetScriptDescription "implements spatial ICA reclean (per subject)"

#mandatory (mrfix name must be specified if applicable, so including it here despite being mechanically optional)
#general inputs
opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder that contains all subjects"
opts_AddMandatory '--subject' 'Subject' '100206' "one subject ID"
opts_AddMandatory '--fmri-names' 'fMRINames' 'rfMRI_REST1_LR@rfMRI_REST1_RL...' "list of fmri run names separated by @s" #Needs to be the single fMRI run names only (for DVARS and GS code) for MR+FIX, is also the SR+FIX input names
opts_AddOptional '--mrfix-concat-name' 'MRFixConcatName' 'rfMRI_REST' "if multi-run FIX was used, you must specify the concat name with this option"
opts_AddMandatory '--fix-high-pass' 'HighPass' 'integer' 'the high pass value that was used when running FIX' '--melodic-high-pass'
opts_AddMandatory '--fmri-resolution' 'fMRIResolution' 'string' "resolution of data, like '2' or '1.60'"
opts_AddMandatory '--subject-expected-timepoints' 'subjectExpectedTimepoints' 'string' "output spectra size for sICA individual projection, RunsXNumTimePoints, like '4800'"
#TSC: doesn't default to MSMAll because we don't have that default string in the MSMAll pipeline
opts_AddMandatory '--surf-reg-name' 'RegName' 'MSMAll' "the registration string corresponding to the input files"
opts_AddConfigMandatory '--low-res' 'LowResMesh' 'LowResMesh' 'meshnum' "mesh resolution, like '32' for 32k_fs_LR"
opts_AddMandatory '--reclassify-as-signal-file' 'ReclassifyAsSignalFile' 'file name' "the file name for the output ReclassifyAsSignal file"
opts_AddMandatory '--reclassify-as-noise-file' 'ReclassifyAsNoiseFile' 'file name' "the file name for the output ReclassifyAsNoise file"
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

UseLocalPython="TRUE"
singularity_command=""
if [[ "$PythonSingularity" != "" && "$PythonInterpreter" != "" ]]; then
    log_Err_Abort "please only specify one of --python-singularity and --python-interpreter"
fi

if [[ "$PythonSingularity" != "" ]]; then
    if [ ! -f "$PythonSingularity" ]; then
        log_Err_Abort "the singularity container doesn't exists under python version: $PythonSingularity"
    fi

    if command -v singularity &> /dev/null; then
        log_Msg "Singularity is installed."
    else
        log_Err_Abort "Singularity is not installed or not in PATH."
    fi
    UseLocalPython="FALSE"
    singularity_command=(singularity exec --bind "$PythonSingularityMountPath" "$PythonSingularity" python3)
else
    # native env using conda
    if [ ! -f "$PythonInterpreter" ]; then
        PythonInterpreter="python3" # default native env
    fi
fi

if [[ "$VoteThresh" == "" ]]; then
    count=$(echo "$ModelToUse" | awk -F'@' '{print NF}')
    VoteThresh=$((count - 1))
fi

IFS='@' read -a fMRINamesArray <<<"$fMRINames"

tempfiles_create fMRIList_XXXXXX.txt fMRIListName

# check SR or MR FIX
if [[ "$MRFixConcatName" != "" ]] ; then
    fMRINamesToUse=("$MRFixConcatName")
else
    fMRINamesToUse=("${fMRINamesArray[@]}")
fi
# check if FIX features are generated (csv with 181 features)
for fMRIName in "${fMRINamesToUse[@]}" ; do
    echo "${fMRIName}" >> "$fMRIListName"
    FixFeaturePath="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}.ica/fix/features.csv"
    if [[ ! -e "$FixFeaturePath" ]]; then
        log_Err_Abort "$FixFeaturePath is not doesn't exist, make sure ICA+FIX is applied to this subject: ${Subject}, fMRI run: ${fMRIName}"
    fi
done

# Preprocess step 1: Merge and dropout
Caret7_Command="wb_command"

#TODO: enable multiple resolutions like macaque (1.25mm resolution) or 7T (1.6mm resolution)
FinalfMRIResolution="2"
SmoothingFWHM="2"
BrainOrdinatesResolution="2"
Flag="FALSE" #FALSE=Don't fix zeros, TRUE=Fix zeros
DeleteIntermediates="TRUE" #TRUE/FALSE

CorticalLUT="$HCPPIPEDIR/global/config/FreeSurferCorticalLabelTableLut.txt"
SubCorticalLUT="$HCPPIPEDIR/global/config/FreeSurferSubcorticalLabelTableLut.txt"

if [ ! ${MRFixConcatName} = "" ] ; then
    DropOutSubSTRING=""
    for fMRIName in "${fMRINamesArray[@]}" ; do
        if [ -e ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_dropouts.nii.gz ] ; then
        DropOutSubSTRING=`echo "${DropOutSubSTRING}${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_dropouts.nii.gz "`
        fi
    done
    if [ ! -z "${DropOutSubSTRING}" ] ; then
        fslmerge -t ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_dropouts.nii.gz ${DropOutSubSTRING}
        fslmaths ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_dropouts.nii.gz -Tmean ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_dropouts.nii.gz
        WorkingDirectory="/tmp/RecleanClassify_MR_${Subject}_${MRFixConcatName}"
        mkdir -p ${WorkingDirectory}
        cp ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_dropouts.nii.gz ${WorkingDirectory}/${MRFixConcatName}_dropouts.nii.gz
        "$HCPPIPEDIR"/ICAFIX/scripts/MapVolumeToCIFTI.sh ${StudyFolder} ${Subject} ${MRFixConcatName} ${CorticalLUT} ${SubCorticalLUT} ${Caret7_Command} ${LowResMesh} ${RegName} ${SmoothingFWHM} ${FinalfMRIResolution} ${BrainOrdinatesResolution} ${WorkingDirectory}/${MRFixConcatName}_dropouts.nii.gz ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_dropouts.dscalar.nii ${MRFixConcatName}_dropouts ${Flag} ${DeleteIntermediates} nii.gz ${WorkingDirectory}
        rm -r ${WorkingDirectory}
    fi
else
    for fMRIName in "${fMRINamesArray[@]}" ; do
        if [ -e ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_dropouts.nii.gz ] ; then
        WorkingDirectory="/tmp/RecleanClassify_SR_${Subject}_${fMRIName}"
        mkdir -p ${WorkingDirectory}
        cp ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_dropouts.nii.gz ${WorkingDirectory}/${fMRIName}_dropouts.nii.gz
        "$HCPPIPEDIR"/ICAFIX/scripts/MapVolumeToCIFTI.sh ${StudyFolder} ${Subject} ${fMRIName} ${CorticalLUT} ${SubCorticalLUT} ${Caret7_Command} ${LowResMesh} ${RegName} ${SmoothingFWHM} ${FinalfMRIResolution} ${BrainOrdinatesResolution} ${WorkingDirectory}/${fMRIName}_dropouts.nii.gz ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_dropouts.dscalar.nii ${fMRIName}_dropouts ${Flag} ${DeleteIntermediates} nii.gz ${WorkingDirectory}
        rm -r ${WorkingDirectory}
        fi
    done
fi

# compute additional features from matlab script
CorticalParcellationFile="$HCPPIPEDIR/global/templates/tICA/Q1-Q6_RelatedValidation210.CorticalAreas_dil_Final_Final_Areas_Group_Colors.32k_fs_LR.dlabel.nii"
SubRegionParcellation="$HCPPIPEDIR/global/templates/tICA/Q1-Q6_RelatedParcellation210.CorticalAreasAndSubRegions_dil.32k_fs_LR.dlabel.nii"
WMLabelFile="$HCPPIPEDIR/global/config/FreeSurferWMRegLut.txt"
CSFLabelFile="$HCPPIPEDIR/global/config/FreeSurferCSFRegLut.txt"
VisualAreasFile="$HCPPIPEDIR/global/config/Visual.ROI.txt"
LanguageAreasFile="$HCPPIPEDIR/global/config/Language.ROI.txt"
SubRegionsFile="$HCPPIPEDIR/global/config/SubRegions.ROI.txt"
NonGreyParcelsFile="$HCPPIPEDIR/global/config/NonGreyParcels.ROI.txt"
GrayOrdinateTemplateFile="$HCPPIPEDIR"/global/templates/91282_Greyordinates/91282_Greyordinates.dscalar.nii

tempfiles_create MMPROIs_temp_XXXXXX.dlabel.nii roitemp
wb_command -cifti-create-dense-from-template "$GrayOrdinateTemplateFile" "$roitemp" -cifti "$CorticalParcellationFile"

tempfiles_create MMPSubRegionROIs_temp_XXXXXX.dlabel.nii roisubtemp
wb_command -cifti-create-dense-from-template "$GrayOrdinateTemplateFile" "$roisubtemp" -cifti "$SubRegionParcellation"

tempfiles_create VisualROI_temp_XXXXXX.dlabel.nii VisualROItemp
tempfiles_add "$VisualROItemp"_labels.dlabel.nii
wb_command -cifti-label-import "$roitemp" "$HCPPIPEDIR"/global/config/Visual.ROI.txt "$VisualROItemp"_labels.dlabel.nii -discard-others
wb_command -cifti-math 'x > 0' "$VisualROItemp" -var x "$VisualROItemp"_labels.dlabel.nii

tempfiles_create LanguageROI_temp_XXXXXX.dlabel.nii LanguageROItemp
tempfiles_add "$LanguageROItemp"_labels.dlabel.nii
wb_command -cifti-label-import "$roitemp" "$HCPPIPEDIR"/global/config/Language.ROI.txt "$LanguageROItemp"_labels.dlabel.nii -discard-others
wb_command -cifti-math 'x > 0' "$LanguageROItemp" -var x "$LanguageROItemp"_labels.dlabel.nii

tempfiles_create SubRegionsROI_temp_XXXXXX.dscalar.nii SubRegionsROItemp
tempfiles_add "$SubRegionsROItemp"_labels.dlabel.nii "$SubRegionsROItemp"_all_labels.dlabel.nii
wb_command -cifti-label-import "$roisubtemp" "$HCPPIPEDIR"/global/config/SubRegions.ROI.txt "$SubRegionsROItemp"_labels.dlabel.nii -discard-others
wb_command -cifti-all-labels-to-rois "$SubRegionsROItemp"_labels.dlabel.nii 1 "$SubRegionsROItemp"

# shortcut in case the folder gets renamed
this_script_dir=$(dirname "$0")
#all arguments are strings, so we can can use the same argument list for compiled and interpreted
matlab_argarray=("$StudyFolder" "$Subject" "$fMRIListName" "$subjectExpectedTimepoints" "$HighPass" "$fMRIResolution" "$CorticalParcellationFile" "$WMLabelFile" "$CSFLabelFile" "$VisualROItemp" "$LanguageROItemp" "$SubRegionsROItemp" "$NonGreyParcelsFile")

case "$MatlabMode" in
    (0)
        matlab_cmd=("$this_script_dir/Compiled_computeRecleanFeatures/run_computeRecleanFeatures.sh" "$MATLAB_COMPILER_RUNTIME" "${matlab_argarray[@]}")
        log_Msg "running compiled matlab command: ${matlab_cmd[*]}"
        "${matlab_cmd[@]}"
        ;;
    (1 | 2)
        #reformat argument array so matlab sees them as strings
        matlab_args=""
        for thisarg in "${matlab_argarray[@]}"
        do
            if [[ "$matlab_args" != "" ]]
            then
                matlab_args+=", "
            fi
            matlab_args+="'$thisarg'"
        done
        
        matlabcode="
            addpath('$HCPPIPEDIR/global/matlab');
            addpath('$HCPPIPEDIR/global/scripts');
            addpath('$HCPCIFTIRWDIR');
            addpath('$this_script_dir');
            computeRecleanFeatures($matlab_args);"

        log_Msg "running matlab code: $matlabcode"
        "${matlab_interpreter[@]}" <<<"$matlabcode"
        echo
        ;;
esac

# hardcoded
FixProbThresh="10"

# inference each subjects under python environment
for fMRIName in "${fMRINamesToUse[@]}" ; do
    RecleanFeaturePath="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}.ica/fix_reclean_features.csv"
    FixProbPath="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}.ica/fix_prob.csv"
    PredictionResult="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}.ica"

    # ReclassifyAsSignalTxt="${PredictionResult}/ReclassifyAsSignalRecleanVote${VoteThresh}.txt"
    # ReclassifyAsNoiseTxt="${PredictionResult}/ReclassifyAsNoiseRecleanVote${VoteThresh}.txt"

    # ReclassifyAsSignalTxt="${PredictionResult}/${ReclassifyAsSignalFile}"
    # ReclassifyAsNoiseTxt="${PredictionResult}/${ReclassifyAsNoiseFile}"

    ReclassifyAsSignalTxt="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${ReclassifyAsSignalFile}"
    ReclassifyAsNoiseTxt="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${ReclassifyAsNoiseFile}"

    pythonCode=(
        "$HCPPIPEDIR/ICAFIX/scripts/RecleanClassifierInference.py"
        --input_csv="$RecleanFeaturePath"
        --input_fix_prob_csv="$FixProbPath"
        --fix_prob_threshold="$FixProbThresh"
        --trained_folder="$ModelFolder"
        --model="$ModelToUse"
        --output_folder="$PredictionResult"
        --voting_threshold="$VoteThresh"
        --reclassify_as_signal_file="$ReclassifyAsSignalTxt"
        --reclassify_as_noise_file="$ReclassifyAsNoiseTxt"
    )

    if [ "$UseLocalPython" = "FALSE" ]; then
        # use singularity
        PythonLaunchCommand=("${singularity_command[@]}" "${pythonCode[@]}")
    else
        # use native env
        PythonLaunchCommand=("${PythonInterpreter}" "${pythonCode[@]}")
    fi

    log_Msg "Run python inference..."
    log_Msg "${PythonLaunchCommand[@]}"
    "${PythonLaunchCommand[@]}"
done
