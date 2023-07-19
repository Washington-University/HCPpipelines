#!/bin/bash

# Global default values
DEFAULT_STUDY_FOLDER="${HOME}/data/Pipelines_ExampleData"
DEFAULT_SUBJECT_LIST="100307 100610"
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
	source "$EnvironmentScript"

	# MPH: If DEFAULT_FIXDIR is set, or --FixDir argument was used, then use that to
	# override the setting of FSL_FIXDIR in EnvironmentScript
	if [ ! -z ${FixDir} ]; then
		export FSL_FIXDIR=${FixDir}
	fi

	# set list of fMRI on which to run ICA+FIX, separate MR FIX groups with %, use spaces (or @ like dedrift...) to otherwise separate runs
	# the MR FIX groups determine what gets concatenated before doing ICA
	# the groups can be whatever you want, you can make a day 1 group and a day 2 group, or just concatenate everything, etc
	fMRINames="tfMRI_WM_RL@tfMRI_WM_LR@tfMRI_GAMBLING_RL@tfMRI_GAMBLING_LR@tfMRI_MOTOR_RL@tfMRI_MOTOR_LR%tfMRI_LANGUAGE_RL@tfMRI_LANGUAGE_LR@tfMRI_SOCIAL_RL@tfMRI_SOCIAL_LR@tfMRI_RELATIONAL_RL@tfMRI_RELATIONAL_LR@tfMRI_EMOTION_RL@tfMRI_EMOTION_LR"

	# If you wish to run "multi-run" (concatenated) FIX, specify the names to give the concatenated output files
	# In this case, all the runs included in ${fMRINames} become the input to multi-run FIX
	ConcatNames="tfMRI_WM_GAMBLING_MOTOR_RL_LR@tfMRI_LANGUAGE_SOCIAL_RELATIONAL_EMOTION_RL_LR"  ## Use space (or @) to separate concatenation groups
	# Otherwise, leave ConcatNames empty (in which case "single-run" FIX is executed serially on each run in ${fMRINames})
	#ConcatNames=""

	# set temporal highpass full-width (2*sigma) to use, in seconds, cannot be 0 for single-run FIX
	# MR FIX also supports 0 for a linear detrend, or "pdX" for a polynomial detrend of order X
	# e.g., bandpass=pd1 is linear detrend (functionally equivalent to bandpass=0)
	# bandpass=pd2 is a quadratic detrend
	bandpass=0
	#bandpass=2000 #for single run FIX, bandpass=2000 was used in HCP preprocessing

	# set whether or not to regress motion parameters (24 regressors)
	# out of the data as part of FIX (TRUE or FALSE)
	domot=FALSE
	
	# set the training data used in multi-run fix mode
	MRTrainingData=HCP_Style_Single_Multirun_Dedrift.RData

	# set the training data used in single-run fix mode
	SRTrainingData=HCP_hp2000.RData
	
	# set FIX threshold (controls sensitivity/specificity tradeoff)
	FixThreshold=10
	
	#delete highpass files (note that delete intermediates=TRUE is not recommended for MR+FIX)
	DeleteIntermediates=FALSE
	
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
		
		if [ -z "${ConcatNames}" ]; then
			# single-run FIX
			fMRINamesFlat=$(echo ${fMRINames} | sed 's/[@%]/ /g')
			
			for fMRIName in ${fMRINamesFlat}; do
				echo "  ${fMRIName}"

				InputFile="${ResultsFolder}/${fMRIName}/${fMRIName}"

				cmd=("${queuing_command[@]}" "${HCPPIPEDIR}/ICAFIX/hcp_fix" "${InputFile}" ${bandpass} ${domot} "${SRTrainingData}" ${FixThreshold} "${DeleteIntermediates}")
				echo "About to run: ${cmd[*]}"
				"${cmd[@]}"
			done

		else
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

				cmd=("${queuing_command[@]}" "${HCPPIPEDIR}/ICAFIX/hcp_fix_multi_run" --fmri-names="${InputFile}" --high-pass=${bandpass} --concat-fmri-name="${ConcatFileName}" --motion-regression=${domot} --training-file="${MRTrainingData}" --fix-threshold=${FixThreshold} --delete-intermediates="${DeleteIntermediates}" --config="$config" --processing-mode="$processingmode")
				echo "About to run: ${cmd[*]}"
				"${cmd[@]}"
			done

		fi

	done
}  # main()

#
# Invoke the main function to get things started
#
main "$@"

