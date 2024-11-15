#!/bin/bash
set -euE

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/tempfiles.shlib" "$@"

opts_SetScriptDescription "calculate the receive bias field for a scanner

Use either --bodycoil and --headcoil together, or --psn-image and --nopsn-image together.
Inputs must be in scanner space."

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject' 'Subject' 'subject ID' "(e.g. 100610)"
opts_AddOptional '--workingdir' 'WD' 'folder' "where to put intermediate files"
opts_AddMandatory '--transmit-res' 'transmitRes' 'number' "resolution to use for transmit field"
opts_AddOptional '--scanner-grad-coeffs' 'GradientDistortionCoeffs' 'file' "Siemens gradient coefficients file"
opts_AddOptional '--bodycoil' 'bodycoil' 'image' "body coil image, requires --headcoil"
opts_AddOptional '--headcoil' 'headcoil' 'image' "head coil image with matching contrast to --bodycoil"
opts_AddOptional '--psn-t1w-image' 'psnimage' 'image' "image with PSN correction, requires --nopsn-image"
opts_AddOptional '--nopsn-t1w-image' 'nopsnimage' 'image' "same image as --psn-image, but without PSN correction applied"
opts_AddMandatory '--unproc-t1w-list' 'T1wunprocstr' 'image1@image2...' "list of non-PSN T1w images"
opts_AddMandatory '--unproc-t2w-list' 'T2wunprocstr' 'image1@image2...' "list of non-PSN T2w images"
opts_AddOptional '--low-res-mesh' 'LowResMesh' 'number' "resolution of grayordinates mesh for --myelin-surface-correction-out, default '32'" '32'
opts_AddOptional '--reg-name' 'RegName' 'string' "surface registration to use, default MSMAll" 'MSMAll'
opts_AddMandatory '--bias-image-out' 'biasout' 'filename' "output - what file to write the bias field image to"
opts_AddMandatory '--myelin-correction-field-out' 'myelinbiasout' 'filename' "output - correction factor to divide previous myelin volume data by"
opts_AddOptional '--t1w-corrected-out' 't1avgout' 'filename' "output - corrected average T1w image"
opts_AddOptional '--t2w-corrected-out' 't2avgout' 'filename' "output - corrected average T2w image"
opts_AddOptional '--myelin-surface-correction-out' 'myelinsurfbiasout' 'cifti' "output - correction factor to divide previous myelin surface data by"

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

IFS=' @' read -a T1wunprocarray <<<"$T1wunprocstr"
IFS=' @' read -a T2wunprocarray <<<"$T2wunprocstr"

if [[ "$bodycoil" != "" && "$psnimage" != "" ]]
then
    log_Err_Abort "specify only one of --bodycoil or --psn-image"
fi

if [[ "$bodycoil" == "" && "$psnimage" == "" ]]
then
    log_Err_Abort "no bias-corrected input image specified"
fi

if [[ "$bodycoil" != "" && "$headcoil" == "" ]]
then
    log_Err_Abort "--bodycoil option requires also specifying --headcoil"
fi

if [[ "$psnimage" != "" && "$nopsnimage" == "" ]]
then
    log_Err_Abort "--psn-image option requires also specifying --nopsn-image"
fi

T1wFolder="$StudyFolder"/"$Subject"/T1w
T1wDownSampleFolder="$T1wFolder"/fsaverage_LR"$LowResMesh"k

#only used for DownSampleFolder
AtlasFolder="$StudyFolder/$Subject"/MNINonLinear
#only used for cifti ROIs
DownSampleFolder="$AtlasFolder"/fsaverage_LR"$LowResMesh"k

if [[ "$WD" == "" ]]
then
    WD="$T1wFolder"/CalculateReceiveField
fi

mkdir -p "$WD"/xfms

if [[ "$RegName" == "" || "$RegName" == "MSMSulc" ]]
then
    RegString=""
else
    RegString="_$RegName"
fi

#assume the gradunwarp displacements don't change per image (since it doesn't take in any scan timing parameters)
#would make sense if they don't, being a local but static multiplicative factor on each encoding gradient strength
gradxfmargs=()
if [[ "$GradientDistortionCoeffs" != "" ]]
then
    image="$headcoil"
    if [[ "$image" == "" ]]
    then
        image="$psnimage"
    fi
    #we need to use this file to deal with the fnirt coordinate conventions, so copy it to a standard name
    cp "$image" "$WD"/gradunwarpin.nii.gz
    "$HCPPIPEDIR"/global/scripts/GradientDistortionUnwarp.sh \
        --workingdir="$WD"/gradunwarp \
        --coeffs="$GradientDistortionCoeffs" \
        --in="$WD"/gradunwarpin.nii.gz \
        --out="$WD"/gradunwarpout.nii.gz \
        --owarp="$WD"/gradunwarpfield.nii.gz
    
    gradxfmargs=(-warp "$WD"/gradunwarpfield.nii.gz -fnirt "$WD"/gradunwarpin.nii.gz)
fi

if [[ "$bodycoil" != "" ]]
then
    #paraphrased from AFI
    if [[ "$GradientDistortionCoeffs" != "" ]]
    then
        wb_command -volume-resample "$bodycoil" "$bodycoil" CUBIC "$WD"/bodycoil.nii.gz "${gradxfmargs[@]}"
        wb_command -volume-resample "$headcoil" "$headcoil" CUBIC "$WD"/headcoil.nii.gz "${gradxfmargs[@]}"
    else
        cp "$bodycoil" "$WD"/bodycoil.nii.gz
        cp "$headcoil" "$WD"/headcoil.nii.gz
    fi
    
    "$HCPPIPEDIR"/global/scripts/bbregister.sh --study-folder="$StudyFolder" --subject="$Subject" \
        --input-image="$WD"/bodycoil.nii.gz \
        --init-target-image="$T1wFolder"/T1w_acpc_dc_restore.nii.gz \
        --contrast-type=T1w \
        --surface-name=pial.deformed \
        --output-xfm="$WD"/xfms/bodycoil2str.mat \
        --output-inverse-xfm="$WD"/xfms/str2bodycoil.mat \
        --output-image="$WD"/bodycoil2T1w.nii.gz \
        --bbregister-regfile-out="$WD"/bodycoil_bbregister.dat
    
    #head coil used old receive bias, presumably because it was in the same loop as the T1w in the old code, which we wanted to match the alignment of the previous myelin code
    #don't have new bias field yet, so use the old one
    "$HCPPIPEDIR"/global/scripts/bbregister.sh --study-folder="$StudyFolder" --subject="$Subject" \
        --input-image="$WD"/headcoil.nii.gz \
        --init-target-image="$T1wFolder"/T1w_acpc_dc.nii.gz \
        --contrast-type=T1w \
        --surface-name=pial.deformed \
        --old-receive-bias="$T1wFolder"/BiasField_acpc_dc.nii.gz \
        --output-xfm="$WD"/xfms/headcoil2str.mat \
        --output-inverse-xfm="$WD"/xfms/str2headcoil.mat \
        --output-image="$WD"/headcoil_restore2T1w.nii.gz \
        --bbregister-regfile-out="$WD"/headcoil_bbregister.dat

    #create a refspace at the expected resolution, so we don't have a weird difference compared to the psn method
    #NOTE: may be oblique
    tempfiles_create receivebias_refspace_XXXXXX.nii.gz refspace
    flirt -in "$WD"/headcoil.nii.gz -ref "$WD"/headcoil.nii.gz -applyisoxfm "$transmitRes" -out "$refspace"
    
    wb_command -volume-resample "$WD"/headcoil.nii.gz "$refspace" CUBIC "$WD"/headcoil."$transmitRes".nii.gz

    convert_xfm -omat "$WD"/xfms/bodycoil2headcoil.mat -concat "$WD"/xfms/str2headcoil.mat "$WD"/xfms/bodycoil2str.mat
    
    #NOTE: bodycoil.nii.gz and headcoil.nii.gz already have gdc warp applied
    wb_command -volume-resample "$WD"/bodycoil.nii.gz "$refspace" CUBIC "$WD"/bodycoil2headcoil."$transmitRes".nii.gz \
        -affine "$WD"/xfms/bodycoil2headcoil.mat \
            -flirt "$WD"/bodycoil.nii.gz "$WD"/headcoil.nii.gz
    
    tempfiles_create brainmask_trilin_XXXXXX.nii.gz brainlin
    wb_command -volume-resample "$T1wFolder"/brainmask_fs.nii.gz "$refspace" TRILINEAR "$brainlin" \
        -affine "$WD"/xfms/str2headcoil.mat \
            -flirt "$T1wFolder"/T1w_acpc_dc.nii.gz "$WD"/headcoil.nii.gz
    wb_command -volume-math 'x > 0.5' "$WD"/brainmask_fs."$transmitRes".nii.gz -var x "$brainlin"
    
    #NOTE: need to do create ROIs before this script, because of Head.nii.gz
    tempfiles_create Head_trilin_XXXXXX.nii.gz headlin
    wb_command -volume-resample "$T1wFolder"/Head.nii.gz "$refspace" TRILINEAR "$headlin" \
        -affine "$WD"/xfms/str2headcoil.mat \
            -flirt "$T1wFolder"/T1w_acpc_dc.nii.gz "$WD"/headcoil.nii.gz
    wb_command -volume-math 'x > 0.5' "$WD"/Head."$transmitRes".nii.gz -var x "$headlin"
    
    #8mm fwhm is for YA, we don't expect other data using non-PSN with head+body coil acquisition
    #so, this probably doesn't need to be adjustable
    wb_command -volume-smoothing "$WD"/headcoil."$transmitRes".nii.gz 8 -fwhm "$WD"/headcoil_smooth."$transmitRes".nii.gz -roi "$WD"/brainmask_fs."$transmitRes".nii.gz
    wb_command -volume-smoothing "$WD"/bodycoil2headcoil."$transmitRes".nii.gz 8 -fwhm "$WD"/bodycoil2headcoil_smooth."$transmitRes".nii.gz -roi "$WD"/brainmask_fs."$transmitRes".nii.gz
    
    wb_command -volume-math 'headcoil / bodycoil' "$WD"/ReceiveField_mas."$transmitRes".nii.gz -fixnan 0 \
        -var headcoil "$WD"/headcoil_smooth."$transmitRes".nii.gz \
        -var bodycoil "$WD"/bodycoil2headcoil_smooth."$transmitRes".nii.gz
    wb_command -volume-dilate "$WD"/ReceiveField_mas."$transmitRes".nii.gz 60 WEIGHTED "$WD"/ReceiveField_dilhead."$transmitRes".nii.gz -grad-extrapolate \
        -data-roi "$WD"/Head."$transmitRes".nii.gz
    fslmaths "$WD"/ReceiveField_dilhead."$transmitRes".nii.gz -dilall "$WD"/ReceiveField_dilall."$transmitRes".nii.gz
    mean=$(fslstats "$WD"/ReceiveField_dilall."$transmitRes".nii.gz -n -k "$WD"/Head."$transmitRes".nii.gz -M)
    wb_command -volume-math "clamp(field / $mean, 0.1, 10)" "$biasout" -fixnan 1 \
        -var field "$WD"/ReceiveField_dilall."$transmitRes".nii.gz
else
    #the psn/nopsn images should already be aligned to each other, and in scanner space, but we do need a registration to get the brain/head masks positioned correctly
    if [[ "$GradientDistortionCoeffs" != "" ]]
    then
        wb_command -volume-resample "$psnimage" "$psnimage" CUBIC "$WD"/psnimage.nii.gz "${gradxfmargs[@]}"
        wb_command -volume-resample "$nopsnimage" "$nopsnimage" CUBIC "$WD"/nopsnimage.nii.gz "${gradxfmargs[@]}"
    else
        cp "$psnimage" "$WD"/psnimage.nii.gz
        cp "$nopsnimage" "$WD"/nopsnimage.nii.gz
    fi
    
    "$HCPPIPEDIR"/global/scripts/bbregister.sh --study-folder="$StudyFolder" --subject="$Subject" \
        --input-image="$WD"/psnimage.nii.gz \
        --init-target-image="$T1wFolder"/T1w_acpc_dc_restore.nii.gz \
        --contrast-type=T1w \
        --surface-name=white.deformed \
        --output-xfm="$WD"/xfms/psnimage2str.mat \
        --output-inverse-xfm="$WD"/xfms/str2psnimage.mat \
        --output-image="$WD"/psnimage2T1w.nii.gz \
        --bbregister-regfile-out="$WD"/psnimage_bbregister.dat
    
    #create a downsampled space (NOTE: not present in original head/body pair code, which used the headcoil image resolution, which was already 2mm, though oblique)
    #maybe make this based on T1w space, rather than PSN grid (who knows, might be oblique), under the assumption that scanner space fits the brain somewhere into the MNI FoV?
    tempfiles_create receivebias_refspace_XXXXXX.nii.gz refspace
    flirt -in "$WD"/psnimage.nii.gz -ref "$WD"/psnimage.nii.gz -applyisoxfm "$transmitRes" -out "$refspace"
    
    xfmargs=(-affine "$WD"/xfms/str2psnimage.mat -flirt "$T1wFolder"/T1w_acpc_dc.nii.gz "$WD"/psnimage.nii.gz)
    
    tempfiles_create brainmask_trilin_XXXXXX.nii.gz brainlin
    wb_command -volume-resample "$T1wFolder"/brainmask_fs.nii.gz "$refspace" TRILINEAR "$brainlin" "${xfmargs[@]}"
    wb_command -volume-math 'x > 0.5' "$WD"/brainmask_fs."$transmitRes".nii.gz -var x "$brainlin"
    
    #NOTE: need to do create ROIs before this script, because of Head.nii.gz
    tempfiles_create Head_trilin_XXXXXX.nii.gz headlin
    wb_command -volume-resample "$T1wFolder"/Head.nii.gz "$refspace" TRILINEAR "$headlin" "${xfmargs[@]}"
    wb_command -volume-math 'x > 0.5' "$WD"/Head.nii.gz -var x "$headlin"
    
    #NOTE: don't use BBR transform, that was just to move the masks into scanner space
    #but, we can use the gradunwarp xfm to do a one step resample to low res
    wb_command -volume-resample "$psnimage" "$refspace" CUBIC "$WD"/psnimage."$transmitRes".nii.gz ${gradxfmargs[@]+"${gradxfmargs[@]}"}
    wb_command -volume-resample "$nopsnimage" "$refspace" CUBIC "$WD"/nopsnimage."$transmitRes".nii.gz ${gradxfmargs[@]+"${gradxfmargs[@]}"}
    
    wb_command -volume-math '(mask > 0) * nopsn / psn' "$WD"/ReceiveField_mas.nii.gz -fixnan 0 \
        -var nopsn "$WD"/nopsnimage."$transmitRes".nii.gz \
        -var psn "$WD"/psnimage."$transmitRes".nii.gz \
        -var mask "$WD"/brainmask_fs."$transmitRes".nii.gz
    
    wb_command -volume-dilate "$WD"/ReceiveField_mas.nii.gz 60 WEIGHTED "$WD"/ReceiveField_dilhead.nii.gz -grad-extrapolate \
        -data-roi "$WD"/Head.nii.gz
    fslmaths "$WD"/ReceiveField_dilhead.nii.gz -dilall "$WD"/ReceiveField_dilall.nii.gz
    mean=$(fslstats "$WD"/ReceiveField_dilall.nii.gz -n -k "$WD"/Head.nii.gz -M)
    wb_command -volume-math "clamp(field / $mean, 0.1, 10)" "$biasout" -fixnan 1 \
        -var field "$WD"/ReceiveField_dilall.nii.gz
fi

#Find T1w and T2w scans and reorient and align them, so we can create moved copies of the receive field, to estimate the error in the current T1wDiv... and derived MyelinMap files

function ReorientBBRandBCAvg()
{
    #args: contrast, avgbiasout, avgbcout, inputs...
    local contrast="$1"
    local avgbiasout="$2"
    local avgbcout="$3"
    shift 3
    
    #the header carries through GradientDistortionUnwarp.sh, so fix it here first
    local -a namelist=()
    local i
    for ((i = 1; i <= $#; ++i))
    do
        if [[ -f "${!i}" ]]
        then
            tempfiles_create "$contrast$i"_reorient_XXXXXX.nii.gz tempreorient
            wb_command -volume-reorient "${!i}" RPI "$tempreorient"
            wb_command -volume-resample "$tempreorient" "$tempreorient" CUBIC "$WD"/"$contrast$i"_dc.nii.gz "${gradxfmargs[@]}"
            namelist+=("$contrast$i")
        else
            log_Warn "$contrast image '${!i}' not found"
        fi
    done
    if ((${#namelist[@]} < 1))
    then
        log_Err_Abort "no $contrast images found"
    fi
    
    local -a biasargs=()
    local -a bcargs=()
    for name in "${namelist[@]}"
    do
        #apply the new receive bias to the input image - bbr would probably work fine without it, but why not
        tempfiles_create ReceiveField_rawbias_XXXXXX.nii.gz rawbias
        tempfiles_add "$rawbias"_inputRC.nii.gz
        wb_command -volume-resample "$biasout" \
            "$WD"/"$name"_dc.nii.gz CUBIC "$rawbias"
        wb_command -volume-math 'x / (receive + (receive == 0))' "$rawbias"_inputRC.nii.gz \
            -var x "$WD"/"$name"_dc.nii.gz \
            -var receive "$rawbias"
        
        #NOTE: bbr output mat convention is always "input" to "T1w/T1w_acpc_dc", hardcoded
        #output image uses --init-target-image as the reference space
        "$HCPPIPEDIR"/global/scripts/bbregister.sh --study-folder="$StudyFolder" --subject="$Subject" \
            --input-image="$rawbias"_inputRC.nii.gz \
            --init-target-image="$T1wFolder"/"$contrast"_acpc_dc_restore.nii.gz \
            --contrast-type="$contrast" \
            --surface-name=white.deformed \
            --output-xfm="$WD"/xfms/"$name"2str.mat \
            --output-inverse-xfm="$WD"/xfms/str2"$name".mat \
            --output-image="$WD"/"$name"2T1w.nii.gz \
            --bbregister-regfile-out="$WD"/"$name"_bbregister.dat
        
        #bias field already has gdc, if coefficients provided
        #could resample to lowres space instead
        #original code computes in lowres and upsamples to structural at the end...
        tempfiles_create ReceiveField_biasresamp_XXXXXX.nii.gz biasresamp
        wb_command -volume-resample "$biasout" "$T1wFolder"/"$contrast"_acpc_dc.nii.gz CUBIC "$biasresamp" \
            -affine "$WD"/xfms/"$name"2str.mat \
                -flirt "$WD"/"$name"_dc.nii.gz "$T1wFolder"/T1w_acpc_dc.nii.gz
        #dilall to fix FoV mismatches
        fslmaths "$biasresamp" -dilall "$WD"/"$name"2T1w_bias.nii.gz
        biasargs+=(-volume "$WD"/"$name"2T1w_bias.nii.gz)
        
        if [[ "$avgbcout" != "" ]]
        then
            #avoid divide by zero, then zero output where it would have
            wb_command -volume-math '(bias != 0) * data / (bias + (bias == 0))' "$WD"/"$name"2T1w_restore.nii.gz \
                -var data "$WD"/"$name"2T1w.nii.gz \
                -var bias "$WD"/"$name"2T1w_bias.nii.gz
            bcargs+=(-volume "$WD"/"$name"2T1w_restore.nii.gz)
        fi
    done
    
    tempfiles_create ReceiveField_all"$contrast"2str_bias_XXXXXX.nii.gz allbias
    wb_command -volume-merge "$allbias" "${biasargs[@]}"
    wb_command -volume-reduce "$allbias" MEAN "$avgbiasout"

    if [[ "$avgbcout" != "" ]]
    then
        tempfiles_create all"$contrast"2str_bc_XXXXXX.nii.gz allbc
        wb_command -volume-merge "$allbc" "${bcargs[@]}"
        wb_command -volume-reduce "$allbc" MEAN "$avgbcout"
        
        unset allbc
    fi
    
    unset allbias
}

#empty string for corrected image means it doesn't compute it
ReorientBBRandBCAvg T1w "$WD"/avgt1w2str_bias.nii.gz "$t1avgout" "${T1wunprocarray[@]}"
ReorientBBRandBCAvg T2w "$WD"/avgt2w2str_bias.nii.gz "$t2avgout" "${T2wunprocarray[@]}"

#original code used only the bias field for the correction, not the corrected images

wb_command -volume-math 'clamp(t1bias / t2bias, 0.1, 10)' "$myelinbiasout" \
    -var t1bias "$WD"/avgt1w2str_bias.nii.gz \
    -var t2bias "$WD"/avgt2w2str_bias.nii.gz \
    -fixnan 1

if [[ "$myelinsurfbiasout" != "" ]]
then
    #TSC: this lowres T1w in the T1w folder is created by CreateTransmitBiasROIs
    wb_command -volume-resample "$myelinbiasout" "$T1wFolder"/T1w_acpc_dc_restore."$transmitRes".nii.gz TRILINEAR "$WD"/ReceiveFieldCorrection."$transmitRes".nii.gz
    
    #approximate the surface effect of the receive correction on the previous myelin maps - receive field is smooth, so method doesn't matter much
    wb_command -volume-to-surface-mapping "$WD"/ReceiveFieldCorrection."$transmitRes".nii.gz \
        "$T1wDownSampleFolder"/"$Subject".L.midthickness"$RegString"."$LowResMesh"k_fs_LR.surf.gii \
        "$WD"/L.ReceiveFieldCorrection"$RegString"."$LowResMesh"k_fs_LR.func.gii \
        -ribbon-constrained "$T1wDownSampleFolder"/"$Subject".L.white"$RegString"."$LowResMesh"k_fs_LR.surf.gii \
            "$T1wDownSampleFolder"/"$Subject".L.pial"$RegString"."$LowResMesh"k_fs_LR.surf.gii \
            -volume-roi "$T1wFolder"/ROIs/L_TransmitBias_ROI."$transmitRes".nii.gz
    wb_command -volume-to-surface-mapping "$WD"/ReceiveFieldCorrection."$transmitRes".nii.gz \
        "$T1wDownSampleFolder"/"$Subject".R.midthickness"$RegString"."$LowResMesh"k_fs_LR.surf.gii \
        "$WD"/R.ReceiveFieldCorrection"$RegString"."$LowResMesh"k_fs_LR.func.gii \
        -ribbon-constrained "$T1wDownSampleFolder"/"$Subject".R.white"$RegString"."$LowResMesh"k_fs_LR.surf.gii \
            "$T1wDownSampleFolder"/"$Subject".R.pial"$RegString"."$LowResMesh"k_fs_LR.surf.gii \
            -volume-roi "$T1wFolder"/ROIs/R_TransmitBias_ROI."$transmitRes".nii.gz
    
    tempfiles_create ReceiveCorr_XXXXXX.dscalar.nii receivetemp
    wb_command -cifti-create-dense-scalar "$receivetemp" \
        -left-metric "$WD"/L.ReceiveFieldCorrection"$RegString"."$LowResMesh"k_fs_LR.func.gii \
            -roi-left "$DownSampleFolder"/"$Subject".L.atlasroi."$LowResMesh"k_fs_LR.shape.gii \
        -right-metric "$WD"/R.ReceiveFieldCorrection"$RegString"."$LowResMesh"k_fs_LR.func.gii \
            -roi-right "$DownSampleFolder"/"$Subject".R.atlasroi."$LowResMesh"k_fs_LR.shape.gii
    wb_command -cifti-dilate "$receivetemp" COLUMN 10 10 "$myelinsurfbiasout" \
        -left-surface "$T1wDownSampleFolder"/"$Subject".L.midthickness"$RegString"."$LowResMesh"k_fs_LR.surf.gii \
        -right-surface "$T1wDownSampleFolder"/"$Subject".R.midthickness"$RegString"."$LowResMesh"k_fs_LR.surf.gii
fi

