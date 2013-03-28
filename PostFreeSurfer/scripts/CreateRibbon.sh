#!/bin/bash
set -e
echo -e "\n START: CreateRibbon"

StudyFolder="$1"
Subject="$2"
T1wFolder="$3"
AtlasSpaceFolder="$4"
NativeFolder="$5"
AtlasSpaceT1wImage="$6"
T1wImage="$7"
FreeSurferLabels="$8"

LeftGreyRibbonValue="3"
LeftWhiteMaskValue="2"
RightGreyRibbonValue="42"
RightWhiteMaskValue="41"

for Hemisphere in L R ; do
  if [ $Hemisphere = "L" ] ; then
    GreyRibbonValue="$LeftGreyRibbonValue"
    WhiteMaskValue="$LeftWhiteMaskValue"
  elif [ $Hemisphere = "R" ] ; then
    GreyRibbonValue="$RightGreyRibbonValue"
    WhiteMaskValue="$RightWhiteMaskValue"
  fi    
  ${CARET7DIR}/wb_command -create-signed-distance-volume "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white.native.surf.gii "$T1wFolder"/"$T1wImage".nii.gz "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white.native.nii.gz
  ${CARET7DIR}/wb_command -create-signed-distance-volume "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial.native.surf.gii "$T1wFolder"/"$T1wImage".nii.gz "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial.native.nii.gz
  fslmaths "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white.native.nii.gz -thr 0 -bin -mul 255 "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz
  fslmaths "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz -bin "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz
  fslmaths "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial.native.nii.gz -uthr 0 -abs -bin -mul 255 "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz
  fslmaths "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz -bin "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz
  fslmaths "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz -mas "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz -mul 255 "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".ribbon.nii.gz
  fslmaths "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".ribbon.nii.gz -bin -mul $GreyRibbonValue "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".ribbon.nii.gz
  fslmaths "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white.native.nii.gz -uthr 0 -abs -bin -mul 255 "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_uthr0.native.nii.gz
  fslmaths "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_uthr0.native.nii.gz -bin "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_uthr0.native.nii.gz
  fslmaths "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_uthr0.native.nii.gz -mul $WhiteMaskValue "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_mask.native.nii.gz
  fslmaths "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".ribbon.nii.gz -add "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_mask.native.nii.gz "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".ribbon.nii.gz
  rm "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white.native.nii.gz "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial.native.nii.gz "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_uthr0.native.nii.gz "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_mask.native.nii.gz
done

fslmaths "$T1wFolder"/"$NativeFolder"/"$Subject".L.ribbon.nii.gz -add "$T1wFolder"/"$NativeFolder"/"$Subject".R.ribbon.nii.gz "$T1wFolder"/ribbon.nii.gz
rm "$T1wFolder"/"$NativeFolder"/"$Subject".L.ribbon.nii.gz "$T1wFolder"/"$NativeFolder"/"$Subject".R.ribbon.nii.gz
${CARET7DIR}/wb_command -volume-label-import "$T1wFolder"/ribbon.nii.gz "$FreeSurferLabels" "$T1wFolder"/ribbon.nii.gz -drop-unused-labels


for Hemisphere in L R ; do
  if [ $Hemisphere = "L" ] ; then
    GreyRibbonValue="$LeftGreyRibbonValue"
    WhiteMaskValue="$LeftWhiteMaskValue"
  elif [ $Hemisphere = "R" ] ; then
    GreyRibbonValue="$RightGreyRibbonValue"
    WhiteMaskValue="$RightWhiteMaskValue"
  fi    
  ${CARET7DIR}/wb_command -create-signed-distance-volume "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white.native.surf.gii "$AtlasSpaceFolder"/"$AtlasSpaceT1wImage".nii.gz "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white.native.nii.gz
  ${CARET7DIR}/wb_command -create-signed-distance-volume "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial.native.surf.gii "$AtlasSpaceFolder"/"$AtlasSpaceT1wImage".nii.gz "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial.native.nii.gz
  fslmaths "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white.native.nii.gz -thr 0 -bin -mul 255 "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz
  fslmaths "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz -bin "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz
  fslmaths "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial.native.nii.gz -uthr 0 -abs -bin -mul 255 "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz
  fslmaths "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz -bin "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz
  fslmaths "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz -mas "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz -mul 255 "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".ribbon.nii.gz
  fslmaths "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".ribbon.nii.gz -bin -mul $GreyRibbonValue "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".ribbon.nii.gz
  fslmaths "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white.native.nii.gz -uthr 0 -abs -bin -mul 255 "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_uthr0.native.nii.gz
  fslmaths "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_uthr0.native.nii.gz -bin "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_uthr0.native.nii.gz
  fslmaths "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_uthr0.native.nii.gz -mul $WhiteMaskValue "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_mask.native.nii.gz
  fslmaths "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".ribbon.nii.gz -add "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_mask.native.nii.gz "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".ribbon.nii.gz
  rm "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white.native.nii.gz "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial.native.nii.gz "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_uthr0.native.nii.gz "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_mask.native.nii.gz
done

fslmaths "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject".L.ribbon.nii.gz -add "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject".R.ribbon.nii.gz "$AtlasSpaceFolder"/ribbon.nii.gz
rm "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject".L.ribbon.nii.gz "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject".R.ribbon.nii.gz
${CARET7DIR}/wb_command -volume-label-import "$AtlasSpaceFolder"/ribbon.nii.gz "$FreeSurferLabels" "$AtlasSpaceFolder"/ribbon.nii.gz -drop-unused-labels

echo -e "\n END: CreateRibbon"

