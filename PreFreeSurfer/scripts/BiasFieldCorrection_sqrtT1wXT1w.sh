#!/bin/bash 
set -e

echo -e "\n START: BiasFieldCorrection"

WorkingDirectory="$1"
T1wImage="$2"
T1wImageBrain="$3"
T2wImage="$4"
OutputBiasField="$5"
OutputT1wRestoredImage="$6"
OutputT1wRestoredBrainImage="$7"
OutputT2wRestoredImage="$8"
OutputT2wRestoredBrainImage="$9"
Caret5_Command="${10}"

Factor="0.5" #Leave this at 0.5 for now it is the number of standard deviations below the mean to threshold the non-brain tissues at
BiasFieldSmoothingSigma=5 #Leave this at 5mm for now

cd "$WorkingDirectory"
fslmaths "$T1wImage" -mul "$T2wImage" -abs -sqrt "$WorkingDirectory"/T1wmulT2w.nii.gz -odt float
fslmaths "$WorkingDirectory"/T1wmulT2w.nii.gz -mas "$T1wImageBrain" "$WorkingDirectory"/T1wmulT2w_brain.nii.gz
fslmaths "$WorkingDirectory"/T1wmulT2w_brain.nii.gz -div `fslstats "$WorkingDirectory"/T1wmulT2w_brain.nii.gz -M` "$WorkingDirectory"/T1wmulT2w_brain_norm.nii.gz
fslmaths "$WorkingDirectory"/T1wmulT2w_brain_norm.nii.gz -bin -s "$BiasFieldSmoothingSigma" "$WorkingDirectory"/SmoothNorm_s"$BiasFieldSmoothingSigma".nii.gz
fslmaths "$WorkingDirectory"/T1wmulT2w_brain_norm.nii.gz -s "$BiasFieldSmoothingSigma" -div "$WorkingDirectory"/SmoothNorm_s"$BiasFieldSmoothingSigma".nii.gz "$WorkingDirectory"/T1wmulT2w_brain_norm_s"$BiasFieldSmoothingSigma".nii.gz
fslmaths "$WorkingDirectory"/T1wmulT2w_brain_norm.nii.gz -div "$WorkingDirectory"/T1wmulT2w_brain_norm_s"$BiasFieldSmoothingSigma".nii.gz "$WorkingDirectory"/T1wmulT2w_brain_norm_modulate.nii.gz
STD=`fslstats "$WorkingDirectory"/T1wmulT2w_brain_norm_modulate.nii.gz -S`
echo $STD
MEAN=`fslstats "$WorkingDirectory"/T1wmulT2w_brain_norm_modulate.nii.gz -M`
echo $MEAN
Lower=`echo "$MEAN - ($STD * $Factor)" | bc -l`
echo $Lower
fslmaths "$WorkingDirectory"/T1wmulT2w_brain_norm_modulate -thr "$Lower" -bin -ero -mul 255 "$WorkingDirectory"/T1wmulT2w_brain_norm_modulate_mask
"$Caret5_Command"/caret_command -volume-remove-islands "$WorkingDirectory"/T1wmulT2w_brain_norm_modulate_mask.nii.gz "$WorkingDirectory"/T1wmulT2w_brain_norm_modulate_mask.nii.gz
#Reorient? #There is an error message on the next line, but no problem is detectable, ignoring.
fslmaths "$WorkingDirectory"/T1wmulT2w_brain_norm.nii.gz -mas "$WorkingDirectory"/T1wmulT2w_brain_norm_modulate_mask.nii.gz -dilD -dilD -dilD -dilD -dilD -dilD -dilD -dilD -dilD -dilD -dilD -dilD -dilD -dilD -dilD -dilD -dilD -dilD -dilD -dilD -dilD -dilD -dilD -dilD -dilD -dilD -dilD -dilD -dilD -dilD "$WorkingDirectory"/bias_raw.nii.gz -odt float
fslmaths "$WorkingDirectory"/bias_raw.nii.gz -bin -s "$BiasFieldSmoothingSigma" "$WorkingDirectory"/SmoothNorm_s"$BiasFieldSmoothingSigma".nii.gz
fslmaths "$WorkingDirectory"/bias_raw.nii.gz -s "$BiasFieldSmoothingSigma" -div "$WorkingDirectory"/SmoothNorm_s"$BiasFieldSmoothingSigma".nii.gz "$OutputBiasField"
fslmaths "$T1wImage" -div "$OutputBiasField" -mas "$T1wImageBrain" "$OutputT1wRestoredBrainImage" -odt float
fslmaths "$T1wImage" -div "$OutputBiasField" "$OutputT1wRestoredImage" -odt float
fslmaths "$T2wImage" -div "$OutputBiasField" -mas "$T1wImageBrain" "$OutputT2wRestoredBrainImage" -odt float
fslmaths "$T2wImage" -div "$OutputBiasField" "$OutputT2wRestoredImage" -odt float

echo -e "\n END: BiasFieldCorrection"
