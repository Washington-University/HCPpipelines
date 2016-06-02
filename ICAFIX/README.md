# HCP Pipelines ICAFIX subdirectory.

This directory contains [HCP] and [Washington University] specific modifications 
of the standard files distributed as part of the [FSL] [FIX] tool. 

They are not necessarily intended to be run from this directory, but instead
are intended to replace the corresponding files in the [FIX] distribution.
They may need to be modified to fit your environment.

## Files

* `hcp_fix` 
  * replacement for the `hcp_fix` script supplied with [FIX]
  * adds a command line parameter to specify the training data file to use
  * invokes an altered/corrected version of the `melodic` binary (v3.14a) instead
    of the `melodic` binary in the [FSL] distribution

* `settings.sh.WUSTL_CHPC2`
  * replacement for the `settings.sh` script supplied with [FIX]
  * very likely to need modified to fit your environment
  * sets enviroment variables that are used by other [FIX] tools to invoke 
    such things as Matlab or Octave

<!-- References -->

[HCP]: http://www.humanconnectome.org
[Washington University]: http://www.wustl.edu
[FSL]: http://fsl.fmrib.ox.ac.uk/fsl/fslwiki
[FIX]: http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FIX