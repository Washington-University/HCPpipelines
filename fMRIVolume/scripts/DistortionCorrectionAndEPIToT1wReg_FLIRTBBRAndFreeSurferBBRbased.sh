#!/bin/bash -e
echo -e "\n START: DistortionCorrectionEpiToT1wReg_FLIRTBBRAndFreeSurferBBRBased"

WorkingDirectory="$1"
ScoutInputName="$2"
T1wImage="$3"
T1wRestoreImage="$4"
T1wBrainImage="$5"
MagnitudeInputName="$6"
PhaseInputName="$7"
TE="$8"
DwellTime="$9"
UnwarpDir="${10}"
OutputTransform="${11}"
BiasField="${12}"
RegOutput="${13}"
FreeSurferSubjectFolder="${14}"
FreeSurferSubjectID="${15}"
GlobalScripts="${16}"
GradientDistortionCoeffs="${17}"
T2wRestoreImage="${18}"
FNIRTConfig="${19}"
QAImage="${20}"

ScoutInputFile=`basename $ScoutInputName`
T1wBrainImageFile=`basename $T1wBrainImage`

if [ ! -e "$WorkingDirectory"/FieldMap ] ; then
  mkdir "$WorkingDirectory"/FieldMap
fi

"$GlobalScripts"/FieldMapPreprocessingAll.sh "$WorkingDirectory"/FieldMap "$MagnitudeInputName" "$PhaseInputName" "$TE" "$WorkingDirectory"/Magnitude "$WorkingDirectory"/Magnitude_brain "$WorkingDirectory"/Phase "$WorkingDirectory"/FieldMap "$GradientDistortionCoeffs" "$GlobalScripts" 

cp "$T1wBrainImage".nii.gz "$WorkingDirectory"/"$T1wBrainImageFile".nii.gz
"$GlobalScripts"/epi_reg.sh "$ScoutInputName" "$T1wImage" "$WorkingDirectory"/"$T1wBrainImageFile" "$WorkingDirectory"/"$ScoutInputFile"_undistorted "$WorkingDirectory"/FieldMap.nii.gz "$WorkingDirectory"/Magnitude.nii.gz "$WorkingDirectory"/Magnitude_brain.nii.gz "$DwellTime" "$UnwarpDir"
applywarp --interp=spline -i "$ScoutInputName" -r "$T1wImage" -w "$WorkingDirectory"/"$ScoutInputFile"_undistorted_warp.nii.gz -o "$WorkingDirectory"/"$ScoutInputFile"_undistorted_1vol.nii.gz
fslmaths "$WorkingDirectory"/"$ScoutInputFile"_undistorted_1vol.nii.gz -div "$BiasField" "$WorkingDirectory"/"$ScoutInputFile"_undistorted_1vol.nii.gz
mv "$WorkingDirectory"/"$ScoutInputFile"_undistorted_1vol.nii.gz "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w_init.nii.gz 


SUBJECTS_DIR="$FreeSurferSubjectFolder"
export SUBJECTS_DIR
bbregister --s "$FreeSurferSubjectID" --mov "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w_init.nii.gz --surf white.deformed --init-reg "$FreeSurferSubjectFolder"/"$FreeSurferSubjectID"/mri/transforms/eye.dat --bold --reg "$WorkingDirectory"/EPItoT1w.dat --o "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w.nii.gz
tkregister2 --noedit --reg "$WorkingDirectory"/EPItoT1w.dat --mov "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w_init.nii.gz --targ "$T1wImage".nii.gz --fslregout "$WorkingDirectory"/fMRI2str.mat
convertwarp --warp1="$WorkingDirectory"/"$ScoutInputFile"_undistorted_warp.nii.gz --ref="$T1wImage" --postmat="$WorkingDirectory"/fMRI2str.mat --out="$WorkingDirectory"/fMRI2str.nii.gz
applywarp --interp=spline -i "$ScoutInputName" -r "$T1wImage".nii.gz -w "$WorkingDirectory"/fMRI2str.nii.gz -o "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w
fslmaths "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w -div "$BiasField" "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w

if [ ! "$FNIRTConfig" = "NONE" ] ; then
  Mean=`fslstats "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w -k "$T1wBrainImage".nii.gz -M`
  Std=`fslstats "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w -k "$T1wBrainImage".nii.gz -S`
  Lower=`echo "$Mean - $Std" | bc -l`
  fslmaths "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w -thr $Lower -bin "$WorkingDirectory"/inmask.nii.gz
  fslmaths "$T1wBrainImage".nii.gz -bin "$WorkingDirectory"/refmask.nii.gz
  fslmaths "$WorkingDirectory"/inmask.nii.gz -mas "$WorkingDirectory"/refmask.nii.gz "$WorkingDirectory"/inmask.nii.gz
  fslmaths "$WorkingDirectory"/refmask.nii.gz -mas "$WorkingDirectory"/inmask.nii.gz "$WorkingDirectory"/refmask.nii.gz
  fnirt --in="$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w --ref="$T2wRestoreImage" --inmask="$WorkingDirectory"/inmask.nii.gz --refmask="$WorkingDirectory"/refmask.nii.gz --applyinmask=1 --applyrefmask=1 --config="$FNIRTConfig" --iout="$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w_zblip.nii.gz --fout="$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w_zblip_warp.nii.gz
  convertwarp --ref="$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w_zblip.nii.gz --warp1="$WorkingDirectory"/fMRI2str.nii.gz --warp2="$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w_zblip_warp.nii.gz --out="$WorkingDirectory"/fMRI_zblip2str.nii.gz
  applywarp --interp=spline -i "$ScoutInputName" -r "$T1wImage".nii.gz -w "$WorkingDirectory"/fMRI_zblip2str.nii.gz -o "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w_zblip.nii.gz
  fslmaths "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w_zblip.nii.gz -div "$BiasField" "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w_zblip.nii.gz
  cp "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w_zblip.nii.gz "$RegOutput".nii.gz
  cp "$WorkingDirectory"/fMRI_zblip2str.nii.gz "$OutputTransform".nii.gz
else
  cp "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w.nii.gz "$RegOutput".nii.gz
  cp "$WorkingDirectory"/fMRI2str.nii.gz "$OutputTransform".nii.gz
fi

fslmaths "$T1wRestoreImage".nii.gz -mul "$RegOutput".nii.gz -sqrt "$QAImage".nii.gz

echo " END: DistortionCorrectionEpiToT1wReg_FLIRTBBRAndFreeSurferBBRBased"
