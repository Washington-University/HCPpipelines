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
    local DesignString=""
    if [ "$FsfDesign" != "NONE" ]; then
        DesignString="_${FsfDesign}"
    fi
    path=${path//\{FsfDesign\}/$DesignString}
    path=${path//\{Run\}/$run}
    path=${path//\{NumSubjects\}/$NumSubjects}

    if [[ "$path" != /* || ! -f "$path" || ! -r "$path" ]]; then
        echo "ERROR: FSF must be an absolute, readable file: $path" >&2
        return 1
    fi

    printf '%s\n' "$path"
}

write_filtered_fsf() {
    local input="$1"
    local output="$2"
    local count="$3"

    # Only resize the supplied single-group mean design.
    awk '
        $1 == "set" {
            if ($2 == "fmri(evs_orig)") orig = $3
            if ($2 == "fmri(evs_real)") real = $3
            if ($2 == "fmri(evs_vox)") vox = $3

            if ($2 ~ /^fmri\(evg[0-9]+\.[0-9]+\)$/ &&
                ($2 !~ /\.1\)$/ || $3 != 1)) bad = 1

            if ($2 ~ /^fmri\(groupmem\.[0-9]+\)$/ &&
                $3 != 1) bad = 1

            if ($2 ~ /^(feat_files|highres_files|confoundev_files)\(/)
                bad = 1
        }
        END {
            exit !(orig == 1 && real == 1 && vox == 0 && !bad)
        }
    ' "$input" || {
        echo "ERROR: Expected a single-group mean FSF: $input" >&2
        return 1
    }

    awk -v n="$count" '
        $1 == "set" &&
        ($2 == "fmri(npts)" || $2 == "fmri(multiple)") {
            print "set " $2 " " n
            next
        }

        $1 == "set" &&
        ($2 ~ /^fmri\(evg[0-9]+\.[0-9]+\)$/ ||
         $2 ~ /^fmri\(groupmem\.[0-9]+\)$/) {
            next
        }

        /^# Higher-level EV value/ || /^# Group membership for input/ {
            next
        }

        { print }

        END {
            print "\n# Filtered single-group mean design"
            for (i = 1; i <= n; i++)
                print "set fmri(evg" i ".1) 1"

            for (i = 1; i <= n; i++)
                print "set fmri(groupmem." i ") 1"
        }
    ' "$input" > "$output"
}

get_batch_options "$@"

StudyFolder="${HOME}/projects/HCPpipelines_ExampleData" #Location of Subject folders (named by subjectID)
Subjlist="100307 100610 111312" #Space delimited list of subject IDs
EnvironmentScript="${HOME}/projects/HCPpipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script#Set up pipeline environment variables and software

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
LevelThreePrefix="GroupAnalysis" # Prefix for Level 3 output names and the group output folder; Use NONE to omit the analysis-name prefix.
LevelThreeContrastList="ALL" # Level 2 contrasts to analyze at Level 3: ALL, or contrast numbers separated by @, e.g. "1@6@8".

# Match the design identifiers used for Levels 1 and 2.
# Leave empty for the default design.
# For multiple designs, use: FsfDesignList="StudyDesignA StudyDesignB"
FsfDesignList="NONE"

FsfDesigns=("NONE")
if [[ -n "$FsfDesignList" ]]; then
    read -r -a FsfDesigns <<< "$FsfDesignList"
fi

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

LevelThreeFsfPattern="PathToFsfFolder/tfMRI_{Task}{FsfDesign}_level3_{NumSubjects}subjects.fsf"
LevelThreeOutputFolder="${StudyFolder}/${LevelThreePrefix}_TaskfMRILevel3" 

# Requirements for this script
#  installed versions of: FSL, Connectome Workbench (wb_command)
#  environment: HCPPIPEDIR, FSLDIR 

# Log the originating call
echo "$@"

# Preserve the complete requested list for filtering each task independently.
Subjlist=${Subjlist//@/ }
Subjlist=${Subjlist//$'\n'/ }
read -r -a Subjects <<< "$Subjlist"

RequestedNumSubjects=${#Subjects[@]}
NumSubjects=$RequestedNumSubjects

if (( RequestedNumSubjects < 2 )); then
    echo "ERROR: Level 3 requires at least two requested subjects" >&2
    exit 1
fi

######################################### DO WORK ##########################################

for TaskName in ${TaskNameList}
do
    for FsfDesign in "${FsfDesigns[@]}"
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

                        # Find the ORIGINAL FSF using the original requested subject count.
                        NumSubjects=$RequestedNumSubjects
                        OriginalLevelThreeFsf=$(resolve_fsf_path "$LevelThreeFsfPattern" "" "$TaskName" "")
                        DesignSubjects=$(awk '$1 == "set" && $2 == "fmri(npts)" {gsub(/"/, "", $3); print $3}' "$OriginalLevelThreeFsf")

                        if [[ "$DesignSubjects" != "$RequestedNumSubjects" ]]; then
                            echo "ERROR: Original FSF count does not match requested subjects: ${OriginalLevelThreeFsf}"
                            exit 1
                        fi

                        TemporalFilterString=""
                        if [[ "$HighpassFilter" != "NONE" ]]; then
                            TemporalFilterString="_hp${HighpassFilter}"
                        fi

                        RegString=""
                        if [[ "$RegName" != "NONE" ]]; then
                            RegString="_${RegName}"
                        fi

                        ProcSuffix=""
                        if [[ "$ProcSTRING" != "NONE" && -n "$ProcSTRING" ]]; then
                            ProcSuffix="_${ProcSTRING#_}"
                        fi

                        DesignString=""
                        if [[ "$FsfDesign" != "NONE" && -n "$FsfDesign" ]]; then
                            DesignString="_${FsfDesign}"
                        fi

                        ParcellationString=""
                        if [[ "$Parcellation" != "NONE" ]]; then
                            ParcellationString="_${Parcellation}"
                        fi

                        FeatName="${LevelTwoFSF}${DesignString}${TemporalFilterString}_s${FinalSmoothingFWHM}_level2${RegString}${ProcSuffix}${ParcellationString}.feat"

                        # Exclude subjects with a missing task folder
                        AvailableSubjects=()
                        ExcludedSubjects=()
                        for CandidateSubject in "${Subjects[@]}"; do
                            FeatDir="${StudyFolder}/${CandidateSubject}/MNINonLinear/Results/${LevelTwoTask}/${FeatName}"
                            if [[ -d "$FeatDir" ]]; then
                                AvailableSubjects+=("$CandidateSubject")
                            else
                                ExcludedSubjects+=("$CandidateSubject")
                                echo "ERROR: ${LevelTwoTask}: excluding ${CandidateSubject}; missing Level2 FEAT directory: ${FeatDir}" >&2
                            fi
                        done
                        NumSubjects=${#AvailableSubjects[@]}

                        if (( NumSubjects < 2 )); then
                            echo "ERROR: ${LevelTwoTask}: only ${NumSubjects} subjects available; skipping analysis" >&2
                            i=$((i + 1))
                            continue
                        fi
                        SubjectList=$(IFS=@; 
                        echo "${AvailableSubjects[*]}")

                        ExcludedSubjectList="NONE"
                        if (( ${#ExcludedSubjects[@]} > 0 )); then
                            ExcludedSubjectList=$(IFS=@; echo "${ExcludedSubjects[*]}")
                        fi

                        echo "Running Level 3: ${LevelTwoTask}, ${NumSubjects}/${RequestedNumSubjects} subjects"
                        "${HCPPIPEDIR}/global/scripts/captureoutput.sh" \
                            "${HCPPIPEDIR}/TaskfMRIAnalysis/TaskfMRILevel3.sh" \
                            --excluded-subjectlist="$ExcludedSubjectList" \
                            --level2-feat-name="$FeatName" \
                            --path="$StudyFolder" \
                            --subjectlist="$SubjectList" \
                            --groupfolder="$LevelThreeOutputFolder" \
                            --lvl2task="$LevelTwoTask" \
                            --lvl2fsf="$LevelTwoFSF" \
                            --fsf-design="$FsfDesign" \
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
done


echo "TaskfMRIAnalysisBatch complete"