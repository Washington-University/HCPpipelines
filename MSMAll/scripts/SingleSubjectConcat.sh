#!/bin/bash

#~ND~FORMAT~MARKDOWN
#~ND~START~
#
# # SingleSubjectConcat.sh
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

# ------------------------------------------------------------------------------
#  Show usage information for this script
# ------------------------------------------------------------------------------

show_usage()
{
	cat <<EOF

${g_script_name}: Single Subject Scan Concatenation

Usage: ${g_script_name} PARAMETER...

PARAMETERs are [ ] = optional; < > = user supplied value

  [--help] : show usage information and exit
   --path=<path to study folder> OR --study-folder=<path to study folder>
   --subject=<subject ID>
   --fmri-names-list=<fMRI names> and @ symbol separated list of fMRI scan names
   --high-pass=<high-pass filter used in ICA+FIX>
   --output-fmri-name=<name to give to concatenated single subject "scan">
   --fmri-proc-string=<identification for FIX cleaned dtseries to use>
   --output-proc-string=TBW
   --demean=<YES | NO> demean or not the data
   --variance-normalization=<YES | NO> variance normalize the data or not 
   --compute-variance-normalization=<YES | NO> compute the variance normalization
        so as not to require having run the RestingStateStats pipeline
   --revert-bias-field=<YES | NO> revert the bias field or not
        Requires having run the RestingStateStats pipeline and is not necessary if 
        computing variance normalization above
  [--matlab-run-mode={0, 1, 2}] defaults to ${G_DEFAULT_MATLAB_RUN_MODE}
     0 = Use compiled MATLAB
     1 = Use interpreted MATLAB
     2 = Use Octave

EOF
}

# ------------------------------------------------------------------------------
#  Get the command line options for this script.
# ------------------------------------------------------------------------------

get_options()
{
	local arguments=($@)

	# initialize global output variables
	unset p_StudyFolder
	unset p_Subject
	unset p_fMRINames
	unset p_HighPass
	unset p_OutputfMRIName
	unset p_fMRIProcSTRING
	unset p_OutputProcSTRING
	unset p_Demean
	unset p_VarianceNormalization
	unset p_ComputeVarianceNormalization
	unset p_RevertBiasField
	unset p_MatlabRunMode
	
	# set default values
	p_MatlabRunMode=${G_DEFAULT_MATLAB_RUN_MODE}

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
			--fmri-names-list=*)
				p_fMRINames=${argument#*=}
				index=$(( index + 1 ))
				;;
			--high-pass=*)
				p_HighPass=${argument#*=}
				index=$(( index + 1 ))
				;;
			--output-fmri-name=*)
				p_OutputfMRIName=${argument#*=}
				index=$(( index + 1 ))
				;;
			--fmri-proc-string=*)
				p_fMRIProcSTRING=${argument#*=}
				index=$(( index + 1 ))
				;;
			--output-proc-string=*)
				p_OutputProcSTRING=${argument#*=}
				index=$(( index + 1 ))
				;;
			--demean=*)
				p_Demean=${argument#*=}
				index=$(( index + 1 ))
				;;
			--variance-normalization=*)
				p_VarianceNormalization=${argument#*=}
				index=$(( index + 1 ))
				;;
			--compute-variance-normalization=*)
				p_ComputeVarianceNormalization=${argument#*=}
				index=$(( index + 1 ))
				;;
			--revert-bias-field=*)
				p_RevertBiasField=${argument#*=}
				index=$(( index + 1 ))
				;;
			--matlab-run-mode=*)
				p_MatlabRunMode=${argument#*=}
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

	if [ -z "${p_fMRINames}" ]; then
		log_Err "fMRI name list (--fmri-names-list=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "fMRI name list: ${p_fMRINames}"
	fi

	if [ -z "${p_HighPass}" ]; then
		log_Err "ICA+FIX highpass setting (--high-pass=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "ICA+FIX highpass setting: ${p_HighPass}"
	fi

	if [ -z "${p_OutputfMRIName}" ]; then
		log_Err "Output fMRI Name (--output-fmri-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Output fMRI Name: ${p_OutputfMRIName}"
	fi

	if [ -z "${p_fMRIProcSTRING}" ]; then
		log_Err "fMRI Proc String: (--fmri-proc-string=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "fMRI Proc String: ${p_fMRIProcSTRING}"
	fi

	if [ -z "${p_OutputProcSTRING}" ]; then
		log_Err "Output Proc String: (--output-proc-string=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Output Proc String: ${p_OutputProcSTRING}"
	fi

	if [ -z "${p_Demean}" ]; then
		log_Err "Demean: (--demean=<YES | NO>) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Demean: ${p_Demean}"
	fi

	if [ -z "${p_VarianceNormalization}" ]; then
		log_Err "Variance Normalization (--variance-normalization=<YES | NO>) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Variance Normalization: ${p_VarianceNormalization}"
	fi

	if [ -z "${p_ComputeVarianceNormalization}" ]; then
		log_Err "Compute Variance Normalization (--compute-variance-normalization=<YES | NO> required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Compute Variance Normalization: ${p_ComputeVarianceNormalization}"
	fi

	if [ -z "${p_RevertBiasField}" ]; then
		log_Err "Revert Bias Field (--revert-bias-field=<YES | NO>) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Revert Bias Field: ${p_RevertBiasField}"
	fi
	
	if [ -z "${p_MatlabRunMode}" ]; then
		log_Err "MATLAB run mode value (--matlab-run_mode=) required"
		error_count=$(( error_count + 1 ))
	else
		case ${p_MatlabRunMode} in
			0)
				log_Msg "MATLAB run mode: ${p_MatlabRunMode}"

				if [ -z "${MATLAB_COMPILER_RUNTIME}" ]; then
					log_Err_Abort "To use MATLAB run mode: ${p_MatlabRunMode}, the MATLAB_COMPILER_RUNTIME environment variable must be set"
				else
					log_Msg "MATLAB_COMPILER_RUNTIME: ${MATLAB_COMPILER_RUNTIME}"
				fi
				;;
			1 | 2)
				log_Msg "MATLAB run mode: ${p_MatlabRunMode}"
				;;
			*)
				log_Err "MATLAB run mode value must be 0, 1, or 2"
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
	# Show wb_command version
	log_Msg "Showing wb_command version"
	"${CARET7DIR}"/wb_command -version
}

# ------------------------------------------------------------------------------
#  Main processing of script.
# ------------------------------------------------------------------------------

main()
{
	# Retrieve positional parameters
	local StudyFolder="${1}"
	local Subject="${2}"
	local fMRINames="${3}"
	local HighPass="${4}"
	local OutputfMRIName="${5}"
	local fMRIProcSTRING="${6}"
	local OutputProcSTRING="${7}"
	local Demean="${8}"
	local VarianceNormalization="${9}"
	local ComputeVarianceNormalization="${10}"
	local RevertBiasField="${11}"

	local MatlabRunMode
	if [ -z "${12}" ]; then
		MatlabRunMode=${G_DEFAULT_MATLAB_RUN_MODE}
	else
		MatlabRunMode="${12}"
	fi
	
	# Log values retrieved from positional parameters
	log_Msg "StudyFolder: ${StudyFolder}"
	log_Msg "Subject: ${Subject}"
	log_Msg "fMRINames: ${fMRINames}"
	log_Msg "HighPass: ${HighPass}"
	log_Msg "OutputfMRIName: ${OutputfMRIName}"
	log_Msg "fMRIProcSTRING: ${fMRIProcSTRING}"
	log_Msg "OutputProcSTRING: ${OutputProcSTRING}"
	log_Msg "Demean: ${Demean}"
	log_Msg "VarianceNormalization: ${VarianceNormalization}"
	log_Msg "ComputeVarianceNormalization: ${ComputeVarianceNormalization}"
	log_Msg "RevertBiasField: ${RevertBiasField}"
	log_Msg "MatlabRunMode: ${MatlabRunMode}"

	# Naming Conventions and other variables
	fMRINames=$(echo ${fMRINames} | sed 's/@/ /g')
	log_Msg "fMRINames: ${fMRINames}"

	if [ "${OutputProcSTRING}" = "NONE" ]; then
		OutputProcSTRING=""
	fi
	log_Msg "OutputProcSTRING: ${OutputProcSTRING}"

	AtlasFolder="${StudyFolder}/${Subject}/MNINonLinear"
	log_Msg "AtlasFolder: ${AtlasFolder}"

	OutputFolder="${AtlasFolder}/Results/${OutputfMRIName}"
	log_Msg "OutputFolder: ${OutputFolder}"

	Caret7_Command=${CARET7DIR}/wb_command
	log_Msg "Caret7_Command: ${Caret7_Command}"

	# Actual work
	for fMRIName in ${fMRINames} ; do
		log_Msg "fMRIName: ${fMRIName}"
		
		ResultsFolder="${AtlasFolder}/Results/${fMRIName}"
		log_Msg "ResultsFolder: ${ResultsFolder}"
		
		if [ "${Demean}" = "YES" ] ; then
			${Caret7_Command} -cifti-reduce ${ResultsFolder}/${fMRIName}${fMRIProcSTRING}.dtseries.nii MEAN ${ResultsFolder}/${fMRIName}${fMRIProcSTRING}_mean.dscalar.nii
			MATHDemean=" - Mean"
			VarDemean="-var Mean ${ResultsFolder}/${fMRIName}${fMRIProcSTRING}_mean.dscalar.nii -select 1 1 -repeat"
		else
			MATHDemean=""
			VarDemean=""
		fi

		if [ "${RevertBiasField}" = "YES" ] ; then
			if [ ! -e ${ResultsFolder}/${fMRIName}${fMRIProcSTRING}_bias.dscalar.nii ] ; then
				log_Err "Bias field in CIFTI space with correct file name doesn't exist:"
				log_Err "${ResultsFolder}/${fMRIName}${fMRIProcSTRING}_bias.dscalar.nii"
				log_Err_Abort "You need to run RestingStateStats to generate it or set RevertBiasField to NO"
			fi
			bias="${ResultsFolder}/${fMRIName}${fMRIProcSTRING}_bias.dscalar.nii"
			MATHRB=" * Bias"
			VarRB="-var Bias ${bias} -select 1 1 -repeat"
		else
			bias="NONE"
			MATHRB=""
			VarRB=""
		fi

		if [ "${VarianceNormalization}" = "YES" ] ; then

			if [ "${ComputeVarianceNormalization}" = "YES" ] ; then
				cleandtseries="${ResultsFolder}/${fMRIName}${fMRIProcSTRING}.dtseries.nii"
				bias="${bias}"
				ICAtcs="${ResultsFolder}/${fMRIName}_hp${HighPass}.ica/filtered_func_data.ica/melodic_mix"
				if [ ! -e ${ResultsFolder}/${fMRIName}_hp${HighPass}.ica/HandNoise.txt ] ; then
					ICANoise="${ResultsFolder}/${fMRIName}_hp${HighPass}.ica/.fix"
				else
					ICANoise="${ResultsFolder}/${fMRIName}_hp${HighPass}.ica/HandNoise.txt"
				fi
				log_Msg "ICANoise: ${ICANoise}"
				
				OutputVN="${ResultsFolder}/${fMRIName}${fMRIProcSTRING}_vn_tempcompute.dscalar.nii"
				log_Msg "OutputVN: ${OutputVN}"
				
				# run MATLAB ComputeVN function
				case ${MatlabRunMode} in
					
					0)
						# Use Compiled MATLAB
						matlab_exe="${HCPPIPEDIR}"
						matlab_exe+="/MSMAll/scripts/Compiled_ComputeVN/run_ComputeVN.sh"
						
						matlab_compiler_runtime="${MATLAB_COMPILER_RUNTIME}"
						
						matlab_function_arguments=("${cleandtseries}" "${bias}" "${ICAtcs}" "${ICANoise}" "${OutputVN}" "${Caret7_Command}")
						
						matlab_cmd=("${matlab_exe}" "${matlab_compiler_runtime}" "${matlab_function_arguments[@]}")
						
						#don't log to a separate file, separate log files have never been desirable
						log_Msg "Run MATLAB command: ${matlab_cmd[*]}"
						"${matlab_cmd[@]}"
						log_Msg "MATLAB command return code: $?"
						;;
					
					1 | 2)
						# Use interpreted MATLAB or Octave
						if [[ ${MatlabRunMode} == "1" ]]
						then
						    interpreter=(matlab -nojvm -nodisplay -nosplash)
						else
						    interpreter=(octave-cli -q --no-window-system)
						fi
						mPath="${HCPPIPEDIR}/MSMAll/scripts"
						mGlobalPath="${HCPPIPEDIR}/global/matlab"
						
						matlabCode="addpath '$HCPCIFTIRWDIR'; addpath '$mGlobalPath'; addpath '$mPath';
						ComputeVN('${cleandtseries}', '${bias}', '${ICAtcs}', '${ICANoise}', '${OutputVN}', '${Caret7_Command}');"
						
						log_Msg "$matlabCode"
						"${interpreter[@]}" <<<"$matlabCode"
						;;
					
					*)
						# Unsupported MATLAB run mode
						log_Err_Abort "Unsupported MATLAB run mode value: ${MatlabRunMode}"
						;;
				esac
				
			else
				if [ ! -e ${ResultsFolder}/${fMRIName}${fMRIProcSTRING}_vn.dscalar.nii ] ; then
					log_Err "Variance Normalization file doesn't exist:"
					log_Err "${ResultsFolder}/${fMRIName}${fMRIProcSTRING}_vn.dscalar.nii"
					log_Err_Abort "You need to run RestingStateStats to generate it or set ComputeVarianceNormalization to YES"
				fi
				OutputVN="${ResultsFolder}/${fMRIName}${fMRIProcSTRING}_vn.dscalar.nii"
			fi
			
			MATHVN=" / max(VN,0.001)"
			VarVN="-var VN ${OutputVN} -select 1 1 -repeat"
		else
			MATHVN=""
			VarVN=""
		fi
      
		MATH="((TCS${MATHDemean})${MATHRB})${MATHVN}"
		log_Msg "MATH: ${MATH}"
    
		${Caret7_Command} -cifti-math "${MATH}" ${ResultsFolder}/${fMRIName}${fMRIProcSTRING}${OutputProcSTRING}.dtseries.nii -var TCS ${ResultsFolder}/${fMRIName}${fMRIProcSTRING}.dtseries.nii ${VarDemean} ${VarRB} ${VarVN} 

		if [ "${Demean}" = "YES" ] ; then
			rm ${ResultsFolder}/${fMRIName}${fMRIProcSTRING}_mean.dscalar.nii
		fi

		if [ "${VarianceNormalization}" = "YES" ] ; then
			if [ "${ComputeVarianceNormalization}" = "YES" ] ; then
				rm ${ResultsFolder}/${fMRIName}${fMRIProcSTRING}_vn_tempcompute.dscalar.nii
			fi
		fi

		MergeSTRING=`echo "${MergeSTRING} -cifti ${ResultsFolder}/${fMRIName}${fMRIProcSTRING}${OutputProcSTRING}.dtseries.nii"`
		
	done
	mkdir -p "${OutputFolder}"
	${Caret7_Command} -cifti-merge ${OutputFolder}/${OutputfMRIName}${fMRIProcSTRING}${OutputProcSTRING}.dtseries.nii ${MergeSTRING}
}

# ------------------------------------------------------------------------------
#  "Global" processing - everything above here should be in a function
# ------------------------------------------------------------------------------

# Establish defaults
G_DEFAULT_MATLAB_RUN_MODE=1		# Use interpreted MATLAB

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

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
	show_usage
	exit 0
fi

${HCPPIPEDIR}/show_version

# Verify required environment variables are set and log value
log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var CARET7DIR

# Show tool versions
show_tool_versions

# Determine whether named or positional parameters are used and invoke the 'main' function
if [[ ${1} == --* ]]; then
	# Named parameters (e.g. --parameter-name=parameter-value) are used
	log_Msg "Using named parameters"

	# Get command line options
	get_options "$@"

	# Invoke main functionality using positional parameters
	#     ${1}               ${2}           ${3}             ${4}            ${5}                  ${6}                  ${7}                    ${8}          ${9}                         ${10}                               ${11}                  ${12}
	main "${p_StudyFolder}" "${p_Subject}" "${p_fMRINames}" "${p_HighPass}" "${p_OutputfMRIName}" "${p_fMRIProcSTRING}" "${p_OutputProcSTRING}" "${p_Demean}" "${p_VarianceNormalization}" "${p_ComputeVarianceNormalization}" "${p_RevertBiasField}" "${p_MatlabRunMode}"

else
	# Positional parameters are used
	log_Msg "Using positional parameters"
	main $@
	
fi
