#!/bin/bash

#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # MSMAllPipeline.sh
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
# This is the main script for the MSM Registration pipeline. Once this registration is run
# on all subjects in a group, the Group Registration Drift can be computed.
#
# ## Prerequisites
#
# ### Previous Processing
#
# The necessary input files for this processing come from:
#
# * TBW
# * The Resting State Stats pipeline
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
#
#
#
#
# <!-- References -->
# [HCP]: http://www.humanconnectome.org
#
#~ND~END~

# ------------------------------------------------------------------------------
#  Code Start
# ------------------------------------------------------------------------------

# If any commands exit with non-zero value, this script exits
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
	echo "  MSM-All Registration"
	echo ""
	echo "  Usage: ${g_script_name} <options>"
	echo ""
	echo "  Options: [ ] = optional; < > = user supplied value"
	echo ""
	echo "   [--help] : show usage information and exit"
	echo "    --path=<path to study folder> OR --study-folder=<path to study folder>"
	echo "    --subject=<subject ID>"
	echo "    --fmri-names-list=<fMRI names> an @ symbol separated list of fMRI scan names"




	echo ""
}

#
# Function Description:
#  Get the command line options for this script.
#  Shows usage information and exits if command line is malformed
#
# Global Output Variables
#  ${g_path_to_study_folder} - path to folder containing subject data directories
#  ${g_subject} - subject ID
#  ${g_fmri_names_list} - @ symbol separated list of fMRI names
#  ${g_output_fmri_name} - name to give to concatenated single subject "scan"
#  ${g_fmri_proc_string} - identification for FIX cleaned dtseries to use
#                          The dense timeseries files used will be named
#                          ${fmri_name}_${g_fmri_proc_string}.dtseries.nii
#                          where ${fmri_name} is each of the fMRIs specified in
#                          ${g_frmi_names_list}.
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

	# set default values

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
			--fmri-names-list=*)
				g_fmri_names_list=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--output-fmri-name=*)
				g_output_fmri_name=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--fmri-proc-string=*)
				g_fmri_proc_string=${argument/*=/""}
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



	if [ ${error_count} -gt 0 ]; then
		echo "For usage information, use --help"
		exit 1
	fi
}

#
# Function Description:
#  Document Tool Versions
#
show_tool_versions() 
{
	# Show HCP pipelines version
	log_Msg "Showing HCP Pipelines version"
	cat ${HCPPIPEDIR}/version.txt
}

#
# Function Description:
#  Main processing of script.
#
main()
{
	# Get command line options
	# See documentation for the get_options function for global variables set
	get_options $@

	# show the versions of tools used
	show_tool_versions

	# Values of variables determining MIGP usage"
	# Form:    UseMIGP    @ PCAInitDim     @ PCAFinalDim    @ ReRunIfExists @ VarianceNormalization
	# Values:  YES or NO  @ number or NONE @ number or NONE @ YES or NO     @ YES or NO
	# 
	# Note: Spaces should not be used in the variable's value. They are used above to 
	#       help make the form and values easier to understand.
	# Note: If UseMIGP value is NO, then we use the full timeseries
	log_Msg "Running MSM on full timeseries"
	migp_vars="NO@0@0@NO@YES"
	log_Msg "migp_vars: ${migp_vars}"

	output_proc_string="_nobias_vn"
	log_Msg "output_proc_string: ${output_proc_string}"

	${HCPPIPEDIR}/MSMAll/scripts/SingleSubjectConcat.sh \
		--path=${g_path_to_study_folder} \
		--subject=${g_subject} \
		--fmri-names-list=${g_fmri_names_list} \
		--output-fmri-name=${g_output_fmri_name} \
		--fmri-proc-string=${g_fmri_proc_string} \
		--migp-vars=${migp_vars} \
		--output-proc-string=${output_proc_string}


	exit 1



}

# 
# Invoke the main function to get things started
#
main $@
