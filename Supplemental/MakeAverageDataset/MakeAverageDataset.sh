#!/bin/bash
set -e
g_script_name=`basename ${0}`

source ${HCPPIPEDIR}/global/scripts/log.shlib # Logging related functions
log_SetToolName "${g_script_name}"

source ${HCPPIPEDIR}/global/scripts/fsl_version.shlib # Function for getting FSL version

get_options()
{
	local arguments=($@)

	# initialize global output variables
	unset g_subject_list
	unset g_study_folder
	unset g_group_average_name
	unset g_surface_atlas_dir
	unset g_grayordinates_space_dir
	unset g_high_res_mesh
	unset g_low_res_meshes
	unset g_freesurfer_labels
	#Caret7_Command="${9}"
	unset g_sigma
	unset g_reg_name
	unset g_videen_maps
	unset g_greyscale_maps
	unset g_distortion_maps
	unset g_gradient_maps
	unset g_std_maps
	unset g_multi_maps

	# parse arguments
	local num_args=${#arguments[@]}
	local argument
	local index=0

	while [ ${index} -lt ${num_args} ]; do
		argument=${arguments[index]}

		case ${argument} in
			--subject-list=*)
				g_subject_list=${argument#*=}
				index=$(( index + 1 ))
				;;
			--study-folder=*)
				g_study_folder=${argument#*=}
				index=$(( index + 1 ))
				;;
			--group-average-name=*)
				g_group_average_name=${argument#*=}
				index=$(( index + 1 ))
				;;
			--surface-atlas-dir=*)
				g_surface_atlas_dir=${argument#*=}
				index=$(( index + 1 ))
				;;
			--grayordinates-space-dir=*)
				g_grayordinates_space_dir=${argument#*=}
				index=$(( index + 1 ))
				;;
			--high-res-mesh=*)
				g_high_res_mesh=${argument#*=}
				index=$(( index + 1 ))
				;;
			--low-res-meshes=*)
				g_low_res_meshes=${argument#*=}
				index=$(( index + 1 ))
				;;
			--freesurfer-labels=*)
				g_freesurfer_labels=${argument#*=}
				index=$(( index + 1 ))
				;;
			--sigma=*)
				g_sigma=${argument#*=}
				index=$(( index + 1 ))
				;;
			--reg-name=*)
				g_reg_name=${argument#*=}
				index=$(( index + 1 ))
				;;
			--videen-maps=*)
				g_videen_maps=${argument#*=}
				index=$(( index + 1 ))
				;;
			--greyscale-maps=*)
				g_greyscale_maps=${argument#*=}
				index=$(( index + 1 ))
				;;
			--distortion-maps=*)
				g_distortion_maps=${argument#*=}
				index=$(( index + 1 ))
				;;
			--gradient-maps=*)
				g_gradient_maps=${argument#*=}
				index=$(( index + 1 ))
				;;
			--std-maps=*)
				g_std_maps=${argument#*=}
				index=$(( index + 1 ))
				;;
			--multi-maps=*)
				g_multi_maps=${argument#*=}
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
	if [ -z "${g_subject_list}" ]; then
		echo "ERROR: subject list (--subject-list=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_subject_list: ${g_subject_list}"
	fi

	if [ -z "${g_study_folder}" ]; then
		echo "ERROR: study folder (--study-folder=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_study_folder: ${g_study_folder}"
	fi

	if [ -z "${g_group_average_name}" ]; then
		echo "ERROR: group average name (--group-average-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_group_average_name: ${g_group_average_name}"
	fi

	if [ -z "${g_surface_atlas_dir}" ]; then
		echo "ERROR: surface atlas dir (--surface-atlas-dir=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_surface_atlas_dir: ${g_surface_atlas_dir}"
	fi

	if [ -z "${g_grayordinates_space_dir}" ]; then
		echo "ERROR: grayordinates space dir (--grayordinates-space-dir=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_grayordinates_space_dir: ${g_grayordinates_space_dir}"
	fi

	if [ -z "${g_high_res_mesh}" ]; then
		echo "ERROR: high res mesh (--high-res-mesh=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_high_res_mesh: ${g_high_res_mesh}"
	fi

	if [ -z "${g_low_res_meshes}" ]; then
		echo "ERROR: low res meshes (--low-res-meshes=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_low_res_meshes: ${g_low_res_meshes}"
	fi

	if [ -z "${g_freesurfer_labels}" ]; then
		echo "ERROR: freesurfer labels (--freesurfer-labels=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_freesurfer_labels: ${g_freesurfer_labels}"
	fi

	if [ -z "${g_sigma}" ]; then
		echo "ERROR: sigma (--sigma=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_sigma: ${g_sigma}"
	fi

	if [ -z "${g_reg_name}" ]; then
		echo "ERROR: reg name (--reg-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_reg_name: ${g_reg_name}"
	fi

	if [ -z "${g_videen_maps}" ]; then
		echo "ERROR: videen maps (--videen-maps=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_videen_maps: ${g_videen_maps}"
	fi

	if [ -z "${g_greyscale_maps}" ]; then
		echo "ERROR: greyscale maps (--greyscale-maps=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_greyscale_maps: ${g_greyscale_maps}"
	fi

	if [ -z "${g_distortion_maps}" ]; then
		echo "ERROR: distortion maps (--distortion-maps=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_distortion_maps: ${g_distortion_maps}"
	fi

	if [ -z "${g_gradient_maps}" ]; then
		echo "ERROR: gradient maps (--gradient-maps=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_gradient_maps: ${g_gradient_maps}"
	fi

	if [ -z "${g_std_maps}" ]; then
		echo "ERROR: std maps (--std-maps=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_std_maps: ${g_std_maps}"
	fi

	if [ -z "${g_multi_maps}" ]; then
		echo "ERROR: multi maps (--multi-maps=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_multi_maps: ${g_multi_maps}"
	fi

	if [ ${error_count} -gt 0 ]; then
		#echo "For usage information, use --help"
		exit 1
	fi
}

show_tool_versions()
{
	# Show HCP pipelines version
	log_Msg "Showing HCP Pipelines version"
	cat ${HCPPIPEDIR}/version.txt

	# Show wb_command version
	log_Msg "Showing Connectome Workbench (wb_command) version"
	${CARET7DIR}/wb_command -version

	# Show fsl version
	log_Msg "Showing FSL version"
	fsl_version_get fsl_ver
	log_Msg "FSL version: ${fsl_ver}"
}

main() 
{
	# Get command line options
	get_options $@

	# Show the versions of tools used
	show_tool_versions

	#Subjlist="${1}"
	local Subjlist="${g_subject_list}"
	log_Msg "Subjlist: ${Subjlist}"

	#StudyFolder="${2}"
	local StudyFolder="${g_study_folder}"
	log_Msg "StudyFolder: ${StudyFolder}"

	#GroupAverageName="${3}"
	local GroupAverageName="${g_group_average_name}"
	log_Msg "GroupAverageName: ${GroupAverageName}"

	#SurfaceAtlasDIR="${4}"
	local SurfaceAtlasDIR="${g_surface_atlas_dir}"
	log_Msg "SurfaceAtlasDIR: ${SurfaceAtlasDIR}"

	#GrayordinatesSpaceDIR="${5}"
	local GrayordinatesSpaceDIR="${g_grayordinates_space_dir}"
	log_Msg "GrayordinatesSpaceDIR: ${GrayordinatesSpaceDIR}"

	#HighResMesh="${6}"
	local HighResMesh="${g_high_res_mesh}"
	log_Msg "HighResMesh: ${HighResMesh}"

	#LowResMeshes="${7}"
	local LowResMeshes="${g_low_res_meshes}"
	log_Msg "LowResMeshes: ${LowResMeshes}"

	#FreeSurferLabels="${8}"
	local FreeSurferLabels="${g_freesurfer_labels}"
	log_Msg "FreeSurferLabels: ${FreeSurferLabels}"

	#Caret7_Command="${9}"
	local Caret7_Command="${CARET7DIR}/wb_command"
	log_Msg "Caret7_Command: ${Caret7_Command}"

	#Sigma="${10}" #Pregradient Smoothing
	local Sigma="${g_sigma}" #Pregradient Smoothing
	log_Msg "Sigma: ${Sigma}"

	#RegName="${11}"
	local RegName="${g_reg_name}"
	log_Msg "RegName: ${RegName}"

	#VideenMaps="${12}"
	local VideenMaps="${g_videen_maps}"
	log_Msg "VideenMaps: ${VideenMaps}"

	#GreyScaleMaps="${13}"
	local GreyScaleMaps="${g_greyscale_maps}"
	log_Msg "GreyScaleMaps: ${GreyScaleMaps}"

	#DistortionMaps="${14}"
	local DistortionMaps="${g_distortion_maps}"
	log_Msg "DistortionMaps: ${DistortionMaps}"

	#GradientMaps="${15}"
	local GradientMaps="${g_gradient_maps}"
	log_Msg "GradientMaps: ${GradientMaps}"

	#STDMaps="${16}"
	local STDMaps="${g_std_maps}"
	log_Msg "STDMaps: ${STDMaps}"

	#MultiMaps="${17}"
	local MultiMaps="${g_multi_maps}"
	log_Msg "MultiMaps: ${MultiMaps}"

	LowResMeshes=`echo ${LowResMeshes} | sed 's/@/ /g'`
	log_Msg "After delimeter substitution, LowResMeshes: ${LowResMeshes}"
	
	Subjlist=`echo ${Subjlist} | sed 's/@/ /g'`	
	log_Msg "After delimeter substitution, Subjlist: ${Subjlist}"

	VideenMaps=`echo ${VideenMaps} | sed 's/@/ /g'`
	log_Msg "After delimeter substitution, VideenMaps: ${VideenMaps}"

	GreyScaleMaps=`echo ${GreyScaleMaps} | sed 's/@/ /g'`
	log_Msg "After delimeter substitution, GreyScaleMaps: ${GreyScaleMaps}"

	DistortionMaps=`echo ${DistortionMaps} | sed 's/@/ /g'`
	log_Msg "After delimeter substitution, DistortionMaps: ${DistortionMaps}"

	GradientMaps=`echo ${GradientMaps} | sed 's/@/ /g'`
	log_Msg "After delimeter substitution, GradientMaps: ${GradientMaps}"

	STDMaps=`echo ${STDMaps} | sed 's/@/ /g'`
	log_Msg "After delimeter substitution, STDMaps: ${STDMaps}"

	MultiMaps=`echo ${MultiMaps} | sed 's/@/ /g'`
	log_Msg "After delimeter substitution, MultiMaps: ${MultiMaps}"

	if [ ${RegName} = "NONE" ] ; then
		RegSTRING=""
		SpecRegSTRING=""
		DistortionMaps="${DistortionMaps} ArealDistortion_FS ArealDistortion_MSMSulc"
		RegName="MSMSulc"
	else
		RegSTRING="_${RegName}"
		SpecRegSTRING=".${RegName}"
	fi

	# Naming Conventions
	log_Msg "Naming Conventions"
	DownSampleFolderNames=""
	for LowResMesh in ${LowResMeshes} ; do
		DownSampleFolderNames=`echo "${DownSampleFolderNames}fsaverage_LR${LowResMesh}k "`
	done
	T1wName="T1w_restore"
	T2wName="T2w_restore"
	wmparc="wmparc"
	ribbon="ribbon"

	# BuildPaths / Make Folders
	log_Msg "Build Paths / Make Folders"
	CommonFolder="${StudyFolder}/${GroupAverageName}"
	CommonAtlasFolder="${CommonFolder}/MNINonLinear"
	CommonDownSampleFolders=""
	for DownSampleFolderName in ${DownSampleFolderNames} ; do
		CommonDownSampleFolders=`echo "${CommonDownSampleFolders}${CommonAtlasFolder}/${DownSampleFolderName} "`
	done

	if [ ! -e ${CommonFolder} ] ; then
		mkdir ${CommonFolder}
	fi
	if [ ! -e ${CommonAtlasFolder} ] ; then
		mkdir ${CommonAtlasFolder}
	fi
	for CommonDownSampleFolder in ${CommonDownSampleFolders} ; do
		if [ ! -e ${CommonDownSampleFolder} ] ; then
			mkdir ${CommonDownSampleFolder}
		fi
	done

	# Make Average Volumes
	log_Msg "Make Average Volumes"
	if [ ! -e ${CommonAtlasFolder}/${GroupAverageName}_Average${T1wName}.nii.gz ]  ; then
		# Scalar Volumes
		log_Msg "Scalar Volumes"
		for Volume in ${T1wName} ${T2wName} ; do
			MergeVolumeSTRING=""
			for Subject in ${Subjlist} ; do
				MergeVolumeSTRING=`echo "${MergeVolumeSTRING}${StudyFolder}/${Subject}/MNINonLinear/${Volume}.nii.gz "`
			done
			fslmerge -t ${CommonAtlasFolder}/${GroupAverageName}_All${Volume}.nii.gz ${MergeVolumeSTRING}
			fslmaths ${CommonAtlasFolder}/${GroupAverageName}_All${Volume}.nii.gz -Tmean ${CommonAtlasFolder}/${GroupAverageName}_Average${Volume}.nii.gz -odt float
		done

		${Caret7_Command} -volume-math "clamp((T1w / T2w), 0, 100)" ${CommonAtlasFolder}/${GroupAverageName}_AverageT1wDividedByT2w.nii.gz  -var T1w ${CommonAtlasFolder}/${GroupAverageName}_Average${T1wName}.nii.gz -var T2w ${CommonAtlasFolder}/${GroupAverageName}_Average${T2wName}.nii.gz -fixnan 0
		${Caret7_Command} -volume-palette ${CommonAtlasFolder}/${GroupAverageName}_AverageT1wDividedByT2w.nii.gz MODE_AUTO_SCALE_PERCENTAGE -pos-percent 4 96 -interpolate true -palette-name videen_style

		# Label Volumes
		log_Msg "Label Volumes"
		for Volume in ${wmparc} ${ribbon} ; do
			MergeVolumeSTRING=""
			for Subject in ${Subjlist} ; do
				MergeVolumeSTRING=`echo "${MergeVolumeSTRING}${StudyFolder}/${Subject}/MNINonLinear/${Volume}.nii.gz "`
			done
			fslmerge -t ${CommonAtlasFolder}/${GroupAverageName}_All${Volume}.nii.gz ${MergeVolumeSTRING}
			${Caret7_Command} -volume-label-import ${CommonAtlasFolder}/${GroupAverageName}_All${Volume}.nii.gz ${FreeSurferLabels} ${CommonAtlasFolder}/${GroupAverageName}_All${Volume}.nii.gz -drop-unused-labels
			${Caret7_Command} -volume-reduce ${CommonAtlasFolder}/${GroupAverageName}_All${Volume}.nii.gz MODE ${CommonAtlasFolder}/${GroupAverageName}_Average${Volume}.nii.gz
			${Caret7_Command} -volume-label-import ${CommonAtlasFolder}/${GroupAverageName}_Average${Volume}.nii.gz ${FreeSurferLabels} ${CommonAtlasFolder}/${GroupAverageName}_Average${Volume}.nii.gz -drop-unused-labels
		done
	fi

	# Make Average Surfaces and Surface Data
	log_Msg "Make Average Surfaces and Surface Data"
	for Hemisphere in L R ; do
		if [ ${Hemisphere} = "L" ] ; then 
			Structure="CORTEX_LEFT"
		elif [ ${Hemisphere} = "R" ] ; then 
			Structure="CORTEX_RIGHT"
		fi 

		cp ${SurfaceAtlasDIR}/fsaverage.${Hemisphere}_LR.spherical_std.${HighResMesh}k_fs_LR.surf.gii ${CommonAtlasFolder}/${GroupAverageName}.${Hemisphere}.sphere.${HighResMesh}k_fs_LR.surf.gii
		cp ${SurfaceAtlasDIR}/${Hemisphere}.atlasroi.${HighResMesh}k_fs_LR.shape.gii ${CommonAtlasFolder}/${GroupAverageName}.${Hemisphere}.atlasroi.${HighResMesh}k_fs_LR.shape.gii
		if [ -e ${SurfaceAtlasDIR}/colin.cerebral.${Hemisphere}.flat.${HighResMesh}k_fs_LR.surf.gii ] ; then
			cp ${SurfaceAtlasDIR}/colin.cerebral.${Hemisphere}.flat.${HighResMesh}k_fs_LR.surf.gii ${CommonAtlasFolder}/${GroupAverageName}.${Hemisphere}.flat.${HighResMesh}k_fs_LR.surf.gii

			spec_file=${CommonAtlasFolder}/${GroupAverageName}${SpecRegSTRING}.${HighResMesh}k_fs_LR.wb.spec
			surf_file=${CommonAtlasFolder}/${GroupAverageName}.${Hemisphere}.flat.${HighResMesh}k_fs_LR.surf.gii
			log_Msg "Adding surf_file: '${surf_file}' to spec_file: '${spec_file}'"

			${Caret7_Command} -add-to-spec-file ${spec_file} ${Structure} ${surf_file}
		fi

		i=1
		for LowResMesh in ${LowResMeshes} ; do
			log_Msg "LowResMesh: ${LowResMesh}"
			CommonFolder=`echo ${CommonDownSampleFolders} | cut -d " " -f ${i}`
			cp ${SurfaceAtlasDIR}/${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii ${CommonFolder}/${GroupAverageName}.${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii
			cp ${GrayordinatesSpaceDIR}/${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii ${CommonFolder}/${GroupAverageName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii
			if [ -e ${SurfaceAtlasDIR}/colin.cerebral.${Hemisphere}.flat.${LowResMesh}k_fs_LR.surf.gii ] ; then
				cp ${SurfaceAtlasDIR}/colin.cerebral.${Hemisphere}.flat.${LowResMesh}k_fs_LR.surf.gii ${CommonFolder}/${GroupAverageName}.${Hemisphere}.flat.${LowResMesh}k_fs_LR.surf.gii

				spec_file=${CommonFolder}/${GroupAverageName}${SpecRegSTRING}.${LowResMesh}k_fs_LR.wb.spec
				surf_file=${CommonFolder}/${GroupAverageName}.${Hemisphere}.flat.${LowResMesh}k_fs_LR.surf.gii
				log_Msg "Adding surf_file: '${surf_file}' to spec_file: '${spec_file}'"

				${Caret7_Command} -add-to-spec-file ${spec_file} ${Structure} ${surf_file}
			fi
			i=$(($i+1))
		done 
  
		for Mesh in ${HighResMesh} ${LowResMeshes} ; do
			log_Msg "Mesh: ${Mesh}"
			if [ $Mesh = ${HighResMesh} ] ; then
				CommonFolder=${CommonAtlasFolder}
				Scale="4"
			else 
				i=1
				for LowResMesh in ${LowResMeshes} ; do
					if [ ${LowResMesh} = ${Mesh} ] ; then
						CommonFolder=`echo ${CommonDownSampleFolders} | cut -d " " -f ${i}`
					fi
					Scale="1"
					i=$(($i+1))
				done
			fi

			spec_file=${CommonFolder}/${GroupAverageName}${SpecRegSTRING}.${Mesh}k_fs_LR.wb.spec
			surf_file=${CommonFolder}/${GroupAverageName}.${Hemisphere}.sphere.${Mesh}k_fs_LR.surf.gii

			${Caret7_Command} -add-to-spec-file ${spec_file} ${Structure} ${surf_file}

			for Surface in white midthickness pial ; do
				log_Msg "Surface: ${Surface}"
				SurfaceSTRING=""
				for Subject in $Subjlist ; do
					log_Msg "Subject: ${Subject}"
					AtlasFolder="${StudyFolder}/${Subject}/MNINonLinear"
					if [ $Mesh = ${HighResMesh} ] ; then
						Folder=${AtlasFolder}
					else      
						i=1
						for LowResMesh in ${LowResMeshes} ; do
							if [ ${LowResMesh} = ${Mesh} ] ; then
								DownSampleFolderName=`echo ${DownSampleFolderNames} | cut -d " " -f ${i}`
							fi
							i=$(($i+1))
						done
						DownSampleFolder="${StudyFolder}/${Subject}/MNINonLinear/${DownSampleFolderName}"
						Folder=${DownSampleFolder}
					fi
					SurfaceSTRING=`echo "${SurfaceSTRING} -surf ${Folder}/${Subject}.${Hemisphere}.${Surface}${RegSTRING}.${Mesh}k_fs_LR.surf.gii "`
				done

				surface_out=${CommonFolder}/${GroupAverageName}.${Hemisphere}.${Surface}${RegSTRING}.${Mesh}k_fs_LR.surf.gii
				uncert_metric_out=${CommonFolder}/${GroupAverageName}.${Hemisphere}.${Surface}${RegSTRING}_uncertainty.${Mesh}k_fs_LR.shape.gii
				stddev_metric_out=${CommonFolder}/${GroupAverageName}.${Hemisphere}.${Surface}${RegSTRING}_std.${Mesh}k_fs_LR.shape.gii
			   
				log_Msg "About to average surface files"
				log_Msg "surface_out: ${surface_out}"
				log_Msg "uncert_metric_out: ${uncert_metric_out}"
				log_Msg "stddev_metric_out: ${stddev_metric_out}"
				log_Msg "SurfaceSTRING: ${SurfaceSTRING}"
				${Caret7_Command} -surface-average ${surface_out} -uncertainty ${uncert_metric_out} -stddev ${stddev_metric_out} ${SurfaceSTRING}


				spec_file=${CommonFolder}/${GroupAverageName}${SpecRegSTRING}.${Mesh}k_fs_LR.wb.spec
				surf_file=${CommonFolder}/${GroupAverageName}.${Hemisphere}.${Surface}${RegSTRING}.${Mesh}k_fs_LR.surf.gii
				log_Msg "Adding surf_file: '${surf_file}' to spec_file: '${spec_file}'"
				${Caret7_Command} -add-to-spec-file ${spec_file} ${Structure} ${surf_file}

				log_Msg "${Caret7_Command} -metric-palette 1"
				${Caret7_Command} -metric-palette ${CommonFolder}/${GroupAverageName}.${Hemisphere}.${Surface}${RegSTRING}_uncertainty.${Mesh}k_fs_LR.shape.gii MODE_AUTO_SCALE_PERCENTAGE -pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false

				log_Msg "${Caret7_Command} -metric-palette 2"
				${Caret7_Command} -metric-palette ${CommonFolder}/${GroupAverageName}.${Hemisphere}.${Surface}${RegSTRING}_std.${Mesh}k_fs_LR.shape.gii MODE_AUTO_SCALE_PERCENTAGE -pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false
				
				log_Msg "Back for another surface"
			done

			log_Msg "${Caret7_Command} -surface-generate-inflated"
			${Caret7_Command} -surface-generate-inflated ${CommonFolder}/${GroupAverageName}.${Hemisphere}.midthickness${RegSTRING}.${Mesh}k_fs_LR.surf.gii ${CommonFolder}/${GroupAverageName}.${Hemisphere}.inflated${RegSTRING}.${Mesh}k_fs_LR.surf.gii ${CommonFolder}/${GroupAverageName}.${Hemisphere}.very_inflated${RegSTRING}.${Mesh}k_fs_LR.surf.gii -iterations-scale ${Scale}
			${Caret7_Command} -add-to-spec-file ${CommonFolder}/${GroupAverageName}${SpecRegSTRING}.${Mesh}k_fs_LR.wb.spec ${Structure} ${CommonFolder}/${GroupAverageName}.${Hemisphere}.inflated${RegSTRING}.${Mesh}k_fs_LR.surf.gii
			${Caret7_Command} -add-to-spec-file ${CommonFolder}/${GroupAverageName}${SpecRegSTRING}.${Mesh}k_fs_LR.wb.spec ${Structure} ${CommonFolder}/${GroupAverageName}.${Hemisphere}.very_inflated${RegSTRING}.${Mesh}k_fs_LR.surf.gii
		done

	done

	log_Msg "Debug Point 1"

	for Mesh in ${HighResMesh} ${LowResMeshes} ; do
		if [ $Mesh = ${HighResMesh} ] ; then
			CommonFolder=${CommonAtlasFolder}
		else 
			i=1
			for LowResMesh in ${LowResMeshes} ; do
				if [ ${LowResMesh} = ${Mesh} ] ; then
					CommonFolder=`echo ${CommonDownSampleFolders} | cut -d " " -f ${i}`
				fi
				i=$(($i+1))
			done
		fi

		for Map in white${RegSTRING}_std white${RegSTRING}_uncertainty midthickness${RegSTRING}_std midthickness${RegSTRING}_uncertainty pial${RegSTRING}_std pial${RegSTRING}_uncertainty ; do
			PaletteStringOne="MODE_AUTO_SCALE_PERCENTAGE"
			PaletteStringTwo="-pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false"
			${Caret7_Command} -cifti-create-dense-scalar ${CommonFolder}/${GroupAverageName}.${Map}.${Mesh}k_fs_LR.dscalar.nii -left-metric ${CommonFolder}/${GroupAverageName}.L.${Map}.${Mesh}k_fs_LR.shape.gii -roi-left ${CommonFolder}/${GroupAverageName}.L.atlasroi.${Mesh}k_fs_LR.shape.gii -right-metric ${CommonFolder}/${GroupAverageName}.R.${Map}.${Mesh}k_fs_LR.shape.gii -roi-right ${CommonFolder}/${GroupAverageName}.R.atlasroi.${Mesh}k_fs_LR.shape.gii
			${Caret7_Command} -set-map-name ${CommonFolder}/${GroupAverageName}.${Map}.${Mesh}k_fs_LR.dscalar.nii 1 ${GroupAverageName}_${Map}
			${Caret7_Command} -cifti-palette ${CommonFolder}/${GroupAverageName}.${Map}.${Mesh}k_fs_LR.dscalar.nii ${PaletteStringOne} ${CommonFolder}/${GroupAverageName}.${Map}.${Mesh}k_fs_LR.dscalar.nii ${PaletteStringTwo}
			for Hemisphere in L R ; do
				rm ${CommonFolder}/${GroupAverageName}.${Hemisphere}.${Map}.${Mesh}k_fs_LR.shape.gii
			done
		done
	done

	log_Msg "Debug Point 2"

	for Mesh in ${HighResMesh} ${LowResMeshes} ; do
		if [ $Mesh = ${HighResMesh} ] ; then
			CommonFolder=${CommonAtlasFolder}
		else 
			i=1
			for LowResMesh in ${LowResMeshes} ; do
				if [ ${LowResMesh} = ${Mesh} ] ; then
					CommonFolder=`echo ${CommonDownSampleFolders} | cut -d " " -f ${i}`
				fi
				i=$(($i+1))
			done
		fi
		MapMerge=""
		MNIMapMerge=""

		for Subject in ${Subjlist} ; do
			AtlasFolder="${StudyFolder}/${Subject}/MNINonLinear"
			T1wFolder="${StudyFolder}/${Subject}/T1w"
			if [ $Mesh = ${HighResMesh} ] ; then
				Folder="${T1wFolder}"
				MNIFolder="${AtlasFolder}"
				for Hemisphere in L R ; do
					${Caret7_Command} -surface-resample ${T1wFolder}/Native/${Subject}.${Hemisphere}.midthickness.native.surf.gii ${AtlasFolder}/Native/${Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii ${AtlasFolder}/${Subject}.${Hemisphere}.sphere.${Mesh}k_fs_LR.surf.gii BARYCENTRIC ${T1wFolder}/${Subject}.${Hemisphere}.midthickness${RegSTRING}.${Mesh}k_fs_LR.surf.gii
					${Caret7_Command} -surface-vertex-areas ${T1wFolder}/${Subject}.${Hemisphere}.midthickness${RegSTRING}.${Mesh}k_fs_LR.surf.gii ${T1wFolder}/${Subject}.${Hemisphere}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.shape.gii
					${Caret7_Command} -surface-vertex-areas ${AtlasFolder}/${Subject}.${Hemisphere}.midthickness${RegSTRING}.${Mesh}k_fs_LR.surf.gii ${AtlasFolder}/${Subject}.${Hemisphere}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.shape.gii
				done
				${Caret7_Command} -cifti-create-dense-scalar ${T1wFolder}/${Subject}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.dscalar.nii -left-metric ${T1wFolder}/${Subject}.L.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.shape.gii -roi-left ${AtlasFolder}/${Subject}.L.atlasroi.${Mesh}k_fs_LR.shape.gii -right-metric ${T1wFolder}/${Subject}.R.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.shape.gii -roi-right ${AtlasFolder}/${Subject}.R.atlasroi.${Mesh}k_fs_LR.shape.gii
				${Caret7_Command} -cifti-create-dense-scalar ${AtlasFolder}/${Subject}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.dscalar.nii -left-metric ${AtlasFolder}/${Subject}.L.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.shape.gii -roi-left ${AtlasFolder}/${Subject}.L.atlasroi.${Mesh}k_fs_LR.shape.gii -right-metric ${AtlasFolder}/${Subject}.R.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.shape.gii -roi-right ${AtlasFolder}/${Subject}.R.atlasroi.${Mesh}k_fs_LR.shape.gii
				for Hemisphere in L R ; do
					rm ${T1wFolder}/${Subject}.${Hemisphere}.midthickness${RegSTRING}.${Mesh}k_fs_LR.surf.gii ${T1wFolder}/${Subject}.${Hemisphere}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.shape.gii ${AtlasFolder}/${Subject}.${Hemisphere}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.shape.gii
				done
			else      
				i=1
				for LowResMesh in ${LowResMeshes} ; do
					if [ ${LowResMesh} = ${Mesh} ] ; then
						DownSampleFolderName=`echo ${DownSampleFolderNames} | cut -d " " -f ${i}`
					fi
					i=$(($i+1))
				done
				DownSampleFolder="${StudyFolder}/${Subject}/T1w/${DownSampleFolderName}"
				MNIDownSampleFolder="${StudyFolder}/${Subject}/MNINonLinear/${DownSampleFolderName}"
				Folder=${DownSampleFolder}
				MNIFolder=${MNIDownSampleFolder}
				for Hemisphere in L R ; do
					${Caret7_Command} -surface-vertex-areas ${MNIFolder}/${Subject}.${Hemisphere}.midthickness${RegSTRING}.${Mesh}k_fs_LR.surf.gii ${MNIFolder}/${Subject}.${Hemisphere}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.shape.gii
				done
				${Caret7_Command} -cifti-create-dense-scalar ${MNIFolder}/${Subject}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.dscalar.nii -left-metric ${MNIFolder}/${Subject}.L.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.shape.gii -roi-left ${MNIFolder}/${Subject}.L.atlasroi.${Mesh}k_fs_LR.shape.gii -right-metric ${MNIFolder}/${Subject}.R.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.shape.gii -roi-right ${MNIFolder}/${Subject}.R.atlasroi.${Mesh}k_fs_LR.shape.gii
				for Hemisphere in L R ; do
					rm ${MNIFolder}/${Subject}.${Hemisphere}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.shape.gii
				done
			fi
			MapMerge=`echo "${MapMerge} -cifti ${Folder}/${Subject}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.dscalar.nii"`
			MNIMapMerge=`echo "${MNIMapMerge} -cifti ${MNIFolder}/${Subject}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.dscalar.nii"` 
		done

		${Caret7_Command} -cifti-merge ${CommonFolder}/${GroupAverageName}.All.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.dscalar.nii ${MapMerge}
		${Caret7_Command} -cifti-reduce ${CommonFolder}/${GroupAverageName}.All.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.dscalar.nii MEAN ${CommonFolder}/${GroupAverageName}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.dscalar.nii 
		${Caret7_Command} -cifti-merge ${CommonFolder}/${GroupAverageName}.All.midthickness${RegSTRING}_va_mni.${Mesh}k_fs_LR.dscalar.nii ${MNIMapMerge}
		${Caret7_Command} -cifti-reduce ${CommonFolder}/${GroupAverageName}.All.midthickness${RegSTRING}_va_mni.${Mesh}k_fs_LR.dscalar.nii MEAN ${CommonFolder}/${GroupAverageName}.midthickness${RegSTRING}_va_mni.${Mesh}k_fs_LR.dscalar.nii 
		rm ${CommonFolder}/${GroupAverageName}.All.midthickness${RegSTRING}_va_mni.${Mesh}k_fs_LR.dscalar.nii
		if [ $Mesh = ${HighResMesh} ] ; then
			for Subject in ${Subjlist} ; do
				T1wFolder="${StudyFolder}/${Subject}/T1w"
				MNIFolder="${StudyFolder}/${Subject}/MNINonLinear"
				rm ${T1wFolder}/${Subject}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.dscalar.nii
				rm ${MNIFolder}/${Subject}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.dscalar.nii
			done
		else
			i=1
			for LowResMesh in ${LowResMeshes} ; do
				if [ ${LowResMesh} = ${Mesh} ] ; then
					DownSampleFolderName=`echo ${DownSampleFolderNames} | cut -d " " -f ${i}`
				fi
				i=$(($i+1))
			done
			MNIDownSampleFolder="${StudyFolder}/${Subject}/MNINonLinear/${DownSampleFolderName}"
			MNIFolder=${MNIDownSampleFolder}
			rm ${MNIFolder}/${Subject}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.dscalar.nii
		fi
		
		for Hemisphere in L R ; do
			${Caret7_Command} -surface-vertex-areas ${CommonFolder}/${GroupAverageName}.${Hemisphere}.midthickness${RegSTRING}.${Mesh}k_fs_LR.surf.gii ${CommonFolder}/${GroupAverageName}.${Hemisphere}.midthickness${RegSTRING}.${Mesh}k_fs_LR.shape.gii
		done

		${Caret7_Command} -cifti-create-dense-scalar ${CommonFolder}/${GroupAverageName}.midthickness${RegSTRING}.${Mesh}k_fs_LR.dscalar.nii -left-metric ${CommonFolder}/${GroupAverageName}.L.midthickness${RegSTRING}.${Mesh}k_fs_LR.shape.gii -roi-left ${CommonFolder}/${GroupAverageName}.L.atlasroi.${Mesh}k_fs_LR.shape.gii -right-metric ${CommonFolder}/${GroupAverageName}.R.midthickness${RegSTRING}.${Mesh}k_fs_LR.shape.gii -roi-right ${CommonFolder}/${GroupAverageName}.R.atlasroi.${Mesh}k_fs_LR.shape.gii
		${Caret7_Command} -cifti-math "ln(avgsurf / meanorig) / ln(2)" ${CommonFolder}/${GroupAverageName}.midthickness${RegSTRING}_va_ratio.${Mesh}k_fs_LR.dscalar.nii -var avgsurf ${CommonFolder}/${GroupAverageName}.midthickness${RegSTRING}.${Mesh}k_fs_LR.dscalar.nii -var meanorig ${CommonFolder}/${GroupAverageName}.midthickness${RegSTRING}_va_mni.${Mesh}k_fs_LR.dscalar.nii 
		rm ${CommonFolder}/${GroupAverageName}.midthickness${RegSTRING}.${Mesh}k_fs_LR.dscalar.nii ${CommonFolder}/${GroupAverageName}.midthickness${RegSTRING}_va_mni.${Mesh}k_fs_LR.dscalar.nii

		for Hemisphere in L R ; do
			if [ ${Hemisphere} = "L" ] ; then 
				Structure="CORTEX_LEFT"
			elif [ ${Hemisphere} = "R" ] ; then 
				Structure="CORTEX_RIGHT"
			fi 
			${Caret7_Command} -cifti-separate ${CommonFolder}/${GroupAverageName}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.dscalar.nii  COLUMN -metric ${Structure} ${CommonFolder}/${GroupAverageName}.${Hemisphere}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.shape.gii
			${Caret7_Command} -metric-dilate ${CommonFolder}/${GroupAverageName}.${Hemisphere}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.shape.gii ${CommonFolder}/${GroupAverageName}.${Hemisphere}.midthickness${RegSTRING}.${Mesh}k_fs_LR.surf.gii 10 ${CommonFolder}/${GroupAverageName}.${Hemisphere}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.shape.gii -nearest 
			${Caret7_Command} -add-to-spec-file ${CommonFolder}/${GroupAverageName}${SpecRegSTRING}.${Mesh}k_fs_LR.wb.spec ${Structure} ${CommonFolder}/${GroupAverageName}.${Hemisphere}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.shape.gii
		done

		${Caret7_Command} -add-to-spec-file ${CommonFolder}/${GroupAverageName}${SpecRegSTRING}.${Mesh}k_fs_LR.wb.spec INVALID ${CommonAtlasFolder}/${GroupAverageName}_Average${T1wName}.nii.gz
		${Caret7_Command} -add-to-spec-file ${CommonFolder}/${GroupAverageName}${SpecRegSTRING}.${Mesh}k_fs_LR.wb.spec INVALID ${CommonAtlasFolder}/${GroupAverageName}_Average${T2wName}.nii.gz
		${Caret7_Command} -add-to-spec-file ${CommonFolder}/${GroupAverageName}${SpecRegSTRING}.${Mesh}k_fs_LR.wb.spec INVALID ${CommonAtlasFolder}/${GroupAverageName}_AverageT1wDividedByT2w.nii.gz
	done

	log_Msg "Debug Point 3"

	for Map in ${GreyScaleMaps} ${VideenMaps} ${DistortionMaps} ; do
		log_Msg "Map: ${Map}"

		for Mesh in ${HighResMesh} ${LowResMeshes} ; do
			if [ $Mesh = ${HighResMesh} ] ; then
				CommonFolder=${CommonAtlasFolder}
			else 
				i=1
				for LowResMesh in ${LowResMeshes} ; do
					if [ ${LowResMesh} = ${Mesh} ] ; then
						CommonFolder=`echo ${CommonDownSampleFolders} | cut -d " " -f ${i}`
					fi
					i=$(($i+1))
				done
			fi
			MapMerge=""
			for Subject in ${Subjlist} ; do 
				AtlasFolder="${StudyFolder}/${Subject}/MNINonLinear"
				if [ $Mesh = ${HighResMesh} ] ; then
					Folder=${AtlasFolder}
				else      
					i=1
					for LowResMesh in ${LowResMeshes} ; do
						if [ ${LowResMesh} = ${Mesh} ] ; then
							DownSampleFolderName=`echo ${DownSampleFolderNames} | cut -d " " -f ${i}`
						fi
						i=$(($i+1))
					done
					DownSampleFolder="${StudyFolder}/${Subject}/MNINonLinear/${DownSampleFolderName}"
					Folder=${DownSampleFolder}
				fi
				MapMerge=`echo "${MapMerge} -cifti ${Folder}/${Subject}.${Map}${RegSTRING}.${Mesh}k_fs_LR.dscalar.nii"` 
			done

			if [ ! x`echo ${VideenMaps} | grep -oE "(^| )${Map}" | sed 's/ //g'` = "x" ] ; then
				PaletteStringOne="MODE_AUTO_SCALE_PERCENTAGE"
				PaletteStringTwo="-pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false"
				SpecFile="True"
			elif [ ! x`echo ${GreyScaleMaps} | grep -oE "(^| )${Map}" | sed 's/ //g'` = "x" ] ; then
				PaletteStringOne="MODE_AUTO_SCALE_PERCENTAGE"
				PaletteStringTwo="-pos-percent 2 98 -palette-name Gray_Interp -disp-pos true -disp-neg true -disp-zero true"
				SpecFile="True"
			elif [ ! x`echo ${DistortionMaps} | grep -oE "(^| )${Map}" | sed 's/ //g'` = "x" ] ; then
				PaletteStringOne="MODE_USER_SCALE"
				PaletteStringTwo=" -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false"
				SpecFile="False"
			fi

			if [ ! x`echo ${MultiMaps} | grep -oE "(^| )${Map}" | sed 's/ //g'` = "x" ] ; then
				${Caret7_Command} -cifti-average ${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}.${Mesh}k_fs_LR.dscalar.nii -exclude-outliers 3 3 ${MapMerge}
				SpecFile="False"
			else
				${Caret7_Command} -cifti-merge ${CommonFolder}/${GroupAverageName}.All.${Map}${RegSTRING}.${Mesh}k_fs_LR.dscalar.nii ${MapMerge}
				${Caret7_Command} -cifti-palette ${CommonFolder}/${GroupAverageName}.All.${Map}${RegSTRING}.${Mesh}k_fs_LR.dscalar.nii ${PaletteStringOne} ${CommonFolder}/${GroupAverageName}.All.${Map}${RegSTRING}.${Mesh}k_fs_LR.dscalar.nii ${PaletteStringTwo}
				${Caret7_Command} -cifti-reduce ${CommonFolder}/${GroupAverageName}.All.${Map}${RegSTRING}.${Mesh}k_fs_LR.dscalar.nii MEAN ${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}.${Mesh}k_fs_LR.dscalar.nii -exclude-outliers 3 3
				if [ ${SpecFile} = "True" ] ; then
					${Caret7_Command} -add-to-spec-file ${CommonFolder}/${GroupAverageName}${SpecRegSTRING}.${Mesh}k_fs_LR.wb.spec INVALID ${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}.${Mesh}k_fs_LR.dscalar.nii
				fi
			fi  

			log_Msg "Debug Point 3.5"

			${Caret7_Command} -cifti-palette ${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}.${Mesh}k_fs_LR.dscalar.nii ${PaletteStringOne} ${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}.${Mesh}k_fs_LR.dscalar.nii ${PaletteStringTwo}
			${Caret7_Command} -set-map-name ${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}.${Mesh}k_fs_LR.dscalar.nii 1 ${GroupAverageName}_${Map}${RegSTRING}

			if [ ! x`echo ${DistortionMaps} | grep -oE "(^| )${Map}" | sed 's/ //g'` = "x" ] ; then
				PaletteStringOne="MODE_USER_SCALE"
				PaletteStringTwo="-pos-user 0 1 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false"    
				${Caret7_Command} -cifti-math 'abs(var)' ${CommonFolder}/${GroupAverageName}.All.${Map}${RegSTRING}_abs.${Mesh}k_fs_LR.dscalar.nii -var var ${CommonFolder}/${GroupAverageName}.All.${Map}${RegSTRING}.${Mesh}k_fs_LR.dscalar.nii
				${Caret7_Command} -cifti-palette ${CommonFolder}/${GroupAverageName}.All.${Map}${RegSTRING}_abs.${Mesh}k_fs_LR.dscalar.nii ${PaletteStringOne} ${CommonFolder}/${GroupAverageName}.All.${Map}${RegSTRING}_abs.${Mesh}k_fs_LR.dscalar.nii ${PaletteStringTwo}
				${Caret7_Command} -cifti-reduce ${CommonFolder}/${GroupAverageName}.All.${Map}${RegSTRING}_abs.${Mesh}k_fs_LR.dscalar.nii MEAN ${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}_abs.${Mesh}k_fs_LR.dscalar.nii
				${Caret7_Command} -cifti-palette ${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}_abs.${Mesh}k_fs_LR.dscalar.nii ${PaletteStringOne} ${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}_abs.${Mesh}k_fs_LR.dscalar.nii ${PaletteStringTwo}
				${Caret7_Command} -set-map-name ${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}_abs.${Mesh}k_fs_LR.dscalar.nii 1 ${GroupAverageName}_${Map}${RegSTRING}_abs
			fi

			if [ ! x`echo ${GradientMaps} | grep -oE "(^| )${Map}" | sed 's/ //g'` = "x" ] ; then
				PaletteStringOne="MODE_AUTO_SCALE_PERCENTAGE"
				PaletteStringTwo="-pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false"
				###Workaround
				for Hemisphere in L R ; do
					if [ ${Hemisphere} = "L" ] ; then 
						Structure="CORTEX_LEFT"
					elif [ ${Hemisphere} = "R" ] ; then 
						Structure="CORTEX_RIGHT"
					fi
					if [ ! -e ${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}_grad.${Mesh}k_fs_LR.dscalar.nii ] ; then
						cp ${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}.${Mesh}k_fs_LR.dscalar.nii ${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}_grad.${Mesh}k_fs_LR.dscalar.nii
					fi
					${Caret7_Command} -cifti-separate ${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}.${Mesh}k_fs_LR.dscalar.nii COLUMN -metric ${Structure} ${CommonFolder}/temp${Hemisphere}.func.gii -roi ${CommonFolder}/temp${Hemisphere}ROI.func.gii
					${Caret7_Command} -cifti-separate ${CommonFolder}/${GroupAverageName}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.dscalar.nii COLUMN -metric ${Structure} ${CommonFolder}/temp${Hemisphere}Area.func.gii
					${Caret7_Command} -metric-dilate ${CommonFolder}/temp${Hemisphere}Area.func.gii ${CommonFolder}/${GroupAverageName}.${Hemisphere}.midthickness${RegSTRING}.${Mesh}k_fs_LR.surf.gii 10 ${CommonFolder}/temp${Hemisphere}Area.func.gii -nearest 
					${Caret7_Command} -metric-gradient ${CommonFolder}/${GroupAverageName}.${Hemisphere}.midthickness${RegSTRING}.${Mesh}k_fs_LR.surf.gii ${CommonFolder}/temp${Hemisphere}.func.gii ${CommonFolder}/temp${Hemisphere}Grad.func.gii -presmooth ${Sigma} -roi ${CommonFolder}/temp${Hemisphere}ROI.func.gii -corrected-areas ${CommonFolder}/temp${Hemisphere}Area.func.gii
					${Caret7_Command} -cifti-replace-structure ${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}_grad.${Mesh}k_fs_LR.dscalar.nii COLUMN -metric ${Structure} ${CommonFolder}/temp${Hemisphere}Grad.func.gii
					rm ${CommonFolder}/temp${Hemisphere}.func.gii ${CommonFolder}/temp${Hemisphere}ROI.func.gii ${CommonFolder}/temp${Hemisphere}Area.func.gii ${CommonFolder}/temp${Hemisphere}Grad.func.gii
				done

				#${Caret7_Command} -cifti-gradient ${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}.${Mesh}k_fs_LR.dscalar.nii COLUMN ${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}_grad.${Mesh}k_fs_LR.dscalar.nii -left-surface ${CommonFolder}/${GroupAverageName}.L.midthickness${RegSTRING}.${Mesh}k_fs_LR.surf.gii -right-surface ${CommonFolder}/${GroupAverageName}.R.midthickness${RegSTRING}.${Mesh}k_fs_LR.surf.gii -surface-presmooth ${Sigma}
				###End Workaround

				${Caret7_Command} -set-map-name ${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}_grad.${Mesh}k_fs_LR.dscalar.nii 1 ${GroupAverageName}_${Map}${RegSTRING}_grad
				${Caret7_Command} -cifti-palette ${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}_grad.${Mesh}k_fs_LR.dscalar.nii ${PaletteStringOne} ${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}_grad.${Mesh}k_fs_LR.dscalar.nii ${PaletteStringTwo}
			fi

			log_Msg "Debug Point: 3.9"

			if [ ! x`echo ${STDMaps} | grep -oE "(^| )${Map}" | sed 's/ //g'` = "x" ] ; then
				PaletteStringOne="MODE_AUTO_SCALE_PERCENTAGE"
				PaletteStringTwo="-pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false"
				${Caret7_Command} -cifti-reduce ${CommonFolder}/${GroupAverageName}.All.${Map}${RegSTRING}.${Mesh}k_fs_LR.dscalar.nii STDEV ${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}_std.${Mesh}k_fs_LR.dscalar.nii -exclude-outliers 3 3     
				${Caret7_Command} -set-map-name ${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}_std.${Mesh}k_fs_LR.dscalar.nii 1 ${GroupAverageName}_${Map}${RegSTRING}_std
				${Caret7_Command} -cifti-palette ${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}_std.${Mesh}k_fs_LR.dscalar.nii ${PaletteStringOne} ${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}_std.${Mesh}k_fs_LR.dscalar.nii ${PaletteStringTwo}
			fi
			
		done  
		
	done

	log_Msg "End"
}

#
# Invoke the main function to get things started
#
main $@
