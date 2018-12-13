#!/bin/bash

# Global default values
DEFAULT_STUDY_FOLDER="${HOME}/data/Pipelines_ExampleData"
DEFAULT_SUBJECT_LIST="100307"
DEFAULT_ENVIRONMENT_SCRIPT="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh"
DEFAULT_RUN_LOCAL="FALSE"
#DEFAULT_FIXDIR="${HOME}/tools/fix1.06"  ##OPTIONAL: If not set will use $FSL_FIXDIR specified in EnvironmentScript

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
	FixDir="${DEFAULT_FIXDIR}"
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

	# MPH: Allow FixDir to be empty at this point, so users can take advantage of the FSL_FIXDIR setting
	# already in their EnvironmentScript
#    if [ -z ${FixDir} ]
#    then
#        echo "ERROR: FixDir not specified"
#        exit 1
#    fi

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
	if [ ! -z ${FixDir} ]; then
		echo "   FixDir: ${FixDir}"
	fi
	echo "   RunLocal: ${RunLocal}"
	echo "-- ${scriptName}: Specified Command-Line Options: -- End --"
}  # get_options()

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
	source ${EnvironmentScript}

	# MPH: If DEFAULT_FIXDIR is set, or --FixDir argument was used, then use that to
	# override the setting of FSL_FIXDIR in EnvironmentScript
	if [ ! -z ${FixDir} ]; then
		export FSL_FIXDIR=${FixDir}
	fi

	# Use the version of hcp_fix supplied with the HCPpipelines (which is extended
	# relative to the version provided with the FIX distribution)
	FixScript=${HCPPIPEDIR}/ICAFIX/hcp_fix

	# establish temporal highpass full-width (2*sigma) to use, in seconds
	bandpass=2000

	# establish training data file
	TrainingData=HCP_hp2000.RData
	
	# establish whether or not to regress motion parameters (24 regressors)
	# out of the data as part of FIX (TRUE or FALSE)
	domot=FALSE
	
	# establish list of conditions on which to run ICA+FIX
	CondList="rfMRI_REST1 rfMRI_REST2"

	# establish list of directions on which to run ICA+FIX
	DirectionList="RL LR"

	# establish queue for job submission
	QUEUE="-q hcp_priority.q"

	for Subject in ${Subjlist}
	do
		echo ${Subject}

		for Condition in ${CondList}
		do
			echo "  ${Condition}"

			for Direction in ${DirectionList}
			do
				echo "    ${Direction}"
				
				InputDir="${StudyFolder}/${Subject}/MNINonLinear/Results/${Condition}_${Direction}"
				InputFile="${InputDir}/${Condition}_${Direction}.nii.gz"

				if [ "${RunLocal}" == "TRUE" ]
				then
					queuing_command=""
					echo "About to run ${FixScript} ${InputFile} ${bandpass} ${domot} ${TrainingData}"
				else
					queuing_command="${FSLDIR}/bin/fsl_sub ${QUEUE}"
					echo "About to use ${queuing_command} to run ${FixScript} ${InputFile} ${bandpass} ${domot} ${TrainingData}"
				fi

				${queuing_command} ${FixScript} ${InputFile} ${bandpass} ${domot} ${TrainingData}
			done

		done

	done
}  # main()

#
# Invoke the main function to get things started
#
main $@

