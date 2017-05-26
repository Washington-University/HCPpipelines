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
	unset p_StudyFolder
	unset p_Subject
	unset p_fMRIName
	unset p_HighPass
	unset p_TemplateSceneDualScreen
	unset p_TemplateSceneSingleScreen
	unset p_ReuseHighPass
	unset p_MatlabRunMode

	# set default values
	p_MatlabRunMode=0

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
				p_StudyFolder=${argument#*=}
				index=$(( index + 1 ))
				;;
			--study-folder=*)
				p_StudyFolder=${argument#*=}
				index=$(( index + 1 ))
				;;
			--subject=*)
				p_Subject=${argument#*=}
				index=$(( index + 1 ))
				;;
			--fmri-name=*)
				p_fMRIName=${argument#*=}
				index=$(( index + 1 ))
				;;
			--high-pass=*)
				p_HighPass=${argument#*=}
				index=$(( index + 1 ))
				;;
			--template-scene-dual-screen=*)
				p_TemplateSceneDualScreen=${argument#*=}
				index=$(( index + 1 ))
				;;
			--template-scene-single-screen=*)
				p_TemplateSceneSingleScreen=${argument#*=}
				index=$(( index + 1 ))
				;;
			--reuse-high-pass=*)
				p_ReuseHighPass=${argument#*=}
				index=$(( index + 1 ))
				;;
			--matlab-run-mode=*)
				p_MatlabRunMode=${argument#*=}
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
	if [ -z "${p_StudyFolder}" ]; then
		log_Err "Study Folder (--path= or --study-folder=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Study Folder: ${p_StudyFolder}"
	fi

	if [ -z "${p_Subject}" ]; then
		log_Err "Subject ID (--subject=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Subject ID: ${p_Subject}"
	fi

	if [ -z "${p_fMRIName}" ]; then
		log_Err "fMRI Name (--fmri-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "fMRI Name: ${p_fMRIName}"
	fi

	if [ -z "${p_HighPass}" ]; then
		log_Err "High Pass: (--high-pass=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "High Pass: ${p_HighPass}"
	fi

	if [ -z "${p_TemplateSceneDualScreen}" ]; then
		log_Err "Dual Screen Template Scene (--template-scene-dual-screen=)required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Dual Screen Template Scene: ${p_TemplateSceneDualScreen}"
	fi

	if [ -z "${p_TemplateSceneSingleScreen}" ]; then
		log_Err "Single Screen Template Scene (--template-scene-single-screen=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Single Screen Template Scene: ${p_TemplateSceneSingleScreen}"
	fi

	if [ -z "${p_ReuseHighPass}" ]; then
		log_Err "Reuse High Pass (--reuse-high-pass=<YES | NO>) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Reuse High Pass: ${p_ReuseHighPass}"
	fi

	if [ -z "${p_MatlabRunMode}" ]; then
		log_Err "MATLAB Run Mode (--matlab-run-mode=) required"
		error_count=$(( error_count + 1 ))
	else
		case ${p_MatlabRunMode} in
			0)
				log_Msg "MATLAB Run Mode: ${p_MatlabRunMode}"
				if [ -z "${MATLAB_COMPILER_RUNTIME}" ]; then
					log_Err_Abort "To use MATLAB run mode: ${p_MatlabRunMode}, the MATLAB_COMPILER_RUNTIME environment variable must be set"
				else
					log_Msg "MATLAB_COMPILER_RUNTIME: ${MATLAB_COMPILER_RUNTIME}"
				fi
				;;
			1)
				log_Msg "MATLAB Run Mode: ${p_MatlabRunMode}"
				if [ -z "${MATLAB_GIFTI_LIB}" ]; then
					log_Err_Abort "To use MATLAB run mode: ${p_MatlabRunMode}, the MATLAB_GIFTI_LIB environment variable must be set"
				else
					log_Msg "MATLAB_GIFTI_LIB: ${MATLAB_GIFTI_LIB}"
				fi
				;;
			*)
				log_Err_Abort "MATLAB Run Mode value must be 0 or 1"
				error_count=$(( error_count + 1 ))
				;;
		esac
	fi

	if [ ${error_count} -gt 0 ]; then
		log_Err_Abort "For usage information, use --help"
	fi
}

# ------------------------------------------------------------------------------
#  Show Tool Versions
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
	log_Msg "main functionality begin"
	
	# Retrieve positional parameters
	local StudyFolder="${1}"
	local Subject="${2}"
	local fMRIName="${3}"
	local HighPass="${4}"
	local TemplateSceneDualScreen="${5}"
	local TemplateSceneSingleScreen="${6}"
	local ReuseHighPass="${7}"

	local MatlabRunMode
	if [ -z "${8}" ]; then
		MatlabRunMode=0
	else
		MatlabRunMode="${8}"
	fi
	
	# Log values retrieved from positional parameters
	log_Msg "StudyFolder: ${StudyFolder}"
	log_Msg "Subject: ${Subject}"
	log_Msg "fMRIName: ${fMRIName}"
	log_Msg "HighPass: ${HighPass}"
	log_Msg "TemplateSceneDualScreen: ${TemplateSceneDualScreen}"
	log_Msg "TemplateSceneSingleScreen: ${TemplateSceneSingleScreen}"
	log_Msg "ReuseHighPass: ${ReuseHighPass}"
	log_Msg "MatlabRunMode: ${MatlabRunMode}"

	# Naming Conventions and other variables
	local AtlasFolder="${StudyFolder}/${Subject}/MNINonLinear"
	log_Msg "AtlasFolder: ${AtlasFolder}"

	local ResultsFolder="${AtlasFolder}/Results/${fMRIName}"
	log_Msg "ResultsFolder: ${ResultsFolder}"

	local ICAFolder="${ResultsFolder}/${fMRIName}_hp${HighPass}.ica/filtered_func_data.ica"
	log_Msg "ICAFolder: ${ICAFolder}"

	local FIXFolder="${ResultsFolder}/${fMRIName}_hp${HighPass}.ica"
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
	if [ ${ReuseHighPass} = "YES" ] ; then
		dtseriesName="${ResultsFolder}/${fMRIName}_Atlas_hp${HighPass}" #No Extension Here
		log_Msg "dtseriesName: ${dtseriesName}"
		HighPassUse="-1"
	else
		dtseriesName="${ResultsFolder}/${fMRIName}_Atlas" #No Extension Here
		log_Msg "dtseriesName: ${dtseriesName}"
		HighPassUse="${HighPass}"
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

	local TR=$(${FSLDIR}/bin/fslval ${ResultsFolder}/${fMRIName}_hp${HighPass}_clean pixdim4)
	log_Msg "TR: ${TR}"

	local NumTimePoints=$(${FSLDIR}/bin/fslval ${ResultsFolder}/${fMRIName}_hp${HighPass}_clean dim4)
	log_Msg "NumTimePoints: ${NumTimePoints}"

	if [ -e ${ComponentList} ] ; then
		log_Msg "Removing ComponentList: ${ComponentList}"
		rm ${ComponentList}
	fi

	# run MATLAB prepareICAs function
	case ${MatlabRunMode} in

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
			matlab_logging=">> ${StudyFolder}/${Subject}_${fMRIName}.matlab.log 2>&1"

			local matlab_cmd
			matlab_cmd="${matlab_exe} ${matlab_compiler_runtime} ${matlab_function_arguments} ${matlab_logging}"

			# Note: Simply using ${matlab_cmd} here instead of echo "${matlab_cmd}" | bash
			#       does NOT work. The output redirects that are part of the ${matlab_logging}
			#       value, get quoted by the run_*.sh script generated by the MATLAB compiler
			#       such that they get passed as parameters to the underlying executable.
			#       So ">>" gets passed as a parameter to the executable as does the
			#       log file name and the "2>&1" redirection. This causes the executable
			#       to die with a "too many parameters" error message.
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
			log_Err_Abort "Unrecognized MATLAB run mode value: ${MatlabRunMode}"
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
	cat ${TemplateSceneDualScreen} | sed s/SubjectID/${Subject}/g | sed s/fMRIName/${fMRIName}/g | sed s@StudyFolder@"../../../.."@g > ${ResultsFolder}/${Subject}_${fMRIName}_ICA_Classification_dualscreen.scene

	log_Msg "Making single screen scene"
	cat ${TemplateSceneSingleScreen} | sed s/SubjectID/${Subject}/g | sed s/fMRIName/${fMRIName}/g | sed s@StudyFolder@"../../../.."@g > ${ResultsFolder}/${Subject}_${fMRIName}_ICA_Classification_singlescreen.scene

	if [ ! -e ${ResultsFolder}/ReclassifyAsSignal.txt ] ; then
		touch ${ResultsFolder}/ReclassifyAsSignal.txt
	fi

	if [ ! -e ${ResultsFolder}/ReclassifyAsNoise.txt ] ; then
		touch ${ResultsFolder}/ReclassifyAsNoise.txt
	fi

	log_Msg "main functionality end"
}

# ------------------------------------------------------------------------------
#  "Global" processing - everything above here should be in a function
# ------------------------------------------------------------------------------

set -e # If any commands exit with non-zero value, this script exits

# Verify HCPPIPEDIR environment variable is set
if [ -z "${HCPPIPEDIR}" ]; then
	script_name=$(basename "${0}")
	echo "${script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
	exit 1
fi

#  Load function libraries
source ${HCPPIPEDIR}/global/scripts/log.shlib # Logging related functions
log_Msg "HCPPIPEDIR: ${HCPPIPEDIR}"

source ${HCPPIPEDIR}/global/scripts/fsl_version.shlib # Function for getting FSL version

# Verify that other needed environment variables are set
if [ -z "${CARET7DIR}" ]; then
	log_Err_Abort "CARET7DIR environment variable must be set"
fi
log_Msg "CARET7DIR: ${CARET7DIR}"

if [ -z "${FSLDIR}" ]; then
	log_Err_Abort "FSLDIR environment variable must be set"
fi
log_Msg "FSLDIR: ${FSLDIR}"

# Show tool versions
show_tool_versions

# Determine whether named or positional parameters are used
if [[ ${1} == --* ]]; then
	# Named parameters (e.g. --parameter-name=parameter-value) are used
	log_Msg "Using named parameters"

	# Get command line options
	get_options "$@"

	# Invoke main functionality using positional parameters
	#     ${1}               ${2}           ${3}            ${4}            ${5}                           ${6}                             ${7}                 ${8}
	main "${p_StudyFolder}" "${p_Subject}" "${p_fMRIName}" "${p_HighPass}" "${p_TemplateSceneDualScreen}" "${p_TemplateSceneSingleScreen}" "${p_ReuseHighPass}"	"${p_MatlabRunMode}"

else
	# Positional parameters are used
	log_Msg "Using positional parameters"
	main $@

fi
