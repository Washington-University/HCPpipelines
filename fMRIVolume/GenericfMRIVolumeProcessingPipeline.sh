#!/bin/bash -e

if [ $# -eq 1 ]
	then
		echo "Version unknown..."
		exit 0
fi

Path="$1"
Subject="$2"
fMRIFolder="$3"
FieldMapImageFolder="$4"
ScoutFolder="$5"
InputNameOffMRI="$6"
OutputNameOffMRI="$7"
MagnitudeInputName="$8" #Expects 4D volume with two 3D timepoints
PhaseInputName="$9"
ScoutInputName="${10}" #Can be set to NONE, to fake, but this is not recommended
DwellTime="${11}"
TE="${12}"
UnwarpDir="${13}"
FinalfMRIResolution="${14}"
PipelineScripts="${15}"
GlobalScripts="${16}"
DistortionCorrection="${17}" #FIELDMAP or TOPUP (not functional currently)
GradientDistortionCoeffs="${18}"
FNIRTConfig="${19}" #NONE to turn off approximate zblip correction
TopupConfig="${20}" #NONE if Topup is not being used

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
MovementRegressor="Movement_Regressors" #No extension, .txt appended
MotionMatrixFolder="MotionMatrices"
MotionMatrixPrefix="MAT_"
FieldMapOutputName="FieldMap"
MagnitudeOutputName="Magnitude"
MagnitudeBrainOutputName="Magnitude_brain"
ScoutName="Scout"
FreeSurferBrainMask="brainmask_fs"
fMRI2strOutputTransform="${OutputNameOffMRI}2str"
RegOutput="Scout2T1w"
AtlasTransform="acpc_dc2standard"
OutputfMRI2StandardTransform="${OutputNameOffMRI}2standard"
T2wRestoreImage="T2w_acpc_dc_restore"
QAImage="T1wMulEPI"

fMRIFolder="$Path"/"$Subject"/"$fMRIFolder"
FieldMapImageFolder="$Path"/"$Subject"/"$FieldMapImageFolder"
ScoutFolder="$Path"/"$Subject"/"$ScoutFolder"
T1wFolder="$Path"/"$Subject"/"$T1wFolder"
AtlasSpaceFolder="$Path"/"$Subject"/"$AtlasSpaceFolder"
ResultsFolder="$AtlasSpaceFolder"/"$ResultsFolder"/"$OutputNameOffMRI"

#Create "Scout" if it doesn't exist
if [ $ScoutInputName = "NONE" ] ; then
  ScoutInputName="FakeScoutInput"
  ScoutFolder="${fMRIFolder}_SB"
  if [ ! -e $ScoutFolder ] ; then 
    mkdir $ScoutFolder
  fi
  fslroi "$fMRIFolder"/"$InputNameOffMRI" "$fMRIFolder"_SB/"$ScoutInputName" 0 1
fi

#Gradient Distortion Correction of fMRI
if [ ! $GradientDistortionCoeffs = "NONE" ] ; then
  if [ ! -e "$fMRIFolder"/GradientDistortionUnwarp ] ; then    
    mkdir "$fMRIFolder"/GradientDistortionUnwarp
  fi
  cp "$fMRIFolder"/"$InputNameOffMRI" "$fMRIFolder"/GradientDistortionUnwarp/"$OutputNameOffMRI".nii.gz
  "$GlobalScripts"/GradientDistortionUnwarp.sh "$fMRIFolder"/GradientDistortionUnwarp "$GradientDistortionCoeffs" "$fMRIFolder"/GradientDistortionUnwarp/"$OutputNameOffMRI" "$fMRIFolder"/"$OutputNameOffMRI"_gdc "$fMRIFolder"/"$OutputNameOffMRI"_gdc_warp
  if [ ! -e "$ScoutFolder"/GradientDistortionUnwarp ] ; then    
    mkdir "$ScoutFolder"/GradientDistortionUnwarp
  fi
  cp "$ScoutFolder"/"$ScoutInputName" "$ScoutFolder"/GradientDistortionUnwarp/"$ScoutName".nii.gz
  "$GlobalScripts"/GradientDistortionUnwarp.sh "$ScoutFolder"/GradientDistortionUnwarp "$GradientDistortionCoeffs" "$ScoutFolder"/GradientDistortionUnwarp/"$ScoutName" "$ScoutFolder"/"$ScoutName"_gdc "$ScoutFolder"/"$ScoutName"_gdc_warp
else
  echo "NOT PERFORMING GRADIENT DISTORTION CORRECTION"
  cp "$fMRIFolder"/"$InputNameOffMRI" "$fMRIFolder"/"$OutputNameOffMRI"_gdc.nii.gz
  fslroi "$fMRIFolder"/"$OutputNameOffMRI"_gdc.nii.gz "$fMRIFolder"/"$OutputNameOffMRI"_gdc_warp.nii.gz 0 3
  fslmaths "$fMRIFolder"/"$OutputNameOffMRI"_gdc_warp.nii.gz -mul 0 "$fMRIFolder"/"$OutputNameOffMRI"_gdc_warp.nii.gz
  cp "$ScoutFolder"/"$ScoutInputName" "$ScoutFolder"/"$ScoutName"_gdc.nii.gz
fi

mkdir -p "$fMRIFolder"/MotionCorrection_FLIRTbased
"$PipelineScripts"/MotionCorrection_FLIRTbased.sh "$fMRIFolder"/MotionCorrection_FLIRTbased "$fMRIFolder"/"$OutputNameOffMRI"_gdc "$ScoutFolder"/"$ScoutName"_gdc "$fMRIFolder"/"$OutputNameOffMRI"_mc "$fMRIFolder"/"$MovementRegressor" "$fMRIFolder"/"$MotionMatrixFolder" "$MotionMatrixPrefix" "$PipelineScripts" "$GlobalScripts"

#EPI Distortion Correction and EPI to T1w Registration
if [ -e "$fMRIFolder"/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased ] ; then
  rm -r "$fMRIFolder"/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased
fi
mkdir -p "$fMRIFolder"/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased
"$PipelineScripts"/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased.sh "$fMRIFolder"/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased "$ScoutFolder"/"$ScoutName"_gdc "$T1wFolder"/"$T1wImage" "$T1wFolder"/"$T1wRestoreImage" "$T1wFolder"/"$T1wRestoreImageBrain" "$FieldMapImageFolder"/"$MagnitudeInputName" "$FieldMapImageFolder"/"$PhaseInputName" "$TE" "$DwellTime" "$UnwarpDir" "$T1wFolder"/xfms/"$fMRI2strOutputTransform" "$T1wFolder"/"$BiasField" "$fMRIFolder"/"$RegOutput" "$T1wFolder" "$Subject" "$GlobalScripts" "$GradientDistortionCoeffs" "$T1wFolder"/"$T2wRestoreImage" "$FNIRTConfig" "$fMRIFolder"/"$QAImage" "$DistortionCorrection" "$TopupConfig"

#One Step Resampling
mkdir -p "$fMRIFolder"/OneStepResampling
"$PipelineScripts"/OneStepResampling.sh "$fMRIFolder"/OneStepResampling "$fMRIFolder"/"$InputNameOffMRI" "$AtlasSpaceFolder"/"$T1wAtlasName" "$FinalfMRIResolution" "$AtlasSpaceFolder" "$T1wFolder"/xfms/"$fMRI2strOutputTransform" "$AtlasSpaceFolder"/xfms/"$AtlasTransform" "$AtlasSpaceFolder"/xfms/"$OutputfMRI2StandardTransform" "$fMRIFolder"/"$MotionMatrixFolder" "$MotionMatrixPrefix" "$fMRIFolder"/"$OutputNameOffMRI"_nonlin "$AtlasSpaceFolder"/"$FreeSurferBrainMask" "$AtlasSpaceFolder"/"$BiasFieldMNI" "$fMRIFolder"/"$OutputNameOffMRI"_gdc_warp

#Intensity Normalization and Bias Removal
"$PipelineScripts"/IntensityNormalization.sh "$fMRIFolder"/"$OutputNameOffMRI"_nonlin "$AtlasSpaceFolder"/"$BiasFieldMNI"."$FinalfMRIResolution" "$AtlasSpaceFolder"/"$FreeSurferBrainMask"."$FinalfMRIResolution" "$fMRIFolder"/"$OutputNameOffMRI"_nonlin_norm

mkdir -p "$ResultsFolder"
cp -r "$fMRIFolder"/"$OutputNameOffMRI"_nonlin_norm.nii.gz "$ResultsFolder"/"$OutputNameOffMRI".nii.gz
cp -r "$fMRIFolder"/"$MovementRegressor".txt "$ResultsFolder"/"$MovementRegressor".txt
cp -r "$fMRIFolder"/"$MovementRegressor"_dt.txt "$ResultsFolder"/"$MovementRegressor"_dt.txt


