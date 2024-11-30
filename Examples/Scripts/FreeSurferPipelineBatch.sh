#!/bin/bash 

get_batch_options() {
    local arguments=("$@")

    command_line_specified_study_folder=""
    command_line_specified_session=""
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
            --Subject=*) #legacy option, please use '--Session' instead
                command_line_specified_session=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --Session=*)
                command_line_specified_session=${argument#*=}
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

StudyFolder="${HOME}/projects/Pipelines_ExampleData" #Location of Session folders (named by sessionID) 
Sessionlist="100307 100610" #Space delimited list of session IDs 
EnvironmentScript="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script 

if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi

if [ -n "${command_line_specified_session}" ]; then
    Sessionlist="${command_line_specified_session}"
fi

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

for Session in $Sessionlist ; do
  echo $Session

  #Input Variables
  SessionID="$Session" #FreeSurfer Subject ID Name
  SessionDIR="${StudyFolder}/${Session}/T1w" #Location to Put FreeSurfer Subject's Folder
  T1wImage="${StudyFolder}/${Session}/T1w/T1w_acpc_dc_restore.nii.gz" #T1w FreeSurfer Input (Full Resolution)
  T1wImageBrain="${StudyFolder}/${Session}/T1w/T1w_acpc_dc_restore_brain.nii.gz" #T1w FreeSurfer Input (Full Resolution)
  T2wImage="${StudyFolder}/${Session}/T1w/T2w_acpc_dc_restore.nii.gz" #T2w FreeSurfer Input (Full Resolution)

  if [[ "${command_line_specified_run_local}" == "TRUE" || "$QUEUE" == "" ]] ; then
      echo "About to locally run ${HCPPIPEDIR}/FreeSurfer/FreeSurferPipeline.sh"
      queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
  else
      echo "About to use fsl_sub to queue ${HCPPIPEDIR}/FreeSurfer/FreeSurferPipeline.sh"
      queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE")
  fi

  "${queuing_command[@]}" "$HCPPIPEDIR"/FreeSurfer/FreeSurferPipeline.sh \
      --session="$Session" \
      --session-dir="$SessionDIR" \
      --t1w-image="$T1wImage" \
      --t1w-brain="$T1wImageBrain" \
      --t2w-image="$T2wImage"
      
  # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...

  echo "set -- --session=$Session \
      --session-dir=$SessionDIR \
      --t1w-image=$T1wImage \
      --t1w-brain=$T1wImageBrain \
      --t2w-image=$T2wImage"

  echo ". ${EnvironmentScript}"

done

