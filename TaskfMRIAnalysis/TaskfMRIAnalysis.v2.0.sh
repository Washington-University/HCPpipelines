#!/bin/bash 
set -e
g_script_name=`basename ${0}`

source ${HCPPIPEDIR}/global/scripts/log.shlib # Logging related functions
log_SetToolName "${g_script_name}"

# Requirements for this script
#  installed versions of: FSL5.0.7 or higher , FreeSurfer (version 5 or higher) , gradunwarp (python code from MGH) 
#  environment: use SetUpHCPPipeline.sh  (or individually set FSLDIR, FREESURFER_HOME, HCPPIPEDIR, PATH - for gradient_unwarp.py)

# make pipeline engine happy...
if [ $# -eq 1 ]
then
    echo "Version unknown..."
    exit 0
fi

########################################## PIPELINE OVERVIEW ########################################## 

# TODO

########################################## OUTPUT DIRECTORIES ########################################## 

# TODO

################################################ SUPPORT FUNCTIONS ##################################################

# function for parsing options
getopt1() {
    sopt="$1"
    shift 1
    for fn in $@ ; do
	if [ `echo $fn | grep -- "^${sopt}=" | wc -w` -gt 0 ] ; then
	    echo $fn | sed "s/^${sopt}=//"
	    return 0
	fi
    done
}

defaultopt() {
    echo $1
}

################################################## OPTION PARSING #####################################################

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi

# parse arguments
Path=`getopt1 "--path" $@`  
log_Msg "Path: ${Path}"

Subject=`getopt1 "--subject" $@`  
log_Msg "Subject: ${Subject}"

LevelOnefMRINames=`getopt1 "--lvl1tasks" $@`
log_Msg "LevelOnefMRINames: ${LevelOnefMRINames}"

LevelOnefsfNames=`getopt1 "--lvl1fsfs" $@`
log_Msg "LevelOnefsfNames: ${LevelOnefsfNames}"

LevelTwofMRIName=`getopt1 "--lvl2task" $@`
log_Msg "LevelTwofMRIName: ${LevelTwofMRIName}"

LevelTwofsfNames=`getopt1 "--lvl2fsf" $@`
log_Msg "LevelTwofsfNames: ${LevelTwofsfNames}" 

LowResMesh=`getopt1 "--lowresmesh" $@`  
log_Msg "LowResMesh: ${LowResMesh}"

GrayordinatesResolution=`getopt1 "--grayordinatesres" $@` 
log_Msg "GrayordinatesResolution: ${GrayordinatesResolution}"

OriginalSmoothingFWHM=`getopt1 "--origsmoothingFWHM" $@`  
log_Msg "OriginalSmoothingFWHM: ${OriginalSmoothingFWHM}"

Confound=`getopt1 "--confound" $@`
log_Msg "Confound: ${Confound}"

FinalSmoothingFWHM=`getopt1 "--finalsmoothingFWHM" $@`
log_Msg "FinalSmoothingFWHM: ${FinalSmoothingFWHM}"

TemporalFilter=`getopt1 "--temporalfilter" $@`
log_Msg "TemporalFilter: ${TemporalFilter}"

VolumeBasedProcessing=`getopt1 "--vba" $@`
log_Msg "VolumeBasedProcessing: ${VolumeBasedProcessing}"

RegName=`getopt1 "--regname" $@`
log_Msg "RegName: ${RegName}"

Parcellation=`getopt1 "--parcellation" $@`
log_Msg "Parcellation: ${Parcellation}"

ParcellationFile=`getopt1 "--parcellationfile" $@`
log_Msg "ParcellationFile: ${ParcellationFile}" 

# Setup PATHS
PipelineScripts=${HCPPIPEDIR_tfMRIAnalysis}
# GlobalScripts=${HCPPIPEDIR_Global}
GlobalBinaries=${HCPPIPEDIR_Bin}

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
  ${PipelineScripts}/TaskfMRILevel1.v2.0.sh $Subject $ResultsFolder $ROIsFolder $DownSampleFolder $LevelOnefMRIName $LevelOnefsfName $LowResMesh $GrayordinatesResolution $OriginalSmoothingFWHM $Confound $FinalSmoothingFWHM $TemporalFilter $VolumeBasedProcessing $RegName $Parcellation $ParcellationFile 
  echo "set -- $Subject $ResultsFolder $ROIsFolder $DownSampleFolder $LevelOnefMRIName $LevelOnefsfName $LowResMesh $GrayordinatesResolution $OriginalSmoothingFWHM $Confound $FinalSmoothingFWHM $TemporalFilter $VolumeBasedProcessing $RegName $Parcellation $ParcellationFile"
  i=$(($i+1))
done

LevelOnefMRINames=`echo $LevelOnefMRINames | sed 's/ /@/g'`
LevelOnefsfNames=`echo $LevelOnefMRINames | sed 's/ /@/g'`

#Combine Data Across Phase Encoding Directions in the Level Two Analysis
log_Msg "Combine Data Across Phase Encoding Directions in the Level Two Analysis"
${PipelineScripts}/TaskfMRILevel2.v2.0.sh $Subject $ResultsFolder $DownSampleFolder $LevelOnefMRINames $LevelOnefsfNames $LevelTwofMRIName $LevelTwofsfNames $LowResMesh $FinalSmoothingFWHM $TemporalFilter $VolumeBasedProcessing $RegName $Parcellation
echo "set -- $Subject $ResultsFolder $DownSampleFolder $LevelOnefMRINames $LevelOnefsfNames $LevelTwofMRIName $LevelTwofsfNames $LowResMesh $FinalSmoothingFWHM $TemporalFilter $VolumeBasedProcessing $RegName $Parcellation"



