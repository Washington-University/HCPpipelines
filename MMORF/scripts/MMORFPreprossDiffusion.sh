#!/bin/bash
set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 <base_diffusion_dir> <output_dir> <fsl_dir>"
  exit 1
fi

BASE_DIR="$1"
OUT_DIR="$2"
FSL_DIR="$3"

mkdir -p "$OUT_DIR"

BVALS="$BASE_DIR/bvals"
BVECS="$BASE_DIR/bvecs"
DATA="$BASE_DIR/data.nii.gz"

OUT_DATA="$OUT_DIR/filtered_data.nii.gz"
OUT_BVALS="$OUT_DIR/bvals_extracted"
OUT_BVECS="$OUT_DIR/bvecs_extracted"
VOL_LIST="$OUT_DIR/vols.txt"


THRESH=1200

echo "Filtering diffusion data (fslselectvols)"
echo "Threshold: bval < $THRESH"

# --------------------------------------------------
# 1. Generate volume list (0-based)
# --------------------------------------------------
awk -v t="$THRESH" '
{
  for (i=1;i<=NF;i++)
    if ($i < t)
      print i-1
}
' "$BVALS" > "$VOL_LIST"

if [ ! -s "$VOL_LIST" ]; then
  echo "ERROR: No volumes pass threshold"
  exit 1
fi

echo "Keeping volumes:"
cat "$VOL_LIST"

# --------------------------------------------------
# 2. Extract volumes (single FSL call)
# --------------------------------------------------
fslselectvols \
  -i "$DATA" \
  -o "$OUT_DATA" \
  --vols="$VOL_LIST"

# --------------------------------------------------
# 3. Write filtered bvals
# --------------------------------------------------
awk -v t="$THRESH" '
{
  for (i=1;i<=NF;i++)
    if ($i < t)
      printf "%f ", $i
  printf "\n"
}
' "$BVALS" > "$OUT_BVALS"

# --------------------------------------------------
# 4. Write filtered bvecs (column-wise)
# --------------------------------------------------
KEEP_IDXS=$(paste -sd' ' "$VOL_LIST")

awk -v keep="$KEEP_IDXS" '
BEGIN { split(keep, idxs, " ") }
{
  for (i in idxs)
    printf "%f ", $(idxs[i]+1)
  printf "\n"
}
' "$BVECS" > "$OUT_BVECS"

#DTI Fit
${FSL_DIR}/bin/dtifit -k "${OUT_DATA}" -o "${BASE_DIR}/data" -m "${BASE_DIR}/nodif_brain_mask.nii.gz" -r "${OUT_BVECS}" -b "${OUT_BVALS}" --gradnonlin="${BASE_DIR}/grad_dev.nii.gz" --save_tensor


echo "Done."
echo "Outputs:"
echo "  $OUT_DATA"
echo "  $OUT_BVALS"
echo "  $OUT_BVECS"
