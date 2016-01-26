#!/bin/bash

echo "This script must be SOURCED to correctly setup the environment prior to running any of the other HCP scripts contained here"
echo "This script is set up to run from FMRIB's Jalapeno"

# Set up FSL (if not already done so in the running environment)
# Uncomment the following 2 lines (remove the leading #) and correct the FSLDIR setting for your setup
#export FSLDIR=/usr/share/fsl/5.0
#. ${FSLDIR}/etc/fslconf/fsl.sh

# Let FreeSurfer know what version of FSL to use
# FreeSurfer uses FSL_DIR instead of FSLDIR to determine the FSL version
export FSL_DIR="${FSLDIR}"

# ensure that the HCP specific version of FreeSurfer is being used
module load freesurfer-5.3.0-HCP > /dev/null 2>&1 # (don't say a peep)
# you can revert back using: module swap freesurfer-5.3.0-HCP freesurfer > /dev/null 2>&1 # (don't say a peep)

# Set up FreeSurfer (if not already done so in the running environment)
# Uncomment the following 2 lines (remove the leading #) and correct the FREESURFER_HOME setting for your setup
#export FREESURFER_HOME=/usr/local/bin/freesurfer
. ${FREESURFER_HOME}/SetUpFreeSurfer.sh > /dev/null 2>&1

# Set up specific environment variables for the HCP Pipeline
#export HCPPIPEDIR=${HOME}/projects/Pipelines
if [[ -z $HCPPIPEDIR ]] ; then
  # retrieve the Example/Scripts folder
  # this script will be sourced, so BASH_SOURCE[0] will be empty
  # therefore retrieve the directory of the caller script instead
  ExampleScriptsFolder=$( cd "$( dirname "${BASH_SOURCE[1]}" )" && pwd )
  # define the general Pipelines folder
  export HCPPIPEDIR=$(cd "${ExampleScriptsFolder}/../../" && pwd)
fi

#export CARET7DIR=${HOME}/tools/workbench/bin_rh_linux64
export CARET7DIR=/opt/fmrib/bin # When on Jalapeno: source it from the general bin folder to allow wb_command to find other libraries and packages

export HCPPIPEDIR_Templates=${HCPPIPEDIR}/global/templates
export HCPPIPEDIR_Bin=${HCPPIPEDIR}/global/binaries
export HCPPIPEDIR_Config=${HCPPIPEDIR}/global/config

export HCPPIPEDIR_PreFS=${HCPPIPEDIR}/PreFreeSurfer/scripts
export HCPPIPEDIR_FS=${HCPPIPEDIR}/FreeSurfer/scripts
export HCPPIPEDIR_PostFS=${HCPPIPEDIR}/PostFreeSurfer/scripts
export HCPPIPEDIR_fMRISurf=${HCPPIPEDIR}/fMRISurface/scripts
export HCPPIPEDIR_fMRIVol=${HCPPIPEDIR}/fMRIVolume/scripts
export HCPPIPEDIR_tfMRI=${HCPPIPEDIR}/tfMRI/scripts
export HCPPIPEDIR_dMRI=${HCPPIPEDIR}/DiffusionPreprocessing/scripts
export HCPPIPEDIR_dMRITract=${HCPPIPEDIR}/DiffusionTractography/scripts
export HCPPIPEDIR_Global=${HCPPIPEDIR}/global/scripts
export HCPPIPEDIR_tfMRIAnalysis=${HCPPIPEDIR}/TaskfMRIAnalysis/scripts
export MSMBin=${HCPPIPEDIR}/MSMBinaries

# FMRIB Jalapeno specific settings
# no further job branching beyond fsl_sub is allowed on the Jalapeno cluster
export NSLOTS=1
export OMP_NUM_THREADS=1
