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

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

show_usage() {
	cat <<EOF

Perform the steps of the HCP Diffusion Preprocessing Pipeline

Usage: ${g_script_name} PARAMETER...

PARAMETERs are: [ ] = optional; < > = user supplied value
  [--help]                show usage information and exit with a non-zero return code
  [--version]             show version information and exit with 0 as return code
  --path=<study-path>     path to subject's data folder
  --subject=<subject-id>  subject ID
  --PEdir=<phase-encoding-dir>
                          phase encoding direction specifier: 1=LR/RL, 2=AP/PA
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
  --echospacing=<echo-spacing>
                          Echo spacing in msecs
  --gdcoeffs=<path-to-gradients-coefficients-file>
                          path to file containing coefficients that describe
                          spatial variations of the scanner gradients.
                          Applied *after* 'eddy'.
                          Use --gdcoeffs=NONE if not available.
  [--dwiname=<DWIName>]   name to give DWI output directories.
                          Defaults to Diffusion
  [--dof=<Degrees of Freedom>]
                          Degrees of Freedom for post eddy registration to
                          structural images. Defaults to ${DEFAULT_DEGREES_OF_FREEDOM}
  [--b0maxbval=<b0-max-bval>]
                          Volumes with a bvalue smaller than this value will be
                          considered as b0s. Defaults to ${DEFAULT_B0_MAX_BVAL}
  [--topup-config-file=<filename>]
                          File containing the FSL topup configuration.
                          Defaults to b02b0.cnf in the HCP configuration
                          directory (as defined by ${HCPPIPEDIR_Config}).
  [--select-best-b0]
                          If set selects the best b0 for each phase encoding direction
                          to pass on to topup rather than the default behaviour of
                          using equally spaced b0's throughout the scan. The best b0
                          is identified as the least distorted (i.e., most similar to
                          the average b0 after registration).
  [--ensure-even-slices]
                          If set will ensure the input images to FSL's topup and eddy
                          have an even number of slices by removing one slice if necessary.
                          This behaviour used to be the default, but is now optional,
                          because discarding a slice is incompatible with using slice-to-volume correction
                          in FSL's eddy.
  [--extra-eddy-arg=<value>]
                          Generic single token (no whitespace) argument to pass
                          to the DiffPreprocPipeline_Eddy.sh script and subsequently
                          to the run_eddy.sh script and finally to the command
                          that actually invokes the eddy binary.

                          The following will work:

                            --extra-eddy-arg=--val=1

                          because "--val=1" is a single token containing no whitespace.

                          The following will not work:

                            --extra-eddy-arg="--val1=1 --val2=2"

                          because "--val1=1 --val2=2" is NOT a single token.

                          To build a multi-token series of arguments, you can
                          specify this --extra-eddy-arg= parameter several times.

                          e.g.,

                            --extra-eddy-arg=--val1=1 --extra-eddy-arg=--val2=2

                          To get an argument like "-flag value" (where there is no
                          '=' between the flag and the value) passed to the
                          eddy binary, the following sequence will work:

                            --extra-eddy-arg=-flag --extra-eddy-arg=value
  [--no-gpu]              If specified, use the non-GPU-enabled version of eddy.
                          Defaults to using the GPU-enabled version of eddy.
  [--cuda-version=X.Y]    If using the GPU-enabled version of eddy, then this
                          option can be used to specify which eddy_cuda binary
                          version to use. If specified, FSLDIR/bin/eddy_cudaX.Y
                          will be used.
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
  [--printcom=<print-command>]
                          Use the specified <print-command> to echo or otherwise
                          output the commands that would be executed instead of
                          actually running them. --printcom=echo is intended to
                          be used for testing purposes

Return Status Value:

  0                       All parameters were properly formed and processing succeeded,
                          or help requested.
  Non-zero                otherwise - malformed parameters or a processing failure was detected

Required Environment Variables:

  HCPPIPEDIR              The home directory for the version of the HCP Pipeline Scripts being used.
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
#  ${PosInputImages}      @ symbol separated list of data with 'positive' phase
#                         encoding direction
#  ${NegInputImages}      @ symbol separated lsit of data with 'negative' phase
#                         encoding direction
#  ${echospacing}         Echo spacing in msecs
#  ${GdCoeffs}            Path to file containing coefficients that describe
#                         spatial variations of the scanner gradients. NONE
#                         if not available.
#  ${DWIName}             Name to give DWI output directories
#  ${DegreesOfFreedom}    Degrees of Freedom for post eddy registration to
#                         structural images
#  ${b0maxbval}           Volumes with a bvalue smaller than this value will
#                         be considered as b0s
#  ${TopupConfig}         Filename with topup configuration
#  ${runcmd}              Set to a user specifed command to use if user has
#                         requested that commands be echo'd (or printed)
#                         instead of actually executed. Otherwise, set to
#                         empty string.
#  ${extra_eddy_args}     Generic string of arguments to be passed to the
#                         eddy binary
#  ${SelectBestB0}        true if we should preselect the least motion corrupted b0's for topup
#                         Anything else or unset means use uniformly sampled b0's
#  ${no_gpu}              true if we should use the non-GPU-enabled version of eddy
#                         Anything else or unset means use the GPU-enabled version of eddy
#  ${cuda_version}        If using the GPU-enabled version, this value _may_ be
#                         given to specify the version of the CUDA libraries in use.
#  ${CombineDataFlag}     CombineDataFlag value to pass to
#                         DiffPreprocPipeline_PostEddy.sh script and
#                         subsequently to eddy_postproc.sh script
#

# --------------------------------------------------------------------------------
#  Support Functions
# --------------------------------------------------------------------------------

get_options() {
	local arguments=($@)

	# initialize global output variables
	unset StudyFolder
	unset Subject
	unset PEdir
	unset PosInputImages
	unset NegInputImages
	unset echospacing
	unset GdCoeffs
	unset SelectBestB0
	DWIName="Diffusion"
	DegreesOfFreedom=${DEFAULT_DEGREES_OF_FREEDOM}
	b0maxbval=${DEFAULT_B0_MAX_BVAL}
	TopupConfig=${HCPPIPEDIR_Config}/b02b0.cnf
	runcmd=""
	extra_eddy_args=""
	SelectBestB0="false"
	EnsureEvenSlices="false"
	no_gpu="false"
	cuda_version=""
	CombineDataFlag=1

	# parse arguments
	local index=0
	local numArgs=${#arguments[@]}
	local argument

	while [ ${index} -lt ${numArgs} ]; do
		argument=${arguments[index]}

		case ${argument} in
		--help)
			show_usage
			exit 0
			;;
		--version)
			version_show "$@"
			exit 0
			;;
		--path=*)
			StudyFolder=${argument#*=}
			index=$((index + 1))
			;;
		--subject=*)
			Subject=${argument#*=}
			index=$((index + 1))
			;;
		--PEdir=*)
			PEdir=${argument#*=}
			index=$((index + 1))
			;;
		--posData=*)
			PosInputImages=${argument#*=}
			index=$((index + 1))
			;;
		--negData=*)
			NegInputImages=${argument#*=}
			index=$((index + 1))
			;;
		--echospacing=*)
			echospacing=${argument#*=}
			index=$((index + 1))
			;;
		--gdcoeffs=*)
			GdCoeffs=${argument#*=}
			index=$((index + 1))
			;;
		--dwiname=*)
			DWIName=${argument#*=}
			index=$((index + 1))
			;;
		--dof=*)
			DegreesOfFreedom=${argument#*=}
			index=$((index + 1))
			;;
		--b0maxbval=*)
			b0maxbval=${argument#*=}
			index=$((index + 1))
			;;
		--printcom=*)
			runcmd=${argument#*=}
			index=$((index + 1))
			;;
		--select-best-b0)
			SelectBestB0="true"
			index=$((index + 1))
			;;
		--ensure-even-slices)
			EnsureEvenSlices="true"
			index=$((index + 1))
			;;
		--topup-config-file=*)
			TopupConfig=${argument#*=}
			index=$((index + 1))
			;;
		--extra-eddy-arg=*)
			extra_eddy_arg=${argument#*=}
			extra_eddy_args+=" ${extra_eddy_arg} "
			index=$((index + 1))
			;;
		--no-gpu)
			no_gpu="true"
			index=$((index + 1))
			;;
		--cuda-version=*)
			cuda_version=${argument#*=}
			index=$((index + 1))
			;;
		--combine-data-flag=*)
			CombineDataFlag=${argument#*=}
			index=$((index + 1))
			;;
		*)
			show_usage
			echo "ERROR: Unrecognized Option: ${argument}"
			exit 1
			;;
		esac
	done

	local error_msgs=""

	# check required parameters
	if [ -z ${StudyFolder} ]; then
		error_msgs+="\nERROR: <study-path> not specified"
	fi

	if [ -z ${Subject} ]; then
		error_msgs+="\nERROR: <subject-id> not specified"
	fi

	if [ -z ${PEdir} ]; then
		error_msgs+="\nERROR: <phase-encoding-dir> not specified"
	fi

	if [ -z ${PosInputImages} ]; then
		error_msgs+="\nERROR: <positive-phase-encoded-data> not specified"
	fi

	if [ -z ${NegInputImages} ]; then
		error_msgs+="\nERROR: <negative-phase-encoded-data> not specified"
	fi

	if [ -z ${echospacing} ]; then
		error_msgs+="\nERROR: <echo-spacing> not specified"
	fi

	if [ -z ${GdCoeffs} ]; then
		error_msgs+="\nERROR: <path-to-gradients-coefficients-file> not specified"
	fi

	if [ -z ${b0maxbval} ]; then
		error_msgs+="\nERROR: <b0-max-bval> not specified"
	fi

	if [ -z ${DWIName} ]; then
		error_msgs+="\nERROR: <DWIName> not specified"
	fi

	if [ -z ${CombineDataFlag} ]; then
		error_msgs+="\nERROR: CombineDataFlag not specified"
	fi

	if [ ! -z "${error_msgs}" ]; then
		show_usage
		echo -e ${error_msgs}
		echo ""
		exit 1
	fi

	# report parameters
	echo "-- ${g_script_name}: Specified Command-Line Parameters - Start --"
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
	echo "   TopupConfig: ${TopupConfig}"
	echo "   SelectBestB0: ${SelectBestB0}"
	echo "   EnsureEvenSlices: ${EnsureEvenSlices}"
	echo "   extra_eddy_args: ${extra_eddy_args}"
	echo "   no_gpu: ${no_gpu}"
	echo "   cuda-version: ${cuda_version}"
	echo "-- ${g_script_name}: Specified Command-Line Parameters - End --"

	if [ "${SelectBestB0}" == "true" ]; then
		dont_peas_set=false
		fwhm_set=false
		if [ ! -z "${extra_eddy_args}" ]; then
			for extra_eddy_arg in ${extra_eddy_args}; do
				if [[ ${extra_eddy_arg} == "--fwhm"* ]]; then
					fwhm_set=true
				fi
				if [[ ${extra_eddy_arg} == "--dont_peas"* ]]; then
					show_usage
					log_Err "When using --select-best-b0, post-alignment of shells in eddy is required, "
					log_Err "as the first b0 could be taken from anywhere within the diffusion data and "
					log_Err "hence might not be aligned to the first diffusion-weighted image."
					log_Err_Abort "Remove either the --extra_eddy_args=--dont_peas flag or the --select-best-b0 flag"
				fi
			done
		fi
		if [ ${fwhm_set} == false ]; then
			log_Warn "Using --select-best-b0 prepends the best b0 to the start of the file passed into eddy."
			log_Warn "To ensure eddy succesfully aligns this new first b0 with the actual first volume,"
			log_Warn "we recommend to increase the FWHM for the first eddy iterations if using --select-best-b0"
			log_Warn "This can be done by setting the --extra_eddy_args=--fwhm=... flag"
		fi
	fi
}

#
# Function Description
#  Validate necessary scripts exist
#
validate_scripts() {
	local error_msgs=""

	if [ ! -e ${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline_PreEddy.sh ]; then
		error_msgs+="\nERROR: HCPPIPEDIR/DiffusionPreprocessing/DiffPreprocPipeline_PreEddy.sh not found"
	fi

	if [ ! -e ${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline_Eddy.sh ]; then
		error_msgs+="\nERROR: HCPPIPEDIR/DiffusionPreprocessing/DiffPreprocPipeline_Eddy.sh not found"
	fi

	if [ ! -e ${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline_PostEddy.sh ]; then
		error_msgs+="\nERROR: HCPPIPEDIR/DiffusionPreprocessing/DiffPreprocPipeline_PostEddy.sh not found"
	fi

	if [ ! -z "${error_msgs}" ]; then
		show_usage
		echo -e ${error_msgs}
		echo ""
		exit 1
	fi
}

#
# Function Description
#  Main processing of script
#
main() {
	# Get Command Line Options
	get_options "$@"

	# Validate scripts
	validate_scripts "$@"

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
	pre_eddy_cmd+=" --topup-config-file=${TopupConfig} "
	pre_eddy_cmd+=" --printcom=${runcmd} "
	if [ "${SelectBestB0}" == "true" ]; then
		pre_eddy_cmd+=" --select-best-b0 "
	fi
	if [ "${EnsureEvenSlices}" == "true" ]; then
		pre_eddy_cmd+=" --ensure-even-slices "
	fi

	log_Msg "pre_eddy_cmd: ${pre_eddy_cmd}"
	${pre_eddy_cmd}

	log_Msg "Invoking Eddy Step"
	local eddy_cmd=""
	eddy_cmd+="${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline_Eddy.sh "
	eddy_cmd+=" --path=${StudyFolder} "
	eddy_cmd+=" --subject=${Subject} "
	eddy_cmd+=" --dwiname=${DWIName} "
	eddy_cmd+=" --printcom=${runcmd} "

	if [ "${no_gpu}" == "true" ]; then
		# default is to use the GPU-enabled version
		eddy_cmd+=" --no-gpu "
	else
		if [ ! -z "${cuda_version}" ]; then
			eddy_cmd+=" --cuda-version=${cuda_version}"
		fi
	fi
	if [ ! -z "${extra_eddy_args}" ]; then
		for extra_eddy_arg in ${extra_eddy_args}; do
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
	if [ "${SelectBestB0}" == "true" ]; then
		post_eddy_cmd+=" --select-best-b0 "
	fi

	log_Msg "post_eddy_cmd: ${post_eddy_cmd}"
	${post_eddy_cmd}

	log_Msg "Completed!"
	exit 0
}

# ------------------------------------------------------------------------------
#  "Global" processing - everything above here should be in a function
# ------------------------------------------------------------------------------

# Establish defaults
DEFAULT_B0_MAX_BVAL=50
DEFAULT_DEGREES_OF_FREEDOM=6

# Set global variables
g_script_name=$(basename "${0}")

# Allow script to return a Usage statement, before any other output
if [ "$#" = "0" ]; then
	show_usage
	exit 1
fi

# Verify that HCPPIPEDIR Environment variable is set
if [ -z "${HCPPIPEDIR}" ]; then
	echo "${g_script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
	exit 1
fi

# Load function libraries
source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@" # Debugging functions; also sources log.shlib
source "${HCPPIPEDIR}/global/scripts/opts.shlib"         # Command line option functions
source "${HCPPIPEDIR}/global/scripts/version.shlib"      # version_ functions

opts_ShowVersionIfRequested "$@"

if opts_CheckForHelpRequest "$@"; then
	show_usage
	exit 0
fi

${HCPPIPEDIR}/show_version

# Verify required environment variables are set and log value
log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FSLDIR

#
# Invoke the 'main' function to get things started
#
main "$@"
