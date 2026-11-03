#!/bin/bash
set -e

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

# ------------------------------------------------------------------------------
#  Start work
# ------------------------------------------------------------------------------

log_Msg "START"

HippUnfoldFolder="$1"
WorkingDirectory="$2"
Session="$3"
SmoothingFWHM="$4"
Meshes="$5"

Sigma=$(echo "${SmoothingFWHM} / (2 * sqrt(2 * l(2)))" | bc -l)

Structures=(hipp dentate)

for Mesh in ${Meshes}; do
    if [[ "${Mesh}" == "native" ]]; then
        MeshFolder="Native"
    else
        MeshFolder="${Mesh}"
    fi

    InputfMRI="${WorkingDirectory}/${Session}.${Mesh}.dtseries.nii"
    OutputfMRI="${WorkingDirectory}/${Session}_s${SmoothingFWHM}.${Mesh}.dtseries.nii"

    if [[ "${SmoothingFWHM}" == "0" ]]; then
        cp "${InputfMRI}" "${OutputfMRI}" 
    else
        wb_command -cifti-smoothing "${InputfMRI}" "${Sigma}" 0 COLUMN "${OutputfMRI}" \
            -surface HIPPOCAMPUS_LEFT "${HippUnfoldFolder}/${MeshFolder}/${Session}.L.hipp_midthickness.${Mesh}.surf.gii" \
            -surface HIPPOCAMPUS_RIGHT "${HippUnfoldFolder}/${MeshFolder}/${Session}.R.hipp_midthickness.${Mesh}.surf.gii" \
            -surface HIPPOCAMPUS_DENTATE_LEFT "${HippUnfoldFolder}/${MeshFolder}/${Session}.L.dentate_midthickness.${Mesh}.surf.gii" \
            -surface HIPPOCAMPUS_DENTATE_RIGHT "${HippUnfoldFolder}/${MeshFolder}/${Session}.R.dentate_midthickness.${Mesh}.surf.gii"
    fi

    log_Msg "Created ${OutputfMRI}"
done


log_Msg "HippocampalSmoothing complete"