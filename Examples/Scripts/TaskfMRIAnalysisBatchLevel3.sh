#!/bin/bash 
set -ue

get_batch_options() {
    local arguments=("$@")

    command_line_specified_study_folder=""
    command_line_specified_subj=""

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
            *)
                echo ""
                echo "ERROR: Unrecognized Option: ${argument}"
                echo ""
                exit 1
                ;;
        esac
    done
}

resolve_fsf_path() {
    local path="$1"
    local subject="$2"
    local task="$3"
    local run="$4"

    path=${path//\{StudyFolder\}/$StudyFolder}
    path=${path//\{Subject\}/$subject}
    path=${path//\{Task\}/$task}
    path=${path//\{Run\}/$run}
    path=${path//\{NumSubjects\}/$NumSubjects}

    if [[ "$path" != /* || ! -f "$path" || ! -r "$path" ]]; then
        echo "ERROR: FSF must be an absolute, readable file: $path" >&2
        return 1
    fi

    printf '%s\n' "$path"
}

get_batch_options "$@"

StudyFolder="${HOME}/projects/Pipelines_ExampleData" #Location of Subject folders (named by subjectID)
Subjlist="100307 100610" #Space delimited list of subject IDs
EnvironmentScript="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

#Set up pipeline environment variables and software
source "$EnvironmentScript"

# Assign variables
LowResMesh="32" # Whole-brain CIFTI mesh;
SmoothingList="2" #Space delimited list for setting different final smoothings.  2mm is no more smoothing (above minimal preprocessing pipelines grayordinates smoothing).  Smoothing is added onto minimal preprocessing smoothing to reach desired amount
GrayOrdinatesResolution="2" #2mm if using HCP minimal preprocessing pipeline outputs
OriginalSmoothingFWHM="2" #2mm if using HCP minimal preprocessing pipeline outputes
Confound="NONE" #File located in ${SubjectID}/MNINonLinear/Results/${fMRIName} or NONE
HighpassFilter="200" #Use 2000 for linear detrend, 200 is default for HCP task fMRI, NONE to turn off
VolumeBasedProcessing="NO" #YES or NO. CAUTION: Only use YES if you want unconstrained volumetric blurring of your data, otherwise set to NO for faster, less biased, and more senstive processing (grayordinates results do not use unconstrained volumetric blurring and are always produced).  
RegNames="MSMAll" # Use NONE to use the default surface registration
ProcSTRING="hp0_clean_rclean_tclean" #A string indicating already perfomed MRI , e.g. rclean_tclean or NONE
ParcellationList="NONE" # Use NONE to perform dense analysis, non-greyordinates parcellations are not supported because they are not valid for cerebral cortex.  Parcellation superseeds smoothing (i.e. smoothing is done)
ParcellationFileList="NONE" # Absolute path the parcellation dlabel file.  Also accepts NONE when the ptseries already exists and does not need to be generated.
HippocampalOutput="YES" # Set to YES to also run hippocampal analysis
HippMesh="2k" # In case HippocampalOutput=YES, then HippUnfold mesh sets hippocampal mesh resolution: 512, 2k, 8k, or 18k
LevelThreePrefix="GroupAnalysis" # Prefix for Level 3 output names and the group output folder; Use NONE to omit the analysis-name prefix.
LevelThreeContrastList="ALL" # Level 2 contrasts to analyze at Level 3: ALL, or contrast numbers separated by @, e.g. "1@6@8".

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

# User-defined FSF paths, including folder and filename.
# FSF files define the analysis design, including EVs, contrasts, and optional F-tests.
# Create Level 1/2 FSFs using FSL FEAT or edit suitable templates; create Level 3 FSFs using FSL's GLM GUI.
# Level 3 design rows must match the subject order in Subjlist.
# Tokens: {StudyFolder}, {Subject}, {Task}, {Run}, {NumSubjects}
# Use an absolute path or a pattern beginning with {StudyFolder}.

LevelThreeFsfPattern="{StudyFolder}/GroupResults/tfMRI_{Task}_level3_{NumSubjects}subjects.fsf"
LevelThreeOutputFolder="${StudyFolder}/${LevelThreePrefix}_TaskfMRILevel3" 

# Requirements for this script
#  installed versions of: FSL, Connectome Workbench (wb_command)
#  environment: HCPPIPEDIR, FSLDIR 

# Log the originating call
echo "$@"

# Normalize the subject list and prepare the group-analysis arguments.
Subjlist=${Subjlist//@/ }
read -r -a Subjects <<< "$Subjlist"
NumSubjects=${#Subjects[@]}
SubjectList=$(IFS=@; echo "${Subjects[*]}")

######################################### INPUTS ##########################################

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

if [[ "$LevelThreePrefix" == "NONE" ]]; then
    LevelThreeOutputFolder="${StudyFolder}/TaskfMRILevel3"
else
    LevelThreeOutputFolder="${StudyFolder}/${LevelThreePrefix}_TaskfMRILevel3"
fi

######################################### DO WORK ##########################################

for TaskName in ${TaskNameList}
do
    LevelTwoTaskList="tfMRI_${TaskName}" #Space delimited list
    LevelTwoFSFList="tfMRI_${TaskName}" #Space delimited list

    for RegName in ${RegNames} ; do
        j=1
        for Parcellation in ${ParcellationList} ; do
            ParcellationFile=`echo "${ParcellationFileList}" | cut -d " " -f ${j}`

            for FinalSmoothingFWHM in $SmoothingList ; do
                echo $FinalSmoothingFWHM
                i=1
                for LevelTwoTask in $LevelTwoTaskList ; do
                    echo "  ${LevelTwoTask}"

                    LevelTwoTask=`echo $LevelTwoTaskList | cut -d " " -f $i`
                    LevelTwoFSF=`echo $LevelTwoFSFList | cut -d " " -f $i`


                    if (( NumSubjects < 2 )); then
                        echo "ERROR: Level 3 requires at least two subjects" >&2
                        exit 1
                    fi

                    # Check every task's design before running any analyses.
                    LevelThreeFsf=$(resolve_fsf_path "$LevelThreeFsfPattern" "" "$TaskName" "")

                    if [[ ! -f "$LevelThreeFsf" ]]; then
                        echo "ERROR: Missing or unreadable Level 3 design: $LevelThreeFsf" >&2
                        exit 1
                    fi

                    DesignSubjects=$(awk '$1 == "set" && $2 == "fmri(npts)" {gsub(/"/, "", $3); print $3}' "$LevelThreeFsf")

                    if [[ "$DesignSubjects" != "$NumSubjects" ]]; then
                        echo "ERROR: Design subject count does not match Subjlist: $LevelThreeFsf" >&2
                        exit 1
                    fi

                    echo "Running Level 3: ${LevelTwoTask}, ${NumSubjects} subjects"

                    "${HCPPIPEDIR}/global/scripts/captureoutput.sh" \
                        "${HCPPIPEDIR}/TaskfMRIAnalysis/TaskfMRILevel3.sh" \
                        --path="$StudyFolder" \
                        --subjectlist="$SubjectList" \
                        --groupfolder="$LevelThreeOutputFolder" \
                        --lvl3fsf="$LevelThreeFsf" \
                        --lvl2task="$LevelTwoTask" \
                        --lvl2fsf="$LevelTwoFSF" \
                        --prefixanalysisname="$LevelThreePrefix" \
                        --finalsmoothingFWHM="$FinalSmoothingFWHM" \
                        --temporalfilter="$HighpassFilter" \
                        --regname="$RegName" \
                        --parcellation="$Parcellation" \
                        --vba="$VolumeBasedProcessing" \
                        --contrastlist="$LevelThreeContrastList" \
                        --procstring="$ProcSTRING" \
                        --hippocampal-output="$HippocampalOutput"

                    i=$((i + 1))
                done
            done
            j=$((j + 1))
        done
    done
done


echo "TaskfMRIAnalysisBatch complete"