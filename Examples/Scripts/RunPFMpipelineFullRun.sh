#!/bin/bash

set -eu

# This is an example script to run the full PFM postprocessing pipeline
# Steps involved:
# 1. ImportPFMNotes - Import PFM results and create time courses, spectra, and maps
# 2. RSNRegression - Run RSN regression on PFM data for dual regression
# 3. PFMNotesGroup - Generate group-level statistics and averages
#
# Please make sure that PROFUMO, ICA-FIX, MSMAll and MakeAverageDataset are done properly 
# matching the input arguments before running this PFM pipeline

# Global default values
DEFAULT_STUDY_FOLDER="/media/myelin/brainmappers/BICAN/Macaque/MacaqueRhesus"
DEFAULT_SUBJECT_LIST="$(find ${DEFAULT_STUDY_FOLDER} -maxdepth 1 -type d -name "A*" -exec basename {} \; | paste -sd@ -)"
# fourRunSubjects=$(ls $DEFAULT_STUDY_FOLDER/A*/MNINonLinear/Results/BOLD_REST_4_PA -d | awk -F'/' '{print $(NF-3)}' | tr '\n' ' ')
# DEFAULT_SUBJECT_LIST=$(echo "${DEFAULT_SUBJECT_LIST}" | tr ' ' '\n' | grep -vxFf <(echo "${fourRunSubjects}" | tr ' ' '\n') | tr '\n' ' ') # remove four run subjects


DEFAULT_ENVIRONMENT_SCRIPT="/media/myelin/burke/projects/Mac25Rhesus/scripts/Mac25Rhesus_v5/Mac25Rhesus_v5_SetUpHCPPipeline.sh"
DEFAULT_GROUP_NAME="Mac25Rhesus_v5" # the group average name, which must be specified the same in MakeAverageDataset before running this tICA script
DEFAULT_REG_NAME="" # the registration string corresponding to the input files, which must be specified the same in MSMAll pipeline before running this tICA script
DEFAULT_MATLAB_MODE=1 # MatlabMode
DEFAULT_RUN_LOCAL=0
DEFAULT_QUEUE="matlabparallelhigh.q" 

get_options() {
    local scriptName=$(basename "$0")
    local arguments=("$@")

    # initialize global variables
    StudyFolder="${DEFAULT_STUDY_FOLDER}"
    Subjlist="${DEFAULT_SUBJECT_LIST}"
    EnvironmentScript="${DEFAULT_ENVIRONMENT_SCRIPT}"
    GroupAverageName="${DEFAULT_GROUP_NAME}"
    RegName="${DEFAULT_REG_NAME}"
    MatlabMode="${DEFAULT_MATLAB_MODE}"
    RunLocal="${DEFAULT_RUN_LOCAL}"
    QUEUE="${DEFAULT_QUEUE}"

    # parse arguments
    local index argument

    for ((index = 0; index < ${#arguments[@]}; ++index))
    do
        argument="${arguments[index]}"

        case "$argument" in
            --StudyFolder=*)
                StudyFolder="${argument#*=}"
                ;;
            --Subject=*)
                Subjlist="${argument#*=}"
                ;;
            --EnvironmentScript=*)
                EnvironmentScript="${argument#*=}"
                ;;
            --GroupAverageName=*)
                GroupAverageName="${argument#*=}"
                ;;
            --RegName=*)
                RegName="${argument#*=}"
                ;;
            --MatlabMode=*)
                MatlabMode="${argument#*=}"
                ;;
            *)
                echo "ERROR: Unrecognized Option: ${argument}"
                exit 1
                ;;
        esac
    done

    # check required parameters
    if [[ "$StudyFolder" == "" ]]
    then
        echo "ERROR: StudyFolder not specified"
        exit 1
    fi

    if [[ "$Subjlist" == "" ]]
    then
        echo "ERROR: Subjlist not specified"
        exit 1
    fi

    if [[ "$EnvironmentScript" == "" ]]
    then
        echo "ERROR: EnvironmentScript not specified"
        exit 1
    fi

    if [[ "$GroupAverageName" == "" ]]
    then
        echo "ERROR: GroupAverageName not specified"
        exit 1
    fi

    # if [[ "$RegName" == "" ]]
    # then
    #     echo "ERROR: RegName not specified"
    #     exit 1
    # fi

    if [[ "$MatlabMode" == "" ]]
    then
        echo "ERROR: MatlabMode not specified"
        exit 1
    fi

    # report options
    echo "-- ${scriptName}: Specified Command-Line Options: -- Start --"
    echo "   StudyFolder: ${StudyFolder}"
    echo "   Subjlist: ${Subjlist}"
    echo "   EnvironmentScript: ${EnvironmentScript}"
    echo "   GroupAverageName: ${GroupAverageName}"
    echo "   RegName: ${RegName}"
    echo "   MatlabMode: ${MatlabMode}"
    echo "-- ${scriptName}: Specified Command-Line Options: -- End --"
}



#
# Function Description
#	Main processing of this script
#
#	Gets user specified command line options and runs PFM postprocessing pipeline 
#   (please make sure the PROFUMO, ICA-FIX, MSMAll and MakeAverageDataset are finished before running this script)
#

main() {

    # get command line options
    get_options "$@"

    # set up pipeline environment variables and software
    source "${EnvironmentScript}"

    if ((RunLocal)) || [[ "$QUEUE" == "" ]]; then
      echo "running locally"
      queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
    else
      echo "queueing with fsl_sub to $QUEUE"
      queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE")
    fi

    # general settings
    # set the start step beginning from RunPROFUMO which is by default the first step
    # StartStep="RunPROFUMO"
    # StopStep="RunPROFUMO"  
    # StartStep="ImportPFMNotes"
    # StopStep="ImportPFMNotes"  
    # StartStep="ImportPFMNotes"
    # StartStep="RSNRegression"  
    # StopStep="RSNRegression"
    # StartStep="RunPROFUMO"
    # StopStep="RSNRegression"

    StartStep="RunPROFUMO"
    StopStep="PFMNotesGroup"

    # set how many subjects to do in parallel (local, not cluster-distributed) during RSN regression, defaults to all detected physical cores, '-1'
    parLimit=-1

    
    # general inputs
    fMRINames="BOLD_REST_1_RL@BOLD_REST_2_LR@BOLD_REST_3_AP@BOLD_REST_4_PA"
    # fMRINames="BOLD_REST_1_RL@BOLD_REST_2_LR"
    randSeed=2 # random seed for PROFUMO 

    OutputfMRIName="Mac25Rhesus_v5_BOLD_REST_CONCAT_PFM"
    # set the MR concat fMRI name, if multi-run FIX was used, leave empty for single runs
    ConcatName="BOLD_REST_CONCAT"
    # set the output spectra size for individual projection, RunsXNumTimePoints
    subjectExpectedTimepoints="8508"
    # set temporal highpass full-width (2*sigma) used in preprocessing
    HighPass="pd2"


    # PFM settings for REST data
    PFMdim="16"  # set the PFM dimensionality
    PFMFolder=${StudyFolder}/$GroupAverageName/MNINonLinear/Results/${OutputfMRIName}_d${PFMdim}_s${randSeed}_M1k
    # Reference image for PROFUMO
    RefImage="${StudyFolder}/$GroupAverageName/MNINonLinear/Results/Mac25Rhesus_v5_BOLD_REST_CONCAT_MIGP/Mac25Rhesus_v5_BOLD_REST_CONCAT_MIGP_Atlas_hppd2_clean_meanvn.dscalar.nii"

    # set the file name component representing the preprocessing already done
    fMRIProcSTRING="hp${HighPass}_clean"

    # set the mesh resolution, like '32' for 32k_fs_LR
    LowResMesh="10"

    # RSN regression settings
    RSNMethod="dual"  # dual or single (default: dual)
    LowDims="6"
    FixLegacyBiasString="NO"
    ScaleFactor="0.01"

    # Volume template file
    VolumeTemplateCIFTI="/media/myelin/brainmappers/BICAN/Macaque/MacaqueRhesus/Mac25Rhesus_v5/MNINonLinear/Results/Mac25Rhesus_v5_VolMaps_16_template.dscalar.nii"

    # PROFUMO settings
    ProfumoSingularity="/media/myelin/burke/projects/Mac25Rhesus/HCPpipelines/PFM/profumo_v2.sif" 
    ProfumoConfig="${PFMFolder}/dataLocations.json"  
    TR="0.702"
    ProfumoThreads="14"
    DOFCorrection="0.5"
    CovModel="Subject"
    nStarts="1000" # number of multi-start iterations for PROFUMO
    RandomSeed="$randSeed" # random seed for PROFUMO reproducibility
    # RefImage will be auto-set based on data type below

    # build Profumo data location json
    mkdir -p $PFMFolder
    echo '{' > $ProfumoConfig
    for Subject in $(echo $Subjlist | tr "@" "\n"); do
        echo -e "\t\"$Subject\": {" >> $ProfumoConfig
        for fMRIName in $(echo $fMRINames | tr "@" "\n"); do
            runFile="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas_${fMRIProcSTRING}.dtseries.nii"
            if [[ -e $runFile ]]; then
                echo -e "\t\t\"$fMRIName\": \"$runFile\"," >> $ProfumoConfig
            fi
        done
        perl -pi -e 'if (eof) { s/,$// }' $ProfumoConfig  # remove trailing comma
        echo -e "\t}," >> $ProfumoConfig
    done
    perl -pi -e 'if (eof) { s/,$// }' $ProfumoConfig  # remove trailing comma
    echo "}" >> $ProfumoConfig

    # PFM pipeline execution
    echo "Starting PFM postprocessing pipeline..."
    echo "Data type: ${OutputfMRIName}"
    echo "PFM dimension: ${PFMdim}"

    "${queuing_command[@]}" "$HCPPIPEDIR"/PFM/PFMPipeline.sh \
                                    --study-folder="$StudyFolder" \
                                    --subject-list="$Subjlist" \
                                    --fmri-names="$fMRINames" \
                                    --output-fmri-name="$OutputfMRIName" \
                                    --proc-string="$fMRIProcSTRING" \
                                    --group-average-name="$GroupAverageName" \
                                    --pfm-dimension="$PFMdim" \
                                    --pfm-folder="$PFMFolder" \
                                    --surf-reg-name="$RegName" \
                                    --concat-name="$ConcatName" \
                                    --low-res-mesh="$LowResMesh" \
                                    --runs-timepoints="$subjectExpectedTimepoints" \
                                    --rsn-method="$RSNMethod" \
                                    --low-dims="$LowDims" \
                                    --fix-legacy-bias="$FixLegacyBiasString" \
                                    --scale-factor="$ScaleFactor" \
                                    --starting-step="$StartStep" \
                                    --stop-after-step="$StopStep" \
                                    --parallel-limit="$parLimit" \
                                    --matlab-run-mode="$MatlabMode" \
                                    --profumo-config="$ProfumoConfig" \
                                    --profumo-singularity="$ProfumoSingularity" \
                                    --profumo-tr="$TR" \
                                    --profumo-threads="$ProfumoThreads" \
                                    --profumo-dof-correction="$DOFCorrection" \
                                    --profumo-cov-model="$CovModel" \
                                    --profumo-multi-start-iterations="$nStarts"\
                                    --profumo-random-seed="$RandomSeed" \
                                    --ref-image="$RefImage" \
                                    --volume-template-file="$VolumeTemplateCIFTI"
    
    echo "PFM pipeline submitted successfully!"
}

#
# Invoke the main function to get things started
#
main "$@"