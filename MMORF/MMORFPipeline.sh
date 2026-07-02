set -uo pipefail
# Load helpers
source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
opts_SetScriptDescription "Run MMORF registration for multiple sessions in parallel"
opts_AddMandatory '--study-folder' 'StudyFolder' 'Path to the study folder containing session folders' ""
opts_AddMandatory '--session-list' 'Sessionlist' 'List of session IDs to process deliminated by @' ""
opts_AddMandatory '--max-jobs' 'MAX_JOBS' 'Maximum number of parallel jobs' ""
opts_AddMandatory '--t1-template' 'T1wTemplate' 'Path to the T1w template image' ""
opts_AddMandatory '--t2-template' 'T2wTemplate' 'Path to the T2w template image' ""
opts_AddMandatory '--ref-mask' 'refmask' 'Path to the reference mask image' ""
opts_AddMandatory '--diffusion-ref' 'DiffusionRef' 'Path to the diffusion reference image' ""
opts_AddMandatory '--dti-mask' 'DTIMask' 'Path to the DTI mask image' ""
opts_AddMandatory '--runlocally' 'RUNLOCALLY' 'Whether to run the MMORF registration locally or on a cluster (true/false)' ""
opts_AddOptional '--Host' 'Host' 'server alias' "You need ssh config setup so your alias gives you access to the cluster"
opts_AddOptional '--CHPCHeader' 'CHPCHeader' 'Header for CHPC cluster' ""
opts_AddOptional '--LocalHost' 'LocalHost' 'Local host name' ""
opts_AddOptional '--mount-point' 'MountPoint' 'Mount point for cluster' ""
opts_AddOptional '--ClusterHomeDirectory' 'ClusterHomeDirectory' 'Home directory on the cluster' ""
opts_ParseArguments "$@"

T1wImage="T1w"
T1wFolderName="T1w"
T2wImage="T2w"
T2wFolderName="T2w"
AtlasSpaceFolderName="MMORFNonLinear"
CAPTURE="${HCPPIPEDIR}/global/scripts/captureoutput.sh"

StudyFolder=${StudyFolder}

T1wTemplate=${T1wTemplate}
T2wTemplate=${T2wTemplate}
refmask=${refmask}
DiffusionRef=${DiffusionRef}
DTIMask=${DTIMask}

MAX_JOBS=${MAX_JOBS}
job_count=0

Sessionlist=`echo ${Sessionlist} | sed 's/@/ /g'`


FAILED_LOG="./mmorf_failed_sessions.txt"
SKIPPED_LOG="./mmorf_skipped_sessions.txt"
: > "$FAILED_LOG"
: > "$SKIPPED_LOG"

# Keep track of background job PIDs
declare -A PIDS

# ==========================
# Loop over sessions
# ==========================
for Session in "${Sessionlist}"; do

    T1wFolder="${StudyFolder}/${Session}/${T1wFolderName}"
    AtlasSpaceFolder="${StudyFolder}/${Session}/${AtlasSpaceFolderName}"
    T1wFolder_T2wImageWithPath_acpc_dc="${T1wFolder}/${T2wImage}_acpc_dc"
    Diffusion="${T1wFolder}/Diffusion"

    # Skip if output already exists
    if [ -d "${AtlasSpaceFolder}" ]; then
        echo "Skipping session ${Session} because output already exists"
        echo "${Session}" >> "$SKIPPED_LOG"
        continue
    fi

    echo "Launching MMORF registration for session ${Session}"

    # Launch subshell as background job
    (
        set -e  # fail fast inside subshell

        ${CAPTURE} \
        ${HCPPIPEDIR}/MMORF/scripts/AtlastRegistrationToMMORF.sh \
          --workingdir="${AtlasSpaceFolder}" \
          --t1="${T1wFolder}/${T1wImage}_acpc_dc" \
          --t1rest="${T1wFolder}/${T1wImage}_acpc_dc_restore" \
          --t1restbrain="${T1wFolder}/${T1wImage}_acpc_dc_restore_brain" \
          --t2="${T1wFolder_T2wImageWithPath_acpc_dc}" \
          --t2rest="${T1wFolder}/${T2wImage}_acpc_dc_restore" \
          --t2restbrain="${T1wFolder}/${T2wImage}_acpc_dc_restore_brain" \
          --brainmask_fs="${T1wFolder}/brainmask_fs.nii.gz" \
          --ref="${T1wTemplate}" \
          --ref2="${T2wTemplate}" \
          --refmask="${refmask}" \
          --Diffusion="${Diffusion}" \
          --DTImask="${Diffusion}/nodif_brain_mask.nii.gz" \
          --DTIref="${DiffusionRef}" \
          --DTIrefmask="${DTIMask}" \
          --owarp="${AtlasSpaceFolder}/xfms/acpc_dc2mmorf.nii.gz" \
          --oinvwarp="${AtlasSpaceFolder}/xfms/mmorf2acpc_dc.nii.gz" \
          --ot1="${AtlasSpaceFolder}/${T1wImage}" \
          --ot1rest="${AtlasSpaceFolder}/${T1wImage}_restore" \
          --ot1restbrain="${AtlasSpaceFolder}/${T1wImage}_restore_brain" \
          --ot2="${AtlasSpaceFolder}/${T2wImage}" \
          --ot2rest="${AtlasSpaceFolder}/${T2wImage}_restore" \
          --ot2restbrain="${AtlasSpaceFolder}/${T2wImage}_restore_brain" \
          --runlocally=${RUNLOCALLY} \
          --mountPoint=${MountPoint} \
          --Host=${Host} \
          --CHPCHeader=${CHPCHeader} \
          --LocalHost=${LocalHost} \
          --ClusterHomeDirectory=${ClusterHomeDirectory}
    ) || {
        # Log failures immediately
        echo "Session ${Session} failed"
        echo "${Session}" >> "$FAILED_LOG"
    } &

    pid=$!
    PIDS["$pid"]="$Session"
    job_count=$((job_count + 1))

    # Throttle MAX_JOBS
    while [ "$job_count" -ge "$MAX_JOBS" ]; do
        sleep 1  # wait for some jobs to finish
        # Count running background jobs
        running_jobs=$(jobs -pr | wc -l)
        job_count=$running_jobs
    done

done

# ==========================
# Wait for remaining jobs
# ==========================
for pid in "${!PIDS[@]}"; do
    wait "$pid"
done

# ==========================
# Summary
# ==========================
echo "========================================"
if [ -s "$FAILED_LOG" ]; then
    echo "Failed sessions:"
    cat "$FAILED_LOG"
else
    echo "All sessions completed successfully"
fi

if [ -s "$SKIPPED_LOG" ]; then
    echo "Skipped sessions:"
    cat "$SKIPPED_LOG"
fi

echo "Log files:"
echo "  Failed sessions:  $FAILED_LOG"
echo "  Skipped sessions: $SKIPPED_LOG"