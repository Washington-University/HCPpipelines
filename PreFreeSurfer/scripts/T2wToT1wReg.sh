#!/bin/bash 
set -e

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib

log_Msg " START: T2w2T1Reg"

WD="$1"
T1wImage="$2"
T1wImageBrain="$3"
T2wImage="$4"
T2wImageBrain="$5"
OutputT1wImage="$6"
OutputT1wImageBrain="$7"
OutputT1wTransform="$8"
OutputT2wImage="$9"
OutputT2wTransform="${10}"
Identmat="${11}"

T1wImageBrainFile=`basename "$T1wImageBrain"`

if [ "$Identmat" != "TRUE" ] ; then
 if [ "${T2wImage}" = "NONE" ] ; then
    log_Msg "Skipping T2w to T1w registration --- no T2w image."
 else
  ${FSLDIR}/bin/imcp "$T1wImageBrain".nii.gz "$WD"/"$T1wImageBrainFile".nii.gz
  ${FSLDIR}/bin/epi_reg --epi="$T2wImageBrain" --t1="$T1wImage" --t1brain="$WD"/"$T1wImageBrainFile" --out="$WD"/T2w2T1w
  #$HCPPIPEDIR/global/scripts/epi_reg_dof --epi="$T2wImageBrain" --t1="$T1wImage" --t1brain="$WD"/"$T1wImageBrainFile" --out="$WD"/T2w2T1w
  ${FSLDIR}/bin/applywarp --rel --interp=spline --in="$T2wImage" --ref="$T1wImage" --premat="$WD"/T2w2T1w.mat --out="$WD"/T2w2T1w
  ${FSLDIR}/bin/fslmaths "$WD"/T2w2T1w -add 1 "$WD"/T2w2T1w -odt float
 fi
else
 imcp "$T2wImageBrain" "$WD"/T2w2T1w
 echo "1 0 0 0" > "$WD"/T2w2T1w.mat
 echo "0 1 0 0" >> "$WD"/T2w2T1w.mat
 echo "0 0 1 0" >> "$WD"/T2w2T1w.mat
 echo "0 0 0 1" >> "$WD"/T2w2T1w.mat
fi

${FSLDIR}/bin/imcp  "$T1wImage".nii.gz "$OutputT1wImage".nii.gz
${FSLDIR}/bin/imcp  "$T1wImageBrain".nii.gz "$OutputT1wImageBrain".nii.gz
${FSLDIR}/bin/fslmerge -t $OutputT1wTransform "$T1wImage".nii.gz "$T1wImage".nii.gz "$T1wImage".nii.gz
${FSLDIR}/bin/fslmaths $OutputT1wTransform -mul 0 $OutputT1wTransform

if [ ! "${T2wImage}" = "NONE" ] ; then
 ${FSLDIR}/bin/imcp  "$WD"/T2w2T1w.nii.gz "$OutputT2wImage".nii.gz
 ${FSLDIR}/bin/convertwarp --relout --rel -r "$OutputT2wImage".nii.gz -w $OutputT1wTransform --postmat="$WD"/T2w2T1w.mat --out="$OutputT2wTransform"
fi

log_Msg " End: T2w2T1Reg"
