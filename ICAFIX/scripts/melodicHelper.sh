#!/bin/bash
set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/parallel.shlib" "$@"

opts_SetScriptDescription "runs independent melodics in parallel for the purpose of melodicicasso.m"

opts_AddMandatory '--inputs' 'inputs' 'input@input@input...' "input files for the melodic runs"
opts_AddMandatory '--output-folders' 'outputs' 'dir@dir@dir...' "output folders for the melodic runs"
opts_AddMandatory '--dim' 'dim' 'int' "melodic dimensionality"
opts_AddMandatory '--brain-mask' 'mask' 'file' "brain mask"
opts_AddOptional '--seeds' 'seeds' 'seed@seed@seed...' "input seeds for the melodic runs"
opts_AddOptional '--initializations' 'inits' 'file@file@file...' "initialization files for the melodic runs"
opts_AddOptional '--log-dir' 'logDir' 'path' "folder to put logs into"
opts_AddOptional '--num-parallel' 'numpar' "how many melodics to run in parallel, default to all physical cores" '-1'

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

opts_ShowValues

if [[ "$seeds" == "" && "$inits" == "" ]]
then
    log_Err_Abort "you must specify either --seeds or --initializations"
fi

IFS='@' read -a inputArray <<<"$inputs"
IFS='@' read -a outputArray <<<"$outputs"

if ((${#outputArray[@]} != ${#inputArray[@]}))
then
    log_Err_Abort "--inputs and --output-folders need to have the same number of items"
fi

if [[ "$seeds" == "" ]]
then
    IFS='@' read -a initArray <<<"$inits"
    if ((${#initArray[@]} != ${#inputArray[@]}))
    then
        log_Err_Abort "--initializations and --inputs need to have the same number of items"
    fi
else
    IFS='@' read -a seedArray <<<"$seeds"
    if ((${#seedArray[@]} != ${#inputArray[@]}))
    then
        log_Err_Abort "--initializations and --inputs need to have the same number of items"
    fi
fi

if [[ "$logDir" != "" ]]
then
    par_set_log_dir "$logDir"
fi

for ((i = 0; i < ${#inputArray[@]}; ++i))
do
    if [[ "$seeds" == "" ]]
    then
        par_addjob melodic -i "${inputArray[i]}" -o "${outputArray[i]}" --nobet --vn --dim="$dim" --no_mm --init_ica="${initArray[i]}" -m "$mask" -v --debug
    else
        par_addjob melodic -i "${inputArray[i]}" -o "${outputArray[i]}" --nobet --vn --dim="$dim" --no_mm --seed="${seedArray[i]}" -m "$mask" -v --debug
    fi
done

par_runjobs "$numpar"

