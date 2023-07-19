#!/bin/bash
set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
g_matlab_default_mode=1

#description to use in usage - syntax of parameters is now explained automatically
opts_SetScriptDescription "implements MSM-All Registration main script"

#mandatory
#general inputs
opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder that contains all subjects" '--path'
opts_AddMandatory '--subject' 'Subject' '100206' "one subject ID"
opts_AddMandatory '--high-res-mesh' 'HighResMesh' 'meshnum' "high resolution mesh node count (in thousands), like '164' for 164k_fs_LR"
opts_AddMandatory '--low-res-mesh' 'LowResMesh' 'meshnum' "low resolution mesh node count (in thousands), like '32' for 32k_fs_LR"
opts_AddMandatory '--output-fmri-name' 'OutputfMRIName' 'rfMRI_REST' "name to give to concatenated single subject scan"
opts_AddMandatory '--fmri-proc-string' 'fMRIProcSTRING' 'string' "file name component representing the preprocessing already done, e.g. '_Atlas_hp0_clean'"
opts_AddMandatory '--input-pca-registration-name' 'InPCARegName' 'MSMAll' "the registration string corresponding to the input PCA files, e.g. 'MSMSulc'"
opts_AddMandatory '--input-registration-name' 'InRegName' 'MSMAll' "the registration string corresponding to the input files, e.g. 'MSMSulc'"
opts_AddMandatory '--registration-name-stem' 'RegNameStem' 'MSMAll' "the registration string corresponding to the output files, e.g. 'MSMAll_InitalReg'"
opts_AddMandatory '--rsn-target-file' 'RSNTargetFileOrig' 'string' "rsn template file, an absolute path"
opts_AddMandatory '--rsn-cost-weights' 'RSNCostWeightsOrig' 'string' "rsn weights file, an absolute path"
opts_AddMandatory '--myelin-target-file' 'MyelinTargetFile' 'string' "myelin map target, an absolute path"
opts_AddMandatory '--topography-roi-file' 'TopographyROIFile' 'string' "topography roi file, an absolute path"
opts_AddMandatory '--topography-target-file' 'TopographyTargetFile' 'string' "topography target, an absolute path"
opts_AddMandatory '--iterations' 'Iterations' 'string' "Specifieds what modalities:
C=RSN Connectivity
A=Myelin Architecture
T=RSN Topography
and number is the number of elements delimited by _
So CA_CAT means one iteration using RSN Connectivity and Myelin
Architecture, followed by another iteration using RSN Connectivity,
Myelin Architecture, and RSN Topography"
opts_AddMandatory '--method' 'Method' 'string' "Possible values: DR, DRZ, DRN, WR, WRZ, WRN"
opts_AddMandatory '--use-migp' 'UseMIGP' 'YES/NO' "whether to use MIGP (MELODIC's Incremental Group Principal Component Analysis)"
opts_AddMandatory '--ica-dim' 'ICAdim' 'integer' "ICA (Independent Component Analysis) dimension"
opts_AddMandatory '--regression-params' 'RegressionParams' 'string' "regression parameters, e.g. the input --low-sica-dims from MSMAllPipeline.sh"
opts_AddMandatory '--vn' 'VN' 'YES/NO' "whether to perform variance normalization" 
opts_AddMandatory '--rerun' 'ReRun' 'YES/NO' "whether to re-run even if output already exists" 
opts_AddMandatory '--reg-conf' 'RegConf' 'string' "an absolute path where the registration configuration exists" 
opts_AddMandatory '--reg-conf-vars' 'RegConfVars' 'string' "the registration configure variables to override instead of using the configuration file. Please use quotes, and space between parameters is not recommended. e.g. 'REGNUMBER=1,REGPOWER=3'"
opts_AddMandatory '--msm-all-templates' 'MSMAllTemplates' 'path' "path to directory containing MSM All template files, e.g. 'YourFolder/global/templates/MSMAll'"
opts_AddOptional '--use-ind-mean' 'UseIndMean' 'YES or NO' "whether to use the mean of the individual myelin map as the group reference map's mean" 'YES'
opts_AddOptional '--matlab-run-mode' 'MatlabRunMode' '0, 1, or 2' "defaults to $g_matlab_default_mode
0 = compiled MATLAB
1 = interpreted MATLAB
2 = Octave" "$g_matlab_default_mode"
opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

# Verify required environment variables are set and log value
log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var CARET7DIR
log_Check_Env_Var MSMBINDIR

#display HCP Pipeline version
log_Msg "Showing HCP Pipelines version"
"${HCPPIPEDIR}"/show_version --short

#display the parsed/default values
opts_ShowValues

# ------------------------------------------------------------------------------
#  Main processing of script.
# ------------------------------------------------------------------------------
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
	LowICAdims=$(echo "${RegressionParams}" | sed 's/[_@]/ /g')
fi

Iterations=$(echo "${Iterations}" | sed 's/_/ /g')
NumIterations=$(echo "${Iterations}" | wc -w)
CorrectionSigma=$(echo "sqrt ( 200 )" | bc -l)
BC="NO"
nTPsForSpectra="0" #Set to zero to not compute spectra
VolParams="NO" #Dont' output volume RSN maps

# boolean values
ReRunBool=$(opts_StringToBool "$ReRun")
UseMIGPBool=$(opts_StringToBool "$UseMIGP")
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

IndArealDistortionFile=${NativeFolder}/${Subject}.ArealDistortion_${RegNameStem}_${NumIterations}_d${ICAdim}_${Method}.native.dscalar.nii
if [[ -e ${IndArealDistortionFile} ]] &&  ((! ReRunBool)) ; then
	log_Msg "--rerun is set to 'no', and the individual areal distortion file exists: ${IndArealDistortionFile}"
	log_Msg "Skipping MSMAll.sh"
	exit 0
fi

log_Msg "Starting main functionality - MSMAll.sh"
RSNTargetFile=$(echo "${RSNTargetFileOrig}" | sed "s/REPLACEDIM/${ICAdim}/g")
log_Msg "RSNTargetFile: ${RSNTargetFile}"
log_File_Must_Exist "${RSNTargetFile}"

RSNCostWeights=$(echo "${RSNCostWeightsOrig}" | sed "s/REPLACEDIM/${ICAdim}/g")
log_Msg "RSNCostWeights: ${RSNCostWeights}"
log_File_Must_Exist "${RSNCostWeights}"

cp "${RSNTargetFile}" "${DownSampleFolder}/${Subject}.atlas_RSNs_d${ICAdim}.${LowResMesh}k_fs_LR.dscalar.nii"
cp "${MyelinTargetFile}" "${DownSampleFolder}/${Subject}.atlas_MyelinMap_BC.${LowResMesh}k_fs_LR.dscalar.nii"
cp "${TopographyROIFile}" "${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs.${LowResMesh}k_fs_LR.dscalar.nii"
cp "${TopographyTargetFile}" "${DownSampleFolder}/${Subject}.atlas_Topography.${LowResMesh}k_fs_LR.dscalar.nii"

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
# path to non-normalized midthickness vertex area file
midthickness_va_file=${DownSampleT1wFolder}/${Subject}.midthickness_va.${LowResMesh}k_fs_LR.dscalar.nii
# path to normalized midthickness vertex area file
normalized_midthickness_va_file=${DownSampleT1wFolder}/${Subject}.midthickness_va_norm.${LowResMesh}k_fs_LR.dscalar.nii

if [ ! -f "${normalized_midthickness_va_file}" ] ; then
	log_Msg "Creating midthickness Vertex Area (VA) maps"

	for Hemisphere in L R ; do
		# path to surface file on which to measure surface areas
		surface_to_measure=${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness.${LowResMesh}k_fs_LR.surf.gii
		# path to metric file generated by -surface-vertex-areas subcommand
		output_metric=${DownSampleT1wFolder}/${Subject}.${Hemisphere}.midthickness_va.${LowResMesh}k_fs_LR.shape.gii
		${Caret7_Command} -surface-vertex-areas ${surface_to_measure} ${output_metric}
	done
	
	# path to left hemisphere VA metric file
	left_metric=${DownSampleT1wFolder}/${Subject}.L.midthickness_va.${LowResMesh}k_fs_LR.shape.gii
	# path to file of ROI vertices to use from left surface
	roi_left=${DownSampleFolder}/${Subject}.L.atlasroi.${LowResMesh}k_fs_LR.shape.gii
	# path to right hemisphere VA metric file
	right_metric=${DownSampleT1wFolder}/${Subject}.R.midthickness_va.${LowResMesh}k_fs_LR.shape.gii
	# path to file of ROI vertices to use from right surface
	roi_right=${DownSampleFolder}/${Subject}.R.atlasroi.${LowResMesh}k_fs_LR.shape.gii

	${Caret7_Command} -cifti-create-dense-scalar ${midthickness_va_file} \
					  -left-metric  ${left_metric} \
					  -roi-left     ${roi_left} \
					  -right-metric ${right_metric} \
					  -roi-right    ${roi_right}

	# mean of surface area accounted for for each vertex - used for normalization
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
		mkdir ${NativeFolder}/${RegName}
	else
		rm -r "${NativeFolder:?}/${RegName}"
		mkdir ${NativeFolder}/${RegName}
	fi

	if [[ $(echo -n ${Modalities} | grep "C") || $(echo -n ${Modalities} | grep "T") ]] ; then
		for Hemisphere in L R ; do
			${Caret7_Command} -surface-sphere-project-unproject ${DownSampleFolder}/${Subject}.${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${InPCARegString}.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${InRegName}.native.surf.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.sphere.${OutPCARegString}${InRegName}.${LowResMesh}k_fs_LR.surf.gii
		done

		if ((UseMIGPBool)) ; then
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

				matlab_function_arguments=("${inputspatialmaps}" "${inputdtseries}" "${inputweights}" "${outputspatialmaps}" "${outputweights}" "${Caret7_Command}" "${Method}" "${Params}" "${VN}" "${nTPsForSpectra}" "${BC}" "${VolParams}")

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

				matlabCode="addpath '$HCPCIFTIRWDIR'; addpath '$mGlobalPath'; addpath '$mPath'; MSMregression('${inputspatialmaps}','${inputdtseries}','${inputweights}','${outputspatialmaps}','${outputweights}','${Caret7_Command}','${Method}','${Params}','${VN}',${nTPsForSpectra},'${BC}','${VolParams}');"

				log_Msg "$matlabCode"
				"${interpreter[@]}" <<<"$matlabCode"
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
		# Myelin Map BC using 32k
		"$HCPPIPEDIR"/global/scripts/MyelinMap_BC.sh \
			--study-folder="$StudyFolder" \
			--subject="$Subject" \
			--registration-name="$InRegName" \
			--myelin-target-file="$MyelinTargetFile" \
			--use-ind-mean="$UseIndMean" \
			--low-res-mesh="$LowResMesh"
		if [ ! -e ${DownSampleFolder}/${Subject}.BiasField_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii ] ; then
			mv ${DownSampleFolder}/${Subject}.BiasField.${LowResMesh}k_fs_LR.dscalar.nii ${DownSampleFolder}/${Subject}.BiasField_${InRegName}.${LowResMesh}k_fs_LR.dscalar.nii
		fi       
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
				matlab_exe="${HCPPIPEDIR}/MSMAll/scripts/Compiled_MSMregression/run_MSMregression.sh"

				matlab_compiler_runtime="${MATLAB_COMPILER_RUNTIME}"

				matlab_function_arguments=("${inputspatialmaps}" "${inputdtseries}" "${inputweights}" "${outputspatialmaps}" "${outputweights}" "${Caret7_Command}" "${Method}" "${Params}" "${VN}" "${nTPsForSpectra}" "${BC}" "${VolParams}")

				matlab_cmd=("${matlab_exe}" "${matlab_compiler_runtime}" "${matlab_function_arguments[@]}")
				
				#don't log to a separate file, separate log files have never been desirable
				log_Msg "Run Matlab command: ${matlab_cmd[*]}"
				"${matlab_cmd[@]}"
				log_Msg "Matlab command return code: $?"
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
				MSMregression('${inputspatialmaps}', '${inputdtseries}', '${inputweights}', '${outputspatialmaps}', '${outputweights}', '${Caret7_Command}', '${Method}', '${Params}', '${VN}', ${nTPsForSpectra}, '${BC}', '${VolParams}');"
				
				log_Msg "$matlabCode"
				"${interpreter[@]}" <<<"$matlabCode"
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
	${Caret7_Command} -surface-distortion ${NativeFolder}/${Subject}.${Hemisphere}.sphere.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.Strain_${RegName}_raw.native.shape.gii -local-affine-method
	${Caret7_Command} -metric-math 'ln(x) / ln(2)' ${NativeFolder}/${Subject}.${Hemisphere}.StrainJ_${RegName}.native.shape.gii -var x ${NativeFolder}/${Subject}.${Hemisphere}.Strain_${RegName}_raw.native.shape.gii -column 1
	${Caret7_Command} -metric-math 'ln(x) / ln(2)' ${NativeFolder}/${Subject}.${Hemisphere}.StrainR_${RegName}.native.shape.gii -var x ${NativeFolder}/${Subject}.${Hemisphere}.Strain_${RegName}_raw.native.shape.gii -column 2
	rm -f ${NativeFolder}/${Subject}.${Hemisphere}.Strain_${RegName}_raw.native.shape.gii

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

${Caret7_Command} -cifti-create-dense-scalar ${NativeFolder}/${Subject}.StrainJ_${RegName}.native.dscalar.nii -left-metric ${NativeFolder}/${Subject}.L.StrainJ_${RegName}.native.shape.gii -roi-left ${NativeFolder}/${Subject}.L.atlasroi.native.shape.gii -right-metric ${NativeFolder}/${Subject}.R.StrainJ_${RegName}.native.shape.gii -roi-right ${NativeFolder}/${Subject}.R.atlasroi.native.shape.gii
${Caret7_Command} -set-map-name ${NativeFolder}/${Subject}.StrainJ_${RegName}.native.dscalar.nii 1 ${Subject}_StrainJ_${RegName}
${Caret7_Command} -cifti-palette ${NativeFolder}/${Subject}.StrainJ_${RegName}.native.dscalar.nii MODE_USER_SCALE ${NativeFolder}/${Subject}.StrainJ_${RegName}.native.dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false

${Caret7_Command} -cifti-create-dense-scalar ${NativeFolder}/${Subject}.StrainR_${RegName}.native.dscalar.nii -left-metric ${NativeFolder}/${Subject}.L.StrainR_${RegName}.native.shape.gii -roi-left ${NativeFolder}/${Subject}.L.atlasroi.native.shape.gii -right-metric ${NativeFolder}/${Subject}.R.StrainR_${RegName}.native.shape.gii -roi-right ${NativeFolder}/${Subject}.R.atlasroi.native.shape.gii
${Caret7_Command} -set-map-name ${NativeFolder}/${Subject}.StrainR_${RegName}.native.dscalar.nii 1 ${Subject}_StrainR_${RegName}
${Caret7_Command} -cifti-palette ${NativeFolder}/${Subject}.StrainR_${RegName}.native.dscalar.nii MODE_USER_SCALE ${NativeFolder}/${Subject}.StrainR_${RegName}.native.dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false

${Caret7_Command} -cifti-create-dense-timeseries ${NativeFolder}/${Subject}.SphericalDistortion.native.dtseries.nii -left-metric ${NativeFolder}/${Subject}.L.SphericalDistortion.native.shape.gii -roi-left ${NativeFolder}/${Subject}.L.atlasroi.native.shape.gii -right-metric ${NativeFolder}/${Subject}.R.SphericalDistortion.native.shape.gii -roi-right ${NativeFolder}/${Subject}.R.atlasroi.native.shape.gii
${Caret7_Command} -cifti-convert-to-scalar ${NativeFolder}/${Subject}.SphericalDistortion.native.dtseries.nii ROW ${NativeFolder}/${Subject}.SphericalDistortion.native.dscalar.nii
${Caret7_Command} -set-map-name ${NativeFolder}/${Subject}.SphericalDistortion.native.dscalar.nii 1 ${Subject}_SphericalDistortion
${Caret7_Command} -cifti-palette ${NativeFolder}/${Subject}.SphericalDistortion.native.dscalar.nii MODE_USER_SCALE ${NativeFolder}/${Subject}.SphericalDistortion.native.dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false
rm ${NativeFolder}/${Subject}.SphericalDistortion.native.dtseries.nii

# Myelin Map BC using 32k
"$HCPPIPEDIR"/global/scripts/MyelinMap_BC.sh \
    --study-folder="$StudyFolder" \
    --subject="$Subject" \
    --registration-name="$RegName" \
    --myelin-target-file="$MyelinTargetFile" \
    --use-ind-mean="$UseIndMean" \
    --low-res-mesh="$LowResMesh"

for Mesh in ${HighResMesh} ${LowResMesh} ; do
	if [ $Mesh = ${HighResMesh} ] ; then
		Folder=${AtlasFolder}
	elif [ $Mesh = ${LowResMesh} ] ; then
		Folder=${DownSampleFolder}
	fi
	for Map in ArealDistortion EdgeDistortion StrainJ StrainR sulc SphericalDistortion MyelinMap_BC ; do
		if [[ ${Map} = "ArealDistortion" || ${Map} = "EdgeDistortion" || ${Map} = "MyelinMap_BC" || ${Map} = "StrainJ" || ${Map} = "StrainR" ]] ; then
			NativeMap="${Map}_${RegName}"
		else
			NativeMap="${Map}"
		fi
		${Caret7_Command} -cifti-resample ${NativeFolder}/${Subject}.${NativeMap}.native.dscalar.nii COLUMN ${Folder}/${Subject}.MyelinMap_BC.${Mesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${Folder}/${Subject}.${Map}_${RegName}.${Mesh}k_fs_LR.dscalar.nii -surface-postdilate 30 -left-spheres ${NativeFolder}/${Subject}.L.sphere.${RegName}.native.surf.gii ${Folder}/${Subject}.L.sphere.${Mesh}k_fs_LR.surf.gii -left-area-surfs ${NativeFolder}/${Subject}.L.midthickness.native.surf.gii ${Folder}/${Subject}.L.midthickness.${Mesh}k_fs_LR.surf.gii -right-spheres ${NativeFolder}/${Subject}.R.sphere.${RegName}.native.surf.gii ${Folder}/${Subject}.R.sphere.${Mesh}k_fs_LR.surf.gii -right-area-surfs ${NativeFolder}/${Subject}.R.midthickness.native.surf.gii ${Folder}/${Subject}.R.midthickness.${Mesh}k_fs_LR.surf.gii
	done
done

if ((UseMIGPBool)) ; then
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
		matlab_exe="${HCPPIPEDIR}/MSMAll/scripts/Compiled_MSMregression/run_MSMregression.sh"

		matlab_compiler_runtime="${MATLAB_COMPILER_RUNTIME}"

		matlab_function_arguments=("${inputspatialmaps}" "${inputdtseries}" "${inputweights}" "${outputspatialmaps}" "${outputweights}" "${Caret7_Command}" "${Method}" "${Params}" "${VN}" "${nTPsForSpectra}" "${BC}" "${VolParams}")

		matlab_cmd=("${matlab_exe}" "${matlab_compiler_runtime}" "${matlab_function_arguments[@]}")

		#don't log to a separate file, separate log files have never been desirable
		log_Msg "Run Matlab command: ${matlab_cmd[*]}"
		"${matlab_cmd[@]}"
		log_Msg "Matlab command return code: $?"
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
		MSMregression('${inputspatialmaps}', '${inputdtseries}', '${inputweights}', '${outputspatialmaps}', '${outputweights}', '${Caret7_Command}', '${Method}', '${Params}', '${VN}', ${nTPsForSpectra}, '${BC}', '${VolParams}');"
		
		log_Msg "$matlabCode"
		"${interpreter[@]}" <<<"$matlabCode"
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
		matlab_exe="${HCPPIPEDIR}/MSMAll/scripts/Compiled_MSMregression/run_MSMregression.sh"

		matlab_compiler_runtime="${MATLAB_COMPILER_RUNTIME}"

		matlab_function_arguments=("${inputspatialmaps}" "${inputdtseries}" "${inputweights}" "${outputspatialmaps}" "${outputweights}" "${Caret7_Command}" "${Method}" "${Params}" "${VN}" "${nTPsForSpectra}" "${BC}" "${VolParams}")

		matlab_cmd=("${matlab_exe}" "${matlab_compiler_runtime}" "${matlab_function_arguments[@]}")

		#don't log to a separate file, separate log files have never been desirable
		log_Msg "Run Matlab command: ${matlab_cmd[*]}"
		"${matlab_cmd[@]}"
		log_Msg "Matlab command return code: $?"
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
		MSMregression('${inputspatialmaps}', '${inputdtseries}', '${inputweights}', '${outputspatialmaps}', '${outputweights}', '${Caret7_Command}', '${Method}', '${Params}', '${VN}', ${nTPsForSpectra}, '${BC}', '${VolParams}');"

		log_Msg "$matlabCode"
		"${interpreter[@]}" <<<"$matlabCode"
		;;

	*)
		log_Err_Abort "Unsupported MATLAB run mode value: ${MatlabRunMode}"
		;;
esac

rm ${Params} ${TopographicWeights} ${DownSampleFolder}/${Subject}.atlas_Topographic_ROIs_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii

# Resample the individual maps so they are in the correct space
log_Msg "Resample the individual maps so they are in the correct space"
${Caret7_Command} -cifti-resample ${DownSampleFolder}/${Subject}.individual_Topography_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ${DownSampleFolder}/${Subject}.individual_Topography_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${Subject}.individual_Topography_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii -surface-postdilate 40 -left-spheres ${DownSampleFolder}/${Subject}.L.sphere.${OutPCARegString}${RegName}.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.sphere.${LowResMesh}k_fs_LR.surf.gii -left-area-surfs ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii -right-spheres ${DownSampleFolder}/${Subject}.R.sphere.${OutPCARegString}${RegName}.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.sphere.${LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii
log_Msg "Completing main functionality - MSMAll.sh"
