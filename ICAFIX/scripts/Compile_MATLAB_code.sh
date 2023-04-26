#!/bin/bash

#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # Compile_MATLAB_code.sh
#
# Compile the MATLAB code necessary for running the ICAFIX Pipeline
#
# ## Copyright Notice
#
# Copyright (C) 2019 The Connectome Coordination Facility (CCF)
#
# * Washington University in St. Louis
# * University of Minnesota
# * Oxford University
#
# ## Author(s)
#
# * Timothy B. Brown, Neuroinformatics Research Group, Washington University in St. Louis
#
# ## Product
#
# [Human Connectome Project][HCP] (HCP) Pipelines
#
# ## License
#
# See the [LICENSE](https://github.com/Washington-Univesity/Pipelines/blob/master/LICENSE.md) file
#
# <!-- References -->
# [HCP]: http://www.humanconnectome.org
#
#~ND~END~


# NOTE: The use of '${HCPPIPEDIR}/global/matlab/@gifti' as a symlink to '${HCPPIPEDIR}/global/matlab/gifti-1.6/@gifti'
# works just fine to ensure that adding '${HCPPIPEDIR}/global/matlab' to the matlab path within scripts
# is sufficient to enable GIFTI I/O functionality within INTERPRETED matlab (or Octave) mode.
# However, for compilation, using a single "-I ${HCPPIPEDIR}/global/matlab" option is NOT sufficient to enable
# GIFTI I/O functionality within compiled matlab executables -- perhaps because the matlab compiler
# doesn't follow or recognize the @gifti symlink?
# Thence the need for explicitly also including "-I ${HCPPIPEDIR}/global/matlab/gifti-1.6" as an option
# in the compiler commands below.

# FURTHER, the "-I" option *appends* folders to the search path, and
# "-I ${HCPPIPEDIR}/global/matlab/gifti-1.6" must come BEFORE
# "-I ${HCPPIPEDIR}/global/matlab", OTHERWISE, the presence of the @gifti symlink actually
# *prevents* the GIFTI I/O functionality from being included.

# Simply deleting the @gifti symlink from ${HCPPIPEDIR}/global/matlab is NOT an option,
# because the pipeline scripts have come to rely on that convenience for interpreted matlab mode.
# We COULD delete the @gifti symlink and simultaneously move the actual '@gifti' folder
# into '${HCPPIPEDIR}/global/matlab', in which case interpreted matlab mode would continue to work,
# and we could then consolidate the two different "-I" options into one.
# But, sticking with the symlink for now, since it was already in place.

 
# ------------------------------------------------------------------------------
#  Compile the prepareICAs MATLAB code
# ------------------------------------------------------------------------------

compile_prepareICAs()
{
	local app_name=prepareICAs
	local output_directory=Compiled_${app_name}

	pushd ${HCPPIPEDIR}/ICAFIX/scripts > /dev/null
	log_Msg "Working in ${PWD}"

	log_Msg "Creating output directory: ${output_directory}"
	mkdir -p ${output_directory}

	log_Msg "Compiling ${app_name} application"
	${MATLAB_HOME}/bin/mcc -m -v ${app_name}.m \
				  -I ${HCPPIPEDIR}/global/matlab/gifti-1.6 \
				  -I ${HCPPIPEDIR}/global/matlab \
				  -I ${HCPPIPEDIR}/global/fsl/etc/matlab \
				  -d ${output_directory}

	popd > /dev/null
}

# ------------------------------------------------------------------------------
# Compile the functionhighpassandvariancenormalize MATLAB code
# ------------------------------------------------------------------------------

compile_functionhighpassandvariancenormalize()
{
	local app_name=functionhighpassandvariancenormalize
	local output_directory=Compiled_${app_name}

	pushd ${HCPPIPEDIR}/ICAFIX/scripts > /dev/null
	log_Msg "Working in ${PWD}"

	log_Msg "Creating output directory: ${output_directory}"
	mkdir -p ${output_directory}

	log_Msg "Compiling ${app_name} application"
	${MATLAB_HOME}/bin/mcc -m -v ${app_name}.m \
				  -I ${HCPPIPEDIR}/ICAFIX/scripts \
				  -I ${HCPPIPEDIR}/global/matlab/gifti-1.6 \
				  -I ${HCPPIPEDIR}/global/matlab \
				  -I ${HCPPIPEDIR}/global/fsl/etc/matlab \
				  -d ${output_directory}
	
	popd > /dev/null
}

# ------------------------------------------------------------------------------
#  Main processing of script.
# ------------------------------------------------------------------------------

main()
{
	compile_prepareICAs
	compile_functionhighpassandvariancenormalize
}

# ------------------------------------------------------------------------------
#  "Global" processing - everything above here should be in a function
# ------------------------------------------------------------------------------

# Verify that HCPPIPEDIR environment variable is set
if [ -z "${HCPPIPEDIR}" ]; then
	script_name=$(basename "${0}")
	echo "${script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
	exit 1
fi

# Load function libraries
source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@" # Debugging functions; also sources log.shlib
log_Msg "HCPPIPEDIR: ${HCPPIPEDIR}"

# Verify that other needed environment variables are set
log_Check_Env_Var MATLAB_HOME

# Invoke the main processing
main "$@"
