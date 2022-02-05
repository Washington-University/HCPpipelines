#!/bin/bash
set -eu

#TODO: should all of this text be in the help info?

# Generate cifti masks for spatial tICA features. There are two categories of masks, 1. specific brain region masks, 
# including CSF, WM, GM and other subcortical and cortical areas. They are used to capture features in different brain regions;
# 2. brain boundary masks. They are used to identify ring patterns from scanner artifacts with subject head motion. If the sICA dataset is not recleaned there may exist more ring pattern tICA components.

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"

#description to use in usage - syntax of parameters is now explained automatically
opts_SetScriptDescription "Generate cifti masks for spatial tICA features."

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--out-group-name' 'GroupAverageName' 'string' 'group name to use for outputs'
opts_AddMandatory '--fmri-resolution' 'fMRIResolution' 'string' "resolution of data, like '2' or '1.60'"
opts_AddMandatory '--output-fmri-name' 'OutputfMRIName' 'rfMRI_REST' "name to use for tICA pipeline outputs"
opts_AddOptional '--mask-save-path' 'MaskSavePath' 'path' "subfolder name for output mask files"
opts_AddOptional '--label-text-folder' 'ConfigFilePath' 'path' "folder containing the specific lable table text files needed by this script"
opts_AddOptional '--dilate' 'Dilate' 'distance in mm' "amount of dilation to use for the 'avoid' masks, default 5.0" '5.0'
opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues
fMRIResolution=${fMRIResolution}
VolumeTemplate=${GroupAverageName}_CIFTIVolumeTemplate_${OutputfMRIName}.${fMRIResolution}.dscalar.nii
#erode_mm=(1.25 1.75 2.25 2.75 3.25 3.75 4.25 4.75)
erode_mm=(1.00 2.00 3.00 4.00 5.00)
erode_mm_final=()
for erode in ${erode_mm[@]}; do
    #force 2 decimal places for consistency
	result=$(bc -l <<<"scale = 2; ${erode} * ${fMRIResolution} / 1")
	#echo "$result"
	erode_mm_final+=( $result )
done

#for previous code that skipped running if the outputs existed
#EssentialFileNames=(${MaskSavePath}/${GroupAverageName}_AverageWM_Mask_${OutputfMRIName}.${fMRIResolution}.dscalar.nii
#                ${MaskSavePath}/${GroupAverageName}_AverageGM_Mask_${OutputfMRIName}.${fMRIResolution}.dscalar.nii
#                ${MaskSavePath}/${GroupAverageName}_AverageCSF_Mask_${OutputfMRIName}.${fMRIResolution}.dscalar.nii
#                ${MaskSavePath}/${GroupAverageName}_AverageSubcortical_Mask_${OutputfMRIName}.${fMRIResolution}.dscalar.nii
#                ${MaskSavePath}/${GroupAverageName}_AverageRightCerebellar_Mask_${OutputfMRIName}.${fMRIResolution}.dscalar.nii
#                ${MaskSavePath}/${GroupAverageName}_AverageLeftCerebellar_Mask_${OutputfMRIName}.${fMRIResolution}.dscalar.nii
#                ${MaskSavePath}/${GroupAverageName}_AverageLeftGM_NoCerebellar_Mask_${OutputfMRIName}.${fMRIResolution}.dscalar.nii
#                ${MaskSavePath}/${GroupAverageName}_AverageRightGM_NoCerebellar_Mask_${OutputfMRIName}.${fMRIResolution}.dscalar.nii
#                ${MaskSavePath}/${GroupAverageName}_brainboundary_${erode_mm_final[0]}mm_${OutputfMRIName}.${fMRIResolution}.dscalar.nii
#                ${MaskSavePath}/${GroupAverageName}_brainboundary_${erode_mm_final[1]}mm_${OutputfMRIName}.${fMRIResolution}.dscalar.nii
#                ${MaskSavePath}/${GroupAverageName}_brainboundary_${erode_mm_final[2]}mm_${OutputfMRIName}.${fMRIResolution}.dscalar.nii
#                ${MaskSavePath}/${GroupAverageName}_brainboundary_${erode_mm_final[3]}mm_${OutputfMRIName}.${fMRIResolution}.dscalar.nii
#                ${MaskSavePath}/${GroupAverageName}_brainboundary_${erode_mm_final[4]}mm_${OutputfMRIName}.${fMRIResolution}.dscalar.nii
#                ${MaskSavePath}/${GroupAverageName}_brainboundary_${erode_mm_final[5]}mm_${OutputfMRIName}.${fMRIResolution}.dscalar.nii
#                ${MaskSavePath}/${GroupAverageName}_brainboundary_${erode_mm_final[6]}mm_${OutputfMRIName}.${fMRIResolution}.dscalar.nii
#                ${MaskSavePath}/${GroupAverageName}_brainboundary_${erode_mm_final[7]}mm_${OutputfMRIName}.${fMRIResolution}.dscalar.nii)

MNIPath=${StudyFolder}/${GroupAverageName}/MNINonLinear
mkdir -p "$MaskSavePath"

# specific brain region masks
wb_command -volume-label-import ${MNIPath}/${GroupAverageName}_Averagewmparc.nii.gz ${ConfigFilePath}/FreeSurferAllLut.txt ${MaskSavePath}/${GroupAverageName}_Averagewmparc_for_mask.nii.gz -drop-unused-labels
# transform into nifti volume space
wb_command -volume-resample ${MaskSavePath}/${GroupAverageName}_Averagewmparc_for_mask.nii.gz ${MNIPath}/brain_mask_max_${OutputfMRIName}.${fMRIResolution}.nii.gz ENCLOSING_VOXEL ${MaskSavePath}/${GroupAverageName}_Averagewmparc.${fMRIResolution}.nii.gz

wb_command -volume-label-import ${MaskSavePath}/${GroupAverageName}_Averagewmparc.${fMRIResolution}.nii.gz ${ConfigFilePath}/FreeSurferCSFRegLut.txt ${MaskSavePath}/${GroupAverageName}_AverageCSF.${fMRIResolution}.nii.gz -discard-others -drop-unused-labels
wb_command -volume-label-import ${MaskSavePath}/${GroupAverageName}_Averagewmparc.${fMRIResolution}.nii.gz ${ConfigFilePath}/FreeSurferWMRegLut.txt ${MaskSavePath}/${GroupAverageName}_AverageWM.${fMRIResolution}.nii.gz -discard-others -drop-unused-labels
wb_command -volume-label-import ${MaskSavePath}/${GroupAverageName}_Averagewmparc.${fMRIResolution}.nii.gz ${ConfigFilePath}/FreeSurferAllGM.txt ${MaskSavePath}/${GroupAverageName}_AverageGM.${fMRIResolution}.nii.gz -discard-others -drop-unused-labels
wb_command -volume-label-import ${MaskSavePath}/${GroupAverageName}_Averagewmparc.${fMRIResolution}.nii.gz ${ConfigFilePath}/FreeSurferSubcorticalLabelTableLut.txt ${MaskSavePath}/${GroupAverageName}_AverageSubcortical.${fMRIResolution}.nii.gz -discard-others -drop-unused-labels

wb_command -volume-label-import ${MaskSavePath}/${GroupAverageName}_Averagewmparc.${fMRIResolution}.nii.gz ${ConfigFilePath}/FreeSurferCerebellarLabelTableLut.txt ${MaskSavePath}/${GroupAverageName}_AverageCerebellar.${fMRIResolution}.nii.gz -discard-others -drop-unused-labels
wb_command -volume-label-import ${MaskSavePath}/${GroupAverageName}_Averagewmparc.${fMRIResolution}.nii.gz ${ConfigFilePath}/LeftSubcorticalFreeSurferTrajectoryLabelTableLut.txt ${MaskSavePath}/${GroupAverageName}_AverageLeftSubcortical.${fMRIResolution}.nii.gz -discard-others -drop-unused-labels
wb_command -volume-label-import ${MaskSavePath}/${GroupAverageName}_Averagewmparc.${fMRIResolution}.nii.gz ${ConfigFilePath}/RightSubcorticalFreeSurferTrajectoryLabelTableLut.txt ${MaskSavePath}/${GroupAverageName}_AverageRightSubcortical.${fMRIResolution}.nii.gz -discard-others -drop-unused-labels
wb_command -volume-label-import ${MaskSavePath}/${GroupAverageName}_Averagewmparc.${fMRIResolution}.nii.gz ${ConfigFilePath}/FreeSurferAllGMWMLeft.txt ${MaskSavePath}/${GroupAverageName}_AverageLeftGMWM.${fMRIResolution}.nii.gz -discard-others -drop-unused-labels
wb_command -volume-label-import ${MaskSavePath}/${GroupAverageName}_Averagewmparc.${fMRIResolution}.nii.gz ${ConfigFilePath}/FreeSurferAllGMWMRight.txt ${MaskSavePath}/${GroupAverageName}_AverageRightGMWM.${fMRIResolution}.nii.gz -discard-others -drop-unused-labels

# avoid mask		
wb_command -volume-math 'wm > 0' ${MaskSavePath}/${GroupAverageName}_AverageWM_AvoidMask.${fMRIResolution}.nii.gz -var wm ${MaskSavePath}/${GroupAverageName}_AverageWM.${fMRIResolution}.nii.gz
wb_command -volume-math 'csf > 0' ${MaskSavePath}/${GroupAverageName}_AverageCSF_AvoidMask.${fMRIResolution}.nii.gz -var csf ${MaskSavePath}/${GroupAverageName}_AverageCSF.${fMRIResolution}.nii.gz
wb_command -volume-math 'gm > 0' ${MaskSavePath}/${GroupAverageName}_AverageGM_AvoidMask.${fMRIResolution}.nii.gz -var gm ${MaskSavePath}/${GroupAverageName}_AverageGM.${fMRIResolution}.nii.gz

# dilate
wb_command -volume-dilate ${MaskSavePath}/${GroupAverageName}_AverageWM_AvoidMask.${fMRIResolution}.nii.gz ${Dilate} NEAREST ${MaskSavePath}/${GroupAverageName}_AverageWM_AvoidMask.${fMRIResolution}.nii.gz
wb_command -volume-dilate ${MaskSavePath}/${GroupAverageName}_AverageCSF_AvoidMask.${fMRIResolution}.nii.gz ${Dilate} NEAREST ${MaskSavePath}/${GroupAverageName}_AverageCSF_AvoidMask.${fMRIResolution}.nii.gz
wb_command -volume-dilate ${MaskSavePath}/${GroupAverageName}_AverageGM_AvoidMask.${fMRIResolution}.nii.gz ${Dilate} NEAREST ${MaskSavePath}/${GroupAverageName}_AverageGM_AvoidMask.${fMRIResolution}.nii.gz

# nifti mask files
#wb_command -volume-math '(wm > 0) && (! gmavoid)' ${MaskSavePath}/${GroupAverageName}_AverageWM_Mask.${fMRIResolution}.nii.gz -var wm ${MaskSavePath}/${GroupAverageName}_AverageWM.${fMRIResolution}.nii.gz -var gmavoid ${MaskSavePath}/${GroupAverageName}_AverageGM_AvoidMask.${fMRIResolution}.nii.gz
wb_command -volume-math '(wm > 0)' ${MaskSavePath}/${GroupAverageName}_AverageWM_Mask.${fMRIResolution}.nii.gz -var wm ${MaskSavePath}/${GroupAverageName}_AverageWM.${fMRIResolution}.nii.gz

#wb_command -volume-math '(csf > 0) && (! gmavoid)' ${MaskSavePath}/${GroupAverageName}_AverageCSF_Mask.${fMRIResolution}.nii.gz -var csf ${MaskSavePath}/${GroupAverageName}_AverageCSF.${fMRIResolution}.nii.gz -var gmavoid ${MaskSavePath}/${GroupAverageName}_AverageGM_AvoidMask.${fMRIResolution}.nii.gz
wb_command -volume-math '(csf > 0)' ${MaskSavePath}/${GroupAverageName}_AverageCSF_Mask.${fMRIResolution}.nii.gz -var csf ${MaskSavePath}/${GroupAverageName}_AverageCSF.${fMRIResolution}.nii.gz

#wb_command -volume-math '(gm > 0) && (! wmavoid)' ${MaskSavePath}/${GroupAverageName}_AverageGM_Mask.${fMRIResolution}.nii.gz -var gm ${MaskSavePath}/${GroupAverageName}_AverageGM.${fMRIResolution}.nii.gz -var wmavoid ${MaskSavePath}/${GroupAverageName}_AverageWM_AvoidMask.${fMRIResolution}.nii.gz
#wb_command -volume-math '(gm > 0) && (! csfavoid)' ${MaskSavePath}/${GroupAverageName}_AverageGM_Mask.${fMRIResolution}.nii.gz -var gm ${MaskSavePath}/${GroupAverageName}_AverageGM_Mask.${fMRIResolution}.nii.gz -var csfavoid ${MaskSavePath}/${GroupAverageName}_AverageCSF_AvoidMask.${fMRIResolution}.nii.gz
wb_command -volume-math '(gm > 0)' ${MaskSavePath}/${GroupAverageName}_AverageGM_Mask.${fMRIResolution}.nii.gz -var gm ${MaskSavePath}/${GroupAverageName}_AverageGM.${fMRIResolution}.nii.gz

wb_command -volume-math '(subcortical > 0)' ${MaskSavePath}/${GroupAverageName}_AverageSubcortical_Mask.${fMRIResolution}.nii.gz -var subcortical ${MaskSavePath}/${GroupAverageName}_AverageSubcortical.${fMRIResolution}.nii.gz

wb_command -volume-math '(cerebellar > 0)' ${MaskSavePath}/${GroupAverageName}_AverageCerebellar_Mask.${fMRIResolution}.nii.gz -var cerebellar ${MaskSavePath}/${GroupAverageName}_AverageCerebellar.${fMRIResolution}.nii.gz

wb_command -volume-math '(leftgmwm > 0)' ${MaskSavePath}/${GroupAverageName}_AverageLeftGMWM_Mask.${fMRIResolution}.nii.gz -var leftgmwm ${MaskSavePath}/${GroupAverageName}_AverageLeftGMWM.${fMRIResolution}.nii.gz
wb_command -volume-math '(rightgmwm > 0)' ${MaskSavePath}/${GroupAverageName}_AverageRightGMWM_Mask.${fMRIResolution}.nii.gz -var rightgmwm ${MaskSavePath}/${GroupAverageName}_AverageRightGMWM.${fMRIResolution}.nii.gz
wb_command -volume-math '((leftgmwm > 0) && (! cerebellar)) && (gm > 0)' ${MaskSavePath}/${GroupAverageName}_AverageLeftGM_NoCerebellar_Mask.${fMRIResolution}.nii.gz -var leftgmwm ${MaskSavePath}/${GroupAverageName}_AverageLeftGMWM_Mask.${fMRIResolution}.nii.gz -var cerebellar ${MaskSavePath}/${GroupAverageName}_AverageCerebellar_Mask.${fMRIResolution}.nii.gz -var gm ${MaskSavePath}/${GroupAverageName}_AverageGM_Mask.${fMRIResolution}.nii.gz
wb_command -volume-math '((rightgmwm > 0) && (! cerebellar)) && (gm > 0)' ${MaskSavePath}/${GroupAverageName}_AverageRightGM_NoCerebellar_Mask.${fMRIResolution}.nii.gz -var rightgmwm ${MaskSavePath}/${GroupAverageName}_AverageRightGMWM_Mask.${fMRIResolution}.nii.gz -var cerebellar ${MaskSavePath}/${GroupAverageName}_AverageCerebellar_Mask.${fMRIResolution}.nii.gz -var gm ${MaskSavePath}/${GroupAverageName}_AverageGM_Mask.${fMRIResolution}.nii.gz
wb_command -volume-math '(cerebellar > 0) && (! rightgmwm)' ${MaskSavePath}/${GroupAverageName}_AverageLeftCerebellar_Mask.${fMRIResolution}.nii.gz -var rightgmwm ${MaskSavePath}/${GroupAverageName}_AverageRightGMWM_Mask.${fMRIResolution}.nii.gz -var cerebellar ${MaskSavePath}/${GroupAverageName}_AverageCerebellar_Mask.${fMRIResolution}.nii.gz
wb_command -volume-math '(cerebellar > 0) && (! leftgmwm)' ${MaskSavePath}/${GroupAverageName}_AverageRightCerebellar_Mask.${fMRIResolution}.nii.gz -var leftgmwm ${MaskSavePath}/${GroupAverageName}_AverageLeftGMWM_Mask.${fMRIResolution}.nii.gz -var cerebellar ${MaskSavePath}/${GroupAverageName}_AverageCerebellar_Mask.${fMRIResolution}.nii.gz

# dense from template
wb_command -cifti-create-dense-from-template ${MNIPath}/${VolumeTemplate} ${MaskSavePath}/${GroupAverageName}_AverageWM_Mask_${OutputfMRIName}.${fMRIResolution}.dscalar.nii -volume-all ${MaskSavePath}/${GroupAverageName}_AverageWM_Mask.${fMRIResolution}.nii.gz
wb_command -cifti-create-dense-from-template ${MNIPath}/${VolumeTemplate} ${MaskSavePath}/${GroupAverageName}_AverageCSF_Mask_${OutputfMRIName}.${fMRIResolution}.dscalar.nii -volume-all ${MaskSavePath}/${GroupAverageName}_AverageCSF_Mask.${fMRIResolution}.nii.gz
wb_command -cifti-create-dense-from-template ${MNIPath}/${VolumeTemplate} ${MaskSavePath}/${GroupAverageName}_AverageGM_Mask_${OutputfMRIName}.${fMRIResolution}.dscalar.nii -volume-all ${MaskSavePath}/${GroupAverageName}_AverageGM_Mask.${fMRIResolution}.nii.gz
wb_command -cifti-create-dense-from-template ${MNIPath}/${VolumeTemplate} ${MaskSavePath}/${GroupAverageName}_AverageSubcortical_Mask_${OutputfMRIName}.${fMRIResolution}.dscalar.nii -volume-all ${MaskSavePath}/${GroupAverageName}_AverageSubcortical_Mask.${fMRIResolution}.nii.gz

wb_command -cifti-create-dense-from-template ${MNIPath}/${VolumeTemplate} ${MaskSavePath}/${GroupAverageName}_AverageRightCerebellar_Mask_${OutputfMRIName}.${fMRIResolution}.dscalar.nii -volume-all ${MaskSavePath}/${GroupAverageName}_AverageRightCerebellar_Mask.${fMRIResolution}.nii.gz
wb_command -cifti-create-dense-from-template ${MNIPath}/${VolumeTemplate} ${MaskSavePath}/${GroupAverageName}_AverageLeftCerebellar_Mask_${OutputfMRIName}.${fMRIResolution}.dscalar.nii -volume-all ${MaskSavePath}/${GroupAverageName}_AverageLeftCerebellar_Mask.${fMRIResolution}.nii.gz
wb_command -cifti-create-dense-from-template ${MNIPath}/${VolumeTemplate} ${MaskSavePath}/${GroupAverageName}_AverageLeftGM_NoCerebellar_Mask_${OutputfMRIName}.${fMRIResolution}.dscalar.nii -volume-all ${MaskSavePath}/${GroupAverageName}_AverageLeftGM_NoCerebellar_Mask.${fMRIResolution}.nii.gz
wb_command -cifti-create-dense-from-template ${MNIPath}/${VolumeTemplate} ${MaskSavePath}/${GroupAverageName}_AverageRightGM_NoCerebellar_Mask_${OutputfMRIName}.${fMRIResolution}.dscalar.nii -volume-all ${MaskSavePath}/${GroupAverageName}_AverageRightGM_NoCerebellar_Mask.${fMRIResolution}.nii.gz

# brain boundary mask
for erode in ${erode_mm_final[@]}; do
    wb_command -volume-erode ${MNIPath}/brain_mask_max_${OutputfMRIName}.${fMRIResolution}.nii.gz ${erode} ${MaskSavePath}/${GroupAverageName}_CIFTIVolumeTemplateErode_${erode}.nii.gz
    wb_command -cifti-create-dense-from-template ${MNIPath}/${VolumeTemplate} ${MaskSavePath}/${GroupAverageName}_CIFTIVolumeTemplateErode_${erode}_${OutputfMRIName}.dscalar.nii -volume-all ${MaskSavePath}/${GroupAverageName}_CIFTIVolumeTemplateErode_${erode}.nii.gz
    wb_command -cifti-math '(original > 0) && (!eroded)' ${MaskSavePath}/${GroupAverageName}_brainboundary_${erode}mm_${OutputfMRIName}.${fMRIResolution}.dscalar.nii -var original ${MNIPath}/${VolumeTemplate} -var eroded ${MaskSavePath}/${GroupAverageName}_CIFTIVolumeTemplateErode_${erode}_${OutputfMRIName}.dscalar.nii
    rm ${MaskSavePath}/${GroupAverageName}_CIFTIVolumeTemplateErode_${erode}_${OutputfMRIName}.dscalar.nii ${MaskSavePath}/${GroupAverageName}_CIFTIVolumeTemplateErode_${erode}.nii.gz
done

