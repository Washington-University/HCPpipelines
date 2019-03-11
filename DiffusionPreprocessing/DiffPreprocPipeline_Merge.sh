#!/usr/bin/env bash
#!/bin/bash
#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # DiffPreprocPipeline_Merge.sh
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
# * Michiel Cottaar, FMRIB Analysis Group, Oxford University
# * Matthew F. Glasser, Department of Anatomy and Neurobiology, Washington University in St. Louis
# * Michael Harms, Department of Anatomy and Neurobiology, Washington University in St. Louis
#
# ## Product
#
# [Human Connectome Project][HCP] (HCP) Pipelines
#
# ## License
#
# See the [LICENSE](https://github.com/Washington-University/Pipelines/blob/master/LICENSE.md) file
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
# ## Prerequisite Installed Software for the entire Diffusion Preprocessing Pipeline
#
# * [FSL][FSL] - FMRIB's Software Library (version 6.0.1)
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
#
# Merges the individually processed diffusion MRI data into a single diffusion image
#

# Set up this script such that if any command exits with a non-zero value, the
# script itself exits and does not attempt any further processing.
set -e

# Load Function Libraries
source ${HCPPIPEDIR}/global/scripts/log.shlib     # log_ functions
source ${HCPPIPEDIR}/global/scripts/version.shlib # version_ functions

get_options()
{
	local arguments=($@)

	# initialize global output variables
	unset StudyFolder
	unset Subject
	unset InputNames
	unset OutputName
	unset runcmd
	OutputName="Diffusion"
	runcmd=""

	# parse arguments
	local index=0
	local numArgs=${#arguments[@]}
	local argument

	while [ ${index} -lt ${numArgs} ] ; do
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
				StudyFolder=${argument#*=}
				index=$(( index + 1 ))
				;;
			--subject=*)
				Subject=${argument#*=}
				index=$(( index + 1 ))
				;;
			--input_dwinames=*)
				InputNames=${argument#*=}
				index=$(( index + 1 ))
				;;
			--dwiname=*)
				OutputName=${argument#*=}
				index=$(( index + 1 ))
				;;
			--printcom=*)
				runcmd=${argument#*=}
				index=$(( index + 1 ))
				;;
			*)
				PassOnArguments+=" ${argument} "
				index=$(( index + 1 ))
				;;
		esac
	done

	local error_msgs=""

	# check required parameters
	if [ -z ${StudyFolder} ] ; then
		error_msgs+="\nERROR: <study-path> not specified"
	fi

	if [ -z ${Subject} ] ; then
		error_msgs+="\nERROR: <subject-id> not specified"
	fi

	if [ -z ${InputNames} ] ; then
		error_msgs+="\nERROR: <input_dwinames> not specified"
	fi

	if [ ! -z "${error_msgs}" ] ; then
		usage
		echo -e ${error_msgs}
		echo ""
		exit 1
	fi

	# report parameters
	echo "-- ${SCRIPT_NAME}: Specified Command-Line Parameters - Start --"
	echo "   Path: ${StudyFolder}"
	echo "   Subject: ${Subject}"
	echo "   InputDWINames: ${InputNames}"
	echo "   OutputDWIName: ${OutputName}"
	echo "-- ${SCRIPT_NAME}: Specified Command-Line Parameters - End --"
}

validate_environment_vars()
{
	local error_msgs=""

	# validate
	if [ -z ${HCPPIPEDIR_dMRI} ] ; then
		error_msgs+="\nERROR: HCPPIPEDIR_dMRI environment variable not set"
	fi

	if [ ! -e ${HCPPIPEDIR_dMRI}/merge_split.sh ] ; then
		error_msgs+="\nERROR: HCPPIPEDIR_dMRI/merge_split.sh not found"
	fi

	if [ -z ${FSLDIR} ] ; then
		error_msgs+="\nERROR: FSLDIR environment variable not set"
	fi

	if [ ! -z "${error_msgs}" ] ; then
		usage
		echo -e ${error_msgs}
		echo ""
		exit 1
	fi

	# report
	echo "-- ${SCRIPT_NAME}: Environment Variables Used - Start --"
	echo "   HCPPIPEDIR_dMRI: ${HCPPIPEDIR_dMRI}"
	echo "   FSLDIR: ${FSLDIR}"
	echo "-- ${SCRIPT_NAME}: Environment Variables Used - End --"
}

usage()
{
	cat << EOF

Merges the results from multiple runs of the HCP pipeline on the same subject

This is designed to handle the case where the scanner was reshimmed between the
acquisition of different diffusion MRI data pairs and hence are preprocessed
independently in their own call to DiffPreprocPipeline.sh. This merges the results.

Usage: ${SCRIPT_NAME} PARAMETER...

PARAMETERs are: [ ] = optional; < > = user supplied value
  [--help]                show usage information and exit with a non-zero return
                          code
  [--version]             show version information and exit with 0 as return code
  --path=<study-path>     path to subject's data folder
  --subject=<subject-id>  subject ID
  --input_dwinames=<input_names>    @-seperated list of the DWI output directories.
  [--dwiname=<output_name>]
                          Name of the directory containing the merged diffusion data
                          Defaults to Diffusion
  [--printcom=<print-command>]
                          Use the specified <print-command> to echo or otherwise
                          output the commands that would be executed instead of
                          actually running them. --printcom=echo is intended to
                          be used for testing purposes

Return Status Value:

  0                       if help was not requested, all parameters were properly
                          formed, and processing succeeded
  Non-zero                Otherwise - malformed parameters, help requested, or a
                          processing failure was detected

Required Environment Variables:

  HCPPIPEDIR_dMRI         Location of the Diffusion MRI Preprocessing sub-scripts
                          that are used to carry out some of the steps of the
                          Diffusion Preprocessing Pipeline.
                          (e.g. \${HCPPIPEDIR}/DiffusionPreprocessing/scripts)
  FSLDIR                  The home directory for FSL

EOF
}


main()
{
	# Get Command Line Options
	get_options $@

    validate_environment_vars

    set -e

    # Establish tool name for logging
    log_SetToolName "${SCRIPT_NAME}"

    outdir=${StudyFolder}/${Subject}/T1w/${OutputName}

    indirs=`echo ${InputNames} | sed 's/@/ /g'`
    indirs=`printf "${StudyFolder}/${Subject}/T1w/%s " ${indirs}`

    log_Msg "merging ${indirs} into ${outdir}"

    ${runcmd} ${HCPPIPEDIR_dMRI}/merge_split.sh ${outdir} ${indirs}
}


main $@
