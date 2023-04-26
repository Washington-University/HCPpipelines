#!/bin/bash
#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # DiffPreprocPipeline_PreEddy.sh
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
# [Human Connectome Project][HCP] (HCP) Pipeline Tools
#
# ## License
#
# See the [LICENSE](https://github.com/Washington-University/Pipelines/blob/master/LICENSE.md) file
#
# ## Description
#
# This script, <code>DiffPreprocPipeline_PreEddy.sh</code>, implements the first part of the
# Preprocessing Pipeline for diffusion MRI describe in [Glasser et al. 2013][GlasserEtAl].
# The entire Preprocessing Pipeline for diffusion MRI is split into pre-eddy, eddy,
# and post-eddy scripts so that the running of eddy processing can be submitted
# to a cluster scheduler to take advantage of running on a set of GPUs without forcing
# the entire diffusion preprocessing to occur on a GPU enabled system.  This particular
# script implements the pre-eddy part of the diffusion preprocessing.
#
# ## Prerequisite Installed Software for the Diffusion Preprocessing Pipeline
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
# See output of usage function: e.g. <code>$ ./DiffPreprocPipeline_PreEddy.sh --help</code>
#
# <!-- References -->
#
# [HCP]: http://www.humanconnectome.org
# [GlasserEtAl]: http://www.ncbi.nlm.nih.gov/pubmed/23668970
# [FSL]: http://fsl.fmrib.ox.ac.uk
# [FreeSurfer]: http://freesurfer.net
# [gradunwarp]: https://github.com/ksubramz/gradunwarp.git
#
#~ND~END~

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

show_usage() {
	cat <<EOF

Perform the Pre-Eddy steps of the HCP Diffusion Preprocessing Pipeline

Usage: ${g_script_name} PARAMETER...

PARAMETERs are: [ ] = optional; < > = user supplied value
  [--help]                show usage information and exit with non-zero return code
  [--version]             show version information and exit with 0 as return code
  --path=<study-path>     path to subject's data folder
  --subject=<subject-id>  subject ID
  --PEdir=<phase-encoding-dir>
                          phase encoding direction specifier: 1=RL/LR, 2=PA/AP
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
                          Effective Echo Spacing in msecs
  --topup-config-file=<filename>
                          File containing the FSL topup configuration.
  [--dwiname=<DWIname>]   name to give DWI output directories.
                          Defaults to Diffusion
  [--b0maxbval=<b0-max-bval>]
                          Volumes with a bvalue smaller than this value will be
                          considered as b0s. Defaults to ${DEFAULT_B0_MAX_BVAL}
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
  HCPPIPEDIR_Config       Location of global configuration files

EOF
}

#
# Function Description
#  Get the command line options for this script
#
# Global Output Variables
#  ${StudyFolder}         Path to subject's data folder
#  ${Subject}             Subject ID
#  ${PEdir}	              Phase Encoding Direction, 1=RL/LR, 2=PA/AP
#  ${PosInputImages}      @ symbol separated list of data with 'positive' phase
#                         encoding direction
#  ${NegInputImages}      @ symbol separated lsit of data with 'negative' phase
#                         encoding direction
#  ${echospacing}         Echo spacing in msecs
#  ${DWIName}             Name to give DWI output directories
#  ${TopupConfig}         Filename with topup configuration
#  ${b0maxbval}           Volumes with a bvalue smaller than this value will
#                         be considered as b0s
#  ${SelectBestB0}        If "true" will select the least distorted B0 for topup
#  ${EnsureEvenSlices}    If "true" will ensure input images to topup/eddy have
#                         even number of slices
#  ${runcmd}              Set to a user specified command to use if user has
#                         requested that commands be echo'd (or printed)
#                         instead of actually executed. Otherwise, set to
#                         empty string.
#

# --------------------------------------------------------------------------------
#  Support Functions
# --------------------------------------------------------------------------------

isodd() {
	echo "$(($1 % 2))"
}

get_options() {
	local arguments=($@)

	# initialize global output variables
	unset StudyFolder
	unset Subject
	unset PEdir
	unset PosInputImages
	unset NegInputImages
	unset echospacing
	unset SelectBestB0
	unset TopupConfig
	DWIName="Diffusion"
	b0maxbval=${DEFAULT_B0_MAX_BVAL}
	runcmd=""
	SelectBestB0="false"
	EnsureEvenSlices="false"

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
		--dwiname=*)
			DWIName=${argument#*=}
			index=$((index + 1))
			;;
		--echospacing=*)
			echospacing=${argument#*=}
			index=$((index + 1))
			;;
		--b0maxbval=*)
			b0maxbval=${argument#*=}
			index=$((index + 1))
			;;
		--topup-config-file=*)
			TopupConfig=${argument#*=}
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

	if [ -z ${b0maxbval} ]; then
		error_msgs+="\nERROR: <b0-max-bval> not specified"
	fi

	if [ -z ${DWIName} ]; then
		error_msgs+="\nERROR: <DWIName> not specified"
	fi

	if [ -z ${TopupConfig} ]; then
		error_msgs+="\nERROR: <TopupConfig> not specified"
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
	echo "   DWIName: ${DWIName}"
	echo "   b0maxbval: ${b0maxbval}"
	echo "   runcmd: ${runcmd}"
	echo "   SelectBestB0: ${SelectBestB0}"
	echo "-- ${g_script_name}: Specified Command-Line Parameters - End --"
}

#
# Function Description
#  Validate necessary scripts exist
#
validate_scripts() {
	local error_msgs=""

	for extension in norm_intensity sequence best_b0; do
		if [ ! -e ${HCPPIPEDIR_dMRI}/basic_preproc_${extension}.sh ]; then
			error_msgs+="\nERROR: ${HCPPIPEDIR_dMRI}/basic_preproc_${extension}.sh not found"
		fi
	done

	if [ ! -e ${HCPPIPEDIR_dMRI}/run_topup.sh ]; then
		error_msgs+="\nERROR: ${HCPPIPEDIR_dMRI}/run_topup.sh not found"
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
#  find the minimum of two specified numbers
#
min() {
	if [ $1 -le $2 ]; then
		echo $1
	else
		echo $2
	fi
}

#
# Function Description
#  Main processing of script
#
#  Gets user specified command line options, runs Pre-Eddy steps of Diffusion Preprocessing
#
main() {
	# Hard-Coded variables for the pipeline
	MissingFileFlag="EMPTY" # String used in the input arguments to indicate that a complete series is missing
	b0dist=45               # Minimum distance in volumes between b0s considered for preprocessing

	# Get Command Line Options
	get_options "$@"

	# Validate scripts
	validate_scripts "$@"

	# Establish output directory paths
	outdir=${StudyFolder}/${Subject}/${DWIName}
	outdirT1w=${StudyFolder}/${Subject}/T1w/${DWIName}

	# Delete any existing output sub-directories
	if [ -d ${outdir} ]; then
		${runcmd} rm -rf ${outdir}/rawdata
		${runcmd} rm -rf ${outdir}/topup
		${runcmd} rm -rf ${outdir}/eddy
		${runcmd} rm -rf ${outdir}/data
		${runcmd} rm -rf ${outdir}/reg
	fi

	# Make sure output directories exist
	${runcmd} mkdir -p ${outdir}
	${runcmd} mkdir -p ${outdirT1w}

	log_Msg "outdir: ${outdir}"
	${runcmd} mkdir ${outdir}/rawdata
	${runcmd} mkdir ${outdir}/topup
	${runcmd} mkdir ${outdir}/eddy
	${runcmd} mkdir ${outdir}/data
	${runcmd} mkdir ${outdir}/reg

	if [[ ${PEdir} -ne 1 && ${PEdir} -ne 2 ]]; then
		log_Msg "ERROR: Invalid Phase Encoding Directory (PEdir} specified: ${PEdir}"
		exit 1
	fi

	basePos="Pos"
	baseNeg="Neg"
	log_Msg "basePos: ${basePos}"
	log_Msg "baseNeg: ${baseNeg}"

	# copy positive raw data
	log_Msg "Copying positive raw data to working directory"
	PosInputImages=$(echo ${PosInputImages} | sed 's/@/ /g')
	log_Msg "PosInputImages: ${PosInputImages}"

	Pos_count=1
	for Image in ${PosInputImages}; do
		if [[ ${Image} =~ ^.*EMPTY.*$ ]]; then
			Image=EMPTY
		fi

		if [ ${Image} = ${MissingFileFlag} ]; then
			PosVols[${Pos_count}]=0
		else
			PosVols[${Pos_count}]=$(${FSLDIR}/bin/fslval ${Image} dim4)
			absname=$(${FSLDIR}/bin/imglob ${Image})
			${runcmd} ${FSLDIR}/bin/imcp ${absname} ${outdir}/rawdata/${basePos}_${Pos_count}
			${runcmd} cp ${absname}.bval ${outdir}/rawdata/${basePos}_${Pos_count}.bval
			${runcmd} cp ${absname}.bvec ${outdir}/rawdata/${basePos}_${Pos_count}.bvec
		fi
		Pos_count=$((${Pos_count} + 1))
	done

	# copy negative raw data
	log_Msg "Copying negative raw data to working directory"
	NegInputImages=$(echo ${NegInputImages} | sed 's/@/ /g')
	log_Msg "NegInputImages: ${NegInputImages}"

	Neg_count=1
	for Image in ${NegInputImages}; do
		if [[ ${Image} =~ ^.*EMPTY.*$ ]]; then
			Image=EMPTY
		fi

		if [ ${Image} = ${MissingFileFlag} ]; then
			NegVols[${Neg_count}]=0
		else
			NegVols[${Neg_count}]=$(${FSLDIR}/bin/fslval ${Image} dim4)
			absname=$(${FSLDIR}/bin/imglob ${Image})
			${runcmd} ${FSLDIR}/bin/imcp ${absname} ${outdir}/rawdata/${baseNeg}_${Neg_count}
			${runcmd} cp ${absname}.bval ${outdir}/rawdata/${baseNeg}_${Neg_count}.bval
			${runcmd} cp ${absname}.bvec ${outdir}/rawdata/${baseNeg}_${Neg_count}.bvec
		fi
		Neg_count=$((${Neg_count} + 1))
	done

	#Compute Total_readout in secs with up to 6 decimal places
	any=$(ls ${outdir}/rawdata/${basePos}*.nii* | head -n 1)
	if [ ${PEdir} -eq 1 ]; then #RL/LR phase encoding
		dimP=$(${FSLDIR}/bin/fslval ${any} dim1)
	elif [ ${PEdir} -eq 2 ]; then #PA/AP phase encoding
		dimP=$(${FSLDIR}/bin/fslval ${any} dim2)
	fi
	dimPminus1=$(($dimP - 1))
	#Total_readout=EffectiveEchoSpacing*(ReconMatrixPE-1)
	# Factors such as in-plane acceleration, phase oversampling, phase resolution, phase field-of-view, and interpolation
	# must already be accounted for as part of the "EffectiveEchoSpacing"
	ro_time=$(echo "${echospacing} * ${dimPminus1}" | bc -l)
	ro_time=$(echo "scale=6; ${ro_time} / 1000" | bc -l) # Convert from ms to sec
	log_Msg "Total readout time is $ro_time secs"

	# verify positive and negative datasets are provided in pairs
	if [ ${Pos_count} -ne ${Neg_count} ]; then
		log_Msg "Wrong number of input datasets! Make sure that you provide pairs of input filenames."
		log_Msg "If the respective file does not exist, use EMPTY in the input arguments."
		exit 1
	fi

	# if the number of slices are odd, check that the user has a way to deal with that
	if [ "${EnsureEvenSlices}" == "false" ] && [ "${TopupConfig}" == "${HCPPIPEDIR_Config}/b02b0.cnf" ] ; then
		dimz=$(${FSLDIR}/bin/fslval ${outdir}/topup/Pos_b0 dim3)
		if [ $(isodd $dimz) -eq 1 ]; then
			log_Msg "Input images have an odd number of slices. This is incompatible with the default topup configuration file."
			log_Msg "Either supply a topup configuration file that doesn't use subsampling (e.g., FSL's 'b02b0_1.cnf') using the --topup-config-file=<file> flag (recommended)"
			log_Msg "or instruct the HCP pipelines to remove a slice using the --ensure-even-slices flag (legacy option)."
			log_Msg "Note that the legacy option is incompatible with slice-to-volume correction in FSL's eddy"
			exit 1
		fi
	fi

	# Create two files for each phase encoding direction, that for each series contain the number of
	# corresponding volumes and the number of actual volumes. The file e.g. Pos_SeriesCorrespVolNum.txt
	# will contain as many rows as non-EMPTY series. The entry M in row J indicates that volumes 0-M
	# from 'positive' series J has corresponding 'negative' polarity volumes. This file is used in basic_preproc
	# to generate topup/eddy indices and extract corresponding b0s for topup. The file e.g. Pos_SeriesVolNum.txt
	# will have as many rows as maximum series pairs (even unmatched pairs). The entry M N in row J
	# indicates that the 'positive' series J has its 0-M volumes corresponding to 'negative' series J and
	# 'positive' series J has N volumes in total. This file is used in eddy_combine.
	log_Msg "Create two files for each phase encoding direction"

	Paired_flag=0
	for ((j = 1; j < ${Pos_count}; j++)); do
		CorrVols=$(min ${NegVols[${j}]} ${PosVols[${j}]})
		${runcmd} echo ${CorrVols} ${PosVols[${j}]} >>${outdir}/eddy/Pos_SeriesVolNum.txt
		if [ ${PosVols[${j}]} -ne 0 ]; then
			${runcmd} echo ${CorrVols} >>${outdir}/rawdata/${basePos}_SeriesCorrespVolNum.txt
			if [ ${CorrVols} -ne 0 ]; then
				Paired_flag=1
			fi
		fi
	done

	for ((j = 1; j < ${Neg_count}; j++)); do
		CorrVols=$(min ${NegVols[${j}]} ${PosVols[${j}]})
		${runcmd} echo ${CorrVols} ${NegVols[${j}]} >>${outdir}/eddy/Neg_SeriesVolNum.txt
		if [ ${NegVols[${j}]} -ne 0 ]; then
			${runcmd} echo ${CorrVols} >>${outdir}/rawdata/${baseNeg}_SeriesCorrespVolNum.txt
		fi
	done

	if [ ${Paired_flag} -eq 0 ]; then
		log_Err "Wrong Input! No pairs of phase encoding directions have been found!"
		log_Err_Abort "At least one pair is needed!"
	fi

	log_Msg "Running Intensity Normalisation"
	${runcmd} ${HCPPIPEDIR_dMRI}/basic_preproc_norm_intensity.sh ${outdir} ${b0maxbval}

	if [ "${SelectBestB0}" == "true" ]; then
		log_Msg "Running basic preprocessing in preparation of topup (using least distorted b0's)"
		${runcmd} ${HCPPIPEDIR_dMRI}/basic_preproc_best_b0.sh ${outdir} ${ro_time} ${PEdir} ${b0maxbval}
	else
		log_Msg "Running basic preprocessing in preparation of topup (using uniformly interspaced b0)"
		${runcmd} ${HCPPIPEDIR_dMRI}/basic_preproc_sequence.sh ${outdir} ${ro_time} ${PEdir} ${b0dist} ${b0maxbval}
	fi

	if [ "${EnsureEvenSlices}" == "true" ]; then
		dimz=$(${FSLDIR}/bin/fslval ${outdir}/topup/Pos_b0 dim3)
		if [ $(isodd $dimz) -eq 1 ]; then
			echo "Removing one slice from data to get even number of slices"
			for filename in Pos_Neg_b0 Pos_b0 Neg_b0 ; do
				${runcmd} ${FSLDIR}/bin/fslroi ${outdir}/topup/${filename} ${outdir}/topup/${filename}_tmp 0 -1 0 -1 1 -1
				${runcmd} ${FSLDIR}/bin/imrm ${outdir}/topup/${filename}
				${runcmd} ${FSLDIR}/bin/immv ${outdir}/topup/${filename}_tmp ${outdir}/topup/${filename}
			done
			${runcmd} ${FSLDIR}/bin/fslroi ${outdir}/eddy/Pos_Neg ${outdir}/eddy/Pos_Neg_tmp 0 -1 0 -1 1 -1
			${runcmd} ${FSLDIR}/bin/imrm ${outdir}/eddy/Pos_Neg
			${runcmd} ${FSLDIR}/bin/immv ${outdir}/eddy/Pos_Neg_tmp ${outdir}/eddy/Pos_Neg
		else
			echo "Skipping slice removal, because data already has an even number of slices"
		fi
	fi

	log_Msg "Running Topup"
	${runcmd} ${HCPPIPEDIR_dMRI}/run_topup.sh ${outdir}/topup ${TopupConfig}

	log_Msg "Completed!"
	exit 0
}

# ------------------------------------------------------------------------------
#  "Global" processing - everything above here should be in a function
# ------------------------------------------------------------------------------

# Establish defaults
DEFAULT_B0_MAX_BVAL=50

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
log_Check_Env_Var HCPPIPEDIR_Config # Needed in run_topup.sh

# Set other necessary variables, contingent on HCPPIPEDIR
HCPPIPEDIR_dMRI=${HCPPIPEDIR}/DiffusionPreprocessing/scripts

#
# Invoke the 'main' function to get things started
#
main "$@"
