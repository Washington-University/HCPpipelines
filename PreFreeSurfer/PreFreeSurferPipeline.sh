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
# * Modifications to allow absence of T2w images, to improve bias correction, fix interpolation errors, and mask arteries
#   are done by Lennart Verhagen as a fork of the GitHub repository called "OxfordStructural"
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
# * HCPPIPEDIR_PreFS
#
#   Location of PreFreeSurfer sub-scripts that are used to carry out some of
#   steps of the PreFreeSurfer pipeline
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
# * ${T1wFolder}/BiasFieldCorrection_sqrtT1wXT1w
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

# Setup this script such that if any command exits with a non-zero value, the
# script itself exits and does not attempt any further processing.
set -e

# -----------------------------------------------------------------------------------
#  Constants for specification of Averaging and Readout Distortion Correction Method
# -----------------------------------------------------------------------------------

NONE_METHOD_OPT="NONE"
FIELDMAP_METHOD_OPT="FIELDMAP"
SIEMENS_METHOD_OPT="SiemensFieldMap"
SPIN_ECHO_METHOD_OPT="TOPUP"
GENERAL_ELECTRIC_METHOD_OPT="GeneralElectricFieldMap"

# ------------------------------------------------------------------------------
#  Load Function Libraries
# ------------------------------------------------------------------------------

source $HCPPIPEDIR/global/scripts/log.shlib  # Logging related functions
source $HCPPIPEDIR/global/scripts/opts.shlib # Command line option functions

# ------------------------------------------------------------------------------
#  Usage Description Function
# ------------------------------------------------------------------------------

show_usage() {
    cat <<EOF

PreFreeSurferPipeline.sh

Usage: PreeFreeSurferPipeline.sh [options]

  --path=<path>        Path to study data folder (required)
                       Used with --subject input to create full path to root
                       directory for all outputs generated as path/subject
  --subject=<subject>  Subject ID (required)
                       Used with --path input to create full path to root
                       directory for all outputs generated as path/subject
  --t1=<T1w images>    An @ symbol separated list of full paths to T1-weighted
                       (T1w) structural images for the subject (required)
  --t2=<T2w images>    An @ symbol separated list of full paths to T2-weighted
                       (T2w) structural images for the subject (required)
  --t1template=<file path>          MNI T1w template
  --t1templatebrain=<file path>     Brain extracted MNI T1wTemplate
  --t1template2mm=<file path>       MNI 2mm T1wTemplate
  --t2template=<file path>          MNI T2w template
  --t2templatebrain=<file path>     Brain extracted MNI T2wTemplate
  --t2template2mm=<file path>       MNI 2mm T2wTemplate
  --templatemask=<file path>        Brain mask MNI Template
  --template2mmmask=<file path>     Brain mask MNI 2mm Template
  --brainsize=<size value>          Brain size estimate in mm, 150 for humans
  --fnirtconfig=<file path>         FNIRT 2mm T1w Configuration file
  --fmapmag=<file path>             Siemens Gradient Echo Fieldmap magnitude file
  --fmapphase=<file path>           Siemens Gradient Echo Fieldmap phase file
  --fmapgeneralelectric=<file path> General Electric Gradient Echo Field Map file
                                    Two volumes in one file
                                    1. field map in deg
                                    2. magnitude
  --echodiff=<delta TE>             Delta TE in ms for field map or "NONE" if
                                    not used
  --SEPhaseNeg={<file path>, NONE}  For spin echo field map, path to volume with
                                    a negative phase encoding direction (LR in
                                    HCP data), set to "NONE" if not using Spin
                                    Echo Field Maps
  --SEPhasePos={<file path>, NONE}  For spin echo field map, path to volume with
                                    a positive phase encoding direction (RL in
                                    HCP data), set to "NONE" if not using Spin
                                    Echo Field Maps
  --echospacing=<dwell time>        Echo Spacing or Dwelltime of Spin Echo Field
                                    Map or "NONE" if not used
  --seunwarpdir={x, y, NONE}        Phase encoding direction of the spin echo
                                    field map. (Only applies when using a spin echo
                                    field map.)
  --t1samplespacing=<seconds>       T1 image sample spacing, "NONE" if not used
  --t2samplespacing=<seconds>       T2 image sample spacing, "NONE" if not used
  --unwarpdir={x, y, z}             Readout direction of the T1w and T2w images
                                    (Used with either a gradient echo field map
                                     or a spin echo field map)
  --gdcoeffs=<file path>            File containing gradient distortion
                                    coefficients, Set to "NONE" to turn off
  --avgrdcmethod=<avgrdcmethod>     Averaging and readout distortion correction
                                    method. See below for supported values.

      "${NONE_METHOD_OPT}"
         average any repeats with no readout distortion correction

      "${FIELDMAP_METHOD_OPT}"
         equivalent to "${SIEMENS_METHOD_OPT}" (see below)
         SiemensFieldMap is preferred. This option value is maintained for
         backward compatibility.

      "${SPIN_ECHO_METHOD_OPT}"
         average any repeats and use Spin Echo Field Maps for readout
         distortion correction

      "${GENERAL_ELECTRIC_METHOD_OPT}"
         average any repeats and use General Electric specific Gradient
         Echo Field Maps for readout distortion correction

      "${SIEMENS_METHOD_OPT}"
         average any repeats and use Siemens specific Gradient Echo
         Field Maps for readout distortion correction

  --topupconfig=<file path>      Configuration file for topup or "NONE" if not
                                 used
  --bfsigma=<value>              Bias Field Smoothing Sigma (optional)
  --initbiascorr={TRUE, FALSE}   Perform inital (and temporary) bias correction
                                 to improve FNIRT based brain extraction and
                                 T2w to T1w registration.
  --biascorr={sqrtT1wbyT2w, FAST}
                                 Bias correction method.
                                 "sqrtT1wbyT2w" =  default of HCP
                                 "FAST" = (robust implementation of) FAST
  --fixnegvalmethod={none, thr (default), abs, smooth}
                                 Fix negative values, either by thresholding at
                                 zero (default), taking absolute values, or
                                 smoothly filling (interpolate) voxels with
                                 values below or exactly at 0. Negative values
                                 can arise through spline interpolation (the
                                 default in the HCP pipelines). Select "none" to
                                 skip this fix.
  --maskartery={TRUE (default), FALSE}
                                 Mask arteries or not. This could be beneficial
                                 for registration and bias field estimation
                                 using 7T T1w images, where arteries are
                                 generally extremely bright.
EOF
    exit 1
}

defaultopt() {
    echo $1
}

# ------------------------------------------------------------------------------
#  Establish tool name for logging
# ------------------------------------------------------------------------------
log_SetToolName "PreFreeSurferPipeline.sh"

# ------------------------------------------------------------------------------
#  Parse Command Line Options
# ------------------------------------------------------------------------------

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
    show_usage
fi

log_Msg "Platform Information Follows: "
uname -a

log_Msg "Parsing Command Line Options"

StudyFolder=`opts_GetOpt1 "--path" $@`
Subject=`opts_GetOpt1 "--subject" $@`
T1wInputImages=`opts_GetOpt1 "--t1" $@`
T2wInputImages=`opts_GetOpt1 "--t2" $@`
T1wTemplate=`opts_GetOpt1 "--t1template" $@`
T1wTemplateBrain=`opts_GetOpt1 "--t1templatebrain" $@`
T1wTemplate2mm=`opts_GetOpt1 "--t1template2mm" $@`
T2wTemplate=`opts_GetOpt1 "--t2template" $@`
T2wTemplateBrain=`opts_GetOpt1 "--t2templatebrain" $@`
T2wTemplate2mm=`opts_GetOpt1 "--t2template2mm" $@`
TemplateMask=`opts_GetOpt1 "--templatemask" $@`
Template2mmMask=`opts_GetOpt1 "--template2mmmask" $@`
BrainSize=`opts_GetOpt1 "--brainsize" $@`
FNIRTConfig=`opts_GetOpt1 "--fnirtconfig" $@`
MagnitudeInputName=`opts_GetOpt1 "--fmapmag" $@`
PhaseInputName=`opts_GetOpt1 "--fmapphase" $@`
GEB0InputName=`opts_GetOpt1 "--fmapgeneralelectric" $@`
TE=`opts_GetOpt1 "--echodiff" $@`
SpinEchoPhaseEncodeNegative=`opts_GetOpt1 "--SEPhaseNeg" $@`
SpinEchoPhaseEncodePositive=`opts_GetOpt1 "--SEPhasePos" $@`
DwellTime=`opts_GetOpt1 "--echospacing" $@`
SEUnwarpDir=`opts_GetOpt1 "--seunwarpdir" $@`
T1wSampleSpacing=`opts_GetOpt1 "--t1samplespacing" $@`
T2wSampleSpacing=`opts_GetOpt1 "--t2samplespacing" $@`
UnwarpDir=`opts_GetOpt1 "--unwarpdir" $@`
GradientDistortionCoeffs=`opts_GetOpt1 "--gdcoeffs" $@`
AvgrdcSTRING=`opts_GetOpt1 "--avgrdcmethod" $@`
TopupConfig=`opts_GetOpt1 "--topupconfig" $@`
BiasFieldSmoothingSigma=`opts_GetOpt1 "--bfsigma" $@`
InitBiasCorr=`opts_GetOpt1 "--initbiascorr" $@`
BiasCorr=`opts_GetOpt1 "--biascorr" $@`
FixNegValMethod=`opts_GetOpt1 "--fixnegvalmethod" $@`
MaskArtery=`opts_GetOpt1 "--maskartery" $@`

# set defaults for OxfordStructural arguments
InitBiasCorr=`defaultopt $InitBiasCorr "FALSE"`
BiasCorr=`defaultopt $BiasCorr "sqrtT1wbyT2w"`
FixNegValMethod=`defaultopt $FixNegValMethod "thr"`
MaskArtery=`defaultopt $MaskArtery "TRUE"`

#NOTE: currently is only used in gradient distortion correction of spin echo fieldmaps to topup
#not currently in usage, either, because of this very limited use
UseJacobian=`opts_GetOpt1 "--usejacobian" $@`

# Use --printcom=echo for just printing everything and not actually
# running the commands (the default is to actually run the commands)
RUN=`opts_GetOpt1 "--printcom" $@`

# Convert UseJacobian value to all lowercase (to allow the user the flexibility to use True, true, TRUE, False, False, false, etc.)
UseJacobian="$(echo ${UseJacobian} | tr '[:upper:]' '[:lower:]')"
UseJacobian=`opts_DefaultOpt $UseJacobian "true"`

# ------------------------------------------------------------------------------
#  Show Command Line Options
# ------------------------------------------------------------------------------

log_Msg "Finished Parsing Command Line Options"
log_Msg "StudyFolder: ${StudyFolder}"
log_Msg "Subject: ${Subject}"
log_Msg "T1wInputImages: ${T1wInputImages}"
log_Msg "T2wInputImages: ${T2wInputImages}"
log_Msg "T1wTemplate: ${T1wTemplate}"
log_Msg "T1wTemplateBrain: ${T1wTemplateBrain}"
log_Msg "T1wTemplate2mm: ${T1wTemplate2mm}"
log_Msg "T2wTemplate: ${T2wTemplate}"
log_Msg "T2wTemplateBrain: ${T2wTemplateBrain}"
log_Msg "T2wTemplate2mm: ${T2wTemplate2mm}"
log_Msg "TemplateMask: ${TemplateMask}"
log_Msg "Template2mmMask: ${Template2mmMask}"
log_Msg "BrainSize: ${BrainSize}"
log_Msg "FNIRTConfig: ${FNIRTConfig}"
log_Msg "MagnitudeInputName: ${MagnitudeInputName}"
log_Msg "PhaseInputName: ${PhaseInputName}"
log_Msg "GEB0InputName: ${GEB0InputName}"
log_Msg "TE: ${TE}"
log_Msg "SpinEchoPhaseEncodeNegative: ${SpinEchoPhaseEncodeNegative}"
log_Msg "SpinEchoPhaseEncodePositive: ${SpinEchoPhaseEncodePositive}"
log_Msg "DwellTime: ${DwellTime}"
log_Msg "SEUnwarpDir: ${SEUnwarpDir}"
log_Msg "T1wSampleSpacing: ${T1wSampleSpacing}"
log_Msg "T2wSampleSpacing: ${T2wSampleSpacing}"
log_Msg "UnwarpDir: ${UnwarpDir}"
log_Msg "GradientDistortionCoeffs: ${GradientDistortionCoeffs}"
log_Msg "AvgrdcSTRING: ${AvgrdcSTRING}"
log_Msg "TopupConfig: ${TopupConfig}"
log_Msg "BiasFieldSmoothingSigma: ${BiasFieldSmoothingSigma}"
log_Msg "UseJacobian: ${UseJacobian}"
log_Msg "InitBiasCorr: ${InitBiasCorr}"
log_Msg "BiasCorr: ${BiasCorr}"
log_Msg "FixNegValMethod: ${FixNegValMethod}"
log_Msg "MaskArtery: ${MaskArtery}"

# ------------------------------------------------------------------------------
#  Show Environment Variables
# ------------------------------------------------------------------------------

log_Msg "FSLDIR: ${FSLDIR}"
log_Msg "HCPPIPEDIR: ${HCPPIPEDIR}"
log_Msg "HCPPIPEDIR_Global: ${HCPPIPEDIR_Global}"
log_Msg "HCPPIPEDIR_PreFS: ${HCPPIPEDIR_PreFS}"

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

if [ ! -e ${T1wFolder}/xfms ] ; then
    log_Msg "mkdir -p ${T1wFolder}/xfms/"
    mkdir -p ${T1wFolder}/xfms/
fi

if [[ -n $T2wInputImages ]] && [ ! -e ${T2wFolder}/xfms ] ; then
	log_Msg "mkdir -p ${T2wFolder}/xfms/"
    mkdir -p ${T2wFolder}/xfms/
fi

if [ ! -e ${AtlasSpaceFolder}/xfms ] ; then
    log_Msg "mkdir -p ${AtlasSpaceFolder}/xfms/"
    mkdir -p ${AtlasSpaceFolder}/xfms/
fi

log_Msg "POSIXLY_CORRECT="${POSIXLY_CORRECT}

# ------------------------------------------------------------------------------
#  Do primary work
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
#  Loop over the processing for T1w and T2w (just with different names).
#  For each modality, perform
#  - Gradient Nonlinearity Correction (Unless no gradient distortion
#    coefficients are available)
#  - Average same modality images (if more than one is available)
#  - Rigidly align images to 0.7mm MNI Template to create native volume space
#  - Perform Brain Extraction(FNIRT-based Masking)
# ------------------------------------------------------------------------------

if [[ -n $T2wInputImages ]] ; then
  Modalities="T1w T2w"
else
  Modalities="T1w"
fi

for TXw in ${Modalities} ; do
    log_Msg "Processing Modality: " $TXw

    # set up appropriate input variables
    if [[ $TXw = T1w ]] ; then
        TXwInputImages="${T1wInputImages}"
        TXwFolder=${T1wFolder}
        TXwImage=${T1wImage}
        TXwTemplate=${T1wTemplate}
    	  TXwTemplate2mm=${T1wTemplate2mm}
        X=1
    else
        TXwInputImages="${T2wInputImages}"
        TXwFolder=${T2wFolder}
        TXwImage=${T2wImage}
        TXwTemplate=${T2wTemplate}
        TXwTemplate2mm=${T2wTemplate2mm}
        X=2
    fi
    OutputTXwImageSTRING=""

    # Perform Gradient Nonlinearity Correction

    if [[ ! $GradientDistortionCoeffs = "NONE" ]] ; then
        log_Msg "Performing Gradient Nonlinearity Correction"

        i=1
        for Image in $TXwInputImages ; do
            wdir=${TXwFolder}/${TXwImage}${i}_GradientDistortionUnwarp
            log_Msg "mkdir -p $wdir"
            mkdir -p $wdir
            # Make sure input axes are oriented the same as the templates
            ${RUN} ${FSLDIR}/bin/fslreorient2std $Image ${wdir}/${TXwImage}${i}
            # fix negative values in the images
            ${RUN} $HCPPIPEDIR_PreFS/FixNegVal.sh --in=${wdir}/${TXwImage}${i} --method=$FixNegValMethod

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
            # reorient the input images to the standard configuration
            ${RUN} ${FSLDIR}/bin/fslreorient2std $Image ${TXwFolder}/${TXwImage}${i}_gdc
            # fix negative values in the images
            ${RUN} $HCPPIPEDIR_PreFS/FixNegVal.sh --in=${TXwFolder}/${TXwImage}${i}_gdc --method=$FixNegValMethod

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
        log_Msg "ONLY ONE AVERAGE FOUND: COPYING"
        ${RUN} ${FSLDIR}/bin/imcp ${TXwFolder}/${TXwImage}1_gdc ${TXwFolder}/${TXwImage}
    fi

    # Perform initial robust bias correction based on fast to improve registration
    if [[ $InitBiasCorr = "TRUE" ]] ; then
        log_Msg "Initial bias correction of ${TXw} image to improve subsequent registration"
        log_Msg "mkdir -p ${TXwFolder}/InitBiasCorr"
        mkdir -p ${TXwFolder}/InitBiasCorr
        [[ -n $BiasFieldSmoothingSigma ]] && bfsigma_initbiascorr=$BiasFieldSmoothingSigma || bfsigma_initbiascorr=5
        FWHM=$(echo "2.3548 * $bfsigma_initbiascorr" | bc)
        ${RUN} $HCPPIPEDIR_PreFS/RobustBiasCorr.sh --in=${TXwFolder}/${TXwImage} --workingdir=${TXwFolder}/InitBiasCorr --basename=${TXwImage} --FWHM=$FWHM --type=$X --fixnegvalmethod=$FixNegValMethod
        # move bias corrected images to main folder and clean up
        ${FSLDIR}/bin/immv ${TXwFolder}/InitBiasCorr/${TXwImage}_restore ${TXwFolder}/${TXwImage}_restore
        rm -r ${TXwFolder}/InitBiasCorr/
    fi

    # ACPC align T1w or T2w image to 0.7mm MNI Template to create native volume space
    log_Msg "Aligning ${TXw} image to 0.7mm MNI ${TXw}Template to create native volume space"
    log_Msg "mkdir -p ${TXwFolder}/ACPCAlignment"
    mkdir -p ${TXwFolder}/ACPCAlignment

    # set context dependent arguments
    if [[ $InitBiasCorr = "TRUE" ]] ; then
      Arg_in=${TXwFolder}/${TXwImage}_restore
      Arg_out=${TXwFolder}/${TXwImage}_restore_acpc
      ExtraArguments="--inextra=${TXwFolder}/${TXwImage} --outextra=${TXwFolder}/${TXwImage}_acpc"
    else
      Arg_in=${TXwFolder}/${TXwImage}
      Arg_out=${TXwFolder}/${TXwImage}_acpc
      ExtraArguments=""
    fi

    ${RUN} ${HCPPIPEDIR_PreFS}/ACPCAlignment.sh \
        --workingdir=${TXwFolder}/ACPCAlignment \
        --in=${Arg_in} \
        --ref=${TXwTemplate} \
        --out=${Arg_out} \
        --omat=${TXwFolder}/xfms/acpc.mat \
        --brainsize=${BrainSize} \
        --fixnegvalmethod=${FixNegValMethod} \
        $ExtraArguments

    # detect arteries based on intensity in T1w image
    if [[ $TXw = "T1w" && $MaskArtery = "TRUE" ]] ; then
      # extract brain
      bet $Arg_out ${Arg_out}_brain -f 0.1
      # detect arteries based on intensity
      ${RUN} $HCPPIPEDIR_PreFS/ArteryDetection.sh --workingdir=${T1wFolder}/ArteryDetection --t1=${Arg_out} --t1brain=${Arg_out}_brain
      # set the inverse artery mask as the input mask for registration
      Arg_out_base=$(basename $Arg_out)
      ArteryMaskInv=${T1wFolder}/ArteryDetection/${Arg_out_base}_arterymask_inv
      ArteryMaskDilInv=${T1wFolder}/ArteryDetection/${Arg_out_base}_arterymaskdil_inv
      Arg_inmask=$ArteryMaskDilInv
    else
      Arg_inmask=""
    fi

    # Brain Extraction(FNIRT-based Masking)
    log_Msg "Performing Brain Extraction using FNIRT-based Masking"
    log_Msg "mkdir -p ${TXwFolder}/BrainExtraction_FNIRTbased"
    mkdir -p ${TXwFolder}/BrainExtraction_FNIRTbased

    # set context dependent arguments
    if [[ $InitBiasCorr = "TRUE" ]] ; then
      Arg_in=${TXwFolder}/${TXwImage}_restore_acpc
      Arg_outbrain=${TXwFolder}/${TXwImage}_restore_acpc_brain
      Arg_outbrainmask=${TXwFolder}/${TXwImage}_restore_acpc_brain_mask
    else
      Arg_in=${TXwFolder}/${TXwImage}_acpc
      Arg_outbrain=${TXwFolder}/${TXwImage}_acpc_brain
      Arg_outbrainmask=${TXwFolder}/${TXwImage}_acpc_brain_mask
    fi

    ${RUN} ${HCPPIPEDIR_PreFS}/BrainExtraction_FNIRTbased.sh \
        --workingdir=${TXwFolder}/BrainExtraction_FNIRTbased \
        --in=${Arg_in} \
        --inmask=${Arg_inmask} \
        --ref=${TXwTemplate} \
        --refmask=${TemplateMask} \
        --ref2mm=${TXwTemplate2mm} \
        --ref2mmmask=${Template2mmMask} \
        --outbrain=${Arg_outbrain} \
    	  --outbrainmask=${Arg_outbrainmask} \
      	--fnirtconfig=${FNIRTConfig}

    # mask uncorrected acpc aligned image with corrected brain mask
    if [[ $InitBiasCorr = "TRUE" ]] ; then
        ${FSLDIR}/bin/imcp ${Arg_outbrainmask} ${TXwFolder}/${TXwImage}_acpc_brain_mask
        ${FSLDIR}/bin/fslmaths ${TXwFolder}/${TXwImage}_acpc -mas ${TXwFolder}/${TXwImage}_acpc_brain_mask ${TXwFolder}/${TXwImage}_acpc_brain
    fi

done

# End of looping over modalities (T1w and T2w)

# ------------------------------------------------------------------------------
#  T2w to T1w Registration and Optional Readout Distortion Correction
# ------------------------------------------------------------------------------

case $AvgrdcSTRING in

    ${FIELDMAP_METHOD_OPT} | ${SPIN_ECHO_METHOD_OPT} | ${GENERAL_ELECTRIC_METHOD_OPT} | ${SIEMENS_METHOD_OPT})

      # if T2w image is present
      if [[ -n $T2wInputImages ]] ; then

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

        # set context dependent arguments
        ExtraArguments=""
        if [[ $InitBiasCorr = "TRUE" ]] ; then
          ExtraArguments="--t1reg=${T1wFolder}/${T1wImage}_restore_acpc --t1brainreg=${T1wFolder}/${T1wImage}_restore_acpc_brain --t2reg=${T2wFolder}/${T2wImage}_restore_acpc --t2brainreg=${T2wFolder}/${T2wImage}_restore_acpc_brain --ot1reg=${T1wFolder}/${T1wImage}_restore_acpc_dc --ot1brainreg=${T1wFolder}/${T1wImage}_restore_acpc_dc_brain --ot2reg=${T1wFolder}/${T2wImage}_restore_acpc_dc --ot2brainreg=${T1wFolder}/${T2wImage}_restore_acpc_dc_brain"
        fi

        ${RUN} ${HCPPIPEDIR_PreFS}/T2wToT1wDistortionCorrectAndReg.sh \
            --workingdir=${wdir} \
            --t1=${T1wFolder}/${T1wImage}_acpc \
            --t1brain=${T1wFolder}/${T1wImage}_acpc_brain \
            --t2=${T2wFolder}/${T2wImage}_acpc \
            --t2brain=${T2wFolder}/${T2wImage}_acpc_brain \
            --fmapmag=${MagnitudeInputName} \
            --fmapphase=${PhaseInputName} \
            --fmapgeneralelectric=${GEB0InputName} \
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
            --ot2brain=${T1wFolder}/${T2wImage}_acpc_dc_brain \
            --ot2warp=${T1wFolder}/xfms/${T2wImage}_reg_dc \
            --method=${AvgrdcSTRING} \
            --topupconfig=${TopupConfig} \
            --gdcoeffs=${GradientDistortionCoeffs} \
            --usejacobian=${UseJacobian} \
            --fixnegvalmethod=${FixNegValMethod} \
            ${ExtraArguments}

          else

            log_Msg "Performing ${AvgrdcSTRING} Readout Distortion Correction"
            wdir=${T1wFolder}/DistortionCorrect
            if [ -d ${wdir} ] ; then
                # DO NOT change the following line to "rm -r ${wdir}" because the
                # chances of something going wrong with that are much higher, and
                # rm -r always needs to be treated with the utmost caution
                rm -r ${T1wFolder}/DistortionCorrect
            fi

            log_Msg "mkdir -p ${wdir}"
            mkdir -p ${wdir}
            ExtraArguments=""
            if [[ $InitBiasCorr = "TRUE" ]] ; then
              ExtraArguments="--t1reg=${T1wFolder}/${T1wImage}_restore_acpc --t1brainreg=${T1wFolder}/${T1wImage}_restore_acpc_brain --ot1reg=${T1wFolder}/${T1wImage}_restore_acpc_dc --ot1brainreg=${T1wFolder}/${T1wImage}_restore_acpc_dc_brain"
            fi

            ${RUN} ${HCPPIPEDIR_PreFS}/DistortionCorrect.sh \
                --workingdir=${wdir} \
                --t1=${T1wFolder}/${T1wImage}_acpc \
                --t1brain=${T1wFolder}/${T1wImage}_acpc_brain \
                --fmapmag=${MagnitudeInputName} \
                --fmapphase=${PhaseInputName} \
                --echodiff=${TE} \
                --SEPhaseNeg=${SpinEchoPhaseEncodeNegative} \
                --SEPhasePos=${SpinEchoPhaseEncodePositive} \
                --echospacing=${DwellTime} \
                --seunwarpdir=${SEUnwarpDir} \
                --t1sampspacing=${T1wSampleSpacing} \
                --unwarpdir=${UnwarpDir} \
                --ot1=${T1wFolder}/${T1wImage}_acpc_dc \
                --ot1brain=${T1wFolder}/${T1wImage}_acpc_dc_brain \
                --ot1warp=${T1wFolder}/xfms/${T1wImage}_dc \
                --method=${AvgrdcSTRING} \
                --topupconfig=${TopupConfig} \
                --gdcoeffs=${GradientDistortionCoeffs} \
                --usejacobian=${UseJacobian} \
                --fixnegvalmethod=${FixNegValMethod} \
                ${ExtraArguments}

            fi

        ;;

    *)

      # if T2w image is present
      if [[ -n $T2wInputImages ]] ; then

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

        # set context dependent arguments
        ExtraArguments=""
        if [[ $InitBiasCorr = "TRUE" ]] ; then
          ExtraArguments="--t1reg=${T1wFolder}/${T1wImage}_restore_acpc --t1brainreg=${T1wFolder}/${T1wImage}_restore_acpc_brain --t2reg=${T2wFolder}/${T2wImage}_restore_acpc --t2brainreg=${T2wFolder}/${T2wImage}_restore_acpc_brain --ot1reg=${T1wFolder}/${T1wImage}_restore_acpc_dc --ot1brainreg=${T1wFolder}/${T1wImage}_restore_acpc_dc_brain --ot2reg=${T1wFolder}/${T2wImage}_restore_acpc_dc --ot2brainreg=${T1wFolder}/${T2wImage}_restore_acpc_dc_brain"
        fi

        ${RUN} ${HCPPIPEDIR_PreFS}/T2wToT1wReg.sh \
            --workingdir=${wdir} \
            --t1=${T1wFolder}/${T1wImage}_acpc \
            --t1brain=${T1wFolder}/${T1wImage}_acpc_brain \
            --t2=${T2wFolder}/${T2wImage}_acpc \
            --t2brain=${T2wFolder}/${T2wImage}_acpc_brain \
            --ot1=${T1wFolder}/${T1wImage}_acpc_dc \
            --ot1brain=${T1wFolder}/${T1wImage}_acpc_dc_brain \
            --ot1warp=${T1wFolder}/xfms/${T1wImage}_dc \
            --ot2=${T1wFolder}/${T2wImage}_acpc_dc \
            --ot2brain=${T1wFolder}/${T2wImage}_acpc_dc_brain \
            --ot2warp=${T1wFolder}/xfms/${T2wImage}_reg_dc \
            --fixnegvalmethod=${FixNegValMethod} \
            ${ExtraArguments}
      else

        log_Msg "No Readout Distortion Correction and No T2w>T1w Registration"
        cp ${T1wFolder}/${T1wImage}_acpc.nii.gz ${T1wFolder}/${T1wImage}_acpc_dc.nii.gz
        cp ${T1wFolder}/${T1wImage}_acpc_brain.nii.gz ${T1wFolder}/${T1wImage}_acpc_dc_brain.nii.gz

      fi
esac

# ------------------------------------------------------------------------------
#  Bias Field Correction: Calculate bias field using square root of the product
#  of T1w and T2w iamges.
# ------------------------------------------------------------------------------

log_Msg "Performing Bias Field Correction"

# mask arteries before bias field estimation (or not)
if [[ $MaskArtery = "TRUE" ]] ; then

  # set arguments
  if [[ $InitBiasCorr = "TRUE" ]] ; then
    Arg_t1=${T1wFolder}/${T1wImage}_restore_acpc_dc
    Arg_t1brain=${T1wFolder}/${T1wImage}_restore_acpc_dc_brain
    [[ -n $T2wInputImages ]] && Arg_t2brain=${T1wFolder}/${T2wImage}_restore_acpc_dc_brain || Arg_t2brain=""
    Arg_basenamebrain=${T1wImage}_restore_acpc_dc_brain
    Arg_basename=${T1wImage}_restore_acpc_dc
    FWHM="INF"
  else
    Arg_t1=${T1wFolder}/${T1wImage}_acpc_dc
    Arg_t1brain=${T1wFolder}/${T1wImage}_acpc_dc_brain
    [[ -n $T2wInputImages ]] && Arg_t2brain=${T1wFolder}/${T2wImage}_acpc_dc_brain || Arg_t2brain=""
    Arg_basenamebrain=${T1wImage}_acpc_dc_brain
    Arg_basename=${T1wImage}_acpc_dc
    [[ -n $BiasFieldSmoothingSigma ]] && bfsigma_initbiascorr=$BiasFieldSmoothingSigma || bfsigma_initbiascorr=5
    FWHM=$(echo "2.3548 * $bfsigma_initbiascorr" | bc)
  fi

  # remove the old RobustSegmentation folder
  rm -rf ${T1wFolder}/RobustSegmentation

  # Create a WM mask
  ${RUN} $HCPPIPEDIR_PreFS/RobustSegmentation.sh \
  --workingdir=${T1wFolder}/RobustSegmentation \
  --t1brain=$Arg_t1brain \
  --t2brain=$Arg_t2brain \
  --runfast="TRUE" \
  --fwhm=$FWHM \
  --basename=$Arg_basenamebrain

  # detect arteries based on intensity
  ${RUN} $HCPPIPEDIR_PreFS/ArteryDetection.sh \
  --workingdir=${T1wFolder}/ArteryDetection \
  --t1=$Arg_t1 \
  --t1brain=$Arg_t1brain \
  --exclmask=${T1wFolder}/RobustSegmentation/${Arg_basenamebrain}_WM \
  --basename=$Arg_basename

  # smooth filling on original non-bias-corrected T1 and T2
  ${RUN} $HCPPIPEDIR_PreFS/FixNegVal.sh \
  --in=${T1wFolder}/${T1wImage}_acpc_dc \
  --method=smooth
  --fillmask=${T1wFolder}/ArteryDetection/${Arg_basename}_arterymaskdil \
  --out=${T1wFolder}/${T1wImage}_acpc_dc_arteryfill
  ${RUN} $HCPPIPEDIR_PreFS/FixNegVal.sh \
  --in=${T1wFolder}/${T2wImage}_acpc_dc \
  --method=smooth
  --fillmask=${T1wFolder}/ArteryDetection/${Arg_basename}_arterymaskdil \
  --out=${T1wFolder}/${T2wImage}_acpc_dc_arteryfill

  # set filled images as bias-field estimation input
  Arg_T1imest=${T1wFolder}/${T1wImage}_acpc_dc_arteryfill
  Arg_T2imest=${T1wFolder}/${T2wImage}_acpc_dc_arteryfill
else
  Arg_T1imest=""
  Arg_T2imest=""
fi

# clean up initial bias corrected images
if [[ $InitBiasCorr = "TRUE" ]] ; then
  ${RUN} ${FSLDIR}/bin/imrm ${T1wFolder}/${T1wImage}_restore ${T1wFolder}/${T1wImage}_restore_acpc ${T1wFolder}/${T1wImage}_restore_acpc_brain ${T1wFolder}/${T1wImage}_restore_acpc_brain_mask ${T1wFolder}/${T1wImage}_restore_acpc_dc ${T1wFolder}/${T1wImage}_restore_acpc_dc_brain
  ${RUN} ${FSLDIR}/bin/imrm ${T2wFolder}/${T2wImage}_restore ${T2wFolder}/${T2wImage}_restore_acpc ${T2wFolder}/${T2wImage}_restore_acpc_brain ${T2wFolder}/${T2wImage}_restore_acpc_brain_mask ${T1wFolder}/${T2wImage}_restore_acpc_dc ${T1wFolder}/${T2wImage}_restore_acpc_dc_brain
fi

# set bias field smoothing kernel sigma if provided
[[ -n ${BiasFieldSmoothingSigma} ]] && BiasFieldSmoothingSigma="--bfsigma=${BiasFieldSmoothingSigma}"

# estimate bias field either using 'sqrt(T1w*T2w)' or 'RobustBiasCorr'
if [[ -n $T2wInputImages ]] && [[ $BiasCorr = "sqrtT1wbyT2w" ]]; then

  log_Msg "mkdir -p ${T1wFolder}/BiasFieldCorrection_sqrtT1wXT1w"
  mkdir -p ${T1wFolder}/BiasFieldCorrection_sqrtT1wXT1w

  ${RUN} ${HCPPIPEDIR_PreFS}/BiasFieldCorrection_sqrtT1wXT1w.sh \
      --workingdir=${T1wFolder}/BiasFieldCorrection_sqrtT1wXT1w \
      --T1im=${T1wFolder}/${T1wImage}_acpc_dc \
      --T1brain=${T1wFolder}/${T1wImage}_acpc_dc_brain \
      --T2im=${T1wFolder}/${T2wImage}_acpc_dc \
      --T1imest=$Arg_T1imest \
      --T2imest=$Arg_T2imest \
      --obias=${T1wFolder}/BiasField_acpc_dc \
      --oT1im=${T1wFolder}/${T1wImage}_acpc_dc_restore \
      --oT1brain=${T1wFolder}/${T1wImage}_acpc_dc_restore_brain \
      --oT2im=${T1wFolder}/${T2wImage}_acpc_dc_restore \
      --oT2brain=${T1wFolder}/${T2wImage}_acpc_dc_restore_brain \
      --fixnegvalmethod=${FixNegValMethod} \
      ${BiasFieldSmoothingSigma}

else

  log_Msg "mkdir -p ${T1wFolder}/BiasFieldCorrection_FAST"
  mkdir -p ${T1wFolder}/BiasFieldCorrection_FAST

  # set context dependent arguments
  ExtraArguments=""
  if [[ -n $T2wInputImages ]] ; then
    ExtraArguments="--T2im=${T1wFolder}/${T2wImage}_acpc_dc --T2imest=$Arg_T2imest --oT2im=${T1wFolder}/${T2wImage}_acpc_dc_restore --oT2brain=${T1wFolder}/${T2wImage}_acpc_dc_restore_brain"
  fi

  # estimate the bias field using a robust wrapper around FAST
  ${RUN} ${HCPPIPEDIR_PreFS}/BiasFieldCorrection_fast.sh \
      --workingdir=${T1wFolder}/BiasFieldCorrection_FAST \
      --T1im=${T1wFolder}/${T1wImage}_acpc_dc \
      --T1imest=$Arg_T1imest \
      --T1brain=${T1wFolder}/${T1wImage}_acpc_dc_brain \
      --obias=${T1wFolder}/BiasField_acpc_dc \
      --oT1im=${T1wFolder}/${T1wImage}_acpc_dc_restore \
      --oT1brain=${T1wFolder}/${T1wImage}_acpc_dc_restore_brain \
      --fastmethod="ROBUST" \
      --fixnegvalmethod=${FixNegValMethod} \
      ${BiasFieldSmoothingSigma} \
      ${ExtraArguments}

fi

# ------------------------------------------------------------------------------
#  Atlas Registration to MNI152: FLIRT + FNIRT
#  Also applies registration to T1w and T2w images
# ------------------------------------------------------------------------------

log_Msg "Performing Atlas Registration to MNI152 (FLIRT and FNIRT)"

# set context dependent arguments
if [ -n "$T2wInputImages" ] ; then
  Arg_t2=${T1wFolder}/${T2wImage}_acpc_dc
  Arg_t2rest=${T1wFolder}/${T2wImage}_acpc_dc_restore
  Arg_t2restbrain=${T1wFolder}/${T2wImage}_acpc_dc_restore_brain
  Arg_ot2=${AtlasSpaceFolder}/${T2wImage}
  Arg_ot2rest=${AtlasSpaceFolder}/${T2wImage}_restore
  Arg_ot2restbrain=${AtlasSpaceFolder}/${T2wImage}_restore_brain
else
  Arg_t2=""; Arg_t2rest=""; Arg_t2restbrain=""; Arg_ot2=""; Arg_ot2rest=""; Arg_ot2restbrain=""
fi

# mask arteries (useful for 7T T1w images) before registration or not
if [[ $MaskArtery = "TRUE" ]] ; then

  # remove the old RobustSegmentation folder
  rm -rf ${T1wFolder}/RobustSegmentation

  # now that the bias field is corrected, run fast once more to segment the
  # structural for the last time. The robust WM mask will be used to ignore WM in
  # the artery detection.
  ${RUN} $HCPPIPEDIR_PreFS/RobustSegmentation.sh \
  --workingdir=${T1wFolder}/RobustSegmentation \
  --t1brain=${T1wFolder}/${T1wImage}_acpc_dc_restore_brain \
  --t2brain=$Arg_t2restbrain \
  --runfast="TRUE" \
  --fwhm="INF" \
  --basename=${T1wImage}_acpc_dc_restore_brain

  # detect arteries based on intensity
  ${RUN} $HCPPIPEDIR_PreFS/ArteryDetection.sh \
  --workingdir=${T1wFolder}/ArteryDetection \
  --t1=${T1wFolder}/${T1wImage}_acpc_dc_restore \
  --t1brain=${T1wFolder}/${T1wImage}_acpc_dc_restore_brain \
  --exclmask=${T1wFolder}/RobustSegmentation/${T1wImage}_acpc_dc_restore_brain_WM \
  --basename=${T1wImage}_acpc_dc_restore

  # define the artery masks
  ArteryMaskInv=${T1wFolder}/ArteryDetection/${T1wImage}_acpc_dc_restore_arterymask_inv
  ArteryMaskDilInv=${T1wFolder}/ArteryDetection/${T1wImage}_acpc_dc_restore_arterymaskdil_inv
  #fslmaths $ArteryMaskDilInv -mas ${T1wFolder}/${T1wImage}_acpc_brain_mask ${T1wFolder}/${T1wImage}_acpc_brain_arterybrainmask_inv
  Arg_inmask=$ArteryMaskDilInv
else
  Arg_inmask=""
fi

# linear and non-linear registration to MNI template
${RUN} ${HCPPIPEDIR_PreFS}/AtlasRegistrationToMNI152_FLIRTandFNIRT.sh \
    --workingdir=${AtlasSpaceFolder} \
    --t1=${T1wFolder}/${T1wImage}_acpc_dc \
    --t1rest=${T1wFolder}/${T1wImage}_acpc_dc_restore \
    --t1restbrain=${T1wFolder}/${T1wImage}_acpc_dc_restore_brain \
    --t2=$Arg_t2 \
    --t2rest=$Arg_t2rest\
    --t2restbrain=$Arg_t2restbrain \
    --inmask=$Arg_inmask \
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
    --ot2=$Arg_ot2 \
    --ot2rest=$Arg_ot2rest \
    --ot2restbrain=$Arg_ot2restbrain \
    --fnirtconfig=${FNIRTConfig} \
    --fixnegvalmethod=${FixNegValMethod}


# ------------------------------------------------------------------------------
#  All done
# ------------------------------------------------------------------------------

log_Msg "Completed"
