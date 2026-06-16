#!/bin/bash
set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"

#this function gets called by opts_ParseArguments when --help is specified
function usage()
{
    #header text
    echo "
$log_ToolName: does stuff

Usage: $log_ToolName PARAMETER...

PARAMETERs are [ ] = optional; < > = user supplied value
"
    #automatic argument descriptions
    opts_ShowArguments
    
    #do not use exit, the parsing code takes care of it
}

#arguments to opts_Add*: switch, variable to set, name for inside of <> in help text, description, [default value if AddOptional], [compatibility flag, ...]
#help info for option gets printed like "--foo=<$3> - $4"
opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject' 'Subject' 'subject ID' ""
opts_AddMandatory '--low-res' 'LowResMesh' 'number' "mesh resolution for fMRI processing, probably '32'"
opts_AddMandatory '--smoothing-fwhm' 'SmoothingFWHM' 'number' "smoothing amount used during fMRI processing, in FWHM mm"
opts_AddMandatory '--fmri-res' 'FinalfMRIResolution' 'number' "voxel size used for fMRIVolume output, in mm"
opts_AddMandatory '--grayordinates-res' 'BrainOrdinatesResolution' 'number' "size of the voxels in cifti outputs"
opts_AddOptional '--surf-reg-name' 'RegName' 'name' "the registration string corresponding to the input files" 'NONE'
opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

#processing code goes here
Sigma=`echo "$SmoothingFWHM / (2 * sqrt(2 * l(2)))" | bc -l`
Factor="0.5" #1/2 T1w/T2w standard deviation

if [ ! ${RegName} = "NONE" ] ; then
  RegString="_${RegName}"
else
  RegString=""
  RegName="MSMSulc"
fi

T1wFolder="${StudyFolder}/${Subject}/T1w"
T1wNativeFolder="${T1wFolder}/Native"
AtlasFolder="${StudyFolder}/${Subject}/MNINonLinear"
NativeFolder="${AtlasFolder}/Native"
DownSampleFolder="${AtlasFolder}/fsaverage_LR${LowResMesh}k"
ROIFolder="${AtlasFolder}/ROIs"

#vein code
if [[ ! -e "${DownSampleFolder}/${Subject}.T1wDividedByT2w_vein_effects${RegString}.${LowResMesh}k_fs_LR.dscalar.nii" ]]
then
    Mean=`fslstats ${T1wFolder}/T1wDividedByT2w.nii.gz -M`
    Std=`fslstats ${T1wFolder}/T1wDividedByT2w.nii.gz -S`
    Thr=`echo "${Mean} + ( ${Std} * ${Factor} )" | bc -l` #The normalized threshold depends on the image mean and standard deviation

    #Blood vessels must be located in between the eroded and dilated brain mask
    fslmaths ${T1wFolder}/brainmask_fs.nii.gz -ero ${T1wFolder}/brainmask_fs_ero.nii.gz
    fslmaths ${T1wFolder}/brainmask_fs.nii.gz -dilD -dilD -dilD ${T1wFolder}/brainmask_fs_dil.nii.gz

    #Threshold stuff and exclude things that are inside the brain
    wb_command -volume-math "(Var * (Var > (${Mean} + (${Std} * ${Factor})))) * (Mask == 0)" ${T1wFolder}/T1wDividedByT2w_thr${Thr}_invmask.nii.gz -var Var ${T1wFolder}/T1wDividedByT2w.nii.gz -var Mask ${T1wFolder}/brainmask_fs_ero.nii.gz 
    #Exclude very small things
    fslmaths ${T1wFolder}/T1wDividedByT2w_thr${Thr}_invmask.nii.gz -bin -ero -dilD ${T1wFolder}/T1wDividedByT2w_thr${Thr}_invmask.nii.gz

    #Threshold stuff and exclude things that are outside the brain
    wb_command -volume-math "(Var * (Var > (${Mean} + (${Std} * ${Factor})))) * (Mask > 0)" ${T1wFolder}/T1wDividedByT2w_thr${Thr}_mask.nii.gz -var Var ${T1wFolder}/T1wDividedByT2w.nii.gz -var Mask ${T1wFolder}/brainmask_fs_ero.nii.gz 
    #Combine things inside and outside the brain, mask by dilated brain mask to produce vessels map
    fslmaths ${T1wFolder}/T1wDividedByT2w_thr${Thr}_mask.nii.gz -bin -add ${T1wFolder}/T1wDividedByT2w_thr${Thr}_invmask.nii.gz -mas ${T1wFolder}/brainmask_fs_dil.nii.gz -bin ${T1wFolder}/T1wDividedByT2w_veins.nii.gz

    #Blood vessels may have effects out to some distance, so dilate two 0.7mm voxels and smooth- 
    fslmaths ${T1wFolder}/T1wDividedByT2w_veins.nii.gz -dilD -dilD -s ${Sigma} ${T1wFolder}/T1wDividedByT2w_vein_effects.nii.gz
    rm ${T1wFolder}/brainmask_fs_ero.nii.gz ${T1wFolder}/brainmask_fs_dil.nii.gz ${T1wFolder}/T1wDividedByT2w_thr${Thr}_invmask.nii.gz ${T1wFolder}/T1wDividedByT2w_thr${Thr}_mask.nii.gz

    applywarp --interp=trilinear -i ${T1wFolder}/T1wDividedByT2w_vein_effects.nii.gz -r ${AtlasFolder}/T1w_restore.${BrainOrdinatesResolution}.nii.gz -w ${AtlasFolder}/xfms/acpc_dc2standard.nii.gz -o ${AtlasFolder}/T1wDividedByT2w_vein_effects.${BrainOrdinatesResolution}.nii.gz
    applywarp --interp=trilinear -i ${T1wFolder}/T1wDividedByT2w_vein_effects.nii.gz -r ${AtlasFolder}/T1w_restore.nii.gz -w ${AtlasFolder}/xfms/acpc_dc2standard.nii.gz -o ${AtlasFolder}/T1wDividedByT2w_vein_effects.nii.gz

    for Hemisphere in L R ; do
        #Map bias field volume to surface using the same approach as when fMRI data are projected to the surface
        volume="${AtlasFolder}/T1wDividedByT2w_vein_effects.${BrainOrdinatesResolution}.nii.gz"
        surface="${NativeFolder}/${Subject}.${Hemisphere}.midthickness.native.surf.gii"
        metricOut="${NativeFolder}/${Subject}.${Hemisphere}.T1wDividedByT2w_vein_effects.native.func.gii"
        ribbonInner="${NativeFolder}/${Subject}.${Hemisphere}.white.native.surf.gii"
        ribbonOutter="${NativeFolder}/${Subject}.${Hemisphere}.pial.native.surf.gii"
        wb_command -volume-to-surface-mapping $volume $surface $metricOut -ribbon-constrained $ribbonInner $ribbonOutter
     
        #Mask out the medial wall of dilated file
        metric="${NativeFolder}/${Subject}.${Hemisphere}.T1wDividedByT2w_vein_effects.native.func.gii"
        mask="${NativeFolder}/${Subject}.${Hemisphere}.roi.native.shape.gii"
        metricOut="${NativeFolder}/${Subject}.${Hemisphere}.T1wDividedByT2w_vein_effects.native.func.gii"
        wb_command -metric-mask $metric $mask $metricOut

        #Resample the surface data from the native mesh to the standard mesh
        metricIn="${NativeFolder}/${Subject}.${Hemisphere}.T1wDividedByT2w_vein_effects.native.func.gii"
        currentSphere="${NativeFolder}/${Subject}.${Hemisphere}.sphere.${RegName}.native.surf.gii"
        newSphere="${DownSampleFolder}/${Subject}.${Hemisphere}.sphere.${LowResMesh}k_fs_LR.surf.gii"
        method="ADAP_BARY_AREA"
        metricOut="${DownSampleFolder}/${Subject}.${Hemisphere}.T1wDividedByT2w_vein_effects.${LowResMesh}k_fs_LR.func.gii"
        currentArea="${NativeFolder}/${Subject}.${Hemisphere}.midthickness.native.surf.gii"
        newArea="${DownSampleFolder}/${Subject}.${Hemisphere}.midthickness.${LowResMesh}k_fs_LR.surf.gii"
        roiMetric="${NativeFolder}/${Subject}.${Hemisphere}.roi.native.shape.gii"
        wb_command -metric-resample $metricIn $currentSphere $newSphere $method $metricOut -area-surfs $currentArea $newArea -current-roi $roiMetric

        #Make sure the medial wall is zeros
        metric="${DownSampleFolder}/${Subject}.${Hemisphere}.T1wDividedByT2w_vein_effects.${LowResMesh}k_fs_LR.func.gii"
        mask="${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii"
        metricOut="${DownSampleFolder}/${Subject}.${Hemisphere}.T1wDividedByT2w_vein_effects.${LowResMesh}k_fs_LR.func.gii"
        wb_command -metric-mask $metric $mask $metricOut

        #Smooth the surface bias field the same as the fMRI
        surface="${DownSampleFolder}/${Subject}.${Hemisphere}.midthickness.${LowResMesh}k_fs_LR.surf.gii"
        metricIn="${DownSampleFolder}/${Subject}.${Hemisphere}.T1wDividedByT2w_vein_effects.${LowResMesh}k_fs_LR.func.gii"
        smoothingKernel="${Sigma}"
        metricOut="${DownSampleFolder}/${Subject}.${Hemisphere}.T1wDividedByT2w_vein_effects.${LowResMesh}k_fs_LR.func.gii"
        roiMetric="${DownSampleFolder}/${Subject}.${Hemisphere}.atlasroi.${LowResMesh}k_fs_LR.shape.gii"
        wb_command -metric-smoothing $surface $metricIn $smoothingKernel $metricOut -roi $roiMetric
    done
      
    unset POSIXLY_CORRECT
    if [ 1 -eq `echo "$BrainOrdinatesResolution == $FinalfMRIResolution" | bc -l` ] ; then
        #If using the same fMRI and grayordinates space resolution, use the simple algorithm to project bias field into subcortical CIFTI space like fMRI
        volumeIn="${AtlasFolder}/T1wDividedByT2w_vein_effects.${BrainOrdinatesResolution}.nii.gz"
        currentParcel="${ROIFolder}/ROIs.${BrainOrdinatesResolution}.nii.gz"
        newParcel="${ROIFolder}/Atlas_ROIs.${BrainOrdinatesResolution}.nii.gz"
        kernel="${Sigma}"
        volumeOut="${AtlasFolder}/T1wDividedByT2w_vein_effects_AtlasSubcortical.${BrainOrdinatesResolution}.nii.gz"
        wb_command -volume-parcel-resampling $volumeIn $currentParcel $newParcel $kernel $volumeOut
    else
        #If using different fMRI and grayordinates space resolutions, use the generic algorithm to project bias field into subcortical CIFTI space like fMRI
        volumeIn="${AtlasFolder}/T1wDividedByT2w_vein_effects.${BrainOrdinatesResolution}.nii.gz"
        currentParcel="${AtlasResultsFolder}/ROIs.${FinalfMRIResolution}.nii.gz"
        newParcel="${ROIFolder}/Atlas_ROIs.${BrainOrdinatesResolution}.nii.gz"
        kernel="${Sigma}"
        volumeOut="${AtlasFolder}/T1wDividedByT2w_vein_effects_AtlasSubcortical.${BrainOrdinatesResolution}.nii.gz"
        wb_command -volume-parcel-resampling-generic $volumeIn $currentParcel $newParcel $kernel $volumeOut
    fi

    #Create CIFTI file of bias field as was done with fMRI
    ciftiOut="${DownSampleFolder}/${Subject}.T1wDividedByT2w_vein_effects${RegString}.${LowResMesh}k_fs_LR.dscalar.nii"
    volumeData="${AtlasFolder}/T1wDividedByT2w_vein_effects_AtlasSubcortical.${BrainOrdinatesResolution}.nii.gz"
    labelVolume="${ROIFolder}/Atlas_ROIs.${BrainOrdinatesResolution}.nii.gz"
    lMetric="${DownSampleFolder}/${Subject}.L.T1wDividedByT2w_vein_effects.${LowResMesh}k_fs_LR.func.gii"
    lRoiMetric="${DownSampleFolder}/${Subject}.L.atlasroi.${LowResMesh}k_fs_LR.shape.gii"
    rMetric="${DownSampleFolder}/${Subject}.R.T1wDividedByT2w_vein_effects.${LowResMesh}k_fs_LR.func.gii"
    rRoiMetric="${DownSampleFolder}/${Subject}.R.atlasroi.${LowResMesh}k_fs_LR.shape.gii"
    wb_command -cifti-create-dense-scalar $ciftiOut -volume $volumeData $labelVolume -left-metric $lMetric -roi-left $lRoiMetric -right-metric $rMetric -roi-right $rRoiMetric

    #Set Palette in CIFTI dscalar
    ciftiIn="${DownSampleFolder}/${Subject}.T1wDividedByT2w_vein_effects${RegString}.${LowResMesh}k_fs_LR.dscalar.nii"
    mode="MODE_AUTO_SCALE_PERCENTAGE"
    ciftiOut="${DownSampleFolder}/${Subject}.T1wDividedByT2w_vein_effects${RegString}.${LowResMesh}k_fs_LR.dscalar.nii"
    wb_command -cifti-palette $ciftiIn $mode $ciftiOut -pos-percent 4 96 -neg-percent 4 96 -interpolate true -disp-pos true -disp-neg true -disp-zero true -palette-name videen_style
    wb_command -set-map-names "$ciftiOut" -map 1 vein_effects
fi

#putamen code
if [[ ! -e "${DownSampleFolder}/${Subject}.PialPutamen_Effects${RegString}.${LowResMesh}k_fs_LR.dscalar.nii" ]]
then

    wb_command -volume-math "(Vol == 12) + (Vol == 51)" ${T1wFolder}/Putamen.nii.gz -var Vol ${T1wFolder}/wmparc.nii.gz
    wb_command -volume-dilate ${T1wFolder}/Putamen.nii.gz 3 NEAREST ${T1wFolder}/Putamen_dil.nii.gz
    #wb_command -volume-to-surface-mapping ${T1wFolder}/Putamen_dil.nii.gz ${T1wNativeFolder}/${Subject}.L.pial.native.surf.gii ${T1wNativeFolder}/${Subject}.L.Putamen.native.func.gii -enclosing
    #wb_command -volume-to-surface-mapping ${T1wFolder}/Putamen_dil.nii.gz ${T1wNativeFolder}/${Subject}.R.pial.native.surf.gii ${T1wNativeFolder}/${Subject}.R.Putamen.native.func.gii -enclosing
    wb_command -volume-to-surface-mapping ${T1wFolder}/Putamen_dil.nii.gz ${T1wNativeFolder}/${Subject}.L.white.native.surf.gii ${T1wNativeFolder}/${Subject}.L.Putamen.native.func.gii -enclosing
    wb_command -volume-to-surface-mapping ${T1wFolder}/Putamen_dil.nii.gz ${T1wNativeFolder}/${Subject}.R.white.native.surf.gii ${T1wNativeFolder}/${Subject}.R.Putamen.native.func.gii -enclosing

    wb_command -cifti-create-dense-from-template ${NativeFolder}/${Subject}.MyelinMap_BC.native.dscalar.nii ${NativeFolder}/${Subject}.PialPutamen_Effects.native.dscalar.nii -metric CORTEX_LEFT ${T1wNativeFolder}/${Subject}.L.Putamen.native.func.gii -metric CORTEX_RIGHT ${T1wNativeFolder}/${Subject}.R.Putamen.native.func.gii
    rm ${T1wNativeFolder}/${Subject}.L.Putamen.native.func.gii ${T1wNativeFolder}/${Subject}.R.Putamen.native.func.gii
    wb_command -cifti-find-clusters ${NativeFolder}/${Subject}.PialPutamen_Effects.native.dscalar.nii 0.99 5 0.99 25 COLUMN ${NativeFolder}/${Subject}.PialPutamen_Effects.native.dscalar.nii -left-surface ${T1wNativeFolder}/${Subject}.L.midthickness.native.surf.gii -right-surface ${T1wNativeFolder}/${Subject}.R.midthickness.native.surf.gii
    wb_command -cifti-math "Var > 0" ${NativeFolder}/${Subject}.PialPutamen_Effects.native.dscalar.nii -var Var ${NativeFolder}/${Subject}.PialPutamen_Effects.native.dscalar.nii
    wb_command -cifti-dilate ${NativeFolder}/${Subject}.PialPutamen_Effects.native.dscalar.nii COLUMN 3 3 ${NativeFolder}/${Subject}.PialPutamen_Effects.native.dscalar.nii -left-surface ${T1wNativeFolder}/${Subject}.L.midthickness.native.surf.gii -right-surface ${T1wNativeFolder}/${Subject}.R.midthickness.native.surf.gii -nearest
    wb_command -cifti-smoothing ${NativeFolder}/${Subject}.PialPutamen_Effects.native.dscalar.nii ${Sigma} ${Sigma} COLUMN ${NativeFolder}/${Subject}.PialPutamen_Effects.native.dscalar.nii -left-surface ${T1wNativeFolder}/${Subject}.L.midthickness.native.surf.gii -right-surface ${T1wNativeFolder}/${Subject}.R.midthickness.native.surf.gii

    wb_command -cifti-resample ${NativeFolder}/${Subject}.PialPutamen_Effects.native.dscalar.nii COLUMN ${DownSampleFolder}/${Subject}.MyelinMap_BC${RegString}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ADAP_BARY_AREA ENCLOSING_VOXEL ${DownSampleFolder}/${Subject}.PialPutamen_Effects${RegString}.${LowResMesh}k_fs_LR.dscalar.nii -left-spheres ${NativeFolder}/${Subject}.L.sphere.${RegName}.native.surf.gii ${DownSampleFolder}/${Subject}.L.sphere.${LowResMesh}k_fs_LR.surf.gii -left-area-surfs ${NativeFolder}/${Subject}.L.midthickness.native.surf.gii ${DownSampleFolder}/${Subject}.L.midthickness.${LowResMesh}k_fs_LR.surf.gii -right-spheres ${NativeFolder}/${Subject}.R.sphere.${RegName}.native.surf.gii ${DownSampleFolder}/${Subject}.R.sphere.${LowResMesh}k_fs_LR.surf.gii -right-area-surfs ${NativeFolder}/${Subject}.R.midthickness.native.surf.gii ${DownSampleFolder}/${Subject}.R.midthickness.${LowResMesh}k_fs_LR.surf.gii

    #Set Palette in CIFTI dscalar
    ciftiIn="${DownSampleFolder}/${Subject}.PialPutamen_Effects${RegString}.${LowResMesh}k_fs_LR.dscalar.nii"
    mode="MODE_AUTO_SCALE_PERCENTAGE"
    ciftiOut="${DownSampleFolder}/${Subject}.PialPutamen_Effects${RegString}.${LowResMesh}k_fs_LR.dscalar.nii"
    wb_command -cifti-palette $ciftiIn $mode $ciftiOut -pos-percent 4 96 -neg-percent 4 96 -interpolate true -disp-pos true -disp-neg true -disp-zero true -palette-name videen_style
    wb_command -set-map-names "$ciftiOut" -map 1 PialPutamen_Effects
fi

