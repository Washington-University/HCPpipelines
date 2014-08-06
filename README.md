# HCP Pipelines 

The HCP Pipelines product is a set tools (primarily, but not exclusively,
shell scripts) for processing MRI images for the [Human Connectome Project][HCP]. 
Among other things, these tools implement the Minimal Preprocessing Pipeline 
(MPP) described in [Glasser et al. 2013][GlasserEtAl]

-----

## Table of Contents

* [Prerequisities](#prerequisites)
* [Notes on gradient nonlinearity correction](#notes-on-gradient-nonlinearity-correction)
* [Installation](#installation)
* [Getting example data](#getting-example-data)
* [Running the HCP Pipelines on example data](#running-pipelines-on-example-data)
* [Still have questions](#still-have-questions)

-----

<a id="prerequisites">
## Prerequisites
</a>

The HCP Pipelines Tools have the following software requirements:

1. A 64-bit Linux Operating System

2. The [FMRIB Software Library][FSL] (a.k.a. [FSL][FSL]) version 
   5.0.6 or later installed and configuration file properly sourced

3. [FreeSurfer][FreeSurfer] [version 5.3.0-HCP][FreeSurfer-hcp-version] 

4. The [HCP version of gradunwarp][HCP-gradunwarp] (if gradient nonlinearity correction is to be done.)

-----

<a id="notes-on-gradient-nonlinearity-correction">
## Notes on gradient nonlinearity correction (a.k.a. gradient distortion correction, a.k.a. GDC)
</a>

1. As is true of the other prerequisite pieces of software, the HCP version of 
   gradunwarp has its own set of prerequisites. See the HCP gradunwarp 
   [README](https://github.com/Washington-University/gradunwarp/blob/master/README.md) 
   file for those prerequisites.  

2. In order to run HCP gradunwarp, you will need a gradient coefficients file to 
   use as an input to the gradient distortion correction process.  Please
   see questions 7 and 8 in the 
   [HCP Pipelines FAQ](https://github.com/Washington-University/Pipelines/blob/master/FAQ.md) 
   for further information about gradient nonlinearity correction and obtaining a
   gradient coefficients file.

3. The HCP Pipelines scripts expect to be able to find the main module of the 
   gradunwarp tool (gradient_unwarp.py) within a directory specified in the 
   <code>PATH</code> environment variable.  

4. A number of the example scripts that serve as templates for running types of 
   pipeline processing, assume that you have placed the gradient coefficients file 
   in the standard configuration directory for your installation of HCP Pipelines.
   This standard configuration directory is usually the global/config subdirectory
   within your HCP Pipelines installation directory.

5. If you are not planning on performing gradient nonlinearity correction, you will 
   not need the HCP gradunwarp software or the gradient coefficients files, but you 
   will need to make sure that you run the pipelines with flags set to indicate that 
   you do not want gradient nonlinearity correction to be done.

-----

<a id="installation">
## Installation
</a>

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

2. Download the necessary compressed tar file (.tar.gz) for the 
   [HCP Pipelines release][HCP-pipelines-release].

3. Move the compressed tar file that you download to the directory in which you want
   the HCP Pipelines to be installed.
   
   <pre>
   <code>
   $ mv Pipelines-3.3.1.tar.gz ~/projects
   </code>
   </pre>

4. Extract the data from the compressed tar file, e.g.

   <pre>
   <code>
   $ cd ~/projects
   $ tar xvf Pipelines-3.3.1.tar.gz
   </code>
   </pre>

5. This will create a directory containing the HCP Pipelines, e.g.

   <pre>
   <code>
   $ cd ~/projects/Pipelines-3.3.1
   $ ls 
   DiffusionPreprocessing/  fMRIVolume/      PreFreeSurfer/     VersionHistory.md*
   DiffusionTractography/   FreeSurfer/      product.txt        version.txt
   Examples/                global/          README.md*
   FAQ.md                   LICENSE.md*      TaskfMRIAnalysis/
   fMRISurface/             PostFreeSurfer/  tfMRI/
   $
   </code>
   </pre>

6. This newly created directory is your *HCP Pipelines Directory*.  Add a 
   statement to your login configuration files setting the `HCPPIPEDIR` 
   environment variable to contain the path to your *HCP Pipelines Directory*, e.g.

   <pre>
   <code>
   $ cd
   $ cp .bash_profile .bash_profile.before_hcp_pipelines_install
   $ echo "export HCPPIPEDIR=$HOME/projects/Pipelines-3.3.1" >> ~/.bash_profile
   </code>
   </pre>

   **NB:** There are two greater than signs (`>>`) before the `~/.bash_profile`.
   This causes a new statement creating the `HCPPIPEDIR` environment variable
   to be added to the end of your `.bash_profile` file.  If you accidentally 
   use only one greater than sign (`>`) you will completely overwrite the
   configuration file with a new configuration file that does nothing but
   set the environment variable for the HCP Pipelines.

   Of course, if you use a different command line shell than `bash`, you
   will need to change the appropriate login configuration file for your
   chosen shell and use a command to set the environment variable that is
   appropriate for that shell.

   In this documentation, in documentation within the script files themselves,
   and elsewhere, we will use the terminology *HCP Pipelines Directory* 
   interchangably with `HCPPIPEDIR`, `$HCPPIPEDIR`, or `${HCPPIPEDIR}`.

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
[here](link needs to be added). In that case, you will need to place the 
obtained gradient coefficients file (`coeff_SC72C_Skyra.grad`) in the 
`global/config` directory within your HCP Pipelines Directory.

If you do not have and are not planning to obtain the gradient coefficients 
file for the Connectome Skyra scanner used to collect the sample data and 
want to run the pipelines on files on which gradient distortion correction
has already been performed, you should should download a zip file containing 
example data [here](link needs to be added).

The remainder of these instructions assume you have extracted the example data
into the directory `~/projects/Pipelines_ExampleData`.  You will need to 
modify the instructions accordingly if you have extracted the example data
elsewhere.

-----

<a id="running-pipelines-on-example-data">
## Running the HCP Pipelines on example data
</a>

### Structural preprocessing
   
Structural preprocessing is subdivided into 3 parts (Pre-FreeSurfer processing, 
FreeSurfer processing, and Post-FreeSurfer processing).  These 3 steps should
be excuted in the order specified, and each of these 3 parts is implemented
as a separate `bash` script.

*Pre-FreeSurfer processing*

In the `${HCPPIPEDIR}/Examples/Scripts` directory, you will find 
a shell script for running a batch of subject data through the 
Pre-FreeSurfer processing.  This shell script is named:
`PreFreeSurferPipelineBatch.sh`. You should review and possibly 
edit that script file to run the example data through the 
Pre-FreeSurfer processing.

*`StudyFolder`*

The setting of the `StudyFolder` variable at the top of this script
should be verified or edited.  This variable should contain the path to a 
directory that will contain data for all subjects in subdirectories named 
for each of the subject IDs.

As distributed, this variable is set with the assumption that you have
extracted the sample data into a directory named `projects/Pipelines_ExampleData`
within your login or "home" directory.

<blockquote>
<code>
StudyFolder="${HOME}/projects/Pipelines_ExampleData"
</code>
</blockquote>

You should either verify that your example data is extracted to that
location or modify the variable setting accordingly.

*`Subjlist`*

The setting of the `Subjlist` variable, which comes immediately
after the setting of the `StudyFolder` variable, should also be 
verified or edited.  This variable should contain a space delimited 
list of the subject IDs for which you want the Pre-FreeSurfer processing
to run.  

As distributed, this variable is set with the assumption that you will
run the processing only for the single example subject, which has a
subject ID of `100307`.  

<blockquote>
<code>
Subjlist="100307"
</code>
</blockquote>

Using this value in conjunction with the value of the `StudyFolder` variable,
the script will look for a directory named `100307` within the directory 
`${HOME}/projects/Pipelines_ExampleData`.  This is where it will expect to 
find the data it is to process.

You should either verify that your example data is in that location
or modify the variable setting accordingly.

*`EnvironmentScript`*

The `EnvironmentScript` variable should contain the path to a 
script that sets up the rest of the environment variables that 
are necessary for running the Pipeline scripts.  

As distributed, this variable is set with the assumption that you
have installed the HCP Pipelines in the directory 
`${HOME}/projects/Pipelines` (i.e. that your HCP Pipelines directory
is `${HOME}/projects/Pipelines` and that you will use the 
example environment setup provided in the 
`Examples/Scripts/SetUpHCPPipeline.sh` script.

You may need to update the setting of the `EnvironmentScript` 
variable to reflect where you have installed the HCP Pipelines.

*`GradientDistortionCoeffs`*

Further down in the script, the `GradientDistortionCoeffs` variable
is set.  This variable should be set to contain either the path to 
the gradient coefficients file to be used for gradient distortion 
correction, or it should be set to the value `NONE` to skip over the 
gradient distortion correction step.

As distributed, the script assumes that the coefficients file is 
available, is named `coeff_SC72C_Skyra.grad`, and has been placed 
in the standard HCP Pipelines configuration directory.

<blockquote>
<code>
GradientDistortionCoeffs="${HCPPIPEDIR_Config}/coeff_SC72C_Skyra.grad"
</code>
</blockquote>

You will need to update the setting of this variable if you have
a gradient coefficients file to use that is placed elsewhere.  If you 
intend to skip the gradient distortion correction (e.g. if you have
downloaded sample data that is already gradient distortion corrected,
you will need to set this variable to `NONE`.

<blockquote>
<code>
GradientDistortionCoeffs="NONE"
</code>
</blockquote>

*`HCPPIPEDIR` and the `SetUpHCPPipeline.sh` script*

The script file referenced by the `EnvironmentScript` variable 
in the `PreFreeSurferPipelineBatch.sh` file (by default the 
`SetUpHCPPipeline.sh` file in the Examples\Scripts folder)
does nothing but establish values for all the environment
variables that will be needed by various pipeline scripts.

All of the environment variables set in the `SetUpHCPPipeline.sh`
script (with the exception of the `HCPPIPEDIR` environment variable
itself) are set relative to the `HCPPIPEDIR`
environment variable.  Even if you have set the 
`HCPPIPEDIR` environment variable in your login configuration
file as instructed above, it is advisable to set the value
correctly in the `SetUpHCPPipeline.sh` file.  Depending upon
how you launch the a pipeline, the value for `HCPPIPEDIR` 
that you set in your login configuration file may not 
take effect for a particular run of the pipeline.

As distributed, the setting of the `HCPPIPEDIR` environment 
variable assumes that you have installed the HCP Pipelines
in the `${HOME}/projects/Pipelines` directory.  You may 
need to change this to reflect your actual installation
directory.  

As distributed, the `SetUpHCPPipeline.sh` script assumes 
that you have 

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

*Running the Pre-FreeSurfer processing*

Once you have made any necessary edits as described above,
the Pre-FreeSurfer processing can be invoked by commands
similar to:

<blockquote>
<code>
$ cd ~/projects/Pipelines/Examples/Scripts
$ ./PreFreeSurferPipelineBatch.sh
This script must be SOURCED to correctly setup the environment 
prior to running any of the other HCP scripts contained here

100307
Found 1 T1w Images for subject 100307
Found 1 T2w Images for subject 100307
About to use fls_sub to queue or run PreFreeSurferPipeline.sh
</code>
</blockquote>

After reporting The `PreFreeSurferPipelineBatch.sh` script uses the FSL
command `fsl_sub` to submit the processing job which ultimately runs
the `PreFreeSurferPipeline.sh` pipeline script.

If your system is configured to run jobs on an Oracle Grid Engine cluster 
(previously known as Sun Grid Engine (SGE) cluster), then `fsl_sub` will 
submit a job to run the `PreFreeSurferPipeline.sh` script on the
cluster. Otherwise, `fsl_sub` will run the script directly on the 
system from which you launched the example script.

In either case, the standard output (stdout) and standard error (stderr) 
output from the running of `PreFreeSurferPipeline.sh` will be sent to 
files instead of being send directly back to your terminal.  This 
could leave you with the impression that "nothing is happening".
To follow the progress of the processing you will need to find 
the associated standard output file and view its contents.

If you do not have your system configured to submit jobs to a
grid engine (cluster), the standard out and standard error files
will be found in the directory you were in when issuing the 
`./PreFreeSurferPipelineBatch.sh` command.  They will be 
named `PreFreeSurferPipeline.sh.o<process-id>` and 
`PreFreeSurferPipeline.sh.e<process-id>` respectively, where
<process-id> is an operating system assigned unique process
ID for the running job.

For example, if you might see two files named:

<blockquote>
<code>
PreFreeSurferPipeline.sh.e14201
PreFreeSurferPipeline.sh.o14201
</code>
</blockquote>

in the directory from which you launched the `PreFreeSurferPipelineBatch.sh` 
script.  To watch the progress of processing you could then issue a command
like:

<blockquote>
<code>
$ tail -f PreFreeSurferPipeline.sh.o14201
</blockquote>


submit if SGE...

otherwise simply run





-----

<a id="still-have-questions">
## Still have questions?
</a>

Please review the [FAQ][FAQ]

-----

<!-- References -->

[HCP]: http://www.humanconnectome.org
[GlasserEtAl]: http://www.ncbi.nlm.nih.gov/pubmed/23668970
[FSL]: http://fsl.fmrib.ox.ac.uk
[FreeSurfer]: http://freesurfer.net
[FreeSurfer-hcp-version]: ftp://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/5.3.0-HCP/
[FAQ]: https://github.com/Washington-University/Pipelines/blob/master/FAQ.md
[HCP-gradunwarp]: https://github.com/Washington-University/gradunwarp/releases
[HCP-pipelines-release]: https://github.com/Washington-University/Pipelines/releases