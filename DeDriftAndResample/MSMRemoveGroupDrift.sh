#!/bin/bash

# ------------------------------------------------------------------------------
#  Show usage information for this script
# ------------------------------------------------------------------------------

show_usage()
{
	cat <<EOF

${g_script_name}: MSM Remove Group Drift - Compute Group Registration Drift

Usage: ${g_script_name} <options>

  Options: [ ] = optional; < > = user supplied value

    [--help] : show usage information and exit"

	Usage information To Be Written

EOF
}

# ------------------------------------------------------------------------------
#  Get the command line options for this script.
# ------------------------------------------------------------------------------

get_options()
{
	local arguments=($@)

	# initialize global output variables
	unset p_StudyFolder     # StudyFolder
	unset p_Subjlist             # Subjlist
	unset p_CommonFolder            # CommonFolder
	unset p_GroupAverageName       # GroupAverageName
	unset p_InputRegName  # InRegName
	unset p_TargetRegName # TargetRegName
	unset p_RegName                # RegName
	unset p_HighResMesh            # HighResMesh
	unset p_LowResMesh             # LowResMesh

	# set default values

	# parse arguments
	local num_args=${#arguments[@]}
	local argument
	local index

    for ((index = 0; index < num_args; ++index))
    do
		argument=${arguments[index]}

		case ${argument} in
			--help)
				show_usage
				exit 0
				;;
			--path=*)
				p_StudyFolder=${argument#*=}
				;;
			--study-folder=*)
				p_StudyFolder=${argument#*=}
				;;
			--subject-list=*)
				p_Subjlist=${argument#*=}
				;;
			--common-folder=*)
				p_CommonFolder=${argument#*=}
				;;
			--group-average-name=*)
				p_GroupAverageName=${argument#*=}
				;;
			--input-registration-name=*)
				p_InputRegName=${argument#*=}
				;;
			--target-registration-name=*)
				p_TargetRegName=${argument#*=}
				;;
			--registration-name=*)
				p_RegName=${argument#*=}
				;;
			--high-res-mesh=*)
				p_HighResMesh=${argument#*=}
				;;
			--low-res-mesh=*)
				p_LowResMesh=${argument#*=}
				;;
			*)
				show_usage
				log_Err_Abort "unrecognized option: ${argument}"
				;;
		esac
	done

	local error_count=0
	# check required parameters
	if [ -z "${p_StudyFolder}" ]; then
		echo "ERROR: path to study folder (--path= or --study-folder=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "p_StudyFolder: ${p_StudyFolder}"
	fi

	if [ -z "${p_Subjlist}" ]; then
		echo "ERROR: subject ID list (--subject-list=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "p_Subjlist: ${p_Subjlist}"
	fi

	if [ -z "${p_CommonFolder}" ]; then
		echo "ERROR: common folder (--common-folder=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "p_CommonFolder: ${p_CommonFolder}"
	fi

	if [ -z "${p_GroupAverageName}" ]; then
		echo "ERROR: group average name (--group-average-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "p_GroupAverageName: ${p_GroupAverageName}"
	fi

	if [ -z "${p_InputRegName}" ]; then
		echo "ERROR: input registration name (--input-registration-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "p_InputRegName: ${p_InputRegName}"
	fi

	if [ -z "${p_TargetRegName}" ]; then
		echo "ERROR: target registration name (--target-registration-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "p_TargetRegName: ${p_TargetRegName}"
	fi

	if [ -z "${p_RegName}" ]; then
		echo "ERROR: registration name (--registration-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "p_RegName: ${p_RegName}"
	fi

	if [ -z "${p_HighResMesh}" ]; then
		echo "ERROR: high resolution mesh (--high-res-mesh=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "p_HighResMesh: ${p_HighResMesh}"
	fi

	if [ -z "${p_LowResMesh}" ]; then
		echo "ERROR: low resolution mesh (--low-res-mesh=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "p_LowResMesh: ${p_LowResMesh}"
	fi

	if [ ${error_count} -gt 0 ]; then
		echo "For usage information, use --help"
		exit 1
	fi
}

# ------------------------------------------------------------------------------
#  Show Tool Versions
# ------------------------------------------------------------------------------

show_tool_versions()
{
	# Show HCP pipelines version
	log_Msg "Showing HCP Pipelines version"
	"${HCPPIPEDIR}"/show_version --short

 	# Show wb_command version
	log_Msg "Showing wb_command version"
	${CARET7DIR}/wb_command -version
}

# ------------------------------------------------------------------------------
#  Main processing of script.
# ------------------------------------------------------------------------------

main()
{
	# Get command line options
	# See documentation for the get_options function for global variables set
	get_options "$@"

	StudyFolder="${p_StudyFolder}"
	log_Msg "StudyFolder: ${StudyFolder}"

	Subjlist="${p_Subjlist}"
	log_Msg "Subjlist: ${Subjlist}"

	Caret7_Command="${CARET7DIR}/wb_command"
	log_Msg "Caret7_Command: ${Caret7_Command}"

	CommonFolder="${p_CommonFolder}"
	log_Msg "CommonFolder: ${CommonFolder}"

	GroupAverageName="${p_GroupAverageName}"
	log_Msg "GroupAverageName: ${GroupAverageName}"

	InRegName="${p_InputRegName}"
	log_Msg "InRegName: ${InRegName}"

	TargetRegName="${p_TargetRegName}"
	log_Msg "TargetRegName: ${TargetRegName}"

	RegName="${p_RegName}"
	log_Msg "RegName: ${RegName}"

	HighResMesh="${p_HighResMesh}"
	log_Msg "HighResMesh: ${HighResMesh}"

	LowResMesh="${p_LowResMesh}"
	log_Msg "LowResMes: ${LowResMesh}"

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

}

# ------------------------------------------------------------------------------
#  "Global" processing - everything above here should be in a function
# ------------------------------------------------------------------------------

# Establish defaults

# Set global variables
g_script_name=$(basename "${0}")

# Allow script to return a Usage statement, before any other output
if [ "$#" = "0" ]; then
    show_usage
    exit 1
fi

# Verify HCPPIPEDIR environment variable is set
if [ -z "${HCPPIPEDIR}" ]; then
	echo "${g_script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
	exit 1
fi

# Load function libraries
source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source ${HCPPIPEDIR}/global/scripts/opts.shlib                 # Command line option functions

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
	show_usage
	exit 0
fi

${HCPPIPEDIR}/show_version

log_Debug_On

# Verify required environment variables are set and log value
log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var CARET7DIR

# Show tool versions
show_tool_versions

#
#
# Invoke the 'main' function to get things started
#
main "$@"
