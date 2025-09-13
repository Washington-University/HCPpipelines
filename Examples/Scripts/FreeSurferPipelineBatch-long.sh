#!/bin/bash

command_line_specified_run_local=FALSE
while [ -n "$1" ]; do
    case "$1" in
        --runlocal) shift; command_line_specified_run_local=TRUE ;;
        *) shift ;;
    esac
done

#################################################################################################
# General input variables
##################################################################################################
#Location of Subject folders (named by subjectID)
StudyFolder="/my/study/path"
#The list of subject labels, space separated
Subjects=(HCA6002236 HCA6002237 HCA6002238)
#The list of possible visits (aka timepoints, sessions) that each subject may have. Timepoint directories should be named <Subject>_<Visit>.
PossibleVisits=(V1_MR V2_MR V3_MR)
#The list of possible visits that each subject may have. Timepoint (visit) is expected to be named <Subject>_<Visit>.
#Actual visits (timepoints) are determined based on existing directories that match the visit name pattern.
#ExcludeVisits=(HCA6002237_V1_MR HCA6002238_V1_MR)
ExcludeVisits=()
#Longitudinal template labels, one per each subject.
Templates=(HCA6002236_V1_V2 HCA6002237_V1_V2 HCA6002238_V1_V2)

EnvironmentScript="<HCPInstallDir>/scripts/SetUpHCPPipeline.sh" #Pipeline environment script

# Requirements for this script
#  installed versions of: FSL, FreeSurfer, Connectome Workbench (wb_command), gradunwarp (HCP version)
#  environment: HCPPIPEDIR, FSLDIR, FREESURFER_HOME, CARET7DIR, PATH for gradient_unwarp.py

# If you want to use FreeSurfer 5.3, change the ${queuing_command} line below to use
# ${HCPPIPEDIR}/FreeSurfer/FreeSurferPipeline-v5.3.0-HCP.sh

#Set up pipeline environment variables and software
source "$EnvironmentScript"

# Log the originating call
echo "$@"

#NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
#DO NOT include "-q " at the beginning
#default to no queue, implying run local
QUEUE="long.q"
#QUEUE="hcp_priority.q"

#parallel options
parallel_mode=BUILTIN

# This setting is for BUILTIN mode. Set to -1 to auto-detect the # of CPU cores on the node where each per-subject job is run.
# Note that in case when multiple subject jobs are run on the same node and are submitted 
# in parallel by e.g. fsl_sub, max_jobs should be set manually to not significantly exceed
# (number of available cores)/(number of subjects) in the batch. 
max_jobs=-1
#max_jobs=4

#TEMPLATE stage must be run before TIMEPOINTS stage
start_stage=TEMPLATE
end_stage=TIMEPOINTS

#Processing goes here.
function identify_timepoints
{
    local subject=$1
    local tplist=""
    local tp visit n

    #build the list of timepoints (sessions)
    n=0
    for session in ${PossibleVisits[*]}; do
        tp="${subject}_${session}"
        if [ -d "$StudyFolder/$tp" ] && ! [[ " ${ExcludeVisits[*]+${ExcludeVisits[*]}} " =~ [[:space:]]"$tp"[[:space:]] ]]; then
             if (( n==0 )); then 
                    tplist="$tp"
             else
                    tplist="$tplist@$tp"
             fi
        fi
        ((n++))
    done
    echo $tplist
}

########################################## INPUTS ########################################## 
#Scripts called by this script do assume they run on the outputs of the PreFreeSurfer Pipeline
######################################### DO WORK ##########################################

for i in ${!Subjects[@]}; do
  Subject=${Subjects[i]}
  #Subject's time point list, @ separated.  
  TPlist=(`identify_timepoints $Subject`)
  #Array with timepoints
  IFS=@ read -ra Timepoints <<< "$TPlist"
  #Freesurfer longitudinal average template label
  LongitudinalTemplate=${Templates[i]}

  #Longitudinal FreeSurfer Input Variables
  SubjectID="$Subject" #FreeSurfer Subject ID Name
  SubjectDIR="${StudyFolder}/${Subject}/T1w" #Location to Put FreeSurfer Subject's Folder
  T1wImage="${StudyFolder}/${Subject}/T1w/T1w_acpc_dc_restore.nii.gz" #T1w FreeSurfer Input (Full Resolution)
  T1wImageBrain="${StudyFolder}/${Subject}/T1w/T1w_acpc_dc_restore_brain.nii.gz" #T1w FreeSurfer Input (Full Resolution)
  T2wImage="${StudyFolder}/${Subject}/T1w/T2w_acpc_dc_restore.nii.gz" #T2w FreeSurfer Input (Full Resolution)

  if [ "$parallel_mode" != FSLSUB ]; then #fsl_sub does not allow nested submissions
    if [[ "${command_line_specified_run_local}" == "TRUE" || "$QUEUE" == "" ]] ; then
        echo "About to locally run ${HCPPIPEDIR}/FreeSurfer/LongitudinalFreeSurferPipeline.sh"
        #NOTE: fsl_sub without -q runs locally and captures output in files
        queuing_command=("$FSLDIR/bin/fsl_sub")
    else
        echo "About to use fsl_sub to queue ${HCPPIPEDIR}/FreeSurfer/LongitudinalFreeSurferPipeline.sh"
        queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE")
    fi
  else
    queuing_command=()
  fi

  #DO NOT PUT timepoint-specific options here!!!
  cmd=(${queuing_command[@]+"${queuing_command[@]}"} "$HCPPIPEDIR"/FreeSurfer/LongitudinalFreeSurferPipeline.sh \
    --subject="$Subject" \
    --path="$StudyFolder" \
    --sessions="$TPlist" \
    --fslsub-queue="$QUEUE" \
    --longitudinal-template="$LongitudinalTemplate" \
    --parallel-mode="$parallel_mode" \
    --max-jobs="$max_jobs" \
    --start-stage="$start_stage" \
    --end-stage="$end_stage" \
    )

  #--extra-reconall-arg-base=-conf2hires Freesurfer reports this is unneeded.
  echo "Running command: ${cmd[*]}"
  "${cmd[@]}"

  # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...
  # echo set --subject=$Subject --subjectDIR=$SubjectDIR --t1=$T1wImage --t1brain=$T1wImageBrain --t2=$T2wImage --extra-reconall-arg-long="-i \"$SubjectDIR\"/T1w/T1w_acpc_dc_restore.nii.gz -emregmask \"$SubjectDIR\"/T1w/T1w_acpc_dc_restore_brain.nii.gz -T2 $SubjectDIR\"/T1w/T2w_acpc_dc_restore.nii.gz -T2pial"
  #echo ". ${EnvironmentScript}"

done
