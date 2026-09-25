#!/bin/bash
set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"

# Make a standard set of seeds for Tractography
opts_SetScriptDescription "Make a standard set of seeds for Tractography"

opts_AddMandatory '--path' 'StudyFolder' 'Path' "path to session's data folder"
opts_AddMandatory '--subject' 'Subject' 'subject ID' ""
opts_AddMandatory '--results-folder' 'Folder' 'Folder' ""
opts_AddMandatory '--diffresmesh' 'DiffResMesh' 'number' 'Diffusion res mesh number'
opts_AddMandatory '--diffresol' 'DiffusionResolution' 'number' 'diffusion resolution'
opts_AddMandatory '--regname' 'RegName' 'Name of Registration' 'RegName such as MSMAll'
opts_AddMandatory '--whimmask' 'WhimMask' 'file' 'path to WHIM mask'
opts_AddOptional '--groupname' 'GroupName' 'Group Folder_Name' ""


opts_ParseArguments "$@"

opts_ShowValues

SurfaceAtlasDIR="$HCPPIPEDIR/global/templates/standard_mesh_atlases"

TrajectorySpaceFolder="${StudyFolder}/${Subject}/${Folder}"
AtlasFolder="${StudyFolder}/${Subject}/MNINonLinear"
NativeAtlasFolder="${AtlasFolder}/Native"
NativeTrajectorySpaceFolder="${TrajectorySpaceFolder}/Native"
DiffusionFolder="${TrajectorySpaceFolder}/Diffusion"
#DiffMeshFolder was previously T1w.
DiffMeshFolder="${AtlasFolder}/fsaverage_LR${DiffResMesh}k"
ROIsTrajectorySpaceFolder="${TrajectorySpaceFolder}/ROIs"
FolderMeshFolder="${TrajectorySpaceFolder}/fsaverage_LR${DiffResMesh}k"


InflateExtraScale=1
DiffResInflationScale=$(echo "scale=4; $InflateExtraScale * 0.75 * $DiffResMesh / 32" | bc -l)

if [ ! -e ${FolderMeshFolder} ] ; then
  mkdir ${FolderMeshFolder}
fi

for Hemisphere in L R ; do
  if [ ! -f "${FolderMeshFolder}/${Subject}.${Hemisphere}.very_inflated_${RegName}.${DiffResMesh}k_fs_LR.surf.gii" ]; then
    cp "$SurfaceAtlasDIR"/${Hemisphere}.sphere.${DiffResMesh}k_fs_LR.surf.gii ${DiffMeshFolder}/${Subject}.${Hemisphere}.sphere.${DiffResMesh}k_fs_LR.surf.gii
    for Surface in white pial midthickness ; do
      ${CARET7DIR}/wb_command -surface-resample ${NativeTrajectorySpaceFolder}/${Subject}.${Hemisphere}.${Surface}.native.surf.gii ${NativeAtlasFolder}/${Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii ${DiffMeshFolder}/${Subject}.${Hemisphere}.sphere.${DiffResMesh}k_fs_LR.surf.gii BARYCENTRIC ${FolderMeshFolder}/${Subject}.${Hemisphere}.${Surface}_${RegName}.${DiffResMesh}k_fs_LR.surf.gii
    done
    ${CARET7DIR}/wb_command -surface-generate-inflated ${FolderMeshFolder}/${Subject}.${Hemisphere}.midthickness_${RegName}.${DiffResMesh}k_fs_LR.surf.gii ${FolderMeshFolder}/${Subject}.${Hemisphere}.inflated_${RegName}.${DiffResMesh}k_fs_LR.surf.gii ${FolderMeshFolder}/${Subject}.${Hemisphere}.very_inflated_${RegName}.${DiffResMesh}k_fs_LR.surf.gii -iterations-scale ${DiffResInflationScale}
  fi
  if [[ -n "$WhimMask" ]]; then
    $FSLDIR/bin/surf2surf -i ${FolderMeshFolder}/${Subject}.${Hemisphere}.white_${RegName}.${DiffResMesh}k_fs_LR.surf.gii -o ${ROIsTrajectorySpaceFolder}/${Subject}.${Hemisphere}.white_${RegName}.${DiffResMesh}k_fs_LR.gii --values=${AtlasFolder}/fsaverage_LR${DiffResMesh}k/${Subject}.${Hemisphere}.atlasroi.${DiffResMesh}k_fs_LR.shape.gii
    $FSLDIR/bin/surf2surf -i ${FolderMeshFolder}/${Subject}.${Hemisphere}.pial_${RegName}.${DiffResMesh}k_fs_LR.surf.gii -o ${ROIsTrajectorySpaceFolder}/${Subject}.${Hemisphere}.pial_${RegName}.${DiffResMesh}k_fs_LR.gii --values=${AtlasFolder}/fsaverage_LR${DiffResMesh}k/${Subject}.${Hemisphere}.atlasroi.${DiffResMesh}k_fs_LR.shape.gii
  else
    ${CARET7DIR}/wb_command -metric-resample ${NativeAtlasFolder}/${Subject}.${Hemisphere}.roi.native.shape.gii ${NativeAtlasFolder}/${Subject}.${Hemisphere}.sphere.MSMAll.native.surf.gii ${DiffMeshFolder}/${Subject}.${Hemisphere}.sphere.${DiffResMesh}k_fs_LR.surf.gii ADAP_BARY_AREA ${FolderMeshFolder}/${Subject}.${Hemisphere}.roi_${RegName}.${DiffResMesh}k_fs_LR.shape.gii -area-surfs ${NativeAtlasFolder}/${Subject}.${Hemisphere}.midthickness.native.surf.gii ${FolderMeshFolder}/${Subject}.${Hemisphere}.midthickness_${RegName}.${DiffResMesh}k_fs_LR.surf.gii -largest
    ${CARET7DIR}/wb_command -metric-math var-var+1 ${FolderMeshFolder}/${Subject}.${Hemisphere}.all_${RegName}.${DiffResMesh}k_fs_LR.shape.gii -var var ${AtlasFolder}/fsaverage_LR${DiffResMesh}k/${Subject}.${Hemisphere}.atlasroi.${DiffResMesh}k_fs_LR.shape.gii  #Is this really needed?
    $FSLDIR/bin/surf2surf -i ${FolderMeshFolder}/${Subject}.${Hemisphere}.white_${RegName}.${DiffResMesh}k_fs_LR.surf.gii -o ${ROIsTrajectorySpaceFolder}/${Subject}.${Hemisphere}.white_${RegName}.${DiffResMesh}k_fs_LR.gii --values=${FolderMeshFolder}/${Subject}.${Hemisphere}.roi_${RegName}.${DiffResMesh}k_fs_LR.shape.gii
    $FSLDIR/bin/surf2surf -i ${FolderMeshFolder}/${Subject}.${Hemisphere}.pial_${RegName}.${DiffResMesh}k_fs_LR.surf.gii -o ${ROIsTrajectorySpaceFolder}/${Subject}.${Hemisphere}.pial_${RegName}.${DiffResMesh}k_fs_LR.gii --values=${FolderMeshFolder}/${Subject}.${Hemisphere}.roi_${RegName}.${DiffResMesh}k_fs_LR.shape.gii
  fi
done

#TODO: Currently unique per individual
##Need group name here
if [[ -n "$WhimMask" ]]; then
  fslmaths ${StudyFolder}/${GroupName}/${Folder}/Whole_Brain_SubCortical_GreyMatter_${DiffusionResolution}.nii.gz -bin ${ROIsTrajectorySpaceFolder}/Atlas_Whole_Brain_SubCortical_GreyMatter_${DiffusionResolution}.nii.gz
  echo "OTHER" > ${ROIsTrajectorySpaceFolder}/tmp.txt
  echo "1 255 255 255 255" >> ${ROIsTrajectorySpaceFolder}/tmp.txt
  ${CARET7DIR}/wb_command -volume-label-import ${ROIsTrajectorySpaceFolder}/Atlas_Whole_Brain_SubCortical_GreyMatter_${DiffusionResolution}.nii.gz ${ROIsTrajectorySpaceFolder}/tmp.txt ${ROIsTrajectorySpaceFolder}/Atlas_Whole_Brain_SubCortical_GreyMatter_${DiffusionResolution}.nii.gz
else
  fslmaths ${TrajectorySpaceFolder}/Whole_Brain_SubCortical_GreyMatter_${DiffusionResolution}.nii.gz -bin ${ROIsTrajectorySpaceFolder}/Whole_Brain_SubCortical_GreyMatter_${DiffusionResolution}.nii.gz
  echo "OTHER" > ${ROIsTrajectorySpaceFolder}/tmp.txt
  echo "1 255 255 255 255" >> ${ROIsTrajectorySpaceFolder}/tmp.txt
  ${CARET7DIR}/wb_command -volume-label-import ${ROIsTrajectorySpaceFolder}/Whole_Brain_SubCortical_GreyMatter_${DiffusionResolution}.nii.gz ${ROIsTrajectorySpaceFolder}/tmp.txt ${ROIsTrajectorySpaceFolder}/Whole_Brain_SubCortical_GreyMatter_${DiffusionResolution}.nii.gz
fi
rm ${ROIsTrajectorySpaceFolder}/tmp.txt

###Add conditional to detect whether to change this to individual vs group.
if [[ -n "$WhimMask" ]]; then
  ${CARET7DIR}/wb_command -cifti-create-dense-scalar ${FolderMeshFolder}/Grey.dscalar.nii -left-metric ${AtlasFolder}/fsaverage_LR${DiffResMesh}k/${Subject}.L.atlasroi.${DiffResMesh}k_fs_LR.shape.gii -roi-left ${AtlasFolder}/fsaverage_LR${DiffResMesh}k/${Subject}.L.atlasroi.${DiffResMesh}k_fs_LR.shape.gii -right-metric ${AtlasFolder}/fsaverage_LR${DiffResMesh}k/${Subject}.R.atlasroi.${DiffResMesh}k_fs_LR.shape.gii -roi-right ${AtlasFolder}/fsaverage_LR${DiffResMesh}k/${Subject}.R.atlasroi.${DiffResMesh}k_fs_LR.shape.gii -volume ${ROIsTrajectorySpaceFolder}/Atlas_Whole_Brain_SubCortical_GreyMatter_${DiffusionResolution}.nii.gz ${ROIsTrajectorySpaceFolder}/Atlas_Whole_Brain_SubCortical_GreyMatter_${DiffusionResolution}.nii.gz
else
  ${CARET7DIR}/wb_command -cifti-create-dense-scalar ${FolderMeshFolder}/Grey.dscalar.nii -left-metric ${FolderMeshFolder}/${Subject}.L.roi_${RegName}.${DiffResMesh}k_fs_LR.shape.gii -roi-left ${FolderMeshFolder}/${Subject}.L.roi_${RegName}.${DiffResMesh}k_fs_LR.shape.gii -right-metric ${FolderMeshFolder}/${Subject}.R.roi_${RegName}.${DiffResMesh}k_fs_LR.shape.gii -roi-right ${FolderMeshFolder}/${Subject}.R.roi_${RegName}.${DiffResMesh}k_fs_LR.shape.gii -volume ${ROIsTrajectorySpaceFolder}/Whole_Brain_SubCortical_GreyMatter_${DiffusionResolution}.nii.gz ${ROIsTrajectorySpaceFolder}/Whole_Brain_SubCortical_GreyMatter_${DiffusionResolution}.nii.gz
fi
echo ${ROIsTrajectorySpaceFolder}/${Subject}.L.pial_${RegName}.${DiffResMesh}k_fs_LR.gii > ${ROIsTrajectorySpaceFolder}/${Subject}.StopROI_${RegName}.${DiffResMesh}k_fs_LR.txt
echo ${ROIsTrajectorySpaceFolder}/${Subject}.R.pial_${RegName}.${DiffResMesh}k_fs_LR.gii >> ${ROIsTrajectorySpaceFolder}/${Subject}.StopROI_${RegName}.${DiffResMesh}k_fs_LR.txt

echo ${ROIsTrajectorySpaceFolder}/${Subject}.L.white_${RegName}.${DiffResMesh}k_fs_LR.gii > ${ROIsTrajectorySpaceFolder}/${Subject}.GreyROI_${RegName}.${DiffResMesh}k_fs_LR_${DiffusionResolution}.txt
echo ${ROIsTrajectorySpaceFolder}/${Subject}.R.white_${RegName}.${DiffResMesh}k_fs_LR.gii >> ${ROIsTrajectorySpaceFolder}/${Subject}.GreyROI_${RegName}.${DiffResMesh}k_fs_LR_${DiffusionResolution}.txt
if [[ -n "$WhimMask" ]]; then
  echo ${ROIsTrajectorySpaceFolder}/Atlas_Whole_Brain_SubCortical_GreyMatter_${DiffusionResolution}.nii.gz >> ${ROIsTrajectorySpaceFolder}/${Subject}.GreyROI_${RegName}.${DiffResMesh}k_fs_LR_${DiffusionResolution}.txt
else
  echo ${ROIsTrajectorySpaceFolder}/Whole_Brain_SubCortical_GreyMatter_${DiffusionResolution}.nii.gz >> ${ROIsTrajectorySpaceFolder}/${Subject}.GreyROI_${RegName}.${DiffResMesh}k_fs_LR_${DiffusionResolution}.txt
fi


