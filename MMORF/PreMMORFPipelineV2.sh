set -uo pipefail
# Load helpers
source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
opts_SetScriptDescription "Run MMORF registration for multiple sessions in parallel"
opts_AddMandatory '--study-folder' 'StudyFolder' 'Path to the study folder containing session folders' ""
opts_AddMandatory '--session' 'Session' 'Subject ID' ""
opts_AddMandatory '--t1-template' 'T1wTemplate' 'Path to the T1w template image' ""
opts_AddMandatory '--t2-template' 'T2wTemplate' 'Path to the T2w template image' ""
opts_AddMandatory '--ref-mask' 'refmask' 'Path to the reference mask image' ""
opts_AddMandatory '--diffusion-ref' 'DiffusionRef' 'Path to the diffusion reference image' ""
opts_AddMandatory '--dti-mask' 'DTIMask' 'Path to the DTI mask image' ""
opts_ParseArguments "$@"

T1wImage="T1w"
T1wFolderName="T1w"
T2wImage="T2w"
T2wFolderName="T2w"
AtlasSpaceFolderName="MMORFNonLinear"


# ==========================
# Loop over sessions
# ==========================

    T1wFolder="${StudyFolder}/${Session}/${T1wFolderName}"
    AtlasSpaceFolder="${StudyFolder}/${Session}/${AtlasSpaceFolderName}"
    Diffusion="${T1wFolder}/Diffusion"


    echo "Launching MMORF registration for session ${Session}"






        ${HCPPIPEDIR}/MMORF/scripts/AtlastRegistrationToMMORF.sh \
          --workingdir="${AtlasSpaceFolder}" \
          --t1rest="${T1wFolder}/${T1wImage}_acpc_dc_restore" \
          --t2rest="${T1wFolder}/${T2wImage}_acpc_dc_restore" \
          --brainmask_fs="${T1wFolder}/brainmask_fs.nii.gz" \
          --ref="${T1wTemplate}" \
          --ref2="${T2wTemplate}" \
          --refmask="${refmask}" \
          --Diffusion="${Diffusion}" \
          --DTImask="${Diffusion}/nodif_brain_mask.nii.gz" \
          --DTIref="${DiffusionRef}" \
          --DTIrefmask="${DTIMask}" \
   