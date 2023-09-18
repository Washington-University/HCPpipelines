#!/bin/bash 
#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # PreFreeSurferPipeline.sh
#
# ## Copyright Notice
#
# Copyright (C) 2013-2014 The Human Connectome Project
#
# * Washington University in St. Louis
# * University of Minnesota
# * Oxford University
#
# ## Author(s)
#
# * Matthew F. Glasser, Department of Anatomy and Neurobiology, Washington University in St. Louis
# * Mark Jenkinson, FMRIB Centre, Oxford University
# * Timothy B. Brown, Neuroinformatics Research Group, Washington University in St. Louis
# * Modifications to support General Electric Gradient Echo field maps for readout distortion correction
#   are based on example code provided by Gaurav Patel, Columbia University
#
# ## Product
#
# [Human Connectome Project][HCP] (HCP) Pipelines
#
# ## License
#
# See the [LICENSE](https://github.com/Washington-University/Pipelines/blob/master/LICENSE.md) file
#
# ## Description
#
# This script, PreFreeSurferPipeline.sh, is the first of 3 sub-parts of the
# Structural Preprocessing phase of the [HCP][HCP] Minimal Preprocessing Pipelines.
#
# See [Glasser et al. 2013][GlasserEtAl].
#
# This script implements the PreFreeSurfer Pipeline referred to in that publication.
#
# The primary purposes of the PreFreeSurfer Pipeline are:
#
# 1. To average any image repeats (i.e. multiple T1w or T2w images available)
# 2. To create a native, undistorted structural volume space for the subject
#    * Subject images in this native space will be distortion corrected
#      for gradient and b0 distortions and rigidly aligned to the axes
#      of the MNI space. "Native, undistorted structural volume space"
#      is sometimes shortened to the "subject's native space" or simply
#      "native space".
# 3. To provide an initial robust brain extraction
# 4. To align the T1w and T2w structural images (register them to the native space)
# 5. To perform bias field correction
# 6. To register the subject's native space to the MNI space
#
# ## Prerequisites:
#
# ### Installed Software
#
# * [FSL][FSL] - FMRIB's Software Library (version 5.0.6)
#
# ### Environment Variables
#
# * HCPPIPEDIR
#
#   The "home" directory for the version of the HCP Pipeline Tools product
#   being used. E.g. /nrgpackages/tools.release/hcp-pipeline-tools-V3.0
#
# * HCPPIPEDIR_Global
#
#   Location of shared sub-scripts that are used to carry out some of the
#   steps of the PreFreeSurfer pipeline and are also used to carry out
#   some steps of other pipelines.
#
# * FSLDIR
#
#   Home directory for [FSL][FSL] the FMRIB Software Library from Oxford
#   University
#
# ### Image Files
#
# At least one T1 weighted image and one T2 weighted image are required
# for this script to work.
#
# ### Output Directories
#
# Command line arguments are used to specify the StudyFolder (--path) and
# the Subject (--subject).  All outputs are generated within the tree rooted
# at ${StudyFolder}/${Subject}.  The main output directories are:
#
# * The T1wFolder: ${StudyFolder}/${Subject}/T1w
# * The T2wFolder: ${StudyFolder}/${Subject}/T2w
# * The AtlasSpaceFolder: ${StudyFolder}/${Subject}/MNINonLinear
#
# All outputs are generated in directories at or below these three main
# output directories.  The full list of output directories is:
#
# * ${T1wFolder}/T1w${i}_GradientDistortionUnwarp
# * ${T1wFolder}/AverageT1wImages
# * ${T1wFolder}/ACPCAlignment
# * ${T1wFolder}/BrainExtraction_FNIRTbased
# * ${T1wFolder}/xfms - transformation matrices and warp fields
#
# * ${T2wFolder}/T2w${i}_GradientDistortionUnwarp
# * ${T2wFolder}/AverageT1wImages
# * ${T2wFolder}/ACPCAlignment
# * ${T2wFolder}/BrainExtraction_FNIRTbased
# * ${T2wFolder}/xfms - transformation matrices and warp fields
#
# * ${T2wFolder}/T2wToT1wDistortionCorrectAndReg
# * ${T1wFolder}/BiasFieldCorrection_sqrtT1wXT2w
#
# * ${AtlasSpaceFolder}
# * ${AtlasSpaceFolder}/xfms
#
# Note that no assumptions are made about the input paths with respect to the
# output directories. All specification of input files is done via command
# line arguments specified when this script is invoked.
#
# Also note that the following output directories are created:
#
# * T1wFolder, which is created by concatenating the following three option
#   values: --path / --subject / --t1
# * T2wFolder, which is created by concatenating the following three option
#   values: --path / --subject / --t2
#
# These two output directories must be different. Otherwise, various output
# files with standard names contained in such subdirectories, e.g.
# full2std.mat, would overwrite each other).  If this script is modified,
# then those two output directories must be kept distinct.
#
# ### Output Files
#
# * T1wFolder Contents: TODO
# * T2wFolder Contents: TODO
# * AtlasSpaceFolder Contents: TODO
#
# <!-- References -->
# [HCP]: http://www.humanconnectome.org
# [GlasserEtAl]: http://www.ncbi.nlm.nih.gov/pubmed/23668970
# [FSL]: http://fsl.fmrib.ox.ac.uk
#
#~ND~END~

# ------------------------------------------------------------------------------
#  Code Start
# ------------------------------------------------------------------------------

# -----------------------------------------------------------------------------------
#  Constants for specification of Averaging and Readout Distortion Correction Method
# -----------------------------------------------------------------------------------

NONE_METHOD_OPT="NONE"
FIELDMAP_METHOD_OPT="FIELDMAP"
SIEMENS_METHOD_OPT="SiemensFieldMap"
SPIN_ECHO_METHOD_OPT="TOPUP"
GENERAL_ELECTRIC_METHOD_OPT="GeneralElectricFieldMap"
PHILIPS_METHOD_OPT="PhilipsFieldMap"

# ------------------------------------------------------------------------------
#  Usage Description Function
# ------------------------------------------------------------------------------

script_name=$(basename "${0}")

show_usage() {
  cat <<EOF

${script_name}

Usage: ${script_name} [options]

  --path=<path>                       Path to study data folder (required)
                                      Used with --subject input to create full path to root
                                      directory for all outputs generated as path/subject
  --subject=<subject>                 Subject ID (required)
                                      Used with --path input to create full path to root
                                      directory for all outputs generated as path/subject
  --t1=<T1w images>                   An @ symbol separated list of full paths to T1-weighted
                                      (T1w) structural images for the subject (required)
  --t2=<T2w images>                   An @ symbol separated list of full paths to T2-weighted
                                      (T2w) structural images for the subject (required for 
                                      hcp-style data, can be NONE for legacy-style data, 
                                      see --processing-mode option)
  --t1template=<file path>            MNI T1w template
  --t1templatebrain=<file path>       Brain extracted MNI T1wTemplate
  --t1template2mm=<file path>         MNI 2mm T1wTemplate
  --t2template=<file path>            MNI T2w template
  --t2templatebrain=<file path>       Brain extracted MNI T2wTemplate
  --t2template2mm=<file path>         MNI 2mm T2wTemplate
  --templatemask=<file path>          Brain mask MNI Template
  --template2mmmask=<file path>       Brain mask MNI 2mm Template
  --brainsize=<size value>            Brain size estimate in mm, 150 for humans
  --fnirtconfig=<file path>           FNIRT 2mm T1w Configuration file
  --fmapmag=<file path>               Siemens/Philips Gradient Echo Fieldmap magnitude file
  --fmapphase=<file path>             Siemens/Philips Gradient Echo Fieldmap phase file
  --fmapgeneralelectric=<file path>   General Electric Gradient Echo Field Map file
                                      Two volumes in one file
                                      1. field map in deg
                                      2. magnitude
  --echodiff=<delta TE>               Delta TE in ms for field map or "NONE" if
                                      not used
  --SEPhaseNeg={<file path>, NONE}    For spin echo field map, path to volume with
                                      a negative phase encoding direction (LR in
                                      HCP data), set to "NONE" if not using Spin
                                      Echo Field Maps
  --SEPhasePos={<file path>, NONE}    For spin echo field map, path to volume with
                                      a positive phase encoding direction (RL in
                                      HCP data), set to "NONE" if not using Spin
                                      Echo Field Maps
  --seechospacing=<seconds>           Effective Echo Spacing of Spin Echo Field Map,
                                      (in seconds) or "NONE" if not used
  --seunwarpdir={x,y,NONE}            Phase encoding direction (according to the *voxel* axes)
             or={i,j,NONE}            of the spin echo field map. 
                                      (Only applies when using a spin echo field map.)
  --t1samplespacing=<seconds>         T1 image sample spacing, "NONE" if not used
  --t2samplespacing=<seconds>         T2 image sample spacing, "NONE" if not used
  --unwarpdir={x,y,z,x-,y-,z-}        Readout direction of the T1w and T2w images (according to the *voxel axes)
           or={i,j,k,i-,j-,k-}        (Used with either a gradient echo field map 
                                      or a spin echo field map)
  --gdcoeffs=<file path>              File containing gradient distortion
                                      coefficients, Set to "NONE" to turn off
  --avgrdcmethod=<avgrdcmethod>       Averaging and readout distortion correction method. 
                                      See below for supported values.

      "${NONE_METHOD_OPT}"
         average any repeats with no readout distortion correction

      "${SPIN_ECHO_METHOD_OPT}"
         average any repeats and use Spin Echo Field Maps for readout
         distortion correction

      "${PHILIPS_METHOD_OPT}"
         average any repeats and use Philips specific Gradient Echo
         Field Maps for readout distortion correction

      "${GENERAL_ELECTRIC_METHOD_OPT}"
         average any repeats and use General Electric specific Gradient
         Echo Field Maps for readout distortion correction

      "${SIEMENS_METHOD_OPT}"
         average any repeats and use Siemens specific Gradient Echo
         Field Maps for readout distortion correction

      "${FIELDMAP_METHOD_OPT}"
         equivalent to "${SIEMENS_METHOD_OPT}" (preferred)
         This option value is maintained for backward compatibility.

  --topupconfig=<file path>           Configuration file for topup or "NONE" if not used
  [--bfsigma=<value>]                 Bias Field Smoothing Sigma (optional)
  [--custombrain=(NONE|MASK|CUSTOM)]  If PreFreeSurfer has been run before and you have created a custom
                                      brain mask saved as "<subject>/T1w/custom_acpc_dc_restore_mask.nii.gz", specify "MASK". 
                                      If PreFreeSurfer has been run before and you have created custom structural images, e.g.: 
                                      - "<subject>/T1w/T1w_acpc_dc_restore_brain.nii.gz"
                                      - "<subject>/T1w/T1w_acpc_dc_restore.nii.gz"
                                      - "<subject>/T1w/T2w_acpc_dc_restore_brain.nii.gz"
                                      - "<subject>/T1w/T2w_acpc_dc_restore.nii.gz"
                                      to be used when peforming MNI152 Atlas registration, specify "CUSTOM".
                                      When "MASK" or "CUSTOM" is specified, only the AtlasRegistration step is run.
                                      If the parameter is omitted or set to NONE (the default), 
                                      standard image processing will take place.
                                      If using "MASK" or "CUSTOM", the data still needs to be staged properly by 
                                      running FreeSurfer and PostFreeSurfer afterwards.
                                      NOTE: This option allows manual correction of brain images in cases when they
                                      were not successfully processed and/or masked by the regular use of the pipelines.
                                      Before using this option, first ensure that the pipeline arguments used were 
                                      correct and that templates are a good match to the data.
  [--processing-mode=(HCPStyleData|   Controls whether the HCP acquisition and processing guidelines should be treated as requirements.
               LegacyStyleData)]      "HCPStyleData" (the default) follows the processing steps described in Glasser et al. (2013) 
                                         and requires 'HCP-Style' data acquistion. 
                                      "LegacyStyleData" allows additional processing functionality and use of some acquisitions
                                         that do not conform to 'HCP-Style' expectations.
                                         In this script, it allows not having a high-resolution T2w image.

EOF
}

# Allow script to return a Usage statement, before any other output or checking
if [ "$#" = "0" ]; then
    show_usage
    exit 1
fi

# ------------------------------------------------------------------------------
#  Check that HCPPIPEDIR is defined and Load Function Libraries
# ------------------------------------------------------------------------------

if [ -z "${HCPPIPEDIR}" ]; then
  echo "${script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
  exit 1
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source ${HCPPIPEDIR}/global/scripts/opts.shlib                 # Command line option functions
source ${HCPPIPEDIR}/global/scripts/processingmodecheck.shlib  # Check processing mode requirements

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
	show_usage
	exit 0
fi

${HCPPIPEDIR}/show_version

# ------------------------------------------------------------------------------
#  Verify required environment variables are set and log value
# ------------------------------------------------------------------------------

log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FSLDIR
log_Check_Env_Var HCPPIPEDIR_Global

HCPPIPEDIR_PreFS=${HCPPIPEDIR}/PreFreeSurfer/scripts

# ------------------------------------------------------------------------------
#  Parse Command Line Options
# ------------------------------------------------------------------------------

log_Msg "Platform Information Follows: "
uname -a

log_Msg "Parsing Command Line Options"

StudyFolder=`opts_GetOpt1 "--path" $@`  # "$1" #Path to subject's data folder
Subject=`opts_GetOpt1 "--subject" $@`  # "$2" #SubjectID
T1wInputImages=`opts_GetOpt1 "--t1" $@`  # "$3" #T1w1@T1w2@etc..
T2wInputImages=`opts_GetOpt1 "--t2" $@`  # "$4" #T2w1@T2w2@etc..
T1wTemplate=`opts_GetOpt1 "--t1template" $@`  # "$5" #MNI template
T1wTemplateBrain=`opts_GetOpt1 "--t1templatebrain" $@`  # "$6" #Brain extracted MNI T1wTemphostlate
T1wTemplate2mm=`opts_GetOpt1 "--t1template2mm" $@`  # "$7" #MNI2mm T1wTemplate
T2wTemplate=`opts_GetOpt1 "--t2template" $@`  # "${8}" #MNI T2wTemplate
T2wTemplateBrain=`opts_GetOpt1 "--t2templatebrain" $@`  # "$9" #Brain extracted MNI T2wTemplate
T2wTemplate2mm=`opts_GetOpt1 "--t2template2mm" $@`  # "${10}" #MNI2mm T2wTemplate
TemplateMask=`opts_GetOpt1 "--templatemask" $@`  # "${11}" #Brain mask MNI Template
Template2mmMask=`opts_GetOpt1 "--template2mmmask" $@`  # "${12}" #Brain mask MNI2mm Template 
BrainSize=`opts_GetOpt1 "--brainsize" $@`  # "${13}" #StandardFOV mask for averaging structurals
FNIRTConfig=`opts_GetOpt1 "--fnirtconfig" $@`  # "${14}" #FNIRT 2mm T1w Config
MagnitudeInputName=`opts_GetOpt1 "--fmapmag" $@`  # "${16}" #Expects 4D magitude volume with two 3D timepoints
PhaseInputName=`opts_GetOpt1 "--fmapphase" $@`  # "${17}" #Expects 3D phase difference volume
TE=`opts_GetOpt1 "--echodiff" $@`  # "${18}" #delta TE for field map
SpinEchoPhaseEncodeNegative=`opts_GetOpt1 "--SEPhaseNeg" $@`
SpinEchoPhaseEncodePositive=`opts_GetOpt1 "--SEPhasePos" $@`
SpinEchoPhaseEncodeNegative2=`opts_GetOpt1 "--SEPhaseNeg2" $@`  # added for oppsing phase dir topup data in the 2nd axis - TH Mar 2023
SpinEchoPhaseEncodePositive2=`opts_GetOpt1 "--SEPhasePos2" $@`  # added for oppsing phase dir topup data in the 2nd axis - TH Mar 2023
DwellTime=`opts_GetOpt1 "--echospacing" $@`
SEUnwarpDir=`opts_GetOpt1 "--seunwarpdir" $@`
T1wSampleSpacing=`opts_GetOpt1 "--t1samplespacing" $@`  # "${19}" #DICOM field (0019,1018)
T2wSampleSpacing=`opts_GetOpt1 "--t2samplespacing" $@`  # "${20}" #DICOM field (0019,1018) 
UnwarpDir=`opts_GetOpt1 "--unwarpdir" $@`  # "${21}" #z appears to be best
GradientDistortionCoeffs=`opts_GetOpt1 "--gdcoeffs" $@`  # "${25}" #Select correct coeffs for scanner or "NONE" to turn off
AvgrdcSTRING=`opts_GetOpt1 "--avgrdcmethod" $@`  # "${26}" #Averaging and readout distortion correction methods: "NONE" = average any repeats with no readout correction "FIELDMAP" = average any repeats and use field map for readout correction "TOPUP" = average and distortion correct at the same time with topup/applytopup only works for 2 images currently
TopupConfig=`opts_GetOpt1 "--topupconfig" $@`  # "${27}" #Config for topup or "NONE" if not used
BiasFieldSmoothingSigma=`opts_GetOpt1 "--bfsigma" $@`  # "$9"
RUN=`opts_GetOpt1 "--printcom" $@`  # use ="echo" for just printing everything and not running the commands (default is to run)
BrainExtract=`opts_GetOpt1 "--brainextract" $@`   # EXVIVO, ANTS or FNIRT - TH Feb 2023
Defacing=`opts_GetOpt1 "--defacing" $@`   # TRUE or NONE by TH Jan 2020
T2wType=`opts_GetOpt1 "--t2wtype" $@`   # T2w or FLAIR TH Feb 2023
SPECIES=`opts_GetOpt1 "--species" $@` # Human, Chimp, Macaque, Marmoset, NightMonkey - TH 2016-2023
RunMode=`opts_GetOpt1 "--runmode" $@` 
TruePatientOrientation=`opts_GetOpt1 "--truepatientorientation" $@`  # HFS, SPHINX - TH 2023
ScannerPatientOrientation=`opts_GetOpt1 "--scannerpatientorientation" $@` # HFS, HFP, FFS or FFP

log_Msg "StudyFolder: $StudyFolder"
log_Msg "Subject:  $Subject"

# Paths for scripts etc (uses variables defined in SetUpHCPPipeline.sh)
PipelineScripts=${HCPPIPEDIR_PreFS}
GlobalScripts=${HCPPIPEDIR_Global}

# Naming Conventions
T1wImage="T1w"
T1wFolder="T1w" #Location of T1w images
T2wImage="T2w" 
T2wFolder="T2w" #Location of T2w images
AtlasSpaceFolder="MNINonLinear"

# Build Paths
T1wFolder=${StudyFolder}/${Subject}/${T1wFolder} 
T2wFolder=${StudyFolder}/${Subject}/${T2wFolder} 
AtlasSpaceFolder=${StudyFolder}/${Subject}/${AtlasSpaceFolder}

# Unpack List of Images
T1wInputImages=`echo ${T1wInputImages} | sed 's/@/ /g' | sed -e  's/^[ \t]*//'`  # Remove leading space - TH 
T2wInputImages=`echo ${T2wInputImages} | sed 's/@/ /g' | sed -e  's/^[ \t]*//'`

log_Msg "T1wInputImages: $T1wInputImages"
log_Msg "T2wInputImages: $T2wInputImages"

# -- Are T2w images available

if [ "${T2wInputImages}" = "NONE" ] ; then
  T2wFolder="NONE"
  T2wFolder_T2wImageWithPath_acpc="NONE"
  T2wFolder_T2wImageWithPath_acpc_brain="NONE"
  T1wFolder_T2wImageWithPath_acpc_dc="NONE"
else
  T2wFolder_T2wImageWithPath_acpc="${T2wFolder}/${T2wImage}_acpc"
  T2wFolder_T2wImageWithPath_acpc_brain="${T2wFolder}/${T2wImage}_acpc_brain"
  T1wFolder_T2wImageWithPath_acpc_dc=${T1wFolder}/${T2wImage}_acpc_dc
fi

log_Msg "T1wFolder: $T1wFolder"
log_Msg "T2wFolder: $T2wFolder"
log_Msg "AtlasFolder: $AtlasSpaceFolder"

if [ ! -e ${T1wFolder}/xfms ] ; then
  log_Msg "mkdir -p ${T1wFolder}/xfms/"
  mkdir -p ${T1wFolder}/xfms/
fi

if [ ! -e ${T2wFolder}/xfms ] && [ ${T2wFolder} != "NONE" ] ; then
  log_Msg "mkdir -p ${T2wFolder}/xfms/"
  mkdir -p ${T2wFolder}/xfms/
fi

if [ ! -e ${AtlasSpaceFolder}/xfms ] ; then
  log_Msg "mkdir -p ${AtlasSpaceFolder}/xfms/"
  mkdir -p ${AtlasSpaceFolder}/xfms/
fi

log_Msg "POSIXLY_CORRECT="${POSIXLY_CORRECT}

# default parameters
SPECIES=`opts_DefaultOpt $SPECIES Human`
RunMode=`opts_DefaultOpt $RunMode 1`
log_Msg "SPECIES: $SPECIES" 
log_Msg "RunMode: $RunMode"

# ------------------------------------------------------------------------------
# Species-specific values
# ------------------------------------------------------------------------------
if [[ "$SPECIES" = "Human" ]] ; then 
	BrainSize=${BrainSize:-150}  # Distance between top of FOV and bottom of brain in T1w or T2w 
	betcenter="45,55,39" # comma separated voxel coordinates in T1wTemplate2mm
	betradius="75"
	betfraction="0.3"
	bettop2center="86"           # Distance between top of FOV and center of brain
elif [[ $SPECIES =~ Chimp ]] ; then
	BrainSize=${BrainSize:-130}  # BrainSizeOpt in robustfov
	betcenter=""
	betradius=""
	betfraction=""
	bettop2center="60"
elif [[ $SPECIES =~ MacaqueRhes ]] ; then 
	BrainSize=${BrainSize:-60}  # Distance between top of FOV and bottom of brain in T1w or T2w
	betcenter="48,56,51"        # comma separated voxel coordinates in T1wTemplate2mm
	betradius="35"
	betfraction="0.2"
	bettop2center="30"          # distance in mm from the top of FOV to the center of brain in robustroi
elif [[ $SPECIES =~ MacaqueCyno ]] ; then 
	BrainSize=${BrainSize:-60}  # Distance between top of FOV and bottom of brain in T1w or T2w
	betcenter="48,56,47"        # comma separated voxel coordinates in T1wTemplate2mm
	betradius="30"
	betfraction="0.3"
	bettop2center="34"
elif [[ $SPECIES =~ MacaqueFusc ]] ; then
	BrainSize=${BrainSize:-60}  # Distance between top of FOV and bottom of brain in T1w or T2w
	betcenter="48,56,51"        # comma separated voxel coordinates in T1wTemplate2mm
	betradius="40"
	betfraction=0.3
	bettop2center="30"	
elif [[ $SPECIES =~ NightMonkey ]] ; then
	BrainSize=${BrainSize:-80}  # Distance between top of FOV and bottom of brain in T1w or T2w
	betcenter=""                # comma separated voxel coordinates in T1wTemplate2mm
	betradius="30"
	betfraction="0.4"
	bettop2center="16"
elif [[ $SPECIES =~ Marmoset ]] ; then
	#BrainSize=${BrainSize:-45}  # Distance between top of FOV and bottom of brain in T1w or T2w
	BrainSizeT1w=45 #22  # Distance between top of FOV and bottom of brain in T1w or T2w
	BrainSizeT2w=45
	betcenter="50,40,30"        # comma separated voxel coordinates in T1wTemplate2mm
	betradius="12"
	betfraction="0.4"
	bettop2center="12"       # distance in mm from the top of FOV to the center of brain in robustroi
	bettop2centerT1w=12      # distance in mm from the top of FOV to the center of brain in robustroi. 12 for RIKEN and MIT
	bettop2centerT2w=12      # distance in mm from the top of FOV to the center of brain in robustroi  12 for RIKEN and MIT
fi

########################################## DO WORK ########################################## 

######## LOOP over the same processing for T1w and T2w (just with different names) ########

Modalities="T1w T2w"

SetTemplateGradientNonlinearityAverage () {
for TXw in ${Modalities} ; do
    # set up appropriate input variables
    if [ $TXw = T1w ] ; then
	TXwInputImages="${T1wInputImages}"
	TXwFolder=${T1wFolder}
	TXwImage=${T1wImage}
	# Create hires reference volumes if the resolution of raw image is higher than T1xTemplate - TH Mar 2023 
	StrucRes=$(fslval $(echo ${T1wInputImages} | cut -d ' ' -f1) pixdim1 | awk '{printf "%0.2f", $1}')
	RefRes=$(fslval ${T1wTemplate} pixdim1 | awk '{printf "%0.2f", $1}')
	log_Msg "Resolution of structure: $StrucRes"
	log_Msg "Resolution of T1wTemplate: $RefRes" 
	if [ ! "$StrucRes" == "$RefRes" ] ; then
	  	log_Msg "Calculating and saving T1w reference volume in ${AtlasSpaceFolder}"
		flirt -in ${T1wTemplate} -ref ${T1wTemplate2mm} -applyisoxfm $StrucRes -o ${AtlasSpaceFolder}/T1wTemplate -interp sinc
		flirt -in ${TemplateMask} -ref ${T1wTemplate2mm} -applyisoxfm $StrucRes -o ${AtlasSpaceFolder}/TemplateMask -interp nearestneighbour
		fslmaths ${AtlasSpaceFolder}/T1wTemplate -mas ${AtlasSpaceFolder}/TemplateMask ${AtlasSpaceFolder}/T1wTemplateBrain
	else
	  	log_Msg "Copying T1w reference volume in ${AtlasSpaceFolder}"
		imcp ${T1wTemplate} ${AtlasSpaceFolder}/T1wTemplate
		imcp ${T1wTemplateBrain} ${AtlasSpaceFolder}/T1wTemplateBrain
		imcp ${TemplateMask} ${AtlasSpaceFolder}/TemplateMask
	fi
	TXwTemplate=${AtlasSpaceFolder}/T1wTemplate	
	TXwTemplateBrain=${AtlasSpaceFolder}/T1wTemplateBrain
	TXwTemplate2mm=${T1wTemplate2mm}
	TXwTemplate2mmBrain=${T1wTemplate2mmBrain}
	Contrast=T1w
    else
	TXwInputImages="${T2wInputImages}"
	TXwFolder=${T2wFolder}
	TXwImage=${T2wImage}
	# Create hires reference volumes if the resolution of raw image is higher than T1xTemplate - TH Mar 2023 
	if [ ! "$StrucRes" == "$RefRes" ] ; then
	  	log_Msg "Calculating and saving T2w reference volume in ${AtlasSpaceFolder}"
		flirt -in ${T2wTemplate} -ref ${T2wTemplate2mm} -applyisoxfm $StrucRes -o ${AtlasSpaceFolder}/T2wTemplate -interp sinc
		fslmaths ${AtlasSpaceFolder}/T2wTemplate -mas ${AtlasSpaceFolder}/TemplateMask ${AtlasSpaceFolder}/T2wTemplateBrain
	else
	  	log_Msg "Copying T2w reference volume in ${AtlasSpaceFolder}"
		imcp ${T2wTemplate} ${AtlasSpaceFolder}/T2wTemplate
		imcp ${T2wTemplateBrain} ${AtlasSpaceFolder}/T2wTemplateBrain
	fi
	TXwTemplate=${AtlasSpaceFolder}/T2wTemplate	
	TXwTemplateBrain=${AtlasSpaceFolder}/T2wTemplateBrain
	TXwTemplate2mm=${T2wTemplate2mm}
	TXwTemplate2mmBrain=${T2wTemplate2mmBrain}
	Contrast=$T2wType
    fi
    OutputTXwImageSTRING=""
    OutputTXwBrainImageSTRING=""

      # skip modality if no image

    if [ "${TXwInputImages}" = "NONE" ] ; then
       log_Msg "Skipping Modality: $TXw - image not specified."
       continue
    else
        log_Msg "Processing Modality: $TXw"
    fi

#### Gradient nonlinearity correction  (for T1w and T2w) ####

    if [ ! $GradientDistortionCoeffs = "NONE" ] ; then
	
	i=1
	for Image in $TXwInputImages ; do
	    wdir=${TXwFolder}/${TXwImage}${i}_GradientDistortionUnwarp
		log_Msg "mkdir -p $wdir"
	    mkdir -p $wdir
    	    log_Msg "reorient data to std" 
	    ${RUN} ${FSLDIR}/bin/fslreorient2std ${Image} ${wdir}/${TXwImage}${i} #Make sure input axes are oriented the same as the templates
	    ${RUN} ${GlobalScripts}/GradientDistortionUnwarp.sh \
		--workingdir=${wdir} \
		--coeffs=$GradientDistortionCoeffs \
		--in=${wdir}/${TXwImage}${i} \
		--out=${TXwFolder}/${TXwImage}${i}_gdc \
		--owarp=${TXwFolder}/xfms/${TXwImage}${i}_gdc_warp
	    OutputTXwImageSTRING="${OutputTXwImageSTRING}${TXwFolder}/${TXwImage}${i}_gdc "
	    if [ "$TruePatientOrientation" = "HFSx" ] ; then
	        log_Msg "Reorient sphinx-positioned data with a scanner orientation of $SPHINX"
		 ${GlobalScripts}/sphinx2reorient --in=${TXwFolder}/${TXwImage}${i}_gdc --out=${TXwFolder}/${TXwImage}${i}_gdc --position="$ScannerPatientOrientation"
		 convertwarp --warp1=${TXwFolder}/xfms/${TXwImage}${i}_gdc_warp --ref=${TXwFolder}/${TXwImage}${i}_gdc --postmat=${TXwFolder}/${TXwImage}${i}_gdc_reorient.mat --out=${TXwFolder}/xfms/${TXwImage}${i}_gdc_warp
	    fi

	    if [ $(${FSLDIR}/bin/imtest $(remove_ext $Image)_brain) = 1 ] ; then # # TH 2016 for ACPC initialization
              if [[ $(imtest ${TXwFolder}/${TXwImage}${i}_gdc_brain) = 1 ]] ; then
                imrm ${TXwFolder}/${TXwImage}${i}_gdc_brain
              fi
	      ${RUN} ${FSLDIR}/bin/fslreorient2std $(remove_ext $Image)_brain ${wdir}/${TXwImage}${i}_brain
	      log_Msg "Found $(remove_ext $Image)_brain"
	      applywarp -i ${wdir}/${TXwImage}${i}_brain -r ${TXwFolder}/${TXwImage}${i}_gdc -w ${TXwFolder}/xfms/${TXwImage}${i}_gdc_warp --interp=sinc
	    fi
	    i=$(($i+1))
	done
    else
	log_Msg "NOT PERFORMING GRADIENT DISTORTION CORRECTION"
	i=1
	for Image in $TXwInputImages ; do
	    Image="`${FSLDIR}/bin/remove_ext $Image`"
            if [[ $(imtest ${TXwFolder}/${TXwImage}${i}_gdc) = 1 ]] ; then
               imrm ${TXwFolder}/${TXwImage}${i}_gdc
            fi
           log_Msg "reorient data to std" 
	    if [ $TruePatientOrientation ] ; then
	        log_Msg "Reorient sphinx-positioned data with a scanner orientation of $SPHINX"
		 ${GlobalScripts}/sphinx2reorient --in=${TXwFolder}/${TXwImage}${i}_gdc --out=${TXwFolder}/${TXwImage}${i}_gdc --position="$ScannerPatientOrientation"
           else
              ${RUN} ${FSLDIR}/bin/fslreorient2std $Image ${TXwFolder}/${TXwImage}${i}_gdc
	   fi 
     	    OutputTXwImageSTRING="${OutputTXwImageSTRING}${TXwFolder}/${TXwImage}${i}_gdc "

	    if [ $(${FSLDIR}/bin/imtest $(remove_ext $Image)_brain) = 1 ] ; then # TH 2016 for ACPC initialization
	      log_Msg "Found $(remove_ext $Image)_brain"
             if [[ $(imtest ${TXwFolder}/${TXwImage}${i}_gdc_brain) = 1 ]] ; then
                imrm ${TXwFolder}/${TXwImage}${i}_gdc_brain
             fi
             if [ "$TruePatientOrientation" = "HFSx" ] ; then 
               ${RUN} ${GlobalScripts}/sphinx2orient --in-vol=${Image}_brain --out-root=${TXwFolder}/${TXwImage}${i}_gdc_brain --position="$ScannerPatientOrientation"
             else
 	        ${RUN} ${FSLDIR}/bin/fslreorient2std ${Image}_brain ${TXwFolder}/${TXwImage}${i}_gdc_brain
             fi
	      OutputTXwBrainImageSTRING="${OutputTXwBrainImageSTRING}${TXwFolder}/${TXwImage}${i}_gdc_brain "
	    fi
	    i=$(($i+1))
	done
    fi

#### Average Like Scans ####

    if [ `echo $TXwInputImages | wc -w` -gt 1 ] ; then
	log_Msg "Averaging ${TXw} Images"
        log_Msg "mkdir -p ${TXwFolder}/Average${TXw}Images"
        mkdir -p ${TXwFolder}/Average${TXw}Images
        log_Msg "PERFORMING SIMPLE AVERAGING FOR ${TXw}"
        ${RUN} ${HCPPIPEDIR_PreFS}/AnatomicalAverage.sh -o ${TXwFolder}/${TXwImage} -s ${TXwTemplate} -m ${AtlasSpaceFolder}/TemplateMask -n -w ${TXwFolder}/Average${TXw}Images --noclean -v -b $BrainSize $OutputTXwImageSTRING
        if [ `echo $OutputTXwBrainImageSTRING | wc -w` -ge 1 ] ; then   # TH 2016 for ACPC initialization
          log_Msg "PERFORMING SIMPLE AVERAGING FOR ${TXw} BRAIN" 
          if [ `echo $OutputTXwBrainImageSTRING | wc -w` = 1 ] ; then
            for img in $OutputTXwBrainImageSTRING ; do
               flirt -in $img -ref ${TXwFolder}/${TXwImage} -applyxfm -init ${TXwFolder}/Average${TXw}Images/ToHalfTrans0001.mat -o ${TXwFolder}/${TXwImage}_brain -interp nearestneighbour
            done
          elif [ `echo $OutputTXwBrainImageSTRING | wc -w` =  `echo $OutputTXwImageSTRING | wc -w` ] ; then
            i=1; 
            for img in $OutputTXwBrainImageSTRING ; do
               num=$(echo $OutputTXwBrainImageSTRING | wc -w)
               num=$(zeropad $num 4)
               flirt -in $img -ref ${TXwFolder}/${TXwImage} -applyxfm -init ${TXwFolder}/Average${TXw}Images/ToHalfTrans${num}.mat -o ${TXwFolder}/Average${TXw}Images/${TXwImage}${i}_gdc_brain -interp nearestneighbour
               OutputTXwBrainImageSTRINGTMP="$OutputTXwBrainImageSTRINGTMP ${TXwFolder}/Average${TXw}Images/${TXwImage}${i}_gdc_brain"
               i=$((i + 1))
            done
            fslmerge -t  ${TXwFolder}/${TXwImage}_brain $OutputTXwBrainImageSTRINGTMP
            fslmaths ${TXwFolder}/${TXwImage}_brain -Tmean ${TXwFolder}/${TXwImage}_brain
          else
          	log_Msg "ERROR: the brain only image should be prepared either for the initial input or for all the inputs"
          	exit 1;
          fi
        fi
    else
	log_Msg "ONLY ONE AVERAGE FOUND: COPYING"
	${RUN} ${FSLDIR}/bin/imcp ${TXwFolder}/${TXwImage}1_gdc ${TXwFolder}/${TXwImage}
	if [ `${FSLDIR}/bin/imtest ${TXwFolder}/${TXwImage}1_gdc_brain` = 1 ] ; then     # TH 2016
		${RUN} ${FSLDIR}/bin/imcp ${TXwFolder}/${TXwImage}1_gdc_brain ${TXwFolder}/${TXwImage}_brain
	fi
    fi

    # Defacing T1w and T2w if BrainSize=150 (assuminng that it is human brain) - TH July 1 2019
    if [[ $Defacing = TRUE ]] ; then
      if [ "$BrainSize" -eq "150" ] ; then
	log_Msg "BrainSize=150. Defacing ${TXwImage}"
    	${GlobalScripts}/fsl_deface ${TXwFolder}/${TXwImage}.nii.gz ${TXwFolder}/${TXwImage}.nii.gz
      fi
    fi

done

}

ACPCAlignment () {

for TXw in ${Modalities} ; do
    # set up appropriate input variables
    if [ $TXw = T1w ] ; then
	TXwInputImages="${T1wInputImages}"
	TXwFolder=${T1wFolder}
	TXwImage=${T1wImage}
	TXwTemplate=${AtlasSpaceFolder}/T1wTemplate	
	TXwTemplateBrain=${AtlasSpaceFolder}/T1wTemplateBrain
	TXwTemplate2mm=${T1wTemplate2mm}
	TXwTemplate2mmBrain=${T1wTemplate2mmBrain}
	Contrast=T1w
	if [ ! -z ${BrainSizeT1w} ] ; then
		BrainSize=${BrainSizeT1w}
	fi
	if [ ! -z ${bettop2centerT1w} ] ; then
		bettop2center=${bettop2centerT1w}
	fi
    else
	TXwInputImages="${T2wInputImages}"
	TXwFolder=${T2wFolder}
	TXwImage=${T2wImage}
	TXwTemplate=${AtlasSpaceFolder}/T2wTemplate	
	TXwTemplateBrain=${AtlasSpaceFolder}/T2wTemplateBrain
	TXwTemplate2mm=${T2wTemplate2mm}
	TXwTemplate2mmBrain=${T2wTemplate2mmBrain}
	Contrast=$T2wType
	if [ ! -z ${BrainSizeT2w} ] ; then
		BrainSize=${BrainSizeT2w}
	fi
	if [ ! -z ${bettop2centerT2w} ] ; then
		bettop2center=${bettop2centerT2w} 
	fi
    fi

#### ACPC align T1w and T2w image to 0.7mm MNI T1wTemplate to create native volume space ####

    if [ $BrainExtract = EXVIVO ] ; then	
      BrainExtraction=EXVIVO  
    else
      BrainExtraction=FSL  
    fi
    mkdir -p ${TXwFolder}/ACPCAlignment  # TH modified Oct 2016 - Feb 2023
    ${RUN} ${PipelineScripts}/ACPCAlignment.sh \
	--workingdir=${TXwFolder}/ACPCAlignment \
	--in=${TXwFolder}/${TXwImage} \
	--ref=${TXwTemplate} \
	--refbrain=${TXwTemplateBrain} \
	--out=${TXwFolder}/${TXwImage}_acpc \
	--omat=${TXwFolder}/xfms/acpc.mat \
	--brainsize=${BrainSize} \
	--brainextract=${BrainExtraction} \
	--betfraction=${betfraction} \
	--bettop2center=${bettop2center} \
       --betradius=${betradius} \
    	--contrast=$Contrast \
	--ref2mm=${TXwTemplate2mm} \
	--ref2mmmask=${Template2mmMask} \
	--species=$SPECIES

done

}


BrainExtracion () {

for TXw in ${Modalities} ; do
    # set up appropriate input variables
    if [ $TXw = T1w ] ; then
	TXwInputImages="${T1wInputImages}"
	TXwFolder=${T1wFolder}
	TXwImage=${T1wImage}
	TXwTemplate=${AtlasSpaceFolder}/T1wTemplate	
	TXwTemplateBrain=${AtlasSpaceFolder}/T1wTemplateBrain
	TXwTemplate2mm=${T1wTemplate2mm}
	TXwTemplate2mmBrain=${T1wTemplate2mmBrain}
	Contrast=T1w
    else
	TXwInputImages="${T2wInputImages}"
	TXwFolder=${T2wFolder}
	TXwImage=${T2wImage}
	TXwTemplate=${AtlasSpaceFolder}/T2wTemplate	
	TXwTemplateBrain=${AtlasSpaceFolder}/T2wTemplateBrain
	TXwTemplate2mm=${T2wTemplate2mm}
	TXwTemplate2mmBrain=${T2wTemplate2mmBrain}
	Contrast=$T2wType
    fi

#### Brain Extraction (FNIRT-based Masking) ####
  # TH modified June 2016 - Feb 2023
  if [ "$BrainExtract" = ANTS ] ; then
    log_Msg "Brain extract with ANTs" 
    if [ -e ${TXwFolder}/BrainExtraction_ANTSbased ] ; then 
       rm -rf ${TXwFolder}/BrainExtraction_ANTSbased
    fi
    ${RUN} ${PipelineScripts}/BrainExtraction_ANTSbased.sh \
	--workingdir=${TXwFolder}/BrainExtraction_ANTSbased \
	--in=${TXwFolder}/${TXwImage}_acpc \
	--ref=${TXwTemplate2mm} \
	--refmask=${AtlasSpaceFolder}/TemplateMask \
	--outbrain=${TXwFolder}/${TXwImage}_acpc_brain \
	--outbrainmask=${TXwFolder}/${TXwImage}_acpc_brain_mask \
	--contrast=$Contrast
  else
    log_Msg "Brain extract with FNIRT" 
    mkdir -p ${TXwFolder}/BrainExtraction_FNIRTbased
    ${RUN} ${PipelineScripts}/BrainExtraction_FNIRTbased.sh \
	--workingdir=${TXwFolder}/BrainExtraction_FNIRTbased \
	--in=${TXwFolder}/${TXwImage}_acpc \
	--ref=${TXwTemplate} \
	--refmask=${AtlasSpaceFolder}/TemplateMask \
	--ref2mm=${TXwTemplate2mm} \
	--ref2mmmask=${Template2mmMask} \
	--outbrain=${TXwFolder}/${TXwImage}_acpc_brain \
	--outbrainmask=${TXwFolder}/${TXwImage}_acpc_brain_mask \
	--fnirtconfig=${FNIRTConfig} \
       --betcenter=${betcenter} \
       --betradius=${betradius} \
	--betfraction=${betfraction} \
	--initdof=$InitDof \
	--brainextract=${BrainExtract} 
  fi 
done 

######## END LOOP over T1w and T2w #########

}

T2wToT1wRegAndBiasCorrection () {

#### T2w to T1w Registration and Optional Readout Distortion Correction ####

if [[ ${AvgrdcSTRING} = "FIELDMAP" || ${AvgrdcSTRING} = "TOPUP" ]] ; then
  log_Msg "PERFORMING ${AvgrdcSTRING} READOUT DISTORTION CORRECTION"
  if [ ! $T2wFolder = NONE ] ; then
   wdir=${T2wFolder}/T2wToT1wDistortionCorrectAndReg
   if [ -d ${wdir} ] ; then
      # DO NOT change the following line to "rm -r ${wdir}" because the chances of something going wrong with that are much higher, and rm -r always needs to be treated with the utmost caution
    rm -r ${T2wFolder}/T2wToT1wDistortionCorrectAndReg
   fi
  else
   wdir=${T1wFolder}/T2wToT1wDistortionCorrectAndReg
  fi
  mkdir -p ${wdir}
  ${RUN} ${PipelineScripts}/T2wToT1wDistortionCorrectAndReg.sh \
      --workingdir=${wdir} \
      --t1=${T1wFolder}/${T1wImage}_acpc \
      --t1brain=${T1wFolder}/${T1wImage}_acpc_brain \
      --t2=${T2wFolder_T2wImageWithPath_acpc} \
      --t2brain=${T2wFolder_T2wImageWithPath_acpc_brain} \
      --fmapmag=${MagnitudeInputName} \
      --fmapphase=${PhaseInputName} \
      --echodiff=${TE} \
      --SEPhaseNeg=${SpinEchoPhaseEncodeNegative} \
      --SEPhasePos=${SpinEchoPhaseEncodePositive} \
      --echospacing=${DwellTime} \
      --seunwarpdir=${SEUnwarpDir} \
      --t1sampspacing=${T1wSampleSpacing} \
      --t2sampspacing=${T2wSampleSpacing} \
      --unwarpdir=${UnwarpDir} \
      --ot1=${T1wFolder}/${T1wImage}_acpc_dc \
      --ot1brain=${T1wFolder}/${T1wImage}_acpc_dc_brain \
      --ot1warp=${T1wFolder}/xfms/${T1wImage}_dc \
      --ot2=${T1wFolder}/${T2wImage}_acpc_dc \
      --ot2warp=${T1wFolder}/xfms/${T2wImage}_reg_dc \
      --method=${AvgrdcSTRING} \
      --topupconfig=${TopupConfig} \
      --gdcoeffs=${GradientDistortionCoeffs} \
      --usejacobian="true"

else

  if [ ! $T2wFolder = NONE ] ; then
    wdir=${T2wFolder}/T2wToT1wReg
    if [ -e ${wdir} ] ; then
      # DO NOT change the following line to "rm -r ${wdir}" because the chances of something going wrong with that are much higher, and rm -r always needs to be treated with the utmost caution
      rm -r ${T2wFolder}/T2wToT1wReg
    fi
  else
    wdir=${T1wFolder}/T2wToT1wReg
  fi

  mkdir -p ${wdir}
  ${RUN} ${PipelineScripts}/T2wToT1wReg.sh \
      ${wdir} \
      ${T1wFolder}/${T1wImage}_acpc \
      ${T1wFolder}/${T1wImage}_acpc_brain \
      ${T2wFolder_T2wImageWithPath_acpc} \
      ${T2wFolder_T2wImageWithPath_acpc_brain} \
      ${T1wFolder}/${T1wImage}_acpc_dc \
      ${T1wFolder}/${T1wImage}_acpc_dc_brain \
      ${T1wFolder}/xfms/${T1wImage}_dc \
      ${T1wFolder}/${T2wImage}_acpc_dc \
      ${T1wFolder}/xfms/${T2wImage}_reg_dc \
      ${IdentMat}
fi  


#### Bias Field Correction: Calculate bias field using square root of the product of T1w and T2w iamges.  ####
if [ ! -z ${BiasFieldSmoothingSigma} ] ; then
  BiasFieldSmoothingSigma="--bfsigma=${BiasFieldSmoothingSigma}"
fi

if [ ! "${T2wInputImages}" = "NONE" ] ; then

   mkdir -p ${T1wFolder}/BiasFieldCorrection_sqrtT1wXT2w 
   ${RUN} ${PipelineScripts}/BiasFieldCorrection_sqrtT1wXT2w.sh \
    --workingdir=${T1wFolder}/BiasFieldCorrection_sqrtT1wXT2w \
    --T1im=${T1wFolder}/${T1wImage}_acpc_dc \
    --T1brain=${T1wFolder}/${T1wImage}_acpc_dc_brain \
    --T2im=${T1wFolder_T2wImageWithPath_acpc_dc} \
    --obias=${T1wFolder}/BiasField_acpc_dc \
    --oT1im=${T1wFolder}/${T1wImage}_acpc_dc_restore \
    --oT1brain=${T1wFolder}/${T1wImage}_acpc_dc_restore_brain \
    --oT2im=${T1wFolder}/${T2wImage}_acpc_dc_restore \
    --oT2brain=${T1wFolder}/${T2wImage}_acpc_dc_restore_brain \
    ${BiasFieldSmoothingSigma}

else  # -- No T2w image

    log_Msg "Performing Bias Field Correction using T1w image only"
    BiasFieldFastSmoothingSigma="20"
    BiasFieldFastSmoothingSigma="--bfsigma=${BiasFieldFastSmoothingSigma}"

    ${RUN} ${HCPPIPEDIR_PreFS}/BiasFieldCorrection_T1wOnly_RIKEN.sh \
      --workingdir=${T1wFolder}/BiasFieldCorrection_T1wOnly \
      --T1im=${T1wFolder}/${T1wImage}_acpc_dc \
      --T1brain=${T1wFolder}/${T1wImage}_acpc_dc_brain \
      --obias=${T1wFolder}/BiasField_acpc_dc \
      --oT1im=${T1wFolder}/${T1wImage}_acpc_dc_restore \
      --oT1brain=${T1wFolder}/${T1wImage}_acpc_dc_restore_brain \
      ${BiasFieldFastSmoothingSigma}

fi

}

AtlasRegistration () {
#### Atlas Registration to MNI152: FLIRT + FNIRT  #Also applies registration to T1w and T2w images ####
#Consider combining all transforms and recreating files with single resampling steps
 
${RUN} ${PipelineScripts}/AtlasRegistrationToMNI152_FLIRTandFNIRT.sh \
    --workingdir=${AtlasSpaceFolder} \
    --t1=${T1wFolder}/${T1wImage}_acpc_dc \
    --t1rest=${T1wFolder}/${T1wImage}_acpc_dc_restore \
    --t1restbrain=${T1wFolder}/${T1wImage}_acpc_dc_restore_brain \
    --t2=${T1wFolder_T2wImageWithPath_acpc_dc}  \
    --t2rest=${T1wFolder}/${T2wImage}_acpc_dc_restore \
    --t2restbrain=${T1wFolder}/${T2wImage}_acpc_dc_restore_brain \
    --ref=${AtlasSpaceFolder}/T1wTemplate \
    --refbrain=${AtlasSpaceFolder}/T1wTemplateBrain \
    --refmask=${AtlasSpaceFolder}/TemplateMask \
    --ref2mm=${T1wTemplate2mm} \
    --ref2mmmask=${Template2mmMask} \
    --owarp=${AtlasSpaceFolder}/xfms/acpc_dc2standard.nii.gz \
    --oinvwarp=${AtlasSpaceFolder}/xfms/standard2acpc_dc.nii.gz \
    --ot1=${AtlasSpaceFolder}/${T1wImage} \
    --ot1rest=${AtlasSpaceFolder}/${T1wImage}_restore \
    --ot1restbrain=${AtlasSpaceFolder}/${T1wImage}_restore_brain \
    --ot2=${AtlasSpaceFolder}/${T2wImage} \
    --ot2rest=${AtlasSpaceFolder}/${T2wImage}_restore \
    --ot2restbrain=${AtlasSpaceFolder}/${T2wImage}_restore_brain \
    --fnirtconfig=${FNIRTConfig} \
    --brainextract=${BrainExtract}

}

main () {
if   [ "$RunMode" = "1" ] ; then
	SetTemplateGradientNonlinearityAverage; ACPCAlignment; BrainExtracion; T2wToT1wRegAndBiasCorrection; AtlasRegistration
elif [ "$RunMode" = "2" ] ; then
	                                        ACPCAlignment; BrainExtracion; T2wToT1wRegAndBiasCorrection; AtlasRegistration
elif [ "$RunMode" = "3" ] ; then
	                                                       BrainExtracion; T2wToT1wRegAndBiasCorrection; AtlasRegistration
elif [ "$RunMode" = "4" ] ; then
	                                                                       T2wToT1wRegAndBiasCorrection; AtlasRegistration
elif [ "$RunMode" = "5" ] ; then
	                                                                                                     AtlasRegistration
fi
}
main
#### Next stage: FreeSurfer/FreeSurferPipeline.sh

