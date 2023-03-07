#!/bin/bash
set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source "$HCPPIPEDIR/global/scripts/tempfiles.shlib"

defaultSigma=$(echo "sqrt(200)" | bc -l)

#description to use in usage - syntax of parameters is now explained automatically
opts_SetScriptDescription "corrects an individual native mesh myelin map for bias fields based on a group average myelin map"

#mandatory
#general inputs
opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder that contains all subjects"
opts_AddMandatory '--subject' 'Subject' '100206' "one subject ID"
opts_AddMandatory '--registration-name' 'RegName' 'MSMAll' "the registration string corresponding to the input files, e.g. 'MSMAll' or 'MSMSulc'"
opts_AddMandatory '--msm-all-templates' 'MSMAllTemplates' 'path' "path to directory containing MSM All template files, e.g. 'YourFolder/global/templates/MSMAll'"
#optional inputs
opts_AddOptional '--use-ind-mean' 'UseIndMean' 'YES or NO' "whether to use the mean of the subject's myelin map as reference map's myelin map mean , defaults to 'YES'" 'YES'
opts_AddOptional '--low-res-mesh' 'LowResMesh' 'meshnum' "low resolution mesh node count (in thousands), defaults to '32' for 32k_fs_LR" '32'
opts_AddOptional '--mcsigma' 'CorrectionSigma' 'number' "myelin map bias correction sigma, this option is mainly intended for non-human-adult data, defaults to '$defaultSigma'" "$defaultSigma"
opts_AddOptional '--myelin-target-file' 'MyelinTarget' 'string' "alternate myelin map target, relative to the --msm-all-templates folder" 'Q1-Q6_RelatedParcellation210.MyelinMap_BC_MSMAll_2_d41_WRN_DeDrift.32k_fs_LR.dscalar.nii'
opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

# Verify required environment variables are set and log value
log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var CARET7DIR

#display HCP Pipeline version
log_Msg "Showing HCP Pipelines version"
"${HCPPIPEDIR}"/show_version --short

#display the parsed/default values
opts_ShowValues

# ------------------------------------------------------------------------------
#  Main processing of script.
# ------------------------------------------------------------------------------
log_Msg "Starting main functionality"
Caret7_Command=${CARET7DIR}/wb_command
UseIndMeanBool=$(opts_StringToBool "$UseIndMean")
# default folders
SubjFolder=${StudyFolder}/${Subject}
log_Msg "SubjFolder: $SubjFolder"
AtlasSpaceFolder=${SubjFolder}/MNINonLinear
log_Msg "AtlasSpaceFolder: $AtlasSpaceFolder"
T1wFolder=${SubjFolder}/T1w
log_Msg "T1wFolder: $T1wFolder"
NativeFolder=${AtlasSpaceFolder}/Native
log_Msg "NativeFolder: $NativeFolder"
NativeT1wFolder=${T1wFolder}/Native
log_Msg "NativeT1wFolder: $NativeT1wFolder"
# MSMAll templates Myelin Target which is the group average MyelinMap_BC
MyelinTarget="${MSMAllTemplates}/${MyelinTarget}"
# low res setting
LowResMeshString=${LowResMesh}k_fs_LR
LowResFolder=${AtlasSpaceFolder}/fsaverage_LR${LowResMesh}k
LowResT1wFolder=${T1wFolder}/fsaverage_LR${LowResMesh}k
LowResBCMapName="atlas_MyelinMap"

# atlas group average reference map
tempfiles_create atlas_MyelinMap_BC_XXXXXX.dscalar.nii ReferenceMapMeanMatch
ReferenceMap=${MyelinTarget}
ReferenceMapToUse=${ReferenceMap}

case "$RegName" in
	(MSMSulc|"")
		RegNameInOutputName=""
		RegNameInT1wName=""
		RegNameStructString=.MSMSulc
		;;
	(*)
		RegNameInOutputName=_${RegName}
		RegNameInT1wName=_${RegName}
		RegNameStructString=.${RegName}
        ;;
esac
log_Msg "RegNameInOutputName: $RegNameInOutputName"
log_Msg "RegNameInT1wName: $RegNameInT1wName"
log_Msg "RegNameStructString: $RegNameStructString"

NativeMyelinMap=${NativeFolder}/${Subject}.MyelinMap.native.dscalar.nii
log_File_Must_Exist "${NativeMyelinMap}"

IndividualLowResMap=${LowResFolder}/${Subject}.MyelinMap${RegNameInOutputName}.${LowResMeshString}.dscalar.nii
${Caret7_Command} -cifti-resample ${NativeMyelinMap} \
	COLUMN ${LowResFolder}/${Subject}.MyelinMap.${LowResMeshString}.dscalar.nii \
	COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL \
	${IndividualLowResMap} \
	-surface-postdilate 40 \
	-left-spheres ${NativeFolder}/${Subject}.L.sphere${RegNameStructString}.native.surf.gii ${LowResFolder}/${Subject}.L.sphere.${LowResMeshString}.surf.gii \
	-left-area-surfs ${NativeT1wFolder}/${Subject}.L.midthickness.native.surf.gii ${LowResFolder}/${Subject}.L.midthickness.${LowResMeshString}.surf.gii \
	-right-spheres ${NativeFolder}/${Subject}.R.sphere${RegNameStructString}.native.surf.gii ${LowResFolder}/${Subject}.R.sphere.${LowResMeshString}.surf.gii \
	-right-area-surfs ${NativeT1wFolder}/${Subject}.R.midthickness.native.surf.gii ${LowResFolder}/${Subject}.R.midthickness.${LowResMeshString}.surf.gii

log_Msg "Resampled MyelinMap in the low res mesh space using registration: ${IndividualLowResMap}"

# match the reference map's mean with the individual map's mean
if ((UseIndMeanBool)); then
	log_Msg "match the group reference map's mean with the individual map's mean"
	log_Msg "UseIndMeanBool: $UseIndMeanBool"
	# calcualte means of reference and individual maps
	# not average in vertex areas, but it is fine
	MeanRef=$(${Caret7_Command} -cifti-stats -reduce MEAN ${ReferenceMap})
	MeanInd=$(${Caret7_Command} -cifti-stats -reduce MEAN ${IndividualLowResMap})
	log_Msg "MeanRef: $MeanRef"
	log_Msg "MeanInd: $MeanInd"
	
	# match the reference map's mean as individual map's mean
	${Caret7_Command} -cifti-math "Reference / $MeanRef * $MeanInd" ${ReferenceMapMeanMatch} -var Reference ${ReferenceMap}
	ReferenceMapToUse=${ReferenceMapMeanMatch}
fi

# generate BiasField in the input mesh space
LowResBiasField=${LowResFolder}/${Subject}.BiasField${RegNameInOutputName}.${LowResMeshString}.dscalar.nii
${Caret7_Command} -cifti-math "Individual - Reference" ${LowResBiasField} \
	-var Individual ${IndividualLowResMap} \
	-var Reference ${ReferenceMapToUse}
	
log_Msg "BiasField in the low res mesh space: ${LowResBiasField}"
# smooth the bias field
${Caret7_Command} -cifti-smoothing ${LowResBiasField} \
	${CorrectionSigma} 0 COLUMN \
	${LowResBiasField} \
	-left-surface ${LowResT1wFolder}/${Subject}.L.midthickness${RegNameInT1wName}.${LowResMeshString}.surf.gii \
	-right-surface ${LowResT1wFolder}/${Subject}.R.midthickness${RegNameInT1wName}.${LowResMeshString}.surf.gii

log_Msg "Smoothed BiasField in the low res mesh space: ${LowResBiasField}"

# resample the bias field back to native mesh space
NativeBiasField=${NativeFolder}/${Subject}.BiasField${RegNameInOutputName}.native.dscalar.nii
${Caret7_Command} -cifti-resample ${LowResBiasField} \
	COLUMN ${NativeMyelinMap} \
	COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL \
	${NativeBiasField} \
	-surface-postdilate 40 \
	-left-spheres ${LowResFolder}/${Subject}.L.sphere.${LowResMeshString}.surf.gii ${NativeFolder}/${Subject}.L.sphere${RegNameStructString}.native.surf.gii \
	-left-area-surfs ${LowResT1wFolder}/${Subject}.L.midthickness${RegNameInT1wName}.${LowResMeshString}.surf.gii ${NativeT1wFolder}/${Subject}.L.midthickness.native.surf.gii \
	-right-spheres ${LowResFolder}/${Subject}.R.sphere.${LowResMeshString}.surf.gii ${NativeFolder}/${Subject}.R.sphere${RegNameStructString}.native.surf.gii \
	-right-area-surfs ${LowResT1wFolder}/${Subject}.R.midthickness${RegNameInT1wName}.${LowResMeshString}.surf.gii ${NativeT1wFolder}/${Subject}.R.midthickness.native.surf.gii 

log_Msg "Resampled BiasField in the native mesh space: ${NativeBiasField}"

# generate bias corrected map in the output mesh space
NativeBCMap=${NativeFolder}/${Subject}.MyelinMap_BC${RegNameInOutputName}.native.dscalar.nii

${Caret7_Command} -cifti-math "Var - Bias" ${NativeBCMap} \
	-var Var ${NativeMyelinMap} \
	-var Bias ${NativeBiasField}

log_Msg "_BC Myelin map in the native mesh space: ${NativeBCMap}"
# TODO: add gifti generation according to one argument
# -cifti-separate-all
log_Msg "Completing main functionality"
