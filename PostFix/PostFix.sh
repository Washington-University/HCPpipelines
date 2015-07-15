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
# ### Installed Software
#
# ### Environment Variables
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
#  Document Tool Versions
#
show_tool_versions() {
	# Show HCP pipelines version
	log_Msg "Showing HCP Pipelines version"
	cat ${HCPPIPEDIR}/version.txt
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
	echo ""
}

#
# Function Description:
#  Get the command line options for this script.
#  Shows usage information and exits if command line is malformed.
#
# Global Output Variables
#  ${g_path_to_stud_folder} - path to folder containing subject data directories
#  ${g_subject} - subject ID
#  ${g_fmri_name} - fMRI name
#
get_options()
{
	local arguments=($@)

	# initialize global output variables
	unset g_path_to_study_folder
	unset g_subject
	unset g_fmri_name

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

}


#
# Invoke the main function to get things started
#
main $@

exit

Path="$1"
Subject="$2"
rfMRIName="$3"
GitRepo="$4"
HighPass="$5"
Caret7_Command="$6"
TemplateSceneDualScreen="$7"
TemplateSceneSingleScreen="$8"

#Naming Conventions
AtlasFolder="${Path}/${Subject}/MNINonLinear"
ResultsFolder="${AtlasFolder}/Results/${rfMRIName}"
ICAFolder="${ResultsFolder}/${rfMRIName}_hp${HighPass}.ica/filtered_func_data.ica"
FIXFolder="${ResultsFolder}/${rfMRIName}_hp${HighPass}.ica"

echo "OTHER" > "$ICAFolder"/ICAVolumeSpace.txt
echo "1 255 255 255 255" >> "$ICAFolder"/ICAVolumeSpace.txt

$FSLDIR/bin/fslmaths "$ICAFolder"/melodic_oIC.nii.gz -Tstd -bin "$ICAFolder"/mask.nii.gz
$Caret7_Command -volume-label-import "$ICAFolder"/mask.nii.gz "$ICAFolder"/ICAVolumeSpace.txt "$ICAFolder"/mask.nii.gz

$Caret7_Command -cifti-create-dense-timeseries "$ICAFolder"/melodic_oIC_vol.dtseries.nii -volume "$ICAFolder"/melodic_oIC.nii.gz "$ICAFolder"/mask.nii.gz -timestep 1 -timestart 1

dtseriesName="${ResultsFolder}/${rfMRIName}_Atlas" #No Extension Here
ICAs="${ICAFolder}/melodic_mix"
ICAdtseries="${ICAFolder}/melodic_oIC.dtseries.nii"
NoiseICAs="${FIXFolder}/.fix"
Noise="${FIXFolder}/Noise.txt"
Signal="${FIXFolder}/Signal.txt"
ComponentList="${FIXFolder}/ComponentList.txt"

TR=`$FSLDIR/bin/fslval ${ResultsFolder}/${rfMRIName}_hp2000_clean pixdim4`
NumTimePoints=`$FSLDIR/bin/fslval ${ResultsFolder}/${rfMRIName}_hp2000_clean dim4`

if [ -e ${ComponentList} ] ; then
  rm ${ComponentList}
fi

matlab <<M_PROG
prepareICAs('${dtseriesName}','${ICAs}','${Caret7_Command}','${ICAdtseries}','${NoiseICAs}','${Noise}','${Signal}','${ComponentList}',${HighPass},${TR});
M_PROG
echo "prepareICAs('${dtseriesName}','${ICAs}','${Caret7_Command}','${ICAdtseries}','${NoiseICAs}','${Noise}','${Signal}','${ComponentList}',${HighPass},${TR});"

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

