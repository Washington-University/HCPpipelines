#!/bin/bash

set -e # If any commands exit with non-zero value, this script exits

# ------------------------------------------------------------------------------
#  Verify HCPPIPEDIR environment variable is set
# ------------------------------------------------------------------------------

if [ -z "${HCPPIPEDIR}" ]; then
	script_name=$(basename "${0}")
	echo "${script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
	exit 1
fi

# ------------------------------------------------------------------------------
#  Load function libraries
# ------------------------------------------------------------------------------

source ${HCPPIPEDIR}/global/scripts/log.shlib # Logging related functions
log_Msg "HCPPIPEDIR: ${HCPPIPEDIR}"

# ------------------------------------------------------------------------------
#  Verify other needed environment variables are set
# ------------------------------------------------------------------------------

if [ -z "${MATLAB_HOME}" ]; then
	log_Err_Abort "MATLAB_HOME environment variable must be set"
fi
log_Msg "MATLAB_HOME: ${MATLAB_HOME}"

# ------------------------------------------------------------------------------
#  Main processing of script.
# ------------------------------------------------------------------------------

main()
{
	local output_directory=Compiled_prepareICAs
	
	pushd ${HCPPIPEDIR}/PostFix > /dev/null
	log_Msg "Working in ${PWD}"
	
	log_Msg "Creating output directory: ${output_directory}"
	mkdir --parents ${output_directory}

	log_Msg "Compiling prepareICAs application"
	${MATLAB_HOME}/bin/mcc -mv prepareICAs.m \
				  -a ${HCPPIPEDIR}/global/matlab/ciftiopen.m \
				  -a ${HCPPIPEDIR}/global/matlab/gifti-1.6 \
				  -a ${HCPPIPEDIR}/global/fsl/etc/matlab \
				  -d ${output_directory}

	popd > /dev/null
}

# ------------------------------------------------------------------------------
#  Invoke the main function to get things started
# ------------------------------------------------------------------------------

main "$@"
