#!/bin/bash

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

script_name=$(basename "${0}")

show_usage() {
	cat <<EOF

${script_name}

Usage: ${script_name} StudyFolder Subject SessionList TemplateID

Create base template from T1w images of cross-sectional sessions. Coregister each T2w image to the base template.
Make average T2w image and put it in the longitudinal template T2w/average folder.

EOF
}

# Allow script to return a Usage statement, before any other output or checking
if [ "$#" = "0" ]; then
    show_usage
    exit 1
fi

# ------------------------------------------------------------------------------
#  Check that HCPPIPEDIR is defined and Load Function Libraries
# ------------------------------------------------------------------------------

if [ -z "${HCPPIPEDIR}" ]; then
  echo "${script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
  exit 1
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source "${HCPPIPEDIR}/global/scripts/opts.shlib"                 # Command line option functions

opts_ShowVersionIfRequested "$@"

if opts_CheckForHelpRequest "$@"; then
	show_usage
	exit 0
fi

# ------------------------------------------------------------------------------
#  Verify required environment variables are set and log value
# ------------------------------------------------------------------------------

log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FREESURFER_HOME
log_Check_Env_Var CARET7DIR

# ------------------------------------------------------------------------------
#  Start work
# ------------------------------------------------------------------------------

echo -e "\n START: MakeAverageT2w.sh"

StudyFolder="$1"
Subject="$2"
Sessions="$3"
TemplateID="$4" #Base template ID
TemplateDir="$StudyFolder"/"$Subject.long.$TemplateID"


# 1. make template.
cmd=(mri_robust_template)
cmd_mov=()
cmd_lta=()


Sessions=$(echo "${Sessions}" | sed 's/@/ /g')

for session in ${Sessions[@]}; do
    cmd_mov+=("$StudyFolder/$session/T1w/$session/mri/orig/T2raw.mgz")
    cmd_lta+=("$TemplateDir/T1w/xfms/${session}_t2w2base.lta")
done

echo "${cmd_mov[@]}"

cmd+=(--mov "${cmd_mov[@]}")
cmd+=(--template "$TemplateDir/T2w/bootstrap_average.nii.gz" --iscale --satit)
#uncomment this to output T2w->average template transforms
#cmd+=(--lta ${cmd_lta[@]} --iscale --satit)

mkdir -p "$TemplateDir/T2w"

echo "${cmd[@]}"
"${cmd[@]}"

log_Msg "Completed MakeAverageT2w.sh"