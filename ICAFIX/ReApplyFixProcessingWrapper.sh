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
g_matlab_default_mode=1

#mandatory (mrfix name must be specified if applicable, so including it here despite being mechanically optional)
#general inputs
opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder that contains all subjects"
opts_AddMandatory '--subject' 'Subject' '100206' "one subject ID"
opts_AddMandatory '--fmri-names' 'fMRINames' 'rfMRI_REST1_LR@rfMRI_REST1_RL...' "list of fmri run names separated by @s" #Needs to be the single fMRI run names only (for DVARS and GS code) for MR+FIX, is also the SR+FIX input names
opts_AddOptional '--mrfix-concat-name' 'MRFixConcatName' 'rfMRI_REST' "if multi-run FIX was used, you must specify the concat name with this option" ""
opts_AddMandatory '--fix-high-pass' 'HighPass' 'integer' 'the high pass value that was used when running FIX' '--melodic-high-pass'
opts_AddMandatory '--surf-reg-name' 'RegName' 'MSMAll' "the registration string corresponding to the input files"
opts_AddConfigMandatory '--low-res' 'LowResMesh' 'LowResMesh' 'meshnum' "mesh resolution, like '32' for 32k_fs_LR"
opts_AddOptional '--motion-regression' 'MotionReg' 'MotionReg' " whether to apply motion regression" "FALSE"
opts_AddOptional '--delete-intermediates' 'DeleteIntermediates' 'DeleteIntermediates' "whether to delete intermediate files" "FALSE"
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

IFS='@' read -a fMRINamesArray <<<"$fMRINames"

if [ ${RegName} = "NONE" ] ; then
    RegNameString=""
else
    RegNameString="_${RegName}"
fi

#processing code goes here
if [ -z ${MRFixConcatName} ] ; then
    # if single run
    #Move old files to backup
    echo "" > /dev/null
    for fMRIName in "${fMRINamesArray[@]}"; do
        mv -n ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegNameString}_hp${HighPass}_clean.dtseries.nii ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegNameString}_hp${HighPass}_clean_bak.dtseries.nii
        mv -n ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegNameString}_hp${HighPass}_clean_vn.dscalar.nii ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegNameString}_hp${HighPass}_clean_vn_bak.dscalar.nii
  
        if [ ${RegName} = "NONE" ] ; then
            mv -n ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}_clean.nii.gz ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}_clean_bak.nii.gz
            mv -n ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}_clean_vn.nii.gz ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}_clean_vn_bak.nii.gz
        fi
        
        mv -n ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}.ica/HandNoise.txt ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}.ica/HandNoise_bak.txt
        cp -f ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}.ica/ReCleanNoise.txt ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}.ica/HandNoise.txt

        # Single-Run main processing
        "$HCPPIPEDIR"/ICAFIX/ReApplyFixPipeline.sh \
            --path="$StudyFolder" \
            --subject="$Subject" \
            --fmri-name="$fMRIName" \
            --high-pass="$HighPass" \
            --reg-name="$RegName" \
            --low-res-mesh="$LowResMesh" \
            --matlab-run-mode="$MatlabMode" \
            --motion-regression="${MotionReg}" \
            --delete-intermediates="${DeleteIntermediates}"
  
        mv ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}.ica/HandNoise_bak.txt ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}.ica/HandNoise.txt

        #Move new files to new names: rclean
        mv ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegNameString}_hp${HighPass}_clean.dtseries.nii ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegNameString}_hp${HighPass}_clean_rclean.dtseries.nii
        mv ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegNameString}_hp${HighPass}_clean_vn.dscalar.nii ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegNameString}_hp${HighPass}_clean_rclean_vn.dscalar.nii
        
        if [ ${RegName} = "NONE" ] ; then
            mv ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}_clean.nii.gz ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}_clean_rclean.nii.gz
            mv ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}_clean_vn.nii.gz ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}_clean_rclean_vn.nii.gz
        fi

        #Move old files to original names: clean
        mv ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegNameString}_hp${HighPass}_clean_bak.dtseries.nii ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegNameString}_hp${HighPass}_clean.dtseries.nii
        mv ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegNameString}_hp${HighPass}_clean_vn_bak.dscalar.nii ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegNameString}_hp${HighPass}_clean_vn.dscalar.nii
        if [ ${RegName} = "NONE" ] ; then
            mv ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}_clean_bak.nii.gz ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}_clean.nii.gz
            mv ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}_clean_vn_bak.nii.gz ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}_clean_vn.nii.gz            
        fi
    done
else
    # if multi-run
    # check missing runs
    SubjfMRINames=""
    for fMRIName in "${fMRINamesArray[@]}"; do
        if [[ -e "$StudyFolder/$Subject/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegNameString}.dtseries.nii" ]]; then
            SubjfMRINames+="@${fMRIName}"
        fi
    done

    # Remove the leading @
    SubjfMRINames="${SubjfMRINames:1}"

    IFS='@' read -a ExistfMRINamesArray <<<"$SubjfMRINames"

    #Move old files to backup
    mv -n ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_Atlas${RegNameString}_hp${HighPass}_clean.dtseries.nii ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_Atlas${RegNameString}_hp${HighPass}_clean_bak.dtseries.nii
    mv -n ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_Atlas${RegNameString}_hp${HighPass}_clean_vn.dscalar.nii ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_Atlas${RegNameString}_hp${HighPass}_clean_vn_bak.dscalar.nii
    
    if [ ${RegName} = "NONE" ] ; then
        mv -n ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_hp${HighPass}_clean.nii.gz ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_hp${HighPass}_clean_bak.nii.gz
        mv -n ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_hp${HighPass}_clean_vn.nii.gz ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_hp${HighPass}_clean_vn_bak.nii.gz
    fi
    
    for fMRIName in "${ExistfMRINamesArray[@]}"; do
        mv -n ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegNameString}_hp${HighPass}_clean.dtseries.nii ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegNameString}_hp${HighPass}_clean_bak.dtseries.nii
        if [ ${RegName} = "NONE" ] ; then
            mv -n ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}_clean.nii.gz ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}_clean_bak.nii.gz 
        fi
    done

    mv -n ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_hp${HighPass}.ica/HandNoise.txt ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_hp${HighPass}.ica/HandNoise_bak.txt
    cp -f ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_hp${HighPass}.ica/ReCleanNoise.txt ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_hp${HighPass}.ica/HandNoise.txt
    
    # Multi-Run main processing
    "$HCPPIPEDIR"/ICAFIX/ReApplyFixMultiRunPipeline.sh \
        --path="$StudyFolder" \
        --subject="$Subject" \
        --fmri-names="$SubjfMRINames" \
        --high-pass="$HighPass" \
        --reg-name="$RegName" \
        --concat-fmri-name="$MRFixConcatName" \
        --low-res-mesh="$LowResMesh" \
        --matlab-run-mode="$MatlabMode" \
        --motion-regression="$MotionReg"

    mv ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_hp${HighPass}.ica/HandNoise_bak.txt ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_hp${HighPass}.ica/HandNoise.txt

    #Move new files to new names
    mv ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_Atlas${RegNameString}_hp${HighPass}_clean.dtseries.nii ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_Atlas${RegNameString}_hp${HighPass}_clean_rclean.dtseries.nii
    mv ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_Atlas${RegNameString}_hp${HighPass}_clean_vn.dscalar.nii ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_Atlas${RegNameString}_hp${HighPass}_clean_rclean_vn.dscalar.nii
        
    if [ ${RegName} = "NONE" ] ; then
        mv ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_hp${HighPass}_clean.nii.gz ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_hp${HighPass}_clean_rclean.nii.gz
        mv ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_hp${HighPass}_clean_vn.nii.gz ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_hp${HighPass}_clean_rclean_vn.nii.gz
    fi

    for fMRIName in "${ExistfMRINamesArray[@]}"; do
        mv ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegNameString}_hp${HighPass}_clean.dtseries.nii ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegNameString}_hp${HighPass}_clean_rclean.dtseries.nii
        if [ ${RegName} = "NONE" ] ; then
            mv ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}_clean.nii.gz ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}_clean_rclean.nii.gz 
        fi
    done

    #Move old files to original names
    mv ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_Atlas${RegNameString}_hp${HighPass}_clean_bak.dtseries.nii ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_Atlas${RegNameString}_hp${HighPass}_clean.dtseries.nii
    mv ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_Atlas${RegNameString}_hp${HighPass}_clean_vn_bak.dscalar.nii ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_Atlas${RegNameString}_hp${HighPass}_clean_vn.dscalar.nii
        
    if [ ${RegName} = "NONE" ] ; then
        mv ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_hp${HighPass}_clean_bak.nii.gz ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_hp${HighPass}_clean.nii.gz
        mv ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_hp${HighPass}_clean_vn_bak.nii.gz ${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_hp${HighPass}_clean_vn.nii.gz
    fi

    for fMRIName in "${ExistfMRINamesArray[@]}"; do
        mv ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegNameString}_hp${HighPass}_clean_bak.dtseries.nii ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegNameString}_hp${HighPass}_clean.dtseries.nii
        if [ ${RegName} = "NONE" ] ; then
            mv ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}_clean_bak.nii.gz ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}_clean.nii.gz 
        fi
    done
fi