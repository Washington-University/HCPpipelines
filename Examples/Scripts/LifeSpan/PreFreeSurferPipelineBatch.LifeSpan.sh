#!/bin/bash

#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # PreFreeSurferPipelineBatch.LifeSpan.sh
#
# ## Copyright Notice
#
# Copyright (C) 2019 The Human Connectome Project/The Connectome Coordination Facility
#
# * Washington University in St. Louis
# * University of Minnesota
# * Oxford University
#
# ## Author(s)
#
# * Timothy B. Brown, Neuroinformatics Research Group,
#	Washington University in St. Louis
#
# ## Product
#
# [Human Connectome Project][HCP] (HCP) Pipelines
#
# ## License
#
# See the [LICENSE](https://github.com/Washington-University/Pipelines/blob/master/LICENSE.md) file
#
# ## Description:
#
# Example script for running the Pre-FreeSurfer phase of the HCP Structural
# Preprocessing pipeline on LifeSpan style data.
#
# See [Glasser et al. 2013][GlasserEtAl].
#
# ## Prerequisites
#
# ### Installed software 
#
# * FSL (version v6.0.1)
# * FreeSurfer (version v6.0.0)
# * gradunwarp (HCP version 1.0.2) - if doing gradient distortion correction
#
# ### Environment variables
#
# Should be set in script file pointed to by EnvironmentScript variable.
# See setting of the EnvironmentScript variable in the main() function
# below.
#
# * FSLDIR - FSL installation directory
# * FREESURFER_HOME - FreeSurfer installation directory
# * HCPPIPEDIR - HCP Pipelines installation directory
# * CARET7DIR - Connectome Workbench installation directory
# * PATH - must point to where gradient_unwarp.py is if doing gradient unwarping
#
# <!-- References -->
# [HCP]: http://www.humanconnectome.org
# [GlasserEtAl]: http://www.ncbi.nlm.nih.gov/pubmed/23668970
#
#~ND~END~

# ----------------------------------------------------------------
#   HERE IS WHERE YOU WOULD CHANGE DEFAULT VALUES TO BE USED
#   IF YOU WOULD LIKE TO RUN THIS SCRIPT WITHOUT SPECIFYING
#   ANY COMMAND LINE PARAMETERS.
# ----------------------------------------------------------------

# Default location of study folder
DEFAULT_STUDY_FOLDER="${HOME}/projects/Pipelines_ExampleData"

# Default space delimited list of subject IDs
DEFAULT_SESSION_LIST="100307_MR_3T" 

# Default pipeline environment script
DEFAULT_ENVIRONMENT_SCRIPT="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh"

# Default indicator of whether to run the processing "locally" (i.e. on the
# machine on which this script is invoked) or try to submit the a job
# to a processing queue using fsl_sub. If this value is anything other
# than empty, then the processing is done "locally".
#
# Example usage:
#
# Set to empty string to submit a job for each session/subject.
#
#   DEFAULT_RUN_LOCAL=""
#
# Set to "TRUE" to do processing "locally".
#
#   DEFAULT_RUN_LOCAL="TRUE"
#
DEFAULT_RUN_LOCAL=""

usage()
{
	cat <<EOF

PreFreeSurferPipelineBatch.LifeSpan.sh: 

  Example script for running the Pre-FreeSurfer phase of the HCP Structural
  Preprocessing pipeline on LifeSpan-style data.

PARAMETERs are: [ ] = optional; < > = user supplied value

  [--help] : show this usage information and exit

  [--study=<study folder>]

	The study folder in which to find the session sub-directories.

	If this option isn't specified, the study folder used defaults to:

	  ${DEFAULT_STUDY_FOLDER}

  [--session=<session ID>]

	A session within the study folder for which to run this processing.

	This parameter can be specified multiple times to create a list of 
	sessions to process. E.g. --session=100307_MR_3T --session=100287_MR_3T 
	would result in the following list of sessions to process: 100307_MR_3T 100287_MR_3T

	If none of these options are specified, the list of sessions to process
	defaults to:

	  ${DEFAULT_SESSION_LIST}

  [--runlocal]

	Specifies that processing should occur "locally" (i.e. on this machine) as 
    opposed to trying to submit the processing to a queuing system. If this 
    option is not specified, this script default to trying to submit the 
    processing job to a queuing system using the fsl_sub command. 

  [--env=<path to environment script>]

	This parameter specifies the path to the environment script which sets 
    the environment variables necessary to run this processing.

	If none of these options are specified, the environment script path
	defaults to:

	  ${DEFAULT_ENVIRONMENT_SCRIPT}

EOF
}

get_options()
{
	# Note that the ($@) construction parses the arguments into an
	# array of values using spaces as the delimiter
	local arguments=($@)

	unset p_study_folder
	unset p_session_list
	unset p_run_local
	unset p_environment_script
	
	# parse arguments
	local num_args=${#arguments[@]}
	local argument
	local index

	for (( index =	0; index < num_args; ++index )); do
		argument=${arguments[index]}
		
		case ${argument} in
			--help)
				usage
				exit 1
				;;
			--study=*)
 				p_study_folder=${argument#*=}
				;;
			--session=*)
				if [ -n "${p_session_list}" ]; then
					p_session_list+=" "
				fi
				p_session_list+=${argument#*=}
				;;
			--runlocal)
				p_run_local="TRUE"
				;;
			--env=*)
				p_environment_script=${argument#*=}
				;;
			*)
				usage
				exit 1
				;;
		esac
		
	done
	
	if [ -z "${p_study_folder}" ]; then
		p_study_folder=${DEFAULT_STUDY_FOLDER}
	fi
	
	if [ -z "${p_session_list}" ]; then
		p_session_list=${DEFAULT_SESSION_LIST}
	fi
	
	if [ -z "${p_environment_script}" ]; then
		p_environment_script=${DEFAULT_ENVIRONMENT_SCRIPT}
	fi

	if [ -z "${p_run_local}" ]; then
		p_run_local=${DEFAULT_RUN_LOCAL}
	fi
}

main()
{
	get_options "$@"
	
	# Gather options specified on the command line or given default values
	local StudyFolder="${p_study_folder}"
	local SessionList="${p_session_list}"
	local EnvironmentScript="${p_environment_script}"
	local RunLocal="${p_run_local}"
	
	# Report major script control variables to user
	echo ""
	echo "StudyFolder: ${StudyFolder}"
	echo "SessionList: ${SessionList}"
	echo "EnvironmentScript: ${EnvironmentScript}"
	echo "RunLocal: ${RunLocal}"
	echo ""
	
	# Set up pipeline environment variables and software paths
	source ${EnvironmentScript}
	
	# Report environment variables pointing to tools
	echo "FSLDIR: ${FSLDIR}"
	echo "FREESURFER_HOME: ${FREESURFER_HOME}"
	echo "HCPPIPEDIR: ${HCPPIPEDIR}"
	echo "CARET7DIR: ${CARET7DIR}"
	echo "PATH: ${PATH}"

	# If PRINTCOM is not a null or empty string variable, then
	# this script and other scripts that it calls will simply
	# print out the primary commands it otherwise would run.
	# This printing will be done using the command specified
	# in the PRINTCOM variable
	PRINTCOM=""
	# PRINTCOM="echo"

	# Define processing queue to be used if submitted to job scheduler
	# if [ X$SGE_ROOT != X ] ; then
	#	 QUEUE="-q long.q"
	#	 QUEUE="-q veryshort.q"
	QUEUE="-q hcp_priority.q"
	# fi
	
	# Establish queuing command based on whether running locally or submitting jobs
	if [ -n "${RunLocal}" ] ; then
		queuing_command=""
	else
		queuing_command="${FSLDIR}/bin/fsl_sub ${QUEUE}"
	fi

	# Cycle through specified subjects/sessions and run/submit processing
	for Session in ${SessionList} ; do
		echo ""
		echo "Processing: ${Session}"
		echo ""
		
		# Scripts called by this script do NOT assume anything about the form of the
		# input names or paths. This batch script assumes either the HCP unprocessed
		# data naming convention or the LifeSpan unprocessed data naming convention
		# depending upon whether LifeSpanStyle is "TRUE".
		
		# Input Images
		T1wInputImages="${StudyFolder}/${Session}/unprocessed/T1w_MPR_vNav_4e_RMS/${Session}_T1w_MPR_vNav_4e_RMS.nii.gz"
		T2wInputImages="${StudyFolder}/${Session}/unprocessed/T2w_SPC_vNav/${Session}_T2w_SPC_vNav.nii.gz"
			
		if [ ! -e ${T1wInputImages} ]; then
			echo "Expected input T1w image: ${T1wInputImages} "
			echo "Does not exist"
			exit 1
		fi
			
		if [ ! -e ${T2wInputImages} ]; then
			echo "Expected input T2w image: ${T2wInputImages} "
			echo "Does not exist"
			exit 1
		fi
			
		# Templates
			
		# Hires T1w MNI template
		T1wTemplate="${HCPPIPEDIR_Templates}/MNI152_T1_0.8mm.nii.gz"
		
		# Hires brain extracted MNI template
		T1wTemplateBrain="${HCPPIPEDIR_Templates}/MNI152_T1_0.8mm_brain.nii.gz"
		
		# Lowres T1w MNI template
		T1wTemplate2mm="${HCPPIPEDIR_Templates}/MNI152_T1_2mm.nii.gz"
		
		# Hires T2w MNI Template
		T2wTemplate="${HCPPIPEDIR_Templates}/MNI152_T2_0.8mm.nii.gz"
		
		# Hires T2w brain extracted MNI Template
		T2wTemplateBrain="${HCPPIPEDIR_Templates}/MNI152_T2_0.8mm_brain.nii.gz"
		
		# Lowres T2w MNI Template
		T2wTemplate2mm="${HCPPIPEDIR_Templates}/MNI152_T2_2mm.nii.gz"
		
		# Hires MNI brain mask template
		TemplateMask="${HCPPIPEDIR_Templates}/MNI152_T1_0.8mm_brain_mask.nii.gz"
		
		# Lowres MNI brain mask template
		Template2mmMask="${HCPPIPEDIR_Templates}/MNI152_T1_2mm_brain_mask_dil.nii.gz"
		
		# FNIRT 2mm T1w Config
		FNIRTConfig="${HCPPIPEDIR_Config}/T1_2_MNI152_2mm.cnf"
		
		# Location of Coeffs file or "NONE" to skip
		# GradientDistortionCoeffs="${HCPPIPEDIR_Config}/Prisma_3T_coeff_AS82.grad"
		
		# Set to NONE to skip gradient distortion correction
		GradientDistortionCoeffs="NONE"
		
		# BrainSize in mm, 150 for humans
		BrainSize="150"
		
		# ----------------------------------------------------------------------
		# Variables related to using Siemens specific Gradient Echo Field Maps
		# NOT USED IN THIS CASE
		# ----------------------------------------------------------------------
			
		# The MagnitudeInputName variable should be set to a 4D magitude volume
		# with two 3D timepoints or "NONE" if not used
		MagnitudeInputName="NONE"
		
		# The PhaseInputName variable should be set to a 3D phase difference
		# volume or "NONE" if not used
		PhaseInputName="NONE"
		
		# The TE variable should be set to 2.46ms for 3T scanner, 1.02ms for 7T
		# scanner or "NONE" if not using
		TE="NONE"
		
		# The values set below are for the LifeSpan Aging Protocol using
		# a Prisma 3T scanner
		
		# See the DwellTime value in the JSON Sidecar file corresponding to the T1w scan file
		# "DwellTime": 2.1e-06
		T1wSampleSpacing="0.000002100"
		
		# See the DwellTime value in the JSON Sidecar file corresponding to the T2w scan file
		# "DwellTime": 2.1e-06		
		T2wSampleSpacing="0.000002100"
		
		# Readout Distortion Correction:
		#
		#	Currently supported Averaging and readout distortion correction
		#	methods: (i.e. supported values for the AvgrdcSTRING variable in this
		#	script and the --avgrdcmethod= command line option for the
		#	PreFreeSurferPipeline.sh script.)
		#
		#	"NONE"
		#	  Average any repeats but do no readout distortion correction
		#
		#	"FIELDMAP"
		#	  This value is equivalent to the "SiemensFieldMap" value described
		#	  below. Use of the "SiemensFieldMap" value is prefered, but
		#	  "FIELDMAP" is included for backward compatibility with earlier versions
		#	  of these scripts that only supported use of Siemens-specific
		#	  Gradient Echo Field Maps and did not support Gradient Echo Field
		#	  Maps from any other scanner vendor.
		#
		#	"TOPUP"
		#	  Average any repeats and use Spin Echo Field Maps for readout
		#	  distortion correction
		#
		#	"GeneralElectricFieldMap"
		#	  Average any repeats and use General Electric specific Gradient
		#	  Echo Field Map for readout distortion correction
		#
		#	"SiemensFieldMap"
		#	  Average any repeats and use Siemens specific Gradient Echo
		#	  Field Maps for readout distortion correction
		#
		# Current Setup is to use TOPUP and Spin Echo Field Maps
		#
		AvgrdcSTRING="TOPUP"
			
		# Spin Echo Field Maps
		
		PositiveFieldMaps=$(ls ${StudyFolder}/${Session}/unprocessed/T1w_MPR_vNav_4e_RMS/${Session}_SpinEchoFieldMap*PA.nii.gz)
		NegativeFieldMaps=$(ls ${StudyFolder}/${Session}/unprocessed/T1w_MPR_vNav_4e_RMS/${Session}_SpinEchoFieldMap*AP.nii.gz)
			
		# Take the first found of each field map
		SpinEchoPhaseEncodePositive=${PositiveFieldMaps##* }
		SpinEchoPhaseEncodeNegative=${NegativeFieldMaps##* }

		# Spin Echo Echo Spacing
		# See the EffectiveEchoSpacing value in the JSON sidecar file corresponding to the SpinEchoFieldMap file
		# "EffectiveEchoSpacing": 0.000580009
		SEEchoSpacing="0.000580009"

		# Default file to use when using SEFMs
		TopupConfig="${HCPPIPEDIR_Config}/b02b0.cnf"
		
		# Spin Echo Unwarp Direction
		# See the PhaseEncodingDirection value in the JSON sidecar file corresponding to the SpinEchoFieldMap file
		# "PhaseEncodingDirection": "j"
		SEUnwarpDir="j"
		
		# See the ReadoutDirection value in the JSON sidecare file corresponding to the T1w file
		# "ReadoutDirection": "k"
		# x,y,z corresponds to i,j,k
		UnwarpDir="z"
		
		# Build the PreFreeSurferPipeline.sh script invocation command to run
		# with all the specified parameter values
		
		PreFreeSurferCmd=()
		if [ -n "${queuing_command}" ]; then
			PreFreeSurferCmd+=("${queuing_command}")
		fi
		PreFreeSurferCmd+=("${HCPPIPEDIR}/PreFreeSurfer/PreFreeSurferPipeline.sh")
		PreFreeSurferCmd+=("--path=${StudyFolder}")
		PreFreeSurferCmd+=("--subject=${Session}")
		PreFreeSurferCmd+=("--t1=${T1wInputImages}")
		PreFreeSurferCmd+=("--t2=${T2wInputImages}")
		PreFreeSurferCmd+=("--t1template=${T1wTemplate}")
		PreFreeSurferCmd+=("--t1templatebrain=${T1wTemplateBrain}")
		PreFreeSurferCmd+=("--t1template2mm=${T1wTemplate2mm}")
		PreFreeSurferCmd+=("--t2template=${T2wTemplate}")
		PreFreeSurferCmd+=("--t2templatebrain=${T2wTemplateBrain}")
		PreFreeSurferCmd+=("--t2template2mm=${T2wTemplate2mm}")
		PreFreeSurferCmd+=("--templatemask=${TemplateMask}")
		PreFreeSurferCmd+=("--template2mmmask=${Template2mmMask}")
		PreFreeSurferCmd+=("--fnirtconfig=${FNIRTConfig}")
		PreFreeSurferCmd+=("--gdcoeffs=${GradientDistortionCoeffs}")
		PreFreeSurferCmd+=("--brainsize=${BrainSize}")
		PreFreeSurferCmd+=("--echodiff=${TE}")
		PreFreeSurferCmd+=("--t1samplespacing=${T1wSampleSpacing}")
		PreFreeSurferCmd+=("--t2samplespacing=${T2wSampleSpacing}")
		PreFreeSurferCmd+=("--avgrdcmethod=${AvgrdcSTRING}")
		PreFreeSurferCmd+=("--SEPhasePos=${SpinEchoPhaseEncodePositive}")
		PreFreeSurferCmd+=("--SEPhaseNeg=${SpinEchoPhaseEncodeNegative}")
		PreFreeSurferCmd+=("--seechospacing=${SEEchoSpacing}")
		PreFreeSurferCmd+=("--topupconfig=${TopupConfig}")
		PreFreeSurferCmd+=("--seunwarpdir=${SEUnwarpDir}")
		PreFreeSurferCmd+=("--unwarpdir=${UnwarpDir}")
		PreFreeSurferCmd+=("--printcom=${PRINTCOM}")

		# Show the command 
		num_cmd_args=${#PreFreeSurferCmd[@]}
		echo "PreFreeSurfer command to execute:"
		for (( cmdindex = 0; cmdindex < num_cmd_args; ++cmdindex )); do
			echo "${PreFreeSurferCmd[cmdindex]}"
		done
		echo ""
		
		# Execute the command
		"${PreFreeSurferCmd[@]}"
		
	done
}

# Invoke the main function to get things started
main "$@"
