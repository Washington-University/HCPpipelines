#!/bin/bash
#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # DiffPreprocPipeline.sh
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
# * Timothy B. Brown, Neuroinfomatics Research Group, Washington University in St. Louis
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
# This script, <code>DiffPreprocPipeline.sh</code>, implements the Diffusion 
# MRI Preprocessing Pipeline described in [Glasser et al. 2013][GlasserEtAl]. 
# It generates the "data" directory that can be used as input to the fibre 
# orientation estimation scripts.
#  
# ## Prerequisite Installed Software
# 
# * [FSL][FSL] - FMRIB's Software Library (version 5.0.11)
#
#   FSL's environment setup script must also be sourced
#
# * [FreeSurfer][FreeSurfer] (version 5.3.0-HCP)
# 
# * [HCP-gradunwarp][HCP-gradunwarp] - (HCP version 1.0.2)
#
# ## Prerequisite Environment Variables
# 
# See output of usage function: 
# e.g. <code>$ ./DiffPreprocPipeline.sh --help</code>
# 
# ## Output Directories
# 
# *NB: NO assumption is made about the input paths with respect to the output 
#      directories - they can be totally different. All inputs are taken directly
#      from the input variables without additions or modifications.*
# 
# Output path specifiers
# 
# * <code>${StudyFolder}</code> is an input parameter
# * <code>${Subject}</code> is an input parameter
# 
# Main output directories
# 
# * <code>DiffFolder=${StudyFolder}/${Subject}/Diffusion</code>
# * <code>T1wDiffFolder=${StudyFolder}/${Subject}/T1w/Diffusion</code>
# 
# All outputs are within the directory: <code>${StudyFolder}/${Subject}</code>
# 
# The full list of output directories are the following
# 
# * <code>$DiffFolder/rawdata</code>
# * <code>$DiffFolder/topup</code>
# * <code>$DiffFolder/eddy</code>
# * <code>$DiffFolder/data</code>
# * <code>$DiffFolder/reg</code>
# * <code>$T1wDiffFolder</code>
# 
# Also assumes that T1 preprocessing has been carried out with results in 
# <code>${StudyFolder}/${Subject}/T1w</code>
# 
# <!-- References -->
# 
# [HCP]: http://www.humanconnectome.org
# [GlasserEtAl]: http://www.ncbi.nlm.nih.gov/pubmed/23668970
# [FSL]: http://fsl.fmrib.ox.ac.uk
# [FreeSurfer]: http://freesurfer.net
# [HCP-gradunwarp]: https://github.com/Washington-University/gradunwarp/releases
# [license]: https://github.com/Washington-University/Pipelines/blob/master/LICENSE.md
# 
#~ND~END~

# Set up this script such that if any command exits with a non-zero value, the 
# script itself exits and does not attempt any further processing.
set -e

# Load Function Libraries
source ${HCPPIPEDIR}/global/scripts/log.shlib		# log_ functions
source ${HCPPIPEDIR}/global/scripts/version.shlib	# version_ functions

# Global values
DEFAULT_B0_MAX_BVAL=50
DEFAULT_DEGREES_OF_FREEDOM=6
SCRIPT_NAME=$(basename ${0})

#
# Function Descripton
#  Show usage information for this script
#
usage()
{
	cat << EOF

Perform the steps of the HCP Diffusion Preprocessing Pipeline separately for each shim group

The resulting files are merged into a single dataset using DiffPreprocPipeline_Merge.sh.

Usage: ${SCRIPT_NAME} PARAMETER...

PARAMETERs are: [ ] = optional; < > = user supplied value
  [--help]                show usage information and exit with a non-zero return
                          code
  [--version]             show version information and exit with 0 as return code
  --posData=<positive-phase-encoding-data>
                          @ symbol separated list of data with 'positive' phase
                          encoding direction; e.g.,
                            data_RL1@data_RL2@...data_RLn, or
                            data_PA1@data_PA2@...data_PAn
  --negData=<negative-phase-encoding-data>
                          @ symbol separated list of data with 'negative' phase 
                          encoding direction; e.g.,
                            data_LR1@data_LR2@...data_LRn, or
                            data_AP1@data_AP2@...data_APn
  --posDataShimGroup=<shim-group-for-positive-phase-encoding-data>
                          @ symbol separated list of the shim groups that
                          each dataset with 'positive' phase encoding
                          belongs to; e.g.,
                            A@A@...B@C
                          Note that the shim groups can have any non-empty name
  --negDataShimGroup=<shim-group-for-negative-phase-encoding-data>
                          @ symbol separated list of the shim groups that
                          each dataset with 'negative' phase encoding
                          belongs to; e.g.,
                            A@A@...B@C
                          Note that the shim groups can have any non-empty name
  [--dwiname=<DWIName>]   basename to give DWI output directories.
                          will be appended with "_scanA", "_scanB", etc.
                          Defaults to Diffusion

  All other parameters are passed on to DiffPreprocPipeline.sh without alteration
  Run DiffPreprocPipeline.sh for more details on these flags

Return Status Value:

  0                       if help was not requested, all parameters were properly
                          formed, and processing succeeded
  Non-zero                Otherwise - malformed parameters, help requested, or a 
                          processing failure was detected

Required Environment Variables:

  HCPPIPEDIR              The home directory for the version of the HCP Pipeline 
                          Scripts being used.
  HCPPIPEDIR_dMRI         Location of the Diffusion MRI Preprocessing sub-scripts
                          that are used to carry out some of the steps of the
                          Diffusion Preprocessing Pipeline. 
                          (e.g. \${HCPPIPEDIR}/DiffusionPreprocessing/scripts)
  FSLDIR                  The home directory for FSL
  FREESURFER_HOME         The home directory for FreeSurfer
  PATH                    Standard PATH environment variable must be set to find
                          HCP-customized version of gradient_unwarp.py

EOF
}

#
# Function Description
#  Get the command line options for this script
#
# Global Output Variables
#  ${PosInputImages}	  @ symbol separated list of data with 'positive' phase
#                         encoding direction
#  ${NegInputImages}      @ symbol separated lsit of data with 'negative' phase
#                         encoding direction
#  ${DWIName}             Basename to give DWI output directories
#
get_options()
{
	local arguments=($@)
	
	# initialize global output variables
	unset PosInputImages
	unset NegInputImages
	unset PassOnArguments
	unset StudyFolder
	unset Subject
	DWIName="Diffusion"
	PassOnArguments=""

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
			--posData=*)
				PosInputImages=${argument#*=}
				index=$(( index + 1 ))
				;;
			--negData=*)
				NegInputImages=${argument#*=}
				index=$(( index + 1 ))
				;;
			--dwiname=*)
				DWIName=${argument#*=}
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
	if [ -z ${PosInputImages} ] ; then
		error_msgs+="\nERROR: <positive-phase-encoded-data> not specified"
	fi
	
	if [ -z ${NegInputImages} ] ; then
		error_msgs+="\nERROR: <negative-phase-encoded-data> not specified"
	fi

	if [ -z ${StudyFolder} ] ; then
		error_msgs+="\nERROR: <study-path> not specified"
	fi

	if [ -z ${Subject} ] ; then
		error_msgs+="\nERROR: <subject-id> not specified"
	fi

	if [ ! -z "${error_msgs}" ] ; then
		usage
		echo -e ${error_msgs}
		echo ""
		exit 1
	fi
	
	# report parameters
	echo "-- ${SCRIPT_NAME}: Specified Command-Line Parameters - Start --"
	echo "   PosInputImages: ${PosInputImages}"
	echo "   NegInputImages: ${NegInputImages}"
	echo "   DWIName: ${DWIName}"
	echo "   Arguments for DiffPreprocPipeline.sh: ${PassOnArguments}"
	echo "-- ${SCRIPT_NAME}: Specified Command-Line Parameters - End --"
}

# 
# Function Description
#  Validate necessary environment variables
#
validate_environment_vars()
{
	local error_msgs=""

	# validate
	if [ -z ${HCPPIPEDIR_dMRI} ] ; then
		error_msgs+="\nERROR: HCPPIPEDIR_dMRI environment variable not set"
	fi

	if [ ! -e ${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline.sh ] ; then
		error_msgs+="\nERROR: HCPPIPEDIR/DiffusionPreprocessing/DiffPreprocPipeline.sh not found"
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

#
# Function description
#  Main processing of script if --split is set
#
main()
{
	# Get Command Line Options
	get_options $@

	# Validate environment variables
	validate_environment_vars $@

	# Establish tool name for logging
	log_SetToolName "${SCRIPT_NAME}"


    input_dwinames=""
    for Label_text in `python ${HCPPIPEDIR_dMRI}/scripts/split_shimgroups.py ${PosInputImages} ${PosShimLabels} ${NegInputImages} ${NegShimLabels}` ; do
        ShimLabel=$(echo ${Label_text} | cut -f1 -d" ")
        ShimPosInputImages=$(echo ${Label_text} | cut -f2 -d" ")
        ShimNegInputImages=$(echo ${Label_text} | cut -f3 -d" ")

		ShimDWIName=${DWIName}_${ImageIndex}

		preproc_pipeline_cmd="${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline.sh "
		preproc_pipeline_cmd+=" --posData=${ShimPosInputImages} "
		preproc_pipeline_cmd+=" --negData=${ShimNegInputImages} "
		preproc_pipeline_cmd+=" --dwiname=${ShimDWIName} "
		preproc_pipeline_cmd+=" --path=${StudyFolder} "
		preproc_pipeline_cmd+=" --subject=${Subject} "
		preproc_pipeline_cmd+=" ${PassOnArguments}"

        input_dwinames=${input_dwinames}@${ShimDWIName}
		log_Msg "Invoking Preprocessing pipeline for data in shim group ${ShimLabel}"
		echo ${preproc_pipeline_cmd}
	done

    # get rid of the leading @
    input_dwinames=${input_dwinames:1}

    merge_cmd="${HCPPIPEDIR}/DiffusionPreprocessing_Merge.sh "
    merge_cmd+=" --path=${StudyFolder} "
    merge_cmd+=" --subject=${Subject} "
    merge_cmd+=" --dwiname=${DWIName} "
    merge_cmd+=" --input_dwiname=${input_dwinames} "
	log_Msg "Merging all the shim groups"
	${merge_cmd}
	log_Msg "Completed all the shim groups"
	exit 0
}

#
# Invoke the main function to get things started
#
main $@

