# HCP Pipelines bedpostx subdirectory

This subdirectory contains a drop-in replacement for the `bedpostx_gpu`
executable (bash script) found in an [FSL][FSL] installation's bin 
directory. 

The modifications to the `bedpostx_gpu` script from the standard
version of the script found in FSL version 5.0.9 are two-fold.
First, changes were made by Stamatios Sotiropoulos to properly
submit jobs using the PBS job scheduler on the Washington University
[CHPC][CHPC] cluster (v2.0). Second, very minor changes were made
by Timothy B. Brown at [NRG][NRG] to add subject IDs to the beginning
of job names to make job management easier.

<!-- References -->

[FSL]: https://fsl.fmrib.ox.ac.uk/fsl/fslwiki
[CHPC]: http://chpc2.wustl.edu
[NRG]: http://nrg.wustl.edu
