#!/bin/bash -e

Path="$1"
Subject="$2"
fMRIFolder="$3"
FieldMapImageFolder="$4"
ScoutFolder="$5"
InputNameOffMRI="$6"
OutputNameOffMRI="$7"
MagnitudeInputName="$8" #Expects 4D volume with two 3D timepoints
PhaseInputName="$9"
ScoutInputName="${10}"
DwellTime="${11}"
TE="${12}"
UnwarpDir="${13}"
FinalFcMRIResolution="${14}"
PipelineScripts="${15}"
GlobalScripts="${16}"

#Naming Conventions
T1wImage="T1w_acpc_dc"
T1wRestoreImage="T1w_acpc_dc_restore"
T1wRestoreImageBrain="T1w_acpc_dc_restore_brain"
T1wFolder="T1w" #Location of T1w images
AtlasSpaceFolder="MNINonLinear"
ResultsFolder="Results"
BiasField="BiasField_acpc_dc"
BiasFieldMNI="BiasField"
T1wAtlasName="T1w_restore"
MovementRegressor="Movement_Regressors.txt"
MotionMatrixFolder="MotionMatrices"
MotionMatrixPrefix="MAT_"
FieldMapOutputName="FieldMap"
MagnitudeOutputName="Magnitude"
MagnitudeBrainOutputName="Magnitude_brain"
FreeSurferBrainMask="brainmask_fs"
fMRI2strOutputTransform="${OutputNameOffMRI}2str"
RegOutput="Scout2T1w"
AtlasTransform="acpc_dc2standard"
OutputfMRI2StandardTransform="${OutputNameOffMRI}2standard"

fMRIFolder="$fMRIFolder"
FieldMapImageFolder="$FieldMapImageFolder"
ScoutFolder="$ScoutFolder"
T1wFolder="$Path"/"$Subject"/"$T1wFolder"
AtlasSpaceFolder="$Path"/"$Subject"/"$AtlasSpaceFolder"
ResultsFolder="$AtlasSpaceFolder"/"$ResultsFolder"/"$OutputNameOffMRI"


#Gradient Distortion Correction of fMRI
cp -r "$fMRIFolder"/"$InputNameOffMRI".nii.gz "$fMRIFolder"/"$OutputNameOffMRI".nii.gz

#MotionCorrection
##mkdir "$fMRIFolder"/MotionCorrection_mcFLIRTbased
##"$PipelineComponents"/MotionCorrection_mcFLIRTbased.sh "$fMRIFolder"/MotionCorrection_mcFLIRTbased "$fMRIFolder"/"$OutputNameOffMRI" "$ScoutFolder"/"$ScoutInputName" "$fMRIFolder"/"$OutputNameOffMRI"_mc "$fMRIFolder"/"$MovementRegressor" "$fMRIFolder"/"$MotionMatrixFolder" "$MotionMatrixPrefix"

mkdir -p "$fMRIFolder"/MotionCorrection_FLIRTbased
"$PipelineScripts"/MotionCorrection_FLIRTbased.sh "$fMRIFolder"/MotionCorrection_FLIRTbased "$fMRIFolder"/"$OutputNameOffMRI" "$ScoutFolder"/"$ScoutInputName" "$fMRIFolder"/"$OutputNameOffMRI"_mc "$fMRIFolder"/"$MovementRegressor" "$fMRIFolder"/"$MotionMatrixFolder" "$MotionMatrixPrefix" "$PipelineScripts" "$GlobalScripts"

#FieldMap Preprocessing
mkdir -p "$fMRIFolder"/FieldMapPreProcessing
"$GlobalScripts"/FieldMapPreProcessing.sh "$fMRIFolder"/FieldMapPreProcessing "$FieldMapImageFolder"/"$MagnitudeInputName" "$FieldMapImageFolder"/"$PhaseInputName" "$FieldMapOutputName" "$MagnitudeOutputName" "$MagnitudeBrainOutputName" "$TE"

#EPI Distortion Correction and EPI to T1w Registration (For preprocessing evaluation, not for main pipeline)
##mkdir "$fMRIFolder"/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRbased
##"$PipelineComponents"/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRbased.sh "$fMRIFolder"/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRbased "$fMRIFolder"/"$OutputNameOffMRI"_mc "$ScoutFolder"/"$ScoutInputName" "$T1wFolder"/"$T1wImage" "$T1wFolder"/"$T1wRestoreImage" "$T1wFolder"/"$FreeSurferBrainMask" "$FieldMapImageFolder"/"$FieldMapOutputName" "$FieldMapImageFolder"/"$MagnitudeOutputName" "$FieldMapImageFolder"/"$MagnitudeBrainOutputName" "$DwellTime" "$UnwarpDir" "$T1wFolder"/xfms/"$fMRI2strOutputTransform" "$T1wFolder"/"$BiasField" "$fMRIFolder"/"$RegOutput"

#EPI Distortion Correction and EPI to T1w Registration (For preprocessing evaluation, not for main pipeline)
##mkdir "$fMRIFolder"/DistortionCorrectionAndEPIToT1wReg_FugueAndFreeSurferBBRbased
##"$PipelineComponents"/DistortionCorrectionAndEPIToT1wReg_FugueAndFreeSurferBBRbased.sh "$fMRIFolder"/DistortionCorrectionAndEPIToT1wReg_FugueAndFreeSurferBBRbased "$fMRIFolder"/"$OutputNameOffMRI"_mc "$ScoutFolder"/"$ScoutInputName" "$T1wFolder"/"$T1wImage" "$T1wFolder"/"$T1wRestoreImage" "$T1wFolder"/"$FreeSurferBrainMask" "$FieldMapImageFolder"/"$FieldMapOutputName" "$FieldMapImageFolder"/"$MagnitudeOutputName" "$FieldMapImageFolder"/"$MagnitudeBrainOutputName" "$DwellTime" "$UnwarpDir" "$T1wFolder"/xfms/"$fMRI2strOutputTransform" "$T1wFolder"/"$BiasField" "$fMRIFolder"/"$RegOutput" "$T1wFolder" "$Subject" 

#EPI Distortion Correction and EPI to T1w Registration (For preprocessing evaluation, not for main pipeline) includes VSM option (Unfinished)
##mkdir "$fMRIFolder"/DistortionCorrectionAndEPIToT1wReg_FugueAndFreeSurferBBRbasedVSM
##"$PipelineComponents"/DistortionCorrectionAndEPIToT1wReg_FugueAndFreeSurferBBRbasedVSM.sh "$fMRIFolder"/DistortionCorrectionAndEPIToT1wReg_FugueAndFreeSurferBBRbasedVSM "$fMRIFolder"/"$OutputNameOffMRI"_mc "$ScoutFolder"/"$ScoutInputName" "$T1wFolder"/"$T1wImage" "$T1wFolder"/"$T1wRestoreImage" "$T1wFolder"/"$FreeSurferBrainMask" "$FieldMapImageFolder"/"$FieldMapOutputName" "$FieldMapImageFolder"/"$MagnitudeOutputName" "$FieldMapImageFolder"/"$MagnitudeBrainOutputName" "$DwellTime" "$UnwarpDir" "$T1wFolder"/xfms/"$fMRI2strOutputTransform" "$T1wFolder"/"$BiasField" "$fMRIFolder"/"$RegOutput" "$T1wFolder" "$Subject" 

#EPI Distortion Correction and EPI to T1w Registration
if [ -e "$fMRIFolder"/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased ] ; then
  rm -r "$fMRIFolder"/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased
fi
mkdir -p "$fMRIFolder"/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased

"$PipelineScripts"/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased.sh "$fMRIFolder"/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased "$ScoutFolder"/"$ScoutInputName" "$T1wFolder"/"$T1wImage" "$T1wFolder"/"$T1wRestoreImage" "$T1wFolder"/"$T1wRestoreImageBrain" "$fMRIFolder"/FieldMapPreProcessing/"$FieldMapOutputName" "$fMRIFolder"/FieldMapPreProcessing/"$MagnitudeOutputName" "$fMRIFolder"/FieldMapPreProcessing/"$MagnitudeBrainOutputName" "$DwellTime" "$UnwarpDir" "$T1wFolder"/xfms/"$fMRI2strOutputTransform" "$T1wFolder"/"$BiasField" "$fMRIFolder"/"$RegOutput" "$T1wFolder" "$Subject" "$GlobalScripts"

#One Step Resampling
mkdir -p "$fMRIFolder"/OneStepResampling
"$PipelineScripts"/OneStepResampling.sh "$fMRIFolder"/OneStepResampling "$fMRIFolder"/"$OutputNameOffMRI" "$AtlasSpaceFolder"/"$T1wAtlasName" "$FinalFcMRIResolution" "$AtlasSpaceFolder" "$T1wFolder"/xfms/"$fMRI2strOutputTransform" "$AtlasSpaceFolder"/xfms/"$AtlasTransform" "$AtlasSpaceFolder"/xfms/"$OutputfMRI2StandardTransform" "$fMRIFolder"/"$MotionMatrixFolder" "$MotionMatrixPrefix" "$fMRIFolder"/"$OutputNameOffMRI"_nonlin "$AtlasSpaceFolder"/"$FreeSurferBrainMask" "$AtlasSpaceFolder"/"$BiasFieldMNI"

#Intensity Normalization and Bias Removal
"$PipelineScripts"/IntensityNormalization.sh "$fMRIFolder"/"$OutputNameOffMRI"_nonlin "$AtlasSpaceFolder"/"$BiasFieldMNI"."$FinalFcMRIResolution" "$AtlasSpaceFolder"/"$FreeSurferBrainMask"."$FinalFcMRIResolution" "$fMRIFolder"/"$OutputNameOffMRI"_nonlin_norm

mkdir -p "$ResultsFolder"
cp -r "$fMRIFolder"/"$OutputNameOffMRI"_nonlin_norm.nii.gz "$ResultsFolder"/"$OutputNameOffMRI".nii.gz
cp -r "$fMRIFolder"/"$MovementRegressor" "$ResultsFolder"/"$MovementRegressor"


