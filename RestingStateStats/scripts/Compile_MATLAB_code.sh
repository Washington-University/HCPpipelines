#!/bin/bash

#
# # Compile_MATLAB_code.sh
#
# Compile the MATLAB code necessary for running Resting State Stats
#
# ## Copyright Notice
#
# Copyright (C) 2019 The Connectome Coordination Facility (CCF)
#
# ## Author(s)
#
# * Timothy B. Brown, Neuroinformatics Research Group, Washington University in St. Louis
#
# ## Product
#
# [Human Connectome Project](https://www.humanconnectome.org) (HCP) Pipelines
#
# ## License
#
# See the [LICENSE](https://github.com/Washington-University/HCPpipelines/blob/master/LICENSE.md) file
#


# ------------------------------------------------------------------------------
# Compile the RestingStateStats MATLAB function
# ------------------------------------------------------------------------------
compile_RestingStateStats()
{
	local app_name=RestingStateStats
	local output_directory=Compiled_${app_name}

	pushd ${HCPPIPEDIR}/RestingStateStats/scripts > /dev/null
	log_Msg "Working in ${PWD}"

	log_Msg "Creating output directory: ${output_directory}"
	mkdir -p ${output_directory}
	
	log_Msg "Compiling ${app_name} application"
	${MATLAB_HOME}/bin/mcc -mv ${app_name}.m \
				  -a ${HCPPIPEDIR}/global/matlab/ciftiopen.m \
				  -a ${HCPPIPEDIR}/global/matlab/ciftisave.m \
				  -a ${HCPPIPEDIR}/global/matlab/ciftisavereset.m \
				  -a ${HCPPIPEDIR}/global/matlab/demean.m \
				  -a ${HCPPIPEDIR}/global/matlab/normalise.m \
				  -a ${HCPPIPEDIR}/global/matlab/gifti-1.6 \
				  -a ${HCPPIPEDIR}/global/fsl/etc/matlab \
				  -d ${output_directory}
	
	popd > /dev/null
}

# ------------------------------------------------------------------------------
#  Main processing of script.
# ------------------------------------------------------------------------------
main()
{
	compile_RestingStateStats
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
source "${HCPPIPEDIR}/global/scripts/log.shlib" # Logging related functions
log_Msg "HCPPIPEDIR: ${HCPPIPEDIR}"

# Verify that any other needed environment variables are set
log_Check_Env_Var MATLAB_HOME

# Invoke the main processing
main "$@"

