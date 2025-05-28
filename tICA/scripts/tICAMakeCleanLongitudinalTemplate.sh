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
    local session sessionLong resultsDir fmri fmri_rt frame_ind1 frame_ind2 NumTPs
    
    local ts_all_dtseries_clean #concatenated runs from all timepoints in order after demeaning, dividing by _vn and muliplying by the average _vn
    for session in ${sessions[*]}; do
        sessionLong="$session.long.$template"
        echo "Timepoint: $sessionLong"
        resultsDir="$StudyFolder"/"$sessionLong"/MNINonLinear/Results

        # Average vn's in the atlas and native spaces. We assume that $nameOut exists in $sessionLong tICA output
        vn_average_cifti_array+=(-cifti "$resultsDir/$nameOut/${nameOut}_Atlas_${RegName}_hp${HighPass}_clean_tclean_vn.dscalar.nii")
        vn_average_nifti_array+=(-volume "$resultsDir/$nameOut/${nameOut}_hp${HighPass}_clean_tclean_vn.nii.gz")
        
        #reset session starting frame
        frame_ind1=0
        
        for fmri in ${fMRIs[*]}; do
            fmri_rt=$resultsDir/"$fmri/${fmri}_Atlas_${RegName}_hp${HighPass}_clean_tclean"
            NumTPs=$(wb_command -file-information "$fmri_rt.dtseries.nii" -only-number-of-maps)
            frame_ind2=$(( frame_ind1 + NumTPs ))
            
            # 1. cifti: Extract demeaned tcleaned fMRI run, divide by vn            
            wb_command -cifti-merge "${fmri_rt}_demean.dtseries.nii" \
                -cifti "$resultsDir/${nameOut}/${nameOut}_Atlas_${RegName}_hp${HighPass}_clean_tclean.dtseries.nii" \
                -index $(( frame_ind1 + 1 ))  \
                -up-to $(( frame_ind2 ))
            
            wb_command -cifti-math 'TS / VN' "${fmri_rt}_demean_v1.dtseries.nii" \
                -var TS "${fmri_rt}_demean.dtseries.nii" \
                -var VN "$resultsDir/${nameOut}/${nameOut}_Atlas_${RegName}_hp${HighPass}_clean_tclean_vn.dscalar.nii" -select 1 1 -repeat
            ts_concat_cifti_array+=(-cifti "${fmri_rt}_demean_v1.dtseries.nii")
            #clean up
            rm -f "${fmri_rt}_demean.dtseries.nii"
                    
            # 2. NIFTI processing
            fmri_rt="$resultsDir/$fmri/${fmri}_hp${HighPass}_clean_tclean"
            #extract NIFTI time series and divide by average cleaned session's vn
            wb_command -volume-merge "${fmri_rt}_demean.nii" \
                -volume "$resultsDir/${nameOut}/${nameOut}_hp${HighPass}_clean_tclean.nii.gz" \
                -subvolume $(( frame_ind1 + 1 )) \
                -up-to $(( frame_ind2 ))
            wb_command -volume-math 'TS / VN' "${fmri_rt}_demean_v1.nii" \
                -var TS "${fmri_rt}_demean.nii" \
                -var VN "$resultsDir/${nameOut}/${nameOut}_hp${HighPass}_clean_tclean_vn.nii.gz" -repeat
                
            ts_concat_nifti_array+=(-volume "${fmri_rt}_demean_v1.nii")
            #clean up
            rm -f "${fmri_rt}_demean.nii"
            
            # 3. Update the starting frame
            frame_ind1="$frame_ind2"
        done
    done

    # concatenate time series across sessions and runs
    wb_command -cifti-merge "$OutDir/${nameOut}_Atlas_${RegName}_hp${HighPass}_clean_tclean_v1.dtseries.nii" "${ts_concat_cifti_array[@]}"
    wb_command -volume-merge "$OutDir/${nameOut}_hp${HighPass}_clean_tclean_v1.nii" "${ts_concat_nifti_array[@]}"
    
    # average vn's across sessions
    wb_command -cifti-average "$OutDir/${nameOut}_Atlas_${RegName}_hp${HighPass}_clean_tclean_vn.dscalar.nii" "${vn_average_cifti_array[@]}"
    wb_command -volume-merge "$OutDir/${nameOut}_hp${HighPass}_clean_tclean_vn_all.nii.gz" "${vn_average_nifti_array[@]}"
    wb_command -volume-reduce "$OutDir/${nameOut}_hp${HighPass}_clean_tclean_vn_all.nii.gz" MEAN "$OutDir/${nameOut}_hp${HighPass}_clean_tclean_vn.nii.gz"

    # multiply by average _vn - cifti
    wb_command -cifti-math "TS * VN" "$OutDir/${nameOut}_Atlas_${RegName}_hp${HighPass}_clean_tclean.dtseries.nii" \
       -var TS "$OutDir/${nameOut}_Atlas_${RegName}_hp${HighPass}_clean_tclean_v1.dtseries.nii" \
       -var VN "$OutDir/${nameOut}_Atlas_${RegName}_hp${HighPass}_clean_tclean_vn.dscalar.nii" -select 1 1 -repeat

    # multiply by average _vn - nifti
    wb_command -volume-math "TS * VN" "$OutDir/${nameOut}_hp${HighPass}_clean_tclean.nii.gz" \
        -var TS "$OutDir/${nameOut}_hp${HighPass}_clean_tclean_v1.nii" \
        -var VN "$OutDir/${nameOut}_hp${HighPass}_clean_tclean_vn.nii.gz" -repeat
    
    #clean up
    rm -f "$OutDir/${nameOut}_Atlas_${RegName}_hp${HighPass}_clean_tclean_v1.dtseries.nii" \
        "$OutDir/${nameOut}_hp${HighPass}_clean_tclean_v1.nii" \
        "$OutDir/${nameOut}_hp${HighPass}_clean_tclean_vn_all.nii.gz"
        
    for session in ${sessions[*]}; do
        sessionLong="$session.long.$template"
        resultsDir="$StudyFolder/$sessionLong/MNINonLinear/Results"
        for fmri in ${fMRIs[*]}; do
            rm -f "$resultsDir/$fmri/${fmri}_Atlas_${RegName}_hp${HighPass}_clean_tclean_demean_v1.dtseries.nii" \
                "$resultsDir/$fmri/${fmri}_hp${HighPass}_clean_tclean_demean_v1.nii"
        done
    done
}

#create outputs for the selected time series across all timepoints.
makeTemplateConcatRuns "$concatNamesToUse" "$SesslistRaw" "$TemplateLong" "$extractNameOut"

#optionally, create outputs for all time series.
if [[ "$extractNameAll" != "" ]]; then 
    makeTemplateConcatRuns "$fMRINames" "$SesslistRaw" "$TemplateLong" "$extractNameAll"
fi
echo "completed tICAMakeCleanLongitudinalTemplate.sh"