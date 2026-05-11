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
g_matlab_default_mode=1

opts_SetScriptDescription "applies Wishart filter to CIFTI dtseries files for PROFUMO"

opts_AddMandatory '--input' 'inputFile' 'file' "comma-separated list of input dtseries files"
opts_AddMandatory '--output' 'outputFile' 'file' "comma-separated list of output wishart-filtered dtseries files"
opts_AddMandatory '--num-wishart' 'numWisharts' 'integer' "number of Wishart distributions to fit"
opts_AddMandatory '--pfm-dimension' 'PFMdim' 'integer' "PFM dimensionality (e.g., 76, 92, 65)"
opts_AddOptional '--matlab-run-mode' 'MatlabMode' '0, 1, or 2' "defaults to $g_matlab_default_mode

0 = compiled MATLAB
1 = interpreted MATLAB
2 = Octave" "$g_matlab_default_mode"

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

opts_ShowValues

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

this_script_dir=$(dirname "$0")

matlab_argarray=("$inputFile" "$outputFile" "$numWisharts" "$PFMdim")

case "$MatlabMode" in
    (0)
        matlab_cmd=("$this_script_dir/Compiled_WishartFilter/run_WishartFilter.sh" "$MATLAB_COMPILER_RUNTIME" "${matlab_argarray[@]}")
        log_Msg "running compiled matlab command: ${matlab_cmd[*]}"
        "${matlab_cmd[@]}"
        ;;
    (1 | 2)
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
            addpath('$HCPPIPEDIR/global/matlab/icaDim');
            addpath('$HCPPIPEDIR/global/matlab');
            addpath('$this_script_dir');
            addpath('$HCPCIFTIRWDIR');
            WishartFilter($matlab_args);"

        log_Msg "running matlab code: $matlabcode"
        "${matlab_interpreter[@]}" <<<"$matlabcode"
        echo
        ;;
esac