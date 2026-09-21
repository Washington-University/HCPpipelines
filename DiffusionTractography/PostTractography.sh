#!/bin/bash
set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

# Load function libraries
source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"    # Debugging functions; also sources log.shlib
source "${HCPPIPEDIR}/global/scripts/newopts.shlib" "$@"  # Command line option functions


# Perform the steps of the HCP Diffusion Preprocessing Pipeline
opts_SetScriptDescription "Prepare the data to run Tractography"

opts_AddMandatory '--path' 'StudyFolder' 'Path' "path to session's data folder"
opts_AddMandatory '--subject' 'Subject' 'subject ID' ""
opts_AddMandatory '--results-folder' 'folder' 'The specific folder in which the seed of tractography is located. This should follow HCP standards' ""
opts_AddMandatory '--diffresmesh' 'DiffResMesh' 'number' 'diffusion res mesh number'
opts_AddMandatory '--bpxdir' 'BedpostXFolder' 'folder that stores bedpostX results or whim results' 'BEDPOSTX Folder or whim folder'
opts_AddMandatory '--regname' 'RegName' 'Name of Registration' 'NONE for MSMSulc, else RegName such as MSMAll'
opts_AddMandatory '--matrix' 'Matrix' '1 or 3' 'Matrix 1 or Matrix 3 seeding strategy'
opts_AddMandatory '--group' 'whim' 'true or false' "Indicate if you tractography for averaging or just an individual. true if this is for averaging"
opts_AddOptional '--cleanup' 'cleanup' 'bool' "indicate if you want to cleanup the intermediate files. Default is false" "false"


opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

opts_ShowValues

"$HCPPIPEDIR"/show_version

# ------------------------------------------------------------------------------
#  Verify required environment variables are set and log value
# ------------------------------------------------------------------------------

log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FSLDIR
log_Check_Env_Var CARET7DIR

log_Msg "Platform Information Follows: "
uname -a

TrajectorySpaceFolder="${StudyFolder}/${Subject}/${Folder}"
T1wDiffusionFolder="${StudyFolder}/${Subject}/T1w/Diffusion"
DiffusionResolution=`${FSLDIR}/bin/fslval ${T1wDiffusionFolder}/data pixdim1`
DiffusionResolution=`printf "%0.2f" ${DiffusionResolution}`
ResultsFolder="${TrajectorySpaceFolder}/Results"
DiffMeshFolder="${TrajectorySpaceFolder}/fsaverage_LR${DiffResMesh}k"
TractographyResultsFolder="${ResultsFolder}/Matrix${Matrix}WholeBrainTractography"
BedpostXFolderPath="${TrajectorySpaceFolder}/${BedpostXFolder}" 
BedpostXFolderPathT1w="${StudyFolder}/${Subject}/T1w/${BedpostXFolder}" 

log_Msg "Converting Probtrackx Matrices"

if [ ${Matrix} -eq 1 ] ; then
  ${CARET7DIR}/wb_command -probtrackx-dot-convert ${TractographyResultsFolder}/fdt_matrix1.dot WBSPARSE ${TractographyResultsFolder}/fdt_matrix1.dconn.wbsparse -row-cifti ${DiffMeshFolder}/Grey.dscalar.nii COLUMN -col-cifti ${DiffMeshFolder}/Grey.dscalar.nii COLUMN -transpose
  ${CARET7DIR}/wb_command -probtrackx-dot-convert ${TractographyResultsFolder}/fdt_matrix1_lengths.dot WBSPARSE ${TractographyResultsFolder}/fdt_matrix1_lengths.dconn.wbsparse -row-cifti ${DiffMeshFolder}/Grey.dscalar.nii COLUMN -col-cifti ${DiffMeshFolder}/Grey.dscalar.nii COLUMN -transpose
elif [ ${Matrix} -eq 3 ] ; then
  ${CARET7DIR}/wb_command -probtrackx-dot-convert ${TractographyResultsFolder}/fdt_matrix3.dot WBSPARSE ${TractographyResultsFolder}/fdt_matrix3.dconn.wbsparse -row-cifti ${DiffMeshFolder}/Grey.dscalar.nii COLUMN -col-cifti ${DiffMeshFolder}/Grey.dscalar.nii COLUMN -transpose -make-symmetric
  ${CARET7DIR}/wb_command -probtrackx-dot-convert ${TractographyResultsFolder}/fdt_matrix3_lengths.dot WBSPARSE ${TractographyResultsFolder}/fdt_matrix3_lengths.dconn.wbsparse -row-cifti ${DiffMeshFolder}/Grey.dscalar.nii COLUMN -col-cifti ${DiffMeshFolder}/Grey.dscalar.nii COLUMN -transpose -make-symmetric
else
  log_Err_Abort "Matrix Type Not Supported"
fi
if [ "${whim}" == "true" ]; then
  ${CARET7DIR}/wb_command -convert-matrix4-to-workbench-sparse ${TractographyResultsFolder}/fdt_matrix4_1.mtx ${TractographyResultsFolder}/fdt_matrix4_2.mtx ${TractographyResultsFolder}/fdt_matrix4_3.mtx ${BedpostXFolderPath}/${BedpostXFolder}_Whole_Brain_Trajectory_1.25.fiberTEMP.nii ${TractographyResultsFolder}/tract_space_coords_for_fdt_matrix4 ${TractographyResultsFolder}/fdt_matrix4.trajTEMP.wbsparse -cifti-seeds ${DiffMeshFolder}/Grey.dscalar.nii COLUMN
else
  ${CARET7DIR}/wb_command -convert-matrix4-to-workbench-sparse ${TractographyResultsFolder}/fdt_matrix4_1.mtx ${TractographyResultsFolder}/fdt_matrix4_2.mtx ${TractographyResultsFolder}/fdt_matrix4_3.mtx ${BedpostXFolderPathT1w}/Diffusion.bedpostX_Whole_Brain_Trajectory_1.25.fiberTEMP.nii ${TractographyResultsFolder}/tract_space_coords_for_fdt_matrix4 ${TractographyResultsFolder}/fdt_matrix4.trajTEMP.wbsparse -cifti-seeds ${DiffMeshFolder}/Grey.dscalar.nii COLUMN
fi

if [ "${cleanup}" == "true" ]; then
  rm -f ${TractographyResultsFolder}/fdt_matrix4_1.mtx
  rm -f ${TractographyResultsFolder}/fdt_matrix4_2.mtx
  rm -f ${TractographyResultsFolder}/fdt_matrix4_3.mtx
  if [ ${Matrix} -eq 1 ] ; then
    rm -f ${TractographyResultsFolder}/fdt_matrix1.dot
    rm -f ${TractographyResultsFolder}/fdt_matrix1_lengths.dot
  elif [ ${Matrix} -eq 3 ] ; then
    rm -f ${TractographyResultsFolder}/fdt_matrix3.dot
    rm -f ${TractographyResultsFolder}/fdt_matrix3_lengths.dot
  fi
fi


log_Msg "Completed"

