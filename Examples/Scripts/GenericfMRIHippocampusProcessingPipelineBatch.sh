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
            --Subject=*)
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

ProcString="_hp0_clean_rclean_tclean" #Processing suffix identifying previously executed MRI preprocessing stages
HippSmoothingFWHM="2" #Hippocampal surface smoothing FWHM in mm; 0 means no smoothing
doGoodVoxels="YES" #Exclude noisy voxels during hippocampal volume-to-surface mapping; YES or NO
factor="1.5" #Good-voxel upper threshold is MEAN + factor * STD of the normalized, locally adjusted coefficient of variation; larger values exclude fewer voxels
TargetMesh="2k" #Default Resampled hippunfold mesh for fMRI usage with 3T scanner. Future releases will support additional mesh resolutions.


if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi

if [ -n "${command_line_specified_subj}" ]; then
    Subjlist="${command_line_specified_subj}"
fi

# Requirements for this script
#  installed versions of: FSL, Connectome Workbench (wb_command)
#  environment: HCPPIPEDIR, FSLDIR, CARET7DIR

#Set up pipeline environment variables and software
source "$EnvironmentScript" || exit 1

# Log the originating call
echo "$@"

#NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
#DO NOT include "-q " at the beginning
#default to no queue, implying run local
QUEUE=""
#QUEUE="hcp_priority.q"

if [[ "${command_line_specified_run_local}" == "TRUE" || -z "${QUEUE}" ]]; then
    queuing_command=("${HCPPIPEDIR}/global/scripts/captureoutput.sh")
else
    queuing_command=("${FSLDIR}/bin/fsl_sub" -q "${QUEUE}")
fi

TaskList=()
TaskList+=(rfMRI_REST1_RL)
TaskList+=(rfMRI_REST1_LR)
TaskList+=(tfMRI_Task1_RL)
TaskList+=(tfMRI_Task1_LR)

########################################## INPUTS ########################################## 

#Scripts called by this script do assume they run on the outputs of the FreeSurfer Pipeline

######################################### DO WORK ##########################################

for Subject in $Subjlist ; do
    echo $Subject

    for fMRIName in "${TaskList[@]}" ; do
        echo "  ${fMRIName}"
        # Hippocampal surface/CIFTI processing
        "${queuing_command[@]}" "$HCPPIPEDIR"/fMRISurface/GenericHippocampusfMRISurfaceProcessingPipeline.sh \
            --studyfolder="$StudyFolder" \
            --session="$Subject" \
            --fmriname="$fMRIName" \
            --procstring="$ProcString" \
            --smoothingFWHM="$HippSmoothingFWHM" \
            --goodvoxel="$doGoodVoxels" \
            --factor="$factor" \
            --target_mesh="$TargetMesh"

        echo "set -- --studyfolder=$StudyFolder \
            --session=$Subject \
            --fmriname=$fMRIName \
            --procstring=$ProcString \
            --smoothingFWHM=$HippSmoothingFWHM \
            --goodvoxel=$doGoodVoxels \
            --factor=$factor \
            --target_mesh=$TargetMesh"

        echo ". ${EnvironmentScript}"

    done
done