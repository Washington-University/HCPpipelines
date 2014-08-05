# HCP Pipelines 

The HCP Pipelines product is a set tools (primarily, but not exclusively,
shell scripts) for processing MRI images for the [Human Connectome Project][HCP]. 
Among other things, these tools implement the Minimal Preprocessing Pipeline 
(MPP) described in [Glasser et al. 2013][GlasserEtAl]

<a id="prerequisites">
## Prerequisites
</a>

The HCP Pipelines Tools have the following software requirements:

1. A 64-bit Linux Operating System

2. The [FMRIB Software Library][FSL] (a.k.a. [FSL][FSL]) version 
   5.0.6 or later installed and configuration file properly sourced

3. [FreeSurfer][FreeSurfer] [version 5.3.0-HCP][FreeSurfer-hcp-version] 

4. The [HCP version of gradunwarp][HCP-gradunwarp] (if gradient nonlinearity correction is to be done.)

### Notes on Gradient Nonlinearity Correction (a.k.a. Gradient Distortion Correction)

   * As is true of the other prerequisite pieces of software, the HCP version of gradunwarp has its own set of 
     prerequisites. See the HCP gradunwarp [README](https://github.com/Washington-University/gradunwarp/blob/master/README.md) 
     file for those prerequisites.  

   * In order to run HCP gradunwarp, you will need a gradient coefficients file to 
     use as an input to the gradient distortion correction process.  Please
     see questions 7 and 8 in the [HCP Pipelines FAQ](https://github.com/Washington-University/Pipelines/blob/master/FAQ.md) 
     for further information about gradient nonlinearity correction and obtaining a
     gradient coefficients file.

   * The HCP Pipelines scripts expect to be able to find the main module of the 
     gradunwarp tool (gradient_unwarp.py) within a directory specified in the 
     <code>PATH</code> environment variable.  

   * A number of the example scripts that serve as templates for running types of 
     pipeline processing, assume that you have placed the gradient coefficients file 
     in the standard configuration directory for your installation of HCP Pipelines.
     This standard configuration directory is usually the global/config subdirectory
     within your HCP Pipelines installation directory.

   * If you are not planning on performing gradient nonlinearity correction, you will not 
     need the HCP gradunwarp software or the gradient coefficients files, but you will need
     to make sure that you run the pipelines with flags set to indicate that you do not want
     gradient nonlinearity correction to be done.

## Installation

1. Install the listed [prerequisites](#prerequisites) first.

   * Ubuntu Installation Notes for FSL

     * Once you have installed FSL, verify that you have a recent enough version of FSL
       by simply running the <code>$ fsl</code> command. The FSL window that shows
       up should identify the version of FSL you are running in its title bar.  

     * Sometimes FSL is installed without the separate documentation package, it is 
       most likely worth the extra effort to install the FSL documentation package.

   * Ubuntu Installation Notes for FreeSurfer

     * For Linux, FreeSurfer is distributed in gzipped tarballs for CentOS 4 and CentOS 6.

     * The instructions [here](http://simnibs.de/installation/installfsandfsl) provide
       guidance for installing FreeSurfer on Ubuntu.  If following the instructions
       there, be sure to download version 5.3.0-HCP of FreeSurfer and not version
       5.1.0 as those instructions indicate.

     * Ubuntu (at least starting with version 12.04 and running through version 14.04 LTS
       is missing a library that is used by some parts of FreeSurfer.  To install
       that library enter <code>$ sudo apt-get install libjpeg62</code>.








*

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


## Still have questions?

Please start out by reviewing the [FAQ][FAQ]




<!-- References -->

[HCP]: http://www.humanconnectome.org
[GlasserEtAl]: http://www.ncbi.nlm.nih.gov/pubmed/23668970
[FSL]: http://fsl.fmrib.ox.ac.uk
[FreeSurfer]: http://freesurfer.net
[FreeSurfer-hcp-version]: ftp://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/5.3.0-HCP/
[FAQ]: https://github.com/Washington-University/Pipelines/blob/master/FAQ.md
[HCP-gradunwarp]: https://github.com/Washington-University/gradunwarp/releases
