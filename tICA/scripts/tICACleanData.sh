#!/bin/bash
set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    export HCPPIPEDIR="$(dirname "$0")/../.."
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
$log_ToolName: regresses noise group temporal ICA components out of CIFTI and optionaly volume timeseries data and optionally correct the bias legacy field

Usage: $log_ToolName PARAMETER...

PARAMETERs are [ ] = optional; < > = user supplied value
"
    #automatic argument descriptions
    opts_ShowArguments
}

#arguments to opts_Add*: switch, variable to set, name for inside of <> in help text, description, [default value other than empty string if AddOptional], [compatibility flag, ...]
opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject' 'Subject' 'subject ID' ""
opts_AddMandatory  '--noise-list' 'NoiseList' 'file' "the list of temporal ICA components to remove"
opts_AddMandatory  '--timeseries' 'Timeseries' 'file' "the single subject temporal ICA component timecourses"
opts_AddMandatory '--subject-timeseries' 'InputList' 'fmri@fmri@fmri...' "the timeseries fmri names to concatenate"
opts_AddOptional '--surf-reg-name' 'RegName' 'name' "the registration string corresponding to the input files"
opts_AddMandatory '--low-res' 'LowResMesh' 'meshnum' "mesh resolution, like '32' for 32k_fs_LR"
opts_AddMandatory '--proc-string' 'ProcString' 'string' "part of filename describing processing, like '_hp2000_clean'"
#outputs
opts_AddMandatory '--output-string' 'OutString' 'name' "filename part to describe the outputs, like _hp2000_clean_tclean"
#opts_AddOptional '--volume-template-cifti' 'VolCiftiTemplate' 'file' "to generate voxel-based outputs, provide a cifti file setting the voxels to use"
#opts_AddOptional '--volume-fmrires-brain-mask' 'fMRIBrainMask' 'file' "volume ROI of which voxels of the fMRI data to use"
opts_AddOptional '--do-vol' 'DoVolString' 'YES or NO' "whether to generate voxel-based outputs"
opts_AddOptional '--fix-legacy-bias' 'DoFixBiasString' 'YES or NO' "use YES if you are using HCP YA data (because it used an older bias field computation)" 'NO'
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

#sanity check boolean strings and convert to 1 and 0
DoFixBias=$(opts_StringToBool "$DoFixBiasString")

if [[ -L "$0" ]]
then
	this_script_dir=$(dirname "$(readlink "$0")")
else
	this_script_dir=$(dirname "$0")
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

RegString=""
if [[ "$RegName" != "" ]]
then
    RegString="_$RegName"
fi

MNIFolder="$StudyFolder/$Subject/MNINonLinear"
T1wFolder="$StudyFolder/$Subject/T1w"
DownSampleMNIFolder="$MNIFolder/fsaverage_LR${LowResMesh}k"
DownSampleT1wFolder="$T1wFolder/fsaverage_LR${LowResMesh}k"

tempfiles_create rsn_regr_matlab_XXXXXX tempname

tempfiles_add "$tempname.input.txt" "$tempname.inputvn.txt" "$tempname.params.txt" "$tempname.goodbias.txt" "$tempname.volgoodbias.txt" "$tempname.mapnames.txt" "$tempname.outputnames.txt" "$tempname.voloutputnames.txt" "$tempname.vnoutnames.txt" "$tempname.volvnoutnames.txt"
DoVol=$(opts_StringToBool "$DoVolString")
if ((DoVol))
then
    tempfiles_add "$tempname.volinput.txt" "$tempname.volinputvn.txt"
fi
volmergeargs=()
IFS='@' read -a InputArray <<< "$InputList"
#use newline-delimited text files for matlab
#matlab chokes on more than 4096 characters in an input line, so use text files for safety
for fmri in "${InputArray[@]}"
do
    echo "$MNIFolder/Results/$fmri/${fmri}_Atlas${RegString}${ProcString}.dtseries.nii" >> "$tempname.input.txt"
    echo "$MNIFolder/Results/$fmri/${fmri}_Atlas${RegString}${ProcString}_vn.dscalar.nii" >> "$tempname.inputvn.txt"
    echo "$MNIFolder/Results/$fmri/${fmri}_Atlas${RegString}${OutString}.dtseries.nii" >> "$tempname.outputnames.txt"
    echo "$MNIFolder/Results/$fmri/${fmri}_Atlas${RegString}${OutString}_vn.dscalar.nii" >> "$tempname.vnoutnames.txt"
        
    if ((DoFixBias))
    then
        echo "$MNIFolder/Results/$fmri/${fmri}_Atlas${RegString}_real_bias.dscalar.nii" >> "$tempname.goodbias.txt"
    fi
    if ((DoVol))
    then
        echo "$MNIFolder/Results/$fmri/${fmri}${ProcString}.nii.gz" >> "$tempname.volinput.txt"
        echo "$MNIFolder/Results/$fmri/${fmri}${ProcString}_vn.nii.gz" >> "$tempname.volinputvn.txt"
        echo "$MNIFolder/Results/$fmri/${fmri}${OutString}.nii.gz" >> "$tempname.voloutputnames.txt"
        if ((DoFixBias))
        then
            echo "$MNIFolder/Results/$fmri/${fmri}_real_bias.nii.gz" >> "$tempname.volgoodbias.txt"
        fi
        echo "$MNIFolder/Results/$fmri/${fmri}${OutString}_vn.nii.gz" >> "$tempname.volvnoutnames.txt"
        
        tempfiles_add "$tempname.$fmri.min.nii.gz" "$tempname.$fmri.max.nii.gz" "$tempname.$fmri.goodvox.nii.gz"
        wb_command -volume-reduce "$MNIFolder/Results/$fmri/${fmri}${ProcString}.nii.gz" MIN "$tempname.$fmri.min.nii.gz"
        wb_command -volume-reduce "$MNIFolder/Results/$fmri/${fmri}${ProcString}.nii.gz" MAX "$tempname.$fmri.max.nii.gz"
        wb_command -volume-math 'min != max' "$tempname.$fmri.goodvox.nii.gz" \
            -var min "$tempname.$fmri.min.nii.gz" \
            -var max "$tempname.$fmri.max.nii.gz"
        volmergeargs+=(-volume "$tempname.$fmri.goodvox.nii.gz")
    fi
done
if ((DoVol))
then
    VolCiftiTemplate="$tempname.dscalar.nii"
    tempfiles_add "$VolCiftiTemplate" "$tempname.volciftitemplate.label.nii.gz" "$tempname.volciftilabel.txt" "$tempname.goodvox_all.nii.gz" "$tempname.goodvox_min.nii.gz"
    wb_command -volume-merge "$tempname.goodvox_all.nii.gz" "${volmergeargs[@]}"
    wb_command -volume-reduce "$tempname.goodvox_all.nii.gz" MIN "$tempname.goodvox_min.nii.gz"
    
    #make volume cifti template file
    echo -e "OTHER\n1 0 0 0 0" > "$tempname.volciftilabel.txt"
    wb_command -volume-label-import "$tempname.goodvox_min.nii.gz" "$tempname.volciftilabel.txt" "$tempname.volciftitemplate.label.nii.gz"
    wb_command -cifti-create-dense-scalar "$VolCiftiTemplate" -volume "$tempname.goodvox_min.nii.gz" "$tempname.volciftitemplate.label.nii.gz"
fi

#only used if DoFixBias
OldBias="$MNIFolder/Results/$fmri/${fmri}_Atlas${RegString}_bias.dscalar.nii"
OldVolBias="$MNIFolder/Results/$fmri/${fmri}_bias.nii.gz"

#shortcut in case the folder gets renamed
this_script_dir=$(dirname "$0")

#matlab function arguments were already strings, we don't need two copies of the argument list logic in the script
matlab_argarray=("$tempname.input.txt" "$tempname.inputvn.txt" "$tempname.outputnames.txt" "$tempname.vnoutnames.txt" "$Timeseries" "$NoiseList")
if ((DoFixBias))
then
    matlab_argarray+=("GoodBCFile" "$tempname.goodbias.txt" "OldBias" "$OldBias")
fi
if ((DoVol))
then
    matlab_argarray+=("VolCiftiTemplate" "$VolCiftiTemplate" "VolInputFile" "$tempname.volinput.txt" "VolInputVNFile" "$tempname.volinputvn.txt" "OutputVolNamesFile" "$tempname.voloutputnames.txt" "OutputVolVNNamesFile" "$tempname.volvnoutnames.txt")
    if ((DoFixBias))
    then
        matlab_argarray+=("VolGoodBCFile" "$tempname.volgoodbias.txt" "OldVolBias" "$OldVolBias")
    fi
fi

case "$MatlabMode" in
    (0)
        matlab_cmd=("$this_script_dir/Compiled_tICACleanData/run_tICACleanData.sh" "$MATLAB_COMPILER_RUNTIME" "${matlab_argarray[@]}")
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
        matlab_code="
            addpath('$HCPPIPEDIR/global/fsl/etc/matlab');
            addpath('$HCPPIPEDIR/global/matlab');
            addpath('$HCPCIFTIRWDIR');
            addpath('$this_script_dir');
            tICACleanData($matlab_args);"
        
        log_Msg "running matlab code: $matlab_code"
        "${matlab_interpreter[@]}" <<<"$matlab_code"
        #matlab leaves a prompt and no newline when it finishes, so do an echo
        echo
        ;;
esac

if ((DoVol))
then
    for fmri in "${InputArray[@]}"
    do
        fslcpgeom "$MNIFolder/Results/$fmri/${fmri}${ProcString}.nii.gz" "$MNIFolder/Results/$fmri/${fmri}${OutString}.nii.gz"        
        fslcpgeom "$MNIFolder/Results/$fmri/${fmri}${ProcString}_vn.nii.gz" "$MNIFolder/Results/$fmri/${fmri}${OutString}_vn.nii.gz"
    done
fi

