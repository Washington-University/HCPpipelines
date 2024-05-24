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
set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

# Load function libraries
source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"    # Debugging functions; also sources log.shlib
source "${HCPPIPEDIR}/global/scripts/newopts.shlib" "$@"  # Command line option functions

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
            (--select-best-b0|--ensure-even-slices)
                #"--select-best-b0 true" and similar work as-is, detect it and copy it as-is, but don't trigger the argument change
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
            (--no-gpu)
                #we removed the negation, just replace
                newargs+=(--gpu=FALSE)
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

# Establish defaults
DEFAULT_B0_MAX_BVAL=50
DEFAULT_DEGREES_OF_FREEDOM=6

# Perform the steps of the HCP Diffusion Preprocessing Pipeline
opts_SetScriptDescription "Perform the steps of the HCP Diffusion Preprocessing Pipeline"

opts_AddMandatory '--path' 'StudyFolder' 'Path' "path to subject's data folder" 

opts_AddMandatory '--subject' 'Subject' 'subject ID' "subject-id"

opts_AddMandatory '--PEdir' 'PEdir' 'Path' "Phase encoding direction specifier: 1=LR/RL, 2=AP/PA"

opts_AddMandatory '--posData' 'PosInputImages' 'data_RL1@data_RL2@...data_RLn' "An @ symbol separated list of data with 'positive' phase  encoding direction; e.g., data_RL1@data_RL2@...data_RLn, or data_PA1@data_PA2@...data_PAn"

opts_AddMandatory '--negData' 'NegInputImages' 'data_LR1@data_LR2@...data_LRn' "An @ symbol separated list of data with 'negative' phase encoding direction; e.g., data_LR1@data_LR2@...data_LRn, or data_AP1@data_AP2@...data_APn"

opts_AddOptional '--echospacing-seconds' 'echospacingsec' 'Number in sec' "Echo spacing in seconds, REQUIRED (or deprecated millisec option)"
opts_AddOptional '--echospacing' 'echospacing' 'Number in millisec' "DEPRECATED: please use --echospacing-seconds"

opts_AddMandatory '--gdcoeffs' 'GdCoeffs' 'Path' "Path to file containing coefficients that describe spatial variations of the scanner gradients. Applied *after* 'eddy'. Use --gdcoeffs=NONE if not available."

opts_AddOptional '--dwiname' 'DWIName' 'String' "Name to give DWI output directories. Defaults to Diffusion" "Diffusion"

opts_AddOptional '--dof' 'DegreesOfFreedom' 'Number' "Degrees of Freedom for post eddy registration to structural images. Defaults to '${DEFAULT_DEGREES_OF_FREEDOM}'" "${DEFAULT_DEGREES_OF_FREEDOM}"

opts_AddOptional '--b0maxbval' 'b0maxbval' 'Value' "Volumes with a bvalue smaller than this value will be considered as b0s. Defaults to '${DEFAULT_B0_MAX_BVAL}'" "${DEFAULT_B0_MAX_BVAL}"

opts_AddOptional '--topup-config-file' 'TopupConfig' 'Path' "File containing the FSL topup configuration. Defaults to b02b0.cnf in the HCP configuration directory '(as defined by HCPPIPEDIR_Config).'"

opts_AddOptional '--select-best-b0' 'SelectBestB0String' 'Boolean' "If set selects the best b0 for each phase encoding direction to pass on to topup rather than the default behaviour of using equally spaced b0's throughout the scan. The best b0 is identified as the least distorted (i.e., most similar to the average b0 after registration)." "False"

opts_AddOptional '--ensure-even-slices' 'EnsureEvenSlicesString' 'Boolean' "If set will ensure the input images to FSL's topup and eddy have an even number of slices by removing one slice if necessary. This behaviour used to be the default, but is now optional, because discarding a slice is incompatible with using slice-to-volume correction in FSL's eddy." "False"

opts_AddOptional '--extra-eddy-arg' 'extra_eddy_args' 'token' "(repeatable) Generic single token (no whitespace) argument to pass to the DiffPreprocPipeline_Eddy.sh script and subsequently to the run_eddy.sh script and finally to the command that actually invokes the eddy binary. The following will work:
  --extra-eddy-arg=--val=1
because '--val=1' is a single token containing no whitespace. The following will NOT work:
  --extra-eddy-arg='--val1=1 --val2=2'
because '--val1=1' and '--val2=2' need to be treated as separate arguments. To build a multi-token series of arguments, you can specify this --extra-eddy-arg= parameter several times, e.g.,
  --extra-eddy-arg=--val1=1 --extra-eddy-arg=--val2=2
To get an argument like '-flag value' (where there is no '=' between the flag and the value) passed to the eddy binary, the following sequence will work:
  --extra-eddy-arg=-flag --extra-eddy-arg=value"

## This is an extremely confusing flag should rework it to just use-gpu?
opts_AddOptional '--gpu' 'gpuString' 'Boolean' "Specify whether to use the non-GPU-enabled version of eddy. Defaults to using the GPU-enabled version of eddy i.e. True." "True"

opts_AddOptional '--cuda-version' 'cuda_version' 'X.Y' " If using the GPU-enabled version of eddy then this option can be used to specify which eddy_cuda binary version to use. If specified, FSLDIR/bin/eddy_cudaX.Y will be used."

opts_AddOptional '--combine-data-flag' 'CombineDataFlag' 'number' "Specified value is passed as the CombineDataFlag value for the eddy_postproc.sh script. If JAC resampling has been used in eddy, this value determines what to do with the output file.
  2 - include in the output all volumes uncombined (i.e. output file of eddy)
  1 - include in the output and combine only volumes where both LR/RL (or AP/PA) pairs have been acquired
  0 - As 1, but also include uncombined single volumes
Defaults to 1" "1"

opts_AddOptional '--printcom' 'runcmd' 'echo' 'to echo or otherwise  output the commands that would be executed instead of  actually running them. --printcom=echo is intended to  be used for testing purposes'

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
SelectBestB0=$(opts_StringToBool "$SelectBestB0String")
EnsureEvenSlices=$(opts_StringToBool "$EnsureEvenSlicesString")
gpu=$(opts_StringToBool "$gpuString")

#defaults that depend on env variables
if [[ "$TopupConfig" == "" ]]
then
    TopupConfig="${HCPPIPEDIR_Config}/b02b0.cnf"
fi

#resolve echo spacing being required and exclusivity
if [[ "$echospacing" == "" && "$echospacingsec" == "" ]]
then
    log_Err_Abort "You must specify --echospacing-seconds or --echospacing"
fi

if [[ "$echospacing" != "" && "$echospacingsec" != "" ]]
then
    log_Err_Abort "You must not specify both --echospacing-seconds and --echospacing"
fi

#internally, PreEddy script expects milliseconds
if [[ "$echospacingsec" != "" ]]
then
    echospacingmilli=$(echo "$echospacingsec * 1000" | bc -l)
else
    #could add a deprecation warning here, if we want to remove the old parameter in the future
    echospacingmilli="$echospacing"
fi

#check for input unit errors
if [[ $(echo "$echospacingmilli < 10 && $echospacingmilli > 0.01" | bc) == 0* ]]
then
    log_Err_Abort "$echospacingmilli milliseconds is not a sane value for echo spacing"
fi
if [[ $(echo "$echospacingmilli < 1 && $echospacingmilli > 0.1" | bc) == 0* ]]
then
    log_Warn "$echospacingmilli milliseconds seems unlikely for echo spacing, continuing anyway"
fi

"$HCPPIPEDIR"/show_version

# Verify required environment variables are set and log value
log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FSLDIR

if ((SelectBestB0)); then
    dont_peas_set=false
    fwhm_set=false
    for extra_eddy_arg in ${extra_eddy_args[@]+"${extra_eddy_args[@]}"}; do
        if [[ ${extra_eddy_arg} == "--fwhm"* ]]; then
            fwhm_set=true
        fi
        if [[ ${extra_eddy_arg} == "--dont_peas"* ]]; then
            log_Err "When using --select-best-b0, post-alignment of shells in eddy is required, "
            log_Err "as the first b0 could be taken from anywhere within the diffusion data and "
            log_Err "hence might not be aligned to the first diffusion-weighted image."
            log_Err_Abort "Remove either the --extra_eddy_args=--dont_peas flag or the --select-best-b0 flag"
        fi
    done
    if [[ "$fwhm_set" == "false" ]]; then
        log_Warn "Using --select-best-b0 prepends the best b0 to the start of the file passed into eddy."
        log_Warn "To ensure eddy succesfully aligns this new first b0 with the actual first volume,"
        log_Warn "we recommend to increase the FWHM for the first eddy iterations if using --select-best-b0"
        log_Warn "This can be done by setting the --extra_eddy_args=--fwhm=... flag"
    fi
fi


#
# Function Description
#  Validate necessary scripts exist before starting to run anything
#
validate_scripts() {
	local error_msgs=""

	if [[ ! -f "${HCPPIPEDIR}"/DiffusionPreprocessing/DiffPreprocPipeline_PreEddy.sh ]]; then
		error_msgs+="\nERROR: HCPPIPEDIR/DiffusionPreprocessing/DiffPreprocPipeline_PreEddy.sh not found"
	fi

	if [[ ! -f "${HCPPIPEDIR}"/DiffusionPreprocessing/DiffPreprocPipeline_Eddy.sh ]]; then
		error_msgs+="\nERROR: HCPPIPEDIR/DiffusionPreprocessing/DiffPreprocPipeline_Eddy.sh not found"
	fi

	if [[ ! -f "${HCPPIPEDIR}"/DiffusionPreprocessing/scripts/run_eddy.sh ]]; then
		error_msgs+="\nERROR: HCPPIPEDIR/DiffusionPreprocessing/scripts/run_eddy.sh not found"
	fi

	if [[ ! -f "${HCPPIPEDIR}"/DiffusionPreprocessing/DiffPreprocPipeline_PostEddy.sh ]]; then
		error_msgs+="\nERROR: HCPPIPEDIR/DiffusionPreprocessing/DiffPreprocPipeline_PostEddy.sh not found"
	fi

	if [[ "${error_msgs}" != "" ]]; then
		log_Err_Abort "${error_msgs}"
	fi
}

#
# Function Description
#  Main processing of script

# Validate scripts
validate_scripts "$@"

log_Msg "Invoking Pre-Eddy Steps"
pre_eddy_cmd=("${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline_PreEddy.sh"
    "--path=${StudyFolder}"
    "--subject=${Subject}"
    "--dwiname=${DWIName}"
    "--PEdir=${PEdir}"
    "--posData=${PosInputImages}"
    "--negData=${NegInputImages}"
    "--echospacing=${echospacingmilli}"
    "--b0maxbval=${b0maxbval}"
    "--topup-config-file=${TopupConfig}"
    "--printcom=${runcmd}"
    "--select-best-b0=${SelectBestB0}"
    "--ensure-even-slices=${EnsureEvenSlices}")

log_Msg "pre_eddy_cmd: ${pre_eddy_cmd[*]}"
"${pre_eddy_cmd[@]}"

log_Msg "Invoking Eddy Step"
eddy_cmd=("${HCPPIPEDIR}"/DiffusionPreprocessing/DiffPreprocPipeline_Eddy.sh
    --path="$StudyFolder"
    --subject="$Subject"
    --dwiname="$DWIName"
    --printcom="$runcmd"
    --gpu="$gpu"
    --cuda-version="$cuda_version")
for extra_eddy_arg in ${extra_eddy_args[@]+"${extra_eddy_args[@]}"}
do
    eddy_cmd+=(--extra-eddy-arg="$extra_eddy_arg")
done

log_Msg "eddy_cmd: ${eddy_cmd[*]}"
"${eddy_cmd[@]}"

log_Msg "Invoking Post-Eddy Steps"
post_eddy_cmd=("${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline_PostEddy.sh"
    "--path=${StudyFolder}"
    "--subject=${Subject}"
    "--dwiname=${DWIName}"
    "--gdcoeffs=${GdCoeffs}"
    "--dof=${DegreesOfFreedom}"
    "--combine-data-flag=${CombineDataFlag}"
    "--printcom=${runcmd}"
    "--select-best-b0=${SelectBestB0}")

log_Msg "post_eddy_cmd: ${post_eddy_cmd[*]}"
"${post_eddy_cmd[@]}"

log_Msg "Completed!"
exit 0

