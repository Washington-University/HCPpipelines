#!/bin/bash 

get_usage_and_exit(){
    echo "usage: "
    echo "FreeSurferPipelineBatch.sh --Subject <experiment list, space separated> [options]"
    echo "options:"
    echo "  --StudyFolder <study folder>    root processing directory [/media/myelin/brainmappers/Connectome_Project/MishaLongitudinal/hcp]"
    echo "  --runlocal                      run locally [TRUE]"
    exit -1
}

any_job_running()
{
    local jobs="$1"
    local jobs_running=0
    for job in $jobs; do
        if [[ $(qstat | grep -w $job) ]]; then
            jobs_running=1; break; 
        fi
    done
    echo $jobs_running
}

get_batch_options() {
    local arguments=("$@")

    command_line_specified_study_folder=""
    command_line_specified_subj=""
    command_line_specified_run_local="TRUE"

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

StudyFolder="/media/myelin/brainmappers/Connectome_Project/MishaLongitudinal/hcp/FSLong-test"
#Subjlist="100307" #Space delimited list of subject IDs
Subjlist="HCA6002236"

#time point list, @ separated (within subject), space ceparated between subjects
#Example:
#TPlist="Subject1_TP1@Subject1_TP2 Subject2_TP1@Subject2_TP2"
Timepoints="HCA6002236_V1_MR@HCA6002236_V2_MR"
#Timepoints="HCA6002236_V1_MR"
Template_ID="HCA6002236_V1_V2"

# Hires T1w MNI template
T1wTemplate="${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm.nii.gz"

# Hires brain extracted MNI template1
T1wTemplateBrain="${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm_brain.nii.gz"

# Lowres T1w MNI template
T1wTemplate2mm="${HCPPIPEDIR_Templates}/MNI152_T1_2mm.nii.gz"

# Hires T2w MNI Template
T2wTemplate="${HCPPIPEDIR_Templates}/MNI152_T2_0.7mm.nii.gz"

# Hires T2w brain extracted MNI Template
T2wTemplateBrain="${HCPPIPEDIR_Templates}/MNI152_T2_0.7mm_brain.nii.gz"

# Lowres T2w MNI Template
T2wTemplate2mm="${HCPPIPEDIR_Templates}/MNI152_T2_2mm.nii.gz"

# Hires MNI brain mask template
TemplateMask="${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm_brain_mask.nii.gz"

# Lowres MNI brain mask template
Template2mmMask="${HCPPIPEDIR_Templates}/MNI152_T1_2mm_brain_mask_dil.nii.gz"

# FNIRT 2mm T1w Config
FNIRTConfig="${HCPPIPEDIR_Config}/T1_2_MNI152_2mm.cnf"

FreeSurferLabels="${HCPPIPEDIR_Config}/FreeSurferAllLut.txt"

EnvironmentScript="/media/myelin/brainmappers/Connectome_Project/MishaLongitudinal/hcp/scripts/SetUpHCPPipeline-long.sh" #Pipeline environment script

if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi

if [ -n "${command_line_specified_subj}" ]; then
    Subjlist="${command_line_specified_subj}"
fi

if [ -z "$StudyFolder" ]; then echo "No study folder specified"; get_usage_and_exit; fi
if [ -z "$Subjlist" ]; then echo "No experiments were specified"; get_usage_and_exit; fi

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
QUEUE=""
#QUEUE="hcp_priority.q"


######################################### DO WORK ##########################################

DEBUG=0
for (( i=0; i<${#Subjlist[@]}; i++ )); do
  Subject="${Subjlist[i]}"
  IFS='@' read -ra TPList <<< "${Timepoints[i]}"
  echo $Subject

  if [[ "${command_line_specified_run_local}" == "TRUE" || "$QUEUE" == "" ]] ; then
      echo "About to locally run ${HCPPIPEDIR}/PostFreeSurfer/PrePostFreeSurferPipeline-long.sh"
      #NOTE: fsl_sub without -q runs locally and captures output in files
      queuing_command=("$FSLDIR/bin/fsl_sub")
  else
      echo "About to use fsl_sub to queue ${HCPPIPEDIR}/PostFreesurfer/PrePostFreeSurferPipeline-long.sh"
      queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE")
  fi
  if (( DEBUG==0 )); then
  #process all timepoints
  job_list=()
  for TP in ${TPList[@]}; do
	echo "Running ppFS-long for timepoint: $TP"
        job=$($queueing_command ${HCPPIPEDIR}/PostFreeSurfer/PostFreesurferPipelineLongPrep.sh --subject="$Subject" --path="$StudyFolder" \
            --template="$Template_ID" --timepoints="$TP" --template_processing=0 --t1template="$T1wTemplate" \
            --t1templatebrain="$T1wTemplateBrain" --t1template2mm="$T1wTemplate2mm" --t2template="T2wTemplate" \
            --t2templatebrain="$T2wTemplateBrain" --t2template2mm="$T2wTemplate2mm" --templatemask="$TemplateMask" \
            --template2mmmask="$Template2mmMask" --fnirtconfig="$FNIRTConfig" --freesurferlabels="$FreeSurferLabels")
        job_id=${job##* }
        job_list+=($job_id)
	if (( $? )); then 
		echo "Timepoint processing for $Subject failed, exiting"
		exit -1
	fi
  done
  fi

  echo "Waiting for timepoint processing"
  while true; do
    jobs_running=`any_job_running "${job_list[@]}"`
    if (( jobs_running == 0 )); then break;
    sleep 10
  done

  echo "Timepoint processing done"
  #Process template and finalize timepoints. This must wait until all timepoints are finished.
  echo "Running ppFS-long for template $Template"
  $queueing_command ${HCPPIPEDIR}/PostFreeSurfer/PostFreesurferPipelineLongPrep.sh --subject="$Subject" --path="$StudyFolder" \
	--template="$Template_ID" --timepoints="${Timepoints[i]}" --template_processing=1 --t1template="$T1wTemplate" \
        --t1templatebrain="$T1wTemplateBrain" --t1template2mm="$T1wTemplate2mm" --t2template="T2wTemplate" \
        --t2templatebrain="$T2wTemplateBrain" --t2template2mm="$T2wTemplate2mm" --templatemask="$TemplateMask" \
        --template2mmmask="$Template2mmMask" --fnirtconfig="$FNIRTConfig" --freesurferlabels="$FreeSurferLabels"
done
