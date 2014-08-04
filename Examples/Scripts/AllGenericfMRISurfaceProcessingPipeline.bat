#!/bin/bash 

Subjlist="792564" #Space delimited list of subject IDs
StudyFolder="/media/myelin/brainmappers/Connectome_Project/TestStudyFolder" #Location of Subject folders (named by subjectID)
EnvironmentScript="/media/2TBB/Connectome_Project/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

# Requirements for this script
#  installed versions of: FSL (version 5.0.6 or later), FreeSurfer (version 5.3.0-HCP or later) , gradunwarp (HCP version 1.0.0)
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET7DIR , PATH (for gradient_unwarp.py)

#Set up pipeline environment variables and software
. ${EnvironmentScript}

# Log the originating call
echo "$@"

if [ X$SGE_ROOT != X ] ; then
    QUEUE="-q long.q"
fi

PRINTCOM=""
#PRINTCOM="echo"
#QUEUE="-q veryshort.q"

########################################## INPUTS ########################################## 

#Scripts called by this script do assume they run on the outputs of the FreeSurfer Pipeline

######################################### DO WORK ##########################################


Tasklist="tfMRI_EMOTION_RL tfMRI_EMOTION_LR"

for Subject in $Subjlist ; do
  for fMRIName in $Tasklist ; do
    LowResMesh="32" #Needs to match what is in PostFreeSurfer
    FinalfMRIResolution="2" #Needs to match what is in fMRIVolume
    SmoothingFWHM="2" #Recommended to be roughly the voxel size
    GrayordinatesResolution="2" #Needs to match what is in PostFreeSurfer. Could be the same as FinalfRMIResolution something different, which will call a different module for subcortical processing

    ${FSLDIR}/bin/fsl_sub $QUEUE \
      ${HCPPIPEDIR}/fMRISurface/GenericfMRISurfaceProcessingPipeline.sh \
      --path=$StudyFolder \
      --subject=$Subject \
      --fmriname=$fMRIName \
      --lowresmesh=$LowResMesh \
      --fmrires=$FinalfMRIResolution \
      --smoothingFWHM=$SmoothingFWHM \
      --grayordinatesres=$GrayordinatesResolution \
      --regname="MSMSulc"

  # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...

      echo "set -- --path=$StudyFolder \
      --subject=$Subject \
      --fmriname=$fMRIName \
      --lowresmesh=$LowResMesh \
      --fmrires=$FinalfMRIResolution \
      --smoothingFWHM=$SmoothingFWHM \
      --grayordinatesres=$GrayordinatesResolution \
      --regname=\"MSMSulc\""

      echo ". ${EnvironmentScript}"
            
   done
done

