#!/bin/bash
#~ND~FORMAT~MARKDOWN~
#~ND~START~
# 
# # run_eddy.sh
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
# * Stamatios Sotiropoulos - Analysis Group, FMRIB Centre
# * Saad Jbabdi - Analysis Group, FMRIB Center
# * Jesper Andersson - Analysis Group, FMRIB Center
# * Matthew F. Glasser - Anatomy and Neurobiology, Washington University in St. Louis
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
# This script runs FSL's eddy command as part of the Human Connectome Project's
# Diffusion Preprocessing 
# 
# ## Prerequisite Installed Software
# 
# * [FSL][FSL] - FMRIB's Software Library (version 5.0.6)
# 
#   FSL's environment setup script must also be sourced
# 
# ## Prerequisite Environment Variables
# 
# See output of usage function: e.g. <code>$ ./run_eddy.sh --help</code>
# 
# <!-- References -->
# 
# [HCP]: http://www.humanconnectome.org
# [FSL]: http://fsl.fmrib.ox.ac.uk
# 
#~ND~END~

# Load Function Libraries
source ${HCPPIPEDIR}/global/scripts/log.shlib # log_ functions

#
# Function Description:
#  Show usage information for this script
#
usage()
{
	local scriptName=$(basename ${0})
	echo ""
	echo "  Usage: ${scriptName} <options>"
	echo ""
	echo "  Options: [ ] = optional; < > = user supplied value"
	echo ""
	echo "    [-h | --help] : show usage information and exit with non-zero return code"
	echo ""
	echo "    [-g | --gpu]  : use the GPU-enabled version of eddy."
	echo ""
	echo "    [--wss] : produce detailed outlier statistics after each iteration by using "
	echo "              the --wss option to a call to eddy.  Note that this option has "
	echo "              no effect unless the GPU-enabled version of eddy is used."
	echo ""
	echo "    [--repol] : replace outliers. Note that this option has no effect unless the"
	echo "                GPU-enabled version of eddy is used."
	echo ""
	echo "    [--nvoxhp=<number-of-voxel-hyperparameters>] : number of voxel hyperparameters to use"
	echo "                Note that this option has no effect unless the GPU-enabled version of"
	echo "                eddy is used."
	echo ""
	echo "    [--sep_offs_move] : If specified, this option stops dwi from drifting relative to b=0"
	echo "                Note that this option has no effect unless the GPU-enabled version of"
	echo "                eddy is used."
	echo ""
	echo "    [--rms] : If specified, write a root-mean-squared movement file for QA purposes"
	echo "                Note that this option has no effect unless the GPU-enabled version of"
	echo "                eddy is used."
	echo ""
	echo "    [--ff=<ff-value>] : TBW??"
	echo "                Note that this option has no effect unless the GPU-enabled version of"
	echo "                eddy is used."
	echo ""
	echo "    -w <working-dir>           | "
	echo "    -w=<working-dir>           | "
	echo "    --workingdir <working-dir> | "
	echo "    --workingdir=<working-dir> : the working directory (REQUIRED)"
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
	echo "                          If unspecified, no --ol_nstd option is pssed to eddy"
	echo ""
	echo "    [--extra-eddy-arg=token] : Generic single token (no whitespace) argument to pass"
	echo "                               to the eddy binary. To build a multi-token series of"
	echo "                               arguments, you can specify this --extra-eddy-arg= "
	echo "                               parameter serveral times. E.g."
	echo "                               --extra-eddy-arg=--verbose --extra-eddy-arg=T"
	echo "                               will ultimately be translated to --verbose T when"
	echo "                               passed to the eddy binary"
	echo ""
	echo "  Return code:"
	echo ""
	echo "    0 if help was not requested, all parameters were properly formed, and processing succeeded"
	echo "    Non-zero otherwise - malformed parameters, help requested or processing failure was detected"
	echo ""
	echo "  Required Environment Variables:"
	echo ""
	echo "    FSLDIR"
	echo ""
	echo "      The home directory for FSL"
	echo ""
}

#
# Function Description:
#  Get the command line options for this script.
#
# Global Ouput Variables
#  ${useGpuVersion}   - Set to "True" if user has requested an attempt to use
#                       the GPU-enabled version of eddy
#  ${workingdir}      - User specified working directory
#  ${produceDetailedOutlierStats} 
#                     - Set to "True" if user has requested that the GPU-enabled version
#                       of eddy produce detailed statistics about outliers after each iteration
#  ${replaceOutliers} - Set to "True" if user has requested that the GPU-enabled version
#                       of eddy replace any outliers it detects by their expectations
#  ${nvoxhp}          - User specified number of voxel hyperparameters (empty string if unspecified)
#  ${sep_offs_move}   - Set to "True" if user has specified the --sep_offs_move command line option
#  ${rms}             - Set to "True" if user has specified the --rms command line option
#  ${ff_val}          - User specified ff value (what is ff?) (empty string if unspecified)
#  ${ol_nstd_val}     - User specified value for ol_nstd option
#  ${extra_eddy_args} - User specified value for the --extra-eddy-args command line option
#
get_options()
{
	local scriptName=$(basename ${0})
	local arguments=($@)
	
	# global output variables
	useGpuVersion="False"
	produceDetailedOutlierStats="False"
	replaceOutliers="False"
	unset workingdir
	nvoxhp=""
	sep_offs_move="False"
	rms="False"
	ff_val=""
	dont_peas=""
	fwhm_value="0"
	resamp_value=""
	unset ol_nstd_val
	extra_eddy_args=""

	# parse arguments
	local index=0
	local numArgs=${#arguments[@]}
	local argument
	
	while [ ${index} -lt ${numArgs} ]
	do
		argument=${arguments[index]}
		
		case ${argument} in
			-h | --help)
				usage
				exit 1
				;;
			-g | --gpu)
				useGpuVersion="True"
				index=$(( index + 1 ))
				;;
			--wss)
				produceDetailedOutlierStats="True"
				index=$(( index + 1 ))
				;;
			--repol)
				replaceOutliers="True"
				index=$(( index + 1 ))
				;;
			-w | --workingdir)
				workingdir=${arguments[$(( index + 1 ))]}
				index=$(( index + 2 ))
				;;
			-w=* | --workingdir=*)
				workingdir=${argument#*=}
				index=$(( index + 1 ))
				;;
			--nvoxhp=*)
				nvoxhp=${argument#*=}
				index=$(( index + 1 ))
				;;
			--sep_offs_move)
				sep_offs_move="True"
				index=$(( index + 1 ))
				;;
			--rms)
				rms="True"
				index=$(( index + 1 ))
				;;
			--ff=*)
				ff_val=${argument#*=}
				index=$(( index + 1 ))
				;;
			--dont_peas)
				dont_peas="--dont_peas"
				index=$(( index + 1 ))
				;;
			--fwhm=*)
				fwhm_value=${argument#*=}
				index=$(( index + 1 ))
				;;
			--resamp=*)
				resamp_value=${argument#*=}
				index=$(( index + 1 ))
				;;
			--ol_nstd=*)
				ol_nstd_val=${argument#*=}
				index=$(( index + 1 ))
				;;
			--extra-eddy-arg=*)
				extra_eddy_arg=${argument#*=}
				extra_eddy_args+=" ${extra_eddy_arg} "
				index=$(( index + 1 ))
				;;
			*)
				echo "Unrecognized Option: ${argument}"
				usage
				exit 1
				;;
		esac
	done
	
	# check required parameters
	if [ -z ${workingdir} ]; then
		usage
		echo "  Error: <working-dir> not specified - Exiting without running eddy"
		exit 1
	fi
	
	# report options
	echo "-- ${scriptName}: Specified Command-Line Options - Start --"
	echo "   workingdir: ${workingdir}"
	echo "   useGpuVersion: ${useGpuVersion}"
	echo "   produceDetailedOutlierStats: ${produceDetailedOutlierStats}"
	echo "   replaceOutliers: ${replaceOutliers}"
	echo "   nvoxhp: ${nvoxhp}"
	echo "   sep_offs_move: ${sep_offs_move}"
	echo "   rms: ${rms}"
	echo "   ff_val: ${ff_val}"
	echo "   dont_peas: ${dont_peas}"
	echo "   fwhm_value: ${fwhm_value}"
	echo "   resamp_value: ${resamp_value}"
	echo "   ol_nstd_val: ${ol_nstd_val}"
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
	if [ -z ${FSLDIR} ]; then
		usage
		echo "ERROR: FSLDIR environment variable not set"
		exit 1
	fi
	
	# report
	echo "-- ${scriptName}: Environment Variables Used - Start --"
	echo "   FSLDIR: ${FSLDIR}"
	echo "-- ${scriptName}: Environment Variables Used - End --"
}

get_fsl_version()
{
	local fsl_version_file
	local fsl_version
	local __functionResultVar=${1}

	fsl_version_file="${FSLDIR}/etc/fslversion"

	if [ -f ${fsl_version_file} ]; then
		fsl_version=`cat ${fsl_version_file}`
		log_Msg "INFO: Determined that the FSL version in use is ${fsl_version}"
	else
		log_Msg "ERROR: Cannot tell which version of FSL you are using."
		exit 1
	fi

	eval $__functionResultVar="'${fsl_version}'"
}

#
# NOTE:
#   Don't echo anything in this function other than the last echo
#   that outputs the return value
#
determine_old_or_new_fsl()
{
	local fsl_version=${1}
	local old_or_new
	local fsl_version_array
	local fsl_primary_version
	local fsl_secondary_version
	local fsl_tertiary_version

	# parse the FSL version information into primary, secondary, and tertiary parts
	fsl_version_array=(${fsl_version//./ })

	fsl_primary_version="${fsl_version_array[0]}"
	fsl_primary_version=${fsl_primary_version//[!0-9]/}
	
	fsl_secondary_version="${fsl_version_array[1]}"
	fsl_secondary_version=${fsl_secondary_version//[!0-9]/}
	
	fsl_tertiary_version="${fsl_version_array[2]}"
	fsl_tertiary_version=${fsl_tertiary_version//[!0-9]/}

	# determine whether we are using "OLD" or "NEW" FSL 
	# 5.0.8 and below is "OLD"
	# 5.0.9 and above is "NEW"

	if [[ $(( ${fsl_primary_version} )) -lt 5 ]] ; then
		# e.g. 4.x.x
		old_or_new="OLD"
	elif [[ $(( ${fsl_primary_version} )) -gt 5 ]] ; then
		# e.g. 6.x.x
		old_or_new="NEW"
	else
		# e.g. 5.x.x
		if [[ $(( ${fsl_secondary_version} )) -gt 0 ]] ; then
			# e.g. 5.1.x
			old_or_new="NEW"
		else
			# e.g. 5.0.x
			if [[ $(( ${fsl_tertiary_version} )) -le 8 ]] ; then
				# e.g. 5.0.1, 5.0.2, 5.0.3, 5.0.4 ... 5.0.8
				old_or_new="OLD"
			else
				# e.g. 5.0.9 or 5.0.10 ...
				old_or_new="NEW"
			fi
		fi
	fi

	echo ${old_or_new}
}

# 
# Function Description
#  Main processing of script
#
#  Gets user specified command line options, runs appropriate eddy 
#
main()
{
	# Get Command Line Options
	#
	# Global Variables Set:
	#  See documentation for get_options function
	get_options $@
	
	# Validate environment variables
	validate_environment_vars $@
	
	# Establish tool name for logging
	log_SetToolName "run_eddy.sh"

	# Determine whether FSL version is "OLD" or "NEW"
	get_fsl_version fsl_ver
	log_Msg "FSL version: ${fsl_ver}"

	old_or_new_version=$(determine_old_or_new_fsl ${fsl_ver})

	# Set values for stdEddy (non-GPU-enabled version of eddy binary)
	# and gpuEnabledEddy (GPU-enabled version of eddy binary) 
	# based upon version of FSL being used.
	# 
	# stdEddy is "eddy" for FSL versions prior to FSL 5.0.9
	#         is "eddy_openmp" for FSL versions starting with FSL 5.0.9
	#
	# gpuEnabledEddy is "eddy.gpu" for FSL versions prior to FSL 5.0.9 (may not exist)
	#                is "eddy_cuda" for FSL versions starting with FSL 5.0.9
	
	if [ "${old_or_new_version}" == "OLD" ] ; then
		log_Msg "INFO: Detected pre-5.0.9 version of FSL is in use."
		gpuEnabledEddy="${FSLDIR}/bin/eddy.gpu"
		stdEddy="${FSLDIR}/bin/eddy"
	else
		log_Msg "INFO: Detected 5.0.9 or newer version of FSL is in use."
		gpuEnabledEddy="${FSLDIR}/bin/eddy_cuda"
		stdEddy="${FSLDIR}/bin/eddy_openmp"
	fi
	log_Msg "gpuEnabledEddy: ${gpuEnabledEddy}"
	log_Msg "stdEddy: ${stdEddy}"

	# Determine which eddy executable to use based upon whether 
	# the user requested use of the GPU-enabled version of eddy
	# and whether the requested version of eddy can be found.

	if [ "${useGpuVersion}" = "True" ]; then
		log_Msg "User requested GPU-enabled version of eddy"
		if [ -e ${gpuEnabledEddy} ]; then
			log_Msg "GPU-enabled version of eddy found: ${gpuEnabledEddy}"
			eddyExec="${gpuEnabledEddy}"
		else
			log_Msg "GPU-enabled version of eddy NOT found: ${gpuEnabledEddy}"
			log_Msg "ABORTING"
			exit 1
		fi
	else
		log_Msg "User did not request GPU-enabled version of eddy"
		if [ -e ${stdEddy} ]; then
			log_Msg "Non-GPU-enabled version of eddy found: ${stdEddy}"
			eddyExec="${stdEddy}"
		else
			log_Msg "Non-GPU-enabled version of eddy NOT found: ${stdEddy}"
			log_Msg "ABORTING"
			exit 1
		fi
	fi
	
	log_Msg "eddy executable command to use: ${eddyExec}"
	
	# Add option to eddy command for producing detailed outlier stats after each
	# iteration if user has requested that option _and_ the GPU-enabled version
	# of eddy is to be used.  Also add option to eddy command for replacing
	# outliers if the user has requested that option _and_ the GPU-enabled
	# version of eddy to to be used.
	outlierStatsOption=""
	replaceOutliersOption=""
	nvoxhpOption=""
	sep_offs_moveOption=""
	rmsOption=""
	ff_valOption=""
	ol_nstd_option=""
	
	if [ "${eddyExec}" = "${gpuEnabledEddy}" ]; then
		if [ "${produceDetailedOutlierStats}" = "True" ]; then
			outlierStatsOption="--wss"
		fi
		
		if [ "${replaceOutliers}" = "True" ]; then
			replaceOutliersOption="--repol"
		fi
		
		if [ "${nvoxhp}" != "" ]; then
			nvoxhpOption="--nvoxhp=${nvoxhp}"
		fi
		
		if [ "${sep_offs_move}" = "True" ]; then
			sep_offs_moveOption="--sep_offs_move"
		fi
		
		if [ "${rms}" = "True" ]; then
			rmsOption="--rms"
		fi
		
		if [ "${ff_val}" != "" ]; then
			ff_valOption="--ff=${ff_val}"
		fi

		if [ -z "${ol_nstd_val}" ]; then
			ol_nstd_option=""
		else
			ol_nstd_option="--ol_nstd=${ol_nstd_val}"
		fi
	fi
	
	log_Msg "outlier statistics option: ${outlierStatsOption}"
	log_Msg "replace outliers option: ${replaceOutliersOption}"
	log_Msg "nvoxhp option: ${nvoxhpOption}"
	log_Msg "sep_offs_move option: ${sep_offs_moveOption}"
	log_Msg "rms option: ${rmsOption}"
	log_Msg "ff option: ${ff_valOption}"
	log_Msg "ol_nstd_option: ${ol_nstd_option}"

	# Main processing - Run eddy
	
	topupdir=`dirname ${workingdir}`/topup
	
	${FSLDIR}/bin/imcp ${topupdir}/nodif_brain_mask ${workingdir}/
	
	eddy_command="${eddyExec} "
	eddy_command+="${outlierStatsOption} "
	eddy_command+="${replaceOutliersOption} "
	eddy_command+="${nvoxhpOption} "
	eddy_command+="${sep_offs_moveOption} "
	eddy_command+="${rmsOption} "
	eddy_command+="${ff_valOption} "
	eddy_command+="--imain=${workingdir}/Pos_Neg "
	eddy_command+="--mask=${workingdir}/nodif_brain_mask "
	eddy_command+="--index=${workingdir}/index.txt "
	eddy_command+="--acqp=${workingdir}/acqparams.txt "
	eddy_command+="--bvecs=${workingdir}/Pos_Neg.bvecs "
	eddy_command+="--bvals=${workingdir}/Pos_Neg.bvals "
	eddy_command+="--fwhm=${fwhm_value} "
	eddy_command+="--topup=${topupdir}/topup_Pos_Neg_b0 "
	eddy_command+="--out=${workingdir}/eddy_unwarped_images "
	eddy_command+="--flm=quadratic "

	if [ ! -z "${dont_peas}" ] ; then
		eddy_command+="--dont_peas "
	fi

	if [ ! -z "${resamp_value}" ] ; then
		eddy_command+="--resamp=${resamp_value} "
	fi

	if [ ! -z "${ol_nstd_option}" ] ; then
		eddy_command+="${ol_nstd_option} "
	fi
	
	if [ ! -z "${extra_eddy_args}" ] ; then
		for extra_eddy_arg in ${extra_eddy_args} ; do
			eddy_command+=" ${extra_eddy_arg} "
		done
	fi

	log_Msg "About to issue the following eddy command: "
	log_Msg "${eddy_command}"
	${eddy_command}
	eddyReturnValue=$?
	
	log_Msg "Completed with return value: ${eddyReturnValue}"
	exit ${eddyReturnValue}
}

#
# Invoke the main function to get things started
#
main $@
