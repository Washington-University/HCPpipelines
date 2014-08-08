#!/bin/bash 

StudyFolder="${HOME}/projects/Pipelines_ExampleData" #Location of Subject folders (named by subjectID)
Subjlist="100307" #Space delimited list of subject IDs
EnvironmentScript="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

EchoSpacing=0.78 #EPI Echo Spacing for data (in msec)
PEdir=1 #Use 1 for Left-Right Phase Encoding, 2 for Anterior-Posterior

# Requirements for this script
#  installed versions of: FSL (version 5.0.6 or later), FreeSurfer (version 5.3.0-HCP or later) , gradunwarp (HCP version 1.0.2)
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET7DIR , PATH (for gradient_unwarp.py)

#Set up pipeline environment variables and software
. ${EnvironmentScript}

Gdcoeffs="${HCPPIPEDIR_Config}/coeff_SC72C_Skyra.grad" #Coefficients that describe spatial variations of the scanner gradients. Use NONE if not available.

Diffusion="unprocessed/3T/Diffusion"

# Log the originating call
echo "$@"

#Assume that submission nodes have OPENMP enabled (needed for eddy - at least 8 cores suggested for HCP data)
if [ X$SGE_ROOT != X ] ; then
    QUEUE="-q verylong.q"
fi

PRINTCOM=""


########################################## INPUTS ########################################## 

#Scripts called by this script do assume they run on the outputs of the PreFreeSurfer Pipeline

######################################### DO WORK ##########################################

for Subject in $Subjlist ; do
  #Input Variables
  SubjectID="$Subject" #Subject ID Name
  RawDataDir="$StudyFolder/$SubjectID/$Diffusion" #Folder where unprocessed diffusion data are

  # Data with positive Phase encoding direction. Up to N>=1 series (here N=3), separated by @
  PosData="${RawDataDir}/${SubjectID}_3T_DWI_dir95_RL.nii.gz@${RawDataDir}/${SubjectID}_3T_DWI_dir96_RL.nii.gz@${RawDataDir}/${SubjectID}_3T_DWI_dir97_RL.nii.gz"

  # Data with negative Phase encoding direction. Up to N>=1 series (here N=3), separated by @
  # If corresponding series is missing (e.g. 2 RL series and 1 LR) use EMPTY.
  NegData="${RawDataDir}/${SubjectID}_3T_DWI_dir95_LR.nii.gz@${RawDataDir}/${SubjectID}_3T_DWI_dir96_LR.nii.gz@${RawDataDir}/${SubjectID}_3T_DWI_dir97_LR.nii.gz"
  
  ${FSLDIR}/bin/fsl_sub ${QUEUE} \
     ${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline.sh \
      --posData="${PosData}" --negData="${NegData}" \
      --path="${StudyFolder}" --subject="${SubjectID}" \
      --echospacing="${EchoSpacing}" --PEdir=${PEdir} \
      --gdcoeffs="${Gdcoeffs}" \
      --printcom=$PRINTCOM

done

