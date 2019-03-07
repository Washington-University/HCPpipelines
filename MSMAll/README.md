# HCP Pipelines MSMAll subdirectory

<General description to be written>


# Notes on MATLAB usage

Several of the downstream scripts called by MSMAllPipeline.sh rely on
functions written in MATLAB. This MATLAB code can be executed in 2 possible
modes, controlled by the --matlab-run-mode input argument:

0. Compiled Matlab
1. Interpreted Matlab (default) -- probably easiest to use, if it is an option for you

[Interpreted Octave -- an alternative to Matlab -- is not supported currently in this script].

If using Compiled Matlab, the `MATLAB_COMPILER_RUNTIME` environment variable
must be set to the directory containing the "MATLAB Compiler Runtime" (MCR)
version (installed on your system) that was used for the compilation, which
was 'R2016b/v91'.

For example,

	export MATLAB_COMPILER_RUNTIME=/export/matlab/MCR/R2016b/v91
