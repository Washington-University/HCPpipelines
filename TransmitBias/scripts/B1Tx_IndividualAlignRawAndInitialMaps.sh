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

opts_SetScriptDescription "align B1Tx and myelin-related scans"

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject' 'Subject' 'subject ID' "(e.g. 100610)"
opts_AddMandatory '--working-dir' 'WorkingDIR' 'path' "where to put intermediate files"
opts_AddMandatory '--b1tx-mag' 'b1mag' 'file' "magnitude image of B1Tx map"
opts_AddMandatory '--b1tx-phase' 'b1phase' 'file' "phase image of B1Tx map"
opts_AddMandatory '--b1tx-phase-divisor' 'phasediv' 'number' "what to divide the B1Tx phase map by to obtain proportion of expected flip angle"
opts_AddOptional '--receive-bias' 'ReceiveBias' 'image' "receive bias field to divide out of B1Tx images, if PSN wasn't used"
opts_AddOptional '--t2w-receive-corrected' 'T2wRC' 'image' "T2w image with receive correction applied, required when using --receive-bias"
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

if [[ "$ReceiveBias" != "" && "$T2wRC" == "" ]]
then
    log_Err_Abort "--t2w-receive-corrected is required when -receive-bias is used"
fi

#Build Paths
T1wFolder="$StudyFolder"/"$Subject"/T1w
AtlasFolder="$StudyFolder"/"$Subject"/MNINonLinear
T1wResultsFolder="$T1wFolder"/Results
ResultsFolder="$AtlasFolder"/Results
T1wDownSampleFolder="$T1wFolder"/fsaverage_LR"$LowResMesh"k
DownSampleFolder="$AtlasFolder"/fsaverage_LR"$LowResMesh"k

mkdir -p "$WorkingDIR"/xfms

if [[ "$GradientDistortionCoeffs" != "" ]]
then
    cp "$b1mag" "$WorkingDIR"/gradunwarpin.nii.gz
    
    "$HCPPIPEDIR"/global/scripts/GradientDistortionUnwarp.sh \
        --workingdir="$WorkingDIR"/gradunwarp \
        --coeffs="$GradientDistortionCoeffs" \
        --in="$WorkingDIR"/gradunwarpin.nii.gz \
        --out="$WorkingDIR"/gradunwarpout.nii.gz \
        --owarp="$WorkingDIR"/gradunwarpfield.nii.gz
    
    gradxfmargs=(-warp "$WorkingDIR"/gradunwarpfield.nii.gz -fnirt "$WorkingDIR"/gradunwarpin.nii.gz)
    
    wb_command -volume-resample "$b1mag" "$b1mag" CUBIC "$WorkingDIR"/B1Tx_mag.nii.gz "${gradxfmargs[@]}"
    #NOTE: assumes no wraparound exists in phase image (but so does the correction math)
    wb_command -volume-resample "$b1phase" "$b1mag" CUBIC "$WorkingDIR"/B1Tx_phase_raw.nii.gz "${gradxfmargs[@]}"
else
    cp "$b1mag" "$WorkingDIR"/B1Tx_mag.nii.gz
    cp "$b1phase" "$WorkingDIR"/B1Tx_phase_raw.nii.gz
fi

#divide here to avoid passing it into the other scripts
wb_command -volume-math "phase / $phasediv" "$WorkingDIR"/B1Tx_phase.nii.gz \
    -var phase "$WorkingDIR"/B1Tx_phase_raw.nii.gz

#apply receive correction to magnitude ONLY
useB1mag="$WorkingDIR"/B1Tx_mag.nii.gz
useT2w="$T1wFolder"/T2w_acpc_dc.nii.gz
if [[ "$ReceiveBias" != "" ]]
then
    tempfiles_create TransmitBias_B1receive_XXXXXX.nii.gz b1receive
    wb_command -volume-resample "$ReceiveBias" "$WorkingDIR"/B1Tx_mag.nii.gz TRILINEAR "$b1receive"
    wb_command -volume-math 'data / bias' "$WorkingDIR"/B1Tx_mag_RC.nii.gz -fixnan 0 \
        -var data "$WorkingDIR"/B1Tx_mag.nii.gz \
        -var bias "$b1receive"
    useB1mag="$WorkingDIR"/B1Tx_mag_RC.nii.gz
    useT2w="$T2wRC"
fi

#Raw Data Registration
"$HCPPIPEDIR"/global/scripts/bbregister.sh --study-folder="$StudyFolder" --subject="$Subject" \
    --input-image="$useB1mag" \
    --init-target-image="$useT2w" \
    --contrast-type=T2w \
    --surface-name=white.deformed \
    --output-xfm="$WorkingDIR"/xfms/B1Tx_mag2str.mat \
    --output-inverse-xfm="$WorkingDIR"/xfms/str2B1Tx_mag.mat \
    --bbregister-regfile-out="$WorkingDIR"/B1Tx_mag_bbregister.dat

#Resampling Operations
B1ToStr=--premat="$WorkingDIR"/xfms/B1Tx_mag2str.mat
StrToMNI=--warp="$AtlasFolder"/xfms/acpc_dc2standard.nii.gz

wb_command -volume-math '1' "$WorkingDIR"/B1Tx_fov.nii.gz -var x "$useB1mag"

applywarp --rel --interp=trilinear -i "$WorkingDIR"/B1Tx_fov.nii.gz -r "$T1wFolder"/T1w_acpc_dc_restore.nii.gz "$B1ToStr" -o "$T1wFolder"/B1Tx_fov.nii.gz

Val=$(fslstats "$T1wFolder"/B1Tx_fov.nii.gz -k "$T1wFolder"/brainmask_fs.nii.gz -m | cut -d " " -f 1)
echo "$Val" > "$T1wFolder"/B1Tx_Coverage.txt

function resample_multi_space()
{
    local namepart="$1"
    
    applywarp --rel --interp=spline -i "$WorkingDIR"/"$namepart".nii.gz -r "$T1wFolder"/T1w_acpc_dc_restore.nii.gz \
        "$B1ToStr" \
        -o "$T1wFolder"/"$namepart".nii.gz
    applywarp --rel --interp=spline -i "$WorkingDIR"/"$namepart".nii.gz -r "$AtlasFolder"/T1w_restore.nii.gz \
        "$B1ToStr" "$StrToMNI" \
        -o "$AtlasFolder"/"$namepart".nii.gz
    applywarp --rel --interp=spline -i "$WorkingDIR"/"$namepart".nii.gz -r "$T1wFolder"/T1w_acpc_dc_restore."$transmitRes".nii.gz \
        "$B1ToStr" \
        -o "$T1wFolder"/"$namepart"."$transmitRes".nii.gz
    applywarp --rel --interp=spline -i "$WorkingDIR"/"$namepart".nii.gz -r "$AtlasFolder"/T1w_restore."$grayordRes".nii.gz \
        "$B1ToStr" "$StrToMNI" \
        -o "$AtlasFolder"/"$namepart"."$grayordRes".nii.gz

}

resample_multi_space B1Tx_mag
resample_multi_space B1Tx_phase
resample_multi_space B1Tx_fov

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
mappingcommand=(wb_command -volume-to-surface-mapping "$T1wFolder"/B1Tx_phase.nii.gz "$T1wDownSampleFolder"/"$Subject".L.midthickness"$RegString"."$LowResMesh"k_fs_LR.surf.gii "$DownSampleFolder"/"$Subject".L.B1Tx_phase"$RegString"."$LowResMesh"k_fs_LR.func.gii \
    -myelin-style "$lribbon" "$lthickness" "$MyelinMappingSigma")
if ((oldmapping))
then
    mappingcommand+=(-legacy-bug)
fi
"${mappingcommand[@]}"

wb_command -volume-math "ribbon == $RightGreyRibbonValue" "$rribbon" -var ribbon "$T1wFolder"/ribbon.nii.gz
mappingcommand=(wb_command -volume-to-surface-mapping "$T1wFolder"/B1Tx_phase.nii.gz "$T1wDownSampleFolder"/"$Subject".R.midthickness"$RegString"."$LowResMesh"k_fs_LR.surf.gii "$DownSampleFolder"/"$Subject".R.B1Tx_phase"$RegString"."$LowResMesh"k_fs_LR.func.gii \
    -myelin-style "$rribbon" "$rthickness" "$MyelinMappingSigma")
if ((oldmapping))
then
    mappingcommand+=(-legacy-bug)
fi
"${mappingcommand[@]}"

tempfiles_create TransmitBias_B1Tx_phase_raw_XXXXXX.dscalar.nii tempscalar

wb_command -cifti-create-dense-scalar "$tempscalar" \
    -left-metric "$DownSampleFolder"/"$Subject".L.B1Tx_phase"$RegString"."$LowResMesh"k_fs_LR.func.gii \
        -roi-left "$DownSampleFolder"/"$Subject".L.atlasroi."$LowResMesh"k_fs_LR.shape.gii \
    -right-metric "$DownSampleFolder"/"$Subject".R.B1Tx_phase"$RegString"."$LowResMesh"k_fs_LR.func.gii \
        -roi-right "$DownSampleFolder"/"$Subject".R.atlasroi."$LowResMesh"k_fs_LR.shape.gii

wb_command -cifti-dilate "$tempscalar" COLUMN 25 25 "$DownSampleFolder"/"$Subject".B1Tx_phase"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii \
    -left-surface "$T1wDownSampleFolder"/"$Subject".L.midthickness"$RegString"."$LowResMesh"k_fs_LR.surf.gii \
    -right-surface "$T1wDownSampleFolder"/"$Subject".R.midthickness"$RegString"."$LowResMesh"k_fs_LR.surf.gii

