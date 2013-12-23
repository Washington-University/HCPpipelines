#!/bin/bash
set -e

########################################## SUPPORT FUNCTIONS #####################################################

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

show_usage() {
    echo "Usage: PreTractography.sh"
    echo " --path=<StudyFolder>"
    echo " --subject=<Subject>"
    echo " --lowresmesh=<LowResMesh>"
    echo " "
    echo "T1w and MNINonLinear folders are expected within <StudyFolder>/<Subject>"
    echo ""
    exit 1
}

# --------------------------------------------------------------------------------
#   Establish tool name for logging
# --------------------------------------------------------------------------------
log_SetToolName "PreTractography.sh"


################################################## OPTION PARSING ###################################################

opts_ShowVersionIfRequested $@

if [ "$2" == "" ];then
    show_usage 
fi

if opts_CheckForHelpRequest $@; then
    show_usage
fi

log_Msg "Parsing Command Line Options"

# Input Variables
StudyFolder=`getopt1 "--path" $@`                # "$1" #Path to Generic Study folder
Subject=`getopt1 "--subject" $@`                 # "$2" #SubjectID
LowResMesh=`getopt1 "--lowresmesh" $@`  # "$3" #DownSampled number of CIFTI vertices

WholeBrainTrajectoryLabels=${HCPPIPEDIR_Config}/WholeBrainFreeSurferTrajectoryLabelTableLut.txt
LeftCerebralTrajectoryLabels=${HCPPIPEDIR_Config}/LeftCerebralFreeSurferTrajectoryLabelTableLut.txt 
RightCerebralTrajectoryLabels=${HCPPIPEDIR_Config}/RightCerebralFreeSurferTrajectoryLabelTableLut.txt
FreeSurferLabels=${HCPPIPEDIR_Config}/FreeSurferAllLut.txt


T1wDiffusionFolder="${StudyFolder}/${Subject}/T1w/Diffusion"
DiffusionResolution=`${FSLDIR}/bin/fslval ${T1wDiffusionFolder}/data pixdim1`
DiffusionResolution=`printf "%0.2f" ${DiffusionResolution}`
StandardResolution="2"

log_Msg "MakeTrajectorySpace"
${HCPPIPEDIR_dMRITract}/MakeTrajectorySpace.sh \
    --path="$StudyFolder" --subject="$Subject" \
    --wholebrainlabels="$WholeBrainTrajectoryLabels" \
    --leftcerebrallabels="$LeftCerebralTrajectoryLabels" \
    --rightcerebrallabels="$RightCerebralTrajectoryLabels" \
    --diffresol="${DiffusionResolution}" \
    --freesurferlabels="${FreeSurferLabels}"

log_Msg "MakeTrajectorySpace_MNI"
${HCPPIPEDIR_dMRITract}/MakeTrajectorySpace_MNI.sh \
    --path="$StudyFolder" --subject="$Subject" \
    --wholebrainlabels="$WholeBrainTrajectoryLabels" \
    --leftcerebrallabels="$LeftCerebralTrajectoryLabels" \
    --rightcerebrallabels="$RightCerebralTrajectoryLabels" \
    --standresol="${StandardResolution}" \
    --freesurferlabels="${FreeSurferLabels}"

log_Msg "MakeWorkbenchUODFs"
${HCPPIPEDIR_dMRITract}/MakeWorkbenchUODFs.sh --path="${StudyFolder}" --subject="${Subject}" --lowresmesh="${LowResMesh}" --diffresol="${DiffusionResolution}"

# ${HCPPIPEDIR_dMRITract}/PrepareSeeds.sh ${StudyFolder} ${Subject} #This currently creates and calls a Matlab script. Need to Redo in bash or C++

log_Msg "Completed"

