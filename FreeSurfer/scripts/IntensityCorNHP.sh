#!/bin/bash
# IntensityCorNHP.sh
# Intensity bias correction and normalization in NHP
# Takuya Hayashi, RIKEN BCIL 2016-2024

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

opts_SetScriptDescription "Intensity bias field correction and normalization for NHP"

opts_AddMandatory '--input' 'InputImage' 'image' "input image (.mgz)"
opts_AddMandatory '--brainmask' 'BrainMask' 'image' "brain mask image (.mgz)"
opts_AddMandatory '--output' 'OutputImage' 'image' "output image (.mgz)"
opts_AddMandatory '--type' 'ImageType' 'T1|T2' "image type: T1 or T2"

opts_AddOptional '--wm-mask' 'WMMask' 'image' "white matter mask image (.mgz), required for T2 type"
opts_AddOptional '--method' 'Method' 'FAST|ANTS' "bias correction method (default: FAST)" "FAST"
opts_AddOptional '--smoothing' 'Smoothing' 'number' "smoothing parameter: low pass sigma for FAST (default: 20), spline spacing for ANTS (default: 200)"
opts_AddOptional '--strongbias' 'StrongBias' 'TRUE/FALSE' "use stronger bias field correction (default: FALSE)" "FALSE"

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

# ----------------------------------------------------------------------
log_Msg "Start: $(basename $0)"
# ----------------------------------------------------------------------

# strip .mgz extension
in=$(echo "$InputImage" | sed -e 's/.mgz//')
mask=$(echo "$BrainMask" | sed -e 's/.mgz//')
out=$(echo "$OutputImage" | sed -e 's/.mgz//')

# validate type
if [[ "$ImageType" != "T1" && "$ImageType" != "T2" ]]; then
    log_Err_Abort "unknown --type '$ImageType', must be T1 or T2"
fi

type="$ImageType"

# handle wm-mask for T2
if [[ "$type" == "T2" ]]; then
    if [[ -z "$WMMask" ]]; then
        log_Err_Abort "--wm-mask is required when --type is T2"
    fi
    mask2=$(echo "$WMMask" | sed -e 's/.mgz//')
fi

# validate method
if [[ "$Method" != "FAST" && "$Method" != "ANTS" ]]; then
    log_Err_Abort "unknown --method '$Method', must be FAST or ANTS"
fi

# set smoothing defaults based on method
if [[ "$Method" == "FAST" ]]; then
    lowpass=${Smoothing:-20}
else
    splinespace=${Smoothing:-200}
fi

# parse strongbias boolean
StrongBias=$(opts_StringToBool "$StrongBias")
if ((StrongBias)); then
    strongbiasflag="--strongbias"
else
    strongbiasflag=""
fi

ScaleFactorT1w=110 # white matter value for T1w
ScaleFactorT2w=57  # white matter value for T2w

if [[ "$Method" == "FAST" ]]; then
	echo "FSLDIR:      $FSLDIR"
	echo "$type lowpass:     $lowpass"

elif [[ "$Method" == "ANTS" ]]; then
	echo "ANTSPATH:    $ANTSPATH"
	echo "$type splinespace  $splinespace"

	if [[ -z "${ANTSPATH:-}" ]]; then
		log_Err_Abort "ANTSPATH is not set"
	fi
fi

tmpdir="$(dirname "$in")/$(basename "$in").IntensityCor"
mkdir -p "$tmpdir"
echo "$0 $@" >> "$tmpdir"/log.txt
echo "PWD = $(pwd)" >> "$tmpdir"/log.txt
echo "date: $(date)" >> "$tmpdir"/log.txt
echo "============================" >> "$tmpdir"/log.txt
echo "" >> "$tmpdir"/log.txt

# convert from mgz to nifti
log_Msg "Convert from .mgz to .nii.gz..."
mri_convert "$in".mgz "$tmpdir"/orig.nii.gz -odt float
mri_convert "$mask".mgz "$tmpdir"/mask.nii.gz --like "$tmpdir"/orig.nii.gz
${FSLDIR}/bin/fslmaths "$tmpdir"/orig -mas "$tmpdir"/mask "$tmpdir"/orig_brain

# run biasfield correction
if [[ "$Method" == "FAST" ]]; then

	log_Msg "Run fsl_anat..."
	${FSLDIR}/bin/fsl_anat -i "$tmpdir"/orig_brain -o "$tmpdir"/orig_brain --nobet --noreorient --clobber --nocrop --noreg --nononlinreg --noseg --nosubcortseg -s ${lowpass} --nocleanup -t $type $strongbiasflag
	${FSLDIR}/bin/fslmaths "$tmpdir"/orig_brain.anat/${type}_biascorr "$tmpdir"/orig_brain_restore
	${FSLDIR}/bin/fslmaths "$tmpdir"/orig -div "$tmpdir"/orig_brain.anat/${type}_fast_bias "$tmpdir"/orig_restore

elif [[ "$Method" == "ANTS" ]]; then

	log_Msg "Run ANTs..."
	fslmaths "$tmpdir"/orig.nii.gz "$tmpdir"/orig_abs.nii.gz
	LD_LIBRARY_PATH=/usr/local/lib64:$LD_LIBRARY_PATH
	$ANTSPATH/N4BiasFieldCorrection -d 3 -i "$tmpdir"/orig_abs.nii.gz -s 4 -c  "[ 50x50x50x50,0.0000001 ]" -b "[ $splinespace ]" -o "$tmpdir"/orig_restore.nii.gz -v 1 -x "$tmpdir"/mask.nii.gz

fi

# run normalization
log_Msg "Scaling restored image"

if [[ "$type" == "T1" ]]; then

	fslmaths "$tmpdir"/orig_brain.anat/T1_fast_seg.nii.gz -thr 3 -uthr 3 -bin "$tmpdir"/wm.roi.nii.gz
	mean=$(${FSLDIR}/bin/fslstats "$tmpdir"/orig_brain -k "$tmpdir"/wm.roi.nii.gz -m)
	${FSLDIR}/bin/fslmaths "$tmpdir"/orig_restore -mul $ScaleFactorT1w -div $mean "$tmpdir"/orig_restore_scale -odt char

elif [[ "$type" == "T2" ]]; then

	${FREESURFER_HOME}/bin/mri_convert "$mask2".mgz "$tmpdir"/mask2.nii.gz --like "$tmpdir"/orig.nii.gz
	mean=$(${FSLDIR}/bin/fslstats "$tmpdir"/orig_restore.nii.gz -k "$tmpdir"/mask2 -M)
	${FSLDIR}/bin/fslmaths "$tmpdir"/orig_restore -mul $ScaleFactorT2w -div $mean "$tmpdir"/orig_restore_scale -odt char

fi

# convert from nifti to mgz
log_Msg "Convert back to .mgz..."
${FREESURFER_HOME}/bin/mri_convert -ns 1 -odt uchar "$tmpdir"/orig_restore_scale.nii.gz "$out".mgz --like "$in".mgz
${FSLDIR}/bin/fslmaths "$tmpdir"/orig_restore_scale.nii.gz -mas "$tmpdir"/mask.nii.gz "$tmpdir"/orig_restore_scale_brain.nii.gz
${FSLDIR}/bin/fsl_histogram -i "$tmpdir"/orig_restore_scale_brain.nii.gz -b 254 -m "$tmpdir"/mask.nii.gz -o "$out"_brain_hist.png
${FREESURFER_HOME}/bin/mri_convert -ns 1 -odt uchar "$tmpdir"/orig_restore_scale_brain.nii.gz "$out"_brain.mgz --like "$in".mgz
#rm -rf $tmpdir

# ----------------------------------------------------------------------
log_Msg "End: $(basename $0)"
# ----------------------------------------------------------------------
