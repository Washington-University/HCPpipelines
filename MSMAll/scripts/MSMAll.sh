#!/bin/bash

#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # MSMAll.sh
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

usage()
{
	local script_name
	script_name=$(basename "${0}")

	cat <<EOF

${script_name}: MSM-All Registration

Usage: ${script_name} PARAMETER...

PARAMETERs are [ ] = optional; < > = user supplied value

  TBW = To Be Written

  [--help] : show usage information and exit
   --path=<path to study folder> OR --study-folder=<path to study folder>
   --subject=<subject ID>
   --high-res-mesh=<high resolution mesh node count> (in thousands)
   --low-res-mesh=<low resolution mesh node count> (in thousands)
   --fmri-names-list=<fMRI names> an @ symbol separated list of fMRI scan names
   --output-fmri-name=<name given to concatenated singel subject "scan">
   --fmri-proc-string=<identification for FIX cleaned dtseries to use>
   --input-pca-registration-name=TBW
   --input-registration-name=TBW
   --registration-name-stem=TBW
   --rsn-target-file=TBW
   --rsn-cost-weights=TBW
   --myelin-target-file=TBW
   --topography-roi-file=TBW
   --topography-target-file=TBW
   --iterations=TBW
   --method=TBW
   --use-migp=TBW
   --ica-dim=TBW
   --regression-params=TBW
   --vn=TBW
   --rerun=TBW
   --reg-conf=TBW
   --reg-conf-vars=TBW
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
	
	unset p_StudyFolder
	unset p_Subject
	unset p_HighResMesh
	unset p_LowResMesh
	#unset p_fMRINames
	unset p_OutputfMRIName
	unset p_fMRIProcSTRING
	unset p_InPCARegName
	unset p_InRegName
	unset p_RegNameStem
	unset p_RSNTargetFileOrig
	unset p_RSNCostWeightsOrig
	unset p_MyelinTargetFile
	unset p_TopographyROIFile
	unset p_TopographyTargetFile
	unset p_Iterations
	unset p_Method
	unset p_UseMIGP
	unset p_ICAdim
	unset p_RegressionParams
	unset p_VN
	unset p_ReRun
	unset p_RegConf
	unset p_RegConfVars
	unset p_MatlabRunMode
	
	# set default values
	p_MatlabRunMode=0

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
				p_StudyFolder=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--study-folder=*)
				p_StudyFolder=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--subject=*)
				p_Subject=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--high-res-mesh=*)
				p_HighResMesh=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--low-res-mesh=*)
				p_LowResMesh=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			#--fmri-names-list=*)
			#	p_fMRINames=${argument/*=/""}
			#	index=$(( index + 1 ))
			#	;;
			--output-fmri-name=*)
				p_OutputfMRIName=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--fmri-proc-string=*)
				p_fMRIProcSTRING=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--input-pca-registration-name=*)
				p_InPCARegName=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--input-registration-name=*)
				p_InRegName=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--registration-name-stem=*)
				p_RegNameStem=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--rsn-target-file=*)
				p_RSNTargetFileOrig=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--rsn-cost-weights=*)
				p_RSNCostWeightsOrig=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--myelin-target-file=*)
				p_MyelinTargetFile=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--topography-roi-file=*)
				p_TopographyROIFile=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--topography-target-file=*)
				p_TopographyTargetFile=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--iterations=*)
				p_Iterations=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--method=*)
				p_Method=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--use-migp=*)
				p_UseMIGP=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--ica-dim=*)
				p_ICAdim=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--regression-params=*)
				p_RegressionParams=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--vn=*)
				p_VN=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--rerun=*)
				p_ReRun=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--reg-conf=*)
				p_RegConf=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--reg-conf-vars=*)
				# Note: since the value of this parameter contains equal signs ("="),
				# we have to handle grabbing the value slightly differently than
				# in the other cases.
				p_RegConfVars=${argument#--reg-conf-vars=}
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
		log_Msg "Study Folder: ${study_folder}"
	fi

	if [ -z "${p_Subject}" ]; then
		log_Err "Subject (--subject=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Subject: ${p_Subject}"
	fi
	
	if [ -z "${p_HighResMesh}" ]; then
		log_Err "High Res Mesh (--high-res-mesh=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "High Res Mesh: ${p_HighResMesh}"
	fi
	
	if [ -z "${p_LowResMesh}" ]; then
		log_Err "Low Res Mesh (--low-res-mesh=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Low Res Mesh: ${p_LowResMesh}"
	fi

	#if [ -z "${p_fMRINames}" ]; then
	#	log_Err "fMRI Names List (--fmri-names-list=) required"
	#	error_count=$(( error_count + 1 ))
	#else
	#	log_Msg "fMRI Names List: ${p_fMRINames}"
	#fi
	
	if [ -z "${p_OutputfMRIName}" ]; then
		log_Err "Output fMRI Name (--output-fmri-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Output fMRI Name: ${p_OutputfMRIName}"
	fi

	if [ -z "${p_fMRIProcSTRING}" ]; then
		log_Err "fMRI Proc STRING (--fmri-proc-string=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "fMRI Proc STRING: ${p_fMRIProcSTRING}"
	fi

	if [ -z "${p_InPCARegName}" ]; then
		log_Err "Input PCA Registration Name (--input-pca-registration-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Input PCA Registration Name: ${p_InPCARegName}"
	fi
	
	if [ -z "${p_InRegName}" ]; then
		log_Err "Input Registration Name (--input-registration-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Input Registration Name: ${p_InRegName}"
	fi
	
	if [ -z "${p_RegNameStem}" ]; then
		log_Err "Registration Name Stem: (--registration-name-stem=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Registration Name Stem: ${p_RegNameStem}"
	fi

	if [ -z "${p_RSNTargetFileOrig}" ]; then
		log_Err "RSN Target File: (--rsn-target-file=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "RSN Target File: ${p_RSNTargetFileOrig}"
	fi
	
	if [ -z "${p_RSNCostWeightsOrig}" ]; then
		log_Err "RSN Cost Weights: (--rsn-cost-weights=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "RSN Cost Weights: ${p_RSNCostWeightsOrig}"
	fi
	
	if [ -z "${p_MyelinTargetFile}" ]; then
		log_Err "Myelin Target File: (--myelin-target-file=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Myelin Target File: ${p_MyelinTargetFile}"
	fi

	if [ -z "${p_TopographyROIFile}" ]; then
		log_Err "Topography ROI File: (--topography-roi-file=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Topography ROI File: ${p_TopographyROIFile}"
	fi
	
	if [ -z "${p_TopographyTargetFile}" ]; then
		log_Err "Topography Target File: (--topography-target-file=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Topography Target File: ${p_TopographyTargetFile}"
	fi
	
	if [ -z "${p_Iterations}" ]; then
		log_Err "Iterations: (--iterations=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Iterations: ${p_Iterations}"
	fi

	if [ -z "${p_Method}" ]; then
		log_Err "Method: (--method=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Method: ${p_method}"
	fi

 	if [ -z "${p_UseMIGP}" ]; then
		log_Err "Use MIGP: (--use-migp=<YES | NO>) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Use MIGP: ${p_UseMIGP}"
	fi

	if [ -z "${p_ICAdim}" ]; then
		log_Err "ICA Dim: (--ica-dim=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "ICA Dim: ${p_ICAdim}"
	fi

	if [ -z "${p_RegressionParams}" ]; then
		log_Err "Regression Params: (--regression-params=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Regression Params: ${p_RegressionParams}"
	fi
	
	if [ -z "${p_VN}" ]; then
		log_Err "VN: (--vn=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "VN: ${p_vn}"
	fi

	if [ -z "${p_ReRun}" ]; then
		log_Err "ReRun: (--rerun=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "ReRun: ${p_ReRun}"
	fi
	
	if [ -z "${p_RegConf}" ]; then
		log_Err "Reg Conf: (--reg-conf=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Reg Conf: ${p_RegConf}"
	fi
	
	if [ -z "${p_RegConfVars}" ]; then
		log_Err "Reg Conf Vars: (--reg-conf-vars=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Reg Conf Vars: ${p_RegConfVars}"
	fi
	
	if [ -z "${p_MatlabRunMode}" ]; then
		log_Err "MATLAB run mode: (--matlab-run-mode=) required"
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
			1)
				log_Msg "MATLAB run mode: ${p_MatlabRunMode}"
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
#  Show Tool Versions
# ------------------------------------------------------------------------------

show_tool_versions()
{
	# Show wb_command version
	log_Msg "Showing wb_command version"
	"${CARET7DIR}"/wb_command -version

	# Show msm version (?)
	log_Msg "Cannot reliably show an msm version because some versions of msm do not support a --version option"
}

# ------------------------------------------------------------------------------
#  Main processing of script.
# ------------------------------------------------------------------------------

main()
{
	# Retrieve positional parameters
	local StudyFolder="${1}"
	local Subject="${2}"
	local HighResMesh="${3}"
	local LowResMesh="${4}"
	local OutputfMRIName="${5}"
	local fMRIProcSTRING="${6}"
	local InPCARegName="${7}"
	local InRegName="${8}"
	local RegNameStem="${9}"
	local RSNTargetFileOrig="${10}"
	local RSNCostWeightsOrig="${11}"
	local MyelinTargetFile="${12}"
	local TopographyROIFile="${13}"
	local TopographyTargetFile="${14}"
	local Iterations="${15}"
	local Method="${16}"
	local UseMIGP="${17}"
	local ICAdim="${18}"
	local RegressionParams="${19}"
	local VN="${20}"
	local ReRun="${21}"
	local RegConf="${22}"
	local RegConfVars="${23}"

	local MatlabRunMode
	if [ -z "${24}" ]; then
		MatlabRunMode=0
	else
		MatlabRunMode="${24}"
	fi
	
	# Log values retrieved from positional parameters
	log_Msg "StudyFolder: ${StudyFolder}"
	log_Msg "Subject: ${Subject}"
	log_Msg "HighResMesh: ${HighResMesh}"
	log_Msg "LowResMesh: ${LowResMesh}"
	log_Msg "OutputfMRIName: ${OutputfMRIName}"
	log_Msg "fMRIProcSTRING: ${fMRIProcSTRING}"
	log_Msg "InPCARegName: ${InPCARegName}"
	log_Msg "InRegName: ${InRegName}"
	log_Msg "RegNameStem: ${RegNameStem}"
	log_Msg "RSNTargetFileOrig: ${RSNTargetFileOrig}"
	log_Msg "RSNCostWeightsOrig: ${RSNCostWeightsOrig}"
	log_Msg "MyelinTargetFile: ${MyelinTargetFile}"
	log_Msg "TopographyROIFile: ${TopographyROIFile}"
	log_Msg "TopographyTargetFile: ${TopographyTargetFile}"
	log_Msg "Iterations: ${Iterations}"
	log_Msg "Method: ${Method}"
	log_Msg "UseMIGP: ${UseMIGP}"
	log_Msg "ICAdim: ${ICAdim}"
	log_Msg "RegressionParams: ${RegressionParams}"
	log_Msg "VN: ${VN}"
	log_Msg "ReRun: ${ReRun}"
	log_Msg "RegConf: ${RegConf}"
	log_Msg "RegConfVars: ${RegConfVars}"
	log_Msg "MatlabRunMode: ${MatlabRunMode}"
	
	# Naming Conventions and other variables
	Caret7_Command=${CARET7DIR}/wb_command
	AtlasFolder="${StudyFolder}/${Subject}/MNINonLinear"
	DownSampleFolder="${AtlasFolder}/fsaverage_LR${LowResMesh}k"
	NativeFolder="${AtlasFolder}/Native"
	ResultsFolder="${AtlasFolder}/Results/${OutputfMRIName}"
	T1wFolder="${StudyFolder}/${Subject}/T1w"
	DownSampleT1wFolder="${T1wFolder}/fsaverage_LR${LowResMesh}k"
	NativeT1wFolder="${T1wFolder}/Native"

	if [[ $(echo -n "${Method}" | grep "WR") ]] ; then
		LowICAdims=$(echo "${RegressionParams}" | sed 's/_/ /g')
	fi

	Iterations=$(echo "${Iterations}" | sed 's/_/ /g')
	NumIterations=$(echo "${Iterations}" | wc -w)
	CorrectionSigma=$(echo "sqrt ( 200 )" | bc -l)
	BC="NO"
	nTPsForSpectra="0" #Set to zero to not compute spectra
	VolParams="NO" #Dont' output volume RSN maps

	# Log values of Naming Conventions and other variables
	log_Msg "Caret7_Command: ${Caret7_Command}"
	log_Msg "AtlasFolder: ${AtlasFolder}"
	log_Msg "DownSampleFolder: ${DownSampleFolder}"
	log_Msg "NativeFolder: ${NativeFolder}"
	log_Msg "ResultsFolder: ${ResultsFolder}"
	log_Msg "T1wFolder: ${T1wFolder}"
	log_Msg "DownSampleT1wFolder: ${DownSampleT1wFolder}"
	log_Msg "NativeT1wFolder: ${NativeT1wFolder}"
	log_Msg "LowICAdims: ${LowICAdims}"
	log_Msg "Iterations: ${Iterations}"
	log_Msg "NumIterations: ${NumIterations}"
	log_Msg "CorrectionSigma: ${CorrectionSigma}"
	log_Msg "BC: ${BC}"
	log_Msg "nTPsForSpectra: ${nTPsForSpectra}"
	log_Msg "VolParams: ${VolParams}"

	
	if [[ ! -e ${NativeFolder}/${Subject}.ArealDistortion_${RegNameStem}_${NumIterations}_d${ICAdim}_${Method}.native.dscalar.nii || ${ReRun} = "YES" ]] ; then

		##IsRunning="${NativeFolder}/${Subject}.IsRunning_${RegNameStem}_${NumIterations}_d${ICAdim}_${Method}.txt"
		##if [ ! -e ${IsRunning} ] ; then
		##  touch ${IsRunning}
		##else
		##  exit
		##fi

		RSNTargetFile=$(echo "${RSNTargetFileOrig}" | sed "s/REPLACEDIM/${ICAdim}/g")
		log_Msg "RSNTargetFile: ${RSNTargetFile}"
		log_File_Must_Exist "${RSNTargetFile}"

		RSNCostWeights=$(echo "${RSNCostWeightsOrig}" | sed "s/REPLACEDIM/${ICAdim}/g")
		log_Msg "RSNCostWeights: ${RSNCostWeights}"
		log_File_Must_Exist "${RSNCostWeights}"

		cp --verbose "${RSNTargetFile}" "${DownSampleFolder}/${Subject}.atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.dscalar.nii"
		cp --verbose "${MyelinTargetFile}" "${DownSampleFolder}/${Subject}.atlas_MyelinMap_BC.${LowResMesh}k_fs_LR.dscalar.nii"
		cp --verbose "${TopographyROIFile}" "${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs.${LowResMesh}k_fs_LR.dscalar.nii"
		cp --verbose "${TopographyTargetFile}" "${DownSampleFolder}/${Subject}.atlas_Topography.${LowResMesh}k_fs_LR.dscalar.nii"

		if [ "${InPCARegName}" = "MSMSulc" ] ; then
			log_Msg "InPCARegName is MSMSulc"
			InPCARegString="MSMSulc"
			OutPCARegString=""
			PCARegString=""
			SurfRegSTRING=""
		else
			log_Msg "InPCARegName is not MSMSulc"
			InPCARegString="${InPCARegName}"
			OutPCARegString="${InPCARegName}_"
			PCARegString="_${InPCARegName}"
			SurfRegSTRING=""
		fi

		log_Msg "InPCARegString: ${InPCARegString}"
		log_Msg "OutPCARegString: ${OutPCARegString}"
		log_Msg "PCARegString: ${PCARegString}"
		log_Msg "SurfRegSTRING: ${SurfRegSTRING}"

		# Create midthickness Vertex Area (VA) maps if they do not already exist
		log_Msg "Check for existence of of normalized midthickness Vertex Area map"
		
		local midthickness_va_file            # path to non-normalized midthickness vertex area file
		local normalized_midthickness_va_file # path to normalized midthickness vertex area file
		local surface_to_measure              # path to surface file on which to measure surface areas
		local output_metric                   # path to metric file generated by -surface-vertex-areas subcommand

		midthickness_va_file=${DownSampleT1wFolder}/${Subject}.midthickness_va.${LowResMesh}k_fs_LR.dscalar.nii
		normalized_midthickness_va_file=${DownSampleT1wFolder}/${Subject}.midthickness_va_norm.${LowResMesh}k_fs_LR.dscalar.nii
		
		if [ ! -f "${normalized_midthickness_va_file}" ] ; then
			log_Msg "Creating midthickness Vertex Area (VA) maps"

			for Hemisphere in L R ; do
				surface_to_measure=${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness.${LowResMesh}k_fs_LR.surf.gii
				output_metric=${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_va.${LowResMesh}k_fs_LR.shape.gii
				${Caret7_Command} -surface-vertex-areas ${surface_to_measure} ${output_metric}
			done

			local left_metric  # path to left hemisphere VA metric file
			local roi_left     # path to file of ROI vertices to use from left surface
			local right_metric # path to right hemisphere VA metric file
			local roi_right    # path to file of ROI vertices to use from right surface

			left_metric=${DownSampleT1wFolder}/${Subject}.L.midthickness_va.${LowResMesh}k_fs_LR.shape.gii
			roi_left=${DownSampleFolder}/${Subject}.L.atlasroi.${LowResMesh}k_fs_LR.shape.gii
			right_metric=${DownSampleT1wFolder}/${Subject}.R.midthickness_va.${LowResMesh}k_fs_LR.shape.gii
			roi_right=${DownSampleFolder}/${Subject}.R.atlasroi.${LowResMesh}k_fs_LR.shape.gii

			${Caret7_Command} -cifti-create-dense-scalar ${midthickness_va_file} \
							  -left-metric  ${left_metric} \
							  -roi-left     ${roi_left} \
							  -right-metric ${right_metric} \
							  -roi-right    ${roi_right}

			local VAMean # mean of surface area accounted for for each vertex - used for normalization
			VAMean=$(${Caret7_Command} -cifti-stats ${midthickness_va_file} -reduce MEAN)
			log_Msg "VAMean: ${VAMean}"

			${Caret7_Command} -cifti-math "VA / ${VAMean}" ${normalized_midthickness_va_file} -var VA ${midthickness_va_file}

			log_Msg "Done creating midthickness Vertex Area (VA) maps"
			
		else
			log_Msg "Normalized midthickness VA file already exists"
			
		fi
		
		log_Msg "NumIterations: ${NumIterations}"
		i=1
		while [ ${i} -le ${NumIterations} ] ; do
			log_Msg "i: ${i}"
			RegName="${RegNameStem}_${i}_d${ICAdim}_${Method}"
			log_Msg "RegName: ${RegName}"
			Modalities=$(echo ${Iterations} | cut -d " " -f ${i})
			log_Msg "Modalities: ${Modalities}"

			if [ ! -e ${NativeFolder}/${RegName} ] ; then
				mkdir --verbose ${NativeFolder}/${RegName}
			else
				rm -r "${NativeFolder:?}/${RegName}"
				mkdir --verbose ${NativeFolder}/${RegName}
			fi

			if [[ $(echo -n ${Modalities} | grep "C") || $(echo -n ${Modalities} | grep "T") ]] ; then
				for Hemisphere in L R ; do
					${Caret7_Command} -surface-sphere-project-unproject ${DownSampleFolder}/${Subject}.${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${InPCARegString}.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${InRegName}.native.surf.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.sphere.${OutPCARegString}${InRegName}.${LowResMesh}k_fs_LR.surf.gii
				done

				if [ ${UseMIGP} = "YES" ] ; then
					inputdtseries="${ResultsFolder}/${OutputfMRIName}${fMRIProcSTRING}_PCA${PCARegString}.dtseries.nii"
				else
					inputdtseries="${ResultsFolder}/${OutputfMRIName}${fMRIProcSTRING}${PCARegString}.dtseries.nii"
				fi
			fi

			if [[ $(echo -n ${Modalities} | grep "C") ]] ; then
				log_Msg "Modalities includes C"
				log_Msg "Resample the atlas instead of the timeseries"
				${Caret7_Command} -cifti-resample ${DownSampleFolder}/${Subject}.atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ${DownSampleFolder}/${Subject}.atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${Subject}.atlas_RSNs_d${ICAdim}_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${Subject}.L.sphere.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.sphere.${OutPCARegString}${InRegName}.${LowResMesh}k_fs_LR.surf.gii -left-area-surfs ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii -right-spheres ${DownSampleFolder}/${Subject}.R.sphere.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.sphere.${OutPCARegString}${InRegName}.${LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii

				NumValidRSNs=$(cat ${RSNCostWeights} | wc -w)
				inputweights="${RSNCostWeights}"
				inputspatialmaps="${DownSampleFolder}/${Subject}.atlas_RSNs_d${ICAdim}_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii"
				outputspatialmaps="${DownSampleFolder}/${Subject}.individual_RSNs_d${ICAdim}_${InRegName}.${LowResMesh}k_fs_LR" #No Ext
				outputweights="${DownSampleFolder}/${Subject}.individual_RSNs_d${ICAdim}_weights.${LowResMesh}k_fs_LR.dscalar.nii"
				Params="${NativeFolder}/${RegName}/Params.txt"
				touch ${Params}
				if [[ $(echo -n ${Method} | grep "WR") ]] ; then
					Distortion="${normalized_midthickness_va_file}"
					echo ${Distortion} > ${Params}
					LeftSurface="${DownSampleT1wFolder}/${Subject}.L.midthickness${SurfRegSTRING}.${LowResMesh}k_fs_LR.surf.gii"
					echo ${LeftSurface} >> ${Params}
					RightSurface="${DownSampleT1wFolder}/${Subject}.R.midthickness${SurfRegSTRING}.${LowResMesh}k_fs_LR.surf.gii"
					echo ${RightSurface} >> ${Params}
					for LowICAdim in ${LowICAdims} ; do
						LowDim=$(echo ${RSNTargetFileOrig} | sed "s/REPLACEDIM/${LowICAdim}/g")
						echo ${LowDim} >> ${Params}
					done
				fi

				case ${MatlabRunMode} in

					0)
						# Use Compiled MATLAB
						matlab_exe="${HCPPIPEDIR}"
						matlab_exe+="/MSMAll/scripts/Compiled_MSMregression/run_MSMregression.sh"

						matlab_compiler_runtime="${MATLAB_COMPILER_RUNTIME}"

						matlab_function_arguments="'${inputspatialmaps}'"
						matlab_function_arguments+=" '${inputdtseries}'"
						matlab_function_arguments+=" '${inputweights}'"
						matlab_function_arguments+=" '${outputspatialmaps}'"
						matlab_function_arguments+=" '${outputweights}'"
						matlab_function_arguments+=" '${Caret7_Command}'"
						matlab_function_arguments+=" '${Method}'"
						matlab_function_arguments+=" '${Params}'"
						matlab_function_arguments+=" '${VN}'"
						matlab_function_arguments+=" ${nTPsForSpectra}"
						matlab_function_arguments+=" '${BC}'"
						matlab_function_arguments+=" '${VolParams}'"

						matlab_logging=">> ${StudyFolder}/${Subject}.MSMregression.matlab.C.Iteration${i}.log 2>&1"

						matlab_cmd="${matlab_exe} ${matlab_compiler_runtime} ${matlab_function_arguments} ${matlab_logging}"

						# Note: Simply using ${matlab_cmd} here instead of echo "${matlab_cmd}" | bash
						#       does NOT work. The output redirects that are part of the ${matlab_logging}
						#       value, get quoted by the run_*.sh script generated by the MATLAB compiler
						#       such that they get passed as parameters to the underlying executable.
						#       So ">>" gets passed as a parameter to the executable as does the
						#       log file name and the "2>&1" redirection. This causes the executable
						#       to die with a "too many parameters" error message.
						log_Msg "Run MATLAB command: ${matlab_cmd}"
						echo "${matlab_cmd}" | bash
						log_Msg "MATLAB command return code: $?"
						;;

					1)
						# Use interpreted MATLAB
						mPath="${HCPPIPEDIR}/MSMAll/scripts"
						mGlobalPath="${HCPPIPEDIR}/global/matlab"

						matlab -nojvm -nodisplay -nosplash <<M_PROG
addpath '$mPath'; addpath '$mGlobalPath'; MSMregression('${inputspatialmaps}','${inputdtseries}','${inputweights}','${outputspatialmaps}','${outputweights}','${Caret7_Command}','${Method}','${Params}','${VN}',${nTPsForSpectra},'${BC}','${VolParams}');
M_PROG
						log_Msg "addpath '$mPath'; addpath '$mGlobalPath'; MSMregression('${inputspatialmaps}','${inputdtseries}','${inputweights}','${outputspatialmaps}','${outputweights}','${Caret7_Command}','${Method}','${Params}','${VN}',${nTPsForSpectra},'${BC}','${VolParams}');"
						;;

					*)
						log_Err_Abort "Unsupported MATLAB run mode value: ${MatlabRunMode}"
						;;
				esac

				rm ${Params} ${DownSampleFolder}/${Subject}.atlas_RSNs_d${ICAdim}_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii

				# Resample the individual maps so they are in the correct space
				log_Msg "Resample the individual maps so they are in the correct space"
				${Caret7_Command} -cifti-resample ${DownSampleFolder}/${Subject}.individual_RSNs_d${ICAdim}_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ${DownSampleFolder}/${Subject}.individual_RSNs_d${ICAdim}_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${Subject}.individual_RSNs_d${ICAdim}_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${Subject}.L.sphere.${OutPCARegString}${InRegName}.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.sphere.${LowResMesh}k_fs_LR.surf.gii  -left-area-surfs ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii -right-spheres ${DownSampleFolder}/${Subject}.R.sphere.${OutPCARegString}${InRegName}.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.sphere.${LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii

				${Caret7_Command} -cifti-separate-all ${DownSampleFolder}/${Subject}.individual_RSNs_d${ICAdim}_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii -left ${DownSampleFolder}/${Subject}.L.individual_RSNs_d${ICAdim}_${InRegName}.${LowResMesh}k_fs_LR.func.gii -right ${DownSampleFolder}/${Subject}.R.individual_RSNs_d${ICAdim}_${InRegName}.${LowResMesh}k_fs_LR.func.gii

				${Caret7_Command} -cifti-separate-all ${DownSampleFolder}/${Subject}.atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.dscalar.nii -left ${DownSampleFolder}/${Subject}.L.atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.func.gii -right ${DownSampleFolder}/${Subject}.R.atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.func.gii

				${Caret7_Command} -cifti-separate-all ${DownSampleFolder}/${Subject}.individual_RSNs_d${ICAdim}_weights.${LowResMesh}k_fs_LR.dscalar.nii -left ${DownSampleFolder}/${Subject}.L.individual_RSNs_d${ICAdim}_weights.${LowResMesh}k_fs_LR.func.gii -right ${DownSampleFolder}/${Subject}.R.individual_RSNs_d${ICAdim}_weights.${LowResMesh}k_fs_LR.func.gii

			fi

			if [[ $(echo -n ${Modalities} | grep "A") ]] ; then
				log_Msg "Modalities includes A"
				${Caret7_Command} -cifti-resample ${NativeFolder}/${Subject}.MyelinMap.native.dscalar.nii COLUMN ${DownSampleFolder}/${Subject}.MyelinMap.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${Subject}.MyelinMap_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${NativeFolder}/${Subject}.L.sphere.${InRegName}.native.surf.gii ${DownSampleFolder}/${Subject}.L.sphere.${LowResMesh}k_fs_LR.surf.gii -left-area-surfs ${NativeT1wFolder}/${Subject}.L.midthickness.native.surf.gii ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii -right-spheres ${NativeFolder}/${Subject}.R.sphere.${InRegName}.native.surf.gii ${DownSampleFolder}/${Subject}.R.sphere.${LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${NativeT1wFolder}/${Subject}.R.midthickness.native.surf.gii ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii
				${Caret7_Command} -cifti-math "Individual - Reference" ${DownSampleFolder}/${Subject}.BiasField_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii -var Individual ${DownSampleFolder}/${Subject}.MyelinMap_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii -var Reference ${DownSampleFolder}/${Subject}.atlas_MyelinMap_BC.${LowResMesh}k_fs_LR.dscalar.nii
				${Caret7_Command} -cifti-smoothing ${DownSampleFolder}/${Subject}.BiasField_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii ${CorrectionSigma} 0 COLUMN ${DownSampleFolder}/${Subject}.BiasField_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii -left-surface ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii -right-surface ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii
				${Caret7_Command} -cifti-separate-all ${DownSampleFolder}/${Subject}.BiasField_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii -left ${DownSampleFolder}/${Subject}.L.BiasField_${InRegName}.${LowResMesh}k_fs_LR.func.gii -right ${DownSampleFolder}/${Subject}.R.BiasField_${InRegName}.${LowResMesh}k_fs_LR.func.gii
				${Caret7_Command} -cifti-separate-all ${DownSampleFolder}/${Subject}.atlas_MyelinMap_BC.${LowResMesh}k_fs_LR.dscalar.nii -left ${DownSampleFolder}/${Subject}.L.atlas_MyelinMap_BC.${LowResMesh}k_fs_LR.func.gii -right ${DownSampleFolder}/${Subject}.R.atlas_MyelinMap_BC.${LowResMesh}k_fs_LR.func.gii
			fi

			if [[ $(echo -n ${Modalities} | grep "T") ]] ; then
				# Resample the atlas instead of the timeseries
				log_Msg "Modalities includes T"
				log_Msg "Resample the atlas instead of the timeseries"
				${Caret7_Command} -cifti-resample ${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${Subject}.L.sphere.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.sphere.${OutPCARegString}${InRegName}.${LowResMesh}k_fs_LR.surf.gii -left-area-surfs ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii -right-spheres ${DownSampleFolder}/${Subject}.R.sphere.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.sphere.${OutPCARegString}${InRegName}.${LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii
				NumMaps=$(${Caret7_Command} -file-information ${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs.${LowResMesh}k_fs_LR.dscalar.nii -only-number-of-maps)
				TopographicWeights=${NativeFolder}/${RegName}/TopographicWeights.txt
				n=1
				while [ ${n} -le ${NumMaps} ] ; do
					echo -n "${n} " >> ${TopographicWeights}
					n=$(( n+1 ))
				done
				inputweights="${TopographicWeights}"
				inputspatialmaps="${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii"
				outputspatialmaps="${DownSampleFolder}/${Subject}.individual_Topography_${InRegName}.${LowResMesh}k_fs_LR" #No Ext
				outputweights="${DownSampleFolder}/${Subject}.individual_Topography_weights.${LowResMesh}k_fs_LR.dscalar.nii"
				Params="${NativeFolder}/${RegName}/Params.txt"
				touch ${Params}
				if [[ $(echo -n ${Method} | grep "WR") ]] ; then
					Distortion="${normalized_midthickness_va_file}"
					echo ${Distortion} > ${Params}
				fi

				case ${MatlabRunMode} in
					0)
						# Use Compiled Matlab
						matlab_exe="${HCPPIPEDIR}"
						matlab_exe+="/MSMAll/scripts/Compiled_MSMregression/run_MSMregression.sh"

						matlab_compiler_runtime="${MATLAB_COMPILER_RUNTIME}"

						matlab_function_arguments="'${inputspatialmaps}'"
						matlab_function_arguments+=" '${inputdtseries}'"
						matlab_function_arguments+=" '${inputweights}'"
						matlab_function_arguments+=" '${outputspatialmaps}'"
						matlab_function_arguments+=" '${outputweights}'"
						matlab_function_arguments+=" '${Caret7_Command}'"
						matlab_function_arguments+=" '${Method}'"
						matlab_function_arguments+=" '${Params}'"
						matlab_function_arguments+=" '${VN}'"
						matlab_function_arguments+=" ${nTPsForSpectra}"
						matlab_function_arguments+=" '${BC}'"
						matlab_function_arguments+=" '${VolParams}'"

						matlab_logging=">> ${StudyFolder}/${Subject}.MSMregression.matlab.T.Iteration${i}.log 2>&1"

						matlab_cmd="${matlab_exe} ${matlab_compiler_runtime} ${matlab_function_arguments} ${matlab_logging}"
						
						# Note: Simply using ${matlab_cmd} here instead of echo "${matlab_cmd}" | bash
						#       does NOT work. The output redirects that are part of the ${matlab_logging}
						#       value, get quoted by the run_*.sh script generated by the MATLAB compiler
						#       such that they get passed as parameters to the underlying executable.
						#       So ">>" gets passed as a parameter to the executable as does the
						#       log file name and the "2>&1" redirection. This causes the executable
						#       to die with a "too many parameters" error message.
						log_Msg "Run Matlab command: ${matlab_cmd}"
						echo "${matlab_cmd}" | bash
						log_Msg "Matlab command return code: $?"
						;;

					1)
						# Use interpreted MATLAB
						mPath="${HCPPIPEDIR}/MSMAll/scripts"

						matlab -nojvm -nodisplay -nosplash <<M_PROG
addpath '$mPath'; MSMregression('${inputspatialmaps}','${inputdtseries}','${inputweights}','${outputspatialmaps}','${outputweights}','${Caret7_Command}','${Method}','${Params}','${VN}',${nTPsForSpectra},'${BC}','${VolParams}');
M_PROG
						log_Msg "addpath '$mPath'; MSMregression('${inputspatialmaps}','${inputdtseries}','${inputweights}','${outputspatialmaps}','${outputweights}','${Caret7_Command}','${Method}','${Params}','${VN}',${nTPsForSpectra},'${BC}','${VolParams}');"
						;;

					*)
						log_Err_Abort "Unsupported MATLAB run mode value: ${MatlabRunMode}"
						;;
				esac

				rm ${Params} ${TopographicWeights} ${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii

				# Resample the individual maps so they are in the correct space
				log_Msg "Resample the individual maps so they are in the correct space"

				${Caret7_Command} -cifti-resample ${DownSampleFolder}/${Subject}.individual_Topography_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ${DownSampleFolder}/${Subject}.individual_Topography_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${Subject}.individual_Topography_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${Subject}.L.sphere.${OutPCARegString}${InRegName}.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.sphere.${LowResMesh}k_fs_LR.surf.gii  -left-area-surfs ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii -right-spheres ${DownSampleFolder}/${Subject}.R.sphere.${OutPCARegString}${InRegName}.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.sphere.${LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii

				${Caret7_Command} -cifti-math "Weights - (V1 > 0)" ${DownSampleFolder}/${Subject}.individual_Topography_weights.${LowResMesh}k_fs_LR.dscalar.nii -var V1 ${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs.${LowResMesh}k_fs_LR.dscalar.nii -select 1 8 -repeat -var Weights ${DownSampleFolder}/${Subject}.individual_Topography_weights.${LowResMesh}k_fs_LR.dscalar.nii

				${Caret7_Command} -cifti-separate-all ${DownSampleFolder}/${Subject}.individual_Topography_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii -left ${DownSampleFolder}/${Subject}.L.individual_Topography_${InRegName}.${LowResMesh}k_fs_LR.func.gii -right ${DownSampleFolder}/${Subject}.R.individual_Topography_${InRegName}.${LowResMesh}k_fs_LR.func.gii

				${Caret7_Command} -cifti-separate-all ${DownSampleFolder}/${Subject}.atlas_Topography.${LowResMesh}k_fs_LR.dscalar.nii -left ${DownSampleFolder}/${Subject}.L.atlas_Topography.${LowResMesh}k_fs_LR.func.gii -right ${DownSampleFolder}/${Subject}.R.atlas_Topography.${LowResMesh}k_fs_LR.func.gii

				${Caret7_Command} -cifti-separate-all ${DownSampleFolder}/${Subject}.individual_Topography_weights.${LowResMesh}k_fs_LR.dscalar.nii -left ${DownSampleFolder}/${Subject}.L.individual_Topography_weights.${LowResMesh}k_fs_LR.func.gii -right ${DownSampleFolder}/${Subject}.R.individual_Topography_weights.${LowResMesh}k_fs_LR.func.gii

			fi

			function RegHemi
			{
				Hemisphere="${1}"
				if [ $Hemisphere = "L" ] ; then
					Structure="CORTEX_LEFT"
				elif [ $Hemisphere = "R" ] ; then
					Structure="CORTEX_RIGHT"
				fi

				log_Msg "RegHemi - Hemisphere: ${Hemisphere}"
				log_Msg "RegHemi - Structure:  ${Structure}"
				log_Msg "RegHemi - Modalities: ${Modalities}"

				if [[ $(echo -n ${Modalities} | grep "C") ]] ; then
					log_Msg "RegHemi - Modalities contains C"

 					${Caret7_Command} -metric-resample ${DownSampleFolder}/${Subject}.${Hemisphere}.individual_RSNs_d${ICAdim}_${InRegName}.${LowResMesh}k_fs_LR.func.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${InRegName}.native.surf.gii ADAP_BARY_AREA ${NativeFolder}/${Subject}.${Hemisphere}.individual_RSNs_d${ICAdim}_${InRegName}.native.func.gii -area-surfs ${DownSampleFolder}/${Subject}.${Hemisphere}.midthickness.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.midthickness.native.surf.gii -current-roi ${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii -valid-roi-out ${NativeFolder}/${Subject}.${Hemisphere}.${InRegName}_roi.native.shape.gii

					${Caret7_Command} -metric-resample ${DownSampleFolder}/${Subject}.${Hemisphere}.individual_RSNs_d${ICAdim}_weights.${LowResMesh}k_fs_LR.func.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${InRegName}.native.surf.gii ADAP_BARY_AREA ${NativeFolder}/${Subject}.${Hemisphere}.individual_RSNs_d${ICAdim}_weights.native.func.gii -area-surfs ${DownSampleFolder}/${Subject}.${Hemisphere}.midthickness.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.midthickness.native.surf.gii -current-roi ${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii -valid-roi-out ${NativeFolder}/${Subject}.${Hemisphere}.${InRegName}_roi.native.shape.gii -largest

					${Caret7_Command} -metric-resample ${DownSampleFolder}/${Subject}.${Hemisphere}.atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.func.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${InRegName}.native.surf.gii ADAP_BARY_AREA ${NativeFolder}/${Subject}.${Hemisphere}.atlas_RSNs_d${ICAdim}.native.func.gii -area-surfs ${DownSampleFolder}/${Subject}.${Hemisphere}.midthickness.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.midthickness.native.surf.gii -current-roi ${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii -valid-roi-out ${NativeFolder}/${Subject}.${Hemisphere}.${InRegName}_roi.native.shape.gii

				fi

				if [[ $(echo -n ${Modalities} | grep "A") ]] ; then
					log_Msg "RegHemi - Modalities contains A"

					${Caret7_Command} -metric-resample ${DownSampleFolder}/${Subject}.${Hemisphere}.BiasField_${InRegName}.${LowResMesh}k_fs_LR.func.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${InRegName}.native.surf.gii ADAP_BARY_AREA ${NativeFolder}/${Subject}.${Hemisphere}.BiasField_${InRegName}.native.func.gii -area-surfs ${DownSampleFolder}/${Subject}.${Hemisphere}.midthickness.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.midthickness.native.surf.gii -current-roi ${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii -valid-roi-out ${NativeFolder}/${Subject}.${Hemisphere}.${InRegName}_roi.native.shape.gii

				fi

				if [[ $(echo -n ${Modalities} | grep "T") ]] ; then
					log_Msg "RegHemi - Modalities contains T"

					${Caret7_Command} -metric-resample ${DownSampleFolder}/${Subject}.${Hemisphere}.individual_Topography_${InRegName}.${LowResMesh}k_fs_LR.func.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${InRegName}.native.surf.gii ADAP_BARY_AREA ${NativeFolder}/${Subject}.${Hemisphere}.individual_Topography_${InRegName}.native.func.gii -area-surfs ${DownSampleFolder}/${Subject}.${Hemisphere}.midthickness.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.midthickness.native.surf.gii -current-roi ${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii -valid-roi-out ${NativeFolder}/${Subject}.${Hemisphere}.${InRegName}_roi.native.shape.gii

					${Caret7_Command} -metric-resample ${DownSampleFolder}/${Subject}.${Hemisphere}.individual_Topography_weights.${LowResMesh}k_fs_LR.func.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${InRegName}.native.surf.gii ADAP_BARY_AREA ${NativeFolder}/${Subject}.${Hemisphere}.individual_Topography_weights.native.func.gii -area-surfs ${DownSampleFolder}/${Subject}.${Hemisphere}.midthickness.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.midthickness.native.surf.gii -current-roi ${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii -valid-roi-out ${NativeFolder}/${Subject}.${Hemisphere}.${InRegName}_roi.native.shape.gii -largest

					${Caret7_Command} -metric-resample ${DownSampleFolder}/${Subject}.${Hemisphere}.atlas_Topography.${LowResMesh}k_fs_LR.func.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${InRegName}.native.surf.gii ADAP_BARY_AREA ${NativeFolder}/${Subject}.${Hemisphere}.atlas_Topography.native.func.gii -area-surfs ${DownSampleFolder}/${Subject}.${Hemisphere}.midthickness.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.midthickness.native.surf.gii -current-roi ${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii -valid-roi-out ${NativeFolder}/${Subject}.${Hemisphere}.${InRegName}_roi.native.shape.gii

				fi

				MedialWallWeight="1"
				${Caret7_Command} -metric-math "((var - 1) * -1) * ${MedialWallWeight}" ${NativeFolder}/${Subject}.${Hemisphere}.${InRegName}_roi_inv.native.shape.gii -var var ${NativeFolder}/${Subject}.${Hemisphere}.${InRegName}_roi.native.shape.gii
				${Caret7_Command} -metric-math "((var - 1) * -1) * ${MedialWallWeight}" ${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi_inv.${LowResMesh}k_fs_LR.shape.gii -var var ${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii

				NativeMetricMerge=""
				NativeWeightsMerge=""
				AtlasMetricMerge=""
				AtlasWeightsMerge=""
				n=1
				for Modality in $(echo ${Modalities} | sed 's/\(.\)/\1 /g') ; do
					log_Msg "RegHemi - n: ${n}"
					if [ ${Modality} = "C" ] ; then
						log_Msg "RegHemi - Modality: ${Modality}"
						${Caret7_Command} -metric-math "Var * ROI" ${DownSampleFolder}/${Subject}.${Hemisphere}.norm_atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.func.gii -var Var ${DownSampleFolder}/${Subject}.${Hemisphere}.atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.func.gii -var ROI ${DownSampleFolder}/${Subject}.${Hemisphere}.individual_RSNs_d${ICAdim}_weights.${LowResMesh}k_fs_LR.func.gii
						SDEVs=$(${Caret7_Command} -metric-stats ${DownSampleFolder}/${Subject}.${Hemisphere}.norm_atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.func.gii -reduce STDEV)
						SDEVs=$(echo ${SDEVs} | sed 's/ / + /g' | bc -l)
						MeanSDEV=$(echo "${SDEVs} / ${NumValidRSNs}" | bc -l)
						${Caret7_Command} -metric-math "Var / ${MeanSDEV}" ${DownSampleFolder}/${Subject}.${Hemisphere}.norm_atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.func.gii -var Var ${DownSampleFolder}/${Subject}.${Hemisphere}.atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.func.gii
						${Caret7_Command} -metric-math "Var / ${MeanSDEV}" ${NativeFolder}/${Subject}.${Hemisphere}.norm_individual_RSNs_d${ICAdim}_${InRegName}.native.func.gii -var Var ${NativeFolder}/${Subject}.${Hemisphere}.individual_RSNs_d${ICAdim}_${InRegName}.native.func.gii
						NativeMetricMerge=$(echo "${NativeMetricMerge} -metric ${NativeFolder}/${Subject}.${Hemisphere}.norm_individual_RSNs_d${ICAdim}_${InRegName}.native.func.gii")
						NativeWeightsMerge=$(echo "${NativeWeightsMerge} -metric ${NativeFolder}/${Subject}.${Hemisphere}.individual_RSNs_d${ICAdim}_weights.native.func.gii")
						AtlasMetricMerge=$(echo "${AtlasMetricMerge} -metric ${DownSampleFolder}/${Subject}.${Hemisphere}.norm_atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.func.gii")
						AtlasWeightsMerge=$(echo "${AtlasWeightsMerge} -metric ${DownSampleFolder}/${Subject}.${Hemisphere}.individual_RSNs_d${ICAdim}_weights.${LowResMesh}k_fs_LR.func.gii")
					elif [ ${Modality} = "A" ] ; then
						log_Msg "RegHemi - Modality: ${Modality}"
						###Renormalize individual map?
						${Caret7_Command} -metric-math "Var * ROI" ${DownSampleFolder}/${Subject}.${Hemisphere}.norm_MyelinMap_BC.${LowResMesh}k_fs_LR.func.gii -var Var ${DownSampleFolder}/${Subject}.${Hemisphere}.atlas_MyelinMap_BC.${LowResMesh}k_fs_LR.func.gii -var ROI ${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii
						SDEVs=$(${Caret7_Command} -metric-stats ${DownSampleFolder}/${Subject}.${Hemisphere}.norm_MyelinMap_BC.${LowResMesh}k_fs_LR.func.gii -reduce STDEV)
						SDEVs=$(echo ${SDEVs} | sed 's/ / + /g' | bc -l)
						MeanSDEV=$(echo "${SDEVs} / 1" | bc -l)
						${Caret7_Command} -metric-math "Var / ${MeanSDEV}" ${DownSampleFolder}/${Subject}.${Hemisphere}.norm_atlas_MyelinMap_BC.${LowResMesh}k_fs_LR.func.gii -var Var ${DownSampleFolder}/${Subject}.${Hemisphere}.atlas_MyelinMap_BC.${LowResMesh}k_fs_LR.func.gii
						${Caret7_Command} -metric-math "(Var - Bias) / ${MeanSDEV}" ${NativeFolder}/${Subject}.${Hemisphere}.norm_MyelinMap_BC_${InRegName}.native.func.gii -var Var ${NativeFolder}/${Subject}.${Hemisphere}.MyelinMap.native.func.gii -var Bias ${NativeFolder}/${Subject}.${Hemisphere}.BiasField_${InRegName}.native.func.gii
						NativeMetricMerge=$(echo "${NativeMetricMerge} -metric ${NativeFolder}/${Subject}.${Hemisphere}.norm_MyelinMap_BC_${InRegName}.native.func.gii")
						NativeWeightsMerge=$(echo "${NativeWeightsMerge} -metric ${NativeFolder}/${Subject}.${Hemisphere}.${InRegName}_roi.native.shape.gii")
						AtlasMetricMerge=$(echo "${AtlasMetricMerge} -metric ${DownSampleFolder}/${Subject}.${Hemisphere}.norm_atlas_MyelinMap_BC.${LowResMesh}k_fs_LR.func.gii")
						AtlasWeightsMerge=$(echo "${AtlasWeightsMerge} -metric ${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii")
					elif [ ${Modality} = "T" ] ; then
						log_Msg "RegHemi - Modality: ${Modality}"
						${Caret7_Command} -metric-math "Var * ROI" ${DownSampleFolder}/${Subject}.${Hemisphere}.norm_atlas_Topography.${LowResMesh}k_fs_LR.func.gii -var Var ${DownSampleFolder}/${Subject}.${Hemisphere}.atlas_Topography.${LowResMesh}k_fs_LR.func.gii -var ROI ${DownSampleFolder}/${Subject}.${Hemisphere}.individual_Topography_weights.${LowResMesh}k_fs_LR.func.gii
						SDEVs=$(${Caret7_Command} -metric-stats ${DownSampleFolder}/${Subject}.${Hemisphere}.norm_atlas_Topography.${LowResMesh}k_fs_LR.func.gii -reduce STDEV)
						SDEVs=$(echo ${SDEVs} | sed 's/ / + /g' | bc -l)
						MeanSDEV=$(echo "${SDEVs} / 1" | bc -l)
						${Caret7_Command} -metric-math "Var / ${MeanSDEV}" ${DownSampleFolder}/${Subject}.${Hemisphere}.norm_atlas_Topography.${LowResMesh}k_fs_LR.func.gii -var Var ${DownSampleFolder}/${Subject}.${Hemisphere}.atlas_Topography.${LowResMesh}k_fs_LR.func.gii
						${Caret7_Command} -metric-math "Var / ${MeanSDEV}" ${NativeFolder}/${Subject}.${Hemisphere}.norm_individual_Topography_${InRegName}.native.func.gii -var Var ${NativeFolder}/${Subject}.${Hemisphere}.individual_Topography_${InRegName}.native.func.gii
						NativeMetricMerge=$(echo "${NativeMetricMerge} -metric ${NativeFolder}/${Subject}.${Hemisphere}.norm_individual_Topography_${InRegName}.native.func.gii")
						NativeWeightsMerge=$(echo "${NativeWeightsMerge} -metric ${NativeFolder}/${Subject}.${Hemisphere}.individual_Topography_weights.native.func.gii")
						AtlasMetricMerge=$(echo "${AtlasMetricMerge} -metric ${DownSampleFolder}/${Subject}.${Hemisphere}.norm_atlas_Topography.${LowResMesh}k_fs_LR.func.gii")
						AtlasWeightsMerge=$(echo "${AtlasWeightsMerge} -metric ${DownSampleFolder}/${Subject}.${Hemisphere}.individual_Topography_weights.${LowResMesh}k_fs_LR.func.gii")
					fi
					if [ ${n} -eq "1" ] ; then
						NormSDEV=${MeanSDEV}
					fi
					n=$(( n+1 ))
				done

				log_Debug_Msg "RegHemi 1"
				${Caret7_Command} -metric-merge ${NativeFolder}/${Subject}.${Hemisphere}.Modalities_${i}_${InRegName}.native.func.gii ${NativeMetricMerge} -metric ${NativeFolder}/${Subject}.${Hemisphere}.${InRegName}_roi_inv.native.shape.gii
				${Caret7_Command} -metric-merge ${NativeFolder}/${Subject}.${Hemisphere}.Modalities_${i}_weights.native.func.gii ${NativeWeightsMerge} -metric ${NativeFolder}/${Subject}.${Hemisphere}.${InRegName}_roi_inv.native.shape.gii
				${Caret7_Command} -metric-merge ${DownSampleFolder}/${Subject}.${Hemisphere}.Modalities_${i}.${LowResMesh}k_fs_LR.func.gii ${AtlasMetricMerge} -metric ${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi_inv.${LowResMesh}k_fs_LR.shape.gii
				${Caret7_Command} -metric-merge ${DownSampleFolder}/${Subject}.${Hemisphere}.Modalities_${i}_weights.${LowResMesh}k_fs_LR.func.gii ${AtlasWeightsMerge} -metric ${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi_inv.${LowResMesh}k_fs_LR.shape.gii

				log_Debug_Msg "RegHemi 2"
				${Caret7_Command} -metric-math "Modalities * Weights * ${NormSDEV}" ${NativeFolder}/${Subject}.${Hemisphere}.Modalities_${i}_${InRegName}.native.func.gii -var Modalities ${NativeFolder}/${Subject}.${Hemisphere}.Modalities_${i}_${InRegName}.native.func.gii -var Weights ${NativeFolder}/${Subject}.${Hemisphere}.Modalities_${i}_weights.native.func.gii
				${Caret7_Command} -metric-math "Modalities * Weights * ${NormSDEV}" ${DownSampleFolder}/${Subject}.${Hemisphere}.Modalities_${i}.${LowResMesh}k_fs_LR.func.gii -var Modalities ${DownSampleFolder}/${Subject}.${Hemisphere}.Modalities_${i}.${LowResMesh}k_fs_LR.func.gii -var Weights ${DownSampleFolder}/${Subject}.${Hemisphere}.Modalities_${i}_weights.${LowResMesh}k_fs_LR.func.gii

				MEANs=$(${Caret7_Command} -metric-stats ${DownSampleFolder}/${Subject}.${Hemisphere}.Modalities_${i}_weights.${LowResMesh}k_fs_LR.func.gii -reduce MEAN)
				Native=""
				NativeWeights=""
				Atlas=""
				AtlasWeights=""
				j=1
				for MEAN in ${MEANs} ; do
					log_Debug_Msg "RegHemi j: ${j}"
					if [ ! ${MEAN} = 0 ] ; then
						Native=$(echo "${Native} -metric ${NativeFolder}/${Subject}.${Hemisphere}.Modalities_${i}_${InRegName}.native.func.gii -column ${j}")
						NativeWeights=$(echo "${NativeWeights} -metric ${NativeFolder}/${Subject}.${Hemisphere}.Modalities_${i}_weights.native.func.gii -column ${j}")
						Atlas=$(echo "${Atlas} -metric ${DownSampleFolder}/${Subject}.${Hemisphere}.Modalities_${i}.${LowResMesh}k_fs_LR.func.gii -column ${j}")
						AtlasWeights=$(echo "${AtlasWeights} -metric ${DownSampleFolder}/${Subject}.${Hemisphere}.Modalities_${i}_weights.${LowResMesh}k_fs_LR.func.gii -column ${j}")
					fi
					j=$(( j+1 ))
				done

				log_Debug_Msg "RegHemi 3"
				$Caret7_Command -metric-merge ${NativeFolder}/${Subject}.${Hemisphere}.Modalities_${i}_${InRegName}.native.func.gii ${Native}
				$Caret7_Command -metric-merge ${NativeFolder}/${Subject}.${Hemisphere}.Modalities_${i}_weights.native.func.gii ${NativeWeights}
				$Caret7_Command -metric-merge ${DownSampleFolder}/${Subject}.${Hemisphere}.Modalities_${i}.${LowResMesh}k_fs_LR.func.gii ${Atlas}
				$Caret7_Command -metric-merge ${DownSampleFolder}/${Subject}.${Hemisphere}.Modalities_${i}_weights.${LowResMesh}k_fs_LR.func.gii ${AtlasWeights}

				DIR=$(pwd)
				cd ${NativeFolder}/${RegName}

				log_Debug_Msg "RegConf: ${RegConf}"
				log_Debug_Msg "i: ${i}"

				log_File_Must_Exist "${RegConf}_${i}"
				cp ${RegConf}_${i} ${NativeFolder}/${RegName}/conf.${Hemisphere}
				log_File_Must_Exist "${NativeFolder}/${RegName}/conf.${Hemisphere}"

				if [ ! ${RegConfVars} = "NONE" ] ; then
					log_Debug_Msg "RegConfVars not equal to NONE"
					log_Debug_Msg "RegConfVars: ${RegConfVars}"
					RegConfVars=$(echo ${RegConfVars} | sed 's/,/ /g')

					log_Debug_Msg "RegConfVars: ${RegConfVars}"
					log_Debug_Msg "Before substitution"
					log_Debug_Cat ${NativeFolder}/${RegName}/conf.${Hemisphere}

					for RegConfVar in ${RegConfVars} ; do
						mv -f ${NativeFolder}/${RegName}/conf.${Hemisphere} ${NativeFolder}/${RegName}/confbak.${Hemisphere}
						STRING=$(echo ${RegConfVar} | cut -d "=" -f 1)
						Var=$(echo ${RegConfVar} | cut -d "=" -f 2)
						cat ${NativeFolder}/${RegName}/confbak.${Hemisphere} | sed s/${STRING}/${Var}/g > ${NativeFolder}/${RegName}/conf.${Hemisphere}
					done

					log_Debug_Msg "After substitution"
					log_Debug_Cat ${NativeFolder}/${RegName}/conf.${Hemisphere}

					rm ${NativeFolder}/${RegName}/confbak.${Hemisphere}
					RegConfVars=$(echo ${RegConfVars} | sed 's/ /,/g')
				fi

				log_Debug_Msg "RegHemi 4"

				msm_configuration_file="${NativeFolder}/${RegName}/conf.${Hemisphere}"
				log_File_Must_Exist "${msm_configuration_file}"

				${MSMBINDIR}/msm \
							--conf=${msm_configuration_file} \
							--inmesh=${NativeFolder}/${Subject}.${Hemisphere}.sphere.rot.native.surf.gii \
							--trans=${NativeFolder}/${Subject}.${Hemisphere}.sphere.${InPCARegName}.native.surf.gii \
							--refmesh=${DownSampleFolder}/${Subject}.${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii \
							--indata=${NativeFolder}/${Subject}.${Hemisphere}.Modalities_${i}_${InRegName}.native.func.gii \
							--inweight=${NativeFolder}/${Subject}.${Hemisphere}.Modalities_${i}_weights.native.func.gii \
							--refdata=${DownSampleFolder}/${Subject}.${Hemisphere}.Modalities_${i}.${LowResMesh}k_fs_LR.func.gii \
							--refweight=${DownSampleFolder}/${Subject}.${Hemisphere}.Modalities_${i}_weights.${LowResMesh}k_fs_LR.func.gii \
							--out=${NativeFolder}/${RegName}/${Hemisphere}. \
							--verbose \
							--debug \
							2>&1
				MSMOut=$?
				log_Debug_Msg "MSMOut: ${MSMOut}"

				cd $DIR

				log_File_Must_Exist "${NativeFolder}/${RegName}/${Hemisphere}.sphere.reg.surf.gii"
				cp ${NativeFolder}/${RegName}/${Hemisphere}.sphere.reg.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii
				log_File_Must_Exist "${NativeFolder}/${Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii"

				${Caret7_Command} -set-structure ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii ${Structure}

			} # end of function RegHemi

			for Hemisphere in L R ; do
				log_Msg "About to call RegHemi with Hemisphere: ${Hemisphere}"
				# Starting the jobs for the two hemispheres in the background (&) and using
				# wait for them to finish makes debugging somewhat difficult.
				#
				# RegHemi ${Hemisphere} &
				RegHemi ${Hemisphere}
				log_Msg "Called RegHemi ${Hemisphere}"
			done

			# Starting jobs in the background and waiting on them makes
			# debugging somewhat difficult.
			#
			#wait

			for Hemisphere in L R ; do
				if [ $Hemisphere = "L" ] ; then
					Structure="CORTEX_LEFT"
				elif [ $Hemisphere = "R" ] ; then
					Structure="CORTEX_RIGHT"
				fi
				log_Msg "Hemisphere: ${Hemisphere}"
				log_Msg "Structure: ${Structure}"

				# Make MSM Registration Areal Distortion Maps
				log_Msg "Make MSM Registration Areal Distortion Maps"
				${Caret7_Command} -surface-vertex-areas ${NativeFolder}/${Subject}.${Hemisphere}.sphere.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.native.shape.gii

				in_surface="${NativeFolder}/${Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii"
				log_Msg "in_surface: ${in_surface}"
				log_File_Must_Exist "${in_surface}"

				out_metric="${NativeFolder}/${Subject}.${Hemisphere}.sphere.${RegName}.native.shape.gii"
				log_Msg "out_metric: ${out_metric}"

				${Caret7_Command} -surface-vertex-areas ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${RegName}.native.shape.gii
				${Caret7_Command} -metric-math "ln(spherereg / sphere) / ln(2)" ${NativeFolder}/${Subject}.${Hemisphere}.ArealDistortion_${RegName}.native.shape.gii -var sphere ${NativeFolder}/${Subject}.${Hemisphere}.sphere.native.shape.gii -var spherereg ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${RegName}.native.shape.gii
				rm ${NativeFolder}/${Subject}.${Hemisphere}.sphere.native.shape.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${RegName}.native.shape.gii

				${Caret7_Command} -surface-sphere-project-unproject ${DownSampleFolder}/${Subject}.${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${InPCARegString}.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.sphere.${OutPCARegString}${RegName}.${LowResMesh}k_fs_LR.surf.gii

				${Caret7_Command} -surface-resample ${NativeT1wFolder}/${Subject}.${Hemisphere}.midthickness.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii BARYCENTRIC ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_${RegName}.${LowResMesh}k_fs_LR.surf.gii
			done

			${Caret7_Command} -cifti-create-dense-timeseries ${NativeFolder}/${Subject}.ArealDistortion_${RegName}.native.dtseries.nii -left-metric ${NativeFolder}/${Subject}.L.ArealDistortion_${RegName}.native.shape.gii -roi-left ${NativeFolder}/${Subject}.L.atlasroi.native.shape.gii -right-metric ${NativeFolder}/${Subject}.R.ArealDistortion_${RegName}.native.shape.gii -roi-right ${NativeFolder}/${Subject}.R.atlasroi.native.shape.gii
			${Caret7_Command} -cifti-convert-to-scalar ${NativeFolder}/${Subject}.ArealDistortion_${RegName}.native.dtseries.nii ROW ${NativeFolder}/${Subject}.ArealDistortion_${RegName}.native.dscalar.nii
			${Caret7_Command} -set-map-name ${NativeFolder}/${Subject}.ArealDistortion_${RegName}.native.dscalar.nii 1 ${Subject}_ArealDistortion_${RegName}
			${Caret7_Command} -cifti-palette ${NativeFolder}/${Subject}.ArealDistortion_${RegName}.native.dscalar.nii MODE_USER_SCALE ${NativeFolder}/${Subject}.ArealDistortion_${RegName}.native.dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false
			rm ${NativeFolder}/${Subject}.ArealDistortion_${RegName}.native.dtseries.nii

			${Caret7_Command} -cifti-resample ${NativeFolder}/${Subject}.ArealDistortion_${RegName}.native.dscalar.nii COLUMN ${DownSampleFolder}/${Subject}.ArealDistortion_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${Subject}.ArealDistortion_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 30 -left-spheres ${NativeFolder}/${Subject}.L.sphere.${RegName}.native.surf.gii ${DownSampleFolder}/${Subject}.L.sphere.${LowResMesh}k_fs_LR.surf.gii -left-area-surfs ${NativeFolder}/${Subject}.L.midthickness.native.surf.gii ${DownSampleT1wFolder}/${Subject}.L.midthickness_${RegName}.${LowResMesh}k_fs_LR.surf.gii -right-spheres ${NativeFolder}/${Subject}.R.sphere.${RegName}.native.surf.gii ${DownSampleFolder}/${Subject}.R.sphere.${LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${NativeFolder}/${Subject}.R.midthickness.native.surf.gii ${DownSampleT1wFolder}/${Subject}.R.midthickness_${RegName}.${LowResMesh}k_fs_LR.surf.gii
			InRegName="${RegName}"
			SurfRegSTRING="_${RegName}"
			i=$(( i+1 ))

		done # while [ ${i} -le ${NumIterations} ]


		for Hemisphere in L R ; do
			if [ $Hemisphere = "L" ] ; then
				Structure="CORTEX_LEFT"
			elif [ $Hemisphere = "R" ] ; then
				Structure="CORTEX_RIGHT"
			fi
			log_Msg "Hemisphere: ${Hemisphere}"
			log_Msg "Structure: ${Structure}"

			# Make MSM Registration Areal Distortion Maps
			log_Msg "Make MSM Registration Areal Distortion Maps"
			${Caret7_Command} -surface-vertex-areas ${NativeFolder}/${Subject}.${Hemisphere}.sphere.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.native.shape.gii
			${Caret7_Command} -surface-vertex-areas ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${RegName}.native.shape.gii
			${Caret7_Command} -metric-math "ln(spherereg / sphere) / ln(2)" ${NativeFolder}/${Subject}.${Hemisphere}.ArealDistortion_${RegName}.native.shape.gii -var sphere ${NativeFolder}/${Subject}.${Hemisphere}.sphere.native.shape.gii -var spherereg ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${RegName}.native.shape.gii
			rm ${NativeFolder}/${Subject}.${Hemisphere}.sphere.native.shape.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${RegName}.native.shape.gii

			${Caret7_Command} -surface-distortion ${NativeFolder}/${Subject}.${Hemisphere}.sphere.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.EdgeDistortion_${RegName}.native.shape.gii -edge-method

			# Make MSM Registration Areal Distortion Maps
			log_Msg "Make MSM Registration Areal Distortion Maps"
			${Caret7_Command} -surface-vertex-areas ${NativeFolder}/${Subject}.${Hemisphere}.midthickness.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.midthickness.native.shape.gii
			${Caret7_Command} -surface-vertex-areas ${NativeFolder}/${Subject}.${Hemisphere}.sphere.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.native.shape.gii
			${Caret7_Command} -metric-math "ln(sphere / midthickness) / ln(2)" ${NativeFolder}/${Subject}.${Hemisphere}.SphericalDistortion.native.shape.gii -var midthickness ${NativeFolder}/${Subject}.${Hemisphere}.midthickness.native.shape.gii -var sphere ${NativeFolder}/${Subject}.${Hemisphere}.sphere.native.shape.gii
			rm ${NativeFolder}/${Subject}.${Hemisphere}.midthickness.native.shape.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.native.shape.gii

			${Caret7_Command} -surface-sphere-project-unproject ${DownSampleFolder}/${Subject}.${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${InPCARegString}.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.sphere.${OutPCARegString}${RegName}.${LowResMesh}k_fs_LR.surf.gii
		done # for Hemispher in L R

		${Caret7_Command} -cifti-create-dense-timeseries ${NativeFolder}/${Subject}.ArealDistortion_${RegName}.native.dtseries.nii -left-metric ${NativeFolder}/${Subject}.L.ArealDistortion_${RegName}.native.shape.gii -roi-left ${NativeFolder}/${Subject}.L.atlasroi.native.shape.gii -right-metric ${NativeFolder}/${Subject}.R.ArealDistortion_${RegName}.native.shape.gii -roi-right ${NativeFolder}/${Subject}.R.atlasroi.native.shape.gii
		${Caret7_Command} -cifti-convert-to-scalar ${NativeFolder}/${Subject}.ArealDistortion_${RegName}.native.dtseries.nii ROW ${NativeFolder}/${Subject}.ArealDistortion_${RegName}.native.dscalar.nii
		${Caret7_Command} -set-map-name ${NativeFolder}/${Subject}.ArealDistortion_${RegName}.native.dscalar.nii 1 ${Subject}_ArealDistortion_${RegName}
		${Caret7_Command} -cifti-palette ${NativeFolder}/${Subject}.ArealDistortion_${RegName}.native.dscalar.nii MODE_USER_SCALE ${NativeFolder}/${Subject}.ArealDistortion_${RegName}.native.dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false
		rm ${NativeFolder}/${Subject}.ArealDistortion_${RegName}.native.dtseries.nii

		${Caret7_Command} -cifti-create-dense-timeseries ${NativeFolder}/${Subject}.EdgeDistortion_${RegName}.native.dtseries.nii -left-metric ${NativeFolder}/${Subject}.L.EdgeDistortion_${RegName}.native.shape.gii -roi-left ${NativeFolder}/${Subject}.L.atlasroi.native.shape.gii -right-metric ${NativeFolder}/${Subject}.R.EdgeDistortion_${RegName}.native.shape.gii -roi-right ${NativeFolder}/${Subject}.R.atlasroi.native.shape.gii
		${Caret7_Command} -cifti-convert-to-scalar ${NativeFolder}/${Subject}.EdgeDistortion_${RegName}.native.dtseries.nii ROW ${NativeFolder}/${Subject}.EdgeDistortion_${RegName}.native.dscalar.nii
		${Caret7_Command} -set-map-name ${NativeFolder}/${Subject}.EdgeDistortion_${RegName}.native.dscalar.nii 1 ${Subject}_EdgeDistortion_${RegName}
		${Caret7_Command} -cifti-palette ${NativeFolder}/${Subject}.EdgeDistortion_${RegName}.native.dscalar.nii MODE_USER_SCALE ${NativeFolder}/${Subject}.EdgeDistortion_${RegName}.native.dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false
		rm ${NativeFolder}/${Subject}.EdgeDistortion_${RegName}.native.dtseries.nii

		${Caret7_Command} -cifti-create-dense-timeseries ${NativeFolder}/${Subject}.SphericalDistortion.native.dtseries.nii -left-metric ${NativeFolder}/${Subject}.L.SphericalDistortion.native.shape.gii -roi-left ${NativeFolder}/${Subject}.L.atlasroi.native.shape.gii -right-metric ${NativeFolder}/${Subject}.R.SphericalDistortion.native.shape.gii -roi-right ${NativeFolder}/${Subject}.R.atlasroi.native.shape.gii
		${Caret7_Command} -cifti-convert-to-scalar ${NativeFolder}/${Subject}.SphericalDistortion.native.dtseries.nii ROW ${NativeFolder}/${Subject}.SphericalDistortion.native.dscalar.nii
		${Caret7_Command} -set-map-name ${NativeFolder}/${Subject}.SphericalDistortion.native.dscalar.nii 1 ${Subject}_SphericalDistortion
		${Caret7_Command} -cifti-palette ${NativeFolder}/${Subject}.SphericalDistortion.native.dscalar.nii MODE_USER_SCALE ${NativeFolder}/${Subject}.SphericalDistortion.native.dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false
		rm ${NativeFolder}/${Subject}.SphericalDistortion.native.dtseries.nii

		${Caret7_Command} -cifti-resample ${NativeFolder}/${Subject}.MyelinMap.native.dscalar.nii COLUMN ${DownSampleFolder}/${Subject}.MyelinMap.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${Subject}.MyelinMap_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${NativeFolder}/${Subject}.L.sphere.${RegName}.native.surf.gii ${DownSampleFolder}/${Subject}.L.sphere.${LowResMesh}k_fs_LR.surf.gii -left-area-surfs ${NativeT1wFolder}/${Subject}.L.midthickness.native.surf.gii ${DownSampleT1wFolder}/${Subject}.L.midthickness_${RegName}.${LowResMesh}k_fs_LR.surf.gii -right-spheres ${NativeFolder}/${Subject}.R.sphere.${RegName}.native.surf.gii ${DownSampleFolder}/${Subject}.R.sphere.${LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${NativeT1wFolder}/${Subject}.R.midthickness.native.surf.gii ${DownSampleT1wFolder}/${Subject}.R.midthickness_${RegName}.${LowResMesh}k_fs_LR.surf.gii
		${Caret7_Command} -cifti-math "Individual - Reference" ${DownSampleFolder}/${Subject}.BiasField_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii -var Individual ${DownSampleFolder}/${Subject}.MyelinMap_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii -var Reference ${DownSampleFolder}/${Subject}.atlas_MyelinMap_BC.${LowResMesh}k_fs_LR.dscalar.nii
		${Caret7_Command} -cifti-smoothing ${DownSampleFolder}/${Subject}.BiasField_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii ${CorrectionSigma} 0 COLUMN ${DownSampleFolder}/${Subject}.BiasField_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii -left-surface ${DownSampleT1wFolder}/${Subject}.L.midthickness_${RegName}.${LowResMesh}k_fs_LR.surf.gii -right-surface ${DownSampleT1wFolder}/${Subject}.R.midthickness_${RegName}.${LowResMesh}k_fs_LR.surf.gii
		${Caret7_Command} -cifti-resample ${DownSampleFolder}/${Subject}.BiasField_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ${NativeFolder}/${Subject}.MyelinMap.native.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${NativeFolder}/${Subject}.BiasField_${RegName}.native.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${Subject}.L.sphere.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.L.sphere.${RegName}.native.surf.gii -left-area-surfs ${DownSampleT1wFolder}/${Subject}.L.midthickness_${RegName}.${LowResMesh}k_fs_LR.surf.gii ${NativeT1wFolder}/${Subject}.L.midthickness.native.surf.gii -right-spheres ${DownSampleFolder}/${Subject}.R.sphere.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.R.sphere.${RegName}.native.surf.gii -right-area-surfs ${DownSampleT1wFolder}/${Subject}.R.midthickness_${RegName}.${LowResMesh}k_fs_LR.surf.gii ${NativeT1wFolder}/${Subject}.R.midthickness.native.surf.gii
		${Caret7_Command} -cifti-math "Var - Bias" ${NativeFolder}/${Subject}.MyelinMap_BC_${RegName}.native.dscalar.nii -var Var ${NativeFolder}/${Subject}.MyelinMap.native.dscalar.nii -var Bias ${NativeFolder}/${Subject}.BiasField_${RegName}.native.dscalar.nii

		for Mesh in ${HighResMesh} ${LowResMesh} ; do
			if [ $Mesh = ${HighResMesh} ] ; then
				Folder=${AtlasFolder}
			elif [ $Mesh = ${LowResMesh} ] ; then
				Folder=${DownSampleFolder}
			fi
			for Map in ArealDistortion EdgeDistortion sulc SphericalDistortion MyelinMap_BC ; do
				if [[ ${Map} = "ArealDistortion" || ${Map} = "EdgeDistortion" || ${Map} = "MyelinMap_BC" ]] ; then
					NativeMap="${Map}_${RegName}"
				else
					NativeMap="${Map}"
				fi
				${Caret7_Command} -cifti-resample ${NativeFolder}/${Subject}.${NativeMap}.native.dscalar.nii COLUMN ${Folder}/${Subject}.MyelinMap_BC.${Mesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${Folder}/${Subject}.${Map}_${RegName}.${Mesh}k_fs_LR.dscalar.nii -surface-postdilate 30 -left-spheres ${NativeFolder}/${Subject}.L.sphere.${RegName}.native.surf.gii ${Folder}/${Subject}.L.sphere.${Mesh}k_fs_LR.surf.gii -left-area-surfs ${NativeFolder}/${Subject}.L.midthickness.native.surf.gii ${Folder}/${Subject}.L.midthickness.${Mesh}k_fs_LR.surf.gii -right-spheres ${NativeFolder}/${Subject}.R.sphere.${RegName}.native.surf.gii ${Folder}/${Subject}.R.sphere.${Mesh}k_fs_LR.surf.gii -right-area-surfs ${NativeFolder}/${Subject}.R.midthickness.native.surf.gii ${Folder}/${Subject}.R.midthickness.${Mesh}k_fs_LR.surf.gii
			done
		done

		if [ ${UseMIGP} = "YES" ] ; then
			inputdtseries="${ResultsFolder}/${OutputfMRIName}${fMRIProcSTRING}_PCA${PCARegString}.dtseries.nii"
		else
			inputdtseries="${ResultsFolder}/${OutputfMRIName}${fMRIProcSTRING}${PCARegString}.dtseries.nii"
		fi

		# Resample the atlas instead of the timeseries
		log_Msg "Resample the atlas instead of the timeseries"
		${Caret7_Command} -cifti-resample ${DownSampleFolder}/${Subject}.atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ${DownSampleFolder}/${Subject}.atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${Subject}.atlas_RSNs_d${ICAdim}_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${Subject}.L.sphere.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.sphere.${OutPCARegString}${RegName}.${LowResMesh}k_fs_LR.surf.gii -left-area-surfs ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii -right-spheres ${DownSampleFolder}/${Subject}.R.sphere.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.sphere.${OutPCARegString}${RegName}.${LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii

		inputweights="NONE"
		inputspatialmaps="${DownSampleFolder}/${Subject}.atlas_RSNs_d${ICAdim}_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii"
		outputspatialmaps="${DownSampleFolder}/${Subject}.individual_RSNs_d${ICAdim}_${RegName}.${LowResMesh}k_fs_LR" #No Ext
		outputweights="NONE"
		Params="${NativeFolder}/${RegName}/Params.txt"
		touch ${Params}
		if [[ $(echo -n ${Method} | grep "WR") ]] ; then
			Distortion="${normalized_midthickness_va_file}"
			echo ${Distortion} > ${Params}
			LeftSurface="${DownSampleT1wFolder}/${Subject}.L.midthickness_${RegName}.${LowResMesh}k_fs_LR.surf.gii"
			echo ${LeftSurface} >> ${Params}
			RightSurface="${DownSampleT1wFolder}/${Subject}.R.midthickness_${RegName}.${LowResMesh}k_fs_LR.surf.gii"
			echo ${RightSurface} >> ${Params}
			for LowICAdim in ${LowICAdims} ; do
				LowDim=$(echo ${RSNTargetFileOrig} | sed "s/REPLACEDIM/${LowICAdim}/g")
				echo ${LowDim} >> ${Params}
			done
		fi

		case ${MatlabRunMode} in
			0)
				# Use Compiled Matlab
				matlab_exe="${HCPPIPEDIR}"
				matlab_exe+="/MSMAll/scripts/Compiled_MSMregression/run_MSMregression.sh"

				matlab_compiler_runtime="${MATLAB_COMPILER_RUNTIME}"

				matlab_function_arguments="'${inputspatialmaps}'"
				matlab_function_arguments+=" '${inputdtseries}'"
				matlab_function_arguments+=" '${inputweights}'"
				matlab_function_arguments+=" '${outputspatialmaps}'"
				matlab_function_arguments+=" '${outputweights}'"
				matlab_function_arguments+=" '${Caret7_Command}'"
				matlab_function_arguments+=" '${Method}'"
				matlab_function_arguments+=" '${Params}'"
				matlab_function_arguments+=" '${VN}'"
				matlab_function_arguments+=" ${nTPsForSpectra}"
				matlab_function_arguments+=" '${BC}'"
   				matlab_function_arguments+=" '${VolParams}'"

				matlab_logging=">> ${StudyFolder}/${Subject}.MSMregression.matlab.1.log 2>&1"

				matlab_cmd="${matlab_exe} ${matlab_compiler_runtime} ${matlab_function_arguments} ${matlab_logging}"

				# Note: Simply using ${matlab_cmd} here instead of echo "${matlab_cmd}" | bash
				#       does NOT work. The output redirects that are part of the ${matlab_logging}
				#       value, get quoted by the run_*.sh script generated by the MATLAB compiler
				#       such that they get passed as parameters to the underlying executable.
				#       So ">>" gets passed as a parameter to the executable as does the
				#       log file name and the "2>&1" redirection. This causes the executable
				#       to die with a "too many parameters" error message.
				log_Msg "Run Matlab command: ${matlab_cmd}"
				echo "${matlab_cmd}" | bash
				log_Msg "Matlab command return code: $?"
				;;

			1)
				# Use interpreted MATLAB
				mPath="${HCPPIPEDIR}/MSMAll/scripts"

				matlab -nojvm -nodisplay -nosplash <<M_PROG
addpath '$mPath'; MSMregression('${inputspatialmaps}','${inputdtseries}','${inputweights}','${outputspatialmaps}','${outputweights}','${Caret7_Command}','${Method}','${Params}','${VN}',${nTPsForSpectra},'${BC}','${VolParams}');
M_PROG
				log_Msg "addpath '$mPath'; MSMregression('${inputspatialmaps}','${inputdtseries}','${inputweights}','${outputspatialmaps}','${outputweights}','${Caret7_Command}','${Method}','${Params}','${VN}',${nTPsForSpectra},'${BC}','${VolParams}');"
				;;

			*)
				log_Err_Abort "Unsupported MATLAB run mode value: ${MatlabRunMode}"
				;;
		esac

		rm ${Params} ${DownSampleFolder}/${Subject}.atlas_RSNs_d${ICAdim}_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii

		# Resample the individual maps so they are in the correct space
		log_Msg "Resample the individual maps so they are in the correct space"
		${Caret7_Command} -cifti-resample ${DownSampleFolder}/${Subject}.individual_RSNs_d${ICAdim}_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ${DownSampleFolder}/${Subject}.individual_RSNs_d${ICAdim}_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${Subject}.individual_RSNs_d${ICAdim}_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${Subject}.L.sphere.${OutPCARegString}${RegName}.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.sphere.${LowResMesh}k_fs_LR.surf.gii  -left-area-surfs ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii -right-spheres ${DownSampleFolder}/${Subject}.R.sphere.${OutPCARegString}${RegName}.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.sphere.${LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii


		# Resample the atlas instead of the timeseries
		log_Msg "Resample the atlas instead of the timeseries"
		${Caret7_Command} -cifti-resample ${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${Subject}.L.sphere.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.sphere.${OutPCARegString}${RegName}.${LowResMesh}k_fs_LR.surf.gii -left-area-surfs ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii -right-spheres ${DownSampleFolder}/${Subject}.R.sphere.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.sphere.${OutPCARegString}${RegName}.${LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii
		NumMaps=$(${Caret7_Command} -file-information ${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs.${LowResMesh}k_fs_LR.dscalar.nii -only-number-of-maps)
		TopographicWeights=${NativeFolder}/${RegName}/TopographicWeights.txt
		n=1
		while [ ${n} -le ${NumMaps} ] ; do
			echo -n "${n} " >> ${TopographicWeights}
			n=$(( n+1 ))
		done
		inputweights="NONE"
		inputspatialmaps="${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii"
		outputspatialmaps="${DownSampleFolder}/${Subject}.individual_Topography_${RegName}.${LowResMesh}k_fs_LR" #No Ext
		outputweights="NONE"
		Params="${NativeFolder}/${RegName}/Params.txt"
		touch ${Params}
		if [[ $(echo -n ${Method} | grep "WR") ]] ; then
			Distortion="${normalized_midthickness_va_file}"
			echo ${Distortion} > ${Params}
		fi

		case ${MatlabRunMode} in

			0)
				# Use Compiled Matlab
				matlab_exe="${HCPPIPEDIR}"
				matlab_exe+="/MSMAll/scripts/Compiled_MSMregression/run_MSMregression.sh"

				matlab_compiler_runtime="${MATLAB_COMPILER_RUNTIME}"

				matlab_function_arguments="'${inputspatialmaps}'"
				matlab_function_arguments+=" '${inputdtseries}'"
				matlab_function_arguments+=" '${inputweights}'"
				matlab_function_arguments+=" '${outputspatialmaps}'"
				matlab_function_arguments+=" '${outputweights}'"
				matlab_function_arguments+=" '${Caret7_Command}'"
				matlab_function_arguments+=" '${Method}'"
				matlab_function_arguments+=" '${Params}'"
				matlab_function_arguments+=" '${VN}'"
				matlab_function_arguments+=" ${nTPsForSpectra}"
				matlab_function_arguments+=" '${BC}'"
				matlab_function_arguments+=" '${VolParams}'"

				matlab_logging=">> ${StudyFolder}/${Subject}.MSMregression.matlab.2.log 2>&1"

				matlab_cmd="${matlab_exe} ${matlab_compiler_runtime} ${matlab_function_arguments} ${matlab_logging}"

				# Note: Simply using ${matlab_cmd} here instead of echo "${matlab_cmd}" | bash
				#       does NOT work. The output redirects that are part of the ${matlab_logging}
				#       value, get quoted by the run_*.sh script generated by the MATLAB compiler
				#       such that they get passed as parameters to the underlying executable.
				#       So ">>" gets passed as a parameter to the executable as does the
				#       log file name and the "2>&1" redirection. This causes the executable
				#       to die with a "too many parameters" error message.
				log_Msg "Run Matlab command: ${matlab_cmd}"
				echo "${matlab_cmd}" | bash
				log_Msg "Matlab command return code: $?"
				;;

			1)
				# Use interpreted MATLAB
				mPath="${HCPPIPEDIR}/MSMAll/scripts"

				matlab -nojvm -nodisplay -nosplash <<M_PROG
addpath '$mPath'; MSMregression('${inputspatialmaps}','${inputdtseries}','${inputweights}','${outputspatialmaps}','${outputweights}','${Caret7_Command}','${Method}','${Params}','${VN}',${nTPsForSpectra},'${BC}','${VolParams}');
M_PROG
				log_Msg "addpath '$mPath'; MSMregression('${inputspatialmaps}','${inputdtseries}','${inputweights}','${outputspatialmaps}','${outputweights}','${Caret7_Command}','${Method}','${Params}','${VN}',${nTPsForSpectra},'${BC}','${VolParams}');"
				;;

			*)
				log_Err_Abort "Unsupported MATLAB run mode value: ${MatlabRunMode}"
				;;
		esac

		rm ${Params} ${TopographicWeights} ${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii

		# Resample the individual maps so they are in the correct space
		log_Msg "Resample the individual maps so they are in the correct space"
		${Caret7_Command} -cifti-resample ${DownSampleFolder}/${Subject}.individual_Topography_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ${DownSampleFolder}/${Subject}.individual_Topography_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${Subject}.individual_Topography_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${Subject}.L.sphere.${OutPCARegString}${RegName}.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.sphere.${LowResMesh}k_fs_LR.surf.gii -left-area-surfs ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii -right-spheres ${DownSampleFolder}/${Subject}.R.sphere.${OutPCARegString}${RegName}.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.sphere.${LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii

	fi

# ##rm ${IsRunning}

}

# ------------------------------------------------------------------------------
#  "Global" processing - everything above here should be in a function
# ------------------------------------------------------------------------------

set -e # If any commands exit with non-zero value, this script exits

# Verify that HCPPIPEDIR Environment variable is set
if [ -z "${HCPPIPEDIR}" ]; then
	script_name=$(basename "${0}")
	echo "${script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
	exit 1
fi

# Load function libraries
source "${HCPPIPEDIR}/global/scripts/log.shlib" # Logging related functions
log_Msg "HCPPIPEDIR: ${HCPPIPEDIR}"

# Verify that other needed environment variables are set
if [ -z "${CARET7DIR}" ]; then
	log_Err_Abort "CARET7DIR environment variable must be set"
fi
log_Msg "CARET7DIR: ${CARET7DIR}"

if [ -z "${MSMBINDIR}" ]; then
	log_Err_Abort "MSMBINDIR environment variable must be set"
fi
log_Msg "MSMBINDIR: ${MSMBINDIR}"

# Show tool versions
show_tool_versions

# Determine whether named or positional parameters are used
if [[ ${1} == --* ]]; then
	# Named parameters (e.g. --parameter-name=parameter-value) are used
	log_Msg "Using named parameters"
	
	# Get command line options
	get_options "$@"

	# Invoke main functionality using positional parameters
	#     ${1}               ${2}           ${3}               ${4}              ${5}                  ${6}                  ${7}                ${8}             ${9}               ${10}                    ${11}                     ${12}                   ${13}                    ${14}                       ${15}             ${16}         ${17}          ${18}         ${19}                   ${20}     ${21}        ${22}          ${23}              ${24}
	main "${p_StudyFolder}" "${p_Subject}" "${p_HighResMesh}" "${p_LowResMesh}" "${p_OutputfMRIName}" "${p_fMRIProcSTRING}" "${p_InPCARegName}" "${p_InRegName}" "${p_RegNameStem}" "${p_RSNTargetFileOrig}" "${p_RSNCostWeightsOrig}" "${p_MyelinTargetFile}" "${p_TopographyROIFile}" "${p_TopographyTargetFile}" "${p_Iterations}" "${p_Method}" "${p_UseMIGP}" "${p_ICAdim}" "${p_RegressionParams}" "${p_VN}" "${p_ReRun}" "${p_RegConf}" "${p_RegConfVars}" "${p_MatlabRunMode}"

else
	# Positional parameters are used
	log_Msg "Using positional parameters"
	main $@

fi
	
