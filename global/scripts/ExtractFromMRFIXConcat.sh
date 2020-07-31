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

#this function gets called by opts_ParseArguments when --help is specified
function usage()
{
    #header text
    echo "
$log_ToolName: extract a specified set of runs from an MR FIX
    concatenated file and reconcatenate them.  Typically this is used to extract
    the resting state runs from a combined task and resting state MR FIX run.

Usage: $log_ToolName PARAMETER...

PARAMETERs are [ ] = optional; < > = user supplied value
"
    #automatic argument descriptions
    opts_ShowArguments
    
    #do not use exit, the parsing code takes care of it
}

#arguments to opts_Add*: switch, variable to set, name for inside of <> in help text, description, [default value if AddOptional], [compatibility flag, ...]
#help info for option gets printed like "--foo=<$3> - $4"
#we query several cifti files for their length, so I guess we can hardcode naming conventions for that
opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject' 'Subject' 'ID' "the subject ID"
opts_AddMandatory '--multirun-fix-names' 'mrfixNames' 'run1@run2...' "list of run names used in MR FIX, in the SAME ORDER, separated by @s"
opts_AddOptional '--multirun-fix-names-to-use' 'mrfixNamesToUse' 'rest1@rest2...' "list of runs to extract (for cifti or volume outputs)"
opts_AddOptional '--surf-reg-name' 'RegName' 'string' "registration name for which cifti files to get the number of timepoints per run from"
opts_AddOptional '--concat-cifti-input' 'concatCifti' 'file' "filename of the concatenated cifti (for making cifti output)"
opts_AddOptional '--cifti-out' 'ciftiOut' 'file' "output filename for extracted cifti data"
opts_AddOptional '--concat-volume-input' 'concatVol' 'file' "filename of the concatenated volume (for making volume output)"
opts_AddOptional '--volume-out' 'volOut' 'file' "output filename for extracted volume data"
opts_AddOptional '--csv-out' 'csvOut' 'file' "output filename for csv of start and end index for all run names"
opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

if [[ -z "$ciftiOut" && -z "$volOut" && -z "$csvOut" ]]
then
    log_Err_Abort "no outputs options were specified (use one or more of --cifti-out, --volume-out, or --csv-out)"
fi

if [[ -n "$ciftiOut" && (-z "$concatCifti" || -z "$mrfixNamesToUse") ]]
then
    log_Err_Abort "using --cifti-out requires specifying --concat-cifti-input and --multirun-fix-names-to-use"
fi

if [[ -n "$volOut" && (-z "$concatVol" || -z "$mrfixNamesToUse") ]]
then
    log_Err_Abort "using --volume-out requires specifying --concat-volume-input and --multirun-fix-names-to-use"
fi

doMerge=0
if [[ -n "$ciftiOut" || -n "$volOut" ]]
then
    doMerge=1
    IFS=@ read -a mrNamesUseArray <<< "$mrfixNamesToUse"
fi

#naming convention quirk for MSMSulc
if [[ "$RegName" == "MSMSulc" ]]
then
    RegName=""
fi

RegString=""
if [[ -n "$RegName" ]]
then
    RegString="_$RegName"
fi

IFS=@ read -a mrNamesArray <<< "$mrfixNames"
#sanity check for identical names
for ((index = 0; index < ${#mrNamesArray[@]}; ++index))
do
    for ((index2 = index + 1; index2 < ${#mrNamesArray[@]}; ++index2))
    do
        if [[ "${mrNamesArray[$index]}" == "${mrNamesArray[$index2]}" ]]
        then
            log_Err_Abort "MR fix names list contains '${mrNamesArray[$index]}' more than once"
        fi
    done
done

#sanity check for bad names in --multirun-fix-names-to-use
runIndices=()
if ((doMerge))
then
    for ((index2 = 0; index2 < ${#mrNamesUseArray[@]}; ++index2))
    do
        found=0
        for ((index = 0; index < ${#mrNamesArray[@]}; ++index))
        do
            if [[ "${mrNamesUseArray[$index2]}" == "${mrNamesArray[$index]}" ]]
            then
                runIndices[$index2]="$index"
                found=1
                break
            fi
        done
        if ((!found))
        then
            log_Err_Abort "fMRI name '${mrNamesUseArray[$index2]}' in --multirun-fix-names-to-use was not found in --multirun-fix-names"
        fi
    done
fi

testVol=0
if [[ -n "$volOut" && -z "$ciftiOut" ]]
then
    testVol=1
fi

if [[ -n "$csvOut" ]]
then
    rm -f -- "$csvOut"
fi

runSplits=()
curTimepoints=0
#convention: one before the first (1-based) index of the run
runSplits[0]="$curTimepoints"
#calculate the timepoints where the concatenated switches runs, find which runs are used
for ((index = 0; index < ${#mrNamesArray[@]}; ++index))
do
    fmriName="${mrNamesArray[$index]}"
    NumTPs=0
    if ((testVol))
    then
        if [[ ! -f "$StudyFolder/$Subject/MNINonLinear/Results/$fmriName/${fmriName}.nii.gz" ]]
        then
            log_Msg "missing run: '$StudyFolder/$Subject/MNINonLinear/Results/$fmriName/${fmriName}.nii.gz'"
        else
            NumTPs=$(fslval "$StudyFolder/$Subject/MNINonLinear/Results/$fmriName/${fmriName}.nii.gz" dim4)
        fi
    else
        if [[ ! -f "$StudyFolder/$Subject/MNINonLinear/Results/$fmriName/${fmriName}_Atlas$RegString.dtseries.nii" ]]
        then
            log_Msg "missing run: '$StudyFolder/$Subject/MNINonLinear/Results/$fmriName/${fmriName}_Atlas$RegString.dtseries.nii'"
        else
            NumTPs=$(wb_command -file-information "$StudyFolder/$Subject/MNINonLinear/Results/$fmriName/${fmriName}_Atlas$RegString.dtseries.nii" -only-number-of-maps)
        fi
    fi
    curTimepoints=$((curTimepoints + NumTPs))
    runSplits[$((index + 1))]="$curTimepoints"
    if [[ -n "$csvOut" ]] && ((NumTPs != 0))
    then
        echo "$fmriName,$((runSplits[index] + 1)),$((runSplits[index + 1]))" >> "$csvOut"
    fi
done

if ((doMerge))
then
    #check that we found all requested runs, build the merge command
    mergeArgs=()
    volMergeArgs=()
    for ((index2 = 0; index2 < ${#mrNamesUseArray[@]}; ++index2))
    do
        #element may be unset
        runIndex="${runIndices[$index2]+"${runIndices[$index2]}"}"
        if [[ "$runIndex" == "" ]]
        then
            log_Msg "requested run '${mrNamesUseArray[$index2]}' not found"
            continue
        fi
        #missing runs will have start and end equal
        if ((runSplits[runIndex] != runSplits[runIndex + 1]))
        then
            mergeArgs+=(-column $((runSplits[runIndex] + 1)) -up-to $((runSplits[runIndex + 1])) )
            volMergeArgs+=(-subvolume $((runSplits[runIndex] + 1)) -up-to $((runSplits[runIndex + 1])) )
        fi
    done
    
    if ((${#mergeArgs[@]} == 0))
    then
        log_Err_Abort "no requested runs found in this subject (do you need to use --surf-reg-name?)"
    fi

    if [[ -n "$ciftiOut" ]]
    then
        wb_command -cifti-merge "$ciftiOut" -cifti "$concatCifti" "${mergeArgs[@]}"
    fi
    
    if [[ -n "$volOut" ]]
    then
        wb_command -volume-merge "$volOut" -volume "$concatVol" "${volMergeArgs[@]}"
    fi
fi

