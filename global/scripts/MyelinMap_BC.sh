#!/bin/bash
set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
g_matlab_default_mode=1
defaultSigma=$(echo "sqrt(200)" | bc -l)

#description to use in usage - syntax of parameters is now explained automatically
opts_SetScriptDescription "implements CIFTI-based Myelin map bias corrections from one resolution to another; resolution includes native, 164k, 32k"

#mandatory
#general inputs
opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder that contains all subjects"
opts_AddMandatory '--subject' 'Subject' '100206' "one subject ID"
opts_AddMandatory '--registration-name' 'RegName' 'MSMAll' "the registration string corresponding to the input files, e.g. 'MSMAll' or ''"
opts_AddMandatory '--input-mesh' 'InputMesh' 'meshnum or native' "input resolution mesh node count (in thousands) or 'native', like '164' for 164k_fs_LR"
opts_AddMandatory '--output-mesh' 'OutputMesh' 'meshnum or native' "low resolution mesh node count (in thousands) or 'native', like '32' for 32k_fs_LR"
#optional inputs
opts_AddOptional '--use-ind-mean' 'UseIndMean' 'YES or NO' "whether to use the mean of the subject's myelin map as reference map's myelin map mean , defaults to 'NO'" 'NO'
opts_AddOptional '--mcsigma' 'CorrectionSigma' 'number' "myelin map bias correction sigma, default '$defaultSigma'" "$defaultSigma"
opts_AddOptional '--matlab-run-mode' 'MatlabRunMode' '0, 1, or 2' "defaults to $g_matlab_default_mode
0 = compiled MATLAB
1 = interpreted MATLAB
2 = Octave" "$g_matlab_default_mode"
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
RegNameToUse=""
if [[ "$RegName" != "" ]]; then
	RegNameToUse=_${RegName}
fi

# default folders
SubjFolder=${StudyFolder}/${Subject}
AtlasSpaceFolder=${SubjFolder}/MNINonLinear
T1wFolder=${SubjFolder}/T1w
#NativeT1wFolder=${T1wFolder}/Native
#NativeFolder=${AtlasSpaceFolder}/Native
#DownSampleFolder=${AtlasSpaceFolder}/fsaverage_LR${LowResMesh}k
#DownSampleT1wFolder=${T1wFolder}/fsaverage_LR${LowResMesh}k

# convert upper case to lower case
InputMesh=`echo "$InputMesh" | tr '[:upper:]' '[:lower:]'`
OutputMesh=`echo "$OutputMesh" | tr '[:upper:]' '[:lower:]'`

if [[ "$InputMesh" == "$OutputMesh" ]]; then
	log_Err_Abort "the input mesh ${InputMesh} and the output mesh ${OutputMesh} shouldn't be the same!"
fi

case "$InputMesh" in
	(native)
		InputMeshString="native"
		InputFolder=${AtlasSpaceFolder}/Native
		InputT1wFolder=${T1wFolder}/Native
		InputBCMapName="MyelinMap"
		;;
	(164)
		InputMeshString=164k_fs_LR
		InputFolder=${AtlasSpaceFolder}
		InputT1wFolder=${AtlasSpaceFolder}
		InputBCMapName="MyelinMap"
		;;
	(32)
		InputMeshString=32k_fs_LR
		InputFolder=${AtlasSpaceFolder}/fsaverage_LR32k
		InputT1wFolder=${T1wFolder}/fsaverage_LR32k
		InputBCMapName="atlas_MyelinMap"
		;;
	(*)
        log_Err_Abort "unrecognized --input-mesh value '$InputMesh', valid options are native, 32, 164"
        ;;
esac

case "$OutputMesh" in
	(native)
		OutputMeshString="native"
		OutputFolder=${AtlasSpaceFolder}/Native
		OutputT1wFolder=${T1wFolder}/Native
		OutputBCMapName="MyelinMap"
		;;
	(164)
		OutputMeshString=164k_fs_LR
		OutputFolder=${AtlasSpaceFolder}
		OutputT1wFolder=${AtlasSpaceFolder}
		OutputBCMapName="MyelinMap"
		;;
	(32)
		OutputMeshString=32k_fs_LR
		OutputFolder=${AtlasSpaceFolder}/fsaverage_LR32k
		OutputT1wFolder=${T1wFolder}/fsaverage_LR32k
		OutputBCMapName="atlas_MyelinMap"
		;;
	(*)
        log_Err_Abort "unrecognized --output-mesh value '$OutputMesh', valid options are native, 32, 164"
        ;;
esac

IndividualMap=${InputFolder}/${Subject}.MyelinMap${RegNameToUse}.${InputMeshString}.dscalar.nii
log_File_Must_Exist "${IndividualMap}"
ReferenceMap=${InputFolder}/${Subject}.${InputBCMapName}_BC.${InputMeshString}.dscalar.nii
log_File_Must_Exist "${ReferenceMap}"
ReferenceMapOld=${InputFolder}/${Subject}.${InputBCMapName}_oldBC.${InputMeshString}.dscalar.nii
ReferenceMapToUse=${ReferenceMap}

# match the reference map's mean with the individual map's mean
if ((UseIndMeanBool)); then
	# the new reference map
	# TODO: Do we want to distinguish the mean-matched reference map by inserting a string in the file name?
	ReferenceMapMeanMatch=${InputFolder}/${Subject}.atlas_MyelinMap_BC_MatchIndMean.${InputMeshString}.dscalar.nii
	# calcualte means of reference and individual maps
	# not average in vertex areas, but it is fine
	MeanRef=(${Caret7_Command} -cifti-stats -reduce MEAN ${ReferenceMap})
	MeanInd=(${Caret7_Command} -cifti-stats -reduce MEAN ${IndividualMap})
	# to save the old maps as _oldBC
	if [ -f "$ReferenceMap" ]; then
		cp ${ReferenceMap} ${ReferenceMapOld}
	fi
	# match the reference map's mean as individual map's mean
	${Caret7_Command} -cifti-math "Reference - $MeanRef + $MeanInd" ${ReferenceMapMeanMatch} -var Reference ${ReferenceMap}
	ReferenceMapToUse=${ReferenceMapMeanMatch}
fi

# generate BiasField in the input mesh space
${Caret7_Command} -cifti-math "Individual - Reference" ${InputFolder}/${Subject}.BiasField${RegNameToUse}.${InputMeshString}.dscalar.nii \
	-var Individual ${IndividualMap} \
	-var Reference ${ReferenceMapToUse}

# smooth the bias field
${Caret7_Command} -cifti-smoothing ${InputFolder}/${Subject}.BiasField${RegNameToUse}.${InputMeshString}.dscalar.nii \
	${CorrectionSigma} 0 COLUMN \
	${InputFolder}/${Subject}.BiasField${RegNameToUse}.${InputMeshString}.dscalar.nii \
	-left-surface ${InputT1wFolder}/${Subject}.L.midthickness${RegNameToUse}.${InputMeshString}.surf.gii \
	-right-surface ${InputT1wFolder}/${Subject}.R.midthickness${RegNameToUse}.${InputMeshString}.surf.gii
	
# resample the bias field to output mesh space
${Caret7_Command} -cifti-resample ${InputFolder}/${Subject}.BiasField${RegNameToUse}.${InputMeshString}.dscalar.nii \
	COLUMN ${OutputFolder}/${Subject}.MyelinMap.${OutputMeshString}.dscalar.nii \
	COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL \
	${OutputFolder}/${Subject}.BiasField${RegNameToUse}.${OutputMeshString}.dscalar.nii \
	-surface-postdilate 40 \
	-left-spheres ${InputFolder}/${Subject}.L.sphere.${InputMeshString}.surf.gii ${OutputFolder}/${Subject}.L.sphere.${OutputRegName}.${OutputMeshString}.surf.gii \
	-left-area-surfs ${InputT1wFolder}/${Subject}.L.midthickness${RegNameToUse}.${InputMeshString}.surf.gii ${OutputT1wFolder}/${Subject}.L.midthickness.${OutputMeshString}.surf.gii \
	-right-spheres ${InputFolder}/${Subject}.R.sphere.${InputMeshString}.surf.gii ${OutputFolder}/${Subject}.R.sphere.${OutputRegName}.${OutputMeshString}.surf.gii \
	-right-area-surfs ${InputT1wFolder}/${Subject}.R.midthickness${RegNameToUse}.${InputMeshString}.surf.gii ${OutputT1wFolder}/${Subject}.R.midthickness.${OutputMeshString}.surf.gii 

# generate bias corrected map in the output mesh space
${Caret7_Command} -cifti-math "Var - Bias" ${OutputFolder}/${Subject}.${OutputBCMapName}_BC${RegNameToUse}.${OutputMeshString}.dscalar.nii \
	-var Var ${OutputFolder}/${Subject}.MyelinMap.${OutputMeshString}.dscalar.nii \
	-var Bias ${OutputFolder}/${Subject}.BiasField${RegNameToUse}.${OutputMeshString}.dscalar.nii
	
log_Msg "Completing main functionality"
