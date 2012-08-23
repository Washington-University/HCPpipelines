#!/bin/bash 
set -e
echo -e "\n START: OneStepResampling"

WorkingDirectory="$1"
InputfMRI="$2"
T1wImage="$3"
FinalfMRIResolution="$4"
AtlasSpaceFolder="$5"
fMRIToStructuralInput="$6"
StructuralToStandard="$7"
OutputTransform="$8"
MotionMatrixFolder="$9"
MotionMatrixPrefix="${10}"
OutputfMRI="${11}"
FreeSurferBrainMask="${12}"
BiasField="${13}"
GradientDistortionField="${14}"

BiasFieldFile=`basename "$BiasField"`
T1wImageFile=`basename $T1wImage`
FreeSurferBrainMaskFile=`basename "$FreeSurferBrainMask"`


#Save TR for later
TR_vol=`fslval "$InputfMRI" pixdim4 | cut -d " " -f 1`
NumFrames=`fslval "$InputfMRI" dim4`

#Create fMRIres standard space files for T1w image, wmparc, and brain mask, don't trust FLIRT to do spline interpolation with -applyisoxfm

if [ "$FinalfMRIResolution" = "2" ] ; then
  applywarp --interp=spline -i "$T1wImage" -r $FSLDIR/data/standard/MNI152_T1_2mm --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$WorkingDirectory"/"$T1wImageFile""$FinalfMRIResolution"
elif [ "$FinalfMRIResolution" = "1" ] ; then
  applywarp --interp=spline -i "$T1wImage" -r $FSLDIR/data/standard/MNI152_T1_1mm --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$WorkingDirectory"/"$T1wImageFile""$FinalfMRIResolution"
else
  flirt -interp spline -in "$T1wImage" -ref "$T1wImage" -applyisoxfm $FinalfMRIResolution -out "$WorkingDirectory"/"$T1wImageFile""$FinalfMRIResolution"
  applywarp --interp=spline -i "$T1wImage" -r "$WorkingDirectory"/"$T1wImageFile""$FinalfMRIResolution" --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$WorkingDirectory"/"$T1wImageFile""$FinalfMRIResolution"
fi

applywarp --interp=nn -i "$FreeSurferBrainMask".nii.gz -r "$WorkingDirectory"/"$T1wImageFile""$FinalfMRIResolution" --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$WorkingDirectory"/"$FreeSurferBrainMaskFile"."$FinalfMRIResolution".nii.gz
fslmaths "$WorkingDirectory"/"$T1wImageFile""$FinalfMRIResolution" -mas "$WorkingDirectory"/"$FreeSurferBrainMaskFile"."$FinalfMRIResolution".nii.gz "$WorkingDirectory"/"$FreeSurferBrainMaskFile"."$FinalfMRIResolution".nii.gz

applywarp --interp=spline -i "$BiasField" -r "$WorkingDirectory"/"$FreeSurferBrainMaskFile"."$FinalfMRIResolution".nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$WorkingDirectory"/"$BiasFieldFile"."$FinalfMRIResolution"
fslmaths "$WorkingDirectory"/"$BiasFieldFile"."$FinalfMRIResolution" -thr 0.1 "$WorkingDirectory"/"$BiasFieldFile"."$FinalfMRIResolution"

#Downsample warpfield volume to increase speed (warpfield resolution is 10mm, so 1mm to fMRIres downsample loses no precision)
convertwarp --warp1="$fMRIToStructuralInput" --warp2="$StructuralToStandard" --ref="$WorkingDirectory"/"$T1wImageFile""$FinalfMRIResolution" --out="$OutputTransform"

if [ ! -e "$AtlasSpaceFolder"/ISCOPYING ] ; then
  touch "$AtlasSpaceFolder"/ISCOPYING
  cp "$WorkingDirectory"/"$T1wImageFile""$FinalfMRIResolution".nii.gz "$AtlasSpaceFolder"/"$T1wImageFile""$FinalfMRIResolution".nii.gz
  cp "$WorkingDirectory"/"$FreeSurferBrainMaskFile"."$FinalfMRIResolution".nii.gz "$AtlasSpaceFolder"/"$FreeSurferBrainMaskFile"."$FinalfMRIResolution".nii.gz
  cp "$WorkingDirectory"/"$BiasFieldFile"."$FinalfMRIResolution".nii.gz "$AtlasSpaceFolder"/"$BiasFieldFile"."$FinalfMRIResolution".nii.gz
  rm "$AtlasSpaceFolder"/ISCOPYING
fi

if [ ! -e "$WorkingDirectory"/prevols ] ; then
  mkdir "$WorkingDirectory"/prevols
fi
if [ ! -e "$WorkingDirectory"/postvols ] ; then
  mkdir "$WorkingDirectory"/postvols
fi
fslsplit "$InputfMRI" "$WorkingDirectory"/prevols/vol -t
FrameMergeSTRING=""
k=0
while [ $k -lt $NumFrames ] ; do
  convertwarp --ref="$WorkingDirectory"/prevols/vol`zeropad $k 4`.nii.gz --warp1="$GradientDistortionField" --postmat="$MotionMatrixFolder"/"$MotionMatrixPrefix"`zeropad $k 4` --out="$MotionMatrixFolder"/"$MotionMatrixPrefix"`zeropad $k 4`_gdc_warp.nii.gz
  convertwarp --ref="$WorkingDirectory"/"$T1wImageFile""$FinalfMRIResolution" --warp1="$MotionMatrixFolder"/"$MotionMatrixPrefix"`zeropad $k 4`_gdc_warp.nii.gz --warp2="$OutputTransform" --out="$MotionMatrixFolder"/"$MotionMatrixPrefix"`zeropad $k 4`_all_warp.nii.gz
  applywarp --interp=spline --in="$WorkingDirectory"/prevols/vol`zeropad $k 4`.nii.gz --warp="$MotionMatrixFolder"/"$MotionMatrixPrefix"`zeropad $k 4`_all_warp.nii.gz --ref="$WorkingDirectory"/"$T1wImageFile""$FinalfMRIResolution" --out="$WorkingDirectory"/postvols/vol"$k".nii.gz
  FrameMergeSTRING=`echo "$FrameMergeSTRING""$WorkingDirectory""/postvols/vol""$k"".nii.gz "` 
  k=`echo "$k + 1" | bc`
done
fslmerge -tr "$OutputfMRI" $FrameMergeSTRING $TR_vol

echo "END: OneStepResampling"

