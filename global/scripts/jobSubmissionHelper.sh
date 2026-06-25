#!/bin/bash
set -euo pipefail

# Usage: submit_job_single.sh HOST CLUSTER_HOME JOB_SCRIPT REMOTE_OUTPUT LOCAL_OUTPUT
if [[ $# -ne 5 ]]; then
    echo "Usage: $0 HOST CLUSTER_HOME JOB_SCRIPT REMOTE_OUTPUT LOCAL_OUTPUT"
    exit 1
fi

HOST="$1"
CLUSTER_HOME="$2"
JOB_SCRIPT="$3"
REMOTE_OUTPUT="$4"
LOCAL_OUTPUT="$5"

ssh-add || true

JOB_FILENAME=$(basename "$JOB_SCRIPT")
REMOTE_JOB_SCRIPT="$CLUSTER_HOME/$JOB_FILENAME"

# Function to retry SSH commands up to N times
retry_ssh() {
    local max_retries=20
    local delay=5
    local cmd="$1"
    local attempt=1

    while [[ $attempt -le $max_retries ]]; do
        echo "Attempt $attempt: running SSH command..." >&2
        ssh -A -o BatchMode=yes "$HOST" bash -c "module purge; module load slurm; $cmd" && return 0
        echo "SSH command failed. Retrying in $delay seconds..." >&2
        sleep $delay
        attempt=$((attempt + 1))
    done

    echo "SSH command failed after $max_retries attempts." >&2
    return 1
}

retry_scp() {
    local src="$1"
    local dst="$2"
    local max_retries=20
    local delay=5
    local attempt=1

    while [[ $attempt -le $max_retries ]]; do
        echo "Attempt $attempt: copying $src to $dst" >&2
        scp -o BatchMode=yes "$src" "$dst" && return 0
        echo "SCP failed. Retrying in $delay seconds..." >&2
        sleep $delay
        attempt=$((attempt + 1))
    done

    echo "SCP failed after $max_retries attempts." >&2
    return 1
}


# Copy job script to cluster (retry SCP if needed)
echo "Copying $JOB_SCRIPT to $HOST:$REMOTE_JOB_SCRIPT"
retry_scp "$JOB_SCRIPT" "$HOST:$REMOTE_JOB_SCRIPT"

# Create remote output directory if specified
if [[ -n "$REMOTE_OUTPUT" ]]; then
    retry_ssh "mkdir -p '$REMOTE_OUTPUT'"
fi

# Submit job
JOB_SUBMIT_OUTPUT=$(retry_ssh "sbatch '$REMOTE_JOB_SCRIPT'")
echo "$JOB_SUBMIT_OUTPUT"

JOB_ID=$(echo "$JOB_SUBMIT_OUTPUT" | grep -oE '[0-9]+' | tail -n1)
if [[ -z "$JOB_ID" ]]; then
    echo "Error: sbatch did not return a job ID. Submission output:"
    echo "$JOB_SUBMIT_OUTPUT"
    exit 1
fi
echo "Submitted job $JOB_ID for $JOB_SCRIPT"

# Wait for job to finish
while true; do
    JOB_RUNNING=$(retry_ssh "squeue -j $JOB_ID -h")
    if [[ -z "$JOB_RUNNING" ]]; then
        break
    fi
    sleep 10
done


echo "Job $JOB_ID finished."

if [[ -n "$LOCAL_OUTPUT" ]]; then
    # Default Slurm output file name
    SLURM_OUT_REMOTE="$CLUSTER_HOME/slurm-$JOB_ID.out"
    SLURM_OUT_LOCAL="$LOCAL_OUTPUT/slurm-$JOB_ID.out"

    echo "Copying Slurm output $SLURM_OUT_REMOTE to $SLURM_OUT_LOCAL"
    mkdir -p "$(dirname "$SLURM_OUT_LOCAL")"
    retry_scp "$HOST:$SLURM_OUT_REMOTE" "$SLURM_OUT_LOCAL"

    # Optional: clean up remote Slurm output
    retry_ssh "rm -f '$SLURM_OUT_REMOTE'"
fi


# Copy back output if specified
if [[ -n "$LOCAL_OUTPUT" && -n "$REMOTE_OUTPUT" ]]; then
    echo "Copying remote output $REMOTE_OUTPUT to $LOCAL_OUTPUT"
    mkdir -p "$(dirname "$LOCAL_OUTPUT")"
    retry_scp -r "$HOST:$REMOTE_OUTPUT" "$LOCAL_OUTPUT"
    
    # Cleanup remote output
    retry_ssh "rm -rf '$REMOTE_OUTPUT'"
fi

# Cleanup: remove the job script from cluster
retry_ssh "rm -f '$REMOTE_JOB_SCRIPT'"
