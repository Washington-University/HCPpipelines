#! /bin/bash
set -e

Usage_exit (){
echo "RescaleVolumeAndSurface.sh <SubjectDIR> <SubjectID> <ScaleVolumeMatrix (world.mat)> <T1wImage> <T2wImage> <FLAIR|T2|NONE>"
exit 0;
}
if [ "$6" = "" ] ; then Usage_exit ;fi

SubjectDIR="$1" 
SubjectID="$2"
ScaleVolumeTransform="$(echo $3 | sed -e 's/.world.mat//g')"
T1wImage=$(remove_ext "$4")
T2wImage=$(remove_ext "$5")
t2_or_flair="$6"

source $HCPPIPEDIR/global/scripts/log.shlib  # Logging related functions
source $HCPPIPEDIR/global/scripts/opts.shlib # Command line option functions
log_SetToolName "RescaleVolumeAndSurface.sh"

log_Msg "Moving $SubjectID to ${SubjectID}_scaled"
mv "$SubjectDIR"/"$SubjectID" "$SubjectDIR"/"$SubjectID"_scaled
mridir=$SubjectDIR/$SubjectID/mri
surfdir=$SubjectDIR/$SubjectID/surf
labeldir=$SubjectDIR/$SubjectID/label
scaledmridir="$SubjectDIR"/"$SubjectID"_scaled/mri
scaledsurfdir="$SubjectDIR"/"$SubjectID"_scaled/surf
scaledlabeldir="$SubjectDIR"/"$SubjectID"_scaled/label

mkdir -p ${mridir}/transforms
mkdir -p ${mridir}/orig
mkdir -p ${surfdir}
mkdir -p ${labeldir}

ScaleFactor=$(cat ${ScaleVolumeTransform}.world.mat | awk 'NR==1 {print $1}')
RescaleFactor=$(cat ${ScaleVolumeTransform}.world.mat | awk 'NR==1 {print 1/$1}')
RescaleVolumeTransform=${mridir}/transforms/fs2real

# ----------------------------------------------------------------------
log_Msg "Import inputs" 
# ----------------------------------------------------------------------
mri_convert "$T1wImage".nii.gz ${mridir}/rawavg.mgz
if [ "$T2wImage" != NONE ] ; then 
	mri_convert "$T2wImage".nii.gz ${mridir}/orig/${t2_or_flair}raw.mgz
fi
# ----------------------------------------------------------------------
log_Msg "Checking inputs"
# ----------------------------------------------------------------------
read -a sform <<<"$(fslorient -getsform "$T1wImage")"
newsform=()
for ((i = 0; i < 12; ++i))
do
   newsform+=("$(echo "${sform[$i]} * $ScaleFactor" | bc -l)")
done
dims=("$(fslval "$T1wImage" dim1)" "$(fslval "$T1wImage" dim2)" "$(fslval "$T1wImage" dim3)")
$CARET7DIR/wb_command -volume-create "${dims[@]}" ${mridir}/orig/T1w.nii.gz -sform "${newsform[@]}"
$CARET7DIR/wb_command -volume-resample "$T1wImage".nii.gz ${mridir}/orig/T1w.nii.gz CUBIC ${mridir}/orig/T1w.nii.gz -affine ${ScaleVolumeTransform}.world.mat 
mri_convert ${mridir}/rawavg.mgz ${mridir}/orig/rawavg.nii.gz

fslmaths ${mridir}/orig/T1w.nii.gz -sub ${mridir}/orig/rawavg.nii.gz -abs ${mridir}/orig/absdiff_rawavg-T1w.nii.gz
absdiff=$(fslstats ${mridir}/orig/absdiff_rawavg-T1w.nii.gz -m -p 50)
log_Msg "mean and median absolute diff btw unscaled and scaled volumes: $absdiff"
log_Msg "Note that if T1w.nii.gz and rawavg.nii.gz in ${mridir}/orig are moved or absdiff was too large, you need to re-run PreFreeSurferPipeline"

# ----------------------------------------------------------------------
log_Msg "Creating conform space"
# ----------------------------------------------------------------------
mri_convert ${scaledmridir}/orig.mgz ${scaledmridir}/orig.nii.gz
read -a sform <<<"$(fslorient -getsform ${scaledmridir}/orig.nii.gz)"
newsform=()
for ((i = 0; i < 12; ++i))
do
   newsform+=("$(echo "${sform[$i]} * $RescaleFactor" | bc -l)")
done
dims=("$(fslval ${scaledmridir}/orig.nii.gz dim1)" "$(fslval ${scaledmridir}/orig.nii.gz dim2)" "$(fslval ${scaledmridir}/orig.nii.gz dim3)")
$CARET7DIR/wb_command -volume-create "${dims[@]}" $mridir/orig.nii.gz -sform "${newsform[@]}"
convert_xfm -omat ${RescaleVolumeTransform}.world.mat -inverse ${ScaleVolumeTransform}.world.mat 
$CARET7DIR/wb_command -volume-resample ${scaledmridir}/orig.nii.gz $mridir/orig.nii.gz ENCLOSING_VOXEL $mridir/orig.nii.gz -affine ${RescaleVolumeTransform}.world.mat
mri_convert $mridir/orig.nii.gz $mridir/orig.mgz

# ----------------------------------------------------------------------
log_Msg "Calculating transformation matrices"
# ----------------------------------------------------------------------
$CARET7DIR/wb_command -convert-affine -from-world ${RescaleVolumeTransform}.world.mat -to-flirt ${RescaleVolumeTransform}.mat ${scaledmridir}/orig.nii.gz $mridir/orig.nii.gz
lta_convert --infsl ${RescaleVolumeTransform}.mat --outmni ${RescaleVolumeTransform}.xfm --src ${scaledmridir}/orig.mgz --trg ${mridir}/orig.mgz
lta_convert --infsl ${RescaleVolumeTransform}.mat --outreg ${RescaleVolumeTransform}.dat --src ${scaledmridir}/orig.mgz --trg ${mridir}/orig.mgz
cp ${RescaleVolumeTransform}.mat  ${scaledmridir}/transforms/

# ----------------------------------------------------------------------
log_Msg "Rescaling volumes"
# ----------------------------------------------------------------------
# Rescaling voxel size (note that data is not virtually resampled). Thus resampling type (e.g. trilinear vs nearest) is irrelevant.
for vol in wm.asegedit.mgz brain.finalsurfs.mgz filled.mgz wm.mgz aseg+claustrum.mgz aseg.presurf.mgz; do
	log_Msg " $vol"
	mri_convert -at "${RescaleVolumeTransform}.xfm" -rl ${mridir}/orig.mgz ${scaledmridir}/${vol} ${mridir}/${vol}
done

cp ${mridir}/aseg+claustrum.mgz ${mridir}/aseg.mgz
cp ${mridir}/aseg+claustrum.mgz ${mridir}/wmparc.mgz

# ----------------------------------------------------------------------
log_Msg "Rescaling or copying surface data"
# ----------------------------------------------------------------------
export SUBJECTS_DIR="$SubjectDIR"
for hemi in lh rh ; do
	for surf in white.preaparc ; do
	log_Msg " ${hemi}.${surf}"
		mri_surf2surf --s "$SubjectID"_scaled --sval-xyz $surf --reg-inv "${RescaleVolumeTransform}.dat" ${mridir}/orig.mgz --tval-xyz ${scaledmridir}/orig.mgz --tval ${scaledsurfdir}/${hemi}.${surf}_temp --hemi $hemi
		mv ${scaledsurfdir}/${hemi}.${surf}_temp ${surfdir}/${hemi}.${surf}
	done
done

for hemi in lh rh ; do 
	for surf in sphere sphere.reg curv sulc; do
		cp ${scaledsurfdir}/${hemi}.${surf} ${surfdir}/${hemi}.${surf} 
	done
	for label in cortex.label aparc.annot; do
		cp ${scaledlabeldir}/${hemi}.${label} ${labeldir}/${hemi}.${label}
	done
done

# ----------------------------------------------------------------------
log_Msg "End: RescaleVolumeAndSurface.sh"
# ----------------------------------------------------------------------

exit 0


