#!/bin/bash

#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # MSMAllPipeline.sh
#
# ## Copyright Notice
#
# Copyright (C) 2015 The Human Connectome Project
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
# This is the main script for the MSM Registration pipeline. Once this registration is run
# on all subjects in a group, the Group Registration Drift can be computed.
#
# ## Prerequisites
#
# ### Previous Processing
#
# The necessary input files for this processing come from:
#
# * TBW
# * The Resting State Stats pipeline
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
#
#
#
#
# <!-- References -->
# [HCP]: http://www.humanconnectome.org
#
#~ND~END~

# ------------------------------------------------------------------------------
#  Code Start
# ------------------------------------------------------------------------------
set -e # If any commands exit with non-zero value, this script exits
g_script_name=`basename ${0}`

# ------------------------------------------------------------------------------
#  Load function libraries
# ------------------------------------------------------------------------------

source ${HCPPIPEDIR}/global/scripts/log.shlib # Logging related functions
log_SetToolName "${g_script_name}"



#
# Function Description:
#  Show usage information for this script
#
usage()
{
	echo ""
	echo "  MSM-All Registration"
	echo ""
	echo "  Usage: ${g_script_name} <options>"
	echo ""
	echo "  Options: [ ] = optional; < > = user supplied value"
	echo ""
	echo "   [--help] : show usage information and exit"
	echo "    --path=<path to study folder> OR --study-folder=<path to study folder>"
	echo "    --subject=<subject ID>"
	echo "    --fmri-names-list=<fMRI names> an @ symbol separated list of fMRI scan names"
	echo " "
	echo "  TBW "
	echo " "
	echo ""
}

#
# Function Description:
#  Get the command line options for this script.
#  Shows usage information and exits if command line is malformed
#
# Global Output Variables
#  ${g_path_to_study_folder} - path to folder containing subject data directories
#  ${g_subject} - subject ID
#  ${g_fmri_names_list} - @ symbol separated list of fMRI names
#  ${g_output_fmri_name} - name to give to concatenated single subject "scan"
#  ${g_fmri_proc_string} - identification for FIX cleaned dtseries to use
#                          The dense timeseries files used will be named
#                          ${fmri_name}_${g_fmri_proc_string}.dtseries.nii
#                          where ${fmri_name} is each of the fMRIs specified in
#                          ${g_fmri_names_list}.
#  ${g_msm_all_templates} - path to directory containing MSM All template files
#  ${g_output_registration_name} - name to give output registration
#  ${g_high_res_mesh}
#  ${g_low_res_mesh}
#
get_options()
{
	local arguments=($@)

	# initialize global output variables
	unset g_path_to_study_folder
	unset g_subject
	unset g_fmri_names_list
	unset g_output_fmri_name
	unset g_fmri_proc_string
	unset g_msm_all_templates
	unset g_output_registration_name
	unset g_high_res_mesh
	unset g_low_res_mesh
	unset g_input_registration_name

	# set default values

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
			--output-fmri-name=*)
				g_output_fmri_name=${argument#*=}
				index=$(( index + 1 ))
				;;
			--fmri-proc-string=*)
				g_fmri_proc_string=${argument#*=}
				index=$(( index + 1 ))
				;;
			--msm-all-templates=*)
				g_msm_all_templates=${argument#*=}
				index=$(( index + 1 ))
				;;
			--output-registration-name=*)
				g_output_registration_name=${argument#*=}
				index=$(( index + 1 ))
				;;
			--high-res-mesh=*)
				g_high_res_mesh=${argument#*=}
				index=$(( index + 1 ))
				;;
			--low-res-mesh=*)
				g_low_res_mesh=${argument#*=}
				index=$(( index + 1 ))
				;;
			--input-registration-name=*)
				g_input_registration_name=${argument#*=}
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

	if [ -z "${g_fmri_names_list}" ]; then
		echo "ERROR: fMRI name list required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_fmri_names_list: ${g_fmri_names_list}"
	fi

	if [ -z "${g_output_fmri_name}" ]; then
		echo "ERROR: output fMRI name required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_output_fmri_name: ${g_output_fmri_name}"
	fi

	if [ -z "${g_fmri_proc_string}" ]; then
		echo "ERROR: fMRI proc string required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_fmri_proc_string: ${g_fmri_proc_string}"
	fi

	if [ -z "${g_msm_all_templates}" ]; then
		echo "ERROR: msm all templates required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_msm_all_templates: ${g_msm_all_templates}"
	fi

	if [ -z "${g_output_registration_name}" ]; then
		echo "ERROR: output registration name required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_output_registration_name: ${g_output_registration_name}"
	fi

	if [ -z "${g_high_res_mesh}" ]; then
		echo "ERROR: high resolution mesh required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_high_res_mesh: ${g_high_res_mesh}"
	fi

	if [ -z "${g_low_res_mesh}" ]; then
		echo "ERROR: low resolution mesh required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_low_res_mesh: ${g_low_res_mesh}"
	fi

	if [ -z "${g_input_registration_name}" ]; then
		echo "ERROR: input registration name required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_input_registration_name: ${g_input_registration_name}"
	fi

	if [ ${error_count} -gt 0 ]; then
		echo "For usage information, use --help"
		exit 1
	fi
}

#
# Function Description:
#  Document Tool Versions
#
show_tool_versions() 
{
	# Show HCP pipelines version
	log_Msg "Showing HCP Pipelines version"
	cat ${HCPPIPEDIR}/version.txt
}

#
# Function Description:
#  Main processing of script.
#
main()
{
	# Get command line options
	# See documentation for the get_options function for global variables set
	get_options $@

	# show the versions of tools used
	show_tool_versions

	InPCARegName="${g_input_registration_name}"

	# Values of variables determining MIGP usage
	# Form:    UseMIGP    @ PCAInitDim     @ PCAFinalDim    @ ReRunIfExists @ VarianceNormalization
	# Values:  YES or NO  @ number or NONE @ number or NONE @ YES or NO     @ YES or NO
	# 
	# Note: Spaces should not be used in the variable's value. They are used above to 
	#       help make the form and values easier to understand.
	# Note: If UseMIGP value is NO, then we use the full timeseries
	log_Msg "Running MSM on full timeseries"
	migp_vars="NO@0@0@NO@YES"
	log_Msg "migp_vars: ${migp_vars}"

	output_proc_string="_nobias_vn"
	log_Msg "output_proc_string: ${output_proc_string}"

	${HCPPIPEDIR}/MSMAll/scripts/SingleSubjectConcat.sh \
		--path=${g_path_to_study_folder} \
		--subject=${g_subject} \
		--fmri-names-list=${g_fmri_names_list} \
		--output-fmri-name=${g_output_fmri_name} \
		--fmri-proc-string=${g_fmri_proc_string} \
		--migp-vars=${migp_vars} \
		--output-proc-string=${output_proc_string}

	expected_concatenated_output_file=""
	expected_concatenated_output_file+="${g_path_to_study_folder}"
	expected_concatenated_output_file+="/${g_subject}/MNINonLinear/Results"
	expected_concatenated_output_file+="/${g_output_fmri_name}"
	expected_concatenated_output_file+="/${g_output_fmri_name}${g_fmri_proc_string}${output_proc_string}"
	expected_concatenated_output_file+=".dtseries.nii"

	log_Msg "SingleSubjectConcat.sh should have created: ${expected_concatenated_output_file}"
	if [ -e "${expected_concatenated_output_file}" ]; then
		log_Msg "Existence of expected file confirmed"
	else
		log_Msg "Expected file: ${expected_concatenated_output_file} DOES NOT EXIST - Aborting"
		exit 1
	fi

	# g_fmri_proc_string now should reflect the name expected by registrations done below
	# (e.g. MSMAll.sh)
	g_fmri_proc_string+="${output_proc_string}"
	log_Msg "g_fmri_proc_string: ${g_fmri_proc_string}"

	RSNTemplates="${g_msm_all_templates}/rfMRI_REST_Atlas_MSMAll_2_d41_WRN_DeDrift_hp2000_clean_PCA.ica_dREPLACEDIM_ROW_vn/melodic_oIC.dscalar.nii"
	log_Msg "RSNTemplates: ${RSNTemplates}"

	RSNWeights="${g_msm_all_templates}/rfMRI_REST_Atlas_MSMAll_2_d41_WRN_DeDrift_hp2000_clean_PCA.ica_dREPLACEDIM_ROW_vn/Weights.txt"
	log_Msg "RSNWeights: ${RSNWeights}"

	MyelinMaps="${g_msm_all_templates}/Q1-Q6_RelatedParcellation210.MyelinMap_BC_MSMAll_2_d41_WRN_DeDrift.32k_fs_LR.dscalar.nii"
	if [ -e "${MyelinMaps}" ]; then
		log_Msg "MyelinMaps: ${MyelinMaps}"
	else
		log_Msg "ERROR: MyelinMaps file: ${MyelinMaps} DOES NOT EXIST - ABORTING"
		exit 1
	fi

	TopographicRegressors="${g_msm_all_templates}/Q1-Q6_RelatedParcellation210.atlas_Topographic_ROIs.32k_fs_LR.dscalar.nii"
	if [ -e "${TopographicRegressors}" ]; then
		log_Msg "TopographicRegressors: ${TopographicRegressors}"
	else
		log_Msg "ERROR: TopographicRegressors file: ${TopographicRegressors} DOES NOT EXIST - ABORTING"
		exit 1
	fi

	TopographicMaps="${g_msm_all_templates}/Q1-Q6_RelatedParcellation210.atlas_Topography.32k_fs_LR.dscalar.nii"
	if [ -e "${TopographicMaps}" ]; then
		log_Msg "TopographicMaps: ${TopographicMaps}"
	else
		log_Msg "ERROR: TopographicMaps file: ${TopographicMaps} DOES NOT EXIST - ABORTING"
		exit 1
	fi

	# Value of MSMAllRegsOrig and MSMAllRegs variables are @ symbol separated strings that supply the 
	# following values in order. MSMAllRegs is the one actually used. MSMAllRegsOrig is just an
	# intermediate step in building MSMAllRegs. Once MSMAllRegsOrig is populated, the last field
	# in it (RegConfVars) is replaced with the comma delimited value of the ${RegConfVars} variable.
	#
	# ModuleName             = name of script or code used to run registration (e.g. MSMAll.sh)
	# RegName                = output registration name (e.g. MSMAll_InitalReg") 
	# RSNTargetFile          = Resting State Network target file
	# RSNCostWeights         = Resting State Network cost weights (NONE is a valid value)
	# ArchitectureTargetFile = TBW
	# TopographyROIFile      = TBW
	# Iterations             = Specifieds what modalities:
	#                            C=RSN Connectivity
	#                            A=Myelin Architecture
	#                            T=RSN Topography
	#                          and number is the number of elements delimited by _
	#                          So CA_CAT means one iteration using RSN Connectivity and Myelin 
	#                          Architecture, followed by another iteration using RSN Connectivity,
	#                          Myelin Architecture, and RSN Topography. (TBD - Is the comment correct?)
	# Method                 = Possible values: DR, DRZ, DRN, WR, WRZ, WRN - (TBD - each meaning?)
	# UseMIGP                = Possible values: YES or NO (MIGP = MELODIC's Incremental Group Principal 
	#                          Component Analysis)
	# ICAdim                 = ICA (Independent Component Analysis) dimension
	# RegressionParams       = ICA dimensionalilties delimited by _ to use in spatial weighting for WR
	# VarianceNormalization  = TBW
	# ReRunIfExists          = Re-run even if output already exists (TBD - Is this correct?)
	# RegConf                = TBW
	# RegConfVars            = TBW
	#                            delimited by ,
	#                            use NONE to use config file as specified
	MSMAllRegsOrig=""
	MSMAllRegsOrig+="MSMAll.sh"                       # ModuleName
	MSMAllRegsOrig+="@${g_output_registration_name}"  # RegName
	MSMAllRegsOrig+="@${RSNTemplates}"                # RSNTargetFile 
	MSMAllRegsOrig+="@${RSNWeights}"                  # RSNCostWeights
	MSMAllRegsOrig+="@${MyelinMaps}"                  # ArchitectureTargetFile
	MSMAllRegsOrig+="@${TopographicRegressors}"       # TopographyROIFile
	MSMAllRegsOrig+="@${TopographicMaps}"             # TopographyTargetFile
	MSMAllRegsOrig+="@CA_CAT"                         # Iterations
	MSMAllRegsOrig+="@WRN"                            # Method
	MSMAllRegsOrig+="@NO"                             # UseMIGP
	MSMAllRegsOrig+="@40"                             # ICAdim
	MSMAllRegsOrig+="@7_8_9_10_11_12_13_14_15_16_17_18_19_20_21"  # RegressionParams
	MSMAllRegsOrig+="@NO"                             # VarianceNormalization
	MSMAllRegsOrig+="@YES"                            # ReRunIfExists
	MSMAllRegsOrig+="@${MSMBin}/allparametersVariableMSMOptimiztionAllDRconf" # RegConf
	MSMAllRegsOrig+="@RegConfVars"                    # RegConfVars
	log_Msg "MSMAllRegsOrig: ${MSMAllRegsOrig}"
	log_Msg ""

	RegConfVars=""
	RegConfVars+="REGNUMBER=1"
	RegConfVars+=",REGPOWER=3"
	RegConfVars+=",SCALEPOWER=0"
	RegConfVars+=",AREALDISTORTION=0"
	RegConfVars+=",MAXTHETA=0"
	RegConfVars+=",LAMBDAONE=0.01"
	RegConfVars+=",LAMBDATWO=0.05"
	RegConfVars+=",LAMBDATHREE=0.1"
	log_Msg "RegConfVars: ${RegConfVars}"
	log_Msg ""

	MSMAllRegs=`echo ${MSMAllRegsOrig} | sed "s/RegConfVars/${RegConfVars}/g"`
	log_Msg "MSMAllRegs: ${MSMAllRegs}"
	log_Msg ""

	# Run whatever MSMAll registrations were specified (e.g. when running multiple dimensionalities)

	if [ ! "${MSMAllRegs}" = "NONE" ] ; then
		
		MSMAllRegs=`echo ${MSMAllRegs} | sed 's/+/ /g'`		
		log_Msg "About to enter loop through MSMAll registrations: MSMAllRegs: ${MSMAllRegs}"

		for MSMAllReg in ${MSMAllRegs} ; do
			log_Msg "MSMAllReg: ${MSMAllReg}"
			
			Module=`echo ${MSMAllRegs} | cut -d "@" -f 1`
			log_Msg "Module: ${Module}"

			RegName=`echo ${MSMAllRegs} | cut -d "@" -f 2`
			log_Msg "RegName: ${RegName}"

			RSNTargetFile=`echo ${MSMAllRegs} | cut -d "@" -f 3`
			log_Msg "RSNTargetFile: ${RSNTargetFile}"

			RSNCostWeights=`echo ${MSMAllRegs} | cut -d "@" -f 4`
			log_Msg "RSNCostWeights: ${RSNCostWeights}"

			MyelinTargetFile=`echo ${MSMAllRegs} | cut -d "@" -f 5`
			log_Msg "MyelinTargetFile: ${MyelinTargetFile}"

			TopographyROIFile=`echo ${MSMAllRegs} | cut -d "@" -f 6`
			log_Msg "TopographyROIFile: ${TopographyROIFile}"

			TopographyTargetFile=`echo ${MSMAllRegs} | cut -d "@" -f 7`
			log_Msg "TopographyTargetFile: ${TopographyTargetFile}"

			Iterations=`echo ${MSMAllRegs} | cut -d "@" -f 8`
			log_Msg "Iterations: ${Iterations}"

			Method=`echo ${MSMAllRegs} | cut -d "@" -f 9`
			log_Msg "Method: ${Method}"

			UseMIGP=`echo ${MSMAllRegs} | cut -d "@" -f 10`
			log_Msg "UseMIGP: ${UseMIGP}"

			ICAdim=`echo ${MSMAllRegs} | cut -d "@" -f 11`
			log_Msg "ICAdim: ${ICAdim}"

			RegressionParams=`echo ${MSMAllRegs} | cut -d "@" -f 12`
			log_Msg "RegressionParams: ${RegressionParams}"

			VN=`echo ${MSMAllRegs} | cut -d "@" -f 13`
			log_Msg "VN: ${VN}"

			ReRun=`echo ${MSMAllRegs} | cut -d "@" -f 14`
			log_Msg "ReRun: ${ReRun}"

			RegConf=`echo ${MSMAllRegs} | cut -d "@" -f 15`
			log_Msg "RegConf: ${RegConf}"

			RegConfVars=`echo ${MSMAllRegs} | cut -d "@" -f 16`
			log_Msg "RegConfVars: ${RegConfVars}"

			${HCPPIPEDIR}/MSMAll/scripts/${Module} \
				--path=${g_path_to_study_folder} \
				--subject=${g_subject} \
				--high-res-mesh=${g_high_res_mesh} \
				--low-res-mesh=${g_low_res_mesh} \
				--fmri-names-list=${g_fmri_names_list} \
				--output-fmri-name=${g_output_fmri_name} \
				--fmri-proc-string=${g_fmri_proc_string} \
				--input-pca-registration-name=${InPCARegName} \
				--input-registration-name=${g_input_registration_name} \
				--registration-name-stem=${RegName} \
				--rsn-target-file=${RSNTargetFile} \
				--rsn-cost-weights=${RSNCostWeights} \
				--myelin-target-file=${MyelinTargetFile} \
				--topography-roi-file=${TopographyROIFile} \
				--topography-target-file=${TopographyTargetFile} \
				--iterations=${Iterations} \
				--method=${Method} \
				--use-migp=${UseMIGP} \
				--ica-dim=${ICAdim} \
				--regression-params=${RegressionParams} \
				--vn=${VN} \
				--rerun=${ReRun} \
				--reg-conf=${RegConf} \
				--reg-conf-vars="${RegConfVars}"
			
			g_input_registration_name=${RegName}
		done
	fi
}

# 
# Invoke the main function to get things started
#
main $@
