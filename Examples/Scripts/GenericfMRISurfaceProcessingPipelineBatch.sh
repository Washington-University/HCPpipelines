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
source "$EnvironmentScript"

# Log the originating call
echo "$@"

#NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
#DO NOT include "-q " at the beginning
#default to no queue, implying run local
QUEUE="dyn.q"
#QUEUE="hcp_priority.q"

########################################## INPUTS ########################################## 

#Scripts called by this script do assume they run on the outputs of the FreeSurfer Pipeline

######################################### DO WORK ##########################################

TaskList=()
TaskList+=(rfMRI_REST1_RL)
TaskList+=(rfMRI_REST1_LR)
TaskList+=(rfMRI_REST2_RL)
TaskList+=(rfMRI_REST2_LR)
TaskList+=(tfMRI_EMOTION_RL)
TaskList+=(tfMRI_EMOTION_LR)
TaskList+=(tfMRI_GAMBLING_RL)
TaskList+=(tfMRI_GAMBLING_LR)
TaskList+=(tfMRI_LANGUAGE_RL)
TaskList+=(tfMRI_LANGUAGE_LR)
TaskList+=(tfMRI_MOTOR_RL)
TaskList+=(tfMRI_MOTOR_LR)
TaskList+=(tfMRI_RELATIONAL_RL)
TaskList+=(tfMRI_RELATIONAL_LR)
TaskList+=(tfMRI_SOCIAL_RL)
TaskList+=(tfMRI_SOCIAL_LR)
TaskList+=(tfMRI_WM_RL)
TaskList+=(tfMRI_WM_LR)

for Subject in $Subjlist ; do
    echo $Subject

    for fMRIName in "${TaskList[@]}" ; do
        echo "  ${fMRIName}"
        LowResMesh="32" #Needs to match what is in PostFreeSurfer, 32 is on average 2mm spacing between the vertices on the midthickness
        FinalfMRIResolution="2" #Needs to match what is in fMRIVolume, i.e. 2mm for 3T HCP data and 1.6mm for 7T HCP data
        SmoothingFWHM="2" #Recommended to be roughly the grayordinates spacing, i.e 2mm on HCP data 
        GrayordinatesResolution="2" #Needs to match what is in PostFreeSurfer. 2mm gives the HCP standard grayordinates space with 91282 grayordinates.  Can be different from the FinalfMRIResolution (e.g. in the case of HCP 7T data at 1.6mm)
        RegName="MSMAll" #MSMSulc is recommended, if binary is not available use FS (FreeSurfer)

        ProcString="_hp0_clean_rclean_tclean" #Processing suffix identifying previously executed MRI preprocessing stages
        HippSmoothingFWHM="0" #Hippocampal surface smoothing FWHM in mm; 0 means no smoothing
        doGoodVoxels="YES" #Exclude noisy voxels during hippocampal volume-to-surface mapping; YES or NO
        factor="1.5" #Good-voxel upper threshold is MEAN + factor * STD of the normalized, locally adjusted coefficient of variation; larger values exclude fewer voxels
        MeshString="2k" #Resampled HippUnfold mesh: 512, 2k, 8k, or 18k; native mesh is also processed by the pipeline
        if [[ "${fMRIName}" == rfMRI_* ]] ; then
            ProcString="_hp2000_clean_rclean_tclean"
        else
            ProcString="_hp0_clean_rclean_tclean"
        fi
        if [[ "${command_line_specified_run_local}" == "TRUE" || "$QUEUE" == "" ]] ; then
            echo "About to locally run ${HCPPIPEDIR}/fMRISurface/GenericfMRISurfaceProcessingPipeline.sh"
            queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
        else
            echo "About to use fsl_sub to queue ${HCPPIPEDIR}/fMRISurface/GenericfMRISurfaceProcessingPipeline.sh"
            queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE")
        fi
        echo 'GenericfMRISurfaceProcessingPipeline'
        "${queuing_command[@]}" "$HCPPIPEDIR"/fMRISurface/GenericfMRISurfaceProcessingPipeline.sh \
            --path="$StudyFolder" \
            --subject="$Subject" \
            --fmriname="$fMRIName" \
            --lowresmesh="$LowResMesh" \
            --fmrires="$FinalfMRIResolution" \
            --smoothingFWHM="$SmoothingFWHM" \
            --grayordinatesres="$GrayordinatesResolution" \
            --regname="$RegName"

        # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...

        echo "set -- --path=$StudyFolder \
            --subject=$Subject \
            --fmriname=$fMRIName \
            --lowresmesh=$LowResMesh \
            --fmrires=$FinalfMRIResolution \
            --smoothingFWHM=$SmoothingFWHM \
            --grayordinatesres=$GrayordinatesResolution \
            --regname=$RegName"

        echo 'GenericHippocampusfMRISurfaceProcessingPipeline'
        # Hippocampal surface/CIFTI processing
        "${queuing_command[@]}" "$HCPPIPEDIR"/fMRISurface/GenericHippocampusfMRISurfaceProcessingPipeline.sh \
            --studyfolder="$StudyFolder" \
            --subject="$Subject" \
            --fmriname="$fMRIName" \
            --procstring="$ProcString" \
            --smoothingFWHM="$HippSmoothingFWHM" \
            --goodvoxel="$doGoodVoxels" \
            --factor="$factor" \
            --resample_mesh="$MeshString"

        echo "set -- --studyfolder=$StudyFolder \
            --subject=$Subject \
            --fmriname=$fMRIName \
            --procstring=$ProcString \
            --smoothingFWHM=$HippSmoothingFWHM \
            --goodvoxel=$doGoodVoxels \
            --factor=$factor \
            --resample_mesh=$MeshString"

        echo ". ${EnvironmentScript}"

    done
done
