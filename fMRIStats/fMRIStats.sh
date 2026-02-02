#!/bin/bash
set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"

g_matlab_default_mode=1

#this function gets called by opts_ParseArguments when --help is specified
function usage()
{
    #header text
    echo "
$log_ToolName: computes fMRI statistics including mTSNR, fCNR, and percent BOLD

Usage: $log_ToolName PARAMETER...

PARAMETERs are [ ] = optional; < > = user supplied vfalue
"
    #automatic argument descriptions
    opts_ShowArguments
    
    #do not use exit, the parsing code takes care of it
}

#arguments to opts_Add*: switch, variable to set, name for inside of <> in help text, description, [default value if AddOptional], [compatibility flag, ...]
opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects" '--path'
opts_AddMandatory '--subject' 'Subject' 'subject ID' "subject ID (e.g. 100610)"
opts_AddMandatory '--fmri-names' 'fMRINames' 'string' "@-separated list of fMRI run names (e.g. rfMRI_REST1_LR@rfMRI_REST2_LR)"
opts_AddMandatory '--high-pass' 'HighPass' 'string' "the high pass filter value used in ICA+FIX"
opts_AddOptional '--reg-name' 'RegName' 'string' "surface registration name, default 'NONE'" 'NONE'
opts_AddOptional '--process-volume' 'ProcessVolumeStr' 'TRUE or FALSE' "whether to process volume data, default 'false'" 'false'
opts_AddOptional '--cleanup-effects' 'CleanUpEffectsStr' 'TRUE or FALSE' "whether to compute cleanup effects metrics, default 'false'" 'false'
opts_AddOptional '--proc-string' 'ProcSTRING' 'string' "processing string suffix for cleaned data (only needed if --cleanup-effects=TRUE)" 'clean_rclean_tclean'
opts_AddOptional '--ica-mode' 'ICAmode' 'sICA or sICA+tICA' "ICA mode: 'sICA' for spatial ICA only, 'sICA+tICA' for combined spatial+temporal ICA, default 'sICA'" 'sICA'
opts_AddOptional '--tica-component-tcs' 'tICAcomponentTCS' 'path' "path to tICA timecourse CIFTI (required if --tica-mode=sICA+tICA)" ''
opts_AddOptional '--tica-component-text' 'tICAcomponentText' 'path' "path to tICA component signal indices text file (required if --tica-mode=sICA+tICA)" ''
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

# Verify required environment variables
log_Check_Env_Var CARET7DIR

Caret7_Command="${CARET7DIR}/wb_command"

# Parse boolean strings
ProcessVolume=$(opts_StringToBool "$ProcessVolumeStr")
CleanUpEffects=$(opts_StringToBool "$CleanUpEffectsStr")

# Set registration string
if [ "${RegName}" != "NONE" ] ; then
    RegString="_${RegName}"
else
    RegString=""
fi

# Warn if using tICA+sICA mode with cleanup effects but no tclean in processing string
if [[ "$ICAmode" == "sICA+tICA" ]] && [[ "$CleanUpEffects" == "1" ]]; then
    if [[ "$ProcSTRING" != *"tclean"* ]]; then
        log_Warn "Using tICA+sICA mode with CleanUpEffects=true, but ProcSTRING does not contain 'tclean'. Processing string is: '$ProcSTRING'"
    fi
fi

# Convert @ separated fMRI names to array
IFS='@' read -ra fMRINamesArray <<< "$fMRINames"

log_Msg "Processing subject ${Subject} with ${#fMRINamesArray[@]} run(s)"

# Check which runs exist for this subject
fMRIExist=()
for fMRIName in "${fMRINamesArray[@]}"
do
    fMRIFolder="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}"
    
    # Check if cleaned data exists
    if [[ -f "${fMRIFolder}/${fMRIName}_Atlas${RegString}_hp${HighPass}${ProcSTRING}.dtseries.nii" ]]
    then
        # Check if ICA folder and signal file exist
        if [[ -d "${fMRIFolder}/${fMRIName}_hp${HighPass}.ica" ]]
        then
            if [[ -f "${fMRIFolder}/${fMRIName}_hp${HighPass}.ica/HandSignal.txt" ]] || \
               [[ -f "${fMRIFolder}/${fMRIName}_hp${HighPass}.ica/Signal.txt" ]]
            then
                fMRIExist+=("${fMRIName}")
            else
                log_Warn "Skipping ${fMRIName}: Signal.txt not found"
            fi
        else
            log_Warn "Skipping ${fMRIName}: ICA folder not found"
        fi
    else
        log_Warn "Skipping ${fMRIName}: cleaned data not found"
    fi
done

# Skip subject if no runs are ready
if [ ${#fMRIExist[@]} -eq 0 ]
then
    log_Warn "No runs ready for ${Subject}, exiting"
    exit 0
fi

log_Msg "Processing ${#fMRIExist[@]} run(s) for ${Subject}"

# Process each ready run
for fMRIName in "${fMRIExist[@]}"
do
    log_Msg "Running fMRIStats on: ${fMRIName}"
    
    fMRIFolder="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}"
    
    MeanCIFTI="${fMRIFolder}/${fMRIName}_Atlas${RegString}_mean.dscalar.nii"
    MeanVolume="${fMRIFolder}/${fMRIName}_mean.nii.gz"
    
    # sICA files (only needed for sICA mode)
    if [[ "$ICAmode" == "sICA" ]]; then
        sICATCS="${fMRIFolder}/${fMRIName}_hp${HighPass}.ica/filtered_func_data.ica/melodic_mix.sdseries.nii"   
        if [ -e "${fMRIFolder}/${fMRIName}_hp${HighPass}.ica/HandSignal.txt" ] ; then
            Signal="${fMRIFolder}/${fMRIName}_hp${HighPass}.ica/HandSignal.txt"
        else
            Signal="${fMRIFolder}/${fMRIName}_hp${HighPass}.ica/Signal.txt"
        fi
    fi

    OrigCIFTITCS="${fMRIFolder}/${fMRIName}_Atlas${RegString}.dtseries.nii"
    OrigVolumeTCS="${fMRIFolder}/${fMRIName}.nii.gz"
    CleanedCIFTITCS="${fMRIFolder}/${fMRIName}_Atlas${RegString}_hp${HighPass}${ProcSTRING}.dtseries.nii"
    CleanedVolumeTCS="${fMRIFolder}/${fMRIName}_hp${HighPass}${ProcSTRING}.nii.gz"
    CIFTIOutput="${fMRIFolder}/${fMRIName}_Atlas${RegString}_hp${HighPass}${ProcSTRING}_fMRIStats.dscalar.nii"
    VolumeOutput="${fMRIFolder}/${fMRIName}_hp${HighPass}${ProcSTRING}_fMRIStats.nii.gz"
    # tICAcomponentTCS and tICAcomponentText are not constructed here becuase they are not necessaily programmatically named
    
    # Validate required input files exist
    if [ ! -e "${MeanCIFTI}" ]; then
        log_Err_Abort "Required file not found: ${MeanCIFTI}"
    fi
    if [[ "$ICAmode" == "sICA" ]]; then
        if [ ! -e "${sICATCS}" ]; then
            log_Err_Abort "Required file not found: ${sICATCS}"
        fi
        if [ ! -e "${Signal}" ]; then
            log_Err_Abort "Required file not found: ${Signal}"
        fi
    fi
    if [ ! -e "${CleanedCIFTITCS}" ]; then
        log_Err_Abort "Required file not found: ${CleanedCIFTITCS}"
    fi
    
    case "$MatlabMode" in
        (0)
            if [[ "${MATLAB_COMPILER_RUNTIME:-}" == "" ]]
            then
                log_Err_Abort "To use compiled matlab, you must set and export the variable MATLAB_COMPILER_RUNTIME"
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
    
    #matlab function arguments - build name-value pairs for optional args
    # Required positional arguments
    matlab_positional=("$MeanCIFTI" "$CleanedCIFTITCS" "$CIFTIOutput")
    
    # Build name-value pairs for optional arguments
    matlab_opts=()
    matlab_opts+=("ProcessVolume" "$ProcessVolume")
    matlab_opts+=("CleanUpEffects" "$CleanUpEffects")
    matlab_opts+=("ICAmode" "$ICAmode")
    matlab_opts+=("Caret7_Command" "$Caret7_Command")
    
    # Add sICA arguments if in sICA mode
    if [[ "$ICAmode" == "sICA" ]]; then
        matlab_opts+=("sICATCS" "$sICATCS")
        matlab_opts+=("Signal" "$Signal")
    fi
    
    # Add conditionally required arguments based on flags
    if [[ "$CleanUpEffects" == "1" ]]; then
        matlab_opts+=("OrigCIFTITCS" "$OrigCIFTITCS")
    fi
    
    if [[ "$ProcessVolume" == "1" ]]; then
        matlab_opts+=("MeanVolume" "$MeanVolume")
        matlab_opts+=("CleanedVolumeTCS" "$CleanedVolumeTCS")
        matlab_opts+=("VolumeOutputName" "$VolumeOutput")
        
        if [[ "$CleanUpEffects" == "1" ]]; then
            matlab_opts+=("OrigVolumeTCS" "$OrigVolumeTCS")
        fi
    fi
    
    # Add tICA arguments if in sICA+tICA mode
    if [[ "$ICAmode" == "sICA+tICA" ]]; then
        matlab_opts+=("tICAcomponentTCS" "$tICAcomponentTCS")
        matlab_opts+=("tICAcomponentText" "$tICAcomponentText")
    fi
    
    #shortcut in case the folder gets renamed
    this_script_dir=$(dirname "$0")
    
    case "$MatlabMode" in
        (0)
            # For compiled MATLAB, pass all args (positional + name-value pairs flattened)
            matlab_cmd=("$this_script_dir/Compiled_fMRIStats/run_fMRIStats.sh" "$MATLAB_COMPILER_RUNTIME" "${matlab_positional[@]}" "${matlab_opts[@]}")
            log_Msg "running compiled matlab command: ${matlab_cmd[*]}"
            "${matlab_cmd[@]}"
            ;;
        (1 | 2)
            #reformat positional arguments
            matlab_args=""
            for thisarg in "${matlab_positional[@]}"
            do
                if [[ "$matlab_args" != "" ]]
                then
                    matlab_args+=", "
                fi
                matlab_args+="'$thisarg'"
            done
            
            #add name-value pairs
            for ((i=0; i<${#matlab_opts[@]}; i+=2))
            do
                matlab_args+=", '${matlab_opts[i]}', '${matlab_opts[i+1]}'"
            done
            
            matlabcode="
                addpath('$HCPPIPEDIR/fMRIStats/scripts');
                fMRIStats($matlab_args);"
            
            log_Msg "running matlab code: $matlabcode"
            "${matlab_interpreter[@]}" <<<"$matlabcode"
            echo
            ;;
    esac
    
    log_Msg "Completed: ${fMRIName}"
done

log_Msg "fMRIStats processing complete for subject ${Subject}"