#!/bin/bash
set -e
echo -e "\n START: PostProcMatrix3"

Caret7_command=${CARET7DIR}/wb_command

if [ "$2" == "" ];then
    echo ""
    echo "usage: $0 <StudyFolder> <Subject>"
    echo "Final Merge of the three .dconn blocks"
    exit 1
fi

StudyFolder=$1          # "$1" #Path to Generic Study folder
Subject=$2              # "$2" #SubjectID

ResultsFolder="$StudyFolder"/"$Subject"/MNINonLinear/Results/Tractography

${Caret7_command} -cifti-merge-dense COLUMN ${ResultsFolder}/Conn3.dconn.nii -cifti ${ResultsFolder}/merged_matrix3_1.dconn.nii -cifti ${ResultsFolder}/merged_matrix3_2.dconn.nii -cifti ${ResultsFolder}/merged_matrix3_3.dconn.nii

if [ -s ${ResultsFolder}/Conn3.dconn.nii ]; then
    rm -f ${ResultsFolder}/merged_matrix3_?.dconn.nii
fi


# A Mat3 Connectome reduces from 33GB to 4GB in 40 minutes (with default), to 5.5GB (with --fast) in 9 minutes!
gzip ${ResultsFolder}/Conn3.dconn.nii --fast

echo -e "\n END: PostProcMatrix3"
