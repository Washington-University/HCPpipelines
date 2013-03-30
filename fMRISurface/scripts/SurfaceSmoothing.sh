#!/bin/bash 
set -e
echo -e "\n START: SurfaceSmoothing"

NameOffMRI="$1"
Subject="$2"
DownSampleFolder="$3"
LowResMesh="$4"
SmoothingFWHM="$5"

Sigma=`echo "$SmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`


for Hemisphere in L R ; do
  ${CARET7DIR}/wb_command -metric-smoothing "$DownSampleFolder"/"$Subject"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii "$NameOffMRI"."$Hemisphere".atlasroi."$LowResMesh"k_fs_LR.func.gii "$Sigma" "$NameOffMRI"_s"$SmoothingFWHM".atlasroi."$Hemisphere"."$LowResMesh"k_fs_LR.func.gii -roi "$DownSampleFolder"/"$Subject"."$Hemisphere".atlasroi."$LowResMesh"k_fs_LR.shape.gii
done

echo " END: SurfaceSmoothing"

