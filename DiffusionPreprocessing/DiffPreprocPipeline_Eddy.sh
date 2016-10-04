#!/bin/bash
#~ND~FORMAT~MARKDOWN~
#~ND~START~
# 
# # DiffPreprocPipeline_Eddy.sh
# 
# ## Copyright Notice
# 
# Copyright (C) 2012-2016 The Human Connectome Project
# 
# * Washington University in St. Louis
# * University of Minnesota
# * Oxford University
# 
# ## Author(s)
# 
# * Stamatios Sotiropoulos, FMRIB Analysis Group, Oxford University
# * Saad Jbabdi, FMRIB Analysis Group, Oxford University
# * Jesper Andersson, FMRIB Analysis Group, Oxford University
# * Matthew F. Glasser, Department of Anatomy and Neurobiology, Washington University in St. Louis
# * Timothy B. Brown, Neuroinformatics Research Group, Washington University in St. Louis
# 
# ## Product
# 
# [Human Connectome Project][HCP] (HCP) Pipelines
# 
# ## License
# 
# See the [LICENSE](https://github.com/Washington-University/Pipelines/blob/master/LICENCE.md) file
# 
# ## Description
# 
# This script, <code>DiffPreprocPipeline_Eddy.sh</code>, implements the second 
# part of the Preprocessing Pipeline for diffusion MRI describe in 
# [Glasser et al. 2013][GlasserEtAl]. The entire Preprocessing Pipeline for 
# diffusion MRI is split into pre-eddy, eddy, and post-eddy scripts so that 
# the running of eddy processing can be submitted to a cluster scheduler to 
# take advantage of running on a set of GPUs without forcing the entire diffusion
# preprocessing to occur on a GPU enabled system.  This particular script 
# implements the eddy part of the diffusion preprocessing.
# 
# ## Prerequisite Installed Software (for the entire Diffusion Preprocessing Pipeline)
# 
# * [FSL][FSL] - FMRIB's Software Library (version 5.0.6)
#
#   FSL's environment setup script must also be sourced
#
# * [FreeSurfer][FreeSurfer] (version 5.3.0-HCP)
# 
# * [HCP-gradunwarp][HCP-gradunwarp] - (HCP version 1.0.2)
# 
# ## Prerequisite Environment Variables
# 
# See output of usage function: e.g. <code>$ ./DiffPreprocPipeline_Eddy.sh --help</code>
# 
# <!-- References -->
# 
# [HCP]: http://www.humanconnectome.org
# [GlasserEtAl]: http://www.ncbi.nlm.nih.gov/pubmed/23668970
# [FSL]: http://fsl.fmrib.ox.ac.uk
# [FreeSurfer]: http://freesurfer.net
# [HCP-gradunwarp]: https://github.com/Washington-University/gradunwarp/releases
# 
#~ND~END~

# Setup this script such that if any command exits with a non-zero value, the 
# script itself exits and does not attempt any further processing.
set -e

# Load Function Libraries
source ${HCPPIPEDIR}/global/scripts/log.shlib     # log_ functions  
source ${HCPPIPEDIR}/global/scripts/version.shlib # version_ functions 

#
# Function Description
#  Show usage information for this script
#
usage()
{
	local scriptName=$(basename ${0})
	echo ""
	echo "  Perform the Eddy step of the HCP Diffusion Preprocessing Pipeline"
	echo ""
	echo "  Usage: ${scriptName} <options>"
	echo ""
	echo "  Options: [ ] = optional; < > = user supplied value"
	echo ""
	echo "    [--help] : show usage information and exit with non-zero return code"
	echo ""
	echo "    [--version] : show version information and exit with 0 as return code"
	echo ""
	echo "    [--detailed-outlier-stats=True] : produce detailed outlier statistics from eddy after each iteration"
	echo "      Note: This option has no effect if the GPU-enabled version of eddy is not used."
	echo ""
	echo "    [--replace-outliers=True] : ask eddy to replace any outliers it detects by their expectations"
	echo "      Note: This option has no effect if the GPU-enabled version of eddy is not used."
	echo ""
	echo "    [--nvoxhp=<number-of-voxel-hyperparameters>] : number of voxel hyperparameters to use"
	echo "      Note: This option has no effect if the GPU-enabled version of eddy is not used."
	echo ""
	echo "    [--sep_offs_move=True] : Stop dwi from drifting relative to b=0"
	echo "      Note: This option has no effect if the GPU-enabled version of eddy is not used."
	echo ""
	echo "    [--rms=True] : Write a root-mean-squared movement files for QA purposes"
	echo "      Note: This option has no effect if the GPU-enabled version of eddy is not used."
	echo ""
	echo "    [--ff=<ff-value>] : TBW??"
	echo "      Note: This option has no effect if the GPU-enabled version of eddy is not used."
	echo ""
	echo "    --path=<study-path>"
	echo "    : path to subject's data folder"
	echo ""
	echo "    --subject=<subject-id>"
	echo "    : Subject ID"
	echo ""
	echo "    [--dwiname=<DWIName>]"
	echo "    : name to give DWI output directories"
	echo "      defaults to Diffusion"
	echo ""
	echo "    [--printcom=<print-command>]"
	echo "    : Use the specified <print-command> to echo or otherwise output the commands"
	echo "      that would be executed instead of actually running them"
	echo "      --printcom=echo is intended for testing purposes"
	echo ""
	echo "    [--dont_peas] : pass the --dont_peas (Do NOT perform a post-eddy alignment of shells) option"
	echo "                    to eddy invocation"
	echo ""
	echo "    [--fwhm=<value>] : --fwhm value to pass to eddy"
	echo "                       If unspecified, defaults to --fwhm=0"
	echo ""
	echo "    [--resamp=<value>] : --resamp value to pass to eddy"
	echo "                         If unspecified, no --resamp option is passed to eddy"
	echo ""
	echo "    [--ol_nstd=<value>] : --ol_nstd value to pass to eddy"
	echo "                          If unspecified, no --ol_nstd option is passed to eddy"
	echo ""
	echo "    [-extra-eddy-args] : Generic string of arguments to be pased to the run_eddy.sh script"
	echo "                         and subsequently to the eddy binary used."
	echo ""
	echo "  Return code:"
	echo ""
	echo "    0 if help was not requested, all parameters were properly formed, and processing succeeded"
	echo "    Non-zero otherwise - malformed parameters, help requested or processing failure was detected"
	echo ""
	echo "  Required Environment Variables:"
	echo ""
	echo "    HCPPIPEDIR"
	echo ""
	echo "      The home directory for the version of the HCP Pipeline Tools product"
	echo "      being used."
	echo ""
	echo "      Example value: /nrgpackages/tools.release/hcp-pipeline-tools-3.0"
	echo ""
	echo "    HCPPIPEDIR_dMRI"
	echo ""
	echo "      Location of Diffusion MRI sub-scripts that are used to carry out some of the"
	echo "      steps of the Diffusion Preprocessing Pipeline"
	echo ""
	echo "      Example value: ${HCPPIPEDIR}/DiffusionPreprocessing/scripts"
	echo ""
}

#
# Function Description
#  Get the command line options for this script
#
# Global Output Variables
#
#  ${StudyFolder} 
#    Path to subject's data folder
#
#  ${Subject}
#    Subject ID
#
#  ${DetailedOutlierStats}
#    If True (and GPU-enabled eddy program is used), then ask eddy to produce detailed 
#    statistics about outliers after each iteration.
#
#  ${ReplaceOutliers}
#    If True (and GPU-enabled eddy program is used), then ask eddy to replace any 
#    outliers it detects by their expectations
#
#  ${DWIName}
#    Name to give DWI output directories
#
#  ${runcmd}
#    Set to a user specified command to use if user has requested that commands be
#    echo'd (or printed) instead of actually executed. Otherwise, set to empty string.
#
#  ${nvoxhp}
#    Number of voxel hyperparameters to use. Only used if GPU-enabled eddy program is used.
#
#  ${sep_offs_move}
#    Set to "True" if user has specified the --sep_offs_move command line option
#
#  ${rms}
#    Set to "True" if user has specified the --rms command line option
#
#  ${ff_val}
#    User specified ff value (what is ff?) (empty string if unspecified)
#
get_options()
{
	local scriptName=$(basename ${0})
	local arguments=($@)
	
	# initialize global output variables
	unset StudyFolder
	unset Subject
	DWIName="Diffusion"
	DetailedOutlierStats="False"
	ReplaceOutliers="False"
	runcmd=""
	nvoxhp=""
	sep_offs_move="False"
	rms="False"
	ff_val=""
	dont_peas=""
	fwhm_value="0"
	resamp_value=""
	unset ol_nstd_value
	unset extra_eddy_args
	
	# parse arguments
	local index=0
	local numArgs=${#arguments[@]}
	local argument
	
	while [ ${index} -lt ${numArgs} ]
	do
		argument=${arguments[index]}
		
		case ${argument} in
			--help)
				usage
				exit 1
				;;
			--version)
				version_show $@
				exit 0
				;;
			--path=*)
				StudyFolder=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--subject=*)
				Subject=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--detailed-outlier-stats=*)
				DetailedOutlierStats=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--replace-outliers=*)
				ReplaceOutliers=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--printcom=*)
				runcmd=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--dwiname=*)
				DWIName=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--nvoxhp=*)
				nvoxhp=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--sep_offs_move=*)
				sep_offs_move=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--rms=*)
				rms=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--ff=*)
				ff_val=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--dont_peas)
				dont_peas="--dont_peas"
				index=$(( index + 1 ))
				;;
			--fwhm=*)
				fwhm_value=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--resamp=*)
				resamp_value=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--ol_nstd=*)
				ol_nstd_value=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--extra-eddy-args=*)
				extra_eddy_args=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			*)
				usage
				echo "ERROR: Unrecognized Option: ${argument}"
				exit 1
				;;
		esac
	done
	
	# check required parameters
	if [ -z ${StudyFolder} ] ; then
		usage
		echo "ERROR: <study-path> not specified"
		exit 1
	fi
	
	if [ -z ${Subject} ] ; then
		usage
		echo "ERROR: <subject-id> not specified"
		exit 1
	fi
	
	if [ -z ${DWIName} ] ; then
		usage
		echo "ERROR: <DWIName> not specified"
		exit 1
	fi
	
	# report options
	echo "-- ${scriptName}: Specified Command-Line Options - Start --"
	echo "   StudyFolder: ${StudyFolder}"
	echo "   Subject: ${Subject}"
	echo "   DWIName: ${DWIName}"
	echo "   DetailedOutlierStats: ${DetailedOutlierStats}"
	echo "   ReplaceOutliers: ${ReplaceOutliers}"
	echo "   runcmd: ${runcmd}"
	echo "   nvoxhp: ${nvoxhp}"
	echo "   sep_offs_move: ${sep_offs_move}"
	echo "   rms: ${rms}"
	echo "   ff_val: ${ff_val}"
	echo "   dont_peas: ${dont_peas}"
	echo "   fwhm_value: ${fwhm_value}"
	echo "   resamp_value: ${resamp_value}"
	echo "   ol_nstd_value: ${ol_nstd_value}"
	echo "   extra_eddy_args: ${extra_eddy_args}"
	echo "-- ${scriptName}: Specified Command-Line Options - End --"
}

#
# Function Description
#  Validate necessary environment variables
#
validate_environment_vars()
{
	local scriptName=$(basename ${0})
	
	# validate
	if [ -z ${HCPPIPEDIR_dMRI} ] ; then
		usage
		echo "ERROR: HCPPIPEDIR_dMRI environment variable not set"
		exit 1
	fi
	
	if [ ! -e ${HCPPIPEDIR_dMRI}/run_eddy.sh ] ; then
		usage
		echo "ERROR: HCPPIPEDIR_dMRI/run_eddy.sh not found"
		exit 1
	fi
	
	# report
	echo "-- ${scriptName}: Environment Variables Used - Start --"
	echo "   HCPPIPEDIR_dMRI: ${HCPPIPEDIR_dMRI}"
	echo "-- ${scriptName}: Environment Variables Used - End --"
}

#
# Function Description
#  Main processing of script
#
#  Gets user specified command line options, runs Eddy step of Diffusiong Preprocessing
#
main()
{
	# Get Command Line Options
	#
	# Global Variables Set
	#  See documentation for get_options function
	get_options $@
	
	# Validate environment variables
	validate_environment_vars $@
	
	# Establish tool name for logging
	log_SetToolName "DiffPreprocPipeline_Eddy.sh"
	
	# Establish output directory paths
	outdir=${StudyFolder}/${Subject}/${DWIName}
	
	# Determine stats_option value to pass to run_eddy.sh script
	if [ "${DetailedOutlierStats}" = "True" ] ; then
		stats_option="--wss"
	else
		stats_option=""
	fi
	
	# Determine replace_outliers_option value to pass to run_eddy.sh script
	if [ "${ReplaceOutliers}" = "True" ] ; then
		replace_outliers_option="--repol"
	else
		replace_outliers_option=""
	fi
	
	# Determine nvoxhp_option value to pass to run_eddy.sh script
	if [ "${nvoxhp}" != "" ] ; then
		nvoxhp_option="--nvoxhp=${nvoxhp}"
	else
		nvoxhp_option=""
	fi
	
	# Determine sep_offs_move_option value to pass to run_eddy.sh script
	if [ "${sep_offs_move}" = "True" ] ; then
		sep_offs_move_option="--sep_offs_move"
	else
		sep_offs_move_option=""
	fi
	
	# Determine rms_option value to pass to run_eddy.sh script
	if [ "${rms}" = "True" ] ; then
		rms_option="--rms"
	else
		rms_option=""
	fi
	
	# Determine ff_option value to pass to run_eddy.sh script
	if [ "${ff_val}" != "" ] ; then
		ff_option="--ff=${ff_val}"
	else
		ff_option=""
	fi

	# Determine ol_nstd value to pass to run_eddy.sh script
	if [ -z ${ol_nstd_value} ] ; then
		ol_nstd_value_option=""
	else
		ol_nstd_value_option="--ol_nstd=${ol_nstd_value}"
	fi

	log_Msg "Running Eddy"
	
	run_eddy_cmd="${runcmd} ${HCPPIPEDIR_dMRI}/run_eddy.sh "
	run_eddy_cmd+="${stats_option} "
	run_eddy_cmd+="${replace_outliers_option} "
	run_eddy_cmd+="${nvoxhp_option} "
	run_eddy_cmd+="${sep_offs_move_option} "
	run_eddy_cmd+="${rms_option} "
	run_eddy_cmd+="${ff_option} "
	run_eddy_cmd+="${ol_nstd_value_option} "
	run_eddy_cmd+="-g "
	run_eddy_cmd+="-w ${outdir}/eddy "

	if [ ! -z "${dont_peas}" ] ; then
		run_eddy_cmd+="--dont_peas "
	fi

	run_eddy_cmd+="--fwhm=${fwhm_value}"

	if [ ! -z "${resamp_value}" ] ; then
		run_eddy_cmd+="--resamp=${resamp_value}"
	fi
	
	if [ ! -z "${extra_eddy_args}" ] ; then
		run_eddy_cmd+=" --extra-eddy-args=\"${extra_eddy_args}\" "
	fi

	log_Msg "About to issue the following command to invoke the run_eddy.sh script"
	log_Msg "${run_eddy_cmd}"
	${run_eddy_cmd}
	
	log_Msg "Completed"
	exit 0
}

#
# Invoke the main function to get things started
#
main $@
