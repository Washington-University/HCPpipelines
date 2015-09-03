#!/bin/bash

# ------------------------------------------------------------------------------
#  Code Start
# ------------------------------------------------------------------------------

# If any command exit with non-zero value, this script exits
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
	echo "  De-Drift and Resample"
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
#Caret7_Command="${1}"   ${CARET7_DIR}/wb_command
#GitRepo="${2}"          ${HCPPIPEDIR}
#FixDir="${3}"           ${ICAFIX}

#StudyFolder="${4}"
#Subject="${5}"
#HighResMesh="${6}"
#LowResMeshes="${7}"
#RegName="${8}"
#DeDriftRegFiles="${9}"
#ConcatRegName="${10}"
#Maps="${11}"
#MyelinMaps="${12}"
#rfMRINames="${13}"
#tfMRINames="${14}"
#SmoothingFWHM="${15}"
#HighPass="${16}"

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
				g_path_to_study_folder=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--study-folder=*)
				g_path_to_study_folder=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--subject=*)
				g_subject=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--high-res-mesh=*)
				g_high_res_mesh=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--low-res-meshes=*)
				g_low_res_meshes=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--registration-name=*)
				g_registration_name=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--dedrift-reg-files=*)
				g_dedrift_reg_files=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--concat-reg-name=*)
				g_concat_reg_name=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--maps=*)
				g_maps=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--myelin-maps=*)
				g_myelin_maps=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--rfmri-names=*)
				g_rfmri_names=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--tfmri-names=*)
				g_tfmri_names=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--smoothing-fwhm=*)
				g_smoothing_fwhm=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--highpass=*)
				g_highpass=${argument/*=/""}
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

	if [ -z "${g_myeline_maps}" ]; then
		echo "ERROR: list of Myelin maps to be resampled (--myeline-maps) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_myeline_maps: ${g_myeline_maps}"
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

	if [ ${error_count} -gt 0 ]; then
		echo "For usage information, use --help"
		exit 1
	fi
}

show_tool_version()
{
	# Show HCP pipelines version
	log_Msg "Showing HCP Pipelines version"
	cat ${HCPPIPEDIR}/veersion.txt

	# Show wb_command version
	log_Msg "Showing Connectome Workbench (wb_command) version"
	${CARET7DIR}/wb_command -version
}

main()
{
	# Get command line opitons
	get_options $@

	# show the versions of tools used
	show_tool_versions

	Caret7_Command="${CARET7DIR}/wb_command"
	log_Msg "Caret7_Command: ${Caret7_Command}"

	#GitRepo="${2}"
	#FixDir="${3}"

	StudyFolder="${g_path_to_study_folder}"
	log_Msg "StudyFolder: ${StudyFolder}"

	Subject="${g_subject}"
	log_Msg "Subject: ${Subject}"

	HighResMesh="${g_high_res_mesh}"
	log_Msg "HighResMesh: ${HighResMesh}"

	LowResMeshes="${g_low_res_meshes}"
	log_Msg "LowResMeshes: ${LowResMeshes}"

	RegName="${g_registration_name}"
	log_Msg "RegName: ${RegName}"

	DeDriftRegFiles="${g_dedrift_reg_files}"
	log_Msg "DeDriftRegFile: ${DeDriftRegFiles}"

	ConcatRegName="${g_concat_reg_name}"
	log_Msg "ConcatRegName: ${ConcatRegName}"

	Maps="${g_maps}"
	log_Msg "Maps: ${Maps}"
	
	MyelinMaps="${g_myelin_maps}"
	log_Msg "MyelinMaps: ${MyelinMaps}"

	rfMRINames="${g_rfmri_names}"
	log_Msg "rfMRINames: ${rfMRINames}"

	tfMRINames="${g_tfmri_names}"
	log_Msg "tfMRINames: ${tfMRINames}"

	SmoothingFWHM="${g_smoothing_fwhm}"
	log_Msg "SmoothingFWHM: ${SmoothingFWHM}"

	HighPass="${g_highpass}"
	log_Msg "HighPass: ${HighPass}"

	LowResMeshes=`echo ${LowResMeshes} | sed 's/@/ /g'`
	log_Msg "After delimeter substitution, LowResMeshes: ${LowResMeshes}"

	DeDriftRegFiles=`echo "$DeDriftRegFiles" | sed s/"@"/" "/g`
	log_Msg "After delimeter substitution, DeDriftRegFiiles: ${DeDriftRegFiles}"

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

	NativeFolder="${AtlasFolder}/Native"
	log_Msg "NativeFolder: ${NativeFolder}"

	NativeT1wFolder="${T1wFolder}/Native"
	log_Msg "NativeT1wFolder: ${NativeT1wFolder}"

	ResultsFolder="${AtlasFolder}/Results"
	log_Msg "ResultsFolder: ${ResultsFolder}"

	# Naming Conventions
	DownSampleFolderNames=""
	DownSampleT1wFolderNames=""
	for LowResMesh in ${LowResMeshes} ; do
		DownSampleFolderNames=`echo "${DownSampleFolderNames}${AtlasFolder}/fsaverage_LR${LowResMesh}k "`
		DownSampleT1wFolderNames=`echo "${DownSampleT1wFolderNames}${T1wFolder}/fsaverage_LR${LowResMesh}k "`
	done
	log_Msg "DownSampleFolderNames: ${DownSampleFolderNames}"
	log_Msg "DownSampleT1wFolderNames: ${DownSampleT1wFolderNamese}"

	# Concat Reg
	for Hemisphere in L R ; do
		if [ $Hemisphere = "L" ] ; then 
			Structure="CORTEX_LEFT"
			DeDriftRegFile=`echo ${DeDriftRegFiles} | cut -d " " -f 1`
		elif [ $Hemisphere = "R" ] ; then 
			Structure="CORTEX_RIGHT"
			DeDriftRegFile=`echo ${DeDriftRegFiles} | cut -d " " -f 2`
		fi 

ici ici


		if [ ! ${RegName} = ${ConcatRegName} ] ; then #Assume this file is already produced
			${Caret7_Command} -surface-sphere-project-unproject ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii ${AtlasFolder}/${Subject}.${Hemisphere}.sphere.${HighResMesh}k_fs_LR.surf.gii ${DeDriftRegFile} ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${ConcatRegName}.native.surf.gii
  fi
  
  #Make MSM Registration Areal Distortion Maps
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
DownSampleT1wFolder=`echo ${DownSampleT1wFolderNames} | cut -d " " -f 1`
LowResMesh=`echo ${LowResMeshes} | cut -d " " -f 1`

#Recompute Myelin Map Bias Field Based on Better Registration
${Caret7_Command} -cifti-resample ${NativeFolder}/${Subject}.MyelinMap.native.dscalar.nii COLUMN ${DownSampleFolder}/${Subject}.MyelinMap.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${Subject}.MyelinMap_${ConcatRegName}.${LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${NativeFolder}/${Subject}.L.sphere.${ConcatRegName}.native.surf.gii ${DownSampleFolder}/${Subject}.L.sphere.${LowResMesh}k_fs_LR.surf.gii -left-area-surfs ${NativeT1wFolder}/${Subject}.L.midthickness.native.surf.gii ${DownSampleFolder}/${Subject}.L.midthickness_${ConcatRegName}.${LowResMesh}k_fs_LR.surf.gii -right-spheres ${NativeFolder}/${Subject}.R.sphere.${ConcatRegName}.native.surf.gii ${DownSampleFolder}/${Subject}.R.sphere.${LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${NativeT1wFolder}/${Subject}.R.midthickness.native.surf.gii ${DownSampleFolder}/${Subject}.R.midthickness_${ConcatRegName}.${LowResMesh}k_fs_LR.surf.gii
${Caret7_Command} -cifti-math "Individual - Reference" ${DownSampleFolder}/${Subject}.BiasField_${ConcatRegName}.${LowResMesh}k_fs_LR.dscalar.nii -var Individual ${DownSampleFolder}/${Subject}.MyelinMap_${ConcatRegName}.${LowResMesh}k_fs_LR.dscalar.nii -var Reference ${DownSampleFolder}/${Subject}.atlas_MyelinMap_BC.${LowResMesh}k_fs_LR.dscalar.nii
${Caret7_Command} -cifti-smoothing ${DownSampleFolder}/${Subject}.BiasField_${ConcatRegName}.${LowResMesh}k_fs_LR.dscalar.nii ${CorrectionSigma} 0 COLUMN ${DownSampleFolder}/${Subject}.BiasField_${ConcatRegName}.${LowResMesh}k_fs_LR.dscalar.nii -left-surface ${DownSampleFolder}/${Subject}.L.midthickness_${ConcatRegName}.${LowResMesh}k_fs_LR.surf.gii -right-surface ${DownSampleFolder}/${Subject}.R.midthickness_${ConcatRegName}.${LowResMesh}k_fs_LR.surf.gii
${Caret7_Command} -cifti-resample ${DownSampleFolder}/${Subject}.BiasField_${ConcatRegName}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ${NativeFolder}/${Subject}.MyelinMap.native.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${NativeFolder}/${Subject}.BiasField_${ConcatRegName}.native.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${Subject}.L.sphere.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.L.sphere.${ConcatRegName}.native.surf.gii -left-area-surfs ${DownSampleFolder}/${Subject}.L.midthickness_${ConcatRegName}.${LowResMesh}k_fs_LR.surf.gii ${NativeT1wFolder}/${Subject}.L.midthickness.native.surf.gii -right-spheres ${DownSampleFolder}/${Subject}.R.sphere.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.R.sphere.${ConcatRegName}.native.surf.gii -right-area-surfs ${DownSampleFolder}/${Subject}.R.midthickness_${ConcatRegName}.${LowResMesh}k_fs_LR.surf.gii ${NativeT1wFolder}/${Subject}.R.midthickness.native.surf.gii 

#Supports multiple lowres meshes
for Mesh in ${HighResMesh} ${LowResMeshes} ; do
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

    ${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${Folder}/${Subject}.${Hemisphere}.sphere.${Mesh}k_fs_LR.surf.gii
    if [ -e ${Folder}/${Subject}.${Hemisphere}.flat.${Mesh}k_fs_LR.surf.gii ] ; then
      ${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${Folder}/${Subject}.${Hemisphere}.flat.${Mesh}k_fs_LR.surf.gii
    fi

    #Create downsampled fs_LR spec files.   
    for Surface in white midthickness pial ; do
      ${Caret7_Command} -surface-resample ${NativeFolder}/${Subject}.${Hemisphere}.${Surface}.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${ConcatRegName}.native.surf.gii ${Folder}/${Subject}.${Hemisphere}.sphere.${Mesh}k_fs_LR.surf.gii BARYCENTRIC ${Folder}/${Subject}.${Hemisphere}.${Surface}_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii
      ${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${Folder}/${Subject}.${Hemisphere}.${Surface}_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii
    done
    ${Caret7_Command} -surface-generate-inflated ${Folder}/${Subject}.${Hemisphere}.midthickness_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii ${Folder}/${Subject}.${Hemisphere}.inflated_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii ${Folder}/${Subject}.${Hemisphere}.very_inflated_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii -iterations-scale ${Scale}
    ${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${Folder}/${Subject}.${Hemisphere}.inflated_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii
    ${Caret7_Command} -add-to-spec-file ${Folder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${Folder}/${Subject}.${Hemisphere}.very_inflated_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii
    
    if [ ! ${Mesh} = ${HighResMesh} ] ; then
      #Create downsampled fs_LR spec file in structural space.  
      for Surface in white midthickness pial ; do
        ${Caret7_Command} -surface-resample ${NativeT1wFolder}/${Subject}.${Hemisphere}.${Surface}.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${ConcatRegName}.native.surf.gii ${Folder}/${Subject}.${Hemisphere}.sphere.${Mesh}k_fs_LR.surf.gii BARYCENTRIC ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.${Surface}_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii
        ${Caret7_Command} -add-to-spec-file ${DownSampleT1wFolder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.${Surface}_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii
      done
      ${Caret7_Command} -surface-generate-inflated ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.inflated_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.very_inflated_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii -iterations-scale ${Scale}
      ${Caret7_Command} -add-to-spec-file ${DownSampleT1wFolder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.inflated_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii
      ${Caret7_Command} -add-to-spec-file ${DownSampleT1wFolder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.very_inflated_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii

      #Compute vertex areas for other analyses
      ${Caret7_Command} -surface-vertex-areas ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_${ConcatRegName}.${Mesh}k_fs_LR.surf.gii ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_${ConcatRegName}_va.${Mesh}k_fs_LR.shape.gii 

      ${Caret7_Command} -add-to-spec-file ${DownSampleT1wFolder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${Folder}/${Subject}.${Hemisphere}.sphere.${Mesh}k_fs_LR.surf.gii
      if [ -e ${Folder}/${Subject}.${Hemisphere}.flat.${Mesh}k_fs_LR.surf.gii ] ; then
        ${Caret7_Command} -add-to-spec-file ${DownSampleT1wFolder}/${Subject}.${ConcatRegName}.${Mesh}k_fs_LR.wb.spec ${Structure} ${Folder}/${Subject}.${Hemisphere}.flat.${Mesh}k_fs_LR.surf.gii
      fi
    fi  
  done

  if [ ! ${Mesh} = ${HighResMesh} ] ; then 
    #Normalize vertex areas mean to 1 for other analyses
    ${Caret7_Command} -cifti-create-dense-scalar ${DownSampleT1wFolder}/${Subject}.midthickness_${ConcatRegName}_va.${Mesh}k_fs_LR.dscalar.nii -left-metric ${DownSampleT1wFolder}/${Subject}.L.midthickness_${ConcatRegName}_va.${Mesh}k_fs_LR.shape.gii -roi-left ${Folder}/${Subject}.L.atlasroi.${Mesh}k_fs_LR.shape.gii -right-metric ${DownSampleT1wFolder}/${Subject}.R.midthickness_${ConcatRegName}_va.${Mesh}k_fs_LR.shape.gii -roi-right ${Folder}/${Subject}.R.atlasroi.${Mesh}k_fs_LR.shape.gii
    VAMean=`${Caret7_Command} -cifti-stats ${DownSampleT1wFolder}/${Subject}.midthickness_${ConcatRegName}_va.${Mesh}k_fs_LR.dscalar.nii -reduce MEAN`
    ${Caret7_Command} -cifti-math "VA / ${VAMean}" ${DownSampleT1wFolder}/${Subject}.midthickness_${ConcatRegName}_va_norm.${Mesh}k_fs_LR.dscalar.nii -var VA ${DownSampleT1wFolder}/${Subject}.midthickness_${ConcatRegName}_va.${Mesh}k_fs_LR.dscalar.nii
  fi
    
  #Resample scalar maps and apply new bias field
  for Map in ${Maps} ${MyelinMaps} SphericalDistortion ArealDistortion EdgeDistortion ; do
    for MapMap in ${MyelinMaps} ; do
      if [ ${MapMap} = ${Map} ] ; then
        ${Caret7_Command} -cifti-math "Var - Bias" ${NativeFolder}/${Subject}.${Map}_BC_${ConcatRegName}.native.dscalar.nii -var Var ${NativeFolder}/${Subject}.${Map}.native.dscalar.nii -var Bias ${NativeFolder}/${Subject}.BiasField_${ConcatRegName}.native.dscalar.nii
        Map="${Map}_BC"
      fi
    done
    if [[ ${Map} = "ArealDistortion" || ${Map} = "EdgeDistortion" || ${Map} = "MyelinMap_BC" || ${Map} = "SmoothedMyelinMap_BC" ]] ; then
      NativeMap="${Map}_${ConcatRegName}"
    else
      NativeMap="${Map}"
    fi
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
  done
done


for Map in ${MyelinMaps} ; do
  ${Caret7_Command} -add-to-spec-file ${NativeFolder}/${Subject}.native.wb.spec INVALID ${NativeFolder}/${Subject}.${Map}_BC_${ConcatRegName}.native.dscalar.nii
  ${Caret7_Command} -add-to-spec-file ${NativeT1wFolder}/${Subject}.native.wb.spec INVALID ${NativeFolder}/${Subject}.${Map}_BC_${ConcatRegName}.native.dscalar.nii
done


#Set Variables (Does not support multiple resolution meshes):
DownSampleFolder=`echo ${DownSampleFolderNames} | cut -d " " -f 1`
DownSampleT1wFolder=`echo ${DownSampleT1wFolderNames} | cut -d " " -f 1`
LowResMesh=`echo ${LowResMeshes} | cut -d " " -f 1`

#Resample (and resmooth) TS from Native 
for fMRIName in ${rfMRINames} ${tfMRINames} ; do
  cp ${ResultsFolder}/${fMRIName}/${fMRIName}_Atlas.dtseries.nii ${ResultsFolder}/${fMRIName}/${fMRIName}_Atlas_${ConcatRegName}.dtseries.nii
  for Hemisphere in L R ; do
    if [ $Hemisphere = "L" ] ; then 
      Structure="CORTEX_LEFT"
    elif [ $Hemisphere = "R" ] ; then 
      Structure="CORTEX_RIGHT"
    fi 

    ${Caret7_Command} -metric-resample ${ResultsFolder}/${fMRIName}/${fMRIName}.${Hemisphere}.native.func.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${ConcatRegName}.native.surf.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii ADAP_BARY_AREA ${ResultsFolder}/${fMRIName}/${fMRIName}_${ConcatRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii -area-surfs ${NativeT1wFolder}/${Subject}.${Hemisphere}.midthickness.native.surf.gii ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_${ConcatRegName}.${LowResMesh}k_fs_LR.surf.gii -current-roi ${NativeFolder}/${Subject}.${Hemisphere}.roi.native.shape.gii
    ${Caret7_Command} -metric-dilate ${ResultsFolder}/${fMRIName}/${fMRIName}_${ConcatRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_${ConcatRegName}.${LowResMesh}k_fs_LR.surf.gii 30 ${ResultsFolder}/${fMRIName}/${fMRIName}_${ConcatRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii -nearest
    ${Caret7_Command} -metric-mask ${ResultsFolder}/${fMRIName}/${fMRIName}_${ConcatRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii ${ResultsFolder}/${fMRIName}/${fMRIName}_${ConcatRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii
    Sigma=`echo "$SmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`
    ${Caret7_Command} -metric-smoothing ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_${ConcatRegName}.${LowResMesh}k_fs_LR.surf.gii ${ResultsFolder}/${fMRIName}/${fMRIName}_${ConcatRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii ${Sigma} ${ResultsFolder}/${fMRIName}/${fMRIName}_s${SmoothingFWHM}_${ConcatRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii -roi ${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii
    ${Caret7_Command} -cifti-replace-structure ${ResultsFolder}/${fMRIName}/${fMRIName}_Atlas_${ConcatRegName}.dtseries.nii COLUMN -metric ${Structure} ${ResultsFolder}/${fMRIName}/${fMRIName}_s${SmoothingFWHM}_${ConcatRegName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.func.gii
  done
done

#ReApply FIX Cleanup
for fMRIName in ${rfMRINames} ; do
  ${GitRepo}/ReApplyFix/ReApplyFixPipeline.sh ${Caret7_Command} ${GitRepo} ${FixDir} ${StudyFolder} ${Subject} ${fMRIName} ${HighPass} ${ConcatRegName} 
done


}