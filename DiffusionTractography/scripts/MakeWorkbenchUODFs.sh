#!/bin/bash
set -e
echo -e "\n START: MakeWorkbenchUODFs"

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
DiffusionResolution=`getopt1 "--diffresol" $@`   # "$4" #Diffusion Resolution in mm

Caret7_Command="${CARET7DIR}/wb_command"

#NamingConventions and Paths
trajectory="Whole_Brain_Trajectory"
T1wFolder="${StudyFolder}/${Subject}/T1w"
BedpostXFolder="${StudyFolder}/${Subject}/T1w/Diffusion.bedpostX"
MNINonLinearFolder="${StudyFolder}/${Subject}/MNINonLinear"
NativeFolder="${StudyFolder}/${Subject}/T1w/Native"
DownSampleFolder="${StudyFolder}/${Subject}/T1w/fsaverage_LR${LowResMesh}k"

echo "Creating Fibre File for Connectome Workbench"
${Caret7_Command} -estimate-fiber-binghams ${BedpostXFolder}/merged_f1samples.nii.gz ${BedpostXFolder}/merged_th1samples.nii.gz ${BedpostXFolder}/merged_ph1samples.nii.gz ${BedpostXFolder}/merged_f2samples.nii.gz ${BedpostXFolder}/merged_th2samples.nii.gz ${BedpostXFolder}/merged_ph2samples.nii.gz ${BedpostXFolder}/merged_f3samples.nii.gz ${BedpostXFolder}/merged_th3samples.nii.gz ${BedpostXFolder}/merged_ph3samples.nii.gz ${T1wFolder}/${trajectory}_${DiffusionResolution}.nii.gz ${BedpostXFolder}/${trajectory}_${DiffusionResolution}.fiberTEMP.nii

${Caret7_Command} -add-to-spec-file ${NativeFolder}/${Subject}.native.wb.spec INVALID ${BedpostXFolder}/${trajectory}_${DiffusionResolution}.fiberTEMP.nii
${Caret7_Command} -add-to-spec-file ${DownSampleFolder}/${Subject}.${LowResMesh}k_fs_LR.wb.spec INVALID ${BedpostXFolder}/${trajectory}_${DiffusionResolution}.fiberTEMP.nii

echo -e "\n END: MakeWorkbenchUODFs"
