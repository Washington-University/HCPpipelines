#!/bin/bash

#!/bin/bash 

get_batch_options() {
    local arguments=("$@")

    unset command_line_specified_study_folder
    unset command_line_specified_subj
    unset command_line_specified_run_local

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

StudyFolder="/media/myelin/brainmappers/Connectome_Project/HCP_PhaseFinalTesting" #Location of Subject folders (named by subjectID)
Subjlist="100307" #Space delimited list of subject IDs
EnvironmentScript="/media/myelin/brainmappers/Connectome_Project/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi

if [ -n "${command_line_specified_subj}" ]; then
    Subjlist="${command_line_specified_subj}"
fi

# Requirements for this script
#  installed versions of: FSL (version 5.0.6)
#  environment: FSLDIR , HCPPIPEDIR , CARET7DIR 

#Set up pipeline environment variables and software
source ${EnvironmentScript}

# Log the originating call
echo "$@"

#if [ X$SGE_ROOT != X ] ; then
#    QUEUE="-q long.q"
    QUEUE="-q long.q"
#fi

PRINTCOM=""
#PRINTCOM="echo"

########################################## INPUTS ########################################## 

#Scripts called by this script do assume they run on the results of the HCP minimal preprocesing pipelines from Q2

######################################### DO WORK ##########################################

fMRINames="tfMRI_WM_GAMBLING_MOTOR_LR tfMRI_WM_GAMBLING_MOTOR_RL tfMRI_LANGUAGE_SOCIAL_RELATIONAL_EMOTION_LR tfMRI_LANGUAGE_SOCIAL_RELATIONAL_EMOTION_RL"

HighPass="2000"
ReUseHighPass="YES"

DualScene=${HCPPIPEDIR}/PostFix/PostFixScenes/ICA_Classification_DualScreenTemplate.scene
SingleScene=${HCPPIPEDIR}/PostFix/PostFixScenes/ICA_Classification_SingleScreenTemplate.scene

MatlabMode="1" #Mode=0 compiled Matlab, Mode=1 interpreted Matlab
#MatlabMode="0" #Mode=0 compiled Matlab, Mode=1 interpreted Matlab

for Subject in $Subjlist ; do
  for fMRIName in ${fMRINames} ; do
	  echo "    ${Subject}"
	
	  if [ -n "${command_line_specified_run_local}" ] ; then
	      echo "About to run ${HCPPIPEDIR}/PostFix/PostFix.sh"
	      queuing_command=""
	  else
	      echo "About to use fsl_sub to queue or run ${HCPPIPEDIR}/PostFix/PostFix.sh"
	      queuing_command="${FSLDIR}/bin/fsl_sub ${QUEUE}"
	  fi

	  ${queuing_command} ${HCPPIPEDIR}/PostFix/PostFix.sh \
    --study-folder=${StudyFolder} \
    --subject=${Subject} \
    --fmri-names=${fMRIName} \
    --highpass=${HighPass} \
    --template-scene-dual-screen=${DualScene} \
    --template-scene-single-screen=${SingleScene} \
    --reuse-high-pass=${ReUseHighPass} \
    --matlab-run-mode=${MatlabMode}
  done
done

