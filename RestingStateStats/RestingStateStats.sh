#!/bin/bash

#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # RestingStateStats.sh
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
# TBW
#
# ## Prerequisites
#
# ### Previous Processing
#
# The necessary input files for this processing come from
#
# * Structural Preprocessing
# * Functional Preprocessing
# * ICA FIX processing
#
# ### Installed Software
#
# * Connectome Workbench (v1.0 or above)
# * FSL (version 5.0.6 or above)
# * Octave - Open source MATLAB alternative 
#   - Necessary only if Octave is indicated as the Matlab 
#     run mode
# * Matlab (version R2013a)
#   - Necessary only if Matlab (non-compiled) is indicated
#     as the Matlab run mode.
#
# ### Environment Variables
# 
# * HCPPIPEDIR
#  
#   The "home" directory for the HCP Pipeline product.
#   e.g. /home/tbrown01/projects/Pipelines
#
# * FSLDIR
#
#   The "home" directory for the FSL installation
#
# * CARET7DIR
#
#   The executable directory for the Connectome Workbench installation
# 
# * OCTAVE_HOME
# 
#   The home directory for the Octave installation
#
# <!-- References -->
# [HCP]: http://www.humanconnectome.org
#
#~ND~END~

# ------------------------------------------------------------------------------
#  Code Start
# ------------------------------------------------------------------------------

# If any commands exit with non-zero value, this script exits
set -e
g_script_name=`basename ${0}`

# ------------------------------------------------------------------------------
#  Load function libraries
# ------------------------------------------------------------------------------

source ${HCPPIPEDIR}/global/scripts/log.shlib # Logging related functions
log_SetToolName "${g_script_name}"

source ${HCPPIPEDIR}/global/scripts/fsl_version.shlib # Function for getting FSL version

#
# Function Description:
#  Document Tool Versions
#
show_tool_versions() {
	# Show HCP pipelines version
	log_Msg "Showing HCP Pipelines version"
	cat ${HCPPIPEDIR}/version.txt

	# Show wb_command version
	log_Msg "Showing wb_command version"
	${CARET7DIR}/wb_command -version

	# Show fsl version
	log_Msg "Showing FSL version"
	fsl_version_get fsl_ver
	log_Msg "FSL version: ${fsl_ver}"
}

# 
# Function Description:
#  Show usage information for this script
#
usage()
{
	echo ""
	echo "  Compute Resting State Statistics"
	echo ""
	echo "  Usage: ${g_script_name} <options>"
	echo ""
	echo "  Options: [ ] = optional; < > = user supplied value"
	echo ""
	echo "   [--help] : show usage information and exit"
	echo "    --path=<path to study folder> OR --study-folder=<path to study folder>"
	echo "    --subject=<subject ID>"
	echo "    --fmri-name=<fMRI name>"
	echo "    --high-pass=<high pass>"
	echo "   [--reg-name=<registration name> (e.g. NONE or MSMSulc)] defaults to NONE if not specified"
	echo "    --low-res-mesh=<low resolution mesh size> (in thousands, e.g. 32 --> 32k)"
	echo "    --final-fmri-res=<final fMRI resolution> (in millimeters)"
	echo "    --brain-ordinates-res=<brain ordinates resolution> (in millimeters)"
	echo "    --smoothing-fwhm=<smoothing full width at half max>"
	echo "    --output-proc-string=<output processing string>"
	echo "   [--dlabel-file=<dlabel file>] defaults to NONE if not specified"
	echo "   [--matlab-run-mode={0, 1, 2}] defaults to 0 (Compiled Matlab)"
	echo "     0 = Use compiled Matlab"
	echo "     1 = Use Matlab"
	echo "     2 = Use Octave"
	echo "   [--bc-mode={REVERT,NONE,CORRECT}] defaults to REVERT"
	echo "     REVERT = Revert minimal preprocessing pipelines bias field correction"
	echo "     NONE = Do not change bias field correction"
	echo "     CORRECT = Revert and apply corrected bias field correction, requires ${ResultsFolder}/${fMRIName}_Atlas[${RegName}]_real_bias.dscalar.nii"
	echo "   [--out-string=<out-string> defaults to 'stats'"
	echo "   [--wm=<NONE | FreeSurfer Label Config File>]"
	echo "   [--csf=<NONE | FreeSurfer Label Config File>]"
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
#  ${g_fmri_name} - fMRI name
#  ${g_high_pass} - high pass
#  ${g_reg_name}  - registration name
#  ${g_low_res_mesh} - low resolution mesh size
#  ${g_final_fmri_res} - final fMRI resolution
#  ${g_brain_ordinates_res} - brain ordinates resolution
#  ${g_smoothing_fwhm} - smoothing full width at half maximum
#  ${g_output_proc_string} - output processing string
#  ${g_dlabel_file} - label file containing label designations and label color keys
#  ${g_matlab_run_mode} - indication of how to run Matlab code
#    0 - Use compiled Matlab
#    1 - Use Matlab
#    2 - Use Octave
#  ${g_bc_mode} - bias correction mode
#    REVERT - Revert minimal preprocessing pipelines bias field correction
#    NONE - Do not change bias field correction
#    CORRECT - Revert and apply corrected bias field correction, requires ${ResultsFolder}/${fMRIName}_Atlas[${RegName}]_real_bias.dscalar.nii
#  ${g_out_string} - name string of output files
#  ${g_wm} - Switch that turns on white matter timeseries related stats
#  ${g_csf} - Switch that turns on csf timeseries related stats
#
get_options()
{
	local arguments=($@)

	# initialize global output variables
	unset g_path_to_study_folder
	unset g_subject
	unset g_fmri_name
	unset g_high_pass
	unset g_reg_name
	unset g_low_res_mesh
	unset g_final_fmri_res
	unset g_brain_ordinates_res
	unset g_smoothing_fwhm
	unset g_output_proc_string
	unset g_dlabel_file
	unset g_matlab_run_mode
	unset g_bc_mode
	unset g_out_string
	unset g_wm
	unset g_csf

	# set default values 
	g_reg_name="NONE"
	g_dlabel_file="NONE"
	g_matlab_run_mode=0
	g_bc_mode="REVERT"
	g_out_string="stats"
	g_wm="NONE"
	g_csf="NONE"

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
			--fmri-name=*)
				g_fmri_name=${argument#*=}
				index=$(( index + 1 ))
				;;
			--high-pass=*)
				g_high_pass=${argument#*=}
				index=$(( index + 1 ))
				;;
			--reg-name=*)
				g_reg_name=${argument#*=}
				index=$(( index + 1 ))
				;;
			--low-res-mesh=*)
				g_low_res_mesh=${argument#*=}
				index=$(( index + 1 ))
				;;
			--final-fmri-res=*)
				g_final_fmri_res=${argument#*=}
				index=$(( index + 1 ))
				;;				
			--brain-ordinates-res=*)
				g_brain_ordinates_res=${argument#*=}
				index=$(( index + 1 ))
				;;				
			--smoothing-fwhm=*)
				g_smoothing_fwhm=${argument#*=}
				index=$(( index + 1 ))
				;;				
			--output-proc-string=*)
				g_output_proc_string=${argument#*=}
				index=$(( index + 1 ))
				;;
			--dlabel-file=*)
				g_dlabel_file=${argument#*=}
				index=$(( index + 1 ))
				;;
			--matlab-run-mode=*)
				g_matlab_run_mode=${argument#*=}
				index=$(( index + 1 ))
				;;
			--bc-mode=*)
				g_bc_mode=${argument#*=}
				index=$(( index + 1 ))
				;;
			--out-string=*)
				g_out_string=${argument#*=}
				index=$(( index + 1 ))
				;;
		  --wm=*)
				g_wm=${argument#*=}
				index=$(( index + 1 ))
				;;
			--csf=*)
				g_csf=${argument#*=}
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

	if [ -z "${g_fmri_name}" ]; then
		echo "ERROR: fMRI name required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_fmri_name: ${g_fmri_name}"
	fi

	if [ -z "${g_high_pass}" ]; then
		echo "ERROR: high pass required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_high_pass: ${g_high_pass}"
	fi

	if [ -z "${g_reg_name}" ]; then
		echo "ERROR: registration name required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_reg_name: ${g_reg_name}"
	fi

	if [ -z "${g_low_res_mesh}" ]; then
		echo "ERROR: low resolution mesh size required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_low_res_mesh: ${g_low_res_mesh}"
	fi

	if [ -z "${g_final_fmri_res}" ]; then
		echo "ERROR: final fMRI resolution required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_final_fmri_res: ${g_final_fmri_res}"
	fi

	if [ -z "${g_brain_ordinates_res}" ]; then
		echo "ERROR: brain ordinates resolution required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_brain_ordinates_res: ${g_brain_ordinates_res}"
	fi

	if [ -z "${g_smoothing_fwhm}" ]; then
		echo "ERROR: smoothing full width at half max value required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_smoothing_fwhm: ${g_smoothing_fwhm}"
	fi

	if [ -z "${g_output_proc_string}" ]; then
		echo "ERROR: output processing string value required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_output_proc_string: ${g_output_proc_string}"
	fi

	if [ -z "${g_dlabel_file}" ]; then
		echo "ERROR: dlabel file value required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_dlabel_file: ${g_dlabel_file}"
	fi

	if [ -z "${g_matlab_run_mode}" ]; then
		echo "ERROR: matlab run mode value (--matlab-run-mode=) required"
		error_count=$(( error_count + 1 ))
	else
		case ${g_matlab_run_mode} in 
			0)
				;;
			1)
				;;
			2)
				;;
			*)
				echo "ERROR: matlab run mode value must be 0, 1, or 2"
				error_count=$(( error_count + 1 ))
				;;
		esac
	fi

	if [ -z "${g_bc_mode}" ]; then
		echo "ERROR: bias corrrection mode (--bc-mode=) required"
		error_count=$(( error_count + 1 ))
	else
		case ${g_bc_mode} in 
			REVERT)
				;;
			NONE)
				;;
			CORRECT)
				;;
			*)
				echo "ERROR: bias corrrection mode must be REVERT, NONE, or CORRECT"
				error_count=$(( error_count + 1 ))
				;;
		esac
	fi

	if [ -z "${g_out_string}" ]; then
		echo "ERROR: out string required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_out_string: ${g_out_string}"
	fi

	if [ -z "${g_wm}" ]; then
		echo "ERROR: WM switch required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_wm: ${g_wm}"
	fi

	if [ -z "${g_csf}" ]; then
		echo "ERROR: CSF switch required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_csf: ${g_csf}"
	fi

	if [ ${error_count} -gt 0 ]; then
		echo "For usage information, use --help"
		exit 1
	fi
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

	# Naming Conventions
	AtlasFolder="${g_path_to_study_folder}/${g_subject}/MNINonLinear"
	log_Msg "AtlasFolder: ${AtlasFolder}"

	NativeFolder="${AtlasFolder}/Native"
	log_Msg "NativeFolder: ${NativeFolder}"

	ResultsFolder="${AtlasFolder}/Results/${g_fmri_name}"
	log_Msg "ResultsFolder: ${ResultsFolder}"

	DownsampleFolder="${AtlasFolder}/fsaverage_LR${g_low_res_mesh}k"
	log_Msg "DownsampleFolder: ${DownsampleFolder}"

	ROIFolder="${AtlasFolder}/ROIs"
	log_Msg "ROIFolder: ${ROIFolder}"

	ICAFolder="${ResultsFolder}/${g_fmri_name}_hp${g_high_pass}.ica/filtered_func_data.ica"
	log_Msg "ICAFolder: ${ICAFolder}"

	FIXFolder="${ResultsFolder}/${g_fmri_name}_hp${g_high_pass}.ica"
	log_Msg "FIXFolder: ${FIXFolder}"

	if [ ${g_dlabel_file} = "NONE" ] ; then
		unset g_dlabel_file
	fi
	
	if [ ! ${g_reg_name} = "NONE" ] ; then
		RegString="_${g_reg_name}"
	else
		RegString=""
		g_reg_name="MSMSulc"
	fi

	if [ ! ${g_low_res_mesh} = "32" ] ; then
		RegString="${RegString}.${g_low_res_mesh}k"
	fi

	### Calculate CIFTI version of the bias field (which is removed as part of the fMRI minimal pre-processing)
	### so that the bias field can be "restored" prior to the variance decomposition
	### i.e., so that the estimate variance at each grayordinate reflects the scaling of the original data
	### MG: Note that bias field correction and variance normalization are two incompatible goals
	log_Msg "Calculate CIFTI version of the bias field"

	Sigma=`echo "$g_smoothing_fwhm / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`

	# ----------------------------------------
	# Input File(s)
	# ----------------------------------------

	# input image - Result of Structural Preprocessing
	inputImage="${AtlasFolder}/BiasField.nii.gz"

	# reference image - Collected File, retrieved from Functional Preprocessing
	referenceImage="${ResultsFolder}/${g_fmri_name}_SBRef.nii.gz"

	# pre-transform - identity matrix from FSL distribution
	preTransform="${FSLDIR}/etc/flirtsch/ident.mat"

	# ----------------------------------------
	# Ouput File(s)
	# ----------------------------------------

	# newBiasField - newly created file
	newBiasField="${ResultsFolder}/BiasField.${g_final_fmri_res}.nii.gz"

	${FSLDIR}/bin/applywarp \
		--rel \
		--interp=spline \
		-i ${inputImage} \
		-r ${referenceImage} \
		--premat=${preTransform} \
		-o ${newBiasField}

	# ----------------------------------------
	# Input File(s) 
	# ----------------------------------------

	# input image - Result of previous step
	inputImage="${ResultsFolder}/BiasField.${g_final_fmri_res}.nii.gz"

	# ----------------------------------------
	# Output Files(s)
	# ----------------------------------------

	# output image - same as input - modifies file
	outputImage="${inputImage}"

	${FSLDIR}/bin/fslmaths \
		${inputImage} \
		-thr 0.1 \
		${outputImage}

 	for Hemisphere in L R ; do

		# --------------------------------------------------------------------------------
		log_Msg "Working on Hemisphere: ${Hemisphere}"
 		log_Msg "Map bias field volume to surface using the same approach as when fMRI"
		log_Msg " data are projected to the surface"
		# --------------------------------------------------------------------------------

		# ----------------------------------------
		# Input File(s)
		# ----------------------------------------

		# volume - Result of previous step
 		volume="${ResultsFolder}/BiasField.${g_final_fmri_res}.nii.gz"

		# surface - From Structural Preprocessing
 		surface="${NativeFolder}/${g_subject}.${Hemisphere}.midthickness.native.surf.gii"

		# ribbon constraint inner ribbon - From Structural Preprocessing
 		ribbonInner="${NativeFolder}/${g_subject}.${Hemisphere}.white.native.surf.gii"
		
		# ribbon constraint outter ribbon - From Structural Preprocessing
 		ribbonOutter="${NativeFolder}/${g_subject}.${Hemisphere}.pial.native.surf.gii"

		# ribbon constraint ROI volume - From Functional Preprocessing
 		roiVolume="${ResultsFolder}/RibbonVolumeToSurfaceMapping/goodvoxels.nii.gz"

		# ----------------------------------------
		# Output File(s)
		# ----------------------------------------

		# metricOut - newly created file
 		metricOut="${ResultsFolder}/BiasField.${Hemisphere}.native.func.gii"
		
 		${CARET7DIR}/wb_command \
 			-volume-to-surface-mapping ${volume} ${surface} ${metricOut} \
 			-ribbon-constrained ${ribbonInner} ${ribbonOutter} \
 			-volume-roi ${roiVolume}

		# --------------------------------------------------------------------------------
		log_Msg "Fill in any small holes with dilation again as is done with fMRI"
		# --------------------------------------------------------------------------------

		# ----------------------------------------
		# Input File(s)
		# ----------------------------------------

		# metric - From Previous Step
		metric="${ResultsFolder}/BiasField.${Hemisphere}.native.func.gii"

		# surface - From Structural Preprocessing
		surface="${NativeFolder}/${g_subject}.${Hemisphere}.midthickness.native.surf.gii"		

		# ----------------------------------------
		# Output File(s)
		# ----------------------------------------

		# metricOut - same as metric input - modifies file
		metricOut="${metric}"

		distance="10"
		${CARET7DIR}/wb_command -metric-dilate ${metric} ${surface} ${distance} ${metricOut} -nearest

		# --------------------------------------------------------------------------------
		log_Msg "Mask out the medial wall of dilated file"
		# --------------------------------------------------------------------------------

		# ----------------------------------------
		# Input File(s)
		# ----------------------------------------

		# metric - From Previous Step
		metric="${ResultsFolder}/BiasField.${Hemisphere}.native.func.gii"

		# mask - From Structural Preprocessing
		mask="${NativeFolder}/${g_subject}.${Hemisphere}.roi.native.shape.gii"

		# ----------------------------------------
		# Output File(s)
		# ----------------------------------------

		# metricOut - same as metric input - modifies file
		metricOut="${metric}"

		${CARET7DIR}/wb_command -metric-mask $metric $mask $metricOut

		# --------------------------------------------------------------------------------
		log_Msg "Resample the surface data from the native mesh to the standard mesh"
		# --------------------------------------------------------------------------------

		# ----------------------------------------
		# Input File(s)
		# ----------------------------------------

		# metricIn - From Previous Step
		metricIn="${ResultsFolder}/BiasField.${Hemisphere}.native.func.gii"

		# currentSphere - From Structural Preprocessing
		currentSphere="${NativeFolder}/${g_subject}.${Hemisphere}.sphere.${g_reg_name}.native.surf.gii"

		# newSphere - From Structural Preprocessing
		newSphere="${DownsampleFolder}/${g_subject}.${Hemisphere}.sphere.${g_low_res_mesh}k_fs_LR.surf.gii"

		# area-surfs: currentArea - From Structural Preprocessing
		currentArea="${NativeFolder}/${g_subject}.${Hemisphere}.midthickness.native.surf.gii"

		# area-surfs: newArea - From Structural Preprocessing
		newArea="${DownsampleFolder}/${g_subject}.${Hemisphere}.midthickness.${g_low_res_mesh}k_fs_LR.surf.gii"

		# current-roi: roiMetric - From Structural Preprocessing
		roiMetric="${NativeFolder}/${g_subject}.${Hemisphere}.roi.native.shape.gii"

		# ----------------------------------------
		# Output File(s)
		# ----------------------------------------

		# metricOut - newly created file
		metricOut="${ResultsFolder}/BiasField.${Hemisphere}.${g_low_res_mesh}k_fs_LR.func.gii"

		method="ADAP_BARY_AREA"
		${CARET7DIR}/wb_command \
			-metric-resample ${metricIn} ${currentSphere} ${newSphere} ${method} ${metricOut} \
			-area-surfs ${currentArea} ${newArea} \
			-current-roi ${roiMetric}
	
		# --------------------------------------------------------------------------------
		log_Msg "Make sure the medial wall is zeros"
		# --------------------------------------------------------------------------------

		# ----------------------------------------
		# Input File(s)
		# ----------------------------------------

		# metric - From Previous Step
		metric="${ResultsFolder}/BiasField.${Hemisphere}.${g_low_res_mesh}k_fs_LR.func.gii"

		# mask - From Structural Preprocessing
		mask="${DownsampleFolder}/${g_subject}.${Hemisphere}.atlasroi.${g_low_res_mesh}k_fs_LR.shape.gii"

		# ----------------------------------------
		# Output File(s)
		# ----------------------------------------

		# metricOut - same as input metric - modifies file
		metricOut="${ResultsFolder}/BiasField.${Hemisphere}.${g_low_res_mesh}k_fs_LR.func.gii"

		${CARET7DIR}/wb_command -metric-mask ${metric} ${mask} ${metricOut}

		# --------------------------------------------------------------------------------
		log_Msg "Smooth the surface bias field the same as the fMRI"
		# --------------------------------------------------------------------------------

		# ----------------------------------------
		# Input File(s)
		# ----------------------------------------

		# surface - From Structural Preprocessing
		surface="${DownsampleFolder}/${g_subject}.${Hemisphere}.midthickness.${g_low_res_mesh}k_fs_LR.surf.gii"

		# metricIn - From Previous Step
		metricIn="${ResultsFolder}/BiasField.${Hemisphere}.${g_low_res_mesh}k_fs_LR.func.gii"

		# roiMetric - roi to smooth within - From Structural Preprocessing
		roiMetric="${DownsampleFolder}/${g_subject}.${Hemisphere}.atlasroi.${g_low_res_mesh}k_fs_LR.shape.gii"

		# ----------------------------------------
		# Output File(s)
		# ----------------------------------------

		# metricOut - same as input metric - modifies file
		metricOut="${ResultsFolder}/BiasField.${Hemisphere}.${g_low_res_mesh}k_fs_LR.func.gii"

		smoothingKernel="${Sigma}"
		${CARET7DIR}/wb_command \
			-metric-smoothing ${surface} ${metricIn} ${smoothingKernel} ${metricOut} -roi ${roiMetric}

 	done

	# --------------------------------------------------------------------------------
	log_Msg "Project bias field into subcortical CIFTI space"
	# --------------------------------------------------------------------------------
	
	unset POSIXLY_CORRECT

	if [ 1 -eq `echo "$g_brain_ordinates_res == $g_final_fmri_res" | bc -l` ] ; then
		log_Msg "Using the same fMRI and grayordinates space resolution"
		log_Msg "Use the simple algorithm to project bias field into subcortical CIFTI space like fMRI"

		# ----------------------------------------
		# Input File(s)
		# ----------------------------------------

		# volumeIn - From Functional Preprocessing
		volumeIn="${ResultsFolder}/BiasField.${g_final_fmri_res}.nii.gz"

		# currentParcel - From Structural Preprocessing
		currentParcel="${ROIFolder}/ROIs.${g_brain_ordinates_res}.nii.gz"

		# newParcel - From Structural Preprocessing
		newParcel="${ROIFolder}/Atlas_ROIs.${g_brain_ordinates_res}.nii.gz"

		# ----------------------------------------
		# Output File(s)
		# ----------------------------------------

		# volumeOut - newly created file
		volumeOut="${ResultsFolder}/BiasField_AtlasSubcortical.nii.gz"

		kernel="${Sigma}"
		${CARET7DIR}/wb_command \
			-volume-parcel-resampling ${volumeIn} ${currentParcel} ${newParcel} ${kernel} \
			${volumeOut} -fix-zeros

	else
		log_Msg "Using different fMRI and grayordinates space resolutions"
		log_Msg "Use the generic algorithm to project bias field into subcortical CIFTI space like fMRI"

		# ----------------------------------------
		# Input File(s)
		# ----------------------------------------

		# volumeIn - From Functional Preprocessing
		volumeIn="${ResultsFolder}/BiasField.${g_final_fmri_res}.nii.gz"

		# currentParcel - From Structural Preprocessing
		currentParcel="${ResultsFolder}/ROIs.${g_final_fmri_res}.nii.gz"

		# newParcel - From Structural Preprocessing
		newParcel="${ROIFolder}/Atlas_ROIs.${g_brain_ordinates_res}.nii.gz"

		# ----------------------------------------
		# Output File(s)
		# ----------------------------------------

		# volumeOut - newly created file
		volumeOut="${ResultsFolder}/BiasField_AtlasSubcortical.nii.gz"

		kernel="${Sigma}"
		${CARET7DIR}/wb_command \
			-volume-parcel-resampling-generic ${volumeIn} ${currentParcel} ${newParcel} ${kernel} \
		 	${volumeOut} -fix-zeros

	fi

	# --------------------------------------------------------------------------------
	log_Msg "Create CIFTI file of bias field as was done with fMRI"
	# --------------------------------------------------------------------------------

	# ----------------------------------------
	# Input File(s)
	# ----------------------------------------

	# volumeData - From Previous Step
	volumeData="${ResultsFolder}/BiasField_AtlasSubcortical.nii.gz"

	# labelVolume - From Structural Preprocessing
	labelVolume="${ROIFolder}/Atlas_ROIs.${g_brain_ordinates_res}.nii.gz"

	# lMetric - Created in loop above
	lMetric="${ResultsFolder}/BiasField.L.${g_low_res_mesh}k_fs_LR.func.gii"

	# lRoiMetric - From Structural Preprocessing
	lRoiMetric="${DownsampleFolder}/${g_subject}.L.atlasroi.${g_low_res_mesh}k_fs_LR.shape.gii"

	# rMetric - Created in loop above
	rMetric="${ResultsFolder}/BiasField.R.${g_low_res_mesh}k_fs_LR.func.gii"

	# rRoiMetric - From Structural Preprocessing
	rRoiMetric="${DownsampleFolder}/${g_subject}.R.atlasroi.${g_low_res_mesh}k_fs_LR.shape.gii"

	# ----------------------------------------
	# Output File(s)
	# ----------------------------------------

	# ciftiOut - newly created file
	ciftiOut="${ResultsFolder}/${g_fmri_name}_Atlas${RegString}_BiasField.dscalar.nii"

	${CARET7DIR}/wb_command \
		-cifti-create-dense-scalar ${ciftiOut} \
		-volume ${volumeData} ${labelVolume} \
		-left-metric ${lMetric} -roi-left ${lRoiMetric} \
		-right-metric ${rMetric} -roi-right ${rRoiMetric}

	# --------------------------------------------------------------------------------
	log_Msg "Final step in creation of CIFTI bias field"
	# --------------------------------------------------------------------------------

	Mean=`fslstats ${ResultsFolder}/BiasField.${g_final_fmri_res}.nii.gz -k ${ResultsFolder}/${g_fmri_name}_SBRef.nii.gz -M`

	#Someone: don't paramaterize this, it messes up Var and -var Var structure somehow
	#MG: Not sure why unless you tried to change the math expression, question for Tim Coalson
	${CARET7DIR}/wb_command -cifti-math "Var / ${Mean}" ${ResultsFolder}/${g_fmri_name}_Atlas${RegString}_BiasField.dscalar.nii \
		-var Var ${ResultsFolder}/${g_fmri_name}_Atlas${RegString}_BiasField.dscalar.nii
	
	# --------------------------------------------------------------------------------
	log_Msg "End creation of CIFTI bias field"
	# --------------------------------------------------------------------------------

	if [ ! ${g_wm} = "NONE" ] ; then

		# --------------------------------------------------------------------------------
		log_Msg "Create white matter timeseries related stats"
		# --------------------------------------------------------------------------------

		${CARET7DIR}/wb_command \
			-volume-label-import ${ROIFolder}/wmparc.${g_final_fmri_res}.nii.gz ${g_wm} \
			${ROIFolder}/WMReg.${g_final_fmri_res}.nii.gz -discard-others -drop-unused-labels
		
		for Hemisphere in L R ; do
			${CARET7DIR}/wb_command \
				-metric-to-volume-mapping ${DownsampleFolder}/${g_subject}.${Hemisphere}.atlasroi.${g_low_res_mesh}k_fs_LR.shape.gii \
				${DownsampleFolder}/${g_subject}.${Hemisphere}.midthickness.${g_low_res_mesh}k_fs_LR.surf.gii \
				${ROIFolder}/WMReg.${g_final_fmri_res}.nii.gz ${ROIFolder}/${Hemisphere}.${g_final_fmri_res}.nii.gz \
				-ribbon-constrained \
				${DownsampleFolder}/${g_subject}.${Hemisphere}.white.${g_low_res_mesh}k_fs_LR.surf.gii \
				${DownsampleFolder}/${g_subject}.${Hemisphere}.pial.${g_low_res_mesh}k_fs_LR.surf.gii
		done
		
		${FSLDIR}/bin/fslmaths ${ROIFolder}/ROIs.${g_final_fmri_res}.nii.gz -add ${ROIFolder}/L.${g_final_fmri_res}.nii.gz -add ${ROIFolder}/R.${g_final_fmri_res}.nii.gz -dilD -dilD ${ROIFolder}/WMRegAvoid.${g_final_fmri_res}.nii.gz
		${FSLDIR}/bin/fslmaths ${ROIFolder}/WMReg.${g_final_fmri_res}.nii.gz -bin -sub ${ROIFolder}/WMRegAvoid.${g_final_fmri_res}.nii.gz -thr 1 ${ROIFolder}/WMReg.${g_final_fmri_res}.nii.gz
		rm ${ROIFolder}/L.${g_final_fmri_res}.nii.gz ${ROIFolder}/R.${g_final_fmri_res}.nii.gz ${ROIFolder}/WMRegAvoid.${g_final_fmri_res}.nii.gz
		${FSLDIR}/bin/fslmeants -i ${ResultsFolder}/${g_fmri_name}.nii.gz -o ${ResultsFolder}/${g_fmri_name}_WM.txt -m ${ROIFolder}/WMReg.${g_final_fmri_res}.nii.gz
		WM="${ResultsFolder}/${g_fmri_name}_WM.txt"
	else
		WM="NONE"
	fi
	
	if [ ! ${g_csf} = "NONE" ] ; then

		# --------------------------------------------------------------------------------
		log_Msg "Create CSF timeseries related stats"
		# --------------------------------------------------------------------------------

		${CARET7DIR}/wb_command \
			-volume-label-import ${ROIFolder}/wmparc.${g_final_fmri_res}.nii.gz ${g_csf} \
			${ROIFolder}/CSFReg.${g_final_fmri_res}.nii.gz -discard-others -drop-unused-labels

		for Hemisphere in L R ; do
			${CARET7DIR}/wb_command \
				-metric-to-volume-mapping ${DownsampleFolder}/${g_subject}.${Hemisphere}.atlasroi.${g_low_res_mesh}k_fs_LR.shape.gii \
				${DownsampleFolder}/${g_subject}.${Hemisphere}.midthickness.${g_low_res_mesh}k_fs_LR.surf.gii \
				${ROIFolder}/CSFReg.${g_final_fmri_res}.nii.gz ${ROIFolder}/${Hemisphere}.${g_final_fmri_res}.nii.gz \
				-ribbon-constrained \
				${DownsampleFolder}/${g_subject}.${Hemisphere}.white.${g_low_res_mesh}k_fs_LR.surf.gii \
				${DownsampleFolder}/${g_subject}.${Hemisphere}.pial.${g_low_res_mesh}k_fs_LR.surf.gii
		done

		${FSLDIR}/bin/fslmaths ${ROIFolder}/ROIs.${g_final_fmri_res}.nii.gz -add ${ROIFolder}/L.${g_final_fmri_res}.nii.gz -add ${ROIFolder}/R.${g_final_fmri_res}.nii.gz -dilD -dilD ${ROIFolder}/CSFRegAvoid.${g_final_fmri_res}.nii.gz
		${FSLDIR}/bin/fslmaths ${ROIFolder}/CSFReg.${g_final_fmri_res}.nii.gz -bin -sub ${ROIFolder}/CSFRegAvoid.${g_final_fmri_res}.nii.gz -thr 1 ${ROIFolder}/CSFReg.${g_final_fmri_res}.nii.gz
		rm ${ROIFolder}/L.${g_final_fmri_res}.nii.gz ${ROIFolder}/R.${g_final_fmri_res}.nii.gz ${ROIFolder}/CSFRegAvoid.${g_final_fmri_res}.nii.gz
		${FSLDIR}/bin/fslmeants -i ${ResultsFolder}/${g_fmri_name}.nii.gz -o ${ResultsFolder}/${g_fmri_name}_CSF.txt -m ${ROIFolder}/CSFReg.${g_final_fmri_res}.nii.gz
		CSF="${ResultsFolder}/${g_fmri_name}_CSF.txt"
	else
		CSF="NONE"
	fi

	motionparameters="${ResultsFolder}/Movement_Regressors" #No .txt
	TR=`${FSLDIR}/bin/fslval ${ResultsFolder}/${g_fmri_name} pixdim4`
	ICAs="${ICAFolder}/melodic_mix"
	if [ -e ${FIXFolder}/HandNoise.txt ] ; then
		noise="${FIXFolder}/HandNoise.txt"
	else
		noise="${FIXFolder}/.fix"
	fi
	dtseries="${ResultsFolder}/${g_fmri_name}_Atlas${RegString}"
	bias="${ResultsFolder}/${g_fmri_name}_Atlas${RegString}_BiasField.dscalar.nii"
	if [ ${g_bc_mode} = "REVERT" ] ; then
	  g_bc_mode="REVERT"
	elif [ ${g_bc_mode} = "NONE" ] ; then
	  g_bc_mode="NONE"
	elif [ ${g_bc_mode} = "CORRECT" ] ; then
	  g_bc_mode="${ResultsFolder}/${g_fmri_name}_Atlas${RegString}_real_bias.dscalar.nii"
	fi

	RssFolder="${ResultsFolder}/RestingStateStats"
	RssPrefix="${RssFolder}/${g_fmri_name}_Atlas${RegString}"
	mkdir -p ${RssFolder}

	case ${g_matlab_run_mode} in
		0)
			# Use Compiled Matlab
			matlab_exe="${HCPPIPEDIR}"
			matlab_exe+="/RestingStateStats/Compiled_RestingStateStats/distrib/run_RestingStateStats.sh"

			# TBD: Use environment variable instead of fixed path?
			matlab_compiler_runtime="/export/matlab/R2013a/MCR"

			matlab_function_arguments="'${motionparameters}' ${g_high_pass} ${TR} '${ICAs}' '${noise}' "
			matlab_function_arguments+="'${CARET7DIR}/wb_command' '${dtseries}' '${bias}' '${RssPrefix}' '${g_dlabel_file}' '${g_bc_mode}' '${g_out_string}' '${WM}' '${CSF}'"

			matlab_logging=">> ${g_path_to_study_folder}/${g_subject}_${g_fmri_name}.matlab.log 2>&1"

			matlab_cmd="${matlab_exe} ${matlab_compiler_runtime} ${matlab_function_arguments} ${matlab_logging}"

			# --------------------------------------------------------------------------------
			log_Msg "Run matlab command: ${matlab_cmd}"
			# --------------------------------------------------------------------------------

			echo "${matlab_cmd}" | bash
			echo $?

			;;

		1)
			# Use Matlab - Untested
			matlab_script_file_name=${ResultsFolder}/RestingStateStats_${g_fmri_name}.m
			log_Msg "Creating Matlab script: ${matlab_script_file_name}"

			if [ -e ${matlab_script_file_name} ]; then
				echo "Removing old ${matlab_script_file_name}"
				rm -f ${matlab_script_file_name}
			fi
			
			# TBD: change these paths to use variables instead of hard coded paths
			touch ${matlab_script_file_name}
			echo "addpath ${HCPPIPEDIR}/RestingStateStats " >> ${matlab_script_file_name}
			echo "addpath /home/HCPpipeline/pipeline_tools/gifti" >> ${matlab_script_file_name}
			echo "addpath ${FSLDIR}/etc/matlab" >> ${matlab_script_file_name}
			echo "RestingStateStats('${motionparameters}',${g_high_pass},${TR},'${ICAs}','${noise}','${CARET7DIR}/wb_command','${dtseries}','${bias}','${RssPrefix}','${g_dlabel_file}','${g_bc_mode}','${g_out_string}','${WM}','${CSF}');" >> ${matlab_script_file_name}

			log_Msg "About to execute the following Matlab script"

			cat ${matlab_script_file_name}
			cat ${matlab_script_file_name} | matlab -nodisplay -nosplash

			;;

		2)
			# Use Octave - doesn't seem to work
			octave_script_file_name=${ResultsFolder}/RestingStateStats_${g_fmri_name}.m
			log_Msg "Creating Octave script: ${octave_script_file_name}"

			if [ -e ${octave_script_file_name} ]; then
				echo "Removing old ${octave_script_file_name}"
				rm -f ${octave_script_file_name}
			fi
			
			# TBD: change these paths to use variables instead of hard coded paths
			touch ${octave_script_file_name}
			echo "addpath ${HCPPIPEDIR}/RestingStateStats " >> ${octave_script_file_name}
			echo "addpath /home/HCPpipeline/pipeline_tools/gifti" >> ${octave_script_file_name}
			echo "addpath ${FSLDIR}/etc/matlab" >> ${octave_script_file_name}
			echo "RestingStateStats('${motionparameters}',${g_high_pass},${TR},'${ICAs}','${noise}','${CARET7DIR}/wb_command','${dtseries}','${bias}','${RssPrefix}','${g_dlabel_file}','${g_bc_mode}','${g_out_string}','${WM}','${CSF}');" >> ${octave_script_file_name}

			log_Msg "About to execute the following Octave script"

			cat ${octave_script_file_name}
			cat ${octave_script_file_name} | ${OCTAVE_HOME}/bin/octave

			;;

		*)
			log_Msg "ERROR: Unrecognized Matlab run mode value: ${g_matlab_run_mode}"
			exit 1
	esac

	log_Msg "Moving results of Matlab function"
	mv --verbose ${RssFolder}/${g_fmri_name}_Atlas${RegString}_${g_out_string}.txt ${ResultsFolder}
	mv --verbose ${RssFolder}/${g_fmri_name}_Atlas${RegString}_${g_out_string}.dtseries.nii ${ResultsFolder}
	mv --verbose ${RssFolder}/${g_fmri_name}_Atlas${RegString}_vn.dscalar.nii ${ResultsFolder}

	if [ -e ${ResultsFolder}/Names.txt ] ; then 
		rm ${ResultsFolder}/Names.txt
	fi

	Names=`cat ${dtseries}_${g_out_string}.txt | head -1 | sed 's/,/ /g'`
	
	i=1
	for Name in ${Names} ; do
		if [ ${i} -gt 4 ] ; then
			log_Msg "Adding ${Name} to ${ResultsFolder}/Names.txt"
			echo ${Name} >> ${ResultsFolder}/Names.txt
		fi
		i=$((${i}+1))
	done
	
	# --------------------------------------------------------------------------------
	log_Msg "Set map names in CIFTI dscalar"
	# --------------------------------------------------------------------------------	

	# ----------------------------------------
	# Input File(s)
	# ----------------------------------------

	# ciftiIn - Generated by Matlab 
	ciftiIn="${ResultsFolder}/${g_fmri_name}_Atlas${RegString}_${g_out_string}.dtseries.nii"

	# nameFile - From Previous Step
	nameFile="${ResultsFolder}/Names.txt"

	# ----------------------------------------
	# Output File(s)
	# ----------------------------------------
	# ciftiOut - newly created file
	ciftiOut="${ResultsFolder}/${g_fmri_name}_Atlas${RegString}_${g_out_string}.dscalar.nii"

	direction="ROW"
	${CARET7DIR}/wb_command -cifti-convert-to-scalar ${ciftiIn} ${direction} ${ciftiOut} -name-file ${nameFile}

	rm ${nameFile}
	rm ${ciftiIn}

	# --------------------------------------------------------------------------------
	log_Msg "Set Palette in CIFTI dscalar"
	# --------------------------------------------------------------------------------

	# ----------------------------------------
	# Input File(s)
	# ----------------------------------------

	# ciftiIn - From Previous Step
	ciftiIn="${ResultsFolder}/${g_fmri_name}_Atlas${RegString}_${g_out_string}.dscalar.nii"

	# ----------------------------------------
	# Output File(s)
	# ----------------------------------------

	# ciftiOut - same as input file
	ciftiOut="${ciftiIn}"

	mode="MODE_AUTO_SCALE_PERCENTAGE"
	${CARET7DIR}/wb_command -cifti-palette ${ciftiIn} ${mode} ${ciftiOut} \
		-pos-percent 4 96 -neg-percent 4 96 -interpolate true \
		-disp-pos true -disp-neg true -disp-zero true \
		-palette-name videen_style

	# --------------------------------------------------------------------------------
	log_Msg "Rename files for MSMAll or SingleSubjectConcat script"
	# --------------------------------------------------------------------------------

	mv \
		${ResultsFolder}/${g_fmri_name}_Atlas${RegString}_vn.dscalar.nii \
		${ResultsFolder}/${g_fmri_name}_Atlas${RegString}${g_output_proc_string}_vn.dscalar.nii

	mv \
		${ResultsFolder}/${g_fmri_name}_Atlas${RegString}_BiasField.dscalar.nii \
		${ResultsFolder}/${g_fmri_name}_Atlas${RegString}${g_output_proc_string}_bias.dscalar.nii

	# --------------------------------------------------------------------------------
	log_Msg "Remove unneeded intermediate files"
	# --------------------------------------------------------------------------------

	find ${ResultsFolder} -type f -name "BiasField*" -print -delete
}

# 
# Invoke the main function to get things started
#
main $@
