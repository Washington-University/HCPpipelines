#!/bin/bash 

get_batch_options() {
    local arguments=("$@")

    command_line_specified_study_folder=""
    command_line_specified_subject=""
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
                command_line_specified_subject=${argument#*=}
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

StudyFolder="${HOME}/projects/Pipelines_ExampleData" #Location of Subject folders (named by SubjectID) 
Subjlist="100307 100610" #Space delimited list of subject IDs 
EnvironmentScript="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script 

if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi

if [ -n "${command_line_specified_subject}" ]; then
    Subjlist="${command_line_specified_subject}"
fi

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

#Scripts called by this script do assume they run on the outputs of the PostFreeSurfer Pipeline

######################################### DO WORK ##########################################

for Subject in $Subjlist ; do
  echo $Subject

  if [[ "${command_line_specified_run_local}" == "TRUE" || "$QUEUE" == "" ]] ; then
      echo "About to locally run ${HCPPIPEDIR}/HippUnfoldHCP/HippUnfoldHCP.sh"
      queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
  else
      echo "About to use fsl_sub to queue ${HCPPIPEDIR}/HippUnfoldHCP/HippUnfoldHCP.sh"
      queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE")
  fi

  "${queuing_command[@]}" "$HCPPIPEDIR"/HippUnfoldHCP/HippUnfoldHCP.sh \
      --study-folder="$StudyFolder" \
      --subject="$Subject" \
      
  # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...

  echo "set -- --study-folder=$StudyFolder \
      --subject=$Subject" \

  echo ". ${EnvironmentScript}"

done
