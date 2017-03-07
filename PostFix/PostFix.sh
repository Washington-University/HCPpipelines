#!/bin/bash

#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # PostFix.sh
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
#~ND~END~

set -e # If any commands exit with non-zero value, this script exits

# ------------------------------------------------------------------------------
#  Verify HCPPIPEDIR environment variable is set
# ------------------------------------------------------------------------------

if [ -z "${HCPPIPEDIR}" ]; then
	script_name=$(basename "${0}")
	echo "${script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
	exit 1
fi

# ------------------------------------------------------------------------------
#  Load function libraries
# ------------------------------------------------------------------------------

source ${HCPPIPEDIR}/global/scripts/log.shlib # Logging related functions
log_Msg "HCPPIPEDIR: ${HCPPIPEDIR}"

source ${HCPPIPEDIR}/global/scripts/fsl_version.shlib # Function for getting FSL version

# ------------------------------------------------------------------------------
#  Verify other needed environment variables are set
# ------------------------------------------------------------------------------

if [ -z "${CARET7DIR}" ]; then
	log_Err_Abort "CARET7DIR environment variable must be set"
fi
log_Msg "CARET7DIR: ${CARET7DIR}"

if [ -z "${FSLDIR}" ]; then
	log_Err_Abort "FSLDIR environment variable must be set"
fi
log_Msg "FSLDIR: ${FSLDIR}"

# ------------------------------------------------------------------------------
#  Show usage information for this script
# ------------------------------------------------------------------------------

usage()
{
	local script_name
	script_name=$(basename "${0}")

	cat <<EOF

${script_name}: TBW

Usage: ${script_name} PARAMETER...

PARAMETERs are [ ] = optional; < > = user supplied value

  [--help] : show usage information and exit
   --path=<path to study folder> OR --study-folder=<path to study folder>
   --subject=<subject ID>
   --fmri-name=<fMRI name>
   --high-pass=<high pass>
   --template-scene-dual-screen=<template scene file>
   --template-scene-single-screen=<template scene file>
   --reuse-high-pass=<YES | NO>
  [--matlab-run-mode={0, 1}] defaults to 0 (Compiled Matlab)"
     0 = Use compiled MATLAB
     1 = Use interpreted MATLAB

EOF
}

# ------------------------------------------------------------------------------
#  Get the command line options for this script.
# ------------------------------------------------------------------------------

get_options()
{
	local arguments=($@)

	# initialize global output variables
	unset g_path_to_study_folder
	unset g_subject
	unset g_fmri_name
	unset g_high_pass
	unset g_template_scene_dual_screen
	unset g_template_scene_single_screen
	unset g_reuse_high_pass
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
			--fmri-name=*)
				g_fmri_name=${argument#*=}
				index=$(( index + 1 ))
				;;
			--high-pass=*)
				g_high_pass=${argument#*=}
				index=$(( index + 1 ))
				;;
			--template-scene-dual-screen=*)
				g_template_scene_dual_screen=${argument#*=}
				index=$(( index + 1 ))
				;;
			--template-scene-single-screen=*)
				g_template_scene_single_screen=${argument#*=}
				index=$(( index + 1 ))
				;;
			--reuse-high-pass=*)
				g_reuse_high_pass=${argument#*=}
				index=$(( index + 1 ))
				;;
			--matlab-run-mode=*)
				g_matlab_run_mode=${argument#*=}
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
	if [ -z "${g_path_to_study_folder}" ]; then
		log_Err "path to study folder (--path= or --study-folder=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_path_to_study_folder: ${g_path_to_study_folder}"
	fi

	if [ -z "${g_subject}" ]; then
		log_Err "subject ID required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_subject: ${g_subject}"
	fi

	if [ -z "${g_fmri_name}" ]; then
		log_Err "fMRI name required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_fmri_name: ${g_fmri_name}"
	fi

	if [ -z "${g_high_pass}" ]; then
		log_Err "high pass required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_high_pass: ${g_high_pass}"
	fi

	if [ -z "${g_template_scene_dual_screen}" ]; then
		log_Err "template scene dual screen required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_template_scene_dual_screen: ${g_template_scene_dual_screen}"
	fi

	if [ -z "${g_template_scene_single_screen}" ]; then
		log_Err "template scene single screen required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_template_scene_single_screen: ${g_template_scene_single_screen}"
	fi

	if [ -z "${g_reuse_high_pass}" ]; then
		log_Err "reuse high pass not specified"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_template_scene_single_screen: ${g_template_scene_single_screen}"
	fi

	if [ -z "${g_matlab_run_mode}" ]; then
		log_Err "matlab run mode value (--matlab-run-mode=) required"
		error_count=$(( error_count + 1 ))
	else
		case ${g_matlab_run_mode} in
			0)
				log_Msg "g_matlab_run_mode: ${g_matlab_run_mode}"
				if [ -z "${MATLAB_COMPILER_RUNTIME}" ]; then
					log_Err_Abort "To use MATLAB run mode: ${g_matlab_run_mode}, the MATLAB_COMPILER_RUNTIME environment variable must be set"
				else
					log_Msg "MATLAB_COMPILER_RUNTIME: ${MATLAB_COMPILER_RUNTIME}"
				fi
				;;
			1)
				log_Msg "g_matlab_run_mode: ${g_matlab_run_mode}"
				if [ -z "${MATLAB_GIFTI_LIB}" ]; then
					log_Err_Abort "To use MATLAB run mode: ${g_matlab_run_mode}, the MATLAB_GIFTI_LIB environment variable must be set"
				else
					log_Msg "MATLAB_GIFTI_LIB: ${MATLAB_GIFTI_LIB}"
				fi
				;;
			*)
				log_Err "MATLAB run mode value must be 0 or 1"
				error_count=$(( error_count + 1 ))
				;;
		esac
	fi

	if [ ${error_count} -gt 0 ]; then
		log_Err_Abort "For usage information, use --help"
	fi
}

# ------------------------------------------------------------------------------
#  Show/Document Tool Versions
# ------------------------------------------------------------------------------

show_tool_versions() {
	# Show HCP pipelines version
	log_Msg "Showing HCP Pipelines version"
	cat ${HCPPIPEDIR}/version.txt

	# Show wb_command version
	log_Msg "Showing wb_command version"
	${CARET7DIR}/wb_command -version

	# Show FSL version
	log_Msg "Showing FSL version"
	fsl_version_get fsl_ver
	log_Msg "FSL version: ${fsl_ver}"
}

# ------------------------------------------------------------------------------
#  Main processing of script.
# ------------------------------------------------------------------------------

main()
{
	# Get command line options
	get_options "$@"

	# show the versions of tools used
	show_tool_versions

	# Naming Conventions
	AtlasFolder="${g_path_to_study_folder}/${g_subject}/MNINonLinear"
	log_Msg "AtlasFolder: ${AtlasFolder}"

	ResultsFolder="${AtlasFolder}/Results/${g_fmri_name}"
	log_Msg "ResultsFolder: ${ResultsFolder}"

	ICAFolder="${ResultsFolder}/${g_fmri_name}_hp${g_high_pass}.ica/filtered_func_data.ica"
	log_Msg "ICAFolder: ${ICAFolder}"

	FIXFolder="${ResultsFolder}/${g_fmri_name}_hp${g_high_pass}.ica"
	log_Msg "FIXFolder: ${FIXFolder}"

	log_Msg "Creating ${ICAFolder}/ICAVolumeSpace.txt file"
	echo "OTHER" > "${ICAFolder}/ICAVolumeSpace.txt"
	echo "1 255 255 255 255" >> "${ICAFolder}/ICAVolumeSpace.txt"

	log_Msg "Creating ${ICAFolder}/mask.nii.gz"
	${FSLDIR}/bin/fslmaths ${ICAFolder}/melodic_oIC.nii.gz -Tstd -bin ${ICAFolder}/mask.nii.gz

	${CARET7DIR}/wb_command -volume-label-import ${ICAFolder}/mask.nii.gz ${ICAFolder}/ICAVolumeSpace.txt ${ICAFolder}/mask.nii.gz

	log_Msg "Creating dense timeseries"
	${CARET7DIR}/wb_command -cifti-create-dense-timeseries ${ICAFolder}/melodic_oIC_vol.dtseries.nii -volume ${ICAFolder}/melodic_oIC.nii.gz ${ICAFolder}/mask.nii.gz -timestep 1 -timestart 1

	log_Msg "Set up for prepareICAs MATLAB code"
	if [ ${g_reuse_high_pass} = "YES" ] ; then
		dtseriesName="${ResultsFolder}/${g_fmri_name}_Atlas_hp${g_high_pass}" #No Extension Here
		log_Msg "dtseriesName: ${dtseriesName}"
		g_high_pass_use="-1"
	else
		dtseriesName="${ResultsFolder}/${g_fmri_name}_Atlas" #No Extension Here
		log_Msg "dtseriesName: ${dtseriesName}"
		g_high_pass_use="${g_high_pass}"
	fi

	ICAs="${ICAFolder}/melodic_mix"
	log_Msg "ICAs: ${ICAs}"

	ICAdtseries="${ICAFolder}/melodic_oIC.dtseries.nii"
	log_Msg "ICAdtseries: ${ICAdtseries}"

	NoiseICAs="${FIXFolder}/.fix"
	log_Msg "NoiseICAs: ${NoiseICAs}"

	Noise="${FIXFolder}/Noise.txt"
	log_Msg "Noise: ${Noise}"

	Signal="${FIXFolder}/Signal.txt"
	log_Msg "Signal: ${Signal}"

	ComponentList="${FIXFolder}/ComponentList.txt"
	log_Msg "ComponentList: ${ComponentList}"

	TR=$(${FSLDIR}/bin/fslval ${ResultsFolder}/${g_fmri_name}_hp${g_high_pass}_clean pixdim4)
	log_Msg "TR: ${TR}"

	NumTimePoints=$(${FSLDIR}/bin/fslval ${ResultsFolder}/${g_fmri_name}_hp${g_high_pass}_clean dim4)
	log_Msg "NumTimePoints: ${NumTimePoints}"

	if [ -e ${ComponentList} ] ; then
		log_Msg "Removing ComponentList: ${ComponentList}"
		rm ${ComponentList}
	fi

	# run MATLAB prepareICAs function
	case ${g_matlab_run_mode} in

		0)
			# Use Compiled Matlab
			matlab_exe="${HCPPIPEDIR}"
			matlab_exe+="/PostFix/Compiled_prepareICAs/distrib/run_prepareICAs.sh"

			matlab_compiler_runtime="${MATLAB_COMPILER_RUNTIME}"

			matlab_function_arguments="'${dtseriesName}'"
			matlab_function_arguments+=" '${ICAs}'"
			matlab_function_arguments+=" '${CARET7DIR}/wb_command'"
			matlab_function_arguments+=" '${ICAdtseries}'"
			matlab_function_arguments+=" '${NoiseICAs}'"
			matlab_function_arguments+=" '${Noise}'"
			matlab_function_arguments+=" '${Signal}'"
			matlab_function_arguments+=" '${ComponentList}'"
			matlab_function_arguments+=" ${g_high_pass_use}"
			matlab_function_arguments+=" ${TR} "

			matlab_logging=">> ${g_path_to_study_folder}/${g_subject}_${g_fmri_name}.matlab.log 2>&1"

			matlab_cmd="${matlab_exe} ${matlab_compiler_runtime} ${matlab_function_arguments} ${matlab_logging}"

			log_Msg "Run MATLAB command: ${matlab_cmd}"

			echo "${matlab_cmd}" | bash
			log_Msg "MATLAB command return code: $?"
			;;

		1)
			# Use interpreted MATLAB

			matlab -nojvm -nodisplay -nosplash <<M_PROG
addpath '${HCPPIPEDIR}/PostFix'; addpath '${MATLAB_GIFTI_LIB}'; addpath '${FSLDIR}/etc/matlab'; prepareICAs('${dtseriesName}','${ICAs}','${CARET7DIR}/wb_command','${ICAdtseries}','${NoiseICAs}','${Noise}','${Signal}','${ComponentList}',${g_high_pass_use},${TR});
M_PROG
			log_Msg "addpath '${HCPPIPEDIR}/PostFix'; addpath '${MATLAB_GIFTI_LIB}'; addpath '${FSLDIR}/etc/matlab'; prepareICAs('${dtseriesName}','${ICAs}','${CARET7DIR}/wb_command','${ICAdtseries}','${NoiseICAs}','${Noise}','${Signal}','${ComponentList}',${g_high_pass_use},${TR});"
			;;

		*)
			log_Err_Abort "Unrecognized MATLAB run mode value: ${g_matlab_run_mode}"
			;;
	esac

	log_Msg "Convert dense time series to scalar. Output ${ICAFolder}/melodic_oIC_vol.dscalar.nii"
	${CARET7DIR}/wb_command -cifti-convert-to-scalar ${ICAFolder}/melodic_oIC_vol.dtseries.nii ROW ${ICAFolder}/melodic_oIC_vol.dscalar.nii -name-file ${ComponentList}

	log_Msg "Convert dense time series to scalar. Output ${ICAFolder}/melodic_oIC.dscalar.nii"
	${CARET7DIR}/wb_command -cifti-convert-to-scalar ${ICAFolder}/melodic_oIC.dtseries.nii ROW ${ICAFolder}/melodic_oIC.dscalar.nii -name-file ${ComponentList}

	log_Msg "Create scaler series"
	${CARET7DIR}/wb_command -cifti-create-scalar-series ${ICAs} ${ICAs}.sdseries.nii -transpose -name-file ${ComponentList} -series SECOND 0 ${TR}

	# TimC: step=1/length-of-time-course-in-seconds=1/NumTimePoints*TR
	FTmixStep=$(echo "scale=7 ; 1/(${NumTimePoints}*${TR})" | bc -l)
	log_Msg "FTmixStep: ${FTmixStep}"
	${CARET7DIR}/wb_command -cifti-create-scalar-series ${ICAFolder}/melodic_FTmix ${ICAFolder}/melodic_FTmix.sdseries.nii -transpose -name-file ${ComponentList} -series HERTZ 0 ${FTmixStep}
	rm ${ComponentList}

	log_Msg "Making dual screen scene"
	cat ${g_template_scene_dual_screen} | sed s/SubjectID/${g_subject}/g | sed s/fMRIName/${g_fmri_name}/g | sed s@StudyFolder@"../../../.."@g > ${ResultsFolder}/${g_subject}_${g_fmri_name}_ICA_Classification_dualscreen.scene

	log_Msg "Making single screen scene"
	cat ${g_template_scene_single_screen} | sed s/SubjectID/${g_subject}/g | sed s/fMRIName/${g_fmri_name}/g | sed s@StudyFolder@"../../../.."@g > ${ResultsFolder}/${g_subject}_${g_fmri_name}_ICA_Classification_singlescreen.scene

	if [ ! -e ${ResultsFolder}/ReclassifyAsSignal.txt ] ; then
		touch ${ResultsFolder}/ReclassifyAsSignal.txt
	fi

	if [ ! -e ${ResultsFolder}/ReclassifyAsNoise.txt ] ; then
		touch ${ResultsFolder}/ReclassifyAsNoise.txt
	fi
}

# ------------------------------------------------------------------------------
#  Invoke the main function to get things started
# ------------------------------------------------------------------------------

main "$@"
