#!/bin/bash
set -eu

# Convert  hippocampus and dentate GIFTIs to CIFTIs.
# Delete each set of source GIFTIs only after successful conversion.

pipedirguessed=0
if [[ -z "${HCPPIPEDIR:-}" ]]; then
    pipedirguessed=1
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"

opts_SetScriptDescription "Create hippocampal CIFTI files from explicitly named GIFTI files."

opts_AddMandatory '--results-folder'    'ResultsDirectory' 'path'   "folder for the fMRI dense timeseries"
opts_AddMandatory '--working-directory' 'WorkingDirectory' 'path'   "folder containing intermediate GIFTI files"
opts_AddMandatory '--session'           'Session'          'ID'     "session (eg subject) ID"
opts_AddMandatory '--fmri-name'         'NameOffMRI'        'name'  "fMRI run name"
opts_AddMandatory '--proc-string'       'ProcString'       'string' "processing suffix"
opts_AddMandatory '--mesh'              'Mesh'              'list'   "hippocampal mesh selection: 512, 2k, 8k, 18k"
opts_AddMandatory '--good-voxels'       'doGoodVoxels'      'YES/NO' "good-voxels setting"
opts_AddMandatory '--smoothing-fwhm'    'SmoothingFWHM'     'mm'     "smoothing FWHM"
opts_AddMandatory '--volume-fmri'       'VolumefMRI'        'path'   "volume fMRI file used to read the TR"

opts_ParseArguments "$@"

if (( pipedirguessed )); then
    log_Err_Abort "HCPPIPEDIR is not set; source your edited Examples/Scripts/SetUpHCPPipeline.sh"
fi

opts_ShowValues

# Only the explicitly named meshes below are supported.
case "$Mesh" in
    512|2k|8k|18k) ;;
    *)
        log_Err_Abort "--mesh must be set to 512, 2k, 8k, or 18k"
        ;;
esac

case "$doGoodVoxels" in
    YES|NO) ;;
    *)
        log_Err_Abort "--good-voxels must be YES or NO"
        ;;
esac

mkdir -p "$ResultsDirectory"

TR=$(wb_command -file-information "$VolumefMRI" -only-step-interval)

log_Msg "fMRI TR: ${TR} seconds"
log_Msg "START"

# Convert one explicitly named set of four structure files.
convert_and_delete() {
    local DataName="$1"
    local Mesh="$2"
    local OutputFile="$3"
    local OutputType="$4"

    local LeftHipp="${WorkingDirectory}/${Session}.L.hipp_${DataName}.${Mesh}.func.gii"
    local RightHipp="${WorkingDirectory}/${Session}.R.hipp_${DataName}.${Mesh}.func.gii"
    local LeftDentate="${WorkingDirectory}/${Session}.L.dentate_${DataName}.${Mesh}.func.gii"
    local RightDentate="${WorkingDirectory}/${Session}.R.dentate_${DataName}.${Mesh}.func.gii"

    if [[ ! -f "$LeftHipp" || ! -f "$RightHipp" ||
          ! -f "$LeftDentate" || ! -f "$RightDentate" ]]; then
        log_Err_Abort "Missing input GIFTI for ${DataName}, mesh ${Mesh}"
    fi

    if [[ "$OutputType" == "timeseries" ]]; then
        wb_command -cifti-create-dense-timeseries "$OutputFile" -metric HIPPOCAMPUS_LEFT "$LeftHipp" -metric HIPPOCAMPUS_RIGHT "$RightHipp" -metric HIPPOCAMPUS_DENTATE_LEFT "$LeftDentate" -metric HIPPOCAMPUS_DENTATE_RIGHT "$RightDentate" -timestep "$TR"
    else
        wb_command -cifti-create-dense-scalar "$OutputFile" -metric HIPPOCAMPUS_LEFT "$LeftHipp" -metric HIPPOCAMPUS_RIGHT "$RightHipp" -metric HIPPOCAMPUS_DENTATE_LEFT "$LeftDentate" -metric HIPPOCAMPUS_DENTATE_RIGHT "$RightDentate"
    fi

    rm -- "$LeftHipp" "$RightHipp" "$LeftDentate" "$RightDentate"

    log_Msg "Generated CIFTI file: ${OutputFile}"
}

Prefix="${NameOffMRI}_AtlasHipp${ProcString}"

# Native mesh.

convert_and_delete "fMRI_s${SmoothingFWHM}" native "${WorkingDirectory}/${Prefix}.native.dtseries.nii" timeseries
convert_and_delete fMRI_vn native "${WorkingDirectory}/${Prefix}_vn.native.dscalar.nii" scalar
convert_and_delete fMRI native "${WorkingDirectory}/${Prefix}_fMRI.native.dtseries.nii" timeseries
convert_and_delete cov native "${WorkingDirectory}/${Prefix}_cov.native.dscalar.nii" scalar
convert_and_delete cov_all native "${WorkingDirectory}/${Prefix}_cov_all.native.dscalar.nii" scalar
convert_and_delete mean native "${WorkingDirectory}/${Prefix}_mean.native.dscalar.nii" scalar
convert_and_delete mean_all native "${WorkingDirectory}/${Prefix}_mean_all.native.dscalar.nii" scalar

if [[ "$doGoodVoxels" == "YES" ]]; then
    convert_and_delete goodvoxels native "${WorkingDirectory}/${Prefix}_goodvoxels.native.dscalar.nii" scalar
fi

rm -f -- \
    "${WorkingDirectory}/${Session}.L.hipp_ones.native.func.gii" \
    "${WorkingDirectory}/${Session}.R.hipp_ones.native.func.gii" \
    "${WorkingDirectory}/${Session}.L.dentate_ones.native.func.gii" \
    "${WorkingDirectory}/${Session}.R.dentate_ones.native.func.gii"

# Template mesh
convert_and_delete "fMRI_s${SmoothingFWHM}" "$Mesh" "${ResultsDirectory}/${Prefix}.dtseries.nii" timeseries
convert_and_delete fMRI_vn "$Mesh" "${ResultsDirectory}/${Prefix}_vn.dscalar.nii" scalar
convert_and_delete fMRI "$Mesh" "${WorkingDirectory}/${Prefix}_fMRI.${Mesh}.dtseries.nii" timeseries
convert_and_delete cov "$Mesh" "${WorkingDirectory}/${Prefix}_cov.${Mesh}.dscalar.nii" scalar
convert_and_delete cov_all "$Mesh" "${WorkingDirectory}/${Prefix}_cov_all.${Mesh}.dscalar.nii" scalar
convert_and_delete mean "$Mesh" "${WorkingDirectory}/${Prefix}_mean.${Mesh}.dscalar.nii" scalar
convert_and_delete mean_all "$Mesh" "${WorkingDirectory}/${Prefix}_mean_all.${Mesh}.dscalar.nii" scalar

if [[ "$doGoodVoxels" == "YES" ]]; then
    convert_and_delete goodvoxels "$Mesh" "${WorkingDirectory}/${Prefix}_goodvoxels.${Mesh}.dscalar.nii" scalar
fi

rm -f -- \
    "${WorkingDirectory}/${Session}.L.hipp_ones.${Mesh}.func.gii" \
    "${WorkingDirectory}/${Session}.R.hipp_ones.${Mesh}.func.gii" \
    "${WorkingDirectory}/${Session}.L.dentate_ones.${Mesh}.func.gii" \
    "${WorkingDirectory}/${Session}.R.dentate_ones.${Mesh}.func.gii"

log_Msg "END"