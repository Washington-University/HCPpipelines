#!/bin/bash 

get_batch_options() {
    local arguments=("$@")

    command_line_specified_study_folder=""
    command_line_specified_sess=""
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
            --Session=*)
                command_line_specified_sess=${argument#*=}
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


#TODO NHP: check if -S <num> is NHP feature or legacy human feature (likely the latter)
# Usage () {
# echo ""
# echo "Usage $0 <StudyFolder> <Subject1> [options]"
# echo ""
# echo "   Options:"
# echo "       -S <num>             : specify Nth session. You need all sets of variables in hcppipe_conf.txt"
# echo "                              (i.e., Tasklist, Taskreflist, TopupPositive, TopupNegative, PhaseEncodingList,"
# echo "                              and DwellTime, TruePatientPosition [HFS, HFSx, FFSx], ScannerPatientPosition "
# echo "                              [HFS, HFP, FFS, FFP])"
# echo "       -d                   : dry run (print commands in the terminal but not run)" 
# echo ""
# exit 1;
# }


get_batch_options "$@"

StudyFolder="${HOME}/projects/Pipelines_ExampleData" #Location of Session folders (named by SessionID)
Sesslist="100307 100610" #Space delimited list of Session IDs
EnvironmentScript="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script
SPECIES="Macaque"

if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi

if [ -n "${command_line_specified_sess}" ]; then
    Sesslist="${command_line_specified_sess}"
fi

if [ "$SPECIES" = "" ] ; then 
    echo "ERROR: please export SPECIES first to any of Macaque, MacaqueCyno, MacaqueRhesus, Marmoset, NightMonkey, Chimp, Human"
    exit 1
fi

# Requirements for this script
#  installed versions of: FSL, Connectome Workbench (wb_command)
#  environment: HCPPIPEDIR, FSLDIR, CARET7DIR

#Set up pipeline environment variables and software
source "$EnvironmentScript"
source "$HCPPIPEDIR"/Examples/Scripts/SetUpSPECIES.sh --species="$SPECIES"
#HACK: work around the log tool name hack in the sourced script
#since debug.shlib will be active by default, set the log toolname back to the Batch script
log_SetToolName "$(basename -- "$0")"


# Log the originating call
echo "$@"

#NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
#DO NOT include "-q " at the beginning
#default to no queue, implying run local
QUEUE=""
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

for Session in $Sesslist ; do
    echo $Session

    for fMRIName in "${TaskList[@]}" ; do
        echo "  ${fMRIName}"
        
        #The following options are defined in SetUpSecies.sh
        #LowResMesh="32" #Needs to match what is in PostFreeSurfer, 32 is on average 2mm spacing between the vertices on the midthickness
        #FinalfMRIResolution="2" #Needs to match what is in fMRIVolume, i.e. 2mm for 3T HCP data and 1.6mm for 7T HCP data
        #SmoothingFWHM="2" #Recommended to be roughly the grayordinates spacing, i.e 2mm on HCP data 
        #GrayordinatesResolution="2" #Needs to match what is in PostFreeSurfer. 2mm gives the HCP standard grayordinates space with 91282 grayordinates.  Can be different from the FinalfMRIResolution (e.g. in the case of HCP 7T data at 1.6mm)
        RegName="MSMSulc" #MSMSulc is recommended, if binary is not available use FS (FreeSurfer)

        if [[ "${command_line_specified_run_local}" == "TRUE" || "$QUEUE" == "" ]] ; then
            echo "About to locally run ${HCPPIPEDIR}/fMRISurface/GenericfMRISurfaceProcessingPipeline.sh"
            queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
        else
            echo "About to use fsl_sub to queue ${HCPPIPEDIR}/fMRISurface/GenericfMRISurfaceProcessingPipeline.sh"
            queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE")
        fi

        "${queuing_command[@]}" "$HCPPIPEDIR"/fMRISurface/GenericfMRISurfaceProcessingPipeline.sh \
            --path="$StudyFolder" \
            --session="$Session" \
            --fmriname="$fMRIName" \
            --lowresmesh="$LowResMesh" \
            --fmrires="$FinalfMRIResolution" \
            --smoothingFWHM="$SmoothingFWHM" \
            --grayordinatesres="$GrayordinatesResolution" \
            --regname="$RegName" \
            --species="$SPECIES"

        # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...

        echo "set -- --path=$StudyFolder \
            --session=$Session \
            --fmriname=$fMRIName \
            --lowresmesh=$LowResMesh \
            --fmrires=$FinalfMRIResolution \
            --smoothingFWHM=$SmoothingFWHM \
            --grayordinatesres=$GrayordinatesResolution \
            --regname=$RegName" \
            --species="$SPECIES"

        echo ". ${EnvironmentScript}"

    done
done
