#!/bin/bash

set -e
echo -e "\n START: DiffusionToStructural"

WorkingDirectory="$1"
DataDirectory="$2"
T1wOutputDirectory="$3"
T1wImage="$4"
T1wRestoreImage="$5"
T1wBrainImage="$6"
BiasField="$7"
FreeSurferSubjectFolder="$8"
FreeSurferSubjectID="$9"
RegOutput="${10}"
QAImage="${11}"
InputBrainMask="${12}"
GlobalScripts="${13}"
GlobalBinaries="${14}"



T1wBrainImageFile=`basename $T1wBrainImage`
regimg="nodif"

cp "$T1wBrainImage".nii.gz "$WorkingDirectory"/"$T1wBrainImageFile".nii.gz

#b0 FLIRT BBR and bbregister to T1w


"$GlobalScripts"/epi_reg.sh "$DataDirectory"/"$regimg" "$T1wImage" "$WorkingDirectory"/"$T1wBrainImageFile" "$WorkingDirectory"/"$regimg"2T1w_initII
${FSLDIR}/bin/applywarp --interp=spline -i "$DataDirectory"/"$regimg" -r "$T1wImage" --premat="$WorkingDirectory"/"$regimg"2T1w_initII_init.mat -o "$WorkingDirectory"/"$regimg"2T1w_init.nii.gz
${FSLDIR}/bin/applywarp --interp=spline -i "$DataDirectory"/"$regimg" -r "$T1wImage" --premat="$WorkingDirectory"/"$regimg"2T1w_initII.mat -o "$WorkingDirectory"/"$regimg"2T1w_initII.nii.gz
${FSLDIR}/bin/fslmaths "$WorkingDirectory"/"$regimg"2T1w_initII.nii.gz -div "$BiasField" "$WorkingDirectory"/"$regimg"2T1w_restore_initII.nii.gz

SUBJECTS_DIR="$FreeSurferSubjectFolder"
export SUBJECTS_DIR
bbregister --s "$FreeSurferSubjectID" --mov "$WorkingDirectory"/"$regimg"2T1w_restore_initII.nii.gz --surf white.deformed --init-reg "$FreeSurferSubjectFolder"/"$FreeSurferSubjectID"/mri/transforms/eye.dat --bold --reg "$WorkingDirectory"/EPItoT1w.dat --o "$WorkingDirectory"/"$regimg"2T1w.nii.gz
tkregister2 --noedit --reg "$WorkingDirectory"/EPItoT1w.dat --mov "$WorkingDirectory"/"$regimg"2T1w_restore_initII.nii.gz --targ "$T1wImage".nii.gz --fslregout "$WorkingDirectory"/diff2str_fs.mat

${FSLDIR}/bin/convert_xfm -omat "$WorkingDirectory"/diff2str.mat -concat "$WorkingDirectory"/diff2str_fs.mat "$WorkingDirectory"/"$regimg"2T1w_initII.mat
${FSLDIR}/bin/convert_xfm -omat "$WorkingDirectory"/str2diff.mat -inverse "$WorkingDirectory"/diff2str.mat

${FSLDIR}/bin/applywarp --interp=spline -i "$DataDirectory"/"$regimg" -r "$T1wImage".nii.gz --premat="$WorkingDirectory"/diff2str.mat -o "$WorkingDirectory"/"$regimg"2T1w
${FSLDIR}/bin/fslmaths "$WorkingDirectory"/"$regimg"2T1w -div "$BiasField" "$WorkingDirectory"/"$regimg"2T1w_restore

#Are the next two scripts needed?
${FSLDIR}/bin/imcp "$WorkingDirectory"/"$regimg"2T1w_restore "$RegOutput"
${FSLDIR}/bin/fslmaths "$T1wRestoreImage".nii.gz -mul "$WorkingDirectory"/"$regimg"2T1w_restore.nii.gz -sqrt "$QAImage"_"$regimg".nii.gz

#Generate 1.25mm structural space for resampling the diffusion data into
${FSLDIR}/bin/flirt -interp spline -in "$T1wRestoreImage" -ref "$T1wRestoreImage" -applyisoxfm 1.25 -out "$T1wRestoreImage"_1.25
${FSLDIR}/bin/applywarp --interp=spline -i "$T1wRestoreImage" -r "$T1wRestoreImage"_1.25 -o "$T1wRestoreImage"_1.25

echo "Correcting Diffusion data for gradient nonlinearities and registering to structural space"
#In the future, we want this applywarp to be part of eddy and avoid second resampling step.
${FSLDIR}/bin/convertwarp --warp1="$DataDirectory"/warped/fullWarp_abs --abs --postmat="$WorkingDirectory"/diff2str.mat --ref="$T1wRestoreImage"_1.25 --out="$WorkingDirectory"/grad_unwarp_diff2str
${FSLDIR}/bin/applywarp -i "$DataDirectory"/warped/data_warped -r "$T1wRestoreImage"_1.25 -w "$WorkingDirectory"/grad_unwarp_diff2str --interp=spline -o "$T1wOutputDirectory"/data

#Generate 1.25mm mask in structural space
${FSLDIR}/bin/flirt -interp nearestneighbour -in "$InputBrainMask" -ref "$InputBrainMask" -applyisoxfm 1.25 -out "$T1wOutputDirectory"/nodif_brain_mask
${FSLDIR}/bin/fslmaths "$T1wOutputDirectory"/nodif_brain_mask -kernel 3D -dilM "$T1wOutputDirectory"/nodif_brain_mask

${FSLDIR}/bin/fslmaths "$T1wOutputDirectory"/data -mas "$T1wOutputDirectory"/nodif_brain_mask "$T1wOutputDirectory"/data  #Mask-out data outside the brain 
${FSLDIR}/bin/fslmaths "$T1wOutputDirectory"/data -thr 0 "$T1wOutputDirectory"/data      #Remove negative intensity values (caused by spline interpolation) from final data


#Rotate bvecs from diffusion to structural space
${GlobalScripts}/Rotate_bvecs.sh "$DataDirectory"/bvecs "$WorkingDirectory"/diff2str.mat "$T1wOutputDirectory"/bvecs
cp "$DataDirectory"/bvals "$T1wOutputDirectory"/bvals

#Now register the grad_dev tensor 
${GlobalBinaries}/vecreg -i "$DataDirectory"/grad_dev -o "$T1wOutputDirectory"/grad_dev -r "$T1wRestoreImage"_1.25 -t "$WorkingDirectory"/diff2str.mat --interp=spline
${FSLDIR}/bin/fslmaths "$T1wOutputDirectory"/grad_dev -mas "$T1wOutputDirectory"/nodif_brain_mask "$T1wOutputDirectory"/grad_dev  #Mask-out values outside the brain 

echo " END: DiffusionToStructural"
