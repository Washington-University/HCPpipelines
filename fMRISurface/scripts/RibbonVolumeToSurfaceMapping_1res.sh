#!/bin/bash 
set -e
echo -e "\n START: RibbonVolumeToSurfaceMapping_1res"

WorkingDirectory="$1"
VolumefMRI="$2"
Subject="$3"
DownsampleFolder="$4"
LowResMesh="$5"
AtlasSpaceNativeFolder="$6"
RegName="$7"

if [ ${RegName} = "FS" ]; then
    RegName="reg.reg_LR"
fi

for Hemisphere in L R ; do
  for Map in mean cov ; do
    ${CARET7DIR}/wb_command -metric-resample "$WorkingDirectory"/"$Hemisphere"."$Map".native.func.gii "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".sphere.${RegName}.native.surf.gii "$DownsampleFolder"/"$Subject"."$Hemisphere".sphere."$LowResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$WorkingDirectory"/"$Hemisphere"."$Map"."$LowResMesh"k_fs_LR.func.gii -area-surfs "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii "$DownsampleFolder"/"$Subject"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii -current-roi "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".roi.native.shape.gii
    ${CARET7DIR}/wb_command -metric-mask "$WorkingDirectory"/"$Hemisphere"."$Map"."$LowResMesh"k_fs_LR.func.gii "$DownsampleFolder"/"$Subject"."$Hemisphere".atlasroi."$LowResMesh"k_fs_LR.shape.gii "$WorkingDirectory"/"$Hemisphere"."$Map"."$LowResMesh"k_fs_LR.func.gii
    ${CARET7DIR}/wb_command -metric-resample "$WorkingDirectory"/"$Hemisphere"."$Map"_all.native.func.gii "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".sphere.${RegName}.native.surf.gii "$DownsampleFolder"/"$Subject"."$Hemisphere".sphere."$LowResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$WorkingDirectory"/"$Hemisphere"."$Map"_all."$LowResMesh"k_fs_LR.func.gii -area-surfs "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii "$DownsampleFolder"/"$Subject"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii -current-roi "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".roi.native.shape.gii
    ${CARET7DIR}/wb_command -metric-mask "$WorkingDirectory"/"$Hemisphere"."$Map"_all."$LowResMesh"k_fs_LR.func.gii "$DownsampleFolder"/"$Subject"."$Hemisphere".atlasroi."$LowResMesh"k_fs_LR.shape.gii "$WorkingDirectory"/"$Hemisphere"."$Map"_all."$LowResMesh"k_fs_LR.func.gii
  done
  ${CARET7DIR}/wb_command -metric-resample "$WorkingDirectory"/"$Hemisphere".goodvoxels.native.func.gii "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".sphere.${RegName}.native.surf.gii "$DownsampleFolder"/"$Subject"."$Hemisphere".sphere."$LowResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$WorkingDirectory"/"$Hemisphere".goodvoxels."$LowResMesh"k_fs_LR.func.gii -area-surfs "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii "$DownsampleFolder"/"$Subject"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii -current-roi "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".roi.native.shape.gii
  ${CARET7DIR}/wb_command -metric-mask "$WorkingDirectory"/"$Hemisphere".goodvoxels."$LowResMesh"k_fs_LR.func.gii "$DownsampleFolder"/"$Subject"."$Hemisphere".atlasroi."$LowResMesh"k_fs_LR.shape.gii "$WorkingDirectory"/"$Hemisphere".goodvoxels."$LowResMesh"k_fs_LR.func.gii

  ${CARET7DIR}/wb_command -metric-resample "$VolumefMRI"."$Hemisphere".native.func.gii "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".sphere.${RegName}.native.surf.gii "$DownsampleFolder"/"$Subject"."$Hemisphere".sphere."$LowResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$VolumefMRI"."$Hemisphere".atlasroi."$LowResMesh"k_fs_LR.func.gii -area-surfs "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii "$DownsampleFolder"/"$Subject"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii -current-roi "$AtlasSpaceNativeFolder"/"$Subject"."$Hemisphere".roi.native.shape.gii
  ${CARET7DIR}/wb_command -metric-mask "$VolumefMRI"."$Hemisphere".atlasroi."$LowResMesh"k_fs_LR.func.gii "$DownsampleFolder"/"$Subject"."$Hemisphere".atlasroi."$LowResMesh"k_fs_LR.shape.gii "$VolumefMRI"."$Hemisphere".atlasroi."$LowResMesh"k_fs_LR.func.gii
done

echo " END: RibbonVolumeToSurfaceMapping_1res"

