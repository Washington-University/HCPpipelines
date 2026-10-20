#!/bin/bash 
set -ue

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

prepare_fsf_file() {
    local Level Suffix Path Task
    local -a Suffixes Sessions

    IFS=@ read -r -a Suffixes <<< "$SessionSuffix"
    LevelOneFSFs=""
    LevelTwoFSFs=""
    LevelOneTasks=""
    LevelTwoTask=""

    for Level in 1 2; do
        if [[ "$Level" == 1 ]]; then
            Sessions=("${Suffixes[@]}")
        else
            Sessions=("")
        fi

        for Suffix in "${Sessions[@]}"; do
            if [[ "$Level" == 1 ]]; then
                Path="$LevelOneFsfPattern"
            else
                Path="$LevelTwoFsfPattern"
            fi

            Path=${Path//\{StudyFolder\}/$StudyFolder}
            Path=${Path//\{Subject\}/$Subject}
            Path=${Path//\{Task\}/$TaskName}
            Path=${Path//\{Session\}/$Suffix}
            Path=${Path//\{NumSubjects\}/$NumSubjects}
            Path=${Path//\{FSFprocstring\}/$FSFprocstring}

            if [[ ! -f "$Path" ]]; then
                echo "ERROR: Level $Level FSF file missing: $Path" >&2
                return 1
            fi

            if [[ "$Level" == 1 ]]; then
                Task=${LevelOneTaskPattern//\{Task\}/$TaskName}
                Task=${Task//\{Session\}/$Suffix}

                LevelOneTasks+="${LevelOneTasks:+@}${Task}"
                LevelOneFSFs+="${LevelOneFSFs:+@}${Path}"
            else
                LevelTwoTask=${LevelTwoTaskPattern//\{Task\}/$TaskName}
                LevelTwoFSFs="$Path"
            fi
        done
    done
}

get_batch_options "$@"

StudyFolder="${HOME}/projects/Pipelines_ExampleData" #Location of Subject folders (named by subjectID)
Subjlist="100307 100610" #Space delimited list of subject IDs
EnvironmentScript="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script
EnvironmentScript="/media/myelin/oren/HippUnfoldTesting/Pipelines/HCPpipelines_taskfMRI/Examples/Scripts/SetUpHCPPipeline.sh"

#Set up pipeline environment variables and software
source "$EnvironmentScript"

#NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
#DO NOT include "-q " at the beginning
#default to no queue, implying run local
QUEUE=""
#QUEUE="hcp_priority.q"

# Assign variables
LowResMesh="32" # Whole-brain CIFTI mesh;
SmoothingList="2" #Space delimited list for setting different final smoothings.  2mm is no more smoothing (above minimal preprocessing pipelines grayordinates smoothing).  Smoothing is added onto minimal preprocessing smoothing to reach desired amount
GrayOrdinatesResolution="2" #2mm if using HCP minimal preprocessing pipeline outputs
OriginalSmoothingFWHM="2" #2mm if using HCP minimal preprocessing pipeline outputes
Confound="NONE" #File located in ${SubjectID}/MNINonLinear/Results/${fMRIName} or NONE
HighpassFilter="200" #Use 2000 for linear detrend, 200 is default for HCP task fMRI, NONE to turn off
VolumeBasedProcessing="NO" #YES or NO. CAUTION: Only use YES if you want unconstrained volumetric blurring of your data, otherwise set to NO for faster, less biased, and more senstive processing (grayordinates results do not use unconstrained volumetric blurring and are always produced).  
RegNames="MSMAll" # Use NONE to use the default surface registration
ProcSTRING="hp0_clean_rclean_tclean" #A string indicating already perfomed MRI operations, e.g. rclean_tclean or NONE
ParcellationList="NONE" # Use NONE to perform dense analysis, non-greyordinates parcellations are not supported because they are not valid for cerebral cortex.  Parcellation superseeds smoothing (i.e. smoothing is done)
ParcellationFileList="NONE" # Absolute path the parcellation dlabel file.  Also accepts NONE when the ptseries already exists and does not need to be generated.
HippocampalOutput="YES" # Set to YES to also run hippocampal analysis
HippMesh="2k" # In case HippocampalOutput=YES, then HippUnfold mesh sets hippocampal mesh resolution: 512, 2k, 8k, or 18k

TaskNameList=""
TaskNameList="${TaskNameList} EMOTION"
TaskNameList="${TaskNameList} GAMBLING"
TaskNameList="${TaskNameList} LANGUAGE"
TaskNameList="${TaskNameList} MOTOR"
TaskNameList="${TaskNameList} RELATIONAL"
TaskNameList="${TaskNameList} SOCIAL"
TaskNameList="${TaskNameList} WM"

if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi

if [ -n "${command_line_specified_subj}" ]; then
    Subjlist="${command_line_specified_subj}"
fi

Subjlist=${Subjlist//@/ }
read -r -a Subjects <<< "$Subjlist"
NumSubjects=${#Subjects[@]}

read -r -a Tasks <<< "$TaskNameList"
######################################### FSF Files ##########################################
# FSF files define EVs, contrasts, and optional F-tests.
# Create Level 1 and 2 FSFs using FSL FEAT or edit suitable templates.
# Level 2 must combine the sessions below in the same order.
# Tokens: {StudyFolder}, {Subject}, {Task}, {Session}, {NumSubjects}
# Edit the patterns below with the tokens to match your folders and filenames.
# {Session} means one suffix, such as RL or LR.

SessionSuffix="RL@LR" # Alternatives: RL, 1@2@3@4, AC@PC@AP2
FSFprocstring="hp200_s4"

LevelOneFsfPattern="{StudyFolder}/{Subject}/MNINonLinear/Results/tfMRI_{Task}_{Session}/tfMRI_{Task}_{Session}_{FSFprocstring}_level1.fsf"
LevelTwoFsfPattern="{StudyFolder}/{Subject}/MNINonLinear/Results/tfMRI_{Task}/tfMRI_{Task}_{FSFprocstring}_level2.fsf"

LevelOneTaskPattern="tfMRI_{Task}_{Session}"
LevelTwoTaskPattern="tfMRI_{Task}"
######################################### INPUTS ##########################################

# Requirements for this script
#  installed versions of: FSL, Connectome Workbench (wb_command)
#  environment: HCPPIPEDIR, FSLDIR 

case "${HippocampalOutput}" in
    YES) 
        case "${HippMesh}" in
        512|2k|8k|18k) ;;
        *)
            echo "ERROR: --hippocampal-mesh must be 512, 2k, 8k, or 18k"
            exit 1
            ;;
        esac
        ;;
    NO) ;;
    *)
        echo "ERROR: --hippocampal-output must be YES or NO"
        exit 1
        ;;
esac


# Log the originating call
echo "$@"

######################################### DO WORK ##########################################

for TaskName in "${Tasks[@]}"
do
    for RegName in ${RegNames} ; do
        j=1
        for Parcellation in ${ParcellationList} ; do
            ParcellationFile=`echo "${ParcellationFileList}" | cut -d " " -f ${j}`

            for FinalSmoothingFWHM in $SmoothingList ; do
                for Subject in "${Subjects[@]}"; do
                    echo "${Subject}"
                    prepare_fsf_file

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
                        --lvl2fsf="$LevelTwoFSFs" \
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
                        --parcellationfile="$ParcellationFile" \
                        --hippocampal-output="$HippocampalOutput" \
                        --hippocampal-mesh="$HippMesh"
                 done
            done
            j=$((j + 1))
        done
    done
done

echo "TaskfMRIAnalysisBatch complete"