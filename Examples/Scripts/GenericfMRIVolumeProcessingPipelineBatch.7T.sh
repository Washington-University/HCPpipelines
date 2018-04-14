#!/bin/bash 

DEFAULT_STUDY_FOLDER="${HOME}/data/7T_Testing"
DEFAULT_SUBJ_LIST="132118"
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
#  * gradunwarp (HCP version 1.0.1)
#
#  environment: 
#  * FSLDIR
#  * FREESURFER_HOME
#  * HCPPIPEDIR
#  * CARET7DIR
#  * PATH (for gradient_unwarp.py)

# Set up pipeline environment variables and software
source ${EnvironmentScript}

# Log the originating call
echo "$@"

#QUEUE="-q long.q"
QUEUE="-q hcp_priority.q"

# Change to PRINTCOM="echo" to just echo commands instead of actually executing them
#PRINTCOM="echo"
PRINTCOM=""

# To get accurate EPI distortion correction with TOPUP, the phase encoding direction
# encoded as part of the ${TaskList} name must accurately reflect the PE direction of
# the EPI scan, and you must have used the correct images in the
# SpinEchoPhaseEncode{Negative,Positive} variables.  If the distortion is twice as
# bad as in the original images, either swap the
# SpinEchoPhaseEncode{Negative,Positive} definition or reverse the polarity in the
# logic for setting UnwarpDir.
# NOTE: The pipeline expects you to have used the same phase encoding axis and echo
# spacing in the fMRI data as in the spin echo field map acquisitions.

######################################### DO WORK ##########################################

SCRIPT_NAME=`basename ${0}`
echo $SCRIPT_NAME

TaskList=""
TaskList+=" rfMRI_REST1_PA"  #Include space as first character
TaskList+=" rfMRI_REST2_AP"
TaskList+=" rfMRI_REST3_PA"
TaskList+=" rfMRI_REST4_AP"
TaskList+=" tfMRI_MOVIE1_AP"
TaskList+=" tfMRI_MOVIE2_PA"
TaskList+=" tfMRI_MOVIE3_PA"
TaskList+=" tfMRI_MOVIE4_AP"
TaskList+=" tfMRI_RETBAR1_AP"
TaskList+=" tfMRI_RETBAR2_PA"
TaskList+=" tfMRI_RETCCW_AP"
TaskList+=" tfMRI_RETCON_PA"
TaskList+=" tfMRI_RETCW_PA"
TaskList+=" tfMRI_RETEXP_AP"

for Subject in $Subjlist
do
	
	echo "${SCRIPT_NAME}: Processing Subject: ${Subject}"
	
	for fMRIName in ${TaskList}
	do
		echo "  ${SCRIPT_NAME}: Processing Scan: ${fMRIName}"

		TaskName=`echo ${fMRIName} | sed 's/_[APLR]\+$//'`
		echo "  ${SCRIPT_NAME}: TaskName: ${TaskName}"
		
		len=${#fMRIName}
		echo "  ${SCRIPT_NAME}: len: $len"
		start=$(( len - 2 ))
		
		PhaseEncodingDir=${fMRIName:start:2}
		echo "  ${SCRIPT_NAME}: PhaseEncodingDir: ${PhaseEncodingDir}"
		
		case ${PhaseEncodingDir} in
			"PA")
				UnwarpDir="y"
				;;
			"AP")
				UnwarpDir="y-"
				;;
			"RL")
				UnwarpDir="x"
				;;
			"LR")
				UnwarpDir="x-"
				;;
			*)
				echo "${SCRIPT_NAME}: Unrecognized Phase Encoding Direction: ${PhaseEncodingDir}"
				exit 1
		esac
		
		echo "  ${SCRIPT_NAME}: UnwarpDir: ${UnwarpDir}"
		
		SubjectUnprocessedRootDir="${StudyFolder}/${Subject}/unprocessed/7T/${fMRIName}"
		
		fMRITimeSeries="${SubjectUnprocessedRootDir}/${Subject}_7T_${fMRIName}.nii.gz"

		# A single band reference image (SBRef) is recommended if available
		# Set to NONE if you want to use the first volume of the timeseries for motion correction
		fMRISBRef="NONE"
		
		# "Effective" Echo Spacing of fMRI image (specified in *sec* for the fMRI processing)
		# EchoSpacing = 1/(BWPPPE * ReconMatrixPE)
		#   where BWPPPE is the "BandwidthPerPixelPhaseEncode" = DICOM field (0019,1028) for Siemens, and
		#   ReconMatrixPE = size of the reconstructed image in the PE dimension
		# In-plane acceleration, phase oversampling, phase resolution, phase field-of-view, and interpolation
		# all potentially need to be accounted for (which they are in Siemen's reported BWPPPE)
		EchoSpacing="0.00032"

		# Susceptibility distortion correction method (required for accurate processing)
		# Values: TOPUP, SiemensFieldMap (same as FIELDMAP), GeneralElectricFieldMap
		DistortionCorrection="TOPUP"
		
		# For the spin echo field map volume with a 'negative' phase encoding direction
		# (LR in HCP-YA data; AP in 7T HCP-YA and HCP-D/A data)
		# Set to NONE if using regular FIELDMAP
		SpinEchoPhaseEncodeNegative="${SubjectUnprocessedRootDir}/${Subject}_7T_SpinEchoFieldMap_AP.nii.gz"
		
		# For the spin echo field map volume with a 'positive' phase encoding direction
		# (RL in HCP-YA data; PA in 7T HCP-YA and HCP-D/A data)
		# Set to NONE if using regular FIELDMAP
		SpinEchoPhaseEncodePositive="${SubjectUnprocessedRootDir}/${Subject}_7T_SpinEchoFieldMap_PA.nii.gz"
		
		# Topup configuration file (if using TOPUP)
		# Set to NONE if using regular FIELDMAP
		TopUpConfig="${HCPPIPEDIR_Config}/b02b0.cnf"
		
		# Not using Siemens Gradient Echo Field Maps for susceptibility distortion correction
		# Set following to NONE if using TOPUP
		MagnitudeInputName="NONE" #Expects 4D Magnitude volume with two 3D volumes (differing echo times)
		PhaseInputName="NONE" #Expects a 3D Phase difference volume (Siemen's style)
		DeltaTE="NONE" #2.46ms for 3T, 1.02ms for 7T
		
		# Not using General Electric Gradient Echo Field Maps for Distortion Correction
		GEB0InputName="NONE"
		
		FinalFMRIResolution="1.60"
		dof_epi2t1=12
		
		# Skipping Gradient Distortion Correction
		GradientDistortionCoeffs="NONE"
		
		# Use mcflirt motion correction
		MCType="MCFLIRT"
		
		# Determine output name for the fMRI
		output_fMRIName="${TaskName}_7T_${PhaseEncodingDir}"
		echo "  ${SCRIPT_NAME}: output_fMRIName: ${output_fMRIName}"
		
		if [ "${RunLocal}" == "TRUE" ]
		then
			echo "  ${SCRIPT_NAME}: About to run ${HCPPIPEDIR}/fMRIVolume/GenericfMRIVolumeProcessingPipeline.sh"
			queuing_command=""
		else
			echo "  ${SCRIPT_NAME}: About to use fsl_sub to queue or run ${HCPPIPEDIR}/fMRIVolume/GenericfMRIVolumeProcessingPipeline.sh"
			queuing_command="${FSLDIR}/bin/fsl_sub ${QUEUE}"
		fi
		
		${PRINTCOM} ${queuing_command} ${HCPPIPEDIR}/fMRIVolume/GenericfMRIVolumeProcessingPipeline.sh \
			--path=${StudyFolder} \
			--subject=${Subject} \
			--fmriname=${output_fMRIName} \
			--fmritcs=${fMRITimeSeries} \
			--fmriscout=${fMRISBRef} \
			--SEPhaseNeg=${SpinEchoPhaseEncodeNegative} \
			--SEPhasePos=${SpinEchoPhaseEncodePositive} \
			--fmapmag=${MagnitudeInputName} \
			--fmapphase=${PhaseInputName} \
			--fmapgeneralelectric=${GEB0InputName} \
			--echospacing=${EchoSpacing} \
			--echodiff=${DeltaTE} \
			--unwarpdir=${UnwarpDir} \
			--fmrires=${FinalFMRIResolution} \
			--dcmethod=${DistortionCorrection} \
			--gdcoeffs=${GradientDistortionCoeffs} \
			--topupconfig=${TopUpConfig} \
			--dof=${dof_epi2t1} \
			--printcom=${PRINTCOM} \
			--mctype=${MCType}
	done
	
done
