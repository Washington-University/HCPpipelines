#!/bin/bash
set -e
echo -e "\n START: CreateMyelinMaps"

StudyFolder="$1"
Subject="$2"
AtlasSpaceFolder="$3"
NativeFolder="$4"
T1wFolder="$5"
HighResMesh="$6"
LowResMeshes="$7"
OrginalT1wImage="$8"
OrginalT2wImage="$9"
T1wImageBrain="${10}"
InitialT1wTransform="${11}"
dcT1wTransform="${12}"
InitialT2wTransform="${13}"
dcT2wTransform="${14}"
FinalT2wTransform="${15}"
AtlasTransform="${16}"
BiasField="${17}"
OutputT1wImage="${18}"
OutputT1wImageRestore="${19}"
OutputT1wImageRestoreBrain="${20}"
OutputMNIT1wImage="${21}"
OutputMNIT1wImageRestore="${22}"
OutputMNIT1wImageRestoreBrain="${23}"
OutputT2wImage="${24}"
OutputT2wImageRestore="${25}"
OutputT2wImageRestoreBrain="${26}"
OutputMNIT2wImage="${27}"
OutputMNIT2wImageRestore="${28}"
OutputMNIT2wImageRestoreBrain="${29}"
OutputOrigT1wToT1w="${30}"
OutputOrigT1wToStandard="${31}"
OutputOrigT2wToT1w="${32}"
OutputOrigT2wToStandard="${33}"
BiasFieldOutput="${34}"
T1wMNIImageBrain="${35}"
Jacobian="${36}"
ReferenceMyelinMaps="${37}"
CorrectionSigma="${38}"
RegName="${39}"

echo "CreateMyelinMaps.sh: RegName: ${RegName}"

LeftGreyRibbonValue="3"
RightGreyRibbonValue="42"
MyelinMappingFWHM="5"
SurfaceSmoothingFWHM="4"
MyelinMappingSigma=`echo "$MyelinMappingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`
SurfaceSmoothingSigma=`echo "$SurfaceSmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`

LowResMeshes=`echo ${LowResMeshes} | sed 's/@/ /g'`

${CARET7DIR}/wb_command -volume-palette $Jacobian MODE_AUTO_SCALE -interpolate true -disp-pos true -disp-neg false -disp-zero false -palette-name HSB8_clrmid -thresholding THRESHOLD_TYPE_NORMAL THRESHOLD_TEST_SHOW_OUTSIDE 0.5 2

convertwarp --relout --rel --ref="$T1wImageBrain" --premat="$InitialT1wTransform" --warp1="$dcT1wTransform" --out="$OutputOrigT1wToT1w"
convertwarp --relout --rel --ref="$T1wImageBrain" --warp1="$OutputOrigT1wToT1w" --warp2="$AtlasTransform" --out="$OutputOrigT1wToStandard"

convertwarp --relout --rel --ref="$T1wImageBrain" --premat="$InitialT2wTransform" --warp1="$dcT2wTransform" --postmat="$FinalT2wTransform" --out="$OutputOrigT2wToT1w"
convertwarp --relout --rel --ref="$T1wImageBrain" --warp1="$OutputOrigT2wToT1w" --warp2="$AtlasTransform" --out="$OutputOrigT2wToStandard"

applywarp --rel --interp=spline -i "$OrginalT1wImage" -r "$T1wImageBrain" -w "$OutputOrigT1wToT1w" -o "$OutputT1wImage"
fslmaths "$OutputT1wImage" -abs "$OutputT1wImage" -odt float
fslmaths "$OutputT1wImage" -div "$BiasField" "$OutputT1wImageRestore"
fslmaths "$OutputT1wImageRestore" -mas "$T1wImageBrain" "$OutputT1wImageRestoreBrain"

applywarp --rel --interp=spline -i "$BiasField" -r "$T1wImageBrain" -w "$AtlasTransform" -o "$BiasFieldOutput"
fslmaths "$BiasFieldOutput" -thr 0.1 "$BiasFieldOutput"

applywarp --rel --interp=spline -i "$OrginalT1wImage" -r "$T1wImageBrain" -w "$OutputOrigT1wToStandard" -o "$OutputMNIT1wImage"
fslmaths "$OutputMNIT1wImage" -abs "$OutputMNIT1wImage" -odt float
fslmaths "$OutputMNIT1wImage" -div "$BiasFieldOutput" "$OutputMNIT1wImageRestore"
fslmaths "$OutputMNIT1wImageRestore" -mas "$T1wMNIImageBrain" "$OutputMNIT1wImageRestoreBrain"

applywarp --rel --interp=spline -i "$OrginalT2wImage" -r "$T1wImageBrain" -w "$OutputOrigT2wToT1w" -o "$OutputT2wImage"
fslmaths "$OutputT2wImage" -abs "$OutputT2wImage" -odt float
fslmaths "$OutputT2wImage" -div "$BiasField" "$OutputT2wImageRestore"
fslmaths "$OutputT2wImageRestore" -mas "$T1wImageBrain" "$OutputT2wImageRestoreBrain"

applywarp --rel --interp=spline -i "$OrginalT2wImage" -r "$T1wImageBrain" -w "$OutputOrigT2wToStandard" -o "$OutputMNIT2wImage"
fslmaths "$OutputMNIT2wImage" -abs "$OutputMNIT2wImage" -odt float
fslmaths "$OutputMNIT2wImage" -div "$BiasFieldOutput" "$OutputMNIT2wImageRestore"
fslmaths "$OutputMNIT2wImageRestore" -mas "$T1wMNIImageBrain" "$OutputMNIT2wImageRestoreBrain"

${CARET7DIR}/wb_command -volume-math "clamp((T1w / T2w), 0, 100)" "$T1wFolder"/T1wDividedByT2w.nii.gz -var T1w "$OutputT1wImage".nii.gz -var T2w "$OutputT2wImage".nii.gz -fixnan 0
${CARET7DIR}/wb_command -volume-palette "$T1wFolder"/T1wDividedByT2w.nii.gz MODE_AUTO_SCALE_PERCENTAGE -pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false
${CARET7DIR}/wb_command -add-to-spec-file "$T1wFolder"/"$NativeFolder"/"$Subject".native.wb.spec INVALID "$T1wFolder"/T1wDividedByT2w.nii.gz
${CARET7DIR}/wb_command -volume-math "(T1w / T2w) * (((ribbon > ($LeftGreyRibbonValue - 0.01)) * (ribbon < ($LeftGreyRibbonValue + 0.01))) + ((ribbon > ($RightGreyRibbonValue - 0.01)) * (ribbon < ($RightGreyRibbonValue + 0.01))))" "$T1wFolder"/T1wDividedByT2w_ribbon.nii.gz -var T1w "$OutputT1wImage".nii.gz -var T2w "$OutputT2wImage".nii.gz -var ribbon "$T1wFolder"/ribbon.nii.gz
${CARET7DIR}/wb_command -volume-palette "$T1wFolder"/T1wDividedByT2w_ribbon.nii.gz MODE_AUTO_SCALE_PERCENTAGE -pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false
${CARET7DIR}/wb_command -add-to-spec-file "$T1wFolder"/"$NativeFolder"/"$Subject".native.wb.spec INVALID "$T1wFolder"/T1wDividedByT2w_ribbon.nii.gz

${CARET7DIR}/wb_command -cifti-separate-all "$ReferenceMyelinMaps" -left "$AtlasSpaceFolder"/"$Subject".L.RefMyelinMap."$HighResMesh"k_fs_LR.func.gii -right "$AtlasSpaceFolder"/"$Subject".R.RefMyelinMap."$HighResMesh"k_fs_LR.func.gii

for Hemisphere in L R ; do
  if [ $Hemisphere = "L" ] ; then 
    Structure="CORTEX_LEFT"
    ribbon="$LeftGreyRibbonValue"
  elif [ $Hemisphere = "R" ] ; then 
    Structure="CORTEX_RIGHT"
    ribbon="$RightGreyRibbonValue"
  fi
  if [ ${RegName} = "MSMSulc" ] ; then
    RegSphere="${AtlasSpaceFolder}/${NativeFolder}/${Subject}.${Hemisphere}.sphere.MSMSulc.native.surf.gii"
  else
    RegSphere="${AtlasSpaceFolder}/${NativeFolder}/${Subject}.${Hemisphere}.sphere.reg.reg_LR.native.surf.gii"
  fi

  ${CARET7DIR}/wb_command -volume-math "(ribbon > ($ribbon - 0.01)) * (ribbon < ($ribbon + 0.01))" "$T1wFolder"/temp_ribbon.nii.gz -var ribbon "$T1wFolder"/ribbon.nii.gz
  ${CARET7DIR}/wb_command -volume-to-surface-mapping "$T1wFolder"/T1wDividedByT2w.nii.gz "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".MyelinMap.native.func.gii -myelin-style "$T1wFolder"/temp_ribbon.nii.gz "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".thickness.native.shape.gii "$MyelinMappingSigma"
  rm "$T1wFolder"/temp_ribbon.nii.gz
  ${CARET7DIR}/wb_command -metric-regression "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".thickness.native.shape.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".corrThickness.native.shape.gii -roi "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".roi.native.shape.gii -remove "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".curvature.native.shape.gii
  ${CARET7DIR}/wb_command -metric-smoothing "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".MyelinMap.native.func.gii "$SurfaceSmoothingSigma" "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".SmoothedMyelinMap.native.func.gii -roi "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".roi.native.shape.gii 

  ${CARET7DIR}/wb_command -metric-resample "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".RefMyelinMap."$HighResMesh"k_fs_LR.func.gii "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".sphere."$HighResMesh"k_fs_LR.surf.gii ${RegSphere} ADAP_BARY_AREA "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".RefMyelinMap.native.func.gii -area-surfs "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".midthickness."$HighResMesh"k_fs_LR.surf.gii "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii -current-roi "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".atlasroi."$HighResMesh"k_fs_LR.shape.gii
  ${CARET7DIR}/wb_command -metric-dilate "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".RefMyelinMap.native.func.gii "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii 30 "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".RefMyelinMap.native.func.gii -nearest
  ${CARET7DIR}/wb_command -metric-mask "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".RefMyelinMap.native.func.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".roi.native.shape.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".RefMyelinMap.native.func.gii

  #Reduce memory usage by smoothing on downsampled mesh
  LowResMesh=`echo ${LowResMeshes} | cut -d " " -f 1`
  for Map in MyelinMap RefMyelinMap ; do
    ${CARET7DIR}/wb_command -metric-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Map".native.func.gii ${RegSphere} "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere".sphere."$LowResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere"."$Map"."$LowResMesh"k_fs_LR.func.gii -area-surfs "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii -current-roi "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".roi.native.shape.gii
    ${CARET7DIR}/wb_command -metric-smoothing "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere"."$Map"."$LowResMesh"k_fs_LR.func.gii "$CorrectionSigma" "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere"."$Map"_s"$CorrectionSigma"."$LowResMesh"k_fs_LR.func.gii -roi "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere".atlasroi."$LowResMesh"k_fs_LR.shape.gii
    ${CARET7DIR}/wb_command -metric-resample "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere"."$Map"_s"$CorrectionSigma"."$LowResMesh"k_fs_LR.func.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere".sphere."$LowResMesh"k_fs_LR.surf.gii ${RegSphere} ADAP_BARY_AREA "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Map"_s"$CorrectionSigma".native.func.gii -area-surfs "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii -current-roi "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere".atlasroi."$LowResMesh"k_fs_LR.shape.gii
    ${CARET7DIR}/wb_command -metric-dilate "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Map"_s"$CorrectionSigma".native.func.gii "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii 30 "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Map"_s"$CorrectionSigma".native.func.gii -nearest
    ${CARET7DIR}/wb_command -metric-mask "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Map"_s"$CorrectionSigma".native.func.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".roi.native.shape.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Map"_s"$CorrectionSigma".native.func.gii
    rm "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere"."$Map"."$LowResMesh"k_fs_LR.func.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere"."$Map"_s"$CorrectionSigma"."$LowResMesh"k_fs_LR.func.gii
  done
  #${CARET7DIR}/wb_command -metric-smoothing "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".MyelinMap.native.func.gii "$CorrectionSigma" "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".MyelinMap_s"$CorrectionSigma".native.func.gii -roi "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".roi.native.shape.gii 
  #${CARET7DIR}/wb_command -metric-smoothing "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".RefMyelinMap.native.func.gii "$CorrectionSigma" "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".RefMyelinMap_s"$CorrectionSigma".native.func.gii -roi "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".roi.native.shape.gii 

  ${CARET7DIR}/wb_command -metric-math "(Individual - Reference) * Mask" "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".BiasField.native.func.gii -var Individual "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".MyelinMap_s"$CorrectionSigma".native.func.gii -var Reference "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".RefMyelinMap_s"$CorrectionSigma".native.func.gii -var Mask "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".roi.native.shape.gii 
  ${CARET7DIR}/wb_command -metric-math "(Individual - Bias) * Mask" "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".MyelinMap_BC.native.func.gii -var Individual "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".MyelinMap.native.func.gii -var Bias "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".BiasField.native.func.gii -var Mask "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".roi.native.shape.gii 
  ${CARET7DIR}/wb_command -metric-math "(Individual - Bias) * Mask" "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".SmoothedMyelinMap_BC.native.func.gii -var Individual "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".SmoothedMyelinMap.native.func.gii -var Bias "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".BiasField.native.func.gii -var Mask "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".roi.native.shape.gii 
  rm "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".MyelinMap_s"$CorrectionSigma".native.func.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".RefMyelinMap_s"$CorrectionSigma".native.func.gii
  for STRING in MyelinMap@func SmoothedMyelinMap@func MyelinMap_BC@func SmoothedMyelinMap_BC@func corrThickness@shape ; do
    Map=`echo $STRING | cut -d "@" -f 1`
    Ext=`echo $STRING | cut -d "@" -f 2`
    ${CARET7DIR}/wb_command -set-map-name "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Map".native."$Ext".gii 1 "$Subject"_"$Hemisphere"_"$Map"
    ${CARET7DIR}/wb_command -metric-palette "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Map".native."$Ext".gii MODE_AUTO_SCALE_PERCENTAGE -pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false
    ${CARET7DIR}/wb_command -metric-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Map".native."$Ext".gii ${RegSphere} "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".sphere."$HighResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$AtlasSpaceFolder"/"$Subject"."$Hemisphere"."$Map"."$HighResMesh"k_fs_LR."$Ext".gii -area-surfs "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".midthickness."$HighResMesh"k_fs_LR.surf.gii -current-roi "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".roi.native.shape.gii
    ${CARET7DIR}/wb_command -metric-mask "$AtlasSpaceFolder"/"$Subject"."$Hemisphere"."$Map"."$HighResMesh"k_fs_LR."$Ext".gii "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".atlasroi."$HighResMesh"k_fs_LR.shape.gii "$AtlasSpaceFolder"/"$Subject"."$Hemisphere"."$Map"."$HighResMesh"k_fs_LR."$Ext".gii
    for LowResMesh in ${LowResMeshes} ; do
      ${CARET7DIR}/wb_command -metric-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Map".native."$Ext".gii ${RegSphere} "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere".sphere."$LowResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere"."$Map"."$LowResMesh"k_fs_LR."$Ext".gii -area-surfs "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii -current-roi "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".roi.native.shape.gii
      ${CARET7DIR}/wb_command -metric-mask "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere"."$Map"."$LowResMesh"k_fs_LR."$Ext".gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere".atlasroi."$LowResMesh"k_fs_LR.shape.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere"."$Map"."$LowResMesh"k_fs_LR."$Ext".gii
    done
  done
done

STRINGII=""
for LowResMesh in ${LowResMeshes} ; do
  STRINGII=`echo "${STRINGII}${AtlasSpaceFolder}/fsaverage_LR${LowResMesh}k@${LowResMesh}k_fs_LR@atlasroi "`
done

#Create CIFTI Files
for STRING in "$AtlasSpaceFolder"/"$NativeFolder"@native@roi "$AtlasSpaceFolder"@"$HighResMesh"k_fs_LR@atlasroi ${STRINGII} ; do
  Folder=`echo $STRING | cut -d "@" -f 1`
  Mesh=`echo $STRING | cut -d "@" -f 2`
  ROI=`echo $STRING | cut -d "@" -f 3`
  for STRINGII in MyelinMap@func SmoothedMyelinMap@func MyelinMap_BC@func SmoothedMyelinMap_BC@func corrThickness@shape ; do
    Map=`echo $STRINGII | cut -d "@" -f 1`
    Ext=`echo $STRINGII | cut -d "@" -f 2`
    ${CARET7DIR}/wb_command -cifti-create-dense-scalar "$Folder"/"$Subject".${Map}."$Mesh".dscalar.nii -left-metric "$Folder"/"$Subject".L.${Map}."$Mesh"."$Ext".gii -roi-left "$Folder"/"$Subject".L."$ROI"."$Mesh".shape.gii -right-metric "$Folder"/"$Subject".R.${Map}."$Mesh"."$Ext".gii -roi-right "$Folder"/"$Subject".R."$ROI"."$Mesh".shape.gii
    ${CARET7DIR}/wb_command -set-map-names "$Folder"/"$Subject".${Map}."$Mesh".dscalar.nii -map 1 "${Subject}_${Map}"
    ${CARET7DIR}/wb_command -cifti-palette "$Folder"/"$Subject".${Map}."$Mesh".dscalar.nii MODE_AUTO_SCALE_PERCENTAGE "$Folder"/"$Subject".${Map}."$Mesh".dscalar.nii -pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false
  done
done

STRINGII=""
for LowResMesh in ${LowResMeshes} ; do
  STRINGII=`echo "${STRINGII}${AtlasSpaceFolder}/fsaverage_LR${LowResMesh}k@${AtlasSpaceFolder}/fsaverage_LR${LowResMesh}k@${LowResMesh}k_fs_LR ${T1wFolder}/fsaverage_LR${LowResMesh}k@${AtlasSpaceFolder}/fsaverage_LR${LowResMesh}k@${LowResMesh}k_fs_LR "`
done

#Add CIFTI Maps to Spec Files
for STRING in "$T1wFolder"/"$NativeFolder"@"$AtlasSpaceFolder"/"$NativeFolder"@native "$AtlasSpaceFolder"/"$NativeFolder"@"$AtlasSpaceFolder"/"$NativeFolder"@native "$AtlasSpaceFolder"@"$AtlasSpaceFolder"@"$HighResMesh"k_fs_LR ${STRINGII} ; do
  FolderI=`echo $STRING | cut -d "@" -f 1`
  FolderII=`echo $STRING | cut -d "@" -f 2`
  Mesh=`echo $STRING | cut -d "@" -f 3`
  for STRINGII in MyelinMap_BC@dscalar SmoothedMyelinMap_BC@dscalar corrThickness@dscalar ; do
    Map=`echo $STRINGII | cut -d "@" -f 1`
    Ext=`echo $STRINGII | cut -d "@" -f 2`
    ${CARET7DIR}/wb_command -add-to-spec-file "$FolderI"/"$Subject"."$Mesh".wb.spec INVALID "$FolderII"/"$Subject"."$Map"."$Mesh"."$Ext".nii
  done
done

echo -e "\n END: CreateMyelinMaps"
