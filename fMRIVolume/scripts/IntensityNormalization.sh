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
  echo "             [--usemask=<what mask to use: T1, BOLD, DILATED, NONE; default=T1>]"
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
Mask=`getopt1 "--usemask" $@`

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
verbose_echo "         --usemask: ${Mask}"
verbose_echo " "

# default parameters
OutputfMRI=`$FSLDIR/bin/remove_ext $OutputfMRI`
WD=`defaultopt $WD ${OutputfMRI}.wdir`
Mask=${Mask:-T1}

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

if [ $Mask == 'BOLD' ] ; then
  echo " ... Creating BOLD based brain mask"
  if [ X${ScoutInput} == X ] ; then
    ${FSLDIR}/bin/fslmaths ${InputfMRI} -Tmean ${InputfMRI%.nii.gz}_avg
    ${FSLDIR}/bin/bet ${InputfMRI%.nii.gz}_avg ${InputfMRI%.nii.gz}_brain -R -f 0.3
    BrainMask=${InputfMRI%.nii.gz}_brain
  else
    ${FSLDIR}/bin/bet ${ScoutInput} ${ScoutInput%.nii.gz}_brain -R -f 0.3
    BrainMask=${ScoutInput%.nii.gz}_brain
  fi
fi

if [ $Mask == 'DILATED' ] ; then
  BrainMask="${HCPPIPEDIR_Templates}/MNI152_T1_2mm_brain_mask_dil.nii.gz"
fi

BrainMask="-mas ${BrainMask}"

if [ $Mask == 'NONE' ] ; then
  BrainMask=""
fi

# Run intensity normalisation, with bias field correction and optional jacobian modulation, for the main fmri timeseries and the scout images (pre-saturation images)

${FSLDIR}/bin/fslmaths ${InputfMRI} $biascom $jacobiancom ${BrainMask} -mas ${InputfMRI}_mask -thr 0 -ing 10000 ${OutputfMRI} -odt float
if [ X${ScoutInput} != X ] ; then
   ${FSLDIR}/bin/fslmaths ${ScoutInput} $biascom $jacobiancom ${BrainMask} -mas ${InputfMRI}_mask -thr 0 -ing 10000 ${ScoutOutput} -odt float
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
