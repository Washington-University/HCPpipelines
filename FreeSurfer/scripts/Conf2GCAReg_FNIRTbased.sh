#! /bin/bash
# Conf2GCAReg_FNIRTbased.sh
# The script registers the brain volume (nu.mgz) to GCA template using FNIRT and creates non-linear transformation warpfield (talairach.m3z).
#
# Takuya Hayashi, RIKEN BDR Brain Connectomics Imaging Lab 
# Akiko Uematsu, RIKEN BDR Brain Connectomics Imaging Lab

set -eu

usage_exit() {
echo "Usage: $(basename $0) <SubjectDIR> <SubjectID> <GCA>"
exit 1;
}
[ "$3" = "" ] && usage_exit

SubjectDIR=$1
SubjectID=$2
gca=$3

# requires: 
#  FreeSufer >=6.0.0, FSL >=6, workbench >=1.5.0
#  $SubjectDIR/$SubjectID/mri/nu.mgz
#  $SubjectDIR/$SubjectID/mri/brainmask.mgz

FNIRTConfig=$HCPPIPEDIR/global/config/T1_2_MNI152_2mm.cnf 

source $HCPPIPEDIR/global/scripts/log.shlib  # Logging related functions
source $HCPPIPEDIR/global/scripts/opts.shlib # Command line option functions
log_SetToolName "$(basename $0)"

# ----------------------------------------------------------------------
log_Msg "Start: $(basename $0)"
# ----------------------------------------------------------------------
cd $SubjectDIR/$SubjectID/mri
mkdir -p transforms

# format conversion
mri_convert $gca -nth 0 transforms/gcatemplate.nii.gz
mri_convert nu.mgz nu.nii.gz
mri_mask nu.mgz brainmask.mgz nu_brain.mgz
mri_convert nu_brain.mgz nu_brain.nii.gz
mri_convert brainmask.mgz brainmask.nii.gz

# ----------------------------------------------------------------------
log_Msg "Linear registration to GCA template using FLIRT"
# ----------------------------------------------------------------------
flirt -in nu_brain.nii.gz -ref transforms/gcatemplate.nii.gz -dof 12 -omat transforms/conf2gca.mat -o transforms/norm_to_gcatemplate_linear.nii.gz ;
# mri_ca_normalize reqires lta w/ vox2vox format
lta_convert --infsl transforms/conf2gca.mat --outlta transforms/conf2gca.lta --src nu_brain.nii.gz --trg transforms/gcatemplate.nii.gz --ltavox2vox;

# ----------------------------------------------------------------------
log_Msg "Normalize intensity using mri_ca_normalize"
# ----------------------------------------------------------------------
mri_ca_normalize -c ctrl_pts.mgz -mask brainmask.mgz nu.mgz $gca transforms/conf2gca.lta norm.mgz

# ----------------------------------------------------------------------
log_Msg "Non linear registration to GCA template using FNIRT"
# ----------------------------------------------------------------------
mri_convert norm.mgz norm.nii.gz
fslmaths transforms/gcatemplate.nii.gz -bin transforms/gcatemplate_bin.nii.gz
fslmaths brainmask.nii.gz -bin brainmask_bin.nii.gz

fnirt --in=norm.nii.gz --ref=transforms/gcatemplate.nii.gz --aff=transforms/conf2gca.mat --config=$FNIRTConfig --fout=transforms/conf2gca.nii.gz --cout=transforms/conf2gca_coef.nii.gz --iout=transforms/norm_to_gcatemplate.nii.gz --jout=transforms/conf2gca_jac.nii.gz -v --intout=transforms/conf2gca_int.nii.gz --refmask=transforms/gcatemplate_bin.nii.gz --inmask=brainmask_bin.nii.gz

mv norm_to_gcatemplate.log transforms/

# ----------------------------------------------------------------------
log_Msg "Resample warpfield to 1mm"
# ----------------------------------------------------------------------
flirt -in transforms/gcatemplate.nii.gz -ref transforms/gcatemplate.nii.gz -applyisoxfm 1 -o transforms/gcatemplate_1mm.nii.gz
applywarp -i transforms/conf2gca.nii.gz -r transforms/gcatemplate_1mm.nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o transforms/conf2gca_1mm.nii.gz 

# ----------------------------------------------------------------------
log_Msg "Convert warpfield"
# ----------------------------------------------------------------------
$CARET7DIR/wb_command -convert-warpfield -from-fnirt transforms/conf2gca_1mm.nii.gz nu.nii.gz -to-itk transforms/conf2gca_itk.nii.gz
mri_warp_convert --initk transforms/conf2gca_itk.nii.gz --outm3z transforms/conf2gca.m3z --insrcgeom nu.mgz

# check warping & classification
# mri_convert -i norm.mgz --like transforms/gcatemplate.nii.gz -at transforms/conf2gca.m3z -o norm_to_gcatemplate_test.mgz
# export OMP_NUM_THREADS="8"
# mri_ca_label -relabel_unlikely 9 .3 -prior 0.5 -align norm.mgz transforms/conf2gca.m3z $gca aseg.auto_noCCseg.mgz

# ----------------------------------------------------------------------
# overwrite freesurfer outputs and finish
# ----------------------------------------------------------------------
if [ -e transforms/talairach.lta ] ; then
	if [ ! -e transforms/talairach.orig.lta ] ; then
		mv transforms/talairach.lta transforms/talairach.orig.lta
	fi
fi
mv transforms/conf2gca.lta transforms/talairach.lta

if [ -e transforms/talairach.m3z ] ; then
	if [ ! -e transforms/talairach.orig.m3z ] ; then
		mv transforms/talairach.m3z transforms/talairach.orig.m3z
	fi
fi
mv transforms/conf2gca.m3z transforms/talairach.m3z
rm brainmask.nii.gz brainmask_bin.nii.gz transforms/gcatemplate_bin.nii.gz nu.nii.gz nu_brain.nii.gz transforms/conf2gca_itk.nii.gz
# ----------------------------------------------------------------------
log_Msg "End: $(basename $0)"
# ----------------------------------------------------------------------

