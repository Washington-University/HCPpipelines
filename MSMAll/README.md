# HCP Pipelines MSMAll subdirectory

<General description to be written>

# Notes on MATLAB usage

Several of the downstream scripts called by MSMAllPipeline.sh rely on
functions written in MATLAB. This MATLAB code can be executed in 3
possible modes, controlled by the `--matlab-run-mode` input argument:

0. Compiled Matlab -- more on this below
1. Interpreted Matlab (default) -- probably easiest to use, if it is an option for you
2. Interpreted Octave -- an alternative to Matlab, although:
	1. You'll need to configure various helper functions (i.e.,
       `${HCPPIPEDIR/global/matlab/{ciftiopen.m, ciftisave.m, ciftisavereset.m}`) to work within your Octave environment.

### Support for compiled MATLAB

If using Compiled Matlab, the `MATLAB_COMPILER_RUNTIME` environment variable
must be set to the directory containing the "MATLAB Compiler Runtime" (MCR)
version (installed on your system) that was used for the compilation, which
was 'R2016b/v91'.

i.e.,

	export MATLAB_COMPILER_RUNTIME=/export/matlab/MCR/R2016b/v91
