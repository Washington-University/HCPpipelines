#!/bin/bash

#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # PreFreeSurferPipelineBatch.sh
#
# ## Copyright Notice
#
# Copyright (C) 2013-2018 The Human Connectome Project
#
# * Washington University in St. Louis
# * University of Minnesota
# * Oxford University
#
# ## Author(s)
#
# * Matthew F. Glasser, Department of Anatomy and Neurobiology,
#   Washington University in St. Louis
# * Timothy B. Brown, Neuroinformatics Research Group,
#   Washington University in St. Louis
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
# ### Installed software
#
# * FSL (version 5.0.6)
# * FreeSurfer (version 5.3.0-HCP)
# * gradunwarp (HCP version 1.0.2) - if doing gradient distortion correction
#
# ### Environment variables
#
# Should be set in script file pointed to by EnvironmentScript variable.
# See setting of the EnvironmentScript variable in the main() function
# below.
#
# * FSLDIR - main FSL installation directory
# * FREESURFER_HOME - main FreeSurfer installation directory
# * HCPPIPEDIR - main HCP Pipelines installation directory
# * CARET7DIR - main Connectome Workbench installation directory
# * PATH - must point to where gradient_unwarp.py is if doing gradient unwarping
#
# <!-- References -->
# [HCP]: http://www.humanconnectome.org
# [GlasserEtAl]: http://www.ncbi.nlm.nih.gov/pubmed/23668970
#
#~ND~END~

# Function: get_batch_options
# Description
#
#   Retrieve the following command line parameter values if specified
#
#   --StudyFolder= - primary study folder containing subject ID subdirectories
#   --Subjlist=    - quoted, space separated list of subject IDs on which
#                    to run the pipeline
#   --runlocal     - if specified (without an argument), processing is run
#                    on "this" machine as opposed to being submitted to a
#                    computing grid
#
#   Set the values of the following global variables to reflect command
#   line specified parameters
#
#   command_line_specified_study_folder
#   command_line_specified_subj_list
#   command_line_specified_run_local
#
#   These values are intended to be used to override any values set
#   directly within this script file
get_batch_options() {
	local arguments=("$@")

	command_line_specified_study_folder=""
	command_line_specified_subj=""
	command_line_specified_run_local="FALSE"

	local index=0
	local numArgs=${#arguments[@]}
	local argument

	while [ ${index} -lt ${numArgs} ]; do
		argument=${arguments[index]}

		case ${argument} in
			--StudyFolder=*)
				command_line_specified_study_folder=${argument#*=}
				index=$(( index + 1 ))
				;;
			--Subject=*)
				command_line_specified_subj=${argument#*=}
				index=$(( index + 1 ))
				;;
			--runlocal)
				command_line_specified_run_local="TRUE"
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

# Function: main
# Description: main processing work of this script
main()
{
	get_batch_options "$@"

	# Set variable values that locate and specify data to process
	StudyFolder="${HOME}/projects/Pipelines_ExampleData" # Location of Subject folders (named by subjectID)
	Subjlist="100307 100610"                             # Space delimited list of subject IDs

	# Set variable value that sets up environment
	EnvironmentScript="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" # Pipeline environment script

	# Use any command line specified options to override any of the variable settings above
	if [ -n "${command_line_specified_study_folder}" ]; then
		StudyFolder="${command_line_specified_study_folder}"
	fi

	if [ -n "${command_line_specified_subj}" ]; then
		Subjlist="${command_line_specified_subj}"
	fi

	# Report major script control variables to user
	echo "StudyFolder: ${StudyFolder}"
	echo "Subjlist: ${Subjlist}"
	echo "EnvironmentScript: ${EnvironmentScript}"
	echo "Run locally: ${command_line_specified_run_local}"

	# Set up pipeline environment variables and software
	source "$EnvironmentScript"

	#NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
	#DO NOT include "-q " at the beginning
	#default to no queue, implying run local
	QUEUE=""
	#QUEUE="hcp_priority.q"

	#
	# Inputs:
	#
	# Scripts called by this script do NOT assume anything about the form of the
	# input names or paths. This batch script assumes the HCP raw data naming
	# convention, e.g.
	#
	# ${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_T1w_MPR1.nii.gz
	# ${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR2/${Subject}_3T_T1w_MPR2.nii.gz
	#
	# ${StudyFolder}/${Subject}/unprocessed/3T/T2w_SPC1/${Subject}_3T_T2w_SPC1.nii.gz
	# ${StudyFolder}/${Subject}/unprocessed/3T/T2w_SPC2/${Subject}_3T_T2w_SPC2.nii.gz
	#
	# ${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_FieldMap_Magnitude.nii.gz
	# ${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_FieldMap_Phase.nii.gz

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
	# by GE HealthCare scanners.
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

	# DO WORK

	# Cycle through specified subjects
	for Subject in $Subjlist ; do
		echo $Subject

		# Input Images

		# Detect Number of T1w Images and build list of full paths to
		# T1w images
		T1wInputImages=""
		numT1ws=0
		for folder in "${StudyFolder}/${Subject}/unprocessed/3T"/T1w_MPR?; do
			folderbase=$(basename "$folder")
			T1wInputImages+="$folder/${Subject}_3T_$folderbase.nii.gz@"
			numT1ws=$((numT1ws + 1))
		done
		echo "Found ${numT1ws} T1w Images for subject ${Subject}"

		# Detect Number of T2w Images and build list of full paths to
		# T2w images
		T2wInputImages=""
		numT2ws=0
		for folder in "${StudyFolder}/${Subject}/unprocessed/3T"/T2w_SPC?; do
			folderbase=$(basename "$folder")
			T2wInputImages+="$folder/${Subject}_3T_$folderbase.nii.gz@"
			numT2ws=$((numT2ws + 1))
		done
		echo "Found ${numT2ws} T2w Images for subject ${Subject}"

		# Readout Distortion Correction:
		#
		#   Currently supported Averaging and readout distortion correction
		#   methods: (i.e. supported values for the AvgrdcSTRING variable in this
		#   script and the --avgrdcmethod= command line option for the
		#   PreFreeSurferPipeline.sh script.)
		#
		#   "NONE"
		#     Average any repeats but do no readout distortion correction
		#
		#   "FIELDMAP"
		#     This value is equivalent to the "SiemensFieldMap" value described
		#     below. Use of the "SiemensFieldMap" value is prefered, but
		#     "FIELDMAP" is included for backward compatibility with earlier versions
		#     of these scripts that only supported use of Siemens-specific
		#     Gradient Echo Field Maps and did not support Gradient Echo Field
		#     Maps from any other scanner vendor.
		#
		#   "TOPUP"
		#     Average any repeats and use Spin Echo Field Maps for readout
		#     distortion correction
		#
		#   "GEHealthCareLegacyFieldMap"
		#     Average any repeats and use GE HeathCare Legacy specific Gradient
		#     Echo Field Map for readout distortion correction. 
		#	  The Legacy fieldmap is a two volume file: 1. field map in Hz and 2. magnitude image.
		# 	  Use "GEB0InputName" variable to specify the 2-Volume file. 
		#	  Set "DeltaTE" variable to the EchoTime difference (TE2-TE1). 
		#	 
		#	"GEHealthCareFieldMap" 
		#	  Average any repeats and use GE HealthCare specific Gradient Echo
		#     Field Maps for readout distortion correction
		#	  This uses two separate NIfTI files for the fieldmap in Hz and the magnitude image
		#	  Use variables "MagnitudeInputName", "PhaseInputName" and "DeltaTE"
		#
		#   "SiemensFieldMap"
		#     Average any repeats and use Siemens specific Gradient Echo
		#     Field Maps for readout distortion correction
		#
		# Current Setup is for Siemens specific Gradient Echo Field Maps
		#
		#   The following settings for AvgrdcSTRING, MagnitudeInputName,
		#   PhaseInputName, and DeltaTE are for using the Siemens specific
		#   Gradient Echo Field Maps that are collected and used in the
		#   standard HCP-YA protocol.
		#
		#   Note: The AvgrdcSTRING variable could also be set to the value
		#   "FIELDMAP" which is equivalent to "SiemensFieldMap".
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

		# The DeltaTE (echo time difference) of the fieldmap.  For HCP Young Adult data, this variable would typically be 2.46ms for 3T scans, 1.02ms for 7T
		# scans, or "NONE" if not using readout distortion correction
		DeltaTE="2.46"

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
		#   ${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_SpinEchoFieldMap_LR.nii.gz
		#   ${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_SpinEchoFieldMap_AP.nii.gz
		SpinEchoPhaseEncodeNegative="NONE"

		# The SpinEchoPhaseEncodePositive variable should be set to the
		# spin echo field map volume with positive phase encoding direction
		# (RL if using a pair of LR/RL SEFMs; PA if using a AP/PA pair),
		# and set to "NONE" if not using Spin Echo Field Maps
		# (i.e. if AvgrdcSTRING is not equal to "TOPUP")
		#
		# Example values for when using Spin Echo Field Maps from a Siemens machine:
		#   ${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_SpinEchoFieldMap_RL.nii.gz
		#   ${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_SpinEchoFieldMap_PA.nii.gz
		SpinEchoPhaseEncodePositive="NONE"

		# "Effective" Echo Spacing of *Spin Echo Field Maps*. Specified in seconds.
		# Set to "NONE" if not used.
		# SEEchoSpacing = 1/(BWPPPE * ReconMatrixPE)
		#   where BWPPPE is the "BandwidthPerPixelPhaseEncode" = DICOM field (0019,1028) for Siemens, and
		#   ReconMatrixPE = size of the reconstructed SEFM images in the PE dimension
		# In-plane acceleration, phase oversampling, phase resolution, phase field-of-view, and interpolation
		# all potentially need to be accounted for (which they are in Siemen's reported BWPPPE)
		#
		# Example value for when using Spin Echo Field Maps from the HCP-YA
		#   0.000580002668012
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
		#   TopUpConfig="${HCPPIPEDIR_Config}/b02b0.cnf"
		TopupConfig="NONE"

		# ----------------------------------------------------------------------
		# Variables related to using GE HealthCare Legacy specific Gradient Echo
		# Field Maps (GEHealthCareLegacyFieldMap)
		# ----------------------------------------------------------------------

		# The following variables would be set to values other than "NONE" for
		# using GE HealthCare Legacy specific Gradient Echo Field Maps (i.e. when
		# AvgrdcSTRING="GEHealthCareLegacyFieldMap")

		# Example value for when using GE HealthCare Legacy Gradient Echo Field Map
		#
		# GEB0InputName should be a GE HealthCare Legacy style B0 fieldmap with two
		# volumes
		#   1) fieldmap in hertz and
		#   2) magnitude image,
		# set to NONE if using TOPUP or FIELDMAP/SiemensFieldMap or GEHealthCareFieldMap
		#  
		# For Example:
		#   GEB0InputName="${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_GradientEchoFieldMap.nii.gz"
		#	DeltaTE=2.304 
		#   Here DeltaTE refers to the DeltaTE in ms
		#   NOTE: At 3T, the DeltaTE is *usually* 2.304ms for 2D-B0MAP and 2.272ms 3D-B0MAP.
		#   NOTE: The Delta can be found in json files (if data converted with recent dcm2niix)
		#   NOTE: Then DeltaTE = (EchoTime2-EchoTime1)*1000
		#	NOTE: In the DICOM, DeltaTE in ms = round(abs(1e6/( 2*pi*(0019,10E2) )))*1e-3 
		GEB0InputName="NONE"

		# ---------------------------------------------------------------
		# Variables related to using GE HealthCare specific Gradient Echo
		# Field Maps (GEHealthCareFieldMap)
		# ----------------------------------------------------------------

		# The following variables would be set to values other than "NONE" for
		# using GE HealthCare specific Gradient Echo Field Maps (i.e. when
		# AvgrdcSTRING="GEHealthCareFieldMap"). 

		# Example: set MagnitudeInputName to magnitude image, set PhaseInputName 
		# to the input fieldmap in Hertz and DeltaTE 
		# (for DeltaTE see NOTE above)
		#
		# MagnitudeInputName="${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_BOMap_Magnitude.nii.gz"
		# PhaseInputName="${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_B0Map_fieldmaphz.nii.gz"
		# DeltaTE="2.272"

		# ---------------------------------------------------------------

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
		#   T1wSampleSpacing="0.000011999" # For General Electric scanners, 1/((0018,0095)*(0028,0010))
		#   T2wSampleSpacing="0.000008000" # For General Electric scanners, 1/((0018,0095)*(0028,0010))
		#   UnwarpDir="y"  ## MPH: This doesn't seem right. Is this accurate??

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

		# Establish queuing command based on command line option or empty queue name
		if [[ "${command_line_specified_run_local}" == "TRUE" || "$QUEUE" == "" ]] ; then
			echo "About to locally run ${HCPPIPEDIR}/PreFreeSurfer/PreFreeSurferPipeline.sh"
			queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
		else
			echo "About to use fsl_sub to queue ${HCPPIPEDIR}/PreFreeSurfer/PreFreeSurferPipeline.sh"
			queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE")
		fi

		# Run (or submit to be run) the PreFreeSurferPipeline.sh script
		# with all the specified parameter values

		"${queuing_command[@]}" "$HCPPIPEDIR"/PreFreeSurfer/PreFreeSurferPipeline.sh \
			--path="$StudyFolder" \
			--subject="$Subject" \
			--t1="$T1wInputImages" \
			--t2="$T2wInputImages" \
			--t1template="$T1wTemplate" \
			--t1templatebrain="$T1wTemplateBrain" \
			--t1template2mm="$T1wTemplate2mm" \
			--t2template="$T2wTemplate" \
			--t2templatebrain="$T2wTemplateBrain" \
			--t2template2mm="$T2wTemplate2mm" \
			--templatemask="$TemplateMask" \
			--template2mmmask="$Template2mmMask" \
			--brainsize="$BrainSize" \
			--fnirtconfig="$FNIRTConfig" \
			--fmapmag="$MagnitudeInputName" \
			--fmapphase="$PhaseInputName" \
			--fmapcombined="$GEB0InputName" \
			--echodiff="$DeltaTE" \
			--SEPhaseNeg="$SpinEchoPhaseEncodeNegative" \
			--SEPhasePos="$SpinEchoPhaseEncodePositive" \
			--seechospacing="$SEEchoSpacing" \
			--seunwarpdir="$SEUnwarpDir" \
			--t1samplespacing="$T1wSampleSpacing" \
			--t2samplespacing="$T2wSampleSpacing" \
			--unwarpdir="$UnwarpDir" \
			--gdcoeffs="$GradientDistortionCoeffs" \
			--avgrdcmethod="$AvgrdcSTRING" \
			--topupconfig="$TopupConfig"

	done
}

# Invoke the main function to get things started
main "$@"
