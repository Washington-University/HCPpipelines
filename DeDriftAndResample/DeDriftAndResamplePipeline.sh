#!/bin/bash
set -eu
#
# # DeDriftAndResamplePipeline.sh
#
# ## Copyright Notice
#
# Copyright (C) 2015-2017 The Human Connectome Project
#
# * Washington University in St. Louis
# * University of Minnesota
# * Oxford University
#
# ## Author(s)
#
# * Matthew F. Glasser, Department of Anatomy and Neurobiology, Washington University in St. Louis
# * Timothy B. Brown, Neuroinformatics Research Group, Washington University in St. Louis
#
# ## Product
#
# [Human Connectome Project][HCP] (HCP) Pipelines
#
# ## License
#
# See the [LICENSE](https://github.com/Washington-Univesity/Pipelines/blob/master/LICENSE.md) file
#
# <!-- References -->
# [HCP]: http://www.humanconnectome.org
#
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

#description to use in usage - syntax of parameters is now explained automatically
opts_SetScriptDescription "resamples many types of data after a surface registration"

#mandatory
#general inputs
opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder that contains all subjects" '--path'
opts_AddMandatory '--subject' 'Subject' '100206' "one subject ID"
opts_AddMandatory '--high-res-mesh' 'HighResMesh' 'meshnum' "high resolution mesh node count (in thousands), like '164' for 164k_fs_LR"
opts_AddMandatory '--low-res-meshes' 'LowResMeshes' 'meshnum@meshnum@...' "low resolution mesh node counts (in thousands) delimited by @, like '32@59' for 32k_fs_LR and 59_k_fs_LR"
opts_AddMandatory '--registration-name' 'RegName' 'MSMAll' "the registration string corresponding to the input files, e.g. 'MSMAll_InitalReg'"
opts_AddMandatory '--maps' 'Maps' 'non@myelin@maps' "@-delimited map name strings corresponding to maps that are not myelin maps, e.g. 'sulc@curvature@corrThickness@thickness'"
opts_AddMandatory '--smoothing-fwhm' 'SmoothingFWHM' 'number' "Smoothing FWHM that matches what was used in the fMRISurface pipeline"
opts_AddMandatory '--high-pass' 'HighPass' 'integer' 'the high pass value that was used when running FIX' '--melodic-high-pass' '--highpass'
opts_AddMandatory '--motion-regression' 'MotionRegression' 'TRUE or FALSE' 'whether FIX should do motion regression'
opts_AddMandatory '--myelin-target-file' 'MyelinTargetFile' 'string' "myelin map target file, absolute folder, e.g. 'YourFolder/global/templates/MSMAll/Q1-Q6_RelatedParcellation210.MyelinMap_BC_MSMAll_2_d41_WRN_DeDrift.32k_fs_LR.dscalar.nii'"
# optional inputs
opts_AddOptional '--dedrift-reg-files' 'DeDriftRegFiles' 'string' "</Path/to/File/Left.sphere.surf.gii@/Path/to/File/Right.sphere.surf.gii>] Usually the spheres in global/templates/MSMAll/, defaults to ''." ''
opts_AddOptional '--concat-reg-name' 'OutputRegName' 'MSMAll' "String corresponding to the output name for the dedrifted registration (referred to as the concatenated registration), usually MSMAll. Requires --dedrift-reg-files, defaults to ''." ''
opts_AddOptional '--myelin-maps' 'MyelinMaps' 'non@myelin@maps' "@-delimited map name strings corresponding to myelin maps, e.g. 'MyelinMap@SmoothedMyelinMap'. No _BC, this will be reapplied, defaults to ''." ''
opts_AddOptional '--multirun-fix-names' 'mrFIXNames' 'day1run1@day1run2%day2run1@day2run2' " @ and % delimited list of lists of fMRIName strings that will have multi-run ICA+FIX reapplied to them (could be either rfMRI or tfMRI). Requires specifying --multirun-fix-concat-names also, with same number of concat names as lists of runs in this option, defaults to ''." ''
opts_AddOptional '--multirun-fix-concat-names' 'mrFIXConcatNames' 'day1_concat@day2_concat' "@-delimited list of names of the concatenated timeseries, only required when using --multirun-fix-names, defaults to ''." ''
opts_AddOptional '--multirun-fix-extract-names' 'mrFIXExtractNames' 'day1run1@day1run2%day2run1@day2run2' "@ and % delimited list of lists of fMRIName strings to extract, one list for each multi-run ICA+FIX group in --multirun-fix-names (use a NONE instead of the group's runs and a NONE in --multirun-fix-extract-concat-names to skip this for a group), only required when using --multirun-fix-extract-concat-names.  Exists to enable extraction of a subset of the runs in a multi-run ICA+FIX group into a new concatenated series (which is then named using --multirun-fix-extract-concat-names), defaults to ''." ''
opts_AddOptional '--multirun-fix-extract-concat-names' 'mrFIXExtractConcatNames' 'day1_newconcat@day2_newconcat' "@-delimited list of names of the concatenated timeseries, only required when using --multirun-fix-names.@-delimited list of names for the concatenated extracted timeseries, one for each multi-run ICA+FIX group (i.e. name in --multirun-fix-concat-names; use NONE to skip a group), defaults to ''." ''
opts_AddOptional '--multirun-fix-extract-extra-regnames' 'mrFIXExtractExtraRegNames' 'regname@regname' "extract MR FIX runs for additional surface registrations, e.g. 'MSMSulc', defaults to ''." ''
opts_AddOptional '--multirun-fix-extract-volume' 'mrFIXExtractDoVol' 'TRUE or FALSE' "whether to also extract the specified MR FIX runs from the volume data, requires --multirun-fix-extract-concat-names to work, defaults to 'FALSE'." 'FALSE'
opts_AddOptional '--fix-names' 'fixNames' 'ICA+FIXed@fMRI@Names' "@-delimited fMRIName strings corresponding to maps that will have single-run ICA+FIX reapplied to them (could be either rfMRI or tfMRI). Do not specify runs processed with MR FIX here. Previously known as --rfmri-names, defaults to ''." ''
opts_AddOptional '--dont-fix-names' 'dontFixNames' 'not@ICA+FIXed@fMRI@Names' "@-delimited fMRIName strings corresponding to maps that will not have ICA+FIX reapplied to them (not recommended, MR FIX or at least single-run ICA+FIX is recommended for all fMRI data). Previously known as --tfmri-names, defaults to ''." ''
opts_AddOptional '--input-reg-name' 'InRegName' 'string' "A string to enable multiple fMRI resolutions, e.g. '_1.6mm', defaults to ''." ''
opts_AddOptional '--use-ind-mean' 'UseIndMean' 'YES or NO' "whether to use the mean of the individual myelin map as the group reference map's mean" 'YES'
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
# Show wb_command version
log_Msg "Showing Connectome Workbench (wb_command) version"
${CARET7DIR}/wb_command -version

#display the parsed/default values
opts_ShowValues

if [[ "${OutputRegName}" == "" ]]; then
	OutputRegName="${RegName}"
else
	if [[ "${DeDriftRegFiles}" == "NONE" || "${DeDriftRegFiles}" == "" ]]; then
		log_Err_Abort "--concat-reg-name must not be used unless dedrifting (just remove --concat-reg-name=<whatever> from your command)"
	fi
fi
# ------------------------------------------------------------------------------
#  Main processing of script.
# ------------------------------------------------------------------------------
log_Msg "Starting main functionality"
# boolean values
mrFIXExtractDoVolBool=$(opts_StringToBool "$mrFIXExtractDoVol")
# Naming Conventions and other variables
Caret7_Command="${CARET7DIR}/wb_command"
log_Msg "Caret7_Command: ${Caret7_Command}"

LowResMeshes=`echo ${LowResMeshes} | sed 's/@/ /g'`
log_Msg "After delimiter substitution, LowResMeshes: ${LowResMeshes}"

DeDriftRegFiles=`echo "$DeDriftRegFiles" | sed s/"@"/" "/g`
log_Msg "After delimiter substitution, DeDriftRegFiles: ${DeDriftRegFiles}"

Maps=`echo "$Maps" | sed s/"@"/" "/g`
log_Msg "After delimiter substitution, Maps: ${Maps}"

#these elses result in empty when given the empty string, make NONE do the same
if [[ "${MyelinMaps}" == "NONE" ]] ; then
	MyelinMaps=""
	MyelinMapsArray=()
else
	MyelinMaps=`echo "$MyelinMaps" | sed s/"@"/" "/g`
	IFS=' ' read -a MyelinMapsArray <<< "${MyelinMaps}"
fi
log_Msg "After delimiter substitution, MyelinMaps: ${MyelinMaps}"

if [[ "${fixNames}" == "NONE" ]] ; then
	fixNames=()
else
	#fixNames=`echo "$fixNames" | sed s/"@"/" "/g`
	IFS=@ read -a fixNames <<< "${fixNames}"
fi
log_Msg "After delimiter substitution, fixNames: ${fixNames[*]+${fixNames[*]}}"

if [[ "${dontFixNames}" == "NONE" ]] ; then
	dontFixNames=()
else
	#dontFixNames=`echo "$dontFixNames" | sed s/"@"/" "/g`
	IFS=@ read -a dontFixNames <<< "${dontFixNames}"
fi
log_Msg "After delimiter substitution, dontFixNames: ${dontFixNames[*]+${dontFixNames[*]}}"

if [[ "${mrFIXNames}" == "NONE" ]] ; then
	mrFIXNames=()
else
	#need a flat list of all the names in order to resample - do this before we destroy the original value of the variable
	IFS=@% read -a mrFIXNamesAll <<< "${mrFIXNames}"
	#two-level list, % and @, parse only one stage here
	IFS=% read -a mrFIXNames <<< "${mrFIXNames}"
fi
log_Msg "After delimiter substitution, mrFIXNames: ${mrFIXNames[*]+${mrFIXNames[*]}}"

if [[ "$mrFIXConcatNames" == "NONE" ]]
then
	mrFIXConcatNames=()
else
	IFS=@ read -a mrFIXConcatNames <<< "$mrFIXConcatNames"
fi
log_Msg "After delimiter substitution, mrFIXConcatNames: ${mrFIXConcatNames[*]+${mrFIXConcatNames[*]}}"

if (( ${#mrFIXNames[@]} != ${#mrFIXConcatNames[@]} ))
then
	log_Err_Abort "number of MR FIX concat names and run groups are different"
fi

if [[ "${mrFIXExtractNames}" == "NONE" ]] ; then
	mrFIXExtractNamesArr=()
else
	#two-level list, % and @, parse only one stage here
	IFS=% read -a mrFIXExtractNamesArr <<< "${mrFIXExtractNames}"
fi
log_Msg "After delimiter substitution, mrFIXExtractNamesArr: ${mrFIXExtractNamesArr[*]+${mrFIXExtractNamesArr[*]}}"

if [[ "$mrFIXExtractConcatNames" == "NONE" ]]
then
	mrFIXExtractConcatNamesArr=()
else
	IFS=@ read -a mrFIXExtractConcatNamesArr <<< "$mrFIXExtractConcatNames"
fi
log_Msg "After delimiter substitution, mrFIXExtractConcatNamesArr: ${mrFIXExtractConcatNamesArr[*]+${mrFIXExtractConcatNamesArr[*]}}"

if (( ${#mrFIXExtractNamesArr[@]} != ${#mrFIXExtractConcatNamesArr[@]} ))
then
	log_Err_Abort "number of MR FIX extract concat names and run groups are different (use NONE to skip a group)"
fi

if (( ${#mrFIXExtractConcatNamesArr[@]} > 0 && ${#mrFIXConcatNames[@]} != ${#mrFIXExtractConcatNamesArr[@]} ))
then
	log_Err_Abort "number of MR FIX extract groups doesn't match number of MR FIX groups (use NONE to skip a group)"
fi

if [[ "$mrFIXExtractExtraRegNames" == "NONE" ]]
then
	extractExtraRegNamesArr=()
else
	IFS=@ read -a extractExtraRegNamesArr <<< "$mrFIXExtractExtraRegNames"
fi
log_Msg "After delimiter substitution, extractExtraRegNamesArr: ${extractExtraRegNamesArr[*]+${extractExtraRegNamesArr[*]}}"

if ((mrFIXExtractDoVolBool && ${#mrFIXExtractConcatNamesArr[@]} == 0))
then
	log_Err_Abort "--multirun-fix-extract-volume=TRUE requires --multirun-fix-concat-names"
fi

CorrectionSigma=$(echo "sqrt ( 200 )" | bc -l)
log_Msg "CorrectionSigma: ${CorrectionSigma}"

AtlasFolder="${StudyFolder}/${Subject}/MNINonLinear"
log_Msg "AtlasFolder: ${AtlasFolder}"

T1wFolder="${StudyFolder}/${Subject}/T1w"
log_Msg "T1wFolder: ${T1wFolder}"

NativeFolder="${AtlasFolder}/Native"
log_Msg "NativeFolder: ${NativeFolder}"

NativeT1wFolder="${T1wFolder}/Native"
log_Msg "NativeT1wFolder: ${NativeT1wFolder}"

ResultsFolder="${AtlasFolder}/Results"
log_Msg "ResultsFolder: ${ResultsFolder}"

#Naming Conventions
DownSampleFolderNames=""
DownSampleT1wFolderNames=""
for LowResMesh in ${LowResMeshes} ; do
	DownSampleFolderNames+="${AtlasFolder}/fsaverage_LR${LowResMesh}k "
	DownSampleT1wFolderNames+="${T1wFolder}/fsaverage_LR${LowResMesh}k "
done
log_Msg "DownSampleFolderNames: ${DownSampleFolderNames}"
log_Msg "DownSampleT1wFolderNames: ${DownSampleT1wFolderNames}"

# Concat Reg
log_Msg "Concat Reg"
for Hemisphere in L R ; do
	if [ $Hemisphere = "L" ] ; then 
		Structure="CORTEX_LEFT"
		DeDriftRegFile=`echo ${DeDriftRegFiles} | cut -d " " -f 1`
	elif [ $Hemisphere = "R" ] ; then 
		Structure="CORTEX_RIGHT"
		DeDriftRegFile=`echo ${DeDriftRegFiles} | cut -d " " -f 2`
	fi 

	log_Msg "Hemisphere: ${Hemisphere}"
	log_Msg "Structure: ${Structure}"
	log_Msg "DeDriftRegFile: ${DeDriftRegFile}"

	if [ ! ${RegName} = ${OutputRegName} ] ; then #RegName is already the completed registration, don't overwrite
		${Caret7_Command} -surface-sphere-project-unproject ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii ${AtlasFolder}/${Subject}.${Hemisphere}.sphere.${HighResMesh}k_fs_LR.surf.gii ${DeDriftRegFile} ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${OutputRegName}.native.surf.gii
	fi

	# Make MSM Registration Areal Distortion Maps
	log_Msg "Make MSM Registration Areal Distortion Maps"
	${Caret7_Command} -surface-vertex-areas ${NativeFolder}/${Subject}.${Hemisphere}.sphere.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.native.shape.gii
	${Caret7_Command} -surface-vertex-areas ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${OutputRegName}.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${OutputRegName}.native.shape.gii
	${Caret7_Command} -metric-math "ln(spherereg / sphere) / ln(2)" ${NativeFolder}/${Subject}.${Hemisphere}.ArealDistortion_${OutputRegName}.native.shape.gii -var sphere ${NativeFolder}/${Subject}.${Hemisphere}.sphere.native.shape.gii -var spherereg ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${OutputRegName}.native.shape.gii
	rm ${NativeFolder}/${Subject}.${Hemisphere}.sphere.native.shape.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${OutputRegName}.native.shape.gii

	${Caret7_Command} -surface-distortion ${NativeFolder}/${Subject}.${Hemisphere}.sphere.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${OutputRegName}.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.EdgeDistortion_${OutputRegName}.native.shape.gii -edge-method

	${Caret7_Command} -surface-distortion "${NativeFolder}"/"${Subject}"."${Hemisphere}".sphere.native.surf.gii "${NativeFolder}"/"${Subject}"."${Hemisphere}".sphere.${OutputRegName}.native.surf.gii "${NativeFolder}"/"$Subject"."$Hemisphere".Strain_${OutputRegName}.native.shape.gii -local-affine-method
	${Caret7_Command} -metric-merge "${NativeFolder}"/"$Subject"."$Hemisphere".StrainJ_${OutputRegName}.native.shape.gii -metric "${NativeFolder}"/"$Subject"."$Hemisphere".Strain_${OutputRegName}.native.shape.gii -column 1
	${Caret7_Command} -metric-merge "${NativeFolder}"/"$Subject"."$Hemisphere".StrainR_${OutputRegName}.native.shape.gii -metric "${NativeFolder}"/"$Subject"."$Hemisphere".Strain_${OutputRegName}.native.shape.gii -column 2
	${Caret7_Command} -metric-math "ln(var) / ln (2)" "${NativeFolder}"/"$Subject"."$Hemisphere".StrainJ_${OutputRegName}.native.shape.gii -var var "${NativeFolder}"/"$Subject"."$Hemisphere".StrainJ_${OutputRegName}.native.shape.gii
	${Caret7_Command} -metric-math "ln(var) / ln (2)" "${NativeFolder}"/"$Subject"."$Hemisphere".StrainR_${OutputRegName}.native.shape.gii -var var "${NativeFolder}"/"$Subject"."$Hemisphere".StrainR_${OutputRegName}.native.shape.gii
	rm "${NativeFolder}"/"$Subject"."$Hemisphere".Strain_${OutputRegName}.native.shape.gii
done

${Caret7_Command} -cifti-create-dense-timeseries ${NativeFolder}/${Subject}.ArealDistortion_${OutputRegName}.native.dtseries.nii -left-metric ${NativeFolder}/${Subject}.L.ArealDistortion_${OutputRegName}.native.shape.gii -roi-left ${NativeFolder}/${Subject}.L.atlasroi.native.shape.gii -right-metric ${NativeFolder}/${Subject}.R.ArealDistortion_${OutputRegName}.native.shape.gii -roi-right ${NativeFolder}/${Subject}.R.atlasroi.native.shape.gii
${Caret7_Command} -cifti-convert-to-scalar ${NativeFolder}/${Subject}.ArealDistortion_${OutputRegName}.native.dtseries.nii ROW ${NativeFolder}/${Subject}.ArealDistortion_${OutputRegName}.native.dscalar.nii
${Caret7_Command} -set-map-name ${NativeFolder}/${Subject}.ArealDistortion_${OutputRegName}.native.dscalar.nii 1 ${Subject}_ArealDistortion_${OutputRegName}
${Caret7_Command} -cifti-palette ${NativeFolder}/${Subject}.ArealDistortion_${OutputRegName}.native.dscalar.nii MODE_USER_SCALE ${NativeFolder}/${Subject}.ArealDistortion_${OutputRegName}.native.dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false
rm ${NativeFolder}/${Subject}.ArealDistortion_${OutputRegName}.native.dtseries.nii 

${Caret7_Command} -cifti-create-dense-timeseries ${NativeFolder}/${Subject}.EdgeDistortion_${OutputRegName}.native.dtseries.nii -left-metric ${NativeFolder}/${Subject}.L.EdgeDistortion_${OutputRegName}.native.shape.gii -roi-left ${NativeFolder}/${Subject}.L.atlasroi.native.shape.gii -right-metric ${NativeFolder}/${Subject}.R.EdgeDistortion_${OutputRegName}.native.shape.gii -roi-right ${NativeFolder}/${Subject}.R.atlasroi.native.shape.gii
${Caret7_Command} -cifti-convert-to-scalar ${NativeFolder}/${Subject}.EdgeDistortion_${OutputRegName}.native.dtseries.nii ROW ${NativeFolder}/${Subject}.EdgeDistortion_${OutputRegName}.native.dscalar.nii
${Caret7_Command} -set-map-name ${NativeFolder}/${Subject}.EdgeDistortion_${OutputRegName}.native.dscalar.nii 1 ${Subject}_EdgeDistortion_${OutputRegName}
${Caret7_Command} -cifti-palette ${NativeFolder}/${Subject}.EdgeDistortion_${OutputRegName}.native.dscalar.nii MODE_USER_SCALE ${NativeFolder}/${Subject}.EdgeDistortion_${OutputRegName}.native.dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false
rm ${NativeFolder}/${Subject}.EdgeDistortion_${OutputRegName}.native.dtseries.nii 

${Caret7_Command} -cifti-create-dense-timeseries ${NativeFolder}/${Subject}.StrainJ_${OutputRegName}.native.dtseries.nii -left-metric ${NativeFolder}/${Subject}.L.StrainJ_${OutputRegName}.native.shape.gii -roi-left ${NativeFolder}/${Subject}.L.atlasroi.native.shape.gii -right-metric ${NativeFolder}/${Subject}.R.StrainJ_${OutputRegName}.native.shape.gii -roi-right ${NativeFolder}/${Subject}.R.atlasroi.native.shape.gii
${Caret7_Command} -cifti-convert-to-scalar ${NativeFolder}/${Subject}.StrainJ_${OutputRegName}.native.dtseries.nii ROW ${NativeFolder}/${Subject}.StrainJ_${OutputRegName}.native.dscalar.nii
${Caret7_Command} -set-map-name ${NativeFolder}/${Subject}.StrainJ_${OutputRegName}.native.dscalar.nii 1 ${Subject}_StrainJ_${OutputRegName}
${Caret7_Command} -cifti-palette ${NativeFolder}/${Subject}.StrainJ_${OutputRegName}.native.dscalar.nii MODE_USER_SCALE ${NativeFolder}/${Subject}.StrainJ_${OutputRegName}.native.dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false
rm ${NativeFolder}/${Subject}.StrainJ_${OutputRegName}.native.dtseries.nii

${Caret7_Command} -cifti-create-dense-timeseries ${NativeFolder}/${Subject}.StrainR_${OutputRegName}.native.dtseries.nii -left-metric ${NativeFolder}/${Subject}.L.StrainR_${OutputRegName}.native.shape.gii -roi-left ${NativeFolder}/${Subject}.L.atlasroi.native.shape.gii -right-metric ${NativeFolder}/${Subject}.R.StrainR_${OutputRegName}.native.shape.gii -roi-right ${NativeFolder}/${Subject}.R.atlasroi.native.shape.gii
${Caret7_Command} -cifti-convert-to-scalar ${NativeFolder}/${Subject}.StrainR_${OutputRegName}.native.dtseries.nii ROW ${NativeFolder}/${Subject}.StrainR_${OutputRegName}.native.dscalar.nii
${Caret7_Command} -set-map-name ${NativeFolder}/${Subject}.StrainR_${OutputRegName}.native.dscalar.nii 1 ${Subject}_StrainR_${OutputRegName}
${Caret7_Command} -cifti-palette ${NativeFolder}/${Subject}.StrainR_${OutputRegName}.native.dscalar.nii MODE_USER_SCALE ${NativeFolder}/${Subject}.StrainR_${OutputRegName}.native.dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false
rm ${NativeFolder}/${Subject}.StrainR_${OutputRegName}.native.dtseries.nii

DownSampleFolder=`echo ${DownSampleFolderNames} | cut -d " " -f 1`
log_Msg "DownSampleFolder: ${DownSampleFolder}"

DownSampleT1wFolder=`echo ${DownSampleT1wFolderNames} | cut -d " " -f 1`
log_Msg "DownSampleT1wFolder: ${DownSampleT1wFolder}"

LowResMesh=`echo ${LowResMeshes} | cut -d " " -f 1`
log_Msg "LowResMesh: ${LowResMesh}"

# Supports multiple lowres meshes
log_Msg "Supports multiple lowres meshes"
for Mesh in ${LowResMeshes} ${HighResMesh} ; do
	log_Msg "Working with Mesh: ${Mesh}"

	if [ $Mesh = ${HighResMesh} ] ; then
		Folder=${AtlasFolder}
		Scale="4"
	else 
		i=1
		for LowResMesh in ${LowResMeshes} ; do
			if [ ${LowResMesh} = ${Mesh} ] ; then
				Folder=`echo ${DownSampleFolderNames} | cut -d " " -f ${i}`
				DownSampleT1wFolder=`echo ${DownSampleT1wFolderNames} | cut -d " " -f ${i}`
			fi
			Scale="1"
			i=$(($i+1))
		done
	fi

	if [ -e ${Folder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec ] ; then
		rm ${Folder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec
	fi

	${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec INVALID ${AtlasFolder}/T1w_restore.nii.gz
	${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec INVALID ${AtlasFolder}/T2w_restore.nii.gz

	if [ ! ${Mesh} = ${HighResMesh} ] ; then
		if [ -e ${DownSampleT1wFolder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec ] ; then
			rm ${DownSampleT1wFolder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec
		fi

		${Caret7_Command} -add-to-spec-file ${DownSampleT1wFolder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec INVALID ${T1wFolder}/T1w_acpc_dc_restore.nii.gz
		${Caret7_Command} -add-to-spec-file ${DownSampleT1wFolder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec INVALID ${T1wFolder}/T2w_acpc_dc_restore.nii.gz
	fi

	for Hemisphere in L R ; do
		if [ $Hemisphere = "L" ] ; then 
			Structure="CORTEX_LEFT"
		elif [ $Hemisphere = "R" ] ; then 
			Structure="CORTEX_RIGHT"
		fi
		log_Msg "Hemisphere: ${Hemisphere}"
		log_Msg "Structure: ${Structure}"

		${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${Folder}/${Subject}.${Hemisphere}.sphere.${Mesh}k_fs_LR.surf.gii
		if [ -e ${Folder}/${Subject}.${Hemisphere}.flat.${Mesh}k_fs_LR.surf.gii ] ; then
			${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${Folder}/${Subject}.${Hemisphere}.flat.${Mesh}k_fs_LR.surf.gii
		fi

		# Create downsampled fs_LR spec files.   
		log_Msg "Create downsampled fs_LR spec files."
		for Surface in white midthickness pial ; do
			${Caret7_Command} -surface-resample ${NativeFolder}/${Subject}.${Hemisphere}.${Surface}.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${OutputRegName}.native.surf.gii ${Folder}/${Subject}.${Hemisphere}.sphere.${Mesh}k_fs_LR.surf.gii BARYCENTRIC ${Folder}/${Subject}.${Hemisphere}.${Surface}_${OutputRegName}.${Mesh}k_fs_LR.surf.gii
			${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${Folder}/${Subject}.${Hemisphere}.${Surface}_${OutputRegName}.${Mesh}k_fs_LR.surf.gii
		done

		log_Debug_Msg "0.1"
		anatomical_surface_in=${Folder}/${Subject}.${Hemisphere}.midthickness_${OutputRegName}.${Mesh}k_fs_LR.surf.gii
		log_File_Must_Exist "${anatomical_surface_in}"
		${Caret7_Command} -surface-generate-inflated ${anatomical_surface_in} ${Folder}/${Subject}.${Hemisphere}.inflated_${OutputRegName}.${Mesh}k_fs_LR.surf.gii ${Folder}/${Subject}.${Hemisphere}.very_inflated_${OutputRegName}.${Mesh}k_fs_LR.surf.gii -iterations-scale ${Scale}
		${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${Folder}/${Subject}.${Hemisphere}.inflated_${OutputRegName}.${Mesh}k_fs_LR.surf.gii
		${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${Folder}/${Subject}.${Hemisphere}.very_inflated_${OutputRegName}.${Mesh}k_fs_LR.surf.gii

		if [ ! ${Mesh} = ${HighResMesh} ] ; then
			# Create downsampled fs_LR spec file in structural space.  
			log_Msg "Create downsampled fs_LR spec file in structural space."
			
			for Surface in white midthickness pial ; do
				${Caret7_Command} -surface-resample ${NativeT1wFolder}/${Subject}.${Hemisphere}.${Surface}.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${OutputRegName}.native.surf.gii ${Folder}/${Subject}.${Hemisphere}.sphere.${Mesh}k_fs_LR.surf.gii BARYCENTRIC ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.${Surface}_${OutputRegName}.${Mesh}k_fs_LR.surf.gii
				${Caret7_Command} -add-to-spec-file ${DownSampleT1wFolder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.${Surface}_${OutputRegName}.${Mesh}k_fs_LR.surf.gii
			done

			log_Debug_Msg "0.2"
			anatomical_surface_in=${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_${OutputRegName}.${Mesh}k_fs_LR.surf.gii
			log_File_Must_Exist "${anatomical_surface_in}"
			${Caret7_Command} -surface-generate-inflated ${anatomical_surface_in} ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.inflated_${OutputRegName}.${Mesh}k_fs_LR.surf.gii ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.very_inflated_${OutputRegName}.${Mesh}k_fs_LR.surf.gii -iterations-scale ${Scale}
			${Caret7_Command} -add-to-spec-file ${DownSampleT1wFolder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.inflated_${OutputRegName}.${Mesh}k_fs_LR.surf.gii
			${Caret7_Command} -add-to-spec-file ${DownSampleT1wFolder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.very_inflated_${OutputRegName}.${Mesh}k_fs_LR.surf.gii

			# Compute vertex areas for other analyses
			log_Msg "Create vertex areas for other analyses"

			log_Debug_Msg "0.3"
			surface=${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_${OutputRegName}.${Mesh}k_fs_LR.surf.gii
			log_File_Must_Exist "${surface}"
			${Caret7_Command} -surface-vertex-areas ${surface} ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_${OutputRegName}_va.${Mesh}k_fs_LR.shape.gii 

			${Caret7_Command} -add-to-spec-file ${DownSampleT1wFolder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${Folder}/${Subject}.${Hemisphere}.sphere.${Mesh}k_fs_LR.surf.gii
			if [ -e ${Folder}/${Subject}.${Hemisphere}.flat.${Mesh}k_fs_LR.surf.gii ] ; then
				${Caret7_Command} -add-to-spec-file ${DownSampleT1wFolder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${Folder}/${Subject}.${Hemisphere}.flat.${Mesh}k_fs_LR.surf.gii
			fi
		fi  
	done

	if [ ! ${Mesh} = ${HighResMesh} ] ; then 
		# Normalize vertex areas mean to 1 for other analyses
		log_Msg "Normalize vertex areas mean to 1 for other analyses"
		${Caret7_Command} -cifti-create-dense-scalar ${DownSampleT1wFolder}/${Subject}.midthickness_${OutputRegName}_va.${Mesh}k_fs_LR.dscalar.nii -left-metric ${DownSampleT1wFolder}/${Subject}.L.midthickness_${OutputRegName}_va.${Mesh}k_fs_LR.shape.gii -roi-left ${Folder}/${Subject}.L.atlasroi.${Mesh}k_fs_LR.shape.gii -right-metric ${DownSampleT1wFolder}/${Subject}.R.midthickness_${OutputRegName}_va.${Mesh}k_fs_LR.shape.gii -roi-right ${Folder}/${Subject}.R.atlasroi.${Mesh}k_fs_LR.shape.gii
		VAMean=`${Caret7_Command} -cifti-stats ${DownSampleT1wFolder}/${Subject}.midthickness_${OutputRegName}_va.${Mesh}k_fs_LR.dscalar.nii -reduce MEAN`
		${Caret7_Command} -cifti-math "VA / ${VAMean}" ${DownSampleT1wFolder}/${Subject}.midthickness_${OutputRegName}_va_norm.${Mesh}k_fs_LR.dscalar.nii -var VA ${DownSampleT1wFolder}/${Subject}.midthickness_${OutputRegName}_va.${Mesh}k_fs_LR.dscalar.nii
	fi

	# Resample scalar maps and apply new bias field
	log_Msg "Resample scalar maps and apply new bias field"
	
	BiasFieldComputed=false
	MyelinMapsToUse=""
	# myelin map only loop
	for MyelinMap in ${MyelinMaps} ; do
		if [ "$BiasFieldComputed" = false ]; then
			# ----- Begin moved statements -----
			# Recompute Myelin Map Bias Field Based on Better Registration
			log_Msg "Recompute Myelin Map Bias Field Based on Better Registration"
			log_Debug_Msg "Point 1.1"
			
			# Myelin Map BC using low res
			"$HCPPIPEDIR"/global/scripts/MyelinMap_BC.sh \
				--study-folder="$StudyFolder" \
				--subject="$Subject" \
				--registration-name="$OutputRegName" \
				--use-ind-mean="$UseIndMean" \
				--low-res-mesh="$LowResMesh" \
				--myelin-target-file="$MyelinTargetFile" \
				--map="$MyelinMap"
			# ----- End moved statements -----
			# bias field is computed in the module MyelinMap_BC.sh
			BiasFieldComputed=true
		else
			# bias field in native space is already generated
			# BC the other types of given myelin maps
			${Caret7_Command} -cifti-math "Var - Bias" ${NativeFolder}/${Subject}.${MyelinMap}_BC_${OutputRegName}.native.dscalar.nii -var Var ${NativeFolder}/${Subject}.${MyelinMap}.native.dscalar.nii -var Bias ${NativeFolder}/${Subject}.BiasField_${OutputRegName}.native.dscalar.nii
		fi
		MyelinMapsToUse+="${MyelinMap}_BC "
	done
	
	log_Debug_Msg "Point 2.0"
	for Map in ${Maps} ${MyelinMapsToUse} SphericalDistortion ArealDistortion EdgeDistortion StrainJ StrainR ; do
		log_Msg "Map: ${Map}"

		if [[ ${Map} = "ArealDistortion" || ${Map} = "EdgeDistortion" || ${Map} = "StrainJ" || ${Map} = "StrainR" || ${Map} = "MyelinMap_BC" || ${Map} = "SmoothedMyelinMap_BC" ]] ; then
			NativeMap="${Map}_${OutputRegName}"
		else
			NativeMap="${Map}"
		fi

		log_Debug_Msg "Point 3.0"

		if [ ! ${Mesh} = ${HighResMesh} ] ; then
			${Caret7_Command} -cifti-resample ${NativeFolder}/${Subject}.${NativeMap}.native.dscalar.nii COLUMN ${Folder}/${Subject}.MyelinMap_BC.${Mesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${Folder}/${Subject}.${Map}_${OutputRegName}.${Mesh}k_fs_LR.dscalar.nii -surface-postdilate 30 -left-spheres ${NativeFolder}/${Subject}.L.sphere.${OutputRegName}.native.surf.gii ${Folder}/${Subject}.L.sphere.${Mesh}k_fs_LR.surf.gii -left-area-surfs ${NativeT1wFolder}/${Subject}.L.midthickness.native.surf.gii ${DownSampleT1wFolder}/${Subject}.L.midthickness_${OutputRegName}.${Mesh}k_fs_LR.surf.gii -right-spheres ${NativeFolder}/${Subject}.R.sphere.${OutputRegName}.native.surf.gii ${Folder}/${Subject}.R.sphere.${Mesh}k_fs_LR.surf.gii -right-area-surfs ${NativeT1wFolder}/${Subject}.R.midthickness.native.surf.gii ${DownSampleT1wFolder}/${Subject}.R.midthickness_${OutputRegName}.${Mesh}k_fs_LR.surf.gii
			for MapMap in ${Maps} ${MyelinMapsToUse} ; do
				if [[ ${MapMap} = ${Map} ]] ; then
					${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec INVALID ${Folder}/${Subject}.${Map}_${OutputRegName}.${Mesh}k_fs_LR.dscalar.nii
					${Caret7_Command} -add-to-spec-file ${DownSampleT1wFolder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec INVALID ${Folder}/${Subject}.${Map}_${OutputRegName}.${Mesh}k_fs_LR.dscalar.nii
				fi
			done
		else
			${Caret7_Command} -cifti-resample ${NativeFolder}/${Subject}.${NativeMap}.native.dscalar.nii COLUMN ${Folder}/${Subject}.MyelinMap_BC.${Mesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${Folder}/${Subject}.${Map}_${OutputRegName}.${Mesh}k_fs_LR.dscalar.nii -surface-postdilate 30 -left-spheres ${NativeFolder}/${Subject}.L.sphere.${OutputRegName}.native.surf.gii ${Folder}/${Subject}.L.sphere.${Mesh}k_fs_LR.surf.gii -left-area-surfs ${NativeT1wFolder}/${Subject}.L.midthickness.native.surf.gii ${Folder}/${Subject}.L.midthickness_${OutputRegName}.${Mesh}k_fs_LR.surf.gii -right-spheres ${NativeFolder}/${Subject}.R.sphere.${OutputRegName}.native.surf.gii ${Folder}/${Subject}.R.sphere.${Mesh}k_fs_LR.surf.gii -right-area-surfs ${NativeT1wFolder}/${Subject}.R.midthickness.native.surf.gii ${Folder}/${Subject}.R.midthickness_${OutputRegName}.${Mesh}k_fs_LR.surf.gii   
			for MapMap in ${Maps} ${MyelinMapsToUse} ; do
				if [[ ${MapMap} = ${Map} ]] ; then
					${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${OutputRegName}.${Mesh}k_fs_LR.wb.spec INVALID ${Folder}/${Subject}.${Map}_${OutputRegName}.${Mesh}k_fs_LR.dscalar.nii
				fi
			done
		fi
		log_Debug_Msg "Point 4.0"
	done
	log_Debug_Msg "Point 5.0"
done

log_Debug_Msg "Point 6.0"

for Map in ${MyelinMaps} ; do
	log_Debug_Msg "Point 6.1"
	${Caret7_Command} -add-to-spec-file ${NativeFolder}/${Subject}.native.wb.spec INVALID ${NativeFolder}/${Subject}.${Map}_BC_${OutputRegName}.native.dscalar.nii
	log_Debug_Msg "Point 6.2"
	${Caret7_Command} -add-to-spec-file ${NativeT1wFolder}/${Subject}.native.wb.spec INVALID ${NativeFolder}/${Subject}.${Map}_BC_${OutputRegName}.native.dscalar.nii
	log_Debug_Msg "Point 6.3"
done

log_Debug_Msg "Point 7.0"

# Set Variables (Does not support multiple resolution meshes):
DownSampleFolder=`echo ${DownSampleFolderNames} | cut -d " " -f 1`
DownSampleT1wFolder=`echo ${DownSampleT1wFolderNames} | cut -d " " -f 1`
LowResMesh=`echo ${LowResMeshes} | cut -d " " -f 1`

# Resample (and resmooth) TS from Native 
log_Msg "Resample (and resmooth) TS from Native"
for fMRIName in ${fixNames[@]+"${fixNames[@]}"} ${dontFixNames[@]+"${dontFixNames[@]}"} ${mrFIXNamesAll[@]+"${mrFIXNamesAll[@]}"} ; do
	log_Msg "fMRIName: ${fMRIName}"
	cp ${ResultsFolder}/${fMRIName}/${fMRIName}_Atlas${InRegName}.dtseries.nii ${ResultsFolder}/${fMRIName}/${fMRIName}_Atlas_${OutputRegName}.dtseries.nii
	for Hemisphere in L R ; do
		if [ $Hemisphere = "L" ] ; then 
			Structure="CORTEX_LEFT"
		elif [ $Hemisphere = "R" ] ; then 
			Structure="CORTEX_RIGHT"
		fi 

		log_Msg "Hemisphere: ${Hemisphere}"
		log_Msg "Structure: ${Structure}"

		${Caret7_Command} -metric-resample ${ResultsFolder}/${fMRIName}/${fMRIName}.${Hemisphere}.native.func.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${OutputRegName}.native.surf.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii ADAP_BARY_AREA ${ResultsFolder}/${fMRIName}/${fMRIName}_${OutputRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii -area-surfs ${NativeT1wFolder}/${Subject}.${Hemisphere}.midthickness.native.surf.gii ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_${OutputRegName}.${LowResMesh}k_fs_LR.surf.gii -current-roi ${NativeFolder}/${Subject}.${Hemisphere}.roi.native.shape.gii
		${Caret7_Command} -metric-dilate ${ResultsFolder}/${fMRIName}/${fMRIName}_${OutputRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_${OutputRegName}.${LowResMesh}k_fs_LR.surf.gii 30 ${ResultsFolder}/${fMRIName}/${fMRIName}_${OutputRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii -nearest
		${Caret7_Command} -metric-mask ${ResultsFolder}/${fMRIName}/${fMRIName}_${OutputRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii ${ResultsFolder}/${fMRIName}/${fMRIName}_${OutputRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii
		Sigma=`echo "$SmoothingFWHM / (2 * sqrt(2 * l(2)))" | bc -l`
		${Caret7_Command} -metric-smoothing ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_${OutputRegName}.${LowResMesh}k_fs_LR.surf.gii ${ResultsFolder}/${fMRIName}/${fMRIName}_${OutputRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii ${Sigma} ${ResultsFolder}/${fMRIName}/${fMRIName}_s${SmoothingFWHM}_${OutputRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii -roi ${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii
		${Caret7_Command} -cifti-replace-structure ${ResultsFolder}/${fMRIName}/${fMRIName}_Atlas_${OutputRegName}.dtseries.nii COLUMN -metric ${Structure} ${ResultsFolder}/${fMRIName}/${fMRIName}_s${SmoothingFWHM}_${OutputRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii
	done
done

# ReApply FIX Cleanup
log_Msg "ReApply FIX Cleanup"
log_Msg "fixNames: ${fixNames[*]+${fixNames[*]}}"
for fMRIName in ${fixNames[@]+"${fixNames[@]}"} ; do
	log_Msg "fMRIName: ${fMRIName}"
	reapply_fix_cmd=("${HCPPIPEDIR}/ICAFIX/ReApplyFixPipeline.sh" --path="${StudyFolder}" --subject="${Subject}" --fmri-name="${fMRIName}" --high-pass="${HighPass}" --reg-name="${OutputRegName}" --matlab-run-mode="${MatlabRunMode}" --motion-regression="${MotionRegression}")
	log_Msg "reapply_fix_cmd: ${reapply_fix_cmd[*]}"
	"${reapply_fix_cmd[@]}"
done

# reapply multirun fix
for (( i = 0; i < ${#mrFIXConcatNames[@]}; ++i ))
do
	log_Msg "ReApply MultiRun FIX Cleanup"
	log_Msg "mrFIXNames: ${mrFIXNames[$i]}"
	log_Msg "mrFIXConcatNames: ${mrFIXConcatNames[$i]}"
	#stage 2 parsing is done by reapply script
	reapply_mr_fix_cmd=("${HCPPIPEDIR}/ICAFIX/ReApplyFixMultiRunPipeline.sh" --path="${StudyFolder}" --subject="${Subject}" --fmri-names="${mrFIXNames[$i]}" --concat-fmri-name="${mrFIXConcatNames[$i]}" --high-pass="${HighPass}" --reg-name="${OutputRegName}" --matlab-run-mode="${MatlabRunMode}" --motion-regression="${MotionRegression}")
	log_Msg "reapply_mr_fix_cmd: ${reapply_mr_fix_cmd[*]}"
	"${reapply_mr_fix_cmd[@]}"

	for regname in "$OutputRegName" ${extractExtraRegNamesArr[@]+"${extractExtraRegNamesArr[@]}"}
	do
		#MSMSulc special naming convention
		if [[ "$regname" == "MSMSulc" ]]
		then
			regname=""
			regstring=""
		else
			regstring=_"$regname"
		fi
		
		extract_cmd=("${HCPPIPEDIR}/global/scripts/ExtractFromMRFIXConcat.sh"
			            --study-folder="$StudyFolder"
			            --subject="$Subject"
			            --multirun-fix-names="${mrFIXNames[$i]}"
			            --csv-out="$StudyFolder/$Subject/MNINonLinear/Results/${mrFIXConcatNames[$i]}/${mrFIXConcatNames[$i]}_Runs.csv"
			            --concat-cifti-input="$StudyFolder/$Subject/MNINonLinear/Results/${mrFIXConcatNames[$i]}/${mrFIXConcatNames[$i]}_Atlas${regstring}_hp${HighPass}_clean.dtseries.nii"
			            --surf-reg-name="$regname")
		
		if (( ${#mrFIXExtractConcatNamesArr[@]} > 0 )) && [[ "${mrFIXExtractConcatNamesArr[$i]}" != NONE && "${mrFIXExtractConcatNamesArr[$i]}" != "" ]]
		then
			mkdir -p "$StudyFolder/$Subject/MNINonLinear/Results/${mrFIXExtractConcatNamesArr[$i]}"
			
			# Using clean_vn.dscalar.nii estimated from the full concat group for the extracted concat group as well.
			# (i.e., estimate for the variance normalization map is based on the full concat group, not
			#  the subset of extracted scans)
			
			# The per-run differences in (unstructured) noise variance were removed before concatenation.
			# The average of those maps (across runs) was multiplied back into the concatenated time series
			#  (in 'hcp_fix_multi_run'), so that the entire concatenated time series has a spatial pattern of
			#  unstructured noise consistent with the average across runs.
			# Given this manner of constructing the concatenated time series, any subset of runs extracted from
			#  the full concatenated set should use this same average map for later variance normalization.
			# We use the "clean_vn" map for this purpose and thus copy it from the full concatenated set to the
			#  extracted set of runs.
			# As a final subtlety, note that the "clean_vn" map itself is not identical to the aforementioned average of
			#  the individual run vn maps, but it is conceptually very similar. In particular, clean_vn is derived within
			#  FIX itself from the concatenated time series by regressing out all structured signals and using the
			#  residual to estimate the unstructured noise, whereas the individual run vn maps were computed using
			#  PCA-based reconstruction of the unstructured noise in 'icaDim.m'.
			
			cp "$StudyFolder/$Subject/MNINonLinear/Results/${mrFIXConcatNames[$i]}/${mrFIXConcatNames[$i]}_Atlas${regstring}_hp${HighPass}_clean_vn.dscalar.nii" \
			    "$StudyFolder/$Subject/MNINonLinear/Results/${mrFIXExtractConcatNamesArr[$i]}/${mrFIXExtractConcatNamesArr[$i]}_Atlas${regstring}_hp${HighPass}_clean_vn.dscalar.nii"
			
			extract_cmd+=(--multirun-fix-names-to-use="${mrFIXExtractNamesArr[$i]}"
			              --cifti-out="$StudyFolder/$Subject/MNINonLinear/Results/${mrFIXExtractConcatNamesArr[$i]}/${mrFIXExtractConcatNamesArr[$i]}_Atlas${regstring}_hp${HighPass}_clean.dtseries.nii")
		fi
		
		"${extract_cmd[@]}"
	done

	if ((mrFIXExtractDoVolBool))
	then
		# Using clean_vn.nii.gz estimated from the full concat group for the extracted concat group as well.
		cp "$StudyFolder/$Subject/MNINonLinear/Results/${mrFIXConcatNames[$i]}/${mrFIXConcatNames[$i]}_hp${HighPass}_clean_vn.nii.gz" \
		    "$StudyFolder/$Subject/MNINonLinear/Results/${mrFIXExtractConcatNamesArr[$i]}/${mrFIXExtractConcatNamesArr[$i]}_hp${HighPass}_clean_vn.nii.gz"
		
		extract_cmd=("${HCPPIPEDIR}/global/scripts/ExtractFromMRFIXConcat.sh"
		                --study-folder="$StudyFolder"
		                --subject="$Subject"
		                --multirun-fix-names="${mrFIXNames[$i]}"
		                --multirun-fix-names-to-use="${mrFIXExtractNamesArr[$i]}"
		                --volume-out="$StudyFolder/$Subject/MNINonLinear/Results/${mrFIXExtractConcatNamesArr[$i]}/${mrFIXExtractConcatNamesArr[$i]}_hp${HighPass}_clean.nii.gz"
		                --concat-volume-input="$StudyFolder/$Subject/MNINonLinear/Results/${mrFIXConcatNames[$i]}/${mrFIXConcatNames[$i]}_hp${HighPass}_clean.nii.gz")
		
		"${extract_cmd[@]}"
	fi
done

log_Msg "Completing main functionality"
