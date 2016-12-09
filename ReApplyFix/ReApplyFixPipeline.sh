#!/bin/bash

# If any command exits with non-zero value, this script exits
set -e
g_script_name=`basename ${0}`

# ------------------------------------------------------------------------------
#  Load function libraries
# ------------------------------------------------------------------------------

source ${HCPPIPEDIR}/global/scripts/log.shlib # Logging related functions
log_SetToolName "${g_script_name}"

source ${HCPPIPEDIR}/global/scripts/fsl_version.shlib # Function for getting FSL version

#
# Function Description:
#  Show usage information for this script
#
usage()
{
	echo ""
	echo "  Usage: ${g_script_name} <options>"
	echo ""
	echo "  Options: [ ] = optional; < > = user supplied value"
	echo ""
	echo "   [--help] : show usage information and exit"
	echo " "
	echo "  TBW "
	echo " "
	echo ""
}

#
# Function Description:
#  Get the command line options for this script.
#  Shows usage information and exits if command line is malformed
#
get_options()
{
#Caret7_Command="${1}"   ${CARET7_DIR}/wb_command
#GitRepo="${2}"          ${HCPPIPEDIR}
#FixDir="${3}"           ${ICAFIX}

#StudyFolder="${4}"
#Subject="${5}"
#fMRIName="${6}"
#HighPass="${7}"
#RegName="${8}"

	local arguments=($@)

	# initialize global output variables
	unset g_path_to_study_folder     # StudyFolder
	unset g_subject                  # Subject
	unset g_fmri_name                # fMRIName
	unset g_high_pass                # HighPass
	unset g_reg_name                 # RegName
	unset g_low_res_mesh		 # LowResMesh

	# parse arguments
	local num_args=${#arguments[@]}
	local argument
	local index=0

	while [ ${index} -lt ${num_args} ]; do
		argument=${arguments[index]}

		case ${argument} in
			--help)
				usage
				exit 1
				;;
			--path=*)
				g_path_to_study_folder=${argument#*=}
				index=$(( index + 1 ))
				;;
			--study-folder=*)
				g_path_to_study_folder=${argument#*=}
				index=$(( index + 1 ))
				;;
			--subject=*)
				g_subject=${argument#*=}
				index=$(( index + 1 ))
				;;
			--fmri-name=*)
				g_fmri_name=${argument#*=}
				index=$(( index + 1 ))
				;;
			--high-pass=*)
				g_high_pass=${argument#*=}
				index=$(( index + 1 ))
				;;
			--reg-name=*)
				g_reg_name=${argument#*=}
				index=$(( index + 1 ))
				;;
			--low-res-mesh=*)
				g_low_res_mesh=${argument#*=}
				index=$(( index + 1 ))
				;;
			*)
				usage
				echo "ERROR: unrecognized option: ${argument}"
				echo ""
				exit 1
				;;
		esac
	done

	local error_count=0
	# check required parameters
	if [ -z "${g_path_to_study_folder}" ]; then
		echo "ERROR: path to study folder (--path= or --study-folder=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "path to study folder: ${g_path_to_study_folder}"
	fi

	if [ -z "${g_subject}" ]; then
		echo "ERROR: subject ID (--subject=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "subject ID (--subject=): ${g_subject}"
	fi

	if [ -z "${g_fmri_name}" ]; then
		echo "ERROR: fMRI Name (--fmri-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "fMRI Name: (--fmri-name=): ${g_fmri_name}"
	fi

	if [ -z "${g_high_pass}" ]; then
		echo "ERROR: High Pass (--high-pass=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "High Pass: (--high-pass=): ${g_high_pass}"
	fi

	if [ -z "${g_reg_name}" ]; then
		echo "ERROR: Reg Name (--reg-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Reg Name: (--reg-name=): ${g_reg_name}"
	fi

	if [ ${error_count} -gt 0 ]; then
		echo "For usage information, use --help"
		exit 1
	fi
}

show_tool_versions()
{
	# Show HCP pipelines version
	log_Msg "Showing HCP Pipelines version"
	cat ${HCPPIPEDIR}/version.txt

	# Show wb_command version
	log_Msg "Showing Connectome Workbench (wb_command) version"
	${CARET7DIR}/wb_command -version

	# Show fsl version
	log_Msg "Showing FSL version"
	fsl_version_get fsl_ver
	log_Msg "FSL version: ${fsl_ver}"
}

check_fsl_version()
{
	local fsl_version
	local fsl_version_array
	local fsl_primary_version
	local fsl_secondary_version
	local fsl_tertiary_version
	local version_status="OLD"

	# Get FSL version
	log_Msg "About to get FSL version"
	fsl_version_get fsl_ver
	log_Msg "Retrieved fsl_version: ${fsl_ver}"

	# Parse FSL version into primary, secondary, and tertiary parts
	fsl_version_array=(${fsl_ver//./ })
	
	fsl_primary_version="${fsl_version_array[0]}"
	fsl_primary_version=${fsl_primary_version//[!0-9]/}

	fsl_secondary_version="${fsl_version_array[1]}"
    fsl_secondary_version=${fsl_secondary_version//[!0-9]/}

    fsl_tertiary_version="${fsl_version_array[2]}"
    fsl_tertiary_version=${fsl_tertiary_version//[!0-9]/}

	# Determine whether we are using an "OLD" version (5.0.6 or older),
	# an "UNTESTED" version (5.0.7 or 5.0.8),
	# or a "NEW" version (5.0.9 or newer)

	log_Msg "fsl_primary_version: ${fsl_primary_version}"
	log_Msg "fsl_secondary_version: ${fsl_secondary_version}"
	log_Msg "fsl_tertiary_version: ${fsl_tertiary_version}"

	if [[ $(( ${fsl_primary_version} )) -lt 5 ]] ; then
		# e.g. 4.x.x
		log_Msg "fsl_primary_version -lt 5"
		version_status="OLD"
		log_Msg "version_status: ${version_status}"
	elif [[ $(( ${fsl_primary_version} )) -gt 5 ]] ; then
		# e.g. 6.x.x
		log_Msg "fsl_primary_version -gt 5"
		version_status="NEW"
		log_Msg "version_status: ${version_status}"
	else
		# e.g. 5.x.x
		if [[ $(( ${fsl_secondary_version} )) -gt 0 ]] ; then
			# e.g. 5.1.x
			log_Msg "fsl_secondary_version -gt 0"
			version_status="NEW"
			log_Msg "version_status: ${version_status}"
		else
			# e.g. 5.0.x
			if [[ $(( ${fsl_tertiary_version} )) -le 6 ]] ; then
				# e.g. 5.0.5 or 5.0.6
				log_Msg "fsl_tertiary_version -le 6"
				version_status="OLD"
				log_Msg "version_status: ${version_status}"
			elif [[ $(( ${fsl_tertiary_version} )) -le 8 ]] ; then
				# e.g. 5.0.7 or 5.0.8
				log_Msg "fsl_tertiary_version -le 8"
				version_status="UNTESTED"
				log_Msg "version_status: ${version_status}"
			else
				# e.g. 5.0.9, 5.0.10 ..
				log_Msg "fsl_tertiary_version 8 or greater"
				version_status="NEW"
				log_Msg "version_status: ${version_status}"
			fi

		fi

	fi

	if [ "${version_status}" == "OLD" ] ; then
		log_Msg "ERROR: The version of FSL in use (${fsl_version}) is incompatible with this script."
		log_Msg "ERROR: This script and the Matlab code invoked by it, use a behavior of FSL that was"
		log_Msg "ERROR: introduced in version 5.0.7 of FSL. You will need to upgrade to at least FSL"
		log_Msg "ERROR: version 5.0.7 for this script to work correctly. Note, however, that this script"
		log_Msg "ERROR: has not yet been testing using version 5.0.7 or 5.0.8 of FSL. Therefore, if"
		log_Msg "ERROR: you use either of those two versions of FSL, you will receive an \"Untested FSL"
		log_Msg "ERROR: version\" warning. But the script will continue to run."
		log_Msg "ERROR: Since the current version is guaranteed to give unexpected results, we are"
		log_Msg "ERROR: aborting this run of: ${g_script_name}"
		exit 1

	elif [ "${version_status}" == "UNTESTED" ]; then
		log_Msg "WARNING: The version of FSL in use (${fsl_version}) should work with this script,"
		log_Msg "WARNING: but is untested.  This script and the Matlab code invoked by it, use a behavior"
		log_Msg "WARNING: that was introduced in version 5.0.7 of FSL. However, this script has not been"
		log_Msg "WARNING: tested with any version of FSL older than version 5.0.9. This script should"
		log_Msg "WARNING: continue to run after this warning. To avoid this warning in the future, upgrade"
		log_Msg "WARNING: to FSL version 5.0.9 or newer."

	fi
}

main() 
{
	# Get command line options
	get_options $@

	show_tool_versions

	check_fsl_version

	local Caret7_Command="${CARET7DIR}/wb_command"
	log_Msg "Caret7_Command: ${Caret7_Command}"

	#GitRepo="${2}"
	#FixDir="${3}"

	local StudyFolder="${g_path_to_study_folder}"
	log_Msg "StudyFolder: ${StudyFolder}"
	
	local Subject="${g_subject}"
	log_Msg "Subject: ${Subject}"
	
	local fMRIName="${g_fmri_name}"
	log_Msg "fMRIName: ${fMRIName}"

	local HighPass="${g_high_pass}"
	log_Msg "HighPass: ${HighPass}"

	local RegName="${g_reg_name}"
	log_Msg "RegName: ${RegName}"

	if [ ${RegName} != "NONE" ] ; then
		RegString="_${RegName}"
	else
		RegString=""
	fi

	if [ ! -z ${g_low_res_mesh} ] && [ ${g_low_res_mesh} != "32" ]; then
		RegString="${RegString}.${g_low_res_mesh}k"
	fi

	log_Msg "RegString: ${RegString}"

	export FSL_FIX_CIFTIRW="${HCPPIPEDIR}/ReApplyFix/scripts"
	export FSL_FIX_WBC="${Caret7_Command}"
	export FSL_MATLAB_PATH="${FSLDIR}/etc/matlab"

#  #Make appropriate files if they don't exist
#  #Call matlab
#  ML_PATHS="addpath('${FixDir}'); addpath('${FSL_MATLAB_PATH}'); addpath('${FSL_FIX_CIFTIRW}');"

	local aggressive=0
	local domot=1
	local hp=${HighPass}
	local fixlist=".fix"
	local fmri_orig="${fMRIName}"
	local fmri=${fMRIName}

	DIR=`pwd`
	cd ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}.ica

	if [ -f ../${fmri_orig}_Atlas${RegString}.dtseries.nii ] ; then
		log_Msg "FOUND FILE: ../${fmri_orig}_Atlas${RegString}.dtseries.nii"
		log_Msg "Performing imln"
		$FSLDIR/bin/imln ../${fmri_orig}_Atlas${RegString}.dtseries.nii Atlas.dtseries.nii

		
		log_Msg "START: Showing linked files"
		ls -l ../${fmri_orig}_Atlas${RegString}.dtseries.nii
		ls -l Atlas.dtseries.nii
		log_Msg "END: Showing linked files"
	fi

	$FSLDIR/bin/imln ../$fmri filtered_func_data

	mkdir -p mc
	if [ -f ../Movement_Regressors.txt ] ; then
		cat ../Movement_Regressors.txt | awk '{ print $4 " " $5 " " $6 " " $1 " " $2 " " $3}' > mc/prefiltered_func_data_mcf.par
	else
		log_Msg "ERROR: Movement_Regressors.txt not retrieved properly." 
		exit -1
	fi 

	# Use Compiled Matlab
	local matlab_exe="${HCPPIPEDIR}"
	matlab_exe+="/ReApplyFix/scripts/Compiled_fix_3_clean_no_vol/distrib/run_fix_3_clean_no_vol.sh"

	# TBD: Use environment variable instead of fixed path!
	local matlab_compiler_runtime
	if [ "${CLUSTER}" = "1.0" ]; then
		matlab_compiler_runtime="/export/matlab/R2013a/MCR"
	elif [ "${CLUSTER}" = "2.0" ]; then
		matlab_compiler_runtime="/export/matlab/MCR/R2013a/v81"
	else
		log_Msg "ERROR: This script currently uses hardcoded paths to the Matlab compiler runtime."
		log_Msg "ERROR: These hardcoded paths are specific to the Washington University CHPC cluster environment."
		log_Msg "ERROR: This is a known bad practice that we haven't had time to correct just yet."
		log_Msg "ERROR: To correct this for your environment, find this error message in the script and"
		log_Msg "ERROR: either adjust the setting of the matlab_compiler_runtime variable in the"
		log_Msg "ERROR: statements above, or set the value of the matlab_compiler_runtime variable"
		log_Msg "ERROR: using an environment variable's value."
	fi

	local matlab_function_arguments="'${fixlist}' ${aggressive} ${domot} ${hp}"
	
	local matlab_logging=">> ${StudyFolder}/${Subject}_${fMRIName}_${HighPass}${RegString}.matlab.log 2>&1"

	matlab_cmd="${matlab_exe} ${matlab_compiler_runtime} ${matlab_function_arguments} ${matlab_logging}"

	# --------------------------------------------------------------------------------
	log_Msg "Run matlab command: ${matlab_cmd}"
	# --------------------------------------------------------------------------------
	echo "${matlab_cmd}" | bash
	echo $?


#matlab -nojvm -nodisplay -nosplash <<M_PROG
#${ML_PATHS} fix_3_clean_no_vol('${fixlist}',${aggressive},${domot},${hp});
#M_PROG
#echo "${ML_PATHS} fix_3_clean_no_vol('${fixlist}',${aggressive},${domot},${hp});"

	cd ${DIR}

	fmri="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}"
	fmri_orig="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}"
	if [ -f ${fmri}.ica/Atlas_clean.dtseries.nii ] ; then
		/bin/mv ${fmri}.ica/Atlas_clean.dtseries.nii ${fmri_orig}_Atlas${RegString}_hp${hp}_clean.dtseries.nii
	fi

	$FSLDIR/bin/immv ${fmri}.ica/filtered_func_data_clean ${fmri}_clean
}

#
# Invoke the main function to get things started
#
main $@
