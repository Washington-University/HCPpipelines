#!/bin/bash 

echo "This script must be SOURCED to correctly setup the environment prior to running any of the other HCP scripts contained here"

# Set up FSL (if not already done so in the running environment)
#FSLDIR=/usr/share/fsl/5.0
#. ${FSLDIR}/etc/fslconf/fsl.sh

# Set up FreeSurfer (if not already done so in the running environment)
#FREESURFER_HOME=/usr/local/bin/freesurfer
#. ${FREESURFER_HOME}/SetUpFreeSurfer.sh > /dev/null 2>&1

# Set up specific environment variables for the HCP Pipeline
export HCPPIPEDIR=${HOME}/projects/Pipelines
export CARET7DIR=${HOME}/workbench/bin_linux64

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

## WASHU config - as understood by MJ - (different structure from the GIT repository)
## Also look at: /nrgpackages/scripts/tools_setup.sh

# Set up FSL (if not already done so in the running environment)
#FSLDIR=/nrgpackages/scripts
#. ${FSLDIR}/fsl5_setup.sh

# Set up FreeSurfer (if not already done so in the running environment)
#FREESURFER_HOME=/nrgpackages/tools/freesurfer5
#. ${FREESURFER_HOME}/SetUpFreeSurfer.sh

#NRG_SCRIPTS=/nrgpackages/scripts#. ${NRG_SCRIPTS}/epd-python_setup.sh

#export HCPPIPEDIR=/home/NRG/jwilso01/dev/Pipelines
#export HCPPIPEDIR_PreFS=${HCPPIPEDIR}/PreFreeSurfer/scripts
#export HCPPIPEDIR_FS=/data/intradb/pipeline/catalog/StructuralHCP/resources/scripts
#export HCPPIPEDIR_PostFS=/data/intradb/pipeline/catalog/StructuralHCP/resources/scripts

#export HCPPIPEDIR_FIX=/data/intradb/pipeline/catalog/FIX_HCP/resources/scripts
#export HCPPIPEDIR_Diffusion=/data/intradb/pipeline/catalog/DiffusionHCP/resources/scripts
#export HCPPIPEDIR_Functional=/data/intradb/pipeline/catalog/FunctionalHCP/resources/scripts

#export HCPPIPETOOLS=/nrgpackages/tools/HCP
#export HCPPIPEDIR_Templates=/nrgpackages/atlas/HCP
#export HCPPIPEDIR_Bin=${HCPPIPETOOLS}/bin
#export HCPPIPEDIR_Config=${HCPPIPETOOLS}/conf
#export HCPPIPEDIR_Global=${HCPPIPETOOLS}/scripts_v2

#export CARET7DIR=${HCPPIPEDIR_Bin}/caret7/bin_linux64
## may or may not want the above variables to be setup as above
##    (if so then the HCPPIPEDIR line needs to go before them)
## end of WASHU config


# The following is probably unnecessary on most systems
#PATH=${PATH}:/vols/Data/HCP/pybin/bin/
#PYTHONPATH=/vols/Data/HCP/pybin/lib64/python2.6/site-packages/


#echo "Unsetting SGE_ROOT for testing mode only"
#unset SGE_ROOT

