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
$log_ToolName: regresses group ICA spatial maps into individual data in order to obtain individual spatial maps of where the subject's similar function is

Usage: $log_ToolName PARAMETER...

PARAMETERs are [ ] = optional; < > = user supplied value
"
    #automatic argument descriptions
    opts_ShowArguments
}

#arguments to opts_Add*: switch, variable to set, name for inside of <> in help text, description, [default value other than empty string if AddOptional], [compatibility flag, ...]
opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject' 'Subject' 'subject ID' ""
opts_AddOptional  '--group-maps' 'GroupMaps' 'file' "the group template spatial maps for weighted or dual regression"
opts_AddOptional  '--timeseries' 'Timeseries' 'file' "the timeseries for single regression"
opts_AddMandatory '--subject-timeseries' 'InputList' 'fmri@fmri@fmri...' "the timeseries fmri names to concatenate"
opts_AddOptional '--surf-reg-name' 'RegName' 'name' "the registration string corresponding to the input files"
opts_AddMandatory '--low-res' 'LowResMesh' 'meshnum' "mesh resolution, like '32' for 32k_fs_LR"
opts_AddMandatory '--proc-string' 'ProcString' 'string' "part of filename describing processing, like '_hp2000_clean'"
opts_AddMandatory '--method' 'Method' 'regression method' "'weighted', 'dual', or 'single' - weighted regression finds locations in the subject that don't match the template well and downweights them; dual is simpler, both methods use vertex area information.  single temporal regression requires a prior run of weighted or dual regression and is intended for adding an additional output space"
opts_AddOptional '--weighted-smoothing-sigma' 'WRSmoothingSigma' 'number' "default 14 for human data - when using --method=weighted, the smoothing sigma, in mm, to apply to the 'alignment quality' weighting map" '14'
opts_AddOptional '--low-ica-dims' 'LowICADims' 'num@num@num...' "when using --method=weighted, the low ICA dimensionality files to use for determining weighting"
opts_AddOptional '--low-ica-template-name' 'ICATemplateName' 'filename' "filename template where 'REPLACEDIM' will be replaced by each of the --low-ica-dims values in turn to form the low-dim inputs"
opts_AddOptional '--tICA-mixing-matrix' 'tICAMM' 'filename' "path to a previously computed tICA mixing matrix with matching sICA components"

#outputs
opts_AddMandatory '--output-string' 'OutString' 'name' "filename part to describe the outputs, like group_ICA_d127"
opts_AddOptional '--hippocampal-output' 'HippocampalOutputString' 'YES or NO' "YES generates additional hippocampal RSN maps" 'NO'
opts_AddOptional '--hippocampal-mesh' 'HippMesh' '512, 2k, 8k, or 18k' "hippocampal mesh density; allowed values: 512, 2k, 8k, or 18k" '2k'
opts_AddOptional '--output-spectra' 'nTPsForSpectra' 'number' "number of samples to use when computing frequency spectrum" '0'
opts_AddOptional '--volume-template-cifti' 'VolCiftiTemplate' 'file' "to generate voxel-based outputs, provide a cifti file setting the voxels to use"
opts_AddOptional '--output-z' 'DoZString' 'YES or NO' "also create Z maps from the regression" 'NO'
#opts_AddOptional '--output-norm' 'DoNorm' '1 or 0' "also create maps normalized to match the group maps" '0'
#old bias field
opts_AddOptional '--fix-legacy-bias' 'DoFixBiasString' 'YES or NO' "use YES if you are using HCP YA data (because it used an older bias field computation)" 'NO'
opts_AddOptional '--scale-factor' 'ScaleFactor' 'number' "multiply the input timeseries by some factor before processing"
opts_AddOptional '--wf' 'WF' 'number' "number of Wishart Distributions for Wishart Filtering, set to zero to turn off (default)"
opts_AddOptional '--matlab-run-mode' 'MatlabMode' '0, 1, or 2' "defaults to ${g_matlab_default_mode}
0 = compiled MATLAB
1 = interpreted MATLAB
2 = Octave" \
"${g_matlab_default_mode}"

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

HippocampalOutput=$(opts_StringToBool "$HippocampalOutputString")
if ((HippocampalOutput))
then
    case "$HippMesh" in
        (512 | 2k | 8k | 18k)
            ;;
        (*)
            log_Err_Abort \
                "unrecognized hippocampal mesh '$HippMesh', use 512, 2k, 8k, or 18k"
            ;;
    esac
fi
#display the parsed/default values
opts_ShowValues

#sanity check boolean strings and convert to 1 and 0
DoZ=$(opts_StringToBool "$DoZString")
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
            log_Err_Abort "To use compiled matlab, you must set and export the variable MATLAB_COMPILER_RUNTIME"
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

DoVol=0
if [[ "$VolCiftiTemplate" != "" ]]
then
    DoVol=1
fi

MNIFolder="$StudyFolder/$Subject/MNINonLinear"
T1wFolder="$StudyFolder/$Subject/T1w"

DownSampleMNIFolder="$MNIFolder/fsaverage_LR${LowResMesh}k"
DownSampleT1wFolder="$T1wFolder/fsaverage_LR${LowResMesh}k"
HippDownSampleMNIFolder="$MNIFolder/HippUnfold/${HippMesh}"

tempfiles_create rsn_regr_matlab_XXXXXX tempname
tempfiles_add "$tempname.input.txt" "$tempname.inputvn.txt" "$tempname.volinput.txt" "$tempname.volinputvn.txt" "$tempname.params.txt" "$tempname.goodbias.txt" "$tempname.volgoodbias.txt" "$tempname.mapnames.txt"
tempfiles_add "$tempname.hippinput.txt" "$tempname.hippinputvn.txt"
IFS='@' read -a InputArray <<< "$InputList"
#use newline-delimited text files for matlab
#matlab chokes on more than 4096 characters in an input line, so use text files for safety

for fmri in "${InputArray[@]}"
do
    echo "$MNIFolder/Results/$fmri/${fmri}_Atlas${RegString}${ProcString}.dtseries.nii" >> "$tempname.input.txt"
    echo "$MNIFolder/Results/$fmri/${fmri}_Atlas${RegString}${ProcString}_vn.dscalar.nii" >> "$tempname.inputvn.txt"

    if ((HippocampalOutput))
    then
        HippResultsFolder="$MNIFolder/Results/$fmri"

        HippInput="$HippResultsFolder/${fmri}_AtlasHipp${ProcString}.${HippMesh}.dtseries.nii"
        HippInputVN="$HippResultsFolder/${fmri}_AtlasHipp${ProcString}_vn.${HippMesh}.dscalar.nii"
        if [[ ! -f "$HippInput" ]]
        then
            log_Err_Abort "hippocampal timeseries does not exist: $HippInput"
        fi

        if [[ ! -f "$HippInputVN" ]]
        then
            log_Err_Abort "hippocampal VN file does not exist: $HippInputVN"
        fi

        echo "$HippInput" >> "$tempname.hippinput.txt"
        echo "$HippInputVN" >> "$tempname.hippinputvn.txt"
    fi
    if ((DoFixBias))
    then
        echo "$MNIFolder/Results/$fmri/${fmri}_Atlas${RegString}_real_bias.dscalar.nii" >> "$tempname.goodbias.txt"
    fi
    if ((DoVol))
    then
        echo "$MNIFolder/Results/$fmri/${fmri}${ProcString}.nii.gz" >> "$tempname.volinput.txt"
        echo "$MNIFolder/Results/$fmri/${fmri}${ProcString}_vn.nii.gz" >> "$tempname.volinputvn.txt"
        if ((DoFixBias))
        then
            echo "$MNIFolder/Results/$fmri/${fmri}_real_bias.nii.gz" >> "$tempname.volgoodbias.txt"
        fi
    fi
done 
#only used if DoFixBias
OldBias="$MNIFolder/Results/$fmri/${fmri}_Atlas${RegString}_bias.dscalar.nii"
OldVolBias="$MNIFolder/Results/$fmri/${fmri}_bias.nii.gz"
#spectra output files want the correct TR, so save the first input filename
SpectraTRFile="$MNIFolder/Results/${InputArray[0]}/${InputArray[0]}_Atlas${RegString}${ProcString}.dtseries.nii"

# MATLAB cannot take strings containing newlines, so the surfaces are left@right.
SurfString="$DownSampleT1wFolder/${Subject}.L.midthickness${RegString}.${LowResMesh}k_fs_LR.surf.gii@$DownSampleT1wFolder/${Subject}.R.midthickness${RegString}.${LowResMesh}k_fs_LR.surf.gii"

VANormOnlySurf="$DownSampleT1wFolder/${Subject}.midthickness${RegString}_va_norm.${LowResMesh}k_fs_LR.dscalar.nii"

case "$Method" in
    (weighted)
        MethodStr="WR"
        if [[ "$LowICADims" == "" || "$ICATemplateName" == "" ]]
        then
            log_Err_Abort "When using 'weighted' method, you must use --low-ica-dims and --low-ica-template-name"
        fi
        IFS='@' read -a LowDimArray <<< "$LowICADims"
        for dim in "${LowDimArray[@]}"
        do
            #yes, quotes can nest when there is a $() separating them
            echo "$ICATemplateName" | sed "s/REPLACEDIM/$dim/g" >> "$tempname.params.txt"
        done
        ;;
    (tICA_weighted)
        MethodStr="TWR"
        if [[ "$LowICADims" == "" || "$ICATemplateName" == "" || "$tICAMM" == "" ]]
        then
            log_Err_Abort "When using 'tICA_weighted' method, you must use --low-ica-dims, --low-ica-template-name and --tICA-mixing-matrix"
        fi
        IFS='@' read -a LowDimArray <<< "$LowICADims"
        for dim in "${LowDimArray[@]}"
        do
            #yes, quotes can nest when there is a $() separating them
            echo "$ICATemplateName" | sed "s/REPLACEDIM/$dim/g" >> "$tempname.params.txt"
        done
        ;;
    (dual)
        MethodStr="DR"
        ;;
    (single)
        if [ -e ${Timeseries} ] ; then
            MethodStr="SR"
        else 
            log_Err_Abort "single method requires a prior run of weighted or dual"
        fi
        ;;
    (*)
        log_Err_Abort "unknown method string: '$Method'"
        ;;
esac

if [ "$WF" = "0" ] ; then
  WF=""
fi

if [[ "$WF" != "" ]] ; then
  WFstr="WF${WF}"
else
  WFstr=""
fi

OutBeta="$DownSampleMNIFolder/${Subject}.${OutString}_${MethodStr}${WFstr}${RegString}.${LowResMesh}k_fs_LR.dscalar.nii"
OutputVolBeta=""
if ((DoVol))
then
    #no reason for it to have the mesh on the name, but that is what the old script said...
    OutputVolBeta="$DownSampleMNIFolder/${Subject}.${OutString}_${MethodStr}${WFstr}${RegString}_vol.${LowResMesh}k_fs_LR.dscalar.nii"
fi
OutputZ=""
OutputVolZ=""
if ((DoZ))
then
    OutputZ="$DownSampleMNIFolder/${Subject}.${OutString}_${MethodStr}${WFstr}Z${RegString}.${LowResMesh}k_fs_LR.dscalar.nii"
    OutputZMM="$DownSampleMNIFolder/${Subject}.${OutString}_${MethodStr}${WFstr}ZMM${RegString}.${LowResMesh}k_fs_LR.dscalar.nii"
    if ((DoVol))
    then
        OutputVolZ="$DownSampleMNIFolder/${Subject}.${OutString}_${MethodStr}${WFstr}Z${RegString}_vol.${LowResMesh}k_fs_LR.dscalar.nii"
        OutputVolZMM="$DownSampleMNIFolder/${Subject}.${OutString}_${MethodStr}${WFstr}ZMM${RegString}_vol.${LowResMesh}k_fs_LR.dscalar.nii"
    fi
fi

OutputHippBeta=""
OutputHippZ=""
OutputHippZMM=""

if ((HippocampalOutput))
then
    mkdir -p "$HippDownSampleMNIFolder"

    OutputHippBeta="$HippDownSampleMNIFolder/${Subject}.${OutString}_${MethodStr}${WFstr}.Hipp.${HippMesh}.dscalar.nii"

    if ((DoZ))
    then
        OutputHippZ="$HippDownSampleMNIFolder/${Subject}.${OutString}_${MethodStr}${WFstr}Z.Hipp.${HippMesh}.dscalar.nii"
        OutputHippZMM="$HippDownSampleMNIFolder/${Subject}.${OutString}_${MethodStr}${WFstr}ZMM.Hipp.${HippMesh}.dscalar.nii"
    fi
fi

SpectraParams=""

RSNTimeseriesText="$DownSampleMNIFolder/${Subject}.${OutString}_${MethodStr}${RegString}_ts.${LowResMesh}k_fs_LR.txt"
RSNTimeseriesCifti="$DownSampleMNIFolder/${Subject}.${OutString}_${MethodStr}${RegString}_ts.${LowResMesh}k_fs_LR.sdseries.nii"
SpectraText="$DownSampleMNIFolder/${Subject}.${OutString}_${MethodStr}${RegString}_spectra.${LowResMesh}k_fs_LR.txt"

if ((HippocampalOutput))
then
    if [[ "$Method" != "dual" ]]
    then
        log_Err_Abort "Hippocampus can only be processed with method 'dual'; requested method was '$Method'"
    fi

    if ((nTPsForSpectra <= 0))
    then
        # Determines how many timepoints are in the whole-brain fMRI CIFTI
        nTPsForSpectra=$(wb_command -file-information "$SpectraTRFile" -only-number-of-maps)
    fi
fi

if [[ "$nTPsForSpectra" -gt 0 ]] && [[ "$Method" != "single" ]]
then
    SpectraParams="$nTPsForSpectra@$RSNTimeseriesText@$SpectraText"
elif [[ ${Method} == "single" ]]
then
    SpectraParams="${Timeseries}"
fi
#the msmall script should do this for itself instead
#OutputNorm=""
#if ((DoNorm))
#then
#    OutputNorm="$DownSampleMNIFolder/${Subject}.${OutString}_${MethodStr}N${RegString}.${LowResMesh}k_fs_LR.dscalar.nii"
    #probably can't trust the volume outputs to be the same scaling as the surface outputs, and we don't need this except for MSMAll anyway
#fi

#fix the _va_norm file being surface-only
#extract the all-voxels ROI file and use it in -from-template
if [[ "$Method" != "single" ]]
then
    tempfiles_create XXXXXX.roi.nii.gz tempfile
    tempfiles_add "$tempfile.junk.nii.gz" "$tempfile.91k.dscalar.nii"

    wb_command -cifti-separate "$GroupMaps" COLUMN -volume-all "$tempfile.junk.nii.gz" -roi "$tempfile" -crop
    wb_command -cifti-create-dense-from-template "$GroupMaps" "$tempfile.91k.dscalar.nii" -cifti "$VANormOnlySurf" -volume-all "$tempfile" -from-cropped

    GroupMapsForMatlab="$GroupMaps"
    VAWeightsForMatlab="$tempfile.91k.dscalar.nii"
fi

#all arguments happen to be passed to matlab as strings anyway, so we don't need special handling on the script side -- can do argument lists for each matlab mode with the same code
#SurfString and WRSmoothingSigma are optional to the matlab function (needed only for weighted), but we will always have it, so always providing it is simpler here
matlab_argarray=("$tempname.input.txt" "$tempname.inputvn.txt" "$Method" "$tempname.params.txt" "$OutBeta" "SurfString" "$SurfString" "WRSmoothingSigma" "$WRSmoothingSigma")
if [[ "$Method" != "single" ]]
then
    matlab_argarray+=("GroupMaps" "$GroupMapsForMatlab")
    matlab_argarray+=("VAWeightsName" "$VAWeightsForMatlab")
fi
if [[ "$Method" == "tICA_weighted" ]]
then
    matlab_argarray+=("tICAMM" "$tICAMM")
fi
if ((DoZ))
then
    matlab_argarray+=("OutputZ" "$OutputZ")
fi
if ((DoZ))
then
    matlab_argarray+=("OutputZMM" "$OutputZMM")
fi
if [[ "$SpectraParams" != "" ]]
then
    matlab_argarray+=("SpectraParams" "$SpectraParams")
fi
if ((DoFixBias))
then
    matlab_argarray+=("GoodBCFile" "$tempname.goodbias.txt" "OldBias" "$OldBias")
fi
if [[ "$ScaleFactor" != "" ]]
then
    matlab_argarray+=("ScaleFactor" "$ScaleFactor")
fi
if [[ "$WF" != "" ]]
then
    matlab_argarray+=("WF" "$WF")
fi
if ((DoVol))
then
    matlab_argarray+=("VolCiftiTemplate" "$VolCiftiTemplate" "VolInputFile" "$tempname.volinput.txt" "VolInputVNFile" "$tempname.volinputvn.txt" "OutputVolBeta" "$OutputVolBeta")
    if ((DoZ))
    then
        matlab_argarray+=("OutputVolZ" "$OutputVolZ")
    fi
    if ((DoZ))
    then
        matlab_argarray+=("OutputVolZMM" "$OutputVolZMM")
    fi
    if ((DoFixBias))
    then
        matlab_argarray+=("VolGoodBCFile" "$tempname.volgoodbias.txt" "OldVolBias" "$OldVolBias")
    fi
fi

case "$MatlabMode" in
    (0)
        #sadly, matlab 2017b compiler doesn't know how to write sh scripts that are whitespace safe...could write our own...
        matlab_cmd=("$this_script_dir/Compiled_RSNregression/run_RSNregression.sh" "$MATLAB_COMPILER_RUNTIME" "${matlab_argarray[@]}")
        log_Msg "Run compiled MATLAB: ${matlab_cmd[*]}"
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
            addpath('$HCPCIFTIRWDIR');
            addpath('$HCPPIPEDIR/global/matlab/nets_spectra');
            addpath('$HCPPIPEDIR/global/matlab');
            addpath('$this_script_dir');
            RSNregression($matlab_args);"
        
        log_Msg "running matlab code: $matlab_code"
        "${matlab_interpreter[@]}" <<<"$matlab_code"
        #matlab leaves a prompt and no newline when it finishes, so do an echo
        echo
        ;;
esac

if [[ "$SpectraParams" != "" ]] && [[ ! ${Method} == "single" ]] && [[ ! ${Method} == "tICA_weighted" ]]
then
    wb_command -file-information "$GroupMaps" -only-map-names > "$tempname.mapnames.txt"
    TR=$(wb_command -file-information "$SpectraTRFile" -only-step-interval)
    FTmixStep=$(echo "scale = 7; 1 / ($nTPsForSpectra * $TR)" | bc -l)
    wb_command -cifti-create-scalar-series "$RSNTimeseriesText" "$RSNTimeseriesCifti" -transpose -name-file "$tempname.mapnames.txt" -series SECOND 0 "$TR"
    wb_command -cifti-create-scalar-series "$SpectraText" "$DownSampleMNIFolder/${Subject}.${OutString}_${MethodStr}${RegString}_spectra.${LowResMesh}k_fs_LR.sdseries.nii" -transpose -name-file "$tempname.mapnames.txt" -series HERTZ 0 "$FTmixStep"

    rm -f -- "$RSNTimeseriesText" "$SpectraText"
fi

if ((HippocampalOutput))
then
    if [[ ! -f "$RSNTimeseriesCifti" ]]
    then
        log_Err_Abort "whole-brain RSN time-course CIFTI was not created: $RSNTimeseriesCifti"
    fi

    hipp_matlab_argarray=(
        "$tempname.hippinput.txt"
        "$tempname.hippinputvn.txt"
        "single"
        "$tempname.params.txt"
        "$OutputHippBeta"
        "SpectraParams" "$RSNTimeseriesCifti"
    )

    if ((DoZ))
    then
        hipp_matlab_argarray+=(
            "OutputZ" "$OutputHippZ"
            "OutputZMM" "$OutputHippZMM"
        )
    fi

    if [[ "$ScaleFactor" != "" ]]
    then
        hipp_matlab_argarray+=(
            "ScaleFactor" "$ScaleFactor"
        )
    fi

    if [[ "$WF" != "" ]]
    then
        hipp_matlab_argarray+=(
            "WF" "$WF"
        )
    fi

    case "$MatlabMode" in
        (0)
            hipp_matlab_cmd=(
                "$this_script_dir/Compiled_RSNregression/run_RSNregression.sh"
                "$MATLAB_COMPILER_RUNTIME"
                "${hipp_matlab_argarray[@]}"
            )

            log_Msg "Run compiled MATLAB for hippocampal output: ${hipp_matlab_cmd[*]}"

            "${hipp_matlab_cmd[@]}"
            ;;

        (1 | 2)
            hipp_matlab_args=""

            for thisarg in "${hipp_matlab_argarray[@]}"
            do
                if [[ "$hipp_matlab_args" != "" ]]
                then
                    hipp_matlab_args+=", "
                fi

                hipp_matlab_args+="'$thisarg'"
            done

            hipp_matlab_code="
                addpath('$HCPPIPEDIR/global/fsl/etc/matlab');
                addpath('$HCPCIFTIRWDIR');
                addpath('$HCPPIPEDIR/global/matlab/nets_spectra');
                addpath('$HCPPIPEDIR/global/matlab');
                addpath('$this_script_dir');
                RSNregression($hipp_matlab_args);"

            log_Msg "running hippocampal MATLAB code: $hipp_matlab_code"

            "${matlab_interpreter[@]}" <<<"$hipp_matlab_code"
            echo
            ;;
    esac
fi

log_Msg "RSNregression completed successfully"