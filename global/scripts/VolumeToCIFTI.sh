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

opts_SetScriptDescription "make a cifti file using a subject-specific volume file"

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject' 'Subject' 'subject ID' "(e.g. 100610)"
opts_AddMandatory '--volume-in' 'VolIn' 'file' "the volume file to make a cifti version of"
opts_AddMandatory '--cifti-out' 'CiftiOut' 'file' "the output cifti file name"
opts_AddMandatory '--surf-reg-name' 'RegName' 'MSMAll' "what surface registration to use"

#main options
opts_AddOptional '--volume-space' 'volspace' 'MNINonLinear' "what volume space the input volume file is aligned with, default MNINonLinear, also supports T1w" 'MNINonLinear'
opts_AddOptional '--fix-zeros' 'fzdil' 'number' "dilation distance to use to try to eliminate zero values, even if they are present in the input data"
opts_AddOptional '--good-voxels' 'goodvox' 'file' "specify an roi of what voxels can be used for cortex"
opts_AddOptional '--smoothing' 'smoothfwhm' 'number' "what kernel size in mm FWHM to smooth the data by (per subcortical parcel before volume resampling, after adaptive barycentric surface resampling), default no smoothing"
opts_AddOptional '--grayordinates' 'Grayord' '91282' "the grayordinates cifti space to use, default 91282" '91282'

#implementation details
opts_AddOptional '--surface-dilate' 'surfdil' 'number' "how far in mm to dilate the surface data to fix only ribbon-constrained 'missed' vertices and locations excluded by --good-voxels (leaving other zero values alone), default 1" '1'
opts_AddOptional '--volume-dilate' 'voldil' 'number' "how much dilation to use in the volume to reduce edge effects (leaving other zero values alone), default 5" '5'

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

opts_ShowValues

#consider putting a config file in the grayordinates folders containing these values, so they don't need to be hardcoded here
#we don't have a grayordinates space using 164k yet, so we don't need to special case the resampled anatomical surface locations for that
case "$Grayord" in
    (91282)
        outRes=2
        outMesh=32
        ;;
    (170494)
        outRes=1.60
        outMesh=59
        ;;
    (*)
        log_Err_Abort "unrecognized grayordinates space '$Grayord', use 91282 or 170494"
        ;;
esac

case "$volspace" in
    (MNINonLinear)
        warpfield=""
        curbrainmask="$StudyFolder"/"$Subject"/MNINonLinear/T1w_restore_brain.nii.gz
        ;;
    (T1w)
        warpfield="$StudyFolder"/"$Subject"/MNINonLinear/xfms/acpc_dc2standard.nii.gz
        curbrainmask="$StudyFolder"/"$Subject"/T1w/T1w_acpc_dc_restore_brain.nii.gz
        ;;
    (*)
        log_Err_Abort "unrecognized volume space '$volspace', use MNINonLinear or T1w"
        ;;
esac

case "$RegName" in
    (MSMSulc|NONE|'')
        #these all mean the same thing, set registered surface naming here
        #assume we don't need to handle MSMSulcStrain
        RegName="MSMSulc"
        RegString=""
        ;;
    (*)
        RegString="_$RegName"
        #not an error, expect everything else to have regular names
        ;;
esac

function mapToSurf()
{
    input="$1"
    whitesurf="$2"
    midsurf="$3"
    pialsurf="$4"
    hem="$5"
    regNativeSphere="$6"
    atlasSphere="$7"
    giiout="$8"
    
    tempfiles_create volToCifti_toSurf_XXXXXX.func.gii tempgii
    tempfiles_add "$tempgii"_badverts.func.gii "$tempgii"_dil.func.gii
    mapcmd=(wb_command -volume-to-surface-mapping "$input" "$midsurf" "$tempgii" \
                -ribbon-constrained "$whitesurf" "$pialsurf" \
                    -bad-vertices-out "$tempgii"_badverts.func.gii)
    if [[ "$goodvox" != "" ]]
    then
        mapcmd+=(-volume-roi "$goodvox")
    fi
    "${mapcmd[@]}"
    
    if [[ "$fzdil" == "" ]]
    then
        wb_command -metric-dilate "$tempgii" "$midsurf" "$surfdil" "$tempgii"_dil.func.gii \
            -bad-vertex-roi "$tempgii"_badverts.func.gii \
            -data-roi "$StudyFolder"/"$Subject"/MNINonLinear/Native/"$Subject"."$hem".roi.native.shape.gii
    else
        #in fix zeros mode, rely on ribbon mapping bad vertices also being zero
        totaldil=$(bc -l <<<"$surfdil + $fzdil")
        wb_command -metric-dilate "$tempgii" "$midsurf" "$totaldil" "$tempgii"_dil.func.gii \
            -data-roi "$StudyFolder"/"$Subject"/MNINonLinear/Native/"$Subject"."$hem".roi.native.shape.gii
    fi
    
    nativeT1wMidthick="$StudyFolder"/"$Subject"/T1w/Native/"$Subject"."$hem".midthickness.native.surf.gii
    downsampT1wMidthick="$StudyFolder"/"$Subject"/T1w/fsaverage_LR"$outMesh"k/"$Subject"."$hem".midthickness"$RegString"."$outMesh"k_fs_LR.surf.gii
    if [[ ! -f "$downsampT1wMidthick" ]]
    then
        #don't create files/folders in the subject folder the user didn't ask for, make a temporary
        tempfiles_create volToCifti_toSurf_downsampMidthick_"$hem"_XXXXXX.surf.gii downsampT1wMidthick
        wb_command -surface-resample "$nativeT1wMidthick" "$regNativeSphere" "$atlasSphere" BARYCENTRIC "$downsampT1wMidthick"
    fi
    if [[ "$smoothfwhm" == "" ]]
    then
        wb_command -metric-resample "$tempgii"_dil.func.gii "$regNativeSphere" "$atlasSphere" ADAP_BARY_AREA "$giiout" \
            -area-surfs "$nativeT1wMidthick" "$downsampT1wMidthick" \
            -current-roi "$StudyFolder"/"$Subject"/MNINonLinear/Native/"$Subject"."$hem".roi.native.shape.gii
    else
        tempfiles_add "$tempgii"_resample.func.gii
        wb_command -metric-resample "$tempgii"_dil.func.gii "$regNativeSphere" "$atlasSphere" ADAP_BARY_AREA "$tempgii"_resample.func.gii \
            -area-surfs "$nativeT1wMidthick" "$downsampT1wMidthick" \
            -current-roi "$StudyFolder"/"$Subject"/MNINonLinear/Native/"$Subject"."$hem".roi.native.shape.gii
        smoothcmd=(wb_command -metric-smoothing "$downsampT1wMidthick" "$tempgii"_resample.func.gii "$smoothfwhm" -fwhm "$giiout")
        if [[ "$fzdil" != "" ]]
        then
            smoothcmd+=(-fix-zeros)
        fi
        "${smoothcmd[@]}"
    fi
}

VolUse="$VolIn"
if [[ "$fzdil" != "" ]]
then
    tempfiles_create volToCifti_fixzeros_XXXXXX.nii.gz fztemp
    tempfiles_add "$fztemp"_brainmask.nii.gz
    #make a loose brain mask so dilate can be fast
    wb_command -volume-resample "$curbrainmask" "$VolIn" TRILINEAR "$fztemp"_brainmask.nii.gz
    wb_command -volume-dilate "$VolIn" "$fzdil" WEIGHTED "$fztemp" -data-roi "$fztemp"_brainmask.nii.gz
    VolUse="$fztemp"
fi

tempfiles_create volToCifti_left_XXXXXX.func.gii lefttemp
tempfiles_create volToCifti_right_XXXXXX.func.gii righttemp

for hem in L R
do
    if [[ "$hem" == "L" ]]
    then
        thistemp="$lefttemp"
    else
        thistemp="$righttemp"
    fi
    mapToSurf "$VolUse" \
        "$StudyFolder"/"$Subject"/"$volspace"/Native/"$Subject"."$hem".white.native.surf.gii \
        "$StudyFolder"/"$Subject"/"$volspace"/Native/"$Subject"."$hem".midthickness.native.surf.gii \
        "$StudyFolder"/"$Subject"/"$volspace"/Native/"$Subject"."$hem".pial.native.surf.gii \
        "$hem" \
        "$StudyFolder"/"$Subject"/MNINonLinear/Native/"$Subject"."$hem".sphere."$RegName".native.surf.gii \
        "$HCPPIPEDIR"/global/templates/standard_mesh_atlases/"$hem".sphere."$outMesh"k_fs_LR.surf.gii \
        "$thistemp"
done

tempfiles_create volToCifti_ROIs_resample_XXXXXX.nii.gz tempROIs
tempfiles_add "$tempROIs"_label.nii.gz "$tempROIs"_subcortdata.dscalar.nii "$tempROIs"_resampled.dscalar.nii
wb_command -volume-resample "$StudyFolder"/"$Subject"/"$volspace"/wmparc.nii.gz "$VolUse" ENCLOSING_VOXEL "$tempROIs"
wb_command -volume-label-import "$tempROIs" "$HCPPIPEDIR_Config"/FreeSurferSubcorticalLabelTableLut.txt "$tempROIs"_label.nii.gz -discard-others
wb_command -cifti-create-dense-scalar "$tempROIs"_subcortdata.dscalar.nii -volume "$VolUse" "$tempROIs"_label.nii.gz

tempfiles_create volToCifti_atlasSubcort_XXXXXX.dlabel.nii tempAtlasSubcort
wb_command -cifti-create-label "$tempAtlasSubcort" -volume "$HCPPIPEDIR"/global/templates/"$Grayord"_Greyordinates/Atlas_ROIs."$outRes".nii.gz "$HCPPIPEDIR"/global/templates/"$Grayord"_Greyordinates/Atlas_ROIs."$outRes".nii.gz

#don't use goodvox in subcortical, our existing one excludes a majority of some structures
resampinput="$tempROIs"_subcortdata.dscalar.nii
if [[ "$smoothfwhm" != "" ]]
then
    tempfiles_add "$tempROIs"_smoothed.dscalar.nii
    #ignore the surface arguments here, there is no surface data in this input
    smoothcmd=(wb_command -cifti-smoothing "$tempROIs"_subcortdata.dscalar.nii "$smoothfwhm" "$smoothfwhm" -fwhm COLUMN "$tempROIs"_smoothed.dscalar.nii)
    if [[ "$fzdil" != "" ]]
    then
        smoothcmd+=(-fix-zeros-volume)
    fi
    "${smoothcmd[@]}"
    resampinput="$tempROIs"_smoothed.dscalar.nii
fi

resampcmd=(wb_command -cifti-resample "$resampinput" COLUMN "$tempAtlasSubcort" COLUMN BARYCENTRIC CUBIC "$tempROIs"_resampled.dscalar.nii -volume-predilate "$voldil")
if [[ "$warpfield" != "" ]]
then
    resampcmd+=(-warpfield "$warpfield" -fnirt "$StudyFolder"/"$Subject"/T1w/T1w_acpc_dc_restore.nii.gz)
fi
"${resampcmd[@]}"

#subcortical overlap issues could create some zeros, so dilate again after resampling
usesubcort="$tempROIs"_resampled.dscalar.nii
if [[ "$fzdil" != "" ]]
then
    tempfiles_add "$tempROIs"_resampled_dil.dscalar.nii
    wb_command -cifti-dilate "$tempROIs"_resampled.dscalar.nii COLUMN 0 "$fzdil" "$tempROIs"_resampled_dil.dscalar.nii
    usesubcort="$tempROIs"_resampled_dil.dscalar.nii
fi

createcmd=(wb_command -cifti-create-dense-from-template "$HCPPIPEDIR"/global/templates/"$Grayord"_Greyordinates/"$Grayord"_Greyordinates.dscalar.nii "$CiftiOut" \
    -cifti "$usesubcort" \
    -metric CORTEX_LEFT "$lefttemp" \
    -metric CORTEX_RIGHT "$righttemp")
if [[ "$CiftiOut" == *.dtseries.nii ]]
then
    step=$(fslval "$VolIn" pixdim4 | tr -d ' ')
    createcmd+=(-series "$step" 0)
fi
"${createcmd[@]}"

