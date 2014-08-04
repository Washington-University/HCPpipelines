#!/bin/bash 

Subjlist="792564" #Space delimited list of subject IDs
StudyFolder="/media/myelin/brainmappers/Connectome_Project/TestStudyFolder" #Location of Subject folders (named by subjectID)
EnvironmentScript="/media/2TBB/Connectome_Project/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

# Requirements for this script
#  installed versions of: FSL (version 5.0.6 or later)
#  environment: FSLDIR , HCPPIPEDIR , CARET7DIR 

#Set up pipeline environment variables and software
. ${EnvironmentScript}

# Log the originating call
echo "$@"

if [ X$SGE_ROOT != X ] ; then
    QUEUE="-q long.q"
fi

PRINTCOM=""
#PRINTCOM="echo"
QUEUE="-q veryshort.q"

########################################## INPUTS ########################################## 

#Scripts called by this script do assume they run on the results of the HCP minimal preprocesing pipelines from Q2

######################################### DO WORK ##########################################

LevelOneTasksList="tfMRI_EMOTION_RL@tfMRI_EMOTION_LR" #Delimit runs with @ and tasks with space
LevelOneFSFsList="tfMRI_EMOTION_RL@tfMRI_EMOTION_LR" #Delimit runs with @ and tasks with space
LevelTwoTaskList="tfMRI_EMOTION" #Space delimited list
LevelTwoFSFList="tfMRI_EMOTION" #Space delimited list

SmoothingList="4" #Space delimited list for setting different final smoothings.  2mm is no more smoothing (above minimal preprocessing pipelines grayordinates smoothing).  Smoothing is added onto minimal preprocessing smoothing to reach desired amount
LowResMesh="32" #32 if using HCP minimal preprocessing pipeline outputs
GrayOrdinatesResolution="2" #2mm if using HCP minimal preprocessing pipeline outputs
OriginalSmoothingFWHM="2" #2mm if using HCP minimal preprocessing pipeline outputes
Confound="NONE" #File located in ${SubjectID}/MNINonLinear/Results/${fMRIName} or NONE
TemporalFilter="200" #Use 2000 for linear detrend, 200 is default for HCP task fMRI
VolumeBasedProcessing="NO" #YES or NO. CAUTION: Only use YES if you want unconstrained volumetric blurring of your data, otherwise set to NO for faster, less biased, and more senstive processing (grayordinates results do not use unconstrained volumetric blurring and are always produced).  

for FinalSmoothingFWHM in $SmoothingList ; do
  i=1
  for LevelTwoTask in $LevelTwoTaskList ; do
    LevelOneTasks=`echo $LevelOneTasksList | cut -d " " -f $i`
    LevelOneFSFs=`echo $LevelOneFSFsList | cut -d " " -f $i`
    LevelTwoTask=`echo $LevelTwoTaskList | cut -d " " -f $i`
    LevelTwoFSF=`echo $LevelTwoFSFList | cut -d " " -f $i`
    for Subject in $Subjlist ; do

      ${FSLDIR}/bin/fsl_sub ${QUEUE} \
        ${HCPPIPEDIR}/TaskfMRIAnalysis/TaskfMRIAnalysis.sh \
        --path=$StudyFolder \
        --subject=$Subject \
        --lvl1tasks=$LevelOneTasks \
        --lvl1fsfs=$LevelOneFSFs \
        --lvl2task=$LevelTwoTask \
        --lvl2fsf=$LevelTwoFSF \
        --lowresmesh=$LowResMesh \
        --grayordinatesres=$GrayOrdinatesResolution \
        --origsmoothingFWHM=$OriginalSmoothingFWHM \
        --confound=$Confound \
        --finalsmoothingFWHM=$FinalSmoothingFWHM \
        --temporalfilter=$TemporalFilter \
        --vba=$VolumeBasedProcessing

  # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...

        echo "set -- --path=$StudyFolder \
        --subject=$Subject \
        --lvl1tasks=$LevelOneTasks \
        --lvl1fsfs=$LevelOneFSFs \
        --lvl2task=$LevelTwoTask \
        --lvl2fsf=$LevelTwoFSF \
        --lowresmesh=$LowResMesh \
        --grayordinatesres=$GrayOrdinatesResolution \
        --origsmoothingFWHM=$OriginalSmoothingFWHM \
        --confound=$Confound \
        --finalsmoothingFWHM=$FinalSmoothingFWHM \
        --temporalfilter=$TemporalFilter \
        --vba=$VolumeBasedProcessing"

        echo ". ${EnvironmentScript}"

    done
    i=$(($i+1))
  done
done
