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
source "$HCPPIPEDIR/global/scripts/tempfiles.shlib" "$@"
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
opts_AddOptional '--subject-concat-timeseries' 'InputConcat' 'fmri_concat' "the concatenated timeseries, if MR FIX was used, requires --fix-high-pass"
opts_AddOptional '--surf-reg-name' 'RegName' 'name' "the registration string corresponding to the input files"
opts_AddMandatory '--low-res' 'LowResMesh' 'meshnum' "mesh resolution, like '32' for 32k_fs_LR"
opts_AddMandatory '--proc-string' 'ProcString' 'string' "part of filename describing processing, like '_hp2000_clean'"
#this is only needed to build the different proc string of the _vn and _mean files, and therefore only when using --subject-concat-timeseries
opts_AddOptional '--fix-high-pass' 'HighPass' 'integer' 'the high pass value that was used when running FIX, required when using --subject-concat-timeseries' '--melodic-high-pass'
#outputs
opts_AddMandatory '--output-string' 'OutString' 'string' "filename part to describe the outputs, like _hp2000_clean_tclean"
opts_AddOptional '--do-vol' 'DoVolString' 'YES or NO' "whether to generate voxel-based outputs"
opts_AddOptional '--fix-legacy-bias' 'DoFixBiasString' 'YES or NO' "use YES if you are using HCP YA data (because it used an older bias field computation)" 'NO'
opts_AddOptional '--extract-fmri-name-list' 'concatNamesToUse' 'name@name@name...' "list of fMRI run names to concatenate into the --extract-fmri-out output"
opts_AddOptional '--extract-fmri-out' 'extractNameOut' 'name' "fMRI name for concatenated extracted runs, requires --extract-fmri-name-list"
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

if [[ "$HighPass" == "" && "$InputConcat" != "" ]]
then
    log_Err_Abort "--fix-high-pass is required when using --subject-concat-timeseries"
fi

if [[ "$extractNameOut" != "" ]]
then
    if [[ "$InputConcat" == "" ]]
    then
        log_Err_Abort "--subject-concat-timeseries is required when using --extract-fmri-out"
    fi
    if [[ "$concatNamesToUse" == "" ]]
    then
        log_Err_Abort "--extract-fmri-name-list is required when using --extract-fmri-out"
    fi
fi

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

tempfiles_create tICACleanData_matlab_XXXXXX tempname

tempfiles_add "$tempname.input.txt" "$tempname.inputvn.txt" "$tempname.params.txt" "$tempname.goodbias.txt" "$tempname.volgoodbias.txt" "$tempname.mapnames.txt" "$tempname.outputnames.txt" "$tempname.voloutputnames.txt" "$tempname.vnoutnames.txt" "$tempname.volvnoutnames.txt"
DoVol=$(opts_StringToBool "$DoVolString")
if ((DoVol))
then
    tempfiles_add "$tempname.volinput.txt" "$tempname.volinputvn.txt"
fi
volmergeargs=()

if [[ "$InputConcat" == "" ]]
then
    IFS='@' read -a InputArray <<< "$InputList"
else
    InputArray=("$InputConcat")
fi
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
        echo "$MNIFolder/Results/$fmri/${fmri}${OutString}_vn.nii.gz" >> "$tempname.volvnoutnames.txt"

        if ((DoFixBias))
        then
            echo "$MNIFolder/Results/$fmri/${fmri}_real_bias.nii.gz" >> "$tempname.volgoodbias.txt"
        fi
        
        tempfiles_add "$tempname.$fmri.min.nii.gz" "$tempname.$fmri.max.nii.gz" "$tempname.$fmri.goodvox.nii.gz"
        wb_command -volume-reduce "$MNIFolder/Results/$fmri/${fmri}${ProcString}.nii.gz" MIN "$tempname.$fmri.min.nii.gz"
        wb_command -volume-reduce "$MNIFolder/Results/$fmri/${fmri}${ProcString}.nii.gz" MAX "$tempname.$fmri.max.nii.gz"
        #"nan != nan" evaluates to true, so use < instead just in case
        wb_command -volume-math 'min < max' "$tempname.$fmri.goodvox.nii.gz" \
            -var min "$tempname.$fmri.min.nii.gz" \
            -var max "$tempname.$fmri.max.nii.gz"
        volmergeargs+=(-volume "$tempname.$fmri.goodvox.nii.gz")
    fi
done
#try to catch copy paste errors that use a loop-specific variable
unset fmri
if ((DoVol))
then
    VolCiftiTemplate="$tempname.dscalar.nii"
    tempfiles_add "$VolCiftiTemplate" "$tempname.volciftitemplate.label.nii.gz" "$tempname.volciftilabel.txt" "$tempname.goodvox_all.nii.gz" "$tempname.goodvox_min.nii.gz"
    if ((${#InputArray[@]} > 1))
    then
        wb_command -volume-merge "$tempname.goodvox_all.nii.gz" "${volmergeargs[@]}"
        wb_command -volume-reduce "$tempname.goodvox_all.nii.gz" MIN "$tempname.goodvox_min.nii.gz"
    else
        cp "$tempname.${InputArray[0]}.goodvox.nii.gz" "$tempname.goodvox_min.nii.gz"
    fi
    
    #make volume cifti template file
    echo -e "OTHER\n1 0 0 0 0" > "$tempname.volciftilabel.txt"
    wb_command -volume-label-import "$tempname.goodvox_min.nii.gz" "$tempname.volciftilabel.txt" "$tempname.volciftitemplate.label.nii.gz"
    wb_command -cifti-create-dense-scalar "$VolCiftiTemplate" -volume "$tempname.goodvox_min.nii.gz" "$tempname.volciftitemplate.label.nii.gz"
fi

#only used if DoFixBias - old bias is the same across all runs?
OldBias="$MNIFolder/Results/${InputArray[0]}/${InputArray[0]}_Atlas${RegString}_bias.dscalar.nii"
OldVolBias="$MNIFolder/Results/${InputArray[0]}/${InputArray[0]}_bias.nii.gz"

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

fMRIProcSTRING="_Atlas$RegString$ProcString"
IFS='@' read -a SplitArray <<< "$InputList"

if [[ "$InputConcat" != "" ]]
then
    MRFixConcatName="$InputConcat"

    #extract specified runs to another concatenated file (generally intended to recreate the REST concatenated set)
    if [[ "$extractNameOut" != "" ]]
    then
        cp "$MNIFolder/Results/$MRFixConcatName/${MRFixConcatName}_Atlas${RegString}${OutString}_vn.dscalar.nii" \
            "$MNIFolder/Results/$extractNameOut/${extractNameOut}_Atlas${RegString}${OutString}_vn.dscalar.nii"
        extractcmd=("$HCPPIPEDIR"/global/scripts/ExtractFromMRFIXConcat.sh
                    --study-folder="$StudyFolder"
                    --subject="$Subject"
                    --multirun-fix-names="$InputList"
                    --multirun-fix-names-to-use="$concatNamesToUse"
                    --surf-reg-name="$RegName"
                    --concat-cifti-input="$MNIFolder/Results/$MRFixConcatName/${MRFixConcatName}_Atlas${RegString}${OutString}.dtseries.nii"
                    --cifti-out="$MNIFolder/Results/$extractNameOut/${extractNameOut}_Atlas${RegString}${OutString}.dtseries.nii")
        if ((DoVol))
        then
            cp "$MNIFolder/Results/$MRFixConcatName/${MRFixConcatName}${OutString}_vn.nii.gz" \
                "$MNIFolder/Results/$extractNameOut/${extractNameOut}${OutString}_vn.nii.gz"
            extractcmd+=(--concat-volume-input="$MNIFolder/Results/$MRFixConcatName/${MRFixConcatName}${OutString}.nii.gz"
                         --volume-out="$MNIFolder/Results/$extractNameOut/${extractNameOut}${OutString}.nii.gz")
        fi
        "${extractcmd[@]}"
    fi
    curStart=1
    #write out fixed versions of _mean, like the matlab now writes out out fixed _vn files
    #the correct _vn, _mean files don't have "_clean" like fMRIProcString does
    for fMRIName in "${SplitArray[@]}"
    do
        if [[ -f "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}${fMRIProcSTRING}.dtseries.nii" ]]
        then
            curLength=$(wb_command -file-information -only-number-of-maps "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}${fMRIProcSTRING}.dtseries.nii")
            tempfiles_create tICAPipeline-mrsplit-XXXXXX.dtseries.nii tempfile
            wb_command -cifti-merge "$tempfile" \
                -cifti "$MNIFolder/Results/$MRFixConcatName/${MRFixConcatName}_Atlas${RegString}${OutString}.dtseries.nii" \
                    -column "$curStart" -up-to $((curStart + curLength - 1))
            useMean="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegString}_mean.dscalar.nii"
            useOrig="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegString}_hp${HighPass}_vn.dscalar.nii"
            if ((DoFixBias))
            then
                #generate and use new-BC corrected mean
                useMean="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegString}${OutString}_mean.dscalar.nii"
                useOrig="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegString}${OutString}_vn.dscalar.nii"
                wb_command -cifti-math 'mean * oldbias / newbias' "$useMean" \
                    -var mean "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegString}_mean.dscalar.nii" \
                    -var oldbias "$MNIFolder/Results/$fMRIName/${fMRIName}_Atlas${RegString}_bias.dscalar.nii" \
                    -var newbias "$MNIFolder/Results/$fMRIName/${fMRIName}_Atlas${RegString}_real_bias.dscalar.nii"
                wb_command -cifti-math 'origvn * oldbias / newbias' "$useOrig" \
                    -var origvn "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegString}_hp${HighPass}_vn.dscalar.nii" \
                    -var oldbias "$MNIFolder/Results/$fMRIName/${fMRIName}_Atlas${RegString}_bias.dscalar.nii" \
                    -var newbias "$MNIFolder/Results/$fMRIName/${fMRIName}_Atlas${RegString}_real_bias.dscalar.nii"
            fi
            #use the new _vn written by the matlab part
            wb_command -cifti-math 'split / mr_vn * orig_vn + mean' "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegString}${OutString}.dtseries.nii" \
                -var split "$tempfile" \
                -var mr_vn "$MNIFolder/Results/$MRFixConcatName/${MRFixConcatName}_Atlas${RegString}${OutString}_vn.dscalar.nii" -select 1 1 -repeat \
                -var orig_vn "$useOrig" -select 1 1 -repeat \
                -var mean "$useMean" -select 1 1 -repeat
                       
            #don't leave these large temporary timeseries around longer than needed
            rm -f "$tempfile"
            
            if ((DoVol))
            then
                tempfiles_create tICAPipeline-mrsplit-XXXXXX.nii.gz tempfilevol
                wb_command -volume-merge "$tempfilevol" \
                    -volume "$MNIFolder/Results/$MRFixConcatName/${MRFixConcatName}${OutString}.nii.gz" -subvolume "$curStart" -up-to $((curStart + curLength - 1))
                useMeanVol="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_mean.nii.gz"
                useOrigVol="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}_vn.nii.gz"
                if ((DoFixBias))
                then
                    useMeanVol="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}${OutString}_mean.nii.gz"
                    useOrigVol="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}${OutString}_vn.nii.gz"
                    #"$MNIFolder/Results/$fmri/${fmri}_real_bias.nii.gz"
                    wb_command -volume-math 'mean * oldbias / newbias' "$useMeanVol" \
                        -var mean "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_mean.nii.gz" \
                        -var oldbias "$MNIFolder/Results/$fMRIName/${fMRIName}_bias.nii.gz" \
                        -var newbias "$MNIFolder/Results/$fMRIName/${fMRIName}_real_bias.nii.gz" \
                        -fixnan 0
                    wb_command -volume-math 'origvn * oldbias / newbias' "$useOrigVol" \
                        -var origvn "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}_vn.nii.gz" \
                        -var oldbias "$MNIFolder/Results/$fMRIName/${fMRIName}_bias.nii.gz" \
                        -var newbias "$MNIFolder/Results/$fMRIName/${fMRIName}_real_bias.nii.gz" \
                        -fixnan 0
                fi
                wb_command -volume-math 'split / mr_vn * orig_vn + mean' "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}${OutString}.nii.gz" \
                    -var split "$tempfilevol" \
                    -var mr_vn $MNIFolder/Results/$MRFixConcatName/${MRFixConcatName}${OutString}_vn.nii.gz -subvolume 1 -repeat \
                    -var orig_vn "$useOrigVol" -subvolume 1 -repeat \
                    -var mean "$useMeanVol" -subvolume 1 -repeat \
                    -fixnan 0
                
                rm -f "$tempfilevol"
            fi
            
            curStart=$((curStart + curLength))
        fi
    done
else
    for fMRIName in "${SplitArray[@]}"
    do
        if [[ -f "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}${fMRIProcSTRING}.dtseries.nii" ]]
        then
            wb_command -cifti-reduce "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegString}.dtseries.nii" MEAN "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegString}_mean.dscalar.nii"
            useMean="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegString}_mean.dscalar.nii"
            if ((DoFixBias))
            then
                #generate and use new-BC corrected mean
                useMean="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegString}${OutString}_mean.dscalar.nii"
                wb_command -cifti-math 'mean * oldbias / newbias' "$useMean" \
                    -var mean "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegString}_mean.dscalar.nii" \
                    -var oldbias "$MNIFolder/Results/$fMRIName/${fMRIName}_Atlas${RegString}_bias.dscalar.nii" \
                    -var newbias "$MNIFolder/Results/$fMRIName/${fMRIName}_Atlas${RegString}_real_bias.dscalar.nii"
            fi
            #use the new _vn written by the matlab part
            wb_command -cifti-math 'fmri + mean' "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegString}${OutString}.dtseries.nii" \
                -var fmri "$MNIFolder/Results/$fMRIName/${fMRIName}_Atlas${RegString}${OutString}.dtseries.nii" \
                -var mean "$useMean" -select 1 1 -repeat 
                                    
            if ((DoVol))
            then
                wb_command -volume-reduce "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}.nii.gz" MEAN "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_mean.nii.gz"
                useMeanVol="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_mean.nii.gz"
                if ((DoFixBias))
                then
                    useMeanVol="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}${OutString}_mean.nii.gz"
                    wb_command -volume-math 'mean * oldbias / newbias' "$useMeanVol" \
                        -var mean "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_mean.nii.gz" \
                        -var oldbias "$MNIFolder/Results/$fMRIName/${fMRIName}_bias.nii.gz" \
                        -var newbias "$MNIFolder/Results/$fMRIName/${fMRIName}_real_bias.nii.gz" \
                        -fixnan 0
                fi
                wb_command -volume-math 'fmri + mean' "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}${OutString}.nii.gz" \
                    -var fmri "$MNIFolder/Results/$fMRIName/${fMRIName}${OutString}.nii.gz" \
                    -var mean "$useMeanVol" -subvolume 1 -repeat \
                    -fixnan 0
                
            fi
            
        fi
    done
fi

