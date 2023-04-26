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

script_name=$(basename "${0}")

show_usage() {
	cat <<EOF

${script_name}

Usage: ${script_name} [options]

  --infmri=<input fmri data>
  --biasfield=<bias field, already registered to fmri data>
  --jacobian=<jacobian image, already registered to fmri data>
  --brainmask=<brain mask in fmri space>
  --ofmri=<output basename for fmri data>
  --usejacobian=<apply jacobian modulation: true/false>
  [--inscout=<input name for scout image (pre-sat EPI)>]
  [--oscout=<output name for normalized scout image>]
  [--workingdir=<working dir>]
  [--fmrimask=<type of mask to use for generating final fMRI output volume:
        "T1_fMRI_FOV" (default) - T1w brain based mask combined with fMRI FOV mask
        "T1_DILATED_fMRI_FOV" - once dilated T1w brain based mask combined with fMRI FOV
        "T1_DILATED2x_fMRI_FOV" - twice dilated T1w brain based mask combined with fMRI FOV
        "fMRI_FOV" - fMRI FOV mask only (i.e., voxels having spatial coverage at all time points)

EOF
}

# Allow script to return a Usage statement, before any other output or checking
if [ "$#" = "0" ]; then
    show_usage
    exit 1
fi

# ------------------------------------------------------------------------------
#  Check that HCPPIPEDIR is defined and Load Function Libraries
# ------------------------------------------------------------------------------

if [ -z "${HCPPIPEDIR}" ]; then
  echo "${script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
  exit 1
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source ${HCPPIPEDIR}/global/scripts/opts.shlib                 # Command line option functions

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
	show_usage
	exit 0
fi

# ------------------------------------------------------------------------------
#  Verify required environment variables are set and log value
# ------------------------------------------------------------------------------

log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FSLDIR

################################################ SUPPORT FUNCTIONS ##################################################

# function for parsing options
getopt1() {
    sopt="$1"
    shift 1
    for fn in $@ ; do
  if [ `echo $fn | grep -- "^${sopt}=" | wc -w` -gt 0 ] ; then
      echo $fn | sed "s/^${sopt}=//"
      return 0
  fi
    done
}

defaultopt() {
    echo $1
}

################################################### OUTPUT FILES #####################################################

# ${OutputfMRI}  (compulsory)
# ${ScoutOutput}  (optional)

################################################## OPTION PARSING #####################################################

# parse arguments
InputfMRI=`getopt1 "--infmri" $@`  # "$1"
BiasField=`getopt1 "--biasfield" $@`  # "$2"
Jacobian=`getopt1 "--jacobian" $@`  # "$3"
BrainMask=`getopt1 "--brainmask" $@`  # "$4"
OutputfMRI=`getopt1 "--ofmri" $@`  # "$5"
ScoutInput=`getopt1 "--inscout" $@`  # "$6"
ScoutOutput=`getopt1 "--oscout" $@`  # "$7"
UseJacobian=`getopt1 "--usejacobian" $@`  # 
fMRIMask=`getopt1 "--fmrimask" $@`

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

# default parameters
OutputfMRI=`$FSLDIR/bin/remove_ext $OutputfMRI`
WD=`defaultopt $WD ${OutputfMRI}.wdir`
fMRIMask=`defaultopt $fMRIMask "T1_fMRI_FOV"`

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
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt

########################################## DO WORK ##########################################

FinalMask=`${FSLDIR}/bin/remove_ext ${InputfMRI}`_finalmask
T1FOVMask=`${FSLDIR}/bin/remove_ext ${InputfMRI}`_T1FOVmask
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
NvoxBrainMask=`fslstats ${BrainMask} -V | awk '{print $1}'`
NvoxT1FOVMask=`fslstats ${T1FOVMask} -V | awk '{print $1}'`
NvoxFinalMask=`fslstats ${FinalMask} -V | awk '{print $1}'`
PctBrainCoverage=`echo "scale=4; 100 * ${NvoxT1FOVMask} / ${NvoxBrainMask}" | bc -l`
PctMaskCoverage=`echo "scale=4; 100 * ${NvoxFinalMask} / ${NvoxT1FOVMask}" | bc -l`
echo "fMRIMask, PctBrainCoverage, PctMaskCoverage, NvoxT1FOVMask, NvoxBrainMask, NvoxFinalMask" >| ${FinalMask}.stats.txt
echo "${fMRIMask}, ${PctBrainCoverage}, ${PctMaskCoverage}, ${NvoxT1FOVMask}, ${NvoxBrainMask}, ${NvoxFinalMask}" >> ${FinalMask}.stats.txt


# Run intensity normalisation, with bias field correction and optional jacobian modulation,
# for the main fmri timeseries and the scout images (pre-saturation images)
${FSLDIR}/bin/fslmaths ${InputfMRI} $biascom $jacobiancom -mas ${FinalMask} -thr 0 -ing 10000 ${OutputfMRI} -odt float
if [ X${ScoutInput} != X ] ; then
    # Generate both masked and unmasked versions of scout, but with consistent scaling within the mask
    ScoutOutputNotMasked=${ScoutOutput}_nomask
    ${FSLDIR}/bin/fslmaths ${ScoutInput} $biascom $jacobiancom ${ScoutOutputNotMasked} -odt float
    # Compute spatial mean within mask, and normalize to a mean of 10000 inside the mask
    scaleFactor=$(${FSLDIR}/bin/fslstats ${ScoutOutputNotMasked} -k ${FinalMask} -l 0 -M)
    ${FSLDIR}/bin/fslmaths ${ScoutOutputNotMasked} -mul 10000 -div $scaleFactor -thr 0 ${ScoutOutputNotMasked} -odt float
    # Apply mask to generate masked version
    ${FSLDIR}/bin/fslmaths ${ScoutOutputNotMasked} -mas ${FinalMask} ${ScoutOutput} -odt float
fi

#Basic Cleanup
#rm ${InputfMRI}.nii.* #Don't delete the spatially corrected but unmasked and unnormalized data by default

echo " "
echo "END: IntensityNormalization"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ##########################################

if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# Check that the fMRI and Scout images look OK and that the mean intensity across the timeseries is about 10000" >> $WD/qa.txt
echo "fslview ${ScoutOutput} ${OutputfMRI}" >> $WD/qa.txt

##############################################################################################
