#!/bin/bash

# --------------------------------------------------------------------------------
# A script for the conversion of 4 structures (L hipp, R hipp, L dentate, R dentate) 
# into a single CIFTI file and deletion of intermediate func.gii file
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
#  Loop that detects func.gii for all 4 structures (L hipp, R hipp, L dentate, R dentate),
#  merges them into CIFTI files, and deletes the func.gii
# ------------------------------------------------------------------------------

log_Msg "START"

ResultsFolder="$1"
WorkingDirectory="$2"
Subject="$3"
NameOffMRI="$4"
ProcString="$5"
Meshes="$6"
doGoodVoxels="$7"
SmoothingFWHM="$8"

for Mesh in ${Meshes}; do

    for LeftHipp in "${WorkingDirectory}/${Subject}.L.hipp_"*.${Mesh}.func.gii; do

        if [[ ! -e "${LeftHipp}" ]]; then
            continue
        fi

        BaseName=$(basename "${LeftHipp}")

        DataName="${BaseName#${Subject}.L.hipp_}"
        DataName="${DataName%.${Mesh}.func.gii}"

        RightHipp="${WorkingDirectory}/${Subject}.R.hipp_${DataName}.${Mesh}.func.gii"
        LeftDentate="${WorkingDirectory}/${Subject}.L.dentate_${DataName}.${Mesh}.func.gii"
        RightDentate="${WorkingDirectory}/${Subject}.R.dentate_${DataName}.${Mesh}.func.gii"

        if [[ -f "${LeftHipp}" &&
              -f "${RightHipp}" &&
              -f "${LeftDentate}" &&
              -f "${RightDentate}" ]]; then

            if [[ "${DataName}" == fMRI_s* ]]; then

                OutputFile="${ResultsFolder}/${NameOffMRI}_AtlasHipp${ProcString}.${Mesh}.dtseries.nii"

                wb_command -cifti-create-dense-timeseries "${OutputFile}" \
                    -metric HIPPOCAMPUS_LEFT "${LeftHipp}" \
                    -metric HIPPOCAMPUS_RIGHT "${RightHipp}" \
                    -metric HIPPOCAMPUS_DENTATE_LEFT "${LeftDentate}" \
                    -metric HIPPOCAMPUS_DENTATE_RIGHT "${RightDentate}"

            else

                OutputName="${DataName#fMRI_}"

                OutputFile="${WorkingDirectory}/${NameOffMRI}_AtlasHipp${ProcString}_${OutputName}.${Mesh}.dscalar.nii"

                wb_command -cifti-create-dense-scalar "${OutputFile}" \
                    -metric HIPPOCAMPUS_LEFT "${LeftHipp}" \
                    -metric HIPPOCAMPUS_RIGHT "${RightHipp}" \
                    -metric HIPPOCAMPUS_DENTATE_LEFT "${LeftDentate}" \
                    -metric HIPPOCAMPUS_DENTATE_RIGHT "${RightDentate}"
            fi

            rm -f \
                "${LeftHipp}" \
                "${RightHipp}" \
                "${LeftDentate}" \
                "${RightDentate}"

            log_Msg "Generated CIFTI file: ${OutputFile}"
        fi

    done

done