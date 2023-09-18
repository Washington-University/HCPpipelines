#!/bin/bash 
set -e

# Requirements for this script
#  installed versions of: FSL6.0.4+ , HCP Pipeline, ANTs v2.4.3
#  environment: as in SetUpHCPPipeline.sh   (or individually: FSLDIR, HCPPIPEDIR_Templates)

################################################ SUPPORT FUNCTIONS ##################################################

Usage() {
  echo "`basename $0`: Tool for performing brain extraction using non-linear (FNIRT) results"
  echo " "
  echo "Usage: `basename $0` [--workingdir=<working dir>] --in=<input image> [--ref=<reference highres image>] [--refmask=<reference brain mask>]  --outbrain=<output brain extracted image> --outbrainmask=<output brain mask> [--fsl-init-mat=<fsl init mat>] [--contrast=<T1w (default), T2w, FLAIR>]"
  echo ""
  exit 
}
[[ $2 = "" ]] && Usage

if [ -z ${HCPPIPEDIR} ] ; then
	echo "ERROR: please set HCPPIPEDIR"
	exit
fi
source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib

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

# All except variables starting with $Output are saved in the Working Directory:
#     roughlin.mat "$BaseName"_to_MNI_roughlin.nii.gz   (flirt outputs)
#     NonlinearRegJacobians.nii.gz IntensityModulatedT1.nii.gz NonlinearReg.txt NonlinearIntensities.nii.gz 
#     NonlinearReg.nii.gz (the coefficient version of the warpfield) 
#     str2standard.nii.gz standard2str.nii.gz   (both warpfields in field format)
#     "$BaseName"_to_MNI_nonlin.nii.gz   (spline interpolated output)
#    "$OutputBrainMask" "$OutputBrainExtractedImage"

################################################## OPTION PARSING #####################################################

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options
if [ $# -lt 4 ] ; then Usage; exit 1; fi

# parse arguments
WD=`getopt1 "--workingdir" $@`  # "$1"
Input=`getopt1 "--in" $@`  # "$2"
Reference=`getopt1 "--ref" $@` # "$3"
ReferenceMask=`getopt1 "--refmask" $@` # "$4"
OutputBrainExtractedImage=`getopt1 "--outbrain" $@` # "$5"
OutputBrainMask=`getopt1 "--outbrainmask" $@` # "$6"
FSLInitMatNIRF=`getopt1 "--fsl-init-mat" $@` # "$7"
Contrast=`getopt1 "--contrast" $@` # "$7"

# default parameters
WD=`defaultopt $WD .`
Reference=`defaultopt $Reference ${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm.nii.gz`
ReferenceMask=`defaultopt $ReferenceMask ${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm_brain_mask.nii.gz`  # dilate to be conservative with final brain mask

BaseName=`${FSLDIR}/bin/remove_ext $Input`;
BaseName=`basename $BaseName`;

log_Msg " START: BrainExtrtaction_ANTS"

mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt

########################################## DO WORK ########################################## 

# Register to reference image and extract brain
# Requires environment for ANTs

if [ -z $ANTSPATH ] ; then
	echo "ERROR: cannnot find ANTSPATH"
	exit  
fi
if [[ $(printenv | grep "PATH=" | grep "$ANTSPATH") = "" ]] ; then
	echo "ERROR: cannnot find path to $ANTSPATH"
	exit
fi

Contrast=${Contrast:=T1w}
if [ $Contrast = T1w ] ; then
	opts="-c 3x1x2x3 "
elif [ $Contrast = T2w ] ; then
	opts="-c 3x3x2x1 "
elif [ $Contrast = FLAIR ] ; then
	opts="-c 3x1x3x2 "
fi

# -c 3x1x2x3 for T1 with K=3, CSF=1, GM=2, WM=3 (default)
# -c 3x3x2x1 for T2 with K=3, CSF=3, GM=2, WM=1
# -c 3x1x3x2 for FLAIR with K=3, CSF=1 GM=3, WM=2

log_Msg "ANTSPATH: $ANTSPATH"
log_Msg "Input: $Input"
log_Msg "Reference: $Reference"
log_Msg "ReferenceMask: $ReferenceMask"

if [ ! -z $FSLInitMatNIRF ] ; then
	log_Msg "Found FSL init matrix. Converting to itk format"
	cp $FSLInitMatNIRF ${WD}/init_affine_fsl.mat
	$CARET7DIR/wb_command -convert-affine -from-flirt ${WD}/init_affine_fsl.mat "$Input" "$Reference" -to-itk ${WD}/init_affine_itk.xfm
	opts="$opts -r init_affine_itk.xfm"
fi

log_Msg "Run brain extraction tool using ANTs"

fslmaths "$Input" -abs $WD/Input
imcp "$Reference" $WD/Reference
imcp "$ReferenceMask" $WD/ReferenceMask
CWD=`pwd`
cd $WD

LD_LIBRARY_PATH=/usr/local/lib64:$LD_LIBRARY_PATH

${ANTSPATH}/antsBrainExtraction.sh -d 3 -a Input.nii.gz -e Reference.nii.gz -m ReferenceMask.nii.gz -o ANTs -k 1 $opts

imcp ANTsBrainExtractionBrain.nii.gz $OutputBrainExtractedImage
imcp ANTsBrainExtractionMask.nii.gz $OutputBrainMask
rmdir ANTs

cd $CWD

log_Msg " END: BrainExtrtaction_ANTS"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ########################################## 

if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# Check that the following brain mask does not exclude any brain tissue (and is reasonably good at not including non-brain tissue outside of the immediately surrounding CSF)" >> $WD/qa.txt
echo "fsleyes $Input $OutputBrainMask -cm red -a 50" >> $WD/qa.txt

##############################################################################################
