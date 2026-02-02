#!/bin/bash

set -eu


# Example script to run fMRIStats pipeline on multiple subjects to compute 
# fMRI quality metrics (mTSNR, fCNR, percent BOLD) after ICA+FIX cleanup

# Global default values
DEFAULT_STUDY_FOLDER="${HOME}/projects/HCPpipelines_ExampleData" # location of Subject folders (named by subjectID)
DEFAULT_ENVIRONMENT_SCRIPT="${HOME}/projects/HCPpipelines/Examples/Scripts/SetUpHCPPipeline.sh" # location of HCP Pipeline environment script

# example subjects, separated by @
DEFAULT_SUBJECT_LIST="100610@102311"
DEFAULT_REG_NAME="MSMAll" # the registration string corresponding to the input files, which must be specified the same in MSMAll pipeline
DEFAULT_MATLAB_MODE=1 # MatlabMode
DEFAULT_RUN_LOCAL=0
DEFAULT_QUEUE=""

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
    fMRINames="rfMRI_REST1_7T_PA@rfMRI_REST2_7T_AP@rfMRI_REST3_7T_PA@rfMRI_REST4_7T_AP"

    # set the file name component representing the preprocessing already done, e.g. '_hp2000_clean'
    fMRIProcSTRING="_hp2000_clean_rclean_tclean"

    # set temporal highpass full-width (2*sigma) used in ICA+FIX, should match with $fMRIProcSTRING
    HighPass="2000"

    # set whether to process volume data in addition to surface data
    ProcessVolume="false"

    # set whether to compute cleanup effects metrics (comparing cleaned vs uncleaned data)
    CleanUpEffects="false"

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
            if [[ -f "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegString}${fMRIProcSTRING}.dtseries.nii" ]]
            then
                fMRIExist+=("${fMRIName}")
            fi
        done
        
        # Convert array to @ separated string for passing to fMRIStats
        fMRINamesForSub=$(IFS='@'; echo "${fMRIExist[*]}")
        
        # Only queue job if subject has data
        if [[ "$fMRINamesForSub" != "" ]]
        then
            fsl_sub -q matlabparallelhigh.q "$HCPPIPEDIR"/fMRIStats/fMRIStats.sh \
                --study-folder="$StudyFolder" \
                --subject="$Subject" \
                --fmri-names="$fMRINamesForSub" \
                --high-pass="$HighPass" \
                --proc-string="$fMRIProcSTRING" \
                --reg-name="$RegName" \
                --process-volume="$ProcessVolume" \
                --cleanup-effects="$CleanUpEffects" \
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