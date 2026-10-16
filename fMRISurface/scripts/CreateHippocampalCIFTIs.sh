#!/bin/bash
set -eu

# Convert the four hippocampal and dentate GIFTI structures into CIFTI files.
# Remove intermediate func.gii files after successful conversion.

script_name=$(basename -- "$0")

pipedirguessed=0
if [[ -z "${HCPPIPEDIR:-}" ]]; then
    pipedirguessed=1
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"

opts_SetScriptDescription "Create hippocampal CIFTI files from left/right hippocampus and dentate GIFTI files."

opts_AddMandatory '--results-folder'    'ResultsDirectory'    'path'   "folder for the fMRI dense timeseries"
opts_AddMandatory '--working-directory' 'WorkingDirectory' 'path'   "folder containing intermediate GIFTI files"
opts_AddMandatory '--subject'           'Subject'          'ID'     "subject ID"
opts_AddMandatory '--fmri-name'         'NameOffMRI'       'name'   "fMRI run name"
opts_AddMandatory '--proc-string'       'ProcString'       'string' "processing suffix"
opts_AddMandatory '--meshes'            'Meshes'           'list'   "space-separated mesh names"
opts_AddMandatory '--good-voxels'       'doGoodVoxels'     'YES/NO' "good-voxels setting"
opts_AddMandatory '--smoothing-fwhm'    'SmoothingFWHM'    'mm'     "smoothing FWHM"
opts_AddMandatory '--volume-fmri'       'VolumefMRI'       'path'   "volume fMRI file used to read the TR"

opts_ParseArguments "$@"

if (( pipedirguessed )); then
    log_Err_Abort "HCPPIPEDIR is not set; source your edited Examples/Scripts/SetUpHCPPipeline.sh"
fi


opts_ShowValues

TR=$(wb_command -file-information "$VolumefMRI" -only-step-interval)
log_Msg "fMRI TR: ${TR} seconds"
log_Msg "START"


for Mesh in ${Meshes}; do
    for Hemisphere in L R; do
        for Structure in hipp dentate; do
            rm -f "${WorkingDirectory}/${Subject}.${Hemisphere}.${Structure}_ones.${Mesh}.func.gii"
        done
    done

    for LeftHipp in "${WorkingDirectory}/${Subject}.L.hipp_"*.${Mesh}.func.gii; do
        [[ -e "$LeftHipp" ]] || continue

        BaseName=$(basename -- "$LeftHipp")
        DataName="${BaseName#${Subject}.L.hipp_}"
        DataName="${DataName%.${Mesh}.func.gii}"


        RightHipp="${WorkingDirectory}/${Subject}.R.hipp_${DataName}.${Mesh}.func.gii"
        LeftDentate="${WorkingDirectory}/${Subject}.L.dentate_${DataName}.${Mesh}.func.gii"
        RightDentate="${WorkingDirectory}/${Subject}.R.dentate_${DataName}.${Mesh}.func.gii"

        if [[ ! -f "$RightHipp" || ! -f "$LeftDentate" || ! -f "$RightDentate" ]]; then
            continue
        fi

        if [[ "$DataName" == fMRI_s* ]]; then

            if [[ "$Mesh" == "native" ]]; then
                OutputFile="${WorkingDirectory}/${NameOffMRI}_AtlasHipp${ProcString}.${Mesh}.dtseries.nii"
            else
                OutputFile="${ResultsDirectory}/${NameOffMRI}_AtlasHipp${ProcString}.dtseries.nii"
            fi
            wb_command -cifti-create-dense-timeseries "$OutputFile" \
                -metric HIPPOCAMPUS_LEFT "$LeftHipp" \
                -metric HIPPOCAMPUS_RIGHT "$RightHipp" \
                -metric HIPPOCAMPUS_DENTATE_LEFT "$LeftDentate" \
                -metric HIPPOCAMPUS_DENTATE_RIGHT "$RightDentate" \
                -timestep "$TR"
        else
            if [[ "$DataName" == *_vn ]]; then
                if [[ "$Mesh" == "native" ]]; then
                    OutputFile="${WorkingDirectory}/${NameOffMRI}_AtlasHipp${ProcString}_vn.${Mesh}.dscalar.nii"
                else
                    OutputFile="${ResultsDirectory}/${NameOffMRI}_AtlasHipp${ProcString}_vn.dscalar.nii"
                fi
            else
                OutputFile="${WorkingDirectory}/${NameOffMRI}_AtlasHipp${ProcString}_${DataName}.${Mesh}.dscalar.nii"
            fi
            wb_command -cifti-create-dense-scalar "$OutputFile" \
                -metric HIPPOCAMPUS_LEFT "$LeftHipp" \
                -metric HIPPOCAMPUS_RIGHT "$RightHipp" \
                -metric HIPPOCAMPUS_DENTATE_LEFT "$LeftDentate" \
                -metric HIPPOCAMPUS_DENTATE_RIGHT "$RightDentate"
        fi

        rm -f "$LeftHipp" "$RightHipp" "$LeftDentate" "$RightDentate"
        log_Msg "Generated CIFTI file: ${OutputFile}"
    done
done