#!/bin/bash

#~ND~FORMAT~MARKDOWN
#~ND~START~
#
# # SingleSubjectConcat.sh
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

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source "$HCPPIPEDIR/global/scripts/tempfiles.shlib" "$@"

#description to use in usage - syntax of parameters is now explained automatically
opts_SetScriptDescription "implements Single Subject Scan Concatenation"
#mandatory
#general inputs
opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder that contains all subjects" "--path"
opts_AddMandatory '--subject' 'Subject' '100206' "one subject ID"
opts_AddMandatory '--fmri-names-list' 'fMRINames' 'rfMRI_REST1_LR@rfMRI_REST1_RL...' "list of single-run fmri run names separated by @s"
opts_AddMandatory '--output-fmri-name' 'OutputfMRIName' 'rfMRI_REST' "name to give to concatenated single subject scan"
opts_AddMandatory '--high-pass' 'HighPass' 'integer' 'the high pass value that was used when running FIX' '--melodic-high-pass'
opts_AddMandatory '--fmri-proc-string' 'fMRIProcSTRING' 'string' "file name component representing the preprocessing already done, e.g. '_Atlas_hp0_clean'"
opts_AddMandatory '--output-proc-string' 'OutputProcSTRING' 'string' "the output file name component, e.g. '_vn'"
#optional inputs
opts_AddOptional '--start-frame' 'StartFrame' 'integer' "the starting frame to choose from each fMRI run (inclusive), defaults to '1'" '1'
opts_AddOptional '--end-frame' 'EndFrame' 'integer' "the ending frame to choose from each fMRI run (inclusive), defaults to '' which will be overrided by the minimum frame length across the given list of fMRI runs" ''
opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

# Verify required environment variables are set and log value
log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var CARET7DIR

#display HCP Pipeline version
log_Msg "Showing HCP Pipelines version"
"${HCPPIPEDIR}"/show_version --short

# Show wb_command version
log_Msg "Showing wb_command version"
"${CARET7DIR}"/wb_command -version

#display the parsed/default values
opts_ShowValues

# ------------------------------------------------------------------------------
#  Main processing of script.
# ------------------------------------------------------------------------------
log_Msg "Starting Single Subject Scan Concatenation using the selected frame range"
# Naming Conventions and other variables
IFS='@' read -a fMRINamesArray <<< "${fMRINames}"
fMRINames=$(echo ${fMRINames} | sed 's/@/ /g')
log_Msg "fMRINames: ${fMRINames}"

if [ "${OutputProcSTRING}" = "NONE" ]; then
	OutputProcSTRING=""
fi
log_Msg "OutputProcSTRING: ${OutputProcSTRING}"

AtlasFolder="${StudyFolder}/${Subject}/MNINonLinear"
log_Msg "AtlasFolder: ${AtlasFolder}"

OutputFolder="${AtlasFolder}/Results/${OutputfMRIName}"
log_Msg "OutputFolder: ${OutputFolder}"
# create folder to save the concatenated file
mkdir -p "${OutputFolder}"

Caret7_Command=${CARET7DIR}/wb_command
log_Msg "Caret7_Command: ${Caret7_Command}"

# read frame informations
runFrames=()
runTR=()
for ((index = 0; index < ${#fMRINamesArray[@]}; ++index))
do
	fMRIName="${fMRINamesArray[index]}"
	ResultsFolder="${AtlasFolder}/Results/${fMRIName}"
	log_Msg "ResultsFolder: ${ResultsFolder}"
	FullDenseTCS=${ResultsFolder}/${fMRIName}${fMRIProcSTRING}.dtseries.nii
	log_Msg "FullDenseTCS: ${FullDenseTCS}"
	NumFrames=`${Caret7_Command} -file-information "${FullDenseTCS}" -only-number-of-maps`
	runFrames[index]="$NumFrames"
	TR=`${Caret7_Command} -file-information "${FullDenseTCS}" -only-step-interval`
	runTR[index]="$TR"
	if [ $((index)) -eq 0 ]; then
		minFrames=${runFrames[index]}
	else
		(( ${runFrames[index]}<minFrames )) && minFrames=${runFrames[index]}
	fi
done
if [[ "$EndFrame" == "" ]]; then
	EndFrame="$minFrames"
	log_Msg "EndFrame: ${EndFrame}"
fi
# check valid frame range
if [ $((StartFrame)) -gt "${minFrames}" ] || [ $((EndFrame)) -gt "${minFrames}" ] || [ $((StartFrame)) -lt 1 ] || [ $((EndFrame)) -lt 1 ] || [ $((StartFrame)) -gt $((EndFrame)) ]; then
	log_Err_Abort "The provided start frame ${StartFrame} and end frame ${EndFrame} is not valid, it must be between the range 1 to ${minFrames}. Please check the fMRI runs."
fi
log_Msg "StartFrame: ${StartFrame}, EndFrame: ${EndFrame}"
FrameString="Frame${StartFrame}To${EndFrame}"
duration=0
for ((index = 0; index < ${#fMRINamesArray[@]}; ++index))
do
	TR="${runTR[index]}"
	Frames=$((EndFrame-StartFrame+1))
	duration=$(bc -l <<< $duration+$TR*$Frames)
done

# convert to mins secs
m=$(bc <<< "${duration}/60")
s=$(bc <<< "${duration}%60")
DurationString="${m}mins${s}secs"

MergeArray=()
cnt=0
# loop for demean+vn+concat
for ((index = 0; index < ${#fMRINamesArray[@]}; ++index)) ; do
    fMRIName="${fMRINamesArray[$index]}"
	log_Msg "fMRIName: ${fMRIName}"
	ResultsFolder="${AtlasFolder}/Results/${fMRIName}"
	log_Msg "ResultsFolder: ${ResultsFolder}"
	
	FullDenseTCS=${ResultsFolder}/${fMRIName}${fMRIProcSTRING}.dtseries.nii
	# temporary files
	FrameDenseTCS=${ResultsFolder}/${fMRIName}${fMRIProcSTRING}_${FrameString}.dtseries.nii
	FrameMean=${ResultsFolder}/${fMRIName}${fMRIProcSTRING}_${FrameString}_mean.dscalar.nii
	FrameOutput=${ResultsFolder}/${fMRIName}${fMRIProcSTRING}_${FrameString}${OutputProcSTRING}.dtseries.nii

	# pick frames
	${Caret7_Command} -cifti-merge ${FrameDenseTCS} -cifti ${FullDenseTCS} -column ${StartFrame} -up-to ${EndFrame}

	# mean file
	${Caret7_Command} -cifti-reduce ${FrameDenseTCS} MEAN ${FrameMean}
	MATHDemean=" - Mean"
	VarDemean="-var Mean ${FrameMean} -select 1 1 -repeat"
	
	# vn file
	OutputVN="${ResultsFolder}/${fMRIName}${fMRIProcSTRING}_vn.dscalar.nii"
	log_File_Must_Exist "$OutputVN"
	MATHVN=" / max(VN,0.001)"
	VarVN="-var VN ${OutputVN} -select 1 1 -repeat"
	
  	# math expression
	MATH="(TCS${MATHDemean})${MATHVN}"
	log_Msg "MATH: ${MATH}"
	
	# demean + vn
	${Caret7_Command} -cifti-math "${MATH}" ${FrameOutput} -var TCS ${FrameDenseTCS} ${VarDemean} ${VarVN} 
	
	# construct the merge string
	MergeArray+=(-cifti "${FrameOutput}")
	
	# mark temp files for mean, selected range and timeseries after the above process
	tempfiles_add ${FrameMean} ${FrameDenseTCS} ${FrameOutput}
done

# save the frame range and duration info
log_Msg "FrameString: ${FrameString}"
log_Msg "DurationString: ${DurationString}"
#echo "${FrameString} ${DurationString}" > ${OutputFolder}/frames_duration.txt

# final output: concatenated file
${Caret7_Command} -cifti-merge "${OutputFolder}/${OutputfMRIName}${fMRIProcSTRING}${OutputProcSTRING}.dtseries.nii" "${MergeArray[@]}"

log_Msg "Completing SingleSubjectConcat"
