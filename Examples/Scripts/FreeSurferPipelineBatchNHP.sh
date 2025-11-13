#!/bin/bash 
set -e
# Requirements for this script
#  installed versions of: FSL6.0.4 or higher , FreeSurfer (version 6.0 or higher) , gradunwarp (python code from MGH)
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET7DIR , PATH (for gradient_unwarp.py)

usage () {
echo "Usage: $0 <StudyFolder> <SubjectID> <T2w type> <SPECIES> <RunMode>"
echo "    Runmode: 1 - 3"
exit 1
}
[ "$5" = "" ] && usage

StudyFolder=$1
Subjlist=$2
T2wType=$3
SPECIES=$4
RunMode=$5

#put the full path to your edited version of SetUpHCPPipeline.sh here
EnvironmentScript="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh"
source $EnvironmentScript

# Log the originating call
echo "$@"

#if [ X$SGE_ROOT != X ] ; then
#    QUEUE="-q long.q"
#fi

PRINTCOM=""
#PRINTCOM="echo"




########################################## INPUT




########################################## 

#Scripts called by this script do assume they run on the outputs of the PreFreeSurfer Pipeline

######################################### DO WORK ##########################################

for Subject in `echo $Subjlist | sed -e 's/@/ /g'` ; do

    #Input Variables
    SubjectID="$Subject" #FreeSurfer Subject ID Name
    SubjectDIR="${StudyFolder}/${Subject}/T1w" #Location to Put FreeSurfer Subject's Folder
    T1wImage="${StudyFolder}/${Subject}/T1w/T1w_acpc_dc_restore.nii.gz" #T1w FreeSurfer Input (Full Resolution)
    T1wImageBrain="${StudyFolder}/${Subject}/T1w/T1w_acpc_dc_restore_brain.nii.gz" #T1w FreeSurfer Input (Full Resolution) This is only used as an initial brainmask
    isFLAIR=false
    if [ -e "${StudyFolder}/${Subject}/T1w/T2w_acpc_dc_restore.nii.gz" ] ; then
        T2wImage="${StudyFolder}/${Subject}/T1w/T2w_acpc_dc_restore.nii.gz" #T2w FreeSurfer Input (Full Resolution)
        T2wType="${T2wType:=T2w}" # T2w, FLAIR. Default is T2w
        if [ "$T2wType" = "FLAIR" ] ; then 
            isFLAIR=true
        fi
    else
        T2wImage="NONE"
        T2wType=NONE
    fi
  
    ${HCPPIPEDIR}/FreeSurfer/FreeSurferPipelineNHP.sh \
        --subject="$Subject" \
        --subjectDIR="$SubjectDIR" \
        --t1="$T1wImage" \
        --t1brain="$T1wImageBrain" \
        --t2="$T2wImage" \
        --flair="$isFLAIR" \
        --species="$SPECIES" \
        --runmode="$RunMode" 

    # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...

    echo set -- --subject="$Subject" \
        --subjectDIR="$SubjectDIR" \
        --t1="$T1wImage" \
        --t1brain="$T1wImageBrain" \
        --t2="$T2wImage" \
        --flair="$isFLAIR" \
        --species="$SPECIES" \
        --runmode="$RunMode" 

    echo ". ${EnvironmentScript}"

done


