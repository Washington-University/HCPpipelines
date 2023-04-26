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
opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject-list' 'Subjlist' '100206@100307...' 'list of subject IDs separated by @s'
opts_AddMandatory '--fmri-names' 'fMRINames' 'rfMRI_REST1_LR@rfMRI_REST1_RL...' 'list of fmri run names separated by @s'
opts_AddMandatory '--out-fmri-name' 'OutputfMRIName' 'name' 'name component to use for outputs'
opts_AddMandatory '--proc-string' 'fMRIProcSTRING' 'string' 'name component used while preprocessing inputs'
#maybe make this the absolute group folder path?
opts_AddMandatory '--out-group-name' 'GroupAverageName' 'string' 'name to use for the output folder'
opts_AddMandatory '--pca-internal-dim' 'PCAInternalDim' 'integer' 'internal MIGP dimensionality'
opts_AddMandatory '--pca-out-dim' 'PCAOutputDim' 'integer' 'number of components to output'
opts_AddOptional '--resumable' 'checkpointFile' 'filename' 'file to use to save and resume interrupted processing, must use .mat extension'
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

#matlab load() and save() look around for file extensions, while movefile() doesn't
#so have the script require .mat for predictability
if [[ "$checkpointFile" != "" && "$checkpointFile" != *.mat ]]
then
    log_Err_Abort "argument to --resumable must end in .mat"
fi

#Naming Conventions
CommonAtlasFolder="$StudyFolder/$GroupAverageName/MNINonLinear"
OutputFolder="$CommonAtlasFolder/Results/$OutputfMRIName"

OutputPCA="$OutputFolder/${OutputfMRIName}${fMRIProcSTRING}"

mkdir -p "$OutputFolder"

tempfiles_add "$OutputFolder/${OutputfMRIName}${fMRIProcSTRING}.txt"
echo "$Subjlist" | tr @ '\n' > "$OutputFolder/${OutputfMRIName}${fMRIProcSTRING}.txt"

#don't get fooled into thinking the run was fine if the output existed before we ran the matlab
rm -f "${OutputPCA}_PCA.dtseries.nii" "${OutputPCA}_meanvn.dscalar.nii"

#shortcut in case the folder gets renamed
this_script_dir=$(dirname "$0")

#matlab function arguments have been changed to strings, to avoid having two copies of the argument list in the script
matlab_argarray=("$StudyFolder" "$OutputFolder/${OutputfMRIName}${fMRIProcSTRING}.txt" "$fMRINames" "$fMRIProcSTRING" "$PCAInternalDim" "$PCAOutputDim" "$OutputPCA" "$checkpointFile")

case "$MatlabMode" in
    (0)
        matlab_cmd=("$this_script_dir/Compiled_MIGP/run_MIGP.sh" "$MATLAB_COMPILER_RUNTIME" "${matlab_argarray[@]}")
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
        mlcode="
            addpath('$HCPPIPEDIR/global/matlab');
            addpath('$this_script_dir');
            addpath('$HCPCIFTIRWDIR');
            MIGP($matlab_args);"

        log_Msg "running matlab code: $mlcode"
        "${matlab_interpreter[@]}" <<<"$mlcode"
        echo
        ;;
esac

if [[ ! -f "${OutputPCA}_PCA.dtseries.nii" || ! -f "${OutputPCA}_meanvn.dscalar.nii" ]]
then
    log_Err_Abort "MIGP did not produce expected output, check above for errors from matlab"
fi

