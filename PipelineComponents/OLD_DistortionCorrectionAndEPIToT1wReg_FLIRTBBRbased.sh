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

InputfMRIFile=`basename $InputfMRI`
ScoutInputFile=`basename $ScoutInputName`
T1wRestoreImageFile=`basename $T1wRestoreImage`

#Take the mean motion corrected fMRI volume
fslmaths "$InputfMRI" -Tmean "$InputfMRI"_mean

#Do distortion correction and registration of fMRI to T1w image.  Use T1w image with bias field because the fMRI has a bias field as well.  
flirt -dof 6 -in "$InputfMRI"_mean -ref "$ScoutInputName" -omat "$WorkingDirectory"/fMRI2Scout.mat -out "$WorkingDirectory"/"$InputfMRIFile"_mean2Scout
fslmaths "$T1wRestoreImage" -mas "$T1wBrainImage" "$T1wRestoreImage"_brain_fs
cp "$T1wRestoreImage"_brain_fs.nii.gz "$WorkingDirectory"/"$T1wRestoreImageFile"_brain_fs.nii.gz
epi_reg "$ScoutInputName" "$T1wImage" "$WorkingDirectory"/"$T1wRestoreImageFile"_brain_fs "$WorkingDirectory"/"$ScoutInputFile"_undistorted "$FieldMap" "$Magnitude" "$MagnitudeBrain" "$DwellTime" "$UnwarpDir"
applywarp --interp=spline -i "$ScoutInputName" -r "$T1wImage" -w "$WorkingDirectory"/"$ScoutInputFile"_undistorted_warp.nii.gz -o "$WorkingDirectory"/"$ScoutInputFile"_undistorted_1vol.nii.gz
fslmaths "$WorkingDirectory"/"$ScoutInputFile"_undistorted_1vol.nii.gz -div "$BiasField" "$WorkingDirectory"/"$ScoutInputFile"_undistorted_1vol.nii.gz
cp "$WorkingDirectory"/"$ScoutInputFile"_undistorted_1vol.nii.gz "$RegOutput".nii.gz

convertwarp --premat="$WorkingDirectory"/fMRI2Scout.mat --warp1="$WorkingDirectory"/"$ScoutInputFile"_undistorted_warp.nii.gz --ref="$T1wImage" --out="$OutputTransform"

