#!/bin/bash
# ScaleVolume.sh
# Scale volume for NHP FreeSurfer
# The script calculates a scaled volume to be used for FreeSurfer. Scaling factor is usually set by the number larger
# than 1 for small brain, and useful for NHP brain. The brain of the output volume is enlarged by the scaling factor
# with the same location of origin (commonly set to AC). The script only changes the header and does not resample
# voxels.
#
# Takuya Hayashi, RIKEN Brain Connectomics Imaging Laboratory, Kobe
# Tim Coalson, Washington University in St. Louis

set -eu

usage_exit() {
echo "Usage: $(basename $0) <input> <scale factor> <output scaled volume> [output matrix (in world format]"
exit 1;
}

[[ "${3:-}" = "" ]] && usage_exit

T1wImage=$(remove_ext "$1")
ScaleFactor="$2"
out=$(remove_ext "$3")
if [ "${4:-x}" != x ] ; then
	outmat=$4
fi

interp="${interp:-CUBIC}" # The script is irrelevant to resampling method.
tmpmat=tmp_$$

source "$HCPPIPEDIR"/global/scripts/log.shlib "$@"  # Logging related functions
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"

log_SetToolName "ScaleVolume.sh"
# ----------------------------------------------------------------------
log_Msg "START: ScaleVolume.sh"
# ----------------------------------------------------------------------

# ----------------------------------------------------------------------
log_Msg " reading sform from input"
# ----------------------------------------------------------------------
read -a sform <<<"$(fslorient -getsform "$T1wImage")"
newsform=()
sumsform=0
for ((i = 0; i < 12; ++i))
do
   newsform+=("$(echo "${sform[$i]}" | awk '{printf "%.8f\n",$1*'$ScaleFactor'}')")
   if [ $i -lt 11 ] ; then
     sumsform=$(echo "${sform[$i]}+${sumsform}" | bc -l)
   fi
done
if [ "${sumsform}" = 0 ] ; then
  log_Err "No information in sform. Please correct input sform" 
  exit 1;
fi
dims=("$(fslval "$T1wImage" dim1)" "$(fslval "$T1wImage" dim2)" "$(fslval "$T1wImage" dim3)")
# ----------------------------------------------------------------------
log_Msg " creating reference volume"
# ----------------------------------------------------------------------
$CARET7DIR/wb_command -volume-create "${dims[@]}" "$out".nii.gz -sform "${newsform[@]}"

# ----------------------------------------------------------------------
log_Msg " scaling voxel size with scaling factor = $ScaleFactor"
# ----------------------------------------------------------------------
echo "$ScaleFactor 0 0 0" > "$tmpmat"
echo "0 $ScaleFactor 0 0" >> "$tmpmat"
echo "0 0 $ScaleFactor 0" >> "$tmpmat"
echo "0 0 0 1" >> "$tmpmat"
$CARET7DIR/wb_command -volume-resample $(imglob -extension "$T1wImage") "$out".nii.gz "$interp" "$out".nii.gz -affine "$tmpmat"

if [ "${outmat:-x}" != x ] ; then
	mv $tmpmat $outmat
else
	rm $tmpmat
fi
# ----------------------------------------------------------------------
log_Msg "End: ScaleVolume.sh"
# ----------------------------------------------------------------------
exit 0
