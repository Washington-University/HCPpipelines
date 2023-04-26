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
#  installed versions of: FSL, Connectome Workbench (wb_command)
#  environment: HCPPIPEDIR, FSLDIR, CARET7DIR 

#Set up pipeline environment variables and software
source "$EnvironmentScript"

# Log the originating call
echo "$@"

#NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
#DO NOT include "-q " at the beginning
#default to no queue, implying run local
QUEUE=""
#QUEUE="hcp_priority.q"

########################################## INPUTS ########################################## 

#Scripts called by this script do assume they run on the results of the HCP minimal preprocesing pipelines from Q2

######################################### DO WORK ##########################################

TaskNameList=""
TaskNameList="${TaskNameList} EMOTION"
TaskNameList="${TaskNameList} GAMBLING"
TaskNameList="${TaskNameList} LANGUAGE"
TaskNameList="${TaskNameList} MOTOR"
TaskNameList="${TaskNameList} RELATIONAL"
TaskNameList="${TaskNameList} SOCIAL"
TaskNameList="${TaskNameList} WM"

for TaskName in ${TaskNameList}
do
    LevelOneTasksList="tfMRI_${TaskName}_RL@tfMRI_${TaskName}_LR" #Delimit runs with @ and tasks with space
    LevelOneFSFsList="tfMRI_${TaskName}_RL@tfMRI_${TaskName}_LR" #Delimit runs with @ and tasks with space
    LevelTwoTaskList="tfMRI_${TaskName}" #Space delimited list
    LevelTwoFSFList="tfMRI_${TaskName}" #Space delimited list

    SmoothingList="2" #Space delimited list for setting different final smoothings.  2mm is no more smoothing (above minimal preprocessing pipelines grayordinates smoothing).  Smoothing is added onto minimal preprocessing smoothing to reach desired amount
    LowResMesh="32" #32 if using HCP minimal preprocessing pipeline outputs
    GrayOrdinatesResolution="2" #2mm if using HCP minimal preprocessing pipeline outputs
    OriginalSmoothingFWHM="2" #2mm if using HCP minimal preprocessing pipeline outputes
    Confound="NONE" #File located in ${SubjectID}/MNINonLinear/Results/${fMRIName} or NONE
    HighpassFilter="200" #Use 2000 for linear detrend, 200 is default for HCP task fMRI, NONE to turn off
    VolumeBasedProcessing="NO" #YES or NO. CAUTION: Only use YES if you want unconstrained volumetric blurring of your data, otherwise set to NO for faster, less biased, and more senstive processing (grayordinates results do not use unconstrained volumetric blurring and are always produced).  
    RegNames="NONE" # Use NONE to use the default surface registration
    ProcSTRING="NONE" #Any preprocesing beyond CIFTI mapping and surface registration, e.g. spatial and temporal ICA cleanup or NONE
    ParcellationList="NONE" # Use NONE to perform dense analysis, non-greyordinates parcellations are not supported because they are not valid for cerebral cortex.  Parcellation superseeds smoothing (i.e. smoothing is done)
    ParcellationFileList="NONE" # Absolute path the parcellation dlabel file.  Also accepts NONE when the ptseries already exists and does not need to be generated.


    for RegName in ${RegNames} ; do
        j=1
        for Parcellation in ${ParcellationList} ; do
            ParcellationFile=`echo "${ParcellationFileList}" | cut -d " " -f ${j}`

            for FinalSmoothingFWHM in $SmoothingList ; do
                echo $FinalSmoothingFWHM
                i=1
                for LevelTwoTask in $LevelTwoTaskList ; do
                    echo "  ${LevelTwoTask}"

                    LevelOneTasks=`echo $LevelOneTasksList | cut -d " " -f $i`
                    LevelOneFSFs=`echo $LevelOneFSFsList | cut -d " " -f $i`
                    LevelTwoTask=`echo $LevelTwoTaskList | cut -d " " -f $i`
                    LevelTwoFSF=`echo $LevelTwoFSFList | cut -d " " -f $i`

                    for Subject in $Subjlist ; do
                        echo "    ${Subject}"

                        if [[ "${command_line_specified_run_local}" == "TRUE" || "$QUEUE" == "" ]] ; then
                            echo "About to locally run ${HCPPIPEDIR}/TaskfMRIAnalysis/TaskfMRIAnalysis.sh"
                            queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
                        else
                            echo "About to use fsl_sub to queue ${HCPPIPEDIR}/TaskfMRIAnalysis/TaskfMRIAnalysis.sh"
                            queuing_command=("${FSLDIR}/bin/fsl_sub" -q "$QUEUE")
                        fi

                        "${queuing_command[@]}" "$HCPPIPEDIR"/TaskfMRIAnalysis/TaskfMRIAnalysis.sh \
                            --study-folder="$StudyFolder" \
                            --subject="$Subject" \
                            --lvl1tasks="$LevelOneTasks" \
                            --lvl1fsfs="$LevelOneFSFs" \
                            --lvl2task="$LevelTwoTask" \
                            --lvl2fsf="$LevelTwoFSF" \
                            --lowresmesh="$LowResMesh" \
                            --grayordinatesres="$GrayOrdinatesResolution" \
                            --origsmoothingFWHM="$OriginalSmoothingFWHM" \
                            --confound="$Confound" \
                            --finalsmoothingFWHM="$FinalSmoothingFWHM" \
                            --highpassfilter="$HighpassFilter" \
                            --vba="$VolumeBasedProcessing" \
                            --regname="$RegName" \
                            --procstring="$ProcSTRING" \
                            --parcellation="$Parcellation" \
                            --parcellationfile="$ParcellationFile"

                    done
                    i=$((i + 1))
                done
            done
            j=$((j + 1))
        done
    done
done
