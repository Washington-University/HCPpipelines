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
  echo "             [--usemask=<what mask to use for generating final BOLD timeseries:"
  echo "                         T1_fMRI_FOV (mask based on T1 and voxels available at all timepoints - the default)"
  echo "                         T1 (mask based on the T1w image)"
  echo "                         DILATEDT1 (dilated T1w image based mask)"
  echo "                         NONE (do not use a mask)]"
  echo "                         NOTE: Mask used will also determine intensity normalization!"
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
UseMask=`getopt1 "--usemask" $@`

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
verbose_echo "         --usemask: ${UseMask}"
verbose_echo " "

# default parameters
OutputfMRI=`$FSLDIR/bin/remove_ext $OutputfMRI`
WD=`defaultopt $WD ${OutputfMRI}.wdir`
UseMask=`defaultopt $UseMask "T1_fMRI_FOV"`

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

# FinalMask is a combination of the FS-derived brainmask, and the spatial coverage mask that captures the
# voxels that have data available at *ALL* time points (derived in OneStepResampling)
FinalMask=`${FSLDIR}/bin/remove_ext ${InputfMRI}`_finalmask
${FSLDIR}/bin/fslmaths ${BrainMask} -bin -mas ${InputfMRI}_mask ${FinalMask}

# Create a simple summary text file of the percentage of spatial coverage of the fMRI data inside the FS-derived brain mask
NvoxBrainMask=`fslstats ${BrainMask} -V | awk '{print $1}'`
NvoxFinalMask=`fslstats ${FinalMask} -V | awk '{print $1}'`
PctCoverage=`echo "scale=4; 100 * ${NvoxFinalMask} / ${NvoxBrainMask}" | bc -l`
echo "PctCoverage, NvoxFinalMask, NvoxBrainMask" >| ${FinalMask}.stats.txt
echo "${PctCoverage}, ${NvoxFinalMask}, ${NvoxBrainMask}" >> ${FinalMask}.stats.txt

# If a user requested, use a T1 mas, a dilated T1 mask or no mask instedad when generating final BOLD timeseries

if [ "${UseMask}" = "DILATEDT1" ] ; then
    # -- create a dilated version of T1 mask
    ${FSLDIR}/bin/fslmaths ${BrainMask} -dilF ${BrainMask}_dil
    MaskStr="-mas ${BrainMask}_dil"
elif [ "${UseMask}" = "T1" ] ; then
    MaskStr="-mas ${BrainMask}"
elif [ "${UseMask}" = "NONE" ] ; then
    MaskStr=""
elif [ "${UseMask}" = "T1_fMRI_FOV" ] ; then
    MaskStr="-mas ${FinalMask}"
elif
    log_Err_Abort "Specified BOLD mask to use (--usemask=${UseMask}) is invalid!"
fi


# Run intensity normalisation, with bias field correction and optional jacobian modulation,
# for the main fmri timeseries and the scout images (pre-saturation images)
${FSLDIR}/bin/fslmaths ${InputfMRI} $biascom $jacobiancom ${MaskStr} -thr 0 -ing 10000 ${OutputfMRI} -odt float
if [ X${ScoutInput} != X ] ; then
   ${FSLDIR}/bin/fslmaths ${ScoutInput} $biascom $jacobiancom ${MaskStr} -thr 0 -ing 10000 ${ScoutOutput} -odt float
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
