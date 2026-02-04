#!/bin/bash

set -eu


# Example script to run fMRIStats pipeline on multiple subjects to compute 
# fMRI quality metrics (mTSNR, fCNR, percent BOLD) after ICA+FIX cleanup

# Global default values
DEFAULT_STUDY_FOLDER="${HOME}/projects/HCPpipelines_ExampleData" # location of Subject folders (named by subjectID)
DEFAULT_ENVIRONMENT_SCRIPT="${HOME}/projects/HCPpipelines/Examples/Scripts/SetUpHCPPipeline.sh" # location of HCP Pipeline environment script

# example subjects, separated by @
DEFAULT_SUBJECT_LIST="100307"
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
    # set list of fMRI runs on which ICA+FIX has been run, use @ to separate multiple
    ConcatNames="tfMRI_Concat"

    # set the file name component representing the preprocessing already done, e.g. '_clean'
    fMRIProcSTRING="_clean_rclean_tclean"

    # set temporal highpass full-width (2*sigma) used in ICA+FIX, should match with $fMRIProcSTRING
    HighPass="0"

    # set whether to process volume data in addition to surface data
    ProcessVolume="TRUE"

    # set whether to compute cleanup effects metrics (comparing cleaned vs uncleaned data)
    CleanUpEffects="TRUE"

    # tICA mode
    ICAmode="sICA+tICA" # options: 'sICA' or 'sICA+tICA'
    # 
    # sICATCS and Signal are always required (auto-constructed from standard paths):
    #   - sICATCS: {fMRIFolder}/{ConcatName}_hp{HighPass}.ica/filtered_func_data.ica/melodic_mix.sdseries.nii
    #   - Signal: {fMRIFolder}/{ConcatName}_hp{HighPass}.ica/HandSignal.txt or Signal.txt
    #
    # If ICAmode="sICA+tICA", you can also provide:
    #   - tICAcomponentTCS: @ delimited list one path per subject
    #   - tICAcomponentNoise: single group file 
    # These files path are not automatically constructed because their names and locations are not necessarily programmatically derivable 
    tICAcomponentTCS="${StudyFolder}/100307/MNINonLinear/fsaverage_LR32k/100307.tfMRI_Concat_d72_WF6_S1200_MSMAll3T475T_WR_tICA_MSMAll_ts.32k_fs_LR.sdseries.nii" # path to tICA timecourse CIFTI (@ delimited or file)
    tICAcomponentNoise="${StudyFolder}/S1200_MSMAll3T1071/MNINonLinear/Results/tfMRI_Concat/Pre_tICA/tICA_d72/Noise.txt" # path to tICA component noise indices text file (same for all subjects)

    # end of general inputs

    # set registration string
    if [ "${RegName}" != "NONE" ] ; then
        RegString="_${RegName}"
    else
        RegString=""
    fi

    # Convert @ separated lists to arrays
    IFS='@' read -ra SubjectArray <<< "$Subjlist"
    IFS='@' read -ra ConcatNamesArray <<< "$ConcatNames"
    IFS='@' read -ra tICAcomponentTCSArray <<< "$tICAcomponentTCS"

    # Loop through subjects and queue parallel jobs
    for ((subjectIndex = 0; subjectIndex < ${#SubjectArray[@]}; ++subjectIndex))
    do
        Subject="${SubjectArray[$subjectIndex]}"
        # Build list of fMRI files that exist for this subject
        fMRIExist=()
        for ConcatName in "${ConcatNamesArray[@]}"
        do
            if [[ -f "${StudyFolder}/${Subject}/MNINonLinear/Results/${ConcatName}/${ConcatName}_Atlas${RegString}_hp${HighPass}${fMRIProcSTRING}.dtseries.nii" ]]
            then
                fMRIExist+=("${ConcatName}")
            fi
        done
        
        # Convert array to @ separated string for passing to fMRIStats
        ConcatNamesForSub=$(IFS='@'; echo "${fMRIExist[*]}")
        
        # Only queue job if subject has data
        if [[ "$ConcatNamesForSub" != "" ]]
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
                --concat-names="$ConcatNamesForSub" \
                --high-pass="$HighPass" \
                --proc-string="$fMRIProcSTRING" \
                --reg-name="$RegName" \
                --process-volume="$ProcessVolume" \
                --cleanup-effects="$CleanUpEffects" \
                --ica-mode="$ICAmode" \
                --tica-component-tcs="${tICAcomponentTCSArray[$subjectIndex]}" \
                --tica-component-noise="$tICAcomponentNoise" \
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