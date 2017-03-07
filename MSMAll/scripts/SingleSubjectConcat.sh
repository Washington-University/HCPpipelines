#!/bin/bash

#~ND~FORMAT~MARKDOWN
#~ND~START~
#
# # SingleSubjectConcat.sh
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
# ## Description
#
# TBW
#
# ## Prerequisites
#
# ### Installed Software
#
# * TBW
#
# ### Environment Variables
#
# * HCPPIPEDIR
#
#   The "home" directory for the HCP Pipeline product.
#   e.g. /home/tbrown01/projects/Pipelines
#
# * CARET7DIR
#
#   The executable directory for the Connectome Workbench installation
#
# <!-- References -->
# [HCP]: http://www.humanconnectome.org
#
#~ND~END~

# ------------------------------------------------------------------------------
#  Code Start
# ------------------------------------------------------------------------------

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

# ------------------------------------------------------------------------------
#  Verify other needed environment variables are set
# ------------------------------------------------------------------------------

if [ -z "${CARET7DIR}" ]; then
	log_Err_Abort "CARET7DIR environment variable must be set"
fi
log_Msg "CARET7DIR: ${CARET7DIR}"

# ------------------------------------------------------------------------------
#  Show usage information for this script
# ------------------------------------------------------------------------------

usage()
{
	local script_name
	script_name=$(basename "${0}")

	cat <<EOF

${script_name}: Single Subject Scan Concatenation

Usage: ${script_name} PARAMETER...

PARAMETERs are [ ] = optional; < > = user supplied value

  [--help] : show usage information and exit
   --path=<path to study folder> OR --study-folder=<path to study folder>
   --subject=<subject ID>
   --fmri-names-list=<fMRI names> and @ symbol separated list of fMRI scan names
   --output-fmri-name=<name to give to concatenated single subject "scan">
   --fmri-proc-string=<identification for FIX cleaned dtseries to use>
   --migp-vars=TBW
   --output-proc-string=TBW
  [--matlab-run-mode={0, 1}] defaults to 0 (Compiled MATLAB)
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
	unset g_fmri_names_list
	unset g_output_fmri_name
	unset g_fmri_proc_string
	unset g_migp_vars
	unset g_output_proc_string
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
			--fmri-names-list=*)
				g_fmri_names_list=${argument#*=}
				index=$(( index + 1 ))
				;;
			--output-fmri-name=*)
				g_output_fmri_name=${argument#*=}
				index=$(( index + 1 ))
				;;
			--fmri-proc-string=*)
				g_fmri_proc_string=${argument#*=}
				index=$(( index + 1 ))
				;;
			--migp-vars=*)
				g_migp_vars=${argument#*=}
				index=$(( index + 1 ))
				;;
			--output-proc-string=*)
				g_output_proc_string=${argument#*=}
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

	if [ -z "${g_fmri_names_list}" ]; then
		log_Err "fMRI name list required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_fmri_names_list: ${g_fmri_names_list}"
	fi

	if [ -z "${g_output_fmri_name}" ]; then
		log_Err "output fMRI name required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_output_fmri_name: ${g_output_fmri_name}"
	fi

	if [ -z "${g_fmri_proc_string}" ]; then
		log_Err "fMRI proc string required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_fmri_proc_string: ${g_fmri_proc_string}"
	fi

	if [ -z "${g_migp_vars}" ]; then
		log_Err "MIGP vars required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_migp_vars: ${g_migp_vars}"
	fi

	if [ -z "${g_output_proc_string}" ]; then
		log_Err "output proc string required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_output_proc_string: ${g_output_proc_string}"
	fi

	if [ -z "${g_matlab_run_mode}" ]; then
		log_Err "MATLAB run mode value (--matlab-run_mode=) required"
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
#  Main processing of script.
# ------------------------------------------------------------------------------

main()
{
	# Get command line options
	get_options "$@"

	g_fmri_names_list=$(echo ${g_fmri_names_list} | sed 's/@/ /g')
	log_Msg "g_fmri_names_list: ${g_fmri_names_list}"

	# Naming Conventions
	AtlasFolder="${g_path_to_study_folder}/${g_subject}/MNINonLinear"
	log_Msg "AtlasFolder: ${AtlasFolder}"

	OutputFolder="${AtlasFolder}/Results/${g_output_fmri_name}"
	log_Msg "OutputFolder: ${OutputFolder}"

	if [ "${g_output_proc_string}" = "NONE" ]; then
		g_output_proc_string=""
	fi
	log_Msg "g_output_proc_string: ${g_output_proc_string}"

	OutputConcat="${OutputFolder}/${g_output_fmri_name}${g_fmri_proc_string}${g_output_proc_string}.dtseries.nii"
	log_Msg "OutputConcat: ${OutputConcat}"

	if [[ ! -e ${OutputConcat} || $(echo ${g_migp_vars} | cut -d "@" -f 4) = "YES" ]] ; then

		if [ ! -e "${OutputFolder}" ] ; then
			mkdir -p ${OutputFolder}
		fi

		txtfile="${OutputFolder}/${g_output_fmri_name}.txt"
		log_Msg "txtfile: ${txtfile}"

		if [ -e "${txtfile}" ]; then
			rm ${txtfile}
		fi

		touch ${txtfile}

		log_Msg "Showing txtfile: ${txtfile} contents"
		cat ${txtfile}
		log_Msg "Done Showing txtfile contents"

		for fMRIName in ${g_fmri_names_list} ; do
			ResultsFolder="${AtlasFolder}/Results/${fMRIName}"
			log_Msg "ResultsFolder: ${ResultsFolder}"
			echo "${ResultsFolder}/${fMRIName}${g_fmri_proc_string}" >> ${txtfile}
			log_Msg "Showing txtfile: ${txtfile} contents"
			cat ${txtfile}
			log_Msg "Done Showing txtfile contents"
		done

		VN=$(echo ${g_migp_vars} | cut -d "@" -f 5)
		log_Msg "VN: ${VN}"

		# run MATLAB ssConcat function
		case ${g_matlab_run_mode} in

			0)
				# Use Compiled Matlab
				matlab_exe="${HCPPIPEDIR}"
				matlab_exe+="/MSMAll/scripts/Compiled_ssConcat/distrib/run_ssConcat.sh"

				matlab_compiler_runtime="${MATLAB_COMPILER_RUNTIME}"

				matlab_function_arguments="'${txtfile}' '${CARET7DIR}/wb_command' '${OutputConcat}' '${VN}'"

				matlab_logging=">> ${g_path_to_study_folder}/${g_subject}.ssConcat.matlab.log 2>&1"

				matlab_cmd="${matlab_exe} ${matlab_compiler_runtime} ${matlab_function_arguments} ${matlab_logging}"

				log_Msg "Run Matlab command: ${matlab_cmd}"

				echo "${matlab_cmd}" | bash
				log_Msg "MATLAB command return code: $?"
				;;

			1)
				# Use interpreted MATLAB
				mPath="${HCPPIPEDIR}/MSMAll/scripts"

				matlab -nojvm -nodisplay -nosplash <<M_PROG
addpath '$mPath'; ssConcat('${txtfile}','${CARET7DIR}/wb_command','${OutputConcat}','${VN}');
M_PROG

				log_Msg "addpath '$mPath'; ssConcat('${txtfile}','${CARET7DIR}/wb_command','${OutputConcat}','${VN}');"
				;;

			*)
				log_Err_Abort "Unsupported MATLAB run mode value: ${g_matlab_run_mode}"
				exit 1
		esac

		log_Msg "Removing ${txtfile} used as input to ssConcat"
		rm ${txtfile}
	fi

}

# ------------------------------------------------------------------------------
#  Invoke the main function to get things started
# ------------------------------------------------------------------------------

main "$@"
