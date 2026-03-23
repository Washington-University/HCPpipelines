#!/bin/bash
# IntesityCor.sh
# Intensity bias correction and normalization in NHP
# Takuya Hayashi, RIKEN BCIL 2016-2024

set -eu

usage_exit() {
      cat <<EOF

  Intenity biasfield correction and normalization in NHP

  Usage for T1w:
	$(basename $0) <T1w input.mgz> <brainmask.mgz> <output.mgz> -t1 [options]
 
  Usage for T2w or T2w FLAIR:
	$(basename $0) <T2w input.mgz> <brainmask.mgz> <output.mgz> -t2 <white matter mask.mgz> [options]

  Options:
	-m <method>,<num> : "FAST,<low pass>" or "ANTS,<spline space>". Default is "FAST,20"
	-s                : strong bias correction

  Outputs are output.mgz, output_brain.mgz and output_brain_histogram.png


EOF
    exit 1;
}

[ "$5" = "" ] && usage_exit

command="$0 $@"
 
in=`echo $1 | sed -e 's/.mgz//'`
mask=`echo $2 | sed -e 's/.mgz//'`
out=`echo $3 | sed -e 's/.mgz//'`
shift 3
if [ "$1" = "-t1" ] ; then
	type=T1
	shift 1
else
	type=T2
	mask2=`echo $2 | sed -e 's/.mgz//'`
	shift 2
fi

strongbiasflag=""
while getopts m:s opt; do
        case "$opt" in
            m)
                method=$(echo "$OPTARG" | cut -d ',' -f1)
                smoothing=$(echo "$OPTARG" | cut -d ',' -f2)
		;;
            s)
                strongbiasflag="--strongbias"
                ;;
              \?)
                usage_exit
                ;;
	esac
done
shift $((OPTIND - 1))

source $HCPPIPEDIR/global/scripts/log.shlib  # Logging related functions
source $HCPPIPEDIR/global/scripts/opts.shlib # Command line option functions
log_SetToolName "$(basename $0)"
# ----------------------------------------------------------------------
log_Msg "Start: $(basename $0)"
# ----------------------------------------------------------------------

method=${method:-FAST}
if [ $method = FAST ] ; then
	lowpass=${smoothing:-20}         
else
	splinespace=${smoothing:-200}
fi

ScaleFactorT1w=110 # white matter value for T1w
ScaleFactorT2w=57  # white matter value for T2w

if [[ $method != FAST && $method != ANTS ]] ; then
	echo "ERROR: unknown method $method"
	exit 1;
fi
if [ $method = FAST ] ; then
	echo "FSLDIR:      $FSLDIR"
	echo "$type lowpass:     $lowpass"

elif [ $method = ANTS ] ; then
	echo "ANTSPATH:    $ANTSPATH"
	echo "$type splinespace  $splinespace"

	if [ -z $ANTSPATH ] ; then
		echo "ERROR: ANTSPATH is not set"
		exit 1;
	fi
fi

tmpdir="`dirname $in`/"`basename $in`".IntensityCor"
mkdir -p $tmpdir
echo "$command" >> $tmpdir/log.txt
echo "PWD = `pwd`" >> $tmpdir/log.txt
echo "date: `date`" >> $tmpdir/log.txt
echo "============================" >> $tmpdir/log.txt
echo "" >> $tmpdir/log.txt

# convert from mgz to nifti
log_Msg "Convert from .mgz to .nii.gz..."
mri_convert "$in".mgz "$tmpdir"/orig.nii.gz -odt float
mri_convert "$mask".mgz "$tmpdir"/mask.nii.gz --like "$tmpdir"/orig.nii.gz
${FSLDIR}/bin/fslmaths "$tmpdir"/orig -mas "$tmpdir"/mask "$tmpdir"/orig_brain

#${FSLDIR}/bin/fslmaths "$tmpdir"/orig_brain -thr 40 "$tmpdir"/orig_brain  # needed for Lyon M146 (Simulated T2w from diffusion MRI)

# run biasfield correciton
if [ $method = FAST ] ; then

	log_Msg "Run fsl_anat..."
	${FSLDIR}/bin/fsl_anat -i "$tmpdir"/orig_brain -o "$tmpdir"/orig_brain --nobet --noreorient --clobber --nocrop --noreg --nononlinreg --noseg --nosubcortseg -s ${lowpass} --nocleanup -t $type $strongbiasflag
	${FSLDIR}/bin/fslmaths "$tmpdir"/orig_brain.anat/${type}_biascorr "$tmpdir"/orig_brain_restore
	${FSLDIR}/bin/fslmaths "$tmpdir"/orig -div "$tmpdir"/orig_brain.anat/${type}_fast_bias "$tmpdir"/orig_restore

elif [ $method = ANTS ] ; then

	log_Msg "Run ANTs..."
	fslmaths "$tmpdir"/orig.nii.gz "$tmpdir"/orig_abs.nii.gz
	LD_LIBRARY_PATH=/usr/local/lib64:$LD_LIBRARY_PATH
	$ANTSPATH/N4BiasFieldCorrection -d 3 -i "$tmpdir"/orig_abs.nii.gz -s 4 -c  "[ 50x50x50x50,0.0000001 ]" -b "[ $splinespace ]" -o "$tmpdir"/orig_restore.nii.gz -v 1 -x "$tmpdir"/mask.nii.gz

fi

# run normaliztion 
log_Msg "Scaling restored image"

if [ $type = T1 ] ; then

	fslmaths "$tmpdir"/orig_brain.anat/T1_fast_seg.nii.gz -thr 3 -uthr 3 -bin "$tmpdir"/wm.roi.nii.gz
	mean=`${FSLDIR}/bin/fslstats "$tmpdir"/orig_brain -k "$tmpdir"/wm.roi.nii.gz -m`
	${FSLDIR}/bin/fslmaths "$tmpdir"/orig_restore -mul $ScaleFactorT1w -div $mean "$tmpdir"/orig_restore_scale -odt char

elif [ $type = T2 ] ; then

	${FREESURFER_HOME}/bin/mri_convert "$mask2".mgz "$tmpdir"/mask2.nii.gz --like "$tmpdir"/orig.nii.gz
	mean=`${FSLDIR}/bin/fslstats "$tmpdir"/orig_restore.nii.gz -k "$tmpdir"/mask2 -M`
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
exit 0;
