#!/bin/bash
set -eu
# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

script_name=$(basename "${0}")

show_usage() {
    cat <<EOF

${script_name}: Sub-script of GenericHippocampusfMRISurfaceProcessingPipeline.sh

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
source "${HCPPIPEDIR}/global/scripts/opts.shlib"               # Command line option functions

opts_ShowVersionIfRequested "$@"

if opts_CheckForHelpRequest "$@"; then
    show_usage
    exit 0
fi

# ------------------------------------------------------------------------------
#  Verify required environment variables are set and log value
# ------------------------------------------------------------------------------

log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var CARET7DIR

# ------------------------------------------------------------------------------
#  Start work
# ------------------------------------------------------------------------------

log_Msg "START"

ResultsFolder="$1"
Subject="$2"
NameOffMRI="$3"
ProcString="$4"
SmoothingFWHM="$5"
Meshes="$6"

for Mesh in ${Meshes}; do

    wb_command -cifti-create-dense-timeseries "${ResultsFolder}/${NameOffMRI}_AtlasHipp${ProcString}.${Mesh}.dtseries.nii" \
        -metric HIPPOCAMPUS_LEFT "${ResultsFolder}/${Subject}.L.hipp_fMRI_s${SmoothingFWHM}.${Mesh}.func.gii" \
        -metric HIPPOCAMPUS_RIGHT "${ResultsFolder}/${Subject}.R.hipp_fMRI_s${SmoothingFWHM}.${Mesh}.func.gii" \
        -metric HIPPOCAMPUS_DENTATE_LEFT "${ResultsFolder}/${Subject}.L.dentate_fMRI_s${SmoothingFWHM}.${Mesh}.func.gii" \
        -metric HIPPOCAMPUS_DENTATE_RIGHT "${ResultsFolder}/${Subject}.R.dentate_fMRI_s${SmoothingFWHM}.${Mesh}.func.gii"

    log_Msg "Generated fMRI time series CIFTI file: ${ResultsFolder}/${NameOffMRI}_AtlasHipp${ProcString}.${Mesh}.dtseries.nii"

    wb_command -cifti-create-dense-scalar "${ResultsFolder}/${NameOffMRI}_AtlasHipp${ProcString}_vn.${Mesh}.dscalar.nii" \
        -metric HIPPOCAMPUS_LEFT "${ResultsFolder}/${Subject}.L.hipp_fMRI_vn.${Mesh}.func.gii" \
        -metric HIPPOCAMPUS_RIGHT "${ResultsFolder}/${Subject}.R.hipp_fMRI_vn.${Mesh}.func.gii" \
        -metric HIPPOCAMPUS_DENTATE_LEFT "${ResultsFolder}/${Subject}.L.dentate_fMRI_vn.${Mesh}.func.gii" \
        -metric HIPPOCAMPUS_DENTATE_RIGHT "${ResultsFolder}/${Subject}.R.dentate_fMRI_vn.${Mesh}.func.gii"

    log_Msg "Generated VN CIFTI file: ${ResultsFolder}/${NameOffMRI}_AtlasHipp${ProcString}_vn.${Mesh}.dscalar.nii"

done

log_Msg "END"