#!/bin/bash

#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # PostFix.sh
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
# * ICA FIX processing
#
# ### Installed Software
#
# * Connectome Workbench (v1.0 or above)
# * FSL (version 5.0.6 or above)
#
# ### Environment Variables
#
# * HCPPIPEDIR
# * CARET7DIR
# * FSLDIR
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
	echo "  Compute PostFix ..."
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
	echo "    --template-scene-dual-screen=<template scene file>"
	echo "    --template-scene-single-screen=<template scene file>"
	echo ""
}

#
# Function Description:
#  Get the command line options for this script.
#  Shows usage information and exits if command line is malformed.
#
# Global Output Variables
#  ${g_path_to_study_folder} - path to folder containing subject data directories
#  ${g_subject} - subject ID
#  ${g_fmri_name} - fMRI name
#  ${g_high_pass} - high pass
#  ${g_template_scene_dual_screen} - template scene file
#  ${g_template_scene_single_screen} - template scene file
#
get_options()
{
	local arguments=($@)

	# initialize global output variables
	unset g_path_to_study_folder
	unset g_subject
	unset g_fmri_name
	unset g_high_pass
	unset g_template_scene_dual_screen
	unset g_template_scene_single_screen

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
			--template-scene-dual-screen=*)
				g_template_scene_dual_screen=${argument/*=/""}
				index=$(( index + 1 ))
				;;
			--template-scene-single-screen=*)
				g_template_scene_single_screen=${argument/*=/""}
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

	if [ -z "${g_template_scene_dual_screen}" ]; then
		echo "ERROR: template scene dual screen required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_template_scene_dual_screen: ${g_template_scene_dual_screen}"
	fi

	if [ -z "${g_template_scene_single_screen}" ]; then
		echo "ERROR: template scene single screen required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "g_template_scene_single_screen: ${g_template_scene_single_screen}"
	fi

	if [ ${error_count} -gt 0 ]; then
		echo "For usage information, use --help"
		exit 1
	fi
}

# 
# Function Descripton:
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

	ResultsFolder="${AtlasFolder}/Results/${g_fmri_name}"
	log_Msg "ResultsFolder: ${ResultsFolder}"

	ICAFolder="${ResultsFolder}/${g_fmri_name}_hp${g_high_pass}.ica/filtered_func_data.ica"
	log_Msg "ICAFolder: ${ICAFolder}"

	FIXFolder="${ResultsFolder}/${g_fmri_name}_hp${g_high_pass}.ica"
	log_Msg "FIXFolder: ${FIXFolder}"

	# --------------------------------------------------------------------------------
	log_Msg "Creating ${ICAFolder}/ICAVolumeSpace.txt file"
	# --------------------------------------------------------------------------------

	echo "OTHER" > "${ICAFolder}/ICAVolumeSpace.txt"
	echo "1 255 255 255 255" >> "${ICAFolder}/ICAVolumeSpace.txt"

	# --------------------------------------------------------------------------------
	log_Msg "Creating ${ICAFolder}/mask.nii.gz"
	# --------------------------------------------------------------------------------

	${FSLDIR}/bin/fslmaths ${ICAFolder}/melodic_oIC.nii.gz -Tstd -bin ${ICAFolder}/mask.nii.gz

	${CARET7DIR}/wb_command -volume-label-import ${ICAFolder}/mask.nii.gz ${ICAFolder}/ICAVolumeSpace.txt ${ICAFolder}/mask.nii.gz

	# --------------------------------------------------------------------------------
	log_Msg "Creating dense timeseries"
	# --------------------------------------------------------------------------------

	${CARET7DIR}/wb_command -cifti-create-dense-timeseries ${ICAFolder}/melodic_oIC_vol.dtseries.nii -volume ${ICAFolder}/melodic_oIC.nii.gz ${ICAFolder}/mask.nii.gz -timestep 1 -timestart 1

	# --------------------------------------------------------------------------------
	log_Msg "Set up for prepareICAs Matlab code"
	# --------------------------------------------------------------------------------

	dtseriesName="${ResultsFolder}/${g_fmri_name}_Atlas" #No Extension Here	
	log_Msg "dtseriesName: ${dtseriesName}"

	ICAs="${ICAFolder}/melodic_mix"
	log_Msg "ICAs: ${ICAs}"

	ICAdtseries="${ICAFolder}/melodic_oIC.dtseries.nii"
	log_Msg "ICAdtseries: ${ICAdtseries}"

	NoiseICAs="${FIXFolder}/.fix"
	log_Msg "NoiseICAs: ${NoiseICAs}"

	Noise="${FIXFolder}/Noise.txt"
	log_Msg "Noise: ${Noise}"

	Signal="${FIXFolder}/Signal.txt"
	log_Msg "Signal: ${Signal}"

	ComponentList="${FIXFolder}/ComponentList.txt"
	log_Msg "ComponentList: ${ComponentList}"

	TR=`${FSLDIR}/bin/fslval ${ResultsFolder}/${g_fmri_name}_hp2000_clean pixdim4`
	log_Msg "TR: ${TR}"

	NumTimePoints=`${FSLDIR}/bin/fslval ${ResultsFolder}/${g_fmri_name}_hp2000_clean dim4`
	log_Msg "NumTimePoints: ${NumTimePoints}"

	if [ -e ${ComponentList} ] ; then
		log_Msg "Removing ComponentList: ${ComponentList}"
		rm ${ComponentList}
	fi

	matlab_exe="${HCPPIPEDIR}"
	matlab_exe+="/PostFix/Compiled_prepareICAs/distrib/run_prepareICAs.sh"

	# TBD: Use environment variable instead of fixed path?
	matlab_compiler_runtime="/export/matlab/R2013a/MCR"

	matlab_function_arguments="'${dtseriesName}' '${ICAs}' '${CARET7DIR}/wb_command' '${ICAdtseries}' '${NoiseICAs}' '${Noise}' "
	matlab_function_arguments+="'${Signal}' '${ComponentList}' ${g_high_pass} ${TR} "

	matlab_logging=">> ${g_path_to_study_folder}/${g_subject}_${g_fmri_name}.matlab.log 2>&1"

	matlab_cmd="${matlab_exe} ${matlab_compiler_runtime} ${matlab_function_arguments} ${matlab_logging}"

	# --------------------------------------------------------------------------------
	log_Msg "Run matlab command: ${matlab_cmd}"
	# --------------------------------------------------------------------------------

	echo "${matlab_cmd}" | bash
	echo $?

	# --------------------------------------------------------------------------------
	log_Msg "Convert dense time series to scalar. Output ${ICAFolder}/melodic_oIC_vol.dscalar.nii"
	# --------------------------------------------------------------------------------
	${CARET7DIR}/wb_command -cifti-convert-to-scalar "$ICAFolder"/melodic_oIC_vol.dtseries.nii ROW "$ICAFolder"/melodic_oIC_vol.dscalar.nii -name-file ${ComponentList}
















}


#
# Invoke the main function to get things started
#
main $@

exit

#TBB Path="$1" # ${g_path_to_study_folder}
#TBB Subject="$2" # ${g_subject}
#TBB rfMRIName="$3" # ${g_fmri_name}
#TBB GitRepo="$4" # not used
#TBB HighPass="$5" # ${g_high_pass}

#TBB Caret7_Command="$6" # not used
#TBB TemplateSceneDualScreen="$7" # ${g_template_scene_dual_screen}
#TBB TemplateSceneSingleScreen="$8" # ${g_template_scene_single_screen}

#Naming Conventions
#TBB AtlasFolder="${Path}/${Subject}/MNINonLinear"
#TBB ResultsFolder="${AtlasFolder}/Results/${rfMRIName}"
#TBB ICAFolder="${ResultsFolder}/${rfMRIName}_hp${HighPass}.ica/filtered_func_data.ica"
#TBB FIXFolder="${ResultsFolder}/${rfMRIName}_hp${HighPass}.ica"

#TBB echo "OTHER" > "$ICAFolder"/ICAVolumeSpace.txt
#TBB echo "1 255 255 255 255" >> "$ICAFolder"/ICAVolumeSpace.txt



#TBB $FSLDIR/bin/fslmaths "$ICAFolder"/melodic_oIC.nii.gz -Tstd -bin "$ICAFolder"/mask.nii.gz

#TBB $Caret7_Command -volume-label-import "$ICAFolder"/mask.nii.gz "$ICAFolder"/ICAVolumeSpace.txt "$ICAFolder"/mask.nii.gz

#TBB $Caret7_Command -cifti-create-dense-timeseries "$ICAFolder"/melodic_oIC_vol.dtseries.nii -volume "$ICAFolder"/melodic_oIC.nii.gz "$ICAFolder"/mask.nii.gz -timestep 1 -timestart 1

#TBB dtseriesName="${ResultsFolder}/${rfMRIName}_Atlas" #No Extension Here
#TBB ICAs="${ICAFolder}/melodic_mix"
#TBB ICAdtseries="${ICAFolder}/melodic_oIC.dtseries.nii"
#TBB NoiseICAs="${FIXFolder}/.fix"
#TBB Noise="${FIXFolder}/Noise.txt"
#TBB Signal="${FIXFolder}/Signal.txt"
#TBB ComponentList="${FIXFolder}/ComponentList.txt"

#TBB TR=`$FSLDIR/bin/fslval ${ResultsFolder}/${rfMRIName}_hp2000_clean pixdim4`
#TBB NumTimePoints=`$FSLDIR/bin/fslval ${ResultsFolder}/${rfMRIName}_hp2000_clean dim4`

#TBB if [ -e ${ComponentList} ] ; then
#TBB  rm ${ComponentList}
#TBB fi

#TBB matlab <<M_PROG
#TBB prepareICAs('${dtseriesName}','${ICAs}','${Caret7_Command}','${ICAdtseries}','${NoiseICAs}','${Noise}','${Signal}','${ComponentList}',${HighPass},${TR});
#TBB M_PROG
#TBB echo "prepareICAs('${dtseriesName}','${ICAs}','${Caret7_Command}','${ICAdtseries}','${NoiseICAs}','${Noise}','${Signal}','${ComponentList}',${HighPass},${TR});"

#TBB ici


$Caret7_Command -cifti-convert-to-scalar "$ICAFolder"/melodic_oIC_vol.dtseries.nii ROW "$ICAFolder"/melodic_oIC_vol.dscalar.nii -name-file ${ComponentList}
#mv "$ICAFolder"/melodic_oIC_vol.dscalar.nii "$ICAFolder"/melodic_oIC_vol.dtseries.nii

$Caret7_Command -cifti-convert-to-scalar "$ICAFolder"/melodic_oIC.dtseries.nii ROW "$ICAFolder"/melodic_oIC.dscalar.nii -name-file ${ComponentList}
#mv "$ICAFolder"/melodic_oIC.dscalar.nii "$ICAFolder"/melodic_oIC.dtseries.nii

$Caret7_Command -cifti-create-scalar-series $ICAs $ICAs.sdseries.nii -transpose -name-file ${ComponentList} -series SECOND 0 ${TR}

# TimC: step=1/length-of-time-course-in-seconds=1/NumTimePoints*TR
FTmixStep=`echo "scale=7 ; 1/(${NumTimePoints}*${TR})" | bc -l`
$Caret7_Command -cifti-create-scalar-series ${ICAFolder}/melodic_FTmix ${ICAFolder}/melodic_FTmix.sdseries.nii -transpose -name-file ${ComponentList} -series HERTZ 0 ${FTmixStep}
rm ${ComponentList}

cat $TemplateSceneDualScreen | sed s/SubjectID/${Subject}/g | sed s/fMRIName/${rfMRIName}/g | sed s@StudyFolder@"../../../.."@g > ${ResultsFolder}/${Subject}_${rfMRIName}_ICA_Classification_dualscreen.scene
cat $TemplateSceneSingleScreen | sed s/SubjectID/${Subject}/g | sed s/fMRIName/${rfMRIName}/g | sed s@StudyFolder@"../../../.."@g > ${ResultsFolder}/${Subject}_${rfMRIName}_ICA_Classification_singlescreen.scene

if [ ! -e ${ResultsFolder}/ReclassifyAsSignal.txt ] ; then
  touch ${ResultsFolder}/ReclassifyAsSignal.txt
fi

if [ ! -e ${ResultsFolder}/ReclassifyAsNoise.txt ] ; then
  touch ${ResultsFolder}/ReclassifyAsNoise.txt
fi

