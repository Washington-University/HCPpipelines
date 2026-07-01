set -uo pipefail
# Load helpers
source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
opts_SetScriptDescription "Post MMORF Pipeline"
opts_AddMandatory '--study-folder' 'StudyFolder' 'Path to the study folder containing session folders' ""
opts_AddMandatory '--subject' 'subj' 'subject ID' ""
opts_AddMandatory '--high-res-mesh' 'HighResMesh' 'High resolution mesh' ""
opts_AddMandatory '--low-res-meshes' 'LowResMeshes' 'Low resolution meshes deliminated by @' ""
opts_AddMandatory '--RegName' 'RegName' 'Registration name' "MSMAll"
opts_AddMandatory '--RegNameOrig' 'RegNameOrig' 'Registration name for original' "MSMSulc"
opts_AddMandatory '--InflateExtraScale' 'InflateExtraScale' 'Inflate extra scale' "1"
opts_ParseArguments "$@"

ExperimentRoot=$subj
T1wImage="T1w_acpc_dc"
T1wFolder="T1w" #Location of T1w images
T2wImage="T2w_acpc_dc"
AtlasSpaceFolder="MMORFNonLinear"
NativeFolder="Native"

SurfaceAtlasDIR=${HCPPIPEDIR}/global/templates/standard_mesh_atlases
FreeSurferFolder=$ExperimentRoot
FreeSurferInput="T1w_acpc_dc_restore_1mm"
AtlasTransform="acpc_dc2mmorf"
InverseAtlasTransform="mmorf2acpc_dc"
AtlasSpaceT1wImage="T1w_restore"
AtlasSpaceT2wImage="T2w_restore"
T1wRestoreImage="T1w_acpc_dc_restore"
T2wRestoreImage="T2w_acpc_dc_restore"
T1wImageBrainMask="brainmask_fs"


T1wFolder="$StudyFolder"/"$ExperimentRoot"/"$T1wFolder"
AtlasSpaceFolder="$StudyFolder"/"$ExperimentRoot"/"$AtlasSpaceFolder"
FreeSurferFolder="$T1wFolder"/"$FreeSurferFolder"
AtlasTransform="$AtlasSpaceFolder"/xfms/"$AtlasTransform"
InverseAtlasTransform="$AtlasSpaceFolder"/xfms/"$InverseAtlasTransform"
MNINonLinearFolder="$StudyFolder"/"$ExperimentRoot"/"MNINonLinear"



argList=("$StudyFolder")                # ${1}
argList+=("$ExperimentRoot")            # ${2} #same as Session in cross-sectional mode.
argList+=("$T1wFolder")                 # ${3}
argList+=("$AtlasSpaceFolder")          # ${4}
argList+=("$NativeFolder")              # ${5}
argList+=("$T1wRestoreImage")           # ${6}  Called T1wImage in FreeSurfer2CaretConvertAndRegisterNonlinear.sh
argList+=("$T2wRestoreImage")           # ${7}  
argList+=("$LowResMeshes")              # ${9}
argList+=("$AtlasTransform")            # ${10}
argList+=("$InverseAtlasTransform")     # ${11}
argList+=("$AtlasSpaceT1wImage")        # ${12}
argList+=("$AtlasSpaceT2wImage")        # ${13}
argList+=("$T1wImageBrainMask")         # ${14}
argList+=("$RegName")                   # ${15}
argList+=("$RegNameOrig")                   # ${16}
argList+=("$InflateExtraScale")         # ${17}
    
"$PipelineScripts"/PostMMORF.sh "${argList[@]}"
