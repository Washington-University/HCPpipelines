#!/bin/bash
#
# # ReApplyFixMultiRunPipeline.sh
#
# ## Copyright Notice
#
# Copyright (C) 2017-2025 The Human Connectome Project/Connectome Coordination Facility
#
# * Washington University in St. Louis
# * University of Minnesota
# * Oxford University
#
# ## Author(s)
#
# * Matthew F. Glasser, Department of Anatomy and Neurobiology, Washington University in St. Louis
# * Timothy B. Brown, Neuroinformatics Research Group, Washington University in St. Louis
# * Mikhail Milchenko (longitudinal patch), Computational Imaging Research Center, Washington University in St. Louis
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
set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
	pipedirguessed=1
	#fix this if the script is more than one level below HCPPIPEDIR
	export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/fsl_version.shlib" "$@"        # Functions for getting FSL version
source "$HCPPIPEDIR/global/scripts/processingmodecheck.shlib" "$@"

opts_SetScriptDescription "ReApplyFix Pipeline for MultiRun ICA+FIX"

#WARNING: this "default" is also used to special case whether filenames have ".<num>k" added to their regstring
G_DEFAULT_LOW_RES_MESH=32

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all sessions" '--path'

opts_AddMandatory '--session' 'SessionCross' 'session ID' "(e.g. 100610_V1)" "--subject"

opts_AddMandatory '--fmri-names' 'fMRINames' 'fMRI names' "an '@' symbol separated list of fMRI scan names (no whitespace, e.g. rfMRI_REST1_LR@rfMRI_REST1_RL).  Do not include path, nifti extension, or the 'hp' string.  All runs are assumed to have the same repetition time (TR)."

opts_AddMandatory '--concat-fmri-name' 'ConcatName' 'fMRI_ALL' "root name of the concatenated fMRI scan file, do not include path, nifti extension, or the 'hp' string"

opts_AddMandatory '--high-pass' 'HighPass' 'number or pd#' 'high-pass filter used in multi-run ICA+FIX'

opts_AddOptional '--reg-name' 'RegName' 'surface registration name' "use NONE for MSMSulc registration, default NONE" "NONE"

opts_AddOptional '--low-res-mesh' 'LowResMesh' 'number' "low resolution mesh identifier, default ${G_DEFAULT_LOW_RES_MESH}" "${G_DEFAULT_LOW_RES_MESH}"

opts_AddOptional '--motion-regression' 'MotionRegression' 'TRUE or FALSE' "default FALSE" "FALSE"

opts_AddOptional '--delete-intermediates' 'DeleteIntermediates' 'TRUE or FALSE' "whether to delete the concatenated high-pass filtered and non-filtered timeseries files that are prerequisites to FIX cleaning (the concatenated, hpXX_clean timeseries files are preserved for use in downstream scripts), default FALSE" "FALSE"

opts_AddConfigOptional '--vol-wisharts' 'volwisharts' 'volwisharts' 'integer' "Number of wisharts to fit to volume data in icaDim, default 2" "2"

opts_AddConfigOptional '--cifti-wisharts' 'ciftiwisharts' 'ciftiwisharts' 'integer' "Number of wisharts to fit to cifti data in icaDim, default 3" "3"

opts_AddConfigOptional '--icadim-mode' 'icadimmode' 'icadimmode' '"default" or "fewtimepoints"' 'Choose how to run icaDim:
"default" - start with a VN dimensionality of 1 and rerun until convergence
"fewtimepoints" - start with a VN dimensionality of half the timepoints, do not iterate' "default"

opts_AddOptional '--processing-mode' 'ProcessingMode' '"HCPStyleData" (default) or "LegacyStyleData"' "controls whether --icadim-mode=fewtimepoints is allowed" 'HCPStyleData'

opts_AddOptional '--clean-substring' 'CleanSubstring' 'string' "the clean mode substring, can be 'clean' as sICA+FIX cleaned,'clean_rclean' as sICA+FIX cleaned and reclean, default to 'clean'" "clean"

opts_AddOptional '--is-longitudinal' 'IsLongitudinal' 'TRUE or FALSE' "indicate longitudinal processing [FALSE]" "FALSE"
opts_AddOptional '--longitudinal-session' 'SessionLong' 'longitudinal session ID' "specify longitudinal session" ""


opts_AddOptional '--matlab-run-mode' 'MatlabMode' '0, 1, or 2' "defaults to 1
0 = Use compiled MATLAB
1 = Use interpreted MATLAB
2 = Use interpreted Octave" "1"

opts_ParseArguments "$@"

if ((pipedirguessed))
then
	log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

Compliance="HCPStyleData"
ComplianceMsg=""

if [[ "$icadimmode" == 'fewtimepoints' ]]
then
	Compliance="LegacyStyleData"
	ComplianceMsg+=" --icadim-mode=$icadimmode"
	log_Warn "The use of 'fewtimepoints' mode in icaDim skips the iterative fitting process for the wishart distributions, and is only intended as a workaround for data that does not have enough timepoints for the default icaDim mode to work properly."
fi

check_mode_compliance "$ProcessingMode" "$Compliance" "$ComplianceMsg"

g_script_name=$(basename "${0}")

#
# NOTE:
#   Don't echo anything in this function other than the last echo
#   that outputs the return value
#
determine_old_or_new_fsl()
{
	local fsl_version=${1}
	local old_or_new
	local fsl_version_array
	local fsl_primary_version
	local fsl_secondary_version
	local fsl_tertiary_version

	# parse the FSL version information into primary, secondary, and tertiary parts
	fsl_version_array=(${fsl_version//./ })

	fsl_primary_version="${fsl_version_array[0]}"
	fsl_primary_version=${fsl_primary_version//[!0-9]/}

	fsl_secondary_version="${fsl_version_array[1]}"
	fsl_secondary_version=${fsl_secondary_version//[!0-9]/}

	fsl_tertiary_version="${fsl_version_array[2]}"
	fsl_tertiary_version=${fsl_tertiary_version//[!0-9]/}

	# determine whether we are using "OLD" or "NEW" FSL
	# 6.0.0 and below is "OLD"
	# 6.0.1 and above is "NEW"

	if [[ $(( ${fsl_primary_version} )) -lt 6 ]] ; then
		# e.g. 4.x.x, 5.x.x
		old_or_new="OLD"
	elif [[ $(( ${fsl_primary_version} )) -gt 6 ]] ; then
		# e.g. 7.x.x
		old_or_new="NEW"
	else
		# e.g. 6.x.x
		if [[ $(( ${fsl_secondary_version} )) -gt 0 ]] ; then
			# e.g. 6.1.x
			old_or_new="NEW"
		else
			# e.g. 6.0.x
			if [[ $(( ${fsl_tertiary_version} )) -lt 1 ]] ; then
				# e.g. 6.0.0
				old_or_new="OLD"
			else
				# e.g. 6.0.1, 6.0.2, 6.0.3 ...
				old_or_new="NEW"
			fi
		fi
	fi

	echo ${old_or_new}
}

# ------------------------------------------------------------------------------
#  Check for whether or not we have hand reclassification files
# ------------------------------------------------------------------------------

have_hand_reclassification()
{
	local StudyFolder="${1}"
	local Session="${2}"
	local fMRIName="${3}"
	local HighPass="${4}"

	[ -e "${StudyFolder}/${Session}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}.ica/HandNoise.txt" ]
}

# ------------------------------------------------------------------------------
# Copy necessary files from cross-sectional to longitudinal target
# ------------------------------------------------------------------------------
function copy_to_longitudinal()
{
	local StudyFolder="$1"
	local SessionCross="$2"
	local SessionLong="$3"
	local fMRINames="$4"
	local ConcatName="$5"
	local HighPass="$6"

	local fmri S T
	#copy for concatentated run
	S="$StudyFolder/$SessionCross/MNINonLinear/Results/$ConcatName"
	T="$StudyFolder/$SessionLong/MNINonLinear/Results/$ConcatName"
	local file files_to_copy="Movement_Regressors_demean.txt ReclassifyAsNoise.txt ReclassifyAsSignal.txt"
	mkdir -p "$T"
	for file in $files_to_copy; do
		cp "$S"/"$file" "$T"/
	done

	local ICADir="$S/${ConcatName}_hp$HighPass.ica"
	local ICADirLong="$T/${ConcatName}_hp$HighPass.ica"
	mkdir -p "$ICADirLong"
	# copy mandatory files
	mandatory_files_to_copy="fix4melview_HCP_Style_Single_Multirun_Dedrift_thr10.txt fix4melview_HCP_Style_Single_Multirun_Dedrift_thr10.wb_annsub.csv \
	.fix Noise.txt Signal.txt ReclassifyAsNoise.txt ReclassifyAsSignal.txt"
	for file in $mandatory_files_to_copy; do
		if [ -f "$ICADir/$file" ]; then
			cp "$ICADir"/"$file" "$ICADirLong"/
		else
			log_Err_Abort "$file not found in $ICADir, a successfully completed MR+FIX and PostFix run is required before running this script"
		fi
	done
	# copy optional files
	optional_files_to_copy="hand_labels_noise.txt HandNoise.txt HandSignal.txt"
	for file in $optional_files_to_copy; do
		if [ -f "$ICADir/$file" ]; then
			cp "$ICADir"/"$file" "$ICADirLong"/
		fi
	done

	mkdir -p "$ICADirLong/mc"
	cp "$ICADir/mc/prefiltered_func_data_mcf_conf.nii.gz" "$ICADirLong"/mc/
	cp "$ICADir/mc/prefiltered_func_data_mcf_conf_hp.nii.gz" "$ICADirLong"/mc/
	cp "$ICADir/mc/prefiltered_func_data_mcf.par" "$ICADirLong"/mc/

	mkdir -p "$ICADirLong"/fix/
	cp "$ICADir"/fix/features.csv "$ICADirLong"/fix/

	files_to_copy="eigenvalues_percent ICAVolumeSpace.txt melodic_FTmix melodic_FTmix.sdseries.nii \
		melodic_ICstats melodic_mix melodic_mix.sdseries.nii melodic_Tmodes melodic_unmix"
	mkdir -p "$ICADirLong"/filtered_func_data.ica
	for file in $files_to_copy; do
		cp "$ICADir"/filtered_func_data.ica/"$file" "$ICADirLong"/filtered_func_data.ica/
	done

	#copy for individual fMRI runs
	for fmri in $fMRINames; do
		S="$StudyFolder/$SessionCross/MNINonLinear/Results/$fmri"
		T="$StudyFolder/$SessionLong/MNINonLinear/Results/$fmri"
		mkdir -p "$T"/"$fmri"_hp"$HighPass".ica/mc
		cp "$S"/"$fmri"_hp"$HighPass".ica/mc/prefiltered_func_data_mcf.par "$T"/"$fmri"_hp"$HighPass".ica/mc/
	done
}

# ------------------------------------------------------------------------------
#  Main processing of script.
# ------------------------------------------------------------------------------

"$HCPPIPEDIR"/show_version

# Verify required environment variables are set and log value
log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var CARET7DIR
log_Check_Env_Var FSLDIR

# Show tool versions
log_Msg "Showing HCP Pipelines version"
"${HCPPIPEDIR}"/show_version --short

log_Msg "Showing Connectome Workbench (wb_command) version"
"${CARET7DIR}"/wb_command -version

log_Msg "Showing FSL version"
fsl_version_get fsl_ver
log_Msg "FSL version: ${fsl_ver}"

old_or_new_version=$(determine_old_or_new_fsl ${fsl_ver})
if [ "${old_or_new_version}" == "OLD" ] ; then
	log_Err_Abort "FSL version 6.0.1 or greater is required."
fi

#mac readlink doesn't have -f
if [[ -L "$0" ]]
then
	this_script_dir=$(dirname "$(readlink "$0")")
else
	this_script_dir=$(dirname "$0")
fi

log_Msg "Starting main functionality"

if [[ "${HighPass}" == pd* ]]
then
	hpNum=${HighPass:2}
	if (( hpNum > 5 ))
	then
		log_Err_Abort "Polynomial detrending of order ${hpNum} is not allowed (may not be numerically stable); Use 5th order or less"
	fi
else
	hpNum=${HighPass}
fi
if ! [[ "${hpNum}" =~ ^[-]?[0-9]+$ ]]
then
	log_Err_Abort "--high-pass value of ${HighPass} is not valid"
fi
if [[ $(echo "${hpNum} < 0" | bc) == "1" ]]
then  #Logic of this script does not support negative hp values
	log_Err_Abort "--high-pass value must not be negative"
fi

case "$MatlabMode" in
	(0)
		log_Check_Env_Var MATLAB_COMPILER_RUNTIME
		;;
	(1)
		matlab_interpreter=(matlab -nodisplay -nosplash)
		;;
	(2)
		matlab_interpreter=(octave-cli -q --no-window-system)
		;;
	(*)
		log_Err_Abort "unrecognized matlab mode '$MatlabMode', use 0, 1, or 2"
	;;
esac

MotionRegression=$(opts_StringToBool "$MotionRegression")
DeleteIntermediates=$(opts_StringToBool "$DeleteIntermediates")
IsLongitudinal=$(opts_StringToBool "$IsLongitudinal")

if (( IsLongitudinal )) && ! [ -d "$StudyFolder/$SessionLong" ]; then
	log_Err_Abort "Longitudinal session directory $StudyFolder/$SessionLong does not exist"
fi

# Naming Conventions and other variables
Caret7_Command="${CARET7DIR}/wb_command"
log_Msg "Caret7_Command: ${Caret7_Command}"

if [ "${RegName}" != "NONE" ] ; then
	RegString="_${RegName}"
else
	RegString=""
fi

if [ ! -z ${LowResMesh} ] && [ ${LowResMesh} != ${G_DEFAULT_LOW_RES_MESH} ]; then
	RegString+=".${LowResMesh}k"
fi

log_Msg "RegString: ${RegString}"

if [[ "$icadimmode" == "fewtimepoints" ]] && ((volwisharts > 1 || ciftiwisharts > 1))
then
	log_Warn "--icadim-mode='fewtimepoints' is being used with multiple wisharts, multiple wishart fitting is not expected to work well when the data has few timepoints"
fi

# For INTERPRETED MODES, make sure that matlab/octave has access to the functions it needs.
# normalise.m (needed by functionhighpassandvariancenormalize.m) is in '${HCPPIPEDIR}/global/matlab'
# and ${FSL_MATLAB_PATH} (e.g., read_avw.m, save_avw.m) to the matlab path as well.
export FSL_MATLAB_PATH="${FSLDIR}/etc/matlab"
ML_PATHS="addpath('${FSL_MATLAB_PATH}'); addpath('$HCPCIFTIRWDIR'); addpath('${HCPPIPEDIR}/global/matlab/icaDim'); addpath('${HCPPIPEDIR}/global/matlab'); addpath('${this_script_dir}/scripts');"

# Some defaults
aggressive=0
newclassification=0
hp=${HighPass}
DoVol=0
fixlist=".fix"
Session=$SessionCross

if (( IsLongitudinal )); then
	DoVol=1
	Session=$SessionLong
	log_Msg "Copying ICAFIX output to longitudinal session"
	copy_to_longitudinal "$StudyFolder" "$SessionCross" "$SessionLong" "${fMRINames//@/ }" "$ConcatName" "$HighPass"
fi

# ConcatName is expected to NOT include path info, or a nifti extension; make sure that is indeed the case
ConcatNameOnly=$(basename $($FSLDIR/bin/remove_ext $ConcatName))
# But, then generate the absolute path so we can reuse the code from hcp_fix_multi_run
ConcatName="${StudyFolder}/${Session}/MNINonLinear/Results/${ConcatNameOnly}/${ConcatNameOnly}"

# If we have a hand classification and no regname, reapply fix to the volume as well
if have_hand_reclassification ${StudyFolder} ${Session} ${ConcatNameOnly} ${hp}
then
	fixlist="HandNoise.txt"
	#TSC: if regname (which applies to the surface) isn't NONE, assume the hand classification was previously already applied to the volume data
	if [[ "${RegName}" == "NONE" ]]
	then
		DoVol=1
	fi
fi
log_Msg "Use fixlist=$fixlist"

fmris=${fMRINames//@/ } # replaces the @ that combines the filenames with a space
log_Msg "fmris: ${fmris}"

DIR=`pwd`
log_Msg "PWD : $DIR"

## MPH: Create a high level variable that checks whether the files necessary for fix_3_clean
## already exist (i.e., reapplying FIX cleanup following manual classification).
## If so, we can skip all the following looping through individual runs and concatenation,
## and resume at the "Housekeeping related to files expected for fix_3_clean" section

ConcatNameNoExt=$($FSLDIR/bin/remove_ext $ConcatName)  # No extension, but still includes the directory path

regenConcatHP=0
if [[ ! -f "${ConcatNameNoExt}_Atlas${RegString}_hp${hp}.dtseries.nii" || \
	( $DoVol == "1" && `$FSLDIR/bin/imtest "${ConcatNameNoExt}_hp${hp}"` != 1 ) ]]
then
	regenConcatHP=1
else  # Generate some messages that we are going to use already existing files
	log_Warn "${ConcatNameNoExt}_Atlas${RegString}_hp${hp}.dtseries.nii already exists."
	if (( DoVol )); then
		log_Warn "$($FSLDIR/bin/imglob -extension ${ConcatNameNoExt}_hp${hp}) already exists."
	fi
	log_Warn "Using preceding existing concatenated file(s) for recleaning."
fi

####### BEGIN: Skip a whole bunch of code unless regenConcatHP=1 ########
if (( regenConcatHP )); then

	# This 'if' clause terminates at the start of the
	# "Housekeeping related to files expected for fix_3_clean" section

	###LOOP HERE --> Since the files are being passed as a group

	#echo $fmris | tr ' ' '\n' #separates paths separated by ' '

	## ---------------------------------------------------------------------------
	## Preparation (highpass) on the individual runs
	## ---------------------------------------------------------------------------

	#Loops over the runs and do highpass on each of them
	log_Msg "Looping over files and doing highpass to each of them"

	NIFTIvolMergeArray=()
	NIFTIvolhpVNMergeArray=()
	SBRefVolArray=()
	MeanVolArray=()
	VNVolArray=()
	CIFTIMergeArray=()
	CIFTIhpVNMergeArray=()
	MeanCIFTIArray=()
	VNCIFTIArray=()

	for fmriname in $fmris ; do
		# fmriname is expected to NOT include path info, or a nifti extension; make sure that is indeed the case
		fmriname=$(basename $($FSLDIR/bin/remove_ext $fmriname))
		# But, then generate the absolute path so we can reuse the code from hcp_fix_multi_run
		fmri="${StudyFolder}/${Session}/MNINonLinear/Results/${fmriname}/${fmriname}"

		log_Msg "Top of loop through fmris: fmri: ${fmri}"

		fmriNoExt=$($FSLDIR/bin/remove_ext $fmri)  # $fmriNoExt still includes leading directory components

		# Create necessary strings for merging across runs
		# N.B. Some of these files don't exist yet, and are about to get created
		NIFTIvolMergeArray+=("${fmriNoExt}_demean")
		NIFTIvolhpVNMergeArray+=("${fmriNoExt}_hp${hp}_vnts")  #These are the individual run, VN'ed *time series*
		SBRefVolArray+=("${fmriNoExt}_SBRef")
		MeanVolArray+=("${fmriNoExt}_mean")
		VNVolArray+=("${fmriNoExt}_hp${hp}_vn")  #These are the individual run, VN'ed NIFTI *maps* (created by functionhighpassandvariancenormalize)
		CIFTIMergeArray+=(-cifti "${fmriNoExt}_Atlas${RegString}_demean.dtseries.nii")
		CIFTIhpVNMergeArray+=(-cifti "${fmriNoExt}_Atlas${RegString}_hp${hp}_vn.dtseries.nii")
		MeanCIFTIArray+=(-cifti "${fmriNoExt}_Atlas${RegString}_mean.dscalar.nii")
		VNCIFTIArray+=(-cifti "${fmriNoExt}_Atlas${RegString}_hp${hp}_vn.dscalar.nii")  #These are the individual run, VN'ed CIFTI *maps* (created by functionhighpassandvariancenormalize)

		cd `dirname $fmri`
		fmri=`basename $fmri`  # After this, $fmri no longer includes the leading directory components
		fmri=`$FSLDIR/bin/imglob $fmri`  # After this, $fmri will no longer have an extension (if there was one initially)
		log_Msg "fmri: $fmri"
		if [ `$FSLDIR/bin/imtest $fmri` != 1 ]; then
			log_Err_Abort "Invalid 4D_FMRI input file specified: ${fmri}"
		fi

		#Demean volumes
		if (( DoVol )); then
			if [ `$FSLDIR/bin/imtest ${fmri}_demean` != 1 ]; then
				${FSLDIR}/bin/fslmaths $fmri -Tmean ${fmri}_mean
				${FSLDIR}/bin/fslmaths $fmri -sub ${fmri}_mean ${fmri}_demean
			else
				log_Warn "$($FSLDIR/bin/imglob -extension ${fmri}_demean) already exists. Using existing version"
			fi
		fi

		#Demean CIFTI
		if [[ ! -f ${fmriNoExt}_Atlas${RegString}_demean.dtseries.nii ]]; then
			"${Caret7_Command}" -cifti-reduce ${fmriNoExt}_Atlas${RegString}.dtseries.nii MEAN ${fmriNoExt}_Atlas${RegString}_mean.dscalar.nii
			"${Caret7_Command}" -cifti-math "TCS - MEAN" ${fmriNoExt}_Atlas${RegString}_demean.dtseries.nii -var TCS ${fmriNoExt}_Atlas${RegString}.dtseries.nii -var MEAN ${fmriNoExt}_Atlas${RegString}_mean.dscalar.nii -select 1 1 -repeat
		else
			log_Warn "${fmriNoExt}_Atlas${RegString}_demean.dtseries.nii already exists. Using existing version"
		fi

		# ReApplyFixMultiRunPipeline has only a single pass through functionhighpassandvariancenormalize.
		# whereas hcp_fix_multi_run has two (because it runs melodic, which is not re-run here).
		# So, the "1st pass" VN is the only-pass, and there is no "2nd pass" VN.
		# Note that functionhighpassandvariancenormalize internally determines whether to process
		# the volume based on whether ${RegString} is empty. (Thus no explicit DoVol conditional
		# in the following).
		# If ${RegString} is empty, the movement regressors will also automatically get re-filtered.

		tr=`$FSLDIR/bin/fslval $fmri pixdim4 | tr -d ' '`  #No checking currently that TR is same across runs
		log_Msg "tr: $tr"

		## Check if "1st pass" VN on the individual runs is needed; high-pass gets done here as well
		## Note that the existence of the HP'ed, VN timeseries and VN maps is all that matters here for
		## creating the "final" ${ConcatNameNoExt}*_hp${hp}.{dtseries.nii,nii.gz} files.
		## (i.e., whether the individual run _hp${hp}.dtseries and _hp${hp}.nii.gz files exist is irrelevant)
		if [[ ! -f "${fmriNoExt}_Atlas${RegString}_hp${hp}_vn.dtseries.nii" || \
			! -f "${fmriNoExt}_Atlas${RegString}_vn.dscalar.nii" || \
			( $DoVol == "1" && \
			( `$FSLDIR/bin/imtest "${fmriNoExt}_hp${hp}_vnts"` != 1 || \
				`$FSLDIR/bin/imtest "${fmriNoExt}_hp${hp}_vn"` != 1 ) ) ]]
		then

			log_Msg "processing FMRI file $fmri with highpass $hp"
			case ${MatlabMode} in
			0)
				# Use Compiled Matlab
				matlab_exe="${HCPPIPEDIR}"
				matlab_exe+="/ICAFIX/scripts/Compiled_functionhighpassandvariancenormalize/run_functionhighpassandvariancenormalize.sh"

				# Do NOT enclose string variables inside an additional single quote because all
				# variables are already passed into the compiled binary as strings
				matlab_function_arguments=("${tr}" "${hp}" "${fmri}" "${Caret7_Command}" "${RegString}" "${volwisharts}" "${ciftiwisharts}" "${icadimmode}")

				# ${MATLAB_COMPILER_RUNTIME} contains the location of the MCR used to compile functionhighpassandvariancenormalize.m
				matlab_cmd=("${matlab_exe}" "${MATLAB_COMPILER_RUNTIME}" "${matlab_function_arguments[@]}")

				# redirect tokens must be parsed by bash before doing variable expansion, and thus can't be inside a variable
				# MPH: Going to let Compiled MATLAB use the existing stdout and stderr, rather than creating a separate log file
				#matlab_logfile=".reapplyfixmultirun.${concatfmri}${RegString}.functionhighpassandvariancenormalize.log"
				#"${matlab_cmd[@]}" >> "${matlab_logfile}" 2>&1
				log_Msg "Run compiled MATLAB: ${matlab_cmd[*]}"
				"${matlab_cmd[@]}"
				;;

			1 | 2)
				# Use interpreted MATLAB or Octave
				# ${hp} needs to be passed in as a string, to handle the hp=pd* case
				matlab_code="${ML_PATHS} functionhighpassandvariancenormalize(${tr}, '${hp}', '${fmri}', '${Caret7_Command}', '${RegString}', ${volwisharts}, ${ciftiwisharts}, '${icadimmode}');"

				log_Msg "Run interpreted MATLAB/Octave (${matlab_interpreter[*]}) with code..."
				log_Msg "${matlab_code}"
				# Use bash redirection ("here-string") to pass multiple commands into matlab
				# (Necessary to protect the semicolons that separate matlab commands, which would otherwise
				# get interpreted as separating different bash shell commands)
				"${matlab_interpreter[@]}" <<<"${matlab_code}"
				echo #matlab output doesn't include a newline, so add one
				;;

			*)
				# Unsupported MATLAB run mode
				log_Err_Abort "Unsupported MATLAB run mode value: ${MatlabMode}"
				;;

			esac

			# Demean the movement regressors (in the 'fake-NIFTI' format returned by functionhighpassandvariancenormalize)
			# MPH: This is irrelevant, since we aren't doing anything with these files.
			# (i.e,. not regenerating ${concatfmrihp}.ica/mc/prefiltered_func_data_mcf_conf)
			# But do it anyway, just to ensure that the files left behind are demeaned in the DoVol case
			if (( DoVol )); then
				fslmaths ${fmri}_hp${hp}.ica/mc/prefiltered_func_data_mcf_conf -Tmean ${fmri}_hp${hp}.ica/mc/prefiltered_func_data_mcf_conf_mean
				fslmaths ${fmri}_hp${hp}.ica/mc/prefiltered_func_data_mcf_conf -sub ${fmri}_hp${hp}.ica/mc/prefiltered_func_data_mcf_conf_mean ${fmri}_hp${hp}.ica/mc/prefiltered_func_data_mcf_conf
				$FSLDIR/bin/imrm ${fmri}_hp${hp}.ica/mc/prefiltered_func_data_mcf_conf_mean
			fi

			log_Msg "Dims: $(cat ${fmri}_dims.txt)"

		else
			log_Warn "Skipping functionhighpassandvariancenormalize because expected files for ${fmri} already exist"

		fi

		cd ${DIR}  # Return to directory where script was launched

		log_Msg "Bottom of loop through fmris: fmri: ${fmri}"

	done  ###END LOOP (for fmriname in $fmris; do)

	## ---------------------------------------------------------------------------
	## Concatenate the individual runs and create necessary files
	## ---------------------------------------------------------------------------

	if (( DoVol )); then
		if [ `$FSLDIR/bin/imtest ${ConcatNameNoExt}_hp${hp}` != 1 ]; then
			# Merge volumes from the individual runs
			fslmerge -tr "${ConcatNameNoExt}_demean" "${NIFTIvolMergeArray[@]}" $tr
			fslmerge -tr "${ConcatNameNoExt}_hp${hp}_vnts" "${NIFTIvolhpVNMergeArray[@]}" $tr
			fslmerge -t  "${ConcatNameNoExt}_SBRef" "${SBRefVolArray[@]}"
			fslmerge -t  "${ConcatNameNoExt}_mean" "${MeanVolArray[@]}"
			fslmerge -t  "${ConcatNameNoExt}_hp${hp}_vn" "${VNVolArray[@]}"
			# Average across runs
			fslmaths "${ConcatNameNoExt}_SBRef" -Tmean "${ConcatNameNoExt}_SBRef"
			fslmaths "${ConcatNameNoExt}_mean" -Tmean "${ConcatNameNoExt}_mean"  # "Grand" mean across runs
			fslmaths "${ConcatNameNoExt}_demean" -add "${ConcatNameNoExt}_mean" "${ConcatNameNoExt}"
			# Preceding line adds back in the "grand" mean
			# Resulting file not used below, but want this concatenated version (without HP or VN) to exist
			fslmaths "${ConcatNameNoExt}_hp${hp}_vn" -Tmean ${ConcatNameNoExt}_hp${hp}_vn  # Mean VN map across the individual runs
			fslmaths "${ConcatNameNoExt}_hp${hp}_vnts" -mul "${ConcatNameNoExt}_hp${hp}_vn" "${ConcatNameNoExt}_hp${hp}"
			  # Preceding line restores the mean VN map
			fslmaths "${ConcatNameNoExt}_SBRef" -bin "${ConcatNameNoExt}_brain_mask"
			  # Preceding line creates mask to be used in melodic for suppressing memory error - Takuya Hayashi
		else
			log_Warn "$($FSLDIR/bin/imglob -extension ${ConcatNameNoExt}_hp${hp}) already exists. Using existing version"
		fi
	fi

	# Same thing for the CIFTI
	if [[ ! -f ${ConcatNameNoExt}_Atlas${RegString}_hp${hp}.dtseries.nii ]]; then
		"${Caret7_Command}" -cifti-merge "${ConcatNameNoExt}_Atlas${RegString}_demean.dtseries.nii" "${CIFTIMergeArray[@]}"
		"${Caret7_Command}" -cifti-average "${ConcatNameNoExt}_Atlas${RegString}_mean.dscalar.nii" "${MeanCIFTIArray[@]}"
		"${Caret7_Command}" -cifti-math "TCS + MEAN" "${ConcatNameNoExt}_Atlas${RegString}.dtseries.nii" -var TCS "${ConcatNameNoExt}_Atlas${RegString}_demean.dtseries.nii" -var MEAN "${ConcatNameNoExt}_Atlas${RegString}_mean.dscalar.nii" -select 1 1 -repeat
		"${Caret7_Command}" -cifti-merge "${ConcatNameNoExt}_Atlas${RegString}_hp${hp}_vn.dtseries.nii" "${CIFTIhpVNMergeArray[@]}"
		"${Caret7_Command}" -cifti-average "${ConcatNameNoExt}_Atlas${RegString}_hp${hp}_vn.dscalar.nii" "${VNCIFTIArray[@]}"
		"${Caret7_Command}" -cifti-math "TCS * VN" "${ConcatNameNoExt}_Atlas${RegString}_hp${hp}.dtseries.nii" -var TCS "${ConcatNameNoExt}_Atlas${RegString}_hp${hp}_vn.dtseries.nii" -var VN "${ConcatNameNoExt}_Atlas${RegString}_hp${hp}_vn.dscalar.nii" -select 1 1 -repeat
	else
		log_Warn "${ConcatNameNoExt}_Atlas${RegString}_hp${hp}.dtseries.nii already exists. Using existing version"
	fi

	# At this point the concatenated VN'ed time series (both volume and CIFTI, following the "1st pass" VN) can be deleted
	# MPH: Conditional on DoVol not needed in the following, since at worst, we'll try removing a file that doesn't exist
	log_Msg "Removing the concatenated VN'ed time series"
	$FSLDIR/bin/imrm ${ConcatNameNoExt}_hp${hp}_vnts
	/bin/rm -f ${ConcatNameNoExt}_Atlas${RegString}_hp${hp}_vn.dtseries.nii

	# Nor do we need the concatenated demeaned time series (either volume or CIFTI)
	log_Msg "Removing the concatenated demeaned time series"
	$FSLDIR/bin/imrm ${ConcatNameNoExt}_demean
	/bin/rm -f ${ConcatNameNoExt}_Atlas${RegString}_demean.dtseries.nii

	# Also, we no longer need the individual run VN'ed or demeaned time series (either volume or CIFTI); delete to save space
	for fmriname in $fmris ; do
		# fmriname is expected to NOT include path info, or a nifti extension; make sure that is indeed the case
		fmriname=$(basename $($FSLDIR/bin/remove_ext $fmriname))
		# But, then generate the absolute path so we can reuse the code from hcp_fix_multi_run
		fmri="${StudyFolder}/${Session}/MNINonLinear/Results/${fmriname}/${fmriname}"

		log_Msg "Removing the individual run VN'ed and demeaned time series for ${fmri}"

		fmriNoExt=$($FSLDIR/bin/remove_ext $fmri)  # $fmriNoExt still includes leading directory components
		$FSLDIR/bin/imrm ${fmriNoExt}_hp${hp}_vnts
		$FSLDIR/bin/imrm ${fmriNoExt}_demean
		/bin/rm -f ${fmriNoExt}_Atlas${RegString}_hp${hp}_vn.dtseries.nii
		/bin/rm -f ${fmriNoExt}_Atlas${RegString}_demean.dtseries.nii

		log_Msg "Removing the individual run HP'ed time series for ${fmri}"
		$FSLDIR/bin/imrm ${fmriNoExt}_hp${hp}
		/bin/rm -f ${fmriNoExt}_Atlas${RegString}_hp${hp}.dtseries.nii
	done

fi   #	if (( regenConcatHP )); then
## Terminate the 'if' clause of the conditional that checked whether
## the large block of preceding code needed to be run.
####### END: Skip a whole bunch of code unless regenConcatHP=1 ########

## ---------------------------------------------------------------------------
## Housekeeping related to files expected for fix_3_clean
## ---------------------------------------------------------------------------

ConcatFolder=`dirname ${ConcatName}`
cd ${ConcatFolder}

concatfmri=`basename ${ConcatNameNoExt}`  # Directory path is now removed
concatfmrihp=${concatfmri}_hp${hp}

#this directory should exist and not be empty (i.e., melodic has already been run)
cd ${concatfmrihp}.ica

# This is the concated volume time series from the 1st pass VN, with requested
# hp-filtering applied and with the mean VN map multiplied back in
${FSLDIR}/bin/imrm filtered_func_data
if (( DoVol ))
then
	if [ `$FSLDIR/bin/imtest ../${concatfmrihp}` != 1 ]; then
		log_Err_Abort "FILE NOT FOUND: ../${concatfmrihp}"
	fi
	${FSLDIR}/bin/imln ../${concatfmrihp} filtered_func_data
else
	#fix_3_clean is hardcoded to pull the TR from "filtered_func_data", so we have to make sure
	#something with the right TR is there (to avoid getting a scary sounding "No image file match" message,
	#and TR=[] (empty), although TR only matters if hp>0, and we have AlreadyHP=-1, so this is really
	#just for good hygene in the log files)
	${FSLDIR}/bin/imln ../${concatfmrihp}_clean filtered_func_data
fi

# This is the concated CIFTI time series from the 1st pass VN, with requested
# hp-filtering applied and with the mean VN map multiplied back in
# Unlike single-run FIX (i.e., 'hcp_fix' and 'ReApplyFixPipeline'), here we symlink
# to the hp-filtered CIFTI and use "AlreadyHP=-1" to skip any additional filtering in fix_3_clean.
if [[ -f ../${concatfmri}_Atlas${RegString}_hp${hp}.dtseries.nii ]] ; then
	log_Msg "FOUND FILE: ../${concatfmri}_Atlas${RegString}_hp${hp}.dtseries.nii"
	log_Msg "Performing imln"

	/bin/rm -f Atlas.dtseries.nii
	$FSLDIR/bin/imln ../${concatfmri}_Atlas${RegString}_hp${hp}.dtseries.nii Atlas.dtseries.nii

	log_Msg "START: Showing linked files"
	ls -l ../${concatfmri}_Atlas${RegString}_hp${hp}.dtseries.nii
	ls -l Atlas.dtseries.nii
	log_Msg "END: Showing linked files"
else
	log_Err_Abort "FILE NOT FOUND: ../${concatfmri}_Atlas${RegString}_hp${hp}.dtseries.nii"
fi

## ---------------------------------------------------------------------------
## Run fix_3_clean
## ---------------------------------------------------------------------------

# MPH: We need to invoke fix_3_clean directly, rather than through 'fix -a <options>' because
# the latter does not provide access to the "DoVol" option within the former.
# (Also, 'fix -a' is hard-coded to use '.fix' as the list of noise components, although that
# could be worked around).

log_Msg "Running fix_3_clean"

AlreadyHP="-1"

case ${MatlabMode} in
	0)
		# Use Compiled Matlab

		matlab_exe="${HCPPIPEDIR}/ICAFIX/scripts/Compiled_fix_3_clean/run_fix_3_clean.sh"

		# Do NOT enclose string variables inside an additional single quote because all
		# variables are already passed into the compiled binary as strings
		matlab_function_arguments=("${fixlist}" "${aggressive}" "${MotionRegression}" "${AlreadyHP}" "${Caret7_Command}" "${DoVol}")

		matlab_cmd=("${matlab_exe}" "${MATLAB_COMPILER_RUNTIME}" "${matlab_function_arguments[@]}")

		# redirect tokens must be parsed by bash before doing variable expansion, and thus can't be inside a variable
		# MPH: Going to let Compiled MATLAB use the existing stdout and stderr, rather than creating a separate log file
		#matlab_logfile=".reapplyfixmultirun.${concatfmri}${RegString}.fix_3_clean.matlab.log"
		#log_Msg "Run MATLAB command: ${matlab_cmd[*]} >> ${matlab_logfile} 2>&1"
		#"${matlab_cmd[@]}" >> "${matlab_logfile}" 2>&1
		log_Msg "Run compiled MATLAB: ${matlab_cmd[*]}"
		"${matlab_cmd[@]}"
		;;

	1 | 2)
		# Use interpreted MATLAB or Octave

		matlab_code="${ML_PATHS} fix_3_clean('${fixlist}',${aggressive},${MotionRegression},${AlreadyHP},'${Caret7_Command}',${DoVol});"

		log_Msg "Run interpreted MATLAB/Octave (${matlab_interpreter[*]}) with code..."
		log_Msg "${matlab_code}"
		"${matlab_interpreter[@]}" <<<"${matlab_code}"
		;;
	*)
		# Unsupported MATLAB run mode
		log_Err_Abort "Unsupported MATLAB run mode value: ${MatlabMode}"
		;;
esac

log_Msg "Done running fix_3_clean"

# Return to ${ConcatFolder}
# Do not use 'cd ${ConcatFolder}', because ${ConcatFolder} may not be an absolute path
cd ..

## ---------------------------------------------------------------------------
## Rename some files (relative to the default names coded in fix_3_clean)
## ---------------------------------------------------------------------------

# Remove any existing old versions of the cleaned data (normally they should be overwritten
# in the renaming that follows, but this ensures that any old versions don't linger)
/bin/rm -f ${concatfmri}_Atlas${RegString}_hp${hp}_${CleanSubstring}.dtseries.nii
/bin/rm -f ${concatfmri}_Atlas${RegString}_hp${hp}_${CleanSubstring}_vn.dscalar.nii

if (( DoVol )); then
	$FSLDIR/bin/imrm  ${concatfmrihp}_${CleanSubstring}
	$FSLDIR/bin/imrm  ${concatfmrihp}_${CleanSubstring}_vn
fi

# Rename some of the outputs from fix_3_clean.
# Note that the variance normalization ("_vn") outputs require use of fix1.067 or later
# So check whether those files exist before moving/renaming them
if [ -f ${concatfmrihp}.ica/Atlas_clean.dtseries.nii ]; then
	/bin/mv ${concatfmrihp}.ica/Atlas_clean.dtseries.nii ${concatfmri}_Atlas${RegString}_hp${hp}_${CleanSubstring}.dtseries.nii
else
	log_Err_Abort "Something went wrong; ${concatfmrihp}.ica/Atlas_clean.dtseries.nii wasn't created"
fi
if [ -f ${concatfmrihp}.ica/Atlas_clean_vn.dscalar.nii ]; then
	/bin/mv ${concatfmrihp}.ica/Atlas_clean_vn.dscalar.nii ${concatfmri}_Atlas${RegString}_hp${hp}_${CleanSubstring}_vn.dscalar.nii
fi

if (( DoVol )); then
	$FSLDIR/bin/immv ${concatfmrihp}.ica/filtered_func_data_clean ${concatfmrihp}_${CleanSubstring}
	if [ "$?" -ne "0" ]; then
		log_Err_Abort "Something went wrong; ${concatfmrihp}.ica/filtered_func_data_clean wasn't created"
	fi
	if [ `$FSLDIR/bin/imtest ${concatfmrihp}.ica/filtered_func_data_clean_vn` = 1 ]; then
		$FSLDIR/bin/immv ${concatfmrihp}.ica/filtered_func_data_clean_vn ${concatfmrihp}_${CleanSubstring}_vn
	fi

	# Convert sICA+FIX cleaned movement regressors to text
	if [ -f ${concatfmrihp}.ica/mc/prefiltered_func_data_mcf_conf_hp_clean.nii.gz ] ; then
		fslmeants -i ${concatfmrihp}.ica/mc/prefiltered_func_data_mcf_conf_hp_clean.nii.gz -o Movement_Regressors_hp${hp}_clean.txt --showall
		# Strip header lines included as part of '--showall' flag
		nVols=$($FSLDIR/bin/fslnvols ${concatfmrihp}.ica/mc/prefiltered_func_data_mcf_conf_hp_clean.nii.gz)
		# Execute tail in a subshell, so we can successfully overwrite file with same name
		echo "$(tail -n ${nVols} Movement_Regressors_hp${hp}_clean.txt)" > Movement_Regressors_hp${hp}_clean.txt
	fi

fi
log_Msg "Done renaming files"

# Remove the 'fake-NIFTI' file created in fix_3_clean for high-pass filtering of the CIFTI (if it exists)
$FSLDIR/bin/imrm ${concatfmrihp}.ica/Atlas

# Always delete things with too-generic names
$FSLDIR/bin/imrm ${concatfmrihp}.ica/filtered_func_data
rm -f ${concatfmrihp}.ica/Atlas.dtseries.nii

# Optional deletion of highpass intermediates and the concatenated (non-filtered) time series
# (hp<0 not supported in this script currently, so no need to condition on value of hp)
if [ "${DeleteIntermediates}" == "1" ]
then
	$FSLDIR/bin/imrm ${concatfmri} ${concatfmrihp}
	rm -f ${concatfmri}_Atlas.dtseries.nii ${concatfmri}_Atlas_hp${hp}.dtseries.nii
fi

## ---------------------------------------------------------------------------
## Split the cleaned volume and CIFTI back into individual runs.
## ---------------------------------------------------------------------------

## The cleaned volume and CIFTI have no mean.
## The time series of the individual runs were variance normalized via the 1st pass through functionhighpassandvariancenormalize.
## The mean VN map (across runs) was then multiplied into the concatenated time series, and that became the input to FIX.
## We now reverse that process.
## i.e., the mean VN (across runs) is divided back out, and the VN map for the individual run multiplied back in.
## Then the mean is added back in to return the timeseries to its original state minus the noise (as estimated by FIX).

cd ${DIR}  # Return to directory where script was launched

log_Msg "Splitting cifti back into individual runs"
if (( DoVol )); then
	log_Msg "Also splitting nifti back into individual runs"
fi
Start="1"
for fmriname in $fmris ; do
	# fmriname is expected to NOT include path info, or a nifti extension; make sure that is indeed the case
	fmriname=$(basename $($FSLDIR/bin/remove_ext $fmriname))
	# But, then generate the absolute path so we can reuse the code from hcp_fix_multi_run
	fmri="${StudyFolder}/${Session}/MNINonLinear/Results/${fmriname}/${fmriname}"

	fmriNoExt=$($FSLDIR/bin/remove_ext $fmri)  # $fmriNoExt still includes leading directory components
	NumTPS=`"${Caret7_Command}" -file-information ${fmriNoExt}_Atlas${RegString}.dtseries.nii -no-map-info -only-number-of-maps`
	Stop=`echo "${NumTPS} + ${Start} -1" | bc -l`
	log_Msg "${fmriNoExt}: Start=${Start} Stop=${Stop}"

	cifti_out=${fmriNoExt}_Atlas${RegString}_hp${hp}_${CleanSubstring}.dtseries.nii
	"${Caret7_Command}" -cifti-merge ${cifti_out} -cifti ${ConcatFolder}/${concatfmri}_Atlas${RegString}_hp${hp}_${CleanSubstring}.dtseries.nii -column ${Start} -up-to ${Stop}
	"${Caret7_Command}" -cifti-math "((TCS / VNA) * VN) + Mean" ${cifti_out} -var TCS ${cifti_out} -var VNA ${ConcatFolder}/${concatfmri}_Atlas${RegString}_hp${hp}_vn.dscalar.nii -select 1 1 -repeat -var VN ${fmriNoExt}_Atlas${RegString}_hp${hp}_vn.dscalar.nii -select 1 1 -repeat -var Mean ${fmriNoExt}_Atlas${RegString}_mean.dscalar.nii -select 1 1 -repeat

	readme_for_cifti_out=${cifti_out%.dtseries.nii}.README.txt
	touch ${readme_for_cifti_out}
	short_cifti_out=${cifti_out##*/}
	# MPH: Overwrite file, if it already exists
	echo "${short_cifti_out} was generated by applying \"multi-run FIX\" (using '${g_script_name}')" >| ${readme_for_cifti_out}
	echo "across the following individual runs:" >> ${readme_for_cifti_out}
	for readme_fmri_name in ${fmris} ; do
		# Make sure that readme_fmri_name is indeed without path or extension
		readme_fmri_name=$(basename $($FSLDIR/bin/remove_ext $readme_fmri_name))
		# But, then generate the absolute path so we can reuse the code from hcp_fix_multi_run
		readme_fmri="${StudyFolder}/${Session}/MNINonLinear/Results/${readme_fmri_name}/${readme_fmri_name}"
		echo "  ${readme_fmri}" >> ${readme_for_cifti_out}
	done

	if (( DoVol )); then
		volume_out=${fmriNoExt}_hp${hp}_${CleanSubstring}.nii.gz
		"${Caret7_Command}" -volume-merge ${volume_out} -volume ${ConcatFolder}/${concatfmrihp}_${CleanSubstring}.nii.gz -subvolume ${Start} -up-to ${Stop}
		fslmaths ${volume_out} -div ${ConcatFolder}/${concatfmrihp}_vn -mul ${fmriNoExt}_hp${hp}_vn -add ${fmriNoExt}_mean ${volume_out}

		# Convert sICA+FIX cleaned movement regressors to text
		if [ -f ${ConcatFolder}/${concatfmrihp}.ica/mc/prefiltered_func_data_mcf_conf_hp_clean.nii.gz ] ; then
			${Caret7_Command} -volume-merge ${fmriNoExt}_hp${hp}.ica/mc/prefiltered_func_data_mcf_conf_hp_clean.nii.gz -volume ${ConcatFolder}/${concatfmrihp}.ica/mc/prefiltered_func_data_mcf_conf_hp_clean.nii.gz -subvolume ${Start} -up-to ${Stop}
			fmriDir=$(dirname $fmri)
			fslmeants -i ${fmriNoExt}_hp${hp}.ica/mc/prefiltered_func_data_mcf_conf_hp_clean.nii.gz -o ${fmriDir}/Movement_Regressors_hp${hp}_clean.txt --showall
			# Strip header lines included as part of '--showall' flag
			nVols=$($FSLDIR/bin/fslnvols ${fmriNoExt}_hp${hp}.ica/mc/prefiltered_func_data_mcf_conf_hp_clean.nii.gz)
			# Execute tail in a subshell, so we can successfully overwrite file with same name
			echo "$(tail -n ${nVols} ${fmriDir}/Movement_Regressors_hp${hp}_clean.txt)" > ${fmriDir}/Movement_Regressors_hp${hp}_clean.txt
		fi
	fi
	Start=`echo "${Start} + ${NumTPS}" | bc -l`
done

cd ${DIR}

log_Msg "Completed!"
