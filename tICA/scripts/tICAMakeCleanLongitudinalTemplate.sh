#!/bin/bash
set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/tempfiles.shlib" "$@"

#description to use in usage - syntax of parameters is now explained automatically
opts_SetScriptDescription "creates tICA cleaned data for all longitudinal sessions in template directory"

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder that contains all sessions"
opts_AddMandatory '--subject' 'Subject' 'str' 'longitudinal subject ID'
opts_AddMandatory '--session-list' 'SesslistRaw' 'HCA6002236_V1_MR@HCA6002236_V2_MR...' "list of longitudinal timepoint/session IDs separated by @s."
opts_AddMandatory '--template-long' 'TemplateLong' 'ID' 'Longitudinal template ID'
opts_AddMandatory '--extract-fmri-name-list' 'concatNamesToUse' 'name@name@name...' "list of fMRI run names to concatenate into the --extract-fmri-out output after tICA cleanup"
opts_AddMandatory '--highpass' 'HighPass' 'hp value' 'High pass used with these data'
opts_AddMandatory '--extract-fmri-name' 'extractNameOut' 'name' "fMRI name for concatenated extracted runs.
Must match the one used in cortical registration."
opts_AddOptional  '--reg-name' 'RegName' 'registration algorithm' "Cortical registration algorithm used [MSMAll]" "MSMAll"
opts_AddOptional  '--fmri-name-concat-all' 'extractNameAll' 'name' "Concatenated output run label. If specified, must match the one used in multi-run FIX and cortical registration." ""
opts_AddOptional  '--fmri-names' 'fMRINames' 'rfMRI_REST1_LR@rfMRI_REST1_RL...' "list of all fmri run names separated by @. Required with --extract-fmri-out-all" ""

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

if [[ "$extractNameAll" != "" && "$fMRINames" == "" ]]; then 
    log_Err_Abort "--fmri-names is required with --fmri-name-concat-all"
fi

#display the parsed/default values
opts_ShowValues

#do work
TemplateDir="$StudyFolder"/"$Subject.long.$TemplateLong"

function makeTemplateConcatRuns {
    local fMRIStr="$1" sessionsStr="$2" template="$3" nameOut="$4" 
    local fMRIs sessions
    IFS=@ read -r -a fMRIs <<< "${fMRIStr}"
    IFS=@ read -r -a sessions <<< "${sessionsStr}"
    local numSessions="${#sessions[@]}"
    local OutDir="$TemplateDir/MNINonLinear/Results/$nameOut"
    mkdir -p "$OutDir"
    
    #per fMRI run lists for concat/merge commands
    local vn_average_cifti_array
    local vn_average_nifti_array #average of the _vn from all timepoints
    local ts_concat_cifti_array
    local ts_concat_nifti_array #average nifti timeseries
    
    #loop variables 
    local session sessionLong resultsDir fmri fmri_rt
    
    local ts_all_dtseries_clean #concatenated runs from all timepoints in order after demeaning, dividing by _vn and muliplying by the average _vn
    for session in ${sessions[*]}; do
        sessionLong="$session.long.$template"
        echo "Timepoint: $sessionLong"
        resultsDir="$StudyFolder"/"$sessionLong"/MNINonLinear/Results

        # Average vn's in the atlas and native spaces. We assume that $nameOut exists in $sessionLong tICA output
        vn_average_cifti_array+=(-cifti "$resultsDir/$nameOut/${nameOut}_Atlas_${RegName}_hp${HighPass}_clean_tclean_vn.dscalar.nii")
        vn_average_nifti_array+=("$resultsDir/$nameOut/${nameOut}_hp${HighPass}_clean_tclean_vn.nii.gz")
        
        for fmri in ${fMRIs[*]}; do
            #demean each fmri and save to temporary file - cifti
            fmri_rt=$resultsDir/"$fmri/$fmri"_Atlas_"$RegName"_hp"$HighPass"_clean_tclean
            wb_command -cifti-reduce "$fmri_rt".dtseries.nii MEAN "$fmri_rt"_mean.dscalar.nii
            wb_command -cifti-math '(TS - M) / VN' "$fmri_rt"_demean.dtseries.nii \
                -var TS "$fmri_rt".dtseries.nii\
                -var M "$fmri_rt"_mean.dscalar.nii -select 1 1 -repeat \
                -var VN $resultsDir/"$fmri/$fmri"_Atlas_"$RegName"_hp"$HighPass"_vn.dscalar.nii -select 1 1 -repeat 
            rm "$fmri_rt"_mean.dscalar.nii
            ts_concat_cifti_array+=(-cifti "${fmri_rt}_demean.dtseries.nii")
            
            #demean each fmri and save to temporary file - nifti
            fmri_rt=$resultsDir/"$fmri/$fmri"_hp"$HighPass"_clean_tclean
            fslmaths "$fmri_rt".nii.gz -Tmean -mul -1 -add "$fmri_rt".nii.gz -div $resultsDir/"$fmri/$fmri"_hp"$HighPass"_vn.nii.gz "$fmri_rt"_demean.nii
            ts_concat_nifti_array+=("${fmri_rt}_demean.nii.gz")
        done
    done

    # run concat/average commands
    wb_command -cifti-merge "$OutDir/${nameOut}_Atlas_${RegName}_hp${HighPass}_clean_tclean_v1.dtseries.nii" "${ts_concat_cifti_array[@]}"
    fslmerge -t "$OutDir/${nameOut}_hp${HighPass}_clean_tclean_v1.nii" "${ts_concat_nifti_array[@]}"
    wb_command -cifti-average "$OutDir/${nameOut}_Atlas_${RegName}_hp${HighPass}_clean_tclean_vn.dscalar.nii" "${vn_average_cifti_array[@]}"
    fslmerge -t  "$OutDir/${nameOut}_hp${HighPass}_clean_tclean_vn_all.nii.gz" "${vn_average_nifti_array[@]}"
    fslmaths "$OutDir/${nameOut}_hp${HighPass}_clean_tclean_vn_all.nii.gz" -Tmean "$OutDir/${nameOut}_hp${HighPass}_clean_tclean_vn.nii.gz"
    rm "$OutDir/${nameOut}_hp${HighPass}_clean_tclean_vn_all.nii.gz"

    # multiply by average _vn files
    # multiply by average _vn - cifti
    wb_command -cifti-math "TS * VN" "$OutDir/${nameOut}_Atlas_${RegName}_hp${HighPass}_clean_tclean.dtseries.nii" \
       -var TS "$OutDir/${nameOut}_Atlas_${RegName}_hp${HighPass}_clean_tclean_v1.dtseries.nii" \
       -var VN "$OutDir/${nameOut}_Atlas_${RegName}_hp${HighPass}_clean_tclean_vn.dscalar.nii" -select 1 1 -repeat
    # multiply by average _vn - nifti
    fslmaths "$OutDir/${nameOut}_hp${HighPass}_clean_tclean_v1.nii.gz" -mul "$OutDir/${nameOut}_hp${HighPass}_clean_tclean_vn.nii.gz" \
       "$OutDir/${nameOut}_hp${HighPass}_clean_tclean.nii.gz"
    
    #clean up
    rm -f "$OutDir/${nameOut}_Atlas_${RegName}_hp${HighPass}_clean_tclean_v1.dtseries.nii" \
        "$OutDir/${nameOut}_hp${HighPass}_clean_tclean_v1.nii.gz"
        
    for session in ${sessions[*]}; do
        sessionLong="$session.long.$template"
        resultsDir="$StudyFolder/$sessionLong/MNINonLinear/Results"
        for fmri in ${fMRIs[*]}; do
            rm -f "$resultsDir/$fmri/${fmri}_Atlas_${RegName}_hp${HighPass}_clean_tclean_demean.dtseries.nii" \
                "$resultsDir/$fmri/${fmri}_hp${HighPass}_clean_tclean_demean.nii.gz"
        done
    done
}

#create outputs from the selected time series across all timepoints.
makeTemplateConcatRuns "$concatNamesToUse" "$SesslistRaw" "$TemplateLong" "$extractNameOut"

#optionally, create outputs from all time series.
if [[ "$extractNameAll" != "" ]]; then 
    makeTemplateConcatRuns "$fMRINames" "$SesslistRaw" "$TemplateLong" "$extractNameAll"
fi
echo "completed tICAMakeCleanLongitudinalTemplate.sh"