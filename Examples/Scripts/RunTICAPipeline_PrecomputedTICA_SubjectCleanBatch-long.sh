#!/bin/bash

set -eu

# this is an example script to run the tICA pipeline to clean a batch of subjects with group sICA and group tICA results that are both generated from a previous computation
# steps that aren't needed for this mode are automaticaly skipped inside the pipeline
# please make sure that precomputed group sICA and group tICA exist
# please make sure that ICA-FIX, MSMAll and MakeAverageDataset are done properly matching the input arguments before running this tICA pipeline

# Global default values
DEFAULT_STUDY_FOLDER="${HOME}/data/Pipelines_ExampleData" # location of Subject folders (named by subjectID)
# example subjects including 175 7T HCP subjects, separated by @
# space separated subject list
DEFAULT_SUBJECT_LIST="HCA6002236 HCA6002237"
# list of longitudinal sessions suffices
DEFAULT_POSSIBLE_VISITS="V1_MR V2_MR V3_MR"
DEFAULT_TEMPLATE_LIST="HCA6002236_V1_V2_V3 HCA6002237_V1_V2_V3"
DEFAULT_ENVIRONMENT_SCRIPT="$DEFAULT_STUDY_FOLDER/scripts/SetUpHCPPipeline-long.sh"
DEFAULT_GROUP_NAME="HCA1798_MSMAll" # the group average name, which must be specified the same in MakeAverageDataset before running this tICA script
DEFAULT_REG_NAME="MSMAll" # the registration string corresponding to the input files, which must be specified the same in MSMAll pipeline before running this tICA script
DEFAULT_MATLAB_MODE=1 # MatlabMode
DEFAULT_RUN_LOCAL=0
DEFAULT_QUEUE="short.q"
#DEFAULT_QUEUE="hcp_priority.q"

get_options() {
    local scriptName=$(basename "$0")
    local arguments=("$@")

    # initialize global variables
    StudyFolder="${DEFAULT_STUDY_FOLDER}"
    Subjlist=(${DEFAULT_SUBJECT_LIST})
    TemplateList=($DEFAULT_TEMPLATE_LIST)
    PossibleVisits=($DEFAULT_POSSIBLE_VISITS)
    EnvironmentScript="${DEFAULT_ENVIRONMENT_SCRIPT}"
    GroupAverageName="${DEFAULT_GROUP_NAME}"
    RegName="${DEFAULT_REG_NAME}"
    MatlabMode="${DEFAULT_MATLAB_MODE}"
    RunLocal="${DEFAULT_RUN_LOCAL}"
    QUEUE="${DEFAULT_QUEUE}"

    # parse arguments
    local index argument
    local numArgs=${#arguments[@]}

    for ((index = 0; index < ${#arguments[@]}; ++index))
    do
        argument="${arguments[index]}"

        case "${argument}" in
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
            --runlocal | --RunLocal)
                RunLocal=1
                ;;
            --queue=*)
                QUEUE="${argument#*=}"
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

    if [[ "$RegName" == "" ]]
    then
        echo "ERROR: RegName not specified"
        exit 1
    fi

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

function identify_timepoints
{
    local subject=$1
    local tplist=""
    local tp visit n

    #build the list of timepoints
    n=0
    for visit in ${PossibleVisits[*]}; do
        tp="${subject}_${visit}"
        if [ -d "$StudyFolder/$tp" ] && ! [[ " ${ExcludeVisits[*]+${ExcludeVisits[*]}} " =~ [[:space:]]"$tp"[[:space:]] ]]; then
             if (( n==0 )); then
                    tplist="$tp"
             else
                    tplist="$tplist@$tp"
             fi
        fi
        ((n++))
    done
    echo $tplist
}

#
# Function Description
#	Main processing of this script
#
#	Gets user specified command line options and runs tICA group processing (please make sure the ICA-FIX, MSMAll and MakeAverageDataset are finished before running this script)
#

main() {

    # get command line options
    get_options "$@"

    # set up pipeline environment variables and software
    source "${EnvironmentScript}"

    # general settings
    # ICA mode
    # ICA mode is hard-coded to be REUSE_TICA, which is mandatory in longitudinal mode.
    # ICAmode="REUSE_TICA"

    # set how many subjects to do in parallel (local, not cluster-distributed) during individual projection and cleanup, defaults to all detected physical cores, '-1'
    parLimit=-1

    # general inputs
    # key arguments under 'REUSE_TICA' mode that are different from the full run example
    # set the group folder containing an existing tICA cleanup to make use of for REUSE or INITIALIZE modes
    precomputeTICAFolder="<tICA precompute dir>/HCA1798_MSMAll"
    # set the output fMRI name used in the previously computed tICA
    precomputeTICAfMRIName="fMRI_CONCAT_ALL"
    # set the group name used during the previously computed tICA
    precomputeGroupName="HCA1798_MSMAll"
    # set the corresponding dimensionality instead of icaDim's estimate
    sICADim="86"
    # end of key arguments for general inputs under 'REUSE_TICA' mode

    # set list of fMRI on which ICA+FIX has been run, use @ to separate runs (not from the precomputed data)
    fMRINames="rfMRI_REST1_AP@rfMRI_REST1_PA@tfMRI_VISMOTOR_PA@tfMRI_CARIT_PA@tfMRI_FACENAME_PA@rfMRI_REST2_AP@rfMRI_REST2_PA"

    # fMRI names to extract. Required in longitudinal mode; must match (in longitudinal mode) cortical registration (MSMAll) extract names.
    extractfMRINames="rfMRI_REST1_AP@rfMRI_REST1_PA@rfMRI_REST2_AP@rfMRI_REST2_PA"

    # fMRI name to extract. Required in longitudinal mode. Must match (in longitudinal mode) cortical registration (MSMAll) extract name.
    extractfMRIOut="rfMRI_REST"

    # set the output fMRI for the output folder and the other output tICA files (not from the precomputed data)
    OutputfMRIName="fMRI_CONCAT_ALL"

    # set the MR concat fMRI name, if multi-run FIX was used, you must specify the concat name with this option, otherwise use an empty string (not from the precomputed data)
    MRFixConcatName="fMRI_CONCAT_ALL"

    # set the file name component representing the preprocessing already done, e.g. '_Atlas_MSMAll_hp0_clean' (not from the precomputed data)
    fMRIProcSTRING="_Atlas_MSMAll_hp0_clean"

    # set temporal highpass full-width (2*sigma) to use, should be the same from running FIX (not from the precomputed data)
    HighPass="0"

    # set the resolution of data, like '2' or '1.60' or '2.40' (not from the precomputed data)
    fMRIResolution="2"

    # set the number of Wishart filtering used in icaDim, since it's under 'REUSE_TICA' mode, please match this value with that from the precomputation (from the precomputed data)
    # 6 for HCP-style data of ~2000k-5000k timepoints
    # 5 for HCP-style data of <2000k timepoints
    numWisharts="6"

    # set the mesh resolution, like '32' for 32k_fs_LR (not from the precomputed data)
    LowResMesh="32"

    # set the output spectra size for sICA individual projection, RunsXNumTimePoints, like '4800' for 'rfMRI_REST' with four runs or '3880' for 'tfMRI_Concat' with full task concat (not from the precomputed data)
    sessionExpectedTimepoints="2721"
    # end of general inputs

    # step0: MIGP inputs, since it's under 'REUSE_TICA' mode, MIGP will be skipped

    # step1: GroupSICA inputs, since it's under 'REUSE_TICA' mode, GroupSICA will be skipped

    # step2: indProjSICA inputs
    # set the low sICA dimensionalities to use for determining weighting for individual projection, defaults to '7@8@9@10@11@12@13@14@15@16@17@18@19@20@21'
    LowsICADims="7@8@9@10@11@12@13@14@15@16@17@18@19@20@21"

    # step3: ConcatGroupSICA inputs
    # hardcoded conventions are used

    # step4: ComputeGroupTICA inputs
    # hardcoded conventions are used

    # step5: indProjTICA inputs
    # hardcoded conventions are used

    # step6: ComputeTICAFeatures inputs, since it's under 'REUSE_TICA' mode, ComputeTICAFeatures will be skipped

    # step7: ClassifyTICA inputs
    # not integrated yet

    # step8: CleanData inputs
    # set whether the input data used the legacy bias correction (not from the precomputed data)
    FixLegacyBiasString="NO"

    if ((RunLocal)) || [[ "$QUEUE" == "" ]]
    then
        echo "running locally"
        queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
    else
        echo "queueing with fsl_sub to to $QUEUE"
        queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE")
    fi

    #iterate over subjects
    for i in ${!Subjlist[@]}; do
        Subject="${Subjlist[i]}"
        echo "Subject: ${Subject}"
        TemplateLong="${TemplateList[i]}"
        #extract the list of sessions for the current subject.
        Timepoint_list_cross_at_separated=$(identify_timepoints "$Subject")

        # tICA pipeline
        "${queuing_command[@]}" "$HCPPIPEDIR"/tICA/tICAPipeline.sh --study-folder="$StudyFolder" \
            --session-list="${Timepoint_list_cross_at_separated}" \
            --fmri-names="$fMRINames" \
            --output-fmri-name="$OutputfMRIName" \
            --mrfix-concat-name="$MRFixConcatName" \
            --proc-string="$fMRIProcSTRING" \
            --melodic-high-pass="$HighPass" \
            --out-group-name="$GroupAverageName" \
            --fmri-resolution="$fMRIResolution" \
            --surf-reg-name="$RegName" \
            --ica-mode="REUSE_TICA" \
            --num-wishart="$numWisharts" \
            --low-res="$LowResMesh" \
            --low-sica-dims="$LowsICADims" \
            --session-expected-timepoints="$sessionExpectedTimepoints" \
            --fix-legacy-bias="$FixLegacyBiasString" \
            --parallel-limit="$parLimit" \
            --matlab-run-mode="$MatlabMode" \
            --sicadim-override="$sICADim" \
            --precomputed-clean-folder="$precomputeTICAFolder" \
            --precomputed-clean-fmri-name="$precomputeTICAfMRIName" \
            --precomputed-group-name="$precomputeGroupName" \
            --extract-fmri-name-list="$extractfMRINames" \
            --extract-fmri-out="$extractfMRIOut" \
            --is-longitudinal="TRUE" \
            --longitudinal-template="$TemplateLong" \
            --longitudinal-subject="$Subject" \
            --longitudinal-extract-all="TRUE"
    done
}

#
# Invoke the main function to get things started
#
main "$@"
