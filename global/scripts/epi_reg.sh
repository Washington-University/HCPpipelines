#!/bin/sh

Usage() {
  echo "Usage: `basename $0` <EPI image> <wholehead T1 image> <brain extracted T1 image> <output name>"
  echo "       `basename $0` <EPI image> <wholehead T1 image> <brain extracted T1 image> <output name> <fieldmap rad/s> <wholehead fieldmap mag> <brain extracted fieldmap mag> <EPI echo spacing (dwell time)> <pe dir> [refweight]"
  echo " "
  echo "Second case is when using fieldmaps: echo spacing (dwell time) in seconds; phase encoding direction = x/y/z/-x/-y/-z" 
}

FLIRTDIR=`dirname $0`;

if [ $# -lt 4 ] ; then
    Usage
    exit 0;
fi

vepi=`$FSLDIR/bin/remove_ext $1`;
vrefhead=`$FSLDIR/bin/remove_ext $2`;
vrefbrain=`$FSLDIR/bin/remove_ext $3`;
vout=`$FSLDIR/bin/remove_ext $4`;
use_fmap=no;
use_weighting=no;

if [ $# -ge 9 ] ; then
    use_fmap=yes;
    fmaprads=`$FSLDIR/bin/remove_ext $5`;
    fmapmaghead=`$FSLDIR/bin/remove_ext $6`;
    fmapmagbrain=`$FSLDIR/bin/remove_ext $7`;
    dwell=$8;
    # These are consistent with the ones used in FUGUE (this has been checked)
    if [ $9 = "x" ] ; then pe_dir=1; fdir="x"; fi
    if [ $9 = "y" ] ; then pe_dir=2; fdir="y"; fi
    if [ $9 = "z" ] ; then pe_dir=3; fdir="z"; fi
    if [ $9 = "-x" ] ; then pe_dir=-1; fdir="x-"; fi
    if [ $9 = "-y" ] ; then pe_dir=-2; fdir="y-"; fi
    if [ $9 = "-z" ] ; then pe_dir=-3; fdir="z-"; fi
    if [ $9 = "x-" ] ; then pe_dir=-1; fdir="x-"; fi
    if [ $9 = "y-" ] ; then pe_dir=-2; fdir="y-"; fi
    if [ $9 = "z-" ] ; then pe_dir=-3; fdir="z-"; fi
    if [ X${pe_dir} = X ] ; then
	echo "Error: invalid phase encode direction specified";
	exit 2;
    fi
    if [ $# -ge 10 ] ; then refweight="${10}"; use_weighting=yes; echo REFWEIGHT = $refweight ; fi
else
    if [ $# -ne 4 ] ; then
	Usage
	exit 1;
    fi
fi

# create the WM segmentation
if [ `$FSLDIR/bin/imtest ${vrefbrain}_wmseg` = 0 ] ; then
    echo "Running FAST segmentation"
    $FSLDIR/bin/fast ${vrefbrain}
    $FSLDIR/bin/fslmaths ${vrefbrain}_pve_2 -thr 0.5 -bin ${vrefbrain}_wmseg
fi
# make a WM edge map for visualisation (good to overlay in FSLView)
if [ `$FSLDIR/bin/imtest ${vrefbrain}_wmedge` = 0 ] ; then
  $FSLDIR/bin/fslmaths ${vrefbrain}_wmseg -edge -bin -mas ${vrefbrain}_wmseg ${vrefbrain}_wmedge
fi

# do a standard flirt pre-alignment
echo "FLIRT pre-alignment"
$FSLDIR/bin/flirt -ref ${vrefbrain} -in ${vepi} -dof 6 -omat ${vout}_init.mat

####################

if [ $use_fmap = no ] ; then

# NO FIELDMAP
    # now run the bbr
    echo "Running BBR"
    $FSLDIR/bin/flirt -ref ${vrefhead} -in ${vepi} -dof 6 -cost bbr -wmseg ${vrefbrain}_wmseg -init ${vout}_init.mat -omat ${vout}.mat -out ${vout} -schedule $FSLDIR/etc/flirtsch/bbr.sch
    $FSLDIR/bin/applywarp -i ${vepi} -r ${vrefhead} -o ${vout} --premat=${vout}.mat --interp=spline

####################

else

# WITH FIELDMAP
    echo "Registering fieldmap to structural"
    # register fmap to structural image
    $FSLDIR/bin/flirt -in ${fmapmagbrain} -ref ${vrefbrain} -dof 6 -omat ${fmapmagbrain}2str_init.mat
    $FSLDIR/bin/flirt -in ${fmapmaghead} -ref ${vrefhead} -dof 6 -init ${fmapmagbrain}2str_init.mat -omat ${fmapmagbrain}2str.mat -out ${fmapmagbrain}2str -nosearch
    # unmask the fieldmap (necessary to avoid edge effects)
    $FSLDIR/bin/fslmaths ${fmapmagbrain} -abs -bin ${fmaprads}_mask
    $FSLDIR/bin/fslmaths ${fmaprads} -abs -bin -mul ${fmaprads}_mask ${fmaprads}_mask
    $FSLDIR/bin/fugue --loadfmap=${fmaprads} --mask=${fmaprads}_mask --unmaskfmap --savefmap=${fmaprads}_unmasked --unwarpdir=${fdir}   # the direction here should take into account the initial affine (it needs to be the direction in the EPI)
    $FSLDIR/bin/flirt -in ${fmaprads}_unmasked -ref ${vrefhead} -applyxfm -init ${fmapmagbrain}2str.mat -out ${fmaprads}2str

    # run bbr with fieldmap
    echo "Running BBR with fieldmap"
    if [ $use_weighting = yes ] ; then wopt="-refweight $refweight"; else wopt=""; fi
    $FSLDIR/bin/flirt -ref ${vrefhead} -in ${vepi} -dof 6 -cost bbr -wmseg ${vrefbrain}_wmseg -init ${vout}_init.mat -omat ${vout}.mat -out ${vout}_1vol -schedule $FSLDIR/etc/flirtsch/bbr.sch -echospacing ${dwell} -pedir ${pe_dir} -fieldmap ${fmaprads}2str $wopt

    # make equivalent warp fields
    echo "Making warp fields and applying registration to EPI series"
    $FSLDIR/bin/convert_xfm -omat ${vout}_inv.mat -inverse ${vout}.mat
    $FSLDIR/bin/convert_xfm -omat ${fmaprads}2epi.mat -concat ${vout}_inv.mat ${fmapmagbrain}2str.mat
    $FSLDIR/bin/flirt -in ${fmaprads}_unmasked -ref ${vepi} -applyxfm -init ${fmaprads}2epi.mat -out ${fmaprads}2epi
    $FSLDIR/bin/fugue --loadfmap=${fmaprads}2epi --saveshift=${fmaprads}2epi_shift --dwell=${dwell} --unwarpdir=${fdir}
    $FSLDIR/bin/convertwarp -r ${vrefhead} -s ${fmaprads}2epi_shift --postmat=${vout}.mat -o ${vout}_warp --shiftdir=${fdir} --absout
    $FSLDIR/bin/applywarp -i ${vepi} -r ${vrefhead} -o ${vout} -w ${vout}_warp --interp=spline --abs

fi

####################



