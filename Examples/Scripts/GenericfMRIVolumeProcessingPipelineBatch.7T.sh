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

######################################### DO WORK ##########################################

SCRIPT_NAME=`basename ${0}`
echo $SCRIPT_NAME

Tasklist=""
Tasklist="${Tasklist} rfMRI_REST1_PA"
Tasklist="${Tasklist} rfMRI_REST2_AP"
Tasklist="${Tasklist} rfMRI_REST3_PA"
Tasklist="${Tasklist} rfMRI_REST4_AP"
Tasklist="${Tasklist} tfMRI_MOVIE1_AP"
Tasklist="${Tasklist} tfMRI_MOVIE2_PA"
Tasklist="${Tasklist} tfMRI_MOVIE3_PA"
Tasklist="${Tasklist} tfMRI_MOVIE4_AP"
Tasklist="${Tasklist} tfMRI_RETBAR1_AP"
Tasklist="${Tasklist} tfMRI_RETBAR2_PA"
Tasklist="${Tasklist} tfMRI_RETCCW_AP"
Tasklist="${Tasklist} tfMRI_RETCON_PA"
Tasklist="${Tasklist} tfMRI_RETCW_PA"
Tasklist="${Tasklist} tfMRI_RETEXP_AP"

for Subject in $Subjlist
do
	
	echo "${SCRIPT_NAME}: Processing Subject: ${Subject}"
	
	for fMRIName in ${Tasklist}
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
		fMRISBRef="NONE"
		
		# Echo Spacing or Dwelltime of fMRI image
		DwellTime="0.00032"

		# To get accurate EPI distortion correction with TOPUP, the flags in PhaseEncodinglist must match 
		# the phase encoding direction of the EPI scan, and you must have used the correct images in 
		# SpinEchoPhaseEncodeNegative and Positive variables.  If the distortion is twice as bad as in 
		# the original images, flip either the order of the spin echo images or reverse the phase encoding 
		# list flag.  The pipeline expects you to have used the same phase encoding axis in the fMRI data 
		# as in the spin echo field map data (x/-x or y/-y).

		# Using Spin Echo Field Maps for Readout Distortion Correction
		DistortionCorrection="TOPUP"
		
		# For the spin echo field map volume with a negative phase encoding direction (LR in HCP data, AP in 7T HCP data)
		# Set to NONE if using regular FIELDMAP
		SpinEchoPhaseEncodeNegative="${SubjectUnprocessedRootDir}/${Subject}_7T_SpinEchoFieldMap_AP.nii.gz"
		
		# For the spin echo field map volume with a positive phase encoding direction (RL in HCP data, PA in 7T HCP data)
		# Set to NONE if using regular FIELDMAP
		SpinEchoPhaseEncodePositive="${SubjectUnprocessedRootDir}/${Subject}_7T_SpinEchoFieldMap_PA.nii.gz"
		
		# Topup configuration file
		TopUpConfig="${HCPPIPEDIR_Config}/b02b0.cnf"
		
		# Not using Siemens Gradient Echo Field Maps for Readout Distortion Correction
		MagnitudeInputName="NONE"
		PhaseInputName="NONE"
		DeltaTE="NONE"
		
		# Not using General Electric Gradient Echo Field Maps for Readout Distortion Correction
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
			--echospacing=${DwellTime} \
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
