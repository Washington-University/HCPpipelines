#!/bin/bash
#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # run_eddy.sh
#
# ## Copyright Notice
#
# Copyright (C) 2012-2019 The Human Connectome Project
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
# * [FSL][FSL] - FMRIB's Software Library (version 5.0.7 or later)
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
source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@" # Debugging functions; also sources log.shlib

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

show_usage() {
	cat <<EOF

Usage: ${g_script_name} PARAMETER...

PARAMETERS are: [ ] = optional; < > = user supplied value

  -w <working-dir> OR
  -w=<working-dir> OR
  --workingdir <working-dir> OR
  --workingdir=<working-dir> : the working directory (REQUIRED)

  [-h | --help] : show usage information and exit with non-zero return code

  [-g | --gpu]  : use the GPU-enabled version of eddy.

  [--wss] : produce detailed outlier statistics after each iteration by using
            the --wss option to a call to eddy.  Note that this option has
            no effect unless the GPU-enabled version of eddy is used.

  [--repol] : replace outliers. Note that this option has no effect unless the
              GPU-enabled version of eddy is used.

  [--nvoxhp=<number-of-voxel-hyperparameters>] : number of voxel hyperparameters to use
              Note that this option has no effect unless the GPU-enabled version of
              eddy is used.

  [--sep_offs_move] : If specified, this option stops dwi from drifting relative to b=0
              Note that this option has no effect unless the GPU-enabled version of
              eddy is used.

  [--rms] : If specified, write a root-mean-squared movement file for QA purposes
              Note that this option has no effect unless the GPU-enabled version of
              eddy is used.

  [--ff=<ff-value>] : Determines level of Q-space smoothing during esimation of movement/distortions

  [--dont_peas] : pass the --dont_peas (Do NOT perform a post-eddy alignment of shells) option
                  to eddy invocation"

  [--fwhm=<value>] : --fwhm value to pass to eddy
                     If unspecified, defaults to --fwhm=0

  [--resamp=<value>] : --resamp value to pass to eddy
                     If unspecified, no --resamp option is passed to eddy

  [--ol_nstd=<value>] : --ol_nstd value to pass to eddy
                     If unspecified, no --ol_nstd option is pssed to eddy

  [--extra-eddy-arg=token] : Generic single token (no whitespace) argument to pass
                             to the eddy binary. To build a multi-token series of
                             arguments, you can specify this --extra-eddy-arg= 
                             parameter several times. E.g.,
                                --extra-eddy-arg=--verbose --extra-eddy-arg=T
                                will ultimately be translated to --verbose T when
                                passed to the eddy binary
  [--cuda-version=X.Y] : X.Y are the CUDA version of the eddy binary to use
                         This command line argument is required if -g or --gpu is
                         specified and the FSL installation used is not configured
                         with a file FSLDIR/bin/eddy as a symbolic link to the
                         appropriate FSLDIR/bin/eddy_cudaX.Y binary file.

Return Status Value:

  0                       All parameters were properly formed and processing succeeded,
                          or help requested.
  Non-zero                otherwise - malformed parameters or a processing failure was detected

Required Environment Variables:

  FSLDIR                  The home directory for FSL

EOF
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
#  ${ff_val}          - User specified ff value (empty string if unspecified)
#  ${ol_nstd_val}     - User specified value for ol_nstd option
#  ${extra_eddy_args} - User specified value for the --extra-eddy-args command line option
#  ${g_cuda_version}  - User specified value for the --cuda-version command line option
#

# --------------------------------------------------------------------------------
#  Support Functions
# --------------------------------------------------------------------------------

get_options() {
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
	g_cuda_version=""

	# parse arguments
	local index=0
	local numArgs=${#arguments[@]}
	local argument

	while [ ${index} -lt ${numArgs} ]; do
		argument=${arguments[index]}

		case ${argument} in
		-h | --help)
			show_usage
			exit 0
			;;
		-g | --gpu)
			useGpuVersion="True"
			index=$((index + 1))
			;;
		--wss)
			produceDetailedOutlierStats="True"
			index=$((index + 1))
			;;
		--repol)
			replaceOutliers="True"
			index=$((index + 1))
			;;
		-w | --workingdir)
			workingdir=${arguments[$((index + 1))]}
			index=$((index + 2))
			;;
		-w=* | --workingdir=*)
			workingdir=${argument#*=}
			index=$((index + 1))
			;;
		--nvoxhp=*)
			nvoxhp=${argument#*=}
			index=$((index + 1))
			;;
		--sep_offs_move)
			sep_offs_move="True"
			index=$((index + 1))
			;;
		--rms)
			rms="True"
			index=$((index + 1))
			;;
		--ff=*)
			ff_val=${argument#*=}
			index=$((index + 1))
			;;
		--dont_peas)
			dont_peas="--dont_peas"
			index=$((index + 1))
			;;
		--fwhm=*)
			fwhm_value=${argument#*=}
			index=$((index + 1))
			;;
		--resamp=*)
			resamp_value=${argument#*=}
			index=$((index + 1))
			;;
		--ol_nstd=*)
			ol_nstd_val=${argument#*=}
			index=$((index + 1))
			;;
		--extra-eddy-arg=*)
			extra_eddy_arg=${argument#*=}
			extra_eddy_args+=" ${extra_eddy_arg} "
			index=$((index + 1))
			;;
		--cuda-version=*)
			g_cuda_version=${argument#*=}
			index=$((index + 1))
			;;
		*)
			show_usage
			echo "ERROR: Unrecognized Option: ${argument}"
			exit 1
			;;
		esac
	done

	# check required parameters
	if [ -z ${workingdir} ]; then
		show_usage
		echo "  Error: <working-dir> not specified - Exiting without running eddy"
		exit 1
	fi

	# report options
	echo "-- ${g_script_name}: Specified Command-Line Options - Start --"
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
	echo "   g_cuda_version: ${g_cuda_version}"
	echo "-- ${g_script_name}: Specified Command-Line Options - End --"
}

#
# Determine g_stdEddy and g_gpuEnabledEddy for a supported
# "6-series" version of FSL (e.g. 6.0.1, 6.0.2, ... 7.x.x ...)
# But not 6.0.0 which is unsupported.
#
# This assumes that the version of FSL in use is already determined
# to be a supported "6-series" version.
#
# Outputs:
#   g_stdEddy
#   g_gpuEnabledEddy
#
determine_eddy_tools_for_supported_six_series() {
	g_stdEddy="${FSLDIR}/bin/eddy_openmp"

	if [ "${useGpuVersion}" = "True" ]; then
		if [ ! -z "${g_cuda_version}" ]; then
			# The user has asked to use the GPU-enabled version and
			# explicitly specified the CUDA version to use (via
			# the --cuda-version= option). So set things up to
			# use that version of eddy.
			g_gpuEnabledEddy="${FSLDIR}/bin/eddy_cuda${g_cuda_version}"
		else
			# The user has asked to use the GPU-enabled version but
			# has not explicitly specified the CUDA version to use.
			# However, it may still be possible to proceed, assuming
			# that the user has created a symbolic link of either
			# 'eddy_cuda' or (more dangerously) 'eddy' to the specific
			# desired CUDA binary (e.g., ${FSLDIR}/bin/eddy_cuda -> eddy_cuda9.1)
			if [ -e ${FSLDIR}/bin/eddy_cuda ]; then
				# They have an ${FSLDIR}/bin/eddy_cuda. So use it.
				g_gpuEnabledEddy="${FSLDIR}/bin/eddy_cuda"
			elif [ -e ${FSLDIR}/bin/eddy ]; then
				# They have an ${FSLDIR}/bin/eddy. It is dangerous to assume that this
				# is a symlink to an eddy_cudaX.X version, esp. since recent FSL installers
				# run an 'eddy_configuration.sh' script, that symlinks 'eddy' to 'eddy_openmp'
				# (which is NOT a GPU/CUDA-enabled version). But we'll attempt to detect
				# this situation below, and error out if it is detected.
				g_gpuEnabledEddy="${FSLDIR}/bin/eddy"
			else
				# If neither an FSLDIR/bin/eddy_cuda or FSLDIR/bin/eddy exists,
				# tell them that we can't figure out what eddy to use.
				log_Err "Since you have requested the use of GPU-enabled eddy,"
				log_Err "you must either:"
				log_Err "1. Set ${FSLDIR}/bin/eddy_cuda as a symbolic link to the version"
				log_Err "   of eddy_cudaX.Y in ${FSLDIR}/bin that you want to use"
				log_Err "   and is appropriate for the CUDA libraries installed"
				log_Err "   on your system OR "
				log_Err "2. Specify the --cuda-version=X.Y option to this "
				log_Err "   script in order to explicitly force the use of "
				log_Err "   ${FSLDIR}/bin/eddy_cudaX.Y"
				log_Err "3. Set ${FSLDIR}/bin/eddy as a symbolic link to the version of"
				log_Err "   eddy_cudaX.Y in ${FSLDIR}/bin that you want to use"
				log_Err "   (NOT RECOMMENDED since 'eddy' without any suffix is inherently ambiguous)"
				log_Err_Abort ""
			fi

			# If g_stdEddy and g_gpuEnabledEddy are the same, we have a problem
			# (probably a consequence of 'eddy' existing as a symlink to 'eddy_openmp')
			if [ -e ${g_stdEddy} ]; then
				# Check if files differ (which is what we want) within an 'if' statement
				# so that we don't trigger any active error trapping if they do differ.
				# 'diff' returns "true" if files are the same, in which case we want to abort.
				# Don't wrap the 'diff' command in () or [], as that will likely change the behavior.
				if diff -q ${g_stdEddy} ${g_gpuEnabledEddy} > /dev/null; then
					log_Err "Since you have requested the use of GPU-enabled eddy,"
					log_Err "you must either:"
					log_Err "1. Set ${FSLDIR}/bin/eddy_cuda as a symbolic link to the version"
					log_Err "   of eddy_cudaX.Y in ${FSLDIR}/bin that you want to use"
					log_Err "   and is appropriate for the CUDA libraries installed"
					log_Err "   on your system OR "
					log_Err "2. Specify the --cuda-version=X.Y option to this "
					log_Err "   script in order to explicitly force the use of "
					log_Err "   ${FSLDIR}/bin/eddy_cudaX.Y"
					log_Err "3. Set ${FSLDIR}/bin/eddy as a symbolic link to the version of"
					log_Err "   eddy_cudaX.Y in ${FSLDIR}/bin that you want to use"
					log_Err "   (NOT RECOMMENDED since 'eddy' without any suffix is inherently ambiguous)"
					log_Err_Abort ""
				fi
			fi
		fi

	else
		# User hasn't requested to use the GPU-enabled version.
		# So, it really doesn't matter what we set g_gpuEnabledEddy to.
		g_gpuEnabledEddy="nothing"
	fi
}

#
# Outputs:
#   g_stdEddy - path to the standard (non-GPU) version of eddy
#   g_gpuEnabledEddy - path to GPU-enabled version of eddy
#
determine_eddy_tools_to_use() {
	local fsl_version_file
	local fsl_version
	local fsl_version_array
	local fsl_primary_version
	local fsl_secondary_version
	local fsl_tertiary_version

	# get the current version of FSL in use
	fsl_version_file="${FSLDIR}/etc/fslversion"

	if [ -f ${fsl_version_file} ]; then
		fsl_version=$(cat ${fsl_version_file})
		log_Msg "INFO: Determined that the FSL version in use is ${fsl_version}"
	else
		log_Err_Abort "Cannot tell which version of FSL you are using."
	fi

	# break FSL version string into components
	# primary, secondary, and tertiary
	# FSL X.Y.Z would have X as primary, Y as secondary, and Z as tertiary versions

	fsl_version_array=(${fsl_version//./ })

	fsl_primary_version="${fsl_version_array[0]}"
	fsl_primary_version=${fsl_primary_version//[!0-9]/}

	fsl_secondary_version="${fsl_version_array[1]}"
	fsl_secondary_version=${fsl_secondary_version//[!0-9]/}

	fsl_tertiary_version="${fsl_version_array[2]}"
	fsl_tertiary_version=${fsl_tertiary_version//[!0-9]/}

	if [[ $((${fsl_primary_version})) -lt 5 ]]; then
		# e.g. 4.x.x
		log_Err_Abort "FSL 5.0.7 or greater is required."

	elif [[ $((${fsl_primary_version})) -eq 5 ]]; then
		# e.g. 5.x.x
		if [[ $((${fsl_secondary_version})) -gt 0 ]]; then
			# e.g. 5.1.x, 5.2.x, 5.3.x, etc.
			# There aren't any 5.1.x, 5.2.x, 5.3.x, etc. versions that we know
			# at the time this code was written. We don't expect any such
			# versions to ever exist. So it is unclear how to configure
			# g_stdEddy and g_gpuEnabledEddy for any such versions.
			log_Err_Abort "FSL version ${fsl_version} is currently unsupported"
		else
			# e.g. 5.0.x
			if [[ $((${fsl_tertiary_version})) -le 8 ]]; then
				# 5.0.7 or 5.0.8
				g_stdEddy="${FSLDIR}/bin/eddy"
				g_gpuEnabledEddy="${FSLDIR}/bin/eddy.gpu"
				log_Msg "Detected supported, pre-5.0.9 version of FSL"
				log_Msg "Standard (non-GPU-enabled) version of eddy available: ${g_stdEddy}"
				log_Msg "GPU-enabled version of eddy available: ${g_gpuEnabledEddy}"
			else
				# 5.0.9, 5.0.10, or 5.0.11
				g_stdEddy="${FSLDIR}/bin/eddy_openmp"
				g_gpuEnabledEddy="${FSLDIR}/bin/eddy_cuda"
				log_Msg "Detected supported, 5 series, post-5.0.9 version of FSL"
				log_Msg "Standard (non-GPU-enabled) version of eddy available: ${g_stdEddy}"
				log_Msg "GPU-enabled version of eddy available: ${g_gpuEnabledEddy}"
			fi
		fi

	elif [[ $((${fsl_primary_version})) -eq 6 ]]; then
		# e.g. 6.x.x
		if [[ $((${fsl_secondary_version})) -eq 0 ]]; then
			# e.g. 6.0.x
			if [[ $((${fsl_tertiary_version})) -eq 0 ]]; then
				# 6.0.0
				log_Err_Abort "FSL version ${fsl_version} is currently unsupported"
			else
				# e.g. 6.0.1, 6.0.2, etc.
				# At the time of this writing, only 6.0.1 exists. We expect
				# any more in the 6.0.2, 6.0.3 series that are created will
				# use the same file naming conventions.
				determine_eddy_tools_for_supported_six_series
			fi
		else
			# secondary version != 0 (means secondary version > 0)
			# e.g. 6.1.x, 6.2.x, etc.
			# These versions do not exist that we know of at this writing.
			# But, for now, we'll assume that they will work like the 6.0.1
			# version that we do know about.
			determine_eddy_tools_for_supported_six_series
		fi

	elif [[ $((${fsl_primary_version})) -gt 6 ]]; then
		# e.g. 7.x.x
		# These versions do not exist that we know of at this writing.
		# For now, we'll assume that they will work like the 6.0.1 version.
		determine_eddy_tools_for_supported_six_series

	else
		# If we reach here, the primary version is:
		# - not less than 5
		# - not equal to 5
		# - not equal to 6
		# - not greater than 6
		#
		# This should be impossible. So we better report an error if it actually happens
		# because that means the above logic has some fatal flaw in it or the
		# FSL version number has some very expected value.
		log_Err_Abort "Cannot figure out how to handle an FSL version like: ${fsl_version}"
	fi
}

#
# Function Description
#  Main processing of script
#
#  Gets user specified command line options, runs appropriate eddy
#
main() {
	# Get Command Line Options
	#
	# Global Variables Set:
	#  See documentation for get_options function
	get_options "$@"

	# Determine the eddy tools to use
	determine_eddy_tools_to_use

	local stdEddy="${g_stdEddy}"
	local gpuEnabledEddy="${g_gpuEnabledEddy}"

	# Determine which eddy executable to use based upon whether
	# the user requested use of the GPU-enabled version of eddy
	# and whether the requested version of eddy can be found.

	if [ "${useGpuVersion}" = "True" ]; then
		log_Msg "User requested GPU-enabled version of eddy"
		if [ -e ${gpuEnabledEddy} ]; then
			log_Msg "GPU-enabled version of eddy found: ${gpuEnabledEddy}"
			eddyExec="${gpuEnabledEddy}"
		else
			log_Err_Abort "GPU-enabled version of eddy NOT found: ${gpuEnabledEddy}"
		fi
	else
		log_Msg "User did not request GPU-enabled version of eddy"
		if [ -e ${stdEddy} ]; then
			log_Msg "Non-GPU-enabled version of eddy found: ${stdEddy}"
			eddyExec="${stdEddy}"
		else
			log_Err_Abort "Non-GPU-enabled version of eddy NOT found: ${stdEddy}"
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

	topupdir=$(dirname ${workingdir})/topup

	${FSLDIR}/bin/imcp ${topupdir}/nodif_brain_mask ${workingdir}/

	eddy_command="${eddyExec} "
	eddy_command+="${outlierStatsOption} "
	eddy_command+="${replaceOutliersOption} "
	eddy_command+="${nvoxhpOption} "
	eddy_command+="${sep_offs_moveOption} "
	eddy_command+="${rmsOption} "
	eddy_command+="${ff_valOption} "
	eddy_command+="--cnr_maps "  #Hard-coded as an option to 'eddy', so we can run EDDY QC (QUAD)
	eddy_command+="--imain=${workingdir}/Pos_Neg "
	eddy_command+="--mask=${workingdir}/nodif_brain_mask "
	eddy_command+="--index=${workingdir}/index.txt "
	eddy_command+="--acqp=${workingdir}/acqparams.txt "
	eddy_command+="--bvecs=${workingdir}/Pos_Neg.bvecs "
	eddy_command+="--bvals=${workingdir}/Pos_Neg.bvals "
	eddy_command+="--fwhm=${fwhm_value} "
	eddy_command+="--topup=${topupdir}/topup_Pos_Neg_b0 "
	eddy_command+="--out=${workingdir}/eddy_unwarped_images "

	if [ ! -z "${dont_peas}" ]; then
		eddy_command+="--dont_peas "
	fi

	if [ ! -z "${resamp_value}" ]; then
		eddy_command+="--resamp=${resamp_value} "
	fi

	if [ ! -z "${ol_nstd_option}" ]; then
		eddy_command+="${ol_nstd_option} "
	fi

	if [ ! -z "${extra_eddy_args}" ]; then
		for extra_eddy_arg in ${extra_eddy_args}; do
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

# ------------------------------------------------------------------------------
#  "Global" processing - everything above here should be in a function
# ------------------------------------------------------------------------------

# Establish defaults

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
source ${HCPPIPEDIR}/global/scripts/opts.shlib         # Command line option functions

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
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
