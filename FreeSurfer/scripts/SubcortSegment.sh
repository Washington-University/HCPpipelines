#!/bin/bash

# SubcortSegment.sh
# The script creates subcortical segment (aseg) and white matter segment (wm) for NHP brain using FS6. The wm is deweighted
# for cortex and weighted for claustrum and white matter skeleton based on species template. Skeleton weighting is needed
# for NHP brain cortical surface anlaysis, since the white matter is often thin relative to the resolution of MRI and difficult
# to be segmented (Hayashi et al., 2022). The script also accepts manually-defined aseg.edit.mgz or/and wm.edit.mgz and use
# them as aseg.presurf.mgz and wm.mgz respectively in the subsequent process of surface reconstruction.

usage_exit() {
echo "Usage: $(basename $0) <SubjectDIR> <SubjectID> <T1wImage> <TemplateWMSkeleton> <real2fs.world.mat> [mri_segment_args]"
exit 1;
}
[ "$5" = "" ] && usage_exit

SubjectDIR="$1"
SubjectID="$2"
T1wImage=$(remove_ext "$3")
TemplateWMSkeleton="$4"
ScaleVolumeTransform=$5
shift 5
mri_segment_args="$@"

source $HCPPIPEDIR/global/scripts/log.shlib  # Logging related functions
source $HCPPIPEDIR/global/scripts/opts.shlib # Command line option functions
log_SetToolName "$(basename $0)"

AtlasFolder="$SubjectDIR/../MNINonLinear"

	mkdir -p "$AtlasFolder"/ROIs
	mri_convert "$SubjectDIR"/"$SubjectID"/mri/brain.mgz "$SubjectDIR"/"$SubjectID"/mri/brain.nii.gz
	if [ "$TemplateWMSkeleton" != "NONE" ] ; then	
		imcp "$TemplateWMSkeleton" "$AtlasFolder"/ROIs/Atlas_wmskeleton.nii.gz
	fi
	$CARET7DIR/wb_command -convert-affine -from-world "$ScaleVolumeTransform" -to-flirt "$SubjectDIR"/"$SubjectID"/mri/transforms/real2fs.mat "${T1wImage}".nii.gz "$SubjectDIR"/"$SubjectID"/mri/brain.nii.gz
	imrm brain.nii.gz

	DIR=`pwd`
	cd "$SubjectDIR"/"$SubjectID"/mri

	## This section is add-on function of'recon-all -skullstrip and -maskbfs' for creating improved pial surfaces in NHP.
	## It is useful when pial surfaces are too inflated particularly when high signals are found next to 
	## the outer cortical surface (e.g. ventral prefrontal area in macaque). - TH 2017-2023
	if [ -e brainmask.edit.mgz ] ; then                            # test if manually defined brain segment exists
		log_Msg "Found brainmask.edit.mgz. Use it for subsequent analysis"
		vol="brainmask.edit"
		while [ -e ${vol}.mgz ] ; do
			vol="${vol}+"
		done
		cp brainmask.edit.mgz ${vol}.mgz
		mv brainmask.edit.mgz brainmask.mgz
		mri_mask -T brain.mgz brainmask.mgz brain.finalsurfs.mgz
	fi

	## This section is add-on function of'recon-all -calabel' for creating optimized aseg in NHP.
	## This is needed for suppressing 'insular/claustrum errors of white surfaces', and sub-genual
	## 'insufficient inflation errors' of pial surfaces - TH 2017-2023
	if [ ! -e aseg.edit.mgz ] ; then                               # test if manually defined aseg exists
		cp aseg.auto.mgz aseg.presurf.mgz
		log_Msg "Convert claustrum etc to putamen to create aseg.presurf.mgz"
		mri_binarize --i aseg.presurf.mgz --replace 139 51 --replace 58 51 --replace 50 51 --replace 43 51 --replace 138 12 --replace 26 12 --replace 11 12 --replace 4 12 --o aseg.presurf.mgz
	else
		log_Msg "Found aseg.edit.mgz. Use it as aseg.presurf.mgz"
		vol="aseg.edit"
		while [ -e ${vol}.mgz ] ; do
			vol="${vol}+"
		done
		cp aseg.edit.mgz ${vol}.mgz
		mv aseg.edit.mgz aseg.presurf.mgz
	fi

	## This section is add-on function of'recon-all -segmentaion' for creating improved wm.mgz in NHP.
	## This is needed for optimizing segmentation of the white matter with mri_segment_args, deweighting
	## cortical ribbons, weighting claustum and feeding white matter skeleton to suppress 'thin white
	## blade errors of white surfaces' - TH 2017-2023

	if [ ! -e wm.edit.mgz ] ; then  # test if manually defined white matter segment exists
		log_Msg "Run mri_segment with args: $mri_segment_args"
		mri_segment -mprage $mri_segment_args brain.mgz wm.seg.mgz
		log_Msg "Run mri_edit_wm_with_aseg"
		mri_edit_wm_with_aseg wm.seg.mgz brain.mgz aseg.presurf.mgz wm.asegedit.mgz
		log_Msg "Run mri_pretess"
		mri_pretess wm.asegedit.mgz wm norm.mgz wm.mgz
		mri_convert wm.mgz wm.preweight.nii.gz

		log_Msg "Deweighting cortex with aseg"
		cp aseg.auto.mgz aseg+claustrum.mgz
		mri_convert aseg+claustrum.mgz aseg+claustrum.nii.gz
		
		mri_binarize --i aseg+claustrum.nii.gz --replace 42 3 --o aseg.ribbon.nii.gz
		fslmaths aseg.ribbon.nii.gz -thr 3 -uthr 3 -bin aseg.ribbon.nii.gz
		fslmaths aseg.ribbon.nii.gz -binv -mul wm.preweight.nii.gz wm.preskeleton.nii.gz -odt char

		log_Msg "Weighting claustrum with aseg"
		mri_binarize --i aseg+claustrum.nii.gz --replace 138 255 --replace 139 255 --o aseg.claustrum.nii.gz
		fslmaths aseg.claustrum.nii.gz -thr 255 -uthr 255 aseg.claustrum.nii.gz  # Setting 255 is effective for weighting FS white 
		fslmaths wm.preskeleton.nii.gz -max aseg.claustrum.nii.gz wm.preskeleton.nii.gz

		if [ "$TemplateWMSkeleton" != "NONE" ] ; then
			log_Msg "Weighting white matter skeleton" 
			applywarp -i "$AtlasFolder"/ROIs/Atlas_wmskeleton.nii.gz -r brain.nii.gz -w "$AtlasFolder"/xfms/standard2acpc_dc.nii.gz --postmat=transforms/real2fs.mat -o wmskeleton.nii.gz --interp=trilinear
			fslmaths wmskeleton.nii.gz -thr 0.1 -bin -mul 255 wmskeleton.nii.gz 
			fslmaths wmskeleton.nii.gz -max wm.preskeleton.nii.gz wm.nii.gz  # Setting 255 is effective for weighting FS white 
			mri_convert -ns 1 -odt uchar wm.nii.gz wm.mgz
		else
			fslmaths wm.preskeleton.nii.gz wm.nii.gz
			mri_convert -ns 1 -odt uchar wm.nii.gz wm.mgz
		fi

	else
		log_Msg "Found wm.edit.mgz. Use it as wm.mgz"
		vol="wm.edit"
		while [ -e ${vol}.mgz ] ; do
			vol="${vol}+"
		done
		cp wm.edit.mgz ${vol}.mgz
		mv wm.edit.mgz wm.mgz
	fi

	cd $DIR

log_Msg "End: $(basename $0)"

