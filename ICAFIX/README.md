# HCP Pipelines ICAFIX subdirectory

This directory contains [HCP] and [Washington University] official versions of
scripts related to [FSL]'s [FIX], a tool for denoising of fMRI data using
spatial ICA (i.e., melodic) followed by automatic classification of components into
'signal' and 'noise' components.

The scripts here support both "single-run" FIX and "multi-run" FIX (MR-FIX).
MR-FIX concatenates a set of fMRI runs so as to provide more data to the
spatial ICA, to yield better separation of 'signal' and 'noise' components.

A typical workflow would be:
* Run single or multi-run FIX (see Examples/Scripts/IcaFixProcessingBatch.sh)
* Run "PostFix" to generate Workbench scenes for reviewing the FIX classification (see
  Examples/Scripts/PostFixBatch.sh)
* Review those scenes to QC the quality of the FIX classification. If you are
  satisfied with the quality, proceed to use the cleaned data.
* If you feel reclassification of certain components is necessary, enter the
  appropriate component numbers that you feel were mis-classified into the
  ReclassifyAsSignal.txt or ReclassifyAsNoise.txt files (as appropriate).
  * Run ApplyHandReClassifications.sh (see
  Examples/Scripts/ApplyHandReClassificationsBatch.sh)
  * Run ReApplyFixPipeline.sh (for single-run FIX) or
  ReApplyFixMultiRunPipeline.sh (for multi-run FIX) to re-clean the data using
  the manual ("hand") reclassification. These scripts are also the mechanism
  by which cleaned files are generated for an alternative surface registration
  (e.g., 'MSMAll') (although in that case, the ReApplyFix scripts are invoked automatically 
  by the DeDriftAndResamplePipeline)
  
Note that `FSL_FIXDIR` environment variable needs to be set to the location of 
your [FIX] installation. You may need to modify your FIX installation to fit your 
compute environment. In particular, the `${FSL_FIXDIR}/settings.sh` file may need modification. 
(The settings.sh.WUSTL_CHPC2 file in this directory is the settings.sh file that is
used on the WUSTL "CHPC2" cluster).

# Notes on MATLAB usage

Most of the scripts in this directory at some point rely on functions written
in MATLAB. This MATLAB code can be executed in 3 possible modes:

0. Compiled Matlab -- more on this below
1. Interpreted Matlab -- probably easiest to use, if it is an option for you
2. Interpreted Octave -- an alternative to Matlab, although:
	1. You'll need to configure various helper functions (such as `${HCPPIPEDIR/global/matlab/{ciftiopen.m, ciftisave.m}` and `$FSLDIR/etc/matlab/{read_avw.m, save_avw.m}`) to work within your Octave environment.
	2. Default builds of Octave are limited in the amount of memory and array dimensions that are supported. Especially in the context of multi-run FIX, you will likely need to build a version of Octave that supports increased memory, more on this below.

### Building Octave with support for large matrices

Several dependencies of octave also need to be built with nonstandard options to enable large matrices.  Other people have already made build recipes that automate most of this, our slightly altered version of one is here:

https://github.com/coalsont/GNU-Octave-enable-64

You will need to install most of the build dependencies of octave before using it (however, having a default build of libsuitesparse installed can result in a non-working octave executable, one effective solution is to uninstall the libsuitesparse headers):

```bash
#ubuntu 14.04 recipe
apt-add-repository ppa:ubuntu-toolchain-r/test
apt-get update && apt-get build-dep -y --no-install-recommends octave && apt-get install -y --no-install-recommends git cmake libpq-dev gcc-6 gfortran-6 g++-6 zip libosmesa6-dev libsundials-serial-dev bison && apt-get remove -y libsuitesparse-dev && apt-get autoremove -y
git clone https://github.com/coalsont/GNU-Octave-enable-64.git && cd GNU-Octave-enable-64 && make INSTALL_DIR=/usr/local CC=gcc-6 FC=gfortran-6 CXX=g++-6 && ldconfig
```

### Control of Matlab mode within specific scripts

#### hcp_fix and hcp_fix_multi_run

The Matlab mode is controlled by the `FSL_FIX_MATLAB_MODE` environment variable within the
`${FSL_FIXDIR}/settings.sh` file. 
[Note: If the `${FSL_FIXDIR}/settings.sh` file is set up appropriately (i.e., FIX v1.068 or later), 
it should respect the value of `FSL_FIX_MATLAB_MODE` in your current environment].

#### ReApplyFixPipeline, ReApplyFixMultiRunPipeline, and PostFix

The Matlab mode is controlled via the `--matlab-run-mode` input argument
(defaults to mode 1, interpreted Matlab).

#### ApplyHandReClassifications

Does not use any Matlab code.

### Support for compiled Matlab within specific scripts

If your cluster compute environment doesn't support the use of interpreted
MATLAB, your options are either to use compiled MATLAB or Octave.
Unfortunately, due to different development paths, the setup of compiled
MATLAB differs across the different scripts in this directory. We hope to be
able to harmonize this in the future.

#### hcp_fix, ReApplyFixPipeline

The `FSL_FIX_MCRROOT` environment variable in the `${FSL_FIXDIR}/settings.sh`
file must be set to the "root" of the directory containing the "MATLAB
Compiler Runtime" (MCR) version for the MATLAB release under which the FIX
distribution was compiled (which is 'R2014a' as of FIX version 1.068).
[Note that the `${FSL_FIXDIR}/settings.sh` file automatically determines the MCR version number (i.e., 'v83')].

#### hcp_fix_multi_run, ReApplyFixMultiRunPipeline

* First, `${FSL_FIXDIR}/settings.sh` must be set up correctly.
* Second, because some MATLAB functions (that are part of the HCPpipelines, rather
than the FIX distribution) were compiled under a different version of the MCR,
the `MATLAB_COMPILER_RUNTIME` environment variable must be set to the
directory containing the 'R2016b/v91' MCR.

i.e.,

	export MATLAB_COMPILER_RUNTIME=/export/matlab/MCR/R2016b/v91

#### PostFix

The `MATLAB_COMPILER_RUNTIME` environment variable must be set to the
directory containing the 'R2016b/v91' MCR (i.e., same as with
`hcp_fix_multi_run` and `ReApplyFixMultiRunPipeline`.


# Supplemental instructions for installing FIX

Some effort (trial and error) is required to install the versions of R packages specified on the [FIX User Guide] page, so below are instructions obtained from working installations of FIX.  Note that [FIX]'s minimum supported version of R is 3.3.0.

### Ubuntu 14.04

```bash
#superuser permissions are required for all steps as written, you can use "sudo -s" to obtain a root-privileged shell

#cran includes packages of R for ubuntu (and other linux distros) which are in sync with cran
#this repo should install a 3.4.x version - 3.5.x doesn't seem to be able to install the specified package versions
echo deb http://cloud.r-project.org/bin/linux/ubuntu trusty/ >> /etc/apt/sources.list
apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0x51716619E084DAB9

#install build dependencies for the R packages we need
apt-get update && apt-get install build-essential bc r-base-core gfortran libblas-dev liblapack-dev libcurl4-openssl-dev libssl-dev libssh2-1-dev --no-install-recommends

#use R to install devtools, then use its install_version for the rest
echo '
  install.packages("devtools", repos = "http://cloud.r-project.org/");
  require(devtools);
  install_version("kernlab", version = "0.9-24", repos = "http://cloud.r-project.org/");
  install_version("ROCR", version = "1.0-7", repos = "http://cloud.r-project.org/");
  install_version("class", version = "7.3-14", repos = "http://cloud.r-project.org/");
  install_version("party", version = "1.0-25", repos = "http://cloud.r-project.org/");
  install_version("e1071", version = "1.6-7", repos = "http://cloud.r-project.org/");
  install_version("randomForest", version = "4.6-12", repos = "http://cloud.r-project.org/");
' | R --vanilla
```

### Generic approach, tested on 3.3.x and 3.4.x

```bash
#superuser permissions are required for most steps as written, you can use "sudo -s" to obtain a root-privileged shell

#PICK ONE:
#1) fedora/redhat/centos dependencies for R packages
yum -y groupinstall 'Development Tools'
yum -y install blas-devel lapack-devel qt-devel mesa-libGLU openssl-devel libssh-devel

#2) debian/ubuntu dependencies
apt-get update && apt-get install -y build-essential libblas-dev liblapack-dev qt5-default libglu1-mesa libcurl4-openssl-dev libssl-dev libssh2-1-dev --no-install-recommends

#R and recommended R packages must already be installed
PACKAGES="mvtnorm_1.0-8 modeltools_0.2-22 zoo_1.8-4 sandwich_2.5-0 strucchange_1.5-1 TH.data_1.0-9 survival_2.43-3 multcomp_1.4-8 coin_1.2-2 bitops_1.0-6 gtools_3.8.1 gdata_2.18.0 caTools_1.17.1.1 gplots_3.0.1 kernlab_0.9-24 ROCR_1.0-7 class_7.3-14 party_1.0-25 e1071_1.6-7 randomForest_4.6-12"
MIRROR="http://cloud.r-project.org"

for package in $PACKAGES
do
    wget "$MIRROR"/src/contrib/Archive/$(echo "$package" | cut -f1 -d_)/"$package".tar.gz || \
        wget "$MIRROR"/src/contrib/"$package".tar.gz
    R CMD INSTALL "$package".tar.gz
done
```

<!-- References -->

[HCP]: http://www.humanconnectome.org
[Washington University]: http://www.wustl.edu
[FSL]: http://fsl.fmrib.ox.ac.uk/fsl/fslwiki
[FIX]: http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FIX
[FIX User Guide]: https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FIX/UserGuide
