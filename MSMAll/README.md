# HCP Pipelines MSMAll subdirectory

MSMAll is a tool for surface-based functional alignment.  It uses T1w/T2w myelin maps, resting state network maps, and resting-state-based visuotopic maps to align a subject's cortical data to a group template.  One runs MSMAll after running either sICA+FIX (single run or multi-run).  One first runs the MSMAll Pipeline, then the DeDriftAndResample Pipeline.  Most users should not do any dedrifting as they should use an existing registration template; dedrifting is only intended to be used when generating a new registration template.

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
was 'R2016b/v91'.

i.e.,

	export MATLAB_COMPILER_RUNTIME=/export/matlab/MCR/R2016b/v91
