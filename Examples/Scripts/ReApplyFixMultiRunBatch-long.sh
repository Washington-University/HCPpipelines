#!/bin/bash
#set -xv


# Naming assumptions
# This script assumes that:
# 1. The cross-sectional session dirs are named <Subject>_<PossibleVisit>, 
# 2. Longitudinal session dirs are named <Subject>_<Possible_Visit>.long.<Template>,
# 3. Both longitudinal and cross-sectional sessions exist in the study folder.

# Global default values
DEFAULT_STUDY_FOLDER="${HOME}/data/Pipelines_ExampleData"
DEFAULT_SUBJECT_LIST="HCA6002236 HCA6002237"
DEFAULT_ENVIRONMENT_SCRIPT="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh"
DEFAULT_RUN_LOCAL="FALSE"

DEFAULT_POSSIBLE_VISITS="V1_MR V2_MR V3_MR"

# The template list should include labels for the longitudinal template of each subject, similar to those used in longitudinal FreeSurfer.
DEFAULT_TEMPLATE_LIST="HCA6002236_V1_V2_V3 HCA6002237_V1_V2_V3"

ExcludeVisits=()
#
# Function Description
# Get the command line options for this script
#
# Global Output Variables
#   ${StudyFolder}           - Path to folder containing all subjects data in subdirectories named 
#                              for the subject id
#   ${Subjlist}              - Space delimited list of subject IDs
#   ${EnvironmentScript}     - Script to source to setup pipeline environment
#   ${RunLocal}              - Indication whether to run this processing "locally" i.e. not submit
#                              the processing to a cluster or grid
#
get_options() {
	local scriptName=$(basename ${0})
	local arguments=("$@")

	# initialize global output variables
	StudyFolder="${DEFAULT_STUDY_FOLDER}"
	Subjlist="${DEFAULT_SUBJECT_LIST}"
	EnvironmentScript="${DEFAULT_ENVIRONMENT_SCRIPT}"
	RunLocal="${DEFAULT_RUN_LOCAL}"
	
	# make these into command-line options later if desired.
	PossibleVisits=($DEFAULT_POSSIBLE_VISITS)
	Templates=($DEFAULT_TEMPLATE_LIST)

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
	echo "	 Templates: ${Templates[@]}"
	echo "	 Possible visits: ${PossibleVisits[@]}"
	echo "   EnvironmentScript: ${EnvironmentScript}"
	echo "   RunLocal: ${RunLocal}"
	echo "-- ${scriptName}: Specified Command-Line Options: -- End --"
}  # get_options()

# Function description
#
# For the given subject, identify_timepoints creates a string listing @ separated visits/timepoints to process
# Uses StudyFolder, ExcludeVisits, PossibleVisits global variables as input.
# Subject must be supplied as the first argument. 

function identify_timepoints
{
    local subject=$1
    local tplist=""
    local tp visit n

    #build the list of timepoints
    n=0
    for visit in ${PossibleVisits[*]}; do
        tp="${subject}_${visit}"
        if [ -d "$StudyFolder/$tp" ] && ! [[ " ${ExcludeVisits[*]+${ExcludeVisits[*]}} " =~ [[:space:]]"$tp"[[:space:]] ]]; then
             if (( n==0 )); then 
                    tplist="$tp"
             else
                    tplist="$tplist@$tp"
             fi
        fi
        ((n++))
    done
    echo $tplist
}

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

	# set list of fMRI on which to run ReApplyFixPipeline, separate MR FIX groups with %, use spaces (or @ like dedrift...) to otherwise separate runs
	# ReApplyFixPipeline
	fMRINames="rfMRI_REST1_AP@rfMRI_REST1_PA@tfMRI_VISMOTOR_PA@tfMRI_CARIT_PA@tfMRI_FACENAME_PA@rfMRI_REST2_AP@rfMRI_REST2_PA"
  
	# specify the name of concatenated folder
	# if run Multi-Run specify ConcatNames as null string
	ConcatNames="fMRI_CONCAT_ALL"
	#ConcatNames="tfMRI_WM_GAMBLING_MOTOR_RL_LR@tfMRI_LANGUAGE_SOCIAL_RELATIONAL_EMOTION_RL_LR"

	# set highpass
	highpass=0
	
	#NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
	#DO NOT include "-q " at the beginning
	#default to no queue, implying run local
	#QUEUE=""
	QUEUE="hcp_priority.q"

	# regression mode
	RegName="NONE"

	# low res mesh
	LowResMesh=32

	# matlab mode
	# 0 = Use compiled MATLAB
	# 1 = Use interpreted MATLAB
	# 2 = Use interpreted Octave
	MatlabMode=1

	# motion regression or not
	MotionReg=FALSE

	# clean up intermediates
	DeleteIntermediates=FALSE

	#MR FIX config support for non-HCP settings
	config=""
	processingmode="HCPStyleData"
	#uncomment the below two lines for legacy-style data
	#config="$HCPPIPEDIR"/ICAFIX/config/legacy.conf
	#processingmode="LegacyStyleData"

	if [[ "${RunLocal}" == "TRUE" || "$QUEUE" == "" ]]; then
		queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
	else
		queuing_command=("${FSLDIR}/bin/fsl_sub" -q "$QUEUE")
	fi

	for Subject in ${Subjlist}; do
		TemplateLong="${Templates[i]}"
		Timepoint_list_cross_at_separated=$(identify_timepoints "$Subject")
		IFS=@ read -r -a Timepoint_list_cross <<< "${Timepoint_list_cross_at_separated}"
		
		for TimepointCross in "${Timepoint_list_cross[@]}"; do
			TimepointLong=${TimepointCross}.long.${TemplateLong}
			if [ -z ${ConcatNames} ]; then
					echo "Single run legacy processing is not supported in longitudinal mode."
					exit -1
			else # Multi-Run				
				#need arrays to sanity check number of concat groups
				IFS=' @' read -a concatarray <<< "${ConcatNames}"
				IFS=% read -a fmriarray <<< "${fMRINames}"
				
				if ((${#concatarray[@]} != ${#fmriarray[@]})); then
					echo "ERROR: number of names in ConcatNames does not match number of fMRINames groups"
					exit 1
				fi

				for ((i = 0; i < ${#concatarray[@]}; ++i)); do
					ConcatName="${concatarray[$i]}"
					fMRINamesGroup="${fmriarray[$i]}"
				
					"${queuing_command[@]}" "$HCPPIPEDIR"/ICAFIX/ReApplyFixMultiRunPipeline.sh \
						--path="$StudyFolder" \
						--session="$TimepointCross" \
						--fmri-names="$fMRINamesGroup" \
						--high-pass="$highpass" \
						--reg-name="$RegName" \
						--concat-fmri-name="$ConcatName" \
						--low-res-mesh="$LowResMesh" \
						--matlab-run-mode="$MatlabMode" \
						--motion-regression="$MotionReg" \
						--config="$config" \
						--processing-mode="$processingmode" \
						--is-longitudinal="TRUE" \
						--longitudinal-session="$TimepointLong"
					
					echo "${TimepointCross} ${TimepointLong} ${ConcatName}"					
				done
			fi
		done #iterating over timepoints
	done #iterating over subjects
}  # main()

#
# Invoke the main function to get things started
#
main "$@"

