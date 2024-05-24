#!/bin/bash
#set -xv

# Global default values
DEFAULT_STUDY_FOLDER="${HOME}/data/Pipelines_ExampleData"
DEFAULT_SUBJECT_LIST="100307 100610"
DEFAULT_ENVIRONMENT_SCRIPT="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh"
DEFAULT_RUN_LOCAL="FALSE"

#
# Function Description
#	Get the command line options for this script
#
# Global Output Variables
#	${StudyFolder}			- Path to folder containing all subjects data in subdirectories named 
#							  for the subject id
#	${Subjlist}				- Space delimited list of subject IDs
#	${EnvironmentScript}	- Script to source to setup pipeline environment
#	${RunLocal}				- Indication whether to run this processing "locally" i.e. not submit
#							  the processing to a cluster or grid
#
get_options() {
	local scriptName=$(basename ${0})
	local arguments=("$@")

	# initialize global output variables
	StudyFolder="${DEFAULT_STUDY_FOLDER}"
	Subjlist="${DEFAULT_SUBJECT_LIST}"
	EnvironmentScript="${DEFAULT_ENVIRONMENT_SCRIPT}"
	RunLocal="${DEFAULT_RUN_LOCAL}"

	# parse arguments
	local index=0
	local numArgs=${#arguments[@]}
	local argument

	while [ ${index} -lt ${numArgs} ]
	do
		argument=${arguments[index]}

		case ${argument} in
			--StudyFolder=*)
				StudyFolder=${argument#*=}
				index=$(( index + 1 ))
				;;
			--Subject=*)
				Subjlist=${argument#*=}
				index=$(( index + 1 ))
				;;
			--EnvironmentScript=*)
				EnvironmentScript=${argument#*=}
				index=$(( index + 1 ))
				;;
			--runlocal | --RunLocal)
				RunLocal="TRUE"
				index=$(( index + 1 ))
				;;
			*)
				echo "ERROR: Unrecognized Option: ${argument}"
				exit 1
				;;
		esac
	done

	# check required parameters
	if [ -z ${StudyFolder} ]
	then
		echo "ERROR: StudyFolder not specified"
		exit 1
	fi

	if [ -z "${Subjlist}" ]
	then
		echo "ERROR: Subjlist not specified"
		exit 1
	fi

	if [ -z ${EnvironmentScript} ]
	then
		echo "ERROR: EnvironmentScript not specified"
		exit 1
	fi

	if [ -z ${RunLocal} ]
	then
		echo "ERROR: RunLocal is an empty string"
		exit 1
	fi

	# report options
	echo "-- ${scriptName}: Specified Command-Line Options: -- Start --"
	echo "   StudyFolder: ${StudyFolder}"
	echo "   Subjlist: ${Subjlist}"
	echo "   EnvironmentScript: ${EnvironmentScript}"
	echo "   RunLocal: ${RunLocal}"
	echo "-- ${scriptName}: Specified Command-Line Options: -- End --"
}  # get_options()

#
# Function Description
#	Main processing of this script
#
#	Gets user specified command line options and runs a batch of ReApplyFix processing
#
main() {
	# get command line options
	get_options "$@"

	# set up pipeline environment variables and software
	source "$EnvironmentScript"

	# set list of fMRI
	fMRINames="rfMRI_REST1_RL@rfMRI_REST1_LR@rfMRI_REST2_LR@rfMRI_REST2_RL"
  
	# specify the name of concatenated folder
	# if run Multi-Run specify ConcatNames as null string
	MRConcatfMRIName="rfMRI_REST"

	# set highpass
	highpass=2000
	
	# set resolution
	fMRIResolution="2"

	#run in singularity
	PythonSingularity="/path/to/singularity.img"
	PythonSingularityMountPath="/path/to/data" # where the data dir need to mount to the singularity
	PythonInterpreter=""

	#run in conda
	#PythonSingularity=""
	#PythonSingularityMountPath=""
	#PythonInterpreter="/my/conda/path/envs/hcp_python_env/bin/python3"

	# models to use
	Models="RandomForest@MLP@Xgboost@WeightedKNN@XgboostEnsemble"

	# set threshold
	VoteThresh="5" # the number stands for how many votes to finalze the classification, if there are 5 models, then vote threshold 5 means only reclassify when the 5 models all agree on the prediction

	#NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
	#DO NOT include "-q " at the beginning
	#default to no queue, implying run local
	QUEUE=""
	#QUEUE="long.q"

	# low res mesh
	LowResMesh=32

	if [[ "${RunLocal}" == "TRUE" || "$QUEUE" == "" ]]; then
		queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
	else
		queuing_command=("${FSLDIR}/bin/fsl_sub" -q "$QUEUE")
	fi

	for Subject in ${Subjlist}; do
		# if run via singularity
		"${queuing_command[@]}" "$HCPPIPEDIR"/ICAFIX/ApplyAutoRecleanPipeline.sh \
		--study-folder="$StudyFolder" \
		--subject="$Subject" \
		--fmri-names="$fMRINames" \
		--mrfix-concat-name="$MRConcatfMRIName" \
		--fix-high-pass="$highpass" \
		--fmri-resolution="$fMRIResolution" \
		--subject-expected-timepoints="$subjectExpectedTimepoints" \
		--low-res="$LowResMesh" \
		--python-singularity="$PythonSingularity" \
		--python-singularity-mount-path="$PythonSingularityMountPath" \
		--python-interpreter="$PythonInterpreter" \
		--model-to-use="$Models" \
		--vote-threshold="$VoteThresh"

	done
}  # main()

#
# Invoke the main function to get things started
#
main "$@"

