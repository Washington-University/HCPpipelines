#!/bin/bash
#~ND~FORMAT~MARKDOWN~
#~ND~START~
# 
# # run_eddy.sh
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
usage() {
    local scriptName=$(basename ${0})
    echo ""
    echo "  Usage: ${scriptName} <options>"
    echo ""
    echo "  Options: [ ] = optional; < > = user supplied value"
    echo ""
    echo "    [-h | --help] : show usage information and exit with non-zero return code"
    echo ""
    echo "    [-g | --gpu]  : attempt to use the GPU-enabled version of eddy"
    echo "                    (eddy.gpu).  If the GPU-enabled version is not"
    echo "                    found or returns a non-zero exit code, then"
    echo "                    this script \"falls back\" to using the standard"
    echo "                    version of eddy."
    echo ""
    echo "    -w <working-dir>           | "
    echo "    -w=<working-dir>           | "
    echo "    --workingdir <working-dir> | "
    echo "    --workingdir=<working-dir> : the working directory (REQUIRED)"
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
#  ${useGpuVersion} - Set to "True" if use has requested an attempt to use
#                     the GPU-enabled version of eddy
#  ${workingdir}    - User specified working directory
#
get_options() {
    local scriptName=$(basename ${0})
    local arguments=($@)

    # global output variables
    useGpuVersion="False"
    unset workingdir

    # parse arguments
    local index=0
    local numArgs=${#arguments[@]}
    local argument

    while [ ${index} -lt ${numArgs} ]; do
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
            -w | --workingdir)
                workingdir=${arguments[$(( index + 1 ))]}
                index=$(( index + 2 ))
                ;;
            -w=* | --workingdir=*)
                workingdir=${argument/*=/""}
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
    echo "-- ${scriptName}: Specified Command-Line Options - End --"
}

#
# Function Description
#  Validate necessary environment variables
#
validate_environment_vars() {
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
    #  ${useGpuVersion} - Set to "True" if use has requested an attempt to use
    #                     the GPU-enabled version of eddy
    #  ${workingdir}    - User specified working directory
    get_options $@

    # Validate environment variables
    validate_environment_vars $@

    # Establish tool name for logging
    log_SetToolName "run_eddy.sh"

    # Determine eddy executable to use
    #
    #  If the user has asked us to try to use the GPU-enabled version of eddy,
    #  then we check to see if that GPU-enabled version exists.  If it does,
    #  we'll try to use it. Otherwise, we'll fall back to using the standard
    #  (CPU) version of eddy.
    #
    #  If the user has not requested us to try to use the GPU-enabled version,
    #  then we don't bother looking for it or trying to use it.
    gpuEnabledEddy="${FSLDIR}/bin/eddy.gpu"
    stdEddy="${FSLDIR}/bin/eddy"

    if [ "${useGpuVersion}" = "True" ]; then
        log_Msg "User requested GPU-enabled version of eddy"
        if [ -e ${gpuEnabledEddy} ]; then
            log_Msg "GPU-enabled version of eddy found"
            eddyExec="${gpuEnabledEddy}"
        else
            log_Msg "GPU-enabled version of eddy NOT found"
            eddyExec="${stdEddy}"
        fi
    else
        log_Msg "User did not request GPU-enabled version of eddy"
        eddyExec="${stdEddy}"
    fi

    log_Msg "eddy executable to use: ${eddyExec}"

    # Main processing - Run eddy

    topupdir=`dirname ${workingdir}`/topup

    ${FSLDIR}/bin/imcp ${topupdir}/nodif_brain_mask ${workingdir}/

    ${eddyExec} --imain=${workingdir}/Pos_Neg --mask=${workingdir}/nodif_brain_mask --index=${workingdir}/index.txt --acqp=${workingdir}/acqparams.txt --bvecs=${workingdir}/Pos_Neg.bvecs --bvals=${workingdir}/Pos_Neg.bvals --fwhm=0 --topup=${topupdir}/topup_Pos_Neg_b0 --out=${workingdir}/eddy_unwarped_images --flm=quadratic -v #--resamp=lsr #--session=${workingdir}/series_index.txt
    eddyReturnValue=$?

    # Another fallback. 
    #
    #  If we were trying to use the GPU-enabled version of eddy, but it 
    #  returned a failure code, then report that the GPU-enabled eddy 
    #  failed and use the standard version of eddy.
    if [ "${eddyExec}" = "${gpuEnabledEddy}" ]; then
        if [ ${eddyReturnValue} -ne 0 ]; then
            log_Msg "Tried to run GPU-enabled eddy, ${eddyExec}, as requested."
            log_Msg "That attempt failed with return code: ${eddyReturnValue}"
            log_Msg "Running standard version of eddy, ${stdEddy}, instead."
            ${stdEddy} --imain=${workingdir}/Pos_Neg --mask=${workingdir}/nodif_brain_mask --index=${workingdir}/index.txt --acqp=${workingdir}/acqparams.txt --bvecs=${workingdir}/Pos_Neg.bvecs --bvals=${workingdir}/Pos_Neg.bvals --fwhm=0 --topup=${topupdir}/topup_Pos_Neg_b0 --out=${workingdir}/eddy_unwarped_images --flm=quadratic -v #--resamp=lsr #--session=${workingdir}/series_index.txt
            eddyReturnValue=$?
        fi
    fi

    log_Msg "Completed with return value: ${eddyReturnValue}"
    exit ${eddyReturnValue}
}

#
# Invoke the main function to get things started
#
main $@
