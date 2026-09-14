#!/bin/bash
set -e
echo -e "\n START: MakeWorkbenchUODFs"


pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"    # Debugging functions; also sources log.shlib
source "${HCPPIPEDIR}/global/scripts/newopts.shlib" "$@"  

opts_SetScriptDescription "Make workbench UODFs for Tractography"
opts_AddMandatory '--path' 'StudyFolder' 'folder' 'path to Generic Study folder'
opts_AddMandatory '--subject' 'Subject' 'subject' 'subject ID'
opts_AddMandatory '--folder' 'Folder' 'folder' 'folder so it is not just T1w'
opts_AddMandatory '--diffresol' 'DiffusionResolution' 'number' 'diffusion resolution in mm'

opts_AddOptional '--bpxfoldername' 'BedpostXFolders' 'folder@folder' 'names of folders containing fiber estimations, delimited by @'

opts_AddOptional '--whimmask' 'WhimMask' 'file' 'path to WHIM mask'

opts_ParseArguments "$@"

opts_ShowValues

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
  if [[ -n "$WhimMask" ]]; then
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

