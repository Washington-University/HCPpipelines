#!/bin/bash
set -eu

## Guess HCPPIPEDIR if not set
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

## Source libraries
source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/tempfiles.shlib" "$@"

## Description of this script to use in usage
opts_SetScriptDescription "Create head mask from T1w and T2w images, and brain mask"

## Define arguments
opts_AddMandatory '--t1w' 'T1wImage' 'path' "full path to T1w image (default filename: T1w_acpc_dc_restore.nii.gz)"
opts_AddMandatory '--t2w' 'T2wImage' 'path' "full path to T2w image (default filename: T2w_acpc_dc_restore.nii.gz)"
opts_AddMandatory '--brain-mask' 'BrainMaskFile' 'path' "full path to brain mask file (default filename: brainmask_fs.nii.gz)"
opts_AddMandatory '--output-filename' 'OutputFile' 'path' "full path to output head mask file (default filename: Head.nii.gz)"

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

## Display the parsed/default values
opts_ShowValues

## Validate that input files exist and that output directory exists and is writable
if [[ ! -f "$T1wImage" ]]; then
    log_Err_Abort "T1w image not found: $T1wImage"
fi
if [[ ! -f "$T2wImage" ]]; then
    log_Err_Abort "T2w image not found: $T2wImage"
fi
if [[ ! -f "$BrainMaskFile" ]]; then
    log_Err_Abort "Brain mask not found: $BrainMaskFile"
fi
outDir="$(dirname "$OutputFile")"
if [[ ! -d "$outDir" || ! -w "$outDir" ]]; then
    log_Err_Abort "Output directory does not exist or is not writable: $outDir"
fi

## Prepare temp files
tempfiles_create HeadSize_bottomslice_XXXXXX.nii.gz botslicetemp
tempfiles_create HeadSize_Head_XXXXXX.nii.gz headtemp

## Main processing
#taken from https://github.com/Washington-University/HCPpipelines/blob/39b9e03c90b80cdc22c81342defe5db7b674a642/TransmitBias/scripts/CreateTransmitBiasROIs.sh#L49C1-L54C71 
fslmaths "$T1wImage" -mul "$T2wImage" -sqrt "$headtemp"
brainmean=$(fslstats "$headtemp" -k "$BrainMaskFile" -M | tr -d ' ')
fslmaths "$headtemp" -div "$brainmean" -thr 0.25 -bin -dilD -dilD -dilD -dilD -ero -ero -ero "$headtemp"
fslmaths "$headtemp" -mul 0 -add 1 -roi 0 -1 0 -1 0 1 0 1 "$botslicetemp"
fslmaths "$headtemp" -add "$botslicetemp" -bin -fillh -ero "$headtemp"
wb_command -volume-remove-islands "$headtemp" "$OutputFile"

log_Msg "Head mask created: $OutputFile"
