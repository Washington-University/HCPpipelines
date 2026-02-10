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

function usage()
{
    echo "
$log_ToolName: classifies tICA components as signal or noise using the pre-trained tICA classifier

Usage: $log_ToolName PARAMETER...

PARAMETERs are [ ] = optional; < > = user supplied value
"
    opts_ShowArguments
}

opts_AddMandatory '--study-folder'      'StudyFolder'      'path'    "folder that contains all sessions"
opts_AddMandatory '--out-group-name'    'GroupAverageName' 'string'  "name of the group output folder"
opts_AddMandatory '--fmri-output-name'  'OutputfMRIName'   'string'  "name used for tICA pipeline outputs"
opts_AddMandatory '--ica-dim'           'tICADim'          'integer' "tICA dimensionality"
opts_AddMandatory '--model-dir'         'ModelDir'         'path'    "path to finalized_models/ directory"
opts_AddOptional  '--threshold'         'Threshold'        'float'   "signal classification threshold, default 0.5" '0.5'
opts_AddOptional  '--python-executable' 'PythonExec'       'path'    "python executable to use, default python3" 'python3'

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

opts_ShowValues

tICAFolder="${StudyFolder}/${GroupAverageName}/MNINonLinear/Results/${OutputfMRIName}/tICA_d${tICADim}"

"$PythonExec" "$HCPPIPEDIR/tICA/scripts/ClassifyTICA.py" \
    "$tICAFolder" \
    "$ModelDir" \
    "$Threshold"