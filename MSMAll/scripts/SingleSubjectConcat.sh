#!/bin/bash
set -e

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
# ## Description
#
# TBW
#
# ## Prerequisites
#
# ### Installed Software
#
# * TBW
#
# ### Environment Variables
#
# * HCPPIPEDIR
#
#   The "home" directory for the HCP Pipeline product.
#   e.g. /home/tbrown01/projects/Pipelines
#
# * CARET7DIR
#
#   The executable directory for the Connectome Workbench installation
#
# <!-- References -->
# [HCP]: http://www.humanconnectome.org
#
#~ND~END~

# ------------------------------------------------------------------------------
#  Code Start
# ------------------------------------------------------------------------------

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

source ${HCPPIPEDIR}/global/scripts/log.shlib # Logging related functions
log_Msg "HCPPIPEDIR: ${HCPPIPEDIR}"

# ------------------------------------------------------------------------------
#  Verify other needed environment variables are set
# ------------------------------------------------------------------------------

if [ -z "${CARET7DIR}" ]; then
	log_Err_Abort "CARET7DIR environment variable must be set"
fi
log_Msg "CARET7DIR: ${CARET7DIR}"

# ------------------------------------------------------------------------------
#  Show usage information for this script
# ------------------------------------------------------------------------------

usage()
{
	local script_name
	script_name=$(basename "${0}")

	cat <<EOF

${script_name}: Single Subject Scan Concatenation

Usage: ${script_name} PARAMETER...

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
	unset g_path_to_study_folder
	unset g_subject
	unset g_fmri_names_list
	unset g_high_pass
	unset g_output_fmri_name
	unset g_fmri_proc_string
	unset g_output_proc_string
	unset g_demean
	unset g_variance_normalization
	unset g_compute_variance_normalization
	unset g_revert_bias_field
	unset g_matlab_run_mode
	
	# set default values
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
			--fmri-names-list=*)
				g_fmri_names_list=${argument#*=}
				index=$(( index + 1 ))
				;;
			--high-pass=*)
				g_high_pass=${argument#*=}
				index=$(( index + 1 ))
				;;
			--output-fmri-name=*)
				g_output_fmri_name=${argument#*=}
				index=$(( index + 1 ))
				;;
			--fmri-proc-string=*)
				g_fmri_proc_string=${argument#*=}
				index=$(( index + 1 ))
				;;
			--output-proc-string=*)
				g_output_proc_string=${argument#*=}
				index=$(( index + 1 ))
				;;
			--demean=*)
				g_demean=${argument#*=}
				index=$(( index + 1 ))
				;;
			--variance-normalization=*)
				g_variance_normalization=${argument#*=}
				index=$(( index + 1 ))
				;;
			--compute-variance-normalization=*)
				g_compute_variance_normalization=${argument#*=}
				index=$(( index + 1 ))
				;;
			--revert-bias-field=*)
				g_revert_bias_field=${argument#*=}
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
		log_Msg "g_path_to_study_folder: ${g_path_to_study_folder}"
	fi

	if [ -z "${g_subject}" ]; then
		log_Err "subject ID required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_subject: ${g_subject}"
	fi

	if [ -z "${g_fmri_names_list}" ]; then
		log_Err "fMRI name list required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_fmri_names_list: ${g_fmri_names_list}"
	fi

	if [ -z "${g_high_pass}" ]; then
		log_Err "ICA+FIX highpass setting required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_high_pass: ${g_high_pass}"
	fi
	
	if [ -z "${g_output_fmri_name}" ]; then
		log_Err "output fMRI name required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_output_fmri_name: ${g_output_fmri_name}"
	fi

	if [ -z "${g_fmri_proc_string}" ]; then
		log_Err "fMRI proc string required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_fmri_proc_string: ${g_fmri_proc_string}"
	fi

	if [ -z "${g_output_proc_string}" ]; then
		log_Err "output proc string required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_output_proc_string: ${g_output_proc_string}"
	fi

	if [ -z "${g_demean}" ]; then
		log_Err "demean setting required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_demean: ${g_demean}"
	fi

	if [ -z "${g_variance_normalization}" ]; then
		log_Err "variance normalization setting required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_variance_normalization: ${g_variance_normalization}"
	fi

	if [ -z "${g_compute_variance_normalization}" ]; then
		log_Err "compute variance normalization setting required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_compute_variance_normalization: ${g_compute_variance_normalization}"
	fi

	if [ -z "${g_revert_bias_field}" ]; then
		log_Err "revert bias field setting required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_revert_bias_field: ${g_revert_bias_field}"
	fi
	
	if [ -z "${g_matlab_run_mode}" ]; then
		log_Err "MATLAB run mode value (--matlab-run_mode=) required"
		error_count=$(( error_count + 1 ))
	else
		case ${g_matlab_run_mode} in
			0)
				log_Msg "g_matlab_run_mode: ${g_matlab_run_mode}"

				if [ -z "${MATLAB_COMPILER_RUNTIME}" ]; then
					log_Err_Abort "To use MATLAB run mode: ${g_matlab_run_mode}, the MATLAB_COMPILER_RUNTIME environment variable must be set"
				else
					log_Msg "MATLAB_COMPILER_RUNTIME: ${MATLAB_COMPILER_RUNTIME}"
				fi
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
#  Main processing of script.
# ------------------------------------------------------------------------------

main()
{
	# Get command line options
	get_options "$@"

	g_fmri_names_list=$(echo ${g_fmri_names_list} | sed 's/@/ /g')
	log_Msg "g_fmri_names_list: ${g_fmri_names_list}"

	# Naming Conventions
	fMRINames=${g_fmri_names_list}
	log_Msg "fMRINames: ${fMRINames}"

	AtlasFolder="${g_path_to_study_folder}/${g_subject}/MNINonLinear"
	log_Msg "AtlasFolder: ${AtlasFolder}"

	OutputFolder="${AtlasFolder}/Results/${g_output_fmri_name}"
	log_Msg "OutputFolder: ${OutputFolder}"

	if [ "${g_output_proc_string}" = "NONE" ]; then
		g_output_proc_string=""
	fi
	log_Msg "g_output_proc_string: ${g_output_proc_string}"

	OutputProcSTRING=${g_output_proc_string}
	log_Msg "OutputProcSTRING: ${OutputProcSTRING}"

	Caret7_Command=${CARET7DIR}/wb_command
	log_Msg "Caret7_Command: ${Caret7_Command}"

	HighPass=${g_high_pass}
	log_Msg "HighPass: ${HighPass}"

	OutputfMRIName=${g_output_fmri_name}
	log_Msg "OutputfMRIName: ${OutputfMRIName}"

	fMRIProcSTRING=${g_fmri_proc_string}
	log_Msg "fMRIProcSTRING: ${fMRIProcSTRING}"

	Demean=${g_demean}
	log_Msg "Demean: ${Demean}"

	VarianceNormalization=${g_variance_normalization}
	log_Msg "VarianceNormalization: ${VarianceNormalization}"

	ComputeVarianceNormalization=${g_compute_variance_normalization}
	log_Msg "ComputeVarianceNormalization: ${ComputeVarianceNormalization}"

	RevertBiasField=${g_revert_bias_field}
	log_Msg "RevertBiasField: ${RevertBiasField}"

	for fMRIName in $fMRINames ; do
		
		ResultsFolder="${AtlasFolder}/Results/${fMRIName}"

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
				
				# run MATLAB ComputVN function
				case ${g_matlab_run_mode} in
					
					0)
						# Use Compiled MATLAB
						matlab_exe="${HCPPIPEDIR}"
						matlab_exe+="/MSMAll/scripts/Compiled_ComputeVN/run_ComputeVN.sh"
						
						matlab_compiler_runtime="${MATLAB_COMPILER_RUNTIME}"
						
						matlab_function_arguments="'${cleandtseries}' '${bias}' '${ICAtcs}' '${ICANoise}' '${OutputVN}' '${Caret7_Command}'"
						
						matlab_logging=">> ${g_path_to_study_folder}/${g_subject}.ComputeVN.matlab.log 2>&1"
						
						matlab_cmd="${matlab_exe} ${matlab_compiler_runtime} ${matlab_function_arguments} ${matlab_logging}"
						
						log_Msg "Run MATLAB command: ${matlab_cmd}"
						#echo "${matlab_cmd}" | bash
						${matlab_cmd}
						log_msg "MATLAB command return code: $?"
						;;
					
					1)
						# Use interpreted MATLAB
						mPath="${HCPPIPEDIR}/MSMAll/scripts"
						
						matlab -nojvm -nodisplay -nosplash <<M_PROG
addpath '$mPath'; ComputeVN('${cleandtseries}','${bias}','${ICAtcs}','${ICANoise}','${OutputVN}','${Caret7_Command}');
M_PROG
						log_Msg "ComputeVN('${cleandtseries}','${bias}','${ICAtcs}','${ICANoise}','${OutputVN}','${Caret7_Command}');"
						;;
					
					*)
						# Unsupported MATLAB run mode
						log_Err_Abort "Unsupported MATLAB run mode value: ${g_matlab_run_mode}"
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
		log_Msg "${MATH}"
    
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
	${Caret7_Command} -cifti-merge ${OutputFolder}/${OutputfMRIName}${fMRIProcSTRING}${OutputProcSTRING}.dtseries.nii ${MergeSTRING} 

}

# ------------------------------------------------------------------------------
#  Invoke the main function to get things started
# ------------------------------------------------------------------------------

main "$@"
