#!/bin/bash

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

script_name=$(basename "${0}")

show_usage() {
	cat <<EOF

${script_name}: Sub-script of PostFreeSurferPipeline.sh

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
source ${HCPPIPEDIR}/global/scripts/opts.shlib                 # Command line option functions

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
	show_usage
	exit 0
fi

# ------------------------------------------------------------------------------
#  Verify required environment variables are set and log value
# ------------------------------------------------------------------------------

log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var CARET7DIR

# ------------------------------------------------------------------------------
#  Start work
# ------------------------------------------------------------------------------

log_Msg "START"

StudyFolder="${1}"
Session="${2}"
T1wFolder="${3}"
AtlasSpaceFolder="${4}"
NativeFolder="${5}"
AtlasSpaceT1wImage="${6}"
T1wImage="${7}"
FreeSurferLabels="${8}"

LeftGreyRibbonValue="3"
LeftWhiteMaskValue="2"
RightGreyRibbonValue="42"
RightWhiteMaskValue="41"

for Hemisphere in L R ; do
  if [ $Hemisphere = "L" ] ; then
    GreyRibbonValue="$LeftGreyRibbonValue"
    WhiteMaskValue="$LeftWhiteMaskValue"
  elif [ $Hemisphere = "R" ] ; then
    GreyRibbonValue="$RightGreyRibbonValue"
    WhiteMaskValue="$RightWhiteMaskValue"
  fi    
  ${CARET7DIR}/wb_command -create-signed-distance-volume "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white.native.surf.gii "$T1wFolder"/"$T1wImage".nii.gz "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white.native.nii.gz
  ${CARET7DIR}/wb_command -create-signed-distance-volume "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".pial.native.surf.gii "$T1wFolder"/"$T1wImage".nii.gz "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".pial.native.nii.gz
  fslmaths "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white.native.nii.gz -thr 0 -bin -mul 255 "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white_thr0.native.nii.gz
  fslmaths "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white_thr0.native.nii.gz -bin "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white_thr0.native.nii.gz
  fslmaths "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".pial.native.nii.gz -uthr 0 -abs -bin -mul 255 "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".pial_uthr0.native.nii.gz
  fslmaths "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".pial_uthr0.native.nii.gz -bin "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".pial_uthr0.native.nii.gz
  fslmaths "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".pial_uthr0.native.nii.gz -mas "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white_thr0.native.nii.gz -mul 255 "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".ribbon.nii.gz
  fslmaths "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".ribbon.nii.gz -bin -mul $GreyRibbonValue "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".ribbon.nii.gz
  fslmaths "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white.native.nii.gz -uthr 0 -abs -bin -mul 255 "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white_uthr0.native.nii.gz
  fslmaths "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white_uthr0.native.nii.gz -bin "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white_uthr0.native.nii.gz
  fslmaths "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white_uthr0.native.nii.gz -mul $WhiteMaskValue "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white_mask.native.nii.gz
  fslmaths "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".ribbon.nii.gz -add "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white_mask.native.nii.gz "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".ribbon.nii.gz
  rm "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white.native.nii.gz "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white_thr0.native.nii.gz "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".pial.native.nii.gz "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".pial_uthr0.native.nii.gz "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white_uthr0.native.nii.gz "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white_mask.native.nii.gz
done

fslmaths "$T1wFolder"/"$NativeFolder"/"$Session".L.ribbon.nii.gz -add "$T1wFolder"/"$NativeFolder"/"$Session".R.ribbon.nii.gz "$T1wFolder"/ribbon.nii.gz
rm "$T1wFolder"/"$NativeFolder"/"$Session".L.ribbon.nii.gz "$T1wFolder"/"$NativeFolder"/"$Session".R.ribbon.nii.gz
${CARET7DIR}/wb_command -volume-label-import "$T1wFolder"/ribbon.nii.gz "$FreeSurferLabels" "$T1wFolder"/ribbon.nii.gz -drop-unused-labels


for Hemisphere in L R ; do
  if [ $Hemisphere = "L" ] ; then
    GreyRibbonValue="$LeftGreyRibbonValue"
    WhiteMaskValue="$LeftWhiteMaskValue"
  elif [ $Hemisphere = "R" ] ; then
    GreyRibbonValue="$RightGreyRibbonValue"
    WhiteMaskValue="$RightWhiteMaskValue"
  fi    
  ${CARET7DIR}/wb_command -create-signed-distance-volume "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white.native.surf.gii "$AtlasSpaceFolder"/"$AtlasSpaceT1wImage".nii.gz "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white.native.nii.gz
  ${CARET7DIR}/wb_command -create-signed-distance-volume "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".pial.native.surf.gii "$AtlasSpaceFolder"/"$AtlasSpaceT1wImage".nii.gz "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".pial.native.nii.gz
  fslmaths "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white.native.nii.gz -thr 0 -bin -mul 255 "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white_thr0.native.nii.gz
  fslmaths "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white_thr0.native.nii.gz -bin "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white_thr0.native.nii.gz
  fslmaths "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".pial.native.nii.gz -uthr 0 -abs -bin -mul 255 "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".pial_uthr0.native.nii.gz
  fslmaths "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".pial_uthr0.native.nii.gz -bin "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".pial_uthr0.native.nii.gz
  fslmaths "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".pial_uthr0.native.nii.gz -mas "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white_thr0.native.nii.gz -mul 255 "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".ribbon.nii.gz
  fslmaths "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".ribbon.nii.gz -bin -mul $GreyRibbonValue "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".ribbon.nii.gz
  fslmaths "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white.native.nii.gz -uthr 0 -abs -bin -mul 255 "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white_uthr0.native.nii.gz
  fslmaths "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white_uthr0.native.nii.gz -bin "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white_uthr0.native.nii.gz
  fslmaths "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white_uthr0.native.nii.gz -mul $WhiteMaskValue "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white_mask.native.nii.gz
  fslmaths "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".ribbon.nii.gz -add "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white_mask.native.nii.gz "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".ribbon.nii.gz
  rm "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white.native.nii.gz "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white_thr0.native.nii.gz "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".pial.native.nii.gz "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".pial_uthr0.native.nii.gz "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white_uthr0.native.nii.gz "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".white_mask.native.nii.gz
done

fslmaths "$AtlasSpaceFolder"/"$NativeFolder"/"$Session".L.ribbon.nii.gz -add "$AtlasSpaceFolder"/"$NativeFolder"/"$Session".R.ribbon.nii.gz "$AtlasSpaceFolder"/ribbon.nii.gz
rm "$AtlasSpaceFolder"/"$NativeFolder"/"$Session".L.ribbon.nii.gz "$AtlasSpaceFolder"/"$NativeFolder"/"$Session".R.ribbon.nii.gz
${CARET7DIR}/wb_command -volume-label-import "$AtlasSpaceFolder"/ribbon.nii.gz "$FreeSurferLabels" "$AtlasSpaceFolder"/ribbon.nii.gz -drop-unused-labels

log_Msg "END"

