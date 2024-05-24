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

set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

# Load function libraries
source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@" # Debugging functions; also sources log.shlib
source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"

#compatibility, repeatable option
if (($# > 0))
then
    newargs=()
    origargs=("$@")
    extra_eddy_args_manual=()
    changeargs=0
    for ((i = 0; i < ${#origargs[@]}; ++i))
    do
        case "${origargs[i]}" in
            (--gpu|-g|--wss|--repol|--sep-offs-move|--sep_offs_move|--rms)
                #"--gpu true" and similar work as-is, detect it and copy it as-is, but don't trigger the argument change
                if ((i + 1 < ${#origargs[@]})) && (opts_StringToBool "${origargs[i + 1]}" &> /dev/null)
                then
                    newargs+=("${origargs[i]}" "${origargs[i + 1]}")
                    #skip the boolean value, we took care of it
                    i=$((i + 1))
                else
                    newargs+=("${origargs[i]}"=TRUE)
                    changeargs=1
                fi
                ;;
            (--dont-peas)
                #we removed the negation, just replace
                newargs+=(--peas=FALSE)
                changeargs=1
                ;;
            (--extra-eddy-arg=*)
                #repeatable options aren't yet a thing in newopts (indirect assignment to arrays seems to need eval)
                #figure out whether these extra arguments could have a better syntax (if whitespace is supported, probably not)
                extra_eddy_args_manual+=("${origargs[i]#*=}")
                changeargs=1
                ;;
            (--extra-eddy-arg)
                #also support "--extra-eddy-arg foo", for fewer surprises
                if ((i + 1 >= ${#origargs[@]}))
                then
                    log_Err_Abort "--extra-reconall-arg requires an argument"
                fi
                extra_reconall_args_manual+=("${origargs[i + 1]#*=}")
                #skip the next argument, we took care of it
                i=$((i + 1))
                changeargs=1
                ;;
            (*)
                #copy anything unrecognized
                newargs+=("${origargs[i]}")
                ;;
        esac
    done
    if ((changeargs))
    then
        echo "original arguments: $*"
        set -- "${newargs[@]}"
        echo "new arguments: $*"
        echo "extra eddy arguments: ${extra_eddy_args_manual[*]+"${extra_eddy_args_manual[*]}"}"
    fi
fi

opts_SetScriptDescription "Perform the Eddy steps of the HCP Diffusion Preprocessing Pipeline"

opts_AddMandatory '--workingdir' 'workingdir' 'Path' 'The working directory' "-w"

opts_AddOptional '--gpu' 'useGpuVersionString' 'Boolean' 'Whether to use a GPU version of eddy' "False" "-g"

opts_AddOptional '--wss' 'produceDetailedOutlierStatsString' 'Boolean' "Produce detailed outlier statistics after each iteration by using the --wss option to a call to eddy. Note that this option has no effect unless the GPU-enabled version of eddy is used." "False"

opts_AddOptional '--repol' 'replaceOutliersString' 'Boolean' "Replace outliers. Note that this option has no effect unless the GPU-enabled version of eddy is used." "False"

opts_AddOptional '--nvoxhp' 'nvoxhp' 'Number' "Number of voxel hyperparameters to use Note that this option has no effect unless the GPU-enabled version of  eddy is used."

opts_AddOptional '--sep-offs-move' 'sepOffsMoveString' 'Boolean' "This option stops dwi from drifting relative to b=0 Note that this option has no effect unless the GPU-enabled version of eddy is used." "False" '--sep_offs_move'

opts_AddOptional '--rms' 'rmsString' 'Boolean' "Write root-mean-squared movement files for QA purposes Note: This option has no effect if the GPU-enabled version of eddy is not used." "False"

opts_AddOptional '--ff' 'ff_val' 'Value' "Determines level of Q-space smoothing during esimation of movement/distortions"

opts_AddOptional '--peas' 'peasString' 'Boolean' "Whether to perform a post-eddy alignment of shells"

opts_AddOptional '--fwhm' 'fwhm_value' 'Value' "Fwhm value to pass to eddy If unspecified, defaults to --fwhm=0" "0"

opts_AddOptional '--resamp' 'resamp_value' 'Value' 'Resamp value to pass to the eddy binary If unspecified, no option is passed to the eddy binary.'

opts_AddOptional '--ol_nstd' 'ol_nstd_val' 'Value' 'Ol_nstd value to pass to the eddy binary If unspecified, no ol_nstd option is passed to the eddy binary'

opts_AddOptional '--extra-eddy-arg' 'extra_eddy_args' 'token' '(repeatable) Generic single token (no whitespace) argument to be passed to the run_eddy.sh script and subsequently to the eddy binary. To build a multi-token series of arguments, you can specify this parameter several times. E.g.  --extra-eddy-arg=--verbose --extra-eddy-arg=T will ultimately be translated to --verbose T when passed to the eddy binary.'

opts_AddOptional '--cuda-version' 'g_cuda_version' 'X.Y' " If using the GPU-enabled version of eddy then this option can be used to specify which eddy_cuda binary version to use. If specified, FSLDIR/bin/eddy_cudaX.Y will be used."

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#TSC: hack around the lack of repeatable option support, use a single string for display
extra_eddy_args=${extra_eddy_args_manual[*]+"${extra_eddy_args_manual[*]}"}

opts_ShowValues

#TSC: now use an array for proper argument handling
extra_eddy_args=(${extra_eddy_args_manual[@]+"${extra_eddy_args_manual[@]}"})

#parse booleans
useGpuVersion=$(opts_StringToBool "$useGpuVersionString")
produceDetailedOutlierStats=$(opts_StringToBool "$produceDetailedOutlierStatsString")
replaceOutliers=$(opts_StringToBool "$replaceOutliersString")
sepOffsMove=$(opts_StringToBool "$sepOffsMoveString")
rms=$(opts_StringToBool "$rmsString")
peas=$(opts_StringToBool "$peasString")

"$HCPPIPEDIR"/show_version

# Verify required environment variables are set and log value
log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FSLDIR

# Set other necessary variables, contingent on HCPPIPEDIR
HCPPIPEDIR_dMRI=${HCPPIPEDIR}/DiffusionPreprocessing/scripts

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
	#newer fsl renamed the cpu version
	if [[ ! -f "$g_stdEddy" ]]; then
	    g_stdEddy="${FSLDIR}/bin/eddy_cpu"
	fi

	if ((useGpuVersion)); then
		if [[ ! -z "${g_cuda_version}" ]]; then
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
			if [[ -e "${FSLDIR}/bin/eddy_cuda" ]]; then
				# They have an ${FSLDIR}/bin/eddy_cuda. So use it.
				g_gpuEnabledEddy="${FSLDIR}/bin/eddy_cuda"
			elif [[ -e "${FSLDIR}/bin/eddy" ]]; then
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
			if [[ -e "${g_stdEddy}" ]]; then
				# Check if files differ (which is what we want) within an 'if' statement
				# so that we don't trigger any active error trapping if they do differ.
				# 'diff' returns "true" if files are the same, in which case we want to abort.
				# Don't wrap the 'diff' command in () or [], as that will likely change the behavior.
				if diff -q "${g_stdEddy}" "${g_gpuEnabledEddy}" > /dev/null; then
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

# Determine the eddy tools to use
determine_eddy_tools_to_use

stdEddy="${g_stdEddy}"
gpuEnabledEddy="${g_gpuEnabledEddy}"

# Determine which eddy executable to use based upon whether
# the user requested use of the GPU-enabled version of eddy
# and whether the requested version of eddy can be found.

if ((useGpuVersion)); then
	log_Msg "User requested GPU-enabled version of eddy"
	if [[ -e "${gpuEnabledEddy}" ]]; then
		log_Msg "GPU-enabled version of eddy found: ${gpuEnabledEddy}"
		eddyExec="${gpuEnabledEddy}"
	else
		log_Err_Abort "GPU-enabled version of eddy NOT found: ${gpuEnabledEddy}"
	fi
else
	log_Msg "User did not request GPU-enabled version of eddy"
	if [[ -e "${stdEddy}" ]]; then
		log_Msg "Non-GPU-enabled version of eddy found: ${stdEddy}"
		eddyExec="${stdEddy}"
	else
		log_Err_Abort "Non-GPU-enabled version of eddy NOT found: ${stdEddy}"
	fi
fi

log_Msg "eddy executable command to use: ${eddyExec}"

topupdir=$(dirname ${workingdir})/topup

${FSLDIR}/bin/imcp ${topupdir}/nodif_brain_mask ${workingdir}/

#TSC: currently using same order as previous construct
#if it doesn't matter, move the other gpu-only thing into the gpu block
eddy_command=("${eddyExec}")
#various options only implemented in gpu version
if [[ "${eddyExec}" == "${gpuEnabledEddy}" ]]; then
    if ((produceDetailedOutlierStats)); then
        eddy_command+=(--wss)
    fi
    if ((replaceOutliers)); then
        eddy_command+=(--repol)
    fi
    if [[ "$nvoxhp" != "" ]] ; then
        eddy_command+=(--nvoxhp="${nvoxhp}")
    fi
    if ((sepOffsMove)); then
        eddy_command+=(--sep_offs_move)
    fi
    if ((rms)); then
        eddy_command+=(--rms)
    fi
    if [[ "$ff_val" != "" ]] ; then
        eddy_command+=(--nvoxhp="${ff_val}")
    fi
fi
eddy_command+=("--cnr_maps"  #Hard-coded as an option to 'eddy', so we can run EDDY QC (QUAD)
    "--imain=${workingdir}/Pos_Neg"
    "--mask=${workingdir}/nodif_brain_mask"
    "--index=${workingdir}/index.txt"
    "--acqp=${workingdir}/acqparams.txt"
    "--bvecs=${workingdir}/Pos_Neg.bvecs"
    "--bvals=${workingdir}/Pos_Neg.bvals"
    "--fwhm=${fwhm_value}"
    "--topup=${topupdir}/topup_Pos_Neg_b0"
    "--out=${workingdir}/eddy_unwarped_images")
if ((! peas)); then
    eddy_command+=(--dont_peas)
fi
if [[ "${resamp_value}" != "" ]]; then
	eddy_command+=("--resamp=${resamp_value}")
fi
#another gpu-dependent option
if [[ "${eddyExec}" == "${gpuEnabledEddy}" && "${ol_nstd_val}" != "" ]]; then
	eddy_command+=("--ol_nstd=${ol_nstd_val}")
fi
eddy_command+=(${extra_eddy_args[@]+"${extra_eddy_args[@]}"})

log_Msg "About to issue the following eddy command: "
log_Msg "${eddy_command[*]}"
"${eddy_command[@]}"

