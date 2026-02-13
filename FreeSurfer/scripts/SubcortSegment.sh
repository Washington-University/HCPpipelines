#!/bin/bash
# SubcortSegment.sh
# The script edits subcortical segment (aseg) and white matter segment (wm) for NHP brain using FS6. The wm is deweighted
# for cortex and weighted for claustrum and white matter skeleton based on species template. Skeleton weighting is needed
# for NHP brain cortical surface anlaysis, since the white matter is often thin relative to the resolution of MRI and difficult
# to be segmented. The script also accepts manually-defined aseg.edit.mgz or/and wm.edit.mgz and use them as aseg.presurf.mgz
# and wm.mgz respectively in the subsequent process of surface reconstruction.
#
# Takuya Hayashi, RIKEN BDR Brain Connectomics Imaging Lab 

#set -eu

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
# ----------------------------------------------------------------------
log_Msg "Start: $(basename $0)"
# ----------------------------------------------------------------------

mkdir -p "$AtlasFolder"/ROIs
mri_convert "$SubjectDIR"/"$SubjectID"/mri/brain.mgz "$SubjectDIR"/"$SubjectID"/mri/brain.nii.gz

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
		checkfile=brainmask.edit.mgz
		if [ -e "$checkfile" ] ; then
			if [ ! -w "$checkfile" ] ; then
				log_Err_Abort "no permission to write $checkfile"
			fi
		fi

		mv brainmask.edit.mgz brainmask.mgz
		if [ -e brain.finalsurfs.edit.mgz ] ; then
			vol="brain.finalsurfs.edit"
			while [ -e ${vol}.mgz ] ; do
				vol="${vol}+"
			done
			cp brain.finalsurfs.edit.mgz ${vol}.mgz
			checkfile=brain.finalsurfs.edit.mgz
			if [ -e "$checkfile" ] ; then
				if [ ! -w "$checkfile" ] ; then
					log_Err_Abort "no permission to write $checkfile"
				fi
			fi
			mri_mask -T 5 brain.finalsurfs.edit.mgz brainmask.mgz brain.finalsurfs.edit.mgz			
		else
			checkfile=brain.finalsurfs.mgz
			if [ -e "$checkfile" ] ; then
				if [ ! -w "$checkfile" ] ; then
					log_Err_Abort "no permission to write $checkfile"
				fi
			fi
			mri_mask -T 5 brain.mgz brainmask.mgz brain.finalsurfs.mgz
		fi

	fi


	if [ -e brain.finalsurfs.edit.mgz ] ; then
		log_Msg "Found brain.finalsurfs.edit.mgz. Use it as brain.finalsurfs.mgz"
		if [ ! -e brain.finalsurfs.orig.mgz ] ; then
			checkfile=brain.finalsurfs.mgz
			if [ -e "$checkfile" ] ; then
				if [ ! -w "$checkfile" ] ; then
					log_Err_Abort "no permission to write $checkfile"
				fi
			fi
			mv brain.finalsurfs.mgz brain.finalsurfs.orig.mgz
		fi
		vol="brain.finalsurfs.edit"
		while [ -e ${vol}.mgz ] ; do
			vol="${vol}+"
		done
		cp brain.finalsurfs.edit.mgz ${vol}.mgz
		checkfile=brain.finalsurfs.mgz
		if [ -e "$checkfile" ] ; then
			if [ ! -w "$checkfile" ] ; then
				log_Err_Abort "no permission to write $checkfile"
			fi
		fi
		mv brain.finalsurfs.edit.mgz brain.finalsurfs.mgz
	fi

	## This section is add-on function of'recon-all -calabel' for creating optimized aseg in NHP.
	## This is needed for suppressing 'insular/claustrum errors of white surfaces', and sub-genual
	## 'insufficient inflation errors' of pial surfaces (see Autio et al., NeuroImage 2021)- TH 2017-2025
	if [ ! -e aseg.presurf.edit.mgz ] ; then      # test if manually defined aseg exists
		checkfile=aseg.presurf.mgz
		if [ -e "$checkfile" ] ; then
			if [ ! -w "$checkfile" ] ; then
				log_Err_Abort "no permission to write $checkfile"
			fi
		fi
		cp aseg.auto.mgz aseg.presurf.mgz
		log_Msg "Replace claustrum, hippocampus, amygdala to white matter for creating aseg.cortex.mgz"
		# aseg.cortex.mgz is required for making cortex.label
		mri_binarize --i aseg.auto.mgz --replace 139 41 --replace 58 51 --replace 50 51 --replace 43 51 --replace 138 2 --replace 26 12 --replace 11 12 --replace 4 12 --replace 53 41 --replace 54 41 --replace 18 2 --replace 17 2 --o aseg.cortex.mgz
		log_Msg "Replace claustrum, caudate, lateral ventricle to putamen for creating aseg.presurf.mgz"
		# aseg.presurf is required for making white and pial surface
		mri_binarize --i aseg.auto.mgz --replace 139 51 --replace 58 51 --replace 50 51 --replace 43 51 --replace 138 12 --replace 26 12 --replace 11 12 --replace 4 12 --o aseg.presurf.mgz
	else
		log_Msg "Found aseg.presurf.edit.mgz. Use it as aseg.presurf.mgz"
		vol="aseg.presurf.edit"
		while [ -e ${vol}.mgz ] ; do
			vol="${vol}+"
		done
		cp aseg.presurf.edit.mgz ${vol}.mgz
		checkfile=aseg.presurf.mgz
		if [ -e "$checkfile" ] ; then
			if [ ! -w "$checkfile" ] ; then
				log_Err_Abort "no permission to write $checkfile"
			fi
		fi
		mv aseg.presurf.edit.mgz aseg.presurf.mgz
	fi

	## This section is add-on function of'recon-all -segmentaion' for creating improved wm.mgz in NHP.
	## This is needed for optimizing segmentation of the white matter with mri_segment_args, deweighting
	## cortical ribbons, weighting claustum and feeding white matter skeleton to suppress 'thin white
	## blade errors of white surfaces' - TH 2017-2023 (see also Autio et al., NeuroImage 2020)

	if [ ! -e wm.edit.mgz ] ; then  # test if manually defined white matter segment or precalculated wm.mgz exists
		log_Msg "Run mri_segment with args: $mri_segment_args"
		mri_segment -mprage $mri_segment_args brain.mgz wm.seg.mgz
		log_Msg "Run mri_edit_wm_with_aseg"
		mri_edit_wm_with_aseg wm.seg.mgz brain.mgz aseg.presurf.mgz wm.asegedit.mgz
		log_Msg "Run mri_pretess"
		mri_pretess wm.asegedit.mgz wm norm.mgz wm.mgz
		cp wm.mgz wm.orig.mgz
		mri_convert wm.mgz wm.preweight.nii.gz
		log_Msg "Deweighting non-whitematter regions" # avoid white surface errors (e.g. protrusion to gray matter, invasion to cerebellrum, brainstem etc.)
		mri_binarize --i aseg.auto.mgz  --replace 42 0 --replace 3 0 --replace 47 0 --replace 8 0 --replace 46 0 --replace 7 0 --replace 15 0 --replace 16 0 --replace 54 0 --replace 18 0 --replace 53 0 --replace 17 0 --o aseg.wmmask.nii.gz
		fslmaths wm.preweight.nii.gz -mas aseg.wmmask.nii.gz wm.preskeleton.nii.gz -odt char
		log_Msg "Weighting claustrum with aseg" # avoid white surface errors in the insular cortex
		mri_binarize --i aseg.auto.mgz --replace 138 255 --replace 139 255 --o aseg.claustrum.nii.gz
		fslmaths aseg.claustrum.nii.gz -thr 255 -uthr 255 aseg.claustrum.nii.gz  # Setting 255 is effective for weighting FS white 
		fslmaths wm.preskeleton.nii.gz -max aseg.claustrum.nii.gz wm.preskeleton.nii.gz

		if [ "$TemplateWMSkeleton" != "NONE" ] ; then 
		   # White matter skeleton weighting - effective particularly in small sized brain NHP (e.g.,marmoset, cynomolgus) Autio et al., NeuroImage 2020
			log_Msg "Weighting white matter skeleton in aseg.presurf.mgz" 
			imcp "$TemplateWMSkeleton" "$AtlasFolder"/ROIs/Atlas_wmskeleton.nii.gz
			applywarp -i "$AtlasFolder"/ROIs/Atlas_wmskeleton.nii.gz -r brain.nii.gz -w "$AtlasFolder"/xfms/standard2acpc_dc.nii.gz --postmat=transforms/real2fs.mat -o wmskeleton.nii.gz --interp=trilinear
			fslmaths wmskeleton.nii.gz -thr 0.2 -bin -mul 255 wmskeleton.nii.gz   # 255 is effective for weighting FS white
			fslmaths wmskeleton.nii.gz -max wm.preskeleton.nii.gz wm.nii.gz   
			mri_convert -ns 1 -odt uchar wm.nii.gz wm.mgz
			log_Msg "Weighting white matter skeleton in aseg.presurf.mgz" 			
			mri_convert aseg.presurf.mgz aseg.presurf.nii.gz
			fslmaths aseg.presurf.nii.gz -thr 250 -bin aseg.presurf.CC.mask.nii.gz
			xmiddim=$(fslstats aseg.presurf.CC.mask.nii.gz -x | awk '{print $1}')
			fslmaths wmskeleton.nii.gz -roi 0 $((xmiddim-2)) 0 -1 0 -1 0 -1 -bin -mul 41 wmskeleton.R.nii.gz
			fslmaths wmskeleton.nii.gz -roi $((xmiddim+2)) -1 0 -1 0 -1 0 -1 -bin -mul 2 wmskeleton.L.nii.gz
			fslmaths wmskeleton.R.nii.gz -binv -mul aseg.presurf.nii.gz -add wmskeleton.R.nii.gz aseg.presurf.nii.gz
			fslmaths wmskeleton.L.nii.gz -binv -mul aseg.presurf.nii.gz -add wmskeleton.L.nii.gz  aseg.presurf.nii.gz 
			mri_convert aseg.presurf.nii.gz aseg.presurf.mgz
			imrm aseg.presurf.nii.gz aseg.presurf.CC.mask.nii.gz			
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
		checkfile=wm.mgz
		if [ -e "$checkfile" ] ; then
			if [ ! -w "$checkfile" ] ; then
				log_Err_Abort "no permission to write $checkfile"
			fi
		fi
		mv wm.edit.mgz wm.mgz
	fi

cd $DIR
# ----------------------------------------------------------------------
log_Msg "End: $(basename $0)"
# ----------------------------------------------------------------------


