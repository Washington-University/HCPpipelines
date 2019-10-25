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

StudyFolder="${HOME}/projects/Pipelines_ExampleData" #Location of Subject folders (named by subjectID)
Subjlist="100307" #Space delimited list of subject IDs
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

# This script runs on the outputs from ICAFIX

######################################### DO WORK ##########################################

# List of fMRI runs
# If running on output from multi-run FIX, use ConcatName as value for fMRINames
fMRINames="rfMRI_REST1_LR rfMRI_REST1_RL rfMRI_REST2_LR rfMRI_REST2_RL"

HighPass="2000"
ReUseHighPass="NO" #Use YES if running on output from multi-run FIX, otherwise use NO

DualScene=${HCPPIPEDIR}/ICAFIX/PostFixScenes/ICA_Classification_DualScreenTemplate.scene
SingleScene=${HCPPIPEDIR}/ICAFIX/PostFixScenes/ICA_Classification_SingleScreenTemplate.scene

MatlabMode="1" #Mode=0 compiled Matlab, Mode=1 interpreted Matlab, Mode=2 octave

for Subject in $Subjlist ; do
  for fMRIName in ${fMRINames} ; do
	  echo "    ${Subject}"
	
	  if [ -n "${command_line_specified_run_local}" ] ; then
	      echo "About to run ${HCPPIPEDIR}/ICAFIX/PostFix.sh"
	      queuing_command=""
	  else
	      echo "About to use fsl_sub to queue or run ${HCPPIPEDIR}/ICAFIX/PostFix.sh"
	      queuing_command="${FSLDIR}/bin/fsl_sub ${QUEUE}"
	  fi

	  ${queuing_command} ${HCPPIPEDIR}/ICAFIX/PostFix.sh \
    --study-folder=${StudyFolder} \
    --subject=${Subject} \
    --fmri-name=${fMRIName} \
    --high-pass=${HighPass} \
    --template-scene-dual-screen=${DualScene} \
    --template-scene-single-screen=${SingleScene} \
    --reuse-high-pass=${ReUseHighPass} \
    --matlab-run-mode=${MatlabMode}
  done
done

