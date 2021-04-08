#!/bin/bash
#
# # ReApplyFixPipeline.sh
#
# ## Copyright Notice
#
# Copyright (C) 2015-2017 The Human Connectome Project/Connectome Coordination Facility
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

# ------------------------------------------------------------------------------
#  Show usage information for this script
# ------------------------------------------------------------------------------

show_usage()
{
	cat <<EOF

${g_script_name}: ReApplyFix Pipeline

This script has two purposes:
1) Reapply FIX cleanup to the volume and default CIFTI (i.e., MSMSulc registered surfaces)
following manual reclassification of the FIX signal/noise components (see ApplyHandReClassifications.sh).
2) Apply FIX cleanup to the CIFTI from an alternative surface registration (e.g., MSMAll)
(either for the first time, or following manual reclassification of the components).
Only one of these two purposes can be accomplished per invocation.

Usage: ${g_script_name} PARAMETER...

PARAMETERs are [ ] = optional; < > = user supplied value

  Note: The PARAMETERS can be specified positionally (i.e. without using the --param=value
        form) by simply specifying all values on the command line in the order they are
        listed below.

        e.g. ${g_script_name} /path/to/study/folder 100307 rfMRI_REST1_LR 2000 ...

  [--help] : show usage information and exit
   --path=<path to study folder> OR --study-folder=<path to study folder>
   --subject=<subject ID>
   --fmri-name=<fMRI name> (Do not include path, nifti extension, or the 'hp' string).
   --high-pass=<high-pass filter used in ICA+FIX>
   [--reg-name=<surface registration name> defaults to ${G_DEFAULT_REG_NAME}. (Use NONE for MSMSulc registration)
   [--low-res-mesh=<low res mesh number>] defaults to ${G_DEFAULT_LOW_RES_MESH}
   [--matlab-run-mode={0, 1, 2}] defaults to ${G_DEFAULT_MATLAB_RUN_MODE}
     0 = Use compiled MATLAB
     1 = Use interpreted MATLAB
     2 = Use interpreted Octave
   [--motion-regression={TRUE, FALSE}] defaults to ${G_DEFAULT_MOTION_REGRESSION}
   [--delete-intermediates={TRUE, FALSE}] defaults to ${G_DEFAULT_DELETE_INTERMEDIATES}
     If TRUE, deletes the high-pass filtered files.

EOF
}

# Establish defaults
G_DEFAULT_REG_NAME="NONE"
G_DEFAULT_LOW_RES_MESH=32
G_DEFAULT_MATLAB_RUN_MODE=1		# Use interpreted MATLAB
G_DEFAULT_MOTION_REGRESSION="FALSE"
G_DEFAULT_DELETE_INTERMEDIATES="FALSE"

# ------------------------------------------------------------------------------
#  Get the command line options for this script.
# ------------------------------------------------------------------------------

get_options()
{
	local arguments=("$@")

	# initialize global output variables
	unset p_StudyFolder      # ${1}
	unset p_Subject          # ${2}
	unset p_fMRIName         # ${3}
	unset p_HighPass         # ${4}
	unset p_RegName          # ${5}
	unset p_LowResMesh       # ${6}
	unset p_MatlabRunMode    # ${7}
	unset p_MotionRegression # ${8}
    unset p_DeleteIntermediates # ${9}

	# set default values
	p_RegName=${G_DEFAULT_REG_NAME}
	p_LowResMesh=${G_DEFAULT_LOW_RES_MESH}
	p_MatlabRunMode=${G_DEFAULT_MATLAB_RUN_MODE}
	p_MotionRegression=${G_DEFAULT_MOTION_REGRESSION}
    p_DeleteIntermediates=${G_DEFAULT_DELETE_INTERMEDIATES}
	
	# parse arguments
	local num_args=${#arguments[@]}
	local argument
	local index=0

	while [ "${index}" -lt "${num_args}" ]; do
		argument=${arguments[index]}

		case ${argument} in
			--help)
				show_usage
				exit 0
				;;
			--path=*)
				p_StudyFolder=${argument#*=}
				index=$(( index + 1 ))
				;;
			--study-folder=*)
				p_StudyFolder=${argument#*=}
				index=$(( index + 1 ))
				;;
			--subject=*)
				p_Subject=${argument#*=}
				index=$(( index + 1 ))
				;;
			--fmri-name=*)
				p_fMRIName=${argument#*=}
				index=$(( index + 1 ))
				;;
			--high-pass=*)
				p_HighPass=${argument#*=}
				index=$(( index + 1 ))
				;;
			--reg-name=*)
				p_RegName=${argument#*=}
				index=$(( index + 1 ))
				;;
			--low-res-mesh=*)
				p_LowResMesh=${argument#*=}
				index=$(( index + 1 ))
				;;
	  		--matlab-run-mode=*)
				p_MatlabRunMode=${argument#*=}
				index=$(( index + 1 ))
				;;
			--motion-regression=*)
				p_MotionRegression=${argument#*=}
				index=$(( index + 1 ))
				;;
			--delete-intermediates=*)
				p_DeleteIntermediates=${argument#*=}
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
	if [ -z "${p_StudyFolder}" ]; then
		log_Err "Study Folder (--path= or --study-folder=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Study Folder: ${p_StudyFolder}"
	fi

	if [ -z "${p_Subject}" ]; then
		log_Err "Subject ID (--subject=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Subject ID: ${p_Subject}"
	fi

	if [ -z "${p_fMRIName}" ]; then
		log_Err "fMRI Name (--fmri-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "fMRI Name: ${p_fMRIName}"
	fi

	if [ -z "${p_HighPass}" ]; then
		log_Err "High Pass (--high-pass=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "High Pass: ${p_HighPass}"
	fi

	if [ -z "${p_RegName}" ]; then
		log_Err "Reg Name (--reg-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Reg Name: ${p_RegName}"
	fi

	if [ -z "${p_LowResMesh}" ]; then
		log_Err "Low Res Mesh (--low-res-mesh=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Low Res Mesh: ${p_LowResMesh}"
	fi

	if [ -z "${p_MatlabRunMode}" ]; then
		log_Err "MATLAB run mode value (--matlab-run-mode=) required"
		error_count=$(( error_count + 1 ))
	else
		case ${p_MatlabRunMode} in
			0)
				log_Msg "MATLAB Run Mode: ${p_MatlabRunMode} - Use compiled MATLAB"
				;;
			1)
				log_Msg "MATLAB Run Mode: ${p_MatlabRunMode} - Use interpreted MATLAB"
				;;
			2)
				log_Msg "MATLAB Run Mode: ${p_MatlabRunMode} - Use interpreted Octave"
				;;
			*)
				log_Err "MATLAB Run Mode value must be 0, 1, or 2"
				error_count=$(( error_count + 1 ))
				;;
		esac
	fi

	if [ -z "${p_MotionRegression}" ]; then
		log_Err "motion regression setting (--motion-regression=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Motion Regression: ${p_MotionRegression}"
	fi

	if [ -z "${p_DeleteIntermediates}" ]; then
		log_Err "delete intermediates setting (--delete-intermediates=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Delete Intermediates: ${p_DeleteIntermediates}"
	fi

	if [ ${error_count} -gt 0 ]; then
		log_Err_Abort "For usage information, use --help"
	fi
}

# ------------------------------------------------------------------------------
#  Show Tool Versions
# ------------------------------------------------------------------------------

show_tool_versions()
{
	# Show HCP pipelines version
	log_Msg "Showing HCP Pipelines version"
	"${HCPPIPEDIR}"/show_version --short

	# Show wb_command version
	log_Msg "Showing Connectome Workbench (wb_command) version"
	${CARET7DIR}/wb_command -version

	# Show FSL version
	log_Msg "Showing FSL version"
	fsl_version_get fsl_ver
	log_Msg "FSL version: ${fsl_ver}"

	# Show specific FIX version, if available
	if [ -f ${FSL_FIXDIR}/fixversion ]; then
		fixversion=$(cat ${FSL_FIXDIR}/fixversion )
		log_Msg "FIX version: $fixversion"
	fi

}

# ------------------------------------------------------------------------------
#  Check for whether or not we have hand reclassification files
# ------------------------------------------------------------------------------

have_hand_reclassification()
{
	local StudyFolder="${1}"
	local Subject="${2}"
	local fMRIName="${3}"
	local HighPass="${4}"

	if (( HighPass >= 0 )); then
		[ -e "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}.ica/HandNoise.txt" ]
	else
		[ -e "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}.ica/HandNoise.txt" ]
	fi
}

function interpret_as_bool()
{
    case $(echo "$1" | tr '[:upper:]' '[:lower:]') in
    (true | yes | 1)
        echo 1
        ;;
    (false | no | none | 0)
        echo 0
        ;;
    (*)
        log_Err_Abort "error: '$1' is not valid for this argument, please use TRUE or FALSE"
        ;;
    esac
}

# ------------------------------------------------------------------------------
#  Main processing of script.
# ------------------------------------------------------------------------------

main()
{
	log_Msg "Starting main functionality"

	# Retrieve positional parameters
	local StudyFolder="${1}"
	local Subject="${2}"
	local fMRIName="${3}"
	local HighPass="${4}"

	local RegName
	if [ -z "${5}" ]; then
		RegName=${G_DEFAULT_REG_NAME}
	else
		RegName="${5}"
	fi
	
	local LowResMesh
	if [ -z "${6}" ]; then
		LowResMesh=${G_DEFAULT_LOW_RES_MESH}
	else
		LowResMesh="${6}"
	fi
	
	local MatlabRunMode
	if [ -z "${7}" ]; then
		MatlabRunMode=${G_DEFAULT_MATLAB_RUN_MODE}
	else
		MatlabRunMode="${7}"
	fi

	local MotionRegression
	if [ -z "${8}" ]; then
		MotionRegression=$(interpret_as_bool "${G_DEFAULT_MOTION_REGRESSION}")
	else
		MotionRegression=$(interpret_as_bool "${8}")
	fi

	local DeleteIntermediates
	if [ -z "${9}" ]; then
		DeleteIntermediates=$(interpret_as_bool "${G_DEFAULT_DELETE_INTERMEDIATES}")
	else
		DeleteIntermediates=$(interpret_as_bool "${9}")
	fi

	# Log values retrieved from positional parameters
	log_Msg "StudyFolder: ${StudyFolder}"
	log_Msg "Subject: ${Subject}"
	log_Msg "fMRIName: ${fMRIName}"
	log_Msg "HighPass: ${HighPass}"
	log_Msg "RegName: ${RegName}"
	log_Msg "LowResMesh: ${LowResMesh}"
	log_Msg "MatlabRunMode: ${MatlabRunMode}"
	log_Msg "MotionRegression: ${MotionRegression}"
    log_Msg "DeleteIntermediates: ${DeleteIntermediates}"
	
	# Naming Conventions and other variables
	local Caret7_Command="${CARET7DIR}/wb_command"
	log_Msg "Caret7_Command: ${Caret7_Command}"

	local RegString
	if [ ${RegName} != "NONE" ] ; then
		RegString="_${RegName}"
	else
		RegString=""
	fi
	
	if [ ! -z ${LowResMesh} ] && [ ${LowResMesh} != ${G_DEFAULT_LOW_RES_MESH} ]; then
		RegString="${RegString}.${LowResMesh}k"
	fi

	log_Msg "RegString: ${RegString}"

	# For INTERPRETED MODES, make sure that matlab/octave has access to the functions it needs.
	# Since we are NOT using the ${FSL_FIXDIR}/call_matlab.sh script to invoke matlab (unlike 'hcp_fix')
	# we need to explicitly add ${FSL_FIXDIR} (all the fix-related functions)
	# and ${FSL_MATLAB_PATH} (e.g., read_avw.m, save_avw.m) to the matlab path.
	# Several additional necessary environment variables (e.g., ${FSL_FIX_CIFTIRW} and ${FSL_FIX_WBC})
	# are set in ${FSL_FIXDIR}/settings.sh, which is sourced below for interpreted modes.
	# Note that the ciftiopen.m, ciftisave.m functions are *appended* to the path through the ${FSL_FIX_CIFTIRW} 
	# environment variable within fix_3_clean.m itself.
	# Note that previously we did not add '${HCPPIPEDIR}/global/matlab' to the path (which used to contain the
	# CIFTI I/O functions as well), or HCPCIFTIRWDIR.
	# Since addpath adds to the front of the matlab path, we are now overriding the fix settings for cifti I/O,
	# and adding '${HCPPIPEDIR}/global/matlab', so functions in these folders will now replace what fix would normally run.
	export FSL_MATLAB_PATH="${FSLDIR}/etc/matlab"
	local ML_PATHS="addpath('${FSL_FIXDIR}'); addpath('${FSL_MATLAB_PATH}'); addpath('$HCPCIFTIRWDIR'); addpath('${HCPPIPEDIR}/global/matlab');"

	# Some defaults
	local aggressive=0
	local hp=${HighPass}
	local DoVol=0
	local fixlist=".fix"

	if (( hp >= 0 )); then
		hpStr="_hp${hp}"
	else
		hpStr=""
	fi
	
	# fMRIName is expected to NOT include path info, or a nifti extension; make sure that is indeed the case
	# (although if someone includes the hp string as part fMRIName itself, the script will still break)
	fMRIName=$(basename $($FSLDIR/bin/remove_ext $fMRIName))
	
	# If we have a hand classification and no regname, reapply fix to the volume as well
	if have_hand_reclassification ${StudyFolder} ${Subject} ${fMRIName} ${hp}
	then
		fixlist="HandNoise.txt"
		#TSC: if regname (which applies to the surface) isn't NONE, assume the hand classification was previously already applied to the volume data
		if [[ "${RegName}" == "NONE" ]]
		then
			DoVol=1
		fi
	fi
	# WARNING: fix_3_clean doesn't actually do anything different based on the value of DoVol (its 5th argument).
	# Rather, if a 5th argument is present, fix_3_clean does NOT apply cleanup to the volume, *regardless* of whether
	# that 5th argument is 0 or 1 (or even a non-sensical string such as 'foo').
	# It is for that reason that the code below needs to use separate calls to fix_3_clean, with and without DoVol
	# as an argument, rather than simply passing in the value of DoVol as set within this script.
	# Not sure if/when this non-intuitive behavior of fix_3_clean will change, but this is accurate as of fix1.067
	# UPDATE (11/8/2019): As of FIX 1.06.12, fix_3_clean interprets its 5th argument ("DoVol") in the usual boolean
	# manner. However, since we already had a work-around to this problem, we will leave the code unchanged so that
	# we don't need to add a FIX version dependency to the script.

	log_Msg "Use fixlist=$fixlist"

	DIR=$(pwd)
	cd ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}

	# Note: fix_3_clean does NOT filter the volume (NIFTI) data -- it assumes
	# that any desired filtering has already been done outside of fix.
	# So here, we need to symlink to the hp-filtered volume data.
	# HOWEVER, if missing, only need to generate the hp-filtered volume data if DoVol=1.
	# Otherwise (if DoVol=0), the only role of filtered_func_data in fix_3_clean is to determine the TR.
	# In that case, we will just symlink the *non-filtered* data to filtered_func_data
	# (as a hack for fix_3_clean to determine the TR without a time-consuming filtering step
	# on the volume)

	useNonFilteredAsFilteredFunc=0
    if (( $($FSLDIR/bin/imtest "${fMRIName}${hpStr}") )); then
		log_Warn "Using existing $($FSLDIR/bin/imglob -extension ${fMRIName}${hpStr}) (not re-filtering)"
	else  # hp filtered volume file doesn't exist
		if (( DoVol )); then  # need to actually refilter the volume data
			if (( hp > 0 )); then
				tr=`$FSLDIR/bin/fslval ${fMRIName} pixdim4`
				log_Msg "tr: ${tr}"
				log_Msg "processing FMRI file ${fMRIName} with highpass ${hp}"
				hptr=$(echo "scale = 10; $hp / (2 * $tr)" | bc -l)

				# Starting with FSL 5.0.7, 'fslmaths -bptf' no longer includes the temporal mean in its output.
				# A work-around to this, which works with both the pre- and post-5.0.7 behavior is to compute
				# the temporal mean, remove it, run -bptf, and then add the mean back in.
				${FSLDIR}/bin/fslmaths ${fMRIName} -Tmean ${fMRIName}${hpStr}
				highpass_cmd="${FSLDIR}/bin/fslmaths ${fMRIName} -sub ${fMRIName}${hpStr} -bptf ${hptr} -1 -add ${fMRIName}${hpStr} ${fMRIName}${hpStr}"
				log_Msg "highpass_cmd: ${highpass_cmd}"
				${highpass_cmd}
			elif (( hp == 0 )); then
				# Nothing in script currently detrends the volume if hp=0 is requested (which is the intended meaning of hp=0)
				log_Err_Abort "hp = ${hp} not currently supported"
			fi
		else
			useNonFilteredAsFilteredFunc=1
		fi
	fi

	if [ ! -e ${fMRIName}${hpStr}.ica ]; then
		log_Err_Abort "${fMRIName}${hpStr}.ica is expected to already exist, but does not"
	fi
	
	cd ${fMRIName}${hpStr}.ica

	# Create symlink for filtered_func_data (per comments above)
	if (( useNonFilteredAsFilteredFunc )); then
		$FSLDIR/bin/imln ../${fMRIName} filtered_func_data
	else
		$FSLDIR/bin/imln ../${fMRIName}${hpStr} filtered_func_data
	fi
	
	# However, hp-filtering of the *CIFTI* (dtseries) occurs within fix_3_clean.
	# So here, we just create a symlink with the file name expected by
	# fix_3_clean ("Atlas.dtseries.nii") to the non-filtered data.
	if [ -f ../${fMRIName}_Atlas${RegString}.dtseries.nii ] ; then
		log_Msg "FOUND FILE: ../${fMRIName}_Atlas${RegString}.dtseries.nii"
		log_Msg "Performing imln"

		/bin/rm -f Atlas.dtseries.nii
		$FSLDIR/bin/imln ../${fMRIName}_Atlas${RegString}.dtseries.nii Atlas.dtseries.nii

		log_Msg "START: Showing linked files"
		ls -l ../${fMRIName}_Atlas${RegString}.dtseries.nii
		ls -l Atlas.dtseries.nii
		log_Msg "END: Showing linked files"
	else
		log_Warn "FILE NOT FOUND: ../${fMRIName}_Atlas${RegString}.dtseries.nii"
	fi

	# Get Movement_Regressors.txt into the format expected by functionmotionconfounds.m
	mkdir -p mc
	if [ -f ../Movement_Regressors.txt ] ; then
		log_Msg "Creating mc/prefiltered_func_data_mcf.par file"
		cat ../Movement_Regressors.txt | awk '{ print $4 " " $5 " " $6 " " $1 " " $2 " " $3}' > mc/prefiltered_func_data_mcf.par
	else
		log_Err_Abort "Movement_Regressors.txt not retrieved properly."
	fi

	## ---------------------------------------------------------------------------
	## Run fix_3_clean
	## ---------------------------------------------------------------------------

	# MPH: We need to invoke fix_3_clean directly, rather than through 'fix -a <options>' because
	# the latter does not provide access to the "DoVol" option within the former.
	# (Also, 'fix -a' is hard-coded to use '.fix' as the list of noise components, although that 
	# could be worked around).

	export FSL_FIX_WBC="${Caret7_Command}"
	# WARNING: fix_3_clean uses the environment variable FSL_FIX_WBC, but most previous
	# versions of FSL_FIXDIR/settings.sh (v1.067 and earlier) have a hard-coded value for
	# FSL_FIX_WBC, and don't check whether it is already defined in the environment.
	# Thus, when settings.sh file gets sourced, there is a possibility that the version of
	# wb_command is no longer the same as that specified by ${Caret7_Command}.  So, after
	# sourcing settings.sh below, we explicitly set FSL_FIX_WBC back to value of ${Caret7_Command}.
	# (This may only be relevant for interpreted matlab/octave modes).

	log_Msg "Running fix_3_clean"

	case ${MatlabRunMode} in

		# See important WARNING above regarding why ${DoVol} is NOT included as an argument when DoVol=1 !!
			
		0)
			# Use Compiled MATLAB

			local matlab_exe="${FSL_FIXDIR}/compiled/$(uname -s)/$(uname -m)/run_fix_3_clean.sh"

			# Do NOT enclose string variables inside an additional single quote because all
			# variables are already passed into the compiled binary as strings
			local matlab_function_arguments=("${fixlist}" "${aggressive}" "${MotionRegression}" "${hp}")
			if (( ! DoVol )); then
				matlab_function_arguments+=("${DoVol}")
			fi
			
			# fix_3_clean is part of the FIX distribution.
			# If ${FSL_FIX_MCR} is already defined in the environment, use that for the MCR location.
			# If not, the appropriate MCR version for use with fix_3_clean should be set in $FSL_FIXDIR/settings.sh.
			if [ -z "${FSL_FIX_MCR}" ]; then
				debug_disable_trap
				source ${FSL_FIXDIR}/settings.sh
				debug_enable_trap
				export FSL_FIX_WBC="${Caret7_Command}"
				# If FSL_FIX_MCR is still not defined after sourcing settings.sh, we have a problem
				if [ -z "${FSL_FIX_MCR}" ]; then
					log_Err_Abort "To use MATLAB run mode: ${MatlabRunMode}, the FSL_FIX_MCR environment variable must be set"
				fi
			fi
			log_Msg "FSL_FIX_MCR: ${FSL_FIX_MCR}"

			local matlab_cmd=("${matlab_exe}" "${FSL_FIX_MCR}" "${matlab_function_arguments[@]}")

			# redirect tokens must be parsed by bash before doing variable expansion, and thus can't be inside a variable
			# MPH: Going to let Compiled MATLAB use the existing stdout and stderr, rather than creating a separate log file
			#local matlab_logfile=".reapplyfix.${fMRIName}${RegString}.fix_3_clean.matlab.log"
			#log_Msg "Run MATLAB command: ${matlab_cmd[*]} >> ${matlab_logfile} 2>&1"
			#"${matlab_cmd[@]}" >> "${matlab_logfile}" 2>&1
			log_Msg "Run compiled MATLAB: ${matlab_cmd[*]}"
			"${matlab_cmd[@]}"
			;;
		
		1 | 2)
			# Use interpreted MATLAB or Octave
			if [[ ${MatlabRunMode} == "1" ]]; then
				local interpreter=(matlab -nojvm -nodisplay -nosplash)
			else
				local interpreter=(octave-cli -q --no-window-system)
			fi

			if (( DoVol )); then
				local matlab_cmd="${ML_PATHS} fix_3_clean('${fixlist}',${aggressive},${MotionRegression},${hp});"
			else
				local matlab_cmd="${ML_PATHS} fix_3_clean('${fixlist}',${aggressive},${MotionRegression},${hp},${DoVol});"
			fi
			
			log_Msg "Run interpreted MATLAB/Octave (${interpreter[@]}) with command..."
			log_Msg "${matlab_cmd}"

			# Use bash redirection ("here-string") to pass multiple commands into matlab
			# (Necessary to protect the semicolons that separate matlab commands, which would otherwise
			# get interpreted as separating different bash shell commands)
			(debug_disable_trap; source "${FSL_FIXDIR}/settings.sh"; debug_enable_trap; export FSL_FIX_WBC="${Caret7_Command}"; "${interpreter[@]}" <<<"${matlab_cmd}")
			;;

		*)
			# Unsupported MATLAB run mode
			log_Err_Abort "Unsupported MATLAB run mode value: ${MatlabRunMode}"
			;;
	esac

	log_Msg "Done running fix_3_clean"

	## ---------------------------------------------------------------------------
	## Rename some files (relative to the default names coded in fix_3_clean)
	## ---------------------------------------------------------------------------

	# Remove any existing old versions of the cleaned data (normally they should be overwritten
	# in the renaming that follows, but this ensures that any old versions don't linger)
	cd ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}
	local fmri=${fMRIName}
	if (( hp >= 0 )); then
		local fmrihp=${fmri}_hp${hp}
	else
		local fmrihp=${fmri}
	fi
	
	/bin/rm -f ${fmri}_Atlas${RegString}${hpStr}_clean.dtseries.nii
	/bin/rm -f ${fmri}_Atlas${RegString}${hpStr}_clean_vn.dscalar.nii

	if (( DoVol )); then
	    $FSLDIR/bin/imrm ${fmrihp}_clean
	    $FSLDIR/bin/imrm ${fmrihp}_clean_vn
	fi

	# Rename some of the outputs from fix_3_clean.
	# Note that the variance normalization ("_vn") outputs require use of fix1.067 or later
	# So check whether those files exist before moving/renaming them
	if [ -f ${fmrihp}.ica/Atlas_clean.dtseries.nii ]; then
	    /bin/mv ${fmrihp}.ica/Atlas_clean.dtseries.nii ${fmri}_Atlas${RegString}${hpStr}_clean.dtseries.nii
	else
	    log_Err_Abort "Something went wrong; ${fmrihp}.ica/Atlas_clean.dtseries.nii wasn't created"
	fi
	if [ -f ${fmrihp}.ica/Atlas_clean_vn.dscalar.nii ]; then
	    /bin/mv ${fmrihp}.ica/Atlas_clean_vn.dscalar.nii ${fmri}_Atlas${RegString}${hpStr}_clean_vn.dscalar.nii
	fi

	if (( DoVol )); then
	    $FSLDIR/bin/immv ${fmrihp}.ica/filtered_func_data_clean ${fmrihp}_clean
	    if [ "$?" -ne "0" ]; then
			log_Err_Abort "Something went wrong; ${fmrihp}.ica/filtered_func_data_clean wasn't created"
	    fi
	    if [ `$FSLDIR/bin/imtest ${fmrihp}.ica/filtered_func_data_clean_vn` = 1 ]; then
			$FSLDIR/bin/immv ${fmrihp}.ica/filtered_func_data_clean_vn ${fmrihp}_clean_vn
	    fi
	fi
	log_Msg "Done renaming files"

    # Remove the 'fake-NIFTI' file created in fix_3_clean for high-pass filtering of the CIFTI (if it exists)
	$FSLDIR/bin/imrm ${fmrihp}.ica/Atlas

	# Always delete things with too-generic names
	$FSLDIR/bin/imrm ${fmrihp}.ica/filtered_func_data
	rm -f ${fmrihp}.ica/Atlas.dtseries.nii
	
	# Optional deletion of highpass intermediates
    if [ "${DeleteIntermediates}" == "1" ] ; then
		if (( hp > 0 )); then  # fix_3_clean only writes out the hp-filtered time series if hp > 0
			$FSLDIR/bin/imrm ${fmri}_hp${hp}  # Explicitly use _hp${hp} here (rather than $hpStr as a safeguard against accidental deletion of the non-hp-filtered timeseries)
			rm -f ${fmrihp}.ica/Atlas_hp_preclean.dtseries.nii
		fi
	else
		#even if we don't delete it, don't leave this file with a hard to interpret name 
		if (( hp > 0 )); then
			# 'OR' mv command with "true" to avoid returning an error code if file doesn't exist for some reason
			mv -f ${fmrihp}.ica/Atlas_hp_preclean.dtseries.nii ${fmri}_Atlas_hp${hp}.dtseries.nii || true 
		fi
     fi

	cd ${DIR}  # Return to directory where script was launched

	log_Msg "Completed!"
}

# ------------------------------------------------------------------------------
#  "Global" processing - everything above here should be in a function
# ------------------------------------------------------------------------------

# Set global variables
g_script_name=$(basename "${0}")

# Allow script to return a Usage statement, before any other output
if [ "$#" = "0" ]; then
    show_usage
    exit 1
fi

# Verify that HCPPIPEDIR environment variable is set
if [ -z "${HCPPIPEDIR}" ]; then
	echo "${g_script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
	exit 1
fi

# Load function libraries
source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source ${HCPPIPEDIR}/global/scripts/opts.shlib                 # Command line option functions
source "${HCPPIPEDIR}/global/scripts/fsl_version.shlib"        # Functions for getting FSL version

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
	show_usage
	exit 0
fi

${HCPPIPEDIR}/show_version

# Verify required environment variables are set and log value
log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var CARET7DIR
log_Check_Env_Var FSLDIR
log_Check_Env_Var FSL_FIXDIR

# Show tool versions
show_tool_versions

# Determine whether named or positional parameters are used and invoke the 'main' function
if [[ ${1} == --* ]]; then
	# Named parameters (e.g. --parameter-name=parameter-value) are used
	log_Msg "Using named parameters"

	# Get command line options
	get_options "$@"

	# Invoke main functionality
	#     ${1}               ${2}           ${3}            ${4}            ${5}           ${6}              ${7}                ${8}                    ${9}
	main "${p_StudyFolder}" "${p_Subject}" "${p_fMRIName}" "${p_HighPass}" "${p_RegName}" "${p_LowResMesh}" "${p_MatlabRunMode}" "${p_MotionRegression}" "${p_DeleteIntermediates}"

else
	# Positional parameters are used
	log_Msg "Using positional parameters"
	main "$@"

fi
