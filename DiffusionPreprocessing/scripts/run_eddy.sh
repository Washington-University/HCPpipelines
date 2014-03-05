#!/bin/bash
#set -e

#
# Script Description:
#  This script runs FSL's eddy command as part of the Human Connectome Project's 
#  Diffusion Pre-Processing
# 
# Assumptions:
#
#  The FMRIB Software Library (FSL) is installed and available for use.
#  (See http://fsl.fmrib.ox.ac.uk/fsl).
#
#  The environment variable FSLDIR has been set to reflect the installed
#  FSL "home" directory.
#
# Author(s):
#  Stamatios Sotiropoulos - Analysis Group, FMRIB Centre
#  Saad Jbabdi - Analysis Group, FMRIB Center
#  Jesper Andersson - Analysis Group, FMRIB Center
#  Matthew F. Glasser - Anatomy and Neurobiology, Washington University 
#  Timothy B. Brown (TBB) - Radiological Sciences, Washington University 
#  
# Notes:
#  * 2014.03.05 - TBB added code to allow the user to request the use of the 
#                 GPU-enabled version of eddy and "fall back" to using the 
#                 standard version if the GPU-enabled version is not found 
#                 or does not work.
#  

#
# Function Description:
#  Show usage information for this script
#
usage() {
    local scriptName=$(basename ${0})
    echo ""
    echo "  Usage: ${scriptName} [-h] [-g] -w <working-dir>"
    echo ""
    echo "    -h            = If specified, this usage information is"
    echo "                    echoed."
    echo "    -g            = If specifed, an attempt is made to use the"
    echo "                    GPU-enabled version of eddy (eddy.gpu)."
    echo "                    If the GPU-enabled version is not found,"
    echo "                    the script \"falls back\" to using the"
    echo "                    standard version of eddy."
    echo "    <working-dir> = The working directory (REQUIRED)"
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
    unset useGpuVersion
    while getopts "hgw:" opt; do
        case ${opt} in
            h)
                usage
                ;;
            g)
                useGpuVersion="True"
                ;;
            w)
                workingdir=${OPTARG}
                ;;
        esac
    done
    shift $((OPTIND-1))
    
    if [ -z ${workingdir} ]; then
        usage
        echo "  Error: <working-dir> (REQUIRED) not specified"
        echo "         Exiting without running eddy"
        exit
    else
        echo "  User specified <working-dir> = ${workingdir}"
    fi
}

#
# Description:
#  Script start
#
echo -e "\n START: eddy"

# Get Command Line Options
#
# Global Variables Set:
#  ${useGpuVersion} - Set to "True" if use has requested an attempt to use
#                     the GPU-enabled version of eddy
#  ${workingdir}    - User specified working directory
get_options $@

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
    echo "  User requested GPU-enabled version of eddy"
    if [ -e ${gpuEnabledEddy} ]; then
        echo "  GPU-enabled version of eddy found"
        eddyExec="${gpuEnabledEddy}"
    else
        echo "  GPU-enabled version of eddy NOT found"
        eddyExec="${stdEddy}"
    fi
else
    echo "  User did not request GPU-enabled version of eddy"
    eddyExec="${stdEddy}"
fi

echo "  eddy executable to use: ${eddyExec}"

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
        echo "  Tried to run GPU-enabled eddy, ${eddyExec}, as requested."
        echo "  That attempt failed with return code: ${eddyReturnValue}"
        echo "  Running standard version of eddy, ${stdEddy}, instead."
        ${stdEddy} --imain=${workingdir}/Pos_Neg --mask=${workingdir}/nodif_brain_mask --index=${workingdir}/index.txt --acqp=${workingdir}/acqparams.txt --bvecs=${workingdir}/Pos_Neg.bvecs --bvals=${workingdir}/Pos_Neg.bvals --fwhm=0 --topup=${topupdir}/topup_Pos_Neg_b0 --out=${workingdir}/eddy_unwarped_images --flm=quadratic -v #--resamp=lsr #--session=${workingdir}/series_index.txt
    fi
fi

echo -e "\n END: eddy"

