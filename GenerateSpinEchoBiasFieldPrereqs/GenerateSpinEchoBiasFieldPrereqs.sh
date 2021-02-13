#!/bin/bash

# ------------------------------------------------------------------------------
#  Usage Description Function
# ------------------------------------------------------------------------------

g_script_name=`basename ${0}`

show_usage() {
	cat <<EOF

${g_script_name}: Generate Spin Echo Bias Field Prerequisites

Usage: ${g_script_name} [options]

Usage information To Be Written

EOF
}

# Allow script to return a Usage statement, before any other output or checking
if [ "$#" = "0" ]; then
	show_usage
	exit 1
fi

# ------------------------------------------------------------------------------
#  Check that HCPPIPEDIR is defined and Load Function Libraries
# ------------------------------------------------------------------------------

if [ -z "${HCPPIPEDIR}" ]; then
  echo "${script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
  exit 1
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source ${HCPPIPEDIR}/global/scripts/opts.shlib                 # Command line option functions

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
	show_usage
	exit 0
fi

${HCPPIPEDIR}/show_version

log_Debug_On

# ------------------------------------------------------------------------------
#  Verify required environment variables are set and log value
# ------------------------------------------------------------------------------

log_Check_Env_Var HCPPIPEDIR

# ------------------------------------------------------------------------------
#  Support Functions
# ------------------------------------------------------------------------------

get_options() 
{
	local arguments=($@)

	# initialize global output variables
	unset g_path_to_study_folder     # StudyFolder
	unset g_subject                  # Subject
	unset g_rfmri_names              # rfMRINames - @ delimited
	unset g_tfmri_names              # tfMRINames - @ delimited

	# parse arguments
	local num_args=${#arguments[@]}
	local argument
	local index=0

	while [ ${index} -lt ${num_args} ]; do
		argument=${arguments[index]}

		case ${argument} in
			--help)
				show_usage
				exit 0
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
			--rfmri-names=*)
				g_rfmri_names=${argument#*=}
				index=$(( index + 1 ))
				;;
			--tfmri-names=*)
				g_tfmri_names=${argument#*=}
				index=$(( index + 1 ))
				;;
			*)
				show_usage
				log_Err_Abort "unrecognized option: ${argument}"
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
		echo "ERROR: subject ID (--subject=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_subject: ${g_subject}"
	fi

	if [ -z "${g_rfmri_names}" ]; then
		echo "ERROR: list of resting state scans (--rfmri-names=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_rfmri_names: ${g_rfmri_names}"
	fi

	if [ -z "${g_tfmri_names}" ]; then
		echo "ERROR: list of task scans (--tfmri-names=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_tfmri_names: ${g_tfmri_names}"
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
	"${HCPPIPEDIR}"/show_version --short
}

# ------------------------------------------------------------------------------
#  Main Function
# ------------------------------------------------------------------------------

main()
{
	# Get command line options
	get_options $@

	# Show the versions of tools used
	show_tool_versions

	StudyFolder=${g_path_to_study_folder}
	log_Msg "StudyFolder: ${StudyFolder}"

	Subject=${g_subject}
	log_Msg "Subject: ${Subject}"


	rfMRINames=${g_rfmri_names}
	rfMRINames=`echo "$rfMRINames" | sed s/"@"/" "/g`
	if [ "${rfMRINames}" = "NONE" ] ; then
		rfMRINames=""
	fi
	log_Msg "After delimiter substitution, rfMRINames: ${rfMRINames}"

	tfMRINames=${g_tfmri_names}
	tfMRINames=`echo "$tfMRINames" | sed s/"@"/" "/g`
	if [ "${tfMRINames}" = "NONE" ] ; then
		tfMRINames=""
	fi
	log_Msg "After delimiter substitution, tfMRINames: ${tfMRINames}"

	for fMRIName in ${rfMRINames} ${tfMRINames} ; do
		log_Msg "fMRIName: ${fMRIName}"

		files=""
		files+="PhaseOne_gdc_dc.nii.gz "
		files+="PhaseTwo_gdc_dc.nii.gz "
		files+="SBRef_dc.nii.gz"

		for File in ${files} ; do
			log_Msg "--File: ${File}"
			
			if [ ! -e ${StudyFolder}/${Subject}/T1w/Results/${fMRIName}/Import/${File} ]; then
				if [ ! -e ${StudyFolder}/${Subject}/T1w/Results/${fMRIName}/Import ]; then
					mkdir -p ${StudyFolder}/${Subject}/T1w/Results/${fMRIName}/Import
				fi
				if [ ! -e ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/Import ]; then
					mkdir -p ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/Import
				fi

				log_Msg "----Copy"
				cp \
					${StudyFolder}/${Subject}/${fMRIName}/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased/FieldMap/${File} \
					${StudyFolder}/${Subject}/T1w/Results/${fMRIName}/Import/${File}

				log_Msg "----convert_xfm"
				${FSLDIR}/bin/convert_xfm -omat \
					${StudyFolder}/${Subject}/T1w/Results/${fMRIName}/Import/fMRI2str.mat \
					-concat ${StudyFolder}/${Subject}/${fMRIName}/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased/fMRI2str.mat \
					        ${StudyFolder}/${Subject}/${fMRIName}/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased/Scout_gdc_undistorted.mat

				log_Msg "----applywarp 1"
				${FSLDIR}/bin/applywarp --interp=spline \
					-i ${StudyFolder}/${Subject}/T1w/Results/${fMRIName}/Import/${File} \
					-r ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_SBRef.nii.gz \
					--premat=${StudyFolder}/${Subject}/T1w/Results/${fMRIName}/Import/fMRI2str.mat \
					-w ${StudyFolder}/${Subject}/MNINonLinear/xfms/acpc_dc2standard.nii.gz \
					-o ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/Import/${File}

				log_Msg "----applywarp 2"
				${FSLDIR}/bin/applywarp --interp=spline \
					-i ${StudyFolder}/${Subject}/T1w/Results/${fMRIName}/Import/${File} \
					-r ${StudyFolder}/${Subject}/T1w/T2w_acpc_dc.nii.gz \
					--premat=${StudyFolder}/${Subject}/T1w/Results/${fMRIName}/Import/fMRI2str.mat \
					-o ${StudyFolder}/${Subject}/T1w/Results/${fMRIName}/Import/${File}

			else
				echo "--File already exists"
			fi

		done # File in ${files}

		mv ${StudyFolder}/${Subject}/T1w/Results/${fMRIName}/Import/* ${StudyFolder}/${Subject}/T1w/Results/${fMRIName}
		rmdir ${StudyFolder}/${Subject}/T1w/Results/${fMRIName}/Import

		mv ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/Import/* ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}
		rmdir ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/Import

	done # fMRIName in ${rfMRINames} ${tfMRINames}

	log_Msg "End"
}

#
# Invoke the 'main' function to get things started
#
main $@
