#!/bin/bash

#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # PreFreeSurferPipelineBatch.sh
#
# ## Copyright Notice
#
# Copyright (C) 2013-2019 The Human Connectome Project/The Connectome Coordination Facility
#
# * Washington University in St. Louis
# * University of Minnesota
# * Oxford University
#
# ## Author(s)
#
# * Matthew F. Glasser, Department of Anatomy and Neurobiology,
#	Washington University in St. Louis
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
# Preprocessing pipeline
#
# See [Glasser et al. 2013][GlasserEtAl].
#
# ## Prerequisites
#
# ### Installed software for processing HCP-YA data
#
# * FSL (version 5.0.6)
# * FreeSurfer (version 5.3.0-HCP)
# * gradunwarp (HCP version 1.0.2) - if doing gradient distortion correction
#
# ### Installed software for processing LifeSpan data
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

# Default location of study folder
DEFAULT_STUDY_FOLDER="${HOME}/projects/Pipelines_ExampleData"

# Default space delimited list of subject IDs
DEFAULT_SESSION_LIST="100307" 

# Default pipeline environment script
DEFAULT_ENVIRONMENT_SCRIPT="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh"

usage()
{
	cat <<EOF

PreFreeSurferPipelineBatch.sh: Example script for running the Pre-FreeSurfer phase of the HCP Structural
							   Preprocessing pipeline.

PARAMETERs are: [ ] = optional; < > = user supplied value

  [--help] : show this usage information and exit

  [--StudyFolder=<study folder>]
  [--study=<study folder>]
  [--working-dir=<study folder>]

	These are equivalent alternative ways for specifying the study folder in which
	to find the session or subject directories.

	If none of these options are specified, the study folder used defaults to:

	  ${DEFAULT_STUDY_FOLDER}

  [--Subject=<session or subject ID>]
  [--subject=<session or subject ID>]
  [--Session=<session or subject ID>]
  [--session=<session or subject ID>]

	These are equivalent alternative ways for specifying a session (or subject)
	within the study folder for which to run this processing.

	This parameter can be specified multiple times to create a list of 
	sessions to process. E.g. --session=100307 --subject=100287 --Session=190876
	would result in the following list of sessions to process: 100307 100287 190876

	If none of these options are specified, the list of sessions to process
	defaults to:

	  ${DEFAULT_SESSION_LIST}

  [--runlocal]
  [--run-local]

	These are equivalent alternative ways for specifying that processing should 
	occur "locally" (i.e. on this machine) as opposed to trying to submit the
	processing to a queuing system.

  [--lifespan]

	Using this option indicates that the processing should be run on data in a
	directory structure that takes the standard HCP/LifeSpan project form as
	opposed to the default directory structure which is the HCP Young Adult 
	(HCP-YA) form.

  [--env=<path to environment script>]
  [--env-script=<path to environment script>]

	These are equivalent alternative ways for specifying the path to the 
	environment script which sets the environment variables necessary
	to run this processing.

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
	unset p_lifespan_style
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
			--StudyFolder=*)
 				p_study_folder=${argument#*=}
				;;
			--study=*)
				p_study_folder=${argument#*=}
				;;
			--working-dir=*)
				p_study_folder=${argument#*=}
				;;
			--Subject=*)
				if [ -n "${p_session_list}" ]; then
					p_session_list+=" "
				fi
				p_session_list+=${argument#*=}
				;;
			--subject=*)
				if [ -n "${p_session_list}" ]; then
					p_session_list+=" "
				fi
				p_session_list+=${argument#*=}
				;;
			--Session=*)
				if [ -n "${p_session_list}" ]; then
					p_session_list+=" "
				fi
				p_session_list+=${argument#*=}
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
			--run-local)
				p_run_local="TRUE"
				;;
			--lifespan)
				p_lifespan_style="TRUE"
				;;
			--env=*)
				p_environment_script=${argument#*=}
				;;
			--env-script=*)
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
}

main()
{
	get_options "$@"
	
	# Gather options specified
	local StudyFolder="${p_study_folder}"
	local SessionList="${p_session_list}"
	local RunLocal="${p_run_local}"
	local LifeSpanStyle="${p_lifespan_style}"
	local EnvironmentScript="${p_environment_script}"
	
	# Report major script control variables to user
	echo ""
	echo "StudyFolder: ${StudyFolder}"
	echo "SessionList: ${SessionList}"
	echo "RunLocal: ${RunLocal}"
	echo "LifeSpanStyle: ${LifeSpanStyle}"
	echo "EnvironmentScript: ${EnvironmentScript}"
	echo ""
	
	# Set up pipeline environment variables and software
	source ${EnvironmentScript}
	
	# Report environment variables pointing to tools
	echo "FSLDIR: ${FSLDIR}"
	echo "FREESURFER_HOME: ${FREESURFER_HOME}"
	echo "HCPPIPEDIR: ${HCPPIPEDIR}"
	echo "CARET7DIR: ${CARET7DIR}"
	echo "PATH: ${PATH}"
	
	# Define processing queue to be used if submitted to job scheduler
	# if [ X$SGE_ROOT != X ] ; then
	#	 QUEUE="-q long.q"
	#	 QUEUE="-q veryshort.q"
	QUEUE="-q hcp_priority.q"
	# fi
	
	# If PRINTCOM is not a null or empty string variable, then
	# this script and other scripts that it calls will simply
	# print out the primary commands it otherwise would run.
	# This printing will be done using the command specified
	# in the PRINTCOM variable
	PRINTCOM=""
	# PRINTCOM="echo"

	# Establish queuing command based on command line option
	if [ -n "${RunLocal}" ] ; then
		queuing_command=""
	else
		queuing_command="${FSLDIR}/bin/fsl_sub ${QUEUE}"
	fi
			
	for Session in ${SessionList} ; do
		echo ""
		echo "Processing: ${Session}"
		echo ""
		
		# Scripts called by this script do NOT assume anything about the form of the
		# input names or paths. This batch script assumes either the HCP unprocessed
		# data naming convention or the LifeSpan unprocessed data naming convention
		# depending upon whether LifeSpanStyle is "TRUE".
		
		if [ "${LifeSpanStyle}" = "TRUE" ]; then
			
			# Input Images
			#
			# If LifeSpanStyle is "TRUE", then the LifeSpan unprocessed data naming convention
			# is used.
			
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

			echo ${SpinEchoPhaseEncodePositive}
			echo ${SpinEchoPhaseEncodeNegative}

			# --seechospacing=0.000580009
			# --topupconfig=/home/tbbrown/pipeline_tools/HCPpipelines/global/config/b02b0.cnf
			# --seunwarpdir=j
			# --unwarpdir=z
			
			
			
			# Run (or submit to be run) the PreFreeSurferPipeline.sh script
			# with all the specified parameter values

			PreFreeSurferCmd="${queuing_command} "
			PreFreeSurferCmd+="${HCPPIPEDIR}/PreFreeSurfer/PreFreeSurferPipeline.sh "
			PreFreeSurferCmd+=" --path=\"${StudyFolder}\" "
			PreFreeSurferCmd+="	--subject=\"${Session}\" "
			PreFreeSurferCmd+="	--t1=\"${T1wInputImages}\" "
			PreFreeSurferCmd+="	--t2=\"${T2wInputImages}\" "
			PreFreeSurferCmd+="	--t1template=\"${T1wTemplate}\" "
			PreFreeSurferCmd+="	--t1templatebrain=\"${T1wTemplateBrain}\" "
			PreFreeSurferCmd+="	--t1template2mm=\"${T1wTemplate2mm}\" "
			PreFreeSurferCmd+="	--t2template=\"${T2wTemplate}\" "
			PreFreeSurferCmd+="	--t2templatebrain=\"${T2wTemplateBrain}\" "
			PreFreeSurferCmd+="	--t2template2mm=\"${T2wTemplate2mm}\" "
			PreFreeSurferCmd+="	--templatemask=\"${TemplateMask}\" "
			PreFreeSurferCmd+="	--template2mmmask=\"${Template2mmMask}\" "
			PreFreeSurferCmd+="	--fnirtconfig=\"${FNIRTConfig}\" "
			PreFreeSurferCmd+="	--gdcoeffs=\"${GradientDistortionCoeffs}\" "
			PreFreeSurferCmd+="	--brainsize=\"${BrainSize}\" "
			PreFreeSurferCmd+="	--echodiff=\"${TE}\" "
			PreFreeSurferCmd+="	--t1samplespacing=\"${T1wSampleSpacing}\" "
			PreFreeSurferCmd+="	--t2samplespacing=\"${T2wSampleSpacing}\" "
			PreFreeSurferCmd+="	--avgrdcmethod=\"${AvgrdcSTRING}\" "
			PreFreeSurferCmd+=" --SEPhasePos=\"${SpinEchoPhaseEncodePositive}\" "
			PreFreeSurferCmd+=" --SEPhaseNeg=\"${SpinEchoPhaseEncodeNegative}\" "
			

			#				   --seechospacing="$SEEchoSpacing" \
			#				   --seunwarpdir="$SEUnwarpDir" \
			#				   --unwarpdir="$UnwarpDir" \
			#				   --topupconfig="$TopupConfig" \
			#				   --printcom=${PRINTCOM}
			
			
			echo "PreFreeSurferCmd: ${PreFreeSurferCmd}"			
			# ${PreFreeSurferCmd}
			
			
		else # Default to HCP style
			
			# Note that for the HCP naming convention, the "Session" and the "Subject" are
			# essentially equivalent. Sessions would be subject IDs like 100307, 110226, 997865, etc.
			Subject="${Session}"
			
			# If LifeSpanStyle is NOT "TRUE", then the HCP unprocessed data naming convention
			# is used, e.g.
			#
			# ${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_T1w_MPR1.nii.gz
			# ${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_T1w_MPR2.nii.gz
			#
			# ${StudyFolder}/${Subject}/unprocessed/3T/T2w_SPC1/${Subject}_3T_T2w_SPC1.nii.gz
			# ${StudyFolder}/${Subject}/unprocessed/3T/T2w_SPC2/${Subject}_3T_T2w_SPC2.nii.gz
			#
			# ${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_FieldMap_Magnitude.nii.gz
			# ${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_FieldMap_Phase.nii.gz
			
			# Detect Number of T1w Images and build list of full paths to T1w images
			numT1ws=$(ls ${StudyFolder}/${Subject}/unprocessed/3T | grep 'T1w_MPR.$' | wc -l)
			echo "Found ${numT1ws} T1w Images for subject: ${Subject}"
			T1wInputImages=""
			i=1
			while [ ${i} -le ${numT1ws} ] ; do
				echo "T1w ${i}"
				T1wInputImages=$(echo "${T1wInputImages}${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR${i}/${Subject}_3T_T1w_MRP${i}.nii.gz@")
				i=$(($i+1))
			done
			
			# Detect Number of T2w Images and build list of full paths to T2w images
			numT2ws=$(ls ${StudyFolder}/${Subject}/unprocessed/3T | grep 'T2w_SPC.$' | wc -l)
			echo "Found ${numT2ws} T2w Images for subject: ${Subject}"
			T2wInputImages=""
			i=1
			while [ ${i} -le ${numT2ws} ] ; do
				echo "T2w ${i}"
				T2wInputImages=$(echo "${T2wInputImages}${StudyFolder}/${Subject}/unprocessed/3T/T2w_SPC${i}/${Subject}_3T_T2w_SPC${i}.nii.gz@")
				i=$(($i+1))
			done
			
			# Scan settings:
			#
			# Change the Scan Settings (e.g. Sample Spacings and $UnwarpDir) to match your
			# structural images. These are set to match the HCP-YA ("Young Adult") Protocol by default.
			# (i.e., the study collected on the customized Connectom scanner).
			
			# Readout Distortion Correction:
			#
			# You have the option of using either gradient echo field maps or spin echo
			# field maps to perform readout distortion correction on your structural
			# images, or not to do readout distortion correction at all.
			#
			# The HCP Pipeline Scripts currently support the use of gradient echo field
			# maps or spin echo field maps as they are produced by the Siemens Connectom
			# Scanner. They also support the use of gradient echo field maps as generated
			# by General Electric scanners.
			#
			# Change either the gradient echo field map or spin echo field map scan
			# settings to match your data. This script is setup to use gradient echo
			# field maps from the Siemens Connectom Scanner collected using the HCP-YA Protocol.
			
			# Gradient Distortion Correction:
			#
			# If using gradient distortion correction, use the coefficents from your
			# scanner. The HCP gradient distortion coefficents are only available through
			# Siemens. Gradient distortion in standard scanners like the Trio is much
			# less than for the HCP Connectom scanner.
			
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
			# Current Setup is for Siemens specific Gradient Echo Field Maps
			#
			#	The following settings for AvgrdcSTRING, MagnitudeInputName,
			#	PhaseInputName, and TE are for using the Siemens specific
			#	Gradient Echo Field Maps that are collected and used in the
			#	standard HCP-YA protocol.
			#
			#	Note: The AvgrdcSTRING variable could also be set to the value
			#	"FIELDMAP" which is equivalent to "SiemensFieldMap".
			AvgrdcSTRING="SiemensFieldMap"
			
			# ----------------------------------------------------------------------
			# Variables related to using Siemens specific Gradient Echo Field Maps
			# ----------------------------------------------------------------------
			
			# The MagnitudeInputName variable should be set to a 4D magitude volume
			# with two 3D timepoints or "NONE" if not used
			MagnitudeInputName="${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_FieldMap_Magnitude.nii.gz"
			
			# The PhaseInputName variable should be set to a 3D phase difference
			# volume or "NONE" if not used
			PhaseInputName="${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_FieldMap_Phase.nii.gz"
			
			# The TE variable should be set to 2.46ms for 3T scanner, 1.02ms for 7T
			# scanner or "NONE" if not using
			TE="2.46"
			
			# ----------------------------------------------------------------------
			# Variables related to using Spin Echo Field Maps
			# ----------------------------------------------------------------------
			
			# The following variables would be set to values other than "NONE" for
			# using Spin Echo Field Maps (i.e. when AvgrdcSTRING="TOPUP")
			
			# The SpinEchoPhaseEncodeNegative variable should be set to the
			# spin echo field map volume with a negative phase encoding direction
			# (LR if using a pair of LR/RL Siemens Spin Echo Field Maps (SEFMs);
			# AP if using a pair of AP/PA Siemens SEFMS)
			# and set to "NONE" if not using SEFMs
			# (i.e. if AvgrdcSTRING is not equal to "TOPUP")
			#
			# Example values for when using Spin Echo Field Maps from a Siemens machine:
			#	${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_SpinEchoFieldMap_LR.nii.gz
			#	${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_SpinEchoFieldMap_AP.nii.gz
			SpinEchoPhaseEncodeNegative="NONE"
			
			# The SpinEchoPhaseEncodePositive variable should be set to the
			# spin echo field map volume with positive phase encoding direction
			# (RL if using a pair of LR/RL SEFMs; PA if using a AP/PA pair),
			# and set to "NONE" if not using Spin Echo Field Maps
			# (i.e. if AvgrdcSTRING is not equal to "TOPUP")
			#
			# Example values for when using Spin Echo Field Maps from a Siemens machine:
			#	${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_SpinEchoFieldMap_RL.nii.gz
			#	${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_SpinEchoFieldMap_PA.nii.gz
			SpinEchoPhaseEncodePositive="NONE"
			
			# "Effective" Echo Spacing of *Spin Echo Field Maps*. Specified in seconds.
			# Set to "NONE" if not used.
			# SEEchoSpacing = 1/(BWPPPE * ReconMatrixPE)
			#	where BWPPPE is the "BandwidthPerPixelPhaseEncode" = DICOM field (0019,1028) for Siemens, and
			#	ReconMatrixPE = size of the reconstructed SEFM images in the PE dimension
			# In-plane acceleration, phase oversampling, phase resolution, phase field-of-view, and interpolation
			# all potentially need to be accounted for (which they are in Siemen's reported BWPPPE)
			#
			# Example value for when using Spin Echo Field Maps from the HCP-YA
			#	0.000580002668012
			SEEchoSpacing="NONE"
			
			# Spin Echo Unwarping Direction (according to the *voxel* axes)
			# {x,y} (FSL nomenclature), or alternatively, {i,j} (BIDS nomenclature for the voxel axes)
			# Set to "NONE" if not used.
			#
			# Example values for when using Spin Echo Field Maps: {x,y} or {i,j}
			# Note: '+x' or '+y' are not supported. i.e., for positive values, DO NOT include the '+' sign
			# Note: Polarity not important here [i.e., don't use {x-,y-} or {i-,j-}]
			SEUnwarpDir="NONE"
			
			# Topup Configuration file
			# Set to "NONE" if not using SEFMs
			#
			# Default file to use when using SEFMs
			#	TopUpConfig="${HCPPIPEDIR_Config}/b02b0.cnf"
			TopupConfig="NONE"
			
			# ----------------------------------------------------------------------
			# Variables related to using General Electric specific Gradient Echo
			# Field Maps
			# ----------------------------------------------------------------------
			
			# The following variables would be set to values other than "NONE" for
			# using General Electric specific Gradient Echo Field Maps (i.e. when
			# AvgrdcSTRING="GeneralElectricFieldMap")
			
			# Example value for when using General Electric Gradient Echo Field Map
			#
			# GEB0InputName should be a General Electric style B0 fieldmap with two
			# volumes
			#	1) fieldmap in deg and
			#	2) magnitude,
			# set to NONE if using TOPUP or FIELDMAP/SiemensFieldMap
			#
			#	GEB0InputName="${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_GradientEchoFieldMap.nii.gz"
			GEB0InputName="NONE"
			
			# Templates
			
			# Hires T1w MNI template
			T1wTemplate="${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm.nii.gz"
			
			# Hires brain extracted MNI template
			T1wTemplateBrain="${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm_brain.nii.gz"
			
			# Lowres T1w MNI template
			T1wTemplate2mm="${HCPPIPEDIR_Templates}/MNI152_T1_2mm.nii.gz"
			
			# Hires T2w MNI Template
			T2wTemplate="${HCPPIPEDIR_Templates}/MNI152_T2_0.7mm.nii.gz"
			
			# Hires T2w brain extracted MNI Template
			T2wTemplateBrain="${HCPPIPEDIR_Templates}/MNI152_T2_0.7mm_brain.nii.gz"
			
			# Lowres T2w MNI Template
			T2wTemplate2mm="${HCPPIPEDIR_Templates}/MNI152_T2_2mm.nii.gz"
			
			# Hires MNI brain mask template
			TemplateMask="${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm_brain_mask.nii.gz"
			
			# Lowres MNI brain mask template
			Template2mmMask="${HCPPIPEDIR_Templates}/MNI152_T1_2mm_brain_mask_dil.nii.gz"
			
			# Structural Scan Settings
			#
			# "UnwarpDir" is the *readout* direction of the *structural* (T1w,T2w) images,
			# *after* the application of 'fslreorient2std' (which is built into PreFreeSurferPipeline.sh)
			# Do NOT confuse with "SEUnwarpDir" which is the *phase* encoding direction
			# of the Spin Echo Field Maps (if using them).
			# Note that polarity of UnwarpDir DOES matter.
			# Allowed values: {x,y,z,x-,y-,z-} (FSL nomenclature) or {i,j,k,i-,j-,k-} (BIDS nomenclature)
			#
			# set all these values to NONE if not doing readout distortion correction
			#
			# Sample values for when using General Electric structurals
			#	T1wSampleSpacing="0.000011999" # For General Electric scanners, 1/((0018,0095)*(0028,0010))
			#	T2wSampleSpacing="0.000008000" # For General Electric scanners, 1/((0018,0095)*(0028,0010))
			#	UnwarpDir="y"  ## MPH: This doesn't seem right. Is this accurate??
			
			# The values set below are for the HCP-YA Protocol using the Siemens
			# Connectom Scanner
			
			# DICOM field (0019,1018) in s or "NONE" if not used
			T1wSampleSpacing="0.0000074"
			
			# DICOM field (0019,1018) in s or "NONE" if not used
			T2wSampleSpacing="0.0000021"
			
			# z appears to be the appropriate polarity for the 3D structurals collected on Siemens scanners
			UnwarpDir="z"
			
			# Other Config Settings
			
			# BrainSize in mm, 150 for humans
			BrainSize="150"
			
			# FNIRT 2mm T1w Config
			FNIRTConfig="${HCPPIPEDIR_Config}/T1_2_MNI152_2mm.cnf"
			
			# Location of Coeffs file or "NONE" to skip
			# GradientDistortionCoeffs="${HCPPIPEDIR_Config}/coeff_SC72C_Skyra.grad"
			
			# Set to NONE to skip gradient distortion correction
			GradientDistortionCoeffs="NONE"
			
			# Run (or submit to be run) the PreFreeSurferPipeline.sh script
			# with all the specified parameter values
			
			PreFreeSurferCmd="${queuing_command} "
			PreFreeSurferCmd+="${HCPPIPEDIR}/PreFreeSurfer/PreFreeSurferPipeline.sh "
			PreFreeSurferCmd+=" --path=\"${StudyFolder}\" "
			PreFreeSurferCmd+=" --subject=\"${Subject}\" "
			PreFreeSurferCmd+=" --t1=\"${T1wInputImages}\" "
			PreFreeSurferCmd+=" --t2=\"${T2wInputImages}\" "
			PreFreeSurferCmd+=" --t1template=\"${T1wTemplate}\" "
			PreFreeSurferCmd+=" --t1templatebrain=\"${T1wTemplateBrain}\" "
			PreFreeSurferCmd+=" --t1template2mm=\"${T1wTemplate2mm}\" "
			PreFreeSurferCmd+=" --t2template=\"${T2wTemplate}\" "
			PreFreeSurferCmd+=" --t2templatebrain=\"${T2wTemplateBrain}\" "
			PreFreeSurferCmd+=" --t2template2mm=\"${T2wTemplate2mm}\" "
			PreFreeSurferCmd+=" --templatemask=\"${TemplateMask}\" "
			PreFreeSurferCmd+=" --template2mmmask=\"${Template2mmMask}\" "
			PreFreeSurferCmd+=" --brainsize=\"${BrainSize}\" "
			PreFreeSurferCmd+=" --fnirtconfig=\"${FNIRTConfig}\" "
			PreFreeSurferCmd+=" --fmapmag=\"${MagnitudeInputName}\" "
			PreFreeSurferCmd+=" --fmapphase=\"${PhaseInputName}\" "
			PreFreeSurferCmd+=" --fmapgeneralelectric=\"${GEB0InputName}\" "
			PreFreeSurferCmd+=" --echodiff=\"${TE}\" "
			PreFreeSurferCmd+=" --SEPhaseNeg=\"${SpinEchoPhaseEncodeNegative}\" "
			PreFreeSurferCmd+=" --SEPhasePos=\"${SpinEchoPhaseEncodePositive}\" "
			PreFreeSurferCmd+=" --seechospacing=\"${SEEchoSpacing}\" "
			PreFreeSurferCmd+=" --seunwarpdir=\"${SEUnwarpDir}\" "
			PreFreeSurferCmd+=" --t1samplespacing=\"${T1wSampleSpacing}\" "
			PreFreeSurferCmd+=" --t2samplespacing=\"${T2wSampleSpacing}\" "
			PreFreeSurferCmd+=" --unwarpdir=\"${UnwarpDir}\" "
			PreFreeSurferCmd+=" --gdcoeffs=\"${GradientDistortionCoeffs}\" "
			PreFreeSurferCmd+=" --avgrdcmethod=\"${AvgrdcSTRING}\" "
			PreFreeSurferCmd+=" --topupconfig=\"${TopupConfig}\" "
			PreFreeSurferCmd+=" --printcom=\"${PRINTCOM}\" "
			
			echo "PreFreeSurferCmd: ${PreFreeSurferCmd}"			
			# ${PreFreeSurferCmd}
			
		fi
		
	done
}

# Invoke the main function to get things started
main "$@"
