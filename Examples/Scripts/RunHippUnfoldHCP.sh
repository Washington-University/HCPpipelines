#!/bin/bash

get_batch_options() {
    local arguments=("$@")

    command_line_specified_study_folder=""
    command_line_specified_subject=""
    command_line_specified_run_local=""
    
    local index=0
    local numArgs=${#arguments[@]}
    local argument

    while [ ${index} -lt ${numArgs} ]; do
        argument=${arguments[index]}

        case ${argument} in
            --StudyFolder=*)
                command_line_specified_study_folder=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --Subject=*)
                command_line_specified_subject=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --runlocal)
                command_line_specified_run_local="TRUE"
                index=$(( index + 1 ))
                ;;
            *)
                echo ""
                echo "ERROR: Unrecognized Option: ${argument}"
                echo ""
                exit 1
                ;;
        esac
    done
}

get_batch_options "$@"

#StudyFolder="${HOME}/projects/Pipelines_ExampleData" #Location of Subject folders (named by SubjectID) 
#Subjlist="100307 100610" #Space delimited list of subject IDs 
#EnvironmentScript="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script 

StudyFolder="/media/myelin/brainmappers/Connectome_Project/YA_HCP_Final/" 
Subjlist="103818 105923 111312 114823 115320 122317 125525 130518 135528 \
137128 139839 143325 144226 146129 149337 149741 151526 158035 \
169343 172332 175439 177746 185442 187547 192439 194140 195041 \
200109 200614 204521 250427 287248 341834 433839 562345 599671 \
601127 627549 660951 662551 783462 859671 861456 877168 917255"
EnvironmentScript="/media/myelin/oren/HippUnfoldTesting/HCPpipelines/Examples/Scripts/SetUpHCPPipeline.sh" 

if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi

if [ -n "${command_line_specified_subject}" ]; then
    Subjlist="${command_line_specified_subject}"
fi

# Set up pipeline environment variables and software
source "$EnvironmentScript"

# Log the originating call
echo "$@"

# NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
# DO NOT include "-q " at the beginning
QUEUE="dyn.q"
#QUEUE="hcp_priority.q"

######################################### DO WORK ##########################################

for Subject in $Subjlist ; do
    echo "$Subject"

    LogDir="${StudyFolder}/${Subject}/T1w/HippUnfold/logs/HippUnfoldHCP"
    mkdir -p "$LogDir"
    cd "$LogDir"

    if [[ "${command_line_specified_run_local}" == "TRUE" || "$QUEUE" == "" ]] ; then

        echo "About to locally run ${HCPPIPEDIR}/HippUnfoldHCP/HippUnfoldHCP.sh"

        if ! "$HCPPIPEDIR"/global/scripts/captureoutput.sh \
            "$HCPPIPEDIR"/HippUnfoldHCP/HippUnfoldHCP.sh \
            --study-folder="$StudyFolder" \
            --subject="$Subject"
        then
            echo "ERROR: HippUnfold failed for subject: $Subject"
            exit 1
        fi

    else

        echo "About to use fsl_sub to queue ${HCPPIPEDIR}/HippUnfoldHCP/HippUnfoldHCP.sh"

        "$FSLDIR/bin/fsl_sub" \
            -q "$QUEUE" \
            -l "$LogDir" \
            "$HCPPIPEDIR"/HippUnfoldHCP/HippUnfoldHCP.sh \
            --study-folder="$StudyFolder" \
            --subject="$Subject"

    fi

    echo "set -- --study-folder=$StudyFolder --subject=$Subject"
    echo ". ${EnvironmentScript}"

done