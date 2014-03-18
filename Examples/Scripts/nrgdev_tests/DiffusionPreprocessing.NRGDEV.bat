#!/bin/bash 

#Subjlist="100307 103414" #Space delimited list of subject IDs
Subjlist="792564"

#StudyFolder="/vols/Data/HCP/TestStudyFolder" #Location of Subject folders (named by subjectID)
StudyFolder="/home/NRG/tbrown01/projects/Pipelines/Examples"

#EnvironmentScript="/vols/Data/HCP/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script
EnvironmentScript="/home/NRG/tbrown01/projects/Pipelines/Examples/Scripts/nrgdev_tests/SetUpHCPPipeline.NRGDEV.sh"

EchoSpacing=0.78 #EPI Echo Spacing for data (in msec)
PEdir=1 #Use 1 for Left-Right Phase Encoding, 2 for Anterior-Posterior
#Gdcoeffs="/vols/Data/HCP/Pipelines/global/config/coeff_SC72C_Skyra.grad" #Coefficients that describe spatial variations of the scanner gradients. Use NONE if not available.
Gdcoeffs="/home/NRG/tbrown01/projects/Pipelines/global/config/coeff_SC72C_Skyra.grad"

# Requirements for this script
#  installed versions of: FSL5.0.5 or higher , FreeSurfer (version 5.2 or higher) , gradunwarp (python code from MGH)
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET7DIR , PATH (for gradient_unwarp.py)

#Set up pipeline environment variables and software
. ${EnvironmentScript}

# Log the originating call
echo "$@"

#Assume that submission nodes have OPENMP enabled (needed for eddy - at least 8 cores suggested for HCP data)
if [ X$SGE_ROOT != X ] ; then
    QUEUE="-q verylong.q"
fi

PRINTCOM="echo"


########################################## INPUTS ########################################## 

#Scripts called by this script do assume they run on the outputs of the PreFreeSurfer Pipeline

######################################### DO WORK ##########################################

for Subject in $Subjlist ; do
 echo "Subject: ${Subject}"
  #Input Variables
  SubjectID="$Subject" #Subject ID Name
  RawDataDir="$StudyFolder/$SubjectID/$Diffusion" #Folder where unprocessed diffusion data are
  PosData="${RawDataDir}/RL_data1@${RawDataDir}/RL_data2@${RawDataDir}/RL_data3" #Data with positive Phase encoding direction. Up to N>=1 series (here N=3), separated by @
  NegData="${RawDataDir}/LR_data1@${RawDataDir}/LR_data2@${RawDataDir}/LR_data3" #Data with negative Phase encoding direction. Up to N>=1 series (here N=3), separated by @
                                                                                 #If corresponding series is missing (e.g. 2 RL series and 1 LR) use EMPTY.
  
  ${FSLDIR}/bin/fsl_sub ${QUEUE} \
     ${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline.sh \
      --posData="${PosData}" --negData="${NegData}" \
      --path="${StudyFolder}" --subject="${SubjectID}" \
      --echospacing="${EchoSpacing}" --PEdir=${PEdir} \
      --gdcoeffs="${Gdcoeffs}" \
      --printcom=$PRINTCOM

done

