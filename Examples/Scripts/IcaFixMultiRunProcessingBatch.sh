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
	local scriptName=$(basename "${0}")
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

	while [[ ${index} -lt ${numArgs} ]]
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
	if [[ -z ${StudyFolder} ]]
	then
		echo "ERROR: StudyFolder not specified"
		exit 1
	fi

	if [[ -z ${Subjlist} ]]
	then
		echo "ERROR: Subjlist not specified"
		exit 1
	fi

	if [[ -z ${EnvironmentScript} ]]
	then
		echo "ERROR: EnvironmentScript not specified"
		exit 1
	fi

	if [[ -z ${RunLocal} ]]
	then
		echo "ERROR: RunLocal is an empty string"
		exit 1
	fi

	# report options
	echo "-- ${scriptName}: Specified Command-Line Options: -- Start --"
	echo "   StudyFolder: ${StudyFolder}"
	echo "   Subjlist: ${Subjlist}"
	echo "   EnvironmentScript: ${EnvironmentScript}"
	if [[ ! -z ${FixDir} ]]
	then
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
	source "${EnvironmentScript}"

	# MPH: If DEFAULT_FIXDIR is set, or --FixDir argument was used, then use that to
	# override the setting of FSL_FIXDIR in EnvironmentScript
	if [[ ! -z ${FixDir} ]]; then
		export FSL_FIXDIR=${FixDir}
	fi

	# set list of runs to concatenate for MR FIX
	fMRINamesSTRING="rfMRI_REST1_LR@rfMRI_REST1_RL@rfMRI_REST2_LR@rfMRI_REST2_RL"
	
	# an arbitrary name for this concatenation, to not collide with other runs or MR FIX concatenations
	ConcatNames="rfMRI_CONCAT_REST"

	# set temporal highpass full-width (2*sigma) to use, in seconds
	#0 for linear detrend
	highpass=0

	# set whether or not to regress motion parameters (24 regressors)
	# out of the data as part of FIX (TRUE or FALSE)
	domot=FALSE
	
	# set training data file
	TrainingData="HCP_hp2000.RData"

	# set FIX threshold (controls sensitivity/specificity tradeoff)
	FixThreshold=10
	
	# select specific version of hcp_fix to use
	# here, we use the one supplied with the HCPpipelines (which is extended
	# relative to the version provided with the FIX distribution)
	FixScript="${HCPPIPEDIR}/ICAFIX/hcp_fix_multi_run"

	# establish queue for job submission
	QUEUE="hcp_priority.q"

	for Subject in ${Subjlist}
	do
		echo ${Subject}
		
		i=1
		for ConcatName in ${ConcatNames}
		do
			fMRINames=`echo ${fMRINamesSTRING} | cut -d " " -f ${i} | sed 's/@/ /g'`
			Files=""
			for fMRIName in ${fMRINames} ; do
				Files=`echo "${Files}${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}.nii.gz@"`	
				## @ sign is sort of making a list of files to be passed 
				## The files are not being concatenated as of yet.
			done

		    FixCmd=("${FixScript}" "${Files}" ${highpass} "${ConcatName}" ${domot} "${TrainingData}" ${FixThreshold})
			if [[ "${RunLocal}" == "TRUE" ]]
			then
				queuing_command=()
				echo "About to run ${FixCmd[*]}"
			else
				queuing_command=("${FSLDIR}/bin/fsl_sub" -q "${QUEUE}")
				echo "About to use ${queuing_command[*]} to run ${FixCmd[*]}"
			fi

			"${queuing_command[@]}" "${FixCmd[@]}"
			((++i))
		done
	done
}  # main()

#
# Invoke the main function to get things started
#
main "$@"

