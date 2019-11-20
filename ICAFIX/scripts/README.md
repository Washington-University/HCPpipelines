# ICAFIX/scripts

This directory mostly contains the MATLAB functions used for running
the ICAFIX scripts.

## Notes on Compiled_prepareICAs directory

The `Compiled_prepareICAs` sub-directory contains a compiled version of the
`prepareICAs` function used by the `PostFix.sh` script.

This was compiled using MATLAB release R2017b and requires that the
environment variable `MATLAB_COMPILER_RUNTIME` be set to the directory
containing the MATLAB Compiler Runtime (MCR) for MATLAB release R2017b.

For example,

	export MATLAB_COMPILER_RUNTIME=/export/matlab/MCR/R2017b/v93

## Notes on Compiled_functionhighpassandvariancenormalize directory

The `Compiled_functionhighpassandvariancenormalize` sub-directory contains a compiled version of the
`functionhighpassandvariancenormalize` function used by the
`hcp_fix_multi_run` and `ReApplyFixMultiRunPipeline.sh` scripts.

It was also compiled using MATLAB release R2017b, and
`MATLAB_COMPILER_RUNTIME` should be set accordingly (see above).

## Notes on Compile_MATLAB_code.sh script

If you have a need to compile the MATLAB functions `prepareICAs` or
`functionhighpassandvariancenormalize` yourself
(e.g., if you want to use a different version of the MCR, or for a different OS)
you can use the provided `Compile_MATLAB_code.sh` script.

To do so, make sure the following environment variables are set:

	 HCPPIPEDIR  = the root directory of your installation of the HCP Pipeline Scripts
	               (e.g., /home/user/projects/Pipelines)
	 MATLAB_HOME = the root directory of your installation of MATLAB that you would like
	               to use for the compilation (e.g., /usr/local/MATLAB/R2017b)

Then run the `Compile_MATLAB_code.sh` script, which will create the compiled
MATLAB code in the `${HCPPIPEDIR}/ICAFIX/scripts/Compiled_<functionName>` directories.

To then successfully run the associated ICAFIX pipeline scripts using the
newly compiled functions, set the `MATLAB_COMPILER_RUNTIME` environment
variable (see above) and make sure that you invoke the scripts in the
manner that uses compiled MATLAB.
(See https://github.com/Washington-University/HCPpipelines/blob/master/ICAFIX/README.md).
