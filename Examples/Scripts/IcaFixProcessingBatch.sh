#!/bin/bash

# Global default values
DEFAULT_STUDY_FOLDER="${HOME}/data/HCPpipelines_ExampleData"
DEFAULT_SUBJECT_LIST="100307 100610"
DEFAULT_ENVIRONMENT_SCRIPT="${HOME}/projects/HCPpipelines/Examples/Scripts/SetUpHCPPipeline.sh"
DEFAULT_RUN_LOCAL="FALSE"
#DEFAULT_FIXDIR="${HOME}/tools/fix1.06"  ##OPTIONAL: If not set will use $FSL_FIXDIR specified in EnvironmentScript (pyfix recommended, leave unset)

#
# Function Description
#	Get the command line options for this script
#
# Global Output Variables
#	${StudyFolder}			- Path to folder containing all subjects data in subdirectories named 
#							  for the subject id
#	${Subjlist}				- Space delimited list of subject IDs
#	${EnvironmentScript}	- Script to source to setup pipeline environment
#	${FixDir}				- Directory containing FIX (pyfix is recommended, leave unset)
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

    # Note that pyfix is recommended not legacy R FIX, as pyfix is more accurate and easier to use, leave commented out.
	# MPH: Allow FixDir to be empty at this point, so users can take advantage of the FSL_FIXDIR setting
	# already in their EnvironmentScript
#	if [ -z ${FixDir} ]
#	then
#		echo "ERROR: FixDir not specified"
#		exit 1
#	fi

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
	source "$EnvironmentScript"

    # Note that pyfix is recommended not legacy R FIX, as pyfix is more accurate and easier to use.
	# MPH: If DEFAULT_FIXDIR is set, or --FixDir argument was used, then use that to
	# override the setting of FSL_FIXDIR in EnvironmentScript
	if [ ! -z ${FixDir} ]; then
		export FSL_FIXDIR=${FixDir}
	fi

	# "Multi-run" (concatenated) spatial ICA FIX is recommended and "single-run" spatial ICA FIX is deprecated. 
	# Most commonly, all fMRI runs are combined in a single Multi-run fix denoising effort delimited by @,
	# but if separate concatinated run groups are needed (e.g., very large amounts of fMRI acquired over several days), 
	# separate those groups with %. Runs delimited by spaces will call single run spatial ICA FIX.
	fMRINames="tfMRI_WM_RL@tfMRI_WM_LR@tfMRI_GAMBLING_RL@tfMRI_GAMBLING_LR@tfMRI_MOTOR_RL@tfMRI_MOTOR_LR%tfMRI_LANGUAGE_RL@tfMRI_LANGUAGE_LR@tfMRI_SOCIAL_RL@tfMRI_SOCIAL_LR@tfMRI_RELATIONAL_RL@tfMRI_RELATIONAL_LR@tfMRI_EMOTION_RL@tfMRI_EMOTION_LR"

	# Provide a name (or names) for concatinated outputs with multiple names delimited by @. 
	# Single run spatial ICA FIX requires a blank ConcatNames="" variable.
	ConcatNames="tfMRI_WM_GAMBLING_MOTOR_RL_LR@tfMRI_LANGUAGE_SOCIAL_RELATIONAL_EMOTION_RL_LR"

	# A linear detrend "0" or "pd1" is recommended for multi-run spatial ICA FIX for short or medium length runs.
	# For very long continuous runs (e.g., 1 hour or more) phantom studies may indicate asymptotic heating behavior.
	# Such nonlinear trends can be removed with "pd2" (quadractic).
	# Higher order linear detrends "pdX" for a polynomial detrend of order X should only be used with evidence from phantom studies.
	# Temporal highpass can be set with full-width (2*sigma) to use, in seconds, however, this is not recommended.
	# Highpass filters are non-selective (affect both signal and artifacts) and may make ICA less able to separate signal and artifacts.
    # Single run FIX requires bandpass=2000
	bandpass=0

	# 24 movement parameter regression is no longer recommended and has been removed from all current HCP data releases.
	# Movement parameter regression was found to only remove neural signal of interest above and beyond 
	# spatial ICA cleanup (Glasser et al., 2019 Neuroimage; Supplemental).
	domot=FALSE #(TRUE or FALSE)

	# The ICA method controls whether ICA is run once (MELODIC) or many times (ICASSO)
	# ICASSO is much more computationally intensive, particularly when many components are found,
	# but may be helpful in more challenging datasts (e.g., non-human primates).
	ICAmethod=MELODIC
	
	# set the training data used in multi-run fix mode
	MRTrainingData=HCP_Style_Single_Multirun_Dedrift.RData

	# set the training data used in single-run fix mode (not recommended)
	# SRTrainingData=HCP_hp2000.RData
	
	# set FIX threshold (controls sensitivity/specificity tradeoff)
	# 50 means set the cutoff at 0.5 probability signal/artifact, which will be most accurate;
	# however, excluding signal is typically considered a much worse error than including artifact,
	# so the Fix threshold is typically set to 10.
	FixThreshold=10
	
	#delete highpass files (note that delete intermediates=TRUE is not recommended for MR+FIX)
	DeleteIntermediates=FALSE

	#for multi-run only, 0=compiled, 1=interpreted, 2=octave
	MatlabMode=1
	
	#MR FIX config support for non-HCP settings
	config=""
	processingmode="HCPStyleData"
	#uncomment the below two lines for legacy-style data
	#config="$HCPPIPEDIR"/ICAFIX/config/legacy.conf
	#processingmode="LegacyStyleData"
	
	#NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
	#DO NOT include "-q " at the beginning
	#default to no queue, implying run local
	QUEUE=""
	#QUEUE="hcp_priority.q"
	
	if [[ "$RunLocal" == "TRUE" || "$QUEUE" == "" ]]; then
		queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
	else
		queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE")
	fi

	for Subject in ${Subjlist}; do
		echo ${Subject}

		ResultsFolder="${StudyFolder}/${Subject}/MNINonLinear/Results"

		#Uncomment below if needing Single Run FIX (deprecated)
		#if [ -z "${ConcatNames}" ]; then
			# single-run FIX
		#	fMRINamesFlat=$(echo ${fMRINames} | sed 's/[@%]/ /g')
			
		#	for fMRIName in ${fMRINamesFlat}; do
		#		echo "  ${fMRIName}"

		#		InputFile="${ResultsFolder}/${fMRIName}/${fMRIName}"

		#		cmd=("${queuing_command[@]}" "${HCPPIPEDIR}/ICAFIX/hcp_fix" "${InputFile}" ${bandpass} ${domot} "${SRTrainingData}" ${FixThreshold} "${DeleteIntermediates}")
		#		echo "About to run: ${cmd[*]}"
		#		"${cmd[@]}"
		#	done

		#else
			#need arrays to sanity check number of concat groups
			IFS=' @' read -a concatarray <<< "${ConcatNames}"
			IFS=% read -a fmriarray <<< "${fMRINames}"
			
			if ((${#concatarray[@]} != ${#fmriarray[@]})); then
				echo "ERROR: number of names in ConcatNames does not match number of fMRINames groups"
				exit 1
			fi

			for ((i = 0; i < ${#concatarray[@]}; ++i))
			do
				ConcatName="${concatarray[$i]}"
				fMRINamesGroup="${fmriarray[$i]}"
				# multi-run FIX
				ConcatFileName="${ResultsFolder}/${ConcatName}/${ConcatName}"

				IFS=' @' read -a namesgrouparray <<< "${fMRINamesGroup}"
				InputFile=""
				for fMRIName in "${namesgrouparray[@]}"; do
					if [[ "$InputFile" == "" ]]; then
						InputFile="${ResultsFolder}/${fMRIName}/${fMRIName}"
					else
						InputFile+="@${ResultsFolder}/${fMRIName}/${fMRIName}"
					fi
				done

				echo "  InputFile: ${InputFile}"

				cmd=("${queuing_command[@]}" "${HCPPIPEDIR}/ICAFIX/hcp_fix_multi_run" \
					--fmri-names="${InputFile}" --high-pass=${bandpass} \
					--concat-fmri-name="${ConcatFileName}" --motion-regression=${domot} \
					--training-file="${MRTrainingData}" --fix-threshold=${FixThreshold} \
					--delete-intermediates="${DeleteIntermediates}" --config="$config" \
					--processing-mode="$processingmode" --ica-method="$ICAmethod" \
					--matlab-run-mode="$MatlabMode")
				echo "About to run: ${cmd[*]}"
				"${cmd[@]}"
			done
        #Uncomment below if needing Single Run FIX (deprecated)
		#fi

	done
}  # main()

#
# Invoke the main function to get things started
#
main "$@"

