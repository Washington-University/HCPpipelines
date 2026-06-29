set -uo pipefail
# Load helpers
source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
opts_SetScriptDescription "Post MMORF Pipeline"
opts_AddMandatory '--study-folder' 'StudyFolder' 'Path to the study folder containing session folders' ""
opts_AddMandatory '--subject-list' 'Subjectlist' 'List of session IDs to process deliminated by @' ""
opts_AddMandatory '--high-res-mesh' 'HighResMesh' 'High resolution mesh' ""
opts_AddMandatory '--low-res-meshes' 'LowResMeshes' 'Low resolution meshes deliminated by @' ""
opts_AddMandatory '--RegName' 'RegName' 'Registration name' "MSMAll"
opts_AddMandatory '--RegNameOrig' 'RegNameOrig' 'Registration name for original' "MSMSulc"
opts_AddMandatory '--InflateExtraScale' 'InflateExtraScale' 'Inflate extra scale' "1"
opts_ParseArguments "$@"
Subjectlist=`echo ${Subjectlist} | sed 's/@/ /g'`
for subj in $Subjectlist; do
    ExperimentRoot=$subj
    T1wImage="T1w_acpc_dc"
    T1wFolder="T1w" #Location of T1w images
    T2wFolder="T2w" #Location of T1w images
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
    T2wFolder="$StudyFolder"/"$ExperimentRoot"/"$T2wFolder"
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
    argList+=("$T1wRestoreImage")           # ${8}  Called T1wImage in FreeSurfer2CaretConvertAndRegisterNonlinear.sh
    argList+=("$T2wRestoreImage")           # ${9}  Called T2wImage in FreeSurfer2CaretConvertAndRegisterNonlinear.sh
    argList+=("$HighResMesh")               # ${11}
    argList+=("$LowResMeshes")              # ${12}
    argList+=("$AtlasTransform")            # ${13}
    argList+=("$InverseAtlasTransform")     # ${14}
    argList+=("$AtlasSpaceT1wImage")        # ${15}
    argList+=("$AtlasSpaceT2wImage")        # ${16}
    argList+=("$T1wImageBrainMask")         # ${17}
    argList+=("$RegName")                   # ${18}
    argList+=("$RegNameOrig")                   # ${18}
    argList+=("$InflateExtraScale")         # ${19}
    
    "$PipelineScripts"/PostMMORF.sh "${argList[@]}"

fi
done