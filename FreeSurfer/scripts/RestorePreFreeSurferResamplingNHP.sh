#! /bin/bash
# RevertPreFreeSurferResample.sh
# revert PreFreeSurfer resampling

set -eu

Usage () {
echo "Revert PreFreeSurfer resampling"
echo "$0 <StudyFolder> <Subject>"
exit 1;
}
[[ -z "${2:-}" ]] && Usage

# ------------------------------------------------------------------------------
#  Check that HCPPIPEDIR is defined and Load Function Libraries
# ------------------------------------------------------------------------------
if [[ -z "${HCPPIPEDIR:-}" ]]; then
  echo "ERROR: ABORTING: HCPPIPEDIR environment variable must be set"
  exit 1
fi
source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib

# ------------------------------------------------------------------------------
#  Verify required environment variables are set and log value
# ------------------------------------------------------------------------------

log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FSLDIR

StudyFolder=$1
Subject=$2
T1wFolder="$StudyFolder"/"$Subject"/T1w
T2wFolder="$StudyFolder"/"$Subject"/T2w

log_Msg "START: RevertPreFreeSurferResamapling.sh"
if [ -e "$T2wFolder"/T2wToT1wDistortionCorrectAndReg ] ; then 
	log_Msg "  reverting T1w_acpc_dc & T1w_acpc_dc_brain"
	T2wToT1wFolder="$T2wFolder"/T2wToT1wDistortionCorrectAndReg
	${FSLDIR}/bin/imcp ${T2wToT1wFolder}/T1w_acpc "$T1wFolder"/T1w_acpc_dc
	${FSLDIR}/bin/imcp ${T2wToT1wFolder}/T1w_acpc_brain "$T1wFolder"/T1w_acpc_dc_brain
	if [ $(${FSLDIR}/bin/imtest "${T2wFolder}"/T2w_acpc) = 1 ] ; then
		log_Msg "  reverting revert T2w_acpc_dc"
		${FSLDIR}/bin/imcp ${T2wToT1wFolder}/T2w2T1w/T2w_reg "$T1wFolder"/T2w_acpc_dc
	fi
else
	log_Msg "  reverting T1w_acpc_dc & T1w_acpc_dc_brain"
	${FSLDIR}/bin/imcp "$T1wFolder"/T1w_acpc "$T1wFolder"/T1w_acpc_dc
	${FSLDIR}/bin/imcp "$T1wFolder"/T1w_acpc_brain "$T1wFolder"/T1w_acpc_dc_brain
	if [ $(${FSLDIR}/bin/imtest "${T2wFolder}"/T2w_acpc) = 1 ] ; then
		log_Msg "  reverting revert T2w_acpc_dc"
		T2wToT1wFolder="$T2wFolder"/T2wToT1wReg
		${FSLDIR}/bin/imcp "$T2wToT1wFolder"/T2w2T1w "$T1wFolder"/T2w_acpc_dc
	fi
fi

log_Msg "  reverting T1w_acpc_dc_restore & T1w_acpc_dc_restore_brain"
${FSLDIR}/bin/fslmaths "$T1wFolder"/T1w_acpc -div ${T1wFolder}/BiasField_acpc_dc -mas "$T1wFolder"/T1w_acpc_dc_brain "$T1wFolder"/T1w_acpc_dc_restore_brain -odt float
${FSLDIR}/bin/fslmaths "$T1wFolder"/T1w_acpc_dc -div ${T1wFolder}/BiasField_acpc_dc "$T1wFolder"/T1w_acpc_dc_restore -odt float

if [ $(${FSLDIR}/bin/imtest "${T2wFolder}"/T2w_acpc) = 1 ] ; then
	log_Msg "  reverting T2w_acpc_dc_restore & T2w_acpc_dc_restore_brain"
	${FSLDIR}/bin/fslmaths "$T1wFolder"/T2w_acpc_dc -div ${T1wFolder}/BiasField_acpc_dc -mas "$T1wFolder"/T1w_acpc_dc_brain "$T1wFolder"/T2w_acpc_dc_restore_brain -odt float
	${FSLDIR}/bin/fslmaths "$T1wFolder"/T2w_acpc_dc -div ${T1wFolder}/BiasField_acpc_dc "$T1wFolder"/T2w_acpc_dc_restore -odt float
fi

if [ $(${FSLDIR}/bin/imtest "$T1wFolder"/xfms/OrigT1w2T1w) = 1 ] ; then
	${FSLDIR}/bin/imrm "$T1wFolder"/xfms/OrigT1w2T1w
fi

log_Msg "END: RevertPreFreeSurferResamapling.sh"
