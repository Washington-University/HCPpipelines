#!/bin/bash

set -eu


# Example script to run fMRIStats pipeline on multiple subjects to compute 
# fMRI quality metrics (mTSNR, fCNR, percent BOLD) after ICA+FIX cleanup

# Global default values
DEFAULT_STUDY_FOLDER="/mnt/myelin/brainmappers/Connectome_Project/YA_HCP_Final" # location of Subject folders (named by subjectID)
DEFAULT_ENVIRONMENT_SCRIPT="/media/myelin/burke/projects/Mac25Rhesus/scripts/Mac25Rhesus_SetUpHCPPipeline.sh" # location of HCP Pipeline environment script
# DEFAULT_STUDY_FOLDER="${HOME}/projects/HCPpipelines_ExampleData" # location of Subject folders (named by subjectID)
# DEFAULT_ENVIRONMENT_SCRIPT="${HOME}/projects/HCPpipelines/Examples/Scripts/SetUpHCPPipeline.sh" # location of HCP Pipeline environment script

# example subjects, separated by @
DEFAULT_SUBJECT_LIST="100206@100307"
DEFAULT_REG_NAME="MSMAll" # the registration string corresponding to the input files, which must be specified the same in MSMAll pipeline
DEFAULT_MATLAB_MODE=1 # MatlabMode
DEFAULT_RUN_LOCAL=0
DEFAULT_QUEUE="matlabparallel.q"

get_options() {
    local scriptName=$(basename "$0")
    local arguments=("$@")

    # initialize global variables
    StudyFolder="${DEFAULT_STUDY_FOLDER}"
    Subjlist="${DEFAULT_SUBJECT_LIST}"
    EnvironmentScript="${DEFAULT_ENVIRONMENT_SCRIPT}"
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
    echo "   RegName: ${RegName}"
    echo "   MatlabMode: ${MatlabMode}"
    echo "-- ${scriptName}: Specified Command-Line Options: -- End --"

}

#
# Function Description
#   Main processing of this script
#
#   Gets user specified command line options and runs fMRIStats on multiple subjects
#   to compute quality metrics on ICA+FIX cleaned data
#
main() {

    # get command line options
    get_options "$@"

    # set up pipeline environment variables and software
    source "${EnvironmentScript}"

    # general settings
    # set list of fMRI runs on which ICA+FIX has been run, use @ to separate runs
    fMRINames="rfMRI_REST1_LR@rfMRI_REST1_RL@rfMRI_REST2_LR@rfMRI_REST2_RL"

    # set the file name component representing the preprocessing already done, e.g. '_clean'
    fMRIProcSTRING="_clean_rclean"

    # set temporal highpass full-width (2*sigma) used in ICA+FIX, should match with $fMRIProcSTRING
    HighPass="2000"

    # set whether to process volume data in addition to surface data
    ProcessVolume="TRUE"

    # set whether to compute cleanup effects metrics (comparing cleaned vs uncleaned data)
    CleanUpEffects="TRUE"

    # tICA mode
    ICAmode="sICA+tICA" # options: 'sICA' or 'sICA+tICA'
    # If ICAmode="sICA", sICATCS and Signal are auto-constructed from standard paths
    # If ICAmode="sICA+tICA", you need to provide these:
    tICAcomponentTCS="" # path to tICA timecourse CIFTI (required if --ica-mode=sICA+tICA)
    tICAcomponentText="" # path to tICA component signal indices text file (required if --ica-mode=sICA+tICA)
  

    # end of general inputs

    # set registration string
    if [ "${RegName}" != "NONE" ] ; then
        RegString="_${RegName}"
    else
        RegString=""
    fi

    # Convert @ separated lists to arrays
    IFS='@' read -ra SubjectArray <<< "$Subjlist"
    IFS='@' read -ra fMRINamesArray <<< "$fMRINames"


    # Loop through subjects and queue parallel jobs
    for Subject in "${SubjectArray[@]}"
    do
        # Build list of fMRI files that exist for this subject
        fMRIExist=()
        for fMRIName in "${fMRINamesArray[@]}"
        do
            if [[ -f "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegString}_hp${HighPass}${fMRIProcSTRING}.dtseries.nii" ]]
            then
                fMRIExist+=("${fMRIName}")
            fi
        done
        
        # Convert array to @ separated string for passing to fMRIStats
        fMRINamesForSub=$(IFS='@'; echo "${fMRIExist[*]}")
        
        # Only queue job if subject has data
        if [[ "$fMRINamesForSub" != "" ]]
        then
            if ((RunLocal)) || [[ "$QUEUE" == "" ]]
            then
                echo "running locally"
                queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
            else
                echo "queueing with fsl_sub to to $QUEUE"
                queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE")
            fi

            # fMRIStats pipeline
            "${queuing_command[@]}" "$HCPPIPEDIR"/fMRIStats/fMRIStats.sh \
                --study-folder="$StudyFolder" \
                --subject="$Subject" \
                --fmri-names="$fMRINamesForSub" \
                --high-pass="$HighPass" \
                --proc-string="$fMRIProcSTRING" \
                --reg-name="$RegName" \
                --process-volume="$ProcessVolume" \
                --cleanup-effects="$CleanUpEffects" \
                --ica-mode="$ICAmode" \
                --tica-component-tcs="$tICAcomponentTCS" \
                --tica-component-text="$tICAcomponentText" \
                --matlab-run-mode="$MatlabMode"
        else
            echo "Skipping ${Subject}: no runs with cleaned data found"
        fi
    done
    
}

#
# Invoke the main function to get things started
#
main "$@"