#!/bin/bash
#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # TaskfMRIAnalysis.sh
#
# ## Copyright (C) 2015 The Human Connectome Project
#
# * Washington University in St. Louis
# * University of Minnesota
# # Oxford University
#
# ## Author(s)
#
# * Timothy B. Brown, Neuroinformatics Research Group, Washington University in St. Louis
#
# ## Product
#
# [Human Connectome Project][HCP] (HCP) Pipelines
#
# ## License
#
# See the [LICENSE](https://github.com/Washington-University/Pipelines/blob/master/LICENCE.md) file
#
# ## Description
#
# This script is a simple dispatching script for running Task fMRI Analysis.  It checks 
# the ${FSLDIR}/etc/fslversion file to determine which version of [FSL][FSL] is installed,
# and aborts for [FSL][FSL] is 5.0.6 or earlier.
# 
# This script launches Level1 analyses (serially) for each value in the $LevelOnefMRINames
# variable. After the Level1 analyses have completed, the script launches a single Level2
# analysis instance to combine the multiple Level1 estimates into individual subject-level
# estimates. (Level2 analysis is omitted if $LevelTwofMRIName equals "NONE")
#
# <!-- References -->
# [HCP]: http://www.humanconnectome.org
# [FSL]: http://fsl.fmrib.ox.ac.uk
#
#~ND~END~

set -eu

# ------------------------------------------------------------------------------
#  Check that HCPPIPEDIR is defined and Load Function Libraries
# ------------------------------------------------------------------------------

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/fsl_version.shlib"	# Function for getting FSL version


# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

#this function gets called by opts_ParseArguments when --help is specified
function usage()
{
    #header text
    echo "
$log_ToolName: Run TaskfMRIAnalysis pipeline for a subject. Pipeline will run Level1 (scan-level) analyses, and Level2 (single subject-level) analysis as specified.

Usage: $log_ToolName arguments...
[ ] = optional; < > = user supplied value
"
    #automatic argument descriptions
    opts_ShowArguments
    
    #do not use exit, the parsing code takes care of it
}

# ------------------------------------------------------------------------------
#  Parse Command Line Options
# ------------------------------------------------------------------------------

#arguments to opts_Add*: switch, variable to set, name for inside of <> in help text, description, [default value if AddOptional], [compatibility flag, ...]
#help info for option gets printed like "--foo=<$3> - $4"
opts_AddMandatory '--study-folder' 'Path' '/path/to/study/folder' "directory containing imaging data for all subjects"
opts_AddMandatory '--subject' 'Subject' 'SubjectID' ""
opts_AddMandatory '--lvl1tasks' 'LevelOnefMRINames' 'ScanName1@ScanName2' "List of task fMRI scan names, which are the prefixes of the time series filename for the TaskName task. Multiple task fMRI scan names should be provided as a single string separated by '@' character." #Assumes these subdirectories are located in the SubjectID/MNINonLinear/Results directory. Also assumes that timeseries image filename begins with this string.
opts_AddOptional '--lvl1fsfs' 'LevelOnefsfNames' 'DesignName1@DesignName2' "List of design names, which are the prefixes of the fsf filenames for each scan run. Should contain same number of design files as time series images in --lvl1tasks option. (N-th design will be used for N-th time series image.) Separate multiple design names by '@' character. If no value is passed to --lvl1fsfs, the value will be set to the same list passed to --lvl1tasks."
opts_AddOptional '--lvl2task' 'LevelTwofMRIName' 'tfMRI_TaskName' "Name of Level2 subdirectory in which all Level2 feat directories are written for TaskName. Default is 'NONE', which means that no Level2 analysis will run." 'NONE'
opts_AddOptional '--lvl2fsf' 'LevelTwofsfName' 'DesignName_TaskName' "Prefix of design.fsf filename for the Level2 analysis for TaskName. If no value is passed to --lvl2fsf, the value will be set to the same list passed to --lvl2task."
opts_AddOptional '--summaryname' 'SummaryName' 'tfMRI_TaskName/DesignName_TaskName' "Naming convention for single-subject summary directory. Will not create summary directory for Level1 analysis if this flag is missing or set to NONE. Naming for Level1 summary directories should match naming of Level2 summary directories. Default when running Level2 analysis is derived from --lvl2task and --lvl2fsf options \"tfMRI_TaskName/DesignName_TaskName\"" 'NONE'
opts_AddOptional '--confound' 'Confound' 'filename' "Confound matrix text filename (e.g., output of fsl_motion_outliers). Assumes file is located in <SubjectID>/MNINonLinear/Results/<ScanName>. Default='NONE'" 'NONE'
opts_AddOptional '--origsmoothingFWHM' 'OriginalSmoothingFWHM' 'number' "Value (in mm FWHM) of smoothing applied during surface registration in fMRISurface pipeline. Default=2, which is appropriate for HCP minimal preprocessing pipeline outputs" '2'
opts_AddOptional '--finalsmoothingFWHM' 'FinalSmoothingFWHM' 'number' "Value (in mm FWHM) of total desired smoothing, reached by calculating the additional smoothing required and applying that additional amount to data previously smoothed in fMRISurface. Default=2, which is no additional smoothing above HCP minimal preprocessing pipelines outputs." '2'
opts_AddOptional '--highpassfilter' 'TemporalFilter' 'integer' "Apply *additional* highpass filter (in seconds) to time series and task design. This is above and beyond temporal filter applied during preprocessing. To apply no additional filtering, set to 'NONE'. Default=200" '200'
opts_AddOptional '--lowpassfilter' 'TemporalSmoothing' 'integer' "Apply *additional* lowpass filter (in seconds) to time series and task design. This is above and beyond temporal filter applied during preprocessing. Low pass filter is generally not advised for Task fMRI analyses. Default=NONE" 'NONE'
opts_AddOptional '--procstring' 'ProcSTRING' 'string' "String value in filename of time series image, specifying the additional processing that was previously applied (e.g., FIX-cleaned data with 'hp2000_clean' in filename). Default=NONE" 'NONE'
opts_AddOptional '--lowresmesh' 'LowResMesh' 'integer' "Value (in mm) that matches surface resolution for fMRI data. Default=32, which is appropriate for HCP minimal preprocessing pipeline outputs" '32'
opts_AddOptional '--grayordinatesres' 'GrayordinatesResolution' 'number' "Value (in mm) that matches value in 'Atlas_ROIs' filename; Default='2', which is appropriate for HCP minimal preprocessing pipeline outputs" '2'
opts_AddOptional '--regname' 'RegName' 'RegName' "Name of surface registration technique. Default=NONE, which will use the default (MSMSulc) surface registration." 'NONE'
opts_AddOptional '--vba' 'VolumeBasedProcessing' 'YES/NO' "Default=NO. CAUTION: Only use YES if you want unconstrained volumetric blurring of your data, otherwise set to NO for faster, less biased, and more senstive processing (grayordinates results do not use unconstrained volumetric blurring and are always produced)" 'NO'
opts_AddOptional '--parcellation' 'Parcellation' 'ParcellationName' "Name of parcellation scheme to conduct parcellated analysis. Default=NONE, which will perform dense analysis instead. Non-greyordinates parcellations are not supported because they are not valid for cerebral cortex.  Parcellation supersedes smoothing (i.e. no smoothing is done)" 'NONE'
opts_AddOptional '--parcellationfile' 'ParcellationFile' '/path/to/dlabel' "Absolute path to the parcellation dlabel file. Default=NONE" 'NONE'

opts_ParseArguments "$@"

# if LevelOnefsfNames is blank, set equal to LevelOnefMRINames
[ -z "$LevelOnefsfNames" ] && LevelOnefsfNames=${LevelOnefMRINames}
# if LevelTwofsfName is blank, set equal to LevelTwofMRIName
[ -z "$LevelTwofsfName" ] && LevelTwofsfName=${LevelTwofMRIName}

#display the parsed/default values
opts_ShowValues


# ------------------------------------------------------------------------------
#  Verify required environment variables are set and log value
# ------------------------------------------------------------------------------

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

log_Msg "Platform Information Follows: "
uname -a

${HCPPIPEDIR}/show_version

log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FSLDIR
log_Check_Env_Var CARET7DIR

HCPPIPEDIR_tfMRIAnalysis=${HCPPIPEDIR}/TaskfMRIAnalysis/scripts

# ------------------------------------------------------------------------------
#  Determine if required FSL version is present
# ------------------------------------------------------------------------------

# function to determine FSL version
determine_old_or_new_fsl()
{
	# NOTE:
	#   Don't echo anything in this function other than the last echo
	#   that outputs the return value
	#
	local fsl_version=${1}
	local old_or_new
	local fsl_version_array
	local fsl_primary_version
	local fsl_secondary_version
	local fsl_tertiary_version

	# parse the FSL version information into primary, secondary, and tertiary parts
	fsl_version_array=(${fsl_version//./ })

	fsl_primary_version="${fsl_version_array[0]}"
	fsl_primary_version=${fsl_primary_version//[!0-9]/}

	fsl_secondary_version="${fsl_version_array[1]}"
	fsl_secondary_version=${fsl_secondary_version//[!0-9]/}

	fsl_tertiary_version="${fsl_version_array[2]}"
	fsl_tertiary_version=${fsl_tertiary_version//[!0-9]/}

	# determine whether we are using "OLD" or "NEW" FSL
	# 5.0.6 and below is "OLD"
	# 5.0.7 and above is "NEW"
	if [[ $(( ${fsl_primary_version} )) -lt 5 ]]
	then
		# e.g. 4.x.x
		old_or_new="OLD"
	elif [[ $(( ${fsl_primary_version} )) -gt 5 ]]
	then
		# e.g. 6.x.x
		old_or_new="NEW"
	else
		# e.g. 5.x.x
		if [[ $(( ${fsl_secondary_version} )) -gt 0 ]]
		then
			# e.g. 5.1.x
			old_or_new="NEW"
		else
			# e.g. 5.0.x
			if [[ $(( ${fsl_tertiary_version} )) -le 6 ]]
			then
				# e.g. 5.0.5 or 5.0.6
				old_or_new="OLD"
			else
				# e.g. 5.0.7 or 5.0.8
				old_or_new="NEW"
			fi
		fi
	fi

	echo ${old_or_new}
}

# Determine if required FSL version is present
fsl_version_get fsl_ver
old_or_new_version=$(determine_old_or_new_fsl ${fsl_ver})
if [ "${old_or_new_version}" == "OLD" ]
then
	# Need to exit script due to incompatible FSL VERSION!!!!
	log_Err_Abort "Detected pre-5.0.7 version of FSL in use (version ${fsl_ver}). Task fMRI Analysis not invoked."
else
	log_Msg "Beginning analyses with FSL version ${fsl_ver}"
fi



########################################## MAIN #########################################

# Determine locations of necessary directories (using expected naming convention)
AtlasFolder="${Path}/${Subject}/MNINonLinear"
ResultsFolder="${AtlasFolder}/Results"
ROIsFolder="${AtlasFolder}/ROIs"
DownSampleFolder="${AtlasFolder}/fsaverage_LR${LowResMesh}k"


# Run Level 1 analyses for each phase encoding direction (from command line arguments)
log_Msg "RUN_LEVEL1: Running Level 1 Analysis for Both Phase Encoding Directions"
i=1
# Level 1 analysis names were delimited by '@' in command-line; change to space in for loop
for LevelOnefMRIName in $( echo $LevelOnefMRINames | sed 's/@/ /g' ) ; do
	log_Msg "RUN_LEVEL1: LevelOnefMRIName: ${LevelOnefMRIName}"
	# Get corresponding fsf name from $LevelOnefsfNames list
	LevelOnefsfName=`echo $LevelOnefsfNames | cut -d "@" -f $i`
	log_Msg "RUN_LEVEL1: Issuing command: ${HCPPIPEDIR_tfMRIAnalysis}/TaskfMRILevel1.sh $Subject $ResultsFolder $ROIsFolder $DownSampleFolder $LevelOnefMRIName $LevelOnefsfName $LowResMesh $GrayordinatesResolution $OriginalSmoothingFWHM $Confound $FinalSmoothingFWHM $TemporalFilter $VolumeBasedProcessing $RegName $Parcellation $ParcellationFile $ProcSTRING $TemporalSmoothing"
	${HCPPIPEDIR_tfMRIAnalysis}/TaskfMRILevel1.sh \
	  $Subject \
	  $ResultsFolder \
	  $ROIsFolder \
	  $DownSampleFolder \
	  $LevelOnefMRIName \
	  $LevelOnefsfName \
	  $LowResMesh \
	  $GrayordinatesResolution \
	  $OriginalSmoothingFWHM \
	  $Confound \
	  $FinalSmoothingFWHM \
	  $TemporalFilter \
	  $VolumeBasedProcessing \
	  $RegName \
	  $Parcellation \
	  $ParcellationFile \
	  $ProcSTRING \
	  $TemporalSmoothing
	i=$(($i+1))
done

if [ "$LevelTwofMRIName" != "NONE" ]
then
	# Combine Data Across Phase Encoding Directions in the Level 2 Analysis
	log_Msg "RUN_LEVEL2: Combine Data Across Phase Encoding Directions in the Level 2 Analysis"
	log_Msg "RUN_LEVEL2: Issuing command: ${HCPPIPEDIR_tfMRIAnalysis}/TaskfMRILevel2.sh $Subject $ResultsFolder $DownSampleFolder $LevelOnefMRINames $LevelOnefsfNames $LevelTwofMRIName $LevelTwofsfName $LowResMesh $FinalSmoothingFWHM $TemporalFilter $VolumeBasedProcessing $RegName $Parcellation $ProcSTRING $TemporalSmoothing"
	${HCPPIPEDIR_tfMRIAnalysis}/TaskfMRILevel2.sh \
	  $Subject \
	  $ResultsFolder \
	  $DownSampleFolder \
	  $LevelOnefMRINames \
	  $LevelOnefsfNames \
	  $LevelTwofMRIName \
	  $LevelTwofsfName \
	  $LowResMesh \
	  $FinalSmoothingFWHM \
	  $TemporalFilter \
	  $VolumeBasedProcessing \
	  $RegName \
	  $Parcellation \
	  $ProcSTRING \
	  $TemporalSmoothing
fi


if [ "$LevelTwofMRIName" != "NONE" ] || [ "$SummaryName" != "NONE" ];
then
	log_Msg "CREATE SUMMARY DIRECTORY: Creating subject-level summary directory from requested analyses."
	${HCPPIPEDIR_tfMRIAnalysis}/makeSubjectTaskSummary.sh \
		--study-folder=$Path \
		--subject=$Subject \
		--lvl1tasks=$LevelOnefMRINames \
		--lvl1fsfs=$LevelOnefsfNames \
		--lvl2task=$LevelTwofMRIName \
		--lvl2fsf=$LevelTwofsfName \
		--summaryname=$SummaryName \
		--confound=$Confound \
		--origsmoothingFWHM=$OriginalSmoothingFWHM \
		--finalsmoothingFWHM=$FinalSmoothingFWHM \
		--highpassfilter=$TemporalFilter \
		--lowpassfilter=$TemporalSmoothing \
		--procstring=$ProcSTRING \
		--lowresmesh=$LowResMesh \
		--grayordinatesres=$GrayordinatesResolution \
		--regname=$RegName \
		--vba=$VolumeBasedProcessing \
		--parcellation=$Parcellation \
		--parcellationfile=$ParcellationFile
fi

log_Msg "Completed!"

