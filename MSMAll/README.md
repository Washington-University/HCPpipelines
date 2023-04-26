# HCP Pipelines MSMAll subdirectory

MSMAll is a tool for surface-based functional alignment. It uses T1w/T2w myelin maps, resting state network maps, and resting-state-based visuotopic maps to align a subject's cortical data to a group template. MSMAll should be run on sICA+FIX cleaned data (single run or multi-run). First run the MSMAll Pipeline to generate the MSMAll registration, then the DeDriftAndResample Pipeline. DeDriftAndResample is generally used merely to resample the data according to the MSMAll registration, the "dedrift" part of the name only refers to an option (--dedrift-reg-files), which most users should not use, as the option's purpose is for generating a new registration template (atlas). For the uncommon case of generating a new registration template, the MSMRemoveGroupDrift script can calculate the group drift spheres.

# Notes on MATLAB usage

Several of the downstream scripts called by MSMAllPipeline.sh rely on
functions written in MATLAB. This MATLAB code can be executed in 3
possible modes, controlled by the `--matlab-run-mode` input argument:

0. Compiled Matlab -- more on this below
1. Interpreted Matlab (default) -- probably easiest to use, if it is an option for you
2. Interpreted Octave -- an alternative to Matlab

### Support for compiled MATLAB

If using Compiled Matlab, the `MATLAB_COMPILER_RUNTIME` environment variable
must be set to the directory containing the "MATLAB Compiler Runtime" (MCR)
version (installed on your system) that was used for the compilation, which
was 'R2017b/v93'.

i.e.,

	export MATLAB_COMPILER_RUNTIME=/export/matlab/MCR/R2017b/v93
