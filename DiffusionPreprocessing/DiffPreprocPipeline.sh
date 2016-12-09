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

Perform the steps of the HCP Diffusion Preprocessing Pipeline

Usage: ${SCRIPT_NAME} PARAMETER...

PARAMETERs are: [ ] = optional; < > = user supplied value
  [--help]                show usage information and exit with a non-zero return
                          code
  [--version]             show version information and exit with 0 as return code
  --path=<study-path>     path to subject's data folder
  --subject=<subject-id>  subject ID
  --PEdir=<phase-encoding-dir>
                          phase encoding direction specifier: 1=LR/RL, 2=AP/PA
  --posData=<positive-phase-encoding-data>
                          @ symbol separated list of data with positive phase 
                          encoding direction (e.g. dataRL1@dataRL2@...dataRLn)
  --negData=<negative-phase-encoding-data>
                          @ symbol separated list of data with negative phase
                          encoding direction (e.g. dataLR1@dataLR2@...dataLRn)
  --echospacing=<echo-spacing>
                          Echo spacing in msecs
  --gdcoeffs=<path-to-gradients-coefficients-file>
                          path to file containing coefficients that describe
                          spatial variations of the scanner gradients.
                          Use --gdcoeffs=NONE if not available
  [--dwiname=<DWIName>]   name to give DWI output directories.
                          Defaults to Diffusion
  [--dof=<Degrees of Freedom>]
                          Degrees of Freedom for post eddy registration to 
                          structural images. Defaults to ${DEFAULT_DEGREES_OF_FREEDOM}
  [--b0maxbval=<b0-max-bval>]
                          Volumes with a bvalue smaller than this value will be 
                          considered as b0s. Defaults to ${DEFAULT_B0_MAX_BVAL}
  [--printcom=<print-command>]
                          Use the specified <print-command> to echo or otherwise
                          output the commands that would be executed instead of
                          actually running them. --printcom=echo is intended to 
                          be used for testing purposes
  [--extra-eddy-args=<value>]
                          Generic string of arguments to be passed to the 
                          DiffPreprocPipeline_Eddy.sh script and and subsequently
                          to the run_eddy.sh script and finally to the command 
                          that actually invokes the eddy binary
  [--combine-data-flag=<value>]
                          Specified value is passed as the CombineDataFlag value
                          for the eddy_postproc.sh script.
                          If JAC resampling has been used in eddy, this value 
                          determines what to do with the output file.
                          2 - include in the output all volumes uncombined (i.e.
                              output file of eddy)
                          1 - include in the output and combine only volumes 
                              where both LR/RL (or AP/PA) pairs have been 
                              acquired
                          0 - As 1, but also include uncombined single volumes
                          Defaults to 1

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
#  ${StudyFolder}         Path to subject's data folder
#  ${Subject}             Subject ID
#  ${PEdir}               Phase Encoding Direction, 1=LR/RL, 2=AP/PA
#  ${PosInputImages}	  @ symbol separated list of data with positive phase 
#                         encoding direction
#  ${NegInputImages}      @ symbol separated lsit of data with negative phase
#                         encoding direction
#  ${echospacing}         Echo spacing in msecs
#  ${GdCoeffs}			  Path to file containing coefficients that describe 
#                         spatial variations of the scanner gradients. NONE 
#                         if not available.
#  ${DWIName}             Name to give DWI output directories
#  ${DegreesOfFreedom}    Degrees of Freedom for post eddy registration to 
#                         structural images
#  ${b0maxbval}           Volumes with a bvalue smaller than this value will 
#                         be considered as b0s
#  ${runcmd}              Set to a user specifed command to use if user has 
#                         requested that commands be echo'd (or printed)
#                         instead of actually executed. Otherwise, set to
#						  empty string.
#  ${extra_eddy_args}     Generic string of arguments to be passed to the 
#                         eddy binary
#  ${CombineDataFlag}     CombineDataFlag value to pass to 
#                         DiffPreprocPipeline_PostEddy.sh script and 
#                         subsequently to eddy_postproc.sh script
#
get_options()
{
	local arguments=($@)
	
	# initialize global output variables
	unset StudyFolder
	unset Subject
	unset PEdir
	unset PosInputImages
	unset NegInputImages
	unset echospacing
	unset GdCoeffs
	DWIName="Diffusion"
	DegreesOfFreedom=${DEFAULT_DEGREES_OF_FREEDOM}
	b0maxbval=${DEFAULT_B0_MAX_BVAL}
	runcmd=""
	extra_eddy_args=""
	CombineDataFlag=1

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
			--PEdir=*)
				PEdir=${argument#*=}
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
			--echospacing=*)
				echospacing=${argument#*=}
				index=$(( index + 1 ))
				;;
			--gdcoeffs=*)
				GdCoeffs=${argument#*=}
				index=$(( index + 1 ))
				;;
			--dwiname=*)
				DWIName=${argument#*=}
				index=$(( index + 1 ))
				;;
			--dof=*)
				DegreesOfFreedom=${argument#*=}
				index=$(( index + 1 ))
				;;
			--b0maxbval=*)
				b0maxbval=${argument#*=}
				index=$(( index + 1 ))
				;;
			--printcom=*)
				runcmd=${argument#*=}
				index=$(( index + 1 ))
				;;
			--extra-eddy-arg=*)
				extra_eddy_arg=${argument#*=}
				extra_eddy_args+=" ${extra_eddy_arg} "
				index=$(( index + 1 ))
				;;
			--combine-data-flag=*)
				CombineDataFlag=${argument#*=}
				index=$(( index + 1 ))
				;;
			*)
				usage
				echo "ERROR: Unrecognized Option: ${argument}"
				exit 1
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
	
	if [ -z ${PEdir} ] ; then
		error_msgs+="\nERROR: <phase-encoding-dir> not specified"
	fi
	
	if [ -z ${PosInputImages} ] ; then
		error_msgs+="\nERROR: <positive-phase-encoded-data> not specified"
	fi
	
	if [ -z ${NegInputImages} ] ; then
		error_msgs+="\nERROR: <negative-phase-encoded-data> not specified"
	fi
	
	if [ -z ${echospacing} ] ; then
		error_msgs+="\nERROR: <echo-spacing> not specified"
	fi
	
	if [ -z ${GdCoeffs} ] ; then
		error_msgs+="\nERROR: <path-to-gradients-coefficients-file> not specified"
	fi
	
	if [ -z ${b0maxbval} ] ; then
		error_msgs+="\nERROR: <b0-max-bval> not specified"
	fi
	
	if [ -z ${DWIName} ] ; then
		error_msgs+="\nERROR: <DWIName> not specified"
	fi

	if [ -z ${CombineDataFlag} ] ; then
		error_msgs+="\nERROR: CombineDataFlag not specified"
	fi

	if [ ! -z "${error_msgs}" ] ; then
		usage
		echo -e ${error_msgs}
		echo ""
		exit 1
	fi
	
	# report parameters
	echo "-- ${SCRIPT_NAME}: Specified Command-Line Parameters - Start --"
	echo "   StudyFolder: ${StudyFolder}"
	echo "   Subject: ${Subject}"
	echo "   PEdir: ${PEdir}"
	echo "   PosInputImages: ${PosInputImages}"
	echo "   NegInputImages: ${NegInputImages}"
	echo "   echospacing: ${echospacing}"
	echo "   GdCoeffs: ${GdCoeffs}"
	echo "   DWIName: ${DWIName}"
	echo "   DegreesOfFreedom: ${DegreesOfFreedom}"
	echo "   b0maxbval: ${b0maxbval}"
	echo "   runcmd: ${runcmd}"
	echo "   CombineDataFlag: ${CombineDataFlag}"
	echo "   extra_eddy_args: ${extra_eddy_args}"
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
	
	if [ ! -e ${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline_PreEddy.sh ] ; then
		error_msgs+="\nERROR: HCPPIPEDIR/DiffusionPreprocessing/DiffPreprocPipeline_PreEddy.sh not found"
	fi
	
	if [ ! -e ${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline_Eddy.sh ] ; then
		error_msgs+="\nERROR: HCPPIPEDIR/DiffusionPreprocessing/DiffPreprocPipeline_Eddy.sh not found"
	fi
	
	if [ ! -e ${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline_PostEddy.sh ] ; then
		error_msgs+="\nERROR: HCPPIPEDIR/DiffusionPreprocessing/DiffPreprocPipeline_PostEddy.sh not found"
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
# Function Description
#  Main processing of script
#
main()
{
	# Get Command Line Options
	get_options $@
	
	# Validate environment variables
	validate_environment_vars $@
	
	# Establish tool name for logging
	log_SetToolName "${SCRIPT_NAME}"
	
	log_Msg "Invoking Pre-Eddy Steps"
	local pre_eddy_cmd=""
	pre_eddy_cmd+="${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline_PreEddy.sh "
	pre_eddy_cmd+=" --path=${StudyFolder} "
	pre_eddy_cmd+=" --subject=${Subject} "
	pre_eddy_cmd+=" --dwiname=${DWIName} "
	pre_eddy_cmd+=" --PEdir=${PEdir} "
	pre_eddy_cmd+=" --posData=${PosInputImages} "
	pre_eddy_cmd+=" --negData=${NegInputImages} "
	pre_eddy_cmd+=" --echospacing=${echospacing} "
	pre_eddy_cmd+=" --b0maxbval=${b0maxbval} "
	pre_eddy_cmd+=" --printcom=${runcmd} "

	log_Msg "pre_eddy_cmd: ${pre_eddy_cmd}"
	${pre_eddy_cmd}

	log_Msg "Invoking Eddy Step"
	local eddy_cmd=""
	eddy_cmd+="${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline_Eddy.sh "
	eddy_cmd+=" --path=${StudyFolder} "
	eddy_cmd+=" --subject=${Subject} "
	eddy_cmd+=" --dwiname=${DWIName} "
	eddy_cmd+=" --printcom=${runcmd} "
   
	if [ -z "${extra_eddy_args}" ] ; then
		for extra_eddy_arg in ${extra_eddy_args} ; do
			eddy_cmd+=" --extra-eddy-arg=${extra_eddy_arg} "
		done
	fi

	log_Msg "eddy_cmd: ${eddy_cmd}"
	${eddy_cmd}

	log_Msg "Invoking Post-Eddy Steps"
	local post_eddy_cmd=""
	post_eddy_cmd+="${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline_PostEddy.sh "
	post_eddy_cmd+=" --path=${StudyFolder} "
	post_eddy_cmd+=" --subject=${Subject} "
	post_eddy_cmd+=" --dwiname=${DWIName} "
	post_eddy_cmd+=" --gdcoeffs=${GdCoeffs} "
	post_eddy_cmd+=" --dof=${DegreesOfFreedom} "
	post_eddy_cmd+=" --combine-data-flag=${CombineDataFlag} "
	post_eddy_cmd+=" --printcom=${runcmd} "

	log_Msg "post_eddy_cmd: ${post_eddy_cmd}"
	${post_eddy_cmd}
	
	log_Msg "Completed"
	exit 0
}

#
# Invoke the main function to get things started
#
main $@

