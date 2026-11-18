#!/bin/bash 

set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
opts_SetScriptDescription "Wrapper for running post MMORF registration"
opts_AddMandatory '--study-folder' 'StudyFolder' 'folder' 'Path to the study folder containing session folders'
opts_AddMandatory '--session' 'Session' 'subject ID' "(e.g. 100610)"
opts_AddMandatory '--t1-template' 'T1wTemplate' 'Image' "Path to the T1w template image"
opts_AddMandatory '--grayordinates-space-dir' 'GrayordinatesSpaceDIR' 'path' "grayordinates space directory"
opts_AddMandatory '--surface-atlas-dir' 'SurfaceAtlasDIR' 'path' "surface atlas directory"

opts_AddOptional '--hiresmesh' 'HighResMesh' 'number' 'High resolution mesh, default 164' '164'
opts_AddOptional '--lowresmesh' 'LowResMeshes' 'num@num' 'Low resolution meshes delimited by @, default 32' '32'
opts_AddOptional '--diffusionmesh' 'DiffusionMesh' 'number' 'Diffusion mesh, default 79' '79'
opts_AddOptional '--regname' 'RegName' 'MSMAll' 'Registration name, default MSMAll' "MSMAll"
opts_AddOptional '--regnameorig' 'RegNameOrig' 'MSMSulc' 'Registration name for original, default MSMSulc' "MSMSulc"
opts_AddOptional '--inflatescale' 'InflateExtraScale' 'number' 'Additional scaling beyond linear to deal with a lowres mesh greater than 32k, default 1 (linear)' "1"
opts_AddOptional '--grayordinatesres' 'GrayordinatesResolutions' 'num@num' 'Grayordinate resolutions in mm delimited by @, default 2' '2'
opts_AddOptional '--subcortgraylabels' 'SubcorticalGrayLabels' 'file' 'Subcortical label table' "${HCPPIPEDIR}/global/config/FreeSurferSubcorticalLabelTableLut.txt"
opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

opts_ShowValues

echo "Launching Post MMORF registration for session ${Session}"


T1wImage="T1w"
T1wFolderName="T1w"
T2wImage="T2w"
AtlasSpaceFolderName="MMORFNonLinear"
T1wImageBrainMask="brainmask_fs"
T1wImageBiasField="BiasField_acpc_dc"

T1wFolder="${StudyFolder}/${Session}/${T1wFolderName}"
AtlasSpaceFolder="${StudyFolder}/${Session}/${AtlasSpaceFolderName}"
Diffusion="${T1wFolder}/Diffusion"

${HCPPIPEDIR}/MMORF/scripts/PostMMORF_ResampleVolumes.sh \
    --t1folder="${T1wFolder}" \
    --t1="${T1wFolder}/${T1wImage}_acpc_dc" \
    --t1rest="${T1wFolder}/${T1wImage}_acpc_dc_restore" \
    --t1restbrain="${T1wFolder}/${T1wImage}_acpc_dc_restore_brain" \
    --t1brainmask="${T1wFolder}/${T1wImageBrainMask}" \
    --t1biasfield="${T1wFolder}/${T1wImageBiasField}" \
    --grayordinatesres="${GrayordinatesResolutions}" \
    --subcortgraylabels="${SubcorticalGrayLabels}" \
    --t2="${T1wFolder}/${T2wImage}_acpc_dc" \
    --t2rest="${T1wFolder}/${T2wImage}_acpc_dc_restore" \
    --t2restbrain="${T1wFolder}/${T2wImage}_acpc_dc_restore_brain" \
    --ref="${T1wTemplate}" \
    --diffusion="${Diffusion}" \
    --owarp="${AtlasSpaceFolder}/xfms/acpc_dc2standard.nii.gz" \
    --oinvwarp="${AtlasSpaceFolder}/xfms/standard2acpc_dc.nii.gz" \
    --ot1="${AtlasSpaceFolder}/${T1wImage}" \
    --ot1rest="${AtlasSpaceFolder}/${T1wImage}_restore" \
    --ot1restbrain="${AtlasSpaceFolder}/${T1wImage}_restore_brain" \
    --ot1brainmask="${AtlasSpaceFolder}/${T1wImageBrainMask}" \
    --ot1biasfield="${AtlasSpaceFolder}/BiasField" \
    --ot2="${AtlasSpaceFolder}/${T2wImage}" \
    --ot2rest="${AtlasSpaceFolder}/${T2wImage}_restore" \
    --ot2restbrain="${AtlasSpaceFolder}/${T2wImage}_restore_brain" \
    --outputfolder="${AtlasSpaceFolder}" \
    --grayordinates-space-dir="${GrayordinatesSpaceDIR}"

NativeFolder="Native"
AtlasTransform="acpc_dc2standard"
InverseAtlasTransform="standard2acpc_dc"
AtlasSpaceT1wImage="T1w_restore"
AtlasSpaceT2wImage="T2w_restore"
T1wRestoreImage="T1w_acpc_dc_restore"
T2wRestoreImage="T2w_acpc_dc_restore"

AtlasTransform="$AtlasSpaceFolder"/xfms/"$AtlasTransform"
InverseAtlasTransform="$AtlasSpaceFolder"/xfms/"$InverseAtlasTransform"



${HCPPIPEDIR}/MMORF/scripts/PostMMORF_generateSurfaceFiles.sh \
    --study-folder="${StudyFolder}" \
    --session="${Session}" \
    --t1folder="${T1wFolder}" \
    --atlasfolder="${AtlasSpaceFolder}" \
    --nativefolder="${NativeFolder}" \
    --t1="${T1wRestoreImage}" \
    --t2="${T2wRestoreImage}" \
    --hiresmesh="${HighResMesh}" \
    --lowresmesh="${LowResMeshes}" \
    --diffusionmesh="${DiffusionMesh}" \
    --atlas-transform="${AtlasTransform}" \
    --inverse-atlas-transform="${InverseAtlasTransform}" \
    --atlas-t1="${AtlasSpaceT1wImage}" \
    --atlas-t2="${AtlasSpaceT2wImage}" \
    --regname="${RegName}" \
    --regnameorig="${RegNameOrig}" \
    --inflatescale="${InflateExtraScale}" \
    --surface-atlas-dir="${SurfaceAtlasDIR}" \
    --grayordinates-space-dir="${GrayordinatesSpaceDIR}"

