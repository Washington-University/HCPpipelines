#!/bin/bash 

DEFAULT_STUDY_FOLDER="${HOME}/data/7T_Testing"
DEFAULT_SUBJ_LIST="102311"
DEFAULT_RUN_LOCAL="FALSE"
DEFAULT_ENVIRONMENT_SCRIPT="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh"

#
# Function: get_batch_options
# Description:
#  Retrieve the --StudyFolder=, --Subjlist=, --EnvironmentScript=, and 
#  --runlocal or --RunLocal parameter values if they are specified.  
#
#  Sets the values of the global variables: StudyFolder, Subjlist, 
#  EnvironmentScript, and RunLocal
#
#  Default values are used for these variables if the command line options
#  are not specified.
#
get_batch_options() 
{
	local arguments=("$@")
	
	# Output global variables
	unset StudyFolder
	unset Subjlist
	unset RunLocal
	unset EnvironmentScript
	
	# Default values
	
	# Location of subject folders (named by subject ID)
	StudyFolder="${DEFAULT_STUDY_FOLDER}"
	
	# Space delimited list of subject IDs
	Subjlist="${DEFAULT_SUBJ_LIST}"
	
	# Whether or not to run locally instead of submitting to a queue
	RunLocal="${DEFAULT_RUN_LOCAL}"
	
	# Pipeline environment script
	EnvironmentScript="${DEFAULT_ENVIRONMENT_SCRIPT}"
	
	# Parse command line options
	local index=0
	local numArgs=${#arguments[@]}
	local argument
	
	while [ ${index} -lt ${numArgs} ];
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
			--runlocal | --RunLocal)
				RunLocal="TRUE"
				index=$(( index + 1 ))
				;;
			--EnvironmentScript=*)
				EnvironmentScript=${argument#*=}
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

# Get command line batch options
get_batch_options "$@"

# Requirements for this script
#  installed versions of: FSL, Connectome Workbench (wb_command)
#  environment: HCPPIPEDIR, FSLDIR, CARET7DIR

# Set up pipeline environment variables and software
source "$EnvironmentScript"

# Log the originating call
echo "$@"

#NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
#DO NOT include "-q " at the beginning
#default to no queue, implying run local
QUEUE=""
#QUEUE="hcp_priority.q"

######################################### DO WORK ##########################################

SCRIPT_NAME=`basename ${0}`
echo $SCRIPT_NAME

Tasklist=()
Tasklist+=(rfMRI_REST1_PA)
Tasklist+=(rfMRI_REST2_AP)
Tasklist+=(rfMRI_REST3_PA)
Tasklist+=(rfMRI_REST4_AP)
Tasklist+=(tfMRI_MOVIE1_AP)
Tasklist+=(tfMRI_MOVIE2_PA)
Tasklist+=(tfMRI_MOVIE3_PA)
Tasklist+=(tfMRI_MOVIE4_AP)
Tasklist+=(tfMRI_RET1_AP)
Tasklist+=(tfMRI_RET2_PA)
Tasklist+=(tfMRI_RET3_AP)
Tasklist+=(tfMRI_RET4_PA)
Tasklist+=(tfMRI_RET5_AP)
Tasklist+=(tfMRI_RET6_PA)

for Subject in $Subjlist
do
	echo "${SCRIPT_NAME}: Processing Subject: ${Subject}"
	
	for fMRIName in "${Tasklist[@]}"
	do
		echo "  ${SCRIPT_NAME}: Processing Scan: ${fMRIName}"
		
		LowResMesh="32" #Needs to match what is in PostFreeSurfer, 32 is on average 2mm spacing between the vertices on the midthickness
		FinalfMRIResolution="1.60" #Needs to match what is in fMRIVolume, i.e. 2mm for 3T HCP data and 1.6mm for 7T HCP data
		SmoothingFWHM="2" #Recommended to be roughly the grayordinates spacing, i.e 2mm on HCP data
		GrayordinatesResolution="2" #Needs to match what is in PostFreeSurfer. 2mm gives the HCP standard grayordinates space with 91282 grayordinates.  Can be different from the FinalfMRIResolution (e.g. in the case of HCP 7T data at 1.6mm)
		# RegName="MSMSulc" #MSMSulc is recommended, if binary is not available use FS (FreeSurfer)
		RegName="FS"
		
		if [[ "$RunLocal" == "TRUE" || "$QUEUE" == "" ]] ; then
			echo "${SCRIPT_NAME}: About to locally run ${HCPPIPEDIR}/fMRISurface/GenericfMRISurfaceProcessingPipeline.sh"
			queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
		else
			echo "${SCRIPT_NAME}: About to use fsl_sub to queue ${HCPPIPEDIR}/fMRISurface/GenericfMRISurfaceProcessingPipeline.sh"
			queuing_command=("${FSLDIR}/bin/fsl_sub" -q "$QUEUE")
		fi
		
		"${queuing_command[@]}" "$HCPPIPEDIR"/fMRISurface/GenericfMRISurfaceProcessingPipeline.sh \
			--path="$StudyFolder" \
			--subject="$Subject" \
			--fmriname="$fMRIName" \
			--lowresmesh="$LowResMesh" \
			--fmrires="$FinalfMRIResolution" \
			--smoothingFWHM="$SmoothingFWHM" \
			--grayordinatesres="$GrayordinatesResolution" \
			--regname="$RegName"
		
	done
	
done

