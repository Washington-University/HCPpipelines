#!/bin/bash
set -e


if [ "$2" == "" ];then
    echo ""
    echo "usage: $0 <StudyFolder> <Subject>"
         "       T1w and MNINonLinear folders are expected within <StudyFolder>/<Subject>"
    echo ""
    exit 1
fi

StudyFolder=$1
Subject=$2  

WholeBrainTrajectoryLabels=${HCPPIPEDIR_Config}/WholeBrainFreeSurferTrajectoryLabelTableLut.txt
LeftCerebralTrajectoryLabels=${HCPPIPEDIR_Config}/LeftCerebralFreeSurferTrajectoryLabelTableLut.txt 
RightCerebralTrajectoryLabels=${HCPPIPEDIR_Config}/RightCerebralFreeSurferTrajectoryLabelTableLut.txt
FreeSurferLabels=${HCPPIPEDIR_Config}/FreeSurferAllLut.txt


T1wDiffusionFolder="${StudyFolder}/${Subject}/T1w/Diffusion"
DiffusionResolution=`${FSLDIR}/bin/fslval ${T1wDiffusionFolder}/data pixdim1`
DiffusionResolution=`printf "%0.3f" ${DiffusionResolution}`
LowResMesh=32

${HCPPIPEDIR_dMRITract}/MakeTrajectorySpace.sh \
    --path="$StudyFolder" --subject="$Subject" \
    --wholebrainlabels="$WholeBrainTrajectoryLabels" \
    --leftcerebrallabels="$LeftCerebralTrajectoryLabels" \
    --rightcerebrallabels="$RightCerebralTrajectoryLabels" \
    --diffresol="${DiffusionResolution}" \
    --freesurferlabels="${FreeSurferLabels}"

${HCPPIPEDIR_dMRITract}/MakeWorkbenchUODFs.sh --path="${StudyFolder}" --subject="${Subject}" --lowresmesh="${LowResMesh}" --diffresol="${DiffusionResolution}"