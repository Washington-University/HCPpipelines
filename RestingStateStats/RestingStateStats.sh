#!/bin/bash

#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # RestingStateStats.sh
#
# ## Copyright Notice
#
# Copyright (C) 2015 The Human Connectome Projet
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
# TBW
#
# ### Environment Variables
# 
# * HCPPIPEDIR
#  
#   The "home" directory for the HCP Pipeline product.
#   e.g. /home/tbrown01/projects/Pipelines
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
	echo "   [--reg-name=<registration name> (e.g. NONE or MSMSulc)] defaults to NONE if not specified"
	echo "    --low-res-mesh=<low resolution mesh size> (in thousands, e.g. 32 --> 32k)"
	echo "    --final-fmri-res=<final fMRI resolution> (in millimeters)"
	echo "    --brain-ordinates-res=<brain ordinates resolution> (in millimeters)"
	echo "    --smoothing-fwhm=<smoothing full width at half max>"
	echo "    --output-proc-string=<output processing string>"
	echo "   [--dlabel-file=<dlabel file>] defaults to NONE if not specified"
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

	# set default values 
	g_reg_name="NONE"
	g_dlabel_file="NONE"

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
			--fmri-name=*)
				g_fmri_name=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--high-pass=*)
				g_high_pass=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--reg-name=*)
				g_reg_name=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--low-res-mesh=*)
				g_low_res_mesh=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--final-fmri-res=*)
				g_final_fmri_res=${argument/*=/""}
				index=$(( index + 1 ))
				;;				
			--brain-ordinates-res=*)
				g_brain_ordinates_res=${argument/*=/""}
				index=$(( index + 1 ))
				;;				
			--smoothing-fwhm=*)
				g_smoothing_fwhm=${argument/*=/""}
				index=$(( index + 1 ))
				;;				
			--output-proc-string=*)
				g_output_proc_string=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--dlabel-file=*)
				g_dlabel_file=${argument/*=/""}
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

	### Calculate CIFTI version of the bias field (which is removed as part of the fMRI minimal pre-processing)
	### so that the bias field can be "restored" prior to the variance decomposition
	### i.e., so that the estimate variance at each grayordinate reflects the scaling of the original data
	### MG: Note that bias field correction and variance normalization are two incompatible goals
	log_Msg "Calculate CIFTI version of the bias field"

	Sigma=`echo "$g_smoothing_fwhm / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`

	#
	# Input File(s):
	#  -i filename of input image           ${AtlasFolder}/BiasField.nii.gz 
	#  -r filename for reference image      ${ResultsFolder}/${g_fmri_name}_SBRef.nii.gz
	#  --premat filename for pre-transform  ${FSLDIR}/etc/flirtsch/ident.mat
	#
	# Output File(s):
	#  -o ${ResultsFolder}/BiasField.${g_final_frmi_res}.nii.gz
	#

	${FSLDIR}/bin/applywarp \
		--rel \
		--interp=spline \
		-i ${AtlasFolder}/BiasField.nii.gz \
		-r ${ResultsFolder}/${g_fmri_name}_SBRef.nii.gz \
		--premat=${FSLDIR}/etc/flirtsch/ident.mat \
		-o ${ResultsFolder}/BiasField.${g_final_fmri_res}.nii.gz

	${FSLDIR}/bin/fslmaths \
		${ResultsFolder}/BiasField.${g_final_fmri_res}.nii.gz \
		-thr 0.1 ${ResultsFolder}/BiasField.${g_final_fmri_res}.nii.gz

	for Hemisphere in L R ; do
		log_Msg "Map bias field volume to surface using the same approach as when fMRI data are projected to the surface"

		# 
		# Input File(s):
		# 
		# Output File(s):
		#
		#
		volume="${ResultsFolder}/BiasField.${g_final_fmri_res}.nii.gz"
		surface="${NativeFolder}/${g_subject}.${Hemisphere}.midthickness.native.surf.gii"
		metricOut="${ResultsFolder}/BiasField.${Hemisphere}.native.func.gii"
		ribbonInner="${NativeFolder}/${g_subject}.${Hemisphere}.white.native.surf.gii"
		ribbonOutter="${NativeFolder}/${g_subject}.${Hemisphere}.pial.native.surf.gii"
		roiVolume="${ResultsFolder}/RibbonVolumeToSurfaceMapping/goodvoxels.nii.gz"
		${CARET7DIR}/wb_command \
			-volume-to-surface-mapping $volume $surface $metricOut \
			-ribbon-constrained $ribbonInner $ribbonOutter \
			-volume-roi $roiVolume








	done


	


}


# real_work to be incorporated into main


real_work()
{
	### Calculate CIFTI version of the bias field (which is removed as part of the fMRI minimal pre-processing)
	### so that the bias field can be "restored" prior to the variance decomposition
	### i.e., so that the estimate variance at each grayordinate reflects the scaling of the original data
	### MG: Note that bias field correction and variance normalization are two incompatible goals

#	Sigma=`echo "$g_smoothing_fwhm / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`

#	applywarp --rel --interp=spline -i ${AtlasFolder}/BiasField.nii.gz -r ${ResultsFolder}/${g_fmri_name}_SBRef.nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o ${ResultsFolder}/BiasField.${g_final_fmri_res}.nii.gz

#	fslmaths ${ResultsFolder}/BiasField.${g_final_fmri_res}.nii.gz -thr 0.1 ${ResultsFolder}/BiasField.${g_final_fmri_res}.nii.gz
	
	for Hemisphere in L R ; do
		#Map bias field volume to surface using the same approach as when fMRI data are projected to the surface
		volume="${ResultsFolder}/BiasField.${g_final_fmri_res}.nii.gz"
		surface="${NativeFolder}/${g_subject}.${Hemisphere}.midthickness.native.surf.gii"
		metricOut="${ResultsFolder}/BiasField.${Hemisphere}.native.func.gii"
		ribbonInner="${NativeFolder}/${g_subject}.${Hemisphere}.white.native.surf.gii"
		ribbonOutter="${NativeFolder}/${g_subject}.${Hemisphere}.pial.native.surf.gii"
		roiVolume="${ResultsFolder}/RibbonVolumeToSurfaceMapping/goodvoxels.nii.gz"
		#$Caret7_Command -volume-to-surface-mapping $volume $surface $metricOut -ribbon-constrained $ribbonInner $ribbonOutter -volume-roi $roiVolume
		${CARET7DIR}/wb_command -volume-to-surface-mapping $volume $surface $metricOut -ribbon-constrained $ribbonInner $ribbonOutter -volume-roi $roiVolume
		
		#Fill in any small holes with dilation again as is done with fMRI
		metric="${ResultsFolder}/BiasField.${Hemisphere}.native.func.gii"
		surface="${NativeFolder}/${g_subject}.${Hemisphere}.midthickness.native.surf.gii"
		distance="10"
		metricOut="${ResultsFolder}/BiasField.${Hemisphere}.native.func.gii"
		#$Caret7_Command -metric-dilate $metric $surface $distance $metricOut -nearest
		${CARET7DIR}/wb_command -metric-dilate $metric $surface $distance $metricOut -nearest
		
  		#Mask out the medial wall of dilated file
		metric="${ResultsFolder}/BiasField.${Hemisphere}.native.func.gii"
		mask="${NativeFolder}/${g_subject}.${Hemisphere}.roi.native.shape.gii"
		metricOut="${ResultsFolder}/BiasField.${Hemisphere}.native.func.gii"
		#$Caret7_Command -metric-mask $metric $mask $metricOut
		${CARET7DIR}/wb_command -metric-mask $metric $mask $metricOut
		
		#Resample the surface data from the native mesh to the standard mesh
		metricIn="${ResultsFolder}/BiasField.${Hemisphere}.native.func.gii"
		currentSphere="${NativeFolder}/${g_subject}.${Hemisphere}.sphere.${g_reg_name}.native.surf.gii"
		newSphere="${DownsampleFolder}/${g_subject}.${Hemisphere}.sphere.${g_low_res_mesh}k_fs_LR.surf.gii"
		method="ADAP_BARY_AREA"
		metricOut="${ResultsFolder}/BiasField.${Hemisphere}.${g_low_res_mesh}k_fs_LR.func.gii"
		currentArea="${NativeFolder}/${g_subject}.${Hemisphere}.midthickness.native.surf.gii"
		newArea="${DownsampleFolder}/${g_subject}.${Hemisphere}.midthickness.${g_low_res_mesh}k_fs_LR.surf.gii"
		roiMetric="${NativeFolder}/${g_subject}.${Hemisphere}.roi.native.shape.gii"
		#$Caret7_Command -metric-resample $metricIn $currentSphere $newSphere $method $metricOut -area-surfs $currentArea $newArea -current-roi $roiMetric
		${CARET7DIR}/wb_command -metric-resample $metricIn $currentSphere $newSphere $method $metricOut -area-surfs $currentArea $newArea -current-roi $roiMetric
	
		#Make sure the medial wall is zeros
		metric="${ResultsFolder}/BiasField.${Hemisphere}.${g_low_res_mesh}k_fs_LR.func.gii"
		mask="${DownsampleFolder}/${g_subject}.${Hemisphere}.atlasroi.${g_low_res_mesh}k_fs_LR.shape.gii"
		metricOut="${ResultsFolder}/BiasField.${Hemisphere}.${g_low_res_mesh}k_fs_LR.func.gii"
		#$Caret7_Command -metric-mask $metric $mask $metricOut
		${CARET7DIR}/wb_command -metric-mask $metric $mask $metricOut
	
		#Smooth the surface bias field the same as the fMRI
		surface="${DownsampleFolder}/${g_subject}.${Hemisphere}.midthickness.${g_low_res_mesh}k_fs_LR.surf.gii"
		metricIn="${ResultsFolder}/BiasField.${Hemisphere}.${g_low_res_mesh}k_fs_LR.func.gii"
		smoothingKernel="${Sigma}"
		metricOut="${ResultsFolder}/BiasField.${Hemisphere}.${g_low_res_mesh}k_fs_LR.func.gii"
		roiMetric="${DownsampleFolder}/${g_subject}.${Hemisphere}.atlasroi.${g_low_res_mesh}k_fs_LR.shape.gii"
		#$Caret7_Command -metric-smoothing $surface $metricIn $smoothingKernel $metricOut -roi $roiMetric
		${CARET7DIR}/wb_command -metric-smoothing $surface $metricIn $smoothingKernel $metricOut -roi $roiMetric
	done
  
	unset POSIXLY_CORRECT
	if [ 1 -eq `echo "$g_brain_ordinates_res == $g_final_fmri_res" | bc -l` ] ; then
		#If using the same fMRI and grayordinates space resolution, use the simple algorithm to project bias field into subcortical CIFTI space like fMRI
		volumeIn="${ResultsFolder}/BiasField.${g_final_fmri_res}.nii.gz"
		currentParcel="${ROIFolder}/ROIs.${g_brain_ordinates_res}.nii.gz"
		newParcel="${ROIFolder}/Atlas_ROIs.${g_brain_ordinates_res}.nii.gz"
		kernel="${Sigma}"
		volumeOut="${ResultsFolder}/BiasField_AtlasSubcortical.nii.gz"
		#$Caret7_Command -volume-parcel-resampling $volumeIn $currentParcel $newParcel $kernel $volumeOut -fix-zeros
		${CARET7DIR}/wb_command -volume-parcel-resampling $volumeIn $currentParcel $newParcel $kernel $volumeOut -fix-zeros
	else
		#If using different fMRI and grayordinates space resolutions, use the generic algorithm to project bias field into subcortical CIFTI space like fMRI
		volumeIn="${ResultsFolder}/BiasField.${g_final_fmri_res}.nii.gz"
		currentParcel="${ResultsFolder}/ROIs.${g_final_fmri_res}.nii.gz"
		newParcel="${ROIFolder}/Atlas_ROIs.${g_brain_ordinates_res}.nii.gz"
		kernel="${Sigma}"
		volumeOut="${ResultsFolder}/BiasField_AtlasSubcortical.nii.gz"
		#$Caret7_Command -volume-parcel-resampling-generic $volumeIn $currentParcel $newParcel $kernel $volumeOut -fix-zeros
		${CARET7DIR}/wb_command -volume-parcel-resampling-generic $volumeIn $currentParcel $newParcel $kernel $volumeOut -fix-zeros
	fi 

	#Create CIFTI file of bias field as was done with fMRI
	ciftiOut="${ResultsFolder}/${g_fmri_name}_Atlas${RegString}_BiasField.dscalar.nii"
	volumeData="${ResultsFolder}/BiasField_AtlasSubcortical.nii.gz"
	labelVolume="${ROIFolder}/Atlas_ROIs.${g_brain_ordinates_res}.nii.gz"
	lMetric="${ResultsFolder}/BiasField.L.${g_low_res_mesh}k_fs_LR.func.gii"
	lRoiMetric="${DownsampleFolder}/${g_subject}.L.atlasroi.${g_low_res_mesh}k_fs_LR.shape.gii"
	rMetric="${ResultsFolder}/BiasField.R.${g_low_res_mesh}k_fs_LR.func.gii"
	rRoiMetric="${DownsampleFolder}/${g_subject}.R.atlasroi.${g_low_res_mesh}k_fs_LR.shape.gii"
	#$Caret7_Command -cifti-create-dense-scalar $ciftiOut -volume $volumeData $labelVolume -left-metric $lMetric -roi-left $lRoiMetric -right-metric $rMetric -roi-right $rRoiMetric
	${CARET7DIR}/wb_command -cifti-create-dense-scalar $ciftiOut -volume $volumeData $labelVolume -left-metric $lMetric -roi-left $lRoiMetric -right-metric $rMetric -roi-right $rRoiMetric

	Mean=`fslstats ${ResultsFolder}/BiasField.${g_final_fmri_res}.nii.gz -k ${ResultsFolder}/${g_fmri_name}_SBRef.nii.gz -M`

	#Someone: don't paramaterize this, it messes up Var and -var Var structure somehow
	#MG: Not sure why unless you tried to change the math expression, question for Tim Coalson
	#$Caret7_Command -cifti-math "Var / ${Mean}" ${ResultsFolder}/BiasField.dscalar.nii -var Var ${ResultsFolder}/BiasField.dscalar.nii
	${CARET7DIR}/wb_command -cifti-math "Var / ${Mean}" ${ResultsFolder}/BiasField.dscalar.nii -var Var ${ResultsFolder}/BiasField.dscalar.nii

	### End creation of CIFTI bias field

	### Proceed to run the Matlab script

	motionparameters="${ResultsFolder}/Movement_Regressors" #No .txt
	TR=`$FSLDIR/bin/fslval ${ResultsFolder}/${g_fmri_name} pixdim4`
	ICAs="${ICAFolder}/melodic_mix"
	if [ -e ${FIXFolder}/HandNoise.txt ] ; then
		noise="${FIXFolder}/HandNoise.txt"
	else
		noise="${FIXFolder}/.fix"
	fi
	dtseries="${ResultsFolder}/${g_fmri_name}_Atlas${RegString}"
	bias="${ResultsFolder}/${g_fmri_name}_Atlas${RegString}_BiasField.dscalar.nii"

	matlab -nojvm -nodisplay -nosplash <<M_PROG
RestingStateStats('${motionparameters}',${g_high_pass},${TR},'${ICAs}','${noise}','${CARET7DIR}/wb_command','${dtseries}','${bias}',[],'${g_dlabel_file}');
M_PROG
	echo "RestingStateStats('${motionparameters}',${g_high_pass},${TR},'${ICAs}','${noise}','${CARET7DIR}/wb_command','${dtseries}','${bias}',[],'${g_dlabel_file}');"

	if [ -e ${ResultsFolder}/Names.txt ] ; then 
		rm ${ResultsFolder}/Names.txt
	fi

	Names=`cat ${dtseries}_stats.txt | head -1 | sed 's/,/ /g'`
	
	i=1
	for Name in ${Names} ; do
		if [ ${i} -gt 4 ] ; then
			echo ${Name} >> ${ResultsFolder}/Names.txt
		fi
		i=$((${i}+1))
	done

	#Set map names in CIFTI dscalar
	ciftiIn="${ResultsFolder}/${g_fmri_name}_Atlas${RegString}_stats.dtseries.nii"
	direction="ROW"
	ciftiOut="${ResultsFolder}/${g_fmri_name}_Atlas${RegString}_stats.dscalar.nii"
	nameFile="${ResultsFolder}/Names.txt"
	#$Caret7_Command -cifti-convert-to-scalar $ciftiIn $direction $ciftiOut -name-file $nameFile
	${CARET7DIR}/wb_command -cifti-convert-to-scalar $ciftiIn $direction $ciftiOut -name-file $nameFile

	rm ${ResultsFolder}/Names.txt ${ResultsFolder}/${g_frmi_name}_Atlas${RegString}_stats.dtseries.nii

	#Set Palette in CIFTI dscalar
	ciftiIn="${ResultsFolder}/${g_fmri_name}_Atlas${RegString}_stats.dscalar.nii"
	mode="MODE_AUTO_SCALE_PERCENTAGE"
	ciftiOut="${ResultsFolder}/${g_fmri_name}_Atlas${RegString}_stats.dscalar.nii"
	#$Caret7_Command -cifti-palette $ciftiIn $mode $ciftiOut -pos-percent 4 96 -neg-percent 4 96 -interpolate true -disp-pos true -disp-neg true -disp-zero true -palette-name videen_style
	${CARET7DIR}/wb_command -cifti-palette $ciftiIn $mode $ciftiOut -pos-percent 4 96 -neg-percent 4 96 -interpolate true -disp-pos true -disp-neg true -disp-zero true -palette-name videen_style

	#Rename files for MSMAll or SingleSubjectConcat script
	mv ${ResultsFolder}/${g_fmri_name}_Atlas${RegString}_vn.dscalar.nii ${ResultsFolder}/${g_fmri_name}_Atlas${RegString}${g_output_proc_string}_vn.dscalar.nii
}


# 
# Invoke the main function to get things started
#
main $@
