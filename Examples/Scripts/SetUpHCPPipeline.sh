#!/bin/bash 

echo "This script must be SOURCED to correctly setup the environment prior to running any of the other HCP scripts contained here"

# Set up FSL (if not already done so in the running environment)
# Uncomment the following 2 lines (remove the leading #) and correct the FSLDIR setting for your setup
#export FSLDIR=/usr/share/fsl/5.0
#. ${FSLDIR}/etc/fslconf/fsl.sh

# Let FreeSurfer know what version of FSL to use
# FreeSurfer uses FSL_DIR instead of FSLDIR to determine the FSL version
export FSL_DIR="${FSLDIR}"

# Set up FreeSurfer (if not already done so in the running environment)
# Uncomment the following 2 lines (remove the leading #) and correct the FREESURFER_HOME setting for your setup
#export FREESURFER_HOME=/usr/local/bin/freesurfer
#source ${FREESURFER_HOME}/SetUpFreeSurfer.sh > /dev/null 2>&1

# Set up specific environment variables for the HCP Pipeline
export HCPPIPEDIR=${HOME}/projects/Pipelines
export CARET7DIR=${HOME}/tools/workbench/bin_rh_linux64

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

