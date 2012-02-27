#!/bin/bash 
set -e

echo -e "\n START: BrainExtrtaction_FNIRT"

WorkingDirectory="$1"
Input="$2"
Reference="$3"
ReferenceMask="$4"
Reference2mm="$5"
Reference2mmMask="$6"
OutputBrainExtractedImage="$7"
OutputBrainMask="$8"
FNIRTConfig="$9"

InputFile=`remove_ext $Input`;
InputFile=`basename $InputFile`;


flirt -interp spline -dof 12 -in "$Input" -ref "$Reference" -omat "$WorkingDirectory"/roughlin.mat -out "$WorkingDirectory"/"$InputFile"_to_MNI_roughlin.nii.gz -nosearch
cp "$Reference" "$WorkingDirectory"/MNI08mm.nii.gz
cp "$Reference2mm" "$WorkingDirectory"/MNI2mm.nii.gz
gunzip -f "$WorkingDirectory"/MNI08mm.nii.gz
gunzip -f "$WorkingDirectory"/MNI2mm.nii.gz
#aff_conv "$WorkingDirectory"/MNI08mm.nii "$WorkingDirectory"/MNI2mm.nii $FSLDIR/etc/flirtsch/ident.mat "$WorkingDirectory"/0.8mm_to_2mm.mat wf
aff_conv wf "$WorkingDirectory"/MNI08mm.nii "$WorkingDirectory"/MNI2mm.nii $FSLDIR/etc/flirtsch/ident.mat "$WorkingDirectory"/MNI08mm.nii "$WorkingDirectory"/MNI2mm.nii "$WorkingDirectory"/0.8mm_to_2mm.mat
gzip "$WorkingDirectory"/MNI08mm.nii
gzip "$WorkingDirectory"/MNI2mm.nii
convert_xfm -omat "$WorkingDirectory"/roughlin_2mm.mat -concat "$WorkingDirectory"/0.8mm_to_2mm.mat "$WorkingDirectory"/roughlin.mat
applywarp --interp=spline -i "$Input" -r "$Reference2mm" --premat="$WorkingDirectory"/roughlin_2mm.mat -o "$WorkingDirectory"/"$InputFile"_to_MNI_roughlin_2mm.nii.gz
convert_xfm -omat "$WorkingDirectory"/2mm_to_0.8mm.mat -inverse "$WorkingDirectory"/0.8mm_to_2mm.mat
fnirt --in="$WorkingDirectory"/"$InputFile"_to_MNI_roughlin_2mm.nii.gz --ref="$Reference2mm" --refmask="$Reference2mmMask" --fout="$WorkingDirectory"/NonlinearRegField.nii.gz --jout="$WorkingDirectory"/NonlinearRegJacobians.nii.gz --refout="$WorkingDirectory"/IntensityModulatedT1.nii.gz --iout="$WorkingDirectory"/"$InputFile"_to_MNI_nonlin.nii.gz --logout="$WorkingDirectory"/NonlinearReg.txt --intout="$WorkingDirectory"/NonlinearIntesities.nii.gz --cout="$WorkingDirectory"/NonlinearReg.nii.gz --config="$FNIRTConfig"
convertwarp --ref="$Reference" --premat="$WorkingDirectory"/roughlin_2mm.mat --warp1="$WorkingDirectory"/NonlinearRegField.nii.gz --postmat="$WorkingDirectory"/2mm_to_0.8mm.mat --out="$WorkingDirectory"/str2standard.nii.gz
applywarp --interp=spline --in="$Input" --ref="$Reference" -w "$WorkingDirectory"/str2standard.nii.gz --out="$WorkingDirectory"/"$InputFile"_to_MNI_nonlin.nii.gz
invwarp --ref="$Input" -w "$WorkingDirectory"/str2standard.nii.gz -o "$WorkingDirectory"/standard2str.nii.gz
applywarp --interp=nn --in="$ReferenceMask" --ref="$Input" -w "$WorkingDirectory"/standard2str.nii.gz -o "$OutputBrainMask"
fslmaths "$Input" -mas "$OutputBrainMask" "$OutputBrainExtractedImage"

echo -e "\n END: BrainExtrtaction_FNIRT"
