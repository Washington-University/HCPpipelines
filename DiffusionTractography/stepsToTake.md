Before running anything if you want to do group:
Applywarp the relevant files into the correct space. Files absolutely needed: wmparc T1w_restore_1.25.nii.gz, brainmask_fs
Ex:
    TrajectorySpaceFolder="${StudyFolder}/${Subject}/${volspace}"
    ${FSLDIR}/bin/flirt -interp spline -in "$TrajectorySpaceFolder"/"$T1wImage".nii.gz -ref "$TrajectorySpaceFolder"/"$T1wImage".nii.gz -applyisoxfm "$DiffusionResolution" -out "$TrajectorySpaceFolder"/"$T1wImage"_"$DiffusionResolution"


    ${FSLDIR}/bin/applywarp --rel --interp=nn -i ${StudyFolder}/${Subject}/T1w/wmparc_1mm.nii.gz -r "$TrajectorySpaceFolder"/"$T1wImage"_"$DiffusionResolution" --warp="$TrajectorySpaceFolder"/xfms/acpc_dc2standard -o "$TrajectorySpaceFolder"/"$wmparc"_"$DiffusionResolution"

     ${FSLDIR}/bin/applywarp --interp=trilinear -i ${StudyFolder}/${Subject}/T1w/brainmask_fs.nii.gz -w "$TrajectorySpaceFolder"/xfms/acpc_dc2standard -r "$TrajectorySpaceFolder"/"$wmparc"_"$DiffusionResolution" -o "$TrajectorySpaceFolder"/brainmask_fs_1.25.nii.gz

Then average the files running makeAverageDataset, see the sample script for example.
Then open workbench and threshold the brainmask_fs to get rid of artifacts.
Run whim template creation procedure aka Whim EM with the following parameters: 
--mask set to the mask you just created. --nf=3 --jac. You should supply your own file tree and top level directory.
Copy the individual of the last iteration into the corresponding individual files
Needs to be named "$TrajectorySpaceFolder"/Diffusion.Whim

Run groupSubCorticalGray.sh
