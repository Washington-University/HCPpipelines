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

HippUnfoldFolder="$1"
ResultsFolder="$2"
WorkingDirectory="$3"
Subject="$4"
SmoothingFWHM="$5"
Meshes="$6"

Sigma=$(echo "${SmoothingFWHM} / (2 * sqrt(2 * l(2)))" | bc -l)

Structures=(hipp dentate)

for Mesh in ${Meshes}; do
    for Structure in "${Structures[@]}"; do
        for Hemisphere in L R; do
            wb_command -metric-smoothing "${HippUnfoldFolder}/${Mesh}/${Subject}.${Hemisphere}.${Structure}_midthickness.${Mesh}.surf.gii" "${ResultsFolder}/${Subject}.${Hemisphere}.${Structure}_fMRI.${Mesh}.func.gii" "${Sigma}" "${ResultsFolder}/${Subject}.${Hemisphere}.${Structure}_fMRI_s${SmoothingFWHM}.${Mesh}.func.gii" -roi "${WorkingDirectory}/${Subject}.${Hemisphere}.${Structure}_ones.${Mesh}.func.gii"
        done
    done
done

log_Msg "END"