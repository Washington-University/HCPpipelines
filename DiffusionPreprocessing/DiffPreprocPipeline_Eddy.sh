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

set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

# Load function libraries
source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "${HCPPIPEDIR}/global/scripts/processingmodecheck.shlib"  # Check processing mode requirements
source "${HCPPIPEDIR}/global/scripts/fsl_version.shlib"          # Functions for getting FSL version
source "${HCPPIPEDIR}/global/scripts/version.shlib"      # version_ functions

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
            (--rms|--detailed-outlier-stats|--replace-outliers|--sep-offs-move|--sep_offs_move)
                #"--rms true" and similar work as-is, detect it and copy it as-is, but don't trigger the argument change
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
            (--dont-peas)
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

opts_SetScriptDescription "Perform the Eddy step of the HCP Diffusion Preprocessing Pipeline"
 
opts_AddOptional '--detailed-outlier-stats' 'DetailedOutlierStatsString' 'Boolean' "Produce detailed outlier statistics from eddy after each iteration. Note: This option has no effect if the GPU-enabled version of eddy is not used." "False"

opts_AddOptional '--replace-outliers' 'ReplaceOutliersString' 'Boolean' "Ask eddy to replace any outliers it detects by their expectations. Note: This option has no effect if the GPU-enabled version of eddy is not used." "False"

opts_AddOptional '--nvoxhp' 'nvoxhp' 'Number' "Number of voxel hyperparameters to use. Note: This option has no effect if the GPU-enabled version of eddy is not used."

opts_AddOptional '--sep-offs-move' 'sepOffsMoveString' 'Boolean' "Stop DWI from drifting relative to b=0. Note: This option has no effect if the GPU-enabled version of eddy  is not used." "False" "--sep_offs_move"

opts_AddOptional '--rms' 'rmsString' 'Boolean' "Write root-mean-squared movement files for QA purposes Note: This option has no effect if the GPU-enabled version of eddy is not used." "False"

opts_AddOptional '--ff' 'ff_val' 'Number' "Ff-value to be passed to the eddy binary. See eddy documentation at http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/EDDY/UsersGuide#A--ff for further information. Note: This option has no effect if the GPU-enabled version of eddy is not used."

opts_AddMandatory '--path' 'StudyFolder' 'Path' "path to subject's data folder" 
  
opts_AddMandatory '--subject' 'Subject' 'subject ID' "subject-id"

opts_AddOptional '--dwiname' 'DWIName' 'String' "Name to give DWI output directories. Defaults to Diffusion" "Diffusion" 

opts_AddOptional '--peas' 'peasString' 'Boolean' "Whether to perform a post-eddy alignment of shells, default True" "True"

opts_AddOptional '--fwhm' 'fwhm_value' 'Number' 'Fwhm value to pass to the eddy binary Defaults to 0' "0"

opts_AddOptional '--resamp' 'resamp_value' 'Number' 'Resamp value to pass to the eddy binary If unspecified, no option is passed to the eddy binary.'

opts_AddOptional '--ol_nstd' 'ol_nstd_value' 'Number' 'Ol_nstd value to pass to the eddy binary If unspecified, no ol_nstd option is passed to the eddy binary'

opts_AddOptional '--extra-eddy-arg' 'extra_eddy_args' 'token' '(repeatable) Generic single token (no whitespace) argument to be passed to the run_eddy.sh script and subsequently to the eddy binary. To build a multi-token series of arguments, you can specify this parameter several times. E.g.  --extra-eddy-arg=--verbose --extra-eddy-arg=T will ultimately be translated to --verbose T when passed to the eddy binary.'

opts_AddOptional '--gpu' 'gpuString' 'Boolean' "Specify whether to use the non-GPU-enabled version of eddy. Defaults to using the GPU-enabled version of eddy i.e. True." "True"

opts_AddOptional '--cuda-version' 'cuda_version' 'X.Y' " If using the GPU-enabled version of eddy then this option can be used to specify which eddy_cuda binary version to use. If specified, FSLDIR/bin/eddy_cudaX.Y will be used."

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
DetailedOutlierStats=$(opts_StringToBool "$DetailedOutlierStatsString")
ReplaceOutliers=$(opts_StringToBool "$ReplaceOutliersString")
sepOffsMove=$(opts_StringToBool "$sepOffsMoveString")
rms=$(opts_StringToBool "$rmsString")
peas=$(opts_StringToBool "$peasString")
gpu=$(opts_StringToBool "$gpuString")

"$HCPPIPEDIR"/show_version

# Verify required environment variables are set and log value
log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FSLDIR

# Set other necessary variables, contingent on HCPPIPEDIR
HCPPIPEDIR_dMRI=${HCPPIPEDIR}/DiffusionPreprocessing/scripts

# Establish output directory paths
outdir=${StudyFolder}/${Subject}/${DWIName}

run_eddy_cmd=("${HCPPIPEDIR_dMRI}"/run_eddy.sh
    --nvoxhp="$nvoxhp"
    --ff="$ff_val"
    --wss="$DetailedOutlierStats"
    --repol="$ReplaceOutliers"
    --sep-offs-move="$sepOffsMove"
    --rms="$rms"
    --ol_nstd="$ol_nstd_value"
    --gpu="$gpu"
    --cuda-version="$cuda_version"
    --workingdir="$outdir"/eddy
    --peas="$peas"
    --fwhm="$fwhm_value"
    --resamp="$resamp_value")
for extra_eddy_arg in ${extra_eddy_args[@]+"${extra_eddy_args[@]}"}
do
    run_eddy_cmd+=(--extra-eddy-arg="$extra_eddy_arg")
done

log_Msg "About to issue the following command to invoke the run_eddy.sh script"
log_Msg "${run_eddy_cmd[*]}"
#runcmd can't be quoted, it depends on bash expanding it before word splitting
${runcmd} "${run_eddy_cmd[@]}"

log_Msg "Completed!"

