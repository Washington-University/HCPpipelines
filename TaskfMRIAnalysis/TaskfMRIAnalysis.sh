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

# Load function libraries
source ${HCPPIPEDIR}/global/scripts/log.shlib  # Logging related functions
source ${HCPPIPEDIR}/global/scripts/opts.shlib # Command line option funtions

# Establish tool name for logging
log_SetToolName "TaskfMRIAnalysis.sh"

# Other utility functions

get_fsl_version()
{
	local fsl_version_file
	local fsl_version
	local __functionResultVar=${1}

	fsl_version_file="${FSLDIR}/etc/fslversion"

	if [ -f ${fsl_version_file} ]
	then
		fsl_version=`cat ${fsl_version_file}`
		log_Msg "INFO: Determined that the FSL version in use is ${fsl_version}"
	else
		log_Msg "ERROR: Cannot tell which version of FSL you are using."
		exit 1
	fi

	eval $__functionResultVar="'${fsl_version}'"
}

#
# NOTE: 
#   Don't echo anything in this function other than the last echo
#   that outputs the return value
#   
determine_old_or_new_fsl()
{
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


# Show version of HCP Pipeline Scripts in use if requested
opts_ShowVersionIfRequested $@

log_Msg "Parsing Command Line Options"

Path=`opts_GetOpt1 "--path" $@`
log_Msg "Path: ${Path}"

Subject=`opts_GetOpt1 "--subject" $@`
log_Msg "Subject: ${Subject}"

LevelOnefMRINames=`opts_GetOpt1 "--lvl1tasks" $@`
log_Msg "LevelOnefMRINames: ${LevelOnefMRINames}"

LevelOnefsfNames=`opts_GetOpt1 "--lvl1fsfs" $@`
log_Msg "LevelOnefsfNames: ${LevelOnefsfNames}"

LevelTwofMRIName=`opts_GetOpt1 "--lvl2task" $@`
log_Msg "LevelTwofMRIName: ${LevelTwofMRIName}"

LevelTwofsfNames=`opts_GetOpt1 "--lvl2fsf" $@`
log_Msg "LevelTwofsfNames: ${LevelTwofsfNames}"

LowResMesh=`opts_GetOpt1 "--lowresmesh" $@`
log_Msg "LowResMesh: ${LowResMesh}"

GrayordinatesResolution=`opts_GetOpt1 "--grayordinatesres" $@`
log_Msg "GrayordinatesResolution: ${GrayordinatesResolution}"

OriginalSmoothingFWHM=`opts_GetOpt1 "--origsmoothingFWHM" $@`
log_Msg "OriginalSmoothingFWHM: ${OriginalSmoothingFWHM}"

Confound=`opts_GetOpt1 "--confound" $@`
log_Msg "Confound: ${Confound}"

FinalSmoothingFWHM=`opts_GetOpt1 "--finalsmoothingFWHM" $@`
log_Msg "FinalSmoothingFWHM: ${FinalSmoothingFWHM}"

TemporalFilter=`opts_GetOpt1 "--temporalfilter" $@`
log_Msg "TemporalFilter: ${TemporalFilter}"

VolumeBasedProcessing=`opts_GetOpt1 "--vba" $@`
log_Msg "VolumeBasedProcessing: ${VolumeBasedProcessing}"

RegName=`opts_GetOpt1 "--regname" $@`
log_Msg "RegName: ${RegName}"

Parcellation=`opts_GetOpt1 "--parcellation" $@`
log_Msg "Parcellation: ${Parcellation}"

ParcellationFile=`opts_GetOpt1 "--parcellationfile" $@`
log_Msg "ParcellationFile: ${ParcellationFile}"

# Determine the version of FSL that is in use
get_fsl_version fsl_ver
log_Msg "FSL version: ${fsl_ver}"

# Determine whether to invoke the "OLD" (v1.0) or "NEW" (v2.0) version of Task fMRI Analysis
old_or_new_version=$(determine_old_or_new_fsl ${fsl_ver})

if [ "${old_or_new_version}" == "OLD" ]
then
	log_Msg "INFO: Detected pre-5.0.7 version of FSL is in use. Invoking v1.0 of Task fMRI Analysis."
	if [ "${RegName}" != "" ] 
	then
		log_Msg "INFO: V2.0 option: --regname=${RegName} ignored"
	fi

 	if [ "${Parcellation}" != "" ]
	then
		log_Msg "INFO: V2.0 option: --parcellation=${Parcellation} ignored"
	fi

 	if [ "${ParcellationFile}" != "" ]
	then
		log_Msg "INFO: V2.0 option: --parcellationfile=${ParcellationFile} ignored"
	fi

	${HCPPIPEDIR}/TaskfMRIAnalysis/TaskfMRIAnalysis.v1.0.sh \
	    --path=${Path} \
	    --subject=${Subject} \
	    --lvl1tasks=${LevelOnefMRINames} \
	    --lvl1fsfs=${LevelOnefsfNames} \
	    --lvl2task=${LevelTwofMRIName} \
	    --lvl2fsf=${LevelTwofsfNames} \
	    --lowresmesh=${LowResMesh} \
	    --grayordinatesres=${GrayordinatesResolution} \
	    --origsmoothingFWHM=${OriginalSmoothingFWHM} \
	    --confound=${Confound} \
	    --finalsmoothingFWHM=${FinalSmoothingFWHM} \
	    --temporalfilter=${TemporalFilter} \
	    --vba=${VolumeBasedProcessing}

else
	log_Msg "INFO: Detected version 5.0.7 or newer of FSL is in use. Invoking v2.0 of Task fMRI Analysis."

	${HCPPIPEDIR}/TaskfMRIAnalysis/TaskfMRIAnalysis.v2.0.sh \
	    --path=${Path} \
	    --subject=${Subject} \
	    --lvl1tasks=${LevelOnefMRINames} \
	    --lvl1fsfs=${LevelOnefsfNames} \
	    --lvl2task=${LevelTwofMRIName} \
	    --lvl2fsf=${LevelTwofsfNames} \
	    --lowresmesh=${LowResMesh} \
	    --grayordinatesres=${GrayordinatesResolution} \
	    --origsmoothingFWHM=${OriginalSmoothingFWHM} \
	    --confound=${Confound} \
	    --finalsmoothingFWHM=${FinalSmoothingFWHM} \
	    --temporalfilter=${TemporalFilter} \
	    --vba=${VolumeBasedProcessing} \
	    --regname=${RegName} \
	    --parcellation=${Parcellation} \
	    --parcellationfile=${ParcellationFile}

fi

log_Msg "Completed"


