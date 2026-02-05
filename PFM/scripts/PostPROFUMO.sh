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
source "$HCPPIPEDIR/global/scripts/tempfiles.shlib"
g_matlab_default_mode=1

#this function gets called by opts_ParseArguments when --help is specified
function usage()
{
    #header text
    echo "
$log_ToolName: Import PFM notes and create time courses, spectra, and maps

Usage: $log_ToolName PARAMETER...

PARAMETERs are [ ] = optional; < > = user supplied value
"
    #automatic argument descriptions
    opts_ShowArguments
    
    #do not use exit, the parsing code takes care of it
}

#arguments to opts_Add*: switch, variable to set, name for inside of <> in help text, description, [default value if AddOptional], [compatibility flag, ...]
opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject-list' 'SubjListRaw' '100206@100307...' 'list of subject IDs separated by @s'
opts_AddMandatory '--fmri-names' 'fMRIListRaw' 'rfMRI_REST1_LR@rfMRI_REST1_RL...' 'list of fmri run names separated by @s'
opts_AddMandatory '--proc-string' 'fMRIProcSTRING' 'string' "file name component representing the preprocessing"
opts_AddMandatory '--output-fmri-name' 'OutputfMRIName' 'rfMRI_REST' "name to use for PFM pipeline outputs"
opts_AddMandatory '--output-string' 'OutputSTRING' 'string' "output string for files"
opts_AddMandatory '--surf-reg-name' 'RegName' 'MSMAll' "the registration string"
opts_AddMandatory '--low-res-mesh' 'LowResMesh' 'string' "mesh resolution"
opts_AddMandatory '--pfm-folder' 'PFMFolder' 'path' "path to PFM results folder"
opts_AddMandatory '--concat-name' 'ConcatName' 'string' "concatenated fMRI name if using multi-run data"
opts_AddMandatory '--profumo-tr' 'TR' "repetition time for PROFUMO analysis" '0.72'

opts_AddOptional '--matlab-run-mode' 'MatlabMode' '0, 1, or 2' "defaults to $g_matlab_default_mode
0 = compiled MATLAB
1 = interpreted MATLAB  
2 = Octave" "$g_matlab_default_mode"

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

RegString=""
if [[ "$RegName" != "" ]]
then
    RegString="_$RegName"
fi

case "$MatlabMode" in
    (0)
        if [[ "${MATLAB_COMPILER_RUNTIME:-}" == "" ]]
        then
            log_Err_Abort "to use compiled matlab, you must set and export the variable MATLAB_COMPILER_RUNTIME"
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

IFS='@' read -a SubjList <<<"$SubjListRaw"
IFS='@' read -a fMRIList <<<"$fMRIListRaw"

#shortcut in case the folder gets renamed
this_script_dir=$(dirname "$0")

#matlab function arguments converted to strings
matlab_argarray=("$StudyFolder" "$SubjListRaw" "$fMRIListRaw" "$ConcatName" "$fMRIProcSTRING" "$OutputfMRIName" "$OutputSTRING" "$RegString" "$LowResMesh" "$TR" "$PFMFolder")

case "$MatlabMode" in
    (0)
        matlab_cmd=("$this_script_dir/Compiled_PostPROFUMO/run_PostPROFUMO.sh" "$MATLAB_COMPILER_RUNTIME" "${matlab_argarray[@]}")
        log_Msg "running compiled matlab command: ${matlab_cmd[*]}"
        "${matlab_cmd[@]}"
        ;;
    (1 | 2)
        #reformat argument array so matlab sees them as strings
        matlab_args=""
        for thisarg in "${matlab_argarray[@]}"
        do
            if [[ "$matlab_args" != "" ]]
            then
                matlab_args+=", "
            fi
            matlab_args+="'$thisarg'"
        done
        matlabcode="
            addpath('$HCPPIPEDIR/global/matlab');
            addpath('$this_script_dir');
            addpath('$HCPCIFTIRWDIR');
            PostPROFUMO($matlab_args);"

        log_Msg "running matlab code: $matlabcode"
        "${matlab_interpreter[@]}" <<<"$matlabcode"
        echo
        ;;
esac