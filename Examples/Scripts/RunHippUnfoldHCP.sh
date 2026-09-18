#!/bin/bash

get_batch_options() {
    local arguments=("$@")

    command_line_specified_study_folder=""
    command_line_specified_subject=""
    command_line_specified_run_local=""
    command_line_specified_queue=""
    command_line_specified_log_folder=""
    command_line_specified_environment_script=""

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
            --QUEUE=*)
                command_line_specified_queue=${argument#*=}
                index=$((index + 1))
            ;;
            --LogFolder=*)
                command_line_specified_log_folder=${argument#*=}
                index=$((index + 1))
            ;;     
            --EnvironmentScript=*)
                command_line_specified_environment_script=${argument#*=}
                index=$((index + 1))
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

###################################### DEFAULT PARAMETERS ######################################
# Edit these values as needed. Command-line options override the corresponding defaults.
StudyFolder="${HOME}/projects/Pipelines_ExampleData" #Location of Subject folders (named by SubjectID) 
Subjlist="100307 100610" #Space delimited list of subject IDs 
EnvironmentScript="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

# NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
# DO NOT include "-q " at the beginning
QUEUE=""
#QUEUE="hcp_priority.q"
################################################################################################

if [[ -n "$command_line_specified_environment_script" ]] ; then
    EnvironmentScript="$command_line_specified_environment_script"
fi

if [[ ! -f "$EnvironmentScript" ]] ; then
    echo "ERROR: Environment script does not exist: $EnvironmentScript" >&2
    exit 1
fi

if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi

if [ -n "${command_line_specified_subject}" ]; then
    Subjlist="${command_line_specified_subject}"
fi

if [[ "$command_line_specified_run_local" == "TRUE" ]] ; then
    RunLocal="TRUE"
else
    RunLocal="FALSE"
fi

# Set up pipeline environment variables and software
source "$EnvironmentScript"

# Log the originating call
echo "$@"

LogFolder="$StudyFolder"
if [[ -n "$command_line_specified_log_folder" ]] ; then
    LogFolder="$command_line_specified_log_folder"
fi
mkdir -p "$LogFolder"
cd "$LogFolder"

if [[ -n "$command_line_specified_queue" ]] ; then
    QUEUE="$command_line_specified_queue"
fi

######################################### DO WORK ##########################################

for Subject in $Subjlist ; do
    echo "$Subject"

if [[ "$RunLocal" == "TRUE" || -z "$QUEUE" ]] ; then
    echo "About to locally run ${HCPPIPEDIR}/HippUnfoldHCP/HippUnfoldHCP.sh"
    queuing_command=("$HCPPIPEDIR/global/scripts/captureoutput.sh")

else

    echo "About to use fsl_sub to queue ${HCPPIPEDIR}/HippUnfoldHCP/HippUnfoldHCP.sh"
    queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE" -l "$LogFolder")

fi

"${queuing_command[@]}" \
    "$HCPPIPEDIR"/HippUnfoldHCP/HippUnfoldHCP.sh \
    --study-folder="$StudyFolder" \
    --subject="$Subject"

    echo "set -- --study-folder=$StudyFolder --subject=$Subject"
    echo ". ${EnvironmentScript}"

done
