#!/bin/bash 

Subjlist="PostMortem1" #Space delimited list of subject IDs
StudyFolder="/media/myelin/brainmappers/Connectome_Project/Macaques" #Location of Subject folders (named by subjectID)
EnvironmentScript="/media/2TBB/Connectome_Project/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

# Requirements for this script
#  installed versions of: FSL (version 5.0.6 or later), FreeSurfer (version 5.3.0-HCP or later), gradunwarp (HCP version 1.0.0)
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

#Scripts called by this script do assume they run on the results of the HCP minimal preprocesing pipelines from Q2

######################################### DO WORK ##########################################

LowResMesh="32" #32 if using HCP minimal preprocessing pipeline outputs

for Subject in $Subjlist ; do

  ${FSLDIR}/bin/fsl_sub ${QUEUE} \
    ${HCPPIPEDIR}/DiffusionTractography/PreTractography.sh \
    --path=$StudyFolder \
    --subject=$Subject \
    --lowresmesh=$LowResMesh 

  # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...

    echo "set -- --path=$StudyFolder \
    --subject=$Subject \
    --lowresmesh=$LowResMesh"

    echo ". ${EnvironmentScript}"

done
