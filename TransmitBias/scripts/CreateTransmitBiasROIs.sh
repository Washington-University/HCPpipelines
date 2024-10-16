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

opts_SetScriptDescription "makes ROIs relevant to transmit bias correction"

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject' 'Subject' 'subject ID' "(e.g. 100610)"
opts_AddMandatory '--grayordinates-res' 'grayordRes' 'number' "resolution used for low resolution MNINonLinear output volumes"
opts_AddMandatory '--transmit-res' 'transmitRes' 'number' "resolution to use for transmit field"

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

#Build Paths
T1wFolder="$StudyFolder/$Subject"/T1w
AtlasFolder="$StudyFolder/$Subject"/MNINonLinear

#create low-res T1w-space image for completeness
#special case, if resolutions are equal, borrow the fMRI grid (legacy reasons), otherwise do a new applyisoxfm
if [[ "$transmitRes" == "$grayordRes" ]]
then
    wb_command -volume-resample "$T1wFolder"/T1w_acpc_dc_restore.nii.gz "$AtlasFolder"/T1w_restore."$grayordRes".nii.gz CUBIC "$T1wFolder"/T1w_acpc_dc_restore."$transmitRes".nii.gz
else
    #use flirt options to avoid blurring, instead of an extra applywarp
    flirt -in "$T1wFolder"/T1w_acpc_dc_restore.nii.gz -ref "$T1wFolder"/T1w_acpc_dc_restore.nii.gz -applyisoxfm "$transmitRes" -out "$T1wFolder"/T1w_acpc_dc_restore."$transmitRes".nii.gz -interp spline -noresampblur
fi

#Compute Head Size
tempfiles_create TransmitBias_bottomslice_XXXXXX.nii.gz botslicetemp
tempfiles_create TransmitBias_Head_XXXXXX.nii.gz headtemp
fslmaths "$T1wFolder"/T1w_acpc_dc_restore.nii.gz -mul "$T1wFolder"/T2w_acpc_dc_restore.nii.gz -sqrt "$headtemp"
brainmean=$(fslstats "$headtemp" -k "$T1wFolder"/brainmask_fs.nii.gz -M | tr -d ' ')
fslmaths "$headtemp" -div "$brainmean" -thr 0.25 -bin -dilD -dilD -dilD -dilD -ero -ero -ero "$headtemp"
fslmaths "$headtemp" -mul 0 -add 1 -roi 0 -1 0 -1 0 1 0 1 "$botslicetemp"
fslmaths "$headtemp" -add "$botslicetemp" -bin -fillh -ero "$headtemp"
wb_command -volume-remove-islands "$headtemp" "$T1wFolder"/Head.nii.gz

#ROI Operations
applywarp --interp=nn -i "$T1wFolder"/Head.nii.gz -r "$T1wFolder"/T1w_acpc_dc_restore."$transmitRes".nii.gz -o "$T1wFolder"/Head."$transmitRes".nii.gz

#AtlasFolder uses fMRI res, not guaranteed to be transmit res
applywarp --interp=nn -i "$T1wFolder"/Head.nii.gz -r "$AtlasFolder"/T1w_restore."$grayordRes".nii.gz -w "$AtlasFolder"/xfms/acpc_dc2standard.nii.gz -o "$AtlasFolder"/Head."$grayordRes".nii.gz
applywarp --interp=nn -i "$T1wFolder"/Head.nii.gz -r "$AtlasFolder"/T1w_restore.nii.gz -w "$AtlasFolder"/xfms/acpc_dc2standard.nii.gz -o "$AtlasFolder"/Head.nii.gz

mkdir -p "$T1wFolder"/ROIs

wb_command -volume-resample "$T1wFolder"/wmparc.nii.gz "$T1wFolder"/T1w_acpc_dc_restore."$transmitRes".nii.gz ENCLOSING_VOXEL "$T1wFolder"/ROIs/wmparc."$transmitRes".nii.gz

function import_to_roi() {
    wmparc="$1"
    config="$2"
    output="$3"
    tempfiles_create TransmitBias_importtemp_XXXXXX.nii.gz importtemp
    wb_command -volume-label-import "$wmparc" "$config" "$importtemp" -discard-others -drop-unused-labels
    wb_command -volume-math "X > 0" "$output" -var X "$importtemp"
}

GMWMConfig="$HCPPIPEDIR/global/config/FreeSurferAllGMWM.txt"

import_to_roi "$AtlasFolder"/wmparc.nii.gz "$GMWMConfig" "$AtlasFolder"/GMWMTemplate.nii.gz
import_to_roi "$T1wFolder"/wmparc.nii.gz "$GMWMConfig" "$T1wFolder"/GMWMTemplate.nii.gz

import_to_roi "$AtlasFolder"/ROIs/wmparc."$grayordRes".nii.gz "$GMWMConfig" "$AtlasFolder"/ROIs/GMWMTemplate."$grayordRes".nii.gz
import_to_roi "$T1wFolder"/ROIs/wmparc."$transmitRes".nii.gz "$GMWMConfig" "$T1wFolder"/ROIs/GMWMTemplate."$transmitRes".nii.gz

VolumeLEFTConfig="$HCPPIPEDIR/global/config/FreeSurferAllGMWMLeft.txt"
VolumeRIGHTConfig="$HCPPIPEDIR/global/config/FreeSurferAllGMWMRight.txt"
CorpusCallosumConfig="$HCPPIPEDIR/global/config/FreeSurferCorpusCallosum.txt"
HindBrainConfig="$HCPPIPEDIR/global/config/FreeSurferHindBrain.txt"
MidBrainConfig="$HCPPIPEDIR/global/config/FreeSurferMidBrain.txt"
LeftThalamusConfig="$HCPPIPEDIR/global/config/FreeSurferLeftThalamus.txt"
RightThalamusConfig="$HCPPIPEDIR/global/config/FreeSurferRightThalamus.txt"
PureCSFConfig="$HCPPIPEDIR/global/config/FreeSurferPureCSFLut.txt"

#do the straightforward ones first
configs=("$VolumeLEFTConfig" "$VolumeRIGHTConfig" "$HindBrainConfig" "$LeftThalamusConfig" "$RightThalamusConfig")
outnames=( L_GMWMTemplate      R_GMWMTemplate       HindBrainTemplate  L_ThalamusTemplate    R_ThalamusTemplate)

for ((i = 0; i < ${#configs[@]}; ++i))
do
    import_to_roi "$T1wFolder"/ROIs/wmparc."$transmitRes".nii.gz "${configs[$i]}" "$T1wFolder"/ROIs/"${outnames[$i]}"."$transmitRes".nii.gz
done

#these need a bit of cleanup, use temporaries
tempfiles_create transmit_ROIs_callosumtemp_XXXXXX.nii.gz callosumtemp
import_to_roi "$T1wFolder"/ROIs/wmparc."$transmitRes".nii.gz "$CorpusCallosumConfig" "$callosumtemp"
wb_command -volume-dilate "$callosumtemp" 2.5 NEAREST "$T1wFolder"/ROIs/CorpusCallosumTemplate."$transmitRes".nii.gz -data-roi "$T1wFolder"/ROIs/GMWMTemplate."$transmitRes".nii.gz

tempfiles_create transmit_ROIs_midbraintemp_XXXXXX.nii.gz midbraintemp
import_to_roi "$T1wFolder"/ROIs/wmparc."$transmitRes".nii.gz "$MidBrainConfig" "$midbraintemp"
#Rename this, or include thalamus in midbrain config file?
#matt doesn't know a better name
wb_command -volume-math "L_Thalamus || R_Thalamus || MidBrain" "$T1wFolder"/ROIs/MidBrainTemplate."$transmitRes".nii.gz -var L_Thalamus "$T1wFolder"/ROIs/L_ThalamusTemplate."$transmitRes".nii.gz -var R_Thalamus "$T1wFolder"/ROIs/R_ThalamusTemplate."$transmitRes".nii.gz -var MidBrain "$midbraintemp"

#csf uses anatomical resolution, MNI space
wb_command -volume-label-import "$AtlasFolder"/wmparc.nii.gz "$PureCSFConfig" "$AtlasFolder"/LateralVentricles.nii.gz -discard-others -drop-unused-labels
fslmaths "$AtlasFolder"/LateralVentricles.nii.gz -ero -bin "$AtlasFolder"/LateralVentricles.nii.gz

tempfiles_create transmit_ROIs_inttemp_XXXXXX.nii.gz inttemp
wb_command -volume-math '(LEFT && !RIGHT && !HIND) * 1 + (RIGHT && !HIND) * 2 + (HIND > 0) * 3' "$inttemp" -var LEFT "$T1wFolder"/ROIs/L_GMWMTemplate."$transmitRes".nii.gz -var RIGHT "$T1wFolder"/ROIs/R_GMWMTemplate."$transmitRes".nii.gz -var HIND "$T1wFolder"/ROIs/HindBrainTemplate."$transmitRes".nii.gz
wb_command -volume-dilate "$inttemp" 50 NEAREST "$T1wFolder"/ROIs/TransmitBias_ROI."$transmitRes".nii.gz -data-roi "$T1wFolder"/Head."$transmitRes".nii.gz
wb_command -volume-math "(LABEL == 1)" "$T1wFolder"/ROIs/L_TransmitBias_ROI."$transmitRes".nii.gz -var LABEL "$T1wFolder"/ROIs/TransmitBias_ROI."$transmitRes".nii.gz
wb_command -volume-math "(LABEL == 2)" "$T1wFolder"/ROIs/R_TransmitBias_ROI."$transmitRes".nii.gz -var LABEL "$T1wFolder"/ROIs/TransmitBias_ROI."$transmitRes".nii.gz
wb_command -volume-math "(LABEL == 3)" "$T1wFolder"/ROIs/H_TransmitBias_ROI."$transmitRes".nii.gz -var LABEL "$T1wFolder"/ROIs/TransmitBias_ROI."$transmitRes".nii.gz

