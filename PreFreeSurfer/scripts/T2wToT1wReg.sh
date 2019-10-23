#!/bin/bash 

# ------------------------------------------------------------------------------
#  Verify required environment variables are set
# ------------------------------------------------------------------------------

if [ -z "${FSLDIR}" ]; then
	echo "$(basename ${0}): ABORTING: FSLDIR environment variable must be set"
	exit 1
else
	echo "$(basename ${0}): FSLDIR: ${FSLDIR}"
fi

if [ -z "${HCPPIPEDIR}" ]; then
	echo "$(basename ${0}): ABORTING: HCPPIPEDIR environment variable must be set"
	exit 1
else
	echo "$(basename ${0}): HCPPIPEDIR: ${HCPPIPEDIR}"
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@" # Debugging functions; also sources log.shlib

log_Msg "START: T2w2T1Reg"

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

T1wImageBrainFile=`basename "$T1wImageBrain"`

${FSLDIR}/bin/imcp "$T1wImageBrain" "$WD"/"$T1wImageBrainFile"

if [ "${T2wImage}" = "NONE" ] ; then
    log_Msg "Skipping T2w to T1w registration --- no T2w image."
else
    ${FSLDIR}/bin/epi_reg --epi="$T2wImageBrain" --t1="$T1wImage" --t1brain="$WD"/"$T1wImageBrainFile" --out="$WD"/T2w2T1w
    ${FSLDIR}/bin/applywarp --rel --interp=spline --in="$T2wImage" --ref="$T1wImage" --premat="$WD"/T2w2T1w.mat --out="$WD"/T2w2T1w
    ${FSLDIR}/bin/fslmaths "$WD"/T2w2T1w -add 1 "$WD"/T2w2T1w -odt float
fi

${FSLDIR}/bin/imcp "$T1wImage" "$OutputT1wImage"
${FSLDIR}/bin/imcp "$T1wImageBrain" "$OutputT1wImageBrain"
${FSLDIR}/bin/fslmerge -t $OutputT1wTransform "$T1wImage".nii.gz "$T1wImage".nii.gz "$T1wImage".nii.gz
${FSLDIR}/bin/fslmaths $OutputT1wTransform -mul 0 $OutputT1wTransform

if [ ! "${T2wImage}" = "NONE" ] ; then
    ${FSLDIR}/bin/imcp "$WD"/T2w2T1w "$OutputT2wImage"
    ${FSLDIR}/bin/convertwarp --relout --rel -r "$OutputT2wImage".nii.gz -w $OutputT1wTransform --postmat="$WD"/T2w2T1w.mat --out="$OutputT2wTransform"
fi
log_Msg "END: T2w2T1Reg"


