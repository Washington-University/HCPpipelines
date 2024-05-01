#!/bin/bash 

get_usage_and_exit(){
    echo "usage: "
    echo "FreeSurferPipelineBatch.sh --Subject <experiment list, space separated> [options]"
    echo "options:"
    echo "  --StudyFolder <study folder>    root processing directory [/media/myelin/brainmappers/Connectome_Project/MishaLongitudinal/hcp]"
    echo "  --runlocal                      run locally [TRUE]"
    exit -1
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

StudyFolder="/media/myelin/brainmappers/Connectome_Project/MishaLongitudinal/hcp/FSLong-test" #Location of Subject folders (named by subjectID)
#Subjlist="100307" #Space delimited list of subject IDs
Subjlist="HCA6002236"
TPlist="HCA6002236_V1_MR@HCA6002236_V2_MR" #time point list, @ separated.
Template_ID="HCA6002236_V1_V2"

IFS=@ read -ra TPlist_arr <<< "$TPlist"

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

########################################## INPUTS ########################################## 

#Scripts called by this script do assume they run on the outputs of the PreFreeSurfer Pipeline

######################################### DO WORK ##########################################

for Subject in $Subjlist ; do
  echo $Subject

  #Input Variables
  SubjectID="$Subject" #FreeSurfer Subject ID Name
  SubjectDIR="${StudyFolder}/${Subject}/T1w" #Location to Put FreeSurfer Subject's Folder
  T1wImage="${StudyFolder}/${Subject}/T1w/T1w_acpc_dc_restore.nii.gz" #T1w FreeSurfer Input (Full Resolution)
  T1wImageBrain="${StudyFolder}/${Subject}/T1w/T1w_acpc_dc_restore_brain.nii.gz" #T1w FreeSurfer Input (Full Resolution)
  T2wImage="${StudyFolder}/${Subject}/T1w/T2w_acpc_dc_restore.nii.gz" #T2w FreeSurfer Input (Full Resolution)

  if [[ "${command_line_specified_run_local}" == "TRUE" || "$QUEUE" == "" ]] ; then
      echo "About to locally run ${HCPPIPEDIR}/FreeSurfer/LongitudinalFreeSurferPipeline.sh"
      #NOTE: fsl_sub without -q runs locally and captures output in files
      queuing_command=("$FSLDIR/bin/fsl_sub")
  else
      echo "About to use fsl_sub to queue ${HCPPIPEDIR}/FreeSurfer/LongitudinalFreeSurferPipeline.sh"
      queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE")
  fi
#DO NOT PUT timepoint-specific file options here!!!
  echo "${queuing_command[@]}" "$HCPPIPEDIR"/FreeSurfer/LongitudinalFreeSurferPipeline.sh --subject="$Subject" --path="$StudyFolder" --sessions "$TPlist" --template-id "$Template_ID" --extra-reconall-arg-long=-T2pial --extra-reconall-arg-long=-conf2hires --extra-reconall-arg-base=-T2pial --extra-reconall-arg-base=-T2 --extra-reconall-arg-base=$StudyFolder/${TPlist_arr[0]}/T1w/T2w_acpc_dc_restore.nii.gz --generate_timepoints_only=0 --generate_template_only=0
  #--extra-reconall-arg-base=-conf2hires Freesurfer reports this is unneeded.
  
  "${queuing_command[@]}" "$HCPPIPEDIR"/FreeSurfer/LongitudinalFreeSurferPipeline.sh --subject="$Subject" --path="$StudyFolder" --sessions "$TPlist" --template-id "$Template_ID" --extra-reconall-arg-long=-T2pial --extra-reconall-arg-long=-conf2hires --extra-reconall-arg-base=-T2pial --extra-reconall-arg-base=-T2 --extra-reconall-arg-base=$StudyFolder/${TPlist_arr[0]}/T1w/T2w_acpc_dc_restore.nii.gz --generate_timepoints_only=0 --generate_template_only=0

  # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...
  # echo set --subject=$Subject --subjectDIR=$SubjectDIR --t1=$T1wImage --t1brain=$T1wImageBrain --t2=$T2wImage --extra-reconall-arg-long="-i \"$SubjectDIR\"/T1w/T1w_acpc_dc_restore.nii.gz -emregmask \"$SubjectDIR\"/T1w/T1w_acpc_dc_restore_brain.nii.gz -T2 $SubjectDIR\"/T1w/T2w_acpc_dc_restore.nii.gz -T2pial"
  #echo ". ${EnvironmentScript}"

done

