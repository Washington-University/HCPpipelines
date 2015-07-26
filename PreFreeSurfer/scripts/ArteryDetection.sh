#!/bin/env bash
set -e

# Requirements for this script
#  installed versions of: FSL (version 5.0.6)
#  environment: as in SetUpHCPPipeline.sh   (or individually: FSLDIR)
#  give Lennart Verhagen (lennart.verhagen@psy.ox.ac.uk) a coffee or a pint


################################################ SUPPORT FUNCTIONS ##################################################

Usage() {
  echo "`basename $0`: Detect arteries in 7T T1w images (optionally with the help of T2w images)"
  echo " "
  echo "Usage: `basename $0` [--workingdir=<working dir>] --t1=<input T1w image> --t1brain=<input T1w brain image> [--brainmaskloose=<loose brain mask for the arteries>] [--exclmask=<exclusion mask (e.g. WM) image>] [--basename=<output base name>]"
}

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


################################################## OPTION PARSING #####################################################

# Just give usage if no arguments specified
if [[ $# -eq 0 ]] ; then Usage; exit 0; fi
# check for correct options
if [[ $# -lt 2 ]] ; then Usage; exit 1; fi

# parse arguments
WD=`getopt1 "--workingdir" $@`  # "$1"
T1w=`getopt1 "--t1" $@`  # "$2"
T1wBrain=`getopt1 "--t1brain" $@`  # "$3"
BrainMaskLoose=`getopt1 "--brainmaskloose" $@`  # "$6"
ExclMask=`getopt1 "--exclmask" $@`  # "$7"
BaseOut=`getopt1 "--basename" $@`  # "$9"

# get T1w input file base name
BaseT1w=$(${FSLDIR}/bin/remove_ext $T1w)
BaseT1w=$(basename "$BaseT1w")

# default parameters
WD=$(defaultopt $WD ./ArteryDetection)
BaseOut=$(defaultopt $BaseOut $BaseT1w)

# ensure that the working directory exists
mkdir -p $WD

# reporting
echo " "
echo " START: Artery Detection"
echo " "

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt

########################################## DO WORK ##########################################

# get a loose brain mask if not provided
if [[ -z $BrainMaskLoose ]] ; then
  echo "  extracting a very loose brain mask"
  # run brain extraction with very loose parameters
  ${FSLDIR}/bin/bet $T1w $WD/${BaseOut}_brainloose -m -n -f 0.05 -g 0
  BrainMaskLoose=$WD/${BaseOut}_brainloose_mask
  # ensure that the loose brain mask at least contains the proper brain mask
  ${FSLDIR}/bin/fslmaths $BrainMaskLoose -add $T1wBrain -bin $BrainMaskLoose
fi

# mask the T1w image with the loose brain mask
T1wBrainLoose=$WD/${BaseOut}_brainloose
${FSLDIR}/bin/fslmaths $T1w -mas $BrainMaskLoose $T1wBrainLoose

echo "  finding arteries based on their intensity in the T1w image"
# find the threshold for the 10 and 1 percent brightest voxels
thr90=$(${FSLDIR}/bin/fslstats $T1wBrain -P 90)
thr99=$(${FSLDIR}/bin/fslstats $T1wBrain -P 99)

if [[ -z $ExclMask ]] ; then
  echo "  Not excluding any voxels from the artery mask (such as WM voxels). This is potentially problematic, so stricter artery detection criteria are applied."
  cluster90thr=200
  cluster99thr=100
else
  echo "  exclusion mask: $ExclMask"
  cluster90thr=20
  cluster99thr=10
  # mask the brain data with the exclusion mask
  ${FSLDIR}/bin/fslmaths $T1wBrainLoose -bin -sub $ExclMask -thr 0 -bin -mul $T1wBrainLoose $T1wBrainLoose
fi

# find clusters that survive the threshold
${FSLDIR}/bin/cluster --in=$T1wBrainLoose --thresh=$thr90 --osize=$WD/${BaseOut}_thr90cs --omean=$WD/${BaseOut}_thr90cm > /dev/null
${FSLDIR}/bin/cluster --in=$T1wBrainLoose --thresh=$thr99 --osize=$WD/${BaseOut}_thr99cs --omean=$WD/${BaseOut}_thr99cm > /dev/null
# combine size and intensity values into a single cluster statistic
${FSLDIR}/bin/fslmaths $WD/${BaseOut}_thr90cs -mul $WD/${BaseOut}_thr90cm -div $thr90 $WD/${BaseOut}_thr90csm
${FSLDIR}/bin/fslmaths $WD/${BaseOut}_thr99cs -mul $WD/${BaseOut}_thr99cm -div $thr99 $WD/${BaseOut}_thr99csm

# exclude clusters with a very low statistic
${FSLDIR}/bin/fslmaths $WD/${BaseOut}_thr90csm -thr $cluster90thr -bin $WD/${BaseOut}_artery90
${FSLDIR}/bin/fslmaths $WD/${BaseOut}_thr99csm -thr $cluster99thr -bin $WD/${BaseOut}_artery99

# add voxels with extreme values, regardless of their cluster extent

echo "  dilating artery skeletons"
# repeatedly dilate the high-threshold clusters one voxel into the low-intensity clusters
${FSLDIR}/bin/fslmaths $WD/${BaseOut}_artery99 -dilF -mas $WD/${BaseOut}_artery90 $WD/${BaseOut}_arterymask
${FSLDIR}/bin/fslmaths $WD/${BaseOut}_arterymask -dilF -mas $WD/${BaseOut}_artery90 $WD/${BaseOut}_arterymask
${FSLDIR}/bin/fslmaths $WD/${BaseOut}_arterymask -dilF -mas $WD/${BaseOut}_artery90 $WD/${BaseOut}_arterymask

# dilate the whole mask, regardless of low-intensity clusters
${FSLDIR}/bin/fslmaths $WD/${BaseOut}_arterymask -dilF $WD/${BaseOut}_arterymaskdil

# invert the masks to define voxels that are not arteries
${FSLDIR}/bin/fslmaths $WD/${BaseOut}_arterymask -sub 1 -mul -1 $WD/${BaseOut}_arterymask_inv
${FSLDIR}/bin/fslmaths $WD/${BaseOut}_arterymaskdil -sub 1 -mul -1 $WD/${BaseOut}_arterymaskdil_inv

# cleanup intermediate images
${FSLDIR}/bin/imrm $T1wBrainLoose $WD/${BaseOut}_thr90cs $WD/${BaseOut}_thr90cm $WD/${BaseOut}_thr90csm $WD/${BaseOut}_thr99cs $WD/${BaseOut}_thr99cm $WD/${BaseOut}_thr99csm $WD/${BaseOut}_artery90 $WD/${BaseOut}_artery99

# reporting
echo " "
echo " END: Artery Detection"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ##########################################
if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# Look at the quality of the bias corrected output (T1w is brain only)" >> $WD/qa.txt
echo "fslview $T1w $WD/${BaseOut}_arterymask" >> $WD/qa.txt


##############################################################################################
