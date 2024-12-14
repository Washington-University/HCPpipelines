#!/bin/bash
set -eu
pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
  # pipedirguessed=1
   #fix this if the script is more than one level below HCPPIPEDIR
   export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"


opts_SetScriptDescription "Make some BIDS structures and run HippUnfold"

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject' 'Subject' 'subject ID' ""
opts_AddOptional '--hippunfold-dir' 'HippUnfoldDIR' 'path' "location of HippUnfold outputs"

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

opts_ShowValues

T1wFolder="$StudyFolder/$Subject/T1w"       # input data

if [ -z ${HippUnfoldDIR} ] ; then
  HippUnfoldDIR="${T1wFolder}/HippUnfold"
fi 

#Couldn't get non-BIDS to work (wouldn't do anything)
#HippUnfoldT1wFolder="$HippUnfoldDIR/T1w"
#HippUnfoldT2wFolder="$HippUnfoldDIR/T2w"
#HippUnfoldT2wFolder="$HippUnfoldDIR/T1wT2w"

HippUnfoldT1wFolder="$HippUnfoldDIR/T1w/sub-${Subject}/anat"
HippUnfoldT2wFolder="$HippUnfoldDIR/T2w/sub-${Subject}/anat"
HippUnfoldT1wT2wFolder="$HippUnfoldDIR/T1wT2w/sub-${Subject}/anat"

HippUnfoldT1wFolderOut="$HippUnfoldDIR/T1w_hippunfold"
HippUnfoldT2wFolderOut="$HippUnfoldDIR/T2w_hippunfold"
HippUnfoldT1wT2wFolderOut="$HippUnfoldDIR/T1wT2w_hippunfold"


T1wImage="$T1wFolder/T1w_acpc_dc_restore.nii.gz"
T2wImage="$T1wFolder/T2w_acpc_dc_restore.nii.gz"


if [ ! -f "$T1wImage" ]; then
    echo "Error: T1w image not found at $T1wImage" >&2
    exit 1
fi

if [ ! -f "$T2wImage" ]; then
    echo "Error: T2w image not found at $T2wImage" >&2
    exit 1
fi


mkdir -p "$HippUnfoldT1wFolder" "$HippUnfoldT2wFolder" "$HippUnfoldT1wT2wFolder"

#Couldn't get non-BIDS to work (wouldn't do anything)
#cp "$T1wImage" "$HippUnfoldT1wFolder/${Subject}_T1w_acpc_dc_restore.nii.gz"
#cp "$T2wImage" "$HippUnfoldT1wFolder/${Subject}_T2w_acpc_dc_restore.nii.gz"
#cp "$T1wImage" "$HippUnfoldT2wFolder/${Subject}_T1w_acpc_dc_restore.nii.gz"
#cp "$T2wImage" "$HippUnfoldT2wFolder/${Subject}_T2w_acpc_dc_restore.nii.gz"
#cp "$T1wImage" "$HippUnfoldT1wT2wFolder/${Subject}_T1w_acpc_dc_restore.nii.gz"
#cp "$T2wImage" "$HippUnfoldT1wT2wFolder/${Subject}_T2w_acpc_dc_restore.nii.gz"

cp "$T1wImage" "$HippUnfoldT1wFolder/sub-${Subject}_T1w.nii.gz"
cp "$T2wImage" "$HippUnfoldT1wFolder/sub-${Subject}_T2w.nii.gz"
cp "$T1wImage" "$HippUnfoldT2wFolder/sub-${Subject}_T1w.nii.gz"
cp "$T2wImage" "$HippUnfoldT2wFolder/sub-${Subject}_T2w.nii.gz"
cp "$T1wImage" "$HippUnfoldT1wT2wFolder/sub-${Subject}_T1w.nii.gz"
cp "$T2wImage" "$HippUnfoldT1wT2wFolder/sub-${Subject}_T2w.nii.gz"


log_Msg "Created folder structure under $HippUnfoldDIR and copied T1w and T2w images"
log_Msg "Starting HippUnfold pipeline for subject: $Subject"
  
#Couldn't get non-BIDS to work (wouldn't do anything)                                                                                                     #Seriously: don't put a $ here...
#apptainer run --bind $StudyFolder -e $HIPPUNFOLDPATH $HippUnfoldT1wFolder $HippUnfoldT1wFolder participant --modality T1w --path-T1w $HippUnfoldT1wFolder/{Subject}_T1w_acpc_dc_restore.nii.gz --cores all --force-output --generate_myelin_map
#apptainer run --bind $StudyFolder -e $HIPPUNFOLDPATH $HippUnfoldT2wFolder $HippUnfoldT2wFolder participant --modality T2w --path-T2w $HippUnfoldT2wFolder/{Subject}_T2w_acpc_dc_restore.nii.gz --cores all --force-output --generate_myelin_map
#apptainer run --bind $StudyFolder -e $HIPPUNFOLDPATH $HippUnfoldT2wFolder $HippUnfoldT2wFolder participant --modality T2w --path-T2w $HippUnfoldT2wFolder/{Subject}_T2w_acpc_dc_restore.nii.gz --cores all --force-output --generate_myelin_map --force-nnunet-model T1T2w

log_Msg "Running T1w HippUnfold for subject: $Subject"
apptainer run --bind $StudyFolder -e $HIPPUNFOLDPATH $HippUnfoldT1wFolder $HippUnfoldT1wFolderOut participant --modality T1w --cores all --force-output --generate_myelin_map --output-density 0p5mm 1mm 2mm
log_Msg "T1w HippUnfold completed."
log_Msg "Running T2w HippUnfold for subject: $Subject"
apptainer run --bind $StudyFolder -e $HIPPUNFOLDPATH $HippUnfoldT2wFolder $HippUnfoldT2wFolderOut participant --modality T2w --cores all --force-output --generate_myelin_map --output-density 0p5mm 1mm 2mm
log_Msg "T2w HippUnfold completed."
log_Msg "Running T1wT2w HippUnfold for subject: $Subject"
apptainer run --bind $StudyFolder -e $HIPPUNFOLDPATH $HippUnfoldT1wT2wFolder $HippUnfoldT1wT2wFolderOut participant --modality T1w --cores all --force-output --generate_myelin_map --output-density 0p5mm 1mm 2mm --force-nnunet-model T1T2w
log_Msg "T1wT2w HippUnfold completed."

log_Msg "HippUnfold pipeline completed successfully for subject: $Subject"
