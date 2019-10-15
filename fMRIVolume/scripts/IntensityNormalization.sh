#!/bin/bash
set -e
source ${HCPPIPEDIR}/global/scripts/debug.shlib # Debugging functions

# Intensity normalisation, and bias field correction, and optional Jacobian modulation, applied to fMRI images (all inputs must be in fMRI space)

#  This code is released to the public domain.
#
#  Matt Glasser, Washington University in St Louis
#  Mark Jenkinson, FMRIB Centre, University of Oxford
#  2011-2012
#
#  Neither Washington Univeristy in St Louis, the FMRIB Centre, the
#  University of Oxford, nor any of their employees imply any warranty
#  of usefulness of this software for any purpose, and do not assume
#  any liability for damages, incidental or otherwise, caused by any
#  use of this document.

################################################ REQUIREMENTS ##################################################

# Requirements for this script
#  installed versions of: FSL (version 5.0.6)
#  environment: FSLDIR

################################################ SUPPORT FUNCTIONS ##################################################

Usage() {
  echo "`basename $0`: "
  echo " "
  echo "Usage: `basename $0` --infmri=<input fmri data>"
  echo "             --biasfield=<bias field, already registered to fmri data>"
  echo "             --jacobian=<jacobian image, already registered to fmri data>"
  echo "             --brainmask=<brain mask in fmri space>"
  echo "             --ofmri=<output basename for fmri data>"
  echo "             --usejacobian=<apply jacobian modulation: true/false>"
  echo "             [--inscout=<input name for scout image (pre-sat EPI)>]"
  echo "             [--oscout=<output name for normalized scout image>]"
  echo "             [--workingdir=<working dir>]"
  echo "             [--boldmask=<what mask to use for generating final BOLD timeseries:"
  echo "                         T1_fMRI_FOV (default): mask based on T1 and voxels available at all timepoints (i.e., the fMRI FOV)"
  echo "                         T1_DILATED_fMRI_FOV: a once dilated T1w brain based mask combined with fMRI FOV"
  echo "                         T1_DILATED2x_fMRI_FOV: a twice dilated T1w brain based mask combined with fMRI FOV,"
  echo "                         fMRI_FOV: a fMRI FOV mask"
}

# function for parsing options
getopt1() {
    sopt="$1"
    shift 1
    for fn in $@ ; do
  if [ `echo $fn | grep -- "^${sopt}=" | wc -w` -gt 0 ] ; then
      echo $fn | sed "s/^${sopt}=//"
      # if [ ] ; then Usage ; echo " " ; echo "Error:: option ${sopt} requires an argument"; exit 1 ; end
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

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options
if [ $# -lt 4 ] ; then Usage; exit 1; fi

# parse arguments
InputfMRI=`getopt1 "--infmri" $@`  # "$1"
BiasField=`getopt1 "--biasfield" $@`  # "$2"
Jacobian=`getopt1 "--jacobian" $@`  # "$3"
BrainMask=`getopt1 "--brainmask" $@`  # "$4"
OutputfMRI=`getopt1 "--ofmri" $@`  # "$5"
ScoutInput=`getopt1 "--inscout" $@`  # "$6"
ScoutOutput=`getopt1 "--oscout" $@`  # "$7"
UseJacobian=`getopt1 "--usejacobian" $@`  # 
BOLDMask=`getopt1 "--boldmask" $@`

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
verbose_echo "         --boldmask: ${BOLDMask}"
verbose_echo " "

# default parameters
OutputfMRI=`$FSLDIR/bin/remove_ext $OutputfMRI`
WD=`defaultopt $WD ${OutputfMRI}.wdir`
BOLDMask=`defaultopt $BOLDMask "T1_fMRI_FOV"`

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
    biascom="-div $BiasField"
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

# Use the requested BOLD mask 

if [ "${BOLDMask}" = "T1_fMRI_FOV" ] ; then
    # FinalMask is a combination of the FS-derived brainmask, and the spatial coverage mask that captures the
    # voxels that have data available at *ALL* time points (derived in OneStepResampling)
    ${FSLDIR}/bin/imcp ${T1FOVMask} ${FinalMask}

elif [ "${BOLDMask}" = "T1_DILATED_fMRI_FOV" ] ; then
    # FinalMask is a combination of once dilated FS-derived brainmask, and the spatial coverage mask that captures the
    # voxels that have data available at *ALL* time points (derived in OneStepResampling)
    ${FSLDIR}/bin/fslmaths ${BrainMask} -bin -dilF -mas ${InputfMRI}_mask ${FinalMask}

elif [ "${BOLDMask}" = "T1_DILATED2x_fMRI_FOV" ] ; then
    # FinalMask is a combination of twice dilated FS-derived brainmask, and the spatial coverage mask that captures the
    # voxels that have data available at *ALL* time points (derived in OneStepResampling)
    ${FSLDIR}/bin/fslmaths ${BrainMask} -bin -dilF -dilF -mas ${InputfMRI}_mask ${FinalMask}

elif [ "${BOLDMask}" = "fMRI_FOV" ] ; then
    # FinalMask is the spatial coverage mask that captures the
    # voxels that have data available at *ALL* time points (derived in OneStepResampling)
    ${FSLDIR}/bin/imcp ${InputfMRI}_mask ${FinalMask}

elif
    # No valid BOLDMask option was specified
    log_Err_Abort "Invalid entry for specified BOLD mask (--boldmask=${BOLDMask})"
fi


# Create a simple summary text file of the percentage of spatial coverage of the fMRI data inside the FS-derived brain mask and the actual mask used
NvoxBrainMask=`fslstats ${BrainMask} -V | awk '{print $1}'`
NvoxT1FOVMask=`fslstats ${T1FOVMask} -V | awk '{print $1}'`
NvoxFinalMask=`fslstats ${FinalMask} -V | awk '{print $1}'`
PctBrainCoverage=`echo "scale=4; 100 * ${NvoxT1FOVMask} / ${NvoxBrainMask}" | bc -l`
PctMaskCoverage=`echo "scale=4; 100 * ${NvoxFinalMask} / ${NvoxT1FOVMask}" | bc -l`
echo "Mask, PctBrainCoverage, PctMaskCoverage, NvoxT1FOVMask, NvoxBrainMask, NvoxFinalMask" >| ${FinalMask}.stats.txt
echo "${BOLDMask}, ${PctBrainCoverage}, ${PctMaskCoverage}, ${NvoxT1FOVMask}, ${NvoxBrainMask}, ${NvoxFinalMask}" >> ${FinalMask}.stats.txt


# Run intensity normalisation, with bias field correction and optional jacobian modulation,
# for the main fmri timeseries and the scout images (pre-saturation images)
${FSLDIR}/bin/fslmaths ${InputfMRI} $biascom $jacobiancom -mas ${FinalMask} -thr 0 -ing 10000 ${OutputfMRI} -odt float
if [ X${ScoutInput} != X ] ; then
   ${FSLDIR}/bin/fslmaths ${ScoutInput} $biascom $jacobiancom -mas ${FinalMask} -thr 0 -ing 10000 ${ScoutOutput} -odt float
fi

#Basic Cleanup
rm ${InputfMRI}.nii.*

echo " "
echo "END: IntensityNormalization"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ##########################################

if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# Check that the fMRI and Scout images look OK and that the mean intensity across the timeseries is about 10000" >> $WD/qa.txt
echo "fslview ${ScoutOutput} ${OutputfMRI}" >> $WD/qa.txt

##############################################################################################
