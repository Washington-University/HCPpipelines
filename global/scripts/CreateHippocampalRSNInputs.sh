#!/bin/bash
set -euo pipefail

# Create hippocampal inputs for RSNregression:
#   1. normalized hippocampal vertex-area weights
#   2. hippocampal group maps projected from volumetric GroupMaps
#
# Usage:
#   CreateHippocampalRSNInputs.sh MNIFolder WorkingDirectory Subject GroupMaps LowResMesh fMRIName ProcString

if [[ "$#" -ne 7 ]]; then
    echo "Usage: $0 <MNIFolder> <WorkingDirectory> <Subject> <GroupMaps> <LowResMesh> <fMRIName> <ProcString>"
    exit 1
fi

MNIFolder="$1"
WorkingDirectory="$2"
Subject="$3"
GroupMaps="$4"
LowResMesh="$5"
fMRIName="$6"
ProcString="$7"

HippUnfoldDirectory="${MNIFolder}/HippUnfold/${LowResMesh}k"

if [[ -z "${HCPPIPEDIR:-}" ]]; then
    echo "ERROR: HCPPIPEDIR is not set"
    exit 1
fi

source "${HCPPIPEDIR}/global/scripts/log.shlib"

ScriptName="$(basename "$0" .sh)"
TempWorkingDirectory="${WorkingDirectory}/${ScriptName}"

mkdir -p "$TempWorkingDirectory"

HippBOLDResults="${MNIFolder}/Results/${fMRIName}"
HippMappingResults="${HippBOLDResults}/HippocampalVolumeToSurfaceMapping"
VNTemplate="${HippMappingResults}/${fMRIName}_AtlasHipp${ProcString}_vn.${LowResMesh}k.dscalar.nii"

VARaw="${WorkingDirectory}/${Subject}.Hipp_midthickness_va.${LowResMesh}k.dscalar.nii"
VANorm="${WorkingDirectory}/${Subject}.Hipp_midthickness_va_norm.${LowResMesh}k.dscalar.nii"
HippGroupMaps="${WorkingDirectory}/${Subject}.HippGroupMaps.${LowResMesh}k.dscalar.nii"

GroupMapsBase="$(basename "$GroupMaps" .dscalar.nii)"
GroupMapsVolume="${TempWorkingDirectory}/${GroupMapsBase}.volume.nii.gz"

if [[ ! -d "$WorkingDirectory" ]]; then
    log_Err_Abort "Working directory does not exist: $WorkingDirectory"
fi

if [[ ! -f "$GroupMaps" ]]; then
    log_Err_Abort "GroupMaps does not exist: $GroupMaps"
fi

if [[ ! -f "$GroupMaps" ]]; then
    log_Err_Abort "VN template does not exist: $VNTemplate"
fi
# ------------------------------------------------------------------------------
# Create normalized hippocampal vertex-area weights
# ------------------------------------------------------------------------------

log_Msg "Creating hippocampal vertex-area CIFTI"

wb_command -cifti-create-dense-from-template "$VNTemplate" "$VARaw" -metric HIPPOCAMPUS_LEFT "${HippUnfoldDirectory}/${Subject}.L.hipp_surfarea.${LowResMesh}k.shape.gii" -metric HIPPOCAMPUS_RIGHT "${HippUnfoldDirectory}/${Subject}.R.hipp_surfarea.${LowResMesh}k.shape.gii" -metric HIPPOCAMPUS_DENTATE_LEFT "${HippUnfoldDirectory}/${Subject}.L.dentate_surfarea.${LowResMesh}k.shape.gii" -metric HIPPOCAMPUS_DENTATE_RIGHT "${HippUnfoldDirectory}/${Subject}.R.dentate_surfarea.${LowResMesh}k.shape.gii"

VAMean=$(wb_command -cifti-stats "$VARaw" -reduce MEAN)

wb_command -cifti-math "VA / $VAMean" "$VANorm" -var VA "$VARaw"

log_Msg "Created normalized hippocampal vertex-area weights: $VANorm"


# ------------------------------------------------------------------------------
# Extract volumetric component of GroupMaps
# ------------------------------------------------------------------------------

log_Msg "Extracting volumetric GroupMaps from: $GroupMaps"

wb_command -cifti-separate "$GroupMaps" COLUMN -volume-all "$GroupMapsVolume"


# ------------------------------------------------------------------------------
# Map volumetric GroupMaps to HippUnfold surfaces
# ------------------------------------------------------------------------------

for Structure in hipp dentate; do
    for Hemisphere in L R; do

        Prefix="${Subject}.${Hemisphere}.${Structure}"

        InnerSurface="${HippUnfoldDirectory}/${Prefix}_inner.${LowResMesh}k.surf.gii"
        MidSurface="${HippUnfoldDirectory}/${Prefix}_midthickness.${LowResMesh}k.surf.gii"
        OuterSurface="${HippUnfoldDirectory}/${Prefix}_outer.${LowResMesh}k.surf.gii"      
        OutputMetric="${TempWorkingDirectory}/${Prefix}.${GroupMapsBase}.${LowResMesh}k.func.gii"

        if [[ ! -f "$InnerSurface" ]]; then
            log_Err_Abort "Missing surface: $InnerSurface"
        fi

        if [[ ! -f "$MidSurface" ]]; then
            log_Err_Abort "Missing surface: $MidSurface"
        fi

        if [[ ! -f "$OuterSurface" ]]; then
            log_Err_Abort "Missing surface: $OuterSurface"
        fi

        log_Msg "Mapping GroupMaps to ${Hemisphere}.${Structure}"

        wb_command -volume-to-surface-mapping "$GroupMapsVolume" "$MidSurface" "$OutputMetric" -ribbon-constrained "$InnerSurface" "$OuterSurface" -dilate-missing 1

    done
done


# ------------------------------------------------------------------------------
# Create hippocampal GroupMaps CIFTI
# ------------------------------------------------------------------------------

log_Msg "Creating hippocampal GroupMaps CIFTI"

wb_command -cifti-create-dense-from-template "$VNTemplate" "$HippGroupMaps" -metric HIPPOCAMPUS_LEFT "${TempWorkingDirectory}/${Subject}.L.hipp.${GroupMapsBase}.${LowResMesh}k.func.gii" -metric HIPPOCAMPUS_RIGHT "${TempWorkingDirectory}/${Subject}.R.hipp.${GroupMapsBase}.${LowResMesh}k.func.gii" -metric HIPPOCAMPUS_DENTATE_LEFT "${TempWorkingDirectory}/${Subject}.L.dentate.${GroupMapsBase}.${LowResMesh}k.func.gii" -metric HIPPOCAMPUS_DENTATE_RIGHT "${TempWorkingDirectory}/${Subject}.R.dentate.${GroupMapsBase}.${LowResMesh}k.func.gii"

log_Msg "Created hippocampal GroupMaps: $HippGroupMaps"
log_Msg "Created hippocampal VA weights: $VANorm"
log_Msg "Intermediate files retained in: $TempWorkingDirectory"
log_Msg "CreateHippocampalRSNInputs complete"