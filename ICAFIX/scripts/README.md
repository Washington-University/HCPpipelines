# ICAFIX/scripts

This directory mostly contains the MATLAB functions used for running
the ICAFIX scripts.

## Notes on Compiled_prepareICAs directory

The `Compiled_prepareICAs` sub-directory contains a compiled version of the
`prepareICAs` function used by the PostFix script.

This was compiled using MATLAB release R2016b and requires that the
environment variable `MATLAB_COMPILER_RUNTIME` be set to the directory
containing the MATLAB Compiler Runtime (MCR) for MATLAB release R2016b.

For example,

	export MATLAB_COMPILER_RUNTIME=/export/matlab/MCR/R2016b/v91

## Notes on Compile_MATLAB_prepareICAs.sh script

If you have a need to compile the MATLAB function `prepareICAs` yourself
(e.g., if you want to use a different version of the MCR, or for a different OS)
you can use the provided `Compile_prepareICAs.sh` script.

To do so, make sure the following environment variables are set:

	 HCPPIPEDIR  = the root directory of your installation of the HCP Pipeline Scripts
	               (e.g., /home/user/projects/Pipelines)
	 MATLAB_HOME = the root directory of your installation of MATLAB that you would like
	               to use for the compilation (e.g., /usr/local/MATLAB/R2016b)

Then run the `Compile_prepareICAs.sh` script, which will create the compiled
MATLAB code in the `${HCPPIPEDIR}/ICAFIX/scripts/Compiled_prepareICAs` directory.

To then successfully run the PostFix pipeline using the newly compiled `prepareICAs` MATLAB
function, set the `MATLAB_COMPILER_RUNTIME` environment variable (see above) and
make sure that when you invoke the PostFix.sh script, you use the --matlab-run-mode=0
command line option.
