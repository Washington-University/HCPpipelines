#!/bin/bash

#~ND~FORMAT~MARKDOWN
#~ND~START~
#
# # SingleSubjectConcat.sh
#
# ## Copyright Notice
#
# Copyright (C) 2015 The Human Connectome Project
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
# * OCTAVE_HOME
# 
#   The home directory for the Octave installation - only needed if Octave option 
#   is used for running Matlab code.
#
#
# <!-- References -->
# [HCP]: http://www.humanconnectome.org
#
#~ND~END~

# ------------------------------------------------------------------------------
#  Code Start
# ------------------------------------------------------------------------------
g_script_name=`basename ${0}`

# ------------------------------------------------------------------------------
#  Load function libraries
# ------------------------------------------------------------------------------

source ${HCPPIPEDIR}/global/scripts/log.shlib # Logging related functions
log_SetToolName "${g_script_name}"

MATLAB_HOME="/export/matlab/R2013a"
log_Msg "MATLAB_HOME: ${MATLAB_HOME}"

#
# Function Description:
#  TBW
#
usage()
{
	echo ""
	echo "  SingleSubjectConcat.sh"
	echo ""
	echo " usage TBW"
	echo ""
}

#
# Function Description:
#  Get the command line options for this script
#  Shows usage information and exits if command line is malformed
#
# Global Output Variables
#  ${g_path_to_study_folder} - path to folder containing subject data directories
#  ${g_subject}
#  ${g_fmri_names_list}
#  ${g_output_fmri_name}
#  ${g_fmri_proc_string}
#  ${g_migp_vars}
#  ${g_output_proc_string}
#  ${g_matlab_run_mode}
#    0 - Use compiled Matlab
#    1 - Use Matlab
#    2 - Use Octave
#
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
		echo "ERROR: subject ID required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_subject: ${g_subject}"
	fi

	if [ -z "${g_fmri_names_list}" ]; then
		echo "ERROR: fMRI name list required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_fmri_names_list: ${g_fmri_names_list}"
	fi

	if [ -z "${g_output_fmri_name}" ]; then
		echo "ERROR: output fMRI name required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_output_fmri_name: ${g_output_fmri_name}"
	fi

	if [ -z "${g_fmri_proc_string}" ]; then
		echo "ERROR: fMRI proc string required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_fmri_proc_string: ${g_fmri_proc_string}"
	fi

	if [ -z "${g_migp_vars}" ]; then
		echo "ERROR: MIGP vars required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_migp_vars: ${g_migp_vars}"
	fi

	if [ -z "${g_output_proc_string}" ]; then
		echo "ERROR: output proc string required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_output_proc_string: ${g_output_proc_string}"
	fi

	if [ -z "${g_matlab_run_mode}" ]; then
		echo "ERROR: matlab run mode value (--matlab-run_mode=) required"
		error_count=$(( error_count + 1 ))
	else
		case ${g_matlab_run_mode} in
			0)
				;;
			1)
				;;
			2)
				;;
			*)
				echo "ERROR: matlab run mode value must be 0, 1, or 2"
				error_count=$(( error_count + 1 ))
				;;
		esac
	fi

	if [ ${error_count} -gt 0 ]; then
		echo "For usage information, use --help"
		exit 1
	fi
}

#
# Function Description:
#  Main processing of script.
#
main()
{
	# Get command line options
	# See documentation for get_options function for global variables set
	get_options $@

	g_fmri_names_list=`echo ${g_fmri_names_list} | sed 's/@/ /g'`
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

	if [[ ! -e ${OutputConcat} || `echo ${g_migp_var} | cut -d "@" -f 4` = "YES" ]]; then

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

		VN=`echo ${g_migp_vars} | cut -d "@" -f 5`
		log_Msg "VN: ${VN}"

		mPath="${HCPPIPEDIR}/MSMAll/scripts"
		log_Msg "mPath: ${mPath}"

		# run matlab ssConcat function 
		case ${g_matlab_run_mode} in
			0)
				# Use Compiled Matlab
				matlab_exe="${HCPPIPEDIR}"
				matlab_exe+="/MSMAll/scripts/Compiled_ssConcat/distrib/run_ssConcat.sh"
				
				matlab_compiler_runtime="${MATLAB_HOME}/MCR"

				matlab_function_arguments="'${txtfile}' '${CARET7DIR}/wb_command' '${OutputConcat}' '${VN}'"
			
				matlab_logging=">> ${g_path_to_study_folder}/${g_subject}.ssConcat.matlab.log 2>&1"

				matlab_cmd="${matlab_exe} ${matlab_compiler_runtime} ${matlab_function_arguments} ${matlab_logging}"

				# --------------------------------------------------------------------------------
				log_Msg "Run Matlab command: ${matlab_cmd}"
				# --------------------------------------------------------------------------------

				echo "${matlab_cmd}" | bash
				echo $?

				;;

			1)
				# Use Matlab - Untested
				matlab_script_file_name=${ResultsFolder}/ssConcat.m
				log_Msg "Creating Matlab script: ${matlab_script_file_name}"

				if [ -e ${matlab_script_file_name} ]; then
					echo "Removing old ${matlab_script_file_name}"
					rm -f ${matlab_script_file_name}
				fi

				touch ${matlab_script_file_name}
				echo "addpath ${mPath}" >> ${matlab_script_file_name}
				echo "ssConcat('${txtfile}', '${CARET7DIR}/wb_command', '${OutputConcat}', '${VN}');" >> ${matlab_script_file_name}

				log_Msg "About to execute the following Matlab script"

				cat ${matlab_script_file_name}
				cat ${matlab_script_file_name} | matlab -nojvm -nodisplay -nosplash

				;;

			2) 
				# Use Octave - Untested
				octave_script_file_name=${ResultsFolder}/ssConcat.m
				log_Msg "Creating Octave script: ${octave_script_file_name}"

				if [ -e ${octave_script_file_name} ]; then
					echo "Removing old ${octave_script_file_name}"
					rm -f ${octave_script_file_name}
				fi

				touch ${octave_script_file_name}
				echo "addpath ${mPath}" >> ${octave_script_file_name}
				echo "ssConcat('${txtfile}', '${CARET7DIR}/wb_command', '${OutputConcat}', '${VN}');" >> ${octave_script_file_name}

				log_Msg "About to execute the following Octave script"

				cat ${octave_script_file_name}
				cat ${octave_script_file_name} | ${OCTAVE_HOME}/bin/octave

				;;

			*)
				log_Msg "ERROR: Unrecognized Matlab run mode value: ${g_matlab_run_mode}"
				exit 1
		esac

		log_Msg "Removing ${txtfile} used as input to ssConcat"
		rm ${txtfile}
	fi

}

# 
# Invoke the main function to get things started
#
main $@
