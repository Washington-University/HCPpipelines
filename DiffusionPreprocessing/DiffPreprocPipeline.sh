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
# This script, DiffPreprocPiepline.sh, implements the Diffusion MRI Preprocessing 
# Pipeline described in [Glasser et al. 2013][GlasserEtAl]. It generates the 
# "data" directory that can be used as input to the fibre orientation estimation 
# scripts.
# 
# ## Prerequisite Installed Software
#
# * [FSL][FSL] - FMRIB's Software Library - Version 5.0.6 or later
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
# See output of usage function: e.g. $./DiffPreprocPipeline.sh --help




########################################## OUTPUT DIRECTORIES ####################################################

## NB: NO assumption is made about the input paths with respect to the output directories - they can be totally different.  All input are taken directly from the input variables without additions or modifications.

# Output path specifiers:
#
# ${StudyFolder} is an input parameter
# ${Subject} is an input parameter

# Main output directories
# DiffFolder=${StudyFolder}/${Subject}/Diffusion
# T1wDiffFolder=${StudyFolder}/${Subject}/T1w/Diffusion

# All outputs are within the directory: ${StudyFolder}/${Subject}
# The full list of output directories are the following
#    $DiffFolder/rawdata
#    $DiffFolder/topup    
#    $DiffFolder/eddy
#    $DiffFolder/data
#    $DiffFolder/reg
#    $T1wDiffFolder

# Also assumes that T1 preprocessing has been carried out with results in ${StudyFolder}/${Subject}/T1w

########################################## SUPPORT FUNCTIONS #####################################################

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

