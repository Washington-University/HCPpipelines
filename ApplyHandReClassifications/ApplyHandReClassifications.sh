#!/bin/bash

# if any commands exit with non-zero value, this script exits
set -e

# Set global variables from environment variables
g_script_name=`basename ${0}`

g_hcppipedir=${HCPPIPEDIR}
if [ -z "${g_hcppipedir}" ]; then
	echo "ERROR: HCPPIPEDIR must be set!"
	exit 1
fi

g_fsl_dir=${FSLDIR}
if [ -z "${g_fsl_dir}" ]; then
	echo "ERROR: FSLDIR must be set!"
	exit 1
fi

g_cluster=${CLUSTER}
if [ -z "${g_cluster}" ]; then
	echo "ERROR: CLUSTER must be set!"
	exit 1
fi

# load function libraries

# Logging related functions
source ${g_hcppipedir}/global/scripts/log.shlib
log_SetToolName "${g_script_name}"

# Function for getting FSL version
source ${g_hcppipedir}/global/scripts/fsl_version.shlib 

usage()
{
	cat << EOF

Apply Hand Reclassifications of Noise and Signal components using the ReclassifyAsNoise.txt 
and ReclassifyAsSignal.txt input files.

Usage: ${g_script_name} PARAMETER..."

PARAMETERs are: [ ] = optional; < > = user supplied value
  [--help] : show usage information and exite with non-zero return code
   --path=<path to study folder> OR --study-folder=<path to study folder>
   --subject=<subject ID>
   --fmri-name=<fMRI name>
   --high-pass=<high pass>
  [--matlab-run-mode={0, 1}] defaults to 0 (Compiled Matlab)
    0 = Use compiled Matlab
    1 = Use Matlab

EOF
}

get_options()
{
	local arguments=($@)

	# initialize global output variables
	unset g_path_to_study_folder
	unset g_subject
	unset g_fmri_name
	unset g_high_pass
	g_matlab_run_mode=0

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
			--matlab-run-mode=*)
				g_matlab_run_mode=${argument#*=}
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
		log_Msg "g_path_to_study_folder: ${g_path_to_study_folder}"
	fi

	if [ -z "${g_subject}" ]; then
		echo "ERROR: subject ID required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_subject: ${g_subject}"
	fi

	if [ -z "${g_fmri_name}" ]; then
		echo "ERROR: fMRI name required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_fmri_name: ${g_fmri_name}"
	fi

	if [ -z "${g_high_pass}" ]; then
		echo "ERROR: high pass required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_high_pass: ${g_high_pass}"
	fi

	if [ -z "${g_matlab_run_mode}" ]; then
		echo "ERROR: matlab run mode value (--matlab-run-mode=) required"
		error_count=$(( error_count + 1 ))
	else
		case ${g_matlab_run_mode} in 
			0)
				;;
			1)
				;;
			*)
				echo "ERROR: matlab run mode value must be 0 or 1"
				error_count=$(( error_count + 1 ))
				;;
		esac
	fi

	if [ ${error_count} -gt 0 ]; then
		echo "For usage information, use --help"
		exit 1
	fi
}

show_tool_versions()
{
	# Show HCP Pipelines Version
	log_Msg "Showing HCP Pipelines version"
	cat ${g_hcppipedir}/version.txt

	# Show FSL version
	log_Msg "Showing FSL version"
	fsl_version_get fsl_ver
	log_Msg "FSL version: ${fsl_ver}"
}

main()
{
	get_options $@
	show_tool_versions

	# Naming Conventions
	AtlasFolder="${g_path_to_study_folder}/${g_subject}/MNINonLinear"
	log_Msg "AtlasFolder: ${AtlasFolder}"

	ResultsFolder="${AtlasFolder}/Results/${g_fmri_name}"
	log_Msg "ResultsFolder: ${ResultsFolder}"

	ICAFolder="${ResultsFolder}/${g_fmri_name}_hp${g_high_pass}.ica/filtered_func_data.ica"
	log_Msg "ICAFolder: ${ICAFolder}"

	FIXFolder="${ResultsFolder}/${g_fmri_name}_hp${g_high_pass}.ica"
	log_Msg "FIXFolder: ${FIXFolder}"
	
	OriginalFixSignal="${FIXFolder}/Signal.txt"
	log_Msg "OriginalFixSignal: ${OriginalFixSignal}"

	OriginalFixNoise="${FIXFolder}/Noise.txt"
	log_Msg "OriginalFixNoise: ${OriginalFixNoise}"

	ReclassifyAsSignal="${ResultsFolder}/ReclassifyAsSignal.txt"
	log_Msg "ReclassifyAsSignal: ${ReclassifyAsSignal}"

	ReclassifyAsNoise="${ResultsFolder}/ReclassifyAsNoise.txt"
	log_Msg "ReclassifyAsNoise: ${ReclassifyAsNoise}"

	HandSignalName="${FIXFolder}/HandSignal.txt"
	log_Msg "HandSignalName: ${HandSignalName}"

	HandNoiseName="${FIXFolder}/HandNoise.txt"
	log_Msg "HandNoiseName: ${HandNoiseName}"

	TrainingLabelsName="${FIXFolder}/hand_labels_noise.txt"
	log_Msg "TrainingLabelsName: ${TrainingLabelsName}"

	# Retrieve number of ICAs
	NumICAs=`${g_fsl_dir}/bin/fslval ${ICAFolder}/melodic_oIC.nii.gz dim4`
	log_Msg "NumICAs: ${NumICAs}"

	# Merge/edit Signal.txt with ReclassifyAsSignal.txt and ReclassifyAsNoise.txt
	case ${g_matlab_run_mode} in
		0)
			# Use Compiled Matlab
			matlab_exe="${g_hcppipedir}"
			matlab_exe+="/ApplyHandReClassifications/MergeEditClassifications/distrib/run_MergeEditClassifications.sh"

			# TBD: Use environment variable instead of fixed path
			if [ "${CLUSTER}" = "2.0" ]; then
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

			matlab_function_arguments="'${OriginalFixSignal}' '${OriginalFixNoise}' '${ReclassifyAsSignal}' '${ReclassifyAsNoise}' '${HandSignalName}' '${HandNoiseName}' '${TrainingLabelsName}' ${NumICAs}"

			matlab_logging=">> ${g_path_to_study_folder}/${g_subject}_${g_fmri_name}.MergeEditClassifications.matlab.log 2>&1"

			matlab_cmd="${matlab_exe} ${matlab_compiler_runtime} ${matlab_function_arguments} ${matlab_logging}"

			log_Msg "Run matlab command: ${matlab_cmd}"

			echo "${matlab_cmd}" | bash
			echo $?

			;;

		1)
			# Use Matlab

			g_matlab_home=${MATLAB_HOME}
			if [ -z "${g_matlab_home}" ]; then
				echo "ERROR: MATLAB_HOME must be set!"
				exit 1
			fi
			
			${g_matlab_home}/bin/matlab <<M_PROG
MergeEditClassifications('${OriginalFixSignal}','${OriginalFixNoise}','${ReclassifyAsSignal}','${ReclassifyAsNoise}','${HandSignalName}','${HandNoiseName}','${TrainingLabelsName}',${NumICAs});
M_PROG

			echo "MergeEditClassifications('${OriginalFixSignal}','${OriginalFixNoise}','${ReclassifyAsSignal}','${ReclassifyAsNoise}','${HandSignalName}','${HandNoiseName}','${TrainingLabelsName}',${NumICAs});"
			;;

		*)
			log_Msg "ERROR: Unrecognized Matlab run mode value: ${g_matlab_run_mode}"
			exit 1

	esac
}

# Invoke the main to get things started
main $@



  

