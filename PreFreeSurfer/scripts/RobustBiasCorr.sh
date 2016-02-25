#!/usr/bin/env bash
set -e

# Requirements for this script
#  installed versions of: FSL (version 5.0.6)
#  environment: as in SetUpHCPPipeline.sh   (or individually: FSLDIR, $HCPPIPEDIR_PreFS)
#  give Lennart Verhagen (lennart.verhagen@psy.ox.ac.uk) a coffee or a pint


################################################ SUPPORT FUNCTIONS ##################################################

Usage() {
cat <<EOF

RobustBiasCorr.sh: Robust bias field correction using 'fast'

Usage: `RobustBiasCorr.sh` [--workingdir=<working dir>]
      --in=<input image>
      [--basename=<output base name>]
      [--Type={1:T1 (default), 2:T2}]
      [--FWHM=<field smoothness kernel FWHM in mm, default 10>]
      [--brainmask=<brain mask image>]
      [--smoothfillnonpos={TRUE (default), FALSE}]
      [--fslreorient2std={TRUE, FALSE (default)}]
      [--robustfov={TRUE, FALSE (default)}]
      [--betrestore={TRUE, FALSE (default)}]
      [--forcestrictbrainmask={TRUE, FALSE (default)}]
      [--ignorecsf={TRUE (default), FALSE}]
      [--ignorextrm={TRUE, FALSE (default)}]
      [--hpfinit={TRUE, FALSE} (default is auto-determined)]

EOF
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
Input=`getopt1 "--in" $@`  # "$2"
BaseName=`getopt1 "--basename" $@`  # "$3"
Type=`getopt1 "--type" $@`  # "$4"
FWHM=`getopt1 "--FWHM" $@`  # "$5"
BrainMask=`getopt1 "--brainmask" $@`  # "$6"
flg_smoothfillnonpos=`getopt1 "--smoothfillnonpos" $@`  # "$7"
flg_fslreorient2std=`getopt1 "--fslreorient2std" $@`  # "$8"
flg_robustfov=`getopt1 "--robustfov" $@`  # "$9"
flg_betrestore=`getopt1 "--betrestore" $@`  # "$10"
flg_forcestrictbrainmask=`getopt1 "--forcestrictbrainmask" $@`  # "$11"
flg_ignorecsf=`getopt1 "--ignorecsf" $@`  # "$12"
flg_ignorextrm=`getopt1 "--ignorextrm" $@`  # "$13"
flg_hpfinit=`getopt1 "--hpfinit" $@`  # "$13"

# default parameters
FWHM=$(defaultopt $FWHM 10)
Type=$(defaultopt $Type 1)
TX=$(defaultopt $BaseName T${Type})
WD=$(defaultopt $WD ./${TX}_biascorr${FWHM})
flg_smoothfillnonpos=$(defaultopt $flg_smoothfillnonpos "TRUE")
flg_fslreorient2std=$(defaultopt $flg_fslreorient2std "FALSE")
flg_robustfov=$(defaultopt $flg_robustfov "FALSE")
flg_betrestore=$(defaultopt $flg_betrestore "FALSE")
flg_forcestrictbrainmask=$(defaultopt $flg_forcestrictbrainmask "TRUE")
flg_ignorecsf=$(defaultopt $flg_ignorecsf "TRUE")
flg_ignorextrm=$(defaultopt $flg_ignorextrm "FALSE")

echo " "
echo " START: RobustBiasCorr"
echo " "

# folder definitions
FSLbin=$FSLDIR/bin
mkdir -p $WD
# if not given, retrieve dir of current script, and assume to be $HCPPIPEDIR_PreFS
[[ -z $HCPPIPEDIR_PreFS ]] && HCPPIPEDIR_PreFS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Record the input options in a log file
if [[ -e $WD/log.txt ]] ; then rm -f $WD/log.txt ; fi
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt


########################################## DO WORK ##########################################

# copy the input image to the working directory using the base name
echo "  working on a copy of the original input"
$FSLbin/imcp $Input $WD/${TX}

# store an original copy if the input image will be processed
if [[ $flg_fslreorient2std = "TRUE" || $flg_robustfov = "TRUE" ]] ; then
  $FSLbin/fslmaths $WD/${TX} $WD/${TX}_orig
fi

# smooth interpolate the zeros in the images
if [[ $flg_smoothfillnonpos = "TRUE" ]] ; then
  echo "  filling non-positive values in image"
  $HCPPIPEDIR_PreFS/SmoothFill.sh --in=$WD/${TX}
fi

# reorient to standard orientation (swapdim)
if [[ $flg_fslreorient2std = "TRUE" ]] ; then
  echo "  reorienting to standard configuration"
  $FSLbin/fslreorient2std $WD/${TX} > $WD/${TX}_orig2std.mat
  $FSLbin/convert_xfm -omat $WD/${TX}_std2orig.mat -inverse $WD/${TX}_orig2std.mat
  $FSLbin/fslreorient2std $WD/${TX} $WD/${TX}
fi

# crop the image to a robust field-of-view
if [[ $flg_robustfov = "TRUE" ]] ; then
  echo "  cropping to a robust field-of-view"
  $FSLbin/immv $WD/${TX} $WD/${TX}_fullfov
  $FSLbin/robustfov -i $WD/${TX}_fullfov -r $WD/${TX} -m $WD/${TX}_roi2nonroi.mat
  $FSLbin/convert_xfm -omat $WD/${TX}_nonroi2roi.mat -inverse $WD/${TX}_roi2nonroi.mat
  $FSLbin/convert_xfm -omat $WD/${TX}_orig2roi.mat -concat $WD/${TX}_nonroi2roi.mat $WD/${TX}_orig2std.mat
  $FSLbin/convert_xfm -omat $WD/${TX}_roi2orig.mat -inverse $WD/${TX}_orig2roi.mat
fi

# determine if a high-pass is needed for the whole image
if [[ -z $flg_hpfinit ]] ; then
  if [[ -z $BrainMask || $flg_forcestrictbrainmask = "TRUE" || $flg_ignorecsf = "TRUE" || $flg_ignorextrm = "TRUE" ]] ; then
    flg_hpfinit="TRUE"
  else
    flg_hpfinit="FALSE"
  fi
fi

# if a high-pass is needed for the whole image
if [[ $flg_hpfinit = "TRUE" ]] ; then
  echo "  high-pass filtering the whole image"
  # low-pass filter the original image (downsample to smooth, than upsample to retrieve resolution)
  $FSLbin/fslmaths $WD/${TX} -subsamp2 -subsamp2 -subsamp2 -subsamp2 $WD/vol16
  $FSLbin/flirt -in $WD/vol16 -ref $WD/${TX} -out $WD/${TX}_s20 -noresampblur -applyxfm -paddingsize 16
  $FSLbin/imrm $WD/vol16
  # divide original image by its low-pass to retreive high-pass
  $FSLbin/fslmaths $WD/${TX} -div $WD/${TX}_s20 $WD/${TX}_hpf
else
  $FSLbin/imcp $WD/${TX} $WD/${TX}_hpf
fi

# 1) extract the brain, or 2) adjust the provided mask, or 3) just use it
if [[ -z $BrainMask ]] ; then
  echo "  extracting a conservative brain mask"
  # do conservative brain extraction
  $FSLbin/bet $WD/${TX}_hpf $WD/${TX}_hpf_brain -m -n -f 0.1

elif [[ $flg_forcestrictbrainmask = "TRUE" ]] ; then
  echo "  ensuring provided brain mask is conservative"
  # copy and binarise brain mask to working directory and rename
  $FSLbin/fslmaths $BrainMask -bin $WD/${TX}_hpf_brain_mask
  $FSLbin/fslmaths $WD/${TX}_hpf -mas $WD/${TX}_hpf_brain_mask $WD/${TX}_hpf_brain
  # ensure the mask is conservative by running bet again
  $FSLbin/bet $WD/${TX}_hpf_brain $WD/${TX}_hpf_brain_strict -m -n -f 0.1
  $FSLbin/fslmaths $WD/${TX}_hpf_brain_strict_mask -mas $WD/${TX}_hpf_brain_mask $WD/${TX}_hpf_brain_strict_mask
  $FSLbin/imcp $WD/${TX}_hpf_brain_strict_mask $WD/${TX}_hpf_brain_mask

else
  # copy and binarise brain mask to working directory and rename
  $FSLbin/fslmaths $BrainMask -bin $WD/${TX}_hpf_brain_mask

fi

# remove CSF from edge of the mask
if [[ $flg_ignorecsf = "TRUE" ]] ; then
  echo "  removing non-brain tissue (mostly CSF) from the edge of the mask"
  thr=$($FSLbin/fslstats $WD/${TX}_hpf -k $WD/${TX}_hpf_brain_mask -M)
  thr=$(echo "$thr" | awk '{print $1/2}')
  $FSLbin/fslmaths $WD/${TX}_hpf -thr $thr -mas $WD/${TX}_hpf_brain_mask -bin $WD/${TX}_hpf_brain_strict_mask
  $FSLbin/fslmaths $WD/${TX}_hpf_brain_strict_mask -binv $WD/${TX}_hpf_brain_inv_mask
  # select only the largest contiguous cluster of low-intensity voxels
  # one could consider to remove all low-intensity voxels, also for example the ventricles. Then it would probably best to raise --minextent to 1000.
  $FSLbin/cluster --in=$WD/${TX}_hpf_brain_inv_mask --thresh=0.5 --minextent=100 --no_table --oindex=$WD/${TX}_hpf_brain_inv_mask
  thr=$($FSLbin/fslstats $WD/${TX}_hpf_brain_inv_mask -R | awk '{print $2}')
  $FSLbin/fslmaths $WD/${TX}_hpf_brain_inv_mask -thr $thr -bin -dilF -eroF -mul -1 -add 1 -mas $WD/${TX}_hpf_brain_mask $WD/${TX}_hpf_brain_mask
fi

# ignore extreme values outside of robust range
if [[ $flg_ignorextrm = "TRUE" ]] ; then
  echo "  ignoring extreme values (both high and low)"
  $FSLbin/fslmaths $WD/${TX}_hpf -mas $WD/${TX}_hpf_brain_mask -thrP 0 -uthrP 100 -bin $WD/${TX}_hpf_brain_mask
fi

# extract the brain from the original image
$FSLbin/fslmaths $WD/${TX} -mas $WD/${TX}_hpf_brain_mask $WD/${TX}_hpf_s20

echo "  high-pass filtering the extracted brain"
# low-pass filter the brain extracted image (downsample to smooth, than upsample to retrieve resolution)
$FSLbin/fslmaths $WD/${TX}_hpf_s20 -subsamp2 -subsamp2 -subsamp2 -subsamp2 $WD/vol16
$FSLbin/flirt -in $WD/vol16 -ref $WD/${TX}_hpf_s20 -out $WD/${TX}_hpf_s20 -noresampblur -applyxfm -paddingsize 16
$FSLbin/imrm $WD/vol16
# smooth the brain mask to the same degree (downsample to smooth, than upsample to retrieve resolution)
$FSLbin/fslmaths $WD/${TX}_hpf_brain_mask -subsamp2 -subsamp2 -subsamp2 -subsamp2 $WD/vol16
$FSLbin/flirt -in $WD/vol16 -ref $WD/${TX}_hpf_brain_mask -out $WD/${TX}_initmask_s20 -noresampblur -applyxfm -paddingsize 16
$FSLbin/imrm $WD/vol16

# create a brain-mask-weighted low-pass image by combining the smooth and high-pass brain mask
$FSLbin/fslmaths $WD/${TX}_hpf_s20 -div $WD/${TX}_initmask_s20 -mas $WD/${TX}_hpf_brain_mask $WD/${TX}_hpf2_s20
# divide original image  by weighted low-pass to retreive improved high-pass
$FSLbin/fslmaths $WD/${TX} -mas $WD/${TX}_hpf_brain_mask -div $WD/${TX}_hpf2_s20 $WD/${TX}_hpf2_brain
# scale high-pass image
$FSLbin/fslmaths $WD/${TX}_hpf2_brain -div 0.993202 -mul 165.000000 $WD/${TX}_hpf2_brain

# run three iterations of fast for improved bias field correction
echo "  estimating bias field using fast: run 1/3"
$FSLbin/fast -o $WD/${TX}_fast1 -l $FWHM -b -B -t $Type --iter=5 --nopve --fixed=0 $WD/${TX}_hpf2_brain
echo "  estimating bias field using fast: run 2/3"
$FSLbin/fast -o $WD/${TX}_fast2 -l $FWHM -b -B -t $Type --iter=5 --nopve --fixed=0 $WD/${TX}_fast1_restore
echo "  estimating bias field using fast: run 3/3"
$FSLbin/fast -o $WD/${TX}_fast3 -l $FWHM -b -B -t $Type --iter=5 --nopve --fixed=0 $WD/${TX}_fast2_restore

echo "  retrieving combined bias field"
# retrieve total bias field by dividing the orignal image by the final bias-corrected image
$FSLbin/fslmaths $WD/${TX} -div $WD/${TX}_fast3_restore -mas $WD/${TX}_hpf_brain_mask $WD/${TX}_fast3_totbias
# make a strict brain mask by eroding the conservative mask
$FSLbin/fslmaths $WD/${TX}_hpf_brain_mask -ero -ero -ero -ero $WD/${TX}_hpf_brain_mask2

echo "  extrapolate the bias field from the eroded brain mask"
# extrapolate the bias field image from the strict brain mask
$FSLbin/fslmaths $WD/${TX}_fast3_totbias -sub 1 $WD/${TX}_fast3_totbias
$FSLbin/fslsmoothfill -i $WD/${TX}_fast3_totbias -m $WD/${TX}_hpf_brain_mask2 -o $WD/${TX}_fast3_bias > /dev/null
$FSLbin/fslmaths $WD/${TX}_fast3_totbias -add 1 $WD/${TX}_fast3_totbias
$FSLbin/fslmaths $WD/${TX}_fast3_bias -add 1 $WD/${TX}_fast3_bias

# give the final bias field a default name
$FSLbin/immv $WD/${TX}_fast3_bias $WD/${TX}_bias

# create the final bias corrected image using the final bias field
$FSLbin/fslmaths $WD/${TX} -div $WD/${TX}_bias $WD/${TX}_restore

# smooth interpolate the zeros in the restored images
if [[ $flg_smoothfillnonpos = "TRUE" ]] ; then
  echo "  filling non-positive values in image"
  $HCPPIPEDIR_PreFS/SmoothFill.sh --in=$WD/${TX}_restore
fi
echo "  bias field estimation finished"

# do optional brain extraction
if [[ $flg_betrestore = "TRUE" ]] ; then
  echo "  extracting brain from restored image"
  $FSLbin/bet $WD/${TX}_restore $WD/${TX}_restore_brain -m -f 0.1
fi

# clean up intermediate files
$FSLbin/imrm $WD/${TX}_s20 $WD/${TX}_hpf $WD/${TX}_hpf_s20 $WD/${TX}_hpf_brain $WD/${TX}_hpf_brain_inv_mask $WD/${TX}_hpf_brain_strict_mask $WD/${TX}_hpf_brain_mask2 $WD/${TX}_hpf2_s20 $WD/${TX}_hpf2_brain $WD/${TX}_fast1_bias $WD/${TX}_fast1_restore $WD/${TX}_fast1_seg $WD/${TX}_initmask_s20 $WD/${TX}_fast2_bias $WD/${TX}_fast2_restore $WD/${TX}_fast2_seg $WD/${TX}_fast3_bias_idxmask $WD/${TX}_fast3_bias_init $WD/${TX}_fast3_bias_vol2 $WD/${TX}_fast3_bias_vol32 $WD/${TX}_fast3_totbias $WD/${TX}_fast3_seg $WD/${TX}_fast3_restore

echo " "
echo " END: RobustBiasCorr"
echo " END: `date`" >> $WD/log.txt

##############################################################################################
