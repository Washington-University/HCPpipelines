#!/bin/bash

#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # LongitudinalFreeSurferPipeline.sh
#
# ## Copyright Notice
#
# Copyright (C) 2015-2023 The Human Connectome Project/Connectome Coordination Facility
#
# * Washington University in St. Louis
# * Univeristy of Ljubljana
#
# ## Author(s)
#
# * Jure Demsar, Faculty of Computer and Information Science, University of Ljubljana
# * Matthew F. Glasser, Department of Anatomy and Neurobiology, Washington University in St. Louis
# * Mikhail V. Milchenko, Department of Radiology, Washington University in St. Louis
#

# Version: v.0.1, 10/23/2023

# ## Product
#
# [Human Connectome Project](http://www.humanconnectome.org) (HCP) Pipelines
#
# ## License
#
# See the [LICENSE](https://github.com/Washington-University/Pipelines/blob/master/LICENSE.md) file
#
#~ND~END~

#  Define Sources and pipe-dir
# -----------------------------------------------------------------------------------

set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"           # Debugging functions; also sources log.shlib
source "${HCPPIPEDIR}/global/scripts/newopts.shlib" "$@"
source "${HCPPIPEDIR}/global/scripts/processingmodecheck.shlib"  # Check processing mode requirements

#description to use in usage - syntax of parameters is now explained automatically
opts_SetScriptDescription "Runs the Longitudinal FreeSurfer HCP pipeline"

# Show usage information
opts_AddMandatory '--subject' 'SubjectID' 'subject' "Subject ID (required)  Used with --path input to create full path to root directory for all sessions"
opts_AddMandatory '--path' 'StudyFolder' 'path' "Path to subject's data folder (required)  Used with --subject input to create full path to root directory for all outputs generated as path/subject)"
opts_AddMandatory '--sessions' 'Sessions' 'sessions' "Comma separated list of session (timepoint, visit) IDs (required). Also used to generate full path to each longitudinal session directory"
opts_AddMandatory '--template-id' 'TemplateID' 'template-id' "An @ symbol separated list of session IDs (required). Used to generate root template directory name."
opts_AddOptional '--use-T2w' 'UseT2w' 'UseT2w' "Set to 0 for no T2-weighted processing [1]" "1"
opts_AddOptional '--seed' 'recon_all_seed' "Seed" 'recon-all seed value'

#TSC: repeatable options aren't currently supported in newopts, do them manually and fake the help info for now
opts_AddOptional '--generate-template' 'generate_template' 'integer' 'Set to 0 to not generate template (assuming it is already generated) [1]' "1"
opts_AddOptional '--generate-timepoints' 'generate_timepoints' 'integer' 'Set to 0 to not generate timepoints [1]' "1"
opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues
${HCPPIPEDIR}/show_version

#processing code goes here

# ------------------------------------------------------------------------------
#  Verify required environment variables are set and log value
# ------------------------------------------------------------------------------

log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FREESURFER_HOME

# Platform info
log_Msg "Platform Information Follows: "
uname -a

# Configure custom tools
# - Determine if the PATH is configured so that the custom FreeSurfer v6 tools used by this script
#   (the recon-all.v6.hires script and other scripts called by the recon-all.v6.hires script)
#   are found on the PATH. If all such custom scripts are found, then we do nothing here.
#   If any one of them is not found on the PATH, then we change the PATH so that the
#   versions of these scripts found in ${HCPPIPEDIR}/FreeSurfer/custom are used.
configure_custom_tools()
{
  local which_recon_all
  local which_conf2hires
  local which_longmc

	which_recon_all=$(which recon-all.v6.hires || true)
	which_conf2hires=$(which conf2hires || true)
	which_longmc=$(which longmc || true)

  if [[ "${which_recon_all}" = "" || "${which_conf2hires}" == "" || "${which_longmc}" = "" ]] ; then
    export PATH="${HCPPIPEDIR}/FreeSurfer/custom:${PATH}"
    log_Warn "We were not able to locate one of the following required tools:"
    log_Warn "recon-all.v6.hires, conf2hires, or longmc"
    log_Warn ""
    log_Warn "To be able to run this script using the standard versions of these tools,"
    log_Warn "we added ${HCPPIPEDIR}/FreeSurfer/custom to the beginning of the PATH."
    log_Warn ""
    log_Warn "If you intended to use some other version of these tools, please configure"
    log_Warn "your PATH before invoking this script, such that the tools you intended to"
    log_Warn "use can be found on the PATH."
    log_Warn ""
    log_Warn "PATH set to: ${PATH}"
  fi
}

# Show tool versions
show_tool_versions()
{
  # Show HCP pipelines version
  log_Msg "Showing HCP Pipelines version"
  ${HCPPIPEDIR}/show_version

  # Show recon-all version
  log_Msg "Showing recon-all.v6.hires version"
  local which_recon_all=$(which recon-all.v6.hires)
  log_Msg ${which_recon_all}
  recon-all.v6.hires -version
  
  # Show tkregister version
  log_Msg "Showing tkregister version"
  which tkregister
  tkregister -version

  # Show mri_concatenate_lta version
  log_Msg "Showing mri_concatenate_lta version"
  which mri_concatenate_lta
  mri_concatenate_lta -version

  # Show mri_surf2surf version
  log_Msg "Showing mri_surf2surf version"
  which mri_surf2surf
  mri_surf2surf -version

  # Show fslmaths location
  log_Msg "Showing fslmaths location"
  which fslmaths
}

validate_freesurfer_version()
{
  if [ -z "${FREESURFER_HOME}" ]; then
    log_Err_Abort "FREESURFER_HOME must be set"
  fi
  
  freesurfer_version_file="${FREESURFER_HOME}/build-stamp.txt"

  if [ -f "${freesurfer_version_file}" ]; then
    freesurfer_version_string=$(cat "${freesurfer_version_file}")
    log_Msg "INFO: Determined that FreeSurfer full version string is: ${freesurfer_version_string}"
  else
    log_Err_Abort "Cannot tell which version of FreeSurfer you are using."
  fi

  # strip out extraneous stuff from FreeSurfer version string
  freesurfer_version_string_array=(${freesurfer_version_string//-/ })
  freesurfer_version=${freesurfer_version_string_array[5]}
  freesurfer_version=${freesurfer_version#v} # strip leading "v"

  log_Msg "INFO: Determined that FreeSurfer version is: ${freesurfer_version}"

  # break FreeSurfer version into components
  # primary, secondary, and tertiary
  # version X.Y.Z ==> X primary, Y secondary, Z tertiary
  freesurfer_version_array=(${freesurfer_version//./ })

  freesurfer_primary_version="${freesurfer_version_array[0]}"
  freesurfer_primary_version=${freesurfer_primary_version//[!0-9]/}

  freesurfer_secondary_version="${freesurfer_version_array[1]}"
  freesurfer_secondary_version=${freesurfer_secondary_version//[!0-9]/}

  freesurfer_tertiary_version="${freesurfer_version_array[2]}"
  freesurfer_tertiary_version=${freesurfer_tertiary_version//[!0-9]/}

  if [[ $(( ${freesurfer_primary_version} )) -lt 6 ]]; then
    # e.g. 4.y.z, 5.y.z
    log_Err_Abort "FreeSurfer version 6.0.0 or greater is required. (Use FreeSurferPipeline-v5.3.0-HCP.sh if you want to continue using FreeSurfer 5.3)"
  fi
}

# Configure the use of FreeSurfer v6 custom tools
configure_custom_tools

# Show tool versions
show_tool_versions

# Validate version of FreeSurfer in use
validate_freesurfer_version

# ----------------------------------------------------------------------
log_Msg "Starting main functionality"
# ----------------------------------------------------------------------

# ----------------------------------------------------------------------
# Log values retrieved from positional parameters
# ----------------------------------------------------------------------
log_Msg "StudyFolder: ${StudyFolder}"
log_Msg "SubjectID: ${SubjectID}"
log_Msg "Sessions: ${Sessions}"
log_Msg "TemplateID: ${TemplateID}"
log_Msg "recon_all_seed: ${recon_all_seed}"

# ----------------------------------------------------------------------
log_Msg "Preparing the folder structure"
# ----------------------------------------------------------------------
Sessions=`echo ${Sessions} | sed 's/,/ /g'`

extra_reconall_args_base=""
extra_reconall_args_long=""

Session0=( $Sessions ); Session0=${Session0[0]}
if (( UseT2w )); then
  extra_reconall_args_base="-T2pial -T2 ${StudyFolder}/${Session0}/T1w/T2w_acpc_dc_restore.nii.gz"
  extra_reconall_args_long="-T2pial"
fi

log_Msg "extra_reconall_args_base: $extra_reconall_args_base"
log_Msg "extra_reconall_args_long: $extra_reconall_args_long"
log_Msg "After delimiter substitution, Sessions: ${Sessions}"

LongDIR="${StudyFolder}/${SubjectID}.long.${TemplateID}/T1w"
mkdir -p "${LongDIR}"
for Session in ${Sessions} ; do
  Source="${StudyFolder}/${Session}/T1w/${Session}"
  Target="${LongDIR}/${Session}"
  log_Msg "Creating a link: ${Source} => ${Target}"
  ln -sf ${Source} ${Target}
done


if (( generate_template )); then 

	# ----------------------------------------------------------------------
	log_Msg "Creating the base template: ${TemplateID}"
	# ----------------------------------------------------------------------
	# backup template dir if it exists
	if [ -d "${LongDIR}/${TemplateID}" ]; then
	  TimeStamp=`date +%Y-%m-%d_%H.%M.%S.%6N`
	  log_Msg "Base template dir: ${LongDIR}/${TemplateID} already exists, backing up to ${LongDIR}/${TemplateID}.${TimeStamp}"
	  mv ${LongDIR}/${TemplateID} ${LongDIR}/${TemplateID}.${TimeStamp}
	fi

	recon_all_cmd="recon-all.v6.hires"
	recon_all_cmd+=" -sd ${LongDIR}"
	recon_all_cmd+=" -base ${TemplateID}"
	for Session in ${Sessions} ; do
	  recon_all_cmd+=" -tp ${Session}"
	done
	recon_all_cmd+=" -all"

	if [ ! -z "${recon_all_seed}" ]; then
	  recon_all_cmd+=" -norandomness -rng-seed ${recon_all_seed}"
	fi


	#---------------------------------------------------------------------------------------
	log_Msg "Running the recon-all to generate common template"
	#---------------------------------------------------------------------------------------

	#recon_all_cmd+=(${extra_reconall_args_base[@]+"${extra_reconall_args_base[@]}"})  
	recon_all_cmd+=" $extra_reconall_args_base "
	echo "recon_all_cmd:"
	echo ${recon_all_cmd}
	log_Msg "...recon_all_cmd: ${recon_all_cmd}"

	${recon_all_cmd}
	return_code=$?
	if [ "${return_code}" != "0" ]; then
	  log_Err_Abort "recon-all command failed with return_code: ${return_code}"
	fi
fi
if (( generate_timepoints )); then 

	# ----------------------------------------------------------------------
	log_Msg "Running the longitudinal recon-all on each timepoint"
	# ----------------------------------------------------------------------

	for Session in ${Sessions} ; do
	  log_Msg "Running longitudinal recon all for session: ${Session}"
	  recon_all_cmd="recon-all.v6.hires"
	  recon_all_cmd+=" -sd ${LongDIR}"
	  recon_all_cmd+=" -long ${Session} ${TemplateID} -all"
	  
	  #recon_all_cmd+=(${extra_reconall_args_long[@]+"${extra_reconall_args_long[@]}"})
	  recon_all_cmd+=" $extra_reconall_args_long "
	  T2w=${StudyFolder}/${Session}/T1w/T2w_acpc_dc_restore.nii.gz
	  
	  if [ -f "$T2w" ]; then 
		  recon_all_cmd+=" -T2 $T2w"
	  else
	  	  log_Msg "WARNING: No T2-weighed image $T2w, T2-weighted processing will not run."
	  fi
	  	  
	  T1w=${StudyFolder}/${Session}/T1w/T1w_acpc_dc_restore.nii.gz
	  emregmask=${StudyFolder}/${Session}/T1w/T1w_acpc_dc_restore_brain.nii.gz
	  
	  if [ -f "$T1w" -a -f "$emregmask" ]; then 
	  	recon_all_cmd+=" -emregmask $emregmask" #-i $T1w 
	  else
	  	log_Msg "ERROR: one of required files missing ($T1w or $emregmask)"
	  	exit -1	  	
	  fi
	  	  	  
	  log_Msg "...recon_all_cmd: ${recon_all_cmd}"
	  echo ${recon_all_cmd}

	  ${recon_all_cmd}
	  return_code=$?
	  if [ "${return_code}" != "0" ]; then
	    log_Err_Abort "recon-all command failed with return_code: ${return_code}"
	  fi

	  log_Msg "Organizing the folder structure for: ${Session}"
	  # create the symlink
	  TargetDIR="${StudyFolder}/${Session}.long.${TemplateID}/T1w"
	  mkdir -p "${TargetDIR}"
	  ln -sf "${LongDIR}/${Session}.long.${TemplateID}" "${TargetDIR}/${Session}.long.${TemplateID}"
	done
fi

# ----------------------------------------------------------------------
log_Msg "Cleaning up the folder structure"
# ----------------------------------------------------------------------
for Session in ${Sessions} ; do
  # remove the symlink in the subject's folder
  rm -rf "${LongDIR}/${Session}"
done

# ----------------------------------------------------------------------
log_Msg "Completing main functionality"
# ----------------------------------------------------------------------