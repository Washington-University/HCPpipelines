#!/bin/bash 
set -e

echo -e "\n START: T2w to T1w Distortion Correction and Registration"

WorkingDirectory="$1"
T1wImage="$2"
T1wImageBrain="$3"
T2wImage="$4"
T2wImageBrain="$5"
FieldMapImage="$6"
MagnitudeImage="$7"
MagnitudeBrainImage="$8"
T1wSampleSpacing="$9"
T2wSampleSpacing="${10}"
UnwarpDir="${11}"
OutputT1wImage="${12}"
OutputT1wImageBrain="${13}"
OutputT1wTransform="${14}"
OutputT2wImage="${15}"
OutputT2wTransform="${16}"
GlobalScripts="${17}"

MagnitudeBrainImageFile=`basename "$MagnitudeBrainImage"`
FieldMapImageFile=`basename "$FieldMapImage"`
T1wImageBrainFile=`basename "$T1wImageBrain"`
T1wImageFile=`basename "$T1wImage"`
T2wImageBrainFile=`basename "$T2wImageBrain"`
T2wImageFile=`basename "$T2wImage"`

cd "$WorkingDirectory"

fugue -v -i "$MagnitudeBrainImage" --icorr --unwarpdir="$UnwarpDir" --dwell=$T1wSampleSpacing --loadfmap="$FieldMapImage" -w "$MagnitudeBrainImageFile"_warppedT1w
flirt -dof 6 -in "$MagnitudeBrainImageFile"_warppedT1w -ref "$T1wImageBrain" -out "$MagnitudeBrainImageFile"_warppedT1w2"$T1wImageBrainFile" -omat "$WorkingDirectory"/fieldmap2"$T1wImageBrainFile".mat 
flirt -in "$FieldMapImage" -ref "$T1wImageBrain" -applyxfm -init "$WorkingDirectory"/fieldmap2"$T1wImageBrainFile".mat -out "$FieldMapImageFile"2"$T1wImageBrainFile" 
fugue --loadfmap="$FieldMapImageFile"2"$T1wImageBrainFile" --dwell="$T1wSampleSpacing" --saveshift="$FieldMapImageFile"2"$T1wImageBrainFile"_ShiftMap.nii.gz
convertwarp --ref="$T1wImageBrain" --shiftmap="$FieldMapImageFile"2"$T1wImageBrainFile"_ShiftMap.nii.gz --shiftdir="$UnwarpDir" --out="$FieldMapImageFile"2"$T1wImageBrainFile"_Warp.nii.gz
applywarp --interp=spline -i "$T1wImage" -r "$T1wImage" -w "$FieldMapImageFile"2"$T1wImageBrainFile"_Warp.nii.gz -o "$T1wImageFile"
applywarp --interp=nn -i "$T1wImageBrain" -r "$T1wImageBrain" -w "$FieldMapImageFile"2"$T1wImageBrainFile"_Warp.nii.gz -o "$T1wImageBrainFile"
fslmaths "$T1wImageFile" -mas "$T1wImageBrainFile" "$T1wImageBrainFile"
cp "$FieldMapImageFile"2"$T1wImageBrainFile"_Warp.nii.gz "$OutputT1wTransform".nii.gz
cp "$T1wImageFile".nii.gz "$OutputT1wImage".nii.gz
cp "$T1wImageBrainFile".nii.gz "$OutputT1wImageBrain".nii.gz

fugue -v -i "$MagnitudeBrainImage" --icorr --unwarpdir="$UnwarpDir" --dwell=$T2wSampleSpacing --loadfmap="$FieldMapImage" -w "$MagnitudeBrainImageFile"_warppedT2w
flirt -dof 6 -in "$MagnitudeBrainImageFile"_warppedT2w -ref "$T2wImageBrain" -out "$MagnitudeBrainImageFile"_warppedT2w2"$T2wImageBrainFile" -omat "$WorkingDirectory"/fieldmap2"$T2wImageBrainFile".mat 
flirt -in "$FieldMapImage" -ref "$T2wImageBrain" -applyxfm -init "$WorkingDirectory"/fieldmap2"$T2wImageBrainFile".mat -out "$FieldMapImageFile"2"$T2wImageBrainFile" 
fugue --loadfmap="$FieldMapImageFile"2"$T2wImageBrainFile" --dwell="$T2wSampleSpacing" --saveshift="$FieldMapImageFile"2"$T2wImageBrainFile"_ShiftMap.nii.gz
convertwarp --ref="$T2wImageBrain" --shiftmap="$FieldMapImageFile"2"$T2wImageBrainFile"_ShiftMap.nii.gz --shiftdir="$UnwarpDir" --out="$FieldMapImageFile"2"$T2wImageBrainFile"_Warp.nii.gz
applywarp --interp=spline -i "$T2wImage" -r "$T2wImage" -w "$FieldMapImageFile"2"$T2wImageBrainFile"_Warp.nii.gz -o "$T2wImageFile"
applywarp --interp=nn -i "$T2wImageBrain" -r "$T2wImageBrain" -w "$FieldMapImageFile"2"$T2wImageBrainFile"_Warp.nii.gz -o "$T2wImageBrainFile"
fslmaths "$T2wImageFile" -mas "$T2wImageBrainFile" "$T2wImageBrainFile"

mkdir -p T2w2T1w
"$GlobalScripts"/epi_reg.sh "$T2wImageBrainFile" "$T1wImageFile" "$T1wImageBrainFile" T2w2T1w/T2w_reg
convertwarp --ref="$T1wImage" --warp1="$FieldMapImageFile"2"$T2wImageBrainFile"_Warp.nii.gz --postmat="$WorkingDirectory"/T2w2T1w/T2w_reg.mat -o T2w2T1w/T2w_dc_reg
applywarp --interp=spline --in="$T2wImage" --ref="$T1wImage" --warp=T2w2T1w/T2w_dc_reg --out=T2w2T1w/T2w_reg
fslmaths T2w2T1w/T2w_reg.nii.gz -add 1 T2w2T1w/T2w_reg.nii.gz -odt float
cp T2w2T1w/T2w_dc_reg.nii.gz "$OutputT2wTransform".nii.gz
cp T2w2T1w/T2w_reg.nii.gz "$OutputT2wImage".nii.gz

echo -e "\n END: T2w to T1w Distortion Correction and Registration"

