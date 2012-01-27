#!/bin/bash

WorkingDirectory="$1"
VolumefMRI="$2"
Subject="$3"
NativeFolder="$4"
DownsampleFolder="$5"
StructuralVolumeSpace="$6"
DownSampleNameI="$7"
Caret7_Command="$8"
AtlasSurfaceROI="$9"

LeftGreyRibbonValue="1"
RightGreyRibbonValue="1"
NeighborhoodSmoothing="5"
Factor="0.5"

for Hemisphere in L R ; do
  if [ $Hemisphere = "L" ] ; then
    GreyRibbonValue="$LeftGreyRibbonValue"
  elif [ $Hemisphere = "R" ] ; then
    GreyRibbonValue="$RightGreyRibbonValue"
  fi    
  $Caret7_Command -create-signed-distance-volume "$NativeFolder"/"$Subject"."$Hemisphere".white.native.surf.gii "$StructuralVolumeSpace".nii.gz "$NativeFolder"/"$Subject"."$Hemisphere".white.native.nii.gz
  $Caret7_Command -create-signed-distance-volume "$NativeFolder"/"$Subject"."$Hemisphere".pial.native.surf.gii "$StructuralVolumeSpace".nii.gz "$NativeFolder"/"$Subject"."$Hemisphere".pial.native.nii.gz
  fslmaths "$NativeFolder"/"$Subject"."$Hemisphere".white.native.nii.gz -thr 0 -bin -mul 255 "$NativeFolder"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz
  caret_command -volume-remove-islands "$NativeFolder"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz "$NativeFolder"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz
  fslreorient2std "$NativeFolder"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz "$NativeFolder"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz
  fslmaths "$NativeFolder"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz -bin "$NativeFolder"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz
  fslmaths "$NativeFolder"/"$Subject"."$Hemisphere".pial.native.nii.gz -uthr 0 -abs -bin -mul 255 "$NativeFolder"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz
  caret_command -volume-fill-holes "$NativeFolder"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz "$NativeFolder"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz
  fslreorient2std "$NativeFolder"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz "$NativeFolder"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz
  fslmaths "$NativeFolder"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz -bin "$NativeFolder"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz
  fslmaths "$NativeFolder"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz -mas "$NativeFolder"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz -mul 255 "$NativeFolder"/"$Subject"."$Hemisphere".ribbon.nii.gz
  caret_command -volume-remove-islands "$NativeFolder"/"$Subject"."$Hemisphere".ribbon.nii.gz "$NativeFolder"/"$Subject"."$Hemisphere".ribbon.nii.gz
  fslreorient2std "$NativeFolder"/"$Subject"."$Hemisphere".ribbon.nii.gz "$NativeFolder"/"$Subject"."$Hemisphere".ribbon.nii.gz
  fslmaths "$NativeFolder"/"$Subject"."$Hemisphere".ribbon.nii.gz -bin -mul $GreyRibbonValue "$NativeFolder"/"$Subject"."$Hemisphere".ribbon.nii.gz
  rm "$NativeFolder"/"$Subject"."$Hemisphere".white.native.nii.gz "$NativeFolder"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz "$NativeFolder"/"$Subject"."$Hemisphere".pial.native.nii.gz "$NativeFolder"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz
done

fslmaths "$NativeFolder"/"$Subject".L.ribbon.nii.gz -add "$NativeFolder"/"$Subject".R.ribbon.nii.gz "$NativeFolder"/ribbon_only.nii.gz
rm "$NativeFolder"/"$Subject".L.ribbon.nii.gz "$NativeFolder"/"$Subject".R.ribbon.nii.gz

fslmaths "$VolumefMRI" -Tmean "$WorkingDirectory"/mean -odt float
fslmaths "$VolumefMRI" -Tstd "$WorkingDirectory"/std -odt float
fslmaths "$WorkingDirectory"/std -div "$WorkingDirectory"/mean "$WorkingDirectory"/cov

fslmaths "$WorkingDirectory"/cov -mas "$NativeFolder"/ribbon_only.nii.gz "$WorkingDirectory"/cov_ribbon

fslmaths "$WorkingDirectory"/cov_ribbon -div `fslstats "$WorkingDirectory"/cov_ribbon -M` "$WorkingDirectory"/cov_ribbon_norm
fslmaths "$WorkingDirectory"/cov_ribbon_norm -bin -s $NeighborhoodSmoothing "$WorkingDirectory"/SmoothNorm
fslmaths "$WorkingDirectory"/cov_ribbon_norm -s $NeighborhoodSmoothing -div "$WorkingDirectory"/SmoothNorm -dilD "$WorkingDirectory"/cov_ribbon_norm_s$NeighborhoodSmoothing
fslmaths "$WorkingDirectory"/cov -div `fslstats "$WorkingDirectory"/cov_ribbon -M` -div "$WorkingDirectory"/cov_ribbon_norm_s$NeighborhoodSmoothing "$WorkingDirectory"/cov_norm_modulate
fslmaths "$WorkingDirectory"/cov_norm_modulate -mas "$NativeFolder"/ribbon_only.nii.gz "$WorkingDirectory"/cov_norm_modulate_ribbon

STD=`fslstats "$WorkingDirectory"/cov_norm_modulate_ribbon -S`
echo $STD
MEAN=`fslstats "$WorkingDirectory"/cov_norm_modulate_ribbon -M`
echo $MEAN
Lower=`echo "$MEAN - ($STD * $Factor)" | bc -l`
echo $Lower
Upper=`echo "$MEAN + ($STD * $Factor)" | bc -l`
echo $Upper

fslmaths "$WorkingDirectory"/mean -bin "$WorkingDirectory"/mask
fslmaths "$WorkingDirectory"/cov_norm_modulate -thr $Upper -bin -sub "$WorkingDirectory"/mask -mul -1 "$WorkingDirectory"/goodvoxels

for Hemisphere in L R ; do
  $Caret7_Command -volume-to-surface-mapping "$WorkingDirectory"/mean.nii.gz "$NativeFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii "$WorkingDirectory"/"$Hemisphere".mean.func.gii -ribbon-constrained "$NativeFolder"/"$Subject"."$Hemisphere".white.native.surf.gii "$NativeFolder"/"$Subject"."$Hemisphere".pial.native.surf.gii -volume-roi "$WorkingDirectory"/goodvoxels.nii.gz
  $Caret7_Command -metric-dilate "$WorkingDirectory"/"$Hemisphere".mean.func.gii "$NativeFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii 10 "$WorkingDirectory"/"$Hemisphere".mean.func.gii
  $Caret7_Command -volume-to-surface-mapping "$WorkingDirectory"/mean.nii.gz "$NativeFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii "$WorkingDirectory"/"$Hemisphere".mean_all.func.gii -ribbon-constrained "$NativeFolder"/"$Subject"."$Hemisphere".white.native.surf.gii "$NativeFolder"/"$Subject"."$Hemisphere".pial.native.surf.gii
  $Caret7_Command -volume-to-surface-mapping "$WorkingDirectory"/cov.nii.gz "$NativeFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii "$WorkingDirectory"/"$Hemisphere".cov.func.gii -ribbon-constrained "$NativeFolder"/"$Subject"."$Hemisphere".white.native.surf.gii "$NativeFolder"/"$Subject"."$Hemisphere".pial.native.surf.gii -volume-roi "$WorkingDirectory"/goodvoxels.nii.gz
  $Caret7_Command -metric-dilate "$WorkingDirectory"/"$Hemisphere".cov.func.gii "$NativeFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii 10 "$WorkingDirectory"/"$Hemisphere".cov.func.gii
  $Caret7_Command -volume-to-surface-mapping "$WorkingDirectory"/cov.nii.gz "$NativeFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii "$WorkingDirectory"/"$Hemisphere".cov_all.func.gii -ribbon-constrained "$NativeFolder"/"$Subject"."$Hemisphere".white.native.surf.gii "$NativeFolder"/"$Subject"."$Hemisphere".pial.native.surf.gii
  $Caret7_Command -volume-to-surface-mapping "$WorkingDirectory"/goodvoxels.nii.gz "$NativeFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii "$WorkingDirectory"/"$Hemisphere".goodvoxels.func.gii -ribbon-constrained "$NativeFolder"/"$Subject"."$Hemisphere".white.native.surf.gii "$NativeFolder"/"$Subject"."$Hemisphere".pial.native.surf.gii
done

for Hemisphere in L R ; do
  if [ $Hemisphere = "L" ] ; then
    Structure="CORTEX_LEFT"
    SurfaceROI=`echo "$AtlasSurfaceROI" | cut -d "@" -f 1`
  elif [ $Hemisphere = "R" ] ; then
    Structure="CORTEX_RIGHT"
    SurfaceROI=`echo "$AtlasSurfaceROI" | cut -d "@" -f 2`
  fi    
  $Caret7_Command -volume-to-surface-mapping "$VolumefMRI".nii.gz "$NativeFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii "$VolumefMRI"."$Hemisphere".native.func.gii -ribbon-constrained "$NativeFolder"/"$Subject"."$Hemisphere".white.native.surf.gii "$NativeFolder"/"$Subject"."$Hemisphere".pial.native.surf.gii -volume-roi "$WorkingDirectory"/goodvoxels.nii.gz
  #caret_command -metric-smoothing "$NativeFolder"/"$Subject"."$Hemisphere".midthickness.native.coord.gii "$NativeFolder"/"$Subject"."$Hemisphere".native.topo.gii "$VolumefMRI"."$Hemisphere".native.func.gii "$VolumefMRI"."$Hemisphere".native.func.gii DILATE 3 1 -parallel
  $Caret7_Command -metric-dilate "$VolumefMRI"."$Hemisphere".native.func.gii "$NativeFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii 10 "$VolumefMRI"."$Hemisphere".native.func.gii
  caret_command -deformation-map-apply "$DownsampleFolder"/native2"$DownSampleNameI"k_fs_LR."$Hemisphere".deform_map METRIC_AVERAGE_TILE "$VolumefMRI"."$Hemisphere".native.func.gii "$VolumefMRI"."$Hemisphere"."$DownSampleNameI"k_fs_LR.func.gii
  caret_command -deformation-map-apply "$DownsampleFolder"/164k_fs_LR2"$DownSampleNameI"k_fs_LR."$Hemisphere".deform_map METRIC_NEAREST_NODE "$SurfaceROI" "$DownsampleFolder"/"$Subject"."$Hemisphere".atlasroi."$DownSampleNameI"k_fs_LR.shape.gii
  $Caret7_Command -set-structure "$DownsampleFolder"/"$Subject"."$Hemisphere".atlasroi."$DownSampleNameI"k_fs_LR.shape.gii "$Structure"
  $Caret7_Command -metric-mask "$VolumefMRI"."$Hemisphere"."$DownSampleNameI"k_fs_LR.func.gii "$DownsampleFolder"/"$Subject"."$Hemisphere".roi."$DownSampleNameI"k_fs_LR.shape.gii "$VolumefMRI"."$Hemisphere".roi."$DownSampleNameI"k_fs_LR.func.gii
  $Caret7_Command -set-structure "$VolumefMRI"."$Hemisphere".roi."$DownSampleNameI"k_fs_LR.func.gii "$Structure"
  $Caret7_Command -metric-mask "$VolumefMRI"."$Hemisphere"."$DownSampleNameI"k_fs_LR.func.gii "$DownsampleFolder"/"$Subject"."$Hemisphere".atlasroi."$DownSampleNameI"k_fs_LR.shape.gii "$VolumefMRI"."$Hemisphere".atlasroi."$DownSampleNameI"k_fs_LR.func.gii
  $Caret7_Command -set-structure "$VolumefMRI"."$Hemisphere".atlasroi."$DownSampleNameI"k_fs_LR.func.gii "$Structure"
  rm "$VolumefMRI"."$Hemisphere".native.func.gii "$VolumefMRI"."$Hemisphere"."$DownSampleNameI"k_fs_LR.func.gii
done

