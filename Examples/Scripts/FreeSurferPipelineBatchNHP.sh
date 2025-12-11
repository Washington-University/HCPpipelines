#!/bin/bash 
set -e
# Requirements for this script
#  installed versions of: FSL6.0.4 or higher , FreeSurfer (version 6.0 or higher) , gradunwarp (python code from MGH)
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET7DIR , PATH (for gradient_unwarp.py)

Usage () {
    echo "$(basename $0) --StudyFolder=<path> --Subject=<id> --Species=<species> --RunMode=<mode> [--T2wType=<type>] [--EnvironmentScript=<path>]"
    echo ""
    echo "Required Options:"
    echo "  --StudyFolder: Path to the study folder containing subject data"
    echo "  --Subject: Subject identifier (multiple subjects can be separated by space or @)"
    echo "  --T2wType: T2w image type (T2w or FLAIR, default: T2w)"
    echo "  --Species: Species type (Human, Chimp, MacaqueCyno, MacaqueRhes, MacaqueFusc, NightMonkey, Marmoset)"
    echo "  --RunMode: Pipeline run mode (Default, FSinit, FSbrainseg, FSsurfinit, FShires, FSFinish)"
    echo ""
    exit 1
}

# ==== User-editable section ====

# Edit these variables before running

StudyFolder="${HOME}/projects/Pipelines_ExampleData"
Subjlist="nhp_session1 nhp_session2"
SPECIES="Macaque"
RunMode="Default"
T2wType="T2w"
EnvironmentScript="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh"

# Parse command line arguments
get_batch_options() {
    local arguments=("$@")
    
    local index=0
    local numArgs=${#arguments[@]}
    local argument
    
    while [ ${index} -lt ${numArgs} ]; do
        argument=${arguments[index]}
        
        case ${argument} in
            --StudyFolder=*)
                StudyFolder=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --Subject=*)
                Subjlist=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --T2wType=*)
                T2wType=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --Species=*)
                SPECIES=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --RunMode=*)
                RunMode=${argument#*=}
                index=$(( index + 1 ))
                ;;
            *)
                echo ""
                echo "ERROR: Unrecognized Option: ${argument}"
                echo ""
                Usage
                ;;
        esac
    done
}

# Parse arguments
get_batch_options "$@"

# Check required parameters
if [ -z "$StudyFolder" ] || [ -z "$Subjlist" ] || [ -z "$T2wType" ]  || [ -z "$SPECIES" ] || [ -z "$RunMode" ]; then
    echo "ERROR: Missing required parameters"
    Usage
fi

# Load environment script
if [ -z ${EnvironmentScript} ] ; then
    EnvironmentScript="$HCPPIPEDIR/Examples/Scripts/SetUpHCPPipeline.sh"
fi
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


