#!/bin/bash

# Global default values
DEFAULT_STUDY_FOLDER="${HOME}/data/7T_Testing"
DEFAULT_SUBJECT_LIST="100307"
DEFAULT_ENVIRONMENT_SCRIPT="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh"
DEFAULT_RUN_LOCAL="FALSE"
DEFAULT_FIX_DIR="${HOME}/tools/fix1.06"

#
# Function Description
#	Get the command line options for this script
#
# Global Output Variables
#	${StudyFolder}			- Path to folder containing all subjects data in subdirectories named 
#							  for the subject id
#	${Subjlist}				- Space delimited list of subject IDs
#	${EnvironmentScript}	- Script to source to setup pipeline environment
#	${FixDir}				- Directory containing FIX
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
	FixDir="${DEFAULT_FIX_DIR}"
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
			--FixDir=*)
				FixDir=${argument#*=}
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

	if [ -z ${Subjlist} ]
	then
		echo "ERROR: Subjlist not specified"
		exit 1
	fi

	if [ -z ${EnvironmentScript} ]
	then
		echo "ERROR: EnvironmentScript not specified"
		exit 1
	fi

	if [ -z ${FixDir} ]
	then
		echo "ERROR: FixDir not specified"
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
	echo "   FixDir: ${FixDir}"
	echo "   RunLocal: ${RunLocal}"
	echo "-- ${scriptName}: Specified Command-Line Options: -- End --"
}

#
# Function Description
#	Main processing of this script
#
#	Gets user specified command line options and runs a batch of ICA+FIX processing
#
main() {
	# get command line options
	get_options "$@"

	# set up pipeline environment variables and software
	source "$EnvironmentScript"

	export FSL_FIXDIR=${FixDir}
	FixScript=${HCPPIPEDIR}/ICAFIX/hcp_fix
	TrainingData=HCP7T_hp2000.RData

	# validate environment variables
	# validate_environment_vars $@

	#NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
	#DO NOT include "-q " at the beginning
	#default to no queue, implying run local
	QUEUE=""
	#QUEUE="hcp_priority.q"

	# establish list of runs on which to run ICA+FIX
	fmriList=()
	fmriList+=(rfMRI_REST1_7T_PA)
	fmriList+=(rfMRI_REST2_7T_AP)
	fmriList+=(rfMRI_REST3_7T_PA)
	fmriList+=(rfMRI_REST4_7T_AP)

	for Subject in ${Subjlist}
	do
		echo ${Subject}

		for fmri in "${fmriList[@]}"
		do
			echo "  ${fmri}"
			
			InputDir="${StudyFolder}/${Subject}/MNINonLinear/Results/${fmri}"
			InputFile="${InputDir}/${fmri}.nii.gz"

			bandpass=2000
			
			if [[ "$RunLocal" == "TRUE" || "$QUEUE" == "" ]]
			then
				echo "About to locally run ${FixScript} ${InputFile} ${bandpass} ${TrainingData}"
				queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
			else
				echo "About to use fsl_sub to queue ${FixScript} ${InputFile} ${bandpass} ${TrainingData}"
				queuing_command=("${FSLDIR}/bin/fsl_sub" -q "$QUEUE")
			fi

			"${queuing_command[@]}" "$FixScript" "$InputFile" "$bandpass" "$TrainingData"
		done

	done
}

#
# Invoke the main function to get things started
#
main "$@"

