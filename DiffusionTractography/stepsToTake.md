Before running anything if you want to do group:
Applywarp the relevant files into the correct space. Files absolutely needed: wmparc T1w_restore_1.25.nii.gz, brainmask_fs
Then average the files running makeAverageDataset.
Then open workbench and threshold the brainmask_fs to get rid of artifacts.
Make a labeled volumed version of the same mask.
Run whim template creation procedure. (You only need to run nf=3) Use the mask from the threshold.
Copy the individual of the last iteration into the corresponding individual files
Run groupSubCorticalGray.sh
