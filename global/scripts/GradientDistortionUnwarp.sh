#!/bin/bash 
set -e

# Requirements for this script
#  installed versions of: FSL (version 5.0.6) and HCP-gradunwarp (version 1.0.2)
#  environment: FSLDIR, PATH to be able to find gradient_unwarp.py

################################################ SUPPORT FUNCTIONS ##################################################

Usage() {
  echo "`basename $0`: Tool for performing Gradient Non-linearity Distortion Correction for general 4D images, based on gradunwarp python package from MGH (it requires a scanner-specific Siemens coefficient file)"
  echo " "
  echo "Usage: `basename $0` [--workingdir=<working dir>]"
  echo "              --coeffs=<Siemens gradient coefficient file>"
  echo "              --in=<input image>"
  echo "              --out=<output image>"
  echo "              --owarp=<output warp>"
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

# Outputs (in $WD except for those starting with $Output) : 
#        ${BaseName}_vol1    (first 3D image - internal use only)
#        trilinear           (direct output of gradient_unwarp.py)
#        fullWarp_abs        (output from gradient_unwarp.py)
#        $OutputTransform    (warp in relative convention)
#        $OutputFile         (spline interpolated 4D output)

################################################## OPTION PARSING #####################################################

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options
if [ $# -lt 5 ] ; then Usage; exit 1; fi

# parse arguments
WD=`getopt1 "--workingdir" $@`  # "$1"
InputCoefficients=`getopt1 "--coeffs" $@`  # "$2"
InputFile=`getopt1 "--in" $@`  # "$3"
OutputFile=`getopt1 "--out" $@`  # "$4"
OutputTransform=`getopt1 "--owarp" $@`  # "$5"

# default parameters
OutputFile=`${FSLDIR}/bin/remove_ext ${OutputFile}`
OutputTransformFile=`${FSLDIR}/bin/remove_ext ${OutputTransform}`
WD=`defaultopt $WD ${OutputFile}.wdir`

BaseName=`${FSLDIR}/bin/remove_ext $InputFile`;
BaseName=`basename $BaseName`;

echo " "
echo " START: GradientDistortionUnwarp"

mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt

########################################## DO WORK ########################################## 

# Extract first volume and run gradient distortion correction on this (all others follow suit as scanner coordinate system is unchanged, even with subject motion)
${FSLDIR}/bin/fslroi ${InputFile}.nii.gz $WD/${BaseName}_vol1.nii.gz 0 1

# move (temporarily) into the working directory as gradient_unwarp.py outputs some files directly into pwd
InputCoeffs=`${FSLDIR}/bin/fsl_abspath $InputCoefficients`
ORIGDIR=`pwd`
cd $WD
echo "gradient_unwarp.py ${BaseName}_vol1.nii.gz trilinear.nii.gz siemens -g ${InputCoeffs} -n" >> log.txt
# NB: gradient_unwarp.py *must* have the filename extensions written out explicitly or it will crash
gradient_unwarp.py ${BaseName}_vol1.nii.gz trilinear.nii.gz siemens -g $InputCoeffs -n
cd $ORIGDIR

# Now create an appropriate warpfield output (relative convention) and apply it to all timepoints
#convertwarp's jacobian output has 8 frames, each combination of one-sided differences, so average them
${FSLDIR}/bin/convertwarp --abs --ref=$WD/trilinear.nii.gz --warp1=$WD/fullWarp_abs.nii.gz --relout --out=$OutputTransform --jacobian=${OutputTransformFile}_jacobian
${FSLDIR}/bin/fslmaths ${OutputTransformFile}_jacobian -Tmean ${OutputTransformFile}_jacobian
${FSLDIR}/bin/applywarp --rel --interp=spline -i $InputFile -r $WD/${BaseName}_vol1.nii.gz -w $OutputTransform -o $OutputFile

echo " "
echo " END: GradientDistortionUnwarp"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ########################################## 

if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# Check that the image output of gradient_unwarp.py is the same as from applywarp" >> $WD/qa.txt
echo "fslview $WD/trilinear $OutputFile" >> $WD/qa.txt
echo "# Optional (further) checking - results from fslstats should be very close to zero" >> $WD/qa.txt
echo "applywarp --rel --interp=trilinear -i $InputFile -r $WD/${BaseName}_vol1.nii.gz -w $OutputTransform -o $WD/qa_aw_tri" >> $WD/qa.txt
echo "fslmaths $WD/qa_aw_tri -sub $WD/trilinear $WD/diff_tri" >> $WD/qa.txt
echo "fslstats $WD/diff_tri -a -P 100 -M" >> $WD/qa.txt

##############################################################################################
