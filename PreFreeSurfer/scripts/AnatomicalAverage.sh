#!/bin/bash 

# ------------------------------------------------------------------------------
#  Usage Description Function
# ------------------------------------------------------------------------------

script_name=$(basename "${0}")

Usage() {
	cat <<EOF

Usage: ${script_name} [options] <image1> ... <imageN>

Compulsory arguments
  -o <name>        : output basename
Optional arguments
  -s <image>       : standard image (e.g. MNI152_T1_2mm)
  -m <image>       : standard brain mask (e.g. MNI152_T1_2mm_brain_mask_dil)
  -n               : do not crop images
  -w <dir>         : local, temporary working directory (to be cleaned up - i.e. deleted)
  --noclean        : do not run the cleanup
  -v               : verbose output
  -h               : display this help message

e.g.:  ${script_name} -n -o output_name im1 im2

Note that N>=2 (i.e., there must be at least two images in the list)

EOF
}

# Allow script to return a Usage statement, before any other output or checking
if [ "$#" = "0" ]; then
    Usage
    exit 1
fi

# ------------------------------------------------------------------------------
#  Check that HCPPIPEDIR is defined and Load Function Libraries
# ------------------------------------------------------------------------------

if [ -z "${HCPPIPEDIR}" ]; then
  echo "${script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
  exit 1
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib

# ------------------------------------------------------------------------------
#  Verify required environment variables are set and log value
# ------------------------------------------------------------------------------

log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FSLDIR

################################################ SUPPORT FUNCTIONS ##################################################

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
StandardImage=$FSLDIR/data/standard/MNI152_T1_2mm.nii.gz
StandardMask=$FSLDIR/data/standard/MNI152_T1_2mm_brain_mask_dil.nii.gz

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
	-w)
	    wdir=`get_arg2 $1 $2`;
	    cleanup=no;
	    shift 2;;
	-b)
	    BrainSizeOpt=`get_arg2 $1 $2`;
	    BrainSizeOpt="-b $BrainSizeOpt";
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


if [ X$output = X ] ; then
  log_Err_Abort "The compulsory argument -o MUST be used"
fi

if [ `echo $imagelist | wc -w` -lt 2 ] ; then
  Usage;
  log_Err_Abort "Must specify at least two images to average"
fi

# setup working directory
if [ X$wdir = X ] ; then
    wdir=`$FSLDIR/bin/tmpnam`;
    wdir=${wdir}_wdir
fi
if [ ! -d $wdir ] ; then
    if [ -f $wdir ] ; then 
		log_Err_Abort "A file already exists with the name $wdir - cannot use this as the working directory"
    fi
    mkdir $wdir
fi

# process imagelist
newimlist=""
for fn in $imagelist ; do
    bnm=`$FSLDIR/bin/remove_ext $fn`;
    bnm=`basename $bnm`;
    $FSLDIR/bin/imln $fn $wdir/$bnm   ## TODO - THIS FAILS WHEN GIVEN RELATIVE PATHS
    newimlist="$newimlist $wdir/$bnm"
done

if [ $verbose = yes ] ; then
	log_Msg "Images: $imagelist  Output: $output"
fi

# for each image reorient, register to std space, (optionally do "get transformed FOV and crop it based on this")
for fn in $newimlist ; do
  $FSLDIR/bin/fslreorient2std ${fn}.nii.gz ${fn}_reorient
  $FSLDIR/bin/robustfov -i ${fn}_reorient -r ${fn}_roi -m ${fn}_roi2orig.mat $BrainSizeOpt
  $FSLDIR/bin/convert_xfm -omat ${fn}TOroi.mat -inverse ${fn}_roi2orig.mat
  $FSLDIR/bin/flirt -in ${fn}_roi -ref "$StandardImage" -omat ${fn}roi_to_std.mat -out ${fn}roi_to_std -dof 12 -searchrx -30 30 -searchry -30 30 -searchrz -30 30
  $FSLDIR/bin/convert_xfm -omat ${fn}_std2roi.mat -inverse ${fn}roi_to_std.mat
done

# register images together, using standard space brain masks
im1=`echo $newimlist | awk '{ print $1 }'`;
for im2 in $newimlist ; do
    if [ $im2 != $im1 ] ; then
        # register version of two images (whole heads still)
		$FSLDIR/bin/flirt -in ${im2}_roi -ref ${im1}_roi -omat ${im2}_to_im1.mat -out ${im2}_to_im1 -dof 6 -searchrx -30 30 -searchry -30 30 -searchrz -30 30 
		
        # transform std space brain mask
		$FSLDIR/bin/flirt -init ${im1}_std2roi.mat -in "$StandardMask" -ref ${im1}_roi -out ${im1}_roi_linmask -applyxfm
		
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
	$FSLDIR/bin/applywarp --rel -i ${fn}_roi --premat=${wdir}/ToHalfTrans${num}.mat -r ${im1}_roi -o ${wdir}/ImToHalf${num} --interp=spline
    else
	$FSLDIR/bin/convert_xfm -omat ${wdir}/ToHalfTrans${num}.mat -concat ${wdir}/ToHalfTrans${num}.mat ${fn}TOroi.mat
	$FSLDIR/bin/convert_xfm -omat ${wdir}/ToHalfTrans${num}.mat -concat ${im1}_roi2orig.mat ${wdir}/ToHalfTrans${num}.mat
	$FSLDIR/bin/applywarp --rel -i ${fn}_reorient --premat=${wdir}/ToHalfTrans${num}.mat -r ${im1}_reorient -o ${wdir}/ImToHalf${num} --interp=spline  
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

