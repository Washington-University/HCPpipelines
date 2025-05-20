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
opts_AddMandatory '--extract-fmri-out' 'extractNameOut' 'name' "fMRI name for concatenated extracted runs, requires --extract-fmri-name-list"
opts_AddOptional  '--reg-name' 'RegName' 'registration algorithm' "Cortical registration algorithm used [MSMAll]" "MSMAll"
opts_AddOptional  '--extract-fmri-out-all' 'extractNameAll' 'name' "Concatenated run label. If specified, concatenate all runs specified by --fmri-names, for all timepoints." ""
opts_AddOptional  '--fmri-names' 'fMRINames' 'rfMRI_REST1_LR@rfMRI_REST1_RL...' "list of all fmri run names separated by @. Required with --extract-fmri-out-all" ""

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

if [[ "$extractNameAll" != "" && "$fMRINames" == "" ]]; then 
    log_Err_Abort "-fmri-names is required with --extract-fmri-out-all"
fi

#display the parsed/default values
opts_ShowValues

#do work
TemplateDir="$StudyFolder"/"$Subject.$TemplateLong"

function makeTemplateConcatRuns {
    local fMRIStr="$1" sessionsStr="$2" template="$3" nameOut="$4" 
    local fMRIs sessions
    IFS=@ read -r -a fMRIs <<< "${fMRIStr}"
    IFS=@ read -r -a sessions <<< "${sessionsStr}"
    local OutDir="$TemplateDir/MNINonLinear/Results/$nameOut"
    mkdir -p "$OutDir"
    
    #commands to create output files
    local vn_average_cifti="wb_command -cifti-average $OutDir/${nameOut}_Atlas_"$RegName"_hp${HighPass}_clean_tclean_vn.dscalar.nii" 
    local vn_average_nifti="fslmerge -t  "$OutDir"/"$nameOut"_hp"$HighPass"_clean_tclean_vn.nii.gz" #average of the _vn from all timepoints
    local ts_concat_cifti="wb_command -cifti-merge "$nameOut"_Atlas_"$RegName"_hp"$HighPass"_clean_tclean_v1.dtseries.nii"
    local ts_concat_nifti="fslmerge -t "$OutDir"/"$nameOut"_clean_tclean_v1.nii" #average nifti timeseries
    
    #loop variables 
    local session sessionLong resultsDir fmri fmri_rt
    
    local ts_all_dtseries_clean #concatenated runs from all timepoints in order after demeaning, dividing by _vn and muliplying by the average _vn
    for session in ${sessions[*]}; do
        sessionLong="$session.long.$template"
        echo "Timepoint: $sessionLong"
        resultsDir="$StudyFolder"/"$sessionLong"/MNINonLinear/Results
        for fmri in ${fMRIs[*]}; do
            #demean each fmri and save to temporary file - cifti
            fmri_rt=$resultsDir/"$fmri/$fmri"_Atlas_"$RegName"_hp"$HighPass"_clean_tclean
            #DEBUG - uncomment
            # wb_command -cifti-reduce "$fmri_rt".dtseries.nii MEAN "$fmri_rt"_mean.dscalar.nii
            # wb_command -cifti-math '(TS - M) / VN' "$fmri_rt"_demean.dtseries.nii \
                # -var TS "$fmri_rt".dtseries.nii -var M "$fmri_rt"_mean.dscalar.nii -select 1 1 -repeat \
                # -var VN $resultsDir/"$fmri/$fmri"_Atlas_"$RegName"_hp"$HighPass"_vn.dscalar.nii -select 1 1 -repeat 

            #rm "$fmri_rt"_mean.dscalar.nii
            ts_concat_cifti="$ts_concat_cifti -cifti "$fmri_rt"_demean.dtseries.nii"
            
            #demean each fmri and save to temporary file - nifti
            fmri_rt=$resultsDir/"$fmri/$fmri"_hp"$HighPass"_clean_tclean            
            #fslmaths "$fmri_rt".nii.gz -Tmean -mul -1 -add "$fmri_rt".nii.gz -div $resultsDir/"$fmri/$fmri"_hp"$HighPass"_vn.nii.gz "$fmri_rt"_demean.nii
            ts_concat_nifti="$ts_concat_nifti ${fmri_rt}_demean.nii.gz"

            #average vn's in atlas and native space
            vn_average_cifti="$vn_average_cifti -cifti $resultsDir/$fmri/${fmri}_Atlas_${RegName}_hp${HighPass}_clean_tclean_vn.dscalar.nii"
            vn_average_nifti="$vn_average_nifti $resultsDir/$fmri/${fmri}_hp${HighPass}_clean_tclean_vn.nii.gz"
        done
    done
    #run concat/average commands
    #DEBUG - uncomment
    #$ts_concat_cifti
    #$ts_concat_nifti
    echo $vn_average_cifti
    $vn_average_cifti
    echo $vn_average_nifti
    $vn_average_nifti
    #multiply by average _vn file
    echo "multiply by average _vn - cifti" #DEBUG
    wb_command -cifti-math "TS * VN" $OutDir/${nameOut}_Atlas_"$RegName"_hp${HighPass}"_clean_tclean.dtseries.nii.gz" \
        -var TS "$nameOut"_Atlas_"$RegName"_hp"$HighPass"_clean_tclean_v1.dtseries.nii \
        -var VN "$OutDir/${nameOut}"_Atlas_"$RegName"_hp${HighPass}_vn.dscalar.nii -select 1 1 -repeat
    echo "multiply by average _vn - nifti" #DEBUG
    fslmaths "$OutDir"/"$nameOut"_clean_tclean_v1.nii -mul "$OutDir"/"$nameOut"_hp"$HighPass"_clean_tclean_vn.nii.gz \
        "$OutDir"/"$nameOut"_clean_tclean.nii.gz
        
    echo "completed tICAMakeCleanLongitudinalTemplate.sh"
    exit 0 #DEBUG
    #clean up
    rm "$nameOut"_Atlas_"$RegName"_hp"$HighPass"_clean_tclean_v1.dtseries.nii \
        "$OutDir"/"$nameOut"_clean_tclean_v1.nii
        #"$OutDir/${nameOut}"_Atlas_"$RegName"_hp${HighPass}_vn.dscalar.nii \
        #"$OutDir"/"$nameOut"_clean_tclean_vn.nii.gz
        
    for session in ${sessions[*]}; do
        sessionLong="$Session.long.$template"
        resultsDir="$StudyFolder"/"$sessionLong"/MNINonLinear/Results
        for fmri in ${fMRIs[*]}; do
            rm $resultsDir/"$fmri/$fmri"_Atlas_"$RegName"_hp"$HighPass"_clean_tclean_demean.dtseries.nii
            rm $resultsDir/"$fmri/$fmri"_hp"$HighPass"_clean_tclean_demean.nii
        done
    done
}

#create outputs from the selected time series across all timepoints.
makeTemplateConcatRuns "$concatNamesToUse" "$SesslistRaw" "$TemplateLong" "$extractNameOut"

#optionally, create outputs from all time series.
if [[ "$extractfMRIOutAll" != "" ]]; then 
    makeTemplateConcatRuns "$fMRINames" "$SesslistRaw" "$TemplateLong" "$extractNameOutAll"
fi
