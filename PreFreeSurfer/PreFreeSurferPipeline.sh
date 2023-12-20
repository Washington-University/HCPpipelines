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

# -----------------------------------------------------------------------------------
#  Define Sources and pipe-dir
# -----------------------------------------------------------------------------------

set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
source "${HCPPIPEDIR}/global/scripts/processingmodecheck.shlib"
#description to use in usage - syntax of parameters is now explained automatically
opts_SetScriptDescription "Prepares raw data for running the FreeSurfer HCP pipeline"

# ------------------------------------------------------------------------------
#  Usage Description Function
# ------------------------------------------------------------------------------


opts_AddMandatory '--path' 'StudyFolder' 'path' "Path to study data folder (required)  Used with --subject input to create full path to root  directory for all outputs generated as path/subject)"

opts_AddMandatory '--subject' 'Subject' 'subject' "Subject ID (required)  Used with --path input to create full path to root  directory for all outputs generated as path/subject"

opts_AddMandatory '--t1' 'T1wInputImages' "T1" "An @ symbol separated list of full paths to T1-weighted  (T1w) structural images for the subject (required)"

opts_AddMandatory '--t2' 'T2wInputImages' "T2" "An @ symbol separated list of full paths to T2-weighted  (T2w) structural images for the subject (required for   hcp-style data, can be NONE for legacy-style data,   see --processing-mode option)"

opts_AddMandatory '--t1template' 'T1wTemplate' 'file_path' "MNI T1w template"

opts_AddMandatory '--t1templatebrain' 'T1wTemplateBrain' 'file_path' "Brain extracted MNI T1wTemplate"

opts_AddMandatory '--t1template2mm' 'T1wTemplate2mm' 'file_path' "MNI 2mm T1wTemplate"

opts_AddMandatory '--t2template' 'T2wTemplate' 'file_path' "MNI T2w template"

opts_AddMandatory '--t2templatebrain' 'T2wTemplateBrain' 'file_path' "Brain extracted MNI T2wTemplate"

opts_AddMandatory '--t2template2mm' 'T2wTemplate2mm' 'file_path' "MNI 2mm T2wTemplate"

opts_AddMandatory '--templatemask' 'TemplateMask' 'file_path' "Brain mask MNI Template"

opts_AddMandatory '--template2mmmask' 'Template2mmMask' 'file_path' "Brain mask MNI 2mm Template"

opts_AddMandatory '--brainsize' 'BrainSize' 'size_value' "Brain size estimate in mm, 150 for humans"

opts_AddMandatory '--fnirtconfig' 'FNIRTConfig' 'file_path' "FNIRT 2mm T1w Configuration file"

opts_AddOptional '--fmapmag' 'MagnitudeInputName' 'file_path' "Siemens/Philips Gradient Echo Fieldmap magnitude file"

opts_AddOptional '--fmapphase' 'PhaseInputName' 'file_path' "Siemens/Philips Gradient Echo Fieldmap phase file"

opts_AddOptional '--fmapgeneralelectric' 'GEB0InputName' 'file_path' "General Electric Gradient Echo Field Map file  Two volumes in one file  1. field map in deg  2. magnitude"

opts_AddOptional '--echodiff' 'TE' 'delta_TE' "Delta TE in ms for field map or 'NONE' if  not used"

opts_AddOptional '--SEPhaseNeg' 'SpinEchoPhaseEncodeNegative' '<file_path>_or__NONE' "For spin echo field map, path to volume with  a negative phase encoding direction (LR in  HCP data), set to 'NONE' if not using Spin  Echo Field Maps"

opts_AddOptional '--SEPhasePos' 'SpinEchoPhaseEncodePositive' '<file_path>_or__NONE' "For spin echo field map, path to volume with  a positive phase encoding direction (RL in  HCP data), set to 'NONE' if not using Spin  Echo Field Maps" 

opts_AddMandatory '--seechospacing' 'SEEchoSpacing' 'seconds' "Effective Echo Spacing of Spin Echo Field Map,  (in seconds) or 'NONE' if not used"

opts_AddMandatory '--seunwarpdir' 'SEUnwarpDir' '{x,y,NONE} OR {i,j,NONE}' "Phase encoding direction (according to the *voxel* axes)  of the spin echo field map.   (Only applies when using a spin echo field map.)"

opts_AddMandatory '--t1samplespacing' 'T1wSampleSpacing' 'seconds' "T1 image sample spacing, 'NONE' if not used"

opts_AddMandatory '--t2samplespacing' 'T2wSampleSpacing' 'seconds' "T2 image sample spacing, 'NONE' if not used"

opts_AddMandatory '--unwarpdir' 'UnwarpDir' '{x,y,z,x-,y-,z-} OR {i,j,k,i-,j-,k-}' "Readout direction of the T1w and T2w images (according to the *voxel axes)  (Used with either a gradient echo field map   or a spin echo field map)"

opts_AddMandatory '--gdcoeffs' 'GradientDistortionCoeffs' 'file_path' "File containing gradient distortion  coefficients, Set to 'NONE' to turn off"

opts_AddMandatory '--avgrdcmethod' 'AvgrdcSTRING' 'avgrdcmethod' "Averaging and readout distortion correction method.   See below for supported values. 
  '${NONE_METHOD_OPT}' 
      average any repeats with no readout distortion correction

  '${SPIN_ECHO_METHOD_OPT}' 
      average any repeats and use Spin Echo Field Maps for readout
      distortion correction

  '${PHILIPS_METHOD_OPT}' 
      average any repeats and use Philips specific Gradient Echo
      Field Maps for readout distortion correction

  '${GENERAL_ELECTRIC_METHOD_OPT}' 
      average any repeats and use General Electric specific Gradient
      Echo Field Maps for readout distortion correction

  '${SIEMENS_METHOD_OPT}' 
      average any repeats and use Siemens specific Gradient Echo
      Field Maps for readout distortion correction

  '${FIELDMAP_METHOD_OPT}' 
      equivalent to '${SIEMENS_METHOD_OPT}' (preferred)
      This option value is maintained for backward compatibility."

opts_AddOptional '--topupconfig' 'TopupConfig' 'file_path' "Configuration file for topup or 'NONE' if not used"

opts_AddOptional '--bfsigma' 'BiasFieldSmoothingSigma' 'value' "Bias Field Smoothing Sigma (optional)"

opts_AddOptional '--custombrain' 'CustomBrain' 'NONE_or_MASK_or_CUSTOM' "If PreFreeSurfer has been run before and you have created a custom  brain mask saved as '<subject>/T1w/custom_acpc_dc_restore_mask.nii.gz', specify 'MASK'.   If PreFreeSurfer has been run before and you have created custom structural images, e.g.:  
- '<subject>/T1w/T1w_acpc_dc_restore_brain.nii.gz' 
- '<subject>/T1w/T1w_acpc_dc_restore.nii.gz' 
- '<subject>/T1w/T2w_acpc_dc_restore_brain.nii.gz' 
- '<subject>/T1w/T2w_acpc_dc_restore.nii.gz' 
  to be used when peforming MNI152 Atlas registration, specify 'CUSTOM'.  When 'MASK' or 'CUSTOM' is specified, only the AtlasRegistration step is run.  If the parameter is omitted or set to NONE (the default),   standard image processing will take place.  If using 'MASK' or 'CUSTOM', the data still needs to be staged properly by   running FreeSurfer and PostFreeSurfer afterwards.  NOTE: This option allows manual correction of brain images in cases when they  were not successfully processed and/or masked by the regular use of the pipelines.  Before using this option, first ensure that the pipeline arguments used were   correct and that templates are a good match to the data. " "NONE"

opts_AddOptional '--processing-mode' 'ProcessingMode' 'HCPStyleData_or__Controls_whether_the_HCP_acquisition_and_processing_guidelines_should_be_treated_as_requirements.__LegacyStyleData' "'HCPStyleData' (the default) follows the processing steps described in Glasser et al. (2013)   and requires 'HCP-Style' data acquistion.   'LegacyStyleData' allows additional processing functionality and use of some acquisitions  that do not conform to 'HCP-Style' expectations.  In this script, it allows not having a high-resolution T2w image. " "HCPStyleData"

opts_AddOptional '--usejacobian' 'UseJacobian' 'TRUE or FALSE' "Whether to use jacobian modulation when correcting spin echo fieldmaps for gradient distortion" "True" # NOT IN THE ORIGNAL SCRIPT
# ------------------------------------------------------------------------------
#  Parse Arugments
# ------------------------------------------------------------------------------
opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

#processing code goes here
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

# NOTE: UseJacobian only affects whether the spin echo field maps 
# get intensity modulated by the gradient distortion correction warpfield 
# (T2wToT1wDistortionCorrectAndReg -> TopupPreprocessingAll)
# Convert UseJacobian value to all lowercase (to allow the user the flexibility to use True, true, TRUE, False, False, false, etc.)
UseJacobian="$(opts_StringToBool ${UseJacobian})"

# Use --printcom=echo for just printing everything and not actually
# running the commands (the default is to actually run the commands)
RUN="" # SHORT CIRCUT RUN SO IT DOESNT DO ANYTHING 
if [[ "$RUN" != "" ]]
then
    log_Err_Abort "--printcom is not consistently implemented, do not rely on it"
fi

# ------------------------------------------------------------------------------
#  Compliance check
# ------------------------------------------------------------------------------

Compliance="HCPStyleData"
ComplianceMsg=""

# -- T2w image

if [ "${T2wInputImages}" = "NONE" ]; then
  ComplianceMsg+=" --t2=NONE"
  Compliance="LegacyStyleData"
fi

check_mode_compliance "${ProcessingMode}" "${Compliance}" "${ComplianceMsg}"

# ------------------------------------------------------------------------------
#  Show Command Line Options
# ------------------------------------------------------------------------------

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

log_Msg "T1wFolder: $T1wFolder"
log_Msg "T2wFolder: $T2wFolder"
log_Msg "AtlasSpaceFolder: $AtlasSpaceFolder"

# Unpack List of Images
T1wInputImages=`echo ${T1wInputImages} | sed 's/@/ /g'`
T2wInputImages=`echo ${T2wInputImages} | sed 's/@/ /g'`


# -- Are T2w images available

if [ "${T2wInputImages}" = "NONE" ] ; then
  T2wFolder_T2wImageWithPath_acpc="NONE"
  T2wFolder_T2wImageWithPath_acpc_brain="NONE"
  T1wFolder_T2wImageWithPath_acpc_dc="NONE"
else
  T2wFolder_T2wImageWithPath_acpc="${T2wFolder}/${T2wImage}_acpc"
  T2wFolder_T2wImageWithPath_acpc_brain="${T2wFolder}/${T2wImage}_acpc_brain"
  T1wFolder_T2wImageWithPath_acpc_dc=${T1wFolder}/${T2wImage}_acpc_dc
fi

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

# log_Msg "POSIXLY_CORRECT="${POSIXLY_CORRECT} #NOT DEFINED ANYWHERE ELSE DO WE NEED THIS? 

# ------------------------------------------------------------------------------
#  Do primary work
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
#  Loop over the processing for T1w and T2w (just with different names).
#  For each modality, perform
#  - Gradient Nonlinearity Correction (Unless no gradient distortion
#    coefficients are available)
#  - Average same modality images (if more than one is available)
#  - Rigidly align images to specified MNI Template to create native volume space
#  - Perform Brain Extraction(FNIRT-based Masking)
# ------------------------------------------------------------------------------

# NOTE: We skip all the way to AtlasRegistration (last step) if using a custom 
# brain mask or custom structural images ($CustomBrain={MASK|CUSTOM})

if [ "$CustomBrain" = "NONE" ] ; then

  Modalities="T1w T2w"

  for TXw in ${Modalities} ; do

      # set up appropriate input variables
      if [ $TXw = T1w ] ; then
          TXwInputImages="${T1wInputImages}"
          TXwFolder=${T1wFolder}
          TXwImage=${T1wImage}
          TXwTemplate=${T1wTemplate}
          TXwTemplate2mm=${T1wTemplate2mm}
      else
          TXwInputImages="${T2wInputImages}"
          TXwFolder=${T2wFolder}
          TXwImage=${T2wImage}
          TXwTemplate=${T2wTemplate}
          TXwTemplate2mm=${T2wTemplate2mm}
      fi
      OutputTXwImageSTRING=""

      # skip modality if no image

      if [ "${TXwInputImages}" = "NONE" ] ; then
        log_Msg "Skipping Modality: $TXw - image not specified."
        continue
      else
        log_Msg "Processing Modality: $TXw"
      fi

      # Perform Gradient Nonlinearity Correction

      if [ ! $GradientDistortionCoeffs = "NONE" ] ; then
        log_Msg "Performing Gradient Nonlinearity Correction"

        i=1
        for Image in $TXwInputImages ; do
          wdir=${TXwFolder}/${TXwImage}${i}_GradientDistortionUnwarp
          log_Msg "mkdir -p $wdir"
          mkdir -p $wdir
          # Make sure input axes are oriented the same as the templates
          ${RUN} ${FSLDIR}/bin/fslreorient2std $Image ${wdir}/${TXwImage}${i}

          ${RUN} ${HCPPIPEDIR_Global}/GradientDistortionUnwarp.sh \
            --workingdir=${wdir} \
            --coeffs=$GradientDistortionCoeffs \
            --in=${wdir}/${TXwImage}${i} \
            --out=${TXwFolder}/${TXwImage}${i}_gdc \
            --owarp=${TXwFolder}/xfms/${TXwImage}${i}_gdc_warp
          OutputTXwImageSTRING="${OutputTXwImageSTRING}${TXwFolder}/${TXwImage}${i}_gdc "
          i=$(($i+1))
        done

      else
        log_Msg "NOT PERFORMING GRADIENT DISTORTION CORRECTION"

        i=1
        for Image in $TXwInputImages ; do
          ${RUN} ${FSLDIR}/bin/fslreorient2std $Image ${TXwFolder}/${TXwImage}${i}_gdc
          OutputTXwImageSTRING="${OutputTXwImageSTRING}${TXwFolder}/${TXwImage}${i}_gdc "
          i=$(($i+1))
        done

      fi

      # Average Like (Same Modality) Scans

      if [ `echo $TXwInputImages | wc -w` -gt 1 ] ; then
        log_Msg "Averaging ${TXw} Images"
        log_Msg "mkdir -p ${TXwFolder}/Average${TXw}Images"
        mkdir -p ${TXwFolder}/Average${TXw}Images
        log_Msg "PERFORMING SIMPLE AVERAGING"
        ${RUN} ${HCPPIPEDIR_PreFS}/AnatomicalAverage.sh -o ${TXwFolder}/${TXwImage} -s ${TXwTemplate} -m ${TemplateMask} -n -w ${TXwFolder}/Average${TXw}Images --noclean -v -b $BrainSize $OutputTXwImageSTRING
      else
        log_Msg "Not Averaging ${TXw} Images"
        log_Msg "ONLY ONE IMAGE FOUND: COPYING"
        ${RUN} ${FSLDIR}/bin/imcp ${TXwFolder}/${TXwImage}1_gdc ${TXwFolder}/${TXwImage}
      fi

      # ACPC align T1w or T2w image to specified MNI Template to create native volume space
      log_Msg "Aligning ${TXw} image to ${TXwTemplate} to create native volume space"
      log_Msg "mkdir -p ${TXwFolder}/ACPCAlignment"
      mkdir -p ${TXwFolder}/ACPCAlignment
      ${RUN} ${HCPPIPEDIR_PreFS}/ACPCAlignment.sh \
        --workingdir=${TXwFolder}/ACPCAlignment \
        --in=${TXwFolder}/${TXwImage} \
        --ref=${TXwTemplate} \
        --out=${TXwFolder}/${TXwImage}_acpc \
        --omat=${TXwFolder}/xfms/acpc.mat \
        --brainsize=${BrainSize}

      # Brain Extraction(FNIRT-based Masking)
      log_Msg "Performing Brain Extraction using FNIRT-based Masking"
      log_Msg "mkdir -p ${TXwFolder}/BrainExtraction_FNIRTbased"
      mkdir -p ${TXwFolder}/BrainExtraction_FNIRTbased
      ${RUN} ${HCPPIPEDIR_PreFS}/BrainExtraction_FNIRTbased.sh \
        --workingdir=${TXwFolder}/BrainExtraction_FNIRTbased \
        --in=${TXwFolder}/${TXwImage}_acpc \
        --ref=${TXwTemplate} \
        --refmask=${TemplateMask} \
        --ref2mm=${TXwTemplate2mm} \
        --ref2mmmask=${Template2mmMask} \
        --outbrain=${TXwFolder}/${TXwImage}_acpc_brain \
        --outbrainmask=${TXwFolder}/${TXwImage}_acpc_brain_mask \
        --fnirtconfig=${FNIRTConfig}

  done

  # End of looping over modalities (T1w and T2w)

  # ------------------------------------------------------------------------------
  #  T2w to T1w Registration and Optional Readout Distortion Correction
  # ------------------------------------------------------------------------------

  case $AvgrdcSTRING in

    ${FIELDMAP_METHOD_OPT} | ${SPIN_ECHO_METHOD_OPT} | ${GENERAL_ELECTRIC_METHOD_OPT} | ${SIEMENS_METHOD_OPT} | ${PHILIPS_METHOD_OPT})

      log_Msg "Performing ${AvgrdcSTRING} Readout Distortion Correction"
      wdir=${T2wFolder}/T2wToT1wDistortionCorrectAndReg
      if [ -d ${wdir} ] ; then
        # DO NOT change the following line to "rm -r ${wdir}" because the
        # chances of something going wrong with that are much higher, and
        # rm -r always needs to be treated with the utmost caution
        rm -r ${T2wFolder}/T2wToT1wDistortionCorrectAndReg
      fi

      log_Msg "mkdir -p ${wdir}"
      mkdir -p ${wdir}

      ${RUN} ${HCPPIPEDIR_PreFS}/T2wToT1wDistortionCorrectAndReg.sh \
        --workingdir=${wdir} \
        --t1=${T1wFolder}/${T1wImage}_acpc \
        --t1brain=${T1wFolder}/${T1wImage}_acpc_brain \
        --t2=${T2wFolder_T2wImageWithPath_acpc} \
        --t2brain=${T2wFolder_T2wImageWithPath_acpc_brain} \
        --fmapmag=${MagnitudeInputName} \
        --fmapphase=${PhaseInputName} \
        --fmapgeneralelectric=${GEB0InputName} \
        --echodiff=${TE} \
        --SEPhaseNeg=${SpinEchoPhaseEncodeNegative} \
        --SEPhasePos=${SpinEchoPhaseEncodePositive} \
        --seechospacing=${SEEchoSpacing} \
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
        --usejacobian=${UseJacobian} 

      ;;

    *)

      log_Msg "NOT PERFORMING READOUT DISTORTION CORRECTION"
      wdir=${T2wFolder}/T2wToT1wReg
      if [ -e ${wdir} ] ; then
        # DO NOT change the following line to "rm -r ${wdir}" because the
        # chances of something going wrong with that are much higher, and
        # rm -r always needs to be treated with the utmost caution
        rm -r ${T2wFolder}/T2wToT1wReg
      fi

      log_Msg "mkdir -p ${wdir}"
      mkdir -p ${wdir}

      ${RUN} ${HCPPIPEDIR_PreFS}/T2wToT1wReg.sh \
        ${wdir} \
        ${T1wFolder}/${T1wImage}_acpc \
        ${T1wFolder}/${T1wImage}_acpc_brain \
        ${T2wFolder_T2wImageWithPath_acpc} \
        ${T2wFolder_T2wImageWithPath_acpc_brain} \
        ${T1wFolder}/${T1wImage}_acpc_dc \
        ${T1wFolder}/${T1wImage}_acpc_dc_brain \
        ${T1wFolder}/xfms/${T1wImage}_dc \
        ${T1wFolder}/${T2wImage}_acpc_dc \
        ${T1wFolder}/xfms/${T2wImage}_reg_dc 

  esac

  # ------------------------------------------------------------------------------
  #  Bias Field Correction: Calculate bias field using square root of the product
  #  of T1w and T2w images (if both available).
  #  Otherwise (if only T1w available), calculate bias field using 'fsl_anat'
  # ------------------------------------------------------------------------------

  if [ ! -z ${BiasFieldSmoothingSigma} ] ; then
    BiasFieldSmoothingSigma="--bfsigma=${BiasFieldSmoothingSigma}"
  fi

  if [ ! "${T2wInputImages}" = "NONE" ] ; then

    log_Msg "Performing Bias Field Correction using sqrt(T1w x T2w)"    
    log_Msg "mkdir -p ${T1wFolder}/BiasFieldCorrection_sqrtT1wXT2w"

    mkdir -p ${T1wFolder}/BiasFieldCorrection_sqrtT1wXT2w

    ${RUN} ${HCPPIPEDIR_PreFS}/BiasFieldCorrection_sqrtT1wXT2w.sh \
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

    ${RUN} ${HCPPIPEDIR_PreFS}/BiasFieldCorrection_T1wOnly.sh \
      --workingdir=${T1wFolder}/BiasFieldCorrection_T1wOnly \
      --T1im=${T1wFolder}/${T1wImage}_acpc_dc \
      --T1brain=${T1wFolder}/${T1wImage}_acpc_dc_brain \
      --obias=${T1wFolder}/BiasField_acpc_dc \
      --oT1im=${T1wFolder}/${T1wImage}_acpc_dc_restore \
      --oT1brain=${T1wFolder}/${T1wImage}_acpc_dc_restore_brain \
      ${BiasFieldSmoothingSigma}

  fi


  # ------------------------------------------------------------------------------
  # Create a one-step resampled version of the {T1w,T2w}_acpc_dc outputs
  # (applied after GDC, which we don't bundle in, because of the possible need
  # to average multiple T1/T2 inputs).

  # This overwrites the {T1w,T2w}_acpc_dc outputs created above, and mimics what
  # occurs at the beginning of PostFreeSurfer/CreateMyelinMaps.sh.
  # Note that the CreateMyelinMaps equivalent is still needed though because
  # (1) T1w_acpc_dc_restore_brain is (re)generated with a better estimate of
  #     the brain mask, provided by FreeSurfer
  # (2) the entire set of T2w_acpc_dc outputs needs to be regenerated, using the
  #     refinement to the "T2wtoT1w" registration that FreeSurfer provides.

  # Just implement inline, rather than writing a separate script
  # Added 2/19/2019
  # ------------------------------------------------------------------------------

  log_Msg "Creating one-step resampled version of {T1w,T2w}_acpc_dc outputs"

  # T1w
  OutputOrigT1wToT1w=OrigT1w2T1w_PreFS  # Name for one-step resample warpfield
  convertwarp --relout --rel --ref=${T1wTemplate} --premat=${T1wFolder}/xfms/acpc.mat --warp1=${T1wFolder}/xfms/${T1wImage}_dc --out=${T1wFolder}/xfms/${OutputOrigT1wToT1w}

  OutputT1wImage=${T1wFolder}/${T1wImage}_acpc_dc
  applywarp --rel --interp=spline -i ${T1wFolder}/${T1wImage} -r ${T1wTemplate} -w ${T1wFolder}/xfms/${OutputOrigT1wToT1w} -o ${OutputT1wImage}
  fslmaths ${OutputT1wImage} -abs ${OutputT1wImage} -odt float  # Use -abs (rather than '-thr 0') to avoid introducing zeros
  fslmaths ${OutputT1wImage} -div ${T1wFolder}/BiasField_acpc_dc ${OutputT1wImage}_restore
  fslmaths ${OutputT1wImage}_restore -mas ${T1wFolder}/${T1wImage}_acpc_dc_brain ${OutputT1wImage}_restore_brain

  if [ ! "${T2wInputImages}" = "NONE" ] ; then
    OutputOrigT2wToT1w=OrigT2w2T1w_PreFS  # Name for one-step resample warpfield
    convertwarp --relout --rel --ref=${T1wTemplate} --premat=${T2wFolder}/xfms/acpc.mat --warp1=${T1wFolder}/xfms/${T2wImage}_reg_dc --out=${T1wFolder}/xfms/${OutputOrigT2wToT1w}

    OutputT2wImage=${T1wFolder}/${T2wImage}_acpc_dc
    applywarp --rel --interp=spline -i ${T2wFolder}/${T2wImage} -r ${T1wTemplate} -w ${T1wFolder}/xfms/${OutputOrigT2wToT1w} -o ${OutputT2wImage}
    fslmaths ${OutputT2wImage} -abs ${OutputT2wImage} -odt float  # Use -abs (rather than '-thr 0') to avoid introducing zeros
    fslmaths ${OutputT2wImage} -div ${T1wFolder}/BiasField_acpc_dc ${OutputT2wImage}_restore
    fslmaths ${OutputT2wImage}_restore -mas ${T1wFolder}/${T1wImage}_acpc_dc_brain ${OutputT2wImage}_restore_brain
  fi

# -- Are we using a custom mask?

elif [ "$CustomBrain" = "MASK" ] ; then

  log_Msg "Skipping all the steps to Atlas registration, applying custom mask."
  verbose_red_echo "---> Applying custom mask"

  OutputT1wImage=${T1wFolder}/${T1wImage}_acpc_dc
  fslmaths ${OutputT1wImage}_restore -mas ${T1wFolder}/custom_acpc_dc_restore_mask ${OutputT1wImage}_restore_brain

  if [ ! "${T2wInputImages}" = "NONE" ] ; then
    OutputT2wImage=${T1wFolder}/${T2wImage}_acpc_dc
    fslmaths ${OutputT2wImage}_restore -mas ${T1wFolder}/custom_acpc_dc_restore_mask ${OutputT2wImage}_restore_brain
  fi

# -- Then we are using existing images

else

  log_Msg "Skipping all the steps preceding AtlasRegistration, using existing images instead."
  verbose_red_echo "---> Using existing images"

fi  # --- skipped all the way to here if using customized structural images (--custombrain=CUSTOM)

# Remove the file (warpfield) that serves as a proxy in FreeSurferPipeline for whether PostFreeSurfer has been run
# i.e., whether the T1w/T1w_acpc_dc* volumes reflect the PreFreeSurferPipeline versions (above)
# or the PostFreeSurferPipeline versions.
# Make sure that you rerun FreeSurfer and PostFreeSurfer if using --custombrain={CUSTOM|MASK}
# or if otherwise simply re-running PreFreeSurfer on top of existing data [which is not advised; 
# in the --custombrain=NONE condition, the recommendation would be to simply delete the existing data, 
# and run PreFreeSurfer (and then FreeSurfer and PostFreeSurfer) de novo].

OutputOrigT1wToT1wPostFS=OrigT1w2T1w  #Needs to match name used in both FreeSurferPipeline and PostFreeSurferPipeline
imrm ${T1wFolder}/xfms/${OutputOrigT1wToT1wPostFS}


# ------------------------------------------------------------------------------
#  Atlas Registration to MNI152: FLIRT + FNIRT
#  Also applies the MNI registration to T1w and T2w images
#  (although, these will be overwritten, and the final versions generated via
#  a one-step resampling equivalent in PostFreeSurfer/CreateMyelinMaps.sh;
#  so, the primary purpose of the following is to generate the Atlas Registration itself).
# ------------------------------------------------------------------------------

log_Msg "Performing Atlas Registration to MNI152 (FLIRT and FNIRT)"

${RUN} ${HCPPIPEDIR_PreFS}/AtlasRegistrationToMNI152_FLIRTandFNIRT.sh \
  --workingdir=${AtlasSpaceFolder} \
  --t1=${T1wFolder}/${T1wImage}_acpc_dc \
  --t1rest=${T1wFolder}/${T1wImage}_acpc_dc_restore \
  --t1restbrain=${T1wFolder}/${T1wImage}_acpc_dc_restore_brain \
  --t2=${T1wFolder_T2wImageWithPath_acpc_dc} \
  --t2rest=${T1wFolder}/${T2wImage}_acpc_dc_restore \
  --t2restbrain=${T1wFolder}/${T2wImage}_acpc_dc_restore_brain \
  --ref=${T1wTemplate} \
  --refbrain=${T1wTemplateBrain} \
  --refmask=${TemplateMask} \
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
  --fnirtconfig=${FNIRTConfig} 

log_Msg "Completed!"

