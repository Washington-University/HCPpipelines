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

opts_SetScriptDescription "takes the T1w dicom and a cifti ROI file or surface vertex index, and creates a new T1w dicom with the ROI 'burned in' to the voxel values"

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject' 'Subject' 'subject ID' "(e.g. 100610)"
opts_AddMandatory '--dicom-input' 'DicomIn' 'path' "folder containing the original T1w dicom series, must be the first T1w input used in PreFreeSurfer"
opts_AddOptional '--dicom-series' 'DicomSeriesIn' 'series number' "if the folder contains multiple series, you must specify the DICOM series number of the appropriate T1w here"
opts_AddOptional '--grayordinates' 'Grayord' '91282' "the grayordinates cifti space the roi/vertex is based on, default 91282" '91282'
opts_AddMandatory '--surf-reg-name' 'RegName' 'MSMAll' "what surface registration to use"
opts_AddMandatory '--dicom-output' 'DicomOut' 'path' "location to write modified dicom series"
opts_AddOptional '--cifti-roi-in' 'roiIn' 'file' "cifti (dscalar) file containing the binary roi"
opts_AddOptional '--vertex-in' 'vertexIn' 'index' "specify a single vertex index (0-based) to draw an ROI from, requires --vertex-structure and uses the surface mesh implied by --grayordinates"
opts_AddOptional '--vertex-structure' 'vertexStruct' 'name' "specify what surface the vertex is in, currently supports CORTEX_LEFT or CORTEX_RIGHT"
opts_AddOptional '--vertex-radius' 'vertexDist' 'number' "a distance in mm around --vertex-in to include in the ROI, default 0 (just the vertex)" '0'
opts_AddOptional '--burn-value' 'outVal' 'number' "what value to overwrite in-ROI voxels with [default: 20% above voxelwise maximum]"
opts_AddOptional '--outline' 'outlineDist' 'distance' "use an outline with the given thickness in millimeters instead of occluding the ROI location"
opts_AddOptional '--outline-type' 'outlineType' 'name' "outline behavior, valid types:
INSIDE (default) - do not draw any voxels outside of the ROI, only make some of the ROI interior transparent
OUTSIDE - draw voxels outside the ROI and make the entire ROI transparent" 'INSIDE'

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

if [[ "$roiIn" == "" && "$vertexIn" == "" ]]
then
    log_Err_Abort "you must specify --cifti-roi-in or --vertex-in"
fi
if [[ "$vertexIn" != "" ]]
then
    if [[ "$roiIn" != "" ]]
    then
        log_Err_Abort "you must not specify both --cifti-roi-in and --vertex-in"
    fi
    #sanity check structure before warpfield stuff
    case "$vertexStruct" in
        (CORTEX_LEFT|CORTEX_RIGHT)
            ;;
        ("")
            log_Err_Abort "you must specify --vertex-structure when using --vertex-in"
            ;;
        (*)
            log_Err_Abort "unrecognized --vertex-structure specifier: $vertexStruct"
            ;;
    esac
fi

case "$Grayord" in
    (91282)
        #ciftiRes=2
        ciftiMesh=32
        ;;
    (170494)
        #ciftiRes=1.60
        ciftiMesh=59
        ;;
    (*)
        log_Err_Abort "unrecognized grayordinates space '$Grayord', use 91282 or 170494"
        ;;
esac

if [[ "$outlineDist" != "" ]]
then
    case "$outlineType" in
        (OUTSIDE|INSIDE)
            ;;
        (*)
            log_Err_Abort "unrecognized outline type '$outlineType', use 'INSIDE' or 'OUTSIDE'"
            ;;
    esac
fi

RegString=""
if [[ "$RegName" != "" && "$RegName" != "MSMSulc" ]]
then
    RegString="_$RegName"
fi

tempfiles_create ROIdicom_XXXXXX.nii.gz rawnifti

if [[ -f "$StudyFolder"/"$Subject"/T1w/AverageT1wImages ]]
then
    log_Err_Abort "subjects that used an average of multiple T1w images are not currently supported"
else
    acpcdcwarpfield="$StudyFolder"/"$Subject"/T1w/xfms/OrigT1w2T1w_PreFS.nii.gz
    gdcwarpfield="$StudyFolder"/"$Subject"/T1w/xfms/T1w1_gdc_warp.nii.gz
    
    fnirtarg="$StudyFolder"/"$Subject"/T1w/T1w1_gdc.nii.gz
    
    warpfield="$StudyFolder"/"$Subject"/T1w/xfms/raw_T1w1_to_T1w_PreFS.nii.gz
    
    if [[ -f "$gdcwarpfield" ]]
    then
        echo "Concatenating with gradient distortion warp field"
        convertwarp --rel --relout --ref="$StudyFolder/$Subject/T1w/T1w_acpc_dc_restore.nii.gz" --warp1="$gdcwarpfield" --warp2="$acpcdcwarpfield" --out="$warpfield"
    else
        #assume scanner-applied gdc
        cp "$acpcdcwarpfield" "$warpfield"
    fi
    
    echo "inverting the warp field"
    invwarpfield="$StudyFolder"/"$Subject"/T1w/xfms/T1w_PreFS_to_raw_T1w1.nii.gz
    downsampref="$rawnifti"_downsampref.nii.gz
    tempfiles_add "$downsampref"
    #invert at lower resolution for speed - readout and gradient distortion should be small changes, so 3mm is probably fine
    flirt -interp spline -in "$fnirtarg" -ref "$fnirtarg" -applyisoxfm 3 -out "$downsampref" -noresampblur
    invwarp -w "$warpfield" -o "$invwarpfield" -r "$downsampref"
fi

#due to "convert the whole folder" behavior, out filename arguments are unusual
rawbase=$(basename "${rawnifti%.nii.gz}")
rawfolder=$(dirname "$rawnifti")

#dcm2niix adds an "a" to the end of the name if the file exists, so we need to delete the empty file we made first
rm -f "$rawnifti"

#-x i keeps dicom voxel encoding order
dcmniicmd=(dcm2niix -z y -x i -b n -f "$rawbase" -o "$rawfolder")

if [[ "$DicomSeriesIn" != "" ]]
then
    #first matching volume is selected by default, in the case of several volumes per series
    echo "Sorting the input DICOM folder"
    series_crc=($(dcm2niix -o "$rawfolder" -n -1 -b n -f %s "$DicomIn" | \
        awk -v s="$DicomSeriesIn" '$1~/^[0-9]+([.][0-9]+)?$/{n=$NF;sub(/^.*\//,"",n);sub(/_.*/,"",n);if(n==s)print $1}'))
   if (( ${#series_crc[@]} == 0 ))
    then
        log_Err_Abort "could not find series $DicomSeriesIn in folder $DicomIn"
    fi
    dcmniicmd+=(-n "$series_crc")
else #determine the input series number to make the output series number
    echo "Reading the input DICOM folder"
    DicomSeriesIn=($(dcm2niix -o "$rawfolder" -n -1 -b n -f %s "$DicomIn" | \
        awk '$1~/^[0-9]+([.][0-9]+)?$/{sub(".*/","",$NF);sub("_.*","",$NF);print $NF}'))
    if [[ "${#DicomSeriesIn[@]}" != "1" ]]
    then
        log_Err_Abort "No DICOM series, or more than one found in folder $DicomIn"
    fi
fi

#must be the last argument
dcmniicmd+=("$DicomIn")

echo "${dcmniicmd[*]}"
"${dcmniicmd[@]}"

function warpSurface()
{
    surfType="$1"
    outName="$2"
    wb_command -surface-apply-warpfield \
        "$StudyFolder"/"$Subject"/T1w/fsaverage_LR"$ciftiMesh"k/"$Subject"."$surfType""$RegString"."$ciftiMesh"k_fs_LR.surf.gii \
        "$warpfield" \
        "$outName" \
        -fnirt "$fnirtarg"
}

if [[ "$roiIn" != "" ]]
then
    #cifti input
    mergeArgs=()

    for hem in L R
    do
        case "$hem" in
            (L)
                sepStruct=CORTEX_LEFT
                ;;
            (R)
                sepStruct=CORTEX_RIGHT
                ;;
        esac
        
        tempMetric="$rawnifti"_sep."$hem".func.gii
        tempfiles_add "$tempMetric"
        
        #support single-hemisphere cifti, etc
        if wb_command -cifti-separate "$roiIn" COLUMN \
            -metric "$sepStruct" "$tempMetric" &> /dev/null
        then
            tempMetricBin="$rawnifti"_sep_bin."$hem".func.gii
            tempWhite="$rawnifti"_white."$hem".surf.gii
            tempMid="$rawnifti"_midthickness."$hem".surf.gii
            tempPial="$rawnifti"_pial."$hem".surf.gii
            tempfiles_add "$tempMetricBin" "$tempWhite" "$tempMid" "$tempPial"
            
            warpSurface "$hem".white "$tempWhite"
            warpSurface "$hem".midthickness "$tempMid"
            warpSurface "$hem".pial "$tempPial"
            
            wb_command -metric-math 'x > 0' "$tempMetricBin" \
                -var x "$tempMetric"
            
            tempVol="$rawnifti"_"$hem".nii.gz
            tempVolBin="$rawnifti"_"$hem"_bin.nii.gz
            tempfiles_add "$tempVol" "$tempVolBin"
            
            wb_command -metric-to-volume-mapping \
                "$tempMetricBin" \
                "$tempMid" \
                "$rawnifti" \
                "$tempVol" \
                -ribbon-constrained \
                    "$tempWhite" \
                    "$tempPial"
            wb_command -volume-math 'x > 0.5' "$tempVolBin" \
                -var x "$tempVol"
            mergeArgs+=(-volume "$tempVolBin")
        fi
    done

    tempVol="$rawnifti"_sepVol.nii.gz
    tempfiles_add "$tempVol"

    #support surface-only cifti
    if wb_command -cifti-separate "$roiIn" COLUMN \
        -volume-all "$tempVol" &> /dev/null
    then
        tempVolBin="$rawnifti"_sepVol_bin.nii.gz
        tempVolResamp="$rawnifti"_sepVol_resamp.nii.gz
        tempVolResampBin="$rawnifti"_sepVol_resampBin.nii.gz
        tempfiles_add "$tempVolBin" "$tempVolResamp" "$tempVolResampBin"
        
        wb_command -volume-math 'x > 0' "$tempVolBin" \
            -var x "$tempVol"
        
        #voxels in cifti standard space are MNINonLinear, so reverse that warp first
        wb_command -volume-resample \
            "$tempVolBin" \
            "$rawnifti" \
            TRILINEAR \
            "$tempVolResamp" \
            -warp "$StudyFolder"/"$Subject"/MNINonLinear/xfms/standard2acpc_dc.nii.gz \
                -fnirt "$StudyFolder"/"$Subject"/MNINonLinear/T1w_restore.nii.gz \
            -warp "$invwarpfield" \
                -fnirt "$StudyFolder"/"$Subject"/T1w/T1w_acpc_dc_restore.nii.gz
        
        wb_command -volume-math 'x > 0.5' "$tempVolResampBin" \
            -var x "$tempVolResamp"
        mergeArgs+=(-volume "$tempVolResampBin")
    fi

    if ((${#mergeArgs[@]} == 0))
    then
        log_Err_Abort "unable to find cortical surface or volume brain models in input ROI"
    fi

    tempMerge="$rawnifti"_merge.nii.gz
    tempMergeMax="$rawnifti"_mergeMax.nii.gz
    tempfiles_add "$tempMerge" "$tempMergeMax"

    wb_command -volume-merge "$tempMerge" "${mergeArgs[@]}"
    wb_command -volume-reduce "$tempMerge" MAX "$tempMergeMax"

    roiFile="$tempMergeMax"
else
    #vertex index
    case "$vertexStruct" in
        (CORTEX_LEFT)
            hem=L
            ;;
        (CORTEX_RIGHT)
            hem=R
            ;;
    esac
    
    vertTxt="$rawnifti"_vertlist.txt
    tempVertMetric="$rawnifti"_vert.func.gii
    tempVertMetricDil="$rawnifti"_vertdil.func.gii
    tempWhite="$rawnifti"_white."$hem".surf.gii
    tempMid="$rawnifti"_midthickness."$hem".surf.gii
    tempPial="$rawnifti"_pial."$hem".surf.gii
    tempfiles_add "$vertTxt" "$tempVertMetric" "$tempVertMetricDil" "$tempWhite" "$tempMid" "$tempPial"
    
    warpSurface "$hem".white "$tempWhite"
    warpSurface "$hem".midthickness "$tempMid"
    warpSurface "$hem".pial "$tempPial"
    
    echo "$vertexIn" > "$vertTxt"
    #we don't know if the user has requested a smaller radius than the vertex spacing, so use dilation's "one neighbor minimum" to keep the roi centered-ish on the vertex
    #start with distance of 0 to get just the vertex
    wb_command -surface-geodesic-rois \
        "$StudyFolder"/"$Subject"/T1w/fsaverage_LR"$ciftiMesh"k/"$Subject"."$hem".midthickness"$RegString"."$ciftiMesh"k_fs_LR.surf.gii \
        0 \
        "$vertTxt" \
        "$tempVertMetric"
    
    if [[ $(echo "$vertexDist == 0" | bc) == 1* ]]
    then
        useMetric="$tempVertMetric"
    else
        useMetric="$tempVertMetricDil"
        #it's binary, so -nearest is faster and equivalent
        wb_command -metric-dilate \
            "$tempVertMetric" \
            "$StudyFolder"/"$Subject"/T1w/fsaverage_LR"$ciftiMesh"k/"$Subject"."$hem".midthickness"$RegString"."$ciftiMesh"k_fs_LR.surf.gii \
            "$vertexDist" \
            "$tempVertMetricDil" \
            -nearest
    fi
    tempVol="$rawnifti"_"$hem".nii.gz
    tempVolBin="$rawnifti"_"$hem"_bin.nii.gz
    tempfiles_add "$tempVol" "$tempVolBin"
    
    wb_command -metric-to-volume-mapping \
        "$useMetric" \
        "$tempMid" \
        "$rawnifti" \
        "$tempVol" \
        -ribbon-constrained \
            "$tempWhite" \
            "$tempPial"
    wb_command -volume-math 'x > 0.5' "$tempVolBin" \
        -var x "$tempVol"
    roiFile="$tempVolBin"
fi

if [[ "$outlineDist" != "" ]]
then
    case "$outlineType" in
        (INSIDE)
            tempMaxErode="$rawnifti"_mergeMaxErode.nii.gz
            tempMaxBorder="$rawnifti"_mergeMaxBorder.nii.gz
            tempfiles_add "$tempMaxErode" "$tempMaxBorder"

            wb_command -volume-erode \
                "$roiFile" \
                "$outlineDist" \
                "$tempMaxErode"
            wb_command -volume-math 'roi && ! erode' "$tempMaxBorder" \
                -var roi "$roiFile" \
                -var erode "$tempMaxErode"

            roiFile="$tempMaxBorder"
            ;;
        (OUTSIDE)
            tempMaxDilate="$rawnifti"_mergeMaxDil.nii.gz
            tempMaxBorder="$rawnifti"_mergeMaxBorder.nii.gz
            tempfiles_add "$tempMaxDilate" "$tempMaxBorder"

            wb_command -volume-dilate \
                "$roiFile" \
                "$outlineDist" \
                NEAREST \
                "$tempMaxDilate"
            wb_command -volume-math 'dil && ! roi' "$tempMaxBorder" \
                -var roi "$roiFile" \
                -var dil "$tempMaxDilate"

            roiFile="$tempMaxBorder"
            ;;
    esac
fi

if [[ "$outVal" == "" ]]
then
    maxVal=$(fslstats "$rawnifti" -R | cut -f2 -d' ')
    echo "maxVal: $maxVal"
    outVal=$(echo "$maxVal * 1.2" | bc -l)
    echo outVal: $outVal
fi

tempBurned="$rawnifti"_with_roi.nii.gz
tempfiles_add "$tempBurned"

wb_command -volume-math "(roi > 0) * $outVal + (!(roi > 0)) * orig" "$tempBurned" \
    -var roi "$roiFile" \
    -var orig "$rawnifti"

cmd=(python "$HCPPIPEDIR/global/scripts/nifti2dcm.py" \
    --series_description "T1w_with_ROI" \
    --input_series_number "$DicomSeriesIn" \
    --output_series_number "$DicomSeriesIn"001 \
    "$DicomIn" \
    "$tempBurned" \
    "$DicomOut"
)
echo "${cmd[*]}"
"${cmd[@]}"

