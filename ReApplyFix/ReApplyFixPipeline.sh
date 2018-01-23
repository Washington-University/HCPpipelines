#!/bin/bash

#
# # ReApplyFixPipeline.sh
#
# ## Copyright Notice
#
# Copyright (C) 2015-2017 The Human Connectome Project/Connectome Coordination Facility
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

${script_name}: ReApplyFix Pipeline

Usage: ${script_name} PARAMETER...

PARAMETERs are [ ] = optional; < > = user supplied value

  Note: The PARAMETERS can be specified positionally (i.e. without using the --param=value
        form) by simply specifying all values on the command line in the order they are
        listed below.

        E.g. ${script_name} /path/to/study/folder 100307 rfMRI_REST1_LR 2000 ...

        When using this technique, if the optional low res mesh value is not specified, then 
        the default low res mesh value is used (${G_DEFAULT_LOW_RES_MESH}) and the default
        MATLAB run mode (${G_DEFAULT_MATLAB_RUN_MODE}) are used.

  [--help] : show usage information and exit
   --path=<path to study folder> OR --study-folder=<path to study folder>
   --subject=<subject ID>
   --fmri-name=<string> String to represent the ${fMRIName} variable
   --high-pass=<num> Number to represent the ${HighPass} variable used in ICA+FIX
   --reg-name=<string> String to represent the registration that was done (e.g. by DeDriftAndResamplePipeline).  
  [--low-res-mesh=<meshnum> String corresponding to low res mesh number]
  [--matlab-run-mode={0, 1}] defaults to ${G_DEFAULT_MATLAB_RUN_MODE}
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
	unset p_RegName
	unset p_LowResMesh
	unset p_MatlabRunMode

	# set default values
	p_LowResMesh=${G_DEFAULT_LOW_RES_MESH}
	p_MatlabRunMode=${G_DEFAULT_MATLAB_RUN_MODE}

	# parse arguments
	local num_args=${#arguments[@]}
	local argument
	local index=0

	while [ "${index}" -lt "${num_args}" ]; do
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
			--reg-name=*)
				p_RegName=${argument#*=}
				index=$(( index + 1 ))
				;;
			--low-res-mesh=*)
				p_LowResMesh=${argument#*=}
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
		log_Err "High Pass (--high-pass=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "High Pass: ${p_HighPass}"
	fi

	if [ -z "${p_RegName}" ]; then
		log_Err "Reg Name (--reg-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Reg Name: ${p_RegName}"
	fi

	if [ -z "${p_LowResMesh}" ]; then
		log_Err "Low Res Mesh (--low-res-mesh=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Low Res Mesh: ${p_LowResMesh}"
	fi

	if [ -z "${p_MatlabRunMode}" ]; then
		log_Err "MATLAB run mode value (--matlab-run-mode=) required"
		error_count=$(( error_count + 1 ))
	else
		case ${p_MatlabRunMode} in
			0)
				log_Msg "MATLAB Run Mode: ${p_MatlabRunMode} - Use compiled MATLAB"
				if [ -z "${MATLAB_COMPILER_RUNTIME}" ]; then
					log_Err_Abort "To use MATLAB run mode: ${p_MatlabRunMode}, the MATLAB_COMPILER_RUNTIME environment variable must be set"
				else
					log_Msg "MATLAB_COMPILER_RUNTIME: ${MATLAB_COMPILER_RUNTIME}"
				fi
				;;
			1)
				log_Msg "MATLAB Run Mode: ${p_MatlabRunMode} - Use interpreted MATLAB"
				;;
			*)
				log_Err "MATLAB Run Mode value must be 0 or 1"
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

show_tool_versions()
{
	# Show HCP pipelines version
	log_Msg "Showing HCP Pipelines version"
	cat ${HCPPIPEDIR}/version.txt

	# Show wb_command version
	log_Msg "Showing Connectome Workbench (wb_command) version"
	${CARET7DIR}/wb_command -version

	# Show FSL version
	log_Msg "Showing FSL version"
	fsl_version_get fsl_ver
	log_Msg "FSL version: ${fsl_ver}"
}

# ------------------------------------------------------------------------------
#  Check for whether or not we have hand reclassification files
# ------------------------------------------------------------------------------

have_hand_reclassification()
{
	local StudyFolder="${1}"
	local Subject="${2}"
	local fMRIName="${3}"
	local HighPass="${4}"

	[ -e "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}.ica/HandNoise.txt" ]
}

# ------------------------------------------------------------------------------
#  Main processing of script.
# ------------------------------------------------------------------------------

main()
{
	log_Msg "Starting main functionality"

	# Retrieve positional parameters
	local StudyFolder="${1}"
	local Subject="${2}"
	local fMRIName="${3}"
	local HighPass="${4}"
	local RegName="${5}"

	local LowResMesh
	if [ -z "${6}" ]; then
		LowResMesh=${G_DEFAULT_LOW_RES_MESH}
	else
		LowResMesh="${6}"
	fi
	
	local MatlabRunMode
	if [ -z "${7}" ]; then
		MatlabRunMode=${G_DEFAULT_MATLAB_RUN_MODE}
	else
		MatlabRunMode="${7}"
	fi
	
	# Log values retrieved from positional parameters
	log_Msg "StudyFolder: ${StudyFolder}"
	log_Msg "Subject: ${Subject}"
	log_Msg "fMRIName: ${fMRIName}"
	log_Msg "HighPass: ${HighPass}"
	log_Msg "RegName: ${RegName}"
	log_Msg "LowResMesh: ${LowResMesh}"
	log_Msg "MatlabRunMode: ${MatlabRunMode}"

	# Naming Conventions and other variables
	local Caret7_Command="${CARET7DIR}/wb_command"
	log_Msg "Caret7_Command: ${Caret7_Command}"

	local RegString
	if [ ${RegName} != "NONE" ] ; then
		RegString="_${RegName}"
	else
		RegString=""
	fi
	
	if [ ! -z ${LowResMesh} ] && [ ${LowResMesh} != ${G_DEFAULT_LOW_RES_MESH} ]; then
		RegString="${RegString}.${LowResMesh}k"
	fi

	log_Msg "RegString: ${RegString}"

	export FSL_FIX_CIFTIRW="${HCPPIPEDIR}/ReApplyFix/scripts"
	export FSL_FIX_WBC="${Caret7_Command}"
	export FSL_MATLAB_PATH="${FSLDIR}/etc/matlab"

	# Make appropriate files if they don't exist

	local aggressive=0
	local domot=1
	local hp=${HighPass}

	local fixlist
	if have_hand_reclassification ${StudyFolder} ${Subject} ${fMRIName} ${HighPass} ; then
		fixlist="HandNoise.txt"
	else
		fixlist=".fix"
	fi
	local fmri_orig="${fMRIName}"
	local fmri=${fMRIName}

	DIR=$(pwd)
	cd ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}.ica

	if [ -f ../${fmri_orig}_Atlas${RegString}.dtseries.nii ] ; then
		log_Msg "FOUND FILE: ../${fmri_orig}_Atlas${RegString}.dtseries.nii"
		log_Msg "Performing imln"

		rm -f Atlas.dtseries.nii
		$FSLDIR/bin/imln ../${fmri_orig}_Atlas${RegString}.dtseries.nii Atlas.dtseries.nii

		log_Msg "START: Showing linked files"
		ls -l ../${fmri_orig}_Atlas${RegString}.dtseries.nii
		ls -l Atlas.dtseries.nii
		log_Msg "END: Showing linked files"
	else
		log_Warn "FILE NOT FOUND: ../${fmri_orig}_Atlas${RegString}.dtseries.nii"
	fi

	$FSLDIR/bin/imln ../$fmri filtered_func_data

	mkdir -p mc
	if [ -f ../Movement_Regressors.txt ] ; then
		log_Msg "Creating mc/prefiltered_func_data_mcf.par file"
		cat ../Movement_Regressors.txt | awk '{ print $4 " " $5 " " $6 " " $1 " " $2 " " $3}' > mc/prefiltered_func_data_mcf.par
	else
		log_Err_Abort "Movement_Regressors.txt not retrieved properly."
	fi

	log_Msg "About to run fix_3_clean"

	case ${MatlabRunMode} in

		0)
			# Use Compiled MATLAB

			local matlab_exe="${HCPPIPEDIR}/ReApplyFix/scripts/Compiled_fix_3_clean/run_fix_3_clean.sh"

			local matlab_function_arguments
			if have_hand_reclassification ${StudyFolder} ${Subject} ${fMRIName} ${HighPass} ; then #Function above
				DoVol="0"
				matlab_function_arguments="'${fixlist}' ${aggressive} ${domot} ${hp} ${DoVol}"
			else
				matlab_function_arguments="'${fixlist}' ${aggressive} ${domot} ${hp} 0"
			fi

			local matlab_logging=">> ${StudyFolder}/${Subject}_${fMRIName}_${HighPass}${RegString}.fix_3_clean.matlab.log 2>&1"
			local matlab_cmd="${matlab_exe} ${MATLAB_COMPILER_RUNTIME} ${matlab_function_arguments} ${matlab_logging}"

			# Note: Simply using ${matlab_cmd} here instead of echo "${matlab_cmd}" | bash
			#       does NOT work. The output redirects that are part of the ${matlab_logging}
			#       value, get quoted by the run_*.sh script generated by the MATLAB compiler
			#       such that they get passed as parameters to the underlying executable.
			#       So ">>" gets passed as a parameter to the executable as does the
			#       log file name and the "2>&1" redirection. This causes the executable
			#       to die with a "too many parameters" error message.
			log_Msg "Run MATLAB command: ${matlab_cmd}"
			echo "${matlab_cmd}" | bash
			log_Msg "MATLAB command return code $?"
			;;

		1)
			# Use interpreted MATLAB
			ML_PATHS="addpath('${FSL_MATLAB_PATH}'); addpath('${FSL_FIX_CIFTIRW}');"

			if have_hand_reclassification ${StudyFolder} ${Subject} ${fMRIName} ${HighPass} ; then #Function above
			  DoVol="0"
				matlab -nojvm -nodisplay -nosplash <<M_PROG
${ML_PATHS} fix_3_clean('${fixlist}',${aggressive},${domot},${hp},${DoVol});
M_PROG
			else
				matlab -nojvm -nodisplay -nosplash <<M_PROG
${ML_PATHS} fix_3_clean('${fixlist}',${aggressive},${domot},${hp});
M_PROG
			fi
			;;

		*)
			# Unsupported MATLAB run mode
			log_Err_Abort "Unsupported MATLAB run mode value: ${MatlabRunMode}"
			;;
	esac

	fmri="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}"
	fmri_orig="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}"
	if [ -f ${fmri}.ica/Atlas_clean.dtseries.nii ] ; then
		/bin/mv ${fmri}.ica/Atlas_clean.dtseries.nii ${fmri_orig}_Atlas${RegString}_hp${hp}_clean.dtseries.nii
	fi

	if have_hand_reclassification ${StudyFolder} ${Subject} ${fMRIName} ${HighPass} ; then
		$FSLDIR/bin/immv ${fmri}.ica/filtered_func_data_clean ${fmri}_clean
	fi

	cd ${DIR}

	log_Msg "Completing main functionality"
}

# ------------------------------------------------------------------------------
#  "Global" processing - everything above here should be in a function
# ------------------------------------------------------------------------------

set -e # If any command exits with non-zero value, this script exits

# Verify that HCPPIPEDIR environment variable is set
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

# Establish default MATLAB run mode
G_DEFAULT_MATLAB_RUN_MODE=1		# Use interpreted MATLAB

# Establish default low res mesh
G_DEFAULT_LOW_RES_MESH=32

# Determine whether named or positional parameters are used
if [[ ${1} == --* ]]; then
	# Named parameters (e.g. --parameter-name=parameter-value) are used
	log_Msg "Using named parameters"

	# Get command line options
	get_options "$@"

	# Invoke main functionality
	#     ${1}               ${2}           ${3}            ${4}            ${5}           ${6}              ${7}
	main "${p_StudyFolder}" "${p_Subject}" "${p_fMRIName}" "${p_HighPass}" "${p_RegName}" "${p_LowResMesh}" "${p_MatlabRunMode}"

else
	# Positional parameters are used
	log_Msg "Using positional parameters"
	main "$@"

fi
