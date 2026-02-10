#!/bin/bash
set -eu
pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
  # pipedirguessed=1
   #fix this if the script is more than one level below HCPPIPEDIR
   export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"


opts_SetScriptDescription "Make some BIDS structures and run HippUnfold"

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject' 'Subject' 'subject ID' ""
opts_AddOptional '--hippunfold-dir' 'HippUnfoldDIR' 'path' "location of HippUnfold outputs"

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

opts_ShowValues

T1wFolder="$StudyFolder/$Subject/T1w"       # input data

if [ -z ${HippUnfoldDIR} ] ; then
  HippUnfoldDIR="${T1wFolder}/HippUnfold"
fi

HippUnfoldT1wFolder="$HippUnfoldDIR/T1w/hippunfold"
HippUnfoldT2wFolder="$HippUnfoldDIR/T2w/hippunfold"
HippUnfoldT1wT2wFolder="$HippUnfoldDIR/T1wT2w/hippunfold"

T1wImage="$T1wFolder/T1w_acpc_dc_restore.nii.gz"
T2wImage="$T1wFolder/T2w_acpc_dc_restore.nii.gz"


if [ ! -f "$T1wImage" ]; then
    echo "Error: T1w image not found at $T1wImage" >&2
    exit 1
fi

if [ ! -f "$T2wImage" ]; then
    echo "Error: T2w image not found at $T2wImage" >&2
    exit 1
fi


mkdir -p "$HippUnfoldT1wFolder" "$HippUnfoldT2wFolder" "$HippUnfoldT1wT2wFolder"

ln -sf "$T1wImage" "$HippUnfoldT1wFolder/s_${Subject}_T1w_acpc_dc_restore.nii.gz"
ln -sf "$T2wImage" "$HippUnfoldT1wFolder/s_${Subject}_T2w_acpc_dc_restore.nii.gz"
ln -sf "$T1wImage" "$HippUnfoldT2wFolder/s_${Subject}_T1w_acpc_dc_restore.nii.gz"
ln -sf "$T2wImage" "$HippUnfoldT2wFolder/s_${Subject}_T2w_acpc_dc_restore.nii.gz"
ln -sf "$T1wImage" "$HippUnfoldT1wT2wFolder/s_${Subject}_T1w_acpc_dc_restore.nii.gz"
ln -sf "$T2wImage" "$HippUnfoldT1wT2wFolder/s_${Subject}_T2w_acpc_dc_restore.nii.gz"

log_Msg "Created folder structure under $HippUnfoldDIR and copied T1w and T2w images"
log_Msg "Starting HippUnfold pipeline for subject: $Subject"

export APPTAINER_BINDPATH=${HIPPUNFOLD_CACHE_DIR}:${HIPPUNFOLD_CACHE_DIR}
export APPTAINER_CACHEDIR=${HIPPUNFOLD_CACHE_DIR}/apptainer
export APPTAINERENV_HIPPUNFOLD_CACHE_DIR=${HIPPUNFOLD_CACHE_DIR} #This one actually did something

#export HIPPUNFOLD_CACHE_DIR=${HippUnfoldDIR}/cache #Keep for QuNex?
#export APPTAINER_BINDPATH=${StudyFolder}:${StudyFolder}
#export APPTAINER_CACHEDIR=${HippUnfoldDIR}/apptainer
#export APPTAINERENV_HIPPUNFOLD_CACHE_DIR=${HippUnfoldDIR}/cache #This one actually did something
#mkdir -p ${HIPPUNFOLD_CACHE_DIR}
#mkdir -p ${APPTAINER_CACHEDIR}


if [[ "${HIPPUNFOLDPATH:-}" == "" ]]
then
    hippcmd=(hippunfold --use-conda)
else
    hippcmd=(apptainer run --bind "$StudyFolder" -e "$HIPPUNFOLDPATH")
fi

log_Msg "Running T1w HippUnfold for subject: $Subject"
#Seriously: don't put a $ on {subject} and don't capitalize the S...
"${hippcmd[@]}" "$HippUnfoldT1wFolder" "$HippUnfoldT1wFolder" participant \
    --modality T1w \
    --path-T1w "$HippUnfoldT1wFolder"/s_{subject}_T1w_acpc_dc_restore.nii.gz \
    --path-T2w "$HippUnfoldT1wFolder"/s_{subject}_T2w_acpc_dc_restore.nii.gz \
    --cores all \
    --force-output \
    --generate_myelin_map \
    --output-density native 512 2k 8k 18k 
log_Msg "T1w HippUnfold completed."

log_Msg "Running T2w HippUnfold for subject: $Subject"
"${hippcmd[@]}" "$HippUnfoldT2wFolder" "$HippUnfoldT2wFolder" participant \
    --modality T2w \
    --path-T1w "$HippUnfoldT2wFolder"/s_{subject}_T1w_acpc_dc_restore.nii.gz \
    --path-T2w "$HippUnfoldT2wFolder"/s_{subject}_T2w_acpc_dc_restore.nii.gz \
    --cores all \
    --force-output \
    --generate_myelin_map \
    --output-density native 512 2k 8k 18k 
log_Msg "T2w HippUnfold completed."

log_Msg "Running T1wT2w HippUnfold for subject: $Subject"
"${hippcmd[@]}" "$HippUnfoldT1wT2wFolder" "$HippUnfoldT1wT2wFolder" participant \
    --modality T2w \
    --path-T1w "$HippUnfoldT1wT2wFolder"/s_{subject}_T1w_acpc_dc_restore.nii.gz \
    --path-T2w "$HippUnfoldT1wT2wFolder"/s_{subject}_T2w_acpc_dc_restore.nii.gz \
    --cores all \
    --force-output \
    --generate_myelin_map \
    --output-density native 512 2k 8k 18k \
    --force-nnunet-model T1T2w
log_Msg "T1wT2w HippUnfold completed."

log_Msg "HippUnfold pipeline completed successfully for subject: $Subject"

