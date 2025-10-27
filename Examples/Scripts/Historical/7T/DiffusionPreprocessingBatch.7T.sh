#!/bin/bash 

DEFAULT_STUDY_FOLDER="${HOME}/data/7T_Testing"
DEFAULT_SUBJ_LIST="102311"
DEFAULT_RUN_LOCAL="FALSE"
DEFAULT_ENVIRONMENT_SCRIPT="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh"

SCAN_STRENGTH_CODE="7T"
DIRECTIONS="71 72"

#
# Function: get_batch_options
# Description:
#  Retrieve the --StudyFolder=, --Subjlist=, --EnvironmentScript=, and
#  --runlocal or --RunLocal parameter values if they are specified.
#
#  Sets the values of global variables: StudyFolder, Subjlist,
#  EnvironmentScript, and RunLocal
#
#  Default values are used for these variables if the command line options
#  are not specified.
#
get_batch_options() {
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

	while [ ${index} -lt ${numArgs} ]; do
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
#  installed versions of: FSL, FreeSurfer, Connectome Workbench (wb_command), gradunwarp (HCP version)
#  environment: HCPPIPEDIR, FSLDIR, FREESURFER_HOME, CARET7DIR, PATH for gradient_unwarp.py

#Set up pipeline environment variables and software
source "$EnvironmentScript"

# Log the originating call
echo "$@"

#NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
#DO NOT include "-q " at the beginning
#default to no queue, implying run local
QUEUE=""
#QUEUE="hcp_priority.q"

# Change to PRINTCOM="echo" to just echo commands instead of actually executing them
PRINTCOM=""
#PRINTCOM="echo"

SCRIPT_NAME=`basename ${0}`
echo $SCRIPT_NAME

########################################## INPUTS ########################################## 

#Scripts called by this script do assume they run on the outputs of the PreFreeSurfer Pipeline,
#which is a prerequisite for this pipeline

#Scripts called by this script do NOT assume anything about the form of the input names or paths.
#This batch script assumes the HCP raw data naming convention, e.g.

#	${StudyFolder}/${Subject}/unprocessed/3T/Diffusion/${SubjectID}_3T_DWI_dir95_RL.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/Diffusion/${SubjectID}_3T_DWI_dir96_RL.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/Diffusion/${SubjectID}_3T_DWI_dir97_RL.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/Diffusion/${SubjectID}_3T_DWI_dir95_LR.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/Diffusion/${SubjectID}_3T_DWI_dir96_LR.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/Diffusion/${SubjectID}_3T_DWI_dir97_LR.nii.gz

#Change Scan Settings: Echo Spacing and PEDir to match your images
#These are set to match the HCP Protocol by default

#If using gradient distortion correction, use the coefficents from your scanner
#The HCP gradient distortion coefficents are only available through Siemens
#Gradient distortion in standard scanners like the Trio is much less than for the HCP Skyra.

######################################### DO WORK ##########################################

for Subject in $Subjlist ; do

	echo "${SCRIPT_NAME}: Processing Subject: ${Subject}"

	# Input Variables
	SubjectID="${Subject}" #Subject ID Name
	RawDataDir="${StudyFolder}/${SubjectID}/unprocessed/${SCAN_STRENGTH_CODE}/Diffusion" # Folder where unprocessed diffusion data are

	# PosData is a list of files (separated by ‘@‘ symbol) having the same phase encoding (PE) direction 
	# and polarity. Similarly for NegData, which must have the opposite PE polarity of PosData.
	# The PosData files will come first in the merged data file that forms the input to ‘eddy’.
	# The particular PE polarity assigned to PosData/NegData is not relevant; the distortion and eddy 
	# current correction will be accurate either way.
	#
	# NOTE that PosData defines the reference space in 'topup' and 'eddy' AND it is assumed that
	# each scan series begins with a b=0 acquisition, so that the reference space in both
	# 'topup' and 'eddy' will be defined by the same (initial b=0) volume.
	#
	# On Siemens scanners, we typically use 'R>>L' ("RL") as the 'positive' direction for left-right
	# PE data, and 'P>>A' ("PA") as the 'positive' direction for anterior-posterior PE data.
	# And conversely, "LR" and "AP" are then the 'negative' direction data.
	# However, see preceding comment that PosData defines the reference space; so if you want the
	# first temporally acquired volume to define the reference space, then that series needs to be
	# the first listed series in PosData.
	#
	# Note that only volumes (gradient directions) that have matched Pos/Neg pairs are ultimately
	# propagated to the final output, *and* these pairs will be averaged to yield a single
	# volume per pair. This reduces file size by 2x (and thence speeds subsequent processing) and
	# avoids having volumes with different SNR features/ residual distortions.
	# [This behavior can be changed through the hard-coded 'CombineDataFlag' variable in the 
	# DiffPreprocPipeline_PostEddy.sh script if necessary].

	PosData=""
	NegData=""
	for DirectionNumber in ${DIRECTIONS} ; do
		if [ "${PosData}" != "" ] ; then
			PosDataSeparator="@"
		else
			PosDataSeparator=""
		fi
		if [ "${NegData}" != "" ] ; then
			NegDataSeparator="@"
		else
			NegDataSeparator=""
		fi

		PosData="${PosData}${PosDataSeparator}${RawDataDir}/${SubjectID}_${SCAN_STRENGTH_CODE}_DWI_dir${DirectionNumber}_PA.nii.gz"
		NegData="${NegData}${NegDataSeparator}${RawDataDir}/${SubjectID}_${SCAN_STRENGTH_CODE}_DWI_dir${DirectionNumber}_AP.nii.gz"
	done

	echo "  ${SCRIPT_NAME}: PosData: ${PosData}"
	echo "  ${SCRIPT_NAME}: NegData: ${NegData}"

	# "Effective" Echo Spacing of dMRI image (specified in *msec* for the dMRI processing)
	# EchoSpacing = 1/(BWPPPE * ReconMatrixPE)
	#   where BWPPPE is the "BandwidthPerPixelPhaseEncode" = DICOM field (0019,1028) for Siemens, and
	#   ReconMatrixPE = size of the reconstructed image in the PE dimension
	# In-plane acceleration, phase oversampling, phase resolution, phase field-of-view, and interpolation
	# all potentially need to be accounted for (which they are in Siemen's reported BWPPPE)
	EchoSpacing=0.2733285956376756
	echo "  ${SCRIPT_NAME}: EchoSpacing: ${EchoSpacing} (ms)"

	PEdir=2 #Use 1 for Left-Right Phase Encoding, 2 for Anterior-Posterior
	echo "  ${SCRIPT_NAME}: PEdir: ${PEdir}"

	# Gradient distortion correction
	# Set to NONE to skip gradient distortion correction
	# (These files are considered proprietary and therefore not provided as part of the HCP Pipelines -- contact Siemens to obtain)
	# Gdcoeffs="${HCPPIPEDIR_Config}/coeff_SC72C_Skyra.grad"
	Gdcoeffs="NONE"

	if [[ "$RunLocal" == "TRUE" || "$QUEUE" == "" ]] ; then
		echo "${SCRIPT_NAME}: About to locally run ${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline.sh"
		queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
	else
		echo "${SCRIPT_NAME}: About to use fsl_sub to queue ${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline.sh"
		queuing_command=("${FSLDIR}/bin/fsl_sub" -q  "$QUEUE")
	fi

	"${queuing_command[@]}" "${HCPPIPEDIR}"/DiffusionPreprocessing/DiffPreprocPipeline.sh \
		--posData="${PosData}" \
		--negData="${NegData}" \
		--path="${StudyFolder}" \
		--subject="${SubjectID}" \
		--echospacing="${EchoSpacing}" \
		--PEdir="${PEdir}" \
		--gdcoeffs="${Gdcoeffs}" \
		--b0maxbval=100 \
		--printcom="$PRINTCOM"

done
