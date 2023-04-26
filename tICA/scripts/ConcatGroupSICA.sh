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
opts_AddMandatory '--subject-list' 'SubjlistRaw' '100206@100307...' 'list of subject IDs separated by @s'
#FIXME: when full script is ready, make calling script set the naming conventions for outputs
opts_AddMandatory '--out-folder' 'OutGroupFolder' 'path' "group average folder"
opts_AddMandatory '--fmri-concat-name' 'fMRIConcatName' 'string' "name for the concatenated data, like 'rfMRI_REST_7T'"
opts_AddMandatory '--surf-reg-name' 'RegName' 'name' "the surface registration string"
opts_AddMandatory '--ica-dim' 'sICAdim' 'integer' "number of ICA components"
opts_AddMandatory '--subject-expected-timepoints' 'RunsXNumTimePoints' 'integer' "number of concatenated timepoints in a subject with full data"
opts_AddMandatory '--low-res-mesh' 'LowResMesh' 'integer' "mesh resolution, like '32'"
opts_AddMandatory '--sica-proc-string' 'sICAProcString' 'string' "specifier for data and parameters used, like 'tfMRI_RET_7T_d73_WF5_WR'"
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

#FIXME: hardcoded naming conventions, move these to high level script when ready
InputStats="$OutGroupFolder/MNINonLinear/Results/$fMRIConcatName/sICA/iq_$sICAdim.wb_annsub.csv"

OutputFolder="$OutGroupFolder/MNINonLinear/Results/$fMRIConcatName/tICA_d$sICAdim"

OutTCSName="$OutputFolder/sICA_TCS_$sICAdim.sdseries.nii"
OutTCSMaskName="$OutputFolder/sICA_TCSMASK_$sICAdim.sdseries.nii"
OutAvgTCSName="$OutputFolder/sICA_AVGTCS_$sICAdim.sdseries.nii"
OutAbsAvgTCSName="$OutputFolder/sICA_ABSAVGTCS_$sICAdim.sdseries.nii"
OutAvgSpectraName="$OutputFolder/sICA_Spectra_$sICAdim.sdseries.nii"

OutAnnsubName="$OutputFolder/sICA_stats_$sICAdim.wb_annsub.csv"

OutAvgMapsName="$OutputFolder/sICA_Maps_$sICAdim.dscalar.nii"
OutAvgVolMapsName="$OutputFolder/sICA_VolMaps_$sICAdim.dscalar.nii"

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

mkdir -p "$OutputFolder"

IFS='@' read -a SubjList <<<"$SubjlistRaw"

TCSListName="$OutputFolder/TCSList.txt"
MapListName="$OutputFolder/MapList.txt"
VolMapListName="$OutputFolder/VolMapList.txt"
SpectraListName="$OutputFolder/SpectraList.txt"

tempfiles_add "$TCSListName" "$MapListName" "$VolMapListName" "$SpectraListName"

rm -f -- "$TCSListName" "$MapListName" "$VolMapListName" "$SpectraListName"

for Subject in "${SubjList[@]}"
do
    FilePrefix="$StudyFolder/$Subject/MNINonLinear/fsaverage_LR${LowResMesh}k/$Subject.${sICAProcString}${RegString}"
    echo "${FilePrefix}_ts.${LowResMesh}k_fs_LR.sdseries.nii" >> "$TCSListName"
    echo "${FilePrefix}.${LowResMesh}k_fs_LR.dscalar.nii" >> "$MapListName"
    echo "${FilePrefix}_vol.${LowResMesh}k_fs_LR.dscalar.nii" >> "$VolMapListName"
    echo "${FilePrefix}_spectra.${LowResMesh}k_fs_LR.sdseries.nii" >> "$SpectraListName"
done

#shortcut in case the folder gets renamed
this_script_dir=$(dirname "$0")

#matlab function arguments have been changed to strings, to avoid having two copies of the argument list in the script
matlab_argarray=("$TCSListName" "$MapListName" "$VolMapListName" "$SpectraListName" "$InputStats" "$sICAdim" "$RunsXNumTimePoints" "$OutTCSName" "$OutTCSMaskName" "$OutAnnsubName" "$OutAvgTCSName" "$OutAbsAvgTCSName" "$OutAvgSpectraName" "$OutAvgMapsName" "$OutAvgVolMapsName")

case "$MatlabMode" in
    (0)
        matlab_cmd=("$this_script_dir/Compiled_ConcatGroupSICA/run_ConcatGroupSICA.sh" "$MATLAB_COMPILER_RUNTIME" "${matlab_argarray[@]}")
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
            addpath('$HCPPIPEDIR/tICA/scripts/icasso122');
            addpath('$HCPPIPEDIR/tICA/scripts/FastICA_25');
            addpath('$HCPPIPEDIR/tICA/scripts');
            addpath('$HCPCIFTIRWDIR');
            ConcatGroupSICA($matlab_args);"

        log_Msg "running matlab code: $matlabcode"
        "${matlab_interpreter[@]}" <<<"$matlabcode"
        echo
        ;;
esac

