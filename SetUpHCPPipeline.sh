echo "This script must be SOURCED to correctly setup the environment prior to running any of the other HCP scripts contained here"

# Set up FSL (if not already done so in the running environment)
FSLDIR=/usr/local/fsl
. ${FSLDIR}/etc/fslconf/fsl.sh

# Set up FreeSurfer (if not already done so in the running environment)
FREESURFER_HOME=/usr/local/freesurfer
. ${FREESURFER_HOME}/SetUpFreeSurfer.sh

# Set up specific environment variables for the HCP Pipeline
export HCPPIPEDIR=/vols/Data/HCP/GIT/Pipelines
# All the following variables can be left as is if the structure of the GIT repository is maintained
export CARET5DIR=${HCPPIPEDIR}/global/binaries/caret5
export CARET7DIR=${HCPPIPEDIR}/global/binaries/caret7/bin_linux64

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
export HCPPIPEDIR_Global=${HCPPIPEDIR}/global/scripts


## WASHU config - as understood by MJ - (different structure from the GIT repository)
#export HCPPIPEDIR=/data/intradb/pipeline/catalog/FunctionalHCP/resources/scripts/
#export HCPPIPEDIR_Templates=/nrgpackages/atlas/HCP/
#export HCPPIPEDIR_Bin=/nrgpackages/tools/HCP/bin/
#export HCPPIPEDIR_Config=/nrgpackages/tools/HCP/conf
#export HCPPIPEDIR_Global=/nrgpackages/tools/HCP/scripts/
## may or may not want the above variables from CARET5DIR to HCPPIPEDIR_Global to be setup as above or not
##    (if so then the HCPPIPEDIR line needs to go before them)
## end of WASHU config


# The following is probably unnecessary on most systems
#PATH=${PATH}:/vols/Data/HCP/pybin/bin/
#PYTHONPATH=/vols/Data/HCP/pybin/lib64/python2.6/site-packages/


#echo "Unsetting SGE_ROOT for testing mode only"
#unset SGE_ROOT

