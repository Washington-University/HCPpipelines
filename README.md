# HCP Pipelines 

The HCP Pipelines product is a set tools (primarily, but not exclusively,
shell scripts) for processing MRI images for the [Human Connectome Project][HCP]. 
Among other things, these tools implement the Minimal Preprocessing Pipeline 
(MPP) described in [Glasser et al. 2013][GlasserEtAl]

## Prerequisites

The HCP Pipelines Tools have the following software requirements:

1. A 64-bit Linux Operating System
2. The [FMRIB Software Library][FSL] (a.k.a. [FSL][FSL]) version 
   5.0.6 or greater installed and config properly sourced
3. [FreeSurfer] [FreeSurfer] version [5.3.0-HCP] [5.3.0-HCP] installed and 
   config properly sourced
4. ${HCPPIPEDIR}/src/gradient_unwarping installed with dependancies (source
   code located in this folder) if using gradient distortion correction

## Notes

1. You will need to define an environment variable named `HCPPIPEDIR` which 
   should hold the path to the root folder in which the HCP Pipelines Tools 
   reside.

   For example, you might set HCPPIPEDIR in a manner similar to one of the
   following.
   <pre>
   <code>
       export HCPPIPEDIR=/home/NRG/tbrown01/projects/Pipelines
       export HCPPIPEDIR=/media/2TBB/Connectome_Project/Pipelines
       export HCPPIPEDIR=/nrgpackages/tools/hcp-pipeline-tools
   </code>
   </pre>

2. An example setup script is provided in 
   `${HCPPIPEDIR}/Examples/Scripts/SetUpHCPPipeline.sh`.

   That setup script will need to be edited to set the absolute path to the 
   HCP Pipelines Tools root installation folder on your system.  Your modified
   setup script will need to be sourced before running an HCP pipeline.

3. To test that the pipelines work, there is example data located in:
   `${HCPPIPEDIR}/Examples/792564`

4. There are example batch scripts to call the pipelines on this data 
   located in: `${HCPPIPEDIR}/Examples/Scripts`

5. In all example batch scripts, the following variables will need to be 
   modified or checked prior to use:

   <pre>
   <code>
       Subjlist="792564" #Space delimited list of subject IDs
       StudyFolder="/media/myelin/brainmappers/Connectome_Project/TestStudyFolder" #Path to subject's data folder
       EnvironmentScript="/media/2TBB/Connectome_Project/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script
   </code>
   </pre>

   * `SubjList` needs to be changed to the list of subjects to process
   * `StudyFolder` needs to be changed to the location of the data that 
     will be processed.
   * `EnvironmentScript` needs to be changed to the location of your 
     setup script (your modified version of `SetUpHCPPipeline.sh`

<!-- References -->

[HCP]: http://www.humanconnectome.org
[GlasserEtAl]: http://www.ncbi.nlm.nih.gov/pubmed/23668970
[FSL]: http://fsl.fmrib.ox.ac.uk
[FreeSurfer]: http://freesurfer.net
[5.3.0-HCP]: ftp://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/5.3.0-HCP/