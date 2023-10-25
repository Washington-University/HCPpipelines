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
opts_AddMandatory '--subject-list' 'SubjListRaw' '100206@100307...' 'list of subject IDs separated by @s'
opts_AddMandatory '--fmri-list' 'fMRIListRaw' 'rfMRI_REST1_RL@rfMRI_REST1_LR...' 'list of runs used in sICA, in the SAME ORDER, separated by @s'
#FIXME: when full script is ready, make calling script set the naming conventions for outputs
opts_AddMandatory '--out-folder' 'OutGroupFolder' 'path' "group average folder"
opts_AddMandatory '--fmri-concat-name' 'fMRIConcatName' 'string' "name for the concatenated data, like 'rfMRI_REST_7T'"
opts_AddMandatory '--surf-reg-name' 'RegName' 'name' "the surface registration string"
opts_AddMandatory '--ica-dim' 'sICAdim' 'integer' "number of ICA components"
opts_AddMandatory '--subject-expected-timepoints' 'RunsXNumTimePoints' 'integer' "number of concatenated timepoints in a subject with full data"
opts_AddMandatory '--low-res-mesh' 'LowResMesh' 'integer' "mesh resolution, like '32'"
opts_AddMandatory '--sica-proc-string' 'sICAProcString' 'string' "name part to use for some outputs, like 'tfMRI_RET_7T_d73_WF5_WR'"
opts_AddOptional '--matlab-run-mode' 'MatlabMode' '0, 1, or 2' "defaults to $g_matlab_default_mode

0 = compiled MATLAB
1 = interpreted MATLAB
2 = Octave" "$g_matlab_default_mode"
opts_AddOptional '--tICA-mode' 'tICAmode' 'ESTIMATE, INITIALIZE, USE' "defaults to ESTIMATE
ESTIMATE estimates a new tICA mixing matrix
INITIALIZE initializes an estimation with a previously computed mixing matrix with matching sICA components
USE simply applies a previously computed mixing matrix with matching sICA components" "ESTIMATE"
opts_AddOptional '--tICA-mixing-matrix' 'tICAMM' 'filename' "path to a previously computed tICA mixing matrix with matching sICA components"
opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

#FIXME: hardcoded naming conventions, move these to high level script when ready
OutputFolder="$OutGroupFolder/MNINonLinear/Results/$fMRIConcatName/tICA_d$sICAdim"

TCSConcatName="$OutputFolder/sICA_TCS_$sICAdim.sdseries.nii"
TCSMaskName="$OutputFolder/sICA_TCSMASK_$sICAdim.sdseries.nii"
AvgTCSName="$OutputFolder/sICA_AVGTCS_$sICAdim.sdseries.nii"
AbsAvgTCSName="$OutputFolder/sICA_ABSAVGTCS_$sICAdim.sdseries.nii"
AvgSpectraName="$OutputFolder/sICA_Spectra_$sICAdim.sdseries.nii"

#AnnsubName="$OutputFolder/sICA_stats_$sICAdim.wb_annsub.csv"

AvgMapsName="$OutputFolder/sICA_Maps_$sICAdim.dscalar.nii"
AvgVolMapsName="$OutputFolder/sICA_VolMaps_$sICAdim.dscalar.nii"

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

IFS='@' read -a SubjList <<<"$SubjListRaw"
IFS='@' read -a fMRIList <<<"$fMRIListRaw"

TCSListName="$OutputFolder/TCSList.txt"
SpectraListName="$OutputFolder/SpectraList.txt"
SubjListName="$OutputFolder/SubjectList.txt"
fMRIListName="$OutputFolder/fMRIList.txt"

tempfiles_add "$TCSListName" "$SpectraListName" "$SubjListName" "$fMRIListName"

#when running cleanup on a cluster, output folder may not exist, so make it
mkdir -p "$OutputFolder"
rm -f -- "$TCSListName" "$SpectraListName" "$SubjListName" "$fMRIListName"

for Subject in "${SubjList[@]}"
do
    FilePrefix="$StudyFolder/$Subject/MNINonLinear/fsaverage_LR${LowResMesh}k/$Subject.${sICAProcString}${RegString}"
    echo "${FilePrefix}_ts.${LowResMesh}k_fs_LR.sdseries.nii" >> "$TCSListName"
    echo "${FilePrefix}_spectra.${LowResMesh}k_fs_LR.sdseries.nii" >> "$SpectraListName"
    echo "$Subject" >> "$SubjListName"
done

for fMRIName in "${fMRIList[@]}"
do
    echo "MNINonLinear/Results/$fMRIName/${fMRIName}_Atlas${RegString}.dtseries.nii" >> "$fMRIListName"
done

#shortcut in case the folder gets renamed
this_script_dir=$(dirname "$0")

#matlab function arguments have been changed to strings, to avoid having two copies of the argument list in the script
matlab_argarray=("$StudyFolder" "$SubjListName" "$TCSListName" "$SpectraListName" "$fMRIListName" "$sICAdim" "$RunsXNumTimePoints" "$TCSConcatName" "$TCSMaskName" "$AvgTCSName" "$AvgSpectraName" "$AvgMapsName" "$AvgVolMapsName" "$OutputFolder" "$sICAProcString" "$RegName" "$LowResMesh" "$tICAmode" "$tICAMM")

case "$MatlabMode" in
    (0)
        matlab_cmd=("$this_script_dir/Compiled_ComputeGroupTICA/run_ComputeGroupTICA.sh" "$MATLAB_COMPILER_RUNTIME" "${matlab_argarray[@]}")
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
            addpath('$HCPPIPEDIR/global/matlab/nets_spectra');
            addpath('$HCPPIPEDIR/global/matlab');
            addpath('$this_script_dir/icasso122');
            addpath('$this_script_dir/FastICA_25');
            addpath('$this_script_dir');
            addpath('$HCPCIFTIRWDIR');
            ComputeGroupTICA($matlab_args);"

        log_Msg "running matlab code: $matlabcode"
        "${matlab_interpreter[@]}" <<<"$matlabcode"
        echo
        ;;
esac

