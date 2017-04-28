#!/bin/bash
set -e

#quick script to regenerate inflated 59k surfaces to match original HCP 32k

#Example call: 
# . SetUpHCPPipeline.sh
# StudyFolder=/data/Phase2_7T
# Subject=102311
# T1wFolder="$StudyFolder"/"$Subject"/T1w
# AtlasSpaceFolder="$StudyFolder"/"$Subject"/MNINonLinear
# LowResMeshes=59
# Example_1res_inflate.sh  $StudyFolder $Subject $T1wFolder $AtlasSpaceFolder $LowResMeshes

StudyFolder="$1"
Subject="$2"
T1wFolder="$3"
AtlasSpaceFolder="$4"
LowResMeshes="$5"

LowResMeshes=`echo ${LowResMeshes} | sed 's/@/ /g'`

for Hemisphere in L R ; do
  for LowResMesh in ${LowResMeshes} ; do

    InflationScale=`echo "scale=4; 0.75 * $LowResMesh / 32" | bc -l`

    ${CARET7DIR}/wb_command -surface-generate-inflated "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere".inflated."$LowResMesh"k_fs_LR.surf.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere".very_inflated."$LowResMesh"k_fs_LR.surf.gii -iterations-scale "$InflationScale"

    ${CARET7DIR}/wb_command -surface-generate-inflated "$T1wFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii "$T1wFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere".inflated."$LowResMesh"k_fs_LR.surf.gii "$T1wFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere".very_inflated."$LowResMesh"k_fs_LR.surf.gii -iterations-scale "$InflationScale"
  done
done

