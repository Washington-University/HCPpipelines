#!/bin/bash

# ------------------------------------------------------------------------------
#  Main processing of script.
# ------------------------------------------------------------------------------

main()
{
	local app_name=MSMregression
	local output_directory=Compiled_${app_name}
	
	pushd ${HCPPIPEDIR}/MSMAll/scripts > /dev/null
	log_Msg "Working in ${PWD}"
	
	log_Msg "Creating output directory: ${output_directory}"
	mkdir --parents ${output_directory}

	log_Msg "Compiling ${app_name} application"
	${MATLAB_HOME}/bin/mcc -mv ${app_name}.m \
				  -a ss_svds.m \
				  -d ${output_directory}
	
	#				  -a ${HCPPIPEDIR}/global/matlab/ciftiopen.m \
	#				  -a ${HCPPIPEDIR}/global/matlab/gifti-1.6 \
	#				  -a ${HCPPIPEDIR}/global/fsl/etc/matlab \

	popd > /dev/null
}

# ------------------------------------------------------------------------------
#  "Global" processing - everything above here should be in a function
# ------------------------------------------------------------------------------

set -e # If any commands exit with non-zero value, this script exits

# Verify that HCPPIPEDIR environment variable is set
if [ -z "${HCPPIPEDIR}" ]; then
	script_name=$(basename "${0}")
	echo "${script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
	exit 1
fi

# Load function libraries
source ${HCPPIPEDIR}/global/scripts/log.shlib # Logging related functions
log_Msg "HCPPIPEDIR: ${HCPPIPEDIR}"

# Verify that other needed environment variables are set
if [ -z "${MATLAB_HOME}" ]; then
	log_Err_Abort "MATLAB_HOME environment variable must be set"
fi
log_Msg "MATLAB_HOME: ${MATLAB_HOME}"

# Invoke the main processing
main "$@"
