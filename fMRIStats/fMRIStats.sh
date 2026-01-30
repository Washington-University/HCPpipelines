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

PARAMETERs are [ ] = optional; < > = user supplied value
"
    #automatic argument descriptions
    opts_ShowArguments
    
    #do not use exit, the parsing code takes care of it
}

#arguments to opts_Add*: switch, variable to set, name for inside of <> in help text, description, [default value if AddOptional], [compatibility flag, ...]
opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects" '--path'
opts_AddMandatory '--subjlist' 'Subjlist' 'subject IDs' "@-separated list of subject IDs (e.g. 100610@102311)" '--subject-list' '--subject'
opts_AddMandatory '--fmri-names' 'fMRINames' 'string' "@-separated list of fMRI run names (e.g. rfMRI_REST1_LR@rfMRI_REST2_LR)" '--fmri-name'
opts_AddMandatory '--high-pass' 'HighPass' 'integer' "the high pass filter value used in ICA+FIX"
opts_AddMandatory '--proc-string' 'ProcSTRING' 'string' "processing string suffix for cleaned data (e.g. _hp2000_clean)"
opts_AddOptional '--reg-name' 'RegName' 'string' "surface registration name, default 'NONE'" 'NONE'
opts_AddOptional '--process-volume' 'ProcessVolumeStr' 'TRUE or FALSE' "whether to process volume data, default 'false'" 'false'
opts_AddOptional '--cleanup-effects' 'CleanUpEffectsStr' 'TRUE or FALSE' "whether to compute cleanup effects metrics, default 'false'" 'false'
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
ProcessVolume=$(opts_StringToBool "$ProcessVolumeStr")
CleanUpEffects=$(opts_StringToBool "$CleanUpEffectsStr")

IFS='@' read -ra SubjectArray <<< "$Subjlist"
IFS='@' read -ra fMRINamesArray <<< "$fMRINames"

if [ "${RegName}" != "NONE" ] ; then
	RegString="_${RegName}"
else
	RegString=""
fi
for Subject in "${SubjectArray[@]}"
do
    log_Msg "Processing subject: ${Subject}"
    
    # Check which runs exist for this subject
    fMRIExist=()
    for fMRIName in "${fMRINamesArray[@]}"
    do
        fMRIFolder="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}"
        
        # Check if cleaned data exists
        if [[ -f "${fMRIFolder}/${fMRIName}_Atlas${RegString}${ProcSTRING}.dtseries.nii" ]]
        then
            # Check if ICA folder and signal file exist
            if [[ -d "${fMRIFolder}/${fMRIName}_hp${HighPass}.ica" ]]
            then
                if [[ -f "${fMRIFolder}/${fMRIName}_hp${HighPass}.ica/HandSignal.txt" ]] || \
                   [[ -f "${fMRIFolder}/${fMRIName}_hp${HighPass}.ica/Signal.txt" ]]
                then
                    fMRIExist+=("${fMRIName}")
                else
                    log_Warn "Skipping ${Subject} ${fMRIName}: Signal.txt not found"
                fi
            else
                log_Warn "Skipping ${Subject} ${fMRIName}: ICA folder not found"
            fi
        else
            log_Warn "Skipping ${Subject} ${fMRIName}: cleaned data not found"
        fi
    done
    
    # Skip subject if no runs are ready
    if [ ${#fMRIExist[@]} -eq 0 ]
    then
        log_Warn "No runs ready for ${Subject}, skipping subject"
        continue
    fi
        
    # Process each ready run
    for fMRIName in "${fMRIExist[@]}"
    do
        log_Msg "Running fMRIStats on: ${Subject}/${fMRIName}"
        
        fMRIFolder="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}"
        
        MeanCIFTI="${fMRIFolder}/${fMRIName}_Atlas${RegString}_mean.dscalar.nii"
        MeanVolume="${fMRIFolder}/${fMRIName}_mean.nii.gz"
        sICATCS="${fMRIFolder}/${fMRIName}_hp${HighPass}.ica/filtered_func_data.ica/melodic_mix.sdseries.nii"
        
        if [ -e "${fMRIFolder}/${fMRIName}_hp${HighPass}.ica/HandSignal.txt" ] ; then
            Signal="${fMRIFolder}/${fMRIName}_hp${HighPass}.ica/HandSignal.txt"
        else
            Signal="${fMRIFolder}/${fMRIName}_hp${HighPass}.ica/Signal.txt"
        fi
        
        OrigCIFTITCS="${fMRIFolder}/${fMRIName}_Atlas${RegString}.dtseries.nii"
        OrigVolumeTCS="${fMRIFolder}/${fMRIName}.nii.gz"
        CleanedCIFTITCS="${fMRIFolder}/${fMRIName}_Atlas${RegString}${ProcSTRING}.dtseries.nii"
        CleanedVolumeTCS="${fMRIFolder}/${fMRIName}${ProcSTRING}.nii.gz"
        CIFTIOutput="${fMRIFolder}/${fMRIName}_Atlas${RegString}${ProcSTRING}_fMRIStats.dscalar.nii"
        VolumeOutput="${fMRIFolder}/${fMRIName}${ProcSTRING}_fMRIStats.nii.gz"
        
        # Validate required input files exist
        if [ ! -e "${MeanCIFTI}" ]; then
            log_Err_Abort "Required file not found: ${MeanCIFTI}"
        fi
        if [ ! -e "${sICATCS}" ]; then
            log_Err_Abort "Required file not found: ${sICATCS}"
        fi
        if [ ! -e "${Signal}" ]; then
            log_Err_Abort "Required file not found: ${Signal}"
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
                log_Err_Abort "Compiled MATLAB mode not yet implemented for this script"
                ;;
            (1)
                matlab -nodisplay -nosplash <<M_PROG
addpath('${HCPPIPEDIR}/fMRIStats/scripts'); fMRIStats('${MeanCIFTI}','${MeanVolume}','${sICATCS}','${Signal}','${OrigCIFTITCS}','${OrigVolumeTCS}','${CleanedCIFTITCS}','${CleanedVolumeTCS}','${CIFTIOutput}','${VolumeOutput}','${CleanUpEffects}','${ProcessVolume}','${Caret7_Command}');
M_PROG
                ;;
            (2)
                octave-cli -q --eval "addpath('${HCPPIPEDIR}/fMRIStats/scripts'); fMRIStats('${MeanCIFTI}','${MeanVolume}','${sICATCS}','${Signal}','${OrigCIFTITCS}','${OrigVolumeTCS}','${CleanedCIFTITCS}','${CleanedVolumeTCS}','${CIFTIOutput}','${VolumeOutput}','${CleanUpEffects}','${ProcessVolume}','${Caret7_Command}');"
                ;;
            (*)
                log_Err_Abort "Unsupported MATLAB run mode: $MatlabMode"
                ;;
        esac
        
        log_Msg "Completed: ${Subject} - ${fMRIName}"
    done
    
done

