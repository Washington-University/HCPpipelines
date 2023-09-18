#!/bin/bash

# Scale volume for NHP FreeSurfer
# The script calculates a scaled volume to be used for FreeSurfer. Scaling factor is usually set by by number larger
# than 1 for small brain, and useful for NHP brain. The brain of the output volume is enlarged by the scaling factor
# with the same location of origin (commonly set to AC). The script only changes the header and does not resample
# voxels.

usage_exit() {
echo "Usage: $(basename $0) <input> <scale factor> <output scaled volume> [output matrix (in world format]"
exit 1;
}

[ "$3" = "" ] && usage_exit

T1wImage=$(remove_ext "$1")
ScaleFactor="$2"
out="$3"
if [ ! -z "$4" ] ; then
	outmat=$4
fi

interp="${interp:=CUBIC}" # The script is irrelevant to resampling method.
tmpmat=tmp_$$

source $HCPPIPEDIR/global/scripts/log.shlib  # Logging related functions
source $HCPPIPEDIR/global/scripts/opts.shlib # Command line option functions
log_SetToolName "ScaleVolume.sh"

# ----------------------------------------------------------------------
log_Msg " Scaling voxel size with scaling factor = $ScaleFactor"	
# ----------------------------------------------------------------------
read -a sform <<<"$(fslorient -getsform "$T1wImage")"
newsform=()
for ((i = 0; i < 12; ++i))
do
   newsform+=("$(echo "${sform[$i]} * $ScaleFactor" | bc -l)")
done
dims=("$(fslval "$T1wImage" dim1)" "$(fslval "$T1wImage" dim2)" "$(fslval "$T1wImage" dim3)")
$CARET7DIR/wb_command -volume-create "${dims[@]}" "$out".nii.gz -sform "${newsform[@]}"

echo "$ScaleFactor 0 0 0" > "$tmpmat"
echo "0 $ScaleFactor 0 0" >> "$tmpmat"
echo "0 0 $ScaleFactor 0" >> "$tmpmat"
echo "0 0 0 1" >> "$tmpmat"

$CARET7DIR/wb_command -volume-resample "$T1wImage".nii.gz "$out".nii.gz "$interp" "$out".nii.gz -affine "$tmpmat"

if [ ! -z "$outmat" ] ; then
	mv $tmpmat $outmat
else
	rm $tmpmat
fi
log_Msg "End: ScaleVolume.sh"
exit 0
