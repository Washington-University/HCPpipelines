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

#TSC: obsolete, this script no longer uses matlab, which was the only part that cared about CLUSTER
#g_cluster=${CLUSTER}
#TSC: don't test CLUSTER here, it only matters if we use compiled matlab, and there is already a better error message

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

	#--matlab-run-mode is now ignored, but still accepted, to make old scripts work without changes

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

#arguments: filename, output variable name
list_file_to_lookup()
{
    #bash arrays are 0-indexed, but since the components start at 1, we will just ignore the 0th position
    local file_contents=$(cat "$1")
    local component
    #older bash doesn't have "declare -g", which may be the only way to indirect to a global array from a function
    #so, use a hardcoded array name for the return, and copy from it afterwards
    unset lookup_result
    #bash does something weird if you skip indices, which ends up compacting when you do "${a[@]}"
    #so preinitialize
    #use 0 and 1, so we can use math syntax instead of empty string or "== 1"
    for ((i = 0; i < $2; ++i))
    do
        lookup_result[$i]=0
    done
    for component in ${file_contents}
    do
        lookup_result["${component}"]=1
    done
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

	echo "merging classifications start"

	list_file_to_lookup "${OriginalFixSignal}" "$NumICAs"
	orig_signal=("${lookup_result[@]}")
	list_file_to_lookup "${OriginalFixNoise}" "$NumICAs"
	orig_noise=("${lookup_result[@]}")

	list_file_to_lookup "${ReclassifyAsSignal}" "$NumICAs"
	reclass_signal=("${lookup_result[@]}")
	list_file_to_lookup "${ReclassifyAsNoise}" "$NumICAs"
	reclass_noise=("${lookup_result[@]}")

	fail=""
	hand_signal=""
	hand_noise=""
	training_labels=""
	for ((i = 1; i <= NumICAs; ++i))
	do
		if (( reclass_signal[i] || (orig_signal[i] && ! reclass_noise[i]) ))
		then
			if [[ "$hand_signal" ]]
			then
				hand_signal+=" $i"
			else
				hand_signal="$i"
			fi
		else
			if [[ "$hand_noise" ]]
			then
				hand_noise+=" $i"
				training_labels+=", $i"
			else
				hand_noise="$i"
				training_labels+="$i"
			fi
		fi
		#error checking
		if (( reclass_noise[i] && reclass_signal[i] ))
		then
			echo "Duplicate Component Error with Manual Classification on ICA: $i"
			fail=1
		fi
		if (( ! (orig_noise[i] || orig_signal[i]) ))
		then
			echo "Missing Component Error with Automatic Classification on ICA: $i"
			fail=1
		fi
		if (( orig_noise[i] && orig_signal[i] ))
		then
			echo "Duplicate Component Error with Automatic Classification on ICA: $i"
			fail=1
		fi
		#the hand check from the matlab version can't be tripped here without the above code being wrong
	done

	if [[ $fail ]]
	then
		echo "Sanity checks on input files failed, ABORTING"
		exit 1
	fi

	echo "$hand_signal" > "${HandSignalName}"
	echo "$hand_noise" > "${HandNoiseName}"
	echo "[$training_labels]" > "${TrainingLabelsName}"

	echo "merging classifications complete"
}

# Invoke the main to get things started
main $@



  

