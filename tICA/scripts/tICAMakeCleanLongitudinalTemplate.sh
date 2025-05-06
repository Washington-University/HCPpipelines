#!/bin/bash
set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/tempfiles.shlib" "$@"

#description to use in usage - syntax of parameters is now explained automatically
opts_SetScriptDescription "creates tICA cleaned data for all longitudinal sessions in template directory"

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder that contains all sessions"
opts_AddMandatory '--session-list' 'SesslistRaw' 'HCA6002236_V1_MR@HCA6002236_V2_MR...' "list of longitudinal timepoint/session IDs separated by @s."
opts_AddMandatory '--fmri-names' 'fMRINames' 'rfMRI_REST1_LR@rfMRI_REST1_RL...' "list of all fmri run names separated by @s"

opts_AddOptional '--extract-fmri-name-list' 'concatNamesToUse' 'name@name@name...' "list of fMRI run names to concatenate into the --extract-fmri-out output after tICA cleanup"
opts_AddOptional '--extract-fmri-out' 'extractNameOut' 'name' "fMRI name for concatenated extracted runs, requires --extract-fmri-name-list"
opts_AddOptional '--extract-fmri-out-only' 'ExtractfMRIOnly' 'TRUE or FALSE'  'Only output timepoints specified in --extract-frmi-name-list and --extract-fmri-out' 'FALSE'

ExtractfMRIOnly=$(opts_StringToBool "$ExtractfMRIOnly")