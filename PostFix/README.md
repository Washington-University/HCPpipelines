# HCP Pipelines PostFix Pipeline

Part of the PostFix pipeline relies the custom MATLAB function 'prepareICAs'.
If interpreted MATLAB mode is an option, you can use the --matlab-run-mode=1
command line option in PostFix.

Alternatively, you can try using Octave, although to do so, you'll need to 
configure various helper functions (such as ${HCPPIPEDIR/global/matlab/{ciftiopen.m, ciftisave.m}
and $FSLDIR/etc/matlab/{read_avw.m, save_avw.m}) to work within your Octave environment.

The remainder of what follows is for users that need to use *compiled* MATLAB 
(e.g., because your cluster compute environment doesn't support the use of interpreted MATLAB).

-----------------

A compiled version for Linux of the MATLAB code used in this pipeline has been created
in the Compiled_prepareICAs sub-directory. This was compiled using MATLAB
release R2016b and requires that the environment variable MATLAB_COMPILER_RUNTIME
be set to the directory containing the MATLAB Compiler Runtime (MCR) for
MATLAB release R2016b.

For example,

	export MATLAB_COMPILER_RUNTIME=/export/matlab/MCR/R2016b/v91

-----------------

To compile the MATLAB function prepareICAs yourself
(e.g., if you want to use a different version of the MCR, or for a different OS)
make sure the following environment variables are set.

	 HCPPIPEDIR  = the root directory of your installation of the HCP Pipeline Scripts
	               (e.g., /home/user/projects/Pipelines)
	 MATLAB_HOME = the root directory of your installation of MATLAB that you would like
	               to use for the compilation (e.g., /usr/local/MATLAB/R2016b)

Then run the Compile_prepareICAs.sh script to create the compiled MATLAB code in the
${HCPPIPEDIR}/PostFix/Compiled_prepareICAs directory.

To then successfully run the PostFix pipeline using the compiled prepareICAs MATLAB
function, set the MATLAB_COMPILER_RUNTIME environment variable (see above) and
make sure that when you invoke the PostFix.sh script, you use the --matlab-run-mode=0
command line option.
