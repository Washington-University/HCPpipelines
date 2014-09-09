#!/bin/bash
#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # DiffPreprocPipeline_PreEddy.sh
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
# See the [LICENSE](https://github.com/Washington-University/Pipelines/blob/master/LICENCE.md) file
#
# ## Description
#
# This script, DiffPreprocPipeline_PreEddy.sh, implements the first part of the 
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
# See output of usage function: e.g. $ ./DiffPreprocPipeline_PreEddy.sh --help
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
    echo "  Perform the Pre-Eddy steps of the HCP Diffusion Preprocessing Pipeline"
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

    # report options
    echo "-- ${scriptName}: Specified Command-Line Options - Start --"
    echo "   StudyFolder: ${StudyFolder}"
    echo "   Subject: ${Subject}"
    echo "   PEdir: ${PEdir}"
    echo "   PosInputImages: ${PosInputImages}"
    echo "   NegInputImages: ${NegInputImages}"
    echo "   echospacing: ${echospacing}"
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

    if [ ! -e ${HCPPIPEDIR_dMRI}/basic_preproc.sh ]; then 
        usage
        echo "ERROR: HCPPIPEDIR_dMRI/basic_preproc.sh not found"
        exit 1
    fi

    if [ ! -e ${HCPPIPEDIR_dMRI}/run_topup.sh ]; then 
        usage
        echo "ERROR: HCPPIPEDIR_dMRI/run_topup.sh not found"
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
#  find the min between two numbers
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
    MissingFileFlag="EMPTY"  # String used in the input arguments to indicate that a complete series is missing
    b0dist=45                # Minimum distance in volums between b0s considered for preprocessing
    b0maxbval=50             # Volumes with a bvalue smaller than that will be considered as b0s

    # Get Command Line Options
    # 
    # Global Variables Set
    #  ${StudyFolder}    - Path to subject's data folder
    #  ${Subject}        - Subject ID  
    #  ${PEdir}          - Phase Encoding Direction, 1=LR/RL, 2=AP/PA
    #  ${PosInputImages} - @ symbol separated list of data with positive phase encoding direction
    #  ${NegInputImages} - @ symbol separated lsit of data with negative phase encoding direction 
    #  ${echospacing}    - echo spacing in msecs
    #  ${runcmd}         - Set to a user specifed command to use if user has requested
    #                      that commands be echo'd (or printed) instead of actually executed.
    #                      Otherwise, set to empty string.
    get_options $@

    # Validate environment variables
    validate_environment_vars $@

    # Establish tool name for logging
    log_SetToolName "DiffPreprocPipeline_PreEddy.sh"

    # Establish output directory paths
    outdir=${StudyFolder}/${Subject}/Diffusion
    outdirT1w=${StudyFolder}/${Subject}/T1w/Diffusion

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

    if [ ${PEdir} -eq 1 ]; then     # RL/LR phase encoding
        basePos="RL"
        baseNeg="LR"
    elif [ ${PEdir} -eq 2 ]; then   # AP/PA phase encoding
        basePos="AP"
        baseNeg="PA"
    else
        log_Msg "ERROR: Invalid Phase Encoding Directory (PEdir} specified: ${PEdir}"
        exit 1
    fi

    log_Msg "basePos: ${basePos}"
    log_Msg "baseNeg: ${baseNeg}"

    # copy positive raw data
    log_Msg "Copying positive raw data to working directory"
    PosInputImages=`echo ${PosInputImages} | sed 's/@/ /g'`
    log_Msg "PosInputImages: ${PosInputImages}"

    Pos_count=1
    for Image in ${PosInputImages}; do
	if [[ ${Image} =~ ^.*EMPTY.*$  ]]; then
	    Image=EMPTY
	fi
	
        if [ ${Image} = ${MissingFileFlag} ]; then	
            PosVols[${Pos_count}]=0
        else
	    PosVols[${Pos_count}]=`${FSLDIR}/bin/fslval ${Image} dim4`
	    absname=`${FSLDIR}/bin/imglob ${Image}`
	    ${runcmd} ${FSLDIR}/bin/imcp ${absname} ${outdir}/rawdata/${basePos}_${Pos_count}
	    ${runcmd} cp ${absname}.bval ${outdir}/rawdata/${basePos}_${Pos_count}.bval
	    ${runcmd} cp ${absname}.bvec ${outdir}/rawdata/${basePos}_${Pos_count}.bvec
        fi	
        Pos_count=$((${Pos_count} + 1))
    done

    # copy negative raw data
    log_Msg "Copying negative raw data to working directory"
    NegInputImages=`echo ${NegInputImages} | sed 's/@/ /g'`
    log_Msg "NegInputImages: ${NegInputImages}"

    Neg_count=1
    for Image in ${NegInputImages} ; do
	if [[ ${Image} =~ ^.*EMPTY.*$  ]]; then
	    Image=EMPTY
	fi
	
        if [ ${Image} = ${MissingFileFlag} ]; then
	    NegVols[${Neg_count}]=0
        else
	    NegVols[${Neg_count}]=`${FSLDIR}/bin/fslval ${Image} dim4`
	    absname=`${FSLDIR}/bin/imglob ${Image}`
	    ${runcmd} ${FSLDIR}/bin/imcp ${absname} ${outdir}/rawdata/${baseNeg}_${Neg_count}
	    ${runcmd} cp ${absname}.bval ${outdir}/rawdata/${baseNeg}_${Neg_count}.bval
	    ${runcmd} cp ${absname}.bvec ${outdir}/rawdata/${baseNeg}_${Neg_count}.bvec
        fi	
        Neg_count=$((${Neg_count} + 1))
    done

    # verify positive and negative datasets are provided in pairs
    
    if [ ${Pos_count} -ne ${Neg_count} ]; then
        log_Msg "Wrong number of input datasets! Make sure that you provide pairs of input filenames."
        log_Msg "If the respective file does not exist, use EMPTY in the input arguments."
        exit 1
    fi

    # Create two files for each phase encoding direction, that for each series contain the number of 
    # corresponding volumes and the number of actual volumes. The file e.g. RL_SeriesCorrespVolNum.txt
    # will contain as many rows as non-EMPTY series. The entry M in row J indicates that volumes 0-M 
    # from RLseries J has corresponding LR pairs. This file is used in basic_preproc to generate 
    # topup/eddy indices and extract corresponding b0s for topup. The file e.g. Pos_SeriesVolNum.txt 
    # will have as many rows as maximum series pairs (even unmatched pairs). The entry M N in row J 
    # indicates that the RLSeries J has its 0-M volumes corresponding to LRSeries J and RLJ has N 
    # volumes in total. This file is used in eddy_combine.
    log_Msg "Create two files for each phase encoding direction"

    Paired_flag=0
    for (( j=1; j<${Pos_count}; j++ )); do
        CorrVols=`min ${NegVols[${j}]} ${PosVols[${j}]}`
        ${runcmd} echo ${CorrVols} ${PosVols[${j}]} >> ${outdir}/eddy/Pos_SeriesVolNum.txt
        if [ ${PosVols[${j}]} -ne 0 ]; then
	    ${runcmd} echo ${CorrVols} >> ${outdir}/rawdata/${basePos}_SeriesCorrespVolNum.txt
	    if [ ${CorrVols} -ne 0 ]; then
	        Paired_flag=1
	    fi
        fi	
    done

    for (( j=1; j<${Neg_count}; j++ )) ; do
        CorrVols=`min ${NegVols[${j}]} ${PosVols[${j}]}`
        ${runcmd} echo ${CorrVols} ${NegVols[${j}]} >> ${outdir}/eddy/Neg_SeriesVolNum.txt
        if [ ${NegVols[${j}]} -ne 0 ]; then
	    ${runcmd} echo ${CorrVols} >> ${outdir}/rawdata/${baseNeg}_SeriesCorrespVolNum.txt
        fi	
    done

    if [ ${Paired_flag} -eq 0 ]; then
        log_Msg "Wrong Input! No pairs of phase encoding directions have been found!"
        log_Msg "At least one pair is needed!"
        exit 1
    fi

    log_Msg "Running Basic Preprocessing"
    ${runcmd} ${HCPPIPEDIR_dMRI}/basic_preproc.sh ${outdir} ${echospacing} ${PEdir} ${b0dist} ${b0maxbval}

    log_Msg "Running Topup"
    ${runcmd} ${HCPPIPEDIR_dMRI}/run_topup.sh ${outdir}/topup

    log_Msg "Completed"
    exit 0
}

#
# Invoke the main function to get things started
#
main $@
