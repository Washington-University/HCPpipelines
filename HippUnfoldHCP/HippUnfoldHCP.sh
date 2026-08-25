#!/bin/bash
set -eu

pipedirguessed=0

if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    # pipedirguessed=1

    # Fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"

opts_SetScriptDescription "Make some BIDS structures and run HippUnfold"

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject' 'Subject' 'subject ID' ""
opts_AddOptional '--hippunfold-dir' 'HippUnfoldDIR' 'path' "location of HippUnfold outputs"
opts_AddOptional '--runlocal' 'RunLocal' 'TRUE|FALSE' "whether running locally" "FALSE"

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

opts_ShowValues


# ---------------------------------------------------------------------
# Input/output directories
# ---------------------------------------------------------------------

T1wFolder="$StudyFolder/$Subject/T1w"

if [[ -z "${HippUnfoldDIR:-}" ]]
then
    HippUnfoldDIR="${T1wFolder}/HippUnfold"
fi

T1wImage="$T1wFolder/T1w_acpc_dc_restore.nii.gz"
T2wImage="$T1wFolder/T2w_acpc_dc_restore.nii.gz"


# ---------------------------------------------------------------------
# Check inputs
# ---------------------------------------------------------------------

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
# HippUnfold cache
# ---------------------------------------------------------------------

if [[ -z "${HIPPUNFOLD_CACHE_DIR:-}" ]]
then
    log_Err_Abort "HIPPUNFOLD_CACHE_DIR is not set"
fi

export APPTAINER_BINDPATH=${HIPPUNFOLD_CACHE_DIR}:${HIPPUNFOLD_CACHE_DIR}
export APPTAINER_CACHEDIR=${HIPPUNFOLD_CACHE_DIR}/apptainer
export APPTAINERENV_HIPPUNFOLD_CACHE_DIR=${HIPPUNFOLD_CACHE_DIR}

mkdir -p "${HIPPUNFOLD_CACHE_DIR}/apptainer"
mkdir -p "${HIPPUNFOLD_CACHE_DIR}/snakemake-conda"


# ---------------------------------------------------------------------
# Construct HippUnfold command
# ---------------------------------------------------------------------

CondaPrefix="${HIPPUNFOLD_CACHE_DIR}/snakemake-conda"

if [[ "${HIPPUNFOLDPATH:-}" == "" ]]
then
    hippcmd=(hippunfold --use-conda)
else
    if [[ "$RunLocal" == "FALSE" ]]
    then
    	# Separate cache and conda directory for each subject to avoid crash due to parallel use
	JobCache="${HIPPUNFOLD_CACHE_DIR}/job-cache/${JOB_ID:-local}_${Subject}"
	JobCondaPrefix="${JobCache}/snakemake-conda"
	JobCondaPkgs="${JobCache}/conda-pkgs"

	mkdir -p "$JobCache"
	mkdir -p "$JobCondaPrefix"
	mkdir -p "$JobCondaPkgs"
	
	CondaPrefix="$JobCondaPrefix"
        export APPTAINERENV_HIPPUNFOLD_CACHE_DIR="$JobCache"

        hippcmd=(
            apptainer run
            --bind "$StudyFolder"
            --bind "${JobCache}:${JobCache}"
            --env HIPPUNFOLD_CACHE_DIR="$JobCache"
            --env CONDA_PKGS_DIRS="$JobCondaPkgs"
            -e
            "$HIPPUNFOLDPATH"
            hippunfold
        )
    else
        hippcmd=(
            apptainer run
            --bind "$StudyFolder"
            -e
            "$HIPPUNFOLDPATH"
            hippunfold
        )
    fi
fi

# ---------------------------------------------------------------------
# Run HippUnfold
# ---------------------------------------------------------------------

log_Msg "Running HippUnfold for subject: $Subject"

# Do not put a $ before {subject}, and do not capitalize the s.

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
    --conda-prefix "$CondaPrefix"
 
# ---------------------------------------------------------------------
# Remove cache directory
# ---------------------------------------------------------------------
   
if [[ "$RunLocal" == "FALSE" ]]
then
	rm -rf "$JobCache"
fi
    
log_Msg "HippUnfold pipeline completed successfully for subject: $Subject"
