#!/bin/bash

SubjectID="$1" #FreeSurfer Subject ID Name
SubjectDIR="$2" #Location to Put FreeSurfer Subject's Folder
T1wImage="$3" #T1w FreeSurfer Input (Full Resolution)
T2wImage="$4" #T2w FreeSurfer Input (Full Resolution)
PipelineComponents="$5"

T1wImageFile=`remove_ext $T1wImage`;

#Make Spline Interpolated Downsample to 1mm
flirt -interp spline -in "$T1wImage" -ref "$T1wImage" -applyisoxfm 1 -out "$T1wImageFile"_1mm.nii.gz
applywarp --interp=spline -i "$T1wImage" -r "$T1wImageFile"_1mm.nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$T1wImageFile"_1mm.nii.gz

#Initial Recon-all Steps
recon-all -i "$T1wImageFile"_1mm.nii.gz -subjid $SubjectID -sd $SubjectDIR -autorecon1 -autorecon2 -nosmooth2 -noinflate2

#Highres white stuff and Fine Tune T2w to T1w Reg
"$PipelineComponents"/FreeSurferHiresWhite.sh "$SubjectID" "$SubjectDIR" "$T1wImage" "$T2wImage" "$PipelineComponents" 

#Intermediate Recon-all Steps
recon-all -subjid $SubjectID -sd $SubjectDIR -smooth2 -inflate2 -sphere -surfreg -jacobian_white -avgcurv -cortparc 

#Highres pial stuff (this module will adjust the pial surface based on the the T2w image in the future)
"$PipelineComponents"/FreeSurferHiresPial.sh "$SubjectID" "$SubjectDIR" "$T1wImage" "$T2wImage" "$PipelineComponents"

#Final Recon-all Steps
recon-all -subjid $SubjectID -sd $SubjectDIR -surfvolume -parcstats -cortparc2 -parcstats2 -cortribbon -segstats -aparc2aseg -wmparc -balabels -label-exvivo-ec 


