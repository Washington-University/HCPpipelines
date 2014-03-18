#!/bin/bash 
#
# Copyright Notice:
#
#   Copyright (C) 2014 Washington University in St. Louis
#   Author(s); Matthew F. Glasser, Timothy B. Brown
#
# Product:
#
#   Human Connectome Project (HCP) Pipeline Tools
#   http://www.humanconnectome.org
#
# Description:
#
#   This script, FreeSurferPipeLine.NRGDEV.bat, is an example of a wrapper
#   for invoking the FreeSurferPipeline.sh script to execute the second of
#   3 sub-parts of the Structural Preprocessing phase of the HCP Minimal
#   Preprocessing Pipelines. It is sometimes referred to as a 
#   "FreeSurferPipeline wrapper script"
#
#   This script:
#
#   1. Setups up variables to determine where input files will be found 
#      and what subjects to process
#   2. Sets up the environment necessary for runn the FreeSurferPipeline.sh
#      script (sets environment variables)
#
#   TODO:
#
# Prerequisites:
#
#   Environment Variables:
#
#     HCPPIPEDIR
#       The "home" directory for the version of the HCP Pipeline Tools product
#       being used. E.g. /nrgpackages/tools.release/hcp-pipeline-tools-v3.0
#
#   Installed Software:
#
#     TODO:

# Requirements for this script
#  installed versions of: FSL5.0.2 or higher , FreeSurfer (version 5.2 or higher) , gradunwarp (python code from MGH)
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET7DIR , PATH (for gradient_unwarp.py)


#
# Notes:
#
#   
# -----------------------------------------------------------------------------
#  Load Function Libraries
# -----------------------------------------------------------------------------

source ${HCPPIPEDIR}/global/scripts/log.shlib   # Logging related functions

# -----------------------------------------------------------------------------
#  Establish tool name for logging
# -----------------------------------------------------------------------------

log_SetToolName "FreeSurferPipeLine.NRGDEV.bat"

# -----------------------------------------------------------------------------
#  Setup Environment
# -----------------------------------------------------------------------------

# Establish the folder/directory in which all subject folders will be 
# found.

#StudyFolder="/media/myelin/brainmappers/Connectome_Project/TestStudyFolder"
StudyFolder="/home/NRG/tbrown01/projects/Pipelines/Examples"

# Establish the list of subject IDs to process. SubjList is a space delimited
# list of subject IDs. This script assumes that for each subject ID, there will
# be a directory named with the subject ID in the StudyFolder.
Subjlist="792564"

# Establish the location of the "Environment Script". The "Environment Script"
# sets up all the environment variables needed to run the FreeSurferPipeline.sh
# script.

#EnvironmentScript=\
#"/media/2TBB/Connectome_Project/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh"
EnvironmentScript=\
"/home/NRG/tbrown01/projects/Pipelines/Examples/Scripts/nrgdev_tests/SetUpHCPPipeline.NRGDEV.sh"

# Source the environment script to setup pipeline environment variables and 
# software
log_Msg "Sourcing environment script: ${EnvironmentScript}"
. ${EnvironmentScript}

# If the SGE_ROOT variable is not null, then we use that as an indication
# that the job (running the FreeSurferPipelinesh.sh script) will be submitted
# to a cluster via a job contraol system like SGE.
#
# In that case (SGE_ROOT variable is not null), we set the -q option for the
# fsl_sub command to indicate that the job will take more than 4 hours and 
# less than 24 hours.
#
# See the usage information for fls_sub to learn about other queue options
# (e.g. veryshort.q, short.q, etc.)
if [ -n "$SGE_ROOT" ] ; then
    QUEUE="-q long.q"
fi

# If the PRINTCOM variable is set to "echo", then the --printcom=echo option
# is passed to the invocation of the FreeSurferPipeline.sh script. The 
# --printcom=echo option causes FreeSurferPipeline.sh to simply echo the 
# significant commands that it would run instead of actually executing those
# commands. This can be useful for understanding and debugging purposes.
PRINTCOM=""
#PRINTCOM="echo"

# -----------------------------------------------------------------------------
#  Input files for FreeSurferPipeline.sh
# -----------------------------------------------------------------------------

# The FreeSurferPipeline.sh script _does_ assume that PreFreeSurfer pipeline
# script has been run from the subjects. It assumes that it is running on the
# outputs of that pipeline.

# -----------------------------------------------------------------------------
#  Do primary work
# -----------------------------------------------------------------------------

for Subject in $Subjlist ; do
    #Input Variables
    
    # FreeSurfer Subject ID
    SubjectID="$Subject"
    
    # Location to Put FreeSurfer Subject's Folder
    SubjectDIR="${StudyFolder}/${Subject}/T1w"
    
    # T1w FreeSurfer Input (Full Resolution)
    T1wImage="${StudyFolder}/${Subject}/T1w/T1w_acpc_dc_restore.nii.gz"
    
    # T1w FreeSurfer Input (Full Resolution)
    T1wImageBrain="${StudyFolder}/${Subject}/T1w/T1w_acpc_dc_restore_brain.nii.gz"
    
    # T2w FreeSurfer Input (Full Resolution)
    T2wImage="${StudyFolder}/${Subject}/T1w/T2w_acpc_dc_restore.nii.gz"

    # Submit (queue to a cluster or interactively submit) a run of the 
    # FreeSurferPipeline.sh script
    ${FSLDIR}/bin/fsl_sub ${QUEUE} \
        ${HCPPIPEDIR}/FreeSurfer/FreeSurferPipeline.sh \
               --subject="$Subject" \
               --subjectDIR="$SubjectDIR" \
               --t1="$T1wImage" \
               --t1brain="$T1wImageBrain" \
               --t2="$T2wImage" \
               --printcom=$PRINTCOM

    # The following lines are used for interactive debugging to set the
    # positional parameters: $1 $2 $3 ...

    # Is this really needed anymore?
    echo "set -- --subject="$Subject" \
        --subjectDIR="$SubjectDIR" \
        --t1="$T1wImage" \
        --t1brain="$T1wImageBrain" \
        --t2="$T2wImage" \
        --printcom=$PRINTCOM"

    echo ". ${EnvironmentScript}"
done

