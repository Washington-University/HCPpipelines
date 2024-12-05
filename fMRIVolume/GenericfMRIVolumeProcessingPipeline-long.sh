#!/bin/bash

# Requirements for this script
# installed versions of: 
# environment: HCPPIPEDIR, FSLDIR

set -eu

pipedirguessed=0

if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@" 
source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "${HCPPIPEDIR}/global/scripts/processingmodecheck.shlib"  # Check processing mode requirements
source "${HCPPIPEDIR}/global/scripts/fsl_version.shlib"          # Functions for getting FSL version

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------
opts_SetScriptDescription "Run longitudinal fMRIVolume processing"

opts_AddMandatory '--studyfolder' 'Path' 'path' "folder containing all sessions" "--path"

opts_AddMandatory '--session-cross' 'SessionCross' 'Cross-sectional session ID'

opts_AddMandatory '--fmriname' 'NameOffMRI' 'string' 'name (prefix) to use for the output'

opts_AddMandatory '--longitudinal-session' 'SessionLong' 'folder' "Specifies longitudinal session name"

opts_AddOptional '--echoTE' 'echoTE' '@ delimited list of numbers' "TE for each echo (unused for single echo)" "0"

opts_ParseArguments "$@"

if ((pipedirguessed)); then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"; 
fi

opts_ShowValues
script_name=$(basename "$0")
show_processing_mode_info() {
    cat <<EOF

Longitudinal mode additional information
----------------------------------------

TODO: add information

EOF

}

"$HCPPIPEDIR"/show_version

# ------------------------------------------------------------------------------
#  Verify required environment variables are set and log value
# ------------------------------------------------------------------------------

log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FSLDIR
log_Check_Env_Var FREESURFER_HOME
log_Check_Env_Var HCPPIPEDIR_Global

HCPPIPEDIR_fMRIVol=${HCPPIPEDIR}/fMRIVolume/scripts

# ------------------------------------------------------------------------------
#  Check for incompatible FSL version - abort if incompatible
# ------------------------------------------------------------------------------
fsl_minimum_required_version_check "6.0.1" "FSL version 6.0.0 is unsupported. Please upgrade to at least version 6.0.1"

# Naming Conventions
T1wImage="T1w_acpc_dc"
T1wRestoreImage="T1w_acpc_dc_restore"
T1wRestoreImageBrain="T1w_acpc_dc_restore_brain"
T1wFolder="T1w" #Location of T1w images
AtlasSpaceFolder="MNINonLinear"
ResultsFolder="Results"
BiasField="BiasField_acpc_dc"
BiasFieldMNI="BiasField"
T1wAtlasName="T1w_restore"
MovementRegressor="Movement_Regressors" #No extension, .txt appended
MotionMatrixFolder="MotionMatrices"
MotionMatrixPrefix="MAT_"
FieldMapOutputName="FieldMap"
MagnitudeOutputName="Magnitude"
MagnitudeBrainOutputName="Magnitude_brain"
ScoutName="Scout"
OrigScoutName="${ScoutName}_orig"
OrigTCSName="${NameOffMRI}_orig"
FreeSurferBrainMask="brainmask_fs"
fMRI2strOutputTransform="${NameOffMRI}2str"
RegOutput="Scout2T1w"
AtlasTransform="acpc_dc2standard"
OutputfMRI2StandardTransform="${NameOffMRI}2standard"
Standard2OutputfMRITransform="standard2${NameOffMRI}"
QAImage="T1wMulEPI"
JacobianOut="Jacobian"
SessionFolderCross="$Path"/"$SessionCross"
SessionFolderLong="$Path"/"$SessionLong"
fMRIFolderCross="$Path"/"$SessionCross"/"$NameOffMRI"
fMRIFolderLong="$Path"/"SessionLong"/"NameOffMRI"

T1wFolderCross="$Path"/"$SessionCross"/"$T1wFolder"
AtlasSpaceFolderCross="$Path"/"$SessionCross"/"$AtlasSpaceFolder"
ResultsFolderCross="$AtlasSpaceFolder"/"$ResultsFolder"/"$NameOffMRI"

T1wFolderLong="$Path"/"$SessionLong"/"$T1wFolder"
AtlasSpaceFolderLong="$Path"/"$SessionLong"/"$AtlasSpaceFolder"
ResultsFolderLong="$AtlasSpaceFolderLong"/"$ResultsFolder"/"$NameOffMRI"

#-----------------------------------------------------------------------
# Compliance check
#-----------------------------------------------------------------------

# -- Multi-echo fMRI
echoTE=$(echo ${echoTE} | sed 's/@/ /g')
nEcho=$(echo ${echoTE} | wc -w)

#-----------------------------------------------------------------------
# End compliance check
#-----------------------------------------------------------------------

mkdir -p ${T1wFolderLong}/Results/${NameOffMRI}
if [ ! -e "$fMRIFolderLong" ]; then mkdir "$fMRIFolderLong"; fi
ln -sf "$fMRIFolderCross" "$fMRIFolderLong"

if [[ $nEcho -gt 1 ]] ; then
    log_Msg "$nEcho TE's supplied, running in multi-echo mode"
    NumFrames=$("${FSLDIR}"/bin/fslval "${fMRIFolderCross}/${OrigTCSName}" dim4)
    FramesPerEcho=$((NumFrames / nEcho))
    EchoDirCross="${fMRIFolderCross}/MultiEcho"
    EchoDirLong="${fMRIFolderLong}/MultiEcho"
    mkdir -p "$EchoDirLong"
fi

#Scout reference: done, nothing to do
#Distortion correction: reorientation, nothing to do
#Gradient distortion correction of fMRI: nothing to do
#split echos: nothing to do
#motion correction: nothing to do
#EPI distortion correction and EPI to T1w Registration: 

#output to T1w/xfms/"${NameOffMRI}2str".nii.gz?
#Do we want that placed there? If yes, it needs to be updated with template transform. If no, it shouldn't be there.


