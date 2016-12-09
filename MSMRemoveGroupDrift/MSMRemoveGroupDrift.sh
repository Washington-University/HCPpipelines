#!/bin/bash

# ------------------------------------------------------------------------------
#  Code Start
# ------------------------------------------------------------------------------

# If any commands exit with non-zero value, this script exits
set -e
g_script_name=`basename ${0}`

# ------------------------------------------------------------------------------
#  Load function libraries
# ------------------------------------------------------------------------------

source ${HCPPIPEDIR}/global/scripts/log.shlib # Logging related functions
log_SetToolName "${g_script_name}"

#
# Function Description:
#  Show usage information for this script
#
usage()
{
	echo ""
	echo "  MSM Remove Group Drift - Compute Group Registration Drift"
	echo ""
	echo "  Usage: ${g_script_name} <options>"
	echo ""
	echo "  Options: [ ] = optional; < > = user supplied value"
	echo ""
	echo "   [--help] : show usage information and exit"
	echo " "
	echo "  TBW "
	echo " "
	echo ""
}

#
# Function Description:
#  Get the command line options for this script.
#  Shows usage information and exits if command line is malformed
#
get_options()
{
	local arguments=($@)

	# initialize global output variables
	unset g_path_to_study_folder     # StudyFolder
	unset g_subject_list             # Subjlist
	unset g_common_folder            # CommonFolder
	unset g_group_average_name       # GroupAverageName
	unset g_input_registration_name  # InRegName
	unset g_target_registration_name # TargetRegName
	unset g_registration_name        # RegName
	unset g_high_res_mesh            # HighResMesh
	unset g_low_res_mesh             # LowResMesh

	# parse arguments
	local num_args=${#arguments[@]}
	local argument
	local index=0

	while [ ${index} -lt ${num_args} ]; do
		argument=${arguments[index]}

		case ${argument} in
			--help)
				usage
				exit 1
				;;
			--path=*)
				g_path_to_study_folder=${argument#*=}
				index=$(( index + 1 ))
				;;
			--study-folder=*)
				g_path_to_study_folder=${argument#*=}
				index=$(( index + 1 ))
				;;
			--subject-list=*)
				g_subject_list=${argument#*=}
				index=$(( index + 1 ))
				;;
			--common-folder=*)
				g_common_folder=${argument#*=}
				index=$(( index + 1 ))
				;;
			--group-average-name=*)
				g_group_average_name=${argument#*=}
				index=$(( index + 1 ))
				;;
			--input-registration-name=*)
				g_input_registration_name=${argument#*=}
				index=$(( index + 1 ))
				;;
			--target-registration-name=*)
				g_target_registration_name=${argument#*=}
				index=$(( index + 1 ))
				;;
			--registration-name=*)
				g_registration_name=${argument#*=}
				index=$(( index + 1 ))
				;;
			--high-res-mesh=*)
				g_high_res_mesh=${argument#*=}
				index=$(( index + 1 ))
				;;
			--low-res-mesh=*)
				g_low_res_mesh=${argument#*=}
				index=$(( index + 1 ))
				;;
			*)
				usage
				echo "ERROR: unrecognized option: ${argument}"
				echo ""
				exit 1
				;;
		esac
	done

	local error_count=0
	# check required parameters
	if [ -z "${g_path_to_study_folder}" ]; then
		echo "ERROR: path to study folder (--path= or --study-folder=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_path_to_study_folder: ${g_path_to_study_folder}"
	fi

	if [ -z "${g_subject_list}" ]; then
		echo "ERROR: subject ID list (--subject-list=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_subject_list: ${g_subject_list}"
	fi

	if [ -z "${g_common_folder}" ]; then
		echo "ERROR: common folder (--common-folder=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_common_folder: ${g_common_folder}"
	fi

	if [ -z "${g_group_average_name}" ]; then
		echo "ERROR: group average name (--group-average-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_group_average_name: ${g_group_average_name}"
	fi

	if [ -z "${g_input_registration_name}" ]; then
		echo "ERROR: input registration name (--input-registration-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_input_registration_name: ${g_input_registration_name}"
	fi

	if [ -z "${g_target_registration_name}" ]; then
		echo "ERROR: target registration name (--target-registration-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_target_registration_name: ${g_target_registration_name}"
	fi

	if [ -z "${g_registration_name}" ]; then
		echo "ERROR: registration name (--registration-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_registration_name: ${g_registration_name}"
	fi

	if [ -z "${g_high_res_mesh}" ]; then
		echo "ERROR: high resolution mesh (--high-res-mesh=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_high_res_mesh: ${g_high_res_mesh}"
	fi

	if [ -z "${g_low_res_mesh}" ]; then
		echo "ERROR: low resolution mesh (--low-res-mesh=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_low_res_mesh: ${g_low_res_mesh}"
	fi

	if [ ${error_count} -gt 0 ]; then
		echo "For usage information, use --help"
		exit 1
	fi
}

#
# Function Description:
#  Document Tool Versions
#
show_tool_versions() 
{
	# Show HCP pipelines version
	log_Msg "Showing HCP Pipelines version"
	cat ${HCPPIPEDIR}/version.txt

 	# Show wb_command version
	log_Msg "Showing wb_command version"
	${CARET7DIR}/wb_command -version
}

#
# Function Description:
#  Main processing of script.
#
main()
{
	# Get command line options
	# See documentation for the get_options function for global variables set
	get_options $@

	# show the versions of tools used
	show_tool_versions

	StudyFolder="${g_path_to_study_folder}"
	log_Msg "StudyFolder: ${StudyFolder}"

	Subjlist="${g_subject_list}"
	log_Msg "Subjlist: ${Subjlist}"

	Caret7_Command="${CARET7DIR}/wb_command"
	log_Msg "Caret7_Command: ${Caret7_Command}"

	CommonFolder="${g_common_folder}"
	log_Msg "CommonFolder: ${CommonFolder}"

	GroupAverageName="${g_group_average_name}"
	log_Msg "GroupAverageName: ${GroupAverageName}"

	InRegName="${g_input_registration_name}"
	log_Msg "InRegName: ${InRegName}"

	TargetRegName="${g_target_registration_name}"
	log_Msg "TargetRegName: ${TargetRegName}"

	RegName="${g_registration_name}"
	log_Msg "RegName: ${RegName}"

	HighResMesh="${g_high_res_mesh}"
	log_Msg "HighResMesh: ${HighResMesh}"

	LowResMesh="${g_low_res_mesh}"
	log_Msg "LowResMes: ${LowResMesh}"

	Subjlist=`echo "$Subjlist" | sed 's/@/ /g'`
	log_Msg "Subjlist: ${Subjlist}"

	CommonAtlasFolder="${CommonFolder}/MNINonLinear"
	log_Msg "CommonAtlasFolder: ${CommonAtlasFolder}"

	#CommonDownSampleFolder="${CommonAtlasFolder}/fsaverage_LR${LowResMesh}k"
	#log_Msg "CommonDownSampleFolder: ${CommonDownSampleFolder}"

	if [ ! -e ${CommonAtlasFolder}/${RegName} ] ; then
		mkdir -p ${CommonAtlasFolder}/${RegName}
	else 
		rm -r ${CommonAtlasFolder}/${RegName}
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

		max_cmd_length=`getconf ARG_MAX`
		if [ ${#surface_average_cmd} -gt ${max_cmd_length} ] ; then
			log_Error_Abort "Command will be too long to execute. Command: ${surface_average_cmd}."
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
		cp --verbose \
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

}

# 
# Invoke the main function to get things started
#
main $@
