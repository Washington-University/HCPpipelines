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
# This script is a simple dispatching script for running Task fMRI Analysis.  It determines what
# version of [FSL][FSL] is installed and in use and then invokes either V1.0 of the Task fMRI Analysis
# if the version of [FSL][FSL] is 5.0.6 or earlier or V2.0 of the Task fMRI Analysis if the version 
# of [FSL][FSL] is 5.0.7 or later.
#
# The ${FSLDIR}/etc/fslversion file is used to determine the version of [FSL][FSL] in use.
#
# <!-- References -->                                                                                                             
# [HCP]: http://www.humanconnectome.org
# [FSL]: http://fsl.fmrib.ox.ac.uk
#
#~ND~END~   

# If any command used in this script exits with a non-zero value, this script itself exits 
# and does not attempt any further processing.
set -e


########################################## PREPARE FUNCTIONS ########################################## 

# Load function libraries
source ${HCPPIPEDIR}/global/scripts/log.shlib  # Logging related functions
source ${HCPPIPEDIR}/global/scripts/opts.shlib # Command line option functions
source ${HCPPIPEDIR}/global/scripts/fsl_version.shlib	# Function for getting FSL version


# function to test FSL versions
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


########################################## READ_ARGS ##################################

# Explcitly set tool name for logging
log_SetToolName "TaskfMRIAnalysis.sh"

# Show version of HCP Pipeline Scripts in use if requested
opts_ShowVersionIfRequested $@

# Parse expected arguments from command-line array
log_Msg "READ_ARGS: Parsing Command Line Options"
Path=`opts_GetOpt1 "--path" $@`
Subject=`opts_GetOpt1 "--subject" $@`
LevelOnefMRINames=`opts_GetOpt1 "--lvl1tasks" $@`
LevelOnefsfNames=`opts_GetOpt1 "--lvl1fsfs" $@`
LevelTwofMRIName=`opts_GetOpt1 "--lvl2task" $@`
LevelTwofsfNames=`opts_GetOpt1 "--lvl2fsf" $@`
LowResMesh=`opts_GetOpt1 "--lowresmesh" $@`
GrayordinatesResolution=`opts_GetOpt1 "--grayordinatesres" $@`
OriginalSmoothingFWHM=`opts_GetOpt1 "--origsmoothingFWHM" $@`
Confound=`opts_GetOpt1 "--confound" $@`
FinalSmoothingFWHM=`opts_GetOpt1 "--finalsmoothingFWHM" $@`
TemporalFilter=`opts_GetOpt1 "--temporalfilter" $@`
VolumeBasedProcessing=`opts_GetOpt1 "--vba" $@`
RegName=`opts_GetOpt1 "--regname" $@`
Parcellation=`opts_GetOpt1 "--parcellation" $@`
ParcellationFile=`opts_GetOpt1 "--parcellationfile" $@`

# Write command-line arguments to log file
log_Msg "READ_ARGS: Path: ${Path}"
log_Msg "READ_ARGS: Subject: ${Subject}"
log_Msg "READ_ARGS: LevelOnefMRINames: ${LevelOnefMRINames}"
log_Msg "READ_ARGS: LevelOnefsfNames: ${LevelOnefsfNames}"
log_Msg "READ_ARGS: LevelTwofMRIName: ${LevelTwofMRIName}"
log_Msg "READ_ARGS: LevelTwofsfNames: ${LevelTwofsfNames}"
log_Msg "READ_ARGS: LowResMesh: ${LowResMesh}"
log_Msg "READ_ARGS: GrayordinatesResolution: ${GrayordinatesResolution}"
log_Msg "READ_ARGS: OriginalSmoothingFWHM: ${OriginalSmoothingFWHM}"
log_Msg "READ_ARGS: Confound: ${Confound}"
log_Msg "READ_ARGS: FinalSmoothingFWHM: ${FinalSmoothingFWHM}"
log_Msg "READ_ARGS: TemporalFilter: ${TemporalFilter}"
log_Msg "READ_ARGS: VolumeBasedProcessing: ${VolumeBasedProcessing}"
log_Msg "READ_ARGS: RegName: ${RegName}"
log_Msg "READ_ARGS: Parcellation: ${Parcellation}"
log_Msg "READ_ARGS: ParcellationFile: ${ParcellationFile}"


########################################## MAIN #########################################

# Determine if required FSL version is present
fsl_version_get fsl_ver
old_or_new_version=$(determine_old_or_new_fsl ${fsl_ver})
if [ "${old_or_new_version}" == "OLD" ]
then
	# Need to exit script due to incompatible FSL VERSION!!!!
	log_Msg "MAIN: TEST_FSL_VERSION: ERROR: Detected pre-5.0.7 version of FSL in use (version ${fsl_ver}). Task fMRI Analysis not invoked. Exiting."
	exit 1
else
	log_Msg "MAIN: TEST_FSL_VERSION: Beginning analyses with FSL version ${fsl_ver}"
fi

# Determine locations of necessary directories (using expected naming convention)
AtlasFolder="${Path}/${Subject}/MNINonLinear"
ResultsFolder="${AtlasFolder}/Results"
ROIsFolder="${AtlasFolder}/ROIs"
DownSampleFolder="${AtlasFolder}/fsaverage_LR${LowResMesh}k"


# Run Level 1 analyses for each phase encoding direction (from command line arguments)
log_Msg "MAIN: RUN_LEVEL1: Running Level 1 Analysis for Both Phase Encoding Directions"
i=1
# Level 1 analysis names were delimited by '@' in command-line; change to space in for loop
for LevelOnefMRIName in $( echo $LevelOnefMRINames | sed 's/@/ /g' ) ; do
	log_Msg "MAIN: RUN_LEVEL1: LevelOnefMRIName: ${LevelOnefMRIName}"	
	# Get corresponding fsf name from $LevelOnefsfNames list
	LevelOnefsfName=`echo $LevelOnefsfNames | cut -d "@" -f $i`
	log_Msg "MAIN: RUN_LEVEL1: Issuing command: ${HCPPIPEDIR_tfMRIAnalysis}/TaskfMRILevel1.sh $Subject $ResultsFolder $ROIsFolder $DownSampleFolder $LevelOnefMRIName $LevelOnefsfName $LowResMesh $GrayordinatesResolution $OriginalSmoothingFWHM $Confound $FinalSmoothingFWHM $TemporalFilter $VolumeBasedProcessing $RegName $Parcellation $ParcellationFile"
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
	  $ParcellationFile
	i=$(($i+1))
done

if [ "$LevelTwofMRIName" != "NONE" ]
then
	# Combine Data Across Phase Encoding Directions in the Level 2 Analysis
	log_Msg "MAIN: RUN_LEVEL2: Combine Data Across Phase Encoding Directions in the Level 2 Analysis"
	log_Msg "MAIN: RUN_LEVEL2: Issuing command: ${HCPPIPEDIR_tfMRIAnalysis}/TaskfMRILevel2.sh $Subject $ResultsFolder $DownSampleFolder $LevelOnefMRINames $LevelOnefsfNames $LevelTwofMRIName $LevelTwofsfNames $LowResMesh $FinalSmoothingFWHM $TemporalFilter $VolumeBasedProcessing $RegName $Parcellation"
	${HCPPIPEDIR_tfMRIAnalysis}/TaskfMRILevel2.sh \
	  $Subject \
	  $ResultsFolder \
	  $DownSampleFolder \
	  $LevelOnefMRINames \
	  $LevelOnefsfNames \
	  $LevelTwofMRIName \
	  $LevelTwofsfNames \
	  $LowResMesh \
	  $FinalSmoothingFWHM \
	  $TemporalFilter \
	  $VolumeBasedProcessing \
	  $RegName \
	  $Parcellation
fi

log_Msg "MAIN: Completed"

