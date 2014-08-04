# HCP Pipelines Frequently Asked Questions

1. [Why were the HCP Pipelines generated?](#1-why-were-the-hcp-pipelines-generated)
2. [What are CIFTI files and the Grayordinates standard space?](#2-what-are-cifti-files-and-the-grayordinates-standard-space)
3. [What MRI data do I need to use the HCP Pipelines?](#3-what-mri-data-do-i-need-to-use-the-hcp-pipelines)
4. [Why are field maps required?](#4-why-are-field-maps-required)
5. [What if I dont have a field map in my previously acquired data?](#5-what-if-i-dont-have-a-field-map-in-my-previously-acquired-data)
6. [Why is a 3D T2w or 3D FLAIR required?](#6-why-is-a-3d-t2w-or-3d-flair-required)
7. [Can I use the HCP Pipelines to reprocess the HCP data?](#7-can-i-use-the-hcp-pipelines-to-reprocess-the-hcp-data)
8. [What is gradient nonlinearity correction?](#8-what-is-gradient-nonlinearity-correction)
9. [What if I want to process non-human primate (NHP) data with the HCP Pipelines?](#9-what-if-i-want-to-process-non-human-primate-nhp-data-with-the-hcp-pipelines)
10. [What if I want to process pediatric data using HCP Pipelines?](#10-what-if-i-want-to-process-pediatric-data-using-hcp-pipelines)
11. [What if I want to process 7T data with the HCP Pipelines?](#11-what-if-i-want-to-process-7t-data-with-the-hcp-pipelines)
12. [What is the status of MultiModal Surface Matching (MSM)?](#12-what-is-the-status-of-multimodal-surface-matching-msm)
13. [What is next for the HCP Pipelines?](#13-what-is-next-for-the-hcp-pipelines)
14. [How do I learn more about the HCP Pipelines and cite them?](#14-how-do-i-learn-more-about-the-hcp-pipelines-and-cite-them)
15. [I have a question not listed here about the HCP Pipelines, where do I ask it?](#15-i-have-a-question-not-listed-here-about-the-hcp-pipelines-where-do-i-ask-it)

<a id="1-why-were-the-hcp-pipelines-generated">
## 1. Why were the HCP Pipelines generated?
</a>

The HCP Pipelines reflect a concerted effort to improve the spatial accuracy of MRI 
data preprocessing so that the HCP Consortium and HCP Users can take full advantage
of the high quality HCP data acquired for each of four modalities (structural MRI, 
resting-state fMRI, task-fMRI, and diffusion MRI). Another major goal was to improve
the accuracy (and thereby validity) of cross-subject and cross-study spatial comparisons.
This resulted in the development of the CIFTI Grayordinates standard space, which 
brings the advantages of surface-based cortical analyses into a whole-brain analysis 
framework.  

<a id="2-what-are-cifti-files-and-the-grayordinates-standard-space">
## 2. What are CIFTI files and the Grayordinates standard space?
</a>

An overarching purpose of CIFTI files is to allow spatial models of MRI data to 
better match the anatomical structures of the brain. The sheet-like cerebral cortex
is better modeled as a surface mesh, whereas the globular subcortical nuclei are 
better modeled as volume parcels [Glasser et al., 2013][GlasserEtAl].
(Cerebellar cortex is also a sheet, but unfortunately cannot yet be accurately segmented in 
individual subjects, so it is included as a volume parcel.) A space containing 
both cortical surface vertices and subcortical volume voxels is made up of grayordinates.
The HCP uses a 2mm standard space made up of 91,282 grayordinates (2mm average 
spacing between surface vertices and 2mm isotropic voxels). Besides allowing for
more precise analyses of brain MRI data, the grayordinates space markedly reduces
the data storage, computational, and memory requirements for high spatial and 
temporal resolution data, by only storing the minimum data of interest.  

<a id="3-what-mri-data-do-i-need-to-use-the-hcp-pipelines">
## 3. What MRI data do I need to use the HCP Pipelines?
</a>

* For structural analysis, one needs a high-resolution 3D (<=1mm) T1w image 
  and either a high-resolution 3D (<=1mm) T2w image or a high-resolution 3D 
  (<=1mm) FLAIR image. Higher than 1mm resolution is recommended if possible
  (e.g. <=0.8mm). FatSat is recommended for the T1w image. Scanner-based 
  intensity normalizations (like Siemens PreScan Normalize) must be either 
  on for both T1w and T2w images or off for both. 

* For functional analysis, one needs an fMRI timeseries (if the scans are 
  multi-band, it is highly recommended to save the single-band reference scan) 
  and either a standard gradient echo field map (magnitude and phase difference) 
  or a spin echo field map (two phase encoding direction reversed spin echo 
  volumes with the same geometrical and echo spacing parameters as the fMRI 
  timeseries). High spatial (<=2.5mm) and temporal (TR<=1s) resolution fMRI 
  data is recommended.   

* For diffusion analysis, one needs phase encoding direction reversed diffusion
  data. High spatial (<=1.5mm) and angular (>=120 directions) resolution diffusion
  data is recommended with multiple shells that include a higher bvalue (>=1500).

* Functional and diffusion preprocessing also require the scans needed for 
  structural preprocessing.

* For the Siemens HCP 3T Connectome scanner, we found the 32-channel head coil 
  and higher maximum gradient strength to be very helpful.

<a id="4-why-are-field-maps-required">
## 4. Why are field maps required?
</a>

Because the HCP pipelines aim to improve spatial accuracy and localization,
any distortions present in the images need to be corrected. Accurate 
registration of EPI fMRI or diffusion data to the structural scans requires
correction for geometric distortion in the EPI scans.

<a id="5-what-if-i-dont-have-a-field-map-in-my-previously-acquired-data">
## 5. What if I don't have a field map in my previously acquired data?
</a>

It may be possible to attain much of the distortion correction using a group
average field map (e.g., from a different set of subjects), and this capability 
may become available in a future pipelines release.

<a id="6-why-is-a-3d-t2w-or-3d-flair-required">
## 6. Why is a 3D T2w or 3D FLAIR required?
</a>

These images are used for bias field correction, improvements in 
FreeSurfer-generated pial surfaces, and generation of cortical myelin maps.
If myelin maps are important, a T2w scan is preferred over a FLAIR, whereas
if lesion segmentation is more important, a user may prefer a FLAIR. Myelin 
maps are quite helpful for localizing some cortical areas, even on an 
individual subject basis.  (Glasser & Van Essen, J Neuroscience, 2011; 
Van Essen & Glasser, Neuroimage, 2013).

<a id="7-can-i-use-the-hcp-pipelines-to-reprocess-the-hcp-data">
## 7. Can I use the HCP Pipelines to reprocess the HCP data?
</a>

Yes, if you get the gradient nonlinearity correction coefficients from Siemens.
The gradient unwarping code is available at 
[https://github.com/Washington-University/gradunwarp/releases](https://github.com/Washington-University/gradunwarp/releases). 
The gradient unwarping code used by the HCP Pipelines is an HCP-customized 
version of the gradient unwarping code available at
[https://github.com/ksubramz/gradunwarp](https://github.com/ksubramz/gradunwarp) [(Jovicich et al., 2006)][JovicichEtAl].

The gradient field nonlinearity coefficients for the Connectome Skyra are considered
by Siemens to be proprietary information. To request access to these coefficients, 
please contact your Siemens collaboration manager or email [Dingxin Wang][dingxin-email].

<a id="8-what-is-gradient-nonlinearity-correction">
## 8. What is gradient nonlinearity correction?
</a>

MRI scanners use gradients in the magnetic field to define the space of the image.
These gradients are intended to be linear (i.e. have a constant slope). In practice
this is not attainable, resulting in spatial distortions. The HCP 3T Connectome 
scanner has greater distortions than do more standard scanners because of design 
tradeoffs for this customized scanner. If the HCP pipelines are being used with 
regular commercial scanners, the gradient nonlinearity correction can be ignored 
(turned off), however if one is interested in comparing data across scanners, 
it is probably better to do the correction. For Siemens scanners, the gradient 
coefficents are available on the scanner (<code>C:\MedCom\MriSiteData\GradientCoil\coeff.grad</code>).

<a id="9-what-if-i-want-to-process-non-human-primate-nhp-data-with-the-hcp-pipelines">
## 9. What if I want to process non-human primate (NHP) data with the HCP Pipelines?
</a>

We hope to release the FreeSurferNHP pipeline, along with monkey and chimpanzee 
anatomical templates, in the future.  The image acquisition requirements are the 
same as for humans, except that spatial resolution should be higher, if possible.

<a id="10-what-if-i-want-to-process-pediatric-data-using-hcp-pipelines">
## 10. What if I want to process pediatric data using HCP Pipelines?
</a>

At younger ages, children's heads are different enough from adults' heads to make
the initial alignment stages of the HCP Pipelines less robust when using adult volume 
templates. It may be necessary to make age-specific templates for children under a 
certain age. Once the initial alignments are robustly achieved, the HCP Pipelines 
will perform similarly to adults (assuming typical T1w contrast is present).

<a id="11-what-if-i-want-to-process-7t-data-with-the-hcp-pipelines">
## 11. What if I want to process 7T data with the HCP Pipelines?
</a>

Currently it is necessary to acquire the structural data on a 3T scanner (mainly because
of SAR limitations on 7T scanners, making the T2w or FLAIR scans hard to acquire).
Then fMRI or diffusion data can be acquired on the 7T scanner. Gradient distortion correction
is required if combining 3T and 7T data. Additionally, there may be further pipeline 
modifications directed at combining 3T and 7T data in the same subjects.  

<a id="12-what-is-the-status-of-multimodal-surface-matching-msm">
## 12. What is the status of MultiModal Surface Matching (MSM)?
</a>

The current release of the HCP data uses MSMSulc for surface alignment, but MSM 
has not yet been publicly released. MSMSulc offers improvements over standard 
FreeSurfer-based alignment in that there is substantially less surface distortion 
and slightly better alignment of cortical areas across subjects (Robinson et al., Neuroimage, 2014).
We hope the MSM algorithm will be released soon.

<a id="13-what-is-next-for-the-hcp-pipelines">
## 13. What is next for the HCP Pipelines?
</a>

The HCP Pipelines provide a framework for substantially improved spatial localization
of MRI data, particularly across subjects and studies. That said, further substantial 
improvements are possible though better MSM surface registration based on areal features
rather than just cortical folding patterns (as used by MSMSulc and FreeSurfer). We hope 
to release another MSM-based pipeline for areal-feature-based registration (using myelin 
maps and resting state networks) together with HCP data aligned with this pipeline in 
the future.  
 
<a id="14-how-do-i-learn-more-about-the-hcp-pipelines-and-cite-them">
## 14. How do I learn more about the HCP Pipelines and cite them?
</a>

Glasser MF, Sotiropoulos SN, Wilson JA, Coalson TS, Fischl B, Andersson JL, Xu J, Jbabdi S,
Webster M, Polimeni JR, Van Essen DC, Jenkinson M, WU-Minn HCP Consortium. The minimal
preprocessing pipelines for the Human Connectome Project. <i>Neuroimage</i>. 2013 Oct 15;80:105-24. 
PubMed PMID: [23668970][GlasserEtAl]; PubMed Central PMCID: PMC3720813.

<a id="15-i-have-a-question-not-listed-here-about-the-hcp-pipelines-where-do-i-ask-it">
## 15. I have a question not listed here about the HCP Pipelines, where do I ask it?
</a>

Subscribe to the HCP-Users email list at 
[http://humanconnectome.org/contact/#subscribe](http://humanconnectome.org/contact/#subscribe), 
then send a message to the list at [hcp-users@humanconnectome.org](mailto:hcp-users@humanconnectome.org).

<!-- References -->

[GlasserEtAl]: http://www.ncbi.nlm.nih.gov/pubmed/23668970
[JovicichEtAl]: https://surfer.nmr.mgh.harvard.edu/pub/articles/jovicich_neuroimage_2006.pdf
[dingxin-email]: mailto:dingxin.wang@siemens.com
