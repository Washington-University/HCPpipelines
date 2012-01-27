WorkingDirectory="$1"
InputfMRI="$2"
ScoutInputName="$3"
T1wImage="$4"
T1wRestoreImage="$5"
T1wBrainImage="$6"
FieldMap="$7"
Magnitude="$8"
MagnitudeBrain="$9"
DwellTime="${10}"
UnwarpDir="${11}"
OutputTransform="${12}"
BiasField="${13}"
RegOutput="${14}"
FreeSurferSubjectFolder="${15}"
FreeSurferSubjectID="${16}"

InputfMRIFile=`basename $InputfMRI`
ScoutInputFile=`basename $ScoutInputName`
T1wRestoreImageFile=`basename $T1wRestoreImage`
FieldMapFile=`basename $FieldMap`
MagnitudeBrainFile=`basename $MagnitudeBrain`

#Take the mean motion corrected fMRI volume
fslmaths "$InputfMRI" -Tmean "$InputfMRI"_mean

#Do distortion correction and registration of fMRI to T1w image.  Use T1w image with bias field because the fMRI has a bias field as well.  
flirt -dof 6 -in "$InputfMRI"_mean -ref "$ScoutInputName" -omat "$WorkingDirectory"/fMRI2Scout.mat -out "$WorkingDirectory"/"$InputfMRIFile"_mean2Scout

fugue -v -i "$MagnitudeBrain" --icorr --unwarpdir="$UnwarpDir" --dwell=$DwellTime --loadfmap="$FieldMap" -w "$MagnitudeBrain"_warpped #Warp the magnitude image according to the expected EPI distortion

bet "$ScoutInputName" "$ScoutInputName"_brain -m -f .25 #Brain extract the first volume
flirt -dof 6 -in "$MagnitudeBrain"_warpped -ref "$ScoutInputName"_brain -out "$MagnitudeBrain"_warpped2Scout -omat "$WorkingDirectory"/fieldmap2fMRI.mat #Register the warped magnitude image to the first volume and output an affine transformation matrix

flirt -in "$FieldMap" -ref "$ScoutInputName" -applyxfm -init "$WorkingDirectory"/fieldmap2fMRI.mat -out "$WorkingDirectory"/"$FieldMapFile"2Scout #Apply affine transformation matrix to field map

#Convert Field Map to general Warpfield 
fugue --loadfmap="$WorkingDirectory"/"$FieldMapFile"2Scout --dwell=$DwellTime --saveshift="$WorkingDirectory"/FieldMap_ShiftMap.nii.gz
convertwarp --ref="$ScoutInputName"_brain --shiftmap="$WorkingDirectory"/FieldMap_ShiftMap.nii.gz --shiftdir="$UnwarpDir" --out="$WorkingDirectory"/FieldMap_Warp.nii.gz
applywarp --interp=spline -i "$ScoutInputName" -r "$ScoutInputName" -w "$WorkingDirectory"/FieldMap_Warp.nii.gz -o "$WorkingDirectory"/"$ScoutInputFile"_undistorted

#bbregister based BOLD to T1 registration
#flirt -in "$WorkingDirectory"/"$ScoutInputFile"_undistorted -ref "$WorkingDirectory"/"$ScoutInputFile"_undistorted -applyisoxfm 1 -out "$WorkingDirectory"/"$ScoutInputFile"_undistorted1
##applywarp --interp=spline -i "$WorkingDirectory"/"$ScoutInputFile"_undistorted --premat=$FSLDIR/etc/flirtsch/ident.mat -r "$WorkingDirectory"/"$ScoutInputFile"_undistorted1 -o "$WorkingDirectory"/"$ScoutInputFile"_undistorted1
#applywarp --interp=spline -i "$WorkingDirectory"/"$ScoutInputFile"_undistorted -r "$WorkingDirectory"/"$ScoutInputFile"_undistorted1 -o "$WorkingDirectory"/"$ScoutInputFile"_undistorted1
#mri_convert "$WorkingDirectory"/"$ScoutInputFile"_undistorted1.nii.gz "$WorkingDirectory"/"$ScoutInputFile"_undistorted1_conform_RAS.nii.gz --conform
#SUBJECTS_DIR="$FreeSurferSubjectFolder"
#bbregister --s "$FreeSurferSubjectID" --mov "$WorkingDirectory"/"$ScoutInputFile"_undistorted1_conform_RAS.nii.gz --reg "$WorkingDirectory"/fsreg.dat --init-fsl --bold --o "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w_fs.nii.gz --fslmat "$WorkingDirectory"/fMRI2str_fs.mat
#applywarp --interp=spline -i "$WorkingDirectory"/"$ScoutInputFile"_undistorted -r "$T1wImage" --premat="$WorkingDirectory"/fMRI2str_fs.mat -o "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w_translated.nii.gz
#mri_convert -rl "$T1wImage".nii.gz "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w_fs.nii.gz "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w_fs.nii.gz
#flirt -dof 6 -nosearch -in "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w_translated.nii.gz -ref "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w_fs.nii.gz -omat "$WorkingDirectory"/translate.mat -out "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w_not_translated.nii.gz
#convert_xfm -omat "$WorkingDirectory"/fMRI2str.mat -concat "$WorkingDirectory"/translate.mat "$WorkingDirectory"/fMRI2str_fs.mat
#applywarp --interp=spline -i "$WorkingDirectory"/"$ScoutInputFile"_undistorted -r "$T1wImage" --premat="$WorkingDirectory"/fMRI2str.mat -o "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w_final

SUBJECTS_DIR="$FreeSurferSubjectFolder"
export SUBJECTS_DIR
flirt -interp spline -dof 6 -in "$WorkingDirectory"/"$ScoutInputFile"_undistorted.nii.gz -ref "$T1wBrainImage" -omat "$WorkingDirectory"/fMRI2str_init.mat -out "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w_init.nii.gz
bbregister --s "$FreeSurferSubjectID" --mov "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w_init.nii.gz --surf white.deformed --init-reg "$FreeSurferSubjectFolder"/"$FreeSurferSubjectID"/mri/transforms/eye.dat --bold --reg "$WorkingDirectory"/EPItoT1w.dat --o "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w.nii.gz
tkregister2 --noedit --reg "$WorkingDirectory"/EPItoT1w.dat --mov "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w_init.nii.gz --targ "$T1wImage".nii.gz --fslregout "$WorkingDirectory"/fMRI2str.mat
convert_xfm -omat "$WorkingDirectory"/fMRI2str.mat -concat "$WorkingDirectory"/fMRI2str.mat "$WorkingDirectory"/fMRI2str_init.mat 
applywarp --interp=spline -i "$ScoutInputName" -r "$T1wImage".nii.gz  -w "$WorkingDirectory"/FieldMap_Warp.nii.gz --postmat="$WorkingDirectory"/fMRI2str.mat -o "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w
fslmaths "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w -div "$BiasField" "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w

cp "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w_final.nii.gz "$RegOutput".nii.gz

convertwarp --premat="$WorkingDirectory"/fMRI2Scout.mat --warp1="$WorkingDirectory"/FieldMap_Warp.nii.gz --postmat="$WorkingDirectory"/fMRI2str.mat --ref="$T1wImage" --out="$OutputTransform"

