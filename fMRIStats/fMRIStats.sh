#!/bin/bash
set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
  pipedirguessed=1
  export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/tempfiles.shlib" "$@"

g_matlab_default_mode=1

opts_SetScriptDescription "computes fMRI statistics including mTSNR, fCNR, and percent BOLD"

#arguments to opts_Add*: switch, variable to set, name for inside of <> in help text, description, [default value if AddOptional], [compatibility flag, ...]
opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects" '--path'
opts_AddMandatory '--subject' 'Subject' 'subject ID' "subject ID (e.g. 100610)"
opts_AddMandatory '--concat-names' 'ConcatNames' 'string' "@-separated list of fMRI concat names (e.g. tfMRI_ALLTASKS), if single-run FIX is used, this list must be exactly 1 element long"
opts_AddMandatory '--high-pass' 'HighPass' 'string' "the high pass filter value used in ICA+FIX"
opts_AddOptional '--reg-name' 'RegName' 'string' "surface registration name, default 'NONE'" 'NONE'
opts_AddOptional '--process-volume' 'ProcessVolumeStr' 'TRUE or FALSE' "whether to process volume data, default 'false'" 'false'
opts_AddOptional '--cleanup-effects' 'CleanUpEffectsStr' 'TRUE or FALSE' "whether to compute cleanup effects metrics, default 'false'" 'false'
opts_AddOptional '--proc-string' 'ProcSTRING' 'string' "processing string suffix for cleaned data (only needed if --cleanup-effects=TRUE)" 'clean_rclean_tclean'
opts_AddOptional '--ica-mode' 'ICAmode' 'sICA or sICA+tICA' "ICA mode: 'sICA' for spatial ICA only, 'sICA+tICA' for combined spatial+temporal ICA, default 'sICA'" 'sICA'
opts_AddOptional '--fmri-names' 'fMRINames' 'string' "@-separated list of fMRI single run names (only required if data was processed with single-run FIX, must be in order and complete)" ''
opts_AddOptional '--tica-component-tcs' 'tICAcomponentTCS' 'path' "path to tICA timecourse CIFTI (required if --tica-mode=sICA+tICA)" ''
opts_AddOptional '--tica-component-noise' 'tICAcomponentNoise' 'path' "path to tICA component noise indices text file (required if --tica-mode=sICA+tICA)" ''
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

# Verify required environment variables
log_Check_Env_Var CARET7DIR

Caret7_Command="${CARET7DIR}/wb_command"

# Parse boolean strings
ProcessVolume=$(opts_StringToBool "$ProcessVolumeStr")
CleanUpEffects=$(opts_StringToBool "$CleanUpEffectsStr")

# Set registration string
if [ "${RegName}" != "NONE" ] ; then
  RegString="_${RegName}"
else
  RegString=""
fi

# Warn if using tICA+sICA mode with cleanup effects but no tclean in processing string
if [[ "$ICAmode" == "sICA+tICA" ]] && [[ "$CleanUpEffects" == "1" ]]; then
  if [[ "$ProcSTRING" != *"tclean"* ]]; then
    log_Warn "Using tICA+sICA mode with CleanUpEffects=true, but ProcSTRING does not contain 'tclean'. Processing string is: '$ProcSTRING'"
  fi
fi

if [[ -n "$fMRINames" ]]; then # Single-run FIX processing
  # Convert @ separated fMRI names to array
  IFS='@' read -ra NamesArray <<< "$fMRINames"
  IFS='@' read -ra ConcatArray <<< "$ConcatNames"
  # Verify that concat-names contains exactly one name for single-run FIX
  if [ ${#ConcatArray[@]} -ne 1 ]; then
    log_Err_Abort "When --fmri-names is provided for single-run FIX processing, --concat-names must contain exactly one name."
  fi
  ConcatName="${ConcatArray[0]}"
  # Count the time samples in each run
  runLengths=()
  for Name in "${NamesArray[@]}"; do
    fMRIFolder="${StudyFolder}/${Subject}/MNINonLinear/Results/${Name}"
    CleanedCIFTITCS="${fMRIFolder}/${Name}_Atlas${RegString}_hp${HighPass}${ProcSTRING}.dtseries.nii"
    if [[ -f "$CleanedCIFTITCS" ]]; then
      samp=$(fslval "$CleanedCIFTITCS" dim5 | xargs)
      runLengths+=("$samp")
    else
      log_Err_Abort "Required file not found: ${CleanedCIFTITCS}"
    fi
  done
else # Multi-run FIX processing
  # Convert @ separated ConcatNames to array
  IFS='@' read -ra NamesArray <<< "$ConcatNames"
fi

log_Msg "Processing subject ${Subject} with ${#NamesArray[@]} run(s)"

# Check which runs exist for this subject
fMRIExist=()
for Name in "${NamesArray[@]}"
do
  fMRIFolder="${StudyFolder}/${Subject}/MNINonLinear/Results/${Name}"
  
  # Check if cleaned data exists
  if [[ -f "${fMRIFolder}/${Name}_Atlas${RegString}_hp${HighPass}${ProcSTRING}.dtseries.nii" ]]
  then
    # Check if ICA folder and signal file exist
    if [[ -d "${fMRIFolder}/${Name}_hp${HighPass}.ica" ]]
    then
      if [[ -f "${fMRIFolder}/${Name}_hp${HighPass}.ica/HandSignal.txt" ]] || \
       [[ -f "${fMRIFolder}/${Name}_hp${HighPass}.ica/Signal.txt" ]]
      then
        fMRIExist+=("${Name}")
      else
        log_Warn "Skipping ${Name}: Signal.txt not found"
      fi
    else
      log_Warn "Skipping ${Name}: ICA folder not found"
    fi
  else
    log_Warn "Skipping ${Name}: cleaned data not found"
  fi
done

# Skip subject if no runs are ready
if [ ${#fMRIExist[@]} -eq 0 ]
then
  log_Warn "No runs ready for ${Subject}, exiting"
  exit 0
fi

log_Msg "Processing ${#fMRIExist[@]} run(s) for ${Subject}"

# Process each ready run
for Name in "${fMRIExist[@]}"
do
  log_Msg "Running fMRIStats on: ${Name}"
  
  # Construct filepaths
  fMRIFolder="${StudyFolder}/${Subject}/MNINonLinear/Results/${Name}"
  MeanCIFTI="${fMRIFolder}/${Name}_Atlas${RegString}_mean.dscalar.nii"
  MeanVolume="${fMRIFolder}/${Name}_mean.nii.gz"
  OrigCIFTITCS="${fMRIFolder}/${Name}_Atlas${RegString}.dtseries.nii"
  OrigVolumeTCS="${fMRIFolder}/${Name}.nii.gz"
  CleanedCIFTITCS="${fMRIFolder}/${Name}_Atlas${RegString}_hp${HighPass}${ProcSTRING}.dtseries.nii"
  CleanedVolumeTCS="${fMRIFolder}/${Name}_hp${HighPass}${ProcSTRING}.nii.gz"
  CIFTIOutput="${fMRIFolder}/${Name}_Atlas${RegString}_hp${HighPass}${ProcSTRING}_${ICAmode}fMRIStats.dscalar.nii"
  VolumeOutput="${fMRIFolder}/${Name}_hp${HighPass}${ProcSTRING}_${ICAmode}fMRIStats.nii.gz"
  
  # sICATCS and Signal are always required (used in all ICA modes)
  sICATCS="${fMRIFolder}/${Name}_hp${HighPass}.ica/filtered_func_data.ica/melodic_mix.sdseries.nii"   
  if [ -e "${fMRIFolder}/${Name}_hp${HighPass}.ica/HandSignal.txt" ] ; then
    Signal="${fMRIFolder}/${Name}_hp${HighPass}.ica/HandSignal.txt"
  else
    Signal="${fMRIFolder}/${Name}_hp${HighPass}.ica/Signal.txt"
  fi
  # tICAcomponentTCS and tICAcomponentNoise are not constructed here because they are not necessarily programmatically named
  
  # Validate required input files exist
  if [ ! -e "${MeanCIFTI}" ]; then
    log_Err_Abort "Required file not found: ${MeanCIFTI}"
  fi
  if [ ! -e "${sICATCS}" ]; then
    log_Err_Abort "Required file not found: ${sICATCS}"
  fi
  if [ ! -e "${Signal}" ]; then
    log_Err_Abort "Required file not found: ${Signal}"
  fi
  if [ ! -e "${CleanedCIFTITCS}" ]; then
    log_Err_Abort "Required file not found: ${CleanedCIFTITCS}"
  fi
  
  if [[ -n "$fMRINames" ]]; then # Single-run FIX processing
    log_Msg "Single-run FIX processing detected based on --fmri-names argument. Run name: ${Name}"
    # Calculate start and stop sample indices for the current run (1-indexed)
    startSamp=1
    for ((i=0; i<${#NamesArray[@]}; i++)); do
      if [[ "${NamesArray[$i]}" == "$Name" ]]; then
        # Calculate cumulative start sample by summing previous run lengths
        for ((j=0; j<i; j++)); do
          ((startSamp += runLengths[$j]))
        done
        # Stop sample is start + run length - 1
        stopSamp=$((startSamp + runLengths[$i] - 1))
        runSamps="${startSamp}@${stopSamp}"
        break
      fi
    done
  else
    log_Msg "Multi-run FIX processing detected. Concat name: ${Name}"
  fi

  case "$MatlabMode" in
    (0)
      if [[ "${MATLAB_COMPILER_RUNTIME:-}" == "" ]]
      then
        log_Err_Abort "To use compiled matlab, you must set and export the variable MATLAB_COMPILER_RUNTIME"
      fi
      ;;
    (1)
      matlab_interpreter=(matlab -nodisplay -nosplash)
      ;;
    (2)
      matlab_interpreter=(octave-cli -q --no-window-system)
      ;;
    (*)
      log_Err_Abort "unrecognized matlab mode '$MatlabMode', use 0, 1, or 2"
      ;;
  esac
  
  #matlab function arguments - build array of all arguments (positional + name-value pairs)
  matlab_args_array=("$MeanCIFTI" "$CleanedCIFTITCS" "$CIFTIOutput" "$sICATCS" "$Signal")
  
  # Optional name-value pairs
  matlab_args_array+=("ProcessVolume" "$ProcessVolume")
  matlab_args_array+=("CleanUpEffects" "$CleanUpEffects")
  matlab_args_array+=("ICAmode" "$ICAmode")
  matlab_args_array+=("Caret7_Command" "$Caret7_Command")
  
  # Add conditionally required arguments based on flags
  if [[ "$CleanUpEffects" == "1" ]]; then
    matlab_args_array+=("OrigCIFTITCS" "$OrigCIFTITCS")
  fi
  
  if [[ "$ProcessVolume" == "1" ]]; then
    matlab_args_array+=("MeanVolume" "$MeanVolume")
    matlab_args_array+=("CleanedVolumeTCS" "$CleanedVolumeTCS")
    matlab_args_array+=("VolumeOutputName" "$VolumeOutput")
    
    if [[ "$CleanUpEffects" == "1" ]]; then
      matlab_args_array+=("OrigVolumeTCS" "$OrigVolumeTCS")
    fi
  fi
  
  # Add runSamps if single-run FIX processing
  if [[ -n "$fMRINames" ]]; then
    matlab_args_array+=("runSamps" "$runSamps")
  fi
  
  # Add tICA arguments if in sICA+tICA mode
  if [[ "$ICAmode" == "sICA+tICA" ]]; then
    matlab_args_array+=("tICAcomponentTCS" "$tICAcomponentTCS")
    matlab_args_array+=("tICAcomponentNoise" "$tICAcomponentNoise")
  fi
  
  #shortcut in case the folder gets renamed
  this_script_dir=$(dirname "$0")
  
  case "$MatlabMode" in
    (0)
      # For compiled MATLAB, pass all args (positional + name-value pairs flattened)
      matlab_cmd=("$this_script_dir/Compiled_fMRIStats/run_fMRIStats.sh" "$MATLAB_COMPILER_RUNTIME" "${matlab_args_array[@]}")
      log_Msg "running compiled matlab command: ${matlab_cmd[*]}"
      "${matlab_cmd[@]}"
      ;;
    (1 | 2)
      # Format all arguments as comma-separated quoted strings
      matlab_args=""
      for arg in "${matlab_args_array[@]}"
      do
        if [[ "$matlab_args" != "" ]]
        then
          matlab_args+=", "
        fi
        matlab_args+="'$arg'"
      done
      
      matlabcode="
        addpath('$HCPPIPEDIR/fMRIStats/scripts');
        fMRIStats($matlab_args);"
      
      log_Msg "running matlab code: $matlabcode"
      "${matlab_interpreter[@]}" <<<"$matlabcode"
      echo
      ;;
  esac
  
  log_Msg "Completed: ${Name}"
done

## Post-processing: 
# Multi-run FIX: generate summary CSV files 
# Single run FIX: average across individual runs then create summary CSV 
if [[ -z "$fMRINames" ]]; then
  log_Msg "Generating summary CSV files"
  for Name in "${fMRIExist[@]}"; do
    fMRIFolder="${StudyFolder}/${Subject}/MNINonLinear/Results/${Name}"
    CIFTIOutput="${fMRIFolder}/${Name}_Atlas${RegString}_hp${HighPass}${ProcSTRING}_${ICAmode}fMRIStats.dscalar.nii"
    
    # Call fMRIStats_SummaryCSV MATLAB function
    matlab_args="'$CIFTIOutput'"
    matlab_args+=", 'Caret7_Command', '$Caret7_Command'"
    
    matlabcode="addpath('$HCPPIPEDIR/fMRIStats/scripts');fMRIStats_SummaryCSV($matlab_args);"
    case "$MatlabMode" in
      (0)
        matlab_cmd=("$this_script_dir/Compiled_fMRIStats/run_fMRIStats_SummaryCSV.sh" "$MATLAB_COMPILER_RUNTIME" "$CIFTIOutput" "$Caret7_Command")
        log_Msg "running compiled matlab command for SummaryCSV: ${matlab_cmd[*]}"
        "${matlab_cmd[@]}"
        ;;
      (1 | 2)
        log_Msg "running matlab code: $matlabcode"
        "${matlab_interpreter[@]}" <<<"$matlabcode"
        ;;
    esac
  done
else  # Single-run FIX processing - average across individual runs then create summary CSV
  log_Msg "Averaging fMRIStats across ${#fMRIExist[@]} single-run FIX runs"
  
  ciftiFiles=()
  volFiles=()
  for Name in "${fMRIExist[@]}"; do
    fMRIFolder="${StudyFolder}/${Subject}/MNINonLinear/Results/${Name}"
    ciftiFiles+=("${fMRIFolder}/${Name}_Atlas${RegString}_hp${HighPass}${ProcSTRING}_${ICAmode}fMRIStats.dscalar.nii")
    volFiles+=("${fMRIFolder}/${Name}_hp${HighPass}${ProcSTRING}_${ICAmode}fMRIStats.nii.gz")
  done
  N=${#fMRIExist[@]}
  
  metricNamesStr=$("$Caret7_Command" -file-information "${ciftiFiles[0]}" -only-map-names)
  IFS=$'\n' read -rd '' -a metricNames <<<"$metricNamesStr" || true
  nMetrics=${#metricNames[@]}
  log_Msg "Found $nMetrics metrics: ${metricNames[*]}"
  
  tempfiles_create "fMRIStats_XXXXXX" tmpDir
  tmpDir="${tmpDir%/*}"  # Extract parent directory
  log_Msg "Temp directory: $tmpDir"
  
  meanIndices=()
  stdIndices=()
  for ((m=0; m<nMetrics; m++)); do
    if [[ "${metricNames[$m]}" =~ STD$ ]]; then
      stdIndices+=($((m+1)))
      meanIndices+=($((m+1)))
    fi
  done
  
  # Create two temporary CIFTIs per run: one with MEAN metrics, one with STD metrics
  if [[ ${#meanIndices[@]} -gt 0 ]]; then
    for r in "${!ciftiFiles[@]}"; do
      "$Caret7_Command" -cifti-merge "$tmpDir/run${r}_mean.dscalar.nii" -cifti "${ciftiFiles[$r]}" $(printf -- '-index %s ' "${meanIndices[@]}")
    done
  fi
  
  if [[ ${#stdIndices[@]} -gt 0 ]]; then
    for r in "${!ciftiFiles[@]}"; do
      "$Caret7_Command" -cifti-merge "$tmpDir/run${r}_std.dscalar.nii" -cifti "${ciftiFiles[$r]}" $(printf -- '-index %s ' "${stdIndices[@]}")
    done
  fi
  
  # Average MEAN metrics using simple mean
  if [[ ${#meanIndices[@]} -gt 0 ]]; then
    log_Msg "Averaging ${#meanIndices[@]} MEAN metrics across ${N} runs"
    meanExpr="(0$(printf ' + m%d' $(seq 0 $((N-1))))) / $N"
    meanArgs=()
    for ((r=0; r<N; r++)); do
      meanArgs+=(-var "m${r}" "$tmpDir/run${r}_mean.dscalar.nii")
    done
    "$Caret7_Command" -cifti-math "$meanExpr" "$tmpDir/avg_mean.dscalar.nii" "${meanArgs[@]}"
  fi
  
  # Average STD metrics using RMS
  if [[ ${#stdIndices[@]} -gt 0 ]]; then
    log_Msg "Averaging ${#stdIndices[@]} STD metrics using RMS"
    stdExpr="sqrt((0$(for r in $(seq 0 $((N-1))); do printf ' + s%d * s%d' $r $r; done)) / $N)"
    stdArgs=()
    for ((r=0; r<N; r++)); do
      stdArgs+=(-var "s${r}" "$tmpDir/run${r}_std.dscalar.nii")
    done
    "$Caret7_Command" -cifti-math "$stdExpr" "$tmpDir/avg_std.dscalar.nii" "${stdArgs[@]}"
  fi

  # Merge averaged MEAN and STD metrics back in original metric order
  AveragedCIFTIOutput="${StudyFolder}/${Subject}/MNINonLinear/Results/${ConcatName}/${ConcatName}_Atlas${RegString}_hp${HighPass}${ProcSTRING}_${ICAmode}fMRIStats.dscalar.nii"
  
  # Build merge indices to restore original order
  meanIdx=0
  stdIdx=0
  indexOrder=()
  for ((m=0; m<nMetrics; m++)); do
    if [[ " ${meanIndices[@]} " =~ " $((m+1)) " ]]; then
      ((meanIdx=meanIdx+1))
      indexOrder+=("mean" "$meanIdx")
    else
      ((stdIdx=stdIdx+1))
      indexOrder+=("std" "$stdIdx")
    fi
  done
  
  # Build the actual merge command with indices in original order
  mergeCmd=()
  for ((i=0; i<${#indexOrder[@]}; i+=2)); do
    type="${indexOrder[$i]}"
    idx="${indexOrder[$((i+1))]}"
    if [[ "$type" == "mean" ]]; then
      mergeCmd+=(-cifti "$tmpDir/avg_mean.dscalar.nii" -index "$idx")
    else
      mergeCmd+=(-cifti "$tmpDir/avg_std.dscalar.nii" -index "$idx")
    fi
  done
  
  "$Caret7_Command" -cifti-merge "$AveragedCIFTIOutput" "${mergeCmd[@]}"
  log_Msg "Created averaged CIFTI with metrics in original order: $AveragedCIFTIOutput"
  
  # Generate summary CSV using MATLAB
  matlab_args="'$AveragedCIFTIOutput'"
  matlab_args+=", 'Caret7_Command', '$Caret7_Command'"
  
  matlabcode="addpath('$HCPPIPEDIR/fMRIStats/scripts');fMRIStats_SummaryCSV($matlab_args);"
  case "$MatlabMode" in
    (0)
      matlab_cmd=("$this_script_dir/Compiled_fMRIStats/run_fMRIStats_SummaryCSV.sh" "$MATLAB_COMPILER_RUNTIME" "$AveragedCIFTIOutput" "$Caret7_Command")
      log_Msg "running compiled matlab command for SummaryCSV: ${matlab_cmd[*]}"
      "${matlab_cmd[@]}"
      ;;
    (1 | 2)
      log_Msg "running matlab code: $matlabcode"
      "${matlab_interpreter[@]}" <<<"$matlabcode"
      ;;
  esac
  
  # Repeat for volumes if requested, repeating the same steps as for CIFTI but with subvolumes instead of indices, and averaging MEAN metrics with simple mean and STD metrics with RMS
  if [[ "$ProcessVolume" == "1" && ${#volFiles[@]} -gt 0 ]]; then
    # Extract per-run MEAN and STD volume subvolumes
    if [[ ${#meanIndices[@]} -gt 0 ]]; then
      for r in "${!volFiles[@]}"; do
        meanVolCmd=(-volume "${volFiles[$r]}")
        for idx in "${meanIndices[@]}"; do meanVolCmd+=(-subvolume "$idx"); done
        "$Caret7_Command" -volume-merge "$tmpDir/run${r}_mean.nii.gz" "${meanVolCmd[@]}"
      done
    fi
    
    if [[ ${#stdIndices[@]} -gt 0 ]]; then
      for r in "${!volFiles[@]}"; do
        stdVolCmd=(-volume "${volFiles[$r]}")
        for idx in "${stdIndices[@]}"; do stdVolCmd+=(-subvolume "$idx"); done
        "$Caret7_Command" -volume-merge "$tmpDir/run${r}_std.nii.gz" "${stdVolCmd[@]}"
      done
    fi
    
    # Average volumes
    if [[ ${#meanIndices[@]} -gt 0 ]]; then
      meanVolExpr="(0$(printf ' + m%d' $(seq 0 $((N-1))))) / $N"
      meanVolArgs=()
      for ((r=0; r<N; r++)); do
        meanVolArgs+=(-var "m${r}" "$tmpDir/run${r}_mean.nii.gz")
      done
      "$Caret7_Command" -volume-math "$meanVolExpr" "$tmpDir/avg_mean.nii.gz" "${meanVolArgs[@]}"
    fi
    
    if [[ ${#stdIndices[@]} -gt 0 ]]; then
      stdVolExpr="sqrt((0$(for r in $(seq 0 $((N-1))); do printf ' + s%d * s%d' $r $r; done)) / $N)"
      stdVolArgs=()
      for ((r=0; r<N; r++)); do
        stdVolArgs+=(-var "s${r}" "$tmpDir/run${r}_std.nii.gz")
      done
      "$Caret7_Command" -volume-math "$stdVolExpr" "$tmpDir/avg_std.nii.gz" "${stdVolArgs[@]}"
    fi
    
    # Merge volumes in original metric order
    AveragedVolumeOutput="${StudyFolder}/${Subject}/MNINonLinear/Results/${ConcatName}/${ConcatName}_hp${HighPass}${ProcSTRING}_${ICAmode}fMRIStats.nii.gz"
    mergeVolCmd=()
    meanSubvolIdx=0
    stdSubvolIdx=0
    for ((m=0; m<nMetrics; m++)); do
      if [[ " ${meanIndices[@]} " =~ " $((m+1)) " ]]; then
        ((meanSubvolIdx=meanSubvolIdx+1))
        mergeVolCmd+=(-volume "$tmpDir/avg_mean.nii.gz" -subvolume "$meanSubvolIdx")
      else
        ((stdSubvolIdx=stdSubvolIdx+1))
        mergeVolCmd+=(-volume "$tmpDir/avg_std.nii.gz" -subvolume "$stdSubvolIdx")
      fi
    done
    "$Caret7_Command" -volume-merge "$AveragedVolumeOutput" "${mergeVolCmd[@]}"
    log_Msg "Created averaged volume: $AveragedVolumeOutput"
  fi
  
fi

log_Msg "fMRIStats processing complete for subject ${Subject}"