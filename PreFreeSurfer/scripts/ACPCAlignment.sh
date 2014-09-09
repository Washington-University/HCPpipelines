#!/bin/bash 
set -e

# Requirements for this script
#  installed versions of: FSL (version 5.0.6) (including python with numpy, needed to run aff2rigid - part of FSL)
#  environment: FSLDIR

################################################ SUPPORT FUNCTIONS ##################################################

Usage() {
  echo "`basename $0`: Tool for creating a 6 DOF alignment of the AC, ACPC line and hemispheric plane in MNI space"
  echo " "
  echo "Usage: `basename $0` --workingdir=<working dir> --in=<input image> --ref=<reference image> --out=<output image> --omat=<output matrix> [--brainsize=<brainsize>]"
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

################################################### OUTPUT FILES #####################################################

# All except $Output variables, are saved in the Working Directory:
#     roi2full.mat, full2roi.mat, roi2std.mat, full2std.mat
#     robustroi.nii.gz  (the result of the initial cropping)
#     acpc_final.nii.gz (the 12 DOF registration result)
#     "$OutputMatrix"  (a 6 DOF mapping from the original image to the ACPC aligned version)
#     "$Output"  (the ACPC aligned image)

################################################## OPTION PARSING #####################################################

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options
if [ $# -lt 5 ] ; then Usage; exit 1; fi

# parse arguments
WD=`getopt1 "--workingdir" $@`  # "$1"
Input=`getopt1 "--in" $@`  # "$2"
Reference=`getopt1 "--ref" $@`  # "$3"
Output=`getopt1 "--out" $@`  # "$4"
OutputMatrix=`getopt1 "--omat" $@`  # "$5"
BrainSizeOpt=`getopt1 "--brainsize" $@`  # "$6"

# default parameters
Reference=`defaultopt ${Reference} ${FSLDIR}/data/standard/MNI152_T1_1mm`
Output=`$FSLDIR/bin/remove_ext $Output`
WD=`defaultopt $WD ${Output}.wdir`

# make optional arguments truly optional  (as -b without a following argument would crash robustfov)
if [ X${BrainSizeOpt} != X ] ; then BrainSizeOpt="-b ${BrainSizeOpt}" ; fi

echo " "
echo " START: ACPCAlignment"

mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt

########################################## DO WORK ########################################## 

# Crop the FOV
${FSLDIR}/bin/robustfov -i "$Input" -m "$WD"/roi2full.mat -r "$WD"/robustroi.nii.gz $BrainSizeOpt

# Invert the matrix (to get full FOV to ROI)
${FSLDIR}/bin/convert_xfm -omat "$WD"/full2roi.mat -inverse "$WD"/roi2full.mat

# Register cropped image to MNI152 (12 DOF)
${FSLDIR}/bin/flirt -interp spline -in "$WD"/robustroi.nii.gz -ref "$Reference" -omat "$WD"/roi2std.mat -out "$WD"/acpc_final.nii.gz -searchrx -30 30 -searchry -30 30 -searchrz -30 30

# Concatenate matrices to get full FOV to MNI
${FSLDIR}/bin/convert_xfm -omat "$WD"/full2std.mat -concat "$WD"/roi2std.mat "$WD"/full2roi.mat

# Get a 6 DOF approximation which does the ACPC alignment (AC, ACPC line, and hemispheric plane)
${FSLDIR}/bin/aff2rigid "$WD"/full2std.mat "$OutputMatrix"

# Create a resampled image (ACPC aligned) using spline interpolation
${FSLDIR}/bin/applywarp --rel --interp=spline -i "$Input" -r "$Reference" --premat="$OutputMatrix" -o "$Output"

echo " "
echo " END: ACPCAlignment"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ########################################## 

if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# Check that the following image does not cut off any brain tissue" >> $WD/qa.txt
echo "fslview $WD/robustroi" >> $WD/qa.txt
echo "# Check that the alignment to the reference image is acceptable (the top/last image is spline interpolated)" >> $WD/qa.txt
echo "fslview $Reference $WD/acpc_final $Output" >> $WD/qa.txt

##############################################################################################
