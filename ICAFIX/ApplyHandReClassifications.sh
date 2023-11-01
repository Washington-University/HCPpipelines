#!/bin/bash

# ------------------------------------------------------------------------------
#  Show usage information for this script
# ------------------------------------------------------------------------------


set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

# Load function libraries
source "${HCPPIPEDIR}/global/scripts/fsl_version.shlib"        # Functions for getting FSL version
source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"

opts_SetScriptDescription "Apply Hand Reclassifications of Noise and Signal components from FIX using the ReclassifyAsNoise.txt and ReclassifyAsSignal.txt input files. Generates HandNoise.txt and HandSignal.txt as output. Script does NOT reapply the FIX cleanup. For that, use the ReApplyFix scripts."

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "path to study folder" "--path"

opts_AddMandatory '--subject' 'Subject' 'id' "subject ID"

opts_AddMandatory '--fmri-name' 'fMRIName' 'string' "fMRI name"

opts_AddMandatory '--high-pass' 'HighPass' 'amount' "high-pass filter used in ICA+FIX"

##Optional Args 
## MATLAB RUN MODE IS NOT ACTUALLY USED
opts_AddOptional '--matlab-run-mode' 'g_matlab_run_mode' '0, 1, 2' "defaults to ${G_DEFAULT_MATLAB_RUN_MODE} 
     0 = Use compiled MATLAB
     1 = Use interpreted MATLAB
     2 = Use octave" "${G_DEFAULT_MATLAB_RUN_MODE}"

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

log_Check_Env_Var FSLDIR
# Show HCP Pipelines Version
log_Msg "Showing HCP Pipelines version"
"${HCPPIPEDIR}"/show_version --short

# Show FSL version
log_Msg "Showing FSL version"
fsl_version_get fsl_ver
log_Msg "FSL version: ${fsl_ver}"

# show_usage()
# {
# 	cat << EOF

# ${g_script_name}: Apply Hand Reclassifications of Noise and Signal components
# from FIX using the ReclassifyAsNoise.txt and ReclassifyAsSignal.txt input files.

# Generates HandNoise.txt and HandSignal.txt as output.
# Script does NOT reapply the FIX cleanup.
# For that, use the ReApplyFix scripts.

# Usage: ${g_script_name} PARAMETER..."

# PARAMETERs are: [ ] = optional; < > = user supplied value
#   [--help] : show usage information and exit
#    --path=<path to study folder> OR --study-folder=<path to study folder>
#    --subject=<subject ID>
#    --fmri-name=<fMRI name>
#    --high-pass=<high-pass filter used in ICA+FIX>

# EOF
# }

# ------------------------------------------------------------------------------
#  Get the command line options for this script.
# ------------------------------------------------------------------------------
# get_options()
# {
# 	local arguments=($@)

# 	# initialize global output variables
# 	unset p_StudyFolder
# 	unset p_Subject
# 	unset p_fMRIName
# 	unset p_HighPass
# 	g_matlab_run_mode=0

# 	# parse arguments
# 	local num_args=${#arguments[@]}
# 	local argument
# 	local index=0

# 	while [ ${index} -lt ${num_args} ]; do
# 		argument=${arguments[index]}

# 		case ${argument} in
# 			--help)
# 				show_usage
# 				exit 0
# 				;;
# 			--path=*)
# 				p_StudyFolder=${argument#*=}
# 				index=$(( index + 1 ))
# 				;;
# 			--study-folder=*)
# 				p_StudyFolder=${argument#*=}
# 				index=$(( index + 1 ))
# 				;;
# 			--subject=*)
# 				p_Subject=${argument#*=}
# 				index=$(( index + 1 ))
# 				;;
# 			--fmri-name=*)
# 				p_fMRIName=${argument#*=}
# 				index=$(( index + 1 ))
# 				;;
# 			--high-pass=*)
# 				p_HighPass=${argument#*=}
# 				index=$(( index + 1 ))
# 				;;
# 			--matlab-run-mode=*)
# 				g_matlab_run_mode=${argument#*=}
# 				index=$(( index + 1 ))
# 				;;
# 			*)
# 				show_usage
# 				log_Err_Abort "unrecognized option: ${argument}"
# 				;;
# 		esac
# 	done

# 	local error_count=0

# 	# check required parameters
# 	if [ -z "${p_StudyFolder}" ]; then
# 		log_Err "Study Folder (--path= or --study-folder=) required"
# 		error_count=$(( error_count + 1 ))
# 	else
# 		log_Msg "p_StudyFolder: ${p_StudyFolder}"
# 	fi

# 	if [ -z "${p_Subject}" ]; then
# 		log_Err "Subject ID (--subject=) required"
# 		error_count=$(( error_count + 1 ))
# 	else
# 		log_Msg "p_Subject: ${p_Subject}"
# 	fi

# 	if [ -z "${p_fMRIName}" ]; then
# 		log_Err "fMRI Name (--fmri-name=) required"
# 		error_count=$(( error_count + 1 ))
# 	else
# 		log_Msg "p_fMRIName: ${p_fMRIName}"
# 	fi

# 	if [ -z "${p_HighPass}" ]; then
# 		log_Err "High Pass: (--high-pass=) required"
# 		error_count=$(( error_count + 1 ))
# 	else
# 		log_Msg "p_HighPass: ${p_HighPass}"
# 	fi

# 	#--matlab-run-mode is now ignored, but still accepted, to make old scripts work without changes

# 	if [ ${error_count} -gt 0 ]; then
# 		log_Err_Abort "For usage information, use --help"
# 	fi
# }

# ------------------------------------------------------------------------------
#  Show Tool Versions
# ------------------------------------------------------------------------------

# show_tool_versions()
# {
# 	# Show HCP Pipelines Version
# 	log_Msg "Showing HCP Pipelines version"
# 	"${HCPPIPEDIR}"/show_version --short

# 	# Show FSL version
# 	log_Msg "Showing FSL version"
# 	fsl_version_get fsl_ver
# 	log_Msg "FSL version: ${fsl_ver}"
# }

# ------------------------------------------------------------------------------
#  List lookup helper function for this script
# ------------------------------------------------------------------------------

#arguments: filename, numICAs
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

# ------------------------------------------------------------------------------
#  Main processing of script.
# ------------------------------------------------------------------------------

# main()
# {
#get_options $@
show_tool_versions

# NOTE: HighPass flag may be "pd*", if polynomial detrending was requested in 
# hcp_fix_multi_run (not supported in hcp_fix currently)

if [[ "${HighPass}" == pd* ]]; then
	hpNum=${HighPass:2}
else
	hpNum=${HighPass}
fi

# Confirm that $hpNum is a valid numeric
if ! [[ "${hpNum}" =~ ^[-]?[0-9]+$ ]]; then
	log_Err_Abort "Invalid value for --high-pass (${HighPass})"
fi

# If HighPass < 0, then no high-pass was applied and directories/filenames
# will not include an "_hp" string
if (( hpNum < 0 )); then
	hpStr=""
else
	hpStr="_hp${HighPass}"
fi

# Naming Conventions
AtlasFolder="${StudyFolder}/${Subject}/MNINonLinear"
log_Msg "AtlasFolder: ${AtlasFolder}"

ResultsFolder="${AtlasFolder}/Results/${fMRIName}"
log_Msg "ResultsFolder: ${ResultsFolder}"

ICAFolder="${ResultsFolder}/${fMRIName}${hpStr}.ica/filtered_func_data.ica"
log_Msg "ICAFolder: ${ICAFolder}"

FIXFolder="${ResultsFolder}/${fMRIName}${hpStr}.ica"
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
NumICAs=`${FSLDIR}/bin/fslval ${ICAFolder}/melodic_oIC.nii.gz dim4`
log_Msg "NumICAs: ${NumICAs}"

log_Msg "merging classifications start"

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

# Make sure that there is something to do (i.e., ReclassifyAs*.txt files are not BOTH empty)
if (( ! ${#reclass_signal[@]} && ! ${#reclass_noise[@]} ))
then
	log_Warn "${ReclassifyAsNoise} and ${ReclassifyAsSignal} are both empty; nothing to do"
	log_Msg "Completed!"
	exit
fi

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
		log_Msg "Duplicate Component Error with Manual Classification on ICA: $i"
		fail=1
	fi
	if (( ! (orig_noise[i] || orig_signal[i]) ))
	then
		log_Msg "Missing Component Error with Automatic Classification on ICA: $i"
		fail=1
	fi
	if (( orig_noise[i] && orig_signal[i] ))
	then
		log_Msg "Duplicate Component Error with Automatic Classification on ICA: $i"
		fail=1
	fi
	#the hand check from the matlab version can't be tripped here without the above code being wrong
done

if [[ $fail ]]
then
	log_Err_Abort "Sanity checks on input files failed"
fi

echo "$hand_signal" > "${HandSignalName}"
echo "$hand_noise" > "${HandNoiseName}"
echo "[$training_labels]" > "${TrainingLabelsName}"

log_Msg "merging classifications complete"
log_Msg "Completed!"

# }

# ------------------------------------------------------------------------------
#  "Global" processing - everything above here should be in a function
# ------------------------------------------------------------------------------

# # Set global variables
# g_script_name=$(basename "${0}")

# # Allow script to return a Usage statement, before any other output
# if [ "$#" = "0" ]; then
#     show_usage
#     exit 1
# fi

# # Verify that HCPPIPEDIR environment variable is set
# if [ -z "${HCPPIPEDIR}" ]; then
#     echo "${g_script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
#     exit 1
# fi

# # Load function libraries
# source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
# source ${HCPPIPEDIR}/global/scripts/opts.shlib                 # Command line option functions
# source "${HCPPIPEDIR}/global/scripts/fsl_version.shlib"        # Functions for getting FSL version

# opts_ShowVersionIfRequested $@

# if opts_CheckForHelpRequest $@; then
# 	show_usage
# 	exit 0
# fi

# ${HCPPIPEDIR}/show_version

# Verify required environment variables are set and log value
# log_Check_Env_Var HCPPIPEDIR
# log_Check_Env_Var FSLDIR

# Invoke the 'main' function to get things started
# main $@



  

