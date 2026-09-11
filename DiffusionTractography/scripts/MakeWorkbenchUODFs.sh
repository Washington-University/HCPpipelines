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
Folder=`getopt1 "--folder" $@`                   # "$3" #folder so it is not just t1w
DiffusionResolution=`getopt1 "--diffresol" $@`   # "$4" #Diffusion Resolution in mm
BedpostXFolders=`getopt1 "--bpxfoldername" $@` #Delimited by @
Whim=`getopt1 "--whim" $@` #"true" or "false". Though it is just judging if it is true or not.
WhimMask=`getopt1 "--whimmask" $@` #Path to whim mask

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"    # Debugging functions; also sources log.shlib
source "${HCPPIPEDIR}/global/scripts/newopts.shlib" "$@"  
Caret7_Command=${CARET7DIR}/wb_command

#NamingConventions and Paths
trajectory="Whole_Brain_Trajectory"
T1wFolder="${StudyFolder}/${Subject}/${Folder}"
MNINonLinearFolder="${StudyFolder}/${Subject}/MNINonLinear"
NativeFolder="${StudyFolder}/${Subject}/T1w/Native"


BedpostXFolders=`defaultopt $BedpostXFolders Diffusion.bedpostX`
BedpostXFolders=`echo ${BedpostXFolders} | sed 's/@/ /g'`

##We might want to resample tbe psi_zero and small_values.
log_Check_Env_Var HCPPIPEDIR

for BedpostXFolderName in ${BedpostXFolders} ; do
  if [[ "$Whim" == "true" ]]; then
    BedpostXFolder="${T1wFolder}/${BedpostXFolderName}"
    ${Caret7_Command} -convert-fiber-orientations \
    $WhimMask \
    ${BedpostXFolder}/${BedpostXFolderName}_${trajectory}_${DiffusionResolution}.fiberTEMP.nii \
  -fiber \
    ${BedpostXFolder}/f_1_std.nii.gz \
    ${HCPPIPEDIR}/global/templates/small_values.nii.gz \
    ${BedpostXFolder}/theta_1_std.nii.gz \
    ${BedpostXFolder}/phi_1_std.nii.gz \
    ${HCPPIPEDIR}/global/templates/psi_zero.nii.gz \
    ${HCPPIPEDIR}/global/templates/small_values.nii.gz \
    ${HCPPIPEDIR}/global/templates/small_values.nii.gz \
  -fiber \
    ${BedpostXFolder}/f_2_std.nii.gz \
    ${HCPPIPEDIR}/global/templates/small_values.nii.gz \
    ${BedpostXFolder}/theta_2_std.nii.gz \
    ${BedpostXFolder}/phi_2_std.nii.gz \
    ${HCPPIPEDIR}/global/templates/psi_zero.nii.gz \
    ${HCPPIPEDIR}/global/templates/small_values.nii.gz \
    ${HCPPIPEDIR}/global/templates/small_values.nii.gz \
  -fiber \
    ${BedpostXFolder}/f_3_std.nii.gz \
    ${HCPPIPEDIR}/global/templates/small_values.nii.gz \
    ${BedpostXFolder}/theta_3_std.nii.gz \
    ${BedpostXFolder}/phi_3_std.nii.gz \
    ${HCPPIPEDIR}/global/templates/psi_zero.nii.gz \
    ${HCPPIPEDIR}/global/templates/small_values.nii.gz \
    ${HCPPIPEDIR}/global/templates/small_values.nii.gz
  else
    BedpostXFolder="${StudyFolder}/${Subject}/T1w/${BedpostXFolderName}"
    echo "Creating Fiber File for Connectome Workbench"
    ${Caret7_Command} -estimate-fiber-binghams ${BedpostXFolder}/merged_f1samples.nii.gz ${BedpostXFolder}/merged_th1samples.nii.gz ${BedpostXFolder}/merged_ph1samples.nii.gz ${BedpostXFolder}/merged_f2samples.nii.gz ${BedpostXFolder}/merged_th2samples.nii.gz ${BedpostXFolder}/merged_ph2samples.nii.gz ${BedpostXFolder}/merged_f3samples.nii.gz ${BedpostXFolder}/merged_th3samples.nii.gz ${BedpostXFolder}/merged_ph3samples.nii.gz ${T1wFolder}/${trajectory}_${DiffusionResolution}.nii.gz ${BedpostXFolder}/${BedpostXFolderName}_${trajectory}_${DiffusionResolution}.fiberTEMP.nii
  fi

done

echo -e "\n END: MakeWorkbenchUODFs"

