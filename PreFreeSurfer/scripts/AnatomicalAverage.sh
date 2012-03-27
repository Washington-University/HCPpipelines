#!/bin/bash -e

Usage() {
    echo ""
    echo "Usage: `basename $0` [options] <image1> ... <imageN>"
    echo ""
    echo "Compulsory arguments"
    echo "  -o <name>        : output basename"
    echo "  -f <image>       : standard FOV image (e.g. std_fov)"
    echo "Optional arguments"
    echo "  -s <image>       : standard image (e.g. MNI152_T1_2mm)"
    echo "  -m <image>       : standard brain mask (e.g. MNI152_T1_2mm_brain_mask_dil)"
    echo "  -n               : do not crop images"
    echo "  -w <dir>         : local, temporary working directory (to be cleaned up - i.e. deleted)"
    echo "  --noclean        : do not run the cleanup"
    echo "  -v               : verbose output"
    echo "  -h               : display this help message"
    echo ""
    echo "e.g.:  `basename $0` -n -o output_name -r MNI152_T1_2mm -m MNI152_T1_2mm_brain_mask_dil -f std_fov im1 im2"
    echo "       Note that N>=2 (i.e. there must be at least two images in the list)"
    exit 1
}

get_arg2() {
    if [ X$2 = X ] ; then
	echo "Option $1 requires an argument" 1>&2
	exit 1
    fi
    echo $2
}

#########################################################################################################

# deal with options
crop=yes
verbose=no
wdir=
cleanup=yes
StandardImage=${FSLDIR}/data/standard/MNI152_T1_2mm
StandardMask=${FSLDIR}/data/standard/MNI152_T1_2mm_brain_mask_dil

if [ $# -eq 0 ] ; then Usage; exit 0; fi
while [ $# -ge 1 ] ; do
    iarg=$1
    case "$iarg"
	in
	-n)
	    crop=no; 
	    shift;;
	-o)
	    output=`get_arg2 $1 $2`;
	    shift 2;;
	-s)
	    StandardImage=`get_arg2 $1 $2`;
	    shift 2;;
	-m)
	    StandardMask=`get_arg2 $1 $2`;
	    shift 2;;
	-f)
	    StandardFOV=`get_arg2 $1 $2`;
	    shift 2;;
	-w)
	    wdir=`get_arg2 $1 $2`;
	    cleanup=no;
	    shift 2;;
	-v)
	    verbose=yes; 
	    shift;;
	-h)
	    Usage;
	    exit 0;;
	--noclean)
	    cleanup=no;
	    shift;;
	*)
	    if [ `echo $1 | sed 's/^\(.\).*/\1/'` = "-" ] ; then 
		echo "Unrecognised option $1" 1>&2
		exit 1
	    fi
	    imagelist="$imagelist $1"
	    shift;;
    esac
done


if [ X$StandardFOV = X ] ; then
  echo "The compulsory argument -f MUST be used"
  exit 1;
fi

if [ X$output = X ] ; then
  echo "The compulsory argument -o MUST be used"
  exit 1;
fi

if [ `echo $imagelist | wc -w` -lt 2 ] ; then
  Usage;
  echo " "
  echo "Must specify at least two images to average"
  exit 1;
fi

# setup working directory
if [ X$wdir = X ] ; then
    wdir=`$FSLDIR/bin/tmpnam`;
    wdir=${wdir}_wdir
fi
if [ ! -d $wdir ] ; then
    if [ -f $wdir ] ; then 
	echo "A file already exists with the name $wdir - cannot use this as the working directory"
	exit 1;
    fi
    mkdir $wdir
fi

# process imagelist
newimlist=""
for fn in $imagelist ; do
    bnm=`$FSLDIR/bin/remove_ext $fn`;
    bnm=`basename $bnm`;
    $FSLDIR/bin/imln $fn $wdir/$bnm
    newimlist="$newimlist $wdir/$bnm"
done

if [ $verbose = yes ] ; then echo "Images: $imagelist  Output: $output"; fi

# for each image reorient, register to std space, (optionally do "get transformed FOV and crop it based on this")
for fn in $newimlist ; do
  $FSLDIR/bin/fslreorient2std ${fn}.nii.gz ${fn}_reorient
  $FSLDIR/bin/flirt -in ${fn}_reorient -ref "$StandardImage" -omat ${fn}r_to_std.mat -out ${fn}r_to_std -dof 12 -searchrx -30 30 -searchry -30 30 -searchrz -30 30
  $FSLDIR/bin/convert_xfm -omat ${fn}_std_to_im_r.mat -inverse ${fn}r_to_std.mat
  $FSLDIR/bin/flirt -in "$StandardFOV" -ref ${fn}_reorient -init ${fn}_std_to_im_r.mat -applyxfm -out ${fn}r_stdfov_mask 
  $FSLDIR/bin/fslmaths ${fn}r_stdfov_mask -dilF -dilF ${fn}r_stdfov_dil_mask
  roivals=`$FSLDIR/bin/fslstats ${fn}r_stdfov_dil_mask -w`;
  $FSLDIR/bin/fslroi ${fn}_reorient ${fn}_roi $roivals
  # save a matrix that flirt can use to go to and from the original and ROI space
  dx=`$FSLDIR/bin/fslval ${fn}_reorient pixdim1`;
  dy=`$FSLDIR/bin/fslval ${fn}_reorient pixdim2`;
  dz=`$FSLDIR/bin/fslval ${fn}_reorient pixdim3`;
  xmin=`echo $roivals | awk '{ print $1 }'`;
  ymin=`echo $roivals | awk '{ print $3 }'`;
  zmin=`echo $roivals | awk '{ print $5 }'`;
  # now cope with difference in newimage (flirt) and nifti voxel coords
  if [ `$FSLDIR/bin/fslorient ${fn}_reorient` = NEUROLOGICAL ] ; then
      nx=`$FSLDIR/bin/fslval ${fn}_reorient dim1`;
      xsize=`echo $roivals | awk '{ print $2 }'`;
      # calculate voxel distance from far side (NB: xmin + xsize - 1 = voxel coord of far roi edge)
      transx=`echo " ( $nx - 1 - ( $xmin + $xsize - 1 ) ) * $dx" | bc -l`;
  else
      transx=`echo "$xmin * $dx" | bc -l`;
  fi
  transy=`echo "$ymin * $dy" | bc -l`;
  transz=`echo "$zmin * $dz" | bc -l`;
  echo "1 0 0 $transx" > ${fn}_roi2orig.mat
  echo "0 1 0 $transy" >> ${fn}_roi2orig.mat
  echo "0 0 1 $transz" >> ${fn}_roi2orig.mat
  echo "0 0 0 1" >> ${fn}_roi2orig.mat
  $FSLDIR/bin/convert_xfm -omat ${fn}TOroi.mat -inverse ${fn}_roi2orig.mat
done

im1=`echo $newimlist | awk '{ print $1 }'`;
for im2 in $newimlist ; do
    if [ $im2 != $im1 ] ; then
        # register version of two images (whole heads still)
	$FSLDIR/bin/flirt -in ${im2}_roi -ref ${im1}_roi -omat ${im2}_to_im1.mat -out ${im2}_to_im1 -dof 6 -searchrx -30 30 -searchry -30 30 -searchrz -30 30 
	
        # transform std space brain mask
	$FSLDIR/bin/flirt -init ${im2}_std_to_im_r.mat -in "$StandardMask" -ref ${im1}_reorient -out ${im1}r_linmask -applyxfm
	$FSLDIR/bin/fslroi ${im1}r_linmask ${im1}_roi_linmask `$FSLDIR/bin/fslstats ${im1}r_stdfov_dil_mask -w`
	
        # re-register using the brain mask as a weighting image
	$FSLDIR/bin/flirt -in ${im2}_roi -init ${im2}_to_im1.mat -omat ${im2}_to_im1_linmask.mat -out ${im2}_to_im1_linmask -ref ${im1}_roi -refweight ${im1}_roi_linmask -nosearch
    else
	cp $FSLDIR/etc/flirtsch/ident.mat ${im1}_to_im1_linmask.mat
    fi
done

# get the halfway space transforms (midtrans output is the *template* to halfway transform)
translist=""
for fn in $newimlist ; do translist="$translist ${fn}_to_im1_linmask.mat" ; done
$FSLDIR/bin/midtrans --separate=${wdir}/ToHalfTrans --template=${im1}_roi $translist

# interpolate
n=1;
for fn in $newimlist ; do
    num=`$FSLDIR/bin/zeropad $n 4`;
    n=`echo $n + 1 | bc`;
    if [ $crop = yes ] ; then
	$FSLDIR/bin/applywarp -i ${fn}_roi --premat=${wdir}/ToHalfTrans${num}.mat -r ${im1}_roi -o ${wdir}/ImToHalf${num} --interp=spline
    else
	$FSLDIR/bin/convert_xfm -omat ${wdir}/ToHalfTrans${num}.mat -concat ${wdir}/ToHalfTrans${num}.mat ${fn}TOroi.mat
	$FSLDIR/bin/convert_xfm -omat ${wdir}/ToHalfTrans${num}.mat -concat ${im1}_roi2orig.mat ${wdir}/ToHalfTrans${num}.mat
	$FSLDIR/bin/applywarp -i ${fn}_reorient --premat=${wdir}/ToHalfTrans${num}.mat -r ${im1}_reorient -o ${wdir}/ImToHalf${num} --interp=spline  
    fi
done
# average outputs
comm=`echo ${wdir}/ImToHalf* | sed "s@ ${wdir}/ImToHalf@ -add ${wdir}/ImToHalf@g"`;
tot=`echo ${wdir}/ImToHalf* | wc -w`;
$FSLDIR/bin/fslmaths ${comm} -div $tot ${output}



# CLEANUP
if [ $cleanup != no ] ; then
    # the following protects the rm -rf call (making sure that it is not null and really is a directory)
    if [ X$wdir != X ] ; then
	if [ -d $wdir ] ; then
	    # should be safe to call here without trying to remove . or $HOME or /
	    rm -rf $wdir
	fi
    fi
fi

