# HCP Pipelines ICAFIX subdirectory.

This directory contains [HCP] and [Washington University] official versions
of scripts related to [FSL] [FIX].

See Examples/Scripts/IcaFixProcessingBatch.sh for an example launching
script.

Note that `FSL_FIXDIR` should be set to the standard [FIX]
installation. You may need to modify your FIX installation to fit your
environment. In particular, the ${FSL_FIXDIR}/settings.sh file may
need modification.  (The settings.sh.WUSTL_CHPC2 file in this
directory is the settings.sh file that is used on the WUSTL "CHPC2"
cluster).

# Supplemental instructions for installing fix

Some effort (trial and error) is required to install the versions of R packages specified on the [FIX User Guide] page, so below are instructions obtained from working installations of fix:

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

<!-- References -->

[HCP]: http://www.humanconnectome.org
[Washington University]: http://www.wustl.edu
[FSL]: http://fsl.fmrib.ox.ac.uk/fsl/fslwiki
[FIX]: http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FIX
[FIX User Guide]: https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FIX/UserGuide
