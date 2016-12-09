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
#
#  installed versions of:
#  * FSL (version 5.0.6)
#  * FreeSurfer (version 5.3.0-HCP)
#  * gradunwarp (HCP version 1.0.2)
#
#  environment
#  * FSLDIR
#  * FREESURFER_HOME
#  * HCPPIPEDIR
#  * CARET7DIR
#  * PATH (for gradient_unwarp.py)

#Set up pipeline environment variables and software
source ${EnvironmentScript}

# Log the originating call
echo "$@"

#QUEUE="-q verylong.q"
QUEUE="-q hcp_priority.q"

# Change to PRINTCOM="echo" to just echo commands instead of actually executing them
#PRINTCOM="echo"
PRINTCOM=""

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
	# Note that only volumes (gradient directions) that have matched Pos/Neg pairs are ultimately
	# propagated to the final output, *and* these pairs will be averaged to yield a single
	# volume per pair. This reduces file size by 2x (and thence speeds subsequent processing) and
	# avoids having volumes with different SNR features/ residual distortions.
	#
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

		PosData="${PosData}${PosDataSeparator}${RawDataDir}/${SubjectID}_${SCAN_STRENGTH_CODE}_DWI_dir${DirectionNumber}_AP.nii.gz"
		NegData="${NegData}${NegDataSeparator}${RawDataDir}/${SubjectID}_${SCAN_STRENGTH_CODE}_DWI_dir${DirectionNumber}_PA.nii.gz"
	done

	echo "  ${SCRIPT_NAME}: PosData: ${PosData}"
	echo "  ${SCRIPT_NAME}: NegData: ${NegData}"

	#Scan Setings
	EchoSpacing=0.2733285956376756 #Echo Spacing or Dwelltime of dMRI image, set to NONE if not used. Dwelltime = 1/(BandwidthPerPixelPhaseEncode * # of phase encoding samples): DICOM field (0019,1028) = BandwidthPerPixelPhaseEncode, DICOM field (0051,100b) AcquisitionMatrixText first value (# of phase encoding samples).  On Siemens, iPAT/GRAPPA factors have already been accounted for.
	echo "  ${SCRIPT_NAME}: EchoSpacing: ${EchoSpacing}"
	PEdir=2 #Use 1 for Left-Right Phase Encoding, 2 for Anterior-Posterior
	echo "  ${SCRIPT_NAME}: PEdir: ${PEdir}"

	#Config Settings
	# Gdcoeffs="${HCPPIPEDIR_Config}/coeff_SC72C_Skyra.grad" #Coefficients that describe spatial variations of the scanner gradients. Use NONE if not available.
	Gdcoeffs="NONE" # Set to NONE to skip gradient distortion correction

	if [ "${RunLocal}" == "TRUE" ] ; then
		echo "${SCRIPT_NAME}: About to run ${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline.sh"
		queuing_command=""
	else
		echo "${SCRIPT_NAME}: About to use fsl_sub to queue or run ${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline.sh"
		queuing_command="${FSLDIR}/bin/fsl_sub ${QUEUE}"
	fi

	${PRINTCOM} ${queuing_command} ${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline.sh \
		--posData="${PosData}" \
		--negData="${NegData}" \
		--path="${StudyFolder}" \
		--subject="${SubjectID}" \
		--echospacing="${EchoSpacing}" \
		--PEdir=${PEdir} \
		--gdcoeffs="${Gdcoeffs}" \
		--b0maxbval=100 \
		--printcom=$PRINTCOM

done
