#!/bin/bash -e
echo -e "\n START: SurfaceSmoothing"

NameOffMRI="$1"
Subject="$2"
DownSampleFolder="$3"
DownSampleNameI="$4"
SmoothingFWHM="$5"
Caret7_Command="$6"

Sigma=`echo "$SmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`


for Hemisphere in L R ; do
  $Caret7_Command -metric-smoothing "$DownSampleFolder"/"$Subject"."$Hemisphere".midthickness."$DownSampleNameI"k_fs_LR.surf.gii "$NameOffMRI"."$Hemisphere".roi."$DownSampleNameI"k_fs_LR.func.gii "$Sigma" "$NameOffMRI"_s"$SmoothingFWHM".roi."$Hemisphere"."$DownSampleNameI"k_fs_LR.func.gii -roi "$DownSampleFolder"/"$Subject"."$Hemisphere".roi."$DownSampleNameI"k_fs_LR.shape.gii
  $Caret7_Command -metric-smoothing "$DownSampleFolder"/"$Subject"."$Hemisphere".midthickness."$DownSampleNameI"k_fs_LR.surf.gii "$NameOffMRI"."$Hemisphere".atlasroi."$DownSampleNameI"k_fs_LR.func.gii "$Sigma" "$NameOffMRI"_s"$SmoothingFWHM".atlasroi."$Hemisphere"."$DownSampleNameI"k_fs_LR.func.gii -roi "$DownSampleFolder"/"$Subject"."$Hemisphere".atlasroi."$DownSampleNameI"k_fs_LR.shape.gii
done

echo " END: SurfaceSmoothing"

