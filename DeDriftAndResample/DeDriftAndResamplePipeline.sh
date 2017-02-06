#!/bin/bash
set -e
g_script_name=`basename ${0}`

source ${HCPPIPEDIR}/global/scripts/log.shlib # Logging related functions
log_SetToolName "${g_script_name}"
log_Debug_On


usage()
{
	echo ""
	echo "  De-Drift and Resample"
	echo ""
	echo "  Usage: ${g_script_name} - TO BE WRITTEN"
	echo "   [--matlab-run-mode={0, 1}] defaults to 0 (Compiled Matlab)"
	echo "     0 = Use compiled Matlab"
	echo "     1 = Use Matlab"
	#echo "     2 = Use Octave"	
	echo ""
}

get_options() 
{
	local arguments=($@)

	# initialize global output variables
	unset g_path_to_study_folder     # StudyFolder
	unset g_subject                  # Subject
	unset g_high_res_mesh            # HighResMesh
	unset g_low_res_meshes           # LowResMeshes - @ delimited list, e.g. 32@59, multiple resolutions not currently supported for fMRI data
	unset g_registration_name        # RegName
	unset g_dedrift_reg_files        # DeDriftRegFiles - @ delimited, L and R outputs from MSMRemoveGroupDrift.sh
	unset g_concat_reg_name          # ConcatRegName
	unset g_maps                     # Maps
	unset g_myelin_maps              # MyelinMaps
	unset g_rfmri_names              # rfMRINames - @ delimited
	unset g_tfmri_names              # tfMRINames - @ delimited
	unset g_smoothing_fwhm           # SmoothingFWHM
	unset g_highpass                 # HighPass
	unset g_myelin_target_file       # MyelinTargetFile
	unset g_input_reg_name           # InRegName - e.g. "_1.6mm"
	unset g_matlab_run_mode             

  # set default values
  g_matlab_run_mode=0

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
			--subject=*)
				g_subject=${argument#*=}
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
			--registration-name=*)
				g_registration_name=${argument#*=}
				index=$(( index + 1 ))
				;;
			--dedrift-reg-files=*)
				g_dedrift_reg_files=${argument#*=}
				index=$(( index + 1 ))
				;;
			--concat-reg-name=*)
				g_concat_reg_name=${argument#*=}
				index=$(( index + 1 ))
				;;
			--maps=*)
				g_maps=${argument#*=}
				index=$(( index + 1 ))
				;;
			--myelin-maps=*)
				g_myelin_maps=${argument#*=}
				index=$(( index + 1 ))
				;;
			--rfmri-names=*)
				g_rfmri_names=${argument#*=}
				index=$(( index + 1 ))
				;;
			--tfmri-names=*)
				g_tfmri_names=${argument#*=}
				index=$(( index + 1 ))
				;;
			--smoothing-fwhm=*)
				g_smoothing_fwhm=${argument#*=}
				index=$(( index + 1 ))
				;;
			--highpass=*)
				g_highpass=${argument#*=}
				index=$(( index + 1 ))
				;;
			--myelin-target-file=*)
				g_myelin_target_file=${argument#*=}
				index=$(( index + 1 ))
				;;
			--input-reg-name=*)
				g_input_reg_name=${argument#*=}
				index=$(( index + 1 ))
				;;
  		--matlab-run-mode=*)
				g_matlab_run_mode=${argument#*=}
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

	if [ -z "${g_subject}" ]; then
		echo "ERROR: subject ID (--subject=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_subject: ${g_subject}"
	fi

	if [ -z "${g_high_res_mesh}" ]; then
		echo "ERROR: high resolution mesh (--high-res-mesh=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_high_res_mesh: ${g_high_res_mesh}"
	fi

	if [ -z "${g_low_res_meshes}" ]; then
		echo "ERROR: log resolution mesh list (--low-res-meshes=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_low_res_meshes: ${g_low_res_meshes}"
	fi

	if [ -z "${g_registration_name}" ]; then
		echo "ERROR: registration name (--registration-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_registration_name: ${g_registration_name}"
	fi

	if [ -z "${g_dedrift_reg_files}" ]; then
		echo "ERROR: De-Drifting registration files (--dedrift-reg-files=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_dedrift_reg_files: ${g_dedrift_reg_files}"
	fi

	if [ -z "${g_concat_reg_name}" ]; then
		echo "ERROR: concatenated registration name (--concat-reg-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_concat_reg_name: ${g_concat_reg_name}"
	fi
	
	if [ -z "${g_maps}" ]; then
		echo "ERROR: list of structural maps to be resampled (--maps=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_maps: ${g_maps}"
	fi

	if [ -z "${g_myelin_maps}" ]; then
		echo "ERROR: list of Myelin maps to be resampled (--myelin-maps) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_myelin_maps: ${g_myelin_maps}"
	fi

	if [ -z "${g_rfmri_names}" ]; then
		echo "ERROR: list of resting state scans (--rfmri-names=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_rfmri_names: ${g_rfmri_names}"
	fi

	if [ -z "${g_tfmri_names}" ]; then
		echo "ERROR: list of task scans (--tfmri-names=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_tfmri_names: ${g_tfmri_names}"
	fi

	if [ -z "${g_smoothing_fwhm}" ]; then
		echo "ERROR: smoothing value (--smoothing-fwhm=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_smoothing_fwhm: ${g_smoothing_fwhm}"
	fi

	if [ -z "${g_highpass}" ]; then
		echo "ERROR: highpass value (--highpass=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_highpass: ${g_highpass}"
	fi

	if [ -n "${g_myelin_target_file}" ]; then
		log_Msg "g_myelin_target_file: ${g_myelin_target_file}"
	fi

	if [ -n "${g_input_reg_name}" ]; then
		log_Msg "g_input_reg_name: ${g_input_reg_name}"
	fi

	if [ -z "${g_matlab_run_mode}" ]; then
		echo "ERROR: matlab run mode value (--matlab-run-mode=) required"
		error_count=$(( error_count + 1 ))
	else
		case ${g_matlab_run_mode} in 
			0)
				;;
			1)
				;;
			# 2)
			#	;;
			*)
				#echo "ERROR: matlab run mode value must be 0, 1, or 2"
				echo "ERROR: matlab run mode value must be 0 or 1"
				error_count=$(( error_count + 1 ))
				;;
		esac
	fi

	if [ ${error_count} -gt 0 ]; then
		echo "For usage information, use --help"
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
}

main()
{
	# Get command line options
	get_options $@

	# Show the versions of tools used
	show_tool_versions

	#Caret7_Command="${1}"
	local Caret7_Command="${CARET7DIR}/wb_command"
	log_Msg "Caret7_Command: ${Caret7_Command}"

	#GitRepo="${2}"
	#FixDir="${3}"

	#StudyFolder="${4}"
	local StudyFolder="${g_path_to_study_folder}"
	log_Msg "StudyFolder: ${StudyFolder}"

	#Subject="${5}"
	local Subject="${g_subject}"
	log_Msg "Subject: ${Subject}"

	#HighResMesh="${6}"
	local HighResMesh="${g_high_res_mesh}"
	log_Msg "HighResMesh: ${HighResMesh}"

	#LowResMeshes="${7}"
	local LowResMeshes="${g_low_res_meshes}"
	log_Msg "LowResMeshes: ${LowResMeshes}"

	#RegName="${8}"
	local RegName="${g_registration_name}"
	log_Msg "RegName: ${RegName}"

	#DeDriftRegFiles="${9}"
	local DeDriftRegFiles="${g_dedrift_reg_files}"
	log_Msg "DeDriftRegFile: ${DeDriftRegFiles}"

	#ConcatRegName="${10}"
	local ConcatRegName="${g_concat_reg_name}"
	log_Msg "ConcatRegName: ${ConcatRegName}"

	#Maps="${11}"
	local Maps="${g_maps}"
	log_Msg "Maps: ${Maps}"

	#MyelinMaps="${12}"
	local MyelinMaps="${g_myelin_maps}"
	log_Msg "MyelinMaps: ${MyelinMaps}"

	#rfMRINames="${13}"
	local rfMRINames="${g_rfmri_names}"
	log_Msg "rfMRINames: ${rfMRINames}"

	#tfMRINames="${14}"
	local tfMRINames="${g_tfmri_names}"
	log_Msg "tfMRINames: ${tfMRINames}"

	#SmoothingFWHM="${15}"
	local SmoothingFWHM="${g_smoothing_fwhm}"
	log_Msg "SmoothingFWHM: ${SmoothingFWHM}"

	#HighPass="${16}"
	local HighPass="${g_highpass}"
	log_Msg "HighPass: ${HighPass}"

	local MyelinTargetFile="${g_myelin_target_file}"
	log_Msg "MyelinTargetFile: ${MyelinTargetFile}"

	local InRegName="${g_input_reg_name}"
	log_Msg "InRegName: ${InRegName}"

	LowResMeshes=`echo ${LowResMeshes} | sed 's/@/ /g'`
	log_Msg "After delimeter substitution, LowResMeshes: ${LowResMeshes}"

	DeDriftRegFiles=`echo "$DeDriftRegFiles" | sed s/"@"/" "/g`
	log_Msg "After delimeter substitution, DeDriftRegFiles: ${DeDriftRegFiles}"

	Maps=`echo "$Maps" | sed s/"@"/" "/g`
	log_Msg "After delimeter substitution, Maps: ${Maps}"

	MyelinMaps=`echo "$MyelinMaps" | sed s/"@"/" "/g`
	log_Msg "After delimeter substitution, MyelinMaps: ${MyelinMaps}"

	rfMRINames=`echo "$rfMRINames" | sed s/"@"/" "/g`
	if [ "${rfMRINames}" = "NONE" ] ; then
		rfMRINames=""
	fi
	log_Msg "After delimeter substitution, rfMRINames: ${rfMRINames}"

	tfMRINames=`echo "$tfMRINames" | sed s/"@"/" "/g`
	if [ "${tfMRINames}" = "NONE" ] ; then
		tfMRINames=""
	fi
	log_Msg "After delimeter substitution, tfMRINames: ${tfMRINames}"

	CorrectionSigma=$(echo "sqrt ( 200 )" | bc -l)
	log_Msg "CorrectionSigma: ${CorrectionSigma}"

	AtlasFolder="${StudyFolder}/${Subject}/MNINonLinear"
	log_Msg "AtlasFolder: ${AtlasFolder}"

	T1wFolder="${StudyFolder}/${Subject}/T1w"
	log_Msg "T1wFolder: ${T1wFolder}"

	#DownSampleFolder="${AtlasFolder}/fsaverage_LR${LowResMesh}k"
	
	NativeFolder="${AtlasFolder}/Native"
	log_Msg "NativeFolder: ${NativeFolder}"

	NativeT1wFolder="${T1wFolder}/Native"
	log_Msg "NativeT1wFolder: ${NativeT1wFolder}"

	ResultsFolder="${AtlasFolder}/Results"
	log_Msg "ResultsFolder: ${ResultsFolder}"

	#DownSampleT1wFolder="${T1wFolder}/fsaverage_LR${LowResMesh}k"

	#Naming Conventions
	local DownSampleFolderNames=""
	local DownSampleT1wFolderNames=""
	for LowResMesh in ${LowResMeshes} ; do
		DownSampleFolderNames=`echo "${DownSampleFolderNames}${AtlasFolder}/fsaverage_LR${LowResMesh}k "`
		DownSampleT1wFolderNames=`echo "${DownSampleT1wFolderNames}${T1wFolder}/fsaverage_LR${LowResMesh}k "`
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

		if [ ! ${RegName} = ${ConcatRegName} ] ; then #Assume this file is already produced
			${Caret7_Command} -surface-sphere-project-unproject ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii ${AtlasFolder}/${Subject}.${Hemisphere}.sphere.${HighResMesh}k_fs_LR.surf.gii ${DeDriftRegFile} ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${ConcatRegName}.native.surf.gii
		fi

		# Make MSM Registration Areal Distortion Maps
		log_Msg "Make MSM Registration Areal Distortion Maps"
		${Caret7_Command} -surface-vertex-areas ${NativeFolder}/${Subject}.${Hemisphere}.sphere.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.native.shape.gii
		${Caret7_Command} -surface-vertex-areas ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${ConcatRegName}.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${ConcatRegName}.native.shape.gii
		${Caret7_Command} -metric-math "ln(spherereg / sphere) / ln(2)" ${NativeFolder}/${Subject}.${Hemisphere}.ArealDistortion_${ConcatRegName}.native.shape.gii -var sphere ${NativeFolder}/${Subject}.${Hemisphere}.sphere.native.shape.gii -var spherereg ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${ConcatRegName}.native.shape.gii
		rm ${NativeFolder}/${Subject}.${Hemisphere}.sphere.native.shape.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${ConcatRegName}.native.shape.gii

		${Caret7_Command} -surface-distortion ${NativeFolder}/${Subject}.${Hemisphere}.sphere.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${ConcatRegName}.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.EdgeDistortion_${ConcatRegName}.native.shape.gii -edge-method 
	done

	${Caret7_Command} -cifti-create-dense-timeseries ${NativeFolder}/${Subject}.ArealDistortion_${ConcatRegName}.native.dtseries.nii -left-metric ${NativeFolder}/${Subject}.L.ArealDistortion_${ConcatRegName}.native.shape.gii -roi-left ${NativeFolder}/${Subject}.L.atlasroi.native.shape.gii -right-metric ${NativeFolder}/${Subject}.R.ArealDistortion_${ConcatRegName}.native.shape.gii -roi-right ${NativeFolder}/${Subject}.R.atlasroi.native.shape.gii
	${Caret7_Command} -cifti-convert-to-scalar ${NativeFolder}/${Subject}.ArealDistortion_${ConcatRegName}.native.dtseries.nii ROW ${NativeFolder}/${Subject}.ArealDistortion_${ConcatRegName}.native.dscalar.nii
	${Caret7_Command} -set-map-name ${NativeFolder}/${Subject}.ArealDistortion_${ConcatRegName}.native.dscalar.nii 1 ${Subject}_ArealDistortion_${ConcatRegName}
	${Caret7_Command} -cifti-palette ${NativeFolder}/${Subject}.ArealDistortion_${ConcatRegName}.native.dscalar.nii MODE_USER_SCALE ${NativeFolder}/${Subject}.ArealDistortion_${ConcatRegName}.native.dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false
	rm ${NativeFolder}/${Subject}.ArealDistortion_${ConcatRegName}.native.dtseries.nii 

	${Caret7_Command} -cifti-create-dense-timeseries ${NativeFolder}/${Subject}.EdgeDistortion_${ConcatRegName}.native.dtseries.nii -left-metric ${NativeFolder}/${Subject}.L.EdgeDistortion_${ConcatRegName}.native.shape.gii -roi-left ${NativeFolder}/${Subject}.L.atlasroi.native.shape.gii -right-metric ${NativeFolder}/${Subject}.R.EdgeDistortion_${ConcatRegName}.native.shape.gii -roi-right ${NativeFolder}/${Subject}.R.atlasroi.native.shape.gii
	${Caret7_Command} -cifti-convert-to-scalar ${NativeFolder}/${Subject}.EdgeDistortion_${ConcatRegName}.native.dtseries.nii ROW ${NativeFolder}/${Subject}.EdgeDistortion_${ConcatRegName}.native.dscalar.nii
	${Caret7_Command} -set-map-name ${NativeFolder}/${Subject}.EdgeDistortion_${ConcatRegName}.native.dscalar.nii 1 ${Subject}_EdgeDistortion_${ConcatRegName}
	${Caret7_Command} -cifti-palette ${NativeFolder}/${Subject}.EdgeDistortion_${ConcatRegName}.native.dscalar.nii MODE_USER_SCALE ${NativeFolder}/${Subject}.EdgeDistortion_${ConcatRegName}.native.dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false
	rm ${NativeFolder}/${Subject}.EdgeDistortion_${ConcatRegName}.native.dtseries.nii 

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

		if [ -e ${Folder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec ] ; then
			rm ${Folder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec
		fi

		${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec INVALID ${AtlasFolder}/T1w_restore.nii.gz
		${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec INVALID ${AtlasFolder}/T2w_restore.nii.gz

		if [ ! ${Mesh} = ${HighResMesh} ] ; then
			if [ -e ${DownSampleT1wFolder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec ] ; then
				rm ${DownSampleT1wFolder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec
			fi

			${Caret7_Command} -add-to-spec-file ${DownSampleT1wFolder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec INVALID ${T1wFolder}/T1w_acpc_dc_restore.nii.gz
			${Caret7_Command} -add-to-spec-file ${DownSampleT1wFolder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec INVALID ${T1wFolder}/T2w_acpc_dc_restore.nii.gz
		fi

		for Hemisphere in L R ; do
			if [ $Hemisphere = "L" ] ; then 
				Structure="CORTEX_LEFT"
			elif [ $Hemisphere = "R" ] ; then 
				Structure="CORTEX_RIGHT"
			fi
			log_Msg "Hemisphere: ${Hemisphere}"
			log_Msg "Structure: ${Structure}"

			${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${Folder}/${Subject}.${Hemisphere}.sphere.${Mesh}k_fs_LR.surf.gii
			if [ -e ${Folder}/${Subject}.${Hemisphere}.flat.${Mesh}k_fs_LR.surf.gii ] ; then
				${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${Folder}/${Subject}.${Hemisphere}.flat.${Mesh}k_fs_LR.surf.gii
			fi

			# Create downsampled fs_LR spec files.   
			log_Msg "Create downsampled fs_LR spec files."
			for Surface in white midthickness pial ; do
				${Caret7_Command} -surface-resample ${NativeFolder}/${Subject}.${Hemisphere}.${Surface}.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${ConcatRegName}.native.surf.gii ${Folder}/${Subject}.${Hemisphere}.sphere.${Mesh}k_fs_LR.surf.gii BARYCENTRIC ${Folder}/${Subject}.${Hemisphere}.${Surface}_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii
				${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${Folder}/${Subject}.${Hemisphere}.${Surface}_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii
			done

			log_Debug_Msg "0.1"
			local anatomical_surface_in=${Folder}/${Subject}.${Hemisphere}.midthickness_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii
			log_File_Must_Exist "${anatomical_surface_in}"
			${Caret7_Command} -surface-generate-inflated ${anatomical_surface_in} ${Folder}/${Subject}.${Hemisphere}.inflated_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii ${Folder}/${Subject}.${Hemisphere}.very_inflated_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii -iterations-scale ${Scale}
			${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${Folder}/${Subject}.${Hemisphere}.inflated_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii
			${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${Folder}/${Subject}.${Hemisphere}.very_inflated_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii
    
			if [ ! ${Mesh} = ${HighResMesh} ] ; then
				# Create downsampled fs_LR spec file in structural space.  
				log_Msg "Create downsampled fs_LR spec file in structural space."
				
				for Surface in white midthickness pial ; do
					${Caret7_Command} -surface-resample ${NativeT1wFolder}/${Subject}.${Hemisphere}.${Surface}.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${ConcatRegName}.native.surf.gii ${Folder}/${Subject}.${Hemisphere}.sphere.${Mesh}k_fs_LR.surf.gii BARYCENTRIC ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.${Surface}_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii
					${Caret7_Command} -add-to-spec-file ${DownSampleT1wFolder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.${Surface}_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii
				done

				log_Debug_Msg "0.2"
				anatomical_surface_in=${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii
				log_File_Must_Exist "${anatomical_surface_in}"
				${Caret7_Command} -surface-generate-inflated ${anatomical_surface_in} ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.inflated_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.very_inflated_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii -iterations-scale ${Scale}
				${Caret7_Command} -add-to-spec-file ${DownSampleT1wFolder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.inflated_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii
				${Caret7_Command} -add-to-spec-file ${DownSampleT1wFolder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.very_inflated_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii

				# Compute vertex areas for other analyses
				log_Msg "Create vertex areas for other analyses"

				log_Debug_Msg "0.3"
				local surface=${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii
				log_File_Must_Exist "${surface}"
				${Caret7_Command} -surface-vertex-areas ${surface} ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_${ConcatRegName}_va.${Mesh}k_fs_LR.shape.gii 

				${Caret7_Command} -add-to-spec-file ${DownSampleT1wFolder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${Folder}/${Subject}.${Hemisphere}.sphere.${Mesh}k_fs_LR.surf.gii
				if [ -e ${Folder}/${Subject}.${Hemisphere}.flat.${Mesh}k_fs_LR.surf.gii ] ; then
					${Caret7_Command} -add-to-spec-file ${DownSampleT1wFolder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${Folder}/${Subject}.${Hemisphere}.flat.${Mesh}k_fs_LR.surf.gii
				fi
			fi  
		done

		if [ ! ${Mesh} = ${HighResMesh} ] ; then 
			# Normalize vertex areas mean to 1 for other analyses
			log_Msg "Normalize vertex areas mean to 1 for other analyses"
			${Caret7_Command} -cifti-create-dense-scalar ${DownSampleT1wFolder}/${Subject}.midthickness_${ConcatRegName}_va.${Mesh}k_fs_LR.dscalar.nii -left-metric ${DownSampleT1wFolder}/${Subject}.L.midthickness_${ConcatRegName}_va.${Mesh}k_fs_LR.shape.gii -roi-left ${Folder}/${Subject}.L.atlasroi.${Mesh}k_fs_LR.shape.gii -right-metric ${DownSampleT1wFolder}/${Subject}.R.midthickness_${ConcatRegName}_va.${Mesh}k_fs_LR.shape.gii -roi-right ${Folder}/${Subject}.R.atlasroi.${Mesh}k_fs_LR.shape.gii
			VAMean=`${Caret7_Command} -cifti-stats ${DownSampleT1wFolder}/${Subject}.midthickness_${ConcatRegName}_va.${Mesh}k_fs_LR.dscalar.nii -reduce MEAN`
			${Caret7_Command} -cifti-math "VA / ${VAMean}" ${DownSampleT1wFolder}/${Subject}.midthickness_${ConcatRegName}_va_norm.${Mesh}k_fs_LR.dscalar.nii -var VA ${DownSampleT1wFolder}/${Subject}.midthickness_${ConcatRegName}_va.${Mesh}k_fs_LR.dscalar.nii
		fi
    
		# Resample scalar maps and apply new bias field
		log_Msg "Resample scalar maps and apply new bias field"

		for Map in ${Maps} ${MyelinMaps} SphericalDistortion ArealDistortion EdgeDistortion ; do
			log_Msg "Map: ${Map}"

			for MapMap in ${MyelinMaps} ; do
				log_Msg "MapMap: ${MapMap}"

				if [ ${MapMap} = ${Map} ] ; then

					# ----- Begin moved statements -----

					# Recompute Myelin Map Bias Field Based on Better Registration
					log_Msg "Recompute Myelin Map Bias Field Based on Better Registration"

					local cifti_in=${NativeFolder}/${Subject}.MyelinMap.native.dscalar.nii
					log_File_Must_Exist "${cifti_in}" # 1

					local cifti_template=${DownSampleFolder}/${Subject}.MyelinMap.${LowResMesh}k_fs_LR.dscalar.nii
					log_File_Must_Exist "${cifti_template}" # 2

					local cifti_out=${DownSampleFolder}/${Subject}.MyelinMap_${ConcatRegName}.${LowResMesh}k_fs_LR.dscalar.nii

					local left_spheres_current_sphere=${NativeFolder}/${Subject}.L.sphere.${ConcatRegName}.native.surf.gii
					log_File_Must_Exist "${left_spheres_current_sphere}" # 3

					local left_spheres_new_sphere=${DownSampleFolder}/${Subject}.L.sphere.${LowResMesh}k_fs_LR.surf.gii
					log_File_Must_Exist "${left_spheres_new_sphere}" # 4

					local left_area_surfs_current_area=${NativeT1wFolder}/${Subject}.L.midthickness.native.surf.gii
					log_File_Must_Exist "${left_area_surfs_current_area}" # 5

					local left_area_surfs_new_area=${DownSampleT1wFolder}/${Subject}.L.midthickness_${ConcatRegName}.${LowResMesh}k_fs_LR.surf.gii
					log_File_Must_Exist "${left_area_surfs_new_area}" # 6 - This is the one that doesn't exist

					local right_spheres_current_sphere=${NativeFolder}/${Subject}.R.sphere.${ConcatRegName}.native.surf.gii
					log_File_Must_Exist "${right_spheres_current_sphere}"

					local right_spheres_new_sphere=${DownSampleFolder}/${Subject}.R.sphere.${LowResMesh}k_fs_LR.surf.gii
					log_File_Must_Exist "${right_spheres_new_sphere}"

					local right_area_surfs_current_area=${NativeT1wFolder}/${Subject}.R.midthickness.native.surf.gii
					log_File_Must_Exist "${right_area_surfs_current_area}"

					local right_area_surfs_new_area=${DownSampleT1wFolder}/${Subject}.R.midthickness_${ConcatRegName}.${LowResMesh}k_fs_LR.surf.gii
					log_File_Must_Exist "${right_area_surfs_new_area}"

					log_Debug_Msg "Point 1.1"

					${Caret7_Command} -cifti-resample ${cifti_in} COLUMN ${cifti_template} COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${cifti_out} -surface-postdilate 40 -left-spheres ${left_spheres_current_sphere} ${left_spheres_new_sphere} -left-area-surfs ${left_area_surfs_current_area} ${left_area_surfs_new_area} -right-spheres ${right_spheres_current_sphere} ${right_spheres_new_sphere} -right-area-surfs ${right_area_surfs_current_area} ${right_area_surfs_new_area}

					log_Debug_Msg "Point 1.2"

					if [ ! -e ${DownSampleFolder}/${Subject}.atlas_MyelinMap_BC.${LowResMesh}k_fs_LR.dscalar.nii ] ; then
						if [ -n ${MyelinTargetFile} ] ; then
							cp --verbose ${MyelinTargetFile} ${DownSampleFolder}/${Subject}.atlas_MyelinMap_BC.${LowResMesh}k_fs_LR.dscalar.nii
						else
							echo "A ${MyelinTargetFile} is required to run this pipeline when using a different mesh resolution than the original MSMAll registration"
							exit 1
						fi
					fi

					${Caret7_Command} -cifti-math "Individual - Reference" ${DownSampleFolder}/${Subject}.BiasField_${ConcatRegName}.${LowResMesh}k_fs_LR.dscalar.nii -var Individual ${DownSampleFolder}/${Subject}.MyelinMap_${ConcatRegName}.${LowResMesh}k_fs_LR.dscalar.nii -var Reference ${DownSampleFolder}/${Subject}.atlas_MyelinMap_BC.${LowResMesh}k_fs_LR.dscalar.nii
					${Caret7_Command} -cifti-smoothing ${DownSampleFolder}/${Subject}.BiasField_${ConcatRegName}.${LowResMesh}k_fs_LR.dscalar.nii ${CorrectionSigma} 0 COLUMN ${DownSampleFolder}/${Subject}.BiasField_${ConcatRegName}.${LowResMesh}k_fs_LR.dscalar.nii -left-surface ${DownSampleT1wFolder}/${Subject}.L.midthickness_${ConcatRegName}.${LowResMesh}k_fs_LR.surf.gii -right-surface ${DownSampleT1wFolder}/${Subject}.R.midthickness_${ConcatRegName}.${LowResMesh}k_fs_LR.surf.gii
					${Caret7_Command} -cifti-resample ${DownSampleFolder}/${Subject}.BiasField_${ConcatRegName}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ${NativeFolder}/${Subject}.MyelinMap.native.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${NativeFolder}/${Subject}.BiasField_${ConcatRegName}.native.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${Subject}.L.sphere.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.L.sphere.${ConcatRegName}.native.surf.gii -left-area-surfs ${DownSampleT1wFolder}/${Subject}.L.midthickness_${ConcatRegName}.${LowResMesh}k_fs_LR.surf.gii ${NativeT1wFolder}/${Subject}.L.midthickness.native.surf.gii -right-spheres ${DownSampleFolder}/${Subject}.R.sphere.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.R.sphere.${ConcatRegName}.native.surf.gii -right-area-surfs ${DownSampleT1wFolder}/${Subject}.R.midthickness_${ConcatRegName}.${LowResMesh}k_fs_LR.surf.gii ${NativeT1wFolder}/${Subject}.R.midthickness.native.surf.gii 

					# ----- End moved statements -----

					${Caret7_Command} -cifti-math "Var - Bias" ${NativeFolder}/${Subject}.${Map}_BC_${ConcatRegName}.native.dscalar.nii -var Var ${NativeFolder}/${Subject}.${Map}.native.dscalar.nii -var Bias ${NativeFolder}/${Subject}.BiasField_${ConcatRegName}.native.dscalar.nii
					Map="${Map}_BC"

					log_Debug_Msg "Point 1.3"
				fi
			done

			log_Debug_Msg "Point 2.0"

			if [[ ${Map} = "ArealDistortion" || ${Map} = "EdgeDistortion" || ${Map} = "MyelinMap_BC" || ${Map} = "SmoothedMyelinMap_BC" ]] ; then
				NativeMap="${Map}_${ConcatRegName}"
			else
				NativeMap="${Map}"
			fi

			log_Debug_Msg "Point 3.0"

			if [ ! ${Mesh} = ${HighResMesh} ] ; then
				${Caret7_Command} -cifti-resample ${NativeFolder}/${Subject}.${NativeMap}.native.dscalar.nii COLUMN ${Folder}/${Subject}.MyelinMap_BC.${Mesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${Folder}/${Subject}.${Map}_${ConcatRegName}.${Mesh}k_fs_LR.dscalar.nii -surface-postdilate 30 -left-spheres ${NativeFolder}/${Subject}.L.sphere.${ConcatRegName}.native.surf.gii ${Folder}/${Subject}.L.sphere.${Mesh}k_fs_LR.surf.gii -left-area-surfs ${NativeT1wFolder}/${Subject}.L.midthickness.native.surf.gii ${DownSampleT1wFolder}/${Subject}.L.midthickness_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii -right-spheres ${NativeFolder}/${Subject}.R.sphere.${ConcatRegName}.native.surf.gii ${Folder}/${Subject}.R.sphere.${Mesh}k_fs_LR.surf.gii -right-area-surfs ${NativeT1wFolder}/${Subject}.R.midthickness.native.surf.gii ${DownSampleT1wFolder}/${Subject}.R.midthickness_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii
				for MapMap in ${Maps} ${MyelinMaps} ; do
					if [[ ${MapMap} = ${Map} || ${MapMap}_BC = ${Map} ]] ; then
						${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec INVALID ${Folder}/${Subject}.${Map}_${ConcatRegName}.${Mesh}k_fs_LR.dscalar.nii
						${Caret7_Command} -add-to-spec-file ${DownSampleT1wFolder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec INVALID ${Folder}/${Subject}.${Map}_${ConcatRegName}.${Mesh}k_fs_LR.dscalar.nii
					fi
				done
			else
				${Caret7_Command} -cifti-resample ${NativeFolder}/${Subject}.${NativeMap}.native.dscalar.nii COLUMN ${Folder}/${Subject}.MyelinMap_BC.${Mesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${Folder}/${Subject}.${Map}_${ConcatRegName}.${Mesh}k_fs_LR.dscalar.nii -surface-postdilate 30 -left-spheres ${NativeFolder}/${Subject}.L.sphere.${ConcatRegName}.native.surf.gii ${Folder}/${Subject}.L.sphere.${Mesh}k_fs_LR.surf.gii -left-area-surfs ${NativeT1wFolder}/${Subject}.L.midthickness.native.surf.gii ${Folder}/${Subject}.L.midthickness_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii -right-spheres ${NativeFolder}/${Subject}.R.sphere.${ConcatRegName}.native.surf.gii ${Folder}/${Subject}.R.sphere.${Mesh}k_fs_LR.surf.gii -right-area-surfs ${NativeT1wFolder}/${Subject}.R.midthickness.native.surf.gii ${Folder}/${Subject}.R.midthickness_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii   
				for MapMap in ${Maps} ${MyelinMaps} ; do
					if [[ ${MapMap} = ${Map} || ${MapMap}_BC = ${Map} ]] ; then
						${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec INVALID ${Folder}/${Subject}.${Map}_${ConcatRegName}.${Mesh}k_fs_LR.dscalar.nii
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
		${Caret7_Command} -add-to-spec-file ${NativeFolder}/${Subject}.native.wb.spec INVALID ${NativeFolder}/${Subject}.${Map}_BC_${ConcatRegName}.native.dscalar.nii
		log_Debug_Msg "Point 6.2"
		${Caret7_Command} -add-to-spec-file ${NativeT1wFolder}/${Subject}.native.wb.spec INVALID ${NativeFolder}/${Subject}.${Map}_BC_${ConcatRegName}.native.dscalar.nii
		log_Debug_Msg "Point 6.3"
	done

	log_Debug_Msg "Point 7.0"

	# Set Variables (Does not support multiple resolution meshes):
	DownSampleFolder=`echo ${DownSampleFolderNames} | cut -d " " -f 1`
	DownSampleT1wFolder=`echo ${DownSampleT1wFolderNames} | cut -d " " -f 1`
	LowResMesh=`echo ${LowResMeshes} | cut -d " " -f 1`

	# Resample (and resmooth) TS from Native 
	log_Msg "Resample (and resmooth) TS from Native"
	for fMRIName in ${rfMRINames} ${tfMRINames} ; do
		log_Msg "fMRIName: ${fMRIName}"
		cp ${ResultsFolder}/${fMRIName}/${fMRIName}_Atlas${InRegName}.dtseries.nii ${ResultsFolder}/${fMRIName}/${fMRIName}_Atlas_${ConcatRegName}.dtseries.nii
		for Hemisphere in L R ; do
			if [ $Hemisphere = "L" ] ; then 
				Structure="CORTEX_LEFT"
			elif [ $Hemisphere = "R" ] ; then 
				Structure="CORTEX_RIGHT"
			fi 

			log_Msg "Hemisphere: ${Hemisphere}"
			log_Msg "Structure: ${Structure}"

			${Caret7_Command} -metric-resample ${ResultsFolder}/${fMRIName}/${fMRIName}.${Hemisphere}.native.func.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${ConcatRegName}.native.surf.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii ADAP_BARY_AREA ${ResultsFolder}/${fMRIName}/${fMRIName}_${ConcatRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii -area-surfs ${NativeT1wFolder}/${Subject}.${Hemisphere}.midthickness.native.surf.gii ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_${ConcatRegName}.${LowResMesh}k_fs_LR.surf.gii -current-roi ${NativeFolder}/${Subject}.${Hemisphere}.roi.native.shape.gii
			${Caret7_Command} -metric-dilate ${ResultsFolder}/${fMRIName}/${fMRIName}_${ConcatRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_${ConcatRegName}.${LowResMesh}k_fs_LR.surf.gii 30 ${ResultsFolder}/${fMRIName}/${fMRIName}_${ConcatRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii -nearest
			${Caret7_Command} -metric-mask ${ResultsFolder}/${fMRIName}/${fMRIName}_${ConcatRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii ${ResultsFolder}/${fMRIName}/${fMRIName}_${ConcatRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii
			Sigma=`echo "$SmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`
			${Caret7_Command} -metric-smoothing ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_${ConcatRegName}.${LowResMesh}k_fs_LR.surf.gii ${ResultsFolder}/${fMRIName}/${fMRIName}_${ConcatRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii ${Sigma} ${ResultsFolder}/${fMRIName}/${fMRIName}_s${SmoothingFWHM}_${ConcatRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii -roi ${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii
			${Caret7_Command} -cifti-replace-structure ${ResultsFolder}/${fMRIName}/${fMRIName}_Atlas_${ConcatRegName}.dtseries.nii COLUMN -metric ${Structure} ${ResultsFolder}/${fMRIName}/${fMRIName}_s${SmoothingFWHM}_${ConcatRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii
		done
	done

	# ReApply FIX Cleanup
	log_Msg "ReApply FIX Cleanup"
	for fMRIName in ${rfMRINames} ; do
		log_Msg "fMRIName: ${fMRIName}"
		#${HCPPIPEDIR}/ReApplyFix/ReApplyFixPipeline.sh ${Caret7_Command} ${GitRepo} ${FixDir} ${StudyFolder} ${Subject} ${fMRIName} ${HighPass} ${ConcatRegName} 
		${HCPPIPEDIR}/ReApplyFix/ReApplyFixPipeline.sh --path=${StudyFolder} --subject=${Subject} --fmri-name=${fMRIName} --high-pass=${HighPass} --reg-name=${ConcatRegName} --matlab-run-mode=${g_matlab_run_mode}
	done
	
	log_Msg "End"
}

#
# Invoke the main function to get things started
#
main $@
