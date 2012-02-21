#!/bin/sh -e

echo -e "\n do_avg_mprage"

crop=yes;
if [ X$1 = "X-n" ] ; then
  crop=no;
  shift;
fi

if [ $# -lt 3 ] ; then 
 echo "`basename $0` [-n] image1 image2 output ReferenceImage ReferenceMask StandardFOV" ; 
 echo "   -n   do not crop images"
 exit 1
fi

cp $1 ./
cp $2 ./

im1=`remove_ext $1`;
im1=`basename $im1`;
im2=`remove_ext $2`;
im2=`basename $im2`;
output="$3"
ReferenceImage="$4"
ReferenceMask="$5"
StandardFOV="$6"

echo "Images: $im1 and $im2  Output: $output"

# for each image reorient, register to std space, (optionally do "get transformed FOV and crop it based on this")
for fn in $im1 $im2 ; do
  $FSLDIR/bin/fslreorient2std ${fn}.nii.gz ${fn}_reorient
  $FSLDIR/bin/flirt -in ${fn}_reorient -ref "$ReferenceImage" -omat ${fn}r_to_std.mat -out ${fn}r_to_std -dof 12 -searchrx -30 30 -searchry -30 30 -searchrz -30 30
  $FSLDIR/bin/convert_xfm -omat std_to_${fn}r.mat -inverse ${fn}r_to_std.mat
  $FSLDIR/bin/flirt -in "$StandardFOV" -ref ${fn}_reorient -init std_to_${fn}r.mat -applyxfm -out ${fn}r_stdfov_mask 
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

# register version of two images (whole heads still)
$FSLDIR/bin/flirt -in ${im2}_roi -ref ${im1}_roi -omat ${im2}_to_${im1}.mat -out ${im2}_to_${im1} -dof 6 -searchrx -30 30 -searchry -30 30 -searchrz -30 30 

# transform std space brain mask
$FSLDIR/bin/flirt -init std_to_${im2}r.mat -in "$ReferenceMask" -ref ${im1}_reorient -out ${im1}r_linmask -applyxfm
$FSLDIR/bin/fslroi ${im1}r_linmask ${im1}_roi_linmask `$FSLDIR/bin/fslstats ${im1}r_stdfov_dil_mask -w`

# re-register using the brain mask as a weighting image
$FSLDIR/bin/flirt -in ${im2}_roi -init ${im2}_to_${im1}.mat -omat ${im2}_to_${im1}_linmask.mat -out ${im2}_to_${im1}_linmask -ref ${im1}_roi -refweight ${im1}_roi_linmask -nosearch

# get the halfway space transforms (midtrans output is the *template* to halfway transform)
$FSLDIR/bin/midtrans -o ${im1}_to_half.mat --template=${im1}_roi  ${im2}_to_${im1}_linmask.mat  $FSLDIR/etc/flirtsch/ident.mat
$FSLDIR/bin/convert_xfm -omat ${im2}_to_half.mat -concat ${im1}_to_half.mat ${im2}_to_${im1}_linmask.mat

# interpolate and average
if [ $crop = yes ] ; then
    $FSLDIR/bin/applywarp -i ${im1}_roi --premat=${im1}_to_half.mat -r ${im1}_roi -o ${im1}_to_half --interp=spline
    $FSLDIR/bin/applywarp -i ${im2}_roi --premat=${im2}_to_half.mat -r ${im1}_roi -o ${im2}_to_half --interp=spline
else
    $FSLDIR/bin/convert_xfm -omat ${im1}_to_half.mat -concat ${im1}_to_half.mat ${im1}TOroi.mat
    $FSLDIR/bin/convert_xfm -omat ${im2}_to_half.mat -concat ${im2}_to_half.mat ${im2}TOroi.mat
    $FSLDIR/bin/convert_xfm -omat ${im1}_to_half.mat -concat ${im1}_roi2orig.mat ${im1}_to_half.mat
    # NB: the first matrix after the -concat in the line below must be for *im1* not im2 (as the applywarp ref is im1)
    $FSLDIR/bin/convert_xfm -omat ${im2}_to_half.mat -concat ${im1}_roi2orig.mat ${im2}_to_half.mat
    $FSLDIR/bin/applywarp -i ${im1}_reorient --premat=${im1}_to_half.mat -r ${im1}_reorient -o ${im1}_to_half --interp=spline
    $FSLDIR/bin/applywarp -i ${im2}_reorient --premat=${im2}_to_half.mat -r ${im1}_reorient -o ${im2}_to_half --interp=spline  
fi
$FSLDIR/bin/fslmaths ${im1}_to_half -add ${im2}_to_half -div 2 ${output}

echo -e "\n END: do_avg_mprage"

