#!/bin/bash
set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"    # Debugging functions; also sources log.shlib
source "${HCPPIPEDIR}/global/scripts/newopts.shlib" "$@"  
source "${HCPPIPEDIR}/global/scripts/tempfiles.shlib" "$@"  

opts_SetScriptDescription "Make workbench UODFs for Tractography"
opts_AddMandatory '--path' 'StudyFolder' 'folder' 'path to Generic Study folder'
opts_AddMandatory '--subject' 'Subject' 'subject' 'subject ID'
opts_AddMandatory '--volume-space' 'volspace' 'string' "which volume space to generate the tractography outputs in, must be T1w, MNINonLinear, or MMORFNonLinear"
opts_AddMandatory '--diffresol' 'DiffusionResolution' 'number' 'diffusion resolution in mm'

opts_AddOptional '--bpxfoldername' 'BedpostXFolders' 'folder@folder' 'names of folders containing fiber estimations, delimited by @'

opts_AddOptional '--whimmask' 'WhimMask' 'file' 'path to WHIM mask'

opts_ParseArguments "$@"

opts_ShowValues

Caret7_Command=${CARET7DIR}/wb_command

#NamingConventions and Paths
trajectory="Whole_Brain_Trajectory"
TrajectorySpaceFolder="${StudyFolder}/${Subject}/${volspace}"
MNINonLinearFolder="${StudyFolder}/${Subject}/MNINonLinear"
NativeFolder="${StudyFolder}/${Subject}/T1w/Native"


BedpostXFolders=`defaultopt $BedpostXFolders Diffusion.bedpostX`
BedpostXFolders=`echo ${BedpostXFolders} | sed 's/@/ /g'`

log_Check_Env_Var HCPPIPEDIR
echo -e "\n START: MakeWorkbenchUODFs"


for BedpostXFolderName in ${BedpostXFolders} ; do
  if [[ -n "$WhimMask" ]]; then
    BedpostXFolder="${TrajectorySpaceFolder}/${BedpostXFolderName}"
    tempfiles_create diffusion_UODFs_zero_XXXXXX.nii.gz zeroFile
    tempfiles_create diffusion_UODFs_smallval_XXXXXX.nii.gz smallValFile
    wb_command -volume-math '0' "$zeroFile" -var x "$BedpostXFolder"/f_1_std.nii.gz
    wb_command -volume-math '0.001' "$smallValFile" -var x "$BedpostXFolder"/f_1_std.nii.gz
    ${Caret7_Command} -convert-fiber-orientations \
      $WhimMask \
      ${BedpostXFolder}/${BedpostXFolderName}_${trajectory}_${DiffusionResolution}.fiberTEMP.nii \
      -fiber \
        ${BedpostXFolder}/f_1_std.nii.gz \
        "$smallValFile" \
        ${BedpostXFolder}/theta_1_std.nii.gz \
        ${BedpostXFolder}/phi_1_std.nii.gz \
        "$zeroFile" \
        "$smallValFile" \
        "$smallValFile" \
      -fiber \
        ${BedpostXFolder}/f_2_std.nii.gz \
        "$smallValFile" \
        ${BedpostXFolder}/theta_2_std.nii.gz \
        ${BedpostXFolder}/phi_2_std.nii.gz \
        "$zeroFile" \
        "$smallValFile" \
        "$smallValFile" \
      -fiber \
        ${BedpostXFolder}/f_3_std.nii.gz \
        "$smallValFile" \
        ${BedpostXFolder}/theta_3_std.nii.gz \
        ${BedpostXFolder}/phi_3_std.nii.gz \
        "$zeroFile" \
        "$smallValFile" \
        "$smallValFile"
  else
    BedpostXFolder="${StudyFolder}/${Subject}/T1w/${BedpostXFolderName}"
    echo "Creating Fiber File for Connectome Workbench"
    ${Caret7_Command} -estimate-fiber-binghams ${BedpostXFolder}/merged_f1samples.nii.gz ${BedpostXFolder}/merged_th1samples.nii.gz ${BedpostXFolder}/merged_ph1samples.nii.gz ${BedpostXFolder}/merged_f2samples.nii.gz ${BedpostXFolder}/merged_th2samples.nii.gz ${BedpostXFolder}/merged_ph2samples.nii.gz ${BedpostXFolder}/merged_f3samples.nii.gz ${BedpostXFolder}/merged_th3samples.nii.gz ${BedpostXFolder}/merged_ph3samples.nii.gz ${T1wFolder}/${trajectory}_${DiffusionResolution}.nii.gz ${BedpostXFolder}/${BedpostXFolderName}_${trajectory}_${DiffusionResolution}.fiberTEMP.nii
  fi

done

echo -e "\n END: MakeWorkbenchUODFs"

