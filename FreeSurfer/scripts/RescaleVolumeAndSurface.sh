#! /bin/bash
# RescaleVolumeAndSurface.sh

#set -eu

Usage_exit (){
echo "RescaleVolumeAndSurface.sh <SubjectDIR> <SubjectID> <ScaleVolumeMatrix (world.mat)> <T1wImage> <T2wImage> <FLAIR|T2|NONE> [ScaleSuffix]"
exit 0;
}
[ "$6" = "" ] && Usage_exit

# ------------------------------------------------------------------------------
#  Check that HCPPIPEDIR is defined and Load Function Libraries
# ------------------------------------------------------------------------------

if [ -z "${HCPPIPEDIR}" ]; then
  echo "${script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
  exit 1
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source $HCPPIPEDIR/global/scripts/opts.shlib                   # Command line option functions

# ------------------------------------------------------------------------------
#  Verify required environment variables are set and log value
# ------------------------------------------------------------------------------
validate_freesurfer_version ()
{
	if [ -z "${FREESURFER_HOME}" ] ; then
		log_Err_Abort "FREESURFER_HOME must be set"
	fi
	
	freesurfer_version_file="${FREESURFER_HOME}/build-stamp.txt"

	if [ -f "${freesurfer_version_file}" ] ; then
		freesurfer_version_string=$(cat "${freesurfer_version_file}")
		log_Msg "INFO: Determined that FreeSurfer full version string is: ${freesurfer_version_string}"
	else
		log_Err_Abort "Cannot tell which version of FreeSurfer you are using."
	fi

	# strip out extraneous stuff from FreeSurfer version string
	freesurfer_version_string_array=(${freesurfer_version_string//-/ })
	freesurfer_version=${freesurfer_version_string_array[5]}
	freesurfer_version=${freesurfer_version#v} # strip leading "v"

	log_Msg "INFO: Determined that FreeSurfer version is: ${freesurfer_version}"

	# break FreeSurfer version into components
	# primary, secondary, and tertiary
	# version X.Y.Z ==> X primary, Y secondary, Z tertiary
	freesurfer_version_array=(${freesurfer_version//./ })

	freesurfer_primary_version="${freesurfer_version_array[0]}"
	freesurfer_primary_version=${freesurfer_primary_version//[!0-9]/}

	freesurfer_secondary_version="${freesurfer_version_array[1]}"
	freesurfer_secondary_version=${freesurfer_secondary_version//[!0-9]/}

	freesurfer_tertiary_version="${freesurfer_version_array[2]}"
	freesurfer_tertiary_version=${freesurfer_tertiary_version//[!0-9]/}

	if [[ $(( ${freesurfer_primary_version} )) -lt 5 ]] ; then
		# e.g. 4.y.z, 5.y.z
		log_Err_Abort "FreeSurfer version 5.3.0 or greater is required."
	fi
}
validate_freesurfer_version

log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FSLDIR

SubjectDIR="$1" 
SubjectID="$2"
ScaleVolumeTransform="$3"
T1wImage=$(remove_ext "$4")
T2wImage=$(remove_ext "$5")
t2_or_flair="$6"
ScaleSuffix="${7:-_scaled}"

log_SetToolName "RescaleVolumeAndSurface.sh"
log_Msg "START: RescaleVolumeAndSurface"
log_Msg "Moving $SubjectID to ${SubjectID}${ScaleSuffix}"
mv "$SubjectDIR"/"$SubjectID" "$SubjectDIR"/"$SubjectID""$ScaleSuffix"

mridir=$SubjectDIR/$SubjectID/mri
surfdir=$SubjectDIR/$SubjectID/surf
labeldir=$SubjectDIR/$SubjectID/label
scaledmridir="$SubjectDIR"/"$SubjectID""$ScaleSuffix"/mri
scaledsurfdir="$SubjectDIR"/"$SubjectID""$ScaleSuffix"/surf
scaledlabeldir="$SubjectDIR"/"$SubjectID""$ScaleSuffix"/label

mkdir -p ${mridir}/transforms
mkdir -p ${mridir}/orig
mkdir -p ${surfdir}
mkdir -p ${labeldir}
cp $ScaleVolumeTransform ${mridir}/transforms/real2fs.world.mat 
ScaleVolumeTransformRoot=${mridir}/transforms/real2fs
ScaleFactor=$(cat ${ScaleVolumeTransformRoot}.world.mat | awk 'NR==1 {print $1}')
RescaleFactor=$(cat ${ScaleVolumeTransformRoot}.world.mat | awk 'NR==1 {print 1/$1}')
RescaleVolumeTransform=${mridir}/transforms/fs2real

# ----------------------------------------------------------------------
log_Msg "Checking PreFS inputs" 
# ----------------------------------------------------------------------
# copying current PreFreesurfer outputs (T1w_acpc_dc_restore & T2w_acpc_dc_restore)
mri_convert "$T1wImage".nii.gz ${mridir}/rawavg.mgz
if [ "$T2wImage" != NONE ] ; then 
	mri_convert "$T2wImage".nii.gz ${mridir}/orig/${t2_or_flair}raw.mgz
fi
# ----------------------------------------------------------------------
log_Msg "Checking FS inputs"
# ----------------------------------------------------------------------
# copying current FS input and rescale
mri_convert ${scaledmridir}/orig/001.mgz ${scaledmridir}/orig/001.nii.gz
${HCPPIPEDIR}/global/scripts/ScaleVolume.sh ${scaledmridir}/orig/001.nii.gz $RescaleFactor ${mridir}/orig/RescaledT1w.nii.gz ${RescaleVolumeTransform}.world.mat

# test difference between current PreFS and FS volumes
mri_convert ${mridir}/rawavg.mgz ${mridir}/orig/rawavg.nii.gz
fslmaths ${mridir}/orig/RescaledT1w.nii.gz -sub ${mridir}/orig/rawavg.nii.gz -abs ${mridir}/orig/absdiff_RescaledT1w-rawavg.nii.gz
absdiff=$(fslstats ${mridir}/orig/absdiff_RescaledT1w-rawavg.nii.gz -m -p 50)
echo $absdiff >  ${mridir}/orig/absdiff_RescaledT1w-rawavg.txt
imrm ${mridir}/orig/absdiff_RescaledT1w-rawavg.nii.gz
log_Msg "absolute diff btw rescaled T1w (RescaledT1w) and native T1w (rawavg): $absdiff (mean and median)"
log_Msg "If the absdiff is too large, something is wrong and you need to correct it"


# ----------------------------------------------------------------------
log_Msg "Creating conform space"
# ----------------------------------------------------------------------
mri_convert ${scaledmridir}/orig.mgz ${scaledmridir}/orig.nii.gz
${HCPPIPEDIR}/global/scripts/ScaleVolume.sh ${scaledmridir}/orig.nii.gz $RescaleFactor ${mridir}/orig.nii.gz 
mri_convert ${mridir}/orig.nii.gz ${mridir}/orig.mgz

# ----------------------------------------------------------------------
log_Msg "Calculating transformation matrices"
# ----------------------------------------------------------------------
$CARET7DIR/wb_command -convert-affine -from-world ${RescaleVolumeTransform}.world.mat -to-flirt ${RescaleVolumeTransform}.mat ${scaledmridir}/orig.nii.gz $mridir/orig.nii.gz
lta_convert --infsl ${RescaleVolumeTransform}.mat --outmni ${RescaleVolumeTransform}.xfm --src ${scaledmridir}/orig.mgz --trg ${mridir}/orig.mgz
lta_convert --infsl ${RescaleVolumeTransform}.mat --outreg ${RescaleVolumeTransform}.dat --src ${scaledmridir}/orig.mgz --trg ${mridir}/orig.mgz
lta_convert --infsl ${RescaleVolumeTransform}.mat --outlta ${RescaleVolumeTransform}.lta --src ${scaledmridir}/orig.mgz --trg ${mridir}/orig.mgz
cp ${RescaleVolumeTransform}.mat  ${scaledmridir}/transforms/

if [ "$T2wImage" != NONE ] ; then
	$CARET7DIR/wb_command -convert-affine -from-world ${ScaleVolumeTransformRoot}.world.mat -to-flirt ${ScaleVolumeTransformRoot}.mat ${mridir}/orig/rawavg.nii.gz ${scaledmridir}/orig/001.nii.gz
	lta_convert --infsl ${ScaleVolumeTransformRoot}.mat --outlta ${ScaleVolumeTransformRoot}.lta --src ${mridir}/orig/${t2_or_flair}raw.mgz --trg ${scaledmridir}/orig/${t2_or_flair}raw.mgz
fi

# ----------------------------------------------------------------------
log_Msg "Rescaling volumes"
# ----------------------------------------------------------------------
# Rescaling voxel size (note that data is not virtually resampled). Thus resampling type (e.g. trilinear vs nearest) is irrelevant.
if [[ ${freesurfer_primary_version} = 6 && $(echo "$ScaleFactor < 6" | bc) = 1 ]] ; then  # brain is larger than the rat
	volsf="brain.finalsurfs.mgz rawavg.${t2_or_flair}.prenorm.mgz rawavg.${t2_or_flair}.norm.mgz "
	volsu="aseg.presurf.mgz aseg.auto.mgz filled.mgz wm.mgz aparc+aseg.mgz aparc.a2009s+aseg.mgz ribbon.edit.mgz"
	if [ "$T2wImage" != NONE ] ; then
		mri_concatenate_lta ${ScaleVolumeTransformRoot}.lta ${scaledmridir}/transforms/${t2_or_flair}raw.rawavg.lta ${scaledmridir}/transforms/real2fs2${t2_or_flair}raw.lta
		mri_concatenate_lta ${scaledmridir}/transforms/real2fs2${t2_or_flair}raw.lta ${RescaleVolumeTransform}.lta ${mridir}/transforms/${t2_or_flair}raw.lta
	fi
else   
	volsf="brain.finalsurfs.mgz rawavg.${t2_or_flair}.prenorm.mgz rawavg.${t2_or_flair}.norm.mgz"
	volsu="wm.asegedit.mgz filled.mgz wm.mgz aseg.presurf.mgz aseg.auto.mgz aparc+aseg.mgz aparc.a2009s+aseg.mgz ribbon.edit.mgz"
fi

for vol in $volsf ; do
	if [ -e ${scaledmridir}/${vol} ] ; then
		log_Msg " $vol"
		mri_convert -at "${RescaleVolumeTransform}.xfm" -rl ${mridir}/orig.mgz ${scaledmridir}/${vol} ${mridir}/${vol}
	fi	
done

for vol in $volsu ; do
	if [ -e ${scaledmridir}/${vol} ] ; then
		log_Msg " $vol"
		mri_convert -odt uchar -at "${RescaleVolumeTransform}.xfm" -rl ${mridir}/orig.mgz ${scaledmridir}/${vol} ${mridir}/${vol}
	fi
done

cp ${mridir}/aseg.auto.mgz ${mridir}/aseg.mgz
cp ${mridir}/aseg.auto.mgz ${mridir}/wmparc.mgz

# ----------------------------------------------------------------------
log_Msg "Rescaling or copying surface data"
# ----------------------------------------------------------------------
if [[ ${freesurfer_primary_version} = 6 && $(echo "$ScaleFactor < 6" | bc) = 1 ]] ; then
	surfs="white pial orig"
else
	surfs="white.preaparc orig"
fi

export SUBJECTS_DIR="$SubjectDIR"
for hemi in lh rh ; do
	for surf in $surfs; do
	log_Msg " ${hemi}.${surf}"
		mri_surf2surf --s "$SubjectID"${ScaleSuffix} --sval-xyz $surf --reg-inv "${RescaleVolumeTransform}.dat" ${mridir}/orig.mgz --tval-xyz ${scaledmridir}/orig.mgz --tval ${scaledsurfdir}/${hemi}.${surf}_temp --hemi $hemi
		mv ${scaledsurfdir}/${hemi}.${surf}_temp ${surfdir}/${hemi}.${surf}
	done
done

for hemi in lh rh ; do
	for surf in sphere sphere.reg curv sulc; do
		cp ${scaledsurfdir}/${hemi}.${surf} ${surfdir}/${hemi}.${surf} 
	done
	if [ $(echo "$ScaleFactor == 1" | bc) != 1 ] ; then
		mris_calc -o ${surfdir}/${hemi}.thickness ${scaledsurfdir}/${hemi}.thickness div $ScaleFactor
		mris_calc -o ${surfdir}/${hemi}.sulc ${scaledsurfdir}/${hemi}.sulc div $ScaleFactor
	else 
		cp ${scaledsurfdir}/${hemi}.thickness ${surfdir}/${hemi}.thickness
		cp ${scaledsurfdir}/${hemi}.sulc ${surfdir}/${hemi}.sulc
	fi
	for label in cortex.label aparc.annot; do
		cp ${scaledlabeldir}/${hemi}.${label} ${labeldir}/${hemi}.${label}
	done
	for annot in aparc.a2009s.annot ; do
		if [ -e ${scaledlabeldir}/${hemi}.${annot} ] ; then
			cp ${scaledlabeldir}/${hemi}.${annot} ${labeldir}/${hemi}.${annot}
		fi
	done
done

# ----------------------------------------------------------------------
log_Msg "End: RescaleVolumeAndSurface.sh"
# ----------------------------------------------------------------------

log_Msg "END: RescaleVolumeAndSurface"

exit 0


