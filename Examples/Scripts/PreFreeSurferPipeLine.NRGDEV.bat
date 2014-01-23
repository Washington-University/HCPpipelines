#!/bin/bash 
#
# Copyright Notice:
#
#   Copyright (C) 2013-2014 Washington University in St. Louis
#   Author(s): Matthew F. Glasser, Timothy B. Brown
#
# Product:
#
#   Human Connectome Project (HCP) Pipeline Tools
#   http://www.humanconnectome.org
#
# Description:
# 
#   This script, PreFreeSurferPipeLine.NRGDEV.bat, is an example of a wrapper 
#   for invoking the PreFreeSurferPipeline.sh script to execute the first
#   of 3 sub-parts of the Structural Preprocessing phase of the HCP Minimal
#   Preprocessing Pipelines. It is sometimes referred to as a 
#   "PreFreeSurferPipeline wrapper script".
#
#   This script:
#
#   1. Sets up variables to determine where input files will be found
#      and what subjects to process
#   2. Sets up the environment necessary for running the 
#      PreFreeSurferPipeline.sh script (sets environment variables) 
#   3. Sets up variables that determine where various input files are to 
#      be found and what options to use in invoking PreFreeSurferPipeline.sh
#   4. Invokes PreFreeSurferPipeline.sh with the configured variables passed
#      as command line parameters. This invocation takes the form of 
#      submitting the PreFreeSurferPipeline.sh script using the fsl_sub 
#      command.  fsl_sub is part of FSL (see below) and is used to submit
#      the job to a queuing system (e.g. Sun/Oracle Grid Engine or Torque).
#
# Prerequisites:
#
#   Environment Variables:
#
#     HCPPIPEDIR
#       The "home" directory for the version of the HCP Pipeline Tools product
#       being used. E.g. /nrgpackages/tools.release/hcp-pipeline-tools-v3.0
#
#   Installed Software:
#
#     FSL - FMRIB's Software Library (http://www.fmrib.ox.ac.uk/fsl)
#           Version 5.0.6 or greater
# 
#   Image Files:
#
#     At least one T1 weighted image and one T2 weighted image are required
#     for the PreFreeSurferPipeline.sh script to work. Thus they are required
#     for this script to work also.
#
# Notes:
#
#   * The fsl_sub tool that is provided as part of FSL submits the job 
#     to a cluster using the Sun/Oracle Grid Engine. If it cannot find 
#     a local cluster to which to submit the job, it simply runs the 
#     submitted command directly.
#
#   * To submit the job using Torque, a modified version of fsl_sub must
#     be used.  
#
#   TODO: Verify that the above statement about submitting the job via Torque
#         is true.  Determine what modifications are necessary to the fsl_sub
#         tool.
#
# Usage:
#
#   This script has no command line options/arguments. It is intended to 
#   simply be executed with a command like:
#
#   $ ./PreFreeSurferPipeLine.NRGDEV.bat
#
#   To alter the list of subjects, the folder/directory in which the subject
#   files are to be found, or the location of the script which sets up the
#   necessary environment variables, edit this script directly.
#  

# -----------------------------------------------------------------------------
#  Load Function Libraries
# -----------------------------------------------------------------------------

source $HCPPIPEDIR/global/scripts/log.shlib   # Logging related functions

# -----------------------------------------------------------------------------
#  Establish tool name for logging
# -----------------------------------------------------------------------------
 
log_SetToolName "PreFreeSurferPipeLine.NRGDEV.bat"

# -----------------------------------------------------------------------------
#  Setup Environment
# -----------------------------------------------------------------------------

# Establish the folder/directory in which all subject folders 
# will be found.

#StudyFolder="/media/myelin/brainmappers/Connectome_Project/TestStudyFolder" 
StudyFolder="/home/NRG/tbrown01/projects/Pipelines/Examples"

# Establish the list of subject IDs to process. SubjList is a space delimited
# list of subject IDs. This script assumes that for each subject ID, there will
# be a directory named with the subject ID in the StudyFolder.
Subjlist="792564"

# Establish the location of the "Environment Script". The "Environment Script"
# sets up all the environment variables needed to run the 
# PreFreeSurferPipeline.sh script.

#EnvironmentScript=\
#"/media/2TBB/Connectome_Project/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" 
EnvironmentScript=\
"/home/NRG/tbrown01/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.NRGDEV.sh"

# Source the environment script to set up pipeline environment variables and 
# software
log_Msg "Sourcing environment script: ${EnvironmentScript}"
. ${EnvironmentScript}

# If the SGE_ROOT variable is not null, then we use that as an indication
# that the job (running the PreFreeSurferPipeline.sh script) will be 
# submitted to a cluster via a job control system like SGE. 
#
# In that case (SGE_ROOT variable is not null), we set the -q option for the
# fsl_sub command to indicate that the job will take more than 4 hours and 
# less than 24 hours.
#
# See the usage information for fsl_sub to learn about other queue options 
# (e.g. veryshort.q, short.q, etc.)
if [ -n "$SGE_ROOT" ]; then
    QUEUE="-q long.q"
fi

# If the PRINTCOM variable is set to "echo", then the --printcom=echo option 
# is passed to the invocation of the PreFreeSurferPipeline.sh script. The 
# --printcom=echo option causes PreFreeSurferPipeline.sh to simply echo the
# significant commands that it would run instead of actually executing those
# commands. This can be useful for understanding and debugging purposes.
PRINTCOM=""
#PRINTCOM="echo"

# -----------------------------------------------------------------------------
#  Input files for PreFreeSurferPipeline.sh
# -----------------------------------------------------------------------------

# The PreFreeSurferPipeline.sh script does not assume any particular directory
# structure for locating the input files. Instead, paths to all input files are
# fully specified by various command line options passed to the 
# PreFreeSurferPipeline.sh script.
#
# _This_ wrapper script assumes that input files to be specified to the 
# PreFreeSurferPipeline.sh will be found by following a particular directory
# and file naming convention.
#
# It assumes the following HCP data naming convention under the
# ${StudyFolder}/${Subject} directory:
#
#   The form of the file names for the T1-weighted image files is assumed
#   to be:
#
#     unprocessed/3T/T1w_MPR1/${Subject}_3T_T1w_MPR<scanNo>.nii.gz
#
#   where <scanNo> is the sequence number for the T1w image (e.g. 1, 2, 3,...)
#
#   The form of the file names for the T2-weighted image files is assumed
#   to be:
#
#     unprocessed/3T/T2w_SPC1/${Subject}_3T_T2w_SPC<scanNo>.nii.gz
#
#   where <scanNo> is the sequence number for the T2w image (e.g. 1, 2, 3,...)
#
# In each image directory, whether it be for a T1w or T2w scan, we expect to
# find supplemental files that provide additional information about the scan.
# Two of these supplemental files give us information about magnetic field
# inhomogeneity during the scan. An undistorted MRI image requires that the
# magnetic field inside the scanner be homogeneous (except for the gradients
# necessary for spatial encoding.) However, the magnetic field in a scanner
# will not actually be homogeneous. Some inhomogeneity is introduced by
# simply have an object (e.g. the head) in the magnetic field. Corrections
# for this inhomogeneity are done using two fieldmap files in (NIFTI) image
# file format.
#
# One of these fieldmap files (the Magnitude fieldmap file) contains an image
# of the brain that can be used for registration to other images and for
# definition of brain and non-brain tissues.
#
# The form of the name of the Magnitude fieldmap file is assumed to be:
#
#   unprocessed/3T/T1w_MPR1/${Subject}_3T_FieldMap_Magnitude.nii.gz
#


# TODO:

#   unprocessed/3T/T1w_MPR1/${Subject}_3T_FieldMap_Phase.nii.gz

# -----------------------------------------------------------------------------
#  Other configurable settings
# -----------------------------------------------------------------------------

# Change Scan Settings: FieldMap Delta TE, Sample Spacings, and $UnwarpDir to
# match your images. These are set to match the HCP Protocol by default.
#
# If using gradient distortion correction, use the coefficents from your 
# scanner. The HCP gradient distortion coefficents are only available through
# Siemens. Gradient distortion in standard scanners like the Trio is much less
# than for the HCP Skyra.

# -----------------------------------------------------------------------------
#  Do primary work
# -----------------------------------------------------------------------------

for Subject in $Subjlist ; do
  log_Msg "Processing subject:" $Subject
  
  #Input Images

  # Detect Number of T1w Images
  numT1ws=`ls ${StudyFolder}/${Subject}/unprocessed/3T | grep T1w_MPR | wc -l`
  log_Msg "Detected number of T1w images: "${numT1ws}

  # Build @ separated list of T1w images to process
  T1wInputImages=""
  i=1
  while [ $i -le $numT1ws ] ; do
    T1wInputImages=`echo "${T1wInputImages}${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR${i}/${Subject}_3T_T1w_MPR${i}.nii.gz@"`
    i=$(($i+1))
  done

  # Detect Number of T2w Images
  numT2ws=`ls ${StudyFolder}/${Subject}/unprocessed/3T | grep T2w_SPC | wc -l`
  log_Msg "Detected number of T2w images: "${numT2ws}

  # Build @ separated list of T2w images to process
  T2wInputImages=""
  i=1
  while [ $i -le $numT2ws ] ; do
    T2wInputImages=`echo "${T2wInputImages}${StudyFolder}/${Subject}/unprocessed/3T/T2w_SPC${i}/${Subject}_3T_T2w_SPC${i}.nii.gz@"`
    i=$(($i+1))
  done
  
  
  MagnitudeInputName="${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_FieldMap_Magnitude.nii.gz" #Expects 4D magitude volume with two 3D timepoints or "NONE" if not used
  PhaseInputName="${StudyFolder}/${Subject}/unprocessed/3T/T1w_MPR1/${Subject}_3T_FieldMap_Phase.nii.gz" #Expects 3D phase difference volume or "NONE" if not used

  SpinEchoPhaseEncodeNegative="NONE" #For the spin echo field map volume with a negative phase encoding direction (LR in HCP data), set to NONE if using regular FIELDMAP
  SpinEchoPhaseEncodePositive="NONE" #For the spin echo field map volume with a positive phase encoding direction (RL in HCP data), set to NONE if using regular FIELDMAP

  #Templates
  T1wTemplate="${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm.nii.gz" #MNI0.7mm template
  T1wTemplateBrain="${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm_brain.nii.gz" #Brain extracted MNI0.7mm template
  T1wTemplate2mm="${HCPPIPEDIR_Templates}/MNI152_T1_2mm.nii.gz" #MNI2mm template
  T2wTemplate="${HCPPIPEDIR_Templates}/MNI152_T2_0.7mm.nii.gz" #MNI0.7mm T2wTemplate
  T2wTemplateBrain="${HCPPIPEDIR_Templates}/MNI152_T2_0.7mm_brain.nii.gz" #Brain extracted MNI0.7mm T2wTemplate
  T2wTemplate2mm="${HCPPIPEDIR_Templates}/MNI152_T2_2mm.nii.gz" #MNI2mm T2wTemplate
  TemplateMask="${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm_brain_mask.nii.gz" #Brain mask MNI0.7mm template
  Template2mmMask="${HCPPIPEDIR_Templates}/MNI152_T1_2mm_brain_mask_dil.nii.gz" #MNI2mm template

  #Scan Settings
  TE="2.46" #delta TE in ms for field map or "NONE" if not used
  DwellTime="NONE" #Echo Spacing or Dwelltime of Spin Echo Field Map or "NONE" if not used
  SEUnwarpDir="NONE" #x or y (minus or not does not matter) "NONE" if not used 
  T1wSampleSpacing="0.0000074" #DICOM field (0019,1018) in s or "NONE" if not used
  T2wSampleSpacing="0.0000021" #DICOM field (0019,1018) in s or "NONE" if not used
  UnwarpDir="z" #z appears to be best or "NONE" if not used
  GradientDistortionCoeffs="${HCPPIPEDIR_Config}/coeff_SC72C_Skyra.grad" #Location of Coeffs file or "NONE" to skip

  #Config Settings
  BrainSize="150" #BrainSize in mm, 150 for humans
  FNIRTConfig="${HCPPIPEDIR_Config}/T1_2_MNI152_2mm.cnf" #FNIRT 2mm T1w Config
  AvgrdcSTRING="FIELDMAP" #Averaging and readout distortion correction methods: "NONE" = average any repeats with no readout correction "FIELDMAP" = average any repeats and use field map for readout correction "TOPUP" = average and distortion correct at the same time with topup/applytopup only works for 2 images currently
  TopupConfig="NONE" #Config for topup or "NONE" if not used

  ${FSLDIR}/bin/fsl_sub ${QUEUE} \
     ${HCPPIPEDIR}/PreFreeSurfer/PreFreeSurferPipeline.sh \
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
      --echodiff="$TE" \
      --SEPhaseNeg="$SpinEchoPhaseEncodeNegative" \
      --SEPhasePos="$SpinEchoPhaseEncodePositive" \
      --echospacing="$DwellTime" \
      --seunwarpdir="$SEUnwarpDir" \
      --t1samplespacing="$T1wSampleSpacing" \
      --t2samplespacing="$T2wSampleSpacing" \
      --unwarpdir="$UnwarpDir" \
      --gdcoeffs="$GradientDistortionCoeffs" \
      --avgrdcmethod="$AvgrdcSTRING" \
      --topupconfig="$TopupConfig" \
      --printcom=$PRINTCOM
      
  # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...

  echo "set -- --path=${StudyFolder} \
      --subject=${Subject} \
      --t1=${T1wInputImages} \
      --t2=${T2wInputImages} \
      --t1template=${T1wTemplate} \
      --t1templatebrain=${T1wTemplateBrain} \
      --t1template2mm=${T1wTemplate2mm} \
      --t2template=${T2wTemplate} \
      --t2templatebrain=${T2wTemplateBrain} \
      --t2template2mm=${T2wTemplate2mm} \
      --templatemask=${TemplateMask} \
      --template2mmmask=${Template2mmMask} \
      --brainsize=${BrainSize} \
      --fnirtconfig=${FNIRTConfig} \
      --fmapmag=${MagnitudeInputName} \
      --fmapphase=${PhaseInputName} \
      --echodiff=${TE} \
      --SEPhaseNeg=${SpinEchoPhaseEncodeNegative} \
      --SEPhasePos=${SpinEchoPhaseEncodePositive} \
      --echospacing=${DwellTime} \
      --seunwarpdir=${SEUnwarpDir} \     
      --t1samplespacing=${T1wSampleSpacing} \
      --t2samplespacing=${T2wSampleSpacing} \
      --unwarpdir=${UnwarpDir} \
      --gdcoeffs=${GradientDistortionCoeffs} \
      --avgrdcmethod=${AvgrdcSTRING} \
      --topupconfig=${TopupConfig} \
      --printcom=${PRINTCOM}"

  echo ". ${EnvironmentScript}"

done

log_Msg "Completed"

