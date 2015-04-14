#!/bin/bash 
set -e

# Requirements for this script
#  installed versions of: FSL (version 5.0.6), FreeSurfer (version 5.3.0-HCP), gradunwarp (HCP version 1.0.2) 
#  environment: use SetUpHCPPipeline.sh  (or individually set FSLDIR, FREESURFER_HOME, HCPPIPEDIR, PATH - for gradient_unwarp.py)

########################################## PIPELINE OVERVIEW ########################################## 

# TODO

########################################## OUTPUT DIRECTORIES ########################################## 

# TODO

# --------------------------------------------------------------------------------
#  Load Function Libraries
# --------------------------------------------------------------------------------

source $HCPPIPEDIR/global/scripts/log.shlib  # Logging related functions
source $HCPPIPEDIR/global/scripts/opts.shlib # Command line option functions

################################################ SUPPORT FUNCTIONS ##################################################

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

show_usage() {
    echo "Usage information To Be Written"
    exit 1
}

# --------------------------------------------------------------------------------
#   Establish tool name for logging
# --------------------------------------------------------------------------------
log_SetToolName "TaskfMRIAnalysis.v1.0.sh"

################################################## OPTION PARSING #####################################################

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
    show_usage
fi

log_Msg "Parsing Command Line Options"

# parse arguments
Path=`opts_GetOpt1 "--path" $@`  # "$1"
Subject=`opts_GetOpt1 "--subject" $@`  # "$2"
LevelOnefMRINames=`opts_GetOpt1 "--lvl1tasks" $@`
LevelOnefsfNames=`opts_GetOpt1 "--lvl1fsfs" $@`
LevelTwofMRIName=`opts_GetOpt1 "--lvl2task" $@`
LevelTwofsfNames=`opts_GetOpt1 "--lvl2fsf" $@`
LowResMesh=`opts_GetOpt1 "--lowresmesh" $@`  # "$6"
GrayordinatesResolution=`opts_GetOpt1 "--grayordinatesres" $@`  # "${14}"
OriginalSmoothingFWHM=`opts_GetOpt1 "--origsmoothingFWHM" $@`  # "${14}"
Confound=`opts_GetOpt1 "--confound" $@`
FinalSmoothingFWHM=`opts_GetOpt1 "--finalsmoothingFWHM" $@`
TemporalFilter=`opts_GetOpt1 "--temporalfilter" $@`
VolumeBasedProcessing=`opts_GetOpt1 "--vba" $@`

# Setup PATHS
PipelineScripts=${HCPPIPEDIR_tfMRIAnalysis}

LevelOnefMRINames=`echo $LevelOnefMRINames | sed 's/@/ /g'`
LevelOnefsfNames=`echo $LevelOnefsfNames | sed 's/@/ /g'`

#Naming Conventions
AtlasFolder="${Path}/${Subject}/MNINonLinear"
ResultsFolder="${AtlasFolder}/Results"
ROIsFolder="${AtlasFolder}/ROIs"
DownSampleFolder="${AtlasFolder}/fsaverage_LR${LowResMesh}k"

#Run Level One Analysis for Both Phase Encoding Directions
log_Msg "Run Level One Analysis for Both Phase Encoding Directions"
i=1
for LevelOnefMRIName in $LevelOnefMRINames ; do
  log_Msg "LevelOnefMRIName: ${LevelOnefMRIName}"
  LevelOnefsfName=`echo $LevelOnefsfNames | cut -d " " -f $i`
  ${PipelineScripts}/TaskfMRILevel1.v1.0.sh $Subject $ResultsFolder $ROIsFolder $DownSampleFolder $LevelOnefMRIName $LevelOnefsfName $LowResMesh $GrayordinatesResolution $OriginalSmoothingFWHM $Confound $FinalSmoothingFWHM $TemporalFilter $VolumeBasedProcessing 
  echo "set -- $Subject $ResultsFolder $ROIsFolder $DownSampleFolder $LevelOnefMRIName $LevelOnefsfName $LowResMesh $GrayordinatesResolution $OriginalSmoothingFWHM $Confound $FinalSmoothingFWHM $TemporalFilter $VolumeBasedProcessing"
  i=$(($i+1))
done

LevelOnefMRINames=`echo $LevelOnefMRINames | sed 's/ /@/g'`
LevelOnefsfNames=`echo $LevelOnefMRINames | sed 's/ /@/g'`

#Combine Data Across Phase Encoding Directions in the Level Two Analysis
log_Msg "Combine Data Across Phase Encoding Directions in the Level Two Analysis"
${PipelineScripts}/TaskfMRILevel2.v1.0.sh $Subject $ResultsFolder $DownSampleFolder $LevelOnefMRINames $LevelOnefsfNames $LevelTwofMRIName $LevelTwofsfNames $LowResMesh $FinalSmoothingFWHM $TemporalFilter $VolumeBasedProcessing
echo "set -- $Subject $ResultsFolder $DownSampleFolder $LevelOnefMRINames $LevelOnefsfNames $LevelTwofMRIName $LevelTwofsfNames $LowResMesh $FinalSmoothingFWHM $TemporalFilter $VolumeBasedProcessing"

log_Msg "Completed"

