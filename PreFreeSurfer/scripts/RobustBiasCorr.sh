#!/usr/bin/env bash
set -e

# Requirements for this script
#  installed versions of: FSL (version 5.0.6)
#  environment: as in SetUpHCPPipeline.sh   (or individually: FSLDIR, $HCPPIPEDIR_PreFS)
#  give Lennart Verhagen (lennart.verhagen@psy.ox.ac.uk) a coffee or a pint


#==============================
# overhead
#==============================

Usage() {
cat <<EOF

RobustBiasCorr.sh: Robust correction of spatial intensity bias in an image

Usage: `RobustBiasCorr.sh` [--workingdir=<working dir>]
      --in=<input image>
      [--basename=<output base name>]
      [--Type={1:T1 (default), 2:T2}]
      [--FWHM=<field smoothness kernel FWHM in mm, default 10>]
      [--brainmask=<brain mask image>]
      [--fixnegvalmethod=<none, thr (default), abs, smooth>]
      [--fslreorient2std={TRUE, FALSE (default)}]
      [--robustfov={TRUE, FALSE (default)}]
      [--betrestore={TRUE, FALSE (default)}]
      [--forcestrictbrainmask={TRUE, FALSE (default)}]
      [--ignorecsf={TRUE (default), FALSE}]
      [--ignorextrm={TRUE, FALSE (default)}]
      [--hpfinit={TRUE, FALSE} (default is auto-determined)]

EOF
}

# if no arguments given, return the usage
if [[ $# -eq 0 ]] ; then usage; exit 0; fi

# if too few arguments given, return the usage, exit with error
if [[ $# -lt 1 ]] ; then >&2 usage; exit 1; fi

# default parameters
args=""
FWHM=10
Type=1
flg_fixnegvalmethod=thr
flg_fslreorient2std=FALSE
flg_robustfov=FALSE
flg_betrestore=FALSE
flg_forcestrictbrainmask=TRUE
flg_ignorecsf=TRUE
flg_ignorextrm=FALSE

# parse the input arguments
for a in "$@" ; do
  case $a in
    --workingdir=*)           WD="${a#*=}"; shift ;;
    --in=*)                   Input="${a#*=}"; shift ;;
    --basename=*)             Base="${a#*=}"; shift ;;
    --type=*)                 Type="${a#*=}"; shift ;;
    --FWHM=*)                 FWHM="${a#*=}"; shift ;;
    --brainmask=*)            BrainMask="${a#*=}"; shift ;;
    --fixnegvalmethod=*)      flg_fixnegvalmethod="${a#*=}"; shift ;;
    --fslreorient2std=*)      flg_fslreorient2std="${a#*=}"; shift ;;
    --robustfov=*)            flg_robustfov="${a#*=}"; shift ;;
    --betrestore=*)           flg_betrestore="${a#*=}"; shift ;;
    --forcestrictbrainmask=*) flg_forcestrictbrainmask="${a#*=}"; shift ;;
    --ignorecsf=*)            flg_ignorecsf="${a#*=}"; shift ;;
    --ignorextrm*)            flg_ignorextrm="${a#*=}"; shift ;;
    --hpfinit*)               flg_hpfinit="${a#*=}"; shift ;;
    *)                        args=$(echo "$args" "$a"); shift ;; # unknown option
  esac
done

# set dependent defaults
[[ -z $Base ]] && Base=T"$Type"
[[ -z $WD ]] && WD="./${Base}_biascorr$FWHM"

# check if no redundant arguments have been set
if [[ -n $args ]] ; then
  >&2 echo ""; >&2 echo "unsupported arguments are given:" $args
  exit 1
fi


#==============================
# main code
#==============================

echo ""
echo "  START: RobustBiasCorr"
echo ""

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
echo "" >> $WD/log.txt


########################################## DO WORK ##########################################

# copy the input image to the working directory using the base name
echo "      working on a copy of the original input"
$FSLbin/imcp $Input $WD/$Base

# store an original copy if the input image will be processed
if [[ $flg_fslreorient2std = TRUE || $flg_robustfov = TRUE ]] ; then
  $FSLbin/fslmaths $WD/$Base $WD/${Base}_orig
fi

# fixing negative values in the image
echo "      fixing negative values in image"
$HCPPIPEDIR_PreFS/FixNegVal.sh --in=$WD/$Base --method=$flg_fixnegvalmethod

# reorient to standard orientation (swapdim)
if [[ $flg_fslreorient2std = TRUE ]] ; then
  echo "      reorienting to standard configuration"
  $FSLbin/fslreorient2std $WD/$Base > $WD/${Base}_orig2std.mat
  $FSLbin/convert_xfm -omat $WD/${Base}_std2orig.mat -inverse $WD/${Base}_orig2std.mat
  $FSLbin/fslreorient2std $WD/$Base $WD/$Base
fi

# crop the image to a robust field-of-view
if [[ $flg_robustfov = TRUE ]] ; then
  echo "      cropping to a robust field-of-view"
  $FSLbin/immv $WD/$Base $WD/${Base}_fullfov
  $FSLbin/robustfov -i $WD/${Base}_fullfov -r $WD/${Base} -m $WD/${Base}_roi2nonroi.mat
  $FSLbin/convert_xfm -omat $WD/${Base}_nonroi2roi.mat -inverse $WD/${Base}_roi2nonroi.mat
  $FSLbin/convert_xfm -omat $WD/${Base}_orig2roi.mat -concat $WD/${Base}_nonroi2roi.mat $WD/${Base}_orig2std.mat
  $FSLbin/convert_xfm -omat $WD/${Base}_roi2orig.mat -inverse $WD/${Base}_orig2roi.mat
fi

# determine if a high-pass is needed for the whole image
if [[ -z $flg_hpfinit ]] ; then
  if [[ -z $BrainMask || $flg_forcestrictbrainmask = TRUE || $flg_ignorecsf = TRUE || $flg_ignorextrm = TRUE ]] ; then
    flg_hpfinit=TRUE
  else
    flg_hpfinit=FALSE
  fi
fi

# if a high-pass is needed for the whole image
if [[ $flg_hpfinit = TRUE ]] ; then
  echo "      high-pass filtering the whole image"
  # low-pass filter the original image (downsample to smooth, than upsample to retrieve resolution)
  $FSLbin/fslmaths $WD/${Base} -subsamp2 -subsamp2 -subsamp2 -subsamp2 $WD/vol16
  $FSLbin/flirt -in $WD/vol16 -ref $WD/${Base} -out $WD/${Base}_s20 -noresampblur -applyxfm -paddingsize 16
  $FSLbin/imrm $WD/vol16
  # divide original image by its low-pass to retreive high-pass
  $FSLbin/fslmaths $WD/${Base} -div $WD/${Base}_s20 $WD/${Base}_hpf
else
  $FSLbin/imcp $WD/${Base} $WD/${Base}_hpf
fi

# 1) extract the brain, or 2) adjust the provided mask, or 3) just use it
if [[ -z $BrainMask ]] ; then
  echo "      extracting a conservative brain mask"
  # do conservative brain extraction
  $FSLbin/bet $WD/${Base}_hpf $WD/${Base}_hpf_brain -m -n -f 0.1

elif [[ $flg_forcestrictbrainmask = TRUE ]] ; then
  echo "      ensuring provided brain mask is conservative"
  # copy and binarise brain mask to working directory and rename
  $FSLbin/fslmaths $BrainMask -bin $WD/${Base}_hpf_brain_mask
  $FSLbin/fslmaths $WD/${Base}_hpf -mas $WD/${Base}_hpf_brain_mask $WD/${Base}_hpf_brain
  # ensure the mask is conservative by running bet again
  $FSLbin/bet $WD/${Base}_hpf_brain $WD/${Base}_hpf_brain_strict -m -n -f 0.1
  $FSLbin/fslmaths $WD/${Base}_hpf_brain_strict_mask -mas $WD/${Base}_hpf_brain_mask $WD/${Base}_hpf_brain_strict_mask
  $FSLbin/imcp $WD/${Base}_hpf_brain_strict_mask $WD/${Base}_hpf_brain_mask

else
  # copy and binarise brain mask to working directory and rename
  $FSLbin/fslmaths $BrainMask -bin $WD/${Base}_hpf_brain_mask

fi

# remove CSF from edge of the mask
if [[ $flg_ignorecsf = TRUE ]] ; then
  echo "      removing non-brain tissue (mostly CSF) from the edge of the mask"
  thr=$($FSLbin/fslstats $WD/${Base}_hpf -k $WD/${Base}_hpf_brain_mask -M)
  thr=$(echo "$thr" | awk '{print $1/2}')
  $FSLbin/fslmaths $WD/${Base}_hpf -thr $thr -mas $WD/${Base}_hpf_brain_mask -bin $WD/${Base}_hpf_brain_strict_mask
  $FSLbin/fslmaths $WD/${Base}_hpf_brain_strict_mask -binv $WD/${Base}_hpf_brain_inv_mask
  # select only the largest contiguous cluster of low-intensity voxels
  # one could consider to remove all low-intensity voxels, also for example the ventricles. Then it would probably best to raise --minextent to 1000.
  $FSLbin/cluster --in=$WD/${Base}_hpf_brain_inv_mask --thresh=0.5 --minextent=100 --no_table --oindex=$WD/${Base}_hpf_brain_inv_mask
  thr=$($FSLbin/fslstats $WD/${Base}_hpf_brain_inv_mask -R | awk '{print $2}')
  $FSLbin/fslmaths $WD/${Base}_hpf_brain_inv_mask -thr $thr -bin -dilF -eroF -mul -1 -add 1 -mas $WD/${Base}_hpf_brain_mask $WD/${Base}_hpf_brain_mask
fi

# ignore extreme values outside of robust range
if [[ $flg_ignorextrm = TRUE ]] ; then
  echo "      ignoring extreme values (both high and low)"
  $FSLbin/fslmaths $WD/${Base}_hpf -mas $WD/${Base}_hpf_brain_mask -thrP 0 -uthrP 100 -bin $WD/${Base}_hpf_brain_mask
fi

# extract the brain from the original image
$FSLbin/fslmaths $WD/${Base} -mas $WD/${Base}_hpf_brain_mask $WD/${Base}_hpf_s20

echo "      high-pass filtering the extracted brain"
# low-pass filter the brain extracted image (downsample to smooth, than upsample to retrieve resolution)
$FSLbin/fslmaths $WD/${Base}_hpf_s20 -subsamp2 -subsamp2 -subsamp2 -subsamp2 $WD/vol16
$FSLbin/flirt -in $WD/vol16 -ref $WD/${Base}_hpf_s20 -out $WD/${Base}_hpf_s20 -noresampblur -applyxfm -paddingsize 16
$FSLbin/imrm $WD/vol16
# smooth the brain mask to the same degree (downsample to smooth, than upsample to retrieve resolution)
$FSLbin/fslmaths $WD/${Base}_hpf_brain_mask -subsamp2 -subsamp2 -subsamp2 -subsamp2 $WD/vol16
$FSLbin/flirt -in $WD/vol16 -ref $WD/${Base}_hpf_brain_mask -out $WD/${Base}_initmask_s20 -noresampblur -applyxfm -paddingsize 16
$FSLbin/imrm $WD/vol16

# create a brain-mask-weighted low-pass image by combining the smooth and high-pass brain mask
$FSLbin/fslmaths $WD/${Base}_hpf_s20 -div $WD/${Base}_initmask_s20 -mas $WD/${Base}_hpf_brain_mask $WD/${Base}_hpf2_s20
# divide original image  by weighted low-pass to retreive improved high-pass
$FSLbin/fslmaths $WD/${Base} -mas $WD/${Base}_hpf_brain_mask -div $WD/${Base}_hpf2_s20 $WD/${Base}_hpf2_brain
# scale high-pass image
$FSLbin/fslmaths $WD/${Base}_hpf2_brain -div 0.993202 -mul 165.000000 $WD/${Base}_hpf2_brain

# run three iterations of fast for improved bias field correction
echo "      estimating bias field using fast: run 1/3"
$FSLbin/fast -o $WD/${Base}_fast1 -l $FWHM -b -B -t $Type --iter=5 --nopve --fixed=0 $WD/${Base}_hpf2_brain
echo "      estimating bias field using fast: run 2/3"
$FSLbin/fast -o $WD/${Base}_fast2 -l $FWHM -b -B -t $Type --iter=5 --nopve --fixed=0 $WD/${Base}_fast1_restore
echo "      estimating bias field using fast: run 3/3"
$FSLbin/fast -o $WD/${Base}_fast3 -l $FWHM -b -B -t $Type --iter=5 --nopve --fixed=0 $WD/${Base}_fast2_restore

echo "      retrieving combined bias field"
# retrieve total bias field by dividing the orignal image by the final bias-corrected image
$FSLbin/fslmaths $WD/${Base} -div $WD/${Base}_fast3_restore -mas $WD/${Base}_hpf_brain_mask $WD/${Base}_fast3_totbias
# make a strict brain mask by eroding the conservative mask
$FSLbin/fslmaths $WD/${Base}_hpf_brain_mask -ero -ero -ero -ero $WD/${Base}_hpf_brain_mask2

echo "      extrapolate the bias field from the eroded brain mask"
# extrapolate the bias field image from the strict brain mask
$FSLbin/fslmaths $WD/${Base}_fast3_totbias -sub 1 $WD/${Base}_fast3_totbias
$FSLbin/fslsmoothfill -i $WD/${Base}_fast3_totbias -m $WD/${Base}_hpf_brain_mask2 -o $WD/${Base}_fast3_bias > /dev/null
$FSLbin/fslmaths $WD/${Base}_fast3_totbias -add 1 $WD/${Base}_fast3_totbias
$FSLbin/fslmaths $WD/${Base}_fast3_bias -add 1 $WD/${Base}_fast3_bias

# give the final bias field a default name
$FSLbin/immv $WD/${Base}_fast3_bias $WD/${Base}_bias

# create the final bias corrected image using the final bias field
$FSLbin/fslmaths $WD/${Base} -div $WD/${Base}_bias $WD/${Base}_restore

# fixing negative values in the image
echo "      fixing negative values in image"
$HCPPIPEDIR_PreFS/FixNegVal.sh --in=$WD/${Base}_restore --method=$flg_fixnegvalmethod

echo "      bias field estimation finished"

# do optional brain extraction
if [[ $flg_betrestore = TRUE ]] ; then
  echo "      extracting brain from restored image"
  $FSLbin/bet $WD/${Base}_restore $WD/${Base}_restore_brain -m -f 0.1
fi

# clean up intermediate files
$FSLbin/imrm $WD/${Base}_s20 $WD/${Base}_hpf $WD/${Base}_hpf_s20 $WD/${Base}_hpf_brain $WD/${Base}_hpf_brain_inv_mask $WD/${Base}_hpf_brain_strict_mask $WD/${Base}_hpf_brain_mask2 $WD/${Base}_hpf2_s20 $WD/${Base}_hpf2_brain $WD/${Base}_fast1_bias $WD/${Base}_fast1_restore $WD/${Base}_fast1_seg $WD/${Base}_initmask_s20 $WD/${Base}_fast2_bias $WD/${Base}_fast2_restore $WD/${Base}_fast2_seg $WD/${Base}_fast3_bias_idxmask $WD/${Base}_fast3_bias_init $WD/${Base}_fast3_bias_vol2 $WD/${Base}_fast3_bias_vol32 $WD/${Base}_fast3_totbias $WD/${Base}_fast3_seg $WD/${Base}_fast3_restore

echo ""
echo "  END: RobustBiasCorr"
echo "END: `date`" >> $WD/log.txt

##############################################################################################
