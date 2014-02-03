#!/bin/bash
set -e
echo -e "\n START: FreeSurferHighResWhite"

SubjectID="$1"
SubjectDIR="$2"
T1wImage="$3" #T1w FreeSurfer Input (Full Resolution)
T2wImage="$4" #T2w FreeSurfer Input (Full Resolution)

export SUBJECTS_DIR="$SubjectDIR"

mridir=$SubjectDIR/$SubjectID/mri
surfdir=$SubjectDIR/$SubjectID/surf

reg=$mridir/transforms/hires21mm.dat
regII=$mridir/transforms/1mm2hires.dat
fslmaths "$T1wImage" -abs -add 1 "$mridir"/T1w_hires.nii.gz
hires="$mridir"/T1w_hires.nii.gz

# generate registration between conformed and hires based on headers
tkregister2 --mov "$mridir"/T1w_hires.nii.gz --targ $mridir/orig.mgz --noedit --regheader --reg $reg
# map white and pial to hires coords (pial is only for visualization - won't be used later)
cp $SubjectDIR/$SubjectID/surf/lh.white $SubjectDIR/$SubjectID/surf/lh.sphere.reg
cp $SubjectDIR/$SubjectID/surf/rh.white $SubjectDIR/$SubjectID/surf/rh.sphere.reg
mri_surf2surf --s $SubjectID --sval-xyz white --reg $reg "$mridir"/T1w_hires.nii.gz --tval-xyz --tval white.hires --hemi lh
mri_surf2surf --s $SubjectID --sval-xyz white --reg $reg "$mridir"/T1w_hires.nii.gz --tval-xyz --tval white.hires --hemi rh

cp $SubjectDIR/$SubjectID/surf/lh.white $SubjectDIR/$SubjectID/surf/lh.white.prehires
cp $SubjectDIR/$SubjectID/surf/rh.white $SubjectDIR/$SubjectID/surf/rh.white.prehires

# make sure to create the file control.hires.dat in the scripts dir with at least a few points
# in the wm for the mri_normalize call that comes next

# map the various lowres volumes that mris_make_surfaces needs into the hires coords
for v in wm.mgz filled.mgz brain.mgz aseg.mgz ; do
  basename=`echo $v | cut -d "." -f 1`
  mri_convert -rl "$mridir"/T1w_hires.nii.gz -rt nearest $mridir/$v $mridir/$basename.hires.mgz
done

# remove nonbrain tissue
mri_mask "$mridir"/T1w_hires.nii.gz $mridir/brain.hires.mgz $mridir/T1w_hires.masked.mgz

mri_convert $mridir/aseg.hires.mgz $mridir/aseg.hires.nii.gz
leftcoords=`fslstats $mridir/aseg.hires.nii.gz -l 1 -u 3 -c`
rightcoords=`fslstats $mridir/aseg.hires.nii.gz -l 40 -u 42 -c`

echo "$leftcoords" > $SubjectDIR/$SubjectID/scripts/control.hires.dat
echo "$rightcoords" >> $SubjectDIR/$SubjectID/scripts/control.hires.dat
echo "info" >> $SubjectDIR/$SubjectID/scripts/control.hires.dat
echo "numpoints 2" >> $SubjectDIR/$SubjectID/scripts/control.hires.dat
echo "useRealRAS 1" >> $SubjectDIR/$SubjectID/scripts/control.hires.dat

# do intensity normalization on the hires volume using the white surface (use locations that 
mri_normalize -erode 1 -f $SubjectDIR/$SubjectID/scripts/control.hires.dat -min_dist 1 -surface "$surfdir"/lh.white.hires identity.nofile -surface "$surfdir"/rh.white.hires identity.nofile $mridir/T1w_hires.masked.mgz $mridir/T1w_hires.masked.norm.mgz

#Check if FreeSurfer is version 5.2.0 or not.  If it is not, use new -first_wm_peak mris_make_surfaces flag
if [ -z `cat ${FREESURFER_HOME}/build-stamp.txt | grep v5.2.0` ] ; then
  FIRSTWMPEAK="-first_wm_peak"
else
  FIRSTWMPEAK=""
fi

#deform the surfaces
mris_make_surfaces ${FIRSTWMPEAK} -noaparc -aseg aseg.hires -orig white.hires -filled filled.hires -wm wm.hires -sdir $SubjectDIR -T1 T1w_hires.masked.norm -orig_white white.hires -output .deformed -w 0 $SubjectID lh
mris_make_surfaces ${FIRSTWMPEAK} -noaparc -aseg aseg.hires -orig white.hires -filled filled.hires -wm wm.hires -sdir $SubjectDIR -T1 T1w_hires.masked.norm -orig_white white.hires -output .deformed -w 0 $SubjectID rh


#Fine Tune T2w to T1w Registration

echo "$SubjectID" > "$mridir"/transforms/eye.dat
echo "1" >> "$mridir"/transforms/eye.dat
echo "1" >> "$mridir"/transforms/eye.dat
echo "1" >> "$mridir"/transforms/eye.dat
echo "1 0 0 0" >> "$mridir"/transforms/eye.dat
echo "0 1 0 0" >> "$mridir"/transforms/eye.dat
echo "0 0 1 0" >> "$mridir"/transforms/eye.dat
echo "0 0 0 1" >> "$mridir"/transforms/eye.dat
echo "round" >> "$mridir"/transforms/eye.dat

if [ ! -e "$mridir"/transforms/T2wtoT1w.mat ] ; then
  bbregister --s "$SubjectID" --mov "$T2wImage" --surf white.deformed --init-reg "$mridir"/transforms/eye.dat --t2 --reg "$mridir"/transforms/T2wtoT1w.dat --o "$mridir"/T2w_hires.nii.gz
  tkregister2 --noedit --reg "$mridir"/transforms/T2wtoT1w.dat --mov "$T2wImage" --targ "$mridir"/T1w_hires.nii.gz --fslregout "$mridir"/transforms/T2wtoT1w.mat
  applywarp --interp=spline -i "$T2wImage" -r "$mridir"/T1w_hires.nii.gz --premat="$mridir"/transforms/T2wtoT1w.mat -o "$mridir"/T2w_hires.nii.gz
  fslmaths "$mridir"/T2w_hires.nii.gz -abs -add 1 "$mridir"/T2w_hires.nii.gz
  fslmaths "$mridir"/T1w_hires.nii.gz -mul "$mridir"/T2w_hires.nii.gz -sqrt "$mridir"/T1wMulT2w_hires.nii.gz
else
  echo "Warning Reruning FreeSurfer Pipeline"
  echo "T2w to T1w Registration Will Not Be Done Again"
  echo "Verify that "$T2wImage" has not been fine tuned and then remove "$mridir"/transforms/T2wtoT1w.mat"
fi

tkregister2 --mov $mridir/orig.mgz --targ "$mridir"/T1w_hires.nii.gz --noedit --regheader --reg $regII
mri_surf2surf --s $SubjectID --sval-xyz white.deformed --reg $regII $mridir/orig.mgz --tval-xyz --tval white --hemi lh
mri_surf2surf --s $SubjectID --sval-xyz white.deformed --reg $regII $mridir/orig.mgz --tval-xyz --tval white --hemi rh

cp $SubjectDIR/$SubjectID/surf/lh.curv $SubjectDIR/$SubjectID/surf/lh.curv.prehires
cp $SubjectDIR/$SubjectID/surf/lh.area $SubjectDIR/$SubjectID/surf/lh.area.prehires
cp $SubjectDIR/$SubjectID/label/lh.cortex.label $SubjectDIR/$SubjectID/label/lh.cortex.prehires.label
cp $SubjectDIR/$SubjectID/surf/rh.curv $SubjectDIR/$SubjectID/surf/rh.curv.prehires
cp $SubjectDIR/$SubjectID/surf/rh.area $SubjectDIR/$SubjectID/surf/rh.area.prehires
cp $SubjectDIR/$SubjectID/label/rh.cortex.label $SubjectDIR/$SubjectID/label/rh.cortex.prehires.label


cp $SubjectDIR/$SubjectID/surf/lh.curv.deformed $SubjectDIR/$SubjectID/surf/lh.curv
cp $SubjectDIR/$SubjectID/surf/lh.area.deformed  $SubjectDIR/$SubjectID/surf/lh.area
cp $SubjectDIR/$SubjectID/label/lh.cortex.deformed.label $SubjectDIR/$SubjectID/label/lh.cortex.label
cp $SubjectDIR/$SubjectID/surf/rh.curv.deformed $SubjectDIR/$SubjectID/surf/rh.curv
cp $SubjectDIR/$SubjectID/surf/rh.area.deformed  $SubjectDIR/$SubjectID/surf/rh.area
cp $SubjectDIR/$SubjectID/label/rh.cortex.deformed.label $SubjectDIR/$SubjectID/label/rh.cortex.label


rm $SubjectDIR/$SubjectID/surf/lh.sphere.reg
rm $SubjectDIR/$SubjectID/surf/rh.sphere.reg

echo -e "\n END: FreeSurferHighResWhite"

