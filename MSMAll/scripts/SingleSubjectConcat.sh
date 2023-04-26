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
source "$HCPPIPEDIR/global/scripts/tempfiles.shlib" "$@"

#description to use in usage - syntax of parameters is now explained automatically
opts_SetScriptDescription "implements Single Subject Scan Concatenation"
#mandatory
#general inputs
opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder that contains all subjects" "--path"
opts_AddMandatory '--subject' 'Subject' '100206' "one subject ID"
opts_AddMandatory '--fmri-names-list' 'fMRINames' 'rfMRI_REST1_LR@rfMRI_REST1_RL...' "list of single-run fmri run names separated by @s"
opts_AddMandatory '--output-fmri-name' 'OutputfMRIName' 'rfMRI_REST' "name to give to concatenated single subject scan"
opts_AddMandatory '--fmri-proc-string' 'fMRIProcSTRING' 'string' "file name component representing the preprocessing already done, e.g. '_Atlas_hp0_clean'"
opts_AddMandatory '--output-proc-string' 'OutputProcSTRING' 'string' "the output file name component, e.g. '_vn'"
#optional inputs
opts_AddOptional '--start-frame' 'StartFrame' 'integer' "the starting frame to choose from each fMRI run (inclusive), defaults to '1'" '1'
opts_AddOptional '--end-frame' 'EndFrame' 'integer' "the ending frame to choose from each fMRI run (inclusive), defaults to '' which preserves the ending frame of every fMRI run from --fmri-names-list" ''
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
	if ((index == 0 )); then
		minFrames=${runFrames[index]}
	else
		if (( ${runFrames[index]}<minFrames )); then
			minFrames=${runFrames[index]}
		fi
	fi
done

EndFrameToUse=""
if [[ "$EndFrame" == "" ]]; then
	# preserving the timeseries to the end
	FrameString="Frame${StartFrame}ToTheEnd"
else
	# check valid frame range
	if ((StartFrame > minFrames ||  EndFrame > minFrames || StartFrame < 1 || EndFrame < 1 || StartFrame > EndFrame)); then
		log_Err_Abort "The provided start frame ${StartFrame} and end frame ${EndFrame} is not valid, it must be between the range 1 to ${minFrames}. Please check the fMRI runs."
	fi
	FrameString="Frame${StartFrame}To${EndFrame}"
fi

log_Msg "FrameString: ${FrameString}"

duration=0
for ((index = 0; index < ${#fMRINamesArray[@]}; ++index))
do
	TR="${runTR[index]}"
	if [[ "$EndFrame" == "" ]]; then
		Frames=$((runFrames[index]-StartFrame+1))
	else
		Frames=$((EndFrame-StartFrame+1))
	fi
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
	# mark temp files for mean, and timeseries after the processing
	tempfiles_add ${FrameMean} ${FrameOutput}
	# pick frames
	if [[ "$EndFrame" == "" ]]; then
		if ((StartFrame==1)); then
			# override the FrameDenseTCS with the full dense timeseries
			FrameDenseTCS=${FullDenseTCS}
		else
			tempfiles_add ${FrameDenseTCS}
			${Caret7_Command} -cifti-merge ${FrameDenseTCS} -cifti ${FullDenseTCS} -column ${StartFrame} -up-to ${runFrames[index]}
		fi
	else
		tempfiles_add ${FrameDenseTCS}
		${Caret7_Command} -cifti-merge ${FrameDenseTCS} -cifti ${FullDenseTCS} -column ${StartFrame} -up-to ${EndFrame}
	fi

	# mean file
	${Caret7_Command} -cifti-reduce ${FrameDenseTCS} MEAN ${FrameMean}
	
	# vn file
	OutputVN="${ResultsFolder}/${fMRIName}${fMRIProcSTRING}_vn.dscalar.nii"
	log_File_Must_Exist "$OutputVN"
	
	# demean + vn
	${Caret7_Command} -cifti-math "(TCS - Mean) / max(VN, 0.001)" ${FrameOutput} -var TCS ${FrameDenseTCS} -var Mean ${FrameMean} -select 1 1 -repeat -var VN ${OutputVN} -select 1 1 -repeat
	
	# construct the merge string
	MergeArray+=(-cifti "${FrameOutput}")
done

# save the frame range and duration info
log_Msg "FrameString: ${FrameString}"
log_Msg "DurationString: ${DurationString}"
#echo "${FrameString} ${DurationString}" > ${OutputFolder}/frames_duration.txt

# final output: concatenated file
${Caret7_Command} -cifti-merge "${OutputFolder}/${OutputfMRIName}${fMRIProcSTRING}${OutputProcSTRING}.dtseries.nii" "${MergeArray[@]}"

log_Msg "Completing SingleSubjectConcat"
