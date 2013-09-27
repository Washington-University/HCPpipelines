#!/bin/bash
set -e


if [ "$2" == "" ];then
    echo ""
    echo "usage: $0 <StudyFolder> <Subject> <LowResMesh>"
         "       T1w and MNINonLinear folders are expected within <StudyFolder>/<Subject>"
    echo ""
    exit 1
fi


########################################## SUPPORT FUNCTIONS #####################################################
# function for parsing options
getopt1() {
    sopt="$1"
    shift 1
    for fn in $@ ; do
	if [ `echo $fn | grep -- "^${sopt}=" | wc -w` -gt 0 ] ; then
	    echo $fn | sed "s/^${sopt}=//"
	    return 0
	fi
    done
}

defaultopt() {
    echo $1
}


################################################## OPTION PARSING ###################################################
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

${HCPPIPEDIR_dMRITract}/MakeTrajectorySpace.sh \
    --path="$StudyFolder" --subject="$Subject" \
    --wholebrainlabels="$WholeBrainTrajectoryLabels" \
    --leftcerebrallabels="$LeftCerebralTrajectoryLabels" \
    --rightcerebrallabels="$RightCerebralTrajectoryLabels" \
    --diffresol="${DiffusionResolution}" \
    --freesurferlabels="${FreeSurferLabels}"

${HCPPIPEDIR_dMRITract}/MakeTrajectorySpace_MNI.sh \
    --path="$StudyFolder" --subject="$Subject" \
    --wholebrainlabels="$WholeBrainTrajectoryLabels" \
    --leftcerebrallabels="$LeftCerebralTrajectoryLabels" \
    --rightcerebrallabels="$RightCerebralTrajectoryLabels" \
    --standresol="${StandardResolution}" \
    --freesurferlabels="${FreeSurferLabels}"

${HCPPIPEDIR_dMRITract}/MakeWorkbenchUODFs.sh --path="${StudyFolder}" --subject="${Subject}" --lowresmesh="${LowResMesh}" --diffresol="${DiffusionResolution}"

# ${HCPPIPEDIR_dMRITract}/PrepareSeeds.sh ${StudyFolder} ${Subject} #This currently creates and calls a Matlab script. Need to Redo in bash or C++
