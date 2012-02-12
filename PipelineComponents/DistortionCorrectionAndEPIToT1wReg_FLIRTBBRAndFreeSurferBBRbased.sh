WorkingDirectory="$1"
ScoutInputName="$2"
T1wImage="$3"
T1wBrainImage="$4"
FieldMap="$5"
Magnitude="$6"
MagnitudeBrain="$7"
DwellTime="$8"
UnwarpDir="$9"
OutputTransform="${10}"
BiasField="${11}"
RegOutput="${12}"
FreeSurferSubjectFolder="${13}"
FreeSurferSubjectID="${14}"

ScoutInputFile=`basename $ScoutInputName`
T1wBrainImageFile=`basename $T1wBrainImage`
FieldMapFile=`basename $FieldMap`
MagnitudeBrainFile=`basename $MagnitudeBrain`


#fslmaths "$T1wRestoreImage" -mas "$T1wBrainImage" "$T1wRestoreImage"_brain_fs
cp "$T1wBrainImage".nii.gz "$WorkingDirectory"/"$T1wBrainImageFile"_brain_fs.nii.gz
epi_reg "$ScoutInputName" "$T1wImage" "$WorkingDirectory"/"$T1wBrainImageFile_brain_fs" "$WorkingDirectory"/"$ScoutInputFile"_undistorted "$FieldMap" "$Magnitude" "$MagnitudeBrain" "$DwellTime" "$UnwarpDir"
applywarp --interp=spline -i "$ScoutInputName" -r "$T1wImage" -w "$WorkingDirectory"/"$ScoutInputFile"_undistorted_warp.nii.gz -o "$WorkingDirectory"/"$ScoutInputFile"_undistorted_1vol.nii.gz
fslmaths "$WorkingDirectory"/"$ScoutInputFile"_undistorted_1vol.nii.gz -div "$BiasField" "$WorkingDirectory"/"$ScoutInputFile"_undistorted_1vol.nii.gz
mv "$WorkingDirectory"/"$ScoutInputFile"_undistorted_1vol.nii.gz "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w_init.nii.gz 

SUBJECTS_DIR="$FreeSurferSubjectFolder"
export SUBJECTS_DIR
bbregister --s "$FreeSurferSubjectID" --mov "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w_init.nii.gz --surf white.deformed --init-reg "$FreeSurferSubjectFolder"/"$FreeSurferSubjectID"/mri/transforms/eye.dat --bold --reg "$WorkingDirectory"/EPItoT1w.dat --o "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w.nii.gz
tkregister2 --noedit --reg "$WorkingDirectory"/EPItoT1w.dat --mov "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w_init.nii.gz --targ "$T1wImage".nii.gz --fslregout "$WorkingDirectory"/fMRI2str.mat
convertwarp --warp1="$WorkingDirectory"/"$ScoutInputFile"_undistorted_warp.nii.gz --ref="$T1wImage" --postmat="$WorkingDirectory"/fMRI2str.mat --out="$OutputTransform"
applywarp --interp=spline -i "$ScoutInputName" -r "$T1wImage".nii.gz -w "$OutputTransform" -o "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w
fslmaths "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w -div "$BiasField" "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w
fslmaths "$T1wRestoreImage" -mul "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w -sqrt "$WorkingDirectory"/T1wMulEPI.nii.gz

cp "$WorkingDirectory"/"$ScoutInputFile"_undistorted2T1w.nii.gz "$RegOutput".nii.gz


