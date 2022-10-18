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

# ------------------------------------------------------------------------------
#  Show usage information for this script
# ------------------------------------------------------------------------------

show_usage()
{
	cat <<EOF

${g_script_name}: MSM-All Registration Pipeline

Usage: ${g_script_name} PARAMETER...

PARAMETERs are [ ] = optional; < > = user supplied value

  [--help] : show usage information and exit
   --path=<path to study folder> OR --study-folder=<path to study folder>
   --subject=<subject ID>
   --fmri-names-list=<fMRI names> an @ symbol separated list of fMRI scan
        names, cannot be used with --multirun-fix-* options
   --multirun-fix-names=<MRfix names> an @-separated list of names, identical
        to what was used in hcp_fix_multi_run
   --multirun-fix-concat-name=<MRfix concat name>, identical to what was used
        in hcp_fix_multi_run
   --multirun-fix-names-to-use=<MRfix run names to use> @-separated list,
        choose which runs should be used as resting state data
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
  [--myelin-target-file=<alternate myelin map target>
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
	unset p_mrfixNames
	unset p_mrfixConcatName
	unset p_mrfixNamesToUse
	unset p_OutputfMRIName
	unset p_HighPass
	unset p_fMRIProcSTRING
	unset p_MSMAllTemplates
	unset p_OutputRegName
	unset p_HighResMesh
	unset p_LowResMesh
	unset p_InputRegName
	unset p_MyelinTargetFile
	unset p_MatlabRunMode
	
	# set default values
	p_MatlabRunMode=${G_DEFAULT_MATLAB_RUN_MODE}

	# parse arguments
	local num_args=${#arguments[@]}
	local argument
	local index

    for ((index = 0; index < num_args; ++index))
    do
		argument=${arguments[index]}

		case ${argument} in
			--help)
				show_usage
				exit 0
				;;
			--path=*)
				p_StudyFolder=${argument#*=}
				;;
			--study-folder=*)
				p_StudyFolder=${argument#*=}
				;;
			--subject=*)
				p_Subject=${argument#*=}
				;;
			--fmri-names-list=*)
				p_fMRINames=${argument#*=}
				;;
			--multirun-fix-names=*)
				p_mrfixNames=${argument#*=}
				;;
			--multirun-fix-concat-name=*)
				p_mrfixConcatName=${argument#*=}
				;;
			--multirun-fix-names-to-use=*)
				p_mrfixNamesToUse=${argument#*=}
				;;
			--output-fmri-name=*)
				p_OutputfMRIName=${argument#*=}
				;;
			--high-pass=*)
				p_HighPass=${argument#*=}
				;;
			--fmri-proc-string=*)
				p_fMRIProcSTRING=${argument#*=}
				;;
			--msm-all-templates=*)
				p_MSMAllTemplates=${argument#*=}
				;;
			--output-registration-name=*)
				p_OutputRegName=${argument#*=}
				;;
			--high-res-mesh=*)
				p_HighResMesh=${argument#*=}
				;;
			--low-res-mesh=*)
				p_LowResMesh=${argument#*=}
				;;
			--input-registration-name=*)
				p_InputRegName=${argument#*=}
				;;
			--myelin-target-file=*)
				p_MyelinTargetFile=${argument#*=}
				;;
			--matlab-run-mode=*)
				p_MatlabRunMode=${argument#*=}
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
		log_Msg "Subject: ${p_Subject}"
	fi

	if [ -z "${p_fMRINames}" ]; then
	    if [[ -z "${p_mrfixNames}" ]]
	    then
		    log_Err "fMRI name list (--fmri-names-list=) or MR fix name list (--multirun-fix-names) required"
		    error_count=$(( error_count + 1 ))
	    else
    	    if [[ -z "$p_mrfixConcatName" ]]
    	    then
		        log_Err "--multirun-fix-concat-name is required when using --multirun-fix-names"
		        error_count=$(( error_count + 1 ))
    	    fi
    	    if [[ -z "$p_mrfixNamesToUse" ]]
    	    then
		        log_Err "--multirun-fix-names-to-use is required when using --multirun-fix-names"
		        error_count=$(( error_count + 1 ))
    	    fi
	    fi
	    log_Msg "MR fix fMRI Names: ${p_mrfixNames}"
	    log_Msg "MR fix fMRI Concat Name: ${p_mrfixConcatName}"
	    log_Msg "MR fix fMRI Names to use: ${p_mrfixNamesToUse}"
	else
	    if [[ ! -z "${p_mrfixNames}" ]]
	    then
		    log_Err "fMRI name list (--fmri-names-list=) and MR fix name list (--multirun-fix-names) must not be used together"
		    error_count=$(( error_count + 1 ))
	    fi
		log_Msg "fMRI Names: ${p_fMRINames}"
	fi

	if [ -z "${p_OutputfMRIName}" ]; then
		log_Err "Output fMRI name (--output-fmri-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Output fMRI Name: ${p_OutputfMRIName}"
	fi

	if [ -z "${p_HighPass}" ]; then
		log_Err "ICA+FIX HighPass setting (--high-pass=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "ICA+FIX HighPass setting: ${p_HighPass}"
	fi

	if [ -z "${p_fMRIProcSTRING}" ]; then
		log_Err "fMRI Proc string (--fmri-proc-string=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "fMRI Proc string: ${p_fMRIProcSTRING}"
	fi

	if [ -z "${p_MSMAllTemplates}" ]; then
		log_Err "MSM All Templates (--msm-all-templates=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "MSM All Templates: ${p_MSMAllTemplates}"
	fi

	if [ -z "${p_OutputRegName}" ]; then
		log_Err "Output Registration Name (--output-registration-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Output Registration Name: ${p_OutputRegName}"
	fi

	if [ -z "${p_HighResMesh}" ]; then
		log_Err "High Resolution Mesh (--high-res-mesh=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "High Resolution Mesh: ${p_HighResMesh}"
	fi

	if [ -z "${p_LowResMesh}" ]; then
		log_Err "Low Resolution Mesh (--low-res-mesh=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Low Resolution Mesh: ${p_LowResMesh}"
	fi

	if [ -z "${p_InputRegName}" ]; then
		log_Err "Input Registration Name (--input-registration-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Input Registration Name: ${p_InputRegName}"
	fi

	log_Msg "Myelin Target File: ${p_MyelinTargetFile}"

	if [ -z "${p_MatlabRunMode}" ]; then
		log_Err "MATLAB run mode value (--matlab-run-mode=) required"
		error_count=$(( error_count + 1 ))
	else
		case ${p_MatlabRunMode} in
			0)
				log_Msg "MATLAB run mode: ${p_MatlabRunMode} - Use compiled MATLAB"
				if [ -z "${MATLAB_COMPILER_RUNTIME}" ]; then
					log_Err_Abort "To use MATLAB run mode: ${p_MatlabRunMode}, the MATLAB_COMPILER_RUNTIME environment variable must be set"
				else
					log_Msg "MATLAB_COMPILER_RUNTIME: ${MATLAB_COMPILER_RUNTIME}"
			  fi
				;;
			1)
				log_Msg "MATLAB run mode: ${p_MatlabRunMode} - Use interpreted MATLAB"
				;;
			2)
				log_Msg "MATLAB run mode: ${p_MatlabRunMode} - Use Octave"
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
	# Show HCP pipelines version
	log_Msg "Showing HCP Pipelines version"
	"${HCPPIPEDIR}"/show_version --short
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
	local fMRINames="${3}"
	local OutputfMRIName="${4}"
	local HighPass="${5}"
	local fMRIProcSTRING="${6}"
	local MSMAllTemplates="${7}"
	local OutputRegName="${8}"
	local HighResMesh="${9}"
	local LowResMesh="${10}"
	local InputRegName="${11}"
	
	local MatlabRunMode
	if [ -z "${12}" ]; then
		MatlabRunMode="${G_DEFAULT_MATLAB_RUN_MODE}"
	else
		MatlabRunMode="${12}"
	fi

	local mrfixNames="${13}"
	local mrfixConcatName="${14}"
	local mrfixNamesToUse="${15}"
	
	local MyelinTargetFile
	if [ -z "${16}" ]; then
		MyelinTargetFile="${MSMAllTemplates}/Q1-Q6_RelatedParcellation210.MyelinMap_BC_MSMAll_2_d41_WRN_DeDrift.32k_fs_LR.dscalar.nii"
	else
		MyelinTargetFile="${16}"
	fi

	# Log values retrieved from positional parameters
	log_Msg "StudyFolder: ${StudyFolder}"
	log_Msg "Subject: ${Subject}"
	log_Msg "fMRINames: ${fMRINames}"
	log_Msg "OutputfMRIName: ${OutputfMRIName}"
	log_Msg "HighPass: ${HighPass}"
	log_Msg "fMRIProcSTRING: ${fMRIProcSTRING}"
	log_Msg "MSMAllTemplates: ${MSMAllTemplates}"
	log_Msg "OutputRegName: ${OutputRegName}"
	log_Msg "HighResMesh: ${HighResMesh}"
	log_Msg "LowResMesh: ${LowResMesh}"
	log_Msg "InputRegName: ${InputRegName}"
	log_Msg "MyelinTargetFile: ${MyelinTargetFile}"
	log_Msg "MatlabRunMode: ${MatlabRunMode}"
	log_Msg "mrfixNames: ${mrfixNames}"
	log_Msg "mrfixConcatName: ${mrfixConcatName}"
	log_Msg "mrfixNamesToUse: ${mrfixNamesToUse}"

	# Naming Conventions and other variables
	local InPCARegName="${InputRegName}"
	log_Msg "InPCARegName: ${InPCARegName}"
	
    local output_proc_string="_vn" #To VN only to indicate that we did not revert the bias field before computing VN
    log_Msg "output_proc_string: ${output_proc_string}"

	local expected_concatenated_output_dir="${StudyFolder}/${Subject}/MNINonLinear/Results/${OutputfMRIName}"
	expected_concatenated_output_file="${expected_concatenated_output_dir}/${OutputfMRIName}${fMRIProcSTRING}${output_proc_string}.dtseries.nii"
	before_vn_output_file="${expected_concatenated_output_dir}/${OutputfMRIName}${fMRIProcSTRING}_novn.dtseries.nii"

	if [[ -z "$fMRINames" ]]
	then
		local -a mrNamesArray mrNamesUseArray runSplits runIndices
		local curTimepoints=0
		#convention: one before the first index of the run
		runSplits[0]="$curTimepoints"
		IFS=@ read -a mrNamesArray <<< "${mrfixNames}"
		IFS=@ read -a mrNamesUseArray <<< "${mrfixNamesToUse}"
		#sanity check for identical names
		for ((index = 0; index < ${#mrNamesArray[@]}; ++index))
		do
			for ((index2 = 0; index2 < ${#mrNamesArray[@]}; ++index2))
			do
				if ((index != index2)) && [[ "${mrNamesArray[$index]}" == "${mrNamesArray[$index2]}" ]]
				then
					log_Err_Abort "MR fix names list contains '${mrNamesArray[$index]}' more than once"
				fi
			done
		done
		#calculate the timepoints where the concatenated switches runs, find which runs are used
		for ((index = 0; index < ${#mrNamesArray[@]}; ++index))
		do
			fmriName="${mrNamesArray[$index]}"
			NumTPS=`${CARET7DIR}/wb_command -file-information "${StudyFolder}/${Subject}/MNINonLinear/Results/${fmriName}/${fmriName}_Atlas.dtseries.nii" -only-number-of-maps`
			curTimepoints=$((curTimepoints + NumTPS))
			runSplits[$((index + 1))]="$curTimepoints"
			for ((index2 = 0; index2 < ${#mrNamesUseArray[@]}; ++index2))
			do
				if [[ "${mrNamesUseArray[$index2]}" == "${mrNamesArray[$index]}" ]]
				then
					runIndices[$index2]="$index"
				fi
			done
		done
		#check that we found all requested runs, build the merge command
		mergeArgs=()
		for ((index2 = 0; index2 < ${#mrNamesUseArray[@]}; ++index2))
		do
			#element may be unset
			runIndex="${runIndices[$index2]+"${runIndices[$index2]}"}"
			if [[ "$runIndex" == "" ]]
			then
				log_Err_Abort "requested run '${mrNamesUseArray[$index2]}' not found in list of MR fix runs"
			fi
			mergeArgs+=(-column $((runSplits[runIndex] + 1)) -up-to $((runSplits[runIndex + 1])) )
		done
		mkdir -p "${expected_concatenated_output_dir}"
		${CARET7DIR}/wb_command -cifti-merge "${before_vn_output_file}" -cifti "${StudyFolder}/${Subject}/MNINonLinear/Results/${mrfixConcatName}/${mrfixConcatName}_Atlas_hp${HighPass}_clean.dtseries.nii" "${mergeArgs[@]}"
		${CARET7DIR}/wb_command -cifti-math 'data / variance' "${expected_concatenated_output_file}" -var data "${before_vn_output_file}" -var variance "${StudyFolder}/${Subject}/MNINonLinear/Results/${mrfixConcatName}/${mrfixConcatName}_Atlas_hp${HighPass}_clean_vn.dscalar.nii" -select 1 1 -repeat
		rm -f -- "${before_vn_output_file}"
	else
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

		local Demean="YES"
		log_Msg "Demean: ${Demean}"

		local VarianceNormalization="YES"
		log_Msg "VarianceNormalization: ${VarianceNormalization}"

		local ComputeVarianceNormalization="NO" #This is computed in FIX now
		log_Msg "ComputeVarianceNormalization: ${ComputeVarianceNormalization}"

		local RevertBiasField="NO" # Will recompute VN based on not reverting bias field
		log_Msg "RevertBiasField: ${RevertBiasField}"

		"${HCPPIPEDIR}"/MSMAll/scripts/SingleSubjectConcat.sh \
			--path="${StudyFolder}" \
			--subject="${Subject}" \
			--fmri-names-list="${fMRINames}" \
			--high-pass="${HighPass}" \
			--output-fmri-name="${OutputfMRIName}" \
			--fmri-proc-string="${fMRIProcSTRING}" \
			--output-proc-string="${output_proc_string}" \
			--demean="${Demean}" \
			--variance-normalization="${VarianceNormalization}" \
			--compute-variance-normalization="${ComputeVarianceNormalization}" \
			--revert-bias-field="${RevertBiasField}" \
			--matlab-run-mode="${MatlabRunMode}"
    fi

	log_File_Must_Exist "${expected_concatenated_output_file}"
	
	# fMRIProcSTRING now should reflect the name expected by registrations done below
	# (e.g. MSMAll)
	fMRIProcSTRING+="${output_proc_string}"
	log_Msg "fMRIProcSTRING: ${fMRIProcSTRING}"

	local RSNTemplates="${MSMAllTemplates}/rfMRI_REST_Atlas_MSMAll_2_d41_WRN_DeDrift_hp2000_clean_PCA.ica_dREPLACEDIM_ROW_vn/melodic_oIC.dscalar.nii"
	log_Msg "RSNTemplates: ${RSNTemplates}"

	local RSNWeights="${MSMAllTemplates}/rfMRI_REST_Atlas_MSMAll_2_d41_WRN_DeDrift_hp2000_clean_PCA.ica_dREPLACEDIM_ROW_vn/Weights.txt"
	log_Msg "RSNWeights: ${RSNWeights}"

	#local MyelinMaps="${MSMAllTemplates}/Q1-Q6_RelatedParcellation210.MyelinMap_BC_MSMAll_2_d41_WRN_DeDrift.32k_fs_LR.dscalar.nii"
	local MyelinMaps="${MyelinTargetFile}"
	log_File_Must_Exist "${MyelinMaps}"
	
	local TopographicRegressors="${MSMAllTemplates}/Q1-Q6_RelatedParcellation210.atlas_Topographic_ROIs.32k_fs_LR.dscalar.nii"
	log_File_Must_Exist "${TopographicRegressors}"

	local TopographicMaps="${MSMAllTemplates}/Q1-Q6_RelatedParcellation210.atlas_Topography.32k_fs_LR.dscalar.nii"
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
	MSMAllRegsOrig+="@${OutputRegName}"               # RegName
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
				--path="${StudyFolder}" \
				--subject="${Subject}" \
				--high-res-mesh="${HighResMesh}" \
				--low-res-mesh="${LowResMesh}" \
				--output-fmri-name="${OutputfMRIName}" \
				--fmri-proc-string="${fMRIProcSTRING}" \
				--input-pca-registration-name="${InPCARegName}" \
				--input-registration-name="${InputRegName}" \
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
				--matlab-run-mode="${MatlabRunMode}"

			InputRegName=${RegName}
		done
	fi
	
	log_Msg "Completing main functionality"
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

# Verify HCPPIPEDIR environment variable is set
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
log_Check_Env_Var MSMCONFIGDIR

# Show tool versions
show_tool_versions

# Determine whether named or positional parameters are used and invoke the 'main' function
if [[ ${1} == --* ]]; then
	# Named parameters (e.g. --parameter-name=parameter-value) are used
	log_Msg "Using named parameters"

	# Get command line options
	get_options "$@"

	# Invoke main functionality using positional parameters
	#     ${1}               ${2}           ${3}             ${4}                  ${5}            ${6}                  ${7}                   ${8}                 ${9}               ${10}             ${11}               ${12}                ${13}             ${14}                  ${15}                  ${16}
	main "${p_StudyFolder}" "${p_Subject}" "${p_fMRINames}" "${p_OutputfMRIName}" "${p_HighPass}" "${p_fMRIProcSTRING}" "${p_MSMAllTemplates}" "${p_OutputRegName}" "${p_HighResMesh}" "${p_LowResMesh}" "${p_InputRegName}" "${p_MatlabRunMode}" "${p_mrfixNames}" "${p_mrfixConcatName}" "${p_mrfixNamesToUse}" "${p_MyelinTargetFile}"

else
	# Positional parameters are used
	log_Msg "Using positional parameters"
	main "$@"

fi

