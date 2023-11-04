#!/bin/bash

# ------------------------------------------------------------------------------
#  Show usage information for this script
# ------------------------------------------------------------------------------

set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

# Load function libraries
source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"

opts_SetScriptDescription "MSM Remove Group Drift - Compute Group Registration Drift"

#ARE THESE DESCRIPTIONS OK?????
opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "path to study folder"

opts_AddMandatory '--subject-list' 'Subjlist' 'list' "@ delimited list of subject ids"

opts_AddMandatory '--group-folder' 'CommonFolder' 'path' "group-average folder" "--common-folder"

opts_AddMandatory '--group-average-name' 'GroupAverageName' 'name' "output group average name (e.g. S900)"

opts_AddMandatory '--input-registration-name' 'InRegName' 'string' "Name of the input registration (e.g. MSMSulc)"

opts_AddMandatory '--target-registration-name' 'TargetRegName' 'string' "Name of the target registration (e.g. MSMAll)"

opts_AddMandatory '--registration-name' 'RegName' 'string' "Name of the registration (e.g. MSMAll)"

opts_AddMandatory '--high-res-mesh' 'HighResMesh' 'numstring' "representing the highres mesh (e.g. 164)"

opts_AddMandatory '--low-res-meshes' 'LowResMesh' 'numstring' "representing the low res mesh (@ delimited list) (e.g. 32)"

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

log_Check_Env_Var CARET7DIR

Subjlist=${Subjlist//@/ }
log_Msg "Subjlist: ${Subjlist}"

CommonAtlasFolder="${CommonFolder}/MNINonLinear"
log_Msg "CommonAtlasFolder: ${CommonAtlasFolder}"

#CommonDownSampleFolder="${CommonAtlasFolder}/fsaverage_LR${LowResMesh}k"
#log_Msg "CommonDownSampleFolder: ${CommonDownSampleFolder}"

if [ ! -e ${CommonAtlasFolder}/${RegName} ] ; then
	mkdir -p ${CommonAtlasFolder}/${RegName}
else
	rm -r ${CommonAtlasFolder:?}/${RegName}
	mkdir -p ${CommonAtlasFolder}/${RegName}
fi

for Hemisphere in L R ; do

	log_Msg "Working on hemisphere: ${Hemisphere}"

	if [ $Hemisphere = "L" ] ; then
		Structure="CORTEX_LEFT"
	elif [ $Hemisphere = "R" ] ; then
		Structure="CORTEX_RIGHT"
	fi
	SurfAverageSTRING=""

	for Subject in ${Subjlist} ; do
		log_Msg "Working on subject: ${Subject}"

		AtlasFolder="${StudyFolder}/${Subject}/MNINonLinear"
		log_Msg "AtlasFolder: ${AtlasFolder}"
		NativeFolder="${AtlasFolder}/Native"
		log_Msg "NativeFolder: ${NativeFolder}"

		sphere_in="${AtlasFolder}/${Subject}.${Hemisphere}.sphere.${HighResMesh}k_fs_LR.surf.gii"
		log_File_Must_Exist "${sphere_in}"

		sphere_project_to="${NativeFolder}/${Subject}.${Hemisphere}.sphere.${InRegName}.native.surf.gii"
		log_File_Must_Exist "${sphere_project_to}"

		sphere_unproject_from="${NativeFolder}/${Subject}.${Hemisphere}.sphere.${TargetRegName}.native.surf.gii"
		log_File_Must_Exist "${sphere_unproject_from}"

		sphere_out="${AtlasFolder}/${Subject}.${Hemisphere}.sphere.${InRegName}_${TargetRegName}.${HighResMesh}k_fs_LR.surf.gii"
		log_Msg "sphere_out: ${sphere_out}"

		${Caret7_Command} -surface-sphere-project-unproject ${sphere_in} ${sphere_project_to} ${sphere_unproject_from} ${sphere_out}

		log_File_Must_Exist "${sphere_out}"

		# Note: Surface files are specified in the SurfAverageSTRING using relative paths from the ${StudyFolder}.
		# This is to save characters to stave off the point at which we've created a command line for the
		# -surface-average operation (done right after we exit this loop) that is longer than a command
		# line is allowed to be. (Use the command $ getconf ARG_MAX to find out what the maximum command
		# line length is.)

		#SurfAverageSTRING=`echo "${SurfAverageSTRING} -surf ${AtlasFolder}/${Subject}.${Hemisphere}.sphere.${InRegName}_${TargetRegName}.${HighResMesh}k_fs_LR.surf.gii"`
		SurfAverageSTRING+=" -surf ${Subject}/MNINonLinear/${Subject}.${Hemisphere}.sphere.${InRegName}_${TargetRegName}.${HighResMesh}k_fs_LR.surf.gii"

		log_Msg "SurfAverageSTRING: ${SurfAverageSTRING}"
		#log_Msg "Length of SurfAverageSTRING: ${#SurfAverageSTRING}"
	done

	# Put ourselves "in" the ${StudyFolder} so that we can use relative paths to save characters in the following command
	pushd ${StudyFolder}
	surface_average_cmd="${Caret7_Command} -surface-average "
	surface_average_cmd+="${CommonAtlasFolder}/${RegName}/${GroupAverageName}.${Hemisphere}.sphere.${RegName}.${HighResMesh}k_fs_LR.surf.gii "
	surface_average_cmd+="${SurfAverageSTRING}"

	max_cmd_length=$(getconf ARG_MAX)
	if [ ${#surface_average_cmd} -gt ${max_cmd_length} ] ; then
		log_Err_Abort "Command will be too long to execute. Command: ${surface_average_cmd}."
	fi

	${surface_average_cmd}

	# Don't forget to pop back to whatever directory we were previously in.
	popd

	${Caret7_Command} -surface-modify-sphere \
		${CommonAtlasFolder}/${RegName}/${GroupAverageName}.${Hemisphere}.sphere.${RegName}.${HighResMesh}k_fs_LR.surf.gii \
		100 \
		${CommonAtlasFolder}/${RegName}/${GroupAverageName}.${Hemisphere}.sphere.${RegName}.${HighResMesh}k_fs_LR.surf.gii \
		-recenter

	cp \
		${CommonAtlasFolder}/${RegName}/${GroupAverageName}.${Hemisphere}.sphere.${RegName}.${HighResMesh}k_fs_LR.surf.gii \
		${CommonAtlasFolder}/${GroupAverageName}.${Hemisphere}.sphere.${RegName}.${HighResMesh}k_fs_LR.surf.gii

	if [ ! -e ${CommonAtlasFolder}/${GroupAverageName}.${Hemisphere}.sphere.${HighResMesh}k_fs_LR.surf.gii ] ; then
		cp \
			${AtlasFolder}/${Subject}.${Hemisphere}.sphere.${HighResMesh}k_fs_LR.surf.gii \
			${CommonAtlasFolder}/${GroupAverageName}.${Hemisphere}.sphere.${HighResMesh}k_fs_LR.surf.gii
	fi

	${Caret7_Command} -surface-vertex-areas \
		${CommonAtlasFolder}/${GroupAverageName}.${Hemisphere}.sphere.${HighResMesh}k_fs_LR.surf.gii \
		${CommonAtlasFolder}/${GroupAverageName}.${Hemisphere}.sphere.${HighResMesh}k_fs_LR.shape.gii

	${Caret7_Command} -surface-vertex-areas \
		${CommonAtlasFolder}/${GroupAverageName}.${Hemisphere}.sphere.${RegName}.${HighResMesh}k_fs_LR.surf.gii \
		${CommonAtlasFolder}/${GroupAverageName}.${Hemisphere}.sphere.${RegName}.${HighResMesh}k_fs_LR.shape.gii

	${Caret7_Command} -metric-math "ln(spherereg / sphere) / ln(2)" \
		${CommonAtlasFolder}/${GroupAverageName}.${Hemisphere}.ArealDistortion_${RegName}.${HighResMesh}k_fs_LR.shape.gii \
		-var sphere ${CommonAtlasFolder}/${GroupAverageName}.${Hemisphere}.sphere.${HighResMesh}k_fs_LR.shape.gii \
		-var spherereg ${CommonAtlasFolder}/${GroupAverageName}.${Hemisphere}.sphere.${RegName}.${HighResMesh}k_fs_LR.shape.gii

	rm \
		${CommonAtlasFolder}/${GroupAverageName}.${Hemisphere}.sphere.${HighResMesh}k_fs_LR.shape.gii \
		${CommonAtlasFolder}/${GroupAverageName}.${Hemisphere}.sphere.${RegName}.${HighResMesh}k_fs_LR.shape.gii

	${Caret7_Command} -surface-distortion \
		${CommonAtlasFolder}/${GroupAverageName}.${Hemisphere}.sphere.${HighResMesh}k_fs_LR.surf.gii \
		${CommonAtlasFolder}/${GroupAverageName}.${Hemisphere}.sphere.${RegName}.${HighResMesh}k_fs_LR.surf.gii \
		${CommonAtlasFolder}/${GroupAverageName}.${Hemisphere}.EdgeDistortion_${RegName}.${HighResMesh}k_fs_LR.shape.gii \
		-edge-method

done

# Copy Atlas ROI files
for Hemisphere in L R ; do
	cp \
		${HCPPIPEDIR}/global/templates/standard_mesh_atlases/${Hemisphere}.atlasroi.${HighResMesh}k_fs_LR.shape.gii \
		${CommonAtlasFolder}/${GroupAverageName}.${Hemisphere}.atlasroi.${HighResMesh}k_fs_LR.shape.gii
done

# ------------------------------
#  Create dense timeseries
# ------------------------------
cifti_out="${CommonAtlasFolder}/${GroupAverageName}.ArealDistortion_${RegName}.${HighResMesh}k_fs_LR.dtseries.nii"
left_metric="${CommonAtlasFolder}/${GroupAverageName}.L.ArealDistortion_${RegName}.${HighResMesh}k_fs_LR.shape.gii"
roi_left="${CommonAtlasFolder}/${GroupAverageName}.L.atlasroi.${HighResMesh}k_fs_LR.shape.gii"
right_metric="${CommonAtlasFolder}/${GroupAverageName}.R.ArealDistortion_${RegName}.${HighResMesh}k_fs_LR.shape.gii"
roi_right="${CommonAtlasFolder}/${GroupAverageName}.R.atlasroi.${HighResMesh}k_fs_LR.shape.gii"

log_Msg "About to create ArealDistortion dense timeseries: ${cifti_out}"

log_File_Must_Exist "${left_metric}"
log_File_Must_Exist "${roi_left}"
log_File_Must_Exist "${right_metric}"
log_File_Must_Exist "${roi_right}"

${Caret7_Command} -cifti-create-dense-timeseries ${cifti_out} -left-metric ${left_metric} -roi-left ${roi_left} -right-metric ${right_metric} -roi-right ${roi_right}

# ------------------------------
#  Create dscalar file from dense timeseries
# ------------------------------
cifti_in="${CommonAtlasFolder}/${GroupAverageName}.ArealDistortion_${RegName}.${HighResMesh}k_fs_LR.dtseries.nii"
direction="ROW"
cifti_out="${CommonAtlasFolder}/${GroupAverageName}.ArealDistortion_${RegName}.${HighResMesh}k_fs_LR.dscalar.nii"

log_Msg "About to create ArealDistortion dscalar file: ${cifti_out}"
log_File_Must_Exist "${cifti_in}"

${Caret7_Command} -cifti-convert-to-scalar ${cifti_in} ${direction} ${cifti_out}

# ------------------------------
#  Set map name for dscalar file
# ------------------------------
data_file="${CommonAtlasFolder}/${GroupAverageName}.ArealDistortion_${RegName}.${HighResMesh}k_fs_LR.dscalar.nii"
index="1"
name="${GroupAverageName}_ArealDistortion_${RegName}"

log_Msg "About to set map name for ArealDistortion dscalar file: ${data_file}"
log_File_Must_Exist "${data_file}"

${Caret7_Command} -set-map-name ${data_file} ${index} ${name}

# ------------------------------
#  Set palette for dscalar file
# ------------------------------
cifti_in="${CommonAtlasFolder}/${GroupAverageName}.ArealDistortion_${RegName}.${HighResMesh}k_fs_LR.dscalar.nii"
mode="MODE_USER_SCALE"
cifti_out="${CommonAtlasFolder}/${GroupAverageName}.ArealDistortion_${RegName}.${HighResMesh}k_fs_LR.dscalar.nii"

log_Msg "About to set palette for ArealDistortion dscalar file: ${cifti_in}"
log_File_Must_Exist "${cifti_in}"

${Caret7_Command} -cifti-palette ${cifti_in} ${mode} ${cifti_out} \
	-pos-user 0 1 \
	-neg-user 0 -1 \
	-interpolate true \
	-palette-name ROY-BIG-BL \
	-disp-pos true \
	-disp-neg true \
	-disp-zero false

# ------------------------------
#  Remove dense timeseries file
# ------------------------------
file_to_remove="${CommonAtlasFolder}/${GroupAverageName}.ArealDistortion_${RegName}.${HighResMesh}k_fs_LR.dtseries.nii"

log_Msg "About to remove ArealDistortion dense timeseries file: ${file_to_remove}"

rm ${file_to_remove}

# ------------------------------
#  Create dense timeseries
# ------------------------------
cifti_out="${CommonAtlasFolder}/${GroupAverageName}.EdgeDistortion_${RegName}.${HighResMesh}k_fs_LR.dtseries.nii"
left_metric="${CommonAtlasFolder}/${GroupAverageName}.L.EdgeDistortion_${RegName}.${HighResMesh}k_fs_LR.shape.gii"
roi_left="${CommonAtlasFolder}/${GroupAverageName}.L.atlasroi.${HighResMesh}k_fs_LR.shape.gii"
right_metric="${CommonAtlasFolder}/${GroupAverageName}.R.EdgeDistortion_${RegName}.${HighResMesh}k_fs_LR.shape.gii"
roi_right="${CommonAtlasFolder}/${GroupAverageName}.R.atlasroi.${HighResMesh}k_fs_LR.shape.gii"

log_Msg "About to create EdgeDistortion dense timeseries: ${cifti_out}"

log_File_Must_Exist "${left_metric}"
log_File_Must_Exist "${roi_left}"
log_File_Must_Exist "${right_metric}"
log_File_Must_Exist "${roi_right}"

${Caret7_Command} -cifti-create-dense-timeseries ${cifti_out} -left-metric ${left_metric} -roi-left ${roi_left} -right-metric ${right_metric} -roi-right ${roi_right}

# ------------------------------
#  Create dscalar file from dense timeseries
# ------------------------------
cifti_in="${CommonAtlasFolder}/${GroupAverageName}.EdgeDistortion_${RegName}.${HighResMesh}k_fs_LR.dtseries.nii"
direction="ROW"
cifti_out="${CommonAtlasFolder}/${GroupAverageName}.EdgeDistortion_${RegName}.${HighResMesh}k_fs_LR.dscalar.nii"

log_Msg "About to create EdgeDistortion dscalar file: ${cifti_out}"
log_File_Must_Exist "${cifti_in}"

${Caret7_Command} -cifti-convert-to-scalar ${cifti_in} ${direction} ${cifti_out}

# ------------------------------
#  Set map name for dscalar file
# ------------------------------
data_file="${CommonAtlasFolder}/${GroupAverageName}.EdgeDistortion_${RegName}.${HighResMesh}k_fs_LR.dscalar.nii"
index="1"
name="${GroupAverageName}_EdgeDistortion_${RegName}"

log_Msg "About to set map name for EdgeDistortion dscalar file: ${data_file}"
log_File_Must_Exist "${data_file}"

${Caret7_Command} -set-map-name ${data_file} ${index} ${name}

# ------------------------------
#  Set palette for dscalar file
# ------------------------------
cifti_in="${CommonAtlasFolder}/${GroupAverageName}.EdgeDistortion_${RegName}.${HighResMesh}k_fs_LR.dscalar.nii"
mode="MODE_USER_SCALE"
cifti_out="${CommonAtlasFolder}/${GroupAverageName}.EdgeDistortion_${RegName}.${HighResMesh}k_fs_LR.dscalar.nii"

log_Msg "About to set palette for EdgeDistortion dscalar file: ${cifti_in}"
log_File_Must_Exist "${cifti_in}"

${Caret7_Command} -cifti-palette ${cifti_in} ${mode} ${cifti_out} \
	-pos-user 0 1 \
	-neg-user 0 -1 \
	-interpolate true \
	-palette-name ROY-BIG-BL \
	-disp-pos true \
	-disp-neg true \
	-disp-zero false

# ------------------------------
#  Remove dense timeseries file
# ------------------------------
file_to_remove="${CommonAtlasFolder}/${GroupAverageName}.EdgeDistortion_${RegName}.${HighResMesh}k_fs_LR.dtseries.nii"

log_Msg "About to remove EdgeDistortion dense timeseries file: ${file_to_remove}"

rm ${file_to_remove}


#for Mesh in ${LowResMesh} ; do
#  Folder=${CommonDownSampleFolder}
#  for Map in ArealDistortion EdgeDistortion sulc ; do
#    if [[ ${Map} = "ArealDistortion" || ${Map} = "EdgeDistortion" ]] ; then
#      NativeMap="${Map}_${RegName}"
#    else
#      NativeMap="${Map}"
#    fi
#    ${Caret7_Command} -cifti-resample ${CommonAtlasFolder}/${GroupAverageName}.${NativeMap}.${HighResMesh}k_fs_LR.dscalar.nii COLUMN ${Folder}/${GroupAverageName}.thickness.${Mesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${Folder}/${GroupAverageName}.${Map}_${RegName}.${Mesh}k_fs_LR.dscalar.nii -surface-postdilate 30 -left-spheres ${CommonAtlasFolder}/${GroupAverageName}.L.sphere.${RegName}.${HighResMesh}k_fs_LR.surf.gii ${Folder}/${GroupAverageName}.L.sphere.${Mesh}k_fs_LR.surf.gii -left-area-surfs ${CommonAtlasFolder}/${GroupAverageName}.L.midthickness.${HighResMesh}k_fs_LR.surf.gii ${Folder}/${GroupAverageName}.L.midthickness.${Mesh}k_fs_LR.surf.gii -right-spheres ${CommonAtlasFolder}/${GroupAverageName}.R.sphere.${RegName}.${HighResMesh}k_fs_LR.surf.gii ${Folder}/${GroupAverageName}.R.sphere.${Mesh}k_fs_LR.surf.gii -right-area-surfs ${CommonAtlasFolder}/${GroupAverageName}.R.midthickness.${HighResMesh}k_fs_LR.surf.gii ${Folder}/${GroupAverageName}.R.midthickness.${Mesh}k_fs_LR.surf.gii
#  done
#done
