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
# * Michael P. Harms, Department of Psychiatry, Washington University in St. Louis
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
   --surface-atlas-dir=<path/to/folder> location of the standard surfaces (e.g. ${HCPPIPEDIR}/global/templates/standard_mesh_atlases)
   --grayordinates-space-dir=<path/to/folder> location of the standard grayorinates space (e.g. ${HCPPIPEDIR}/global/templates/91282_Greyordinates)
   --high-res-mesh=<numstring> representing the highres mesh (e.g. 164)
   --low-res-meshes=<numstring> representing the low res mesh (@ delimited list) (e.g. 32)
   --freesurfer-labels=<path/to/file> location of the FreeSurfer look up table (path to a file) (e.g. ${HCPPIPEDIR}/global/config/FreeSurferAllLut.txt)
   --sigma=<num> Sigma of pregradient smoothing (e.g. 1)
   --reg-name=<string> Name of the registration (e.g. MSMAll)
   --videen-maps=<mapstring@mapstring> Maps you want to use the videen palette (@ delimited list) (e.g. corrThickness@thickness@MyelinMap_BC@SmoothedMyelinMap_BC)
   --greyscale-maps=<mapstring@mapstring> Maps you want to use the grayscale palette (@ delimited list) (e.g. sulc@curvature)
   --distortion-maps=<mapstring@mapstring> Distortion maps (@ delimited list) (e.g. SphericalDistortion@ArealDistortion@EdgeDistortion)
   --gradient-maps=<mapstring@mapstring> Maps you want to compute the gradietn on (@ delimited list) (e.g. MyelinMap_BC@SmoothedMyelinMap_BC@corrThickness)
   --std-maps=<mapstring@mapstring> maps you want to compute a standard deviation on (@ delimited list) (e.g. sulc@curvature@corrThickness@thickness@MyelinMap_BC)
   --multi-maps=<mapstring@mapstring> Maps with more than one map (column) that cannot be merged and must be averaged (@ delimited list) (e.g. NONE)

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
	unset p_NoMergedT1T2vols
	unset p_NoLabelVols

	# set default values
	p_NoMergedT1T2vols="FALSE"
	p_NoLabelVols="FALSE"

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
			--no-merged-t1t2-vols)
				p_NoMergedT1T2vols="TRUE"
				index=$(( index + 1 ))
				;;
			--no-label-vols)
				p_NoLabelVols="TRUE"
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

	if [ -z "${p_NoMergedT1T2vols}" ]; then
		log_Err "No Merged T1T2 Volumes value required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "No Merged T1T2 Volumes: ${p_NoMergedT1T2vols}"
	fi

	if [ -z "{p_NoLabelVols}" ]; then
		log_Err "No Label Volumes value required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "No Label Volumes: ${p_NoLabelVols}"
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
	log_Msg "Starting main functionality"

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
	local NoMergedT1T2vols="${17}"
	local NoLabelVols="${18}"

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
	log_Msg "No Merged T1T2 Volumes: ${NoMergedT1T2vols}"
	log_Msg "No Label Volumes: ${NoLabelVols}"

	if [ "${NoMergedT1T2vols}" != "TRUE" ]; then
		NoMergedT1T2vols=""
	fi

	if [ "${NoLabelVols}" != "TRUE" ]; then
		NoLabelVols=""
	fi

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

	# Scalar Volumes
	log_Msg "Scalar Volumes"
	for Volume in ${T1wName} ${T2wName} ; do

		MergeVolumeSTRING=""
		for Subject in ${Subjlist} ; do
		MergeVolumeSTRING=`echo "${MergeVolumeSTRING}${StudyFolder}/${Subject}/MNINonLinear/${Volume}.nii.gz "`
		done
		allvolumes=${CommonAtlasFolder}/${GroupAverageName}_All${Volume}.nii.gz
		avgvolume=${CommonAtlasFolder}/${GroupAverageName}_Average${Volume}.nii.gz
		if [ -n "${NoMergedT1T2vols}" ]; then
			# Creating a merged T1/T2 volume can be very time and memory intensive for large number of subjects.
			# Therefore, the --no-merged-t1t2-vols flag exists to forego creation of merged T1/T2 volumes.
			# In this case, create the average across subjects in single command using 'fsladd' (which
			# implements its averaging in a highly memory efficient manner).
			log_Msg "Skipping creation of merged ${Volume}. Only creating the average."
			fsladd ${avgvolume} -m ${MergeVolumeSTRING}
		else
			fslmerge -t ${allvolumes} ${MergeVolumeSTRING}
			# fslmaths -Tmean is not implemented in a memory efficient manner. Use -volume-reduce instead.
			#fslmaths ${allvolumes} -Tmean ${avgvolume} -odt float
			${Caret7_Command} -volume-reduce ${allvolumes} MEAN ${avgvolume}
		fi

	done

	volume_out=${CommonAtlasFolder}/${GroupAverageName}_AverageT1wDividedByT2w.nii.gz
	${Caret7_Command} -volume-math "clamp((T1w / T2w), 0, 100)" ${volume_out} \
		-var T1w ${CommonAtlasFolder}/${GroupAverageName}_Average${T1wName}.nii.gz \
		-var T2w ${CommonAtlasFolder}/${GroupAverageName}_Average${T2wName}.nii.gz \
		-fixnan 0
	${Caret7_Command} -volume-palette ${volume_out} \
		MODE_AUTO_SCALE_PERCENTAGE -pos-percent 4 96 -interpolate true -palette-name videen_style

	# Label Volumes
	# N.B. While the wmparc and ribbon files compress massively, internally they still require memory
	# equal to the T1/T2 volumes.  However, here, the "average" label across subjects is computed via a MODE
	# operation, and a memory efficient shortcut to just the average is not available.
	# Thus, it is either all or none for the label volumes.
	log_Msg "Label Volumes"
	for Volume in ${wmparc} ${ribbon} ; do

		if [ -z "${NoLabelVols}" ]; then
			MergeVolumeSTRING=""
			for Subject in ${Subjlist} ; do
				MergeVolumeSTRING=`echo "${MergeVolumeSTRING}${StudyFolder}/${Subject}/MNINonLinear/${Volume}.nii.gz "`
			done
			allvolumes=${CommonAtlasFolder}/${GroupAverageName}_All${Volume}.nii.gz
			avgvolume=${CommonAtlasFolder}/${GroupAverageName}_Average${Volume}.nii.gz
			fslmerge -t ${allvolumes} ${MergeVolumeSTRING}
			${Caret7_Command} -volume-label-import ${allvolumes} ${FreeSurferLabels} ${allvolumes} -drop-unused-labels
			${Caret7_Command} -volume-reduce ${allvolumes} MODE ${avgvolume}
			${Caret7_Command} -volume-label-import ${avgvolume} ${FreeSurferLabels} ${avgvolume} -drop-unused-labels
		else  # --no-label-vols flag was used
			log_Msg "Skipping creation of merged and average ${Volume}."
		fi

	done

	# Make Average Surfaces and Surface Data
	log_Msg "Make Average Surfaces and Surface Data"
	for Hemisphere in L R ; do
		if [ ${Hemisphere} = "L" ] ; then
			Structure="CORTEX_LEFT"
		elif [ ${Hemisphere} = "R" ] ; then
			Structure="CORTEX_RIGHT"
		fi

		# Copying of some atlas files
		file1=${SurfaceAtlasDIR}/fsaverage.${Hemisphere}_LR.spherical_std.${HighResMesh}k_fs_LR.surf.gii
		file2=${CommonAtlasFolder}/${GroupAverageName}.${Hemisphere}.sphere.${HighResMesh}k_fs_LR.surf.gii
		cp ${file1} ${file2}

		file1=${SurfaceAtlasDIR}/${Hemisphere}.atlasroi.${HighResMesh}k_fs_LR.shape.gii
		file2=${CommonAtlasFolder}/${GroupAverageName}.${Hemisphere}.atlasroi.${HighResMesh}k_fs_LR.shape.gii
		cp ${file1} ${file2}

		file1=${SurfaceAtlasDIR}/colin.cerebral.${Hemisphere}.flat.${HighResMesh}k_fs_LR.surf.gii
		file2=${CommonAtlasFolder}/${GroupAverageName}.${Hemisphere}.flat.${HighResMesh}k_fs_LR.surf.gii
		if [ -e ${file1} ] ; then
			cp ${file1} ${file2}

			spec_file=${CommonAtlasFolder}/${GroupAverageName}${SpecRegSTRING}.${HighResMesh}k_fs_LR.wb.spec
			surf_file=${file2}
			log_Msg "Adding surf_file to spec_file ('${surf_file}' to '${spec_file}')"
			${Caret7_Command} -add-to-spec-file ${spec_file} ${Structure} ${surf_file}
		fi

		i=1
		for LowResMesh in ${LowResMeshes} ; do
			log_Msg "LowResMesh: ${LowResMesh}"
			CommonFolder=`echo ${CommonDownSampleFolders} | cut -d " " -f ${i}`

			file1=${SurfaceAtlasDIR}/${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii
			file2=${CommonFolder}/${GroupAverageName}.${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii
			cp ${file1} ${file2}

			file1=${GrayordinatesSpaceDIR}/${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii
			file2=${CommonFolder}/${GroupAverageName}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii
			cp ${file1} ${file2}

			file1=${SurfaceAtlasDIR}/colin.cerebral.${Hemisphere}.flat.${LowResMesh}k_fs_LR.surf.gii
			file2=${CommonFolder}/${GroupAverageName}.${Hemisphere}.flat.${LowResMesh}k_fs_LR.surf.gii
			if [ -e ${file1} ] ; then
				cp ${file1} ${file2}

				spec_file=${CommonFolder}/${GroupAverageName}${SpecRegSTRING}.${LowResMesh}k_fs_LR.wb.spec
				surf_file=${file2}
				log_Msg "Adding surf_file to spec_file ('${surf_file}' to '${spec_file}')"
				${Caret7_Command} -add-to-spec-file ${spec_file} ${Structure} ${surf_file}
			fi
			i=$(($i+1))

		done

		# Average the actual surfaces across subjects
		for Mesh in ${HighResMesh} ${LowResMeshes} ; do
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
				log_Msg "Surface: ${Surface}; Mesh: ${Mesh}"
				SurfaceSTRING=""
				for Subject in $Subjlist ; do
					#log_Msg "Subject: ${Subject}"
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
				#log_Msg "SurfaceSTRING: ${SurfaceSTRING}"
				${Caret7_Command} -surface-average ${surface_out} -uncertainty ${uncert_metric_out} -stddev ${stddev_metric_out} ${SurfaceSTRING}


				spec_file=${CommonFolder}/${GroupAverageName}${SpecRegSTRING}.${Mesh}k_fs_LR.wb.spec
				surf_file=${CommonFolder}/${GroupAverageName}.${Hemisphere}.${Surface}${RegSTRING}.${Mesh}k_fs_LR.surf.gii
				log_Msg "Adding surf_file to spec_file ('${surf_file}' to '${spec_file}')"
				${Caret7_Command} -add-to-spec-file ${spec_file} ${Structure} ${surf_file}

				#log_Msg "${Caret7_Command} -metric-palette 1"
				${Caret7_Command} -metric-palette ${uncert_metric_out} MODE_AUTO_SCALE_PERCENTAGE \
					-pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false

				#log_Msg "${Caret7_Command} -metric-palette 2"
				${Caret7_Command} -metric-palette ${stddev_metric_out} MODE_AUTO_SCALE_PERCENTAGE \
					-pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false

				#log_Msg "Back for another surface"
			done

			# Generate inflated versions of midthickness surface
			log_Msg "Generating inflated version of group average midthickness surface"
			surface_in=${CommonFolder}/${GroupAverageName}.${Hemisphere}.midthickness${RegSTRING}.${Mesh}k_fs_LR.surf.gii
			inflated_surface=${CommonFolder}/${GroupAverageName}.${Hemisphere}.inflated${RegSTRING}.${Mesh}k_fs_LR.surf.gii
			veryinflated_surface=${CommonFolder}/${GroupAverageName}.${Hemisphere}.very_inflated${RegSTRING}.${Mesh}k_fs_LR.surf.gii
			${Caret7_Command} -surface-generate-inflated ${surface_in} ${inflated_surface} ${veryinflated_surface} -iterations-scale ${Scale}
			${Caret7_Command} -add-to-spec-file ${spec_file} ${Structure} ${inflated_surface}
			${Caret7_Command} -add-to-spec-file ${spec_file} ${Structure} ${veryinflated_surface}
		done

	done
	
	log_Debug_Msg "Debug Point 1"

	# Convert the L/R std and uncertainty metric files (.shape.gii) to cifti (.dscalar.nii)
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
			cifti_out=${CommonFolder}/${GroupAverageName}.${Map}.${Mesh}k_fs_LR.dscalar.nii
			${Caret7_Command} -cifti-create-dense-scalar ${cifti_out} \
				-left-metric ${CommonFolder}/${GroupAverageName}.L.${Map}.${Mesh}k_fs_LR.shape.gii \
				-roi-left ${CommonFolder}/${GroupAverageName}.L.atlasroi.${Mesh}k_fs_LR.shape.gii \
				-right-metric ${CommonFolder}/${GroupAverageName}.R.${Map}.${Mesh}k_fs_LR.shape.gii \
				-roi-right ${CommonFolder}/${GroupAverageName}.R.atlasroi.${Mesh}k_fs_LR.shape.gii

			${Caret7_Command} -set-map-name ${cifti_out} 1 ${GroupAverageName}_${Map}
			${Caret7_Command} -cifti-palette ${cifti_out} ${PaletteStringOne} ${cifti_out} ${PaletteStringTwo}
			for Hemisphere in L R ; do
				rm ${CommonFolder}/${GroupAverageName}.${Hemisphere}.${Map}.${Mesh}k_fs_LR.shape.gii
			done
		done
	done

	log_Msg "Completed generation of average surfaces"
	log_Debug_Msg "Debug Point 2"

	# Create the vertex area ("va") files
	for Mesh in ${HighResMesh} ${LowResMeshes} ; do

		log_Msg "Proceeding to generate vertex area files for individual subjects for ${Mesh}k mesh"

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

			log_Msg "Subject: ${Subject}; Mesh: ${Mesh}"

			AtlasFolder="${StudyFolder}/${Subject}/MNINonLinear"
			T1wFolder="${StudyFolder}/${Subject}/T1w"
			if [ $Mesh = ${HighResMesh} ] ; then
				Folder="${T1wFolder}"
				MNIFolder="${AtlasFolder}"
				for Hemisphere in L R ; do

					# Create surface on HighResMesh in subject's T1w space
					surface=${Subject}.${Hemisphere}.midthickness${RegSTRING}.${Mesh}k_fs_LR.surf.gii
					${Caret7_Command} -surface-resample ${T1wFolder}/Native/${Subject}.${Hemisphere}.midthickness.native.surf.gii \
						${MNIFolder}/Native/${Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii \
						${MNIFolder}/${Subject}.${Hemisphere}.sphere.${Mesh}k_fs_LR.surf.gii \
						BARYCENTRIC ${T1wFolder}/${surface}

					# Compute vertex-areas of HighResMesh in T1 space
					metric=${Subject}.${Hemisphere}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.shape.gii
					${Caret7_Command} -surface-vertex-areas ${T1wFolder}/${surface} ${T1wFolder}/${metric}
					rm ${T1wFolder}/${surface}

					# Compute vertex-areas of HighResMesh in MNI space
					# (Surface on HighResMesh in MNI space already exists)
					${Caret7_Command} -surface-vertex-areas ${MNIFolder}/${surface} ${MNIFolder}/${metric}
				done

				# Convert both T1 and MNI space HighResMesh va files to cifti
				cifti=${Subject}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.dscalar.nii
				left_metric=${Subject}.L.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.shape.gii
				right_metric=${Subject}.R.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.shape.gii
				${Caret7_Command} -cifti-create-dense-scalar ${T1wFolder}/${cifti} \
					-left-metric ${T1wFolder}/${left_metric} \
					-roi-left ${MNIFolder}/${Subject}.L.atlasroi.${Mesh}k_fs_LR.shape.gii \
					-right-metric ${T1wFolder}/${right_metric} \
					-roi-right ${MNIFolder}/${Subject}.R.atlasroi.${Mesh}k_fs_LR.shape.gii
				${Caret7_Command} -cifti-create-dense-scalar ${MNIFolder}/${cifti} \
					-left-metric ${MNIFolder}/${left_metric} \
					-roi-left ${MNIFolder}/${Subject}.L.atlasroi.${Mesh}k_fs_LR.shape.gii \
					-right-metric ${MNIFolder}/${right_metric} \
					-roi-right ${MNIFolder}/${Subject}.R.atlasroi.${Mesh}k_fs_LR.shape.gii
				rm ${T1wFolder}/${left_metric} ${T1wFolder}/${right_metric}
				rm ${MNIFolder}/${left_metric} ${MNIFolder}/${right_metric}
			else
				# Repeat for the LowResMeshes
				# Here, all the relevant surfaces should already exist
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
					# Compute vertex-areas of LowResMesh in MNI space
					surface=${Subject}.${Hemisphere}.midthickness${RegSTRING}.${Mesh}k_fs_LR.surf.gii
					metric=${Subject}.${Hemisphere}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.shape.gii
					${Caret7_Command} -surface-vertex-areas ${MNIFolder}/${surface} ${MNIFolder}/${metric}
				done
				# Convert va files to cifti
				cifti=${Subject}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.dscalar.nii
				left_metric=${Subject}.L.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.shape.gii
				right_metric=${Subject}.R.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.shape.gii
				${Caret7_Command} -cifti-create-dense-scalar ${MNIFolder}/${cifti} \
					-left-metric ${MNIFolder}/${left_metric} \
					-roi-left ${MNIFolder}/${Subject}.L.atlasroi.${Mesh}k_fs_LR.shape.gii \
					-right-metric ${MNIFolder}/${right_metric} \
					-roi-right ${MNIFolder}/${Subject}.R.atlasroi.${Mesh}k_fs_LR.shape.gii
				rm ${MNIFolder}/${left_metric} ${MNIFolder}/${right_metric}
			fi
			MapMerge=`echo "${MapMerge} -cifti ${Folder}/${Subject}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.dscalar.nii"`
			MNIMapMerge=`echo "${MNIMapMerge} -cifti ${MNIFolder}/${Subject}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.dscalar.nii"`

		done  #subject loop

		log_Msg "Completed creation of vertex area files for individual subjects for ${Mesh}k mesh"
		log_Debug_Msg "Debug Point 2.5"
		log_Msg "Proceeding to merge and average the vertex area files for ${Mesh}k mesh"

		# Merge and average the T1 space va files
		cifti=${CommonFolder}/${GroupAverageName}.All.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.dscalar.nii
		avgcifti=${CommonFolder}/${GroupAverageName}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.dscalar.nii
		${Caret7_Command} -cifti-merge ${cifti} ${MapMerge}
		${Caret7_Command} -cifti-reduce ${cifti} MEAN ${avgcifti}

		# Merge and average the MNI space va files
		cifti_mni=${CommonFolder}/${GroupAverageName}.All.midthickness${RegSTRING}_va_mni.${Mesh}k_fs_LR.dscalar.nii
		avgcifti_mni=${CommonFolder}/${GroupAverageName}.midthickness${RegSTRING}_va_mni.${Mesh}k_fs_LR.dscalar.nii
		${Caret7_Command} -cifti-merge ${cifti_mni} ${MNIMapMerge}
		${Caret7_Command} -cifti-reduce ${cifti_mni} MEAN ${avgcifti_mni}
		rm ${cifti_mni}

		# Cleanup/removal of individual subject va files
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

		# Compute vertex areas for the group average midthickness surface (in MNI space)
		for Hemisphere in L R ; do
			surface=${CommonFolder}/${GroupAverageName}.${Hemisphere}.midthickness${RegSTRING}.${Mesh}k_fs_LR.surf.gii
			metric=${CommonFolder}/${GroupAverageName}.${Hemisphere}.midthickness${RegSTRING}_vaFromAvgSurf.${Mesh}k_fs_LR.shape.gii
			${Caret7_Command} -surface-vertex-areas ${surface} ${metric}
		done

		cifti=${CommonFolder}/${GroupAverageName}.midthickness${RegSTRING}_vaFromAvgSurf.${Mesh}k_fs_LR.dscalar.nii
		left_metric=${CommonFolder}/${GroupAverageName}.L.midthickness${RegSTRING}_vaFromAvgSurf.${Mesh}k_fs_LR.shape.gii
		right_metric=${CommonFolder}/${GroupAverageName}.R.midthickness${RegSTRING}_vaFromAvgSurf.${Mesh}k_fs_LR.shape.gii
		${Caret7_Command} -cifti-create-dense-scalar ${cifti} \
			-left-metric ${left_metric} \
			-roi-left ${CommonFolder}/${GroupAverageName}.L.atlasroi.${Mesh}k_fs_LR.shape.gii \
			-right-metric ${right_metric} \
			-roi-right ${CommonFolder}/${GroupAverageName}.R.atlasroi.${Mesh}k_fs_LR.shape.gii

		rm ${left_metric} ${right_metric}

		# Compute ratio of the "vaFromAvgSurf" vs. the average va across individual subjects
		cifti_out=${CommonFolder}/${GroupAverageName}.midthickness${RegSTRING}_va_ratio.${Mesh}k_fs_LR.dscalar.nii
		ciftivar1=${cifti}
		ciftivar2=${CommonFolder}/${GroupAverageName}.midthickness${RegSTRING}_va_mni.${Mesh}k_fs_LR.dscalar.nii
		${Caret7_Command} -cifti-math "ln(avgsurf / meanorig) / ln(2)" ${cifti_out} \
			-var avgsurf ${ciftivar1} \
			-var meanorig ${ciftivar2}

		#rm ${ciftivar1} ${ciftivar2}

		spec_file=${CommonFolder}/${GroupAverageName}${SpecRegSTRING}.${Mesh}k_fs_LR.wb.spec
		for Hemisphere in L R ; do
			if [ ${Hemisphere} = "L" ] ; then
				Structure="CORTEX_LEFT"
			elif [ ${Hemisphere} = "R" ] ; then
				Structure="CORTEX_RIGHT"
			fi
			cifti_in=${CommonFolder}/${GroupAverageName}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.dscalar.nii
			metric=${CommonFolder}/${GroupAverageName}.${Hemisphere}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.shape.gii
			${Caret7_Command} -cifti-separate ${cifti_in} COLUMN -metric ${Structure} ${metric}

			surface=${CommonFolder}/${GroupAverageName}.${Hemisphere}.midthickness${RegSTRING}.${Mesh}k_fs_LR.surf.gii
			${Caret7_Command} -metric-dilate ${metric} ${surface} 10 ${metric} -nearest

			${Caret7_Command} -add-to-spec-file ${spec_file} ${Structure} ${metric}
			# What is the role of these dilated va files, and why are they left as metric (rather than converted to cifti)?
			# A: Probably used as part of some computations for MG's semi-automated parcellation.

		done

		log_Msg "Completed merging and averaging of the vertex area files for ${Mesh}k mesh"

		${Caret7_Command} -add-to-spec-file ${spec_file} INVALID ${CommonAtlasFolder}/${GroupAverageName}_Average${T1wName}.nii.gz
		${Caret7_Command} -add-to-spec-file ${spec_file} INVALID ${CommonAtlasFolder}/${GroupAverageName}_Average${T2wName}.nii.gz
		${Caret7_Command} -add-to-spec-file ${spec_file} INVALID ${CommonAtlasFolder}/${GroupAverageName}_AverageT1wDividedByT2w.nii.gz
	done

	log_Msg "Completed all operations on vertex areas"
	log_Debug_Msg "Debug Point 3"
	log_Msg "Proceeding to create averages of requested maps"

	for Map in ${GreyScaleMaps} ${VideenMaps} ${DistortionMaps} ; do

		for Mesh in ${HighResMesh} ${LowResMeshes} ; do
			log_Msg "Map: ${Map}; Mesh: ${Mesh}"

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
				avgcifti=${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}.${Mesh}k_fs_LR.dscalar.nii
				${Caret7_Command} -cifti-average ${avgcifti} -exclude-outliers 3 3 ${MapMerge}
				SpecFile="False"
			else
				cifti=${CommonFolder}/${GroupAverageName}.All.${Map}${RegSTRING}.${Mesh}k_fs_LR.dscalar.nii
				${Caret7_Command} -cifti-merge ${cifti} ${MapMerge}
				${Caret7_Command} -cifti-palette ${cifti} ${PaletteStringOne} ${cifti} ${PaletteStringTwo}

				avgcifti=${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}.${Mesh}k_fs_LR.dscalar.nii
				${Caret7_Command} -cifti-reduce ${cifti} MEAN ${avgcifti} -exclude-outliers 3 3

				if [ ${SpecFile} = "True" ] ; then
					spec_file=${CommonFolder}/${GroupAverageName}${SpecRegSTRING}.${Mesh}k_fs_LR.wb.spec
					${Caret7_Command} -add-to-spec-file ${spec_file} INVALID ${avgcifti}
				fi
			fi

			#log_Debug_Msg "Debug Point 3.5"

			${Caret7_Command} -cifti-palette ${avgcifti} ${PaletteStringOne} ${avgcifti} ${PaletteStringTwo}
			${Caret7_Command} -set-map-name ${avgcifti} 1 ${GroupAverageName}_${Map}${RegSTRING}

			if [ ! x`echo ${DistortionMaps} | grep -oE "(^| )${Map}" | sed 's/ //g'` = "x" ] ; then
				PaletteStringOne="MODE_USER_SCALE"
				PaletteStringTwo="-pos-user 0 1 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false"
				cifti_abs=${CommonFolder}/${GroupAverageName}.All.${Map}${RegSTRING}_abs.${Mesh}k_fs_LR.dscalar.nii
				ciftivar1=${CommonFolder}/${GroupAverageName}.All.${Map}${RegSTRING}.${Mesh}k_fs_LR.dscalar.nii
				${Caret7_Command} -cifti-math 'abs(var)' ${cifti_abs} -var var ${ciftivar1}
				${Caret7_Command} -cifti-palette ${cifti_abs} ${PaletteStringOne} ${cifti_abs} ${PaletteStringTwo}

				avgcifti=${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}_abs.${Mesh}k_fs_LR.dscalar.nii
				${Caret7_Command} -cifti-reduce ${cifti_abs} MEAN ${avgcifti}
				${Caret7_Command} -cifti-palette ${avgcifti} ${PaletteStringOne} ${avgcifti} ${PaletteStringTwo}
				${Caret7_Command} -set-map-name ${avgcifti} 1 ${GroupAverageName}_${Map}${RegSTRING}_abs
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

					cifti=${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}.${Mesh}k_fs_LR.dscalar.nii
					cifti_grad=${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}_grad.${Mesh}k_fs_LR.dscalar.nii
					if [ ! -e ${cifti_grad} ] ; then
						cp ${cifti} ${cifti_grad}
					fi

					metric_temp=${CommonFolder}/temp${Hemisphere}.func.gii
					roi_temp=${CommonFolder}/temp${Hemisphere}ROI.func.gii
					${Caret7_Command} -cifti-separate ${cifti} COLUMN -metric ${Structure} ${metric_temp} -roi ${roi_temp}

					cifti_va=${CommonFolder}/${GroupAverageName}.midthickness${RegSTRING}_va.${Mesh}k_fs_LR.dscalar.nii
					metric_temparea=${CommonFolder}/temp${Hemisphere}Area.func.gii
					${Caret7_Command} -cifti-separate ${cifti_va} COLUMN -metric ${Structure} ${metric_temparea}

					surf=${CommonFolder}/${GroupAverageName}.${Hemisphere}.midthickness${RegSTRING}.${Mesh}k_fs_LR.surf.gii
					${Caret7_Command} -metric-dilate ${metric_temparea} ${surf} 10 ${metric_temparea} -nearest

					metric_tempgrad=${CommonFolder}/temp${Hemisphere}Grad.func.gii
					${Caret7_Command} -metric-gradient ${surf} ${metric_temp} ${metric_tempgrad} \
						-presmooth ${Sigma} -roi ${roi_temp} -corrected-areas ${metric_temparea}
					${Caret7_Command} -cifti-replace-structure ${cifti_grad} COLUMN -metric ${Structure} ${metric_tempgrad}

					rm ${metric_temp} ${roi_temp} ${metric_temparea} ${metric_tempgrad}
				done

				#${Caret7_Command} -cifti-gradient ${cifti} COLUMN ${cifti_grad} -left-surface ${CommonFolder}/${GroupAverageName}.L.midthickness${RegSTRING}.${Mesh}k_fs_LR.surf.gii -right-surface ${CommonFolder}/${GroupAverageName}.R.midthickness${RegSTRING}.${Mesh}k_fs_LR.surf.gii -surface-presmooth ${Sigma}
				###End Workaround

				${Caret7_Command} -set-map-name ${cifti_grad} 1 ${GroupAverageName}_${Map}${RegSTRING}_grad
				${Caret7_Command} -cifti-palette ${cifti_grad} ${PaletteStringOne} ${cifti_grad} ${PaletteStringTwo}
			fi

			#log_Debug_Msg "Debug Point: 3.9"

			if [ ! x`echo ${STDMaps} | grep -oE "(^| )${Map}" | sed 's/ //g'` = "x" ] ; then
				PaletteStringOne="MODE_AUTO_SCALE_PERCENTAGE"
				PaletteStringTwo="-pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false"
				cifti=${CommonFolder}/${GroupAverageName}.All.${Map}${RegSTRING}.${Mesh}k_fs_LR.dscalar.nii
				stdcifti=${CommonFolder}/${GroupAverageName}.${Map}${RegSTRING}_std.${Mesh}k_fs_LR.dscalar.nii
				${Caret7_Command} -cifti-reduce ${cifti} STDEV ${stdcifti} -exclude-outliers 3 3
				${Caret7_Command} -set-map-name ${stdcifti} 1 ${GroupAverageName}_${Map}${RegSTRING}_std
				${Caret7_Command} -cifti-palette ${stdcifti} ${PaletteStringOne} ${stdcifti} ${PaletteStringTwo}
			fi

		done

	done

	log_Msg "Completed main functionality"
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
	#     ${1}            ${2}               ${3}                    ${4}                   ${5}                         ${6}               ${7}                ${8}                    ${9}         ${10}          ${11}             ${12}                ${13}                 ${14}               ${15}          ${16}            ${17}                   ${18}
	main "${p_Subjlist}" "${p_StudyFolder}" "${p_GroupAverageName}" "${p_SurfaceAtlasDIR}" "${p_GrayordinatesSpaceDIR}" "${p_HighResMesh}" "${p_LowResMeshes}" "${p_FreeSurferLabels}" "${p_Sigma}" "${p_RegName}" "${p_VideenMaps}" "${p_GreyScaleMaps}" "${p_DistortionMaps}" "${p_GradientMaps}"	"${p_STDMaps}" "${p_MultiMaps}" "${p_NoMergedT1T2vols}" "${p_NoLabelVols}"

else
	# Positional parameters are used
	log_Msg "Using positional parameters"
	main "$@"

fi
