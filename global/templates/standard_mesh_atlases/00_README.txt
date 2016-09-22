This directory contains various files related to resampling surface data, creating cifti files, and other odds and ends.

*** Surface resampling-related data ***

The following are the fs_LR standard spheres:

fsaverage.L_LR.spherical_std.164k_fs_LR.surf.gii
L.sphere.59k_fs_LR.surf.gii
L.sphere.32k_fs_LR.surf.gii
fsaverage.R_LR.spherical_std.164k_fs_LR.surf.gii
R.sphere.59k_fs_LR.surf.gii
R.sphere.32k_fs_LR.surf.gii

Importantly, note that “fs_LR” spheres have correspondence between the vertices of the L and R hemispheres.  Some names start with “fsaverage” for historical reasons (and are kept for compatibility purposes; see http://www.ncbi.nlm.nih.gov/pmc/articles/PMC3432236); they are not the same as the fsaverage spheres discussed in the next section.

The fs_L and fs_R directories each contain two spheres:

1) fsaverage.{L,R}.sphere.164k_fs_{L,R}.surf.gii -- the fsaverage 164k standard sphere (from FreeSurfer) converted to GIFTI format (where “{L,R}” is shorthand for either “L” or “R”).  Note that these particular files are the “true” fsaverage (164k) spheres (and therefore do not have correspondence of the L and R hemisphere vertices).
2) fs_{L,R}-to-fs_LR_fsaverage.{L,R}_LR.spherical_std.164k_fs_{L,R}.surf.gii -- a version of the fsaverage sphere (i.e., (1)) that has been deformed to register to the fs_LR atlas.

The resample_fsaverage directory contains files to allow resampling between fs_LR and fsaverage with minimal preparatory steps.  See FAQ 9 here:

https://wiki.humanconnectome.org/display/PublicData/HCP+Users+FAQ#HCPUsersFAQ-9.HowdoImapdatabetweenFreeSurferandHCP?

The resample_fsaverage directory contains several resolutions of fsaverage atlas spheres (from FreeSurfer, but converted to GIFTI format)
fsaverage_std_sphere.{L,R}.164k_fsavg_{L,R}.surf.gii (identical to the spheres in (1) above)
fsaverage6_std_sphere.{L,R}.41k_fsavg_{L,R}.surf.gii
fsaverage5_std_sphere.{L,R}.10k_fsavg_{L,R}.surf.gii
fsaverage4_std_sphere.{L,R}.3k_fsavg_{L,R}.surf.gii

and fs_LR spheres deformed to register to the fsaverage atlas
fs_LR-deformed_to-fsaverage.{L,R}.sphere.{164,59,32}k_fs_LR.surf.gii

In order to assist with resampling group average data, the resample_fsaverage directory also contains data files consisting of the group average of the vertex areas (“va_avg”) from midthickness surfaces from many HCP subjects (i.e., the various *midthickness_va_avg*.shape.gii files).  These are used with the -area-metrics option of the wb_command -*-resample commands, when appropriate.  (See FAQ mentioned above for some examples).


*** Files for creating CIFTI files in standard grayordinate spaces ***

The "Atlas_ROIs" volume files are the definitions of the subcortical boundaries for the standard grayordinate spaces.  The ".2" version uses 2mm cubic voxels, and is used for the 91k grayordinate space, while the ".1.60" version is 1.6mm cubic, and is used for the 170k grayordinate space.

The "atlasroi" files (i.e., {L,R}.atlasroi.{164,59,32}k_fs_LR.shape.gii) define the cortical area that is considered outside the medial wall for the standard grayordinate spaces.  They are also used for other operations in the pipelines to exclude the medial wall.

*** Other data ***

The colin.cerebral.{L,R}.flat.{164,59,32}k_fs_LR.surf.gii files are fs_LR versions of existing cortical flatmaps from the Colin subject, generated originally in caret5 and used here to specify a standard shape (including cuts) of the fs_LR flatmaps for atlases and individuals.

The {L,R}.refsulc.164k_fs_LR.shape.gii files are the template files for MSMSulc registration to fs_LR.

The Conte69.MyelinMap_BC.164k_fs_LR.dscalar.nii file is used as a template for bias correction of myelin maps.

The Avgwmparc.nii.gz file is the most commonly assigned label at each voxel, from the FreeSurfer volume parcellation of the Conte69 dataset (http://www.ncbi.nlm.nih.gov/pubmed/21832190).

Tim Coalson, Matt Glasser, Mike Harms, David Van Essen (22 September, 2016)

