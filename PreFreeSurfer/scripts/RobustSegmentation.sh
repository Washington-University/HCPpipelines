#!/usr/bin/env bash
set -e

# Requirements for this script
#  installed versions of: FSL (version 5.0.6)
#  environment: as in SetUpHCPPipeline.sh   (or individually: FSLDIR)
#  give Lennart Verhagen (lennart.verhagen@psy.ox.ac.uk) a coffee or a pint


################################################ SUPPORT FUNCTIONS ##################################################

Usage() {
  echo "`basename $0`: Segment the brain into CSF, GM, WM using FAST and robustly improve on the classification (optionally with the help of T2w images)"
  echo " "
  echo "Usage: `basename $0` [--workingdir=<working dir>]"
  echo "      --t1brain=<input T1w brain image>"
  echo "      [--t2brain=<input T2w brain image>]"
  echo "      [--basename=<output base name>]"
  echo "      [--runfast={AUTO (default), TRUE, FALSE}]"
  echo "      [--fwhm={INF for no bias field correction, or the FWHM kernel in mm}]"
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
if [[ $# -lt 1 ]] ; then Usage; exit 1; fi

# parse arguments
WD=`getopt1 "--workingdir" $@`  # "$1"
T1wBrain=`getopt1 "--t1brain" $@`  # "$2"
T2wBrain=`getopt1 "--t2brain" $@`  # "$3"
BrainMask=`getopt1 "--brainmask" $@`  # "$4"
Base=`getopt1 "--basename" $@`  # "$5"
RunFast=`getopt1 "--runfast" $@`  # "$6"
FWHM=`getopt1 "--fwhm" $@`  # "$7"

# get T1w input file base name
BaseT1wBrain=$(${FSLDIR}/bin/remove_ext $T1wBrain)
BaseT1wBrain=$(basename "$BaseT1wBrain")

# default parameters
WD=$(defaultopt $WD ./RobustSegmentation)
Base=$(defaultopt $Base $BaseT1wBrain)
RunFast=$(defaultopt $RunFast "AUTO")
FWHM=$(defaultopt $FWHM 10)

# ensure that the working directory exists
mkdir -p $WD

# determine if FAST could/should be run
if [[ $RunFast = "FALSE" ]] && [[ ! -r $WD/${Base}_pveseg.nii.gz ]] ; then
  echo "Requested to NOT run fast, but required partial-volume estimate image is not found: $WD/${Base}_pveseg.nii.gz" 1>&2
  echo "Requested to NOT run fast, but required partial-volume estimate image is not found: $WD/${Base}_pveseg.nii.gz"; exit 1
fi
[[ $RunFast = "AUTO" ]] && [[ -r $WD/${Base}_pveseg.nii.gz ]] && RunFast="FALSE"
[[ $RunFast != "FALSE" ]] && RunFast="TRUE"

# reporting
echo " "
echo " START: Robust Segmentation"
echo " "

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt

########################################## DO WORK ##########################################

# run fast or not
if [[ $RunFast = "TRUE" ]] ; then

  # set additional arguments for bias field correction in fast
  ExtraArguments=""
  if [[ $FWHM = "INF" ]] ; then
    # skip bias correction (if already done)
    ExtraArguments="-N"
  elif [[ -n $FWHM ]] ; then
    # set the bias field smoothing kernel FWHM
    ExtraArguments="-l $FWHM"
  fi

  # run fast either with or without a T2w image
  if [[ -n $T2wBrain ]] ; then
    echo "  segmenting the brain using fast on the T1w and T2w images"
    ${FSLDIR}/bin/fast -I 5 -S 2 $ExtraArguments -o $WD/${Base} $T1wBrain $T2wBrain
  else
    echo "  segmenting the brain using fast on the T1w image"
    ${FSLDIR}/bin/fast -I 5 $ExtraArguments -o $WD/${Base} $T1wBrain
  fi

fi

echo "  finding small clusters in the segmentation that need to be reassigned"
# extract segments from partial-volume estimation
${FSLDIR}/bin/fslmaths $WD/${Base}_pveseg -thr 1 -uthr 1 -bin $WD/${Base}_0
${FSLDIR}/bin/fslmaths $WD/${Base}_pveseg -thr 2 -uthr 2 -bin $WD/${Base}_1
${FSLDIR}/bin/fslmaths $WD/${Base}_pveseg -thr 3 -uthr 3 -bin $WD/${Base}_2

# sort the segments from dark (CSF) to bright (WM)
mean_0=$(${FSLDIR}/bin/fslstats $T1wBrain -k $WD/${Base}_0 -m)
mean_1=$(${FSLDIR}/bin/fslstats $T1wBrain -k $WD/${Base}_1 -m)
mean_2=$(${FSLDIR}/bin/fslstats $T1wBrain -k $WD/${Base}_2 -m)
echo -e "$mean_0 0\n$mean_1 1\n$mean_2 2" > $WD/temp.txt
idx=($(sort -g -k 1 $WD/temp.txt | awk '{ print($2) }'))
rm $WD/temp.txt

# rename the segments according to their contents
${FSLDIR}/bin/immv $WD/${Base}_${idx[0]} $WD/${Base}_CSF
${FSLDIR}/bin/immv $WD/${Base}_${idx[1]} $WD/${Base}_GM
${FSLDIR}/bin/immv $WD/${Base}_${idx[2]} $WD/${Base}_WM
# copy the partial-volume estimation according to their contents
${FSLDIR}/bin/imcp $WD/${Base}_pve_${idx[0]} $WD/${Base}_pve_CSF
${FSLDIR}/bin/imcp $WD/${Base}_pve_${idx[1]} $WD/${Base}_pve_GM
${FSLDIR}/bin/imcp $WD/${Base}_pve_${idx[2]} $WD/${Base}_pve_WM

# find the size of the clusters in the masks (but don't report to stdout)
${FSLDIR}/bin/cluster --in=$WD/${Base}_CSF --thresh=1 --osize=$WD/${Base}_CSF > /dev/null
${FSLDIR}/bin/cluster --in=$WD/${Base}_GM --thresh=1 --osize=$WD/${Base}_GM > /dev/null
${FSLDIR}/bin/cluster --in=$WD/${Base}_WM --thresh=1 --osize=$WD/${Base}_WM > /dev/null

# include only the largest GM and WM clusters, but include all CSF clusters
${FSLDIR}/bin/fslmaths $WD/${Base}_CSF -bin $WD/${Base}_CSF
${FSLDIR}/bin/fslmaths $WD/${Base}_GM -thr 10000 -bin $WD/${Base}_GM
${FSLDIR}/bin/fslmaths $WD/${Base}_WM -thr 10000 -bin $WD/${Base}_WM

echo "  reassigning the lone voxels to neighbouring compartments"
# dilate the partial-volume estimates with a 2mm FWHM Gaussian kernel
${FSLDIR}/bin/fslmaths $WD/${Base}_pve_CSF -mas $WD/${Base}_CSF -s 2 $WD/${Base}_CSFdil
${FSLDIR}/bin/fslmaths $WD/${Base}_pve_GM -mas $WD/${Base}_GM -s 2 $WD/${Base}_GMdil
${FSLDIR}/bin/fslmaths $WD/${Base}_pve_WM -mas $WD/${Base}_WM -s 2 $WD/${Base}_WMdil

# create a binary brain mask
BrainMask=$WD/${Base}_mask
${FSLDIR}/bin/fslmaths $T1wBrain -bin $BrainMask

# re-assign voxels that were previously in small WM/GM clusters
${FSLDIR}/bin/fslmaths $T1wBrain -bin -sub $WD/${Base}_CSF -sub $WD/${Base}_GM -sub $WD/${Base}_WM $WD/${Base}_lonevox
${FSLDIR}/bin/fslmerge -t $WD/${Base}_CSFGMWM $WD/${Base}_CSFdil $WD/${Base}_GMdil $WD/${Base}_WMdil
${FSLDIR}/bin/fslmaths $WD/${Base}_CSFGMWM -Tmaxn -add $BrainMask -mas $WD/${Base}_lonevox $WD/${Base}_lonevox

# update the compartment masks with the newly assigned voxels
${FSLDIR}/bin/fslmaths $WD/${Base}_lonevox -thr 1 -uthr 1 -add $WD/${Base}_CSF -bin $WD/${Base}_CSF
${FSLDIR}/bin/fslmaths $WD/${Base}_lonevox -thr 2 -uthr 2 -add $WD/${Base}_GM -bin $WD/${Base}_GM
${FSLDIR}/bin/fslmaths $WD/${Base}_lonevox -thr 3 -uthr 3 -add $WD/${Base}_WM -bin $WD/${Base}_WM
${FSLDIR}/bin/fslmaths $WD/${Base}_lonevox -thr 1 -uthr 1 -bin -add $WD/${Base}_pve_CSF -mul -1 -add 1 -thr 0 -sub 1 -mul -1 $WD/${Base}_pve_CSF
${FSLDIR}/bin/fslmaths $WD/${Base}_lonevox -thr 2 -uthr 2 -bin -add $WD/${Base}_pve_GM -mul -1 -add 1 -thr 0 -sub 1 -mul -1 $WD/${Base}_pve_GM
${FSLDIR}/bin/fslmaths $WD/${Base}_lonevox -thr 3 -uthr 3 -bin -add $WD/${Base}_pve_WM -mul -1 -add 1 -thr 0 -sub 1 -mul -1 $WD/${Base}_pve_WM

# erode the WM mask
${FSLDIR}/bin/fslmaths $WD/${Base}_WM -ero $WD/${Base}_WMero
# remove WM voxels where CSF probability is higher than zero
${FSLDIR}/bin/fslmaths $WD/${Base}_WM -mas $WD/${Base}_pve_CSF $WD/${Base}_notWM
${FSLDIR}/bin/fslmaths $WD/${Base}_WM -sub $WD/${Base}_notWM -bin $WD/${Base}_WMmin
# assign those to CSF or GM based on partial-volume estimation
${FSLDIR}/bin/fslmaths $WD/${Base}_pve_CSF -sub $WD/${Base}_pve_GM -bin -mas $WD/${Base}_notWM -add $WD/${Base}_CSF $WD/${Base}_CSFplus
${FSLDIR}/bin/fslmaths $WD/${Base}_pve_GM -sub $WD/${Base}_pve_CSF -bin -mas $WD/${Base}_notWM -add $WD/${Base}_GM $WD/${Base}_GMplus
${FSLDIR}/bin/imrm $WD/${Base}_notWM

echo "  robust compartment masks have been created"
# cleanup
${FSLDIR}/bin/imrm $WD/${Base}_CSFdil $WD/${Base}_GMdil $WD/${Base}_WMdil $WD/${Base}_CSFGMWM

# reporting
echo " "
echo " END: Robust Segmentation"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ##########################################
if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# Look at the quality of the bias corrected output (T1w is brain only)" >> $WD/qa.txt
echo "fslview $T1wBrain -l Greyscale $WD/${Base}_CSF -l Blue -t 0.4 $WD/${Base}_GM -l Red -t 0.4 $WD/${Base}_WM -l Yellow -t 0.4" >> $WD/qa.txt


##############################################################################################
