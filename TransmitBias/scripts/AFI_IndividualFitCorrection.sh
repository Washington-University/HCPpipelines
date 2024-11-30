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
source "$HCPPIPEDIR/global/scripts/tempfiles.shlib" "$@"

opts_SetScriptDescription "corrects individual myelin maps based on AFI and group-corrected template"

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject' 'Subject' 'subject ID' "(e.g. 100610)"
opts_AddOptional '--manual-receive' 'useRCfilesStr' 'TRUE or FALSE' "whether Phase1 used unprocessed scans to correct for not using PSN when acquiring scans" 'false'
opts_AddMandatory '--gmwm-template' 'GMWMtemplate' 'file' "file containing GM+WM volume ROI"
opts_AddMandatory '--group-corrected-myelin' 'GroupCorrected' 'file' "the group-corrected myelin file"
opts_AddMandatory '--afi-tr-one' 'TRone' 'number' "TR of first AFI frame"
opts_AddMandatory '--afi-tr-two' 'TRtwo' 'number' "TR of second AFI frame"
opts_AddMandatory '--target-flip-angle' 'TargFlipAngle' 'number' "the target flip angle of the AFI sequence"
opts_AddMandatory '--grayordinates-res' 'grayordRes' 'number' "resolution used in PostFreeSurfer for grayordinates"
opts_AddMandatory '--transmit-res' 'transmitRes' 'number' "resolution to use for transmit field"
opts_AddMandatory '--reg-name' 'RegName' 'string' "surface registration to use, like MSMAll"
opts_AddOptional '--low-res-mesh' 'LowResMesh' 'number' "resolution of grayordinates mesh, default '32'" '32'
opts_AddOptional '--matlab-run-mode' 'MatlabMode' '0, 1, or 2' "defaults to 0
0 = compiled MATLAB
1 = interpreted MATLAB
2 = Octave" '0'

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

useRCfiles=$(opts_StringToBool "$useRCfilesStr")

this_script_dir=$(dirname "$0")

if [[ "$RegName" == "" || "$RegName" == "MSMSulc" ]]
then
    RegString=""
else
    RegString="_$RegName"
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

#Naming Conventions
AtlasTransform="acpc_dc2standard"

#Build Paths
T1wFolder="$StudyFolder/$Subject"/T1w
AtlasFolder="$StudyFolder/$Subject"/MNINonLinear
T1wDownSampleFolder="$T1wFolder"/fsaverage_LR"$LowResMesh"k
DownSampleFolder="$AtlasFolder"/fsaverage_LR"$LowResMesh"k

SubjectMyelin="$DownSampleFolder"/"$Subject".MyelinMap"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii
NativeVolMyelin="$T1wFolder"/T1wDividedByT2w.nii.gz
if ((useRCfiles))
then
    SubjectMyelin="$StudyFolder"/"$Subject"/TransmitBias/"$Subject".MyelinMap_onlyRC"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii
    NativeVolMyelin="$StudyFolder"/"$Subject"/TransmitBias/T1wDividedByT2w_onlyRC.nii.gz
fi

AFIVolume="$T1wFolder"/AFI_orig."$grayordRes".nii.gz
LeftPial="${T1wDownSampleFolder}/${Subject}.L.pial${RegString}.${LowResMesh}k_fs_LR.surf.gii"
LeftMidthick="${T1wDownSampleFolder}/${Subject}.L.midthickness${RegString}.${LowResMesh}k_fs_LR.surf.gii"
LeftWhite="${T1wDownSampleFolder}/${Subject}.L.white${RegString}.${LowResMesh}k_fs_LR.surf.gii"
RightPial="${T1wDownSampleFolder}/${Subject}.R.pial${RegString}.${LowResMesh}k_fs_LR.surf.gii"
RightMidthick="${T1wDownSampleFolder}/${Subject}.R.midthickness${RegString}.${LowResMesh}k_fs_LR.surf.gii"
RightWhite="${T1wDownSampleFolder}/${Subject}.R.white${RegString}.${LowResMesh}k_fs_LR.surf.gii"
SmoothLower="10"
SmoothUpper="100"
LeftVolROI="$T1wFolder"/ROIs/L_TransmitBias_ROI."$grayordRes".nii.gz
RightVolROI="$T1wFolder"/ROIs/R_TransmitBias_ROI."$grayordRes".nii.gz
OutputTextFile="$T1wFolder"/AFI_stats.txt

argvarlist=(SubjectMyelin AFIVolume \
    TRone TRtwo TargFlipAngle \
    LeftPial LeftMidthick LeftWhite \
    RightPial RightMidthick RightWhite \
    SmoothLower SmoothUpper \
    LeftVolROI RightVolROI GroupCorrected OutputTextFile)

case "$MatlabMode" in
    (0)
        arglist=()
        for var in "${argvarlist[@]}"
        do
            arglist+=("${!var}")
        done
        "$this_script_dir"/Compiled_AFI_OptimizeSmoothing/run_AFI_OptimizeSmoothing.sh "$MATLAB_COMPILER_RUNTIME" "${arglist[@]}"
        ;;
    (1 | 2)
        matlabargs=""
        matlabcode="
        addpath('$HCPPIPEDIR/global/fsl/etc/matlab');
        addpath('$HCPCIFTIRWDIR');
        addpath('$HCPPIPEDIR/global/matlab');
        addpath('$this_script_dir');
        "
        for var in "${argvarlist[@]}"
        do
            #NOTE: the newline before the closing quote is important, to avoid the 4KB stdin line limit
            matlabcode+="$var = '${!var}';
            "
            
            if [[ "$matlabargs" != "" ]]; then matlabargs+=", "; fi
            matlabargs+="$var"
        done

        matlabcode+="AFI_OptimizeSmoothing(${matlabargs});"
        
        echo "running matlab code: $matlabcode"
        "${matlab_interpreter[@]}" <<<"$matlabcode"
        echo
        ;;
esac

Smooth=$(cat "$OutputTextFile" | cut -d "," -f 1)
VolTwoCorrFac=$(cat "$OutputTextFile" | cut -d "," -f 2)
Slope=$(cat "$OutputTextFile" | cut -d "," -f 3)

tempfiles_create smoothtemp_XXXXXX smoothtemp
tempfiles_add "$smoothtemp".L_rAFI.nii.gz "$smoothtemp".R_rAFI.nii.gz "$smoothtemp".H_rAFI.nii.gz "$smoothtemp".rAFI_1.nii.gz "$smoothtemp".rAFI_2.nii.gz

wb_command -volume-smoothing "$T1wFolder"/AFI_orig."$transmitRes".nii.gz "$Smooth" "$smoothtemp".L_rAFI.nii.gz -fwhm -roi "$T1wFolder"/ROIs/L_TransmitBias_ROI."$transmitRes".nii.gz
wb_command -volume-smoothing "$T1wFolder"/AFI_orig."$transmitRes".nii.gz "$Smooth" "$smoothtemp".R_rAFI.nii.gz -fwhm -roi "$T1wFolder"/ROIs/R_TransmitBias_ROI."$transmitRes".nii.gz
wb_command -volume-smoothing "$T1wFolder"/AFI_orig."$transmitRes".nii.gz "$Smooth" "$smoothtemp".H_rAFI.nii.gz -fwhm -roi "$T1wFolder"/ROIs/H_TransmitBias_ROI."$transmitRes".nii.gz
#use tempfiles for rAFI in between removegrad steps
wb_command -volume-math "LEFT + RIGHT + HIND" "$smoothtemp".rAFI_1.nii.gz -var LEFT "$smoothtemp".L_rAFI.nii.gz -var RIGHT "$smoothtemp".R_rAFI.nii.gz -var HIND "$smoothtemp".H_rAFI.nii.gz

function removeroigrad()
{
    indata="$1"
    inroi="$2" #mask of where the undesired gradient is, defining the data range to smooth from
    mask="$3" #mask to prevent it from changing input values
    outfinal="$4"
    
    blendero="2.5" #how much to erode the roi when saying which voxels should be completely replaced by the implicit smoothed version (mm, try not to make exact multiple of voxel size)
    fixupsmooth=10 #how much to smooth within the roi (mm fwhm)
    blendsmooth=5 #how much to smooth the roi after dilating to make the blending function (mm fwhm)
    
    #processing
    tempfiles_create removeroigradtemp_XXXXXX tempbase
    tempfiles_add "$tempbase"_data_mask.nii.gz "$tempbase"_data_mask_smooth.nii.gz "$tempbase"_mask_smooth.nii.gz "$tempbase"_data_impsmooth.nii.gz "$tempbase"_mask_blend_smooth.nii.gz "$tempbase"_mask_blend_smooth_mask.nii.gz "$tempbase"_mask_blend.nii.gz "$tempbase"_mask_erode.nii.gz
    
    wb_command -volume-math 'data * mask' "$tempbase"_data_mask.nii.gz -var data "$indata" -var mask "$inroi" -subvolume 1 -repeat
    wb_command -volume-smoothing "$tempbase"_data_mask.nii.gz "$fixupsmooth" "$tempbase"_data_mask_smooth.nii.gz -fwhm
    wb_command -volume-smoothing "$inroi" "$fixupsmooth" "$tempbase"_mask_smooth.nii.gz -fwhm
    wb_command -volume-math 'datasmooth / roismooth' "$tempbase"_data_impsmooth.nii.gz -var datasmooth "$tempbase"_data_mask_smooth.nii.gz -var roismooth "$tempbase"_mask_smooth.nii.gz -subvolume 1 -repeat -fixnan 0

    wb_command -volume-smoothing "$inroi" "$blendsmooth" "$tempbase"_mask_blend_smooth.nii.gz -fwhm
    wb_command -volume-erode "$inroi" "$blendero" "$tempbase"_mask_erode.nii.gz
    wb_command -volume-math 'smooth * (! core)' "$tempbase"_mask_blend_smooth_mask.nii.gz -var smooth "$tempbase"_mask_blend_smooth.nii.gz -var core "$tempbase"_mask_erode.nii.gz
    fringemax=$(wb_command -volume-stats "$tempbase"_mask_blend_smooth_mask.nii.gz -reduce MAX)
    wb_command -volume-math "(core + fringe / $fringemax) * (roismooth && mask)" "$tempbase"_mask_blend.nii.gz -var core "$tempbase"_mask_erode.nii.gz -var fringe "$tempbase"_mask_blend_smooth_mask.nii.gz -var roismooth "$tempbase"_mask_smooth.nii.gz -var mask "$mask"

    wb_command -volume-math "main * (1 - blend) + impsmooth * blend" "$outfinal" -var main "$indata" -var impsmooth "$tempbase"_data_impsmooth.nii.gz -var blend "$tempbase"_mask_blend.nii.gz -subvolume 1 -repeat
}

removeroigrad "$smoothtemp".rAFI_1.nii.gz "$T1wFolder"/ROIs/CorpusCallosumTemplate."$transmitRes".nii.gz "$T1wFolder"/Head."$transmitRes".nii.gz "$smoothtemp".rAFI_2.nii.gz

tempfiles_create hindbraintemp_XXXXXX hindbraintemp
tempfiles_add "$hindbraintemp"_MidBrainTemplate_Dil.nii.gz "$hindbraintemp"_HindBrainTemplate_Dil.nii.gz "$smoothtemp".rAFI_3.nii.gz

wb_command -volume-dilate "$T1wFolder"/ROIs/MidBrainTemplate."$transmitRes".nii.gz 7 NEAREST "$hindbraintemp"_MidBrainTemplate_Dil.nii.gz
wb_command -volume-dilate "$T1wFolder"/ROIs/HindBrainTemplate."$transmitRes".nii.gz 7 NEAREST "$hindbraintemp"_HindBrainTemplate_Dil.nii.gz
wb_command -volume-math "MidBrain && HindBrain && GMWM" "$T1wFolder"/ROIs/HindBrainJunctionTemplate."$transmitRes".nii.gz -var MidBrain "$hindbraintemp"_MidBrainTemplate_Dil.nii.gz -var HindBrain "$hindbraintemp"_HindBrainTemplate_Dil.nii.gz -var GMWM "$T1wFolder"/ROIs/GMWMTemplate."$transmitRes".nii.gz
removeroigrad "$smoothtemp".rAFI_2.nii.gz "$T1wFolder"/ROIs/HindBrainJunctionTemplate."$transmitRes".nii.gz "$T1wFolder"/Head."$transmitRes".nii.gz "$smoothtemp".rAFI_3.nii.gz

tempfiles_create thalamustemp_XXXXXX thalamustemp
tempfiles_add "$thalamustemp"_L_ThalamusTemplate_Dil.nii.gz "$thalamustemp"_R_ThalamusTemplate_Dil.nii.gz
wb_command -volume-dilate "$T1wFolder"/ROIs/L_ThalamusTemplate."$transmitRes".nii.gz 7 NEAREST "$thalamustemp"_L_ThalamusTemplate_Dil.nii.gz
wb_command -volume-dilate "$T1wFolder"/ROIs/R_ThalamusTemplate."$transmitRes".nii.gz 7 NEAREST "$thalamustemp"_R_ThalamusTemplate_Dil.nii.gz
wb_command -volume-math "L_Thalamus && R_Thalamus && GMWM" "$T1wFolder"/ROIs/ThalamusJunctionTemplate."$transmitRes".nii.gz -var L_Thalamus "$thalamustemp"_L_ThalamusTemplate_Dil.nii.gz -var R_Thalamus "$thalamustemp"_R_ThalamusTemplate_Dil.nii.gz -var GMWM "$T1wFolder"/ROIs/GMWMTemplate."$transmitRes".nii.gz
if [[ "$(fslstats "$T1wFolder"/ROIs/ThalamusJunctionTemplate."$transmitRes".nii.gz -V | cut -d " " -f 1)" != "0" ]]
then
    removeroigrad "$smoothtemp".rAFI_3.nii.gz "$T1wFolder"/ROIs/ThalamusJunctionTemplate."$transmitRes".nii.gz "$T1wFolder"/Head."$transmitRes".nii.gz "$T1wFolder"/rAFI."$transmitRes".nii.gz
else
    cp "$smoothtemp".rAFI_3.nii.gz "$T1wFolder"/rAFI."$transmitRes".nii.gz
fi

#Resample Transmit Field
tempfiles_create rAFI_dil.XXXXXX.nii.gz resampletemp
wb_command -volume-dilate "$T1wFolder"/rAFI."$transmitRes".nii.gz 3 NEAREST "$resampletemp"
applywarp --interp=trilinear -i "$resampletemp" -r "$AtlasFolder"/AFI."$grayordRes".nii.gz -w "$AtlasFolder"/xfms/"$AtlasTransform".nii.gz -o "$AtlasFolder"/rAFI."$grayordRes".nii.gz
applywarp --interp=trilinear -i "$resampletemp" -r "$AtlasFolder"/AFI.nii.gz -w "$AtlasFolder"/xfms/"$AtlasTransform".nii.gz -o "$AtlasFolder"/rAFI.nii.gz
applywarp --interp=trilinear -i "$resampletemp" -r "$T1wFolder"/AFI.nii.gz -o "$T1wFolder"/rAFI.nii.gz

AFIAngleFormula="(180 / PI * acos(($TRtwo / $TRone * frametwo * $VolTwoCorrFac / frameone - 1) / ($TRtwo / $TRone - frametwo * $VolTwoCorrFac / frameone))) * MASK"
wb_command -volume-math "$AFIAngleFormula" "$T1wFolder"/rAFI."$transmitRes".nii.gz  -fixnan 0 \
    -var frameone "$T1wFolder"/rAFI."$transmitRes".nii.gz -subvolume 1 \
    -var frametwo "$T1wFolder"/rAFI."$transmitRes".nii.gz -subvolume 2 \
    -var MASK "$T1wFolder"/Head."$transmitRes".nii.gz
wb_command -volume-math "$AFIAngleFormula" "$AtlasFolder"/rAFI."$grayordRes".nii.gz -fixnan 0 \
    -var frameone "$AtlasFolder"/rAFI."$grayordRes".nii.gz -subvolume 1 \
    -var frametwo "$AtlasFolder"/rAFI."$grayordRes".nii.gz -subvolume 2 \
    -var MASK "$AtlasFolder"/Head."$grayordRes".nii.gz
wb_command -volume-math "$AFIAngleFormula" "$T1wFolder"/rAFI.nii.gz  -fixnan 0 \
    -var frameone "$T1wFolder"/rAFI.nii.gz -subvolume 1 \
    -var frametwo "$T1wFolder"/rAFI.nii.gz -subvolume 2 \
    -var MASK "$T1wFolder"/Head.nii.gz
wb_command -volume-math "$AFIAngleFormula" "$AtlasFolder"/rAFI.nii.gz  -fixnan 0 \
    -var frameone "$AtlasFolder"/rAFI.nii.gz -subvolume 1 \
    -var frametwo "$AtlasFolder"/rAFI.nii.gz -subvolume 2 \
    -var MASK "$AtlasFolder"/Head.nii.gz

#apply transmit field correction to surface
wb_command -volume-to-surface-mapping "$T1wFolder"/rAFI."$transmitRes".nii.gz "$T1wDownSampleFolder"/"$Subject".L.midthickness"$RegString"."$LowResMesh"k_fs_LR.surf.gii "$DownSampleFolder"/"$Subject".L.rAFI"$RegString"."$LowResMesh"k_fs_LR.func.gii \
    -ribbon-constrained "$T1wDownSampleFolder"/"$Subject".L.white"$RegString"."$LowResMesh"k_fs_LR.surf.gii "$T1wDownSampleFolder"/"$Subject".L.pial"$RegString"."$LowResMesh"k_fs_LR.surf.gii \
        -volume-roi "$T1wFolder"/ROIs/L_TransmitBias_ROI."$transmitRes".nii.gz
wb_command -volume-to-surface-mapping "$T1wFolder"/rAFI."$transmitRes".nii.gz "$T1wDownSampleFolder"/"$Subject".R.midthickness"$RegString"."$LowResMesh"k_fs_LR.surf.gii "$DownSampleFolder"/"$Subject".R.rAFI"$RegString"."$LowResMesh"k_fs_LR.func.gii \
    -ribbon-constrained "$T1wDownSampleFolder"/"$Subject".R.white"$RegString"."$LowResMesh"k_fs_LR.surf.gii "$T1wDownSampleFolder"/"$Subject".R.pial"$RegString"."$LowResMesh"k_fs_LR.surf.gii \
        -volume-roi "$T1wFolder"/ROIs/R_TransmitBias_ROI."$transmitRes".nii.gz
wb_command -cifti-create-dense-scalar "$DownSampleFolder"/"$Subject".rAFI"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii \
    -left-metric "$DownSampleFolder"/"$Subject".L.rAFI"$RegString"."$LowResMesh"k_fs_LR.func.gii \
        -roi-left "$DownSampleFolder"/"$Subject".L.atlasroi."$LowResMesh"k_fs_LR.shape.gii \
    -right-metric "$DownSampleFolder"/"$Subject".R.rAFI"$RegString"."$LowResMesh"k_fs_LR.func.gii \
        -roi-right "$DownSampleFolder"/"$Subject".R.atlasroi."$LowResMesh"k_fs_LR.shape.gii
wb_command -cifti-dilate "$DownSampleFolder"/"$Subject".rAFI"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii COLUMN 5 5 "$DownSampleFolder"/"$Subject".rAFI"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii \
    -left-surface "$T1wDownSampleFolder"/"$Subject".L.midthickness"$RegString"."$LowResMesh"k_fs_LR.surf.gii \
    -right-surface "$T1wDownSampleFolder"/"$Subject".R.midthickness"$RegString"."$LowResMesh"k_fs_LR.surf.gii

wb_command -cifti-math "myelin / ((transmit / $TargFlipAngle) * $Slope + (1 - $Slope))" "$DownSampleFolder"/"$Subject".MyelinMap_Corr"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii \
    -var myelin "$SubjectMyelin" \
    -var transmit "$DownSampleFolder"/"$Subject".rAFI"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii

function indvolToAtlas()
{
    indata="$1"
    volout="$2"
    tempfiles_create indvolToAtlas_XXXXXX.nii.gz masktemp
    tempfiles_add "$masktemp"_dilate.nii.gz
    wb_command -volume-math '(mask > 0) * data' "$masktemp" -var mask "$AtlasFolder"/GMWMTemplate.nii.gz -subvolume 1 -repeat -var data "$indata"
    wb_command -volume-dilate "$masktemp" 10 WEIGHTED "$masktemp"_dilate.nii.gz -data-roi "$GMWMtemplate"
    wb_command -volume-math '(mask > 0) * data' "$volout" -var mask "$GMWMtemplate" -subvolume 1 -repeat -var data "$masktemp"_dilate.nii.gz
}

#apply to volume

#receive field and T1wDiv... are handled in outer script

indvolToAtlas "$AtlasFolder"/rAFI.nii.gz "$AtlasFolder"/rAFI_Atlas.nii.gz

indvolToAtlas "$AtlasFolder"/AFI_orig.nii.gz "$AtlasFolder"/AFI_orig_Atlas.nii.gz

#this doesn't use VolTwoCorrFac because it is basically a phase 1 output, just didn't have the _Atlas mask for it until this script
tempfiles_create AFI_Atlastemp_XXXXXX.nii.gz afitemp
wb_command -volume-math "180 / PI * acos(($TRtwo / $TRone * frametwo / frameone - 1) / ($TRtwo / $TRone - frametwo / frameone))" "$afitemp" -fixnan 0 -var frameone "$AtlasFolder"/AFI_orig_Atlas.nii.gz -subvolume 1 -var frametwo "$AtlasFolder"/AFI_orig_Atlas.nii.gz -subvolume 2
wb_command -volume-dilate "$afitemp" 10 WEIGHTED "$AtlasFolder"/AFI_Atlas.nii.gz -data-roi "$GMWMtemplate"

AFICorrectionFormula="myelin / (transmit / $TargFlipAngle * $Slope + (1 - $Slope))"
wb_command -volume-math "$AFICorrectionFormula" "$AtlasFolder"/T1wDividedByT2w_Corr_Atlas.nii.gz -fixnan 0 \
    -var myelin "$AtlasFolder"/T1wDividedByT2w_Atlas.nii.gz \
    -var transmit "$AtlasFolder"/rAFI_Atlas.nii.gz
wb_command -volume-math "$AFICorrectionFormula * MASK" "$AtlasFolder"/T1wDividedByT2w_Corr.nii.gz -fixnan 0 \
    -var myelin "$AtlasFolder"/T1wDividedByT2w.nii.gz \
    -var transmit "$AtlasFolder"/rAFI.nii.gz \
    -var MASK "$AtlasFolder"/Head.nii.gz

wb_command -volume-math "$AFICorrectionFormula * MASK" "$T1wFolder"/T1wDividedByT2w_Corr.nii.gz -fixnan 0 \
    -var myelin "$NativeVolMyelin" \
    -var transmit "$T1wFolder"/rAFI.nii.gz \
    -var MASK "$T1wFolder"/Head.nii.gz

wb_command -volume-math 'myelin * (ribbon > 0)' "$T1wFolder"/T1wDividedByT2w_Corr_ribbon.nii.gz \
    -var myelin "$T1wFolder"/T1wDividedByT2w_Corr.nii.gz \
    -var ribbon "$T1wFolder"/T1wDividedByT2w_ribbon.nii.gz

tempfiles_create TransmitBias_findcsf_XXXXXX.nii.gz findcsf

#Regressor Generation
wb_command -volume-math "MASK * sqrt(T1w * T2w) / corrmyelin" "$findcsf" -fixnan 0 \
    -var corrmyelin "$AtlasFolder"/T1wDividedByT2w_Corr.nii.gz \
    -var T1w "$AtlasFolder"/T1w_restore.nii.gz \
    -var T2w "$AtlasFolder"/T2w_restore.nii.gz \
    -var MASK "$AtlasFolder"/Head.nii.gz
fslmaths "$findcsf" -thr $(fslstats "$findcsf" -P 99) -bin -mas "$AtlasFolder"/LateralVentricles.nii.gz "$AtlasFolder"/PureCSF.nii.gz

#use single call to fslstats, avoid repeated decompression
CSFRatioArgs=()
for ((i = 1; i < 100; ++i))
do
    CSFRatioArgs+=(-P "$i")
done
fslstats "$AtlasFolder"/T1wDividedByT2w_Corr.nii.gz -k "$AtlasFolder"/PureCSF.nii.gz "${CSFRatioArgs[@]}" | tr ' ' ',' > "$AtlasFolder"/AFI_CSFStats.txt

