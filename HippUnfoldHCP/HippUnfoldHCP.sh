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


# Remove subject specific cache directory even in case of script failure
cleanup() {
    if [[ -n "${JobCache:-}" && -d "$JobCache" ]]; then
        log_Msg "Removing job cache: $JobCache"
        rm -rf "$JobCache"
        log_Msg "Temporary cache directory deleted"
    fi
}

trap cleanup EXIT


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

T1wFolder="$StudyFolder/$Subject/T1w"


if [[ -z "${HippUnfoldDIR:-}" ]]; then
    HippUnfoldDIR="${T1wFolder}/HippUnfold"
fi

T1wImage="$T1wFolder/T1w_acpc_dc_restore.nii.gz"
T2wImage="$T1wFolder/T2w_acpc_dc_restore.nii.gz"


if [[ ! -f "$T1wImage" ]]
then
    echo "Error: T1w image not found at $T1wImage" >&2
    exit 1
fi

if [[ ! -f "$T2wImage" ]]
then
    echo "Error: T2w image not found at $T2wImage" >&2
    exit 1
fi


# ---------------------------------------------------------------------
# Create HippUnfold input directory
# ---------------------------------------------------------------------

mkdir -p "$HippUnfoldDIR"

ln -sf "$T1wImage" "$HippUnfoldDIR/s_${Subject}_T1w_acpc_dc_restore.nii.gz"
ln -sf "$T2wImage" "$HippUnfoldDIR/s_${Subject}_T2w_acpc_dc_restore.nii.gz"

log_Msg "Created folder structure under $HippUnfoldDIR and linked T1w and T2w images"
log_Msg "Starting HippUnfold pipeline for subject: $Subject"

# ---------------------------------------------------------------------
# Construct HippUnfold command
# ---------------------------------------------------------------------

if [[ -z "${HIPPUNFOLDPATH:-}" || ! -f "$HIPPUNFOLDPATH" ]]; then
    log_Err_Abort "HippUnfold SIF file not found. Please supply the SIF file location in /HCPpipelines/Examples/Scripts"
else
    # Place all HippUnfold cache files next to the SIF
    HippUnfoldCacheDIR="$(dirname "$HIPPUNFOLDPATH")/cache"

    # Separate cache and conda directory for each subject
    JobCache="${HippUnfoldCacheDIR}/job-cache/${JOB_ID:-local}_${Subject}"
    JobCondaPrefix="${JobCache}/snakemake-conda"
    JobCondaPkgs="${JobCache}/conda-pkgs"

    HippUnfoldResourceCache="${JobCache}/resources"

    mkdir -p "$JobCondaPrefix"
    mkdir -p "$JobCondaPkgs"
    mkdir -p "$HippUnfoldResourceCache"

    CondaPrefix="$JobCondaPrefix"

    hippcmd=(
        apptainer run
            --bind "$StudyFolder"
            --bind "${JobCache}:${JobCache}"
            --bind "${HippUnfoldResourceCache}:${HippUnfoldResourceCache}"
            --env HIPPUNFOLD_CACHE_DIR="$HippUnfoldResourceCache"
            --env CONDA_PKGS_DIRS="$JobCondaPkgs"
            -e
            "$HIPPUNFOLDPATH"
            hippunfold
    )
fi

# Additional arguments
# Seriously: don't put a $ on {subject} and don't capitalize the S...
hippargs=(
    "$HippUnfoldDIR"
    "$HippUnfoldDIR"
    participant
    --modality T2w
    --path-T1w "$HippUnfoldDIR/s_{subject}_T1w_acpc_dc_restore.nii.gz"
    --path-T2w "$HippUnfoldDIR/s_{subject}_T2w_acpc_dc_restore.nii.gz"
)

#In cases previous attempts terminated prematurely, snakemake may leave a lock on subject that needs to be removed
SnakemakeLockDir="${HippUnfoldDIR}/.snakemake/locks"
if [[ -d "${SnakemakeLockDir}" ]]; then
    log_Msg "Removing stale Snakemake lock for subject: ${Subject}"
    "${hippcmd[@]}" "${hippargs[@]}" \
        --conda-prefix "$CondaPrefix" \
        --unlock
fi
# ---------------------------------------------------------------------
# Run HippUnfold
# ---------------------------------------------------------------------

log_Msg "Running HippUnfold for subject: $Subject"

#Seriously: don't put a $ on {subject} and don't capitalize the S...
"${hippcmd[@]}" "$HippUnfoldDIR" "$HippUnfoldDIR" participant \
    --modality T2w \
    --path-T1w "$HippUnfoldDIR/s_{subject}_T1w_acpc_dc_restore.nii.gz" \
    --path-T2w "$HippUnfoldDIR/s_{subject}_T2w_acpc_dc_restore.nii.gz" \
    --cores all \
    --force-output \
    --generate_myelin_map \
    --output-density native 512 2k 8k 18k \
    --force-nnunet-model maguire_T2w \
    --inner-outer-reg-smoothing 0 \
    --conda-prefix "$CondaPrefix" \
    --latency-wait 60 \
    --rerun-incomplete
    
log_Msg "HippUnfold pipeline completed successfully for subject: $Subject"
