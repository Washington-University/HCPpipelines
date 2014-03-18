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
# [Human Connectome Project][HCP] (HCP) Pipeline Tools
#
# ## License
#
# * Human Connectome Project Pipeline Tools = the "Software"
# * This Software is distributed "AS IS" without warranty of any kind, either 
# * expressed or implied, including, but not limited to, the implied warranties
# * of merchantability and fitness for a particular purpose.
#
# ### TODO
#
# Find out what actual license terms are to be applied. Commercial use allowed? 
# If so, this would likely violate FSL terms.
#
# ## Description
#
# This script, DiffPreprocPipeline_Eddy.sh, implements the second part of the 
# Preprocessing Pipeline for diffusion MRI describe in [Glasser et al. 2013][GlasserEtAl].
# The entire Preprocessing Pipeline for diffusion MRI is split into pre-eddy, eddy,
# and post-eddy scripts so that the running of eddy processing can be submitted 
# to a cluster scheduler to take advantage of running on a set of GPUs without forcing
# the entire diffusion preprocessing to occur on a GPU enabled system.  This particular
# script implements the eddy part of the diffusion preprocessing.
#
# ## Prerequisite Installed Software for the Diffusion Preprocessing Pipeline
#
# * [FSL][FSL] - FMRIB's Software Library - Version 5.0.6 or later.
#                FSL's environment setup script must also be sourced
#
# * [FreeSurfer][FreeSurfer] - Version 5.2 or greater
#
# * gradunwarp - HCP customized version of [gradunwarp][gradunwarp]. The HCP customized 
#   version of gradunwarp is in the src/gradient_unwarping directory in this 
#   distribution.  _It must be installed separately with its prerequisites and the 
#   PATH environment variable must be setup so that gradient_unwarp.py is found_. 
#
# ## Prerequisite Environment Variables
#
# See output of usage function: e.g. $ ./DiffPreprocPipeline_Eddy.sh --help
# 
# <!-- References -->
# [HCP]: http://www.humanconnectome.org
# [GlasserEtAl]: http://www.ncbi.nlm.nih.gov/pubmed/23668970
# [FSL]: http://fsl.fmrib.ox.ac.uk
# [FreeSurfer]: http://freesurfer.net
# [gradunwarp]: https://github.com/ksubramz/gradunwarp.git
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
#  ${runcmd}      - Set to a user specifed command to use if user has requested
#                   that commands be echo'd (or printed) instead of actually executed.
#                   Otherwise, set to empty string.
#  
get_options() {
    local arguments=($@)

    # initialize global output variables
    unset StudyFolder
    unset Subject
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
    echo "-- Specified Command-Line Options - Start --"
    echo "StudyFolder: ${StudyFolder}"
    echo "Subject: ${Subject}"
    echo "runcmd: ${runcmd}"
    echo "-- Specified Command-Line Options - End --"
}

#
# Function Description
#  Validate necessary environment variables
#
validate_environment_vars() {
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
    echo "-- Environment Variables Used - Start --"
    echo "HCPPIPEDIR_dMRI: ${HCPPIPEDIR_dMRI}"
    echo "-- Environment Variables Used - End --"
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
    #  ${runcmd} - Set to a user specifed command to use if user has requested
    #              that commands be echo'd (or printed) instead of actually executed.
    #              Otherwise, set to empty string.
    get_options $@

    # Validate environment variables
    validate_environment_vars

    # Establish tool name for logging 
    log_SetToolName "DiffPreprocPipeline_Eddy.sh"

    # Establish output directory paths
    outdir=${StudyFolder}/${Subject}/Diffusion

    log_Msg "Running Eddy"
    ${runcmd} ${HCPPIPEDIR_dMRI}/run_eddy.sh -g -w ${outdir}/eddy

    log_Msg "Completed"
    exit 0
}

#
# Invoke the main function to get things started
#
main $@