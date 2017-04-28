#!/bin/bash

#
# # MakeAverageDataset.sh
#
# ## Copyright Notice
#
# Copyright (C) 2014-2017 The Human Connectome Project/Connectome Coordination Facility
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

# ------------------------------------------------------------------------------
#  Show usage information for this script
# ------------------------------------------------------------------------------

usage()
{
	local script_name
	script_name=$(basename "${0}")

	cat <<EOF

${script_name}: Make average dataset

Usage: ${script_name} PARAMETER...

PARAMETERs are [ ] = optional; < > = user supplied value

  [--help] : show this usage information and exit
   --subject-list=<@ delimited list of subject ids>
   --study-folder=<path to study folder>
   --group-average-name=<output group average name> (e.g. S900)
   --surface-atlas-dir= TBW (e.g. ${HCPPIPEDIR}/global/templates/standard_mesh_atlases)
   --grayordinates-space-dir= TBW (e.g. ${HCPPIPEDIR}/global/templates/91282_Greyordinates)
   --high-res-mesh= TBW (e.g. 164)
   --low-res-meshes= TBW (@ delimited list) (e.g. 32)
   --freesurfer-labels= TBW (path to a file) (e.g. ${HCPPIPEDIR}/global/config/FreeSurferAllLut.txt)
   --sigma= TBW (e.g. 1)
   --reg-name= TBW (e.g. MSMAll)
   --videen-maps= TBW (@ delimited list) (e.g. corrThickness@thickness@MyelinMap_BC@SmoothedMyelinMap_BC)
   --greyscale-maps= TBW (@ delimited list) (e.g. sulc@curvature)
   --distortion-maps= TBW (@ delimited list) (e.g. SphericalDistortion@ArealDistortion@EdgeDistortion)
   --gradient-maps= TBW (@ delimited list) (e.g. MyelinMap_BC@SmoothedMyelinMap_BC@corrThickness)
   --std-maps= TBW (@ delimited list) (e.g. sulc@curvature@corrThickness@thickness@MyelinMap_BC)
   --multi-maps= TBW (@ delimited list) (e.g. NONE)

EOF
}

# ------------------------------------------------------------------------------
#  Get the command line options for this script.
# ------------------------------------------------------------------------------

get_options()
{
	local arguments=($@)

	# initialize global output variables
	unset p_Subjlist
	unset p_StudyFolder
	unset p_GroupAverageName
	unset p_SurfaceAtlasDIR
	unset p_GrayordinatesSpaceDIR
	unset p_HighResMesh
	unset p_LowResMeshes
	unset p_FreeSurferLabels
	unset p_Sigma
	unset p_RegName
	unset p_VideenMaps
	unset p_GreyScaleMaps
	unset p_DistortionMaps
	unset p_GradientMaps
	unset p_STDMaps
	unset p_MultiMaps

	# parse arguments
	local num_args=${#arguments[@]}
	local argument
	local index=0

	while [ ${index} -lt ${num_args} ]; do
		argument=${arguments[index]}

		case ${argument} in
			--subject-list=*)
				p_Subjlist=${argument#*=}
				index=$(( index + 1 ))
				;;
			--study-folder=*)
				p_StudyFolder=${argument#*=}
				index=$(( index + 1 ))
				;;
			--group-average-name=*)
				p_GroupAverageName=${argument#*=}
				index=$(( index + 1 ))
				;;
			--surface-atlas-dir=*)
				p_SurfaceAtlasDIR=${argument#*=}
				index=$(( index + 1 ))
				;;
			--grayordinates-space-dir=*)
				p_GrayordinatesSpaceDIR=${argument#*=}
				index=$(( index + 1 ))
				;;
			--high-res-mesh=*)
				p_HighResMesh=${argument#*=}
				index=$(( index + 1 ))
				;;
			--low-res-meshes=*)
				p_LowResMeshes=${argument#*=}
				index=$(( index + 1 ))
				;;
			--freesurfer-labels=*)
				p_FreeSurferLabels=${argument#*=}
				index=$(( index + 1 ))
				;;
			--sigma=*)
				p_Sigma=${argument#*=}
				index=$(( index + 1 ))
				;;
			--reg-name=*)
				p_RegName=${argument#*=}
				index=$(( index + 1 ))
				;;
			--videen-maps=*)
				p_VideenMaps=${argument#*=}
				index=$(( index + 1 ))
				;;
			--greyscale-maps=*)
				p_GreyScaleMaps=${argument#*=}
				index=$(( index + 1 ))
				;;
			--distortion-maps=*)
				p_DistortionMaps=${argument#*=}
				index=$(( index + 1 ))
				;;
			--gradient-maps=*)
				p_GradientMaps=${argument#*=}
				index=$(( index + 1 ))
				;;
			--std-maps=*)
				p_STDMaps=${argument#*=}
				index=$(( index + 1 ))
				;;
			--multi-maps=*)
				p_MultiMaps=${argument#*=}
				index=$(( index + 1 ))
				;;
			*)
				usage
				log_Err_Abort "unrecognized option: ${argument}"
				;;
		esac
	done

	local error_count=0

	# check required parameters
	if [ -z "${p_Subjlist}" ]; then
		log_Err "subject list (--subject-list=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "subject list: ${p_Subjlist}"
	fi
	
	if [ -z "${p_StudyFolder}" ]; then
		log_Err "study folder (--study-folder=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Study Folder: ${p_StudyFolder}"
	fi

	if [ -z "${p_GroupAverageName}" ]; then
		log_Err "group average name (--group-average-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "group average name: ${p_GroupAverageName}"
	fi

	if [ -z "${p_SurfaceAtlasDIR}" ]; then
		log_Err "surface atlas dir (--surface-atlas-dir=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "surface atlas dir: ${p_SurfaceAtlasDIR}"
	fi
	
	if [ -z "${p_GrayordinatesSpaceDIR}" ]; then
		log_Err "grayordinates space dir (--grayordinates-space-dir=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "grayordinates space dir: ${p_GrayordinatesSpaceDIR}"
	fi

	if [ -z "${p_HighResMesh}" ]; then
		log_Err "high res mesh (--high-res-mesh=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "high res mesh: ${p_HighResMesh}"
	fi
	
	if [ -z "${p_LowResMeshes}" ]; then
		log_Err "low res meshes (--low-res-meshes=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "low res meshes: ${p_LowResMeshes}"
	fi

	if [ -z "${p_FreeSurferLabels}" ]; then
		log_Err "freesurfer labels (--freesurfer-labels=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "freesurfer labels: ${p_FreeSurferLabels}"
	fi
	
	if [ -z "${p_Sigma}" ]; then
		log_Err "sigma (--sigma=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "sigma: ${p_Sigma}"
	fi
	
	if [ -z "${p_RegName}" ]; then
		log_Err "reg name (--reg-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "reg name: ${p_RegName}"
	fi

	if [ -z "${p_VideenMaps}" ]; then
		log_Err "videen maps (--videen-maps=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "videen maps: ${p_VideenMaps}"
	fi

	if [ -z "${p_GreyScaleMaps}" ]; then
		log_Err "greyscale maps (--greyscale-maps=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "greyscale maps: ${p_GreyScaleMaps}"
	fi

	if [ -z "${p_DistortionMaps}" ]; then
		log_Err "distortion maps (--distortion-maps=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "distortion maps: ${p_DistortionMaps}"
	fi

	if [ -z "${p_GradientMaps}" ]; then
		log_Err "gradient maps (--gradient-maps=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "gradient maps: ${p_GradientMaps}"
	fi

	if [ -z "${p_STDMaps}" ]; then
		log_Err "std maps (--std-maps=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "std maps: ${p_STDMaps}"
	fi

	if [ -z "${p_MultiMaps}" ]; then
		log_Err "multi maps (--multi-maps=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "multi maps: ${p_MultiMaps}"
	fi

	if [ ${error_count} -gt 0 ]; then
		log_Err_Abort "For usage information, use --help"
	fi
}

# ------------------------------------------------------------------------------
#  Show Tool Versions
# ------------------------------------------------------------------------------

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

# ------------------------------------------------------------------------------
#  Main processing of script.
# ------------------------------------------------------------------------------

main() 
{
	log_Msg "Staring main functionality"

	# Retrieve positional parameters
	local Subjlist="${1}"
	local StudyFolder="${2}"
	local GroupAverageName="${3}"
	local SurfaceAtlasDIR="${4}"
	local GrayordinatesSpaceDIR="${5}"
	local HighResMesh="${6}"
	local LowResMeshes="${7}"
	local FreeSurferLabels="${8}"
	local Sigma="${9}"
	local RegName="${10}"
	local VideenMaps="${11}"
	local GreyScaleMaps="${12}"
	local DistortionMaps="${13}"
	local GradientMaps="${14}"
	local STDMaps="${15}"
	local MultiMaps="${16}"
	
	# Log values retrieved from positional parameters
	log_Msg "Subjlist: ${Subjlist}"
	log_Msg "StudyFolder: ${StudyFolder}"	
	log_Msg "GroupAverageName: ${GroupAverageName}"
	log_Msg "SurfaceAtlasDIR: ${SurfaceAtlasDIR}"
	log_Msg "GrayordinatesSpaceDIR: ${GrayordinatesSpaceDIR}"
	log_Msg "HighResMesh: ${HighResMesh}"	
	log_Msg "LowResMeshes: ${LowResMeshes}"
	log_Msg "FreeSurferLabels: ${FreeSurferLabels}"
	log_Msg "Sigma: ${Sigma}"
	log_Msg "RegName: ${RegName}"
	log_Msg "VideenMaps: ${VideenMaps}"
	log_Msg "GreyScaleMaps: ${GreyScaleMaps}"
	log_Msg "DistortionMaps: ${DistortionMaps}"
	log_Msg "GradientMaps: ${GradientMaps}"
	log_Msg "STDMaps: ${STDMaps}"
	log_Msg "MultiMaps: ${MultiMaps}"	

	# Naming Conventions and other variables
	local Caret7_Command="${CARET7DIR}/wb_command"
	log_Msg "Caret7_Command: ${Caret7_Command}"

	LowResMeshes=`echo ${LowResMeshes} | sed 's/@/ /g'`
	log_Msg "After delimiter substitution, LowResMeshes: ${LowResMeshes}"
	
	Subjlist=`echo ${Subjlist} | sed 's/@/ /g'`	
	log_Msg "After delimiter substitution, Subjlist: ${Subjlist}"

	VideenMaps=`echo ${VideenMaps} | sed 's/@/ /g'`
	log_Msg "After delimiter substitution, VideenMaps: ${VideenMaps}"

	GreyScaleMaps=`echo ${GreyScaleMaps} | sed 's/@/ /g'`
	log_Msg "After delimiter substitution, GreyScaleMaps: ${GreyScaleMaps}"

	DistortionMaps=`echo ${DistortionMaps} | sed 's/@/ /g'`
	log_Msg "After delimiter substitution, DistortionMaps: ${DistortionMaps}"

	GradientMaps=`echo ${GradientMaps} | sed 's/@/ /g'`
	log_Msg "After delimiter substitution, GradientMaps: ${GradientMaps}"

	STDMaps=`echo ${STDMaps} | sed 's/@/ /g'`
	log_Msg "After delimiter substitution, STDMaps: ${STDMaps}"

	MultiMaps=`echo ${MultiMaps} | sed 's/@/ /g'`
	log_Msg "After delimiter substitution, MultiMaps: ${MultiMaps}"

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

	log_Debug_Msg "Debug Point 1"

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

	log_Debug_Msg "Debug Point 2"

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

	log_Debug_Msg "Debug Point 3"

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

			log_Debug_Msg "Debug Point 3.5"

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

			log_Debug_Msg "Debug Point: 3.9"

			if [ ! x`echo ${STDMaps} | grep -oE "(^| )${Map}" | sed 's/ //g'` = "x" ] ; then
				PaletteStringOne="MODE_AUTO_SCALE_PERCENTAGE"
				PaletteStringTwo="-pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false"
				${Caret7_Command} -cifti-reduce ${CommonFolder}/${GroupAverageName}.All.${Map}${RegSTRING}.${Mesh}k_fs_LR.dscalar.nii STDEV ${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}_std.${Mesh}k_fs_LR.dscalar.nii -exclude-outliers 3 3     
				${Caret7_Command} -set-map-name ${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}_std.${Mesh}k_fs_LR.dscalar.nii 1 ${GroupAverageName}_${Map}${RegSTRING}_std
				${Caret7_Command} -cifti-palette ${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}_std.${Mesh}k_fs_LR.dscalar.nii ${PaletteStringOne} ${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}_std.${Mesh}k_fs_LR.dscalar.nii ${PaletteStringTwo}
			fi
			
		done  
		
	done

	log_Msg "Completing main functionality"
}

# ------------------------------------------------------------------------------
#  "Global" processing - everything above here should be in a function
# ------------------------------------------------------------------------------

set -e # If any commands exit with non-zero value, this script exits

# Verify HCPPIPEDIR environment variable is set
if [ -z "${HCPPIPEDIR}" ]; then
	echo "$(basename ${0}): ABORTING: HCPPIPEDIR environment variable must be set"
	exit 1
fi

# Load function libraries
source "${HCPPIPEDIR}/global/scripts/log.shlib" # Logging related functions
source "${HCPPIPEDIR}/global/scripts/fsl_version.shlib" # Function for getting FSL version
log_Msg "HCPPIPEDIR: ${HCPPIPEDIR}"

# Verify any other needed environment variables are set
log_Check_Env_Var CARET7DIR
log_Check_Env_Var FSLDIR

# Show tool versions
show_tool_versions

# Determine whether named or positional parameters are used
if [[ ${1} == --* ]]; then
	# Named parameters (e.g. --parameter-name=parameter-value) are used
	log_Msg "Using named parameters"

	# Get command line options
	get_options "$@"

	# Invoke main functionality
	#     ${1}            ${2}               ${3}                    ${4}                   ${5}                         ${6}               ${7}                ${8}                    ${9}         ${10}          ${11}             ${12}                ${13}                 ${14}               ${15}          ${16}
	main "${p_Subjlist}" "${p_StudyFolder}" "${p_GroupAverageName}" "${p_SurfaceAtlasDIR}" "${p_GrayordinatesSpaceDIR}" "${p_HighResMesh}" "${p_LowResMeshes}" "${p_FreeSurferLabels}" "${p_Sigma}" "${p_RegName}" "${p_VideenMaps}" "${p_GreyScaleMaps}" "${p_DistortionMaps}" "${p_GradientMaps}"	"${p_STDMaps}" "${p_MultiMaps}"
	
else
	# Positional parameters are used
	log_Msg "Using positional parameters"
	main "$@"

fi
