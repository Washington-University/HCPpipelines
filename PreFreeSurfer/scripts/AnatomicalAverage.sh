#!/bin/bash 

# ------------------------------------------------------------------------------
#  Usage Description Function
# ------------------------------------------------------------------------------

set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"

opts_SetScriptDescription "Tool for creating a Anatomical Average"

opts_AddMandatory '--output' 'output' 'name' "output basename"

opts_AddMandatory '--image-list' 'imagesStr' 'image1@image2...' "list of images to average"

#Optional Args
opts_AddOptional '--standard-image' 'StandardImage' 'image' "standard image (e.g. MNI152_T1_2mm)" "$FSLDIR/data/standard/MNI152_T1_2mm.nii.gz"

opts_AddOptional '--standard-mask' 'StandardMask' 'image' "standard brain mask (e.g. MNI152_T1_2mm_brain_mask_dil)" "$FSLDIR/data/standard/MNI152_T1_2mm_brain_mask_dil.nii.gz"

opts_AddOptional '--brain-size' 'BrainSizeOpt' 'number' "pass a brain size value to robustfov"

opts_AddOptional '--crop' 'crop' 'yes OR no' "whether to crop images, default yes" "yes"

opts_AddOptional '--working-dir' 'wdir' 'dir' "temporary working directory" 

opts_AddOptional '--cleanup' 'cleanup' 'yes OR no' "whether to delete the working directory (if set via --working-dir), default yes" "yes"

opts_ParseArguments "$@"

#display the parsed/default values
opts_ShowValues

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

log_Check_Env_Var FSLDIR

crop=$(opts_StringToBool "$crop")
cleanup=$(opts_StringToBool "$cleanup")

#########################################################################################################

IFS='@' read -a imagelist <<<"$imagesStr"

if ((${#imagelist[@]} < 2)) ; then
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
for fn in "${imagelist[@]}" ; do
    bnm=`$FSLDIR/bin/remove_ext $fn`;
    bnm=`basename $bnm`;
    $FSLDIR/bin/imln $fn $wdir/$bnm   ## TODO - THIS FAILS WHEN GIVEN RELATIVE PATHS
    newimlist="$newimlist $wdir/$bnm"
done

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
        #TSC: "-nosearch" only sets angle to 0, still optimizes translation
		$FSLDIR/bin/flirt -in ${im2}_roi -init ${im2}_to_im1.mat -omat ${im2}_to_im1_linmask.mat -out ${im2}_to_im1_linmask -ref ${im1}_roi -refweight ${im1}_roi_linmask -nosearch
    else
		cp $FSLDIR/etc/flirtsch/ident.mat ${im1}_to_im1_linmask.mat
    fi
done

# get the halfway space transforms (midtrans output is the *template* to halfway transform)
#TSC: "halfway" seems to be a misnomer, transforms seem to be from each image all the way to the average template-registered position
translist=""
for fn in $newimlist ; do
    translist="$translist ${fn}_to_im1_linmask.mat"
done
$FSLDIR/bin/midtrans --separate=${wdir}/ToHalfTrans --template=${im1}_roi $translist

# interpolate
n=1;
for fn in $newimlist ; do
    num=`$FSLDIR/bin/zeropad $n 4`;
    n=`echo $n + 1 | bc`;
    if ((crop)) ; then
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
if ((cleanup)) ; then
    # the following protects the rm -rf call (making sure that it is not null and really is a directory)
    #TSC: it shouldn't be possible for wdir to be the empty string, if it was to start with, we set it and then append _wdir to it above
    if [[ "$wdir" != "" ]] ; then
        if [[ -d "$wdir" ]] ; then
            # should be safe to call here without trying to remove . or $HOME or /
            rm -rf "$wdir"
        fi
    fi
fi

