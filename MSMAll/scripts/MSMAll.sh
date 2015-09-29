#!/bin/bash

# ------------------------------------------------------------------------------
#  Code Start
# ------------------------------------------------------------------------------
set -e # If any command exit with non-zero value, this script exits
g_script_name=`basename ${0}`

# ------------------------------------------------------------------------------
#  Load function libraries
# ------------------------------------------------------------------------------

source ${HCPPIPEDIR}/global/scripts/log.shlib # Logging related functions
log_SetToolName "${g_script_name}"
log_Debug_On

MATLAB_HOME="/export/matlab/R2013a"
log_Msg "MATLAB_HOME: ${MATLAB_HOME}"

#
# Function Description:
#  TBW
#
usage()
{
	echo ""
	echo "  MSMAll.sh"
	echo ""
	echo " usage TBW"
	echo ""
}

#
# Function Description:
#  Get the command line options for this script
#  Shows usage information and exits if command line is malformed
#
# Global Output Variables
#
#   TBW
#
get_options()
{
	local arguments=($@)

	# initialize global output variables
	unset g_path_to_study_folder # ${StudyFolder}
	unset g_subject              # ${Subject}
	unset g_high_res_mesh        # ${HighResMesh}
	unset g_low_res_mesh         # ${LowResMesh}
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
				g_path_to_study_folder=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--study-folder=*)
				g_path_to_study_folder=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--subject=*)
				g_subject=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--high-res-mesh=*)
				g_high_res_mesh=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--low-res-mesh=*)
				g_low_res_mesh=${argument/*=/""}
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
			--reg-conf-vars=*)
				# Note: since the value of this parameter contains equal signs ("="),
				# we have to handle grabbing the value slightly differently than
				# in the other cases.
				g_reg_conf_vars=${argument#--reg-conf-vars=}
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
		echo "ERROR: subject required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_subject: ${g_subject}"
	fi

	if [ -z "${g_high_res_mesh}" ]; then
		echo "ERROR: high_res_mesh required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_high_res_mesh: ${g_high_res_mesh}"
	fi

	if [ -z "${g_low_res_mesh}" ]; then
		echo "ERROR: low_res_mesh required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_low_res_mesh: ${g_low_res_mesh}"
	fi

	if [ -z "${g_fmri_names_list}" ]; then
		echo "ERROR: fmri_names_list required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_fmri_names_list: ${g_fmri_names_list}"
	fi

	if [ -z "${g_output_fmri_name}" ]; then
		echo "ERROR: output_fmri_name required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_output_fmri_name: ${g_output_fmri_name}"
	fi

	if [ -z "${g_fmri_proc_string}" ]; then
		echo "ERROR: fmri_proc_string required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_fmri_proc_string: ${g_fmri_proc_string}"
	fi

	if [ -z "${g_input_pca_registration_name}" ]; then
		echo "ERROR: input_pca_registration_name required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_input_pca_registration_name: ${g_input_pca_registration_name}"
	fi

	if [ -z "${g_input_registration_name}" ]; then
		echo "ERROR: input_registration_name required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_input_registration_name: ${g_input_registration_name}"
	fi

	if [ -z "${g_registration_name_stem}" ]; then
		echo "ERROR: registration_name_stem required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_registration_name_stem: ${g_registration_name_stem}"
	fi

	if [ -z "${g_rsn_target_file}" ]; then
		echo "ERROR: rsn_target_file required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_rsn_target_file: ${g_rsn_target_file}"
	fi

	if [ -z "${g_rsn_cost_weights}" ]; then
		echo "ERROR: rsn_cost_weights required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_rsn_cost_weights: ${g_rsn_cost_weights}"
	fi

	if [ -z "${g_myelin_target_file}" ]; then
		echo "ERROR: myelin_target_file required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_myelin_target_file: ${g_myelin_target_file}"
	fi

	if [ -z "${g_topography_roi_file}" ]; then
		echo "ERROR: topography_roi_file required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_topography_roi_file: ${g_topography_roi_file}"
	fi

	if [ -z "${g_topography_target_file}" ]; then
		echo "ERROR: topography_target_file required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_topography_target_file: ${g_topography_target_file}"
	fi

	if [ -z "${g_iterations}" ]; then
		echo "ERROR: iterations required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_iterations: ${g_iterations}"
	fi

	if [ -z "${g_method}" ]; then
		echo "ERROR: method required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_method: ${g_method}"
	fi

	if [ -z "${g_use_migp}" ]; then
		echo "ERROR: use_migp required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_use_migp: ${g_use_migp}"
	fi

	if [ -z "${g_ica_dim}" ]; then
		echo "ERROR: ica_dim required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_ica_dim: ${g_ica_dim}"
	fi

	if [ -z "${g_regression_params}" ]; then
		echo "ERROR: regression_params required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_regression_params: ${g_regression_params}"
	fi

	if [ -z "${g_vn}" ]; then
		echo "ERROR: vn required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_vn: ${g_vn}"
	fi

	if [ -z "${g_rerun}" ]; then
		echo "ERROR: rerun required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_rerun: ${g_rerun}"
	fi

	if [ -z "${g_reg_conf}" ]; then
		echo "ERROR: reg_conf required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_reg_conf: ${g_reg_conf}"
	fi

	if [ -z "${g_reg_conf_vars}" ]; then
		echo "ERROR: reg_conf_vars required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_reg_conf_vars: ${g_reg_conf_vars}"
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
	# Show wb_command version
	log_Msg "Showing wb_command version"
	${CARET7DIR}/wb_command -version

	# Show MSMBin
	log_Msg "MSMBin: ${MSMBin}"
}

#
# Function Description:
#  Main processing of script.
#
main()
{
	# Get command line options
	# See documentation for get_options function for global variables set
	get_options $@

	# show the versions of tools used
	show_tool_versions

	Caret7_Command=${CARET7DIR}/wb_command
	log_Msg "Caret7_Command: ${Caret7_Command}"

	StudyFolder="${g_path_to_study_folder}"
	log_Msg "StudyFolder: ${StudyFolder}"

	Subject="${g_subject}"
	log_Msg "Subject: ${Subject}"

	HighResMesh="${g_high_res_mesh}"
	log_Msg "HighResMesh: ${HighResMesh}"

	LowResMesh="${g_low_res_mesh}"
	log_Msg "LowResMesh: ${LowResMesh}"

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

	AtlasFolder="${StudyFolder}/${Subject}/MNINonLinear"
	log_Msg "AtlasFolder: ${AtlasFolder}"

	DownSampleFolder="${AtlasFolder}/fsaverage_LR${LowResMesh}k"
	log_Msg "DownSampleFolder: ${DownSampleFolder}"

	NativeFolder="${AtlasFolder}/Native"
	log_Msg "NativeFolder: ${NativeFolder}"

	ResultsFolder="${AtlasFolder}/Results/${OutputfMRIName}"
	log_Msg "ResultsFolder: ${ResultsFolder}"

	T1wFolder="${StudyFolder}/${Subject}/T1w"
	log_Msg "T1wFolder: ${T1wFolder}"

	DownSampleT1wFolder="${T1wFolder}/fsaverage_LR${LowResMesh}k"
	log_Msg "DownSampleT1wFolder: ${DownSampleT1wFolder}"

	NativeT1wFolder="${T1wFolder}/Native"
	log_Msg "NativeT1wFolder: ${NativeT1wFolder}"

	if [[ `echo -n ${Method} | grep "WR"` ]] ; then
		LowICAdims=`echo ${RegressionParams} | sed 's/_/ /g'`
	fi
	log_Msg "LowICAdims: ${LowICAdims}"

	Iterations=`echo ${Iterations} | sed 's/_/ /g'`
	log_Msg "Iterations: ${Iterations}"

	NumIterations=`echo ${Iterations} | wc -w`
	log_Msg "NumIterations: ${NumIterations}"

	CorrectionSigma=$(echo "sqrt ( 200 )" | bc -l)
	log_Msg "CorrectionSigma: ${CorrectionSigma}"

	BC="NO"
	log_Msg "BC: ${BC}"

	nTPsForSpectra="0" #Set to zero to not compute spectra
	log_Msg "nTPsForSpectra: ${nTPsForSpectra}"

	if [[ ! -e ${NativeFolder}/${Subject}.ArealDistortion_${RegNameStem}_${NumIterations}_d${ICAdim}_${Method}.native.dscalar.nii || ${ReRun} = "YES" ]] ; then 
		
		##IsRunning="${NativeFolder}/${Subject}.IsRunning_${RegNameStem}_${NumIterations}_d${ICAdim}_${Method}.txt"
		##if [ ! -e ${IsRunning} ] ; then
		##  touch ${IsRunning}
		##else
		##  exit
		##fi

		RSNTargetFile=`echo ${RSNTargetFileOrig} | sed "s/REPLACEDIM/${ICAdim}/g"`
		log_Msg "RSNTargetFile: ${RSNTargetFile}"
		log_File_Must_Exist "${RSNTargetFile}"
		
		RSNCostWeights=`echo ${RSNCostWeightsOrig} | sed "s/REPLACEDIM/${ICAdim}/g"`
		log_Msg "RSNCostWeights: ${RSNCostWeights}"
		log_File_Must_Exist "${RSNCostWeights}"

		cp --verbose ${RSNTargetFile} ${DownSampleFolder}/${Subject}.atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.dscalar.nii
		cp --verbose ${MyelinTargetFile} ${DownSampleFolder}/${Subject}.atlas_MyelinMap_BC.${LowResMesh}k_fs_LR.dscalar.nii
		cp --verbose ${TopographyROIFile} ${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs.${LowResMesh}k_fs_LR.dscalar.nii
		cp --verbose ${TopographyTargetFile} ${DownSampleFolder}/${Subject}.atlas_Topography.${LowResMesh}k_fs_LR.dscalar.nii

		if [ ${InPCARegName} = "MSMSulc" ] ; then
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
			${Caret7_Command} -surface-vertex-areas ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_va.${LowResMesh}k_fs_LR.shape.gii 
		done
		${Caret7_Command} -cifti-create-dense-scalar ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_va.${LowResMesh}k_fs_LR.dscalar.nii -left-metric ${DownSampleT1wFolder}/${Subject}.L.midthickness_va.${LowResMesh}k_fs_LR.shape.gii -roi-left ${DownSampleFolder}/${Subject}.L.atlasroi.${LowResMesh}k_fs_LR.shape.gii -right-metric ${DownSampleT1wFolder}/${Subject}.R.midthickness_va.${LowResMesh}k_fs_LR.shape.gii -roi-right ${DownSampleFolder}/${Subject}.R.atlasroi.${LowResMesh}k_fs_LR.shape.gii
		VAMean=`${Caret7_Command} -cifti-stats ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_va.${LowResMesh}k_fs_LR.dscalar.nii -reduce MEAN`
		log_Msg "VAMean: ${VAMean}"

		${Caret7_Command} -cifti-math "VA / ${VAMean}" ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_va_norm.${LowResMesh}k_fs_LR.dscalar.nii -var VA ${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_va.${LowResMesh}k_fs_LR.dscalar.nii
  
		log_Msg "NumIterations: ${NumIterations}"
		i=1
		while [ ${i} -le ${NumIterations} ] ; do
			log_Msg "i: ${i}"
			RegName="${RegNameStem}_${i}_d${ICAdim}_${Method}"
			log_Msg "RegName: ${RegName}"
			Modalities=`echo ${Iterations} | cut -d " " -f ${i}`
			log_Msg "Modalities: ${Modalities}"

			if [ ! -e ${NativeFolder}/${RegName} ] ; then
				mkdir --verbose ${NativeFolder}/${RegName}
			else 
				rm -r ${NativeFolder}/${RegName}
				mkdir --verbose ${NativeFolder}/${RegName}
			fi

			if [[ `echo -n ${Modalities} | grep "C"` || `echo -n ${Modalities} | grep "T"` ]] ; then
				for Hemisphere in L R ; do
					${Caret7_Command} -surface-sphere-project-unproject ${DownSampleFolder}/${Subject}.${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${InPCARegString}.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${InRegName}.native.surf.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.sphere.${OutPCARegString}${InRegName}.${LowResMesh}k_fs_LR.surf.gii      
				done

				if [ ${UseMIGP} = "YES" ] ; then
					inputdtseries="${ResultsFolder}/${OutputfMRIName}${fMRIProcSTRING}_PCA${PCARegString}.dtseries.nii"
				else
					inputdtseries="${ResultsFolder}/${OutputfMRIName}${fMRIProcSTRING}${PCARegString}.dtseries.nii"
				fi
			fi
    
			if [[ `echo -n ${Modalities} | grep "C"` ]] ; then   
				log_Msg "Modalities includes C"
				log_Msg "Resample the atlas instead of the timeseries"
				${Caret7_Command} -cifti-resample ${DownSampleFolder}/${Subject}.atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ${DownSampleFolder}/${Subject}.atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${Subject}.atlas_RSNs_d${ICAdim}_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${Subject}.L.sphere.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.sphere.${OutPCARegString}${InRegName}.${LowResMesh}k_fs_LR.surf.gii -left-area-surfs ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii -right-spheres ${DownSampleFolder}/${Subject}.R.sphere.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.sphere.${OutPCARegString}${InRegName}.${LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii
      
				NumValidRSNs=`cat ${RSNCostWeights} | wc -w`
				inputweights="${RSNCostWeights}"
				inputspatialmaps="${DownSampleFolder}/${Subject}.atlas_RSNs_d${ICAdim}_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii"
				outputspatialmaps="${DownSampleFolder}/${Subject}.individual_RSNs_d${ICAdim}_${InRegName}.${LowResMesh}k_fs_LR" #No Ext
				outputweights="${DownSampleFolder}/${Subject}.individual_RSNs_d${ICAdim}_weights.${LowResMesh}k_fs_LR.dscalar.nii"
				Params="${NativeFolder}/${RegName}/Params.txt"
				touch ${Params}
				if [[ `echo -n ${Method} | grep "WR"` ]] ; then
					Distortion="${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_va_norm.${LowResMesh}k_fs_LR.dscalar.nii"
					echo ${Distortion} > ${Params}
					LeftSurface="${DownSampleT1wFolder}/${Subject}.L.midthickness${SurfRegSTRING}.${LowResMesh}k_fs_LR.surf.gii"
					echo ${LeftSurface} >> ${Params}
					RightSurface="${DownSampleT1wFolder}/${Subject}.R.midthickness${SurfRegSTRING}.${LowResMesh}k_fs_LR.surf.gii"
					echo ${RightSurface} >> ${Params}        
					for LowICAdim in ${LowICAdims} ; do
						LowDim=`echo ${RSNTargetFileOrig} | sed "s/REPLACEDIM/${LowICAdim}/g"`
						echo ${LowDim} >> ${Params}
					done
				fi

				matlab_exe="${HCPPIPEDIR}"
				matlab_exe+="/MSMAll/scripts/Compiled_MSMregression/distrib/run_MSMregression.sh"
				
				matlab_compiler_runtime="${MATLAB_HOME}/MCR"

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

				matlab_logging=">> ${StudyFolder}/${Subject}.MSMregression.matlab.C.Iteration${i}.log 2>&1"

				matlab_cmd="${matlab_exe} ${matlab_compiler_runtime} ${matlab_function_arguments} ${matlab_logging}"

				# --------------------------------------------------------------------------------
				log_Msg "Run Matlab command: ${matlab_cmd}"
				# --------------------------------------------------------------------------------

				echo "${matlab_cmd}" | bash
				echo "Matlab command return code: $?"

				rm ${Params} ${DownSampleFolder}/${Subject}.atlas_RSNs_d${ICAdim}_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii

				# Resample the individual maps so they are in the correct space
				log_Msg "Resample the individual maps so they are in the correct space"
				${Caret7_Command} -cifti-resample ${DownSampleFolder}/${Subject}.individual_RSNs_d${ICAdim}_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ${DownSampleFolder}/${Subject}.individual_RSNs_d${ICAdim}_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${Subject}.individual_RSNs_d${ICAdim}_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${Subject}.L.sphere.${OutPCARegString}${InRegName}.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.sphere.${LowResMesh}k_fs_LR.surf.gii  -left-area-surfs ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii -right-spheres ${DownSampleFolder}/${Subject}.R.sphere.${OutPCARegString}${InRegName}.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.sphere.${LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii
    
				${Caret7_Command} -cifti-separate-all ${DownSampleFolder}/${Subject}.individual_RSNs_d${ICAdim}_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii -left ${DownSampleFolder}/${Subject}.L.individual_RSNs_d${ICAdim}_${InRegName}.${LowResMesh}k_fs_LR.func.gii -right ${DownSampleFolder}/${Subject}.R.individual_RSNs_d${ICAdim}_${InRegName}.${LowResMesh}k_fs_LR.func.gii
				${Caret7_Command} -cifti-separate-all ${DownSampleFolder}/${Subject}.atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.dscalar.nii -left ${DownSampleFolder}/${Subject}.L.atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.func.gii -right ${DownSampleFolder}/${Subject}.R.atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.func.gii
				${Caret7_Command} -cifti-separate-all ${DownSampleFolder}/${Subject}.individual_RSNs_d${ICAdim}_weights.${LowResMesh}k_fs_LR.dscalar.nii -left ${DownSampleFolder}/${Subject}.L.individual_RSNs_d${ICAdim}_weights.${LowResMesh}k_fs_LR.func.gii -right ${DownSampleFolder}/${Subject}.R.individual_RSNs_d${ICAdim}_weights.${LowResMesh}k_fs_LR.func.gii

			fi

			if [[ `echo -n ${Modalities} | grep "A"` ]] ; then
				echo "Modalities includes A"
				${Caret7_Command} -cifti-resample ${NativeFolder}/${Subject}.MyelinMap.native.dscalar.nii COLUMN ${DownSampleFolder}/${Subject}.MyelinMap.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${Subject}.MyelinMap_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${NativeFolder}/${Subject}.L.sphere.${InRegName}.native.surf.gii ${DownSampleFolder}/${Subject}.L.sphere.${LowResMesh}k_fs_LR.surf.gii -left-area-surfs ${NativeT1wFolder}/${Subject}.L.midthickness.native.surf.gii ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii -right-spheres ${NativeFolder}/${Subject}.R.sphere.${InRegName}.native.surf.gii ${DownSampleFolder}/${Subject}.R.sphere.${LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${NativeT1wFolder}/${Subject}.R.midthickness.native.surf.gii ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii
				${Caret7_Command} -cifti-math "Individual - Reference" ${DownSampleFolder}/${Subject}.BiasField_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii -var Individual ${DownSampleFolder}/${Subject}.MyelinMap_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii -var Reference ${DownSampleFolder}/${Subject}.atlas_MyelinMap_BC.${LowResMesh}k_fs_LR.dscalar.nii
				${Caret7_Command} -cifti-smoothing ${DownSampleFolder}/${Subject}.BiasField_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii ${CorrectionSigma} 0 COLUMN ${DownSampleFolder}/${Subject}.BiasField_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii -left-surface ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii -right-surface ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii
				${Caret7_Command} -cifti-separate-all ${DownSampleFolder}/${Subject}.BiasField_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii -left ${DownSampleFolder}/${Subject}.L.BiasField_${InRegName}.${LowResMesh}k_fs_LR.func.gii -right ${DownSampleFolder}/${Subject}.R.BiasField_${InRegName}.${LowResMesh}k_fs_LR.func.gii
				${Caret7_Command} -cifti-separate-all ${DownSampleFolder}/${Subject}.atlas_MyelinMap_BC.${LowResMesh}k_fs_LR.dscalar.nii -left ${DownSampleFolder}/${Subject}.L.atlas_MyelinMap_BC.${LowResMesh}k_fs_LR.func.gii -right ${DownSampleFolder}/${Subject}.R.atlas_MyelinMap_BC.${LowResMesh}k_fs_LR.func.gii
			fi
    
			if [[ `echo -n ${Modalities} | grep "T"` ]] ; then
				# Resample the atlas instead of the timeseries
				log_Msg "Modalities includes T"
				log_Msg "Resample the atlas instead of the timeseries"
				${Caret7_Command} -cifti-resample ${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${Subject}.L.sphere.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.sphere.${OutPCARegString}${InRegName}.${LowResMesh}k_fs_LR.surf.gii -left-area-surfs ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii -right-spheres ${DownSampleFolder}/${Subject}.R.sphere.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.sphere.${OutPCARegString}${InRegName}.${LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii
				NumMaps=`${Caret7_Command} -file-information ${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs.${LowResMesh}k_fs_LR.dscalar.nii -only-number-of-maps`
				TopographicWeights=${NativeFolder}/${RegName}/TopographicWeights.txt
				n=1
				while [ ${n} -le ${NumMaps} ] ; do
					echo -n "${n} " >> ${TopographicWeights}
					n=$((${n}+1))
				done
				inputweights="${TopographicWeights}"
				inputspatialmaps="${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii"
				outputspatialmaps="${DownSampleFolder}/${Subject}.individual_Topography_${InRegName}.${LowResMesh}k_fs_LR" #No Ext
				outputweights="${DownSampleFolder}/${Subject}.individual_Topography_weights.${LowResMesh}k_fs_LR.dscalar.nii"
				Params="${NativeFolder}/${RegName}/Params.txt"
				touch ${Params}
				if [[ `echo -n ${Method} | grep "WR"` ]] ; then
					Distortion="${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_va_norm.${LowResMesh}k_fs_LR.dscalar.nii"
					echo ${Distortion} > ${Params}
				fi

				matlab_exe="${HCPPIPEDIR}"
				matlab_exe+="/MSMAll/scripts/Compiled_MSMregression/distrib/run_MSMregression.sh"

				matlab_compiler_runtime="${MATLAB_HOME}/MCR"

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

				matlab_logging=">> ${StudyFolder}/${Subject}.MSMregression.matlab.T.Iteration${i}.log 2>&1"

				matlab_cmd="${matlab_exe} ${matlab_compiler_runtime} ${matlab_function_arguments} ${matlab_logging}"

				# --------------------------------------------------------------------------------
				log_Msg "Run Matlab command: ${matlab_cmd}"
				# --------------------------------------------------------------------------------

				echo "${matlab_cmd}" | bash
				echo "Matlab command return code: $?"

				rm ${Params} ${TopographicWeights} ${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii

				# Resample the individual maps so they are in the correct space
				log_Msg "Resample the individual maps so they are in the correct space"
				${Caret7_Command} -cifti-resample ${DownSampleFolder}/${Subject}.individual_Topography_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ${DownSampleFolder}/${Subject}.individual_Topography_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${Subject}.individual_Topography_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${Subject}.L.sphere.${OutPCARegString}${InRegName}.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.sphere.${LowResMesh}k_fs_LR.surf.gii  -left-area-surfs ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii -right-spheres ${DownSampleFolder}/${Subject}.R.sphere.${OutPCARegString}${InRegName}.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.sphere.${LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii
    
				${Caret7_Command} -cifti-math "Weights - (V1 > 0)" ${DownSampleFolder}/${Subject}.individual_Topography_weights.${LowResMesh}k_fs_LR.dscalar.nii -var V1 ${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs.${LowResMesh}k_fs_LR.dscalar.nii -select 1 8 -repeat -var Weights ${DownSampleFolder}/${Subject}.individual_Topography_weights.${LowResMesh}k_fs_LR.dscalar.nii
    
				${Caret7_Command} -cifti-separate-all ${DownSampleFolder}/${Subject}.individual_Topography_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii -left ${DownSampleFolder}/${Subject}.L.individual_Topography_${InRegName}.${LowResMesh}k_fs_LR.func.gii -right ${DownSampleFolder}/${Subject}.R.individual_Topography_${InRegName}.${LowResMesh}k_fs_LR.func.gii
				${Caret7_Command} -cifti-separate-all ${DownSampleFolder}/${Subject}.atlas_Topography.${LowResMesh}k_fs_LR.dscalar.nii -left ${DownSampleFolder}/${Subject}.L.atlas_Topography.${LowResMesh}k_fs_LR.func.gii -right ${DownSampleFolder}/${Subject}.R.atlas_Topography.${LowResMesh}k_fs_LR.func.gii
				${Caret7_Command} -cifti-separate-all ${DownSampleFolder}/${Subject}.individual_Topography_weights.${LowResMesh}k_fs_LR.dscalar.nii -left ${DownSampleFolder}/${Subject}.L.individual_Topography_weights.${LowResMesh}k_fs_LR.func.gii -right ${DownSampleFolder}/${Subject}.R.individual_Topography_weights.${LowResMesh}k_fs_LR.func.gii
			fi

			##for Hemisphere in L R ; do 
			function RegHemi {
				Hemisphere="${1}"
				if [ $Hemisphere = "L" ] ; then 
					Structure="CORTEX_LEFT"
				elif [ $Hemisphere = "R" ] ; then 
					Structure="CORTEX_RIGHT"
				fi  
				
				log_Msg "RegHemi - Hemisphere: ${Hemisphere}"
				log_Msg "RegHemi - Structure:  ${Structure}"
				log_Msg "RegHemi - Modalities: ${Modalities}"

				if [[ `echo -n ${Modalities} | grep "C"` ]] ; then
					log_Msg "RegHemi - Modalities contains C"
					${Caret7_Command} -metric-resample ${DownSampleFolder}/${Subject}.${Hemisphere}.individual_RSNs_d${ICAdim}_${InRegName}.${LowResMesh}k_fs_LR.func.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${InRegName}.native.surf.gii ADAP_BARY_AREA ${NativeFolder}/${Subject}.${Hemisphere}.individual_RSNs_d${ICAdim}_${InRegName}.native.func.gii -area-surfs ${DownSampleFolder}/${Subject}.${Hemisphere}.midthickness.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.midthickness.native.surf.gii -current-roi ${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii -valid-roi-out ${NativeFolder}/${Subject}.${Hemisphere}.${InRegName}_roi.native.shape.gii 
					${Caret7_Command} -metric-resample ${DownSampleFolder}/${Subject}.${Hemisphere}.individual_RSNs_d${ICAdim}_weights.${LowResMesh}k_fs_LR.func.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${InRegName}.native.surf.gii ADAP_BARY_AREA ${NativeFolder}/${Subject}.${Hemisphere}.individual_RSNs_d${ICAdim}_weights.native.func.gii -area-surfs ${DownSampleFolder}/${Subject}.${Hemisphere}.midthickness.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.midthickness.native.surf.gii -current-roi ${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii -valid-roi-out ${NativeFolder}/${Subject}.${Hemisphere}.${InRegName}_roi.native.shape.gii -largest

					${Caret7_Command} -metric-resample ${DownSampleFolder}/${Subject}.${Hemisphere}.atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.func.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${InRegName}.native.surf.gii ADAP_BARY_AREA ${NativeFolder}/${Subject}.${Hemisphere}.atlas_RSNs_d${ICAdim}.native.func.gii -area-surfs ${DownSampleFolder}/${Subject}.${Hemisphere}.midthickness.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.midthickness.native.surf.gii -current-roi ${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii -valid-roi-out ${NativeFolder}/${Subject}.${Hemisphere}.${InRegName}_roi.native.shape.gii 
				fi

				if [[ `echo -n ${Modalities} | grep "A"` ]] ; then   
					log_Msg "RegHemi - Modalities contains A"
					${Caret7_Command} -metric-resample ${DownSampleFolder}/${Subject}.${Hemisphere}.BiasField_${InRegName}.${LowResMesh}k_fs_LR.func.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${InRegName}.native.surf.gii ADAP_BARY_AREA ${NativeFolder}/${Subject}.${Hemisphere}.BiasField_${InRegName}.native.func.gii -area-surfs ${DownSampleFolder}/${Subject}.${Hemisphere}.midthickness.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.midthickness.native.surf.gii -current-roi ${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii -valid-roi-out ${NativeFolder}/${Subject}.${Hemisphere}.${InRegName}_roi.native.shape.gii        
				fi

				if [[ `echo -n ${Modalities} | grep "T"` ]] ; then   
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
				for Modality in `echo ${Modalities} | sed 's/\(.\)/\1 /g'` ; do
					log_Msg "RegHemi - n: ${n}"
					if [ ${Modality} = "C" ] ; then
						log_Msg "RegHemi - Modality: ${Modality}"
						${Caret7_Command} -metric-math "Var * ROI" ${DownSampleFolder}/${Subject}.${Hemisphere}.norm_atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.func.gii -var Var ${DownSampleFolder}/${Subject}.${Hemisphere}.atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.func.gii -var ROI ${DownSampleFolder}/${Subject}.${Hemisphere}.individual_RSNs_d${ICAdim}_weights.${LowResMesh}k_fs_LR.func.gii
						SDEVs=`${Caret7_Command} -metric-stats ${DownSampleFolder}/${Subject}.${Hemisphere}.norm_atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.func.gii -reduce STDEV`
						SDEVs=`echo ${SDEVs} | sed 's/ / + /g' | bc -l`
						MeanSDEV=`echo "${SDEVs} / ${NumValidRSNs}" | bc -l`
						${Caret7_Command} -metric-math "Var / ${MeanSDEV}" ${DownSampleFolder}/${Subject}.${Hemisphere}.norm_atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.func.gii -var Var ${DownSampleFolder}/${Subject}.${Hemisphere}.atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.func.gii
						${Caret7_Command} -metric-math "Var / ${MeanSDEV}" ${NativeFolder}/${Subject}.${Hemisphere}.norm_individual_RSNs_d${ICAdim}_${InRegName}.native.func.gii -var Var ${NativeFolder}/${Subject}.${Hemisphere}.individual_RSNs_d${ICAdim}_${InRegName}.native.func.gii
						NativeMetricMerge=`echo "${NativeMetricMerge} -metric ${NativeFolder}/${Subject}.${Hemisphere}.norm_individual_RSNs_d${ICAdim}_${InRegName}.native.func.gii"`
						NativeWeightsMerge=`echo "${NativeWeightsMerge} -metric ${NativeFolder}/${Subject}.${Hemisphere}.individual_RSNs_d${ICAdim}_weights.native.func.gii"`
						AtlasMetricMerge=`echo "${AtlasMetricMerge} -metric ${DownSampleFolder}/${Subject}.${Hemisphere}.norm_atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.func.gii"`
						AtlasWeightsMerge=`echo "${AtlasWeightsMerge} -metric ${DownSampleFolder}/${Subject}.${Hemisphere}.individual_RSNs_d${ICAdim}_weights.${LowResMesh}k_fs_LR.func.gii"`
					elif [ ${Modality} = "A" ] ; then
						log_Msg "RegHemi - Modality: ${Modality}"
						###Renormalize individual map?
						${Caret7_Command} -metric-math "Var * ROI" ${DownSampleFolder}/${Subject}.${Hemisphere}.norm_MyelinMap_BC.${LowResMesh}k_fs_LR.func.gii -var Var ${DownSampleFolder}/${Subject}.${Hemisphere}.atlas_MyelinMap_BC.${LowResMesh}k_fs_LR.func.gii -var ROI ${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii
						SDEVs=`${Caret7_Command} -metric-stats ${DownSampleFolder}/${Subject}.${Hemisphere}.norm_MyelinMap_BC.${LowResMesh}k_fs_LR.func.gii -reduce STDEV`
						SDEVs=`echo ${SDEVs} | sed 's/ / + /g' | bc -l`
						MeanSDEV=`echo "${SDEVs} / 1" | bc -l`
						${Caret7_Command} -metric-math "Var / ${MeanSDEV}" ${DownSampleFolder}/${Subject}.${Hemisphere}.norm_atlas_MyelinMap_BC.${LowResMesh}k_fs_LR.func.gii -var Var ${DownSampleFolder}/${Subject}.${Hemisphere}.atlas_MyelinMap_BC.${LowResMesh}k_fs_LR.func.gii
						${Caret7_Command} -metric-math "(Var - Bias) / ${MeanSDEV}" ${NativeFolder}/${Subject}.${Hemisphere}.norm_MyelinMap_BC_${InRegName}.native.func.gii -var Var ${NativeFolder}/${Subject}.${Hemisphere}.MyelinMap.native.func.gii -var Bias ${NativeFolder}/${Subject}.${Hemisphere}.BiasField_${InRegName}.native.func.gii
						NativeMetricMerge=`echo "${NativeMetricMerge} -metric ${NativeFolder}/${Subject}.${Hemisphere}.norm_MyelinMap_BC_${InRegName}.native.func.gii"` 
						NativeWeightsMerge=`echo "${NativeWeightsMerge} -metric ${NativeFolder}/${Subject}.${Hemisphere}.${InRegName}_roi.native.shape.gii"` 
						AtlasMetricMerge=`echo "${AtlasMetricMerge} -metric ${DownSampleFolder}/${Subject}.${Hemisphere}.norm_atlas_MyelinMap_BC.${LowResMesh}k_fs_LR.func.gii"` 
						AtlasWeightsMerge=`echo "${AtlasWeightsMerge} -metric ${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii"` 
					elif [ ${Modality} = "T" ] ; then
						log_Msg "RegHemi - Modality: ${Modality}"
						${Caret7_Command} -metric-math "Var * ROI" ${DownSampleFolder}/${Subject}.${Hemisphere}.norm_atlas_Topography.${LowResMesh}k_fs_LR.func.gii -var Var ${DownSampleFolder}/${Subject}.${Hemisphere}.atlas_Topography.${LowResMesh}k_fs_LR.func.gii -var ROI ${DownSampleFolder}/${Subject}.${Hemisphere}.individual_Topography_weights.${LowResMesh}k_fs_LR.func.gii
						SDEVs=`${Caret7_Command} -metric-stats ${DownSampleFolder}/${Subject}.${Hemisphere}.norm_atlas_Topography.${LowResMesh}k_fs_LR.func.gii -reduce STDEV`
						SDEVs=`echo ${SDEVs} | sed 's/ / + /g' | bc -l`
						MeanSDEV=`echo "${SDEVs} / 1" | bc -l`
						${Caret7_Command} -metric-math "Var / ${MeanSDEV}" ${DownSampleFolder}/${Subject}.${Hemisphere}.norm_atlas_Topography.${LowResMesh}k_fs_LR.func.gii -var Var ${DownSampleFolder}/${Subject}.${Hemisphere}.atlas_Topography.${LowResMesh}k_fs_LR.func.gii
						${Caret7_Command} -metric-math "Var / ${MeanSDEV}" ${NativeFolder}/${Subject}.${Hemisphere}.norm_individual_Topography_${InRegName}.native.func.gii -var Var ${NativeFolder}/${Subject}.${Hemisphere}.individual_Topography_${InRegName}.native.func.gii
						NativeMetricMerge=`echo "${NativeMetricMerge} -metric ${NativeFolder}/${Subject}.${Hemisphere}.norm_individual_Topography_${InRegName}.native.func.gii"` 
						NativeWeightsMerge=`echo "${NativeWeightsMerge} -metric ${NativeFolder}/${Subject}.${Hemisphere}.individual_Topography_weights.native.func.gii"` 
						AtlasMetricMerge=`echo "${AtlasMetricMerge} -metric ${DownSampleFolder}/${Subject}.${Hemisphere}.norm_atlas_Topography.${LowResMesh}k_fs_LR.func.gii"` 
						AtlasWeightsMerge=`echo "${AtlasWeightsMerge} -metric ${DownSampleFolder}/${Subject}.${Hemisphere}.individual_Topography_weights.${LowResMesh}k_fs_LR.func.gii"` 
					fi
					if [ ${n} -eq "1" ] ; then
						NormSDEV=${MeanSDEV}
					fi
					n=$((${n}+1))
				done
      
				log_Debug_Msg "RegHemi 1"
				${Caret7_Command} -metric-merge ${NativeFolder}/${Subject}.${Hemisphere}.Modalities_${i}_${InRegName}.native.func.gii ${NativeMetricMerge} -metric ${NativeFolder}/${Subject}.${Hemisphere}.${InRegName}_roi_inv.native.shape.gii
				${Caret7_Command} -metric-merge ${NativeFolder}/${Subject}.${Hemisphere}.Modalities_${i}_weights.native.func.gii ${NativeWeightsMerge} -metric ${NativeFolder}/${Subject}.${Hemisphere}.${InRegName}_roi_inv.native.shape.gii
				${Caret7_Command} -metric-merge ${DownSampleFolder}/${Subject}.${Hemisphere}.Modalities_${i}.${LowResMesh}k_fs_LR.func.gii ${AtlasMetricMerge} -metric ${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi_inv.${LowResMesh}k_fs_LR.shape.gii
				${Caret7_Command} -metric-merge ${DownSampleFolder}/${Subject}.${Hemisphere}.Modalities_${i}_weights.${LowResMesh}k_fs_LR.func.gii ${AtlasWeightsMerge} -metric ${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi_inv.${LowResMesh}k_fs_LR.shape.gii

				log_Debug_Msg "RegHemi 2"
				${Caret7_Command} -metric-math "Modalities * Weights * ${NormSDEV}" ${NativeFolder}/${Subject}.${Hemisphere}.Modalities_${i}_${InRegName}.native.func.gii -var Modalities ${NativeFolder}/${Subject}.${Hemisphere}.Modalities_${i}_${InRegName}.native.func.gii -var Weights ${NativeFolder}/${Subject}.${Hemisphere}.Modalities_${i}_weights.native.func.gii     
				${Caret7_Command} -metric-math "Modalities * Weights * ${NormSDEV}" ${DownSampleFolder}/${Subject}.${Hemisphere}.Modalities_${i}.${LowResMesh}k_fs_LR.func.gii -var Modalities ${DownSampleFolder}/${Subject}.${Hemisphere}.Modalities_${i}.${LowResMesh}k_fs_LR.func.gii -var Weights ${DownSampleFolder}/${Subject}.${Hemisphere}.Modalities_${i}_weights.${LowResMesh}k_fs_LR.func.gii
      
				MEANs=`${Caret7_Command} -metric-stats ${DownSampleFolder}/${Subject}.${Hemisphere}.Modalities_${i}_weights.${LowResMesh}k_fs_LR.func.gii -reduce MEAN`
				Native=""
				NativeWeights=""
				Atlas=""
				AtlasWeights=""
				j=1
				for MEAN in ${MEANs} ; do
					log_Debug_Msg "RegHemi j: ${j}"
					if [ ! ${MEAN} = 0 ] ; then
						Native=`echo "${Native} -metric ${NativeFolder}/${Subject}.${Hemisphere}.Modalities_${i}_${InRegName}.native.func.gii -column ${j}"`
						NativeWeights=`echo "${NativeWeights} -metric ${NativeFolder}/${Subject}.${Hemisphere}.Modalities_${i}_weights.native.func.gii -column ${j}"`
						Atlas=`echo "${Atlas} -metric ${DownSampleFolder}/${Subject}.${Hemisphere}.Modalities_${i}.${LowResMesh}k_fs_LR.func.gii -column ${j}"`
						AtlasWeights=`echo "${AtlasWeights} -metric ${DownSampleFolder}/${Subject}.${Hemisphere}.Modalities_${i}_weights.${LowResMesh}k_fs_LR.func.gii -column ${j}"`
					fi
					j=$((${j}+1))
				done
      
				log_Debug_Msg "RegHemi 3"
				$Caret7_Command -metric-merge ${NativeFolder}/${Subject}.${Hemisphere}.Modalities_${i}_${InRegName}.native.func.gii ${Native}
				$Caret7_Command -metric-merge ${NativeFolder}/${Subject}.${Hemisphere}.Modalities_${i}_weights.native.func.gii ${NativeWeights}
				$Caret7_Command -metric-merge ${DownSampleFolder}/${Subject}.${Hemisphere}.Modalities_${i}.${LowResMesh}k_fs_LR.func.gii ${Atlas}
				$Caret7_Command -metric-merge ${DownSampleFolder}/${Subject}.${Hemisphere}.Modalities_${i}_weights.${LowResMesh}k_fs_LR.func.gii ${AtlasWeights}

				DIR=`pwd`
				cd ${NativeFolder}/${RegName}

				log_Debug_Msg "RegConf: ${RegConf}"
				log_Debug_Msg "i: ${i}"

				log_File_Must_Exist "${RegConf}_${i}"
				cp ${RegConf}_${i} ${NativeFolder}/${RegName}/conf.${Hemisphere}
				log_File_Must_Exist "${NativeFolder}/${RegName}/conf.${Hemisphere}"

				if [ ! ${RegConfVars} = "NONE" ] ; then
					log_Debug_Msg "RegConfVars not equal to NONE"
					log_Debug_Msg "RegConfVars: ${RegConfVars}"
					RegConfVars=`echo ${RegConfVars} | sed 's/,/ /g'`

					log_Debug_Msg "RegConfVars: ${RegConfVars}"
					log_Debug_Msg "Before substitution"
					log_Debug_Cat ${NativeFolder}/${RegName}/conf.${Hemisphere}

					for RegConfVar in ${RegConfVars} ; do
						mv -f ${NativeFolder}/${RegName}/conf.${Hemisphere} ${NativeFolder}/${RegName}/confbak.${Hemisphere}
						STRING=`echo ${RegConfVar} | cut -d "=" -f 1`
						Var=`echo ${RegConfVar} | cut -d "=" -f 2`
						cat ${NativeFolder}/${RegName}/confbak.${Hemisphere} | sed s/${STRING}/${Var}/g > ${NativeFolder}/${RegName}/conf.${Hemisphere}
					done

					log_Debug_Msg "After substitution"
					log_Debug_Cat ${NativeFolder}/${RegName}/conf.${Hemisphere}

					rm ${NativeFolder}/${RegName}/confbak.${Hemisphere}
					RegConfVars=`echo ${RegConfVars} | sed 's/ /,/g'`
				fi

				log_Debug_Msg "RegHemi 4"

				msm_configuration_file="${NativeFolder}/${RegName}/conf.${Hemisphere}"
				log_File_Must_Exist "${msm_configuration_file}"

				# MSMOut=`${MSMBin}/msm --conf=${msm_configuration_file} --inmesh=${NativeFolder}/${Subject}.${Hemisphere}.sphere.rot.native.surf.gii --trans=${NativeFolder}/${Subject}.${Hemisphere}.sphere.${InPCARegName}.native.surf.gii --refmesh=${DownSampleFolder}/${Subject}.${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii --indata=${NativeFolder}/${Subject}.${Hemisphere}.Modalities_${i}_${InRegName}.native.func.gii --inweight=${NativeFolder}/${Subject}.${Hemisphere}.Modalities_${i}_weights.native.func.gii --refdata=${DownSampleFolder}/${Subject}.${Hemisphere}.Modalities_${i}.${LowResMesh}k_fs_LR.func.gii --refweight=${DownSampleFolder}/${Subject}.${Hemisphere}.Modalities_${i}_weights.${LowResMesh}k_fs_LR.func.gii --out=${NativeFolder}/${RegName}/${Hemisphere}. --verbose --debug 2>&1`

				${MSMBin}/msm --conf=${msm_configuration_file} --inmesh=${NativeFolder}/${Subject}.${Hemisphere}.sphere.rot.native.surf.gii --trans=${NativeFolder}/${Subject}.${Hemisphere}.sphere.${InPCARegName}.native.surf.gii --refmesh=${DownSampleFolder}/${Subject}.${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii --indata=${NativeFolder}/${Subject}.${Hemisphere}.Modalities_${i}_${InRegName}.native.func.gii --inweight=${NativeFolder}/${Subject}.${Hemisphere}.Modalities_${i}_weights.native.func.gii --refdata=${DownSampleFolder}/${Subject}.${Hemisphere}.Modalities_${i}.${LowResMesh}k_fs_LR.func.gii --refweight=${DownSampleFolder}/${Subject}.${Hemisphere}.Modalities_${i}_weights.${LowResMesh}k_fs_LR.func.gii --out=${NativeFolder}/${RegName}/${Hemisphere}. --verbose --debug 2>&1
				MSMOut=$?
				log_Debug_Msg "MSMOut: ${MSMOut}"

				cd $DIR

				log_File_Must_Exist "${NativeFolder}/${RegName}/${Hemisphere}.sphere.reg.surf.gii"
				cp ${NativeFolder}/${RegName}/${Hemisphere}.sphere.reg.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii
				log_File_Must_Exist "${NativeFolder}/${Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii"

				${Caret7_Command} -set-structure ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii ${Structure}
				echo "${MSMOut}"
			}

			for Hemisphere in L R ; do
				log_Msg "About to call RegHemi with Hemisphere: ${Hemisphere}"
				# Starting the jobs for the two hemispheres in the background (&) and using
				# wait for them to finish makes debugging somewhat difficult.
				#
				# RegHemi ${Hemisphere} &
				RegHemi ${Hemisphere}
				log_Msg "Called RegHemi"
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
			i=$(($i+1))
		done


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
		done

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
				##if [[ ${Map} = "ArealDistortion" || ${Map} = "EdgeDistortion" ]] ; then
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
		if [[ `echo -n ${Method} | grep "WR"` ]] ; then
			Distortion="${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_va_norm.${LowResMesh}k_fs_LR.dscalar.nii"
			echo ${Distortion} > ${Params}
			LeftSurface="${DownSampleT1wFolder}/${Subject}.L.midthickness_${RegName}.${LowResMesh}k_fs_LR.surf.gii"
			echo ${LeftSurface} >> ${Params}
			RightSurface="${DownSampleT1wFolder}/${Subject}.R.midthickness_${RegName}.${LowResMesh}k_fs_LR.surf.gii"
			echo ${RightSurface} >> ${Params}        
			for LowICAdim in ${LowICAdims} ; do
				LowDim=`echo ${RSNTargetFileOrig} | sed "s/REPLACEDIM/${LowICAdim}/g"`
				echo ${LowDim} >> ${Params}
			done
		fi

		matlab_exe="${HCPPIPEDIR}"
		matlab_exe+="/MSMAll/scripts/Compiled_MSMregression/distrib/run_MSMregression.sh"

		matlab_compiler_runtime="${MATLAB_HOME}/MCR"

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

		matlab_logging=">> ${StudyFolder}/${Subject}.MSMregression.matlab.1.log 2>&1"

		matlab_cmd="${matlab_exe} ${matlab_compiler_runtime} ${matlab_function_arguments} ${matlab_logging}"

		# --------------------------------------------------------------------------------
		log_Msg "Run Matlab command: ${matlab_cmd}"
		# --------------------------------------------------------------------------------

		echo "${matlab_cmd}" | bash
		echo "Matlab command return code: $?"

		rm ${Params} ${DownSampleFolder}/${Subject}.atlas_RSNs_d${ICAdim}_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii

		# Resample the individual maps so they are in the correct space
		log_Msg "Resample the individual maps so they are in the correct space"
		${Caret7_Command} -cifti-resample ${DownSampleFolder}/${Subject}.individual_RSNs_d${ICAdim}_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ${DownSampleFolder}/${Subject}.individual_RSNs_d${ICAdim}_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${Subject}.individual_RSNs_d${ICAdim}_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${Subject}.L.sphere.${OutPCARegString}${RegName}.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.sphere.${LowResMesh}k_fs_LR.surf.gii  -left-area-surfs ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii -right-spheres ${DownSampleFolder}/${Subject}.R.sphere.${OutPCARegString}${RegName}.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.sphere.${LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii


		# Resample the atlas instead of the timeseries
		log_Msg "Resample the atlas instead of the timeseries"
		${Caret7_Command} -cifti-resample ${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${Subject}.L.sphere.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.sphere.${OutPCARegString}${RegName}.${LowResMesh}k_fs_LR.surf.gii -left-area-surfs ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii -right-spheres ${DownSampleFolder}/${Subject}.R.sphere.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.sphere.${OutPCARegString}${RegName}.${LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii
		NumMaps=`${Caret7_Command} -file-information ${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs.${LowResMesh}k_fs_LR.dscalar.nii -only-number-of-maps`
		TopographicWeights=${NativeFolder}/${RegName}/TopographicWeights.txt
		n=1
		while [ ${n} -le ${NumMaps} ] ; do
			echo -n "${n} " >> ${TopographicWeights}
			n=$((${n}+1))
		done
		inputweights="NONE"
		inputspatialmaps="${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii"
		outputspatialmaps="${DownSampleFolder}/${Subject}.individual_Topography_${RegName}.${LowResMesh}k_fs_LR" #No Ext
		outputweights="NONE"
		Params="${NativeFolder}/${RegName}/Params.txt"
		touch ${Params}
		if [[ `echo -n ${Method} | grep "WR"` ]] ; then
			Distortion="${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_va_norm.${LowResMesh}k_fs_LR.dscalar.nii"
			echo ${Distortion} > ${Params}
		fi

		matlab_exe="${HCPPIPEDIR}"
		matlab_exe+="/MSMAll/scripts/Compiled_MSMregression/distrib/run_MSMregression.sh"

		matlab_compiler_runtime="${MATLAB_HOME}/MCR"

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

		matlab_logging=">> ${StudyFolder}/${Subject}.MSMregression.matlab.2.log 2>&1"

		matlab_cmd="${matlab_exe} ${matlab_compiler_runtime} ${matlab_function_arguments} ${matlab_logging}"

		# --------------------------------------------------------------------------------
		log_Msg "Run Matlab command: ${matlab_cmd}"
		# --------------------------------------------------------------------------------

		echo "${matlab_cmd}" | bash
		echo "Matlab command return code: $?"

		rm ${Params} ${TopographicWeights} ${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii

		# Resample the individual maps so they are in the correct space
		log_Msg "Resample the individual maps so they are in the correct space"
		${Caret7_Command} -cifti-resample ${DownSampleFolder}/${Subject}.individual_Topography_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ${DownSampleFolder}/${Subject}.individual_Topography_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${Subject}.individual_Topography_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${Subject}.L.sphere.${OutPCARegString}${RegName}.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.sphere.${LowResMesh}k_fs_LR.surf.gii -left-area-surfs ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii -right-spheres ${DownSampleFolder}/${Subject}.R.sphere.${OutPCARegString}${RegName}.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.sphere.${LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii
	fi

# ##rm ${IsRunning}

}

# 
# Invoke the main function to get things started
#
main $@
