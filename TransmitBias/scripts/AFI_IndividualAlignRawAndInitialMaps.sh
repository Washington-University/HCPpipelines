#!/bin/bash
set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/tempfiles.shlib" "$@"

opts_SetScriptDescription "align AFI and myelin-related scans"

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject' 'Subject' 'subject ID' "(e.g. 100610)"
opts_AddMandatory '--working-dir' 'AFIFolder' 'path' "where to put intermediate files"
opts_AddMandatory '--afi-input' 'AFIin' 'file' "two-frame 'actual flip angle' scan"
opts_AddMandatory '--afi-tr-one' 'TRone' 'number' "TR of first AFI frame"
opts_AddMandatory '--afi-tr-two' 'TRtwo' 'number' "TR of second AFI frame"
opts_AddOptional '--receive-bias' 'ReceiveBias' 'image' "receive bias field to divide out of AFI images, if PSN wasn't used"
opts_AddOptional '--t1w-receive-corrected' 'T1wRC' 'image' "T1w image with receive correction applied, required when using --receive-bias"
opts_AddOptional '--scanner-grad-coeffs' 'GradientDistortionCoeffs' 'file' "Siemens gradient coefficients file"
opts_AddMandatory '--reg-name' 'RegName' 'string' "surface registration to use, like MSMAll"
opts_AddOptional '--low-res-mesh' 'LowResMesh' 'number' "resolution of grayordinates mesh, default '32'" '32'
opts_AddMandatory '--grayordinates-res' 'grayordRes' 'number' "resolution used in PostFreeSurfer for grayordinates"
opts_AddMandatory '--transmit-res' 'transmitRes' 'number' "resolution to use for transmit field"
opts_AddOptional '--myelin-mapping-fwhm' 'MyelinMappingFWHM' 'number' "fwhm value to use in -myelin-style, default 5" '5'
opts_AddOptional '--old-myelin-mapping' 'oldmappingStr' 'TRUE or FALSE' "if myelin mapping was done using version 1.2.3 or earlier of wb_command, set this to true" 'false'

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

oldmapping=$(opts_StringToBool "$oldmappingStr")

if [[ "$RegName" == "" || "$RegName" == "MSMSulc" ]]
then
    RegString=""
else
    RegString="_$RegName"
fi

if [[ "$ReceiveBias" != "" && "$T1wRC" == "" ]]
then
    log_Err_Abort "--t1w-receive-corrected is required when -receive-bias is used"
fi

#Naming Conventions

#keep the /reg folder?
#MFG: check what old code put there
#TSC: bbregister temporary images and output affines
#TSC: other two don't have /reg
#MFG: can make it consistent
#Build Paths
T1wFolder="$StudyFolder/$Subject"/T1w
AtlasFolder="$StudyFolder/$Subject"/MNINonLinear
T1wDownSampleFolder="$T1wFolder"/fsaverage_LR"$LowResMesh"k
DownSampleFolder="$AtlasFolder"/fsaverage_LR"$LowResMesh"k
WorkingDirectory="$AFIFolder"

GlobalScripts="$HCPPIPEDIR/global/scripts"

#Register Raw Data
mkdir -p "$AFIFolder"/GradientDistortionUnwarp
mkdir -p "$WorkingDirectory/xfms"

wb_command -volume-reorient "$AFIin" RPI "$AFIFolder"/AFI_orig.nii.gz
if [[ "$GradientDistortionCoeffs" == "" ]]
then
    cp "$AFIFolder"/AFI_orig.nii.gz "$AFIFolder"/AFI_orig_gdc.nii.gz
else
    "$GlobalScripts"/GradientDistortionUnwarp.sh --workingdir="$AFIFolder"/GradientDistortionUnwarp \
        --coeffs="$GradientDistortionCoeffs" \
        --in="$AFIFolder"/AFI_orig.nii.gz \
        --out="$AFIFolder"/AFI_orig_gdc.nii.gz \
        --owarp="$AFIFolder"/AFI_orig_gdc_warp.nii.gz
fi

useAFI="$AFIFolder"/AFI_orig_gdc.nii.gz
useT1w="$T1wFolder"/T1w_acpc_dc.nii.gz
#use new bias field if PSN wasn't used
if [[ "$ReceiveBias" != "" ]]
then
    tempfiles_create TransmitBias_biasresamp_XXXXXX.nii.gz biasresamp
    wb_command -volume-resample "$ReceiveBias" "$AFIFolder"/AFI_orig_gdc.nii.gz TRILINEAR "$biasresamp"
    #deal with 0s in receive field by pretending they were 1s
    wb_command -volume-math 'AFI / (receive + (receive == 0))' "$AFIFolder"/AFI_orig_gdc_RC.nii.gz -fixnan 0 \
        -var AFI "$AFIFolder"/AFI_orig_gdc.nii.gz \
        -var receive "$biasresamp" -repeat

    useAFI="$AFIFolder"/AFI_orig_gdc_RC.nii.gz
    useT1w="$T1wRC"
fi

fslroi "$useAFI" "$AFIFolder"/AFI_orig_gdc1.nii.gz 0 1

#use new receive-corrected structural for bbr initialization
"$HCPPIPEDIR"/global/scripts/bbregister.sh --study-folder="$StudyFolder" --subject="$Subject" \
    --input-image="$AFIFolder"/AFI_orig_gdc1.nii.gz \
    --init-target-image="$useT1w" \
    --contrast-type=T1w \
    --surface-name=white.deformed \
    --output-xfm="$WorkingDirectory"/xfms/AFI_orig2str.mat \
    --output-image="$WorkingDirectory"/AFI_orig_gdc12T1w.nii.gz \
    --output-inverse-xfm="$WorkingDirectory"/xfms/str2AFI_orig.mat \
    --bbregister-regfile-out="$WorkingDirectory"/AFI_orig_bbregister.dat

if [[ "$GradientDistortionCoeffs" == "" ]]
then
    rigidalign=(-affine "$WorkingDirectory"/xfms/AFI_orig2str.mat -flirt "$useAFI" "$T1wFolder"/T1w_acpc_dc_restore.nii.gz)
else
    #include gdc warp before rigid alignment
    rigidalign=(-warp "$AFIFolder"/AFI_orig_gdc_warp.nii.gz -fnirt "$useAFI" \
        -affine "$WorkingDirectory"/xfms/AFI_orig2str.mat -flirt "$useAFI" "$T1wFolder"/T1w_acpc_dc_restore.nii.gz)
fi

#don't use low res for the -fnirt argument
mniwarp=(-warp "$AtlasFolder"/xfms/acpc_dc2standard.nii.gz -fnirt "$AtlasFolder"/T1w_restore.nii.gz)

wb_command -volume-math '1' "$WorkingDirectory"/AFI_fov.nii.gz -var x "$AFIFolder"/AFI_orig_gdc1.nii.gz

wb_command -volume-resample "$WorkingDirectory"/AFI_fov.nii.gz "$T1wFolder"/T1w_acpc_dc_restore.nii.gz TRILINEAR \
    "$T1wFolder"/AFI_fov.nii.gz \
    "${rigidalign[@]}"

Val=$(fslstats "$T1wFolder"/AFI_fov.nii.gz -k "$T1wFolder"/brainmask_fs.nii.gz -m | cut -d " " -f 1)
echo "$Val" > "$T1wFolder"/AFI_Coverage.txt

#NOTE: useAFI is receive corrected
#Transmit Field Correction Regularization
wb_command -volume-resample "$useAFI" "$T1wFolder"/T1w_acpc_dc_restore."$transmitRes".nii.gz CUBIC \
    "$T1wFolder"/AFI_orig."$transmitRes".nii.gz \
    "${rigidalign[@]}"
wb_command -volume-resample "$useAFI" "$AtlasFolder"/T1w_restore."$grayordRes".nii.gz CUBIC \
    "$AtlasFolder"/AFI_orig."$grayordRes".nii.gz \
    "${rigidalign[@]}" "${mniwarp[@]}"

wb_command -volume-resample "$useAFI" "$T1wFolder"/T1w_acpc_dc_restore.nii.gz CUBIC \
    "$T1wFolder"/AFI_orig.nii.gz \
    "${rigidalign[@]}"
wb_command -volume-resample "$useAFI" "$AtlasFolder"/T1w_restore.nii.gz CUBIC \
    "$AtlasFolder"/AFI_orig.nii.gz \
    "${rigidalign[@]}" "${mniwarp[@]}"

AFIAngleFormula="180 / PI * acos(($TRtwo / $TRone * frametwo / frameone - 1) / ($TRtwo / $TRone - frametwo / frameone))"

wb_command -volume-math "$AFIAngleFormula" "$T1wFolder"/AFI."$transmitRes".nii.gz \
    -var frameone "$T1wFolder"/AFI_orig."$transmitRes".nii.gz -subvolume 1 \
    -var frametwo "$T1wFolder"/AFI_orig."$transmitRes".nii.gz -subvolume 2
wb_command -volume-math "$AFIAngleFormula" "$AtlasFolder"/AFI."$grayordRes".nii.gz \
    -var frameone "$AtlasFolder"/AFI_orig."$grayordRes".nii.gz -subvolume 1 \
    -var frametwo "$AtlasFolder"/AFI_orig."$grayordRes".nii.gz -subvolume 2
wb_command -volume-math "$AFIAngleFormula" "$T1wFolder"/AFI.nii.gz \
    -var frameone "$T1wFolder"/AFI_orig.nii.gz -subvolume 1 \
    -var frametwo "$T1wFolder"/AFI_orig.nii.gz -subvolume 2
wb_command -volume-math "$AFIAngleFormula" "$AtlasFolder"/AFI.nii.gz \
    -var frameone "$AtlasFolder"/AFI_orig.nii.gz -subvolume 1 \
    -var frametwo "$AtlasFolder"/AFI_orig.nii.gz -subvolume 2

#AFI_orig on surface
LeftGreyRibbonValue="3"
RightGreyRibbonValue="42"
MyelinMappingSigma=$(echo "$MyelinMappingFWHM / (2 * sqrt(2 * l(2)))" | bc -l)

tempfiles_create thickness_L_XXXXXX.shape.gii lthickness
tempfiles_create thickness_R_XXXXXX.shape.gii rthickness
tempfiles_create ribbon_L_XXXXXX.nii.gz lribbon
tempfiles_create ribbon_R_XXXXXX.nii.gz rribbon

wb_command -cifti-separate "$DownSampleFolder"/"$Subject".thickness"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii COLUMN \
    -metric CORTEX_LEFT "$lthickness" \
    -metric CORTEX_RIGHT "$rthickness"

wb_command -volume-math "ribbon == $LeftGreyRibbonValue" "$lribbon" -var ribbon "$T1wFolder"/ribbon.nii.gz

mappingcommand=(wb_command -volume-to-surface-mapping "$T1wFolder"/AFI_orig.nii.gz "$T1wDownSampleFolder"/"$Subject".L.midthickness"$RegString"."$LowResMesh"k_fs_LR.surf.gii "$DownSampleFolder"/"$Subject".L.AFI_orig"$RegString"."$LowResMesh"k_fs_LR.func.gii \
    -myelin-style "$lribbon" "$lthickness" "$MyelinMappingSigma")
if ((oldmapping))
then
    mappingcommand+=(-legacy-bug)
fi
"${mappingcommand[@]}"

wb_command -volume-math "ribbon == $RightGreyRibbonValue" "$rribbon" -var ribbon "$T1wFolder"/ribbon.nii.gz

mappingcommand=(wb_command -volume-to-surface-mapping "$T1wFolder"/AFI_orig.nii.gz "$T1wDownSampleFolder"/"$Subject".R.midthickness"$RegString"."$LowResMesh"k_fs_LR.surf.gii "$DownSampleFolder"/"$Subject".R.AFI_orig"$RegString"."$LowResMesh"k_fs_LR.func.gii \
    -myelin-style "$rribbon" "$rthickness" "$MyelinMappingSigma")
if ((oldmapping))
then
    mappingcommand+=(-legacy-bug)
fi
"${mappingcommand[@]}"

wb_command -cifti-create-dense-scalar "$DownSampleFolder"/"$Subject".AFI_orig"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii \
    -left-metric "$DownSampleFolder"/"$Subject".L.AFI_orig"$RegString"."$LowResMesh"k_fs_LR.func.gii \
        -roi-left "$DownSampleFolder"/"$Subject".L.atlasroi."$LowResMesh"k_fs_LR.shape.gii \
    -right-metric "$DownSampleFolder"/"$Subject".R.AFI_orig"$RegString"."$LowResMesh"k_fs_LR.func.gii \
        -roi-right "$DownSampleFolder"/"$Subject".R.atlasroi."$LowResMesh"k_fs_LR.shape.gii

tempfiles_create TransmitBias_AFI_raw_XXXXXX.dscalar.nii tempscalar

wb_command -cifti-math "$AFIAngleFormula" "$tempscalar" -fixnan 0 \
    -var frameone "$DownSampleFolder"/"$Subject".AFI_orig"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii -select 1 1 \
    -var frametwo "$DownSampleFolder"/"$Subject".AFI_orig"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii -select 1 2

wb_command -cifti-dilate "$tempscalar" COLUMN 25 25 "$DownSampleFolder"/"$Subject".AFI"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii \
    -left-surface "$T1wDownSampleFolder"/"$Subject".L.midthickness"$RegString"."$LowResMesh"k_fs_LR.surf.gii \
    -right-surface "$T1wDownSampleFolder"/"$Subject".R.midthickness"$RegString"."$LowResMesh"k_fs_LR.surf.gii

