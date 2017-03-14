#!/bin/bash

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

if [ -z "${CARET7DIR}" ]; then
	log_Err_Abort "CARET7DIR environment variable must be set"
fi
log_Msg "CARET7DIR: ${CARET7DIR}"

if [ -z "${MSMBINDIR}" ]; then
	log_Err_Abort "MSMBINDIR environment variable must be set"
fi
log_Msg "MSMBINDIR: ${MSMBINDIR}"

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
	unset g_StudyFolder
	unset g_Subject
	unset g_HighResMesh
	unset g_LowResMesh


	unset g_fmri_names_list      # ${fMRINames}



	
	unset g_output_fmri_name     # ${OutputfMRIName}
	unset g_fmri_proc_string     # ${fMRIProcSTRING}
	unset g_input_pca_registration_name # ${InPCARegName}
	unset g_input_registration_name     # ${InRegName}
	unset g_registration_name_stem      # ${RegNameStem}
	unset g_rsn_target_file             # ${RSNTargetFileOrig}
	unset g_rsn_cost_weights            # ${RSNCostWeightsOrig}
	unset g_myelin_target_file          # ${MyelinTargetFile}
	unset g_topography_roi_file         # ${TopographyROIFile}
	unset g_topography_target_file      # ${TopographyTargetFile}
	unset g_iterations                  # ${Iterations}
	unset g_method                      # ${Method}
	unset g_use_migp                    # ${UseMIGP}
	unset g_ica_dim                     # ${ICAdim}
	unset g_regression_params           # ${RegressionParams}
	unset g_vn                          # ${VN}
	unset g_rerun                       # ${ReRun}
	unset g_reg_conf                    # ${RegConf}
	unset g_reg_conf_vars               # ${RegConfVars}
	unset g_matlab_run_mode

	# set default values
	g_matlab_run_mode=0

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
				g_StudyFolder=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--study-folder=*)
				g_StudyFolder=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--subject=*)
				g_Subject=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--high-res-mesh=*)
				g_HighResMesh=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--low-res-mesh=*)
				g_LowResMesh=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--fmri-names-list=*)
				g_fmri_names_list=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--output-fmri-name=*)
				g_output_fmri_name=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--fmri-proc-string=*)
				g_fmri_proc_string=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--input-pca-registration-name=*)
				g_input_pca_registration_name=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--input-registration-name=*)
				g_input_registration_name=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--registration-name-stem=*)
				g_registration_name_stem=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--rsn-target-file=*)
				g_rsn_target_file=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--rsn-cost-weights=*)
				g_rsn_cost_weights=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--myelin-target-file=*)
				g_myelin_target_file=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--topography-roi-file=*)
				g_topography_roi_file=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--topography-target-file=*)
				g_topography_target_file=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--iterations=*)
				g_iterations=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--method=*)
				g_method=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--use-migp=*)
				g_use_migp=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--ica-dim=*)
				g_ica_dim=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--regression-params=*)
				g_regression_params=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--vn=*)
				g_vn=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--rerun=*)
				g_rerun=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--reg-conf=*)
				g_reg_conf=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--matlab-run-mode=*)
				g_matlab_run_mode=${argument#*=}
				index=$(( index + 1 ))
				;;
			--reg-conf-vars=*)
				# Note: since the value of this parameter contains equal signs ("="),
				# we have to handle grabbing the value slightly differently than
				# in the other cases.
				g_reg_conf_vars=${argument#--reg-conf-vars=}
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
		log_Err "Subject required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_Subject: ${g_Subject}"
	fi

	if [ -z "${g_HighResMesh}" ]; then
		log_Err "High Res Mesh required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_HighResMesh: ${g_HighResMesh}"
	fi

	if [ -z "${g_LowResMesh}" ]; then
		log_Err "Low Res Mesh required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_LowResMesh: ${g_LowResMesh}"
	fi

	if [ -z "${g_fmri_names_list}" ]; then
		log_Err "fmri_names_list required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_fmri_names_list: ${g_fmri_names_list}"
	fi

	if [ -z "${g_output_fmri_name}" ]; then
		log_Err "output_fmri_name required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_output_fmri_name: ${g_output_fmri_name}"
	fi

	if [ -z "${g_fmri_proc_string}" ]; then
		log_Err "fmri_proc_string required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_fmri_proc_string: ${g_fmri_proc_string}"
	fi

	if [ -z "${g_input_pca_registration_name}" ]; then
		log_Err "input_pca_registration_name required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_input_pca_registration_name: ${g_input_pca_registration_name}"
	fi

	if [ -z "${g_input_registration_name}" ]; then
		log_Err "input_registration_name required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_input_registration_name: ${g_input_registration_name}"
	fi

	if [ -z "${g_registration_name_stem}" ]; then
		log_Err "registration_name_stem required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_registration_name_stem: ${g_registration_name_stem}"
	fi

	if [ -z "${g_rsn_target_file}" ]; then
		log_Err "rsn_target_file required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_rsn_target_file: ${g_rsn_target_file}"
	fi

	if [ -z "${g_rsn_cost_weights}" ]; then
		log_Err "rsn_cost_weights required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_rsn_cost_weights: ${g_rsn_cost_weights}"
	fi

	if [ -z "${g_myelin_target_file}" ]; then
		log_Err "myelin_target_file required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_myelin_target_file: ${g_myelin_target_file}"
	fi

	if [ -z "${g_topography_roi_file}" ]; then
		log_Err "topography_roi_file required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_topography_roi_file: ${g_topography_roi_file}"
	fi

	if [ -z "${g_topography_target_file}" ]; then
		log_Err "topography_target_file required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_topography_target_file: ${g_topography_target_file}"
	fi

	if [ -z "${g_iterations}" ]; then
		log_Err "iterations required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_iterations: ${g_iterations}"
	fi

	if [ -z "${g_method}" ]; then
		log_Err "method required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_method: ${g_method}"
	fi

	if [ -z "${g_use_migp}" ]; then
		log_Err "use_migp required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_use_migp: ${g_use_migp}"
	fi

	if [ -z "${g_ica_dim}" ]; then
		log_Err "ica_dim required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_ica_dim: ${g_ica_dim}"
	fi

	if [ -z "${g_regression_params}" ]; then
		log_Err "regression_params required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_regression_params: ${g_regression_params}"
	fi

	if [ -z "${g_vn}" ]; then
		log_Err "vn required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_vn: ${g_vn}"
	fi

	if [ -z "${g_rerun}" ]; then
		log_Err "rerun required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_rerun: ${g_rerun}"
	fi

	if [ -z "${g_reg_conf}" ]; then
		log_Err "reg_conf required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_reg_conf: ${g_reg_conf}"
	fi

	if [ -z "${g_reg_conf_vars}" ]; then
		log_Err "reg_conf_vars required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_reg_conf_vars: ${g_reg_conf_vars}"
	fi

	if [ -z "${g_matlab_run_mode}" ]; then
		log_Err "MATLAB run mode value (--matlab-run-mode=) required"
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
#  Show/Document Tool Versions
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
	# Get command line options
	get_options "$@"

	# show the versions of tools used
	show_tool_versions

	# Naming Conventions
	Caret7_Command=${CARET7DIR}/wb_command
	log_Msg "Caret7_Command: ${Caret7_Command}"


	fMRINames="${g_fmri_names_list}"
	log_Msg "fMRINames: ${fMRINames}"

	OutputfMRIName="${g_output_fmri_name}"
	log_Msg "OutputfMRIName: ${OutputfMRIName}"

	fMRIProcSTRING="${g_fmri_proc_string}"
	log_Msg "fMRIProcSTRING: ${fMRIProcSTRING}"

	InPCARegName="${g_input_pca_registration_name}"
	log_Msg "InPCARegName: ${InPCARegName}"

	InRegName="${g_input_registration_name}"
	log_Msg "InRegName: ${InRegName}"

	RegNameStem="${g_registration_name_stem}"
	log_Msg "RegNameStem: ${RegNameStem}"

	RSNTargetFileOrig="${g_rsn_target_file}"
	log_Msg "RSNTargetFileOrig: ${RSNTargetFileOrig}"

	RSNCostWeightsOrig="${g_rsn_cost_weights}"
	log_Msg "RSNCostWeightsOrig: ${RSNCostWeightsOrig}"

	MyelinTargetFile="${g_myelin_target_file}"
	log_Msg "MyelinTargetFile: ${MyelinTargetFile}"

	TopographyROIFile="${g_topography_roi_file}"
	log_Msg "TopographyROIFile: ${TopographyROIFile}"

	TopographyTargetFile="${g_topography_target_file}"
	log_Msg "TopographyTargetFile: ${TopographyTargetFile}"

	Iterations="${g_iterations}"
	log_Msg "Iterations: ${Iterations}"

	Method="${g_method}"
	log_Msg "Method: ${Method}"

	UseMIGP="${g_use_migp}"
	log_Msg "UseMIGP: ${UseMIGP}"

	ICAdim="${g_ica_dim}"
	log_Msg "ICAdim: ${ICAdim}"

	RegressionParams="${g_regression_params}"
	log_Msg "RegressionParams: ${RegressionParams}"

	VN="${g_vn}"
	log_Msg "VN: ${VN}"

	ReRun="${g_rerun}"
	log_Msg "ReRun: ${ReRun}"

	RegConf="${g_reg_conf}"
	log_Msg "RegConf: ${RegConf}"

	RegConfVars="${g_reg_conf_vars}"
	log_Msg "RegConfVars: ${RegConfVars}"

	AtlasFolder="${g_StudyFolder}/${g_Subject}/MNINonLinear"
	log_Msg "AtlasFolder: ${AtlasFolder}"

	DownSampleFolder="${AtlasFolder}/fsaverage_LR${g_LowResMesh}k"
	log_Msg "DownSampleFolder: ${DownSampleFolder}"

	NativeFolder="${AtlasFolder}/Native"
	log_Msg "NativeFolder: ${NativeFolder}"

	ResultsFolder="${AtlasFolder}/Results/${OutputfMRIName}"
	log_Msg "ResultsFolder: ${ResultsFolder}"

	T1wFolder="${g_StudyFolder}/${g_Subject}/T1w"
	log_Msg "T1wFolder: ${T1wFolder}"

	DownSampleT1wFolder="${T1wFolder}/fsaverage_LR${g_LowResMesh}k"
	log_Msg "DownSampleT1wFolder: ${DownSampleT1wFolder}"

	NativeT1wFolder="${T1wFolder}/Native"
	log_Msg "NativeT1wFolder: ${NativeT1wFolder}"

	if [[ $(echo -n "${Method}" | grep "WR") ]] ; then
		LowICAdims=$(echo "${RegressionParams}" | sed 's/_/ /g')
	fi
	log_Msg "LowICAdims: ${LowICAdims}"

	Iterations=$(echo "${Iterations}" | sed 's/_/ /g')
	log_Msg "Iterations: ${Iterations}"

	NumIterations=$(echo "${Iterations}" | wc -w)
	log_Msg "NumIterations: ${NumIterations}"

	CorrectionSigma=$(echo "sqrt ( 200 )" | bc -l)
	log_Msg "CorrectionSigma: ${CorrectionSigma}"

	BC="NO"
	log_Msg "BC: ${BC}"

	nTPsForSpectra="0" #Set to zero to not compute spectra
	log_Msg "nTPsForSpectra: ${nTPsForSpectra}"

	VolParams="NO" #Dont' output volume RSN maps
	log_Msg "VolParams: ${VolParams}"

	if [[ ! -e ${NativeFolder}/${g_Subject}.ArealDistortion_${RegNameStem}_${NumIterations}_d${ICAdim}_${Method}.native.dscalar.nii || ${ReRun} = "YES" ]] ; then

		##IsRunning="${NativeFolder}/${g_Subject}.IsRunning_${RegNameStem}_${NumIterations}_d${ICAdim}_${Method}.txt"
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

		cp --verbose "${RSNTargetFile}" "${DownSampleFolder}/${g_Subject}.atlas_RSNs_d${ICAdim}.${g_LowResMesh}k_fs_LR.dscalar.nii"
		cp --verbose "${MyelinTargetFile}" "${DownSampleFolder}/${g_Subject}.atlas_MyelinMap_BC.${g_LowResMesh}k_fs_LR.dscalar.nii"
		cp --verbose "${TopographyROIFile}" "${DownSampleFolder}/${g_Subject}.atlas_Topographic_ROIs.${g_LowResMesh}k_fs_LR.dscalar.nii"
		cp --verbose "${TopographyTargetFile}" "${DownSampleFolder}/${g_Subject}.atlas_Topography.${g_LowResMesh}k_fs_LR.dscalar.nii"

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

		for Hemisphere in L R ; do
			${Caret7_Command} -surface-vertex-areas ${DownSampleT1wFolder}/${g_Subject}.${Hemisphere}.midthickness.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleT1wFolder}/${g_Subject}.${Hemisphere}.midthickness_va.${g_LowResMesh}k_fs_LR.shape.gii
		done
		${Caret7_Command} -cifti-create-dense-scalar ${DownSampleT1wFolder}/${g_Subject}.${Hemisphere}.midthickness_va.${g_LowResMesh}k_fs_LR.dscalar.nii -left-metric ${DownSampleT1wFolder}/${g_Subject}.L.midthickness_va.${g_LowResMesh}k_fs_LR.shape.gii -roi-left ${DownSampleFolder}/${g_Subject}.L.atlasroi.${g_LowResMesh}k_fs_LR.shape.gii -right-metric ${DownSampleT1wFolder}/${g_Subject}.R.midthickness_va.${g_LowResMesh}k_fs_LR.shape.gii -roi-right ${DownSampleFolder}/${g_Subject}.R.atlasroi.${g_LowResMesh}k_fs_LR.shape.gii
		VAMean=$(${Caret7_Command} -cifti-stats ${DownSampleT1wFolder}/${g_Subject}.${Hemisphere}.midthickness_va.${g_LowResMesh}k_fs_LR.dscalar.nii -reduce MEAN)
		log_Msg "VAMean: ${VAMean}"

		${Caret7_Command} -cifti-math "VA / ${VAMean}" ${DownSampleT1wFolder}/${g_Subject}.${Hemisphere}.midthickness_va_norm.${g_LowResMesh}k_fs_LR.dscalar.nii -var VA ${DownSampleT1wFolder}/${g_Subject}.${Hemisphere}.midthickness_va.${g_LowResMesh}k_fs_LR.dscalar.nii

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
					${Caret7_Command} -surface-sphere-project-unproject ${DownSampleFolder}/${g_Subject}.${Hemisphere}.sphere.${g_LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.${InPCARegString}.native.surf.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.${InRegName}.native.surf.gii ${DownSampleFolder}/${g_Subject}.${Hemisphere}.sphere.${OutPCARegString}${InRegName}.${g_LowResMesh}k_fs_LR.surf.gii
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
				${Caret7_Command} -cifti-resample ${DownSampleFolder}/${g_Subject}.atlas_RSNs_d${ICAdim}.${g_LowResMesh}k_fs_LR.dscalar.nii COLUMN ${DownSampleFolder}/${g_Subject}.atlas_RSNs_d${ICAdim}.${g_LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${g_Subject}.atlas_RSNs_d${ICAdim}_${InRegName}.${g_LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${g_Subject}.L.sphere.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.L.sphere.${OutPCARegString}${InRegName}.${g_LowResMesh}k_fs_LR.surf.gii -left-area-surfs ${DownSampleFolder}/${g_Subject}.L.midthickness.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.L.midthickness.${g_LowResMesh}k_fs_LR.surf.gii -right-spheres ${DownSampleFolder}/${g_Subject}.R.sphere.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.R.sphere.${OutPCARegString}${InRegName}.${g_LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${DownSampleFolder}/${g_Subject}.R.midthickness.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.R.midthickness.${g_LowResMesh}k_fs_LR.surf.gii

				NumValidRSNs=$(cat ${RSNCostWeights} | wc -w)
				inputweights="${RSNCostWeights}"
				inputspatialmaps="${DownSampleFolder}/${g_Subject}.atlas_RSNs_d${ICAdim}_${InRegName}.${g_LowResMesh}k_fs_LR.dscalar.nii"
				outputspatialmaps="${DownSampleFolder}/${g_Subject}.individual_RSNs_d${ICAdim}_${InRegName}.${g_LowResMesh}k_fs_LR" #No Ext
				outputweights="${DownSampleFolder}/${g_Subject}.individual_RSNs_d${ICAdim}_weights.${g_LowResMesh}k_fs_LR.dscalar.nii"
				Params="${NativeFolder}/${RegName}/Params.txt"
				touch ${Params}
				if [[ $(echo -n ${Method} | grep "WR") ]] ; then
					Distortion="${DownSampleT1wFolder}/${g_Subject}.${Hemisphere}.midthickness_va_norm.${g_LowResMesh}k_fs_LR.dscalar.nii"
					echo ${Distortion} > ${Params}
					LeftSurface="${DownSampleT1wFolder}/${g_Subject}.L.midthickness${SurfRegSTRING}.${g_LowResMesh}k_fs_LR.surf.gii"
					echo ${LeftSurface} >> ${Params}
					RightSurface="${DownSampleT1wFolder}/${g_Subject}.R.midthickness${SurfRegSTRING}.${g_LowResMesh}k_fs_LR.surf.gii"
					echo ${RightSurface} >> ${Params}
					for LowICAdim in ${LowICAdims} ; do
						LowDim=$(echo ${RSNTargetFileOrig} | sed "s/REPLACEDIM/${LowICAdim}/g")
						echo ${LowDim} >> ${Params}
					done
				fi

				case ${g_matlab_run_mode} in

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

						matlab_logging=">> ${g_StudyFolder}/${g_Subject}.MSMregression.matlab.C.Iteration${i}.log 2>&1"

						matlab_cmd="${matlab_exe} ${matlab_compiler_runtime} ${matlab_function_arguments} ${matlab_logging}"

						log_Msg "Run MATLAB command: ${matlab_cmd}"

						echo "${matlab_cmd}" | bash
						log_Msg "MATLAB command return code: $?"
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
						log_Err_Abort "Unsupported MATLAB run mode value: ${g_matlab_run_mode}"
						;;
				esac

				rm ${Params} ${DownSampleFolder}/${g_Subject}.atlas_RSNs_d${ICAdim}_${InRegName}.${g_LowResMesh}k_fs_LR.dscalar.nii

				# Resample the individual maps so they are in the correct space
				log_Msg "Resample the individual maps so they are in the correct space"
				${Caret7_Command} -cifti-resample ${DownSampleFolder}/${g_Subject}.individual_RSNs_d${ICAdim}_${InRegName}.${g_LowResMesh}k_fs_LR.dscalar.nii COLUMN ${DownSampleFolder}/${g_Subject}.individual_RSNs_d${ICAdim}_${InRegName}.${g_LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${g_Subject}.individual_RSNs_d${ICAdim}_${InRegName}.${g_LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${g_Subject}.L.sphere.${OutPCARegString}${InRegName}.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.L.sphere.${g_LowResMesh}k_fs_LR.surf.gii  -left-area-surfs ${DownSampleFolder}/${g_Subject}.L.midthickness.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.L.midthickness.${g_LowResMesh}k_fs_LR.surf.gii -right-spheres ${DownSampleFolder}/${g_Subject}.R.sphere.${OutPCARegString}${InRegName}.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.R.sphere.${g_LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${DownSampleFolder}/${g_Subject}.R.midthickness.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.R.midthickness.${g_LowResMesh}k_fs_LR.surf.gii

				${Caret7_Command} -cifti-separate-all ${DownSampleFolder}/${g_Subject}.individual_RSNs_d${ICAdim}_${InRegName}.${g_LowResMesh}k_fs_LR.dscalar.nii -left ${DownSampleFolder}/${g_Subject}.L.individual_RSNs_d${ICAdim}_${InRegName}.${g_LowResMesh}k_fs_LR.func.gii -right ${DownSampleFolder}/${g_Subject}.R.individual_RSNs_d${ICAdim}_${InRegName}.${g_LowResMesh}k_fs_LR.func.gii

				${Caret7_Command} -cifti-separate-all ${DownSampleFolder}/${g_Subject}.atlas_RSNs_d${ICAdim}.${g_LowResMesh}k_fs_LR.dscalar.nii -left ${DownSampleFolder}/${g_Subject}.L.atlas_RSNs_d${ICAdim}.${g_LowResMesh}k_fs_LR.func.gii -right ${DownSampleFolder}/${g_Subject}.R.atlas_RSNs_d${ICAdim}.${g_LowResMesh}k_fs_LR.func.gii

				${Caret7_Command} -cifti-separate-all ${DownSampleFolder}/${g_Subject}.individual_RSNs_d${ICAdim}_weights.${g_LowResMesh}k_fs_LR.dscalar.nii -left ${DownSampleFolder}/${g_Subject}.L.individual_RSNs_d${ICAdim}_weights.${g_LowResMesh}k_fs_LR.func.gii -right ${DownSampleFolder}/${g_Subject}.R.individual_RSNs_d${ICAdim}_weights.${g_LowResMesh}k_fs_LR.func.gii

			fi

			if [[ $(echo -n ${Modalities} | grep "A") ]] ; then
				log_Msg "Modalities includes A"
				${Caret7_Command} -cifti-resample ${NativeFolder}/${g_Subject}.MyelinMap.native.dscalar.nii COLUMN ${DownSampleFolder}/${g_Subject}.MyelinMap.${g_LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${g_Subject}.MyelinMap_${InRegName}.${g_LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${NativeFolder}/${g_Subject}.L.sphere.${InRegName}.native.surf.gii ${DownSampleFolder}/${g_Subject}.L.sphere.${g_LowResMesh}k_fs_LR.surf.gii -left-area-surfs ${NativeT1wFolder}/${g_Subject}.L.midthickness.native.surf.gii ${DownSampleFolder}/${g_Subject}.L.midthickness.${g_LowResMesh}k_fs_LR.surf.gii -right-spheres ${NativeFolder}/${g_Subject}.R.sphere.${InRegName}.native.surf.gii ${DownSampleFolder}/${g_Subject}.R.sphere.${g_LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${NativeT1wFolder}/${g_Subject}.R.midthickness.native.surf.gii ${DownSampleFolder}/${g_Subject}.R.midthickness.${g_LowResMesh}k_fs_LR.surf.gii
				${Caret7_Command} -cifti-math "Individual - Reference" ${DownSampleFolder}/${g_Subject}.BiasField_${InRegName}.${g_LowResMesh}k_fs_LR.dscalar.nii -var Individual ${DownSampleFolder}/${g_Subject}.MyelinMap_${InRegName}.${g_LowResMesh}k_fs_LR.dscalar.nii -var Reference ${DownSampleFolder}/${g_Subject}.atlas_MyelinMap_BC.${g_LowResMesh}k_fs_LR.dscalar.nii
				${Caret7_Command} -cifti-smoothing ${DownSampleFolder}/${g_Subject}.BiasField_${InRegName}.${g_LowResMesh}k_fs_LR.dscalar.nii ${CorrectionSigma} 0 COLUMN ${DownSampleFolder}/${g_Subject}.BiasField_${InRegName}.${g_LowResMesh}k_fs_LR.dscalar.nii -left-surface ${DownSampleFolder}/${g_Subject}.L.midthickness.${g_LowResMesh}k_fs_LR.surf.gii -right-surface ${DownSampleFolder}/${g_Subject}.R.midthickness.${g_LowResMesh}k_fs_LR.surf.gii
				${Caret7_Command} -cifti-separate-all ${DownSampleFolder}/${g_Subject}.BiasField_${InRegName}.${g_LowResMesh}k_fs_LR.dscalar.nii -left ${DownSampleFolder}/${g_Subject}.L.BiasField_${InRegName}.${g_LowResMesh}k_fs_LR.func.gii -right ${DownSampleFolder}/${g_Subject}.R.BiasField_${InRegName}.${g_LowResMesh}k_fs_LR.func.gii
				${Caret7_Command} -cifti-separate-all ${DownSampleFolder}/${g_Subject}.atlas_MyelinMap_BC.${g_LowResMesh}k_fs_LR.dscalar.nii -left ${DownSampleFolder}/${g_Subject}.L.atlas_MyelinMap_BC.${g_LowResMesh}k_fs_LR.func.gii -right ${DownSampleFolder}/${g_Subject}.R.atlas_MyelinMap_BC.${g_LowResMesh}k_fs_LR.func.gii
			fi

			if [[ $(echo -n ${Modalities} | grep "T") ]] ; then
				# Resample the atlas instead of the timeseries
				log_Msg "Modalities includes T"
				log_Msg "Resample the atlas instead of the timeseries"
				${Caret7_Command} -cifti-resample ${DownSampleFolder}/${g_Subject}.atlas_Topographic_ROIs.${g_LowResMesh}k_fs_LR.dscalar.nii COLUMN ${DownSampleFolder}/${g_Subject}.atlas_Topographic_ROIs.${g_LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${g_Subject}.atlas_Topographic_ROIs_${InRegName}.${g_LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${g_Subject}.L.sphere.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.L.sphere.${OutPCARegString}${InRegName}.${g_LowResMesh}k_fs_LR.surf.gii -left-area-surfs ${DownSampleFolder}/${g_Subject}.L.midthickness.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.L.midthickness.${g_LowResMesh}k_fs_LR.surf.gii -right-spheres ${DownSampleFolder}/${g_Subject}.R.sphere.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.R.sphere.${OutPCARegString}${InRegName}.${g_LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${DownSampleFolder}/${g_Subject}.R.midthickness.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.R.midthickness.${g_LowResMesh}k_fs_LR.surf.gii
				NumMaps=$(${Caret7_Command} -file-information ${DownSampleFolder}/${g_Subject}.atlas_Topographic_ROIs.${g_LowResMesh}k_fs_LR.dscalar.nii -only-number-of-maps)
				TopographicWeights=${NativeFolder}/${RegName}/TopographicWeights.txt
				n=1
				while [ ${n} -le ${NumMaps} ] ; do
					echo -n "${n} " >> ${TopographicWeights}
					n=$(( n+1 ))
				done
				inputweights="${TopographicWeights}"
				inputspatialmaps="${DownSampleFolder}/${g_Subject}.atlas_Topographic_ROIs_${InRegName}.${g_LowResMesh}k_fs_LR.dscalar.nii"
				outputspatialmaps="${DownSampleFolder}/${g_Subject}.individual_Topography_${InRegName}.${g_LowResMesh}k_fs_LR" #No Ext
				outputweights="${DownSampleFolder}/${g_Subject}.individual_Topography_weights.${g_LowResMesh}k_fs_LR.dscalar.nii"
				Params="${NativeFolder}/${RegName}/Params.txt"
				touch ${Params}
				if [[ $(echo -n ${Method} | grep "WR") ]] ; then
					Distortion="${DownSampleT1wFolder}/${g_Subject}.${Hemisphere}.midthickness_va_norm.${g_LowResMesh}k_fs_LR.dscalar.nii"
					echo ${Distortion} > ${Params}
				fi

				case ${g_matlab_run_mode} in
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

						matlab_logging=">> ${g_StudyFolder}/${g_Subject}.MSMregression.matlab.T.Iteration${i}.log 2>&1"

						matlab_cmd="${matlab_exe} ${matlab_compiler_runtime} ${matlab_function_arguments} ${matlab_logging}"

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
						log_Err_Abort "Unsupported MATLAB run mode value: ${g_matlab_run_mode}"
						;;
				esac

				rm ${Params} ${TopographicWeights} ${DownSampleFolder}/${g_Subject}.atlas_Topographic_ROIs_${InRegName}.${g_LowResMesh}k_fs_LR.dscalar.nii

				# Resample the individual maps so they are in the correct space
				log_Msg "Resample the individual maps so they are in the correct space"

				${Caret7_Command} -cifti-resample ${DownSampleFolder}/${g_Subject}.individual_Topography_${InRegName}.${g_LowResMesh}k_fs_LR.dscalar.nii COLUMN ${DownSampleFolder}/${g_Subject}.individual_Topography_${InRegName}.${g_LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${g_Subject}.individual_Topography_${InRegName}.${g_LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${g_Subject}.L.sphere.${OutPCARegString}${InRegName}.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.L.sphere.${g_LowResMesh}k_fs_LR.surf.gii  -left-area-surfs ${DownSampleFolder}/${g_Subject}.L.midthickness.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.L.midthickness.${g_LowResMesh}k_fs_LR.surf.gii -right-spheres ${DownSampleFolder}/${g_Subject}.R.sphere.${OutPCARegString}${InRegName}.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.R.sphere.${g_LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${DownSampleFolder}/${g_Subject}.R.midthickness.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.R.midthickness.${g_LowResMesh}k_fs_LR.surf.gii

				${Caret7_Command} -cifti-math "Weights - (V1 > 0)" ${DownSampleFolder}/${g_Subject}.individual_Topography_weights.${g_LowResMesh}k_fs_LR.dscalar.nii -var V1 ${DownSampleFolder}/${g_Subject}.atlas_Topographic_ROIs.${g_LowResMesh}k_fs_LR.dscalar.nii -select 1 8 -repeat -var Weights ${DownSampleFolder}/${g_Subject}.individual_Topography_weights.${g_LowResMesh}k_fs_LR.dscalar.nii

				${Caret7_Command} -cifti-separate-all ${DownSampleFolder}/${g_Subject}.individual_Topography_${InRegName}.${g_LowResMesh}k_fs_LR.dscalar.nii -left ${DownSampleFolder}/${g_Subject}.L.individual_Topography_${InRegName}.${g_LowResMesh}k_fs_LR.func.gii -right ${DownSampleFolder}/${g_Subject}.R.individual_Topography_${InRegName}.${g_LowResMesh}k_fs_LR.func.gii

				${Caret7_Command} -cifti-separate-all ${DownSampleFolder}/${g_Subject}.atlas_Topography.${g_LowResMesh}k_fs_LR.dscalar.nii -left ${DownSampleFolder}/${g_Subject}.L.atlas_Topography.${g_LowResMesh}k_fs_LR.func.gii -right ${DownSampleFolder}/${g_Subject}.R.atlas_Topography.${g_LowResMesh}k_fs_LR.func.gii

				${Caret7_Command} -cifti-separate-all ${DownSampleFolder}/${g_Subject}.individual_Topography_weights.${g_LowResMesh}k_fs_LR.dscalar.nii -left ${DownSampleFolder}/${g_Subject}.L.individual_Topography_weights.${g_LowResMesh}k_fs_LR.func.gii -right ${DownSampleFolder}/${g_Subject}.R.individual_Topography_weights.${g_LowResMesh}k_fs_LR.func.gii

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

 					${Caret7_Command} -metric-resample ${DownSampleFolder}/${g_Subject}.${Hemisphere}.individual_RSNs_d${ICAdim}_${InRegName}.${g_LowResMesh}k_fs_LR.func.gii ${DownSampleFolder}/${g_Subject}.${Hemisphere}.sphere.${g_LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.${InRegName}.native.surf.gii ADAP_BARY_AREA ${NativeFolder}/${g_Subject}.${Hemisphere}.individual_RSNs_d${ICAdim}_${InRegName}.native.func.gii -area-surfs ${DownSampleFolder}/${g_Subject}.${Hemisphere}.midthickness.${g_LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.midthickness.native.surf.gii -current-roi ${DownSampleFolder}/${g_Subject}.${Hemisphere}.atlasroi.${g_LowResMesh}k_fs_LR.shape.gii -valid-roi-out ${NativeFolder}/${g_Subject}.${Hemisphere}.${InRegName}_roi.native.shape.gii

					${Caret7_Command} -metric-resample ${DownSampleFolder}/${g_Subject}.${Hemisphere}.individual_RSNs_d${ICAdim}_weights.${g_LowResMesh}k_fs_LR.func.gii ${DownSampleFolder}/${g_Subject}.${Hemisphere}.sphere.${g_LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.${InRegName}.native.surf.gii ADAP_BARY_AREA ${NativeFolder}/${g_Subject}.${Hemisphere}.individual_RSNs_d${ICAdim}_weights.native.func.gii -area-surfs ${DownSampleFolder}/${g_Subject}.${Hemisphere}.midthickness.${g_LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.midthickness.native.surf.gii -current-roi ${DownSampleFolder}/${g_Subject}.${Hemisphere}.atlasroi.${g_LowResMesh}k_fs_LR.shape.gii -valid-roi-out ${NativeFolder}/${g_Subject}.${Hemisphere}.${InRegName}_roi.native.shape.gii -largest

					${Caret7_Command} -metric-resample ${DownSampleFolder}/${g_Subject}.${Hemisphere}.atlas_RSNs_d${ICAdim}.${g_LowResMesh}k_fs_LR.func.gii ${DownSampleFolder}/${g_Subject}.${Hemisphere}.sphere.${g_LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.${InRegName}.native.surf.gii ADAP_BARY_AREA ${NativeFolder}/${g_Subject}.${Hemisphere}.atlas_RSNs_d${ICAdim}.native.func.gii -area-surfs ${DownSampleFolder}/${g_Subject}.${Hemisphere}.midthickness.${g_LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.midthickness.native.surf.gii -current-roi ${DownSampleFolder}/${g_Subject}.${Hemisphere}.atlasroi.${g_LowResMesh}k_fs_LR.shape.gii -valid-roi-out ${NativeFolder}/${g_Subject}.${Hemisphere}.${InRegName}_roi.native.shape.gii

				fi

				if [[ $(echo -n ${Modalities} | grep "A") ]] ; then
					log_Msg "RegHemi - Modalities contains A"

					${Caret7_Command} -metric-resample ${DownSampleFolder}/${g_Subject}.${Hemisphere}.BiasField_${InRegName}.${g_LowResMesh}k_fs_LR.func.gii ${DownSampleFolder}/${g_Subject}.${Hemisphere}.sphere.${g_LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.${InRegName}.native.surf.gii ADAP_BARY_AREA ${NativeFolder}/${g_Subject}.${Hemisphere}.BiasField_${InRegName}.native.func.gii -area-surfs ${DownSampleFolder}/${g_Subject}.${Hemisphere}.midthickness.${g_LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.midthickness.native.surf.gii -current-roi ${DownSampleFolder}/${g_Subject}.${Hemisphere}.atlasroi.${g_LowResMesh}k_fs_LR.shape.gii -valid-roi-out ${NativeFolder}/${g_Subject}.${Hemisphere}.${InRegName}_roi.native.shape.gii

				fi

				if [[ $(echo -n ${Modalities} | grep "T") ]] ; then
					log_Msg "RegHemi - Modalities contains T"

					${Caret7_Command} -metric-resample ${DownSampleFolder}/${g_Subject}.${Hemisphere}.individual_Topography_${InRegName}.${g_LowResMesh}k_fs_LR.func.gii ${DownSampleFolder}/${g_Subject}.${Hemisphere}.sphere.${g_LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.${InRegName}.native.surf.gii ADAP_BARY_AREA ${NativeFolder}/${g_Subject}.${Hemisphere}.individual_Topography_${InRegName}.native.func.gii -area-surfs ${DownSampleFolder}/${g_Subject}.${Hemisphere}.midthickness.${g_LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.midthickness.native.surf.gii -current-roi ${DownSampleFolder}/${g_Subject}.${Hemisphere}.atlasroi.${g_LowResMesh}k_fs_LR.shape.gii -valid-roi-out ${NativeFolder}/${g_Subject}.${Hemisphere}.${InRegName}_roi.native.shape.gii

					${Caret7_Command} -metric-resample ${DownSampleFolder}/${g_Subject}.${Hemisphere}.individual_Topography_weights.${g_LowResMesh}k_fs_LR.func.gii ${DownSampleFolder}/${g_Subject}.${Hemisphere}.sphere.${g_LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.${InRegName}.native.surf.gii ADAP_BARY_AREA ${NativeFolder}/${g_Subject}.${Hemisphere}.individual_Topography_weights.native.func.gii -area-surfs ${DownSampleFolder}/${g_Subject}.${Hemisphere}.midthickness.${g_LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.midthickness.native.surf.gii -current-roi ${DownSampleFolder}/${g_Subject}.${Hemisphere}.atlasroi.${g_LowResMesh}k_fs_LR.shape.gii -valid-roi-out ${NativeFolder}/${g_Subject}.${Hemisphere}.${InRegName}_roi.native.shape.gii -largest

					${Caret7_Command} -metric-resample ${DownSampleFolder}/${g_Subject}.${Hemisphere}.atlas_Topography.${g_LowResMesh}k_fs_LR.func.gii ${DownSampleFolder}/${g_Subject}.${Hemisphere}.sphere.${g_LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.${InRegName}.native.surf.gii ADAP_BARY_AREA ${NativeFolder}/${g_Subject}.${Hemisphere}.atlas_Topography.native.func.gii -area-surfs ${DownSampleFolder}/${g_Subject}.${Hemisphere}.midthickness.${g_LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.midthickness.native.surf.gii -current-roi ${DownSampleFolder}/${g_Subject}.${Hemisphere}.atlasroi.${g_LowResMesh}k_fs_LR.shape.gii -valid-roi-out ${NativeFolder}/${g_Subject}.${Hemisphere}.${InRegName}_roi.native.shape.gii

				fi

				MedialWallWeight="1"
				${Caret7_Command} -metric-math "((var - 1) * -1) * ${MedialWallWeight}" ${NativeFolder}/${g_Subject}.${Hemisphere}.${InRegName}_roi_inv.native.shape.gii -var var ${NativeFolder}/${g_Subject}.${Hemisphere}.${InRegName}_roi.native.shape.gii
				${Caret7_Command} -metric-math "((var - 1) * -1) * ${MedialWallWeight}" ${DownSampleFolder}/${g_Subject}.${Hemisphere}.atlasroi_inv.${g_LowResMesh}k_fs_LR.shape.gii -var var ${DownSampleFolder}/${g_Subject}.${Hemisphere}.atlasroi.${g_LowResMesh}k_fs_LR.shape.gii

				NativeMetricMerge=""
				NativeWeightsMerge=""
				AtlasMetricMerge=""
				AtlasWeightsMerge=""
				n=1
				for Modality in $(echo ${Modalities} | sed 's/\(.\)/\1 /g') ; do
					log_Msg "RegHemi - n: ${n}"
					if [ ${Modality} = "C" ] ; then
						log_Msg "RegHemi - Modality: ${Modality}"
						${Caret7_Command} -metric-math "Var * ROI" ${DownSampleFolder}/${g_Subject}.${Hemisphere}.norm_atlas_RSNs_d${ICAdim}.${g_LowResMesh}k_fs_LR.func.gii -var Var ${DownSampleFolder}/${g_Subject}.${Hemisphere}.atlas_RSNs_d${ICAdim}.${g_LowResMesh}k_fs_LR.func.gii -var ROI ${DownSampleFolder}/${g_Subject}.${Hemisphere}.individual_RSNs_d${ICAdim}_weights.${g_LowResMesh}k_fs_LR.func.gii
						SDEVs=$(${Caret7_Command} -metric-stats ${DownSampleFolder}/${g_Subject}.${Hemisphere}.norm_atlas_RSNs_d${ICAdim}.${g_LowResMesh}k_fs_LR.func.gii -reduce STDEV)
						SDEVs=$(echo ${SDEVs} | sed 's/ / + /g' | bc -l)
						MeanSDEV=$(echo "${SDEVs} / ${NumValidRSNs}" | bc -l)
						${Caret7_Command} -metric-math "Var / ${MeanSDEV}" ${DownSampleFolder}/${g_Subject}.${Hemisphere}.norm_atlas_RSNs_d${ICAdim}.${g_LowResMesh}k_fs_LR.func.gii -var Var ${DownSampleFolder}/${g_Subject}.${Hemisphere}.atlas_RSNs_d${ICAdim}.${g_LowResMesh}k_fs_LR.func.gii
						${Caret7_Command} -metric-math "Var / ${MeanSDEV}" ${NativeFolder}/${g_Subject}.${Hemisphere}.norm_individual_RSNs_d${ICAdim}_${InRegName}.native.func.gii -var Var ${NativeFolder}/${g_Subject}.${Hemisphere}.individual_RSNs_d${ICAdim}_${InRegName}.native.func.gii
						NativeMetricMerge=$(echo "${NativeMetricMerge} -metric ${NativeFolder}/${g_Subject}.${Hemisphere}.norm_individual_RSNs_d${ICAdim}_${InRegName}.native.func.gii")
						NativeWeightsMerge=$(echo "${NativeWeightsMerge} -metric ${NativeFolder}/${g_Subject}.${Hemisphere}.individual_RSNs_d${ICAdim}_weights.native.func.gii")
						AtlasMetricMerge=$(echo "${AtlasMetricMerge} -metric ${DownSampleFolder}/${g_Subject}.${Hemisphere}.norm_atlas_RSNs_d${ICAdim}.${g_LowResMesh}k_fs_LR.func.gii")
						AtlasWeightsMerge=$(echo "${AtlasWeightsMerge} -metric ${DownSampleFolder}/${g_Subject}.${Hemisphere}.individual_RSNs_d${ICAdim}_weights.${g_LowResMesh}k_fs_LR.func.gii")
					elif [ ${Modality} = "A" ] ; then
						log_Msg "RegHemi - Modality: ${Modality}"
						###Renormalize individual map?
						${Caret7_Command} -metric-math "Var * ROI" ${DownSampleFolder}/${g_Subject}.${Hemisphere}.norm_MyelinMap_BC.${g_LowResMesh}k_fs_LR.func.gii -var Var ${DownSampleFolder}/${g_Subject}.${Hemisphere}.atlas_MyelinMap_BC.${g_LowResMesh}k_fs_LR.func.gii -var ROI ${DownSampleFolder}/${g_Subject}.${Hemisphere}.atlasroi.${g_LowResMesh}k_fs_LR.shape.gii
						SDEVs=$(${Caret7_Command} -metric-stats ${DownSampleFolder}/${g_Subject}.${Hemisphere}.norm_MyelinMap_BC.${g_LowResMesh}k_fs_LR.func.gii -reduce STDEV)
						SDEVs=$(echo ${SDEVs} | sed 's/ / + /g' | bc -l)
						MeanSDEV=$(echo "${SDEVs} / 1" | bc -l)
						${Caret7_Command} -metric-math "Var / ${MeanSDEV}" ${DownSampleFolder}/${g_Subject}.${Hemisphere}.norm_atlas_MyelinMap_BC.${g_LowResMesh}k_fs_LR.func.gii -var Var ${DownSampleFolder}/${g_Subject}.${Hemisphere}.atlas_MyelinMap_BC.${g_LowResMesh}k_fs_LR.func.gii
						${Caret7_Command} -metric-math "(Var - Bias) / ${MeanSDEV}" ${NativeFolder}/${g_Subject}.${Hemisphere}.norm_MyelinMap_BC_${InRegName}.native.func.gii -var Var ${NativeFolder}/${g_Subject}.${Hemisphere}.MyelinMap.native.func.gii -var Bias ${NativeFolder}/${g_Subject}.${Hemisphere}.BiasField_${InRegName}.native.func.gii
						NativeMetricMerge=$(echo "${NativeMetricMerge} -metric ${NativeFolder}/${g_Subject}.${Hemisphere}.norm_MyelinMap_BC_${InRegName}.native.func.gii")
						NativeWeightsMerge=$(echo "${NativeWeightsMerge} -metric ${NativeFolder}/${g_Subject}.${Hemisphere}.${InRegName}_roi.native.shape.gii")
						AtlasMetricMerge=$(echo "${AtlasMetricMerge} -metric ${DownSampleFolder}/${g_Subject}.${Hemisphere}.norm_atlas_MyelinMap_BC.${g_LowResMesh}k_fs_LR.func.gii")
						AtlasWeightsMerge=$(echo "${AtlasWeightsMerge} -metric ${DownSampleFolder}/${g_Subject}.${Hemisphere}.atlasroi.${g_LowResMesh}k_fs_LR.shape.gii")
					elif [ ${Modality} = "T" ] ; then
						log_Msg "RegHemi - Modality: ${Modality}"
						${Caret7_Command} -metric-math "Var * ROI" ${DownSampleFolder}/${g_Subject}.${Hemisphere}.norm_atlas_Topography.${g_LowResMesh}k_fs_LR.func.gii -var Var ${DownSampleFolder}/${g_Subject}.${Hemisphere}.atlas_Topography.${g_LowResMesh}k_fs_LR.func.gii -var ROI ${DownSampleFolder}/${g_Subject}.${Hemisphere}.individual_Topography_weights.${g_LowResMesh}k_fs_LR.func.gii
						SDEVs=$(${Caret7_Command} -metric-stats ${DownSampleFolder}/${g_Subject}.${Hemisphere}.norm_atlas_Topography.${g_LowResMesh}k_fs_LR.func.gii -reduce STDEV)
						SDEVs=$(echo ${SDEVs} | sed 's/ / + /g' | bc -l)
						MeanSDEV=$(echo "${SDEVs} / 1" | bc -l)
						${Caret7_Command} -metric-math "Var / ${MeanSDEV}" ${DownSampleFolder}/${g_Subject}.${Hemisphere}.norm_atlas_Topography.${g_LowResMesh}k_fs_LR.func.gii -var Var ${DownSampleFolder}/${g_Subject}.${Hemisphere}.atlas_Topography.${g_LowResMesh}k_fs_LR.func.gii
						${Caret7_Command} -metric-math "Var / ${MeanSDEV}" ${NativeFolder}/${g_Subject}.${Hemisphere}.norm_individual_Topography_${InRegName}.native.func.gii -var Var ${NativeFolder}/${g_Subject}.${Hemisphere}.individual_Topography_${InRegName}.native.func.gii
						NativeMetricMerge=$(echo "${NativeMetricMerge} -metric ${NativeFolder}/${g_Subject}.${Hemisphere}.norm_individual_Topography_${InRegName}.native.func.gii")
						NativeWeightsMerge=$(echo "${NativeWeightsMerge} -metric ${NativeFolder}/${g_Subject}.${Hemisphere}.individual_Topography_weights.native.func.gii")
						AtlasMetricMerge=$(echo "${AtlasMetricMerge} -metric ${DownSampleFolder}/${g_Subject}.${Hemisphere}.norm_atlas_Topography.${g_LowResMesh}k_fs_LR.func.gii")
						AtlasWeightsMerge=$(echo "${AtlasWeightsMerge} -metric ${DownSampleFolder}/${g_Subject}.${Hemisphere}.individual_Topography_weights.${g_LowResMesh}k_fs_LR.func.gii")
					fi
					if [ ${n} -eq "1" ] ; then
						NormSDEV=${MeanSDEV}
					fi
					n=$(( n+1 ))
				done

				log_Debug_Msg "RegHemi 1"
				${Caret7_Command} -metric-merge ${NativeFolder}/${g_Subject}.${Hemisphere}.Modalities_${i}_${InRegName}.native.func.gii ${NativeMetricMerge} -metric ${NativeFolder}/${g_Subject}.${Hemisphere}.${InRegName}_roi_inv.native.shape.gii
				${Caret7_Command} -metric-merge ${NativeFolder}/${g_Subject}.${Hemisphere}.Modalities_${i}_weights.native.func.gii ${NativeWeightsMerge} -metric ${NativeFolder}/${g_Subject}.${Hemisphere}.${InRegName}_roi_inv.native.shape.gii
				${Caret7_Command} -metric-merge ${DownSampleFolder}/${g_Subject}.${Hemisphere}.Modalities_${i}.${g_LowResMesh}k_fs_LR.func.gii ${AtlasMetricMerge} -metric ${DownSampleFolder}/${g_Subject}.${Hemisphere}.atlasroi_inv.${g_LowResMesh}k_fs_LR.shape.gii
				${Caret7_Command} -metric-merge ${DownSampleFolder}/${g_Subject}.${Hemisphere}.Modalities_${i}_weights.${g_LowResMesh}k_fs_LR.func.gii ${AtlasWeightsMerge} -metric ${DownSampleFolder}/${g_Subject}.${Hemisphere}.atlasroi_inv.${g_LowResMesh}k_fs_LR.shape.gii

				log_Debug_Msg "RegHemi 2"
				${Caret7_Command} -metric-math "Modalities * Weights * ${NormSDEV}" ${NativeFolder}/${g_Subject}.${Hemisphere}.Modalities_${i}_${InRegName}.native.func.gii -var Modalities ${NativeFolder}/${g_Subject}.${Hemisphere}.Modalities_${i}_${InRegName}.native.func.gii -var Weights ${NativeFolder}/${g_Subject}.${Hemisphere}.Modalities_${i}_weights.native.func.gii
				${Caret7_Command} -metric-math "Modalities * Weights * ${NormSDEV}" ${DownSampleFolder}/${g_Subject}.${Hemisphere}.Modalities_${i}.${g_LowResMesh}k_fs_LR.func.gii -var Modalities ${DownSampleFolder}/${g_Subject}.${Hemisphere}.Modalities_${i}.${g_LowResMesh}k_fs_LR.func.gii -var Weights ${DownSampleFolder}/${g_Subject}.${Hemisphere}.Modalities_${i}_weights.${g_LowResMesh}k_fs_LR.func.gii

				MEANs=$(${Caret7_Command} -metric-stats ${DownSampleFolder}/${g_Subject}.${Hemisphere}.Modalities_${i}_weights.${g_LowResMesh}k_fs_LR.func.gii -reduce MEAN)
				Native=""
				NativeWeights=""
				Atlas=""
				AtlasWeights=""
				j=1
				for MEAN in ${MEANs} ; do
					log_Debug_Msg "RegHemi j: ${j}"
					if [ ! ${MEAN} = 0 ] ; then
						Native=$(echo "${Native} -metric ${NativeFolder}/${g_Subject}.${Hemisphere}.Modalities_${i}_${InRegName}.native.func.gii -column ${j}")
						NativeWeights=$(echo "${NativeWeights} -metric ${NativeFolder}/${g_Subject}.${Hemisphere}.Modalities_${i}_weights.native.func.gii -column ${j}")
						Atlas=$(echo "${Atlas} -metric ${DownSampleFolder}/${g_Subject}.${Hemisphere}.Modalities_${i}.${g_LowResMesh}k_fs_LR.func.gii -column ${j}")
						AtlasWeights=$(echo "${AtlasWeights} -metric ${DownSampleFolder}/${g_Subject}.${Hemisphere}.Modalities_${i}_weights.${g_LowResMesh}k_fs_LR.func.gii -column ${j}")
					fi
					j=$(( j+1 ))
				done

				log_Debug_Msg "RegHemi 3"
				$Caret7_Command -metric-merge ${NativeFolder}/${g_Subject}.${Hemisphere}.Modalities_${i}_${InRegName}.native.func.gii ${Native}
				$Caret7_Command -metric-merge ${NativeFolder}/${g_Subject}.${Hemisphere}.Modalities_${i}_weights.native.func.gii ${NativeWeights}
				$Caret7_Command -metric-merge ${DownSampleFolder}/${g_Subject}.${Hemisphere}.Modalities_${i}.${g_LowResMesh}k_fs_LR.func.gii ${Atlas}
				$Caret7_Command -metric-merge ${DownSampleFolder}/${g_Subject}.${Hemisphere}.Modalities_${i}_weights.${g_LowResMesh}k_fs_LR.func.gii ${AtlasWeights}

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
							--inmesh=${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.rot.native.surf.gii \
							--trans=${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.${InPCARegName}.native.surf.gii \
							--refmesh=${DownSampleFolder}/${g_Subject}.${Hemisphere}.sphere.${g_LowResMesh}k_fs_LR.surf.gii \
							--indata=${NativeFolder}/${g_Subject}.${Hemisphere}.Modalities_${i}_${InRegName}.native.func.gii \
							--inweight=${NativeFolder}/${g_Subject}.${Hemisphere}.Modalities_${i}_weights.native.func.gii \
							--refdata=${DownSampleFolder}/${g_Subject}.${Hemisphere}.Modalities_${i}.${g_LowResMesh}k_fs_LR.func.gii \
							--refweight=${DownSampleFolder}/${g_Subject}.${Hemisphere}.Modalities_${i}_weights.${g_LowResMesh}k_fs_LR.func.gii \
							--out=${NativeFolder}/${RegName}/${Hemisphere}. \
							--verbose \
							--debug \
							2>&1
				MSMOut=$?
				log_Debug_Msg "MSMOut: ${MSMOut}"

				cd $DIR

				log_File_Must_Exist "${NativeFolder}/${RegName}/${Hemisphere}.sphere.reg.surf.gii"
				cp ${NativeFolder}/${RegName}/${Hemisphere}.sphere.reg.surf.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii
				log_File_Must_Exist "${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii"

				${Caret7_Command} -set-structure ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii ${Structure}

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
				${Caret7_Command} -surface-vertex-areas ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.native.surf.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.native.shape.gii

				in_surface="${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii"
				log_Msg "in_surface: ${in_surface}"
				log_File_Must_Exist "${in_surface}"

				out_metric="${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.${RegName}.native.shape.gii"
				log_Msg "out_metric: ${out_metric}"

				${Caret7_Command} -surface-vertex-areas ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.${RegName}.native.shape.gii
				${Caret7_Command} -metric-math "ln(spherereg / sphere) / ln(2)" ${NativeFolder}/${g_Subject}.${Hemisphere}.ArealDistortion_${RegName}.native.shape.gii -var sphere ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.native.shape.gii -var spherereg ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.${RegName}.native.shape.gii
				rm ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.native.shape.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.${RegName}.native.shape.gii

				${Caret7_Command} -surface-sphere-project-unproject ${DownSampleFolder}/${g_Subject}.${Hemisphere}.sphere.${g_LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.${InPCARegString}.native.surf.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii ${DownSampleFolder}/${g_Subject}.${Hemisphere}.sphere.${OutPCARegString}${RegName}.${g_LowResMesh}k_fs_LR.surf.gii

				${Caret7_Command} -surface-resample ${NativeT1wFolder}/${g_Subject}.${Hemisphere}.midthickness.native.surf.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii ${DownSampleFolder}/${g_Subject}.${Hemisphere}.sphere.${g_LowResMesh}k_fs_LR.surf.gii BARYCENTRIC ${DownSampleT1wFolder}/${g_Subject}.${Hemisphere}.midthickness_${RegName}.${g_LowResMesh}k_fs_LR.surf.gii
			done

			${Caret7_Command} -cifti-create-dense-timeseries ${NativeFolder}/${g_Subject}.ArealDistortion_${RegName}.native.dtseries.nii -left-metric ${NativeFolder}/${g_Subject}.L.ArealDistortion_${RegName}.native.shape.gii -roi-left ${NativeFolder}/${g_Subject}.L.atlasroi.native.shape.gii -right-metric ${NativeFolder}/${g_Subject}.R.ArealDistortion_${RegName}.native.shape.gii -roi-right ${NativeFolder}/${g_Subject}.R.atlasroi.native.shape.gii
			${Caret7_Command} -cifti-convert-to-scalar ${NativeFolder}/${g_Subject}.ArealDistortion_${RegName}.native.dtseries.nii ROW ${NativeFolder}/${g_Subject}.ArealDistortion_${RegName}.native.dscalar.nii
			${Caret7_Command} -set-map-name ${NativeFolder}/${g_Subject}.ArealDistortion_${RegName}.native.dscalar.nii 1 ${g_Subject}_ArealDistortion_${RegName}
			${Caret7_Command} -cifti-palette ${NativeFolder}/${g_Subject}.ArealDistortion_${RegName}.native.dscalar.nii MODE_USER_SCALE ${NativeFolder}/${g_Subject}.ArealDistortion_${RegName}.native.dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false
			rm ${NativeFolder}/${g_Subject}.ArealDistortion_${RegName}.native.dtseries.nii

			${Caret7_Command} -cifti-resample ${NativeFolder}/${g_Subject}.ArealDistortion_${RegName}.native.dscalar.nii COLUMN ${DownSampleFolder}/${g_Subject}.ArealDistortion_${InRegName}.${g_LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${g_Subject}.ArealDistortion_${RegName}.${g_LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 30 -left-spheres ${NativeFolder}/${g_Subject}.L.sphere.${RegName}.native.surf.gii ${DownSampleFolder}/${g_Subject}.L.sphere.${g_LowResMesh}k_fs_LR.surf.gii -left-area-surfs ${NativeFolder}/${g_Subject}.L.midthickness.native.surf.gii ${DownSampleT1wFolder}/${g_Subject}.L.midthickness_${RegName}.${g_LowResMesh}k_fs_LR.surf.gii -right-spheres ${NativeFolder}/${g_Subject}.R.sphere.${RegName}.native.surf.gii ${DownSampleFolder}/${g_Subject}.R.sphere.${g_LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${NativeFolder}/${g_Subject}.R.midthickness.native.surf.gii ${DownSampleT1wFolder}/${g_Subject}.R.midthickness_${RegName}.${g_LowResMesh}k_fs_LR.surf.gii
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
			${Caret7_Command} -surface-vertex-areas ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.native.surf.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.native.shape.gii
			${Caret7_Command} -surface-vertex-areas ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.${RegName}.native.shape.gii
			${Caret7_Command} -metric-math "ln(spherereg / sphere) / ln(2)" ${NativeFolder}/${g_Subject}.${Hemisphere}.ArealDistortion_${RegName}.native.shape.gii -var sphere ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.native.shape.gii -var spherereg ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.${RegName}.native.shape.gii
			rm ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.native.shape.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.${RegName}.native.shape.gii

			${Caret7_Command} -surface-distortion ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.native.surf.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.EdgeDistortion_${RegName}.native.shape.gii -edge-method

			# Make MSM Registration Areal Distortion Maps
			log_Msg "Make MSM Registration Areal Distortion Maps"
			${Caret7_Command} -surface-vertex-areas ${NativeFolder}/${g_Subject}.${Hemisphere}.midthickness.native.surf.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.midthickness.native.shape.gii
			${Caret7_Command} -surface-vertex-areas ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.native.surf.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.native.shape.gii
			${Caret7_Command} -metric-math "ln(sphere / midthickness) / ln(2)" ${NativeFolder}/${g_Subject}.${Hemisphere}.SphericalDistortion.native.shape.gii -var midthickness ${NativeFolder}/${g_Subject}.${Hemisphere}.midthickness.native.shape.gii -var sphere ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.native.shape.gii
			rm ${NativeFolder}/${g_Subject}.${Hemisphere}.midthickness.native.shape.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.native.shape.gii

			${Caret7_Command} -surface-sphere-project-unproject ${DownSampleFolder}/${g_Subject}.${Hemisphere}.sphere.${g_LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.${InPCARegString}.native.surf.gii ${NativeFolder}/${g_Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii ${DownSampleFolder}/${g_Subject}.${Hemisphere}.sphere.${OutPCARegString}${RegName}.${g_LowResMesh}k_fs_LR.surf.gii
		done # for Hemispher in L R

		${Caret7_Command} -cifti-create-dense-timeseries ${NativeFolder}/${g_Subject}.ArealDistortion_${RegName}.native.dtseries.nii -left-metric ${NativeFolder}/${g_Subject}.L.ArealDistortion_${RegName}.native.shape.gii -roi-left ${NativeFolder}/${g_Subject}.L.atlasroi.native.shape.gii -right-metric ${NativeFolder}/${g_Subject}.R.ArealDistortion_${RegName}.native.shape.gii -roi-right ${NativeFolder}/${g_Subject}.R.atlasroi.native.shape.gii
		${Caret7_Command} -cifti-convert-to-scalar ${NativeFolder}/${g_Subject}.ArealDistortion_${RegName}.native.dtseries.nii ROW ${NativeFolder}/${g_Subject}.ArealDistortion_${RegName}.native.dscalar.nii
		${Caret7_Command} -set-map-name ${NativeFolder}/${g_Subject}.ArealDistortion_${RegName}.native.dscalar.nii 1 ${g_Subject}_ArealDistortion_${RegName}
		${Caret7_Command} -cifti-palette ${NativeFolder}/${g_Subject}.ArealDistortion_${RegName}.native.dscalar.nii MODE_USER_SCALE ${NativeFolder}/${g_Subject}.ArealDistortion_${RegName}.native.dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false
		rm ${NativeFolder}/${g_Subject}.ArealDistortion_${RegName}.native.dtseries.nii

		${Caret7_Command} -cifti-create-dense-timeseries ${NativeFolder}/${g_Subject}.EdgeDistortion_${RegName}.native.dtseries.nii -left-metric ${NativeFolder}/${g_Subject}.L.EdgeDistortion_${RegName}.native.shape.gii -roi-left ${NativeFolder}/${g_Subject}.L.atlasroi.native.shape.gii -right-metric ${NativeFolder}/${g_Subject}.R.EdgeDistortion_${RegName}.native.shape.gii -roi-right ${NativeFolder}/${g_Subject}.R.atlasroi.native.shape.gii
		${Caret7_Command} -cifti-convert-to-scalar ${NativeFolder}/${g_Subject}.EdgeDistortion_${RegName}.native.dtseries.nii ROW ${NativeFolder}/${g_Subject}.EdgeDistortion_${RegName}.native.dscalar.nii
		${Caret7_Command} -set-map-name ${NativeFolder}/${g_Subject}.EdgeDistortion_${RegName}.native.dscalar.nii 1 ${g_Subject}_EdgeDistortion_${RegName}
		${Caret7_Command} -cifti-palette ${NativeFolder}/${g_Subject}.EdgeDistortion_${RegName}.native.dscalar.nii MODE_USER_SCALE ${NativeFolder}/${g_Subject}.EdgeDistortion_${RegName}.native.dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false
		rm ${NativeFolder}/${g_Subject}.EdgeDistortion_${RegName}.native.dtseries.nii

		${Caret7_Command} -cifti-create-dense-timeseries ${NativeFolder}/${g_Subject}.SphericalDistortion.native.dtseries.nii -left-metric ${NativeFolder}/${g_Subject}.L.SphericalDistortion.native.shape.gii -roi-left ${NativeFolder}/${g_Subject}.L.atlasroi.native.shape.gii -right-metric ${NativeFolder}/${g_Subject}.R.SphericalDistortion.native.shape.gii -roi-right ${NativeFolder}/${g_Subject}.R.atlasroi.native.shape.gii
		${Caret7_Command} -cifti-convert-to-scalar ${NativeFolder}/${g_Subject}.SphericalDistortion.native.dtseries.nii ROW ${NativeFolder}/${g_Subject}.SphericalDistortion.native.dscalar.nii
		${Caret7_Command} -set-map-name ${NativeFolder}/${g_Subject}.SphericalDistortion.native.dscalar.nii 1 ${g_Subject}_SphericalDistortion
		${Caret7_Command} -cifti-palette ${NativeFolder}/${g_Subject}.SphericalDistortion.native.dscalar.nii MODE_USER_SCALE ${NativeFolder}/${g_Subject}.SphericalDistortion.native.dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false
		rm ${NativeFolder}/${g_Subject}.SphericalDistortion.native.dtseries.nii

		${Caret7_Command} -cifti-resample ${NativeFolder}/${g_Subject}.MyelinMap.native.dscalar.nii COLUMN ${DownSampleFolder}/${g_Subject}.MyelinMap.${g_LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${g_Subject}.MyelinMap_${RegName}.${g_LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${NativeFolder}/${g_Subject}.L.sphere.${RegName}.native.surf.gii ${DownSampleFolder}/${g_Subject}.L.sphere.${g_LowResMesh}k_fs_LR.surf.gii -left-area-surfs ${NativeT1wFolder}/${g_Subject}.L.midthickness.native.surf.gii ${DownSampleT1wFolder}/${g_Subject}.L.midthickness_${RegName}.${g_LowResMesh}k_fs_LR.surf.gii -right-spheres ${NativeFolder}/${g_Subject}.R.sphere.${RegName}.native.surf.gii ${DownSampleFolder}/${g_Subject}.R.sphere.${g_LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${NativeT1wFolder}/${g_Subject}.R.midthickness.native.surf.gii ${DownSampleT1wFolder}/${g_Subject}.R.midthickness_${RegName}.${g_LowResMesh}k_fs_LR.surf.gii
		${Caret7_Command} -cifti-math "Individual - Reference" ${DownSampleFolder}/${g_Subject}.BiasField_${RegName}.${g_LowResMesh}k_fs_LR.dscalar.nii -var Individual ${DownSampleFolder}/${g_Subject}.MyelinMap_${RegName}.${g_LowResMesh}k_fs_LR.dscalar.nii -var Reference ${DownSampleFolder}/${g_Subject}.atlas_MyelinMap_BC.${g_LowResMesh}k_fs_LR.dscalar.nii
		${Caret7_Command} -cifti-smoothing ${DownSampleFolder}/${g_Subject}.BiasField_${RegName}.${g_LowResMesh}k_fs_LR.dscalar.nii ${CorrectionSigma} 0 COLUMN ${DownSampleFolder}/${g_Subject}.BiasField_${RegName}.${g_LowResMesh}k_fs_LR.dscalar.nii -left-surface ${DownSampleT1wFolder}/${g_Subject}.L.midthickness_${RegName}.${g_LowResMesh}k_fs_LR.surf.gii -right-surface ${DownSampleT1wFolder}/${g_Subject}.R.midthickness_${RegName}.${g_LowResMesh}k_fs_LR.surf.gii
		${Caret7_Command} -cifti-resample ${DownSampleFolder}/${g_Subject}.BiasField_${RegName}.${g_LowResMesh}k_fs_LR.dscalar.nii COLUMN ${NativeFolder}/${g_Subject}.MyelinMap.native.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${NativeFolder}/${g_Subject}.BiasField_${RegName}.native.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${g_Subject}.L.sphere.${g_LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${g_Subject}.L.sphere.${RegName}.native.surf.gii -left-area-surfs ${DownSampleT1wFolder}/${g_Subject}.L.midthickness_${RegName}.${g_LowResMesh}k_fs_LR.surf.gii ${NativeT1wFolder}/${g_Subject}.L.midthickness.native.surf.gii -right-spheres ${DownSampleFolder}/${g_Subject}.R.sphere.${g_LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${g_Subject}.R.sphere.${RegName}.native.surf.gii -right-area-surfs ${DownSampleT1wFolder}/${g_Subject}.R.midthickness_${RegName}.${g_LowResMesh}k_fs_LR.surf.gii ${NativeT1wFolder}/${g_Subject}.R.midthickness.native.surf.gii
		${Caret7_Command} -cifti-math "Var - Bias" ${NativeFolder}/${g_Subject}.MyelinMap_BC_${RegName}.native.dscalar.nii -var Var ${NativeFolder}/${g_Subject}.MyelinMap.native.dscalar.nii -var Bias ${NativeFolder}/${g_Subject}.BiasField_${RegName}.native.dscalar.nii

		for Mesh in ${g_HighResMesh} ${g_LowResMesh} ; do
			if [ $Mesh = ${g_HighResMesh} ] ; then
				Folder=${AtlasFolder}
			elif [ $Mesh = ${g_LowResMesh} ] ; then
				Folder=${DownSampleFolder}
			fi
			for Map in ArealDistortion EdgeDistortion sulc SphericalDistortion MyelinMap_BC ; do
				if [[ ${Map} = "ArealDistortion" || ${Map} = "EdgeDistortion" || ${Map} = "MyelinMap_BC" ]] ; then
					NativeMap="${Map}_${RegName}"
				else
					NativeMap="${Map}"
				fi
				${Caret7_Command} -cifti-resample ${NativeFolder}/${g_Subject}.${NativeMap}.native.dscalar.nii COLUMN ${Folder}/${g_Subject}.MyelinMap_BC.${Mesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${Folder}/${g_Subject}.${Map}_${RegName}.${Mesh}k_fs_LR.dscalar.nii -surface-postdilate 30 -left-spheres ${NativeFolder}/${g_Subject}.L.sphere.${RegName}.native.surf.gii ${Folder}/${g_Subject}.L.sphere.${Mesh}k_fs_LR.surf.gii -left-area-surfs ${NativeFolder}/${g_Subject}.L.midthickness.native.surf.gii ${Folder}/${g_Subject}.L.midthickness.${Mesh}k_fs_LR.surf.gii -right-spheres ${NativeFolder}/${g_Subject}.R.sphere.${RegName}.native.surf.gii ${Folder}/${g_Subject}.R.sphere.${Mesh}k_fs_LR.surf.gii -right-area-surfs ${NativeFolder}/${g_Subject}.R.midthickness.native.surf.gii ${Folder}/${g_Subject}.R.midthickness.${Mesh}k_fs_LR.surf.gii
			done
		done

		if [ ${UseMIGP} = "YES" ] ; then
			inputdtseries="${ResultsFolder}/${OutputfMRIName}${fMRIProcSTRING}_PCA${PCARegString}.dtseries.nii"
		else
			inputdtseries="${ResultsFolder}/${OutputfMRIName}${fMRIProcSTRING}${PCARegString}.dtseries.nii"
		fi

		# Resample the atlas instead of the timeseries
		log_Msg "Resample the atlas instead of the timeseries"
		${Caret7_Command} -cifti-resample ${DownSampleFolder}/${g_Subject}.atlas_RSNs_d${ICAdim}.${g_LowResMesh}k_fs_LR.dscalar.nii COLUMN ${DownSampleFolder}/${g_Subject}.atlas_RSNs_d${ICAdim}.${g_LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${g_Subject}.atlas_RSNs_d${ICAdim}_${RegName}.${g_LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${g_Subject}.L.sphere.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.L.sphere.${OutPCARegString}${RegName}.${g_LowResMesh}k_fs_LR.surf.gii -left-area-surfs ${DownSampleFolder}/${g_Subject}.L.midthickness.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.L.midthickness.${g_LowResMesh}k_fs_LR.surf.gii -right-spheres ${DownSampleFolder}/${g_Subject}.R.sphere.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.R.sphere.${OutPCARegString}${RegName}.${g_LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${DownSampleFolder}/${g_Subject}.R.midthickness.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.R.midthickness.${g_LowResMesh}k_fs_LR.surf.gii

		inputweights="NONE"
		inputspatialmaps="${DownSampleFolder}/${g_Subject}.atlas_RSNs_d${ICAdim}_${RegName}.${g_LowResMesh}k_fs_LR.dscalar.nii"
		outputspatialmaps="${DownSampleFolder}/${g_Subject}.individual_RSNs_d${ICAdim}_${RegName}.${g_LowResMesh}k_fs_LR" #No Ext
		outputweights="NONE"
		Params="${NativeFolder}/${RegName}/Params.txt"
		touch ${Params}
		if [[ $(echo -n ${Method} | grep "WR") ]] ; then
			Distortion="${DownSampleT1wFolder}/${g_Subject}.${Hemisphere}.midthickness_va_norm.${g_LowResMesh}k_fs_LR.dscalar.nii"
			echo ${Distortion} > ${Params}
			LeftSurface="${DownSampleT1wFolder}/${g_Subject}.L.midthickness_${RegName}.${g_LowResMesh}k_fs_LR.surf.gii"
			echo ${LeftSurface} >> ${Params}
			RightSurface="${DownSampleT1wFolder}/${g_Subject}.R.midthickness_${RegName}.${g_LowResMesh}k_fs_LR.surf.gii"
			echo ${RightSurface} >> ${Params}
			for LowICAdim in ${LowICAdims} ; do
				LowDim=$(echo ${RSNTargetFileOrig} | sed "s/REPLACEDIM/${LowICAdim}/g")
				echo ${LowDim} >> ${Params}
			done
		fi

		case ${g_matlab_run_mode} in
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

				matlab_logging=">> ${g_StudyFolder}/${g_Subject}.MSMregression.matlab.1.log 2>&1"

				matlab_cmd="${matlab_exe} ${matlab_compiler_runtime} ${matlab_function_arguments} ${matlab_logging}"

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
				log_Err_Abort "Unsupported MATLAB run mode value: ${g_matlab_run_mode}"
				;;
		esac

		rm ${Params} ${DownSampleFolder}/${g_Subject}.atlas_RSNs_d${ICAdim}_${RegName}.${g_LowResMesh}k_fs_LR.dscalar.nii

		# Resample the individual maps so they are in the correct space
		log_Msg "Resample the individual maps so they are in the correct space"
		${Caret7_Command} -cifti-resample ${DownSampleFolder}/${g_Subject}.individual_RSNs_d${ICAdim}_${RegName}.${g_LowResMesh}k_fs_LR.dscalar.nii COLUMN ${DownSampleFolder}/${g_Subject}.individual_RSNs_d${ICAdim}_${RegName}.${g_LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${g_Subject}.individual_RSNs_d${ICAdim}_${RegName}.${g_LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${g_Subject}.L.sphere.${OutPCARegString}${RegName}.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.L.sphere.${g_LowResMesh}k_fs_LR.surf.gii  -left-area-surfs ${DownSampleFolder}/${g_Subject}.L.midthickness.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.L.midthickness.${g_LowResMesh}k_fs_LR.surf.gii -right-spheres ${DownSampleFolder}/${g_Subject}.R.sphere.${OutPCARegString}${RegName}.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.R.sphere.${g_LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${DownSampleFolder}/${g_Subject}.R.midthickness.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.R.midthickness.${g_LowResMesh}k_fs_LR.surf.gii


		# Resample the atlas instead of the timeseries
		log_Msg "Resample the atlas instead of the timeseries"
		${Caret7_Command} -cifti-resample ${DownSampleFolder}/${g_Subject}.atlas_Topographic_ROIs.${g_LowResMesh}k_fs_LR.dscalar.nii COLUMN ${DownSampleFolder}/${g_Subject}.atlas_Topographic_ROIs.${g_LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${g_Subject}.atlas_Topographic_ROIs_${RegName}.${g_LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${g_Subject}.L.sphere.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.L.sphere.${OutPCARegString}${RegName}.${g_LowResMesh}k_fs_LR.surf.gii -left-area-surfs ${DownSampleFolder}/${g_Subject}.L.midthickness.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.L.midthickness.${g_LowResMesh}k_fs_LR.surf.gii -right-spheres ${DownSampleFolder}/${g_Subject}.R.sphere.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.R.sphere.${OutPCARegString}${RegName}.${g_LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${DownSampleFolder}/${g_Subject}.R.midthickness.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.R.midthickness.${g_LowResMesh}k_fs_LR.surf.gii
		NumMaps=$(${Caret7_Command} -file-information ${DownSampleFolder}/${g_Subject}.atlas_Topographic_ROIs.${g_LowResMesh}k_fs_LR.dscalar.nii -only-number-of-maps)
		TopographicWeights=${NativeFolder}/${RegName}/TopographicWeights.txt
		n=1
		while [ ${n} -le ${NumMaps} ] ; do
			echo -n "${n} " >> ${TopographicWeights}
			n=$(( n+1 ))
		done
		inputweights="NONE"
		inputspatialmaps="${DownSampleFolder}/${g_Subject}.atlas_Topographic_ROIs_${RegName}.${g_LowResMesh}k_fs_LR.dscalar.nii"
		outputspatialmaps="${DownSampleFolder}/${g_Subject}.individual_Topography_${RegName}.${g_LowResMesh}k_fs_LR" #No Ext
		outputweights="NONE"
		Params="${NativeFolder}/${RegName}/Params.txt"
		touch ${Params}
		if [[ $(echo -n ${Method} | grep "WR") ]] ; then
			Distortion="${DownSampleT1wFolder}/${g_Subject}.${Hemisphere}.midthickness_va_norm.${g_LowResMesh}k_fs_LR.dscalar.nii"
			echo ${Distortion} > ${Params}
		fi

		case ${g_matlab_run_mode} in

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

				matlab_logging=">> ${g_StudyFolder}/${g_Subject}.MSMregression.matlab.2.log 2>&1"

				matlab_cmd="${matlab_exe} ${matlab_compiler_runtime} ${matlab_function_arguments} ${matlab_logging}"

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
				log_Err_Abort "Unsupported MATLAB run mode value: ${g_matlab_run_mode}"
				;;
		esac

		rm ${Params} ${TopographicWeights} ${DownSampleFolder}/${g_Subject}.atlas_Topographic_ROIs_${RegName}.${g_LowResMesh}k_fs_LR.dscalar.nii

		# Resample the individual maps so they are in the correct space
		log_Msg "Resample the individual maps so they are in the correct space"
		${Caret7_Command} -cifti-resample ${DownSampleFolder}/${g_Subject}.individual_Topography_${RegName}.${g_LowResMesh}k_fs_LR.dscalar.nii COLUMN ${DownSampleFolder}/${g_Subject}.individual_Topography_${RegName}.${g_LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${g_Subject}.individual_Topography_${RegName}.${g_LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${g_Subject}.L.sphere.${OutPCARegString}${RegName}.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.L.sphere.${g_LowResMesh}k_fs_LR.surf.gii -left-area-surfs ${DownSampleFolder}/${g_Subject}.L.midthickness.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.L.midthickness.${g_LowResMesh}k_fs_LR.surf.gii -right-spheres ${DownSampleFolder}/${g_Subject}.R.sphere.${OutPCARegString}${RegName}.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.R.sphere.${g_LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${DownSampleFolder}/${g_Subject}.R.midthickness.${g_LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${g_Subject}.R.midthickness.${g_LowResMesh}k_fs_LR.surf.gii

	fi

# ##rm ${IsRunning}

}

# ------------------------------------------------------------------------------
#  Invoke the main function to get things started
# ------------------------------------------------------------------------------

main "$@"
