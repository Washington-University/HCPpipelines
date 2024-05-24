#!/bin/bash

#
# # Compile_All_MATLAB_code.sh
#
# Compile all the MATLAB source code used in the HCP Pipelines code base
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

g_script_name=$(basename "${0}")

# ------------------------------------------------------------------------------
#  Usage Description Function
# ------------------------------------------------------------------------------

usage()
{
	cat <<EOF

${g_script_name}

  This script can be used to (re)-compile all MATLAB code for functions called by
  any pipelines that are part of the HCP Pipelines.

  Since the HCP Pipelines already provides compiled versions of the associated 
  MATLAB code, it should not be necessary for a user of the HCP Pipelines to 
  use this script to compile the MATLAB code.

  Currently, the compiled MATLAB code was created with MATLAB release R2017b
  and, therefore, is intended to be run using the MATLAB Compiler Runtime (MCR)
  version R2017b/v93. 

  Use of this script by users of the HCP Pipelines should only be necessary if
  a user wants or needs to use a different release of MATLAB. 

  The compiled functions can be used to run the associated pipelines on systems
  that do not have MATLAB itself licensed or installed and therefore cannot use 
  interpreted MATLAB during pipeline processing.

  Requirements for Compiling MATLAB code
  ======================================

  * The system on which you perform the compilation must have a licensed version 
    of MATLAB installed and a licensed version of the optional MATLAB compiler (mcc). 

  * The MATLAB_HOME environment variable must be set to the directory in which
    the version of MATLAB to use for the compilation is installed. For example:

      export MATLAB_HOME=/usr/local/MATLAB/R2017b

  Requirements for Running Compiled MATLAB functions
  ==================================================

  * The system on which pipeline processing is run must have installed the MATLAB 
    Compiler Runtime (MCR) that corresponds to the version of the MATLAB Compiler 
    (mcc) used when compilation was done.

  * The MATLAB_COMPILER_RUNTIME environment variable must be set to the directory
    in which the MCR is installed. For example:

      export MATLAB_COMPILER_RUNTIME=/export/matlab/MCR/R2017b/v93

  Usage: ${g_script_name} [--help]

    [] = optional

    [--help] : show usage information and exit

EOF
}

# ------------------------------------------------------------------------------
#  Get command line options
# ------------------------------------------------------------------------------
get_options()
{
	local arguments=($@) # parse arguments into an array of values using spaces as the delimiter

	# parse arguments
	local num_args=${#arguments[@]}
	local argument
	local index=0

	while [ "${index}" -lt "${num_args}" ]; do
		argument=${arguments[index]}

		case ${argument} in
			--help)
				usage
				exit 1
				;;
			*)
				usage
				log_Err_Abort "unrecognized option: ${argument}"
				;;
		esac
	done
}

# ------------------------------------------------------------------------------
#  Main processing of script.
# ------------------------------------------------------------------------------
main()
{
	get_options "$@"
	
	log_Msg "----------------------------------------"
	log_Msg "Compiling fMRIVolume-related MATLAB code"
	log_Msg "----------------------------------------"
	"${HCPPIPEDIR}"/fMRIVolume/scripts/Compile_MATLAB_code.sh

	log_Msg "----------------------------------------"
	log_Msg "Compiling ICAFIX-related MATLAB code"
	log_Msg "----------------------------------------"
	"${HCPPIPEDIR}"/ICAFIX/scripts/Compile_MATLAB_code.sh

	log_Msg "----------------------------------------"
	log_Msg "Compiling MSMAll-related MATLAB code"
	log_Msg "----------------------------------------"
	"${HCPPIPEDIR}"/MSMAll/scripts/Compile_MATLAB_code.sh

	log_Msg "----------------------------------------"
	log_Msg "Compiling RestingStateStats-related MATLAB code"
	log_Msg "----------------------------------------"
	"${HCPPIPEDIR}"/RestingStateStats/scripts/Compile_MATLAB_code.sh

	log_Msg "----------------------------------------"
	log_Msg "Compiling tICA-related MATLAB code"
	log_Msg "----------------------------------------"
	"${HCPPIPEDIR}"/tICA/scripts/Compile_MATLAB_code.sh

	log_Msg "----------------------------------------"
	log_Msg "Compiling global script MATLAB code"
	log_Msg "----------------------------------------"
	"${HCPPIPEDIR}"/global/scripts/Compile_MATLAB_code.sh
}

# ------------------------------------------------------------------------------
# "Global" processing - everything above here should be in a function
# ------------------------------------------------------------------------------

# Verify that HCPPIPEDIR environment variable is set
if [ -z "${HCPPIPEDIR}" ]; then
	echo "${g_script_name}: ABORTING: HCPPIPEDIR environment variable must be set" 1>&2
	exit 1
fi

# Load function libraries
source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@" # Debugging functions; also sources log.shlib
log_Msg "HCPPIPEDIR: ${HCPPIPEDIR}"

# Verify that any other needed environment variables are set
log_Check_Env_Var MATLAB_HOME
log_Check_Env_Var HCPCIFTIRWDIR

# Invoke the main processing
main "$@"

