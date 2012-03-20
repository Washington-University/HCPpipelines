#!/bin/bash
set -e
echo -e "\n START: CreateMyelinMaps"

StudyFolder="$1"
Subject="$2"
AtlasSpaceFolder="$3"
Native="$4"
T1wFolder="$5"
DownSampleNameI="$6"
Caret5_Command="$7"
Caret7_Command="$8"
OrginalT1wImage="$9"
OrginalT2wImage="${10}"
T1wImageBrain="${11}"
InitialT1wTransform="${12}"
dcT1wTransform="${13}"
InitialT2wTransform="${14}"
dcT2wTransform="${15}"
FinalT2wTransform="${16}"
AtlasTransform="${17}"
BiasField="${18}"
OutputT1wImage="${19}"
OutputT1wImageRestore="${20}"
OutputT1wImageRestoreBrain="${21}"
OutputMNIT1wImage="${22}"
OutputMNIT1wImageRestore="${23}"
OutputMNIT1wImageRestoreBrain="${24}"
OutputT2wImage="${25}"
OutputT2wImageRestore="${26}"
OutputT2wImageRestoreBrain="${27}"
OutputMNIT2wImage="${28}"
OutputMNIT2wImageRestore="${29}"
OutputMNIT2wImageRestoreBrain="${30}"
OutputOrigT1wToT1w="${31}"
OutputOrigT1wToStandard="${32}"
OutputOrigT2wToT1w="${33}"
OutputOrigT2wToStandard="${34}"
BiasFieldOutput="${35}"
T1wMNIImageBrain="${36}"

convertwarp --ref="$T1wImageBrain" --premat="$InitialT1wTransform" --warp1="$dcT1wTransform" --out="$OutputOrigT1wToT1w"
convertwarp --ref="$T1wImageBrain" --warp1="$OutputOrigT1wToT1w" --warp2="$AtlasTransform" --out="$OutputOrigT1wToStandard"
convertwarp --ref="$T1wImageBrain" --premat="$InitialT2wTransform" --warp1="$dcT2wTransform" --postmat="$FinalT2wTransform" --out="$OutputOrigT2wToT1w"
convertwarp --ref="$T1wImageBrain" --warp1="$OutputOrigT2wToT1w" --warp2="$AtlasTransform" --out="$OutputOrigT2wToStandard"

applywarp --interp=spline -i "$OrginalT1wImage" -r "$T1wImageBrain" -w "$OutputOrigT1wToT1w" -o "$OutputT1wImage"
fslmaths "$OutputT1wImage" -abs "$OutputT1wImage" -odt float
fslmaths "$OutputT1wImage" -div "$BiasField" "$OutputT1wImageRestore"
fslmaths "$OutputT1wImageRestore" -mas "$T1wImageBrain" "$OutputT1wImageRestoreBrain"

applywarp --interp=spline -i "$BiasField" -r "$T1wImageBrain" -w "$AtlasTransform" -o "$BiasFieldOutput"
fslmaths "$BiasFieldOutput" -thr 0.1 "$BiasFieldOutput"

applywarp --interp=spline -i "$OrginalT1wImage" -r "$T1wImageBrain" -w "$OutputOrigT1wToStandard" -o "$OutputMNIT1wImage"
fslmaths "$OutputMNIT1wImage" -abs "$OutputMNIT1wImage" -odt float
fslmaths "$OutputMNIT1wImage" -div "$BiasFieldOutput" "$OutputMNIT1wImageRestore"
fslmaths "$OutputMNIT1wImageRestore" -mas "$T1wMNIImageBrain" "$OutputMNIT1wImageRestoreBrain"

applywarp --interp=spline -i "$OrginalT2wImage" -r "$T1wImageBrain" -w "$OutputOrigT2wToT1w" -o "$OutputT2wImage"
fslmaths "$OutputT2wImage" -abs "$OutputT2wImage" -odt float
fslmaths "$OutputT2wImage" -div "$BiasField" "$OutputT2wImageRestore"
fslmaths "$OutputT2wImageRestore" -mas "$T1wImageBrain" "$OutputT2wImageRestoreBrain"

applywarp --interp=spline -i "$OrginalT2wImage" -r "$T1wImageBrain" -w "$OutputOrigT2wToStandard" -o "$OutputMNIT2wImage"
fslmaths "$OutputMNIT2wImage" -abs "$OutputMNIT2wImage" -odt float
fslmaths "$OutputMNIT2wImage" -div "$BiasFieldOutput" "$OutputMNIT2wImageRestore"
fslmaths "$OutputMNIT2wImageRestore" -mas "$T1wMNIImageBrain" "$OutputMNIT2wImageRestoreBrain"


#Fix cortex ROI for any defects, fill in those defects in thickness and curvature maps
for Hemisphere in L R ; do
  if [ $Hemisphere = "L" ] ; then
    hemisphere="l"
    Structure="CORTEX_LEFT"
  elif [ $Hemisphere = "R" ] ; then
    hemisphere="r"
    Structure="CORTEX_RIGHT"    
  fi
  $Caret5_Command -surface-region-of-interest-selection "$T1wFolder"/"$Native"/"$Subject"."$Hemisphere".midthickness.native.coord.gii "$T1wFolder"/"$Native"/"$Subject"."$Hemisphere".native.topo.gii "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".thickness.native.roi "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".thickness.native.roi -metric "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".thickness.native.shape.gii 1 0 0 NORMAL -remove-islands -invert-selection -remove-islands -invert-selection
  mv "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".thickness.native.roi "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".roi.native.shape.gii
  $Caret5_Command -metric-math "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".roi.native.shape.gii "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".roi.native.shape.gii 1 "@1@ - 1"
  $Caret5_Command -metric-roi-mask "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".roi.native.shape.gii 1 "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".roi.native.shape.gii "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".roi.native.shape.gii
  $Caret5_Command -metric-set-column-name "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".roi.native.shape.gii 1 "$Subject"_"$Hemisphere"_ROI
  $Caret7_Command -set-structure "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".roi.native.shape.gii $Structure
  $Caret5_Command -metric-smoothing "$T1wFolder"/"$Native"/"$Subject"."$Hemisphere".midthickness.native.coord.gii "$T1wFolder"/"$Native"/"$Subject"."$Hemisphere".native.topo.gii "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".thickness.native.shape.gii "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".thickness.native.shape.gii DILATE 50 1
  $Caret7_Command -metric-mask "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".thickness.native.shape.gii "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".roi.native.shape.gii "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".thickness.native.shape.gii
  $Caret5_Command -metric-set-column-name "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".thickness.native.shape.gii 1 "$Subject"_"$Hemisphere"_Thickness
  $Caret7_Command -metric-palette "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".thickness.native.shape.gii MODE_AUTO_SCALE_PERCENTAGE -pos-percent 4 96 -interpolate true -palette-name videen_style
  $Caret7_Command -set-structure "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".thickness.native.shape.gii $Structure
  $Caret5_Command -metric-smoothing "$T1wFolder"/"$Native"/"$Subject"."$Hemisphere".midthickness.native.coord.gii "$T1wFolder"/"$Native"/"$Subject"."$Hemisphere".native.topo.gii "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".curvature.native.shape.gii "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".curvature.native.shape.gii DILATE 50 1
  $Caret7_Command -metric-mask "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".curvature.native.shape.gii "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".roi.native.shape.gii "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".curvature.native.shape.gii
  $Caret5_Command -metric-set-column-name "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".curvature.native.shape.gii 1 "$Subject"_"$Hemisphere"_Curvature
  $Caret7_Command -metric-palette "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".curvature.native.shape.gii MODE_AUTO_SCALE_PERCENTAGE -pos-percent 2 98 -palette-name Gray_Interp
  $Caret7_Command -set-structure "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".curvature.native.shape.gii $Structure
done

#Run Myelin mapping algorithm
$Caret5_Command -myelin-mapping "$T1wFolder"/"$Native"/"$Subject".L.midthickness.native.coord.gii "$T1wFolder"/"$Native"/"$Subject".R.midthickness.native.coord.gii "$T1wFolder"/"$Native"/"$Subject".L.native.topo.gii "$T1wFolder"/"$Native"/"$Subject".R.native.topo.gii "$OutputT1wImage".nii.gz "$OutputT2wImage".nii.gz "$T1wFolder"/ribbon.nii.gz "$AtlasSpaceFolder"/"$Native"/"$Subject".L.thickness.native.shape.gii "$AtlasSpaceFolder"/"$Native"/"$Subject".R.thickness.native.shape.gii "$AtlasSpaceFolder"/"$Native"/"$Subject".L.curvature.native.shape.gii "$AtlasSpaceFolder"/"$Native"/"$Subject".R.curvature.native.shape.gii "$AtlasSpaceFolder"/"$Native"/"$Subject".L.MyelinMappingOut.native.func.gii "$AtlasSpaceFolder"/"$Native"/"$Subject".R.MyelinMappingOut.native.func.gii "$T1wFolder"/T1wDividedByT2w.nii.gz "$T1wFolder"/T1wDividedByT2w_ribbon.nii.gz -neighbor-depth 10 -number-of-standard-deviations 4 -smoothing-FWHM 5 -volume-outliers 4

#Break out myelin mapping results into individual files, add them to caret7 spec files, deform them to 164k_fs_LR and 32k_fs_LR
for Hemisphere in L R ; do
  if [ $Hemisphere = "L" ] ; then 
    Structure="CORTEX_LEFT"
  elif [ $Hemisphere = "R" ] ; then 
    Structure="CORTEX_RIGHT"
  fi
  $Caret7_Command -set-structure "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".MyelinMappingOut.native.func.gii $Structure
  $Caret5_Command -metric-composite-identified-columns "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".MyelinMap.native.func.gii "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".MyelinMappingOut.native.func.gii 2
  $Caret5_Command -metric-set-column-name "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".MyelinMap.native.func.gii 1 "$Subject"_"$Hemisphere"_Myelin_Map
  $Caret7_Command -set-structure "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".MyelinMap.native.func.gii $Structure
  $Caret7_Command -metric-palette "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".MyelinMap.native.func.gii MODE_AUTO_SCALE_PERCENTAGE -pos-percent 4 96 -interpolate true -palette-name videen_style
  $Caret7_Command -add-to-spec-file "$AtlasSpaceFolder"/"$Native"/"$Subject".native.7.spec $Structure "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".MyelinMap.native.func.gii
  $Caret5_Command -metric-composite-identified-columns "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".SmoothedMyelinMap.native.func.gii "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".MyelinMappingOut.native.func.gii 3
  $Caret5_Command -metric-set-column-name "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".SmoothedMyelinMap.native.func.gii 1 "$Subject"_"$Hemisphere"_Smoothed_Myelin_Map
  $Caret7_Command -set-structure "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".SmoothedMyelinMap.native.func.gii $Structure
  $Caret7_Command -metric-palette "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".SmoothedMyelinMap.native.func.gii MODE_AUTO_SCALE_PERCENTAGE -pos-percent 4 96 -interpolate true -palette-name videen_style
  $Caret7_Command -add-to-spec-file "$AtlasSpaceFolder"/"$Native"/"$Subject".native.7.spec $Structure "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".SmoothedMyelinMap.native.func.gii
  $Caret5_Command -metric-composite-identified-columns "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".corrThickness.native.shape.gii "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".MyelinMappingOut.native.func.gii 4
  $Caret5_Command -metric-set-column-name "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".corrThickness.native.shape.gii 1 "$Subject"_"$Hemisphere"_corrThickness
  $Caret7_Command -set-structure "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".corrThickness.native.shape.gii $Structure
  $Caret7_Command -metric-palette "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".corrThickness.native.shape.gii MODE_AUTO_SCALE_PERCENTAGE -pos-percent 4 96 -interpolate true -palette-name videen_style
  $Caret7_Command -add-to-spec-file "$AtlasSpaceFolder"/"$Native"/"$Subject".native.7.spec $Structure "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".corrThickness.native.shape.gii
  $Caret5_Command -deformation-map-apply "$AtlasSpaceFolder"/native2164k_fs_LR."$Hemisphere".deform_map METRIC_NEAREST_NODE "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".roi.native.shape.gii "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".roi.164k_fs_LR.shape.gii
  $Caret7_Command -set-structure "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".roi.164k_fs_LR.shape.gii $Structure
  for Map in thickness corrThickness curvature ; do
    $Caret5_Command -deformation-map-apply "$AtlasSpaceFolder"/native2164k_fs_LR."$Hemisphere".deform_map METRIC_AVERAGE_TILE "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere"."$Map".native.shape.gii "$AtlasSpaceFolder"/"$Subject"."$Hemisphere"."$Map".164k_fs_LR.shape.gii
    $Caret7_Command -metric-mask "$AtlasSpaceFolder"/"$Subject"."$Hemisphere"."$Map".164k_fs_LR.shape.gii "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".roi.164k_fs_LR.shape.gii "$AtlasSpaceFolder"/"$Subject"."$Hemisphere"."$Map".164k_fs_LR.shape.gii
    $Caret7_Command -set-structure "$AtlasSpaceFolder"/"$Subject"."$Hemisphere"."$Map".164k_fs_LR.shape.gii $Structure
    $Caret7_Command -add-to-spec-file "$AtlasSpaceFolder"/"$Subject".164k_fs_LR.7.spec $Structure "$AtlasSpaceFolder"/"$Subject"."$Hemisphere"."$Map".164k_fs_LR.shape.gii
  done
  for Map in MyelinMap SmoothedMyelinMap ; do
    $Caret5_Command -deformation-map-apply "$AtlasSpaceFolder"/native2164k_fs_LR."$Hemisphere".deform_map METRIC_AVERAGE_TILE "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere"."$Map".native.func.gii "$AtlasSpaceFolder"/"$Subject"."$Hemisphere"."$Map".164k_fs_LR.func.gii
    $Caret7_Command -metric-mask "$AtlasSpaceFolder"/"$Subject"."$Hemisphere"."$Map".164k_fs_LR.func.gii "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".roi.164k_fs_LR.shape.gii "$AtlasSpaceFolder"/"$Subject"."$Hemisphere"."$Map".164k_fs_LR.func.gii
    $Caret7_Command -set-structure "$AtlasSpaceFolder"/"$Subject"."$Hemisphere"."$Map".164k_fs_LR.func.gii $Structure
    $Caret7_Command -add-to-spec-file "$AtlasSpaceFolder"/"$Subject".164k_fs_LR.7.spec $Structure "$AtlasSpaceFolder"/"$Subject"."$Hemisphere"."$Map".164k_fs_LR.func.gii
  done
  $Caret5_Command -deformation-map-apply "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/native2"$DownSampleNameI"k_fs_LR."$Hemisphere".deform_map METRIC_NEAREST_NODE "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere".roi.native.shape.gii "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere".roi."$DownSampleNameI"k_fs_LR.shape.gii
  $Caret7_Command -set-structure "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere".roi."$DownSampleNameI"k_fs_LR.shape.gii $Structure
  for Map in thickness corrThickness curvature ; do
    $Caret5_Command -deformation-map-apply "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/native2"$DownSampleNameI"k_fs_LR."$Hemisphere".deform_map METRIC_AVERAGE_TILE "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere"."$Map".native.shape.gii "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$Map"."$DownSampleNameI"k_fs_LR.shape.gii
    $Caret7_Command -metric-mask "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$Map"."$DownSampleNameI"k_fs_LR.shape.gii "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere".roi."$DownSampleNameI"k_fs_LR.shape.gii "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$Map"."$DownSampleNameI"k_fs_LR.shape.gii
    $Caret7_Command -set-structure "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$Map"."$DownSampleNameI"k_fs_LR.shape.gii $Structure
    $Caret7_Command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$DownSampleNameI"k_fs_LR.7.spec $Structure "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$Map"."$DownSampleNameI"k_fs_LR.shape.gii
  done
  for Map in MyelinMap SmoothedMyelinMap ; do
    $Caret5_Command -deformation-map-apply "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/native2"$DownSampleNameI"k_fs_LR."$Hemisphere".deform_map METRIC_AVERAGE_TILE "$AtlasSpaceFolder"/"$Native"/"$Subject"."$Hemisphere"."$Map".native.func.gii "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$Map"."$DownSampleNameI"k_fs_LR.func.gii
    $Caret7_Command -metric-mask "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$Map"."$DownSampleNameI"k_fs_LR.func.gii "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere".roi."$DownSampleNameI"k_fs_LR.shape.gii "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$Map"."$DownSampleNameI"k_fs_LR.func.gii
    $Caret7_Command -set-structure "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$Map"."$DownSampleNameI"k_fs_LR.func.gii $Structure
    $Caret7_Command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$DownSampleNameI"k_fs_LR.7.spec $Structure "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$Map"."$DownSampleNameI"k_fs_LR.func.gii
  done
done

echo -e "\n END: CreateMyelinMaps"