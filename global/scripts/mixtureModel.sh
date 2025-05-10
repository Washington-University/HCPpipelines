#!/usr/bin/env bash
# mixtureModel <inFile> <outFile> [wbcmd] [melocmd] [wbshrtctscmd]
# Performs Gaussian mixture modeling on precomputed ICs
# Wrapper around melodic. Accepts nifti or cifti inputs.
# Require Input:
#   inFile  : file path to IC z-scores, file path including extension as string (accepts nifti or cifti files)
#   outFile : file path to IC z-scores with Gaussian mixture modeling
#              Can output nifti, nifti-gz, or cifti, depending on extension: .nii, .nii.gz, .dscalar.nii,
#              Output format does not have to match input format, unless output is cifti.
# Optional Inputs
#   wbcmd   : workbench command, defaults to 'wb_command'
#   melocmd : melodic command, defaults to 'melodic'
#   wbshrtctscmd: workbench shortcuts command, defaults to 'wb_shortcuts'
#
# See also:
# https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=fsl;6e85d498.1607
# https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/MELODIC#Using_melodic_for_just_doing_mixture-modelling
# https://www.fmrib.ox.ac.uk/datasets/techrep/tr02cb1/tr02cb1.pdf
#
# Created by Burke Rosen
# 2024-07-08
# Dependencies: workbench, FSL
# Written with workbench 2.0 and FSL 6.0.7.1
# Refactored from matlab to bash 2025-05-19 by Copilot GPT-4.1
#
# ToDo:
# Feed arbitrary melodic arguments.

mixtureModel() {
  local inFile="$1"
  local outFile="$2"
  local wbcmd="${3:-wb_command}"
  local melocmd="${4:-melodic}"
  local wbshrtctscmd="${5:-wb_shortcuts}"

  # handle inputs
  if [[ -z "$inFile" || -z "$outFile" ]]; then
    echo "inFile and outFile arguments are required!" >&2
    return 1
  fi

  # check dependencies
  command -v "$wbcmd" >/dev/null 2>&1 || { echo "workbench_command binary $wbcmd not on path" >&2; return 1; }
  command -v "$wbshrtctscmd" >/dev/null 2>&1 || { echo "workbench_command binary $wbshrtctscmd not on path" >&2; return 1; }
  command -v "$melocmd" >/dev/null 2>&1 || { echo "melodic command binary $melocmd not on path" >&2; return 1; }

  local inFile0="$inFile"
  local outFile0="$outFile"
  local tDir
  tDir=$(mktemp -d)
  local ext

  # convert input if needed
  if [[ "$inFile0" == *dscalar.nii ]]; then
    # convert input cifti to nifti
    inFile="$(mktemp --suffix=.nii)"
    $wbcmd -cifti-convert -to-nifti "$inFile0" "$inFile" -smaller-dims
    # local dims
    dims=$($wbcmd -file-information "$inFile" | grep Dimensions | awk -F': ' '{print $2}')
    dims_arr=($dims)
    for i in "${!dims_arr[@]}"; do
      if [[ "${dims_arr[$i]}" == "1" && $i -lt 3 ]]; then
        echo "warning: singleton dimension in converted nifti, melodic may not interpret correctly!" >&2
        break
      fi
    done
    inFile="${inFile%.nii}"
  elif [[ "$inFile0" == *.nii ]]; then
    inFile="${inFile0%.nii}"
  elif [[ "$inFile0" == *.nii.gz ]]; then
    inFile="${inFile0%.nii.gz}"
  else
    echo "inFile is not a nifti or dscalar cifti?" >&2
    return 1
  fi

  # handle output extension
  if [[ "$outFile0" == *dscalar.nii ]]; then
    if [[ "$inFile0" != *dscalar.nii ]]; then
      echo "cifti output only supported for cifti input." >&2
      return 1
    fi
    outFile="${outFile0%.dscalar.nii}"
    ext="nii.gz"
  elif [[ "$outFile0" == *.nii ]]; then
    outFile="${outFile0%.nii}"
    ext=".nii"
  elif [[ "$outFile0" == *.nii.gz ]]; then
    ext="nii.gz"
    outFile="${outFile0%.nii.gz}"
  else
    echo "outFile is not a nifti or dscalar cifti?" >&2
    return 1
  fi

  # run gaussian mixture modeling with melodic
  mkdir -p "$tDir"
  echo "1" > "$tDir/grot"
  $melocmd -i "$inFile" --ICs="$inFile" --mix="$tDir/grot" -o "$tDir" --Oall --report -v --mmthresh=0

  # check for multiple z-score maps
  mapCounts=$(find "$tDir/stats/" -name 'thresh_zstat*' -exec bash -c 'fslval "$1" dim4' _ {} \;)
  maxCount=0
  for count in $mapCounts; do
    if (( count > maxCount )); then maxCount=$count; fi
  done
  if (( maxCount > 1 )); then
    echo "warning: At least one component returned two z-score maps (alpha = 0.05 and 0.01)! Using first map only." >&2
  fi

  # concatenate volumes
  $wbshrtctscmd -volume-concatenate -map 1 "${outFile}.${ext}" $(ls "$tDir"/stats/thresh_zstat* | sort -V)

  # clean up temporary files
  rm -r "$tDir"

  # convert output to cifti, if needed
  if [[ "$outFile0" == *dscalar.nii ]]; then
    $wbcmd -cifti-convert -from-nifti "${outFile}.nii.gz" "$inFile0" "$outFile0"
    imrm "$inFile" "$outFile"
  elif [[ "$inFile0" == *dscalar.nii ]]; then
    imrm "$inFile"
  fi

}
# Call the function if the script is run directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  mixtureModel "$@"
fi
# Usage example:
# mixtureModel input.dscalar.nii output.dscalar.nii