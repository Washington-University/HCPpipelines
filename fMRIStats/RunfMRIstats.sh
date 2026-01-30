#!/bin/bash

set -eu


# Example script to run fMRIStats pipeline on multiple subjects to compute 
# fMRI quality metrics (mTSNR, fCNR, percent BOLD) after ICA+FIX cleanup

# Global default values
DEFAULT_STUDY_FOLDER="${HOME}/projects/HCPpipelines_ExampleData" # location of Subject folders (named by subjectID)
# example subjects including 175 7T HCP subjects, separated by @
DEFAULT_SUBJECT_LIST="100610@102311@102816@104416@105923@108323@109123@111312@111514@114823@115017@115825@116726@118225@125525@126426@128935@130518@131217@131722@132118@134627@134829@135124@137128@140117@144226@145834@146129@146432@146735@146937@148133@150423@155938@156334@157336@158035@158136@159239@162935@164131@164636@165436@167036@167440@169343@169444@169747@171633@172130@173334@175237@176542@177140@177645@177746@178142@178243@178647@180533@181232@181636@182436@182739@185442@186949@187345@191033@191336@191841@192439@192641@193845@195041@196144@197348@198653@199655@200210@200311@200614@201515@203418@204521@205220@209228@212419@214019@214524@221319@233326@239136@246133@249947@251833@257845@263436@283543@318637@320826@330324@346137@352738@360030@365343@380036@381038@389357@393247@395756@397760@406836@412528@429040@436845@463040@467351@473952@525541@536647@541943@547046@550439@552241@562345@572045@573249@581450@585256@601127@617748@627549@638049@654552@671855@680957@690152@706040@724446@725751@732243@751550@757764@765864@770352@771354@782561@783462@789373@814649@818859@825048@826353@833249@859671@861456@871762@872764@878776@878877@898176@899885@901139@901442@905147@910241@926862@927359@942658@951457@958976@966975@973770@995174"
DEFAULT_CONFIG_FILE="${HOME}/Examples/Scripts/tICA_config.txt" # generate config file for rerunning with similar settings, or for reusing these results for future cleaning
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

    # load parallel processing library
    source "$HCPPIPEDIR"/global/scripts/parallel.shlib

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

    # set how many subjects to process in parallel, defaults to all detected physical cores, '-1'
    parLimit=-1
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