#!/bin/bash 

# Intensity normalisation, and bias field correction, and optional Jacobian modulation, applied to fMRI images (all inputs must be in fMRI space)

#  This code is released to the public domain.
#
#  Matt Glasser, Washington University in St Louis
#  Mark Jenkinson, FMRIB Centre, University of Oxford
#  2011-2012
#
#  Neither Washington University in St Louis, the FMRIB Centre, the
#  University of Oxford, nor any of their employees imply any warranty
#  of usefulness of this software for any purpose, and do not assume
#  any liability for damages, incidental or otherwise, caused by any
#  use of this document.

# Requirements for this script
#  installed versions of: FSL
#  environment: HCPPIPEDIR, FSLDIR

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------


set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source ${HCPPIPEDIR}/global/scripts/tempfiles.shlib


opts_SetScriptDescription "Script to perform Intensity Normalization" 

opts_AddMandatory '--infmri' 'InputfMRI' 'data' "input fmri data"

opts_AddMandatory '--biasfield' 'BiasField' 'image' "bias field or already registered to fmri data"

opts_AddMandatory '--jacobian' 'Jacobian' 'image' "jacobian image or  already registered to fmri data"

opts_AddMandatory '--brainmask' 'BrainMask' 'mask' "brain mask in fmri space"

opts_AddMandatory '--usejacobian' 'UseJacobian' 'true or false' "apply jacobian modulation: true/false"

#Optional Args
opts_AddOptional '--ofmri' 'OutputfMRI' 'image' "output basename for fmri data" "$FSLDIR/bin/remove_ext"

opts_AddOptional '--inscout' 'ScoutInput' 'image' "input name for scout image (pre-sat EPI)"

opts_AddOptional '--oscout' 'ScoutOutput' 'image' "output name for normalized scout image"

opts_AddOptional '--workingdir' 'WD' 'path' "working dir" ""

opts_AddOptional '--fmrimask' 'fMRIMask' '' "type of mask to use for generating final fMRI output volume: 
        "T1_fMRI_FOV" (default) - T1w brain based mask combined with fMRI FOV mask
        "T1_DILATED_fMRI_FOV" - once dilated T1w brain based mask combined with fMRI FOV
        "T1_DILATED2x_fMRI_FOV" - twice dilated T1w brain based mask combined with fMRI FOV
        "fMRI_FOV" - fMRI FOV mask only (i.e., voxels having spatial coverage at all time points)" "T1_fMRI_FOV"

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

log_Check_Env_Var FSLDIR


################################################### OUTPUT FILES #####################################################

# ${OutputfMRI}  (compulsory)
# ${ScoutOutput}  (optional)

verbose_red_echo "---> Intensity normalization"

verbose_echo " "
verbose_echo " Using parameters ..."
verbose_echo "          --infmri: ${InputfMRI}"
verbose_echo "       --biasfield: ${BiasField}"
verbose_echo "        --jacobian: ${Jacobian}"
verbose_echo "       --brainmask: ${BrainMask}"
verbose_echo "           --ofmri: ${OutputfMRI}"
verbose_echo "         --inscout: ${ScoutInput}"
verbose_echo "          --oscout: ${ScoutOutput}"
verbose_echo "     --usejacobian: ${UseJacobian}"
verbose_echo "        --fmrimask: ${fMRIMask}"
verbose_echo " "

OutputfMRI=$($FSLDIR/bin/remove_ext $OutputfMRI)

#sanity check the jacobian option
if [[ "$UseJacobian" != "true" && "$UseJacobian" != "false" ]]
then
    echo "Error: The --usejacobian option must be 'true' or 'false'"
    exit 1
fi

jacobiancom=""
if [[ $UseJacobian == "true" ]] ; then
    jacobiancom="-mul $Jacobian"
fi

if [[ "$WD" == "" ]]
then
    WD="${OutputfMRI}.wdir"
fi

biascom=""
if [[ "$BiasField" != "" ]]
then
    ${FSLDIR}/bin/fslmaths ${BiasField} -dilall ${BiasField}_dilated
    biascom="-div ${BiasField}_dilated"
fi

# sanity checking
if [ X${ScoutInput} != X ] ; then
    if [ X${ScoutOutput} = X ] ; then
      echo "Error: Must supply an output name for the normalised scout image"
      exit 1
    fi
fi

echo " "
echo " START: IntensityNormalization"

mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = $(pwd)" >> $WD/log.txt
echo "date: $(date)" >> $WD/log.txt
echo " " >> $WD/log.txt

########################################## DO WORK ##########################################

FinalMask=$(${FSLDIR}/bin/remove_ext ${InputfMRI})_finalmask
T1FOVMask=$(${FSLDIR}/bin/remove_ext ${InputfMRI})_T1FOVmask
${FSLDIR}/bin/fslmaths ${BrainMask} -bin -mas ${InputfMRI}_mask ${T1FOVMask}

# Use the requested fMRI mask 

if [ "${fMRIMask}" = "T1_fMRI_FOV" ] ; then
    # FinalMask is a combination of the FS-derived brainmask, and the spatial coverage mask that captures the
    # voxels that have data available at *ALL* time points (derived in OneStepResampling)
    ${FSLDIR}/bin/imcp ${T1FOVMask} ${FinalMask}

elif [ "${fMRIMask}" = "T1_DILATED_fMRI_FOV" ] ; then
    # FinalMask is a combination of once dilated FS-derived brainmask, and the spatial coverage mask that captures the
    # voxels that have data available at *ALL* time points (derived in OneStepResampling)
    ${FSLDIR}/bin/fslmaths ${BrainMask} -bin -dilF -mas ${InputfMRI}_mask ${FinalMask}

elif [ "${fMRIMask}" = "T1_DILATED2x_fMRI_FOV" ] ; then
    # FinalMask is a combination of twice dilated FS-derived brainmask, and the spatial coverage mask that captures the
    # voxels that have data available at *ALL* time points (derived in OneStepResampling)
    ${FSLDIR}/bin/fslmaths ${BrainMask} -bin -dilF -dilF -mas ${InputfMRI}_mask ${FinalMask}

elif [ "${fMRIMask}" = "fMRI_FOV" ] ; then
    # FinalMask is the spatial coverage mask that captures the
    # voxels that have data available at *ALL* time points (derived in OneStepResampling)
    ${FSLDIR}/bin/imcp ${InputfMRI}_mask ${FinalMask}

else
    # No valid fMRIMask option was specified
    log_Err_Abort "Invalid entry for specified fMRI mask (--fmrimask=${fMRIMask})"
fi


# Create a simple summary text file of the percentage of spatial coverage of the fMRI data inside the FS-derived brain mask and the actual mask used
NvoxBrainMask=$(fslstats ${BrainMask} -V | awk '{print $1}')
NvoxT1FOVMask=$(fslstats ${T1FOVMask} -V | awk '{print $1}')
NvoxFinalMask=$(fslstats ${FinalMask} -V | awk '{print $1}')
PctBrainCoverage=$(echo "scale=4; 100 * ${NvoxT1FOVMask} / ${NvoxBrainMask}" | bc -l)
PctMaskCoverage=$(echo "scale=4; 100 * ${NvoxFinalMask} / ${NvoxT1FOVMask}" | bc -l)
echo "fMRIMask, PctBrainCoverage, PctMaskCoverage, NvoxT1FOVMask, NvoxBrainMask, NvoxFinalMask" >| ${FinalMask}.stats.txt
echo "${fMRIMask}, ${PctBrainCoverage}, ${PctMaskCoverage}, ${NvoxT1FOVMask}, ${NvoxBrainMask}, ${NvoxFinalMask}" >> ${FinalMask}.stats.txt


# Run intensity normalisation, with bias field correction and optional jacobian modulation,
# for the main fmri timeseries and the scout images (pre-saturation images)

# ${FSLDIR}/bin/fslmaths ${InputfMRI} $biascom $jacobiancom -mas ${FinalMask} -thr 0 -ing 10000 ${OutputfMRI} -odt float
${FSLDIR}/bin/fslmaths ${InputfMRI} $biascom $jacobiancom ${OutputfMRI} -odt float
# Compute spatial mean within mask, and normalize to a mean of 10000 inside the mask, apply mask
scaleFactor=$(${FSLDIR}/bin/fslstats ${OutputfMRI} -k ${FinalMask} -l 0 -M)
${FSLDIR}/bin/fslmaths ${OutputfMRI} -mul 10000 -div $scaleFactor -thr 0 -mas ${FinalMask} ${OutputfMRI} -odt float
echo $scaleFactor > ${OutputfMRI}_scaleFactor.txt

if [ X${ScoutInput} != X ] ; then
    # Generate both masked and unmasked versions of scout, but with consistent scaling within the mask
    ScoutOutputNotMasked=${ScoutOutput}_nomask
    ${FSLDIR}/bin/fslmaths ${ScoutInput} $biascom $jacobiancom ${ScoutOutputNotMasked} -odt float
    # Compute spatial mean within mask, and normalize to a mean of 10000 inside the mask
    scaleFactor=$(${FSLDIR}/bin/fslstats ${ScoutOutputNotMasked} -k ${FinalMask} -l 0 -M)
    echo $scaleFactor > ${ScoutOutput}_scaleFactor.txt
    ${FSLDIR}/bin/fslmaths ${ScoutOutputNotMasked} -mul 10000 -div $scaleFactor -thr 0 ${ScoutOutputNotMasked} -odt float
    # Apply mask to generate masked version
    ${FSLDIR}/bin/fslmaths ${ScoutOutputNotMasked} -mas ${FinalMask} ${ScoutOutput} -odt float
fi

#Basic Cleanup
#rm ${InputfMRI}.nii.* #Don't delete the spatially corrected but unmasked and unnormalized data by default

echo " "
echo "END: IntensityNormalization"
echo " END: $(date)" >> $WD/log.txt

########################################## QA STUFF ##########################################

if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd $(pwd)" >> $WD/qa.txt
echo "# Check that the fMRI and Scout images look OK and that the mean intensity across the timeseries is about 10000" >> $WD/qa.txt
echo "fslview ${ScoutOutput} ${OutputfMRI}" >> $WD/qa.txt

##############################################################################################
