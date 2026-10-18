#!/bin/bash

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

script_name=$(basename "${0}")

show_usage() {
	cat <<EOF

${script_name}: Sub-script of GenericfMRISurfaceProcessingPipeline.sh

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

AtlasSpaceFolder="$1"
log_Msg "AtlasSpaceFolder: ${AtlasSpaceFolder}"

ROIFolder="$2"
log_Msg "ROIFolder: ${ROIFolder}"

FinalfMRIResolution="$3"
log_Msg "FinalfMRIResolution: ${FinalfMRIResolution}"

ResultsFolder="$4"
log_Msg "ResultsFolder: ${ResultsFolder}"

NameOffMRI="$5"
log_Msg "NameOffMRI: ${NameOffMRI}"

SmoothingFWHM="$6"
log_Msg "SmoothingFWHM: ${SmoothingFWHM}"

BrainOrdinatesResolution="$7"
log_Msg "BrainOrdinatesResolution: ${BrainOrdinatesResolution}"

VolumefMRI="${ResultsFolder}/${NameOffMRI}"
log_Msg "VolumefMRI: ${VolumefMRI}"

Sigma=`echo "$SmoothingFWHM / (2 * sqrt(2 * l(2)))" | bc -l`
log_Msg "Sigma: ${Sigma}"

#NOTE: wmparc has dashes in structure names, which -cifti-create-* won't accept
#ROIs files have acceptable structure names

#deal with fsl_sub being silly when we want to use numeric equality on decimals
unset POSIXLY_CORRECT

#generate subject-roi space fMRI cifti for subcortical
if [[ `echo "$BrainOrdinatesResolution == $FinalfMRIResolution" | bc -l | cut -f1 -d.` == "1" ]]
then
    log_Msg "Creating subject-roi subcortical cifti at same resolution as output"
    ${CARET7DIR}/wb_command -cifti-create-dense-timeseries ${ResultsFolder}/${NameOffMRI}_temp_subject.dtseries.nii -volume "$VolumefMRI".nii.gz "$ROIFolder"/ROIs."$BrainOrdinatesResolution".nii.gz
else
    log_Msg "Creating subject-roi subcortical cifti at differing fMRI resolution"
    ${CARET7DIR}/wb_command -volume-affine-resample "$ROIFolder"/ROIs."$BrainOrdinatesResolution".nii.gz $FSLDIR/etc/flirtsch/ident.mat "$VolumefMRI".nii.gz ENCLOSING_VOXEL "$ResultsFolder"/ROIs."$FinalfMRIResolution".nii.gz
    ${CARET7DIR}/wb_command -cifti-create-dense-timeseries ${ResultsFolder}/${NameOffMRI}_temp_subject.dtseries.nii -volume "$VolumefMRI".nii.gz "$ResultsFolder"/ROIs."$FinalfMRIResolution".nii.gz
    rm -f "$ResultsFolder"/ROIs."$FinalfMRIResolution".nii.gz
fi

log_Msg "Dilating out zeros"
#dilate out any exact zeros in the input data, for instance if the brain mask is wrong. Note that the CIFTI space cannot contain zeros to produce a valid CIFTI file (dilation also occurs below).
${CARET7DIR}/wb_command -cifti-dilate ${ResultsFolder}/${NameOffMRI}_temp_subject.dtseries.nii COLUMN 0 30 ${ResultsFolder}/${NameOffMRI}_temp_subject_dilate.dtseries.nii
rm -f ${ResultsFolder}/${NameOffMRI}_temp_subject.dtseries.nii

log_Msg "Generate atlas subcortical template cifti"
${CARET7DIR}/wb_command -cifti-create-label ${ResultsFolder}/${NameOffMRI}_temp_template.dlabel.nii -volume "$ROIFolder"/Atlas_ROIs."$BrainOrdinatesResolution".nii.gz "$ROIFolder"/Atlas_ROIs."$BrainOrdinatesResolution".nii.gz

#As of wb_command 1.4.0 and later, volume predilate is much less important for reducing edge ringing, and could be reduced
if [[ `echo "${Sigma} > 0" | bc -l | cut -f1 -d.` == "1" ]]
then
    log_Msg "Smoothing and resampling"
    #this is the whole timeseries, so don't overwrite, in order to allow on-disk writing, then delete temporary
    ${CARET7DIR}/wb_command -cifti-smoothing ${ResultsFolder}/${NameOffMRI}_temp_subject_dilate.dtseries.nii 0 ${Sigma} COLUMN ${ResultsFolder}/${NameOffMRI}_temp_subject_smooth.dtseries.nii -fix-zeros-volume
    #resample, delete temporary
    ${CARET7DIR}/wb_command -cifti-resample ${ResultsFolder}/${NameOffMRI}_temp_subject_smooth.dtseries.nii COLUMN ${ResultsFolder}/${NameOffMRI}_temp_template.dlabel.nii COLUMN ADAP_BARY_AREA CUBIC ${ResultsFolder}/${NameOffMRI}_temp_atlas.dtseries.nii -volume-predilate 10
    rm -f ${ResultsFolder}/${NameOffMRI}_temp_subject_smooth.dtseries.nii
else
    log_Msg "Resampling"
    ${CARET7DIR}/wb_command -cifti-resample ${ResultsFolder}/${NameOffMRI}_temp_subject_dilate.dtseries.nii COLUMN ${ResultsFolder}/${NameOffMRI}_temp_template.dlabel.nii COLUMN ADAP_BARY_AREA CUBIC ${ResultsFolder}/${NameOffMRI}_temp_atlas.dtseries.nii -volume-predilate 10
fi

#delete common temporaries
rm -f ${ResultsFolder}/${NameOffMRI}_temp_subject_dilate.dtseries.nii
rm -f ${ResultsFolder}/${NameOffMRI}_temp_template.dlabel.nii

#the standard space output cifti must not contain zeros (or correlation, ICA, variance normalization, etc will break), so dilate in case freesurfer was unable to segment something (may only be applicable for bad quality structurals)
#NOTE: wb_command v1.4.0 and later should only output exact 0s past the edge of predilate, so this works as desired
#earlier verions of wb_command may produce undesired results in the subjects that need this dilation
${CARET7DIR}/wb_command -cifti-dilate ${ResultsFolder}/${NameOffMRI}_temp_atlas.dtseries.nii COLUMN 0 30 ${ResultsFolder}/${NameOffMRI}_temp_atlas_dilate.dtseries.nii
rm -f ${ResultsFolder}/${NameOffMRI}_temp_atlas.dtseries.nii

#write output volume, delete temporary
#NOTE: $VolumefMRI contains a path in it, it is not a file in the current directory
${CARET7DIR}/wb_command -cifti-separate ${ResultsFolder}/${NameOffMRI}_temp_atlas_dilate.dtseries.nii COLUMN -volume-all "$VolumefMRI"_AtlasSubcortical_s"$SmoothingFWHM".nii.gz
rm -f ${ResultsFolder}/${NameOffMRI}_temp_atlas_dilate.dtseries.nii

log_Msg "END"

