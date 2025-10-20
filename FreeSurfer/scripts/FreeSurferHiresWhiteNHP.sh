#!/bin/bash
set -e

# Requirements for this script
#  installed versions of: FSL6.0.4 or higher , FreeSurfer (version 6.0.0 or higher) ,
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET7DIR

usage () {
echo "Usage: $0 <SubjectID> <SubjectDIR> <T1w_acpc_dc_restore or T1w_acpc_dc_restore_1mm> <T2w_acpc_dc_restore or T2w_acpc_dc_restore_1mm> <ScaleFactor>"
exit 1;
}
[ "$4" = "" ] && usage

echo -e "\n START: FreeSurferHighResWhite"

SubjectID="$1"
SubjectDIR="$2"
T1wImage="$3" #T1w FreeSurfer Input (Full Resolution)
T2wImage="$4" #T2w FreeSurfer Input (Full Resolution)
ScaleFactor=$5

export SUBJECTS_DIR="$SubjectDIR"
PipelineScripts=${HCPPIPEDIR_FS}
source $HCPPIPEDIR/global/scripts/log.shlib  # Logging related functions
source $HCPPIPEDIR/global/scripts/opts.shlib # Command line option functions

log_SetToolName "FreeSurferHiresWhite.sh"

mridir=$SubjectDIR/$SubjectID/mri
surfdir=$SubjectDIR/$SubjectID/surf

reg=$mridir/transforms/hires21mm.dat
regII=$mridir/transforms/1mm2hires.dat

log_Msg "SPECIES: $SPECIES"

# Copy highres volume inputs or transform them from real to FS space (in RSP orientation)
if [[ $SPECIES =  Human ]] ; then

	log_Msg "Copy hires volume inputs in human"
	$CARET7DIR/wb_command -volume-reorient "$T1wImage".nii.gz RSP "$mridir"/T1w_hires.nii.gz 
	fslmaths "$mridir"/T1w_hires.nii.gz  -abs -add 1 "$mridir"/T1w_hires.nii.gz
 	if [[ ! $T2wImage =~ NONE ]] ; then
		$CARET7DIR/wb_command -volume-reorient "$T2wImage".nii.gz RSP "$mridir"/T2w_hires_init.nii.gz 
		fslmaths "$mridir"/T2w_hires_init.nii.gz  -abs -add 1 "$mridir"/T2w_hires_init.nii.gz 
	fi
else
	log_Msg "Transform T1wImage from real to hires/scaled FS space in NHP"
	RealRes=$(fslval "$T1wImage" pixdim1)
	FSRes=$(echo "$RealRes * $ScaleFactor" | bc -l | awk '{printf "%0.2f",$1}')
	mri_convert $SubjectDIR/$SubjectID/mri/orig.mgz $SubjectDIR/$SubjectID/mri/orig.nii.gz
	# FreeSurfer requires orientation of "LIA" in the FS convention, which corresponds to "RSP" in workbench convention.
	log_Msg "Create hires volume in LIA (FS convention)/RSP (workbench convention)"
	$CARET7DIR/wb_command -volume-reorient "$T1wImage".nii.gz RSP $SubjectDIR/$SubjectID/mri/T1w_RSP.nii.gz
	flirt -in $SubjectDIR/$SubjectID/mri/orig.nii.gz -ref $SubjectDIR/$SubjectID/mri/orig.nii.gz -applyisoxfm $FSRes -o $SubjectDIR/$SubjectID/mri/orig.hires.nii.gz
	$CARET7DIR/wb_command -convert-affine -from-flirt $SubjectDIR/xfms/real2fs.mat "$T1wImage".nii.gz "$T1wImage"_1mm.nii.gz -to-flirt $SubjectDIR/$SubjectID/mri/transforms/realRSP2fsRSP.mat $SubjectDIR/$SubjectID/mri/T1w_RSP.nii.gz $SubjectDIR/$SubjectID/mri/orig.hires.nii.gz
	$CARET7DIR/wb_command -volume-resample $SubjectDIR/$SubjectID/mri/T1w_RSP.nii.gz $SubjectDIR/$SubjectID/mri/orig.hires.nii.gz CUBIC "$mridir"/T1w_hires.nii.gz -affine $SubjectDIR/$SubjectID/mri/transforms/realRSP2fsRSP.mat -flirt $SubjectDIR/$SubjectID/mri/T1w_RSP.nii.gz $SubjectDIR/$SubjectID/mri/orig.hires.nii.gz
	fslmaths "$mridir"/T1w_hires.nii.gz -abs -add 1 "$mridir"/T1w_hires.nii.gz
	mri_convert "$mridir"/T1w_hires.nii.gz "$mridir"/T1w_hires.mgz
	imrm $SubjectDIR/$SubjectID/mri/T1w_RSP.nii.gz
	if [[ ! $T2wImage =~ NONE ]] ; then
		$CARET7DIR/wb_command -volume-reorient "$T2wImage".nii.gz RSP $SubjectDIR/$SubjectID/mri/T2w_RSP.nii.gz
		$CARET7DIR/wb_command -volume-resample $SubjectDIR/$SubjectID/mri/T2w_RSP.nii.gz $SubjectDIR/$SubjectID/mri/orig.hires.nii.gz CUBIC "$mridir"/T2w_hires_init.nii.gz -affine $SubjectDIR/$SubjectID/mri/transforms/realRSP2fsRSP.mat -flirt $SubjectDIR/$SubjectID/mri/T2w_RSP.nii.gz $SubjectDIR/$SubjectID/mri/orig.hires.nii.gz
	  	fslmaths "$mridir"/T2w_hires_init.nii.gz -abs -add 1 "$mridir"/T2w_hires_init.nii.gz
		imrm $SubjectDIR/$SubjectID/mri/T2w_RSP.nii.gz
	fi
fi

cp $SubjectDIR/$SubjectID/surf/lh.white.preaparc $SubjectDIR/$SubjectID/surf/lh.white
cp $SubjectDIR/$SubjectID/surf/lh.curv $SubjectDIR/$SubjectID/surf/lh.curv.prehires
cp $SubjectDIR/$SubjectID/surf/lh.area $SubjectDIR/$SubjectID/surf/lh.area.prehires
cp $SubjectDIR/$SubjectID/label/lh.cortex.label $SubjectDIR/$SubjectID/label/lh.cortex.prehires.label
cp $SubjectDIR/$SubjectID/surf/rh.white.preaparc $SubjectDIR/$SubjectID/surf/rh.white
cp $SubjectDIR/$SubjectID/surf/rh.curv $SubjectDIR/$SubjectID/surf/rh.curv.prehires
cp $SubjectDIR/$SubjectID/surf/rh.area $SubjectDIR/$SubjectID/surf/rh.area.prehires
cp $SubjectDIR/$SubjectID/label/rh.cortex.label $SubjectDIR/$SubjectID/label/rh.cortex.prehires.label

# generate registration between conformed and hires based on headers
# Note that the convention of tkregister2 is that the resulting $reg is the registration 
# matrix that maps from the "--targ" space into the "--mov" space.  So, while $reg is named
# "hires21mm.dat", the matrix actually maps from the 1 mm (FS conformed) space into the hires space).
tkregister2 --mov "$mridir"/T1w_hires.nii.gz --targ $mridir/orig.mgz --noedit --regheader --reg $reg

# map white and pial to hires coords (pial is only for visualization - won't be used later)
# [Note that Xh.sphere.reg doesn't exist yet, which is the default surface registration 
# assumed by mri_surf2surf, so use "--surfreg white"].
if [ `cat ${FREESURFER_HOME}/build-stamp.txt | grep v6.0` ] ; then 
	mri_surf2surf --s $SubjectID --sval-xyz white --reg $reg "$mridir"/T1w_hires.nii.gz --tval-xyz $mridir/orig.mgz --tval white.hires --surfreg white --hemi lh
	mri_surf2surf --s $SubjectID --sval-xyz white --reg $reg "$mridir"/T1w_hires.nii.gz --tval-xyz $mridir/orig.mgz --tval white.hires --surfreg white --hemi rh
elif [ `cat ${FREESURFER_HOME}/build-stamp.txt | grep v5.3.0` ] ; then 
	mri_surf2surf --s $SubjectID --sval-xyz white --reg $reg "$mridir"/T1w_hires.nii.gz --tval-xyz --tval white.hires --surfreg white --hemi lh
	mri_surf2surf --s $SubjectID --sval-xyz white --reg $reg "$mridir"/T1w_hires.nii.gz --tval-xyz --tval white.hires --surfreg white --hemi rh
fi
cp $SubjectDIR/$SubjectID/surf/lh.white $SubjectDIR/$SubjectID/surf/lh.white.prehires
cp $SubjectDIR/$SubjectID/surf/rh.white $SubjectDIR/$SubjectID/surf/rh.white.prehires

if [[ "$SPECIES" != Human ]] ; then
	cp $mridir/aseg.mgz $mridir/wmparc.mgz 
fi

# map the various lowres volumes that mris_make_surfaces needs into the hires coords
for v in wm.mgz wmparc.mgz filled.mgz brain.mgz aseg.mgz ; do
  basename=`echo $v | cut -d "." -f 1`
  mri_convert -rl "$mridir"/T1w_hires.nii.gz -rt nearest $mridir/$v $mridir/$basename.hires.mgz
done

# make sure to create the file control.hires.dat in the scripts dir with at least a few points
# in the wm for the mri_normalize call that comes next

log_Msg "Bias correction of T1w_hires"
if [[ "$SPECIES" = Human ]] ; then

	mri_mask "$mridir"/T1w_hires.nii.gz $mridir/brain.hires.mgz $mridir/T1w_hires.masked.mgz
	mri_convert $mridir/aseg.hires.mgz $mridir/aseg.hires.nii.gz
	leftcoords=`fslstats $mridir/aseg.hires.nii.gz -l 1 -u 3 -c`
	rightcoords=`fslstats $mridir/aseg.hires.nii.gz -l 40 -u 42 -c`

	echo "$leftcoords" > $SubjectDIR/$SubjectID/scripts/control.hires.dat
	echo "$rightcoords" >> $SubjectDIR/$SubjectID/scripts/control.hires.dat
	echo "info" >> $SubjectDIR/$SubjectID/scripts/control.hires.dat
	echo "numpoints 2" >> $SubjectDIR/$SubjectID/scripts/control.hires.dat
	echo "useRealRAS 1" >> $SubjectDIR/$SubjectID/scripts/control.hires.dat

	# do intensity normalization on the hires volume using the white surface 
	mri_normalize -erode 1 -f $SubjectDIR/$SubjectID/scripts/control.hires.dat -min_dist 1 -surface "$surfdir"/lh.white.hires identity.nofile -surface "$surfdir"/rh.white.hires identity.nofile $mridir/T1w_hires.masked.mgz $mridir/T1w_hires.masked.norm.mgz

	highmyelinnorm=100
	mri_convert $mridir/wm.hires.mgz $mridir/wm.hires.nii.gz
	mri_convert $mridir/T1w_hires.masked.norm.mgz $mridir/T1w_hires.masked.norm.nii.gz
	fslmaths $mridir/wm.hires.nii.gz -bin $mridir/wm.roi.nii.gz
	wmmean=$(fslstats $mridir/T1w_hires.nii.gz -k $mridir/wm.roi.nii.gz -m);
	fslmaths $mridir/T1w_hires -div $wmmean -mul $highmyelinnorm $mridir/T1w_hires.norm.nii.gz
	wmmean=$(fslstats $mridir/T1w_hires.masked.norm.nii.gz -k $mridir/wm.roi.nii.gz -m);
	fslmaths $mridir/T1w_hires.masked.norm.nii.gz -div $wmmean -mul $highmyelinnorm $mridir/T1w_hires.masked.norm.nii.gz
	mri_convert $mridir/T1w_hires.norm.nii.gz $mridir/T1w_hires.norm.mgz
	mri_convert $mridir/T1w_hires.masked.norm.nii.gz $mridir/T1w_hires.masked.norm.mgz
	fsl_histogram -i $mridir/T1w_hires.masked.norm.nii.gz -b 254 -m $mridir/T1w_hires.masked.norm.nii.gz -o $mridir/T1w_hires.masked.norm_hist.png
	imrm $mridir/aseg.hires.nii.gz
else
	# NHP T1w requires intensitvely correction for bias with mri_ca_normalize and aseg-based normalize, thus 'transfer' low-pass biasfield from brain.hires to T1w_hires. Sigma follows that in BiasFieldCorrection_sqrtT1wXT2w - TH Dec 2017
	sigma=3.5
	highmyelinnorm=100                     # normalization factor for high-myelin area (e.g. F1, V1). - TH Mar 2023
	log_Msg "Bias correction sigma: $sigma"
	log_Msg "High-melin normalization factor: $highmyelinnorm"
	mri_convert $mridir/brain.hires.mgz $mridir/brain.hires.nii.gz
	fslmaths $mridir/brain.hires -bin $mridir/brain.hires_mask
	fslmaths $mridir/T1w_hires -mas $mridir/brain.hires_mask $mridir/T1w_hires_brain
	fslmaths $mridir/T1w_hires_brain -s $sigma $mridir/T1w_hires_brain_s$sigma
	fslmaths $mridir/brain.hires -s $sigma $mridir/brain.hires_s$sigma
	fslmaths $mridir/brain.hires_mask -s $sigma $mridir/brain.hires_mask_s$sigma
	fslmaths $mridir/T1w_hires_brain_s$sigma -div $mridir/brain.hires_mask_s$sigma $mridir/T1w_hires_brain_bias
	fslmaths $mridir/brain.hires_s$sigma -div $mridir/brain.hires_mask_s$sigma $mridir/brain.hires_bias
	fslmaths $mridir/brain.hires_bias -div  $mridir/T1w_hires_brain_bias -mas $mridir/brain.hires_mask -dilall $mridir/T1w-brain.hires_bias  # biasfield converting from T1w to brain.hires
	fslmaths $mridir/T1w-brain.hires_bias -div $(fslstats $mridir/T1w-brain.hires_bias -k $mridir/brain.hires_mask -p 50) $mridir/T1w-brain.hires_bias
	fslmaths $mridir/T1w_hires -mul $mridir/T1w-brain.hires_bias -mas $mridir/brain.hires_mask $mridir/T1w_hires.masked.norm.nii.gz
	fslmaths $mridir/T1w_hires -mul $mridir/T1w-brain.hires_bias $mridir/T1w_hires.norm.nii.gz
	
	mri_convert $mridir/aseg.hires.mgz $mridir/aseg.hires.nii.gz
	fslmaths $mridir/aseg.hires.nii.gz -thr 2 -uthr 2 -bin -mul 39 -add $mridir/aseg.hires.nii.gz -thr 41 -uthr 41 -bin $mridir/wm.roi.nii.gz
	wmmean=$(fslstats $mridir/T1w_hires.norm.nii.gz -k $mridir/wm.roi.nii.gz -m);
	fslmaths $mridir/T1w_hires.norm.nii.gz -div $wmmean -mul $highmyelinnorm $mridir/T1w_hires.norm.nii.gz
	fslmaths $mridir/T1w_hires.masked.norm.nii.gz -div $wmmean -mul $highmyelinnorm $mridir/T1w_hires.masked.norm.nii.gz
	mri_convert $mridir/T1w_hires.masked.norm.nii.gz $mridir/T1w_hires.masked.norm.mgz
	mri_convert $mridir/T1w_hires.norm.nii.gz $mridir/T1w_hires.norm.mgz
	fsl_histogram -i $mridir/T1w_hires.masked.norm.nii.gz -b 254 -m $mridir/T1w_hires.masked.norm.nii.gz -o $mridir/T1w_hires.masked.norm_hist.png
	imrm $mridir/brain.hires_bias $mridir/T1w_hires_brain $mridir/T1w_hires_brain_bias $mridir/T1w-brain.hires_bias $mridir/T1w_hires_brain_s$sigma $mridir/brain.hires_s$sigma $mridir/brain.hires_mask $mridir/T1w_hires.norm.nii.gz $mridir/T1w_hires.masked.norm.nii.gz $mridir/brain.hires_mask_s$sigma $mridir/brain.hires.nii.gz $mridir/aseg.hires.nii.gz
fi

mri_convert -rl "$mridir"/T1w_hires.nii.gz -rt nearest $mridir/wm.roi.nii.gz $mridir/wm.roi.hires.mgz

# Check if FreeSurfer is version 6.0,1 or 5.2.0 or others.  
if [ `cat ${FREESURFER_HOME}/build-stamp.txt | grep v6.0` ] ; then  # if first_wm_peak was set in v6.0.0 white will be positioned deeper than white/grey boundary - TH Feb 2023
	FIRSTWMPEAK=""
elif [ `cat ${FREESURFER_HOME}/build-stamp.txt | grep v5.3.0` ] ; then
	FIRSTWMPEAK="-first_wm_peak"
elif [ `cat ${FREESURFER_HOME}/build-stamp.txt | grep v5.2.0` ] ; then
	FIRSTWMPEAK=""
fi

log_Msg "Estimte white surfaces using hires T1w"
mris_make_surfaces ${FIRSTWMPEAK} -noaparc -aseg aseg.hires -orig white.hires -filled filled.hires -wm wm.hires -sdir $SubjectDIR -T1 T1w_hires.masked.norm -orig_white white.hires -output .deformed -w 0 $SubjectID lh
mris_make_surfaces ${FIRSTWMPEAK} -noaparc -aseg aseg.hires -orig white.hires -filled filled.hires -wm wm.hires -sdir $SubjectDIR -T1 T1w_hires.masked.norm -orig_white white.hires -output .deformed -w 0 $SubjectID rh
if [ $SPECIES = Marmoset ] ; then
	mris_smooth -n 5 -nw $surfdir/lh.white.deformed $surfdir/lh.white.deformed
	mris_smooth -n 5 -nw $surfdir/rh.white.deformed $surfdir/rh.white.deformed
fi

cp $SubjectDIR/$SubjectID/surf/lh.curv.deformed $SubjectDIR/$SubjectID/surf/lh.curv
cp $SubjectDIR/$SubjectID/surf/lh.area.deformed  $SubjectDIR/$SubjectID/surf/lh.area
cp $SubjectDIR/$SubjectID/surf/rh.curv.deformed $SubjectDIR/$SubjectID/surf/rh.curv
cp $SubjectDIR/$SubjectID/surf/rh.area.deformed  $SubjectDIR/$SubjectID/surf/rh.area
cp $SubjectDIR/$SubjectID/surf/lh.thickness.deformed $SubjectDIR/$SubjectID/surf/lh.thickness
cp $SubjectDIR/$SubjectID/surf/rh.thickness.deformed $SubjectDIR/$SubjectID/surf/rh.thickness

if [[ ! $T2wImage =~ NONE ]] ; then
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

	#if [ ! -e "$mridir"/transforms/T2wtoT1w.mat ] ; then
	if [ "$SPECIES" != "Marmoset" ] ; then
	  # bbreguster does not work well for marmoset data even having good initialization and correct white surface for marmoset. - TH Dec 2017
	  bbregister --s "$SubjectID" --mov "$mridir"/T2w_hires_init.nii.gz --surf white.deformed --init-reg "$mridir"/transforms/eye.dat --t2 --reg "$mridir"/transforms/T2wtoT1w.dat --o "$mridir"/T2w_hires.nii.gz
	else
	  cp "$mridir"/transforms/eye.dat "$mridir"/transforms/T2wtoT1w.dat
	fi

	tkregister2 --noedit --reg "$mridir"/transforms/T2wtoT1w.dat --mov "$mridir"/T2w_hires_init.nii.gz --targ "$mridir"/T1w_hires.nii.gz --fslregout "$mridir"/transforms/T2wtoT1w.mat
	applywarp --interp=spline -i "$mridir"/T2w_hires_init.nii.gz -r "$mridir"/T1w_hires.nii.gz --premat="$mridir"/transforms/T2wtoT1w.mat -o "$mridir"/T2w_hires.nii.gz  # use nn to avoid blurring - TH
	fslmaths "$mridir"/T2w_hires.nii.gz -abs -add 1 "$mridir"/T2w_hires.nii.gz
	fslmaths "$mridir"/T1w_hires.nii.gz -mul "$mridir"/T2w_hires.nii.gz -sqrt "$mridir"/T1wMulT2w_hires.nii.gz

	#else
	#  echo "Warning Reruning FreeSurfer Pipeline"
	#  echo "T2w to T1w Registration Will Not Be Done Again"
	#  echo "Verify that "$T2wImage" has not been fine tuned and then remove "$mridir"/transforms/T2wtoT1w.mat"
	#fi
fi

# convert surfaces from hires to 1mm space
tkregister2 --mov $mridir/orig.mgz --targ "$mridir"/T1w_hires.nii.gz --noedit --regheader --reg $regII
if [ `cat ${FREESURFER_HOME}/build-stamp.txt | grep v6.0` ] ; then 
	mri_surf2surf --s $SubjectID --sval-xyz white.deformed --reg $regII $mridir/orig.mgz --tval-xyz "$mridir"/T1w_hires.nii.gz --tval white --surfreg white --hemi lh
	mri_surf2surf --s $SubjectID --sval-xyz white.deformed --reg $regII $mridir/orig.mgz --tval-xyz "$mridir"/T1w_hires.nii.gz --tval white --surfreg white --hemi rh
elif [ `cat ${FREESURFER_HOME}/build-stamp.txt | grep v5.3.0` ] ; then 
	mri_surf2surf --s $SubjectID --sval-xyz white.deformed --reg $regII $mridir/orig.mgz --tval-xyz --tval white --surfreg white --hemi lh
	mri_surf2surf --s $SubjectID --sval-xyz white.deformed --reg $regII $mridir/orig.mgz --tval-xyz --tval white --surfreg white --hemi rh
fi


if [[ $SPECIES = Human ]] ; then
	cp $SubjectDIR/$SubjectID/label/lh.cortex.deformed.label $SubjectDIR/$SubjectID/label/lh.cortex.label
	cp $SubjectDIR/$SubjectID/label/rh.cortex.deformed.label $SubjectDIR/$SubjectID/label/rh.cortex.label
else   # to suppress anteior insular/subgenual defect in NHP
	cp $SubjectDIR/$SubjectID/label/lh.cortex.prehires.label $SubjectDIR/$SubjectID/label/lh.cortex.label
	cp $SubjectDIR/$SubjectID/label/rh.cortex.prehires.label $SubjectDIR/$SubjectID/label/rh.cortex.label
fi

echo -e "\n END: FreeSurferHighResWhite"

