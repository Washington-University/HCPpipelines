#!/bin/bash 
set -e

echo -e "\n START: AtlasRegistration to MNI152"

WorkingDirectory="$1"
T1wImage="$2"
T1wRestore="$3"
T1wRestoreBrain="$4"
T2wImage="$5"
T2wRestore="$6"
T2wRestoreBrain="$7"
Reference="$8"
ReferenceBrain="$9"
ReferenceMask="${10}"
Reference2mm="${11}"
Reference2mmMask="${12}"
OutputTransform="${13}"
OutputInvTransform="${14}"
OutputT1wImage="${15}"
OutputT1wImageRestore="${16}"
OutputT1wImageRestoreBrain="${17}"
OutputT2wImage="${18}"
OutputT2wImageRestore="${19}"
OutputT2wImageRestoreBrain="${20}"
FNIRTConfig="${21}"

T1wRestoreFile=`remove_ext $T1wRestore`;
T1wRestoreFile=`basename $T1wRestoreFile`;
T1wRestoreBrainFile=`remove_ext $T1wRestoreBrain`;
T1wRestoreBrainFile=`basename $T1wRestoreBrainFile`;



flirt -interp spline -dof 12 -in "$T1wRestoreBrain" -ref "$ReferenceBrain" -omat "$WorkingDirectory"/xfms/acpc2MNILinear.mat -out "$WorkingDirectory"/xfms/"$T1wRestoreBrainFile"_to_MNILinear
applywarp --interp=spline -i "$T1wRestore" -r "$ReferenceBrain" --premat="$WorkingDirectory"/xfms/acpc2MNILinear.mat -o "$WorkingDirectory"/xfms/"$T1wRestoreFile"_to_MNILinear

#cp "$Reference" "$WorkingDirectory"/MNI08mm.nii.gz
#cp "$Reference2mm" "$WorkingDirectory"/MNI2mm.nii.gz
#gunzip -f "$WorkingDirectory"/MNI08mm.nii.gz
#gunzip -f "$WorkingDirectory"/MNI2mm.nii.gz
#aff_conv "$WorkingDirectory"/MNI08mm.nii "$WorkingDirectory"/MNI2mm.nii $FSLDIR/etc/flirtsch/ident.mat "$WorkingDirectory"/xfms/0.8mm_to_2mm.mat wf
#aff_conv wf "$WorkingDirectory"/MNI08mm.nii "$WorkingDirectory"/MNI2mm.nii $FSLDIR/etc/flirtsch/ident.mat "$WorkingDirectory"/MNI08mm.nii "$WorkingDirectory"/MNI2mm.nii "$WorkingDirectory"/xfms/0.8mm_to_2mm.mat

#rm "$WorkingDirectory"/MNI08mm.nii
#rm "$WorkingDirectory"/MNI2mm.nii
flirt -in "$ReferenceBrain" -ref "$Reference2mm" -usesqform -applyxfm -omat "$WorkingDirectory"/xfms/0.8mm_to_2mm.mat
convert_xfm -omat "$WorkingDirectory"/xfms/acpc2MNILinear_2mm.mat -concat "$WorkingDirectory"/xfms/0.8mm_to_2mm.mat "$WorkingDirectory"/xfms/acpc2MNILinear.mat
applywarp --interp=spline -i "$T1wRestore" -r "$Reference2mm" --premat="$WorkingDirectory"/xfms/acpc2MNILinear_2mm.mat -o "$WorkingDirectory"/xfms/"$T1wRestoreFile"_to_MNILinear_2mm.nii.gz
convert_xfm -omat "$WorkingDirectory"/xfms/2mm_to_0.8mm.mat -inverse "$WorkingDirectory"/xfms/0.8mm_to_2mm.mat

fnirt --in="$WorkingDirectory"/xfms/"$T1wRestoreFile"_to_MNILinear_2mm.nii.gz --ref="$Reference2mm" --refmask="$Reference2mmMask" --fout="$WorkingDirectory"/xfms/MNINonlinearField.nii.gz --jout="$WorkingDirectory"/xfms/NonlinearRegJacobians.nii.gz --refout="$WorkingDirectory"/xfms/IntensityModulatedT1.nii.gz --iout="$WorkingDirectory"/xfms/2mmReg.nii.gz --logout="$WorkingDirectory"/xfms/NonlinearReg.txt --intout="$WorkingDirectory"/xfms/NonlinearIntesities.nii.gz --cout="$WorkingDirectory"/xfms/NonlinearReg.nii.gz --config="$FNIRTConfig"
convertwarp --ref="$Reference" --premat="$WorkingDirectory"/xfms/acpc2MNILinear_2mm.mat --warp1="$WorkingDirectory"/xfms/MNINonlinearField.nii.gz --postmat="$WorkingDirectory"/xfms/2mm_to_0.8mm.mat -o "$OutputTransform"
invwarp -w "$OutputTransform" -o "$OutputInvTransform" -r "$T1wRestore"
applywarp --interp=spline -i "$T1wImage" -r "$Reference" -w "$OutputTransform" -o "$OutputT1wImage"
applywarp --interp=spline -i "$T1wRestore" -r "$Reference" -w "$OutputTransform" -o "$OutputT1wImageRestore"
applywarp --interp=nn -i "$T1wRestoreBrain" -r "$Reference" -w "$OutputTransform" -o "$OutputT1wImageRestoreBrain"
fslmaths "$OutputT1wImageRestore" -mas "$OutputT1wImageRestoreBrain" "$OutputT1wImageRestoreBrain"
applywarp --interp=spline -i "$T2wImage" -r "$Reference" -w "$OutputTransform" -o "$OutputT2wImage"
applywarp --interp=spline -i "$T2wRestore" -r "$Reference" -w "$OutputTransform" -o "$OutputT2wImageRestore"
applywarp --interp=nn -i "$T2wRestoreBrain" -r "$Reference" -w "$OutputTransform" -o "$OutputT2wImageRestoreBrain"
fslmaths "$OutputT2wImageRestore" -mas "$OutputT2wImageRestoreBrain" "$OutputT2wImageRestoreBrain"

echo -e "\n END: AtlasRegistration to MNI152"
