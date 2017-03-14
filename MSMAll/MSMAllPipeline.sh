#!/bin/bash

#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # MSMAllPipeline.sh
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

set -e # If any commands exit with non-zero value, this script exits

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

source "${HCPPIPEDIR}/global/scripts/log.shlib" # Logging related functions
log_Msg "HCPPIPEDIR: ${HCPPIPEDIR}"

# ------------------------------------------------------------------------------
#  Verify other needed environment variables are set
# ------------------------------------------------------------------------------

if [ -z "${MSMCONFIGDIR}" ]; then
	log_Err_Abort "MSMCONFIGDIR environment variable must be set"
fi
log_Msg "MSMCONFIGDIR: ${MSMCONFIGDIR}"

# ------------------------------------------------------------------------------
#  Show usage information for this script
# ------------------------------------------------------------------------------

usage()
{
	local script_name
	script_name=$(basename "${0}")

	cat <<EOF

${script_name}: MSM-All Registration Pipeline

Usage: ${script_name} PARAMETER...

PARAMETERs are [ ] = optional; < > = user supplied value

  [--help] : show usage information and exit
   --path=<path to study folder> OR --study-folder=<path to study folder>
   --subject=<subject ID>
   --fmri-names-list=<fMRI names> an @ symbol separated list of fMRI scan names
   --output-fmri-name=<name to give to concatenated single subject "scan">
   --high-pass=<high-pass filter used in ICA+FIX>
   --fmri-proc-string=<identification for FIX cleaned dtseries to use>
        The dense timeseries files used will be named
        <fmri_name>_<fmri_proc_string>.dtseries.nii where
        <fmri_name> is each of the fMRIs specified in the <fMRI Names> list
        and <fmri_proc_string> is this specified value
   --msm-all-templates=<path to directory containing MSM All template files>
   --output-registration-name=<name to give output registration>
   --high-res-mesh=<high resolution mesh node count> (in thousands)
   --low-res-mesh=<low resolution mesh node count> (in thousands)
   --input-registration-name=<input registration name>
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
	unset g_StudyFolder
	unset g_Subject
	unset g_fMRINames
	unset g_OutputfMRIName
	unset g_HighPass
	unset g_fMRIProcSTRING
	unset g_MSMAllTemplates
	unset g_OutputRegName
	unset g_HighResMesh
	unset g_LowResMesh
	unset g_InputRegName
	unset g_MatlabRunMode
	
	# set default values
	g_MatlabRunMode=0

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
				g_StudyFolder=${argument#*=}
				index=$(( index + 1 ))
				;;
			--study-folder=*)
				g_StudyFolder=${argument#*=}
				index=$(( index + 1 ))
				;;
			--subject=*)
				g_Subject=${argument#*=}
				index=$(( index + 1 ))
				;;
			--fmri-names-list=*)
				g_fMRINames=${argument#*=}
				index=$(( index + 1 ))
				;;
			--output-fmri-name=*)
				g_OutputfMRIName=${argument#*=}
				index=$(( index + 1 ))
				;;
			--high-pass=*)
				g_HighPass=${argument#*=}
				index=$(( index + 1 ))
				;;
			--fmri-proc-string=*)
				g_fMRIProcSTRING=${argument#*=}
				index=$(( index + 1 ))
				;;
			--msm-all-templates=*)
				g_MSMAllTemplates=${argument#*=}
				index=$(( index + 1 ))
				;;
			--output-registration-name=*)
				g_OutputRegName=${argument#*=}
				index=$(( index + 1 ))
				;;
			--high-res-mesh=*)
				g_HighResMesh=${argument#*=}
				index=$(( index + 1 ))
				;;
			--low-res-mesh=*)
				g_LowResMesh=${argument#*=}
				index=$(( index + 1 ))
				;;
			--input-registration-name=*)
				g_InputRegName=${argument#*=}
				index=$(( index + 1 ))
				;;
			--matlab-run-mode=*)
				g_MatlabRunMode=${argument#*=}
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
	if [ -z "${g_StudyFolder}" ]; then
		log_Err "Study Folder (--path= or --study-folder=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_StudyFolder: ${g_StudyFolder}"
	fi

	if [ -z "${g_Subject}" ]; then
		log_Err "Subject ID required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_Subject: ${g_Subject}"
	fi

	if [ -z "${g_fMRINames}" ]; then
		log_Err "fMRI name list required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_fMRINames: ${g_fMRINames}"
	fi

	if [ -z "${g_OutputfMRIName}" ]; then
		log_Err "Output fMRI name required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_OutputfMRIName: ${g_OutputfMRIName}"
	fi

	if [ -z "${g_HighPass}" ]; then
		log_Err "ICA+FIX HighPass setting required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_HighPass: ${g_HighPass}"
	fi

	if [ -z "${g_fMRIProcSTRING}" ]; then
		log_Err "fMRI proc string required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_fMRIProcSTRING: ${g_fMRIProcSTRING}"
	fi

	if [ -z "${g_MSMAllTemplates}" ]; then
		log_Err "msm all templates required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_MSMAllTemplates: ${g_MSMAllTemplates}"
	fi

	if [ -z "${g_OutputRegName}" ]; then
		log_Err "output registration name required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_OutputRegName: ${g_OutputRegName}"
	fi

	if [ -z "${g_HighResMesh}" ]; then
		log_Err "high resolution mesh required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_HighResMesh: ${g_HighResMesh}"
	fi

	if [ -z "${g_LowResMesh}" ]; then
		log_Err "low resolution mesh required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_LowResMesh: ${g_LowResMesh}"
	fi

	if [ -z "${g_InputRegName}" ]; then
		log_Err "input registration name required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_InputRegName: ${g_InputRegName}"
	fi

	if [ -z "${g_MatlabRunMode}" ]; then
		log_Err "MATLAB run mode value (--matlab-run-mode=) required"
		error_count=$(( error_count + 1 ))
	else
		case ${g_MatlabRunMode} in
			0)
				log_Msg "g_MatlabRunMode: ${g_MatlabRunMode}"
				;;
			1)
				log_Msg "g_MatlabRunMode: ${g_MatlabRunMode}"
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
#  Show/Document Tool Versions
# ------------------------------------------------------------------------------

show_tool_versions()
{
	# Show HCP pipelines version
	log_Msg "Showing HCP Pipelines version"
	cat "${HCPPIPEDIR}"/version.txt
}

# ------------------------------------------------------------------------------
#  Main processing of script.
# ------------------------------------------------------------------------------

main()
{
	# Get command line options
	get_options "$@"

	# Show the versions of tools used
	show_tool_versions

	local InPCARegName="${g_InputRegName}"

	# Values of variables determining MIGP usage
	# Form:    UseMIGP    @ PCAInitDim     @ PCAFinalDim    @ ReRunIfExists @ VarianceNormalization
	# Values:  YES or NO  @ number or NONE @ number or NONE @ YES or NO     @ YES or NO
	#
	# Note: Spaces should not be used in the variable's value. They are used above to
	#       help make the form and values easier to understand.
	# Note: If UseMIGP value is NO, then we use the full timeseries
	log_Msg "Running MSM on full timeseries"
#	migp_vars="NO@0@0@YES@YES"
#	log_Msg "migp_vars: ${migp_vars}"

	local output_proc_string="_vn" #To VN only to indicate that we did not revert the bias field before computing VN
	log_Msg "output_proc_string: ${output_proc_string}"

	local Demean="YES"
	log_Msg "Demean: ${Demean}"
	
	local VarianceNormalization="YES"
	log_Msg "VarianceNormalization: ${VarianceNormalization}"
	
	local ComputeVarianceNormalization="YES" #Don't rely on RestingStateStats to have been run
	log_Msg "ComputeVarianceNormalization: ${ComputeVarianceNormalization}"

	local RevertBiasField="NO" # Will recompute VN based on not reverting bias field
	log_Msg "RevertBiasField: ${RevertBiasField}"

	"${HCPPIPEDIR}"/MSMAll/scripts/SingleSubjectConcat.sh \
		--path="${g_StudyFolder}" \
		--subject="${g_Subject}" \
		--fmri-names-list="${g_fMRINames}" \
		--high-pass="${g_HighPass}" \
		--output-fmri-name="${g_OutputfMRIName}" \
		--fmri-proc-string="${g_fMRIProcSTRING}" \
		--output-proc-string="${output_proc_string}" \
		--demean="${Demean}" \
		--variance-normalization="${VarianceNormalization}" \
		--compute-variance-normalization="${ComputeVarianceNormalization}" \
		--revert-bias-field="${RevertBiasField}" \
		--matlab-run-mode="${g_MatlabRunMode}"

	#"${HCPPIPEDIR}"/MSMAll/scripts/SingleSubjectConcat.sh ${CARET7DIR}/wb_command ${g_StudyFolder} ${g_Subject} ${g_fMRINames} ${g_HighPass} ${g_OutputfMRIName} ${g_fMRIProcSTRING} ${output_proc_string} ${Demean} ${VarianceNormalization} ${ComputeVarianceNormalization} ${RevertBiasField} ${g_MatlabRunMode}

	local expected_concatenated_output_file=""
	expected_concatenated_output_file+="${g_StudyFolder}"
	expected_concatenated_output_file+="/${g_Subject}/MNINonLinear/Results"
	expected_concatenated_output_file+="/${g_OutputfMRIName}"
	expected_concatenated_output_file+="/${g_OutputfMRIName}${g_fMRIProcSTRING}${output_proc_string}"
	expected_concatenated_output_file+=".dtseries.nii"

	log_File_Must_Exist "${expected_concatenated_output_file}"
	
	# g_fMRIProcSTRING now should reflect the name expected by registrations done below
	# (e.g. MSMAll)
	g_fMRIProcSTRING+="${output_proc_string}"
	log_Msg "g_fMRIProcSTRING: ${g_fMRIProcSTRING}"

	local RSNTemplates="${g_MSMAllTemplates}/rfMRI_REST_Atlas_MSMAll_2_d41_WRN_DeDrift_hp2000_clean_PCA.ica_dREPLACEDIM_ROW_vn/melodic_oIC.dscalar.nii"
	log_Msg "RSNTemplates: ${RSNTemplates}"

	local RSNWeights="${g_MSMAllTemplates}/rfMRI_REST_Atlas_MSMAll_2_d41_WRN_DeDrift_hp2000_clean_PCA.ica_dREPLACEDIM_ROW_vn/Weights.txt"
	log_Msg "RSNWeights: ${RSNWeights}"

	local MyelinMaps="${g_MSMAllTemplates}/Q1-Q6_RelatedParcellation210.MyelinMap_BC_MSMAll_2_d41_WRN_DeDrift.32k_fs_LR.dscalar.nii"
	log_File_Must_Exist "${MyelinMaps}"
	
	local TopographicRegressors="${g_MSMAllTemplates}/Q1-Q6_RelatedParcellation210.atlas_Topographic_ROIs.32k_fs_LR.dscalar.nii"
	log_File_Must_Exist "${TopographicRegressors}"

	local TopographicMaps="${g_MSMAllTemplates}/Q1-Q6_RelatedParcellation210.atlas_Topography.32k_fs_LR.dscalar.nii"
	log_File_Must_Exist "${TopographicMaps}"
	
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
	local MSMAllRegsOrig=""
	MSMAllRegsOrig+="MSMAll.sh"                       # ModuleName
	MSMAllRegsOrig+="@${g_OutputRegName}"             # RegName
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
	MSMAllRegsOrig+="@${MSMCONFIGDIR}/MSMAllStrainFinalconf1to1_1to3" # RegConf
	MSMAllRegsOrig+="@RegConfVars"                    # RegConfVars
	log_Msg "MSMAllRegsOrig: ${MSMAllRegsOrig}"

	#local RegConfVars=""
	#RegConfVars+="REGNUMBER=1"
	#RegConfVars+=",REGPOWER=3"
	#RegConfVars+=",SCALEPOWER=0"
	#RegConfVars+=",AREALDISTORTION=0"
	#RegConfVars+=",MAXTHETA=0"
	#RegConfVars+=",LAMBDAONE=0.01"
	#RegConfVars+=",LAMBDATWO=0.05"
	#RegConfVars+=",LAMBDATHREE=0.1"
	local RegConfVars="NONE"
	log_Msg "RegConfVars: ${RegConfVars}"

	local MSMAllRegs=$(echo "${MSMAllRegsOrig}" | sed "s/RegConfVars/${RegConfVars}/g")
	log_Msg "MSMAllRegs: ${MSMAllRegs}"

	# Run whatever MSMAll registrations were specified (e.g. when running multiple dimensionalities)

	if [ ! "${MSMAllRegs}" = "NONE" ] ; then

		MSMAllRegs=$(echo "${MSMAllRegs}" | sed 's/+/ /g')
		log_Msg "About to enter loop through MSMAll registrations: MSMAllRegs: ${MSMAllRegs}"

		local MSMAllReg
		for MSMAllReg in ${MSMAllRegs} ; do
			log_Msg "MSMAllReg: ${MSMAllReg}"

			local Module=$(echo "${MSMAllRegs}" | cut -d "@" -f 1)
			log_Msg "Module: ${Module}"

			local RegName=$(echo "${MSMAllRegs}" | cut -d "@" -f 2)
			log_Msg "RegName: ${RegName}"

			local RSNTargetFile=$(echo "${MSMAllRegs}" | cut -d "@" -f 3)
			log_Msg "RSNTargetFile: ${RSNTargetFile}"

			local RSNCostWeights=$(echo "${MSMAllRegs}" | cut -d "@" -f 4)
			log_Msg "RSNCostWeights: ${RSNCostWeights}"

			local MyelinTargetFile=$(echo "${MSMAllRegs}" | cut -d "@" -f 5)
			log_Msg "MyelinTargetFile: ${MyelinTargetFile}"

			local TopographyROIFile=$(echo "${MSMAllRegs}" | cut -d "@" -f 6)
			log_Msg "TopographyROIFile: ${TopographyROIFile}"

			local TopographyTargetFile=$(echo "${MSMAllRegs}" | cut -d "@" -f 7)
			log_Msg "TopographyTargetFile: ${TopographyTargetFile}"

			local Iterations=$(echo "${MSMAllRegs}" | cut -d "@" -f 8)
			log_Msg "Iterations: ${Iterations}"

			local Method=$(echo "${MSMAllRegs}" | cut -d "@" -f 9)
			log_Msg "Method: ${Method}"

			local UseMIGP=$(echo "${MSMAllRegs}" | cut -d "@" -f 10)
			log_Msg "UseMIGP: ${UseMIGP}"

			local ICAdim=$(echo "${MSMAllRegs}" | cut -d "@" -f 11)
			log_Msg "ICAdim: ${ICAdim}"

			local RegressionParams=$(echo "${MSMAllRegs}" | cut -d "@" -f 12)
			log_Msg "RegressionParams: ${RegressionParams}"

			local VN=$(echo "${MSMAllRegs}" | cut -d "@" -f 13)
			log_Msg "VN: ${VN}"

			local ReRun=$(echo "${MSMAllRegs}" | cut -d "@" -f 14)
			log_Msg "ReRun: ${ReRun}"

			local RegConf=$(echo "${MSMAllRegs}" | cut -d "@" -f 15)
			log_Msg "RegConf: ${RegConf}"

			local RegConfVars=$(echo "${MSMAllRegs}" | cut -d "@" -f 16)
			log_Msg "RegConfVars: ${RegConfVars}"

			"${HCPPIPEDIR}"/MSMAll/scripts/"${Module}" \
				--path="${g_StudyFolder}" \
				--subject="${g_Subject}" \
				--high-res-mesh="${g_HighResMesh}" \
				--low-res-mesh="${g_LowResMesh}" \
				--fmri-names-list="${g_fMRINames}" \
				--output-fmri-name="${g_OutputfMRIName}" \
				--fmri-proc-string="${g_fMRIProcSTRING}" \
				--input-pca-registration-name="${InPCARegName}" \
				--input-registration-name="${g_InputRegName}" \
				--registration-name-stem="${RegName}" \
				--rsn-target-file="${RSNTargetFile}" \
				--rsn-cost-weights="${RSNCostWeights}" \
				--myelin-target-file="${MyelinTargetFile}" \
				--topography-roi-file="${TopographyROIFile}" \
				--topography-target-file="${TopographyTargetFile}" \
				--iterations="${Iterations}" \
				--method="${Method}" \
				--use-migp="${UseMIGP}" \
				--ica-dim="${ICAdim}" \
				--regression-params="${RegressionParams}" \
				--vn="${VN}" \
				--rerun="${ReRun}" \
				--reg-conf="${RegConf}" \
				--reg-conf-vars="${RegConfVars}" \
				--matlab-run-mode="${g_MatlabRunMode}"

			g_InputRegName=${RegName}
		done
	fi
}

# ------------------------------------------------------------------------------
#  Invoke the main function to get things started
# ------------------------------------------------------------------------------

main "$@"
