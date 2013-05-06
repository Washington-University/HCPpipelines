#!/bin/bash 
set -e

# Requirements for this script
#  installed versions of: FSL5.0.2 or higher , FreeSurfer (version 5 or higher) , gradunwarp (python code from MGH) 
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
Path=`getopt1 "--path" $@`  # "$1"
Subject=`getopt1 "--subject" $@`  # "$2"
LevelOnefMRINames=`getopt1 "--lvl1tasks" $@`
LevelOnefsfNames=`getopt1 "--lvl1fsfs" $@`
LevelTwofMRIName=`getopt1 "--lvl2task" $@`
LevelTwofsfNames=`getopt1 "--lvl2fsf" $@`
LowResMesh=`getopt1 "--lowresmesh" $@`  # "$6"
GrayordinatesResolution=`getopt1 "--grayordinatesres" $@`  # "${14}"
OriginalSmoothingFWHM=`getopt1 "--origsmoothingFWHM" $@`  # "${14}"
Confound=`getopt1 "--confound" $@`
FinalSmoothingFWHM=`getopt1 "--finalsmoothingFWHM" $@`
TemporalFilter=`getopt1 "--temporalfilter" $@`
VolumeBasedProcessing=`getopt1 "--vba" $@`


# Setup PATHS
PipelineScripts=${HCPPIPEDIR_tfMRIAnalysis}
GlobalScripts=${HCPPIPEDIR_Global}
GlobalBinaries=${HCPPIPEDIR_Bin}

LevelOnefMRINames=`echo $LevelOnefMRINames | sed 's/@/ /g'`
LevelOnefsfNames=`echo $LevelOnefMRINames | sed 's/@/ /g'`

#Naming Conventions
AtlasFolder="${Path}/${Subject}/MNINonLinear"
ResultsFolder="${AtlasFolder}/Results"
ROIsFolder="${AtlasFolder}/ROIs"
DownSampleFolder="${AtlasFolder}/fsaverage_LR${LowResMesh}k"

#Run Level One Analysis for Both Phase Encoding Directions
i=1
for LevelOnefMRIName in $LevelOnefMRINames ; do
  LevelOnefsfName=`echo $LevelOnefsfNames | cut -d " " -f $i`
  ${PipelineScripts}/TaskfMRILevel1.sh $Subject $ResultsFolder $ROIsFolder $DownSampleFolder $LevelOnefMRIName $LevelOnefsfName $LowResMesh $GrayordinatesResolution $OriginalSmoothingFWHM $Confound $FinalSmoothingFWHM $TemporalFilter $VolumeBasedProcessing 
  echo "set -- $Subject $ResultsFolder $ROIsFolder $DownSampleFolder $LevelOnefMRIName $LevelOnefsfName $LowResMesh $GrayordinatesResolution $OriginalSmoothingFWHM $Confound $FinalSmoothingFWHM $TemporalFilter $VolumeBasedProcessing"
  i=$(($i+1))
done

LevelOnefMRINames=`echo $LevelOnefMRINames | sed 's/ /@/g'`
LevelOnefsfNames=`echo $LevelOnefMRINames | sed 's/ /@/g'`

#Combine Data Across Phase Encoding Directions in the Level Two Analysis
${PipelineScripts}/TaskfMRILevel2.sh $Subject $ResultsFolder $DownSampleFolder $LevelOnefMRINames $LevelOnefsfNames $LevelTwofMRIName $LevelTwofsfNames $LowResMesh $FinalSmoothingFWHM $TemporalFilter $VolumeBasedProcessing
echo "set -- $Subject $ResultsFolder $DownSampleFolder $LevelOnefMRINames $LevelOnefsfNames $LevelTwofMRIName $LevelTwofsfNames $LowResMesh $FinalSmoothingFWHM $TemporalFilter $VolumeBasedProcessing"



