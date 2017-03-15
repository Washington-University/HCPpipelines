#!/bin/bash

#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # ReApplyFixPipeline.sh
#
# ## Copyright Notice
#
# Copyright (C) 2015-2017 The Human Connectome Project
#
# * Washington University in St. Louis
# * University of Minnesota
# * Oxford University
#
# ## Author(s)
#
# * Matthew F. Glasser, Department of Anatomy and Neurobiology, Washington University in St. Louis
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

set -e # If any command exits with non-zero value, this script exits

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

source "${HCPPIPEDIR}/global/scripts/log.shlib" # Logging related functions
log_Msg "HCPPIPEDIR: ${HCPPIPEDIR}"

source "${HCPPIPEDIR}/global/scripts/fsl_version.shlib" # Function for getting FSL version

# ------------------------------------------------------------------------------
#  Verify other needed environment variables are set
# ------------------------------------------------------------------------------

if [ -z "${CARET7DIR}" ]; then
	log_Err_Abort "CARET7DIR environment variable must be set"
fi
log_Msg "CARET7DIR: ${CARET7DIR}"


if [ -z "${FSLDIR}" ]; then
	log_Err_Abort "FSLDIR environment variable must be set"
fi
log_Msg "FSLDIR: ${FSLDIR}"

# ------------------------------------------------------------------------------
#  Show usage information for this script
# ------------------------------------------------------------------------------

usage()
{
	local script_name
	script_name=$(basename "${0}")

	cat <<EOF

${script_name}

Usage: ${script_name} PARAMETER...

PARAMETERs are [ ] = optional; < > = user supplied value

  [--help] : show usage information and exit
   --path=<path to study folder> OR --study-folder=<path to study folder>
   --subject=<subject ID>
   --fmri-name=TBW
   --high-pass=TBW
   --reg-name=TBW
   --low-res-mesh=TBW
  [--matlab-run-mode={0, 1}] defaults to 0 (Compiled MATLAB)
     0 = Use compiled MATLAB
     1 = Use interpreted MATLAB

EOF
}

# ------------------------------------------------------------------------------
#  Get the command line options for this script.
# ------------------------------------------------------------------------------

get_options()
{
	local arguments=($@)

	# initialize global output variables
	unset g_path_to_study_folder	# StudyFolder
	unset g_subject					# Subject
	unset g_fmri_name				# fMRIName
	unset g_high_pass				# HighPass
	unset g_reg_name				# RegName
	unset g_low_res_mesh			# LowResMesh
	unset g_matlab_run_mode             

	# set default values
	g_matlab_run_mode=0

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
	  		--matlab-run-mode=*)
				g_matlab_run_mode=${argument#*=}
				index=$(( index + 1 ))
				;;
			*)
				usage
				log_Err_Abort "unrecognized option: ${argument}"
				;;
		esac
	done

	local error_count=0
	
	# check required parameters
	if [ -z "${g_path_to_study_folder}" ]; then
		log_Err "path to study folder (--path= or --study-folder=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "path to study folder: ${g_path_to_study_folder}"
	fi

	if [ -z "${g_subject}" ]; then
		log_Err "subject ID (--subject=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "subject ID (--subject=): ${g_subject}"
	fi

	if [ -z "${g_fmri_name}" ]; then
		log_Err "fMRI Name (--fmri-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "fMRI Name: (--fmri-name=): ${g_fmri_name}"
	fi

	if [ -z "${g_high_pass}" ]; then
		log_Err "High Pass (--high-pass=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "High Pass: (--high-pass=): ${g_high_pass}"
	fi

	if [ -z "${g_reg_name}" ]; then
		log_Err "Reg Name (--reg-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Reg Name: (--reg-name=): ${g_reg_name}"
	fi
	
	if [ -z "${g_matlab_run_mode}" ]; then
		log_Err "MATLAB run mode value (--matlab-run-mode=) required"
		error_count=$(( error_count + 1 ))
	else
		case ${g_matlab_run_mode} in 
			0)
				log_Msg "g_matlab_run_mode: ${g_matlab_run_mode}"
				;;
			1)
				log_Msg "g_matlab_run_mode: ${g_matlab_run_mode}"
				;;
			*)
				log_Err "MATLAB run mode value must be 0 or 1"
				error_count=$(( error_count + 1 ))
				;;
		esac
	fi
	
	if [ ${error_count} -gt 0 ]; then
		log_Err_Abort "For usage information, use --help"
	fi
}

# ------------------------------------------------------------------------------
#  Show/Document Tool Versions
# ------------------------------------------------------------------------------

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





tbb - ici - tbb









check_fsl_version_new()
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

check_fsl_version_old()
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

	if [ "${version_status}" == "NEW" ] || [ "${version_status}" == "UNTESTED" ] ; then
		log_Msg "ERROR: The version of FSL in use (${fsl_version}) is incompatible with this script."
		log_Msg "ERROR: This script and the Matlab code invoked by it, use a behavior of FSL version"
		log_Msg "ERROR: 5.0.6 or earlier."
		log_Msg "ERROR: Since the current version is guaranteed to give unexpected results, we are"
		log_Msg "ERROR: aborting this run of: ${g_script_name}"
		exit 1
	fi
}

main() 
{
	# Get command line options
	get_options $@
	
	show_tool_versions
	
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

	if [ ! -e ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}.ica/HandNoise.txt ] ; then
		# If we ARE NOT using hand reclassification, we perform an FSL version check that ensures that FSL v5.0.7 or later is being used.
		check_fsl_version_new
	else
		# If we ARE using hand reclassification, we perform an FSL version check that ensures that FSL v5.0.6 or earlier is being used.
		check_fsl_version_old
	fi

	# Make appropriate files if they don't exist

	local aggressive=0
	local domot=1
	local hp=${HighPass}
	
	if [ ! -e ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}.ica/HandNoise.txt ] ; then
		local fixlist=".fix"
	else
		local fixlist="HandNoise.txt"
	fi
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

	case ${g_matlab_run_mode} in
		0)
			# Use Compiled Matlab

			if [ -z "${MATLAB_COMPILER_RUNTIME}" ] ; then
				log_Msg "ERROR: To use Compiled Matlab, MATLAB_COMPILER_RUNTIME environment variable must be set"
				exit 1
			fi

			if [ ! -e ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}.ica/HandNoise.txt ] ; then
				local matlab_exe="${HCPPIPEDIR}"
				matlab_exe+="/ReApplyFix/scripts/Compiled_fix_3_clean_no_vol/distrib/run_fix_3_clean_no_vol.sh"

				matlab_compiler_runtime=${MATLAB_COMPILER_RUNTIME}

				local matlab_function_arguments="'${fixlist}' ${aggressive} ${domot} ${hp}"

				local matlab_logging=">> ${StudyFolder}/${Subject}_${fMRIName}_${HighPass}${RegString}.matlab.log 2>&1"
				
				matlab_cmd="${matlab_exe} ${matlab_compiler_runtime} ${matlab_function_arguments} ${matlab_logging}"

				# --------------------------------------------------------------------------------
				log_Msg "Run matlab command: ${matlab_cmd}"
				# --------------------------------------------------------------------------------
				echo "${matlab_cmd}" | bash
				echo $?
			else
				local matlab_exe="${HCPPIPEDIR}"
				matlab_exe+="/ReApplyFix/scripts/Compiled_fix_3_clean/distrib/run_fix_3_clean.sh"

				matlab_compiler_runtime=${MATLAB_COMPILER_RUNTIME}

				local matlab_function_arguments="'${fixlist}' ${aggressive} ${domot} ${hp}"
				
				local matlab_logging=">> ${StudyFolder}/${Subject}_${fMRIName}_${HighPass}${RegString}.matlab.log 2>&1"

				matlab_cmd="${matlab_exe} ${matlab_compiler_runtime} ${matlab_function_arguments} ${matlab_logging}"

				# --------------------------------------------------------------------------------
				log_Msg "Run matlab command: ${matlab_cmd}"
				# --------------------------------------------------------------------------------
				echo "${matlab_cmd}" | bash
				echo $?
			fi
			;;
		1)
			#  Call matlab
			ML_PATHS="addpath('${FSL_MATLAB_PATH}'); addpath('${FSL_FIX_CIFTIRW}');"
			if [ ! -e ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}.ica/HandNoise.txt ] ; then
				matlab -nojvm -nodisplay -nosplash <<M_PROG
${ML_PATHS} fix_3_clean_no_vol('${fixlist}',${aggressive},${domot},${hp});
M_PROG
				echo "${ML_PATHS} fix_3_clean_no_vol('${fixlist}',${aggressive},${domot},${hp});"
			else
				matlab -nojvm -nodisplay -nosplash <<M_PROG
${ML_PATHS} fix_3_clean('${fixlist}',${aggressive},${domot},${hp});
M_PROG
				echo "${ML_PATHS} fix_3_clean('${fixlist}',${aggressive},${domot},${hp});"
			fi
			;;
	esac

	fmri="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}"
	fmri_orig="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}"
	if [ -f ${fmri}.ica/Atlas_clean.dtseries.nii ] ; then
		/bin/mv ${fmri}.ica/Atlas_clean.dtseries.nii ${fmri_orig}_Atlas${RegString}_hp${hp}_clean.dtseries.nii
	fi
	
	if [ -e ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}.ica/HandNoise.txt ] ; then
		$FSLDIR/bin/immv ${fmri}.ica/filtered_func_data_clean ${fmri}_clean
	fi
	
	cd ${DIR}
}

#
# Invoke the main function to get things started
#
main $@
