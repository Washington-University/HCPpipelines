#!/bin/bash
if [ -z "$2" ]; then
    echo "Usage: PostFreesurferLongTPUpdate.sh <cross-sectional experiment dir> <longitudinal experiment dir> [longitudinal template dir]"
    exit -1
fi

cross_dir=$1; shift
long_dir=$1; shift
if [ -n "$1" ]; then fs_template_dir=$1; shift
exp_cross=`basename $cross_dir`
exp_long=`basename $long_dir`
exp_cross_fs_dir=$cross_dir/T1w/$exp_cross
exp_long_fs_dir=$long_dir/T1w/$exp_long

#0. Copy Freesurfer longitudinal output (if FS long dir is provided)
if [ -n "$fs_template_dir" ]; then 
    cp -lr $fs_template_dir/T1w/$exp_long $long_dir/T1w/
fi

#1. Copy MNINonLinear
cp -lr $cross_dir/MNINonLinear $long_dir/
#2. Copy T1w
cp -l $cross_dir/T1w/* $long_dir/T1w/
dirs=(ACPCAlignment BiasFieldCorrection_sqrtT1wXT2w BrainExtraction_FNIRTbased xfms)
for dir in ${dirs[*]}; do
    cp -lr $cross_dir/T1w/$dir $long_dir/T1w/
done
pushd $cross_dir/T1w; cp -ar fsaverage $long_dir/T1w/; popd
#2. Copy T2w
mkdir -p $long_dir/T2w
cp -lr $cross_dir/T2w/* $long_dir/T2w

#3. Copy missing files under freesurfer subject dir; do not overwrite.
cp -lrn $cross_dir/T1w/$exp_cross/* $long_dir/T1w/$exp_long/

l