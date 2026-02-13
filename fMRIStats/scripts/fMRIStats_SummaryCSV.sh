#!/bin/bash

# fMRIStats_SummaryCSV.sh
#
# Loads a single fMRIStats CIFTI dscalar output, separates into cortex/subcortex regions,
# and writes regional averages (mean or RMS) to summary CSV.
#
# Usage: fMRIStats_SummaryCSV.sh <citiFile> <summaryCSVName> [<Caret7_Command>]
#
# Arguments:
#   citiFile - Path to CIFTI dscalar file
#   summaryCSVName - Output path for summary CSV file
#   Caret7_Command - Optional path to wb_command (default: 'wb_command')

set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
  pipedirguessed=1
  # fix this if the script is more than one level below HCPPIPEDIR
  export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

source "$HCPPIPEDIR/global/scripts/log.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/tempfiles.shlib" "$@"

# Parse arguments
if [[ $# -lt 2 ]]; then
  log_Err_Abort "Usage: $0 <ciftiFile> <summaryCSVName> [<Caret7_Command>]"
fi

citiFile="$1"
summaryCSVName="$2"
Caret7_Command="${3:-wb_command}"

log_Msg "Processing CIFTI file: $citiFile"
log_Msg "Output CSV: $summaryCSVName"

if [[ ! -f "$citiFile" ]]; then
  log_Err_Abort "CIFTI file not found: $citiFile"
fi

# Create temporary directory for intermediate files
tempfiles_create "fMRIStats_SummaryCSV_XXXXXX" tmpDir
tmpDir="${tmpDir%/*}"  # Get directory part if tempfiles_create returns a file

# Get metric names from CIFTI file
metricNamesStr=$("$Caret7_Command" -file-information "$citiFile" -only-map-names)
IFS=$'\n' read -rd '' -a metricNames <<<"$metricNamesStr" || true
nM=${#metricNames[@]}
log_Msg "Found $nM metrics"

if [[ $nM -eq 0 ]]; then
  log_Err_Abort "No metrics found in CIFTI file"
fi

# Separate cortex (left and right)
cortexLFile="$tmpDir/cortex_L.func.gii"
cortexRFile="$tmpDir/cortex_R.func.gii"

"$Caret7_Command" -cifti-separate "$citiFile" COLUMN \
  -metric CORTEX_LEFT "$cortexLFile" \
  -metric CORTEX_RIGHT "$cortexRFile"

if [[ ! -f "$cortexLFile" ]] || [[ ! -f "$cortexRFile" ]]; then
  log_Err_Abort "Failed to extract cortex from CIFTI"
fi
tempfiles_add "$cortexLFile" "$cortexRFile"

# Separate subcortex
subcortexFile="$tmpDir/subcortex.nii.gz"
"$Caret7_Command" -cifti-separate "$citiFile" COLUMN -volume-all "$subcortexFile"

if [[ ! -f "$subcortexFile" ]]; then
  log_Err_Abort "Failed to extract subcortex from CIFTI"
fi
tempfiles_add "$subcortexFile"

# Initialize output CSV with header
csvFile="${summaryCSVName}"
{
  printf "Region"
  for name in "${metricNames[@]}"; do
    printf ",%s" "$name"
  done
  printf "\n"
} > "$csvFile"

# Process Cortex region
if [[ -f "$cortexLFile" ]] && [[ -f "$cortexRFile" ]]; then
  # Get vertex counts from file-information output
  cortexLinfo=$("$Caret7_Command" -file-information "$cortexLFile" 2>&1)
  cortexRinfo=$("$Caret7_Command" -file-information "$cortexRFile" 2>&1)
  
  # Extract number of vertices from "Number of Vertices: X" line
  nL=$(echo "$cortexLinfo" | grep "Number of Vertices:" | sed 's/.*Number of Vertices:[[:space:]]*\([0-9]*\).*/\1/')
  nR=$(echo "$cortexRinfo" | grep "Number of Vertices:" | sed 's/.*Number of Vertices:[[:space:]]*\([0-9]*\).*/\1/')
  
  totalN=$((nL + nR))
  log_Msg "Cortex: $nL + $nR vertices, Subcortex: computing"
  printf "Cortex" >> "$csvFile"
  
  for col in $(seq 1 "$nM"); do
    metricName="${metricNames[$((col-1))]}"
    
    if [[ "$metricName" =~ STD$ ]]; then
      # For STD metrics, compute L2NORM (RMS) across all vertices
      l2L=$("$Caret7_Command" -metric-stats "$cortexLFile" -column "$col" -reduce L2NORM)
      l2R=$("$Caret7_Command" -metric-stats "$cortexRFile" -column "$col" -reduce L2NORM)
      # Combine: sqrt((l2L^2 + l2R^2) / totalN)
      combined_sum_sq=$(echo "scale=4; $l2L * $l2L + $l2R * $l2R" | bc)
      val=$(echo "scale=4; sqrt($combined_sum_sq / $totalN)" | bc)
    else
      # For other metrics, compute MEAN across all vertices with proper weighting
      meanL=$("$Caret7_Command" -metric-stats "$cortexLFile" -column "$col" -reduce MEAN)
      meanR=$("$Caret7_Command" -metric-stats "$cortexRFile" -column "$col" -reduce MEAN)
      # Weighted mean: (meanL * nL + meanR * nR) / totalN
      val=$(echo "scale=4; ($meanL * $nL + $meanR * $nR) / $totalN" | bc)
    fi
    # Format with leading zero for values < 1
    val=$(echo "$val" | awk '{printf "%.4f\n", $1}')
    printf ",%s" "$val" >> "$csvFile"
  done
  printf "\n" >> "$csvFile"
  log_Msg "Cortex written"
else
  log_Err_Abort "Cortex files missing"
fi

# Process Subcortex region
if [[ -f "$subcortexFile" ]]; then
  log_Msg "Computing Subcortex"
  printf "Subcortex" >> "$csvFile"
  for col in $(seq 1 "$nM"); do
    metricName="${metricNames[$((col-1))]}"
    # Subvolume index is 1-indexed in wb_command
    subvolIdx="$col"
    
    if [[ "$metricName" =~ STD$ ]]; then
      # For STD metrics, compute L2NORM across all voxels
      val=$("$Caret7_Command" -volume-stats "$subcortexFile" -subvolume "$subvolIdx" -reduce L2NORM)
    else
      # For other metrics, compute MEAN across all voxels
      val=$("$Caret7_Command" -volume-stats "$subcortexFile" -subvolume "$subvolIdx" -reduce MEAN)
    fi
    # Format with leading zero for values < 1
    val=$(echo "$val" | awk '{printf "%.4f\n", $1}')
    printf ",%s" "$val" >> "$csvFile"
  done
  printf "\n" >> "$csvFile"
  log_Msg "Subcortex written"
else
  log_Err_Abort "Subcortex file missing"
fi

log_Msg "Summary CSV complete: $csvFile"

