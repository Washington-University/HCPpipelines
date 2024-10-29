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

opts_SetScriptDescription "align SE fieldmap, SBRef, and myelin-related scans and fine-tune receive bias"

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject' 'Subject' 'subject ID' "(e.g. 100610)"
opts_AddMandatory '--working-dir' 'WorkingDIR' 'path' "where to put intermediate files"
opts_AddMandatory '--fmri-names' 'fMRINames' 'rfMRI_REST1_LR@rfMRI_REST1_RL...' "fmri runs to use SE/SBRef files from, separated by @"
opts_AddOptional '--bbr-threshold' 'bbrthresh' 'number' "mincost threshold to reinitialize bbregister with flirt (may need to be increased for aging-related reduction of gray/white contrast), default 0.5" '0.5'
#topup script uses input resolution for the intermediates that we use, so we still need separate resolutions for low-res MNI and low-res T1w files
opts_AddMandatory '--grayordinates-res' 'grayordRes' 'string' "resolution used in PostFreeSurfer for grayordinates"
opts_AddMandatory '--transmit-res' 'transmitRes' 'number' "resolution to use for transmit field"
opts_AddOptional '--receive-bias' 'ReceiveBias' 'image' "receive bias field to divide out of SE and GRE scans, if PSN wasn't used"
opts_AddOptional '--t2w-receive-corrected' 'T2wRC' 'image' "T2w image with receive correction applied, required when using --receive-bias"
opts_AddMandatory '--reg-name' 'RegName' 'string' "surface registration to use, like MSMAll"
opts_AddOptional '--low-res-mesh' 'LowResMesh' 'number' "resolution of grayordinates mesh, default '32'" '32'
opts_AddOptional '--myelin-mapping-fwhm' 'MyelinMappingFWHM' 'number' "fwhm value to use in -myelin-style, default 5" '5'
opts_AddOptional '--old-myelin-mapping' 'oldmappingStr' 'TRUE or FALSE' "if myelin mapping was done using version 1.2.3 or earlier of wb_command, set this to true" 'false'

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

oldmapping=$(opts_StringToBool "$oldmappingStr")

IFS=' @' read -a fMRINamesArray <<<"$fMRINames"

if [[ "$RegName" == "" || "$RegName" == "MSMSulc" ]]
then
    RegString=""
else
    RegString="_$RegName"
fi

if [[ "$ReceiveBias" != "" && "$T2wRC" == "" ]]
then
    log_Err_Abort "--t2w-receive-corrected is required when -receive-bias is used"
fi

#Naming Conventions

#Build Paths
T1wFolder="$StudyFolder/$Subject"/T1w
AtlasFolder="$StudyFolder/$Subject"/MNINonLinear
T1wResultsFolder="$T1wFolder"/Results
ResultsFolder="$AtlasFolder"/Results
T1wDownSampleFolder="$T1wFolder"/fsaverage_LR"$LowResMesh"k
DownSampleFolder="$AtlasFolder"/fsaverage_LR"$LowResMesh"k

mkdir -p "$WorkingDIR"/xfms

#assumes the availability of the intermediates folder...
#MFG: can get them from REST, don't bother making a topup option
#NOTE: these files have the original header of the inputs, not restricted to grayordinate resolution
for fMRIName in "${fMRINamesArray[@]}"
do
    #deal with naming convention mismatch in SBRef by making links to all 3 with consistent names
    ln -sf "$StudyFolder"/"$Subject"/"$fMRIName"/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased/FieldMap/PhaseOne_gdc_dc_jac.nii.gz "$WorkingDIR"/"$fMRIName"_PhaseOne_gdc_dc_jac.nii.gz
    ln -sf "$StudyFolder"/"$Subject"/"$fMRIName"/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased/FieldMap/PhaseTwo_gdc_dc_jac.nii.gz "$WorkingDIR"/"$fMRIName"_PhaseTwo_gdc_dc_jac.nii.gz
    
    #didn't have _gdc in the name, so add it
    ln -sf "$StudyFolder"/"$Subject"/"$fMRIName"/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased/FieldMap/SBRef_dc_jac.nii.gz "$WorkingDIR"/"$fMRIName"_SBRef_gdc_dc_jac.nii.gz
done

function align_bias_and_avg()
{
    #helper to loop over BOLD runs for a single image type
    namepart="$1"
    imageargs=()
    fovargs=()
    for fMRIName in "${fMRINamesArray[@]}"
    do
        local input="$WorkingDIR"/"$fMRIName"_"$namepart"_gdc_dc_jac.nii.gz
        local target="$T1wFolder"/T2w_acpc_dc_restore.nii.gz
        if [[ "$ReceiveBias" != "" ]]
        then
            #apply receive bias to input, instead of using non-_restore target
            local rcresamp inputRC
            tempfiles_create TransmitBias_"$namepart"_biasresamp_XXXXXX.nii.gz rcresamp
            tempfiles_create TransmitBias_"$namepart"_newreceive_XXXXXX.nii.gz inputRC
            
            wb_command -volume-resample "$ReceiveBias" "$input" TRILINEAR "$rcresamp"
            #deal with 0s in the receive field
            wb_command -volume-math 'data / (bias + (bias == 0))' "$inputRC" -fixnan 0 \
                -var data "$input" \
                -var bias "$rcresamp"
            
            input="$inputRC"
            #use _newreceive as target, too
            target="$T2wRC"
        fi
        local matrix="$WorkingDIR"/xfms/"$fMRIName"_"$namepart"_gdc_dc_jac2str.mat
        
        #we want the output in T1w/ transmitRes space, not anatomical ($target), so don't use --output-image
        "$HCPPIPEDIR"/global/scripts/bbregister.sh --study-folder="$StudyFolder" --subject="$Subject" \
            --input-image="$input" \
            --init-xfm="$StudyFolder"/"$Subject"/"$fMRIName"/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased/fMRI2str.mat \
            --init-target-image="$target" \
            --contrast-type=T2w \
            --surface-name=white.deformed \
            --output-xfm="$matrix" \
            --output-inverse-xfm="$WorkingDIR"/xfms/str2"$fMRIName"_"$namepart"_gdc_dc_jac.mat \
            --rerun-threshold="$bbrthresh" \
            --bbregister-regfile-out="$WorkingDIR"/"$fMRIName"_"$namepart"_bbregister.dat

        local -a xfmargs=(-affine "$matrix" -flirt "$input" "$target")
        local refvol="$T1wFolder"/T1w_acpc_dc_restore."$transmitRes".nii.gz
        local outimage="$T1wResultsFolder"/"$fMRIName"/"$fMRIName"_"$namepart"_gdc_dc_jac.nii.gz
        
        #$input already has the receive bias correction, so just resample and we are done
        wb_command -volume-resample "$input" \
            "$refvol" CUBIC "$outimage" "${xfmargs[@]}"
        imageargs+=(-volume "$outimage")

        tempfiles_create "$fMRIName"_"$namepart"_fovtemp_XXXXXX.nii.gz fovtemp
        tempfiles_add "$fovtemp"_resamp.nii.gz
        wb_command -volume-math '1' "$fovtemp" -var x "$input"
        wb_command -volume-resample "$fovtemp" \
            "$refvol" TRILINEAR "$fovtemp"_resamp.nii.gz "${xfmargs[@]}"
        fovargs+=(-volume "$fovtemp"_resamp.nii.gz)
    done
    #average the resulting images, to improve SNR before division
    #should all this stuff really be directly in T1w/?
    #MFG: probably already released
    #MFG: merged is good for checking registration, keep
    wb_command -volume-merge "$T1wFolder"/"$namepart"_gdc_dc_reg.nii.gz "${imageargs[@]}"
    wb_command -volume-reduce "$T1wFolder"/"$namepart"_gdc_dc_reg.nii.gz MEAN "$T1wFolder"/"$namepart"_gdc_dc_reg_mean.nii.gz
    
    wb_command -volume-merge "$T1wFolder"/"$namepart"_fov_all.nii.gz "${fovargs[@]}"
    wb_command -volume-reduce "$T1wFolder"/"$namepart"_fov_all.nii.gz MIN "$T1wFolder"/"$namepart"_fov_all_min.nii.gz
}

align_bias_and_avg "PhaseOne"
align_bias_and_avg "PhaseTwo"
align_bias_and_avg "SBRef"

wb_command -volume-math "min(min(PhaseOne, PhaseTwo), SBRef)" "$T1wFolder"/PseudoTransmit_fov_all_min.nii.gz \
    -var PhaseOne "$T1wFolder"/PhaseOne_fov_all_min.nii.gz \
    -var PhaseTwo "$T1wFolder"/PhaseTwo_fov_all_min.nii.gz \
    -var SBRef "$T1wFolder"/SBRef_fov_all_min.nii.gz

#These are in /T1w, decide whether these filenames are what we want
#MFG: probably already released
mv "$T1wFolder"/SBRef_gdc_dc_reg_mean.nii.gz "$T1wFolder"/GRE.nii.gz

wb_command -volume-math '(a + b) / 2' "$T1wFolder"/SE.nii.gz -var a "$T1wFolder"/PhaseOne_gdc_dc_reg_mean.nii.gz -var b "$T1wFolder"/PhaseTwo_gdc_dc_reg_mean.nii.gz

applywarp --interp=nn -i "$T1wFolder"/brainmask_fs.nii.gz -r "$T1wFolder"/T1w_acpc_dc_restore."$transmitRes".nii.gz -o "$T1wFolder"/ROIs/brainmask_fs."$transmitRes".nii.gz

##Transmit Field Regularization
tempfiles_create PseudoTransmitField_Raw_XXXXXX.nii.gz tempfield
#TSC: these are already receive-corrected now
#avoid divide by zero, then mask out anywhere that would have
wb_command -volume-math '(SE != 0) * mask * GRE / (SE + (SE == 0))' "$tempfield" -fixnan 0 \
    -var GRE "$T1wFolder"/GRE.nii.gz \
    -var SE "$T1wFolder"/SE.nii.gz \
    -var mask "$T1wFolder"/ROIs/brainmask_fs."$transmitRes".nii.gz

tempfiles_add "$tempfield"_atlaslowres.nii.gz "$tempfield"_atlas.nii.gz "$tempfield"_dil.nii.gz "$tempfield"_anat.nii.gz
fslmaths "$tempfield" -uthr $(fslstats "$tempfield" -P 99.9) -dilM -dilM -mas "$T1wFolder"/ROIs/brainmask_fs."$transmitRes".nii.gz "$T1wFolder"/PseudoTransmitField_Raw."$transmitRes".nii.gz

fslmaths "$T1wFolder"/PseudoTransmitField_Raw."$transmitRes".nii.gz -dilM -dilM "$tempfield"_dil.nii.gz
wb_command -volume-resample "$tempfield"_dil.nii.gz "$AtlasFolder"/T1w_restore."$grayordRes".nii.gz CUBIC "$tempfield"_atlaslowres.nii.gz \
    -warp "$AtlasFolder"/xfms/acpc_dc2standard.nii.gz -fnirt "$T1wFolder"/T1w_acpc_dc_restore.nii.gz
fslmaths "$tempfield"_atlaslowres.nii.gz -mas "$AtlasFolder"/brainmask_fs."$grayordRes".nii.gz "$AtlasFolder"/PseudoTransmitField_Raw."$grayordRes".nii.gz

wb_command -volume-resample "$tempfield"_dil.nii.gz "$T1wFolder"/T1w_acpc_dc_restore.nii.gz CUBIC "$tempfield"_anat.nii.gz
fslmaths "$tempfield"_anat.nii.gz -mas "$T1wFolder"/brainmask_fs.nii.gz "$T1wFolder"/PseudoTransmitField_Raw.nii.gz

wb_command -volume-resample "$tempfield"_dil.nii.gz "$AtlasFolder"/T1w_restore.nii.gz CUBIC "$tempfield"_atlas.nii.gz \
    -warp "$AtlasFolder"/xfms/acpc_dc2standard.nii.gz -fnirt "$T1wFolder"/T1w_acpc_dc_restore.nii.gz
fslmaths "$tempfield"_atlas.nii.gz -mas "$AtlasFolder"/brainmask_fs.nii.gz "$AtlasFolder"/PseudoTransmitField_Raw.nii.gz

LeftGreyRibbonValue="3"
RightGreyRibbonValue="42"
MyelinMappingSigma=$(echo "$MyelinMappingFWHM / (2 * sqrt(2 * l(2)))" | bc -l)

tempfiles_create thickness_L_XXXXXX.shape.gii lthickness
tempfiles_create thickness_R_XXXXXX.shape.gii rthickness
tempfiles_create ribbon_L_XXXXXX.nii.gz lribbon
tempfiles_create ribbon_R_XXXXXX.nii.gz rribbon

wb_command -cifti-separate "$DownSampleFolder"/"$Subject".thickness"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii COLUMN \
    -metric CORTEX_LEFT "$lthickness" \
    -metric CORTEX_RIGHT "$rthickness"

wb_command -volume-math "ribbon == $LeftGreyRibbonValue" "$lribbon" -var ribbon "$T1wFolder"/ribbon.nii.gz
mappingcommand=(wb_command -volume-to-surface-mapping "$T1wFolder"/PseudoTransmitField_Raw.nii.gz "$T1wDownSampleFolder"/"$Subject".L.midthickness"$RegString"."$LowResMesh"k_fs_LR.surf.gii "$DownSampleFolder"/"$Subject".L.PseudoTransmitField_Raw"$RegString"."$LowResMesh"k_fs_LR.func.gii \
    -myelin-style "$lribbon" "$lthickness" "$MyelinMappingSigma")
if ((oldmapping))
then
    mappingcommand+=(-legacy-bug)
fi
"${mappingcommand[@]}"

wb_command -volume-math "ribbon == $RightGreyRibbonValue" "$rribbon" -var ribbon "$T1wFolder"/ribbon.nii.gz
mappingcommand=(wb_command -volume-to-surface-mapping "$T1wFolder"/PseudoTransmitField_Raw.nii.gz "$T1wDownSampleFolder"/"$Subject".R.midthickness"$RegString"."$LowResMesh"k_fs_LR.surf.gii "$DownSampleFolder"/"$Subject".R.PseudoTransmitField_Raw"$RegString"."$LowResMesh"k_fs_LR.func.gii \
    -myelin-style "$rribbon" "$rthickness" "$MyelinMappingSigma")
if ((oldmapping))
then
    mappingcommand+=(-legacy-bug)
fi
"${mappingcommand[@]}"

tempfiles_create TransmitBias_PseudoTransmitField_raw_XXXXXX.dscalar.nii tempscalar

wb_command -cifti-create-dense-scalar "$tempscalar" \
    -left-metric "$DownSampleFolder"/"$Subject".L.PseudoTransmitField_Raw"$RegString"."$LowResMesh"k_fs_LR.func.gii \
        -roi-left "$DownSampleFolder"/"$Subject".L.atlasroi."$LowResMesh"k_fs_LR.shape.gii \
    -right-metric "$DownSampleFolder"/"$Subject".R.PseudoTransmitField_Raw"$RegString"."$LowResMesh"k_fs_LR.func.gii \
        -roi-right "$DownSampleFolder"/"$Subject".R.atlasroi."$LowResMesh"k_fs_LR.shape.gii

wb_command -cifti-dilate "$tempscalar" COLUMN 25 25 "$DownSampleFolder"/"$Subject".PseudoTransmitField_Raw"$RegString"."$LowResMesh"k_fs_LR.dscalar.nii \
    -left-surface "$T1wDownSampleFolder"/"$Subject".L.midthickness"$RegString"."$LowResMesh"k_fs_LR.surf.gii \
    -right-surface "$T1wDownSampleFolder"/"$Subject".R.midthickness"$RegString"."$LowResMesh"k_fs_LR.surf.gii

