#!/bin/bash
#~ND~FORMAT~MARKDOWN~
#~ND~START~
# 
# # DiffPreprocPipeline_Eddy.sh
# 
# ## Copyright Notice
# 
# Copyright (C) 2012-2014 The Human Connectome Project
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
# See the [LICENSE](https://github.com/Washington-University/Pipelines/blob/master/LICENCE.md) file
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
# ## Prerequisite Installed Software (for the entire Diffusion Preprocessing Pipeline)
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

# Setup this script such that if any command exits with a non-zero value, the 
# script itself exits and does not attempt any further processing.
set -e

# Load Function Libraries
source ${HCPPIPEDIR}/global/scripts/log.shlib     # log_ functions  
source ${HCPPIPEDIR}/global/scripts/version.shlib # version_ functions 

#
# Function Description
#  Show usage information for this script
#
usage() {
    local scriptName=$(basename ${0})
    echo ""
    echo "  Perform the Eddy step of the HCP Diffusion Preprocessing Pipeline"
    echo ""
    echo "  Usage: ${scriptName} <options>"
    echo ""
    echo "  Options: [ ] = optional; < > = user supplied value"
    echo ""
    echo "    [--help] : show usage information and exit with non-zero return code"
    echo ""
    echo "    [--version] : show version information and exit with 0 as return code"
    echo ""
    echo "    [--detailed-outlier-stats=True] : produce detailed outlier statistics from eddy after each iteration"
    echo "      Note: This option has no effect if the GPU-enabled version of eddy is not used."
    echo ""
    echo "    [--replace-outliers=True] : ask eddy to replace any outliers it detects by their expectations"
    echo "      Note: This option has no effect if the GPU-enabled version of eddy is not used."
    echo ""
    echo "    --path=<study-path>"
    echo "    : path to subject's data folder"
    echo ""
    echo "    --subject=<subject-id>"
    echo "    : Subject ID"
    echo ""
    echo "    [--printcom=<print-command>]"
    echo "    : Use the specified <print-command> to echo or otherwise output the commands"
    echo "      that would be executed instead of actually running them"
    echo "      --printcom=echo is intended for testing purposes"
    echo ""
    echo "  Return code:"
    echo ""
    echo "    0 if help was not requested, all parameters were properly formed, and processing succeeded"
    echo "    Non-zero otherwise - malformed parameters, help requested or processing failure was detected"
    echo ""
    echo "  Required Environment Variables:"
    echo ""
    echo "    HCPPIPEDIR"
    echo ""
    echo "      The home directory for the version of the HCP Pipeline Tools product"
    echo "      being used."
    echo ""
    echo "      Example value: /nrgpackages/tools.release/hcp-pipeline-tools-3.0"
    echo ""
    echo "    HCPPIPEDIR_dMRI"
    echo ""
    echo "      Location of Diffusion MRI sub-scripts that are used to carry out some of the"
    echo "      steps of the Diffusion Preprocessing Pipeline"
    echo ""
    echo "      Example value: ${HCPPIPEDIR}/DiffusionPreprocessing/scripts"
    echo ""
}

#
# Function Description
#  Get the command line options for this script
#
# Global Output Variables
#  ${StudyFolder} - Path to subject's data folder
#  ${Subject}     - Subject ID
#  ${DetailedOutlierStats} - If True (and GPU-enabled eddy program is used), then ask
#                            eddy to produce detailed statistics about outliers after each
#                            iteration.
#  ${ReplaceOutliers} - If True (and GPU-enabled eddy program is used), then ask eddy
#                       to replace any outliers it detects by their expectations
#  ${runcmd}      - Set to a user specifed command to use if user has requested
#                   that commands be echo'd (or printed) instead of actually executed.
#                   Otherwise, set to empty string.
#  
get_options() {
    local scriptName=$(basename ${0})
    local arguments=($@)

    # initialize global output variables
    unset StudyFolder
    unset Subject
    DetailedOutlierStats="False"
    ReplaceOutliers="False"
    runcmd=""

    # parse arguments
    local index=0
    local numArgs=${#arguments[@]}
    local argument

    while [ ${index} -lt ${numArgs} ]; do
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
                StudyFolder=${argument/*=/""}
                index=$(( index + 1 ))
                ;;
            --subject=*)
                Subject=${argument/*=/""}
                index=$(( index + 1 ))
                ;;
            --detailed-outlier-stats=*)
                DetailedOutlierStats=${argument/*=/""}
                index=$(( index + 1 ))
                ;;
            --replace-outliers=*)
                ReplaceOutliers=${argument/*=/""}
                index=$(( index + 1 ))
                ;;
            --printcom=*)
                runcmd=${argument/*=/""}
                index=$(( index + 1 ))
                ;;
            *)
                usage
                echo "ERROR: Unrecognized Option: ${argument}"
                exit 1
                ;;
        esac
    done

    # check required parameters
    if [ -z ${StudyFolder} ]; then
        usage
        echo "ERROR: <study-path> not specified"
        exit 1
    fi

    if [ -z ${Subject} ]; then
        usage
        echo "ERROR: <subject-id> not specified"
        exit 1
    fi

    # report options
    echo "-- ${scriptName}: Specified Command-Line Options - Start --"
    echo "   StudyFolder: ${StudyFolder}"
    echo "   Subject: ${Subject}"
    echo "   DetailedOutlierStats: ${DetailedOutlierStats}"
    echo "   ReplaceOutliers: ${ReplaceOutliers}"
    echo "   runcmd: ${runcmd}"
    echo "-- ${scriptName}: Specified Command-Line Options - End --"
}

#
# Function Description
#  Validate necessary environment variables
#
validate_environment_vars() {
    local scriptName=$(basename ${0})
    # validate
    if [ -z ${HCPPIPEDIR_dMRI} ]; then
        usage
        echo "ERROR: HCPPIPEDIR_dMRI environment variable not set"
        exit 1
    fi

    if [ ! -e ${HCPPIPEDIR_dMRI}/run_eddy.sh ]; then 
        usage
        echo "ERROR: HCPPIPEDIR_dMRI/run_eddy.sh not found"
        exit 1
    fi

    # report
    echo "-- ${scriptName}: Environment Variables Used - Start --"
    echo "   HCPPIPEDIR_dMRI: ${HCPPIPEDIR_dMRI}"
    echo "-- ${scriptName}: Environment Variables Used - End --"
}

#
# Function Description
#  Main processing of script
#
#  Gets user specified command line options, runs Eddy step of Diffusiong Preprocessing
#
main() {
    # Get Command Line Options
    #
    # Global Variables Set
    #  ${StudyFolder} - Path to subject's data folder
    #  ${Subject}     - Subject ID
    #  ${DetailedOutlierStats} - If True (and GPU-enabled eddy program is used), then ask
    #                            eddy to produce detailed statistics about outliers after each
    #                            iteration.
    #  ${ReplaceOutliers} - If True (and GPU-enabled eddy program is used), then ask eddy
    #                       to replace any outliers it detects by their expectations
    #  ${runcmd} - Set to a user specifed command to use if user has requested
    #              that commands be echo'd (or printed) instead of actually executed.
    #              Otherwise, set to empty string.
    get_options $@

    # Validate environment variables
    validate_environment_vars $@

    # Establish tool name for logging 
    log_SetToolName "DiffPreprocPipeline_Eddy.sh"

    # Establish output directory paths
    outdir=${StudyFolder}/${Subject}/Diffusion

    # Determine stats_option value to pass to run_eddy.sh script
    if [ "${DetailedOutlierStats}" = "True" ]; then
        stats_option="--wss"
    else
        stats_option=""
    fi

    # Determine replace_outliers_option value to pass to run_eddy.sh script
    if [ "${ReplaceOutliers}" = "True" ]; then
        replace_outliers_option="--repol"
    else
        replace_outliers_option=""
    fi

    log_Msg "Running Eddy"

    ${runcmd} ${HCPPIPEDIR_dMRI}/run_eddy.sh ${stats_option} ${replace_outliers_option} -g -w ${outdir}/eddy

    log_Msg "Completed"
    exit 0
}

#
# Invoke the main function to get things started
#
main $@
