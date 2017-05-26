# HCP Pipelines PostFix Pipeline

A compiled version of the MATLAB code used in this pipeline has been created
in the Compiled_prepareICAs sub-directory. This was compiled using MATLAB
release R2016b and requires that the environment variable MATLAB_COMPILER_RUNTIME
be set to the directory containing the MATLAB Compiler Runtime (MCR) for
MATLAB release R2016b.

For example,

	export MATLAB_COMPILER_RUNTIME=/export/matlab/MCR/R2016b/v91

To compile the MATLAB function prepareICAs for use in the PostFix pipeline, make
sure the following environment variables are set.

	 HCPPIPEDIR  = the root directory of your installation of the HCP Pipeline Scripts
	               (e.g. /home/user/projects/Pipelines)
	 MATLAB_HOME = the root directory of your installation of MATLAB that you would like
	               to use for the compilation (e.g. /usr/local/MATLAB/R2016b)

Then run the Compile_prepareICAs.sh script to create the compiled MATLAB code in the
${HCPPIPEDIR}/PostFix/Compiled_prepareICAs directory.

To then successfully run the PostFix pipeline using the compiled prepareICAs MATLAB
function, set the MATLAB_COMPILER_RUNTIME environment variable (see above) and
make sure that when you invoke the PostFix.sh script, you use the --matlab-run-mode=0
command line option.
