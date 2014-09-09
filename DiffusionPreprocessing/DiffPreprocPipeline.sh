#!/bin/bash
#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # DiffPreprocPipeline.sh
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
# * Timothy B. Brown, Neuroinfomatics Research Group, Washington University in St. Louis
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
# See output of usage function: e.g. <code>$ ./DiffPreprocPipeline.sh --help</code>
# 
# ## Output Directories
# 
# *NB: NO assumption is made about the input paths with respect to the output directories - they can be totally different.
# All inputs are taken directly from the input variables without additions or modifications.*
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
# Also assumes that T1 preprocessing has been carried out with results in <code>${StudyFolder}/${Subject}/T1w</code>
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

# Setup this script such that if any command exits with a non-zero value, the 
# script itself exits and does not attempt any further processing.
set -e

# Load Function Libraries
source ${HCPPIPEDIR}/global/scripts/log.shlib     # log_ functions
source ${HCPPIPEDIR}/global/scripts/version.shlib # version_ functions

#
# Function Descripton
#  Show usage information for this script
#
usage() {
    local scriptName=$(basename ${0})
    echo ""
    echo "  Perform the steps of the HCP Diffusion Preprocessing Pipeline"
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
    echo "    --PEdir=<phase-encoding-dir>"
    echo "    : phase encoding direction: 1=LR/RL, 2=AP/PA"
    echo ""
    echo "    --posData=<positive-phase-encoding-data>"
    echo "    : @ symbol separated list of data with positive phase encoding direction"
    echo "      e.g. dataRL1@dataRL2@...dataRLN"
    echo ""
    echo "    --negData=<negative-phase-encoding-data>"
    echo "    : @ symbol separated list of data with negative phase encoding direction"
    echo "      e.g. dataLR1@dataLR2@...dataLRN"
    echo ""
    echo "    --echospacing=<echo-spacing>"
    echo "    : Echo spacing in msecs"
    echo ""
    echo "    --gdcoeffs=<path-to-gradients-coefficients-file>"
    echo "    : path to file containing coefficients that describe spatial variations"
    echo "      of the scanner gradients. Use --gdcoeffs=NONE if not available"
    echo ""
    echo "    [--printcom=<print-command>]"
    echo "    : Use the specified <print-command> to echo or otherwise output the commands"
    echo "      that would be executed instead of actually running them"
    echo "      --printcom=echo is intended for testing purposes"
    echo ""
    echo "  Return Code:"
    echo ""
    echo "    0 if help was not requested, all parameters were properly formed, and processing succeeded"
    echo "    Non-zero otherwise - malformed parameters, help requested, or processing failure was detected"
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
    echo "    FSLDIR"
    echo ""
    echo "      The home directory for FSL"
    echo ""
    echo "    FREESURFER_HOME"
    echo ""
    echo "      Home directory for FreeSurfer"
    echo ""
    echo "    PATH"
    echo ""
    echo "      Must be set to find HCP Customized version of gradient_unwarp.py"
    echo ""
}

#
# Function Description
#  Get the command line options for this script
#
# Global Output Variables
#  ${StudyFolder}    - Path to subject's data folder
#  ${Subject}        - Subject ID
#  ${PEdir}          - Phase Encoding Direction, 1=LR/RL, 2=AP/PA
#  ${PosInputImages} - @ symbol separated list of data with positive phase encoding direction
#  ${NegInputImages} - @ symbol separated lsit of data with negative phase encoding direction 
#  ${echospacing}    - echo spacing in msecs
#  ${GdCoeffs}       - Path to file containing coefficients that describe spatial variations
#                      of the scanner gradients. Use NONE if not available.
#  ${runcmd}         - Set to a user specifed command to use if user has requested
#                      that commands be echo'd (or printed) instead of actually executed.
#                      Otherwise, set to empty string.
#
get_options() {
    local scriptName=$(basename ${0})
    local arguments=($@)
    
    # initialize global output variables
    unset StudyFolder
    unset Subject
    unset PEdir
    unset PosInputImages
    unset NegInputImages
    unset echospacing
    unset GdCoeffs
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
            --PEdir=*)
                PEdir=${argument/*=/""}
                index=$(( index + 1 ))
                ;;
            --posData=*)
                PosInputImages=${argument/*=/""}
                index=$(( index + 1 ))
                ;;
            --negData=*)
                NegInputImages=${argument/*=/""}
                index=$(( index + 1 ))
                ;;
            --echospacing=*)
                echospacing=${argument/*=/""}
                index=$(( index + 1 ))
                ;;
            --gdcoeffs=*)
                GdCoeffs=${argument/*=/""}
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

    if [ -z ${PEdir} ]; then
        usage
        echo "ERROR: <phase-encoding-dir> not specified"
        exit 1
    fi

    if [ -z ${PosInputImages} ]; then
        usage
        echo "ERROR: <positive-phase-encoded-data> not specified"
        exit 1
    fi

    if [ -z ${NegInputImages} ]; then
        usage
        echo "ERROR: <negative-phase-encoded-data> not specified"
        exit 1
    fi

    if [ -z ${echospacing} ]; then
        usage
        echo "ERROR: <echo-spacing> not specified"
        exit 1
    fi

    if [ -z ${GdCoeffs} ]; then
        usage
        echo "ERROR: <path-to-gradients-coefficients-file> not specified"
        exit 1
    fi

    # report options
    echo "-- ${scriptName}: Specified Command-Line Options - Start --"
    echo "   StudyFolder: ${StudyFolder}"
    echo "   Subject: ${Subject}"
    echo "   PEdir: ${PEdir}"
    echo "   PosInputImages: ${PosInputImages}"
    echo "   NegInputImages: ${NegInputImages}"
    echo "   echospacing: ${echospacing}"
    echo "   GdCoeffs: ${GdCoeffs}"
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

    if [ ! -e ${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline_PreEddy.sh ]; then 
        usage
        echo "ERROR: HCPPIPEDIR/DiffusionPreprocessing/DiffPreprocPipeline_PreEddy.sh not found"
        exit 1
    fi

    if [ ! -e ${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline_Eddy.sh ]; then 
        usage
        echo "ERROR: HCPPIPEDIR/DiffusionPreprocessing/DiffPreprocPipeline_Eddy.sh not found"
        exit 1
    fi

    if [ ! -e ${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline_PostEddy.sh ]; then 
        usage
        echo "ERROR: HCPPIPEDIR/DiffusionPreprocessing/DiffPreprocPipeline_PostEddy.sh not found"
        exit 1
    fi

    if [ -z ${FSLDIR} ]; then
        usage
        echo "ERROR: FSLDIR environment variable not set"
        exit 1
    fi

    # report
    echo "-- ${scriptName}: Environment Variables Used - Start --"
    echo "   HCPPIPEDIR_dMRI: ${HCPPIPEDIR_dMRI}"
    echo "   FSLDIR: ${FSLDIR}"
    echo "-- ${scriptName}: Environment Variables Used - End --"
}

#
# Function Description
#  Main processing of script
#
main() {
    # Get Command Line Options
    # 
    # Global Variables Set
    #  ${StudyFolder}    - Path to subject's data folder
    #  ${Subject}        - Subject ID  
    #  ${PEdir}          - Phase Encoding Direction, 1=LR/RL, 2=AP/PA
    #  ${PosInputImages} - @ symbol separated list of data with positive phase encoding direction
    #  ${NegInputImages} - @ symbol separated lsit of data with negative phase encoding direction 
    #  ${echospacing}    - echo spacing in msecs
    #  ${GdCoeffs}       - Path to file containing coefficients that describe spatial variations
    #                      of the scanner gradients. Use NONE if not available.
    #  ${runcmd}         - Set to a user specifed command to use if user has requested
    #                      that commands be echo'd (or printed) instead of actually executed.
    #                      Otherwise, set to empty string.
    get_options $@

    # Validate environment variables
    validate_environment_vars $@

    # Establish tool name for logging
    log_SetToolName "DiffPreprocPipeline.sh"

    log_Msg "Invoking Pre-Eddy Steps"
    ${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline_PreEddy.sh \
        --path=${StudyFolder} \
        --subject=${Subject} \
        --PEdir=${PEdir} \
        --posData=${PosInputImages} \
        --negData=${NegInputImages} \
        --echospacing=${echospacing} \
        --printcom="${runcmd}"
    
    log_Msg "Invoking Eddy Step"
    ${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline_Eddy.sh \
        --path=${StudyFolder} \
        --subject=${Subject} \
        --printcom="${runcmd}"

    log_Msg "Invoking Post-Eddy Steps"
    ${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline_PostEddy.sh \
        --path=${StudyFolder} \
        --subject=${Subject} \
        --gdcoeffs=${GdCoeffs} \
        --printcom="${runcmd}"

    log_Msg "Completed"
    exit 0
}

#
# Invoke the main function to get things started
#
main $@

