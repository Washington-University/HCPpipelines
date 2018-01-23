#!/bin/bash

#
# # ReApplyFixPipelineMultiRun.sh
#
# ## Copyright Notice
#
# Copyright (C) 2017 The Human Connectome Project/Connectome Coordination Facility
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

usage()
{
	local script_name
	script_name=$(basename "${0}")

	cat <<EOF

${script_name}: ReApplyFix Pipeline for MultiRun ICA+FIX

Usage: ${script_name} PARAMETER...

PARAMETERs are [ ] = optional; < > = user supplied value

  Note: The PARAMETERs can be specified positinally (i.e. without using the --param=value
        form) by simply specifying all values on the command line in the order they are
		listed below.

		e.g. ${script_name} <path to study folder> <subject ID> <fMRINames> ...

  [--help] : show this usage information and exit
   --path=<path to study folder> OR --study-folder=<path to study folder>
   --subject=<subject ID> (e.g. 100610)
   --fmri-names=<fMRI Names> @-separated list of fMRI file names 
     (e.g. /path/to/study/100610/MNINonLinear/Results/tfMRI_RETCCW_7T_AP/tfMRI_RETCCW_7T_AP.nii.gz@/path/to/study/100610/MNINonLinear/Results/tfMRI_RETCW_7T_PA/tfMRI_RETCW_7T_PA.nii.gz)
   --concat-fmri-name=<concatenated fMRI scan file name>
     (e.g. /path/to/study/100610/MNINonLinear/Results/tfMRI_7T_RETCCW_AP_RETCW_PA/tfMRI_7T_RETCCW_AP_RETCW_PA.nii.gz)
   --high-pass=<num> the HighPass variable used in Multi-run ICA+FIX (e.g. 2000)
   --reg-name=<registration name> (e.g. MSMAll)
  [--low-res-mesh=<low res mesh number>] defaults to ${G_DEFAULT_LOW_RES_MESH}
  [--matlab-run-mode={0, 1}] defaults to ${G_DEFAULT_MATLAB_RUN_MODE}
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
	unset p_StudyFolder      # ${1}
	unset p_Subject          # ${2}
	unset p_fMRINames        # ${3}
	unset p_ConcatfMRIName   # ${4}
	unset p_HighPass         # ${5}
	unset p_RegName          # ${6}
	unset p_LowResMesh       # ${7}
	unset p_MatlabRunMode    # ${8}

	# set default values
	p_LowResMesh=${G_DEFAULT_LOW_RES_MESH}
	p_MatlabRunMode=${G_DEFAULT_MATLAB_RUN_MODE}
	
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
			--fmri-names=*)
				p_fMRINames=${argument#*=}
				index=$(( index + 1 ))
				;;
			--concat-fmri-name=*)
				p_ConcatfMRIName=${argument#*=}
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
			*)
				usage
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

	if [ -z "${p_fMRINames}" ]; then
		log_Err "fMRI Names (--fmri-names=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "fMRI Names: ${p_fMRINames}"
	fi

	if [ -z "${p_ConcatfMRIName}" ]; then
		log_Err "Concatenated fMRI scan name (--concat-fmri-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Concatenated fMRI scan name: ${p_ConcatfMRIName}"
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
				if [ -z "${MATLAB_COMPILER_RUNTIME}" ]; then
					log_Err_Abort "To use MATLAB run mode: ${p_MatlabRunMode}, the MATLAB_COMPILER_RUNTIME environment variable must be set"
				else
					log_Msg "MATLAB_COMPILER_RUNTIME: ${MATLAB_COMPILER_RUNTIME}"
				fi
				;;
			1)
				log_Msg "MATLAB Run Mode: ${p_MatlabRunMode} - Use interpreted MATLAB"
				;;
			*)
				log_Err "MATLAB Run Mode value must be 0 or 1"
				error_count=$(( error_count + 1 ))
				;;
		esac
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
	cat ${HCPPIPEDIR}/version.txt

	# Show wb_command version
	log_Msg "Showing Connectome Workbench (wb_command) version"
	${CARET7DIR}/wb_command -version

	# Show fsl version
#	log_Msg "Showing FSL version"
#	fsl_version_get fsl_ver
#	log_Msg "FSL version: ${fsl_ver}"
}

main()
{
	# Show tool versions
	show_tool_versions

	log_Msg "Starting main functionality"

	# Retrieve positional parameters
	local StudyFolder="${1}"
	local Subject="${2}"
	local fMRINames="${3}"
	local ConcatfMRIName="${4}"
	local HighPass="${5}"
	local RegName="${6}"

	local LowResMesh
	if [ -z "${7}" ]; then
		LowResMesh=${G_DEFAULT_LOW_RES_MESH}
	else
		LowResMesh="${7}"
	fi
	
	local MatlabRunMode
	if [ -z "${8}" ]; then
		MatlabRunMode=${G_DEFAULT_MATLAB_RUN_MODE}
	else
		MatlabRunMode="${8}"
	fi

	# Log values retrieved from positional parameters
	log_Msg "StudyFolder: ${StudyFolder}"
	log_Msg "Subject: ${Subject}"
	log_Msg "fMRINames: ${fMRINames}"
	log_Msg "ConcatfMRIName: ${ConcatfMRIName}"
	log_Msg "HighPass: ${HighPass}"
	log_Msg "RegName: ${RegName}"
	log_Msg "LowResMesh: ${LowResMesh}"
	log_Msg "MatlabRunMode: ${MatlabRunMode}"

	# Naming Conventions and other variables
	local Caret7_Command="${CARET7DIR}/wb_command"
	log_Msg "Caret7_Command: ${Caret7_Command}"

	local RegString
	if [ "${RegName}" != "NONE" ] ; then
		RegString="_${RegName}"
	else
		RegString=""
	fi

	if [ ! -z ${LowResMesh} ] && [ ${LowResMesh} != ${G_DEFAULT_LOW_RES_MESH} ]; then
		RegString+=".${LowResMesh}k"
	fi

	log_Msg "RegString: ${RegString}"
	
	export FSL_FIX_CIFTIRW="${HCPPIPEDIR}/ReApplyFix/scripts"
	export FSL_FIX_WBC="${Caret7_Command}"
	export FSL_MATLAB_PATH="${FSLDIR}/etc/matlab"

	# Make appropriate files if they don't exist

	local aggressive=0
	local domot=1
	local hp=${HighPass}
	local fixlist=".fix"
	
	local fmris=${fMRINames//@/ } # replaces the @ that combines the filenames with a space
	log_Msg "fmris: ${fmris}"

	local ConcatName=${ConcatfMRIName}
	log_Msg "ConcatName: ${ConcatName}"

	DIR=`pwd`

	###LOOP HERE --> Since the files are being passed as a group

	echo $fmris | tr ' ' '\n' #separates paths separated by ' '

	#Loops over the files and does highpass to each of them
	CIFTIMergeSTRING=""
	CIFTIAverageMeanSTRING=""
	CIFTIMergeHpSTRING=""

	for fmri in $fmris ; do  
		CIFTIMergeSTRING=`echo "${CIFTIMergeSTRING} -cifti $($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}_demean.dtseries.nii"`
		CIFTIAverageMeanSTRING=`echo "${CIFTIAverageMeanSTRING} -cifti $($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}_mean.dscalar.nii"`
		CIFTIMergeHpSTRING=`echo "${CIFTIMergeHpSTRING} -cifti $($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}_hp$hp.dtseries.nii"`
		cd `dirname $fmri`
		fmri=`basename $fmri`
		fmri=`$FSLDIR/bin/imglob $fmri`
		#[ `imtest $fmri` != 1 ] && echo No valid 4D_FMRI input file specified && exit 1
		fmri_orig=$fmri

		tr=`$FSLDIR/bin/fslval $fmri pixdim4`
		hptr=`echo "10 k $hp 2 / $tr / p" | dc -` 

		echo $tr
		log_Msg "processing FMRI file $fmri with highpass $hp"
    
		${FSL_FIX_WBC} -cifti-convert -to-nifti ${fmri}_Atlas${RegString}.dtseries.nii ${fmri}_Atlas${RegString}_FAKENIFTI.nii.gz
		${FSLDIR}/bin/fslmaths ${fmri}_Atlas${RegString}_FAKENIFTI.nii.gz -bptf $hptr -1 ${fmri}_Atlas${RegString}_hp$hp_FAKENIFTI.nii.gz
		${FSL_FIX_WBC} -cifti-convert -from-nifti ${fmri}_Atlas${RegString}_hp$hp_FAKENIFTI.nii.gz ${fmri}_Atlas${RegString}.dtseries.nii ${fmri}_Atlas${RegString}_hp$hp.dtseries.nii
		$FSLDIR/bin/imrm ${fmri}_Atlas${RegString}_FAKENIFTI ${fmri}_Atlas${RegString}_hp$hp_FAKENIFTI
		${FSL_FIX_WBC} -cifti-reduce $($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}.dtseries.nii MEAN $($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}_mean.dscalar.nii
		${FSL_FIX_WBC} -cifti-math "TCS - MEAN" $($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}_demean.dtseries.nii -var TCS $($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}.dtseries.nii -var MEAN $($FSLDIR/bin/remove_ext $fmri)_Atlas${RegString}_mean.dscalar.nii -select 1 1 -repeat
		fmri=${fmri}_hp$hp
		cd ${fmri}.ica
		cd ..
	done
	###END LOOP

	AlreadyHP="-1"

	${FSL_FIX_WBC} -cifti-merge `remove_ext ${ConcatName}`_Atlas${RegString}_demean.dtseries.nii ${CIFTIMergeSTRING}
	${FSL_FIX_WBC} -cifti-average `remove_ext ${ConcatName}`_Atlas${RegString}_mean.dscalar.nii ${CIFTIAverageMeanSTRING}
	${FSL_FIX_WBC} -cifti-math "TCS + MEAN" `remove_ext ${ConcatName}`_Atlas${RegString}.dtseries.nii -var TCS `remove_ext ${ConcatName}`_Atlas${RegString}_demean.dtseries.nii -var MEAN `remove_ext ${ConcatName}`_Atlas${RegString}_mean.dscalar.nii -select 1 1 -repeat
	${FSL_FIX_WBC} -cifti-merge `remove_ext ${ConcatName}`_Atlas${RegString}_hp$hp.dtseries.nii ${CIFTIMergeHpSTRING}
	ConcatFolder=`dirname ${ConcatName}`
	cd ${ConcatFolder}
	##Check to see if concatination occured

	local concat_fmri_orig=`basename $(remove_ext ${ConcatName})`
	local concatfmri=`basename $(remove_ext ${ConcatName})`_hp$hp

	cd `remove_ext ${concatfmri}`.ica

	pwd
	echo ../${concat_fmri_orig}_Atlas${RegString}_hp$hp.dtseries.nii

	if [ -f ../${concat_fmri_orig}_Atlas${RegString}_hp$hp.dtseries.nii ] ; then
		log_Msg "FOUND FILE: ../${concat_fmri_orig}_Atlas${RegString}_hp$hp.dtseries.nii"
		log_Msg "Performing imln"

		rm -f Atlas.dtseries.nii
		$FSLDIR/bin/imln ../${concat_fmri_orig}_Atlas${RegString}_hp$hp.dtseries.nii Atlas.dtseries.nii
		
		log_Msg "START: Showing linked files"
		ls -l ../${concat_fmri_orig}_Atlas${RegString}_hp$hp.dtseries.nii
		ls -l Atlas.dtseries.nii
		log_Msg "END: Showing linked files"
	else
		log_Warn "FILE NOT FOUND: ../${concat_fmri_orig}_Atlas${RegString}_hp$hp.dtseries.nii"
	fi
	
	${FSLDIR}/bin/imln ../${concat_fmri_orig} filtered_func_data

	local DoVol="0"
	case ${MatlabRunMode} in
		0)
			# Use Compiled Matlab
			
			local matlab_exe="${HCPPIPEDIR}"
			matlab_exe+="/ReApplyFix/scripts/Compiled_fix_3_clean/run_fix_3_clean.sh"
	
			#matlab_compiler_runtime=${MATLAB_COMPILER_RUNTIME}
			local matlab_function_arguments="'${fixlist}' ${aggressive} ${domot} ${AlreadyHP} ${DoVol}"
			local matlab_logging=">> ${StudyFolder}/${Subject}_${concat_fmri_orig}_${HighPass}${RegString}.matlab.log 2>&1"
			local matlab_cmd="${matlab_exe} ${MATLAB_COMPILER_RUNTIME} ${matlab_function_arguments} ${matlab_logging}"

			# Note: Simply using ${matlab_cmd} here instead of echo "${matlab_cmd}" | bash
			#       does NOT work. The ouput redirects that are part of the ${matlab_logging}
			#       value, get quoted by the run_*.sh script generated by the MATLAB compiler
			#       such that they get passes as parameters to the underlying executable.
			#       So ">>" gets passed as a parameter to the executable as does the
			#       log file name and the "2>&1" redirection. This causes the executable
			#       to die with a "too many parameters" error message.
			log_Msg "Run MATLAB command: ${matlab_cmd}"
			echo "${matlab_cmd}" | bash
			log_Msg "MATLAB command return code $?"
			;;
		
		1)
			# Use interpreted MATLAB
			ML_PATHS="addpath('${FSL_MATLAB_PATH}'); addpath('${FSL_FIX_CIFTIRW}');"

			matlab -nojvm -nodisplay -nosplash <<M_PROG
${ML_PATHS} fix_3_clean('${fixlist}',${aggressive},${domot},${AlreadyHP},${DoVol});
M_PROG
			;;

		*)
			# Unsupported MATLAB run mode
			log_Err_Abort "Unsupported MATLAB run mode value: ${MatlabRunMode}"
			;;
	esac

	cd ..

	pwd
	echo ${concatfmri}.ica/Atlas_clean.dtseries.nii

	if [ -f ${concatfmri}.ica/Atlas_clean.dtseries.nii ] ; then
		/bin/mv ${concatfmri}.ica/Atlas_clean.dtseries.nii ${concat_fmri_orig}_Atlas${RegString}_hp${hp}_clean.dtseries.nii
	fi
	
	Start="1"
	for fmri in $fmris ; do
		NumTPS=`${FSL_FIX_WBC} -file-information $(remove_ext ${fmri})_Atlas${RegString}.dtseries.nii -no-map-info -only-number-of-maps`
		Stop=`echo "${NumTPS} + ${Start} -1" | bc -l`
		echo "Start=${Start} Stop=${Stop}"
		${FSL_FIX_WBC} -cifti-merge `remove_ext ${fmri}`_Atlas${RegString}_hp${hp}_clean.dtseries.nii -cifti ${concat_fmri_orig}_Atlas${RegString}_hp${hp}_clean.dtseries.nii -column ${Start} -up-to ${Stop}
		#${FSL_FIX_WBC} -cifti-reduce `remove_ext ${fmri}`_Atlas${RegString}.dtseries.nii MEAN `remove_ext ${fmri}`_Atlas${RegString}_mean.dscalar.nii
		${FSL_FIX_WBC} -cifti-math "TCS + Mean" `remove_ext ${fmri}`_Atlas${RegString}_hp${hp}_clean.dtseries.nii -var TCS `remove_ext ${fmri}`_Atlas${RegString}_hp${hp}_clean.dtseries.nii -var Mean `remove_ext ${fmri}`_Atlas${RegString}_mean.dscalar.nii -select 1 1 -repeat
		rm `remove_ext ${fmri}`_Atlas${RegString}_mean.dscalar.nii
		Start=`echo "${Start} + ${NumTPS}" | bc -l`
	done

	cd ${DIR}

	log_Msg "Completing main functionality"
}

# ------------------------------------------------------------------------------
#  "Global" processing - everything above here should be in a function
# ------------------------------------------------------------------------------

set -e # If any command exits with non-zero value, this script exits

# Verify that HCPPIPEDIR environment variable is set
if [ -z "${HCPPIPEDIR}" ]; then
	echo "$(basename ${0}): ABORTING: HCPPIPEDIR environment variable must be set"
	exit 1
fi

# Load function libraries
source ${HCPPIPEDIR}/global/scripts/log.shlib # Logging related functions
source ${HCPPIPEDIR}/global/scripts/fsl_version.shlib # Functions for getting FSL version
log_Msg "HCPPIPEDIR: ${HCPPIPEDIR}"

# Verify any other needed environment variables are set
log_Check_Env_Var CARET7DIR
log_Check_Env_Var FSLDIR

# Establish default MATLAB run mode
G_DEFAULT_MATLAB_RUN_MODE=1		# Use interpreted MATLAB

# Establish default low res mesh
G_DEFAULT_LOW_RES_MESH=32

# Determine whether named or positional parameters are used
if [[ ${1} == --* ]]; then
	# Named parameters (e.g. --parameter-name=parameter-value) are used
	log_Msg "Using named parameters"

	# Get command line options
	get_options "$@"

	# Invoke main functionality
	#     ${1}               ${2}           ${3}             ${4}                  ${5}            ${6}           ${7}              ${8}
	main "${p_StudyFolder}" "${p_Subject}" "${p_fMRINames}" "${p_ConcatfMRIName}" "${p_HighPass}" "${p_RegName}" "${p_LowResMesh}" "${p_MatlabRunMode}"

else
	# Positional parameters are used
	log_Msg "Using positional parameters"
	main "$@"

fi







