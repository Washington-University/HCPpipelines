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

StudyFolder="${HOME}/projects/Pipelines_ExampleData" #Location of Subject folders (named by SubjectID) 
Subjlist="100307 100610" #Space delimited list of subject IDs 
EnvironmentScript="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script 
HippUnfoldMesh="native@512@2k@8k@18k"
BrainMesh="native@32k@32k@164k@164k"

# NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
# DO NOT include "-q " at the beginning
QUEUE=""
#QUEUE="hcp_priority.q"

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

# setting log folder
LogFolder=""
if [[ -n "$command_line_specified_log_folder" ]] ; then
    LogFolder="$command_line_specified_log_folder"
    mkdir -p "$LogFolder"
    cd "$LogFolder"
fi

# Set up pipeline environment variables and software
source "$EnvironmentScript"

# Log the originating call
echo "$@"

for Subject in $Subjlist ; do
    echo "$Subject"
    
    if [[ "$RunLocal" == "TRUE" || -z "$QUEUE" ]] ; then
        echo "About to locally run ${HCPPIPEDIR}/HippUnfoldHCP/PostHippUnfoldHCP.sh"
        queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
    else
        echo "About to use fsl_sub to queue ${HCPPIPEDIR}/HippUnfoldHCP/PostHippUnfoldHCP.sh"
        queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE")

        if [[ -n "$LogFolder" ]]; then
            queuing_command+=(-l "$LogFolder")
        fi
    fi    

    "${queuing_command[@]}" "$HCPPIPEDIR"/HippUnfoldHCP/PostHippUnfoldHCP.sh --study-folder="$StudyFolder" --subject="$Subject" --hippunfold-mesh="$HippUnfoldMesh" --brain-mesh="$BrainMesh"

    # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 $4...

    echo "set -- --study-folder=$StudyFolder --subject=$Subject --hippunfold-mesh=$HippUnfoldMesh --brain-mesh=$BrainMesh"

    echo ". ${EnvironmentScript}"

done
