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
opts_AddOptional '--hiresmesh' 'HighResMesh' 'High resolution mesh, default 164' '164'
opts_AddMandatory '--lowresmesh' 'LowResMeshes' 'Low resolution meshes delimited by @, like 32@79' '32@79'
opts_AddOptional '--regname' 'RegName' 'Registration name, default MSMAll' "MSMAll"
opts_AddOptional '--regnameorig' 'RegNameOrig' 'Registration name for original, default MSMSulc' "MSMSulc"
opts_AddOptional '--inflatescale' 'InflateExtraScale' 'Additional scaling beyond linear to deal with a lowres mesh greater than 32k, default 1 (linear)' "1"
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
T2wFolderName="T2w"
AtlasSpaceFolderName="MMORFNonLinear"



T1wFolder="${StudyFolder}/${Session}/${T1wFolderName}"
AtlasSpaceFolder="${StudyFolder}/${Session}/${AtlasSpaceFolderName}"
Diffusion="${T1wFolder}/Diffusion"


${HCPPIPEDIR}/MMORF/scripts/MMORFPostProcessing.sh \
    --t1="${T1wFolder}/${T1wImage}_acpc_dc" \
    --t1rest="${T1wFolder}/${T1wImage}_acpc_dc_restore" \
    --t1restbrain="${T1wFolder}/${T1wImage}_acpc_dc_restore_brain" \
    --t2="${T1wFolder}/${T2wImage}_acpc_dc" \
    --t2rest="${T1wFolder}/${T2wImage}_acpc_dc_restore" \
    --t2restbrain="${T1wFolder}/${T2wImage}_acpc_dc_restore_brain" \
    --ref="${T1wTemplate}" \
    --diffusion="${Diffusion}" \
    --owarp="${AtlasSpaceFolder}/xfms/acpc_dc2mmorf.nii.gz" \
    --oinvwarp="${AtlasSpaceFolder}/xfms/mmorf2acpc_dc.nii.gz" \
    --ot1="${AtlasSpaceFolder}/${T1wImage}" \
    --ot1rest="${AtlasSpaceFolder}/${T1wImage}_restore" \
    --ot1restbrain="${AtlasSpaceFolder}/${T1wImage}_restore_brain" \
    --ot2="${AtlasSpaceFolder}/${T2wImage}" \
    --ot2rest="${AtlasSpaceFolder}/${T2wImage}_restore" \
    --ot2restbrain="${AtlasSpaceFolder}/${T2wImage}_restore_brain" \
    --outputfolder="${AtlasSpaceFolder}"




T1wFolder="T1w" #Location of T1w images
AtlasSpaceFolder="MMORFNonLinear"
NativeFolder="Native"

AtlasTransform="acpc_dc2mmorf"
InverseAtlasTransform="mmorf2acpc_dc"
AtlasSpaceT1wImage="T1w_restore"
AtlasSpaceT2wImage="T2w_restore"
T1wRestoreImage="T1w_acpc_dc_restore"
T2wRestoreImage="T2w_acpc_dc_restore"
T1wImageBrainMask="brainmask_fs"


T1wFolder="$StudyFolder"/"$Session"/"$T1wFolder"
AtlasSpaceFolder="$StudyFolder"/"$Session"/"$AtlasSpaceFolder"
AtlasTransform="$AtlasSpaceFolder"/xfms/"$AtlasTransform"
InverseAtlasTransform="$AtlasSpaceFolder"/xfms/"$InverseAtlasTransform"



argList=("$StudyFolder")                # ${1}
argList+=("$Session")            # ${2} #same as Session in cross-sectional mode.
argList+=("$T1wFolder")                 # ${3}
argList+=("$AtlasSpaceFolder")          # ${4}
argList+=("$NativeFolder")              # ${5}
argList+=("$T1wRestoreImage")           # ${6}  Called T1wImage in FreeSurfer2CaretConvertAndRegisterNonlinear.sh
argList+=("$T2wRestoreImage")           # ${7}
argList+=("$HighResMesh")        # ${8}  
argList+=("$LowResMeshes")              # ${9}
argList+=("$AtlasTransform")            # ${10}
argList+=("$InverseAtlasTransform")     # ${11}
argList+=("$AtlasSpaceT1wImage")        # ${12}
argList+=("$AtlasSpaceT2wImage")        # ${13}
argList+=("$T1wImageBrainMask")         # ${14}
argList+=("$RegName")                   # ${15}
argList+=("$RegNameOrig")                   # ${16}
argList+=("$InflateExtraScale")         # ${17}
    
${HCPPIPEDIR}/MMORF/scripts/PostMMORF.sh "${argList[@]}"
