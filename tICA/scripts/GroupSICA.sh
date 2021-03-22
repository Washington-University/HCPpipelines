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
#FIXME: no compiled matlab support
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
#opts_AddMandatory '--wf-out-name' 'wfoutname' 'file' "output name for wishart-filtered data" #FIXME - move naming conventions to high-level script when ready
opts_AddOptional '--icadim-iters' 'icadimIters' 'integer' "number of iterations or mode for icaDim(), default 100" '100'
opts_AddOptional '--process-dims' 'dimListRaw' 'num@num@num...' "process at these dimensionalities in addition to icaDim's estimate"
opts_AddOptional '--icadim-override' 'icadimOverride' 'integer' "use this dimensionality instead of icaDim's estimate" '-1'
opts_AddOptional '--matlab-run-mode' 'MatlabMode' '0, 1, or 2' "defaults to $g_matlab_default_mode
0 = compiled MATLAB (not implemented)
1 = interpreted MATLAB
2 = Octave" "$g_matlab_default_mode"
opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

#FIXME: move to high level script when ready
inputbase="${indata%.dtseries.nii}"
wfoutname="$inputbase"_WF"$numWisharts".dtseries.nii

IFS='@' read -a dimList <<<"$dimListRaw"

case "$MatlabMode" in
    (0)
        log_Err_Abort "FIXME: compiled matlab support not yet implemented"
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

#dimList can validly be empty, which in older bash needs the below incantation under 'set -eu'
#yes, "" nests inside ${}
matlabcode="
    addpath('$HCPPIPEDIR/global/matlab/icaDim');
    addpath('$HCPPIPEDIR/global/matlab');
    addpath('$HCPPIPEDIR/tICA/scripts/icasso122');
    addpath('$HCPPIPEDIR/tICA/scripts/FastICA_25');
    addpath('$HCPPIPEDIR/tICA/scripts');
    addpath('$HCPCIFTIRWDIR');
    GroupSICA('$indata', '$invn', '$outfolder', '$wfoutname', $numWisharts, [${dimList[*]+"${dimList[*]}"}], $icadimIters, $icadimOverride);"

log_Msg "running matlab code: $matlabcode"
"${matlab_interpreter[@]}" <<<"$matlabcode"

