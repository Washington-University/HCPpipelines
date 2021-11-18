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
opts_AddMandatory '--data' 'indata' 'file' "the input dtseries"
opts_AddMandatory '--vn-file' 'invn' 'file' "the variance normalization dscalar"
opts_AddMandatory '--out-folder' 'outfolder' 'path' "where to write the outputs"
opts_AddMandatory '--num-wishart' 'numWisharts' 'integer' "how many wisharts to use in icaDim"
opts_AddMandatory '--wf-out-name' 'wfoutname' 'file' "output name for wishart-filtered data"
opts_AddOptional '--icadim-iters' 'icadimIters' 'integer' "number of iterations or mode for icaDim(), default 100" '100'
opts_AddOptional '--process-dims' 'dimListRaw' 'num@num@num...' "process at these dimensionalities in addition to icaDim's estimate"
opts_AddOptional '--icadim-override' 'icadimOverride' 'integer' "use this dimensionality instead of icaDim's estimate"
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

if [[ "$icadimOverride" == "" ]]
then
    icadimOverride='-1'
else
    if (( icadimOverride < 1 ))
    then
        log_Err_Abort "--icadim-override must be a positive integer"
    fi
fi

IFS='@' read -a dimList <<<"$dimListRaw"

case "$MatlabMode" in
    (0)
        if [[ "${MATLAB_COMPILER_RUNTIME:-}" == "" ]]
        then
            log_Err_Abort "to use compiled matlab, you must set and export the variable MATLAB_COMPILER_RUNTIME"
        fi
        ;;
    (1)
        #NOTE: figure() is required by the spectra option, and -nojvm prevents using figure()
        matlab_interpreter=(matlab -nodisplay -nosplash)
        ;;
    (2)
        matlab_interpreter=(octave-cli -q --no-window-system)
        ;;
    (*)
        log_Err_Abort "unrecognized matlab mode '$MatlabMode', use 0, 1, or 2"
        ;;
esac

#shortcut in case the folder gets renamed
this_script_dir=$(dirname "$0")

#matlab function arguments have been changed to strings, to avoid having two copies of the argument list in the script
#dimList can validly be empty, which in older bash needs the below incantation under 'set -eu'
#yes, "" nests inside ${}
matlab_argarray=("$indata" "$invn" "$outfolder" "$wfoutname" "$numWisharts" "${dimList[*]+"${dimList[*]}"}" "$icadimIters" "$icadimOverride")

case "$MatlabMode" in
    (0)
        matlab_cmd=("$this_script_dir/Compiled_GroupSICA/run_GroupSICA.sh" "$MATLAB_COMPILER_RUNTIME" "${matlab_argarray[@]}")
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
            addpath('$HCPPIPEDIR/global/matlab/icaDim');
            addpath('$HCPPIPEDIR/global/matlab');
            addpath('$this_script_dir/icasso122');
            addpath('$this_script_dir/FastICA_25');
            addpath('$this_script_dir');
            addpath('$HCPCIFTIRWDIR');
            GroupSICA($matlab_args);"

        log_Msg "running matlab code: $matlabcode"
        "${matlab_interpreter[@]}" <<<"$matlabcode"
        echo
        ;;
esac

actualDim=$(cat "$outfolder/most_recent_dim.txt")
if [[ ! -f "$outfolder/melodic_oIC_$actualDim.dscalar.nii" || ! -f "$outfolder/melodic_oIC_${actualDim}_norm.dscalar.nii" ]]
then
    log_Err_Abort "GroupSICA did not produce expected output, check above for errors from matlab"
fi

