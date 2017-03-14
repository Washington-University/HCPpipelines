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
	unset g_StudyFolder
	unset g_Subject
	unset g_fMRIName
	unset g_HighPass
	unset g_TemplateSceneDualScreen
	unset g_TemplateSceneSingleScreen
	unset g_ReuseHighPass
	unset g_MatlabRunMode

	# set default values
	g_MatlabRunMode=0

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
				g_StudyFolder=${argument#*=}
				index=$(( index + 1 ))
				;;
			--study-folder=*)
				g_StudyFolder=${argument#*=}
				index=$(( index + 1 ))
				;;
			--subject=*)
				g_Subject=${argument#*=}
				index=$(( index + 1 ))
				;;
			--fmri-name=*)
				g_fMRIName=${argument#*=}
				index=$(( index + 1 ))
				;;
			--high-pass=*)
				g_HighPass=${argument#*=}
				index=$(( index + 1 ))
				;;
			--template-scene-dual-screen=*)
				g_TemplateSceneDualScreen=${argument#*=}
				index=$(( index + 1 ))
				;;
			--template-scene-single-screen=*)
				g_TemplateSceneSingleScreen=${argument#*=}
				index=$(( index + 1 ))
				;;
			--reuse-high-pass=*)
				g_ReuseHighPass=${argument#*=}
				index=$(( index + 1 ))
				;;
			--matlab-run-mode=*)
				g_MatlabRunMode=${argument#*=}
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
	if [ -z "${g_StudyFolder}" ]; then
		log_Err "study folder (--path= or --study-folder=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_StudyFolder: ${g_StudyFolder}"
	fi

	if [ -z "${g_Subject}" ]; then
		log_Err "Subject ID required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_Subject: ${g_Subject}"
	fi

	if [ -z "${g_fMRIName}" ]; then
		log_Err "fMRI name required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_fMRIName: ${g_fMRIName}"
	fi

	if [ -z "${g_HighPass}" ]; then
		log_Err "High Pass required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_HighPass: ${g_HighPass}"
	fi

	if [ -z "${g_TemplateSceneDualScreen}" ]; then
		log_Err "Dual Screen Template Scene required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_TemplateSceneDualScreen: ${g_TemplateSceneDualScreen}"
	fi

	if [ -z "${g_TemplateSceneSingleScreen}" ]; then
		log_Err "Single Screen Template Scene required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_TemplateSceneSingleScreen: ${g_TemplateSceneSingleScreen}"
	fi

	if [ -z "${g_ReuseHighPass}" ]; then
		log_Err "reuse high pass not specified"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_ReuseHighPass: ${g_ReuseHighPass}"
	fi

	if [ -z "${g_MatlabRunMode}" ]; then
		log_Err "matlab run mode value (--matlab-run-mode=) required"
		error_count=$(( error_count + 1 ))
	else
		case ${g_MatlabRunMode} in
			0)
				log_Msg "g_MatlabRunMode: ${g_MatlabRunMode}"
				if [ -z "${MATLAB_COMPILER_RUNTIME}" ]; then
					log_Err_Abort "To use MATLAB run mode: ${g_MatlabRunMode}, the MATLAB_COMPILER_RUNTIME environment variable must be set"
				else
					log_Msg "MATLAB_COMPILER_RUNTIME: ${MATLAB_COMPILER_RUNTIME}"
				fi
				;;
			1)
				log_Msg "g_MatlabRunMode: ${g_MatlabRunMode}"
				if [ -z "${MATLAB_GIFTI_LIB}" ]; then
					log_Err_Abort "To use MATLAB run mode: ${g_MatlabRunMode}, the MATLAB_GIFTI_LIB environment variable must be set"
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
	local AtlasFolder="${g_StudyFolder}/${g_Subject}/MNINonLinear"
	log_Msg "AtlasFolder: ${AtlasFolder}"

	local ResultsFolder="${AtlasFolder}/Results/${g_fMRIName}"
	log_Msg "ResultsFolder: ${ResultsFolder}"

	local ICAFolder="${ResultsFolder}/${g_fMRIName}_hp${g_HighPass}.ica/filtered_func_data.ica"
	log_Msg "ICAFolder: ${ICAFolder}"

	local FIXFolder="${ResultsFolder}/${g_fMRIName}_hp${g_HighPass}.ica"
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
	local HighPassUse
	if [ ${g_ReuseHighPass} = "YES" ] ; then
		dtseriesName="${ResultsFolder}/${g_fMRIName}_Atlas_hp${g_HighPass}" #No Extension Here
		log_Msg "dtseriesName: ${dtseriesName}"
		HighPassUse="-1"
	else
		dtseriesName="${ResultsFolder}/${g_fMRIName}_Atlas" #No Extension Here
		log_Msg "dtseriesName: ${dtseriesName}"
		HighPassUse="${g_HighPass}"
	fi

	local ICAs="${ICAFolder}/melodic_mix"
	log_Msg "ICAs: ${ICAs}"

	local ICAdtseries="${ICAFolder}/melodic_oIC.dtseries.nii"
	log_Msg "ICAdtseries: ${ICAdtseries}"

	local NoiseICAs="${FIXFolder}/.fix"
	log_Msg "NoiseICAs: ${NoiseICAs}"

	local Noise="${FIXFolder}/Noise.txt"
	log_Msg "Noise: ${Noise}"

	local Signal="${FIXFolder}/Signal.txt"
	log_Msg "Signal: ${Signal}"

	local ComponentList="${FIXFolder}/ComponentList.txt"
	log_Msg "ComponentList: ${ComponentList}"

	local TR=$(${FSLDIR}/bin/fslval ${ResultsFolder}/${g_fMRIName}_hp${g_HighPass}_clean pixdim4)
	log_Msg "TR: ${TR}"

	local NumTimePoints=$(${FSLDIR}/bin/fslval ${ResultsFolder}/${g_fMRIName}_hp${g_HighPass}_clean dim4)
	log_Msg "NumTimePoints: ${NumTimePoints}"

	if [ -e ${ComponentList} ] ; then
		log_Msg "Removing ComponentList: ${ComponentList}"
		rm ${ComponentList}
	fi

	# run MATLAB prepareICAs function
	case ${g_MatlabRunMode} in

		0)
			# Use Compiled Matlab
			local matlab_exe
			matlab_exe="${HCPPIPEDIR}"
			matlab_exe+="/PostFix/Compiled_prepareICAs/run_prepareICAs.sh"
			
			local matlab_compiler_runtime
			matlab_compiler_runtime="${MATLAB_COMPILER_RUNTIME}"

			local matlab_function_arguments
			matlab_function_arguments="'${dtseriesName}'"
			matlab_function_arguments+=" '${ICAs}'"
			matlab_function_arguments+=" '${CARET7DIR}/wb_command'"
			matlab_function_arguments+=" '${ICAdtseries}'"
			matlab_function_arguments+=" '${NoiseICAs}'"
			matlab_function_arguments+=" '${Noise}'"
			matlab_function_arguments+=" '${Signal}'"
			matlab_function_arguments+=" '${ComponentList}'"
			matlab_function_arguments+=" ${HighPassUse}"
			matlab_function_arguments+=" ${TR} "

			local matlab_logging
			matlab_logging=">> ${g_StudyFolder}/${g_Subject}_${g_fMRIName}.matlab.log 2>&1"

			local matlab_cmd
			matlab_cmd="${matlab_exe} ${matlab_compiler_runtime} ${matlab_function_arguments} ${matlab_logging}"

			log_Msg "Run MATLAB command: ${matlab_cmd}"

			echo "${matlab_cmd}" | bash
			log_Msg "MATLAB command return code: $?"
			;;

		1)
			# Use interpreted MATLAB

			matlab -nojvm -nodisplay -nosplash <<M_PROG
addpath '${HCPPIPEDIR}/PostFix'; addpath '${MATLAB_GIFTI_LIB}'; addpath '${FSLDIR}/etc/matlab'; prepareICAs('${dtseriesName}','${ICAs}','${CARET7DIR}/wb_command','${ICAdtseries}','${NoiseICAs}','${Noise}','${Signal}','${ComponentList}',${HighPassUse},${TR});
M_PROG
			log_Msg "addpath '${HCPPIPEDIR}/PostFix'; addpath '${MATLAB_GIFTI_LIB}'; addpath '${FSLDIR}/etc/matlab'; prepareICAs('${dtseriesName}','${ICAs}','${CARET7DIR}/wb_command','${ICAdtseries}','${NoiseICAs}','${Noise}','${Signal}','${ComponentList}',${HighPassUse},${TR});"
			;;

		*)
			log_Err_Abort "Unrecognized MATLAB run mode value: ${g_MatlabRunMode}"
			;;
	esac

	log_Msg "Convert dense time series to scalar. Output ${ICAFolder}/melodic_oIC_vol.dscalar.nii"
	${CARET7DIR}/wb_command -cifti-convert-to-scalar ${ICAFolder}/melodic_oIC_vol.dtseries.nii ROW ${ICAFolder}/melodic_oIC_vol.dscalar.nii -name-file ${ComponentList}

	log_Msg "Convert dense time series to scalar. Output ${ICAFolder}/melodic_oIC.dscalar.nii"
	${CARET7DIR}/wb_command -cifti-convert-to-scalar ${ICAFolder}/melodic_oIC.dtseries.nii ROW ${ICAFolder}/melodic_oIC.dscalar.nii -name-file ${ComponentList}

	log_Msg "Create scaler series"
	${CARET7DIR}/wb_command -cifti-create-scalar-series ${ICAs} ${ICAs}.sdseries.nii -transpose -name-file ${ComponentList} -series SECOND 0 ${TR}

	# TimC: step=1/length-of-time-course-in-seconds=1/NumTimePoints*TR
	local FTmixStep=$(echo "scale=7 ; 1/(${NumTimePoints}*${TR})" | bc -l)
	log_Msg "FTmixStep: ${FTmixStep}"
	${CARET7DIR}/wb_command -cifti-create-scalar-series ${ICAFolder}/melodic_FTmix ${ICAFolder}/melodic_FTmix.sdseries.nii -transpose -name-file ${ComponentList} -series HERTZ 0 ${FTmixStep}
	rm ${ComponentList}

	log_Msg "Making dual screen scene"
	cat ${g_TemplateSceneDualScreen} | sed s/SubjectID/${g_Subject}/g | sed s/fMRIName/${g_fMRIName}/g | sed s@StudyFolder@"../../../.."@g > ${ResultsFolder}/${g_Subject}_${g_fMRIName}_ICA_Classification_dualscreen.scene

	log_Msg "Making single screen scene"
	cat ${g_TemplateSceneSingleScreen} | sed s/SubjectID/${g_Subject}/g | sed s/fMRIName/${g_fMRIName}/g | sed s@StudyFolder@"../../../.."@g > ${ResultsFolder}/${g_Subject}_${g_fMRIName}_ICA_Classification_singlescreen.scene

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
