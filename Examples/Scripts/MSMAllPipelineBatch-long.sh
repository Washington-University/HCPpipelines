#!/bin/bash 

get_batch_options() {
    local arguments=("$@")

    command_line_specified_study_folder=""
    command_line_specified_subj=""
    command_line_specified_run_local="FALSE"

    local index=0
    local numArgs=${#arguments[@]}
    local argument

    while [ ${index} -lt ${numArgs} ]; do
        argument=${arguments[index]}

        case ${argument} in
            --StudyFolder=*)
                command_line_specified_study_folder=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --Subjlist=*)
                command_line_specified_subj=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --runlocal)
                command_line_specified_run_local="TRUE"
                index=$(( index + 1 ))
                ;;
        *)
        echo ""
        echo "ERROR: Unrecognized Option: ${argument}"
        echo ""
        exit 1
        ;;
        esac
    done
}

# Function description
#
# For the given subject, identify_timepoins creates a string listing @ separated visits/timepoints to process
# Uses StudyFolder, ExcludeVisits, PossibleVisits global variables as input.
# Subject must be supplied as the first argument. 

function identify_timepoints
{
    local subject=$1
    local tplist=""
    local tp visit n

    #build the list of timepoints
    n=0
    for visit in ${PossibleVisits[*]}; do
        tp="${subject}_${visit}"
        if [ -d "$StudyFolder/$tp" ] && ! [[ " ${ExcludeVisits[*]+${ExcludeVisits[*]}} " =~ [[:space:]]"$tp"[[:space:]] ]]; then
             if (( n==0 )); then 
                    tplist="$tp"
             else
                    tplist="$tplist@$tp"
             fi
        fi
        ((n++))
    done
    echo $tplist
}

get_batch_options "$@"

StudyFolder="${HOME}/data/Pipelines_ExampleData" #Location of Subject folders (named by subjectID)
#Space delimited list of subject IDs
Subjlist=(HCA6002236 HCA6002237 HCA6002238) 
EnvironmentScript="${StudyFolder}/scripts/SetUpHCPPipeline.sh"
#list of possible visits. Visit folder is expected to be named <Subject>_<Visit>
PossibleVisits="V1_MR V2_MR V3_MR" 
#Space delimited list of longitudinal template ID's, one per subject.
Templates=(HCA6002236_V1_V2_V3 HCA6002237_V1_V2 HCA6002238_V1_V2_V3)

#Pipeline environment script

if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi

if [ -n "${command_line_specified_subj}" ]; then
    Subjlist="${command_line_specified_subj}"
fi

# Requirements for this script
#  installed versions of: FSL, Connectome Workbench (wb_command)
#  environment: HCPPIPEDIR, FSLDIR, CARET7DIR 

#Set up pipeline environment variables and software
source "$EnvironmentScript"

# Log the originating call
echo "$@"

#NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
#DO NOT include "-q " at the beginning
#default to no queue, implying run local
QUEUE="short.q"
#QUEUE="hcp_priority.q"

########################################## INPUTS ########################################## 

#Scripts called by this script do assume they run on the results of the HCP minimal preprocesing pipelines from Q2

######################################### DO WORK ##########################################

# fMRINames is for single-run FIX data, set MR FIX settings to empty
# fMRINames="rfMRI_REST1_LR@rfMRI_REST1_RL@rfMRI_REST2_LR@rfMRI_REST2_RL"
# mrfixNames=""
# mrfixConcatName=""
# mrfixNamesToUse=""
# OutfMRIName="rfMRI_REST"

# For MR FIX, set fMRINames to empty
fMRINames=""
# the original MR FIX parameter for what to concatenate. List all single runs from one concatenated group separated with @.
mrfixNames=""
# the original MR FIX concatenated name (only one group)
mrfixConcatName="fMRI_CONCAT_ALL"
# @-separated list of runs to use for this new MSMAll run of MR FIX
mrfixNamesToUse="rfMRI_REST1_AP@rfMRI_REST1_PA@rfMRI_REST2_AP@rfMRI_REST2_PA"
# FIX output concat name for this new MSMAll run of MR FIX
OutfMRIName="rfMRI_REST"

#Use HighPass = 2000 for single-run FIX data, HighPass = 0 for MR FIX data
HighPass="0"
#Name to reflect high pass setting
fMRIProcSTRING="_Atlas_hp0_clean"
MSMAllTemplates="${HCPPIPEDIR}/global/templates/MSMAll"
MyelinTargetFile="${MSMAllTemplates}/Q1-Q6_RelatedParcellation210.MyelinMap_BC_MSMAll_2_d41_WRN_DeDrift.32k_fs_LR.dscalar.nii"
RegName="MSMAll_InitialReg"
HighResMesh="164"
LowResMesh="32"
InRegName="MSMSulc"
MatlabMode="1" #Mode=0 compiled Matlab, Mode=1 interpreted Matlab, Mode=2 Octave

fMRINames=`echo ${fMRINames} | sed 's/ /@/g'`

for (( i=0; i<${#Subjlist[@]}; i++ )); do
    Subject="${Subjlist[i]}"
    echo "    ${Subject}"
    TemplateLong="${Templates[i]}"    
    Timepoints=$(identify_timepoints "$Subject")
    
    if [[ "${command_line_specified_run_local}" == "TRUE" || "$QUEUE" == "" ]] ; then
        echo "About to locally run ${HCPPIPEDIR}/MSMAll/MSMAllPipeline.sh"
        queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
    else
        echo "About to use fsl_sub to queue ${HCPPIPEDIR}/MSMAll/MSMAllPipeline.sh"
        queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE")
    fi

    "${queuing_command[@]}" "$HCPPIPEDIR"/MSMAll/MSMAllPipeline.sh \
        --path="$StudyFolder" \
        --session="$Subject" \
        --fmri-names-list="$fMRINames" \
        --multirun-fix-names="$mrfixNames" \
        --multirun-fix-concat-name="$mrfixConcatName" \
        --multirun-fix-names-to-use="$mrfixNamesToUse" \
        --output-fmri-name="$OutfMRIName" \
        --high-pass="$HighPass" \
        --fmri-proc-string="$fMRIProcSTRING" \
        --msm-all-templates="$MSMAllTemplates" \
        --myelin-target-file="$MyelinTargetFile" \
        --output-registration-name="$RegName" \
        --high-res-mesh="$HighResMesh" \
        --low-res-mesh="$LowResMesh" \
        --input-registration-name="$InRegName" \
        --matlab-run-mode="$MatlabMode" \
        --is-longitudinal="TRUE" \
        --subject-long="$Subject" \
        --sessions-long="$Timepoints" \
        --template-long="$TemplateLong"

done
