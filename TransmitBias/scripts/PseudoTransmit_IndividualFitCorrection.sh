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

opts_SetScriptDescription "uses group pseudotransmit reference value to improve individual correction"

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject' 'Subject' 'subject ID' "(e.g. 100610)"
opts_AddOptional '--manual-receive' 'useRCfilesStr' 'TRUE or FALSE' "whether Phase1 used unprocessed scans to correct for not using PSN when acquiring scans" 'false'
opts_AddMandatory '--gmwm-template' 'GMWMtemplate' 'file' "file containing GM+WM volume ROI"
opts_AddMandatory '--myelin-template' 'ReferenceTemplate' 'file' "expected group-average myelin pattern (for testing correction parameters)"
opts_AddMandatory '--group-uncorrected-myelin' 'GroupUncorrectedMyelin' 'file' "the group-average (non-transmit-corrected) myelin file (to appropriately rescale --myelin-template)"
opts_AddMandatory '--reference-value' 'PseudoTransmitReferenceValue' 'number' "value in pseudotransmit map where the flip angle best matches the intended angle, found in Phase2 script"
opts_AddMandatory '--grayordinates-res' 'grayordRes' 'string' "resolution used in PostFreeSurfer for grayordinates"
opts_AddMandatory '--transmit-res' 'transmitRes' 'number' "resolution to use for transmit field"
opts_AddMandatory '--reg-name' 'RegName' 'string' "surface registration to use, like MSMAll"
opts_AddOptional '--low-res-mesh' 'LowResMesh' 'number' "resolution of grayordinates mesh, default '32'" '32'
opts_AddOptional '--matlab-run-mode' 'MatlabMode' '0, 1, or 2' "defaults to 0
0 = compiled MATLAB
1 = interpreted MATLAB
2 = Octave" '0'

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

useRCfiles=$(opts_StringToBool "$useRCfilesStr")

case "$MatlabMode" in
    (0)
        if [[ "${MATLAB_COMPILER_RUNTIME:-}" == "" ]]
        then
            log_Err_Abort "To use compiled matlab, you must set and export the variable MATLAB_COMPILER_RUNTIME"
        fi
        ;;
    (1)
        matlab_interpreter=(matlab -nodisplay -nosplash)
        ;;
    (2)
        matlab_interpreter=(octave-cli -q --no-window-system)
        ;;
    (*)
        log_Err_Abort "unrecognized matlab mode '$MatlabMode', use 0, 1, or 2"
        ;;
esac

this_script_dir=$(dirname "$0")

if [[ "$RegName" == "" || "$RegName" == "MSMSulc" ]]
then
    RegString=""
else
    RegString="_$RegName"
fi

T1wFolder="$StudyFolder"/"$Subject"/T1w
AtlasFolder="$StudyFolder"/"$Subject"/MNINonLinear
T1wDownSampleFolder="$T1wFolder"/fsaverage_LR"$LowResMesh"k
DownSampleFolder="$AtlasFolder"/fsaverage_LR"$LowResMesh"k

RawPseudoTransmit="$T1wFolder"/PseudoTransmitField_Raw."$transmitRes".nii.gz
LeftWhite="$T1wDownSampleFolder"/"$Subject".L.white"$RegString"."$LowResMesh"k_fs_LR.surf.gii
LeftMidthick="$T1wDownSampleFolder"/"$Subject".L.midthickness"$RegString"."$LowResMesh"k_fs_LR.surf.gii
LeftPial="$T1wDownSampleFolder"/"$Subject".L.pial"$RegString"."$LowResMesh"k_fs_LR.surf.gii
RightWhite="$T1wDownSampleFolder"/"$Subject".R.white"$RegString"."$LowResMesh"k_fs_LR.surf.gii
RightMidthick="$T1wDownSampleFolder"/"$Subject".R.midthickness"$RegString"."$LowResMesh"k_fs_LR.surf.gii
RightPial="$T1wDownSampleFolder"/"$Subject".R.pial"$RegString"."$LowResMesh"k_fs_LR.surf.gii
ThreshUpper=1
ThreshLower=0.6
SmoothLower=10
SmoothUpper=60
L_ROI="$T1wFolder"/ROIs/L_TransmitBias_ROI."$transmitRes".nii.gz
R_ROI="$T1wFolder"/ROIs/R_TransmitBias_ROI."$transmitRes".nii.gz
OutputTextFile="$T1wFolder"/PseudoTransmit_stats.txt
OutlierSmoothing=10
Dilation=25

SubjectMyelin="$DownSampleFolder"/"$Subject".MyelinMap"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii
NativeVolMyelin="$T1wFolder"/T1wDividedByT2w.nii.gz
if ((useRCfiles))
then
    SubjectMyelin="$StudyFolder"/"$Subject"/TransmitBias/"$Subject".MyelinMap_onlyRC"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii
    NativeVolMyelin="$StudyFolder"/"$Subject"/TransmitBias/T1wDividedByT2w_onlyRC.nii.gz
fi

tempfiles_create TransmitBias_scaledpseudotransmit_XXXXXX.nii.gz scaledpt

wb_command -volume-math "Raw / $PseudoTransmitReferenceValue" "$scaledpt" -var Raw "$RawPseudoTransmit"

for var in SubjectMyelin scaledpt LeftPial LeftMidthick LeftWhite RightPial RightMidthick RightWhite L_ROI R_ROI GroupUncorrectedMyelin ReferenceTemplate
do
    newvar="$var"Tmp
    tempfiles_copy "${!var}" "$newvar"
done

argvarlist=(SubjectMyelinTmp scaledptTmp \
    LeftPialTmp LeftMidthickTmp LeftWhiteTmp \
    RightPialTmp RightMidthickTmp RightWhiteTmp \
    ThreshLower ThreshUpper SmoothLower SmoothUpper \
    L_ROITmp R_ROITmp \
    OutlierSmoothing Dilation \
    GroupUncorrectedMyelinTmp ReferenceTemplateTmp OutputTextFile)

case "$MatlabMode" in
    (0)
        arglist=()
        for var in "${argvarlist[@]}"
        do
            arglist+=("${!var}")
        done
        "$this_script_dir"/Compiled_PseudoTransmit_OptimizeSmoothing/run_PseudoTransmit_OptimizeSmoothing.sh "$MATLAB_COMPILER_RUNTIME" "${arglist[@]}"
        ;;
    (1 | 2)
        matlabargs=""
        matlabcode="
        addpath('$HCPPIPEDIR/global/fsl/etc/matlab');
        addpath('$HCPCIFTIRWDIR');
        addpath('$HCPPIPEDIR/global/matlab');
        addpath('$this_script_dir');
        "
        for var in "${argvarlist[@]}"
        do
            #NOTE: the newline before the closing quote is important, to avoid the 4KB stdin line limit
            matlabcode+="$var = '${!var}';
            "
            
            if [[ "$matlabargs" != "" ]]; then matlabargs+=", "; fi
            matlabargs+="$var"
        done

        matlabcode+="PseudoTransmit_OptimizeSmoothing(${matlabargs});"
        
        echo "running matlab code: $matlabcode"
        "${matlab_interpreter[@]}" <<<"$matlabcode"
        echo
        ;;
esac

PseudoTransmitThreshold=$(cat "$OutputTextFile" | cut -d "," -f 1)
Smooth=$(cat "$OutputTextFile" | cut -d "," -f 2)
SmoothingCorrection=$(cat "$OutputTextFile" | cut -d "," -f 3)
Slope=$(cat "$OutputTextFile" | cut -d "," -f 4)

#this code matches part of what goes on inside PseudoTransmitOptimizeSmoothing.m
#probably wouldn't be enough code saved here by making matlab create the file, though
tempfiles_create TransmitBias_XXXXXX_rawnorm.nii.gz rawnorm
tempfiles_add "$rawnorm"_threshbin.nii.gz "$rawnorm"_islandmask.nii.gz "$rawnorm"_smooth.nii.gz "$rawnorm"_diff.nii.gz "$rawnorm"_badvox.nii.gz

wb_command -volume-math "PT >= $PseudoTransmitThreshold" "$rawnorm"_threshbin.nii.gz -var PT "$scaledpt"
wb_command -volume-remove-islands "$rawnorm"_threshbin.nii.gz "$rawnorm"_islandmask.nii.gz

wb_command -volume-smoothing "$scaledpt" -fwhm "$OutlierSmoothing" "$rawnorm"_smooth.nii.gz -roi "$rawnorm"_islandmask.nii.gz
wb_command -volume-math "Mask * (Data - Smooth)" "$rawnorm"_diff.nii.gz \
    -var Data "$scaledpt" \
    -var Smooth "$rawnorm"_smooth.nii.gz \
    -var Mask "$rawnorm"_islandmask.nii.gz
wb_command -volume-math "abs(diff) > 2 * $(wb_command -volume-stats "$rawnorm"_diff.nii.gz -reduce STDEV -roi "$rawnorm"_islandmask.nii.gz)" "$rawnorm"_badvox.nii.gz \
    -var diff "$rawnorm"_diff.nii.gz
wb_command -volume-math "(! Bad) * islandmask * Data" "$rawnorm" \
    -var Data "$scaledpt" \
    -var Bad "$rawnorm"_badvox.nii.gz \
    -var islandmask "$rawnorm"_islandmask.nii.gz

#rPseudoTransmit is in Phase3, but only because of the reference value, not a group-average correction like AFI
function dilate_smooth()
{
    local data="$1"
    local roi="$2"
    local output="$3"
    tempfiles_create TransmitBias_dilatesmooth_XXXXXX.nii.gz tempvol
    #NOTE: exponent 2 is probably because threshold leaves a rim of dropout-like values that we want to largely ignore
    wb_command -volume-dilate "$data" "$Dilation" WEIGHTED "$tempvol" \
        -data-roi "$roi" -grad-extrapolate -exponent 2
    wb_command -volume-smoothing "$tempvol" -fwhm "$Smooth" "$output" \
        -roi "$roi" -fix-zeros
}

tempfiles_create TransmitBias_structure_XXXXXX.txt tempstruct
tempfiles_add "$tempstruct"_L.nii.gz "$tempstruct"_R.nii.gz "$tempstruct"_H.nii.gz

dilate_smooth "$rawnorm" \
    "$T1wFolder"/ROIs/L_TransmitBias_ROI."$transmitRes".nii.gz \
    "$tempstruct"_L.nii.gz

dilate_smooth "$rawnorm" \
    "$T1wFolder"/ROIs/R_TransmitBias_ROI."$transmitRes".nii.gz \
    "$tempstruct"_R.nii.gz

dilate_smooth "$rawnorm" \
    "$T1wFolder"/ROIs/H_TransmitBias_ROI."$transmitRes".nii.gz \
    "$tempstruct"_H.nii.gz

tempfiles_create TransmitBias_rPseudoTransmitNorm_XXXXXX.nii.gz rptnorm
tempfiles_add "$rptnorm"_CC.nii.gz "$rptnorm"_CC_HBJ.nii.gz "$rptnorm"_CC_HBJ_Thal.nii.gz

wb_command -volume-math "LEFT + RIGHT + HIND" "$rptnorm" -var LEFT "$tempstruct"_L.nii.gz -var RIGHT "$tempstruct"_R.nii.gz -var HIND "$tempstruct"_H.nii.gz

function removeroigrad()
{
    indata="$1"
    inroi="$2" #mask of where the undesired gradient is, defining the data range to smooth from
    mask="$3" #mask to prevent it from changing input values
    outfinal="$4"
    blendero="2.5" #how much to erode the roi when saying which voxels should be completely replaced by the implicit smoothed version (mm, try not to make exact multiple of voxel size)
    fixupsmooth=10 #how much to smooth within the roi (mm fwhm)
    blendsmooth=5 #how much to smooth the roi after dilating to make the blending function (mm fwhm)
    
    #processing
    tempfiles_create removeroigradtemp_XXXXXX tempbase
    tempfiles_add "$tempbase"_data_mask.nii.gz "$tempbase"_data_mask_smooth.nii.gz "$tempbase"_mask_smooth.nii.gz "$tempbase"_data_impsmooth.nii.gz "$tempbase"_mask_unlabel.nii.gz
    
    wb_command -volume-math 'data * mask' "$tempbase"_data_mask.nii.gz -var data "$indata" -var mask "$inroi" -subvolume 1 -repeat
    wb_command -volume-smoothing "$tempbase"_data_mask.nii.gz "$fixupsmooth" "$tempbase"_data_mask_smooth.nii.gz -fwhm
    wb_command -volume-math 'label' "$tempbase"_mask_unlabel.nii.gz -var label "$inroi"
    wb_command -volume-smoothing "$tempbase"_mask_unlabel.nii.gz "$fixupsmooth" "$tempbase"_mask_smooth.nii.gz -fwhm
    wb_command -volume-math 'datasmooth / roismooth' "$tempbase"_data_impsmooth.nii.gz -var datasmooth "$tempbase"_data_mask_smooth.nii.gz -var roismooth "$tempbase"_mask_smooth.nii.gz -subvolume 1 -repeat -fixnan 0

    tempfiles_add "$tempbase"_mask_dil.nii.gz "$tempbase"_mask_dil_smooth.nii.gz "$tempbase"_mask_dil_smooth_mask.nii.gz "$tempbase"_mask_blend.nii.gz "$tempbase"_mask_erode.nii.gz
    wb_command -volume-smoothing "$tempbase"_mask_unlabel.nii.gz "$blendsmooth" "$tempbase"_mask_dil_smooth.nii.gz -fwhm
    wb_command -volume-erode "$inroi" "$blendero" "$tempbase"_mask_erode.nii.gz
    wb_command -volume-math 'smooth * (! core)' "$tempbase"_mask_dil_smooth_mask.nii.gz -var smooth "$tempbase"_mask_dil_smooth.nii.gz -var core "$tempbase"_mask_erode.nii.gz
    fringemax=$(wb_command -volume-stats "$tempbase"_mask_dil_smooth_mask.nii.gz -reduce MAX)
    wb_command -volume-math "(core + fringe / $fringemax) * (roismooth && mask)" "$tempbase"_mask_blend.nii.gz -var core "$tempbase"_mask_erode.nii.gz -var fringe "$tempbase"_mask_dil_smooth_mask.nii.gz -var roismooth "$tempbase"_mask_smooth.nii.gz -var mask "$mask"

    wb_command -volume-math "main * (1 - blend) + impsmooth * blend" "$outfinal" -var main "$indata" -var impsmooth "$tempbase"_data_impsmooth.nii.gz -var blend "$tempbase"_mask_blend.nii.gz -subvolume 1 -repeat
}

removeroigrad "$rptnorm" "$T1wFolder"/ROIs/CorpusCallosumTemplate."$transmitRes".nii.gz "$T1wFolder"/Head."$transmitRes".nii.gz "$rptnorm"_CC.nii.gz

tempfiles_create TransmitBias_dilroi_XXXXXX dilroi
tempfiles_add "$dilroi"_midbrain.nii.gz "$dilroi"_hindbrain.nii.gz "$dilroi"_L_thalamus.nii.gz "$dilroi"_R_thalamus.nii.gz

wb_command -volume-dilate "$T1wFolder"/ROIs/MidBrainTemplate."$transmitRes".nii.gz 7 NEAREST "$dilroi"_midbrain.nii.gz
wb_command -volume-dilate "$T1wFolder"/ROIs/HindBrainTemplate."$transmitRes".nii.gz 7 NEAREST "$dilroi"_hindbrain.nii.gz
wb_command -volume-math "MidBrain && HindBrain && GMWM" "$T1wFolder"/ROIs/HindBrainJunctionTemplate."$transmitRes".nii.gz -var MidBrain "$dilroi"_midbrain.nii.gz -var HindBrain "$dilroi"_hindbrain.nii.gz -var GMWM "$T1wFolder"/ROIs/GMWMTemplate."$transmitRes".nii.gz

removeroigrad "$rptnorm"_CC.nii.gz "$T1wFolder"/ROIs/HindBrainJunctionTemplate."$transmitRes".nii.gz "$T1wFolder"/Head."$transmitRes".nii.gz "$rptnorm"_CC_HBJ.nii.gz

wb_command -volume-dilate "$T1wFolder"/ROIs/L_ThalamusTemplate."$transmitRes".nii.gz 7 NEAREST "$dilroi"_L_thalamus.nii.gz
wb_command -volume-dilate "$T1wFolder"/ROIs/R_ThalamusTemplate."$transmitRes".nii.gz 7 NEAREST "$dilroi"_R_thalamus.nii.gz
wb_command -volume-math "L_Thalamus && R_Thalamus && GMWM" "$T1wFolder"/ROIs/ThalamusJunctionTemplate."$transmitRes".nii.gz -var L_Thalamus "$dilroi"_L_thalamus.nii.gz -var R_Thalamus "$dilroi"_R_thalamus.nii.gz -var GMWM "$T1wFolder"/ROIs/GMWMTemplate."$transmitRes".nii.gz

#if there are some voxels in this ROI
if [[ $(fslstats "$T1wFolder"/ROIs/ThalamusJunctionTemplate."$transmitRes".nii.gz -V | cut -d " " -f 1) != "0" ]]
then
    removeroigrad "$rptnorm"_CC_HBJ.nii.gz "$T1wFolder"/ROIs/ThalamusJunctionTemplate."$transmitRes".nii.gz "$T1wFolder"/Head."$transmitRes".nii.gz "$rptnorm"_CC_HBJ_Thal.nii.gz
else
    #mv is fine (and faster) because they are tempfiles and will be deleted anyway
    mv "$rptnorm"_CC_HBJ.nii.gz "$rptnorm"_CC_HBJ_Thal.nii.gz
fi

wb_command -volume-math "Var * $SmoothingCorrection" "$T1wFolder"/rPseudoTransmitField_Norm."$transmitRes".nii.gz -var Var "$rptnorm"_CC_HBJ_Thal.nii.gz

tempfiles_create TransmitBias_rPseudoTransmitNorm_dil_XXXXXX.nii.gz rptnormdil

#Resample Transmit Field
wb_command -volume-dilate "$T1wFolder"/rPseudoTransmitField_Norm."$transmitRes".nii.gz 3 NEAREST "$rptnormdil"
applywarp --interp=trilinear -i "$rptnormdil" -r "$AtlasFolder"/Head."$grayordRes".nii.gz -w "$AtlasFolder"/xfms/acpc_dc2standard.nii.gz -o "$AtlasFolder"/rPseudoTransmitField_Norm."$grayordRes".nii.gz
applywarp --interp=trilinear -i "$rptnormdil" -r "$T1wFolder"/Head.nii.gz -o "$T1wFolder"/rPseudoTransmitField_Norm.nii.gz
applywarp --interp=trilinear -i "$rptnormdil" -r "$AtlasFolder"/Head.nii.gz -w "$AtlasFolder"/xfms/acpc_dc2standard.nii.gz -o "$AtlasFolder"/rPseudoTransmitField_Norm.nii.gz

#Transmit Field Correction Application Surface
wb_command -volume-to-surface-mapping "$T1wFolder"/rPseudoTransmitField_Norm."$transmitRes".nii.gz "$T1wDownSampleFolder"/"$Subject".L.midthickness"$RegString"."$LowResMesh"k_fs_LR.surf.gii "$DownSampleFolder"/"$Subject".L.rPseudoTransmitField_Norm"$RegString"."$LowResMesh"k_fs_LR.func.gii -ribbon-constrained "$T1wDownSampleFolder"/"$Subject".L.white"$RegString"."$LowResMesh"k_fs_LR.surf.gii "$T1wDownSampleFolder"/"$Subject".L.pial"$RegString"."$LowResMesh"k_fs_LR.surf.gii -volume-roi "$T1wFolder"/ROIs/L_TransmitBias_ROI."$transmitRes".nii.gz
wb_command -volume-to-surface-mapping "$T1wFolder"/rPseudoTransmitField_Norm."$transmitRes".nii.gz "$T1wDownSampleFolder"/"$Subject".R.midthickness"$RegString"."$LowResMesh"k_fs_LR.surf.gii "$DownSampleFolder"/"$Subject".R.rPseudoTransmitField_Norm"$RegString"."$LowResMesh"k_fs_LR.func.gii -ribbon-constrained "$T1wDownSampleFolder"/"$Subject".R.white"$RegString"."$LowResMesh"k_fs_LR.surf.gii "$T1wDownSampleFolder"/"$Subject".R.pial"$RegString"."$LowResMesh"k_fs_LR.surf.gii -volume-roi "$T1wFolder"/ROIs/R_TransmitBias_ROI."$transmitRes".nii.gz
wb_command -cifti-create-dense-scalar "$DownSampleFolder"/"$Subject".rPseudoTransmitField_Norm"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii -left-metric "$DownSampleFolder"/"$Subject".L.rPseudoTransmitField_Norm"$RegString"."$LowResMesh"k_fs_LR.func.gii -roi-left "$DownSampleFolder"/"$Subject".L.atlasroi."$LowResMesh"k_fs_LR.shape.gii -right-metric "$DownSampleFolder"/"$Subject".R.rPseudoTransmitField_Norm"$RegString"."$LowResMesh"k_fs_LR.func.gii -roi-right "$DownSampleFolder"/"$Subject".R.atlasroi."$LowResMesh"k_fs_LR.shape.gii
wb_command -cifti-dilate "$DownSampleFolder"/"$Subject".rPseudoTransmitField_Norm"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii COLUMN 10 10 "$DownSampleFolder"/"$Subject".rPseudoTransmitField_Norm"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii -nearest -left-surface "$T1wDownSampleFolder"/"$Subject".L.midthickness"$RegString"."$LowResMesh"k_fs_LR.surf.gii -right-surface "$T1wDownSampleFolder"/"$Subject".R.midthickness"$RegString"."$LowResMesh"k_fs_LR.surf.gii

wb_command -cifti-math "myelin / (transmit * $Slope + (1 - $Slope))" "$DownSampleFolder"/"$Subject".MyelinMap_PseudoCorr"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii \
    -var myelin "$SubjectMyelin" \
    -var transmit "$DownSampleFolder"/"$Subject".rPseudoTransmitField_Norm"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii

tempfiles_create TransmitBias_ptnorm_XXXXXX.dscalar.nii tempnorm

wb_command -cifti-math "(Var * (Var > $PseudoTransmitThreshold)) / $PseudoTransmitReferenceValue" "$tempnorm" -var Var "$DownSampleFolder"/"$Subject".PseudoTransmitField_Raw"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii
wb_command -cifti-dilate "$tempnorm" COLUMN 25 25 "$DownSampleFolder"/"$Subject".PseudoTransmitField_Norm"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii -nearest -left-surface "$T1wDownSampleFolder"/"$Subject".L.midthickness"$RegString"."$LowResMesh"k_fs_LR.surf.gii -right-surface "$T1wDownSampleFolder"/"$Subject".R.midthickness"$RegString"."$LowResMesh"k_fs_LR.surf.gii

#Transmit Field Correction Application Volume

function indvolToAtlas()
{
    indata="$1"
    volout="$2"
    tempfiles_create indvolToAtlas_XXXXXX.nii.gz masktemp
    tempfiles_add "$masktemp"_dilate.nii.gz
    wb_command -volume-math '(mask > 0) * data' "$masktemp" -var mask "$AtlasFolder"/GMWMTemplate.nii.gz -subvolume 1 -repeat -var data "$indata"
    wb_command -volume-dilate "$masktemp" 10 WEIGHTED "$masktemp"_dilate.nii.gz -data-roi "$GMWMtemplate"
    wb_command -volume-math '(mask > 0) * data' "$volout" -var mask "$GMWMtemplate" -subvolume 1 -repeat -var data "$masktemp"_dilate.nii.gz
}

indvolToAtlas "$AtlasFolder"/rPseudoTransmitField_Norm.nii.gz "$AtlasFolder"/rPseudoTransmitField_Norm_Atlas.nii.gz

indvolToAtlas "$AtlasFolder"/PseudoTransmitField_Raw.nii.gz "$AtlasFolder"/PseudoTransmitField_Raw_Atlas.nii.gz

tempfiles_create TransmitBias_pseudofield_norm_XXXXXX.nii.gz fieldtemp

wb_command -volume-math "(Var * (Var > $PseudoTransmitThreshold)) / $PseudoTransmitReferenceValue" "$fieldtemp" \
    -var Var "$AtlasFolder"/PseudoTransmitField_Raw_Atlas.nii.gz
wb_command -volume-dilate "$fieldtemp" 25 WEIGHTED "$AtlasFolder"/PseudoTransmitField_Norm_Atlas.nii.gz -data-roi "$GMWMtemplate"

#NOTE: MNINonLinear/T1wDiv... always has RC applied already (via phase 1 outer script), unlike T1w/

wb_command -volume-math "myelin / (transmit * $Slope + (1 - $Slope))" "$AtlasFolder"/T1wDividedByT2w_PseudoCorr_Atlas.nii.gz -fixnan 0 \
    -var myelin "$AtlasFolder"/T1wDividedByT2w_Atlas.nii.gz \
    -var transmit "$AtlasFolder"/rPseudoTransmitField_Norm_Atlas.nii.gz

wb_command -volume-math "(myelin / (transmit * $Slope + (1 - $Slope))) * MASK" "$AtlasFolder"/T1wDividedByT2w_PseudoCorr.nii.gz -fixnan 0 \
    -var myelin "$AtlasFolder"/T1wDividedByT2w.nii.gz \
    -var transmit "$AtlasFolder"/rPseudoTransmitField_Norm.nii.gz \
    -var MASK "$AtlasFolder"/Head.nii.gz

#T1w-space
wb_command -volume-math "(myelin / (transmit * $Slope + (1 - $Slope)))*MASK" "$T1wFolder"/T1wDividedByT2w_PseudoCorr.nii.gz -fixnan 0 \
    -var myelin "$NativeVolMyelin" \
    -var transmit "$T1wFolder"/rPseudoTransmitField_Norm.nii.gz \
    -var MASK "$T1wFolder"/Head.nii.gz
#just mask to make the _ribbon version
wb_command -volume-math "corrmyelin * (ribbon > 0)" "$T1wFolder"/T1wDividedByT2w_PseudoCorr_ribbon.nii.gz \
    -var corrmyelin "$AtlasFolder"/T1wDividedByT2w_PseudoCorr.nii.gz \
    -var ribbon "$T1wFolder"/T1wDividedByT2w_ribbon.nii.gz

tempfiles_create TransmitBias_findcsf_XXXXXX.nii.gz findcsf

#Regressor Generation
wb_command -volume-math "MASK * sqrt(T1w * T2w) / corrmyelin" "$findcsf" -fixnan 0 -var corrmyelin "$AtlasFolder"/T1wDividedByT2w_PseudoCorr.nii.gz -var T1w "$AtlasFolder"/T1w_restore.nii.gz -var T2w "$AtlasFolder"/T2w_restore.nii.gz -var MASK "$AtlasFolder"/Head.nii.gz
fslmaths "$findcsf" -thr $(fslstats "$findcsf" -P 99) -bin -mas "$AtlasFolder"/LateralVentricles.nii.gz "$AtlasFolder"/PureCSF.nii.gz

CSFRatioArgs=()
for ((i = 1; i < 100; ++i))
do
    CSFRatioArgs+=(-P "$i")
done
fslstats "$AtlasFolder"/T1wDividedByT2w_PseudoCorr.nii.gz -k "$AtlasFolder"/PureCSF.nii.gz "${CSFRatioArgs[@]}" | tr ' ' ',' > "$AtlasFolder"/PseudoTransmit_CSFStats.txt

