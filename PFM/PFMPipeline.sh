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

# add steps to this array and in the switch cases below
pipelineSteps=(RunPROFUMO PostPROFUMO RSNRegression GroupPFMs)
defaultStart="${pipelineSteps[0]}"
defaultStopAfter="${pipelineSteps[${#pipelineSteps[@]} - 1]}"
stepsText="$(IFS=$'\n'; echo "${pipelineSteps[*]}")"

#description to use in usage
opts_SetScriptDescription "implements complete PFM pipeline with four main steps: Run PROFUMO, Post-PROFUMO, RSN Regression, and Group PFM processing"

#mandatory parameters
opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder that contains all subjects"
opts_AddMandatory '--subject-list' 'SubjlistRaw' '100206@100307...' "list of subject IDs separated by @s"
opts_AddMandatory '--fmri-names' 'fMRINames' 'rfMRI_REST1_LR@rfMRI_REST1_RL...' "list of fmri run names separated by @s"
opts_AddMandatory '--output-fmri-name' 'OutputfMRIName' 'rfMRI_REST' "name to use for PFM pipeline outputs"
opts_AddMandatory '--output-string' 'OutputSTRING' 'string' "output string for individual subject files (typically includes dimension, group name, and seed)"
opts_AddMandatory '--proc-string' 'fMRIProcSTRING' 'string' "file name component representing the preprocessing already done, e.g. '_Atlas_MSMAll_hp2000_clean_rclean_tclean'"
opts_AddMandatory '--group-average-name' 'GroupAverageName' 'string' 'name to use for the group output folder'
opts_AddMandatory '--pfm-dimension' 'PFMdim' 'integer' "PFM dimensionality (e.g., 76, 92, 65)"
opts_AddMandatory '--pfm-folder' 'PFMFolder' 'path' "path to PFM results folder containing Results.ppp"
opts_AddMandatory '--surf-reg-name' 'RegName' 'MSMAll' "the registration string corresponding to the input files"
opts_AddMandatory '--profumo-config' 'ProfumoConfig' 'path' "path to PROFUMO JSON configuration file"
opts_AddMandatory '--profumo-tr' 'TR' "seconds" "repetition time for PROFUMO analysis"
opts_AddMandatory '--ref-image' 'RefImage' 'path' "reference image for PROFUMO postprocessing"
opts_AddMandatory '--runs-timepoints' 'RunsXNumTimePoints' "total timepoints across runs" "total timepoints across runs"
opts_AddMandatory '--concat-name' 'ConcatName' "concatenated fMRI name if using multi-run data" ''
opts_AddMandatory '--volume-template-file' 'VolumeTemplateFile' "volume template file path" ''

#PROFUMO specific parameters
opts_AddOptional '--profumo-threads' 'ProfumoThreads' 'integer' "number of threads for PROFUMO" '25'
opts_AddOptional '--profumo-dof-correction' 'DOFCorrection' 'float' "DOF correction for PROFUMO" '0.5'
opts_AddOptional '--profumo-cov-model' 'CovModel' 'string' "covariance model for PROFUMO" 'Subject'
opts_AddOptional '--profumo-singularity' 'ProfumoSingularity' 'path' "path to PROFUMO singularity container"
opts_AddOptional '--profumo-random-seed' 'RandomSeed' 'integer' "random seed for PROFUMO" '123'
opts_AddOptional '--profumo-multi-start-iterations' 'MultiStartIterations' 'integer' "number of iterations of group-level spatial decomposition before inferring full model" '5'
opts_AddOptional '--profumo-initial-maps' 'InitialMaps' 'path' "file to initialise the decomposition based on spatial maps"

#optional parameters
opts_AddOptional '--low-res-mesh' 'LowResMesh' 'string' "mesh resolution, like '32' for 32k_fs_LR" '32'

#RSN regression specific parameters
opts_AddOptional '--low-dims' 'LowDims' 'string' "low dimensionalities for RSN regression" '7@8@9@10@11@12@13@14@15@16@17@18@19@20@21'
opts_AddOptional '--low-dims-template-file' 'LowDimTemplate' 'path' "low dimensionality template name for RSN regression" ''
opts_AddOptional '--fix-legacy-bias' 'FixLegacyBias' 'YES or NO' 'whether the input data used legacy bias correction' 'NO'
opts_AddOptional '--scale-factor' 'ScaleFactor' 'float' 'scale factor for RSN regression' '0.01'

#general settings
opts_AddOptional '--starting-step' 'startStep' 'step' "what step to start processing at, one of:
$stepsText" "$defaultStart"
opts_AddOptional '--stop-after-step' 'stopAfterStep' 'step' "what step to stop processing after, same valid values as --starting-step" "$defaultStopAfter"
opts_AddOptional '--parallel-limit' 'parLimit' 'integer' "set how many subjects to do in parallel during RSN regression, defaults to all detected physical cores" '-1'
opts_AddOptional '--matlab-run-mode' 'MatlabMode' '0, 1, or 2' "defaults to $g_matlab_default_mode
0 = compiled MATLAB
1 = interpreted MATLAB
2 = Octave" "$g_matlab_default_mode"

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

#processing code goes here
IFS='@' read -a Subjlist <<<"$SubjlistRaw"
IFS='@' read -a fMRINamesArray <<<"$fMRINames"

FixLegacyBiasBool=$(opts_StringToBool "$FixLegacyBias")

if ! [[ "$parLimit" == "-1" || "$parLimit" =~ [1-9][0-9]* ]]
then
    log_Err_Abort "--parallel-limit must be a positive integer or -1, provided value: '$parLimit'"
fi

function stepNameToInd()
{
    for ((i = 0; i < ${#pipelineSteps[@]}; ++i))
    do
        if [[ "$1" == "${pipelineSteps[i]}" ]]
        then
            echo "$i"
            return
        fi
    done
    log_Err_Abort "unrecognized step name: '$1'"
}

startInd=$(stepNameToInd "$startStep")
stopAfterInd=$(stepNameToInd "$stopAfterStep")

if ((startInd > stopAfterInd))
then
    log_Err_Abort "starting step '$startStep' must not be after the stopping step '$stopAfterStep'"
fi

RegString=""
if [[ "$RegName" != "" ]]
then
    RegString="_$RegName"
fi

# Volume template file path
# VolumeTemplateFile="${StudyFolder}/${GroupAverageName}/MNINonLinear/${GroupAverageName}_CIFTIVolumeTemplate_${OutputfMRIName}.2.dscalar.nii"

for ((stepInd = startInd; stepInd <= stopAfterInd; ++stepInd))
do
    stepName="${pipelineSteps[stepInd]}"
    case "$stepName" in
        (RunPROFUMO)
            log_Msg "Running PROFUMO analysis step"
            
            # Validate required PROFUMO parameters
            if [[ "$ProfumoConfig" == "" ]]
            then
                log_Err_Abort "PROFUMO config file must be specified with --profumo-config"
            fi
            if [[ "$ProfumoSingularity" == "" ]]
            then
                log_Err_Abort "PROFUMO singularity container must be specified with --profumo-singularity"
            fi
            if [[ "$RefImage" == "" ]]
            then
                log_Err_Abort "Reference image must be specified with --ref-image"
            fi
            
            # Set up PROFUMO paths
            PFM_PATH="${PFMFolder}/Analysis.pfm"
            RESULTS_PATH="${PFMFolder}/Results.ppp"
            REAL_REF_IMAGE=$(readlink -f "${RefImage}")
            
            # Calculate low rank data parameter
            LowRankData=$((PFMdim * 5))
            
            # Create output directory
            mkdir -p "${PFMFolder}"
            
            # Build optional initialMaps argument
            InitialMapsArg=""
            if [[ -n "${InitialMaps}" && -f "${InitialMaps}" ]]
            then
                InitialMapsArg="--initialMaps ${InitialMaps}"
            fi
            
            # log_Msg "Running PROFUMO decomposition with dimension ${PFMdim}"
            echo  apptainer exec --bind $(dirname "${StudyFolder}") \
                --env PROFUMODIR=/opt/profumo \
                "${ProfumoSingularity}" \
                /opt/profumo/C++/PROFUMO "${ProfumoConfig}" \
                "${PFMdim}" "${PFM_PATH}" \
                --useHRF "${TR}" --covModel "${CovModel}" --dofCorrection "${DOFCorrection}" \
                --nThreads "${ProfumoThreads}" --lowRankData "${LowRankData}" \
                --multiStartIterations "${MultiStartIterations}" ${InitialMapsArg}
            apptainer exec --bind $(dirname "${StudyFolder}") \
                --env PROFUMODIR=/opt/profumo \
                "${ProfumoSingularity}" \
                /opt/profumo/C++/PROFUMO "${ProfumoConfig}" \
                "${PFMdim}" "${PFM_PATH}" \
                --useHRF "${TR}" --covModel "${CovModel}" --dofCorrection "${DOFCorrection}" \
                --nThreads "${ProfumoThreads}" --lowRankData "${LowRankData}" --randomSeed "${RandomSeed}" \
                --multiStartIterations "${MultiStartIterations}" ${InitialMapsArg}
            
            log_Msg "Running PROFUMO postprocessing"
            echo  apptainer exec --bind $(dirname "${StudyFolder}") \
                --env PROFUMODIR=/opt/profumo \
                "${ProfumoSingularity}" \
                /opt/fsl/fslpython/envs/profumo/bin/python3 /opt/profumo/Python/postprocess_results.py \
                --web-report \
                "${PFM_PATH}" \
                "${RESULTS_PATH}" \
                "${REAL_REF_IMAGE}"
            apptainer exec --bind $(dirname "${StudyFolder}") \
                --env PROFUMODIR=/opt/profumo \
                "${ProfumoSingularity}" \
                /opt/fsl/fslpython/envs/profumo/bin/python3 /opt/profumo/Python/postprocess_results.py \
                --web-report \
                "${PFM_PATH}" \
                "${RESULTS_PATH}" \
                "${REAL_REF_IMAGE}"
            ;;
        (PostPROFUMO)
            log_Msg "Running PostPROFUMO step"
            "$HCPPIPEDIR"/PFM/scripts/PostPROFUMO.sh \
                --study-folder="$StudyFolder" \
                --subject-list="$SubjlistRaw" \
                --fmri-names="$fMRINames" \
                --concat-name="$ConcatName" \
                --proc-string="$fMRIProcSTRING" \
                --output-fmri-name="$OutputfMRIName" \
                --output-string="$OutputSTRING" \
                --surf-reg-name="$RegName" \
                --low-res-mesh="$LowResMesh" \
                --profumo-tr="$TR" \
                --pfm-folder="$PFMFolder" \
                --matlab-run-mode="$MatlabMode"
            ;;
        (RSNRegression)
            log_Msg "Running RSNRegression step"
            
            # Set up template paths
            # LowDimTemplate="${StudyFolder}/${GroupAverageName}/MNINonLinear/Results/${OutputfMRIName}/sICA/melodic_oIC_${PFMdim}.dscalar.nii"
            
            for Subject in "${Subjlist[@]}"
            do
                # Build list of existing fMRI files for this subject (same logic as your example)
                fMRINamesForSub=""
                for fMRIName in "${fMRINamesArray[@]}"
                do
                    if [[ -f "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas_${RegName}${fMRIProcSTRING}.dtseries.nii" ]]
                    then
                        if [[ "$fMRINamesForSub" != "" ]]
                        then
                            fMRINamesForSub="${fMRINamesForSub}@${fMRIName}"
                        else
                            fMRINamesForSub="${fMRIName}"
                        fi
                    fi
                done
                
                if [[ "$fMRINamesForSub" == "" ]]
                then
                    log_Warn "No valid fMRI runs found for subject $Subject, skipping"
                    continue
                fi
                
                # Set maps for dual regression
                GroupMaps="${PFMFolder}/Results.ppp/Maps/Group.dscalar.nii"
                
                # Build RSN regression command 
                rsn_cmd=("$HCPPIPEDIR"/global/scripts/RSNregression.sh
                    --study-folder="$StudyFolder"
                    --subject="$Subject"
                    --subject-timeseries="$ConcatName" # "$fMRINamesForSub"
                    --surf-reg-name="$RegName"
                    --low-res="$LowResMesh"
                    --proc-string="_$fMRIProcSTRING"
                    --method="dual"
                    --low-ica-dims="$LowDims"
                    --low-ica-template-name="$LowDimTemplate"
                    --output-string="$OutputSTRING"
                    --output-spectra="$RunsXNumTimePoints"
                    --volume-template-cifti="$VolumeTemplateFile"
                    --output-z=1
                    --fix-legacy-bias="$FixLegacyBias"
                    --scale-factor="$ScaleFactor"
                    --group-maps="$GroupMaps"
                )
                
                # Queue parallel job
                par_addjob "${rsn_cmd[@]}"
            done
            
            # Run the jobs
            par_runjobs "$parLimit"
            ;;
        (GroupPFMs)
            log_Msg "Running GroupPFMs step"
            "$HCPPIPEDIR"/PFM/scripts/GroupPFMs.sh \
                --study-folder="$StudyFolder" \
                --subject-list="$SubjlistRaw" \
                --pfm-dimension="$PFMdim" \
                --output-string="$OutputSTRING" \
                --surf-reg-name="$RegName" \
                --low-res-mesh="$LowResMesh" \
                --runs-timepoints="$RunsXNumTimePoints" \
                --pfm-folder="$PFMFolder" \
                --matlab-run-mode="$MatlabMode"
            ;;
        (*) #NOTE: this case MUST be last
            log_Err_Abort "internal error: unimplemented pipeline step '$stepName'"
            ;;
    esac
    log_Msg "step $stepName complete"
done