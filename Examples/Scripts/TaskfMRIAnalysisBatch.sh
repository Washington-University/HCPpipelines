#!/bin/bash 

get_batch_options() {
    local arguments=($@)

    unset command_line_specified_study_folder
    unset command_line_specified_subj_list
    unset command_line_specified_run_local

    local index=0
    local numArgs=${#arguments[@]}
    local argument

    while [ ${index} -lt ${numArgs} ]; do
        argument=${arguments[index]}

        case ${argument} in
            --StudyFolder=*)
                command_line_specified_study_folder=${argument/*=/""}
                index=$(( index + 1 ))
                ;;
            --Subjlist=*)
                command_line_specified_subj_list=${argument/*=/""}
                index=$(( index + 1 ))
                ;;
            --runlocal)
                command_line_specified_run_local="TRUE"
                index=$(( index + 1 ))
                ;;
        esac
    done
}

get_batch_options $@

StudyFolder="${HOME}/projects/Pipelines_ExampleData" #Location of Subject folders (named by subjectID)
Subjlist="100307" #Space delimited list of subject IDs
EnvironmentScript="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi

if [ -n "${command_line_specified_subj_list}" ]; then
    Subjlist="${command_line_specified_subj_list}"
fi

# Requirements for this script
#  installed versions of: FSL (version 5.0.6)
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

SmoothingList="2" #Space delimited list for setting different final smoothings.  2mm is no more smoothing (above minimal preprocessing pipelines grayordinates smoothing).  Smoothing is added onto minimal preprocessing smoothing to reach desired amount
LowResMesh="32" #32 if using HCP minimal preprocessing pipeline outputs
GrayOrdinatesResolution="2" #2mm if using HCP minimal preprocessing pipeline outputs
OriginalSmoothingFWHM="2" #2mm if using HCP minimal preprocessing pipeline outputes
Confound="NONE" #File located in ${SubjectID}/MNINonLinear/Results/${fMRIName} or NONE
TemporalFilter="200" #Use 2000 for linear detrend, 200 is default for HCP task fMRI
VolumeBasedProcessing="NO" #YES or NO. CAUTION: Only use YES if you want unconstrained volumetric blurring of your data, otherwise set to NO for faster, less biased, and more senstive processing (grayordinates results do not use unconstrained volumetric blurring and are always produced).  

for FinalSmoothingFWHM in $SmoothingList ; do
  echo $FinalSmoothingFWHM

  i=1
  for LevelTwoTask in $LevelTwoTaskList ; do
    echo "  ${LevelTwoTask}"

    LevelOneTasks=`echo $LevelOneTasksList | cut -d " " -f $i`
    LevelOneFSFs=`echo $LevelOneFSFsList | cut -d " " -f $i`
    LevelTwoTask=`echo $LevelTwoTaskList | cut -d " " -f $i`
    LevelTwoFSF=`echo $LevelTwoFSFList | cut -d " " -f $i`
    for Subject in $Subjlist ; do
      echo "    ${Subject}"

      if [ -n "${command_line_specified_run_local}" ] ; then
          echo "About to run ${HCPPIPEDIR}/TaskfMRIAnalysis/TaskfMRIAnalysis.sh"
          queuing_command=""
      else
          echo "About to use fsl_sub to queue or run ${HCPPIPEDIR}/TaskfMRIAnalysis/TaskfMRIAnalysis.sh"
          queuing_command="${FSLDIR}/bin/fsl_sub ${QUEUE}"
      fi

      ${queuing_command} ${HCPPIPEDIR}/TaskfMRIAnalysis/TaskfMRIAnalysis.sh \
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
