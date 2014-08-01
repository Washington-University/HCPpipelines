# HCP Pipelines Frequently Asked Questions

1. [Why were the HCP Pipelines written?](#Q1)
2. [What are CIFTI files and the Grayordinates standard space?](#Q2)


##<a id="Q1">Why were the HCP Pipelines written?</a>

  The HCP pipelines were the result of a concerted effort to
  improve the spatial accuracy of MRI data preprocessing so that the HCP
  Consortium and HCP Users could take full advantage of the high quality HCP
  data. Also, a major goal was improving the accuracy (and thereby validity) of 
  cross-subject and cross-study spatial comparisons, leading to the development
  of the CIFTI standard space, which brings the advantages of surface-based 
  analysis into a whole-brain analysis framework.

##<a id="Q2">What are CIFTI files and the Grayordinates standard space?</a>

  The purpose of CIFTI files are to allow the spatial models of MRI 
  data to better match the anatomical structures of the brain.  The 
  sheet-like cerebral cortex is better modeled as a surface mesh and 
  the globular subcortical nuclei are better modeled as volume parcels.  
  A space containing both cortical surface vertices and subcortical 
  volume voxels is made up of grayordinates. The HCP uses a 2mm standard 
  space made up of 91282 grayordiantes (2mm average spacing between the 
  surface vertices and 2mm voxels).  In addition to allowing for more 
  precise analyses of brain MRI data, the grayordinates space reduces 
  the data storage, computational, and memory requirements of high 
  spatial and temporal resolution data substantially by only storing 
  the minimum data of interest.

