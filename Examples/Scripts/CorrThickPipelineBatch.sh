#!/bin/bash

get_batch_options() {
    local arguments=("$@")

    command_line_specified_study_folder=""
    command_line_specified_subj=""
    command_line_specified_run_local="FALSE"

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
            --Subjlist=*)
                command_line_specified_subj=${argument#*=}
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

StudyFolder="${HOME}/projects/Pipelines_ExampleData" #Location of Subject folders (named by subjectID)
Subjlist="100307 100610" #Space delimited list of subject IDs
EnvironmentScript="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi

if [ -n "${command_line_specified_subj}" ]; then
    Subjlist="${command_line_specified_subj}"
fi

# Requirements for this script
#  installed versions of: FSL, Connectome Workbench (wb_command), Python3 with dependencies numpy, nibabel, scipy, and psutil
#  environment: HCPPIPEDIR, FSLDIR, CARET7DIR 

#References:
#  - https://www.biorxiv.org/content/10.1101/2025.05.03.651968v1
#  - https://onlinelibrary.wiley.com/doi/full/10.1002/hbm.25776
#Please cite these works when using this measure.

#Set up pipeline environment variables and software
source "$EnvironmentScript"

# Log the originating call
echo "$@"

#NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
#DO NOT include "-q " at the beginning
#default to no queue, implying run local
QUEUE=""
#QUEUE="hcp_priority.q"

for Subject in $Subjlist ; do
    echo "    ${Subject}"

    if [[ "${command_line_specified_run_local}" == "TRUE" || "$QUEUE" == "" ]] ; then
        echo "About to locally run ${HCPPIPEDIR}/global/scripts/CorrThick.sh"
        queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
    else
        echo "About to use fsl_sub to queue ${HCPPIPEDIR}/global/scripts/CorrThick.sh"
        queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE")
    fi

    "${queuing_command[@]}" "$HCPPIPEDIR"/global/scripts/CorrThick.sh \
        --subject-dir="$StudyFolder" \
        --subject="$Subject" \
done




