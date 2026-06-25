
StudyFolder=/media/myelin/brainmappers/Connectome_Project/YA_HCP_Final
for subj in "$StudyFolder"/*; do
    subj=$(basename "$subj")

    if [[ $subj =~ ^[0-9]+$ ]] && \
       [[ -d "$StudyFolder/$subj/MMORFNonLinear" ]]; then
        ExperimentRoot=$subj
T1wImage="T1w_acpc_dc"
T1wFolder="T1w" #Location of T1w images
T2wFolder="T2w" #Location of T1w images
T2wImage="T2w_acpc_dc"
AtlasSpaceFolder="MMORFNonLinear"
NativeFolder="Native"

SurfaceAtlasDIR=/media/myelin/alexz/HCPpipelines/global/templates/standard_mesh_atlases
FreeSurferFolder=$ExperimentRoot
FreeSurferInput="T1w_acpc_dc_restore_1mm"
AtlasTransform="acpc_dc2mmorf"
InverseAtlasTransform="mmorf2acpc_dc"
AtlasSpaceT1wImage="T1w_restore"
AtlasSpaceT2wImage="T2w_restore"
T1wRestoreImage="T1w_acpc_dc_restore"
T2wRestoreImage="T2w_acpc_dc_restore"
OrginalT1wImage="T1w"
OrginalT2wImage="T2w"
T1wImageBrainMask="brainmask_fs"
InitialT1wTransform="acpc.mat"
dcT1wTransform="T1w_dc.nii.gz"
InitialT2wTransform="acpc.mat"
dcT2wTransform="T2w_reg_dc.nii.gz"
FinalT2wTransform="$ExperimentRoot/mri/transforms/T2wtoT1w.mat"
BiasField="BiasField_acpc_dc"
OutputT1wImage="T1w_acpc_dc"
OutputT1wImageRestore="T1w_acpc_dc_restore"
OutputT1wImageRestoreBrain="T1w_acpc_dc_restore_brain"
OutputMNIT1wImage="T1w"
OutputMNIT1wImageRestore="T1w_restore"
OutputMNIT1wImageRestoreBrain="T1w_restore_brain"
OutputT2wImage="T2w_acpc_dc"
OutputT2wImageRestore="T2w_acpc_dc_restore"
OutputT2wImageRestoreBrain="T2w_acpc_dc_restore_brain"
OutputMNIT2wImage="T2w"
OutputMNIT2wImageRestore="T2w_restore"
OutputMNIT2wImageRestoreBrain="T2w_restore_brain"
OutputOrigT1wToT1w="OrigT1w2T1w.nii.gz"
OutputOrigT1wToStandard="OrigT1w2standard.nii.gz" #File was OrigT2w2standard.nii.gz, regnerate and apply matrix
OutputOrigT2wToT1w="OrigT2w2T1w.nii.gz" #mv OrigT1w2T2w.nii.gz OrigT2w2T1w.nii.gz
OutputOrigT2wToStandard="OrigT2w2standard.nii.gz"
BiasFieldOutput="BiasField"
Jacobian="NonlinearRegJacobians.nii.gz"
HighResMesh='164'
LowResMeshes='32@80'
RegName="MSMAll"
RegNameOrig="MSMSulc"
InflateExtraScale='1'
GrayordinatesResolutions='2'
LongitudinalMode='NONE'
LongitudinalTemplate=
SubcorticalGrayLabels=
GrayordinatesSpaceDIR=
FreeSurferLabels=
SessionList=
Subject="100307"
PipelineScripts="/media/myelin/alexz/HCPpipelines/MMORF/scripts"

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