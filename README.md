# HCP Pipelines 

The HCP Pipelines product is a set of tools (primarily, but not exclusively,
shell scripts) for processing MRI images for the [Human Connectome Project][HCP]. 
Among other things, these tools implement the Minimal Preprocessing Pipeline 
(MPP) described in [Glasser et al. 2013][GlasserEtAl]

-----

## Table of Contents

* [Release notes](#release-notes)
* [Prerequisities](#prerequisites)
* [Notes on gradient nonlinearity correction](#notes-on-gradient-nonlinearity-correction)
* [Installation](#installation)
* [Getting example data](#getting-example-data)
* [Running the HCP Pipelines on example data](#running-the-hcp-pipelines-on-example-data)
  * [Structural Preprocessing](#structural-preprocessing)
  * [Diffusion Preprocessing](#diffusion-preprocessing)
  * [Functional Preprocessing](#functional-preprocessing)
  * [Task Analysis](#task-analysis)
* [The ICA FIX pipeline](#the-ica-fix-pipeline)
* [A note about resource requirements](#a-note-about-resource-requirements)
* [Hint for detected Out of Memory conditions](#hint-for-detecting-out-of-memory-conditions)
* [I still have questions](#i-still-have-questions)

-----

<a id="release-notes">
## Release notes
</a>

1. The HCP Pipelines scripts are being released in essentially the form that they were 
   successfully used for processing data provided in the [Human Connectome Project][HCP] 
   *500 Subjects Data Release*. That processing was done using 64-bit Red Hat Linux version 5.

2. Some improvements to the documentation have been made since they were used for that release.

3. One known difference between these scripts as they were used for the 
   *500 Subjects Data Release* and their currently released form is the version of the 
   `wb_command` from the [Connectome Workbench][Connectome-Workbench] that is used.

   When these scripts were being used for the *500 Subjects Data Release*, Connectome
   Workbench had not reached its 1.0 release level.  Therefore, we used an earlier
   version of the `wb_command` for processing data for the data release.  Distributing 
   that older version of the `wb_command` binary as part of this product is less than 
   ideal because that embedded binary is platform specific and is not
   part of an official Connectome Workbench release.

   If needed, the Red Hat/CentOS specific version of the `wb_command` binary and it
   associated libraries used are available in older, tagged, pre-release versions of this
   project.

4. We have begun the process of making the scripts more robust, well-documented, and 
   usable in other environments (other versions of operating systems, other queueing 
   systems, other versions of prerequisite tools, etc.) But that process is not complete.
   Therefore, we cannot guarantee that you will not have to make modifications to the 
   scripts for them to be used successfully in your environment.

5. A significant part of the value of the open source model of software development
   is the ability to improve software based on source code level feedback from the 
   community of users. Along those lines, if you find that you do need to make changes
   to the source code to use the tools successfully, we would welcome feedback and 
   improvement suggestions. (If you have to change something in the scripts to make
   them work for you, let us know and we'll evaluate how/if to incorporate those
   changes into the released product.)

   Discussion of HCP Pipeline usage and improvements can be posted to the 
   hcp-users discussion list. Sign up for hcp-users at 
   [http://humanconnectome.org/contact/#subscribe](http://humanconnectome.org/contact/#subscribe)

6. For the HCP 500 Subjects Data Release, FSL version 5.0.6 was used with these 
   scripts. There is a known issue with using FSL 5.0.7 for the Task fMRI Analysis 
   Pipeline. See the [Prerequisites](#prerequisites) section below for further information.

7. Improvements to the internal documentation of these scripts are planned.

8. Validation tests to ensure that your installation is working correctly with at 
   least the sample data are also planned but not yet available.  

-----

<a id="prerequisites">
## Prerequisites
</a>

The HCP Pipelines have the following software requirements:

1. A 64-bit Linux Operating System

2. The [FMRIB Software Library][FSL] (a.k.a. [FSL][FSL]) version 
   5.0.6 installed and configuration file properly sourced.  

   **NB: This version of the HCP Pipelines requires version 5.0.6 of FSL, not version
   5.0.6 or greater. This version of the HCP Pipelines is not fully tested with the
   any version of FSL other than version 5.0.6. Preliminary testing has detected that
   there is a difference in behavior between version 5.0.6 of FSL and version 5.0.7 
   of FSL which, while it is an intentional improvement to FSL, is known to cause 
   the Task Analysis pipeline in particular to fail.**

   There is currently a separate branch in this repository named `fsl-5.0.7-changes`.
   That branch is not yet included in a released version of the code, but it contains 
   changes to the Task Analysis pipeline that we expect will fix that pipeline 
   so that it works with version 5.0.7 of FSL. These changes are not fully tested, 
   but they are available to anyone who wants to run the Task Analysis pipeline
   and use FSL 5.0.7.

3. [FreeSurfer][FreeSurfer] version 5.3.0-HCP available at 
   [ftp://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/5.3.0-HCP](ftp://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/5.3.0-HCP)

   **NB: You *must* create and install a license file for FreeSurfer by
   visiting and submitting the 
   [FreeSurfer registration form](https://surfer.nmr.mgh.harvard.edu/registration.html).**

   **NB: The version of FreeSurfer used is a special release of FreeSurfer which is not 
   part of the normal release cycle.  The 5.3.0-HCP version of FreeSurfer contains a 
   slightly different version of the `mris_make_surfaces` program than is part
   of the standard FreeSurfer 5.3.0 release.**

4. [Connectome Workbench][Connectome-Workbench] version 1.0

   The HCP Pipelines scripts use the `wb_command` which is part of the Connectome Workbench.
   They locate the `wb_command` using an environment variable. Instructions for setting
   this environment variable are provided below in the 
   [Running the HCP Pipelines on example data](#running-the-hcp-pipelines-on-example-data) section.

5. The [HCP version of gradunwarp][HCP-gradunwarp] version 1.0.2 (if gradient nonlinearity correction is to be done.)

-----

<a id="notes-on-gradient-nonlinearity-correction">
## Notes on gradient nonlinearity correction
</a>

1. Gradient Nonlinearity Correct is sometimes also referred to as Gradient Distortion Correction
   or GDC

2. As is true of the other prerequisite pieces of software, the HCP version of 
   gradunwarp has its own set of prerequisites. See the HCP gradunwarp 
   [README](https://github.com/Washington-University/gradunwarp/blob/master/README.md) 
   file for those prerequisites.  

3. In order to run HCP gradunwarp, you will need a gradient coefficients file to 
   use as an input to the gradient distortion correction process.  Please
   see questions 7 and 8 in the 
   [HCP Pipelines FAQ](https://github.com/Washington-University/Pipelines/blob/master/FAQ.md) 
   for further information about gradient nonlinearity correction and obtaining a
   gradient coefficients file.

4. The HCP Pipelines scripts expect to be able to find the main module of the 
   gradunwarp tool (gradient_unwarp.py) within a directory specified in the 
   `PATH` environment variable.  

5. As distributed, the examples scripts that serve as templates for running
   various types of pipeline processing are set to *not* run gradient 
   distortion correction.  Commented out portions of those scripts illustrate
   how to change the variable settings to perform gradient distortion correction.
   These commented out portions assume that you have placed the gradient 
   coefficients file in the standard configuration directory for your
   installation of HCP Pipelines (the `global/config` directory within 
   your HCP Pipelines installation directory.

-----

<a id="installation">
## Installation
</a>

1. Install the listed [prerequisites](#prerequisites) first.

   * Installation Notes for FSL

     * Once you have installed FSL, verify that you have the correct version of FSL
       by simply running the `$ fsl` command. The FSL window that shows
       up should identify the version of FSL you are running in its title bar.  

     * Sometimes FSL is installed without the separate documentation package, it is 
       most likely worth the extra effort to install the FSL documentation package.

   * Ubuntu Installation Notes for FreeSurfer

     * For Linux, FreeSurfer is distributed in gzipped tarballs for CentOS 4 and CentOS 6.

     * The instructions [here](http://simnibs.de/installation/installfsandfsl) provide
       guidance for installing FreeSurfer on Ubuntu.  If following the instructions
       there, be sure to download version 5.3.0-HCP of FreeSurfer and not version
       5.1.0 as those instructions indicate.

     * Ubuntu (at least starting with version 12.04 and running through version 14.04 LTS)
       is missing a library that is used by some parts of FreeSurfer.  To install
       that library enter `$ sudo apt-get install libjpeg62`.

2. Download the necessary compressed tar file (.tar.gz) for the 
   [HCP Pipelines release][HCP-pipelines-release].

3. Move the compressed tar file that you download to the directory in which you want
   the HCP Pipelines to be installed, e.g.
   
        $ mv Pipelines-3.4.0.tar.gz ~/projects

4. Extract the files from the compressed tar file, e.g.

        $ cd ~/projects
        $ tar xvf Pipelines-3.4.0.tar.gz

5. This will create a directory containing the HCP Pipelines, e.g.

        $ cd ~/projects/Pipelines-3.4.0
        $ ls -F
        DiffusionPreprocessing/  fMRIVolume/      PostFreeSurfer/  TaskfMRIAnalysis/
        Examples/                FreeSurfer/      PreFreeSurfer/   tfMRI/
        FAQ.md                   global/          product.txt      VersionHistory.md*
        fMRISurface/             LICENSE.md*      README.md        version.txt
        $

6. This newly created directory is your *HCP Pipelines Directory*.  

   In this documentation, in documentation within the script files themselves,
   and elsewhere, we will use the terminology *HCP Pipelines Directory* 
   interchangably with `HCPPIPEDIR`, `$HCPPIPEDIR`, or `${HCPPIPEDIR}`.

   More specifically, `$HCPPIPEDIR` and `${HCPPIPEDIR}` refer to an environment 
   variable that will be set to contain the path to your *HCP Pipelines Directory*.

-----

<a id="getting-example-data">
## Getting example data
</a>

Example data for becoming familiar with the process of running the HCP Pipelines
and testing your installation is available from the Human Connectome Project.

If you already have (or will be obtaining) the gradient coefficients file
for the Connectome Skyra scanner used to collect the sample data and want 
to run the pipelines including the steps which perform gradient distortion 
correction, you can download a zip file containing example data 
[here](https://db.humanconnectome.org/app/action/ChooseDownloadResources?project=HCP_Resources&resource=SampleData&filePath=HcpPipelinesExampleDataNonGDC.zip).

In that case, you will need to place the obtained gradient coefficients 
file (`coeff_SC72C_Skyra.grad`) in the `global/config` directory within 
your HCP Pipelines Directory.

If you do not have and are not planning to obtain the gradient coefficients 
file for the Connectome Skyra scanner used to collect the sample data and 
want to run the pipelines on files on which gradient distortion correction
has already been performed, you should should download a zip file containing 
example data [here](https://db.humanconnectome.org/app/action/ChooseDownloadResources?project=HCP_Resources&resource=SampleData&filePath=HcpPipelinesExampleDataGDC.zip).

The remainder of these instructions assume you have extracted the example data
into the directory `~/projects/Pipelines_ExampleData`.  You will need to 
modify the instructions accordingly if you have extracted the example data
elsewhere.

-----

<a id="running-the-hcp-pipelines-on-example-data">
## Running the HCP Pipelines on example data
</a>

<a id="structural-preprocessing">
### Structural preprocessing
</a>

Structural preprocessing is subdivided into 3 parts (Pre-FreeSurfer processing, 
FreeSurfer processing, and Post-FreeSurfer processing).  These 3 steps should
be excuted in the order specified, and each of these 3 parts is implemented
as a separate `bash` script.

#### Pre-FreeSurfer processing

In the `${HCPPIPEDIR}/Examples/Scripts` directory, you will find 
a shell script for running a batch of subject data through the 
Pre-FreeSurfer part of structural preprocessing. This shell script is 
named: `PreFreeSurferPipelineBatch.sh`. You should review and possibly 
edit that script file to run the example data through the 
Pre-FreeSurfer processing.

*StudyFolder*

The setting of the `StudyFolder` variable near the top of this script
should be verified or edited.  This variable should contain the path to a 
directory that will contain data for all subjects in subdirectories named 
for each of the subject IDs.

As distributed, this variable is set with the assumption that you have
extracted the sample data into a directory named `projects/Pipelines_ExampleData`
within your login or "home" directory.

       StudyFolder="${HOME}/projects/Pipelines_ExampleData"

You should either verify that your example data is extracted to that
location or modify the variable setting accordingly.

*Subjlist*

The setting of the `Subjlist` variable, which comes immediately
after the setting of the `StudyFolder` variable, should also be 
verified or edited.  This variable should contain a space delimited 
list of the subject IDs for which you want the Pre-FreeSurfer processing
to run.  

As distributed, this variable is set with the assumption that you will
run the processing only for the single example subject, which has a
subject ID of `100307`.  

       Subjlist="100307"

Using this value in conjunction with the value of the `StudyFolder` variable,
the script will look for a directory named `100307` within the directory 
`${HOME}/projects/Pipelines_ExampleData`.  This is where it will expect to 
find the data it is to process.

You should either verify that your example data is in that location
or modify the variable setting accordingly.

*EnvironmentScript*

The `EnvironmentScript` variable should contain the path to a 
script that sets up the environment variables that are necessary 
for running the Pipeline scripts.  

As distributed, this variable is set with the assumption that you
have installed the HCP Pipelines in the directory 
`${HOME}/projects/Pipelines` (i.e. that your HCP Pipelines directory
is `${HOME}/projects/Pipelines`) and that you will use the 
example environment setup provided in the 
`Examples/Scripts/SetUpHCPPipeline.sh` script.

You may need to update the setting of the `EnvironmentScript` 
variable to reflect where you have installed the HCP Pipelines.

*GradientDistortionCoeffs*

Further down in the script, the `GradientDistortionCoeffs` variable
is set.  This variable should be set to contain either the path to 
the gradient coefficients file to be used for gradient distortion 
correction or the value `NONE` to skip over the gradient distortion
correction step.

As distributed, the script sets the variable to skip the gradient 
distortion correction step. 

You will need to update the setting of this variable if you have
a gradient coefficients file to use and want to perform the
gradient distortion correction

*`HCPPIPEDIR` and the `SetUpHCPPipeline.sh` script*

The script file referenced by the `EnvironmentScript` variable 
in the `PreFreeSurferPipelineBatch.sh` file (by default the 
`SetUpHCPPipeline.sh` file in the Examples\Scripts folder)
does nothing but establish values for all the environment
variables that will be needed by various pipeline scripts.

Many of the environment variables set in the `SetUpHCPPipeline.sh`
script are set relative to the `HCPPIPEDIR` environment variable.

As distributed, the setting of the `HCPPIPEDIR` environment 
variable assumes that you have installed the HCP Pipelines
in the `${HOME}/projects/Pipelines` directory.  You may 
need to change this to reflect your actual installation
directory.  

As distributed, the `SetUpHCPPipeline.sh` script assumes 
that you have: 

* properly installed FSL
* set the FSLDIR environment variable
* sourced the FSL configuration script
* properly installed FreeSurfer
* set the FREESURFER_HOME environment variable
* sourced the FreeSurfer setup script

Example statements for setting FSLDIR, sourcing the 
FSL configuration script, setting FREESURFER_HOME,
and sourcing the FreeSurfer setup script are provided
but commented out in the `SetUpHCPPipeline.sh` script
prior to setting `HCPPIPEDIR`.

*`CARET7DIR` in the `SetUpHCPPipeline.sh` script*

The `CARET7DIR` variable must provide the path to the directory 
in which to find the Connectome Workbench `wb_command`.  As 
distributed, the `CARET7DIR` is set with the assumption that 
the necessary `wb_command` binary is installed in the 
`${HOME}/workbench/bin_linux64` directory.

It is very likely that you will need to change the value of the 
`CARET7DIR` environment variable to indicate the location of your 
installed version of the `wb_command`.

*Running the Pre-FreeSurfer processing after editing the setup script*

Once you have made any necessary edits as described above,
Pre-FreeSurfer processing can be invoked by commands
similar to:

        $ cd ~/projects/Pipelines/Examples/Scripts
        $ ./PreFreeSurferPipelineBatch.sh
        This script must be SOURCED to correctly setup the environment 
        prior to running any of the other HCP scripts contained here

        100307
        Found 1 T1w Images for subject 100307
        Found 1 T2w Images for subject 100307
        About to use fsl_sub to queue or run /home/user/projects/Pipelines/PreFreeSurfer/PreFreeSurferPipeline.sh

After reporting the number of T1w and T2w images found, the 
`PreFreeSurferPipelineBatch.sh` script uses the FSL command `fsl_sub` 
to submit a processing job which ultimately runs the `PreFreeSurferPipeline.sh` 
pipeline script.

If your system is configured to run jobs via an Oracle Grid Engine cluster 
(previously known as a Sun Grid Engine (SGE) cluster), then `fsl_sub` will 
submit a job to run the `PreFreeSurferPipeline.sh` script on the
cluster and then return you to your system prompt.  You can check on the
status of your running cluster job using the `qstat` command. See the
documentation of the `qstat` command for further information.  

The standard output (stdout) and standard error (stderr) for the job
submitted to the cluster will be redirected to files in the directory
from which you invoked the batch script. Those files will be named
`PreFreeSurferPipeline.sh.o<job-id>` and 
`PreFreeSurferPipeline.sh.e<job-id>` respectively, where
`<job-id>` is the cluster job ID. You can monitor the progress
of the processing with a command like:

        $ tail -f PreFreeSurferPipeline.sh.o1434030

where 1434030 is the cluster job ID.

If your system is not configured to run jobs via an Oracle Grid Engine
cluster, `fsl_sub` will run the `PreFreeSurferPipeline.sh` script
directly on the system from which you launched the batch script.
Your invocation of the batch script will appear to reach a point
at which "nothing is happening."  However, the `PreFreeSurferPipeline.sh`
script will be launched in a separate process and the 
standard output (stdout) and standard error (stderr) will have
been redirected to files in the directory from which you invoked
the batch script.  The files will be named 
`PreFreeSurferPipeline.sh.o<process-id>` and 
`PreFreeSurferPipeline.sh.e<process-id>' respectively, where
`<process-id>` is the operating system assigned unique process
ID for the running process.

A similar `tail` command to the one above will allow you to monitor
the progress of the processing.

Keep in mind that depending upon your processor speed and whether or not 
you are performing gradient distortion correction, the Pre-FreeSurfer
phase of processing can take several hours.

#### FreeSurfer processing

In the `${HCPPIPEDIR}/Examples/Scripts` directory, you will find
a shell script for running a batch of subject data through the 
FreeSurfer part of structural preprocessing. This shell script is
named: `FreeSurferPipelineBatch.sh`. You should review and possibly
edit that script file to run the example data through the 
FreeSurfer processing.

The `StudyFolder`, `Subjlist`, and `EnvironmentScript` variables
are set near the top of the script and should be verified and edited
as indicated above in the discussion of Pre-FreeSurfer processing.

Your environment script (`SetUpHCPPipeline.sh`) will need to have
the same environment variables set as for the Pre-FreeSurfer 
processing.

Once you have made any necessary edits as described above
and the Pre-FreeSurfer processing has completed, then invoking 
FreeSurfer processing is quite similar to invoking Pre-FreeSurfer 
processing.  The command will be similar to:

        $ cd ~/projects/Pipelines/Examples/Scripts
	$ ./FreeSurferPipelineBatch.sh
        This script must be SOURCED to correctly setup the environment 
        prior to running any of the other HCP scripts contained here

	100307
	About to use fsl_sub to queue or run /home/user/projects/Pipelines/FreeSurfer/FreeSurferPipeline.sh

As above, the `fsl_sub` command will either start a new process on the current 
system or submit a job to an Oracle Grid Engine cluster.  Also as above, you can 
monitor the progress by viewing the generated standard output and standard error 
files.

#### Post-FreeSurfer processing

In the `${HCPPIPEDIR}/Examples/Scripts` directory, you will find
a shell script for running a batch of subject data through the 
Post-FreeSurfer part of structural preprocessing. This shell script
is named: `PostFreeSurferPipelineBatch.sh`. This script follows
the same pattern as the batch scripts to run Pre-FreeSurfer and
FreeSurfer processing do.  That is, you will need to verify/edit
the `StudyFolder`, `Subjlist`, and `EnvironmentScript` variables
that are set at the top of the script, and your environment 
script (`SetUpHCPPipeline.sh`) will need to set environment variables
appropriately.

There is an additional variable in the `PostFreeSurferPipelineBatch.sh`
script that needs to be considered.  The `RegName` variable tells
the pipeline whether to use MSMSulc for surface alignment.  (See
the [FAQ][FAQ] for further information about MSMSulc.) As distributed,
the `PostFreeSurferPipelineBatch.sh` script assumes that you do *not*
have access to the `msm` binary to use for surface alignment. Therefore,
the `RegName` variable is set to `"FS"`.  

If you *do* have access to the `msm` binary and wish to use it, you 
can change this variable's value to `"MSMSulc"`.  If you do so, then 
your environment script (e.g. `SetUpHCPPipeline.sh`) will need to set 
an additional environment variable which is used by the pipeline 
scripts to locate the `msm` binary.  That environment variable is
`MSMBin` and it is set in the distributed example `SetUpHCPPipeline.sh` 
file as follows:

        export MSMBin=${HCPPIPEDIR}/MSMBinaries

You will need to either place your `msm` executable binary file 
in the `${HCPPIPEDIR}/MSMBinaries` directory or modify the
value given to the `MSMBin` environment variable so that it
contains the path to the directory in which you have placed
your copy of the `msm` executable.

Once those things are taken care of and FreeSurfer processing 
is completed, commands like the following can be issued:

        $ cd ~/projects/Pipelines/Examples/Scripts
        $ ./PostFreeSurferPipelineBatch.sh
	This script must be SOURCED to correctly setup the environment
	prior to running any of the other HCP scripts contained here

	100307
	About to use fsl_sub to queue or run /home/user/projects/Pipelines/PostFreeSurfer/PostFreeSurferPipeline.sh

The `fsl_sub` command used in the batch script will behave as described 
above and monitoring the progress of the run can be done as described
above.

<a id="diffusion-preprocessing">
### Diffusion Preprocessing
</a>

Diffusion Preprocessing depends on the outputs generated by Structural 
Preprocessing. So Diffusion Preprocessing should not be attempted on
data sets for which Structural Preprocessing is not yet complete.

The `DiffusionPreprocessingBatch.sh` script in the `${HCPPIPEDIR}/Examples/Scripts`
directory is much like the example scripts for the 3 phases of Structural 
Preprocessing.  The `StudyFolder`, `Subjlist`, and `EnvironmentScript` variables
set at the top of the batch script need to be verified or edited as above.

Like the `PreFreeSurferPipelineBatch.sh` script, the `DiffusionPreprocessingBatch.sh`
also needs a variable set to the path to the gradient coefficients file or `NONE`
if gradient distortion correction is to be skipped. In the `DiffusionPreprocessingBatch.sh` 
script that variable is `Gdcoeffs`. As distributed, this example script is setup
with the assumption that you will skip gradient distortion correction.  If you have
a gradient coefficients file available and would like to perform gradient distortion
corrrection, you will need to update the `Gdcoeffs` variable to contain the path
to your gradient coefficients file.

<a id="functional-preprocessing">
### Functional Preprocessing
</a>

Functional Preprocessing depends on the outputs generated by Structural
Preprocessing. So Functional Preprocessing should not be attempted on 
data sets for which Structural Preprocessing is not yet complete.

Functional Preprocessing is divided into 2 parts: Generic fMRI Volume 
Preprocessing and Generic fMRI Surface Preprocessing.  Generic fMRI
Surface Preprocessing depends upon output produced by the Generic
fMRI Volume Preprocessing.  So fMRI Surface Preprocessing should not 
be attempted on data sets for which fMRI Volume Preprocessing is 
not yet complete.

As is true of the other types of preprocessing discussed above, there
are example scripts for running each of the two types of Functional 
Preprocessing.

#### Generic fMRI Volume Preprocessing

The `GenericfMRIVolumeProcessingPipelineBatch.sh` script is the starting
point for running volumetric functional preprocessing.  Like the sample
scripts mentioned above, you will need to verify or edit the `StudyFolder`,
`Subjlist`, and `EnvironmentScript` variables defined near the top of the
batch processing script.  Additionally, you will need to verify or 
edit the `GradientDistortionCoeffs` variable. As distributed, this
value is set to "NONE" to skip gradient distortion correction.

In addition to these variable modifications, you should check or edit
the contents of the `Tasklist` variable.  This variable holds a space
delimited list of the functional tasks that you would like preprocessed.
As distributed, the `Tasklist` variable is set to only process the 2
HCP EMOTION tasks (`tfMRI_EMOTION_RL` and `tfMRI_EMOTION_LR`).  You 
can add other tasks (e.g. `tfMRI_WM_RL`, `tfMRI_WM_LR`, `tfMRI_SOCIAL_RL`,
`tfMRI_SOCIAL_RL`, etc.) to the list in the `Tasklist` variable to get
volume preprocessing to occur on those tasks as well.  The Resting
State "tasks" can also be preprocessed this way too by adding the
specification of those tasks (e.g. `rfMRI_REST1_RL`, `rfMRI_REST1_LR`, 
`rfMRI_REST2_RL`, or `rfMRI_REST2_LR`) to the `Tasklist` variable.

#### Generic fMRI Surface Preprocessing

The `GenericfMRISurfaceProcessingPipelineBatch.sh` script is the starting
point for running surface based functional preprocessing.  As has been
the case with the other sample scripts, you will need to verify or edit 
the `StudyFolder`, `Subjlist`, and `EnvironmentScript` variables defined 
near the top of the batch processing script.

In addition to these variable modifications, you should check or edit
the contents of the `Tasklist` variable.  This variable holds a space
delimited list of the functional tasks that you would like preprocessed.
As distributed, the `Tasklist` variable is set to only process the 2
HCP EMOTION tasks (`tfMRI_EMOTION_RL` and `tfMRI_EMOTION_LR`).  As 
above in the volume based functional preprocessing, you can add other 
tasks to the list in the `Tasklist` variable including other 
actual tasks or the Resting State "tasks".

Like the Post-FreeSurfer pipeline, you will also need to set
the `RegName` variable to either `MSMSulc` or `FS`.  

<a id="task-analysis">
### Task Analysis
</a>

Task fMRI (tfMRI) data can be further processed (after Functional
Preprocessing is complete) using the `TaskfMRIAnalysisBatch.sh` 
script.  The `TaskfMRIAnalysisBatch.sh` script runs Level 1 and 
Level 2 Task fMRI Analysis.  As has been the case with the other 
sample scripts, you will need to verify or edit the `StudyFolder`, 
`Subjlist`, and `EnvironmentScript` variables defined at the top 
of this batch processing script.

In addition to these variable modifications, you should check or edit
the contents of the `LevelOneTasksList`, `LevelOneFSFsList`, `LevelTwoTaskList`,
and `LevelTwoFSFList` variables.  As distributed, these variables are 
configured to perform Level 1 task analysis only on the RL and LR conditions
for the EMOTION task and Level 2 task analysis on the combined results of 
the RL and LR Level 1 analysis for the EMOTION task.  You can add other
conditions for Level 1 and Level 2 analysis by altering the settings of
these variables.  Please be aware that changing these settings will 
alter the types of analysis that are done for *all* subjects listed
in the `Sublist` variable.

#### Preparing to do Level 1 Task Analysis 

Level 1 Task Analysis requires FEAT setup files (FSF files) for each 
direction of the functional task.  

For example, to perform Level 1 Task Analysis for the `tfMRI_EMOTION_RL` 
and `tfMRI_EMOTION_LR` tasks for subject `100307`, the following FEAT setup 
files must exist before running the Task Analysis pipeline:

* `<StudyFolder>/100307/MNINonLinear/Results/tfMRI_EMOTION_LR/tfMRI_EMOTION_LR_hp200_s4_level1.fsf`
* `<StudyFolder>/100307/MNINonLinear/Results/tfMRI_EMOTION_RL/tfMRI_EMOTION_RL_hp200_s4_level1.fsf`

Templates for these files can be found in the `${HCPPIPEDIR}/Examples/fsf_templates` 
directory.  The *number of time points* entry in the template for each
functional task must match the actual number of time points in the corresponding scan.

An entry in the `tfMRI_EMOTION_LR_hp200_s4_level1.fsf` file might look like:

        # Total volumes
        set fmri(npts) 176

The `176` value must match the number of volumes (number of time points) in the 
corresponding `tfMRI_EMOTION_LR.nii.gz` scan file.  After you have copied the appropriate 
template for a scan to the indicated location in the `MNINonLinear/Results/<task>` directory, 
you *may* have to edit the .fsf file to make sure the value that it has for `Total volumes` 
matches the number of time points in the corresponding scan file.

There is a script in the `${HCPPIPEDIR}/Examples/Scripts` directory named `generate_level1_fsf.sh` 
which can be either studied or used directly to retrieve the number of time points from an image
file and set the correct `Total volumes` value in the .fsf file for a specified task.  

Typical invocations of the `generate_level1_fsf.sh` script would look like:

        $ cd ${HCPPIPEDIR}/Examples/Scripts

        $ ./generate_level1_fsf.sh \
        >   --studyfolder=${HOME}/projects/Pipelines_ExampleData \
        >   --subject=100307 --taskname=tfMRI_EMOTION_RL --templatedir=../fsf_templates \
        >   --outdir=${HOME}/projects/Pipelines_ExampleData/100307/MNINonLinear/Results/tfMRI_EMOTION_RL

        $ ./generate_level1_fsf.sh \
        >   --studyfolder=${HOME}/projects/Pipelines_ExampleData \
        >   --subject=100307 --taskname=tfMRI_EMOTION_LR --templatedir=../fsf_templates \
        >   --outdir=${HOME}/projects/Pipelines_ExampleData/100307/MNINonLinear/Results/tfMRI_EMOTION_LR

This must be done for every direction of every task for which you want to perform task analysis.

Level 1 Task Analysis also requires that E-Prime EV files be available in the 
`MNINonLinear/Results` subdirectory for the each task on which Level 1 Task Analysis is to occur.
These EV files are available in the example unprocessed data, but are not in the 
`MNINonLinear/Results` directory because that directory is created as part of Functional 
Preprocessing. Since Functional Preprocessing must be completed before Task Analysis
can be performed, the `MNINonLinear/Results` folder should exist prior to Task Analysis.

There is a script in the `${HCPPIPEDIR}/Examples/Scripts` directory named `copy_evs_into_results.sh`.
This script can be used to copy the necessary E-Prime EV files for a task into the
appropriate place in the `MNINonLinear/Results` directory.

Typical invocations of the `copy_evs_into_results.sh` script would look like:

        $ cd ${HCPPIPEDIR}/Examples/Scripts

        $ ./copy_evs_into_results.sh \
        >   --studyfolder=${HOME}/projects/Pipelines_ExampleData \
        >   --subject=100307 \
        >   --taskname=tfMRI_EMOTION_RL

        $ ./copy_evs_into_results.sh \
        >   --studyfolder=${HOME}/projects/Pipelines_ExampleData \
        >   --subject=100307 \
        >   --taskname=tfMRI_EMOTION_LR

This must be done for every directory of every task for which you want to perform task analysis.

#### Preparing to do Level 2 Task Analysis 

Level 2 Task Analysis requires a FEAT setup file also. For example, to perform 
Level 2 Task Analysis for the `tfMRI_EMOTION` task for subject `100307` (combination 
data from `tfMRI_EMOTION_RL` and `tfMRI_EMOTION_LR`) the following FEAT setup file
must exist before running the Task Analysis pipeline:

* `<StudyFolder>/100307/MNINonLinear/Results/tfMRI_EMOTION/tfMRI_EMOTION_hp200_s4_level2.fsf`

The template file named `tfMRI_EMOTION_hp200_s4_level2.fsf` in the 
`${HCPPIPEDIR}/Examples/fsf_templates` directory can be copied, unchanged 
to the appropriate location before running the Task Analysis pipeline.  You will likely 
have to create the level 2 results directory, e.g. `<StudyFolder>/100307/MNINonLinear/Results/tfMRI_EMOTION`
(Notice that this directory name does not end with `_LR` or `_RL`) before you can copy the template 
into that directory.

-----

<a id="the-ica-fix-pipeline">
## The ICA FIX pipeline
</a>

Resting state fMRI (rfMRI) data can be further processed (after 
Functional Preprocessing is complete) using the FMRIB group's 
ICA-based Xnoiseifer - FIX ([ICA FIX](http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FIX)).
This processing regressess out motion timeseries and artifact ICA components (ICA
run using Melodic and components classified using FIX): ([Salimi-Khorshidi et al 2014](http://www.ncbi.nlm.nih.gov/pubmed/24389422))

The [downloadable FIX tar file](http://www.fmrib.ox.ac.uk/~steve/ftp/fix.tar.gz) 
includes the `hcp_fix` file which is a wrapper script for running 
ICA FIX on data that has been run through the HCP Structural and Functional 
Preprocessing.  The hcp_fix script is run with a high-pass filter of 2000.  

-----

<a id="a-note-about-resource-requirements">
## A note about resource requirements
</a>

The memory and processing time requirements for running the HCP Pipelines scripts is 
relatively high. To provide an reference point, when the HCP runs these scripts to 
process data by submitting them to a cluster managed by a Portable Batch System (PBS) 
job scheduler, we generally request the following resource limits.

* Structural Preprocessing (Pre-Freesurfer, FreeSurfer, and Post-FreeSurfer combined) 
  * Walltime
    * Structural Preprocessing usually finishes within 24 hours
    * We set the walltime limit to 24-48 hours and infrequently have to adjust it up to 96 hours
  * Memory
    * We expect Structural Preprocessing to have maximum memory requirements in the range of
      12 GB. But infrequently we have to adjust the memory limit up to 24 GB.

* Functional Preprocessing (Volume and Surface based preprocessing combined)
  * Time and memory requirements vary depending on the length of the fMRI scanning session
  * In our protocol, resting state functional scans (rfMRI) are longer duration than task 
    functional scans (tfMRI) and therefore have higher time and memory requirements.
  * Jobs processing resting state functional MRI (rfMRI) scans usually have walltime 
    limits in the range of 36-48 hrs and memory limits in the 20-24 GB range.
  * Jobs processing task functional MRI (tfMRI) scans may have resource limits that vary
    based on the task's duration, but generally are walltime limited to 24 hours and 
    memory limited to 12 GB.  
  * Often tfMRI preprocessing takes in the neighborhood of 4 hours and 
    rfMRI preprocessing takes in the neighborhood of 10 hours.

* Diffusion Preprocessing 
  * Time and memory requirements for Diffusion preprocessing will depend upon
    whether you are running the `eddy` portion of Diffusion preprocessing using
    the Graphics Processing Unit (GPU) enabled version of the `eddy` binary 
    that is part of FSL. (The FMRIB group at Oxford University recommends using
    the GPU-enabled version of `eddy` whenever possible.)
  * Memory requirements for Diffusion preprocessing are generally in the 24-50 GB
    range.
  * Walltime requirements can be as high as 36 hours.

* Task fMRI Analysis
  * Walltime limits on Task fMRI Analysis are generally set to 24 hours with 
    the actual expected walltimes to run from 4-12 hours per task.
  * Memory limits are set at 12 GB.

The limits listed above, in particular the walltime limits listed, are only 
useful if you have some idea of the capabilities of the computer node on 
which the jobs were run. For information about the configuration of the 
cluster nodes used to come up with the above limits/requirements, see the 
description of the equipment available at the Washington University 
Center for High Performance Computing ([CHPC](http://chpc.wustl.edu)) 
[hardware resources](http://chpc.wustl.edu/hardware.html).

-----

<a id="hint-for-detecting-out-of-memory-conditions">
## Hint for detecting Out of Memory conditions
</a>

If one of your preprocessing jobs ends in a seemingly inexplicable way with a message 
in the stderr file (e.g. `DiffPreprocPipeline.sh.e<process-id>`) that indicates that
your process was `Killed`, it is worth noting that many versions of Linux have a process
referred to as the *Out of Memory Killer* or *OOM Killer*.  When a system running an 
OOM Killer gets critically low on memory, the OOM Killer starts killing processes by 
sending them a `-9` signal.  This type of process killing immediately stops the process
from running, frees up any memory that process is using, and causes the return value 
from the killed process to be `137`.  (By convention, this return value is 128 plus 
the signal number, which is 9. Thus a return value of 128+9=137.)

For example, if the `eddy` executable used in Diffusion preprocessing attempts to 
allocate more memory than is available, it may be killed by the OOM Killer and return 
a status code of 137. In that case, there may be a line in the stderr that looks
similar to:

        /home/username/projects/Pipelines/DiffusionPreprocessing/scripts/run_eddy.sh: line 182: 39455 Killed  ...*further info here*...

and a line in the stdout that looks similar to:

        Sat Aug 9 21:20:21 CDT 2014 - run_eddy.sh - Completed with return value: 137

Lines such as these are a good hint that you are having problems with not having
enough memory. Out of memory conditions and the subsequent killing of jobs
by the OOM Killer can be confirmed by looking in the file where the OOM Killer
logs its activities (`/var/log/kern.log` on Ubuntu systems, `/var/log/messages*` 
on some other systems).  

Searching those log files for the word `Killed` may help find the log message
indicating that your process was killed by the OOM Killer.  Messages within
these log files will often tell you how much memory was allocated by the 
process just before it was killed.

Note that within the HCP Pipeline scripts, not all invocations of binaries or 
other scripts print messages to stderr or stdout indicating their return 
status codes. The above example is from a case in which the return status
code is reported. So while this hint is intended to be helpful, it should
not be assumed that all out of memory conditions can be discovered by 
searching the stdout and stderr files for return status codes of 137.

-----

<a id="i-still-have-questions">
## I still have questions
</a>

Please review the [FAQ][FAQ]. 

-----

<!-- References -->

[HCP]: http://www.humanconnectome.org
[GlasserEtAl]: http://www.ncbi.nlm.nih.gov/pubmed/23668970
[FSL]: http://fsl.fmrib.ox.ac.uk
[FreeSurfer]: http://freesurfer.net
[FreeSurfer-hcp-version]: http://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/5.3.0-HCP/
[FAQ]: https://github.com/Washington-University/Pipelines/blob/master/FAQ.md
[HCP-gradunwarp]: https://github.com/Washington-University/gradunwarp/releases
[HCP-pipelines-release]: https://github.com/Washington-University/Pipelines/releases
[Connectome-Workbench]: http://www.humanconnectome.org/software/connectome-workbench.html