#!/bin/bash 
set -e

# make pipeline engine happy...
if [ $# -eq 1 ]
	then
		echo "Version unknown..."
		exit 0
fi

#Input Variables
StudyFolder="$1" #Path to subject's data folder
Subject="$2" #SubjectID
T1wInputImages="$3" #T1w1@T1w2@etc..
T2wInputImages="$4" #T2w1@T2w2@etc..
T1wTemplate="$5" #MNI template
T1wTemplateBrain="$6" #Brain extracted MNI T1wTemplate
T1wTemplate2mm="$7" #MNI2mm T1wTemplate
T2wTemplate="${8}" #MNI T2wTemplate
T2wTemplateBrain="$9" #Brain extracted MNI T2wTemplate
T2wTemplate2mm="${10}" #MNI2mm T2wTemplate
TemplateMask="${11}" #Brain mask MNI Template
Template2mmMask="${12}" #Brain mask MNI2mm Template 
StandardFOVMask="${13}" #StandardFOV mask for averaging structurals
FNIRTConfig="${14}" #FNIRT 2mm T1w Config
FieldMapImageFolder="${15}" #Get session from SubjectID
MagnitudeInputName="${16}" #Expects 4D magitude volume with two 3D timepoints
PhaseInputName="${17}" #Expects 3D phase difference volume
TE="${18}" #delta TE for field map
T1wSampleSpacing="${19}" #DICOM field (0019,1018)
T2wSampleSpacing="${20}" #DICOM field (0019,1018) 
UnwarpDir="${21}" #z appears to be best
PipelineScripts="${22}" #Location where the pipeline modules are
Caret5_Command="${23}" #Location of Caret5 caret_command
GlobalScripts="${24}" #Location where the global pipeline modules are
GradientDistortionCoeffs="${25}" #Select correct coeffs for scanner or "NONE" to turn off
AvgrdcSTRING="${26}" #Averaging and readout distortion correction methods: "NONE" = average any repeats with no readout correction "FIELDMAP" = average any repeats and use field map for readout correction "TOPUP" = average and distortion correct at the same time with topup/applytopup only works for 2 images currently
TopupConfig="${27}" #Config for topup or "NONE" if not used

#Naming Conventions
T1wImage="T1w"
T1wFolder="T1w" #Location of T1w images
T2wImage="T2w" 
T2wFolder="T2w" #Location of T2w images
AtlasSpaceFolder="MNINonLinear"

#Build Paths
T1wFolder="$StudyFolder"/"$Subject"/"$T1wFolder" 
T2wFolder="$StudyFolder"/"$Subject"/"$T2wFolder" 
AtlasSpaceFolder="$StudyFolder"/"$Subject"/"$AtlasSpaceFolder"

#Unpack Averages
T1wInputImages=`echo "$T1wInputImages" | sed 's/@/ /g'`
T2wInputImages=`echo "$T2wInputImages" | sed 's/@/ /g'`

if [ ! -e "$T1wFolder"/xfms ] ; then
  mkdir -p "$T1wFolder"/xfms/
fi

if [ ! -e "$T2wFolder"/xfms ] ; then
  mkdir -p "$T2wFolder"/xfms/
fi

if [ ! -e "$AtlasSpaceFolder"/xfms ] ; then
  mkdir -p "$AtlasSpaceFolder"/xfms/
fi

DIR=`pwd`

echo "POSIXLY_CORRECT=""$POSIXLY_CORRECT"

#T1w and T2w gradient nonlinearity correction
OutputT1wImageSTRING=""
OutputT2wImageSTRING=""
if [ ! $GradientDistortionCoeffs = "NONE" ] ; then
  i=1
  for Image in $T1wInputImages ; do
    if [ ! -e "$T1wFolder"/"$T1wImage""$i""_GradientDistortionUnwarp" ] ; then    
      mkdir "$T1wFolder"/"$T1wImage""$i""_GradientDistortionUnwarp"
    fi
    cp "$Image" "$T1wFolder"/"$T1wImage""$i""_GradientDistortionUnwarp"/"$T1wImage""$i".nii.gz
    "$GlobalScripts"/GradientDistortionUnwarp.sh "$T1wFolder"/"$T1wImage""$i""_GradientDistortionUnwarp" "$GradientDistortionCoeffs" "$T1wFolder"/"$T1wImage""$i""_GradientDistortionUnwarp"/"$T1wImage""$i" "$T1wFolder"/"$T1wImage""$i"_gdc "$T1wFolder"/xfms/"$T1wImage""$i"_gdc_warp
    OutputT1wImageSTRING=`echo "$OutputT1wImageSTRING""$T1wFolder""/""$T1wImage""$i""_gdc "`
    i=$(($i+1))
  done
  i=1
  for Image in $T2wInputImages ; do
    if [ ! -e "$T2wFolder"/"$T2wImage""$i""_GradientDistortionUnwarp" ] ; then    
      mkdir "$T2wFolder"/"$T2wImage""$i""_GradientDistortionUnwarp"
    fi
    cp "$Image" "$T2wFolder"/"$T2wImage""$i""_GradientDistortionUnwarp"/"$T2wImage""$i".nii.gz
    "$GlobalScripts"/GradientDistortionUnwarp.sh "$T2wFolder"/"$T2wImage""$i""_GradientDistortionUnwarp" "$GradientDistortionCoeffs" "$T2wFolder"/"$T2wImage""$i""_GradientDistortionUnwarp"/"$T2wImage""$i" "$T2wFolder"/"$T2wImage""$i"_gdc "$T2wFolder"/xfms/"$T2wImage""$i"_gdc_warp
    OutputT2wImageSTRING=`echo "$OutputT2wImageSTRING""$T2wFolder""/""$T2wImage""$i""_gdc "`
    i=$(($i+1))
  done
else
  echo "NOT PERFORMING GRADIENT DISTORTION CORRECTION"
  i=1
  for Image in $T1wInputImages ; do
    cp "$Image" "$T1wFolder"/"$T1wImage""$i"_gdc.nii.gz
    OutputT1wImageSTRING=`echo "$OutputT1wImageSTRING""$T1wFolder""/""$T1wImage""$i""_gdc "`
    i=$(($i+1))
  done
  i=1
  for Image in $T2wInputImages ; do
    cp "$Image" "$T2wFolder"/"$T2wImage""$i"_gdc.nii.gz
    OutputT2wImageSTRING=`echo "$OutputT2wImageSTRING""$T2wFolder""/""$T2wImage""$i""_gdc "`
    i=$(($i+1))
  done
fi

#Average Like Scans
if [ `echo $T1wInputImages | wc -w` -gt 1 ] ; then
  mkdir -p "$T1wFolder"/AverageT1wImages
  if [ "$AvgrdcSTRING" = "TOPUP" ] ; then
    echo "PERFORMING TOPUP READOUT DISTORTION CORRECTION AND AVERAGING"
    "$PipelineScripts"/TopupDistortionCorrectAndAverage.sh "$T1wFolder"/AverageT1wImages "$OutputT1wImageSTRING" "$T1wFolder"/"$T1wImage" "$TopupConfig"
  else
    echo "PERFORMING SIMPLE AVERAGING"
    "$PipelineScripts"/AnatomicalAverage.sh -o "$T1wFolder"/"$T1wImage" -f "$StandardFOVMask" -s "$T1wTemplate" -m "$TemplateMask" -n -w "$T1wFolder"/AverageT1wImages --noclean -v $OutputT1wImageSTRING
  fi
else
  echo "ONLY ONE AVERAGE FOUND: COPYING"
  cp "$T1wFolder"/"$T1wImage"1_gdc.nii.gz "$T1wFolder"/"$T1wImage".nii.gz
fi

if [ `echo $T2wInputImages | wc -w` -gt 1 ] ; then
  mkdir -p "$T2wFolder"/AverageT2wImages
  if [ "$AvgrdcSTRING" = "TOPUP" ] ; then
    echo "PERFORMING TOPUP READOUT DISTORTION CORRECTION AND AVERAGING"
    "$PipelineScripts"/TopupDistortionCorrectAndAverage.sh "$T2wFolder"/AverageT2wImages "$OutputT2wImageSTRING" "$T2wFolder"/"$T2wImage" "$TopupConfig"
  else
    echo "PERFORMING SIMPLE AVERAGING"
    "$PipelineScripts"/AnatomicalAverage.sh -o "$T2wFolder"/"$T2wImage" -f "$StandardFOVMask" -s "$T2wTemplate" -m "$TemplateMask" -n -w "$T2wFolder"/AverageT2wImages --noclean -v $OutputT2wImageSTRING
  fi
else
  echo "ONLY ONE AVERAGE FOUND: COPYING"
  cp "$T2wFolder"/"$T2wImage"1_gdc.nii.gz "$T2wFolder"/"$T2wImage".nii.gz
fi

#acpc align T1w image to 0.8mm MNI T1wTemplate to create native volume space
mkdir -p "$T1wFolder"/ACPCAlignment
"$PipelineScripts"/ACPCAlignment.sh "$T1wFolder"/ACPCAlignment "$T1wFolder"/"$T1wImage" "$T1wTemplate" "$T1wFolder"/"$T1wImage"_acpc "$T1wFolder"/xfms/acpc.mat "$StandardFOVMask" "$GlobalScripts"

#Brain Extraction (FNIRT-based Masking) #Multiple Options to be evaluated here, however.
mkdir -p "$T1wFolder"/BrainExtraction_FNIRTbased
"$PipelineScripts"/BrainExtraction_FNIRTbased.sh "$T1wFolder"/BrainExtraction_FNIRTbased "$T1wFolder"/"$T1wImage"_acpc "$T1wTemplate" "$TemplateMask" "$T1wTemplate2mm" "$Template2mmMask" "$T1wFolder"/"$T1wImage"_acpc_brain "$T1wFolder"/"$T1wImage"_acpc_brain_mask "$FNIRTConfig"

#acpc align T1w image to 0.8mm MNI T1wTemplate to create native volume space
mkdir -p "$T2wFolder"/ACPCAlignment
"$PipelineScripts"/ACPCAlignment.sh "$T2wFolder"/ACPCAlignment "$T2wFolder"/"$T2wImage" "$T2wTemplate" "$T2wFolder"/"$T2wImage"_acpc "$T2wFolder"/xfms/acpc.mat "$StandardFOVMask" "$GlobalScripts"

#Brain Extraction (FNIRT-based Masking) #Multiple Options to be evaluated here, however.
mkdir -p "$T2wFolder"/BrainExtraction_FNIRTbased
"$PipelineScripts"/BrainExtraction_FNIRTbased.sh "$T2wFolder"/BrainExtraction_FNIRTbased "$T2wFolder"/"$T2wImage"_acpc "$T2wTemplate" "$TemplateMask" "$T2wTemplate2mm" "$Template2mmMask" "$T2wFolder"/"$T2wImage"_acpc_brain "$T2wFolder"/"$T2wImage"_acpc_brain_mask "$FNIRTConfig"

#T2w to T1w Registration and Optional Readout Distortion Correction
if [ "$AvgrdcSTRING" = "FIELDMAP" ] ; then
  echo "PERFORMING FIELDMAP READOUT DISTORTION CORRECTION"
  if [ -e "$T2wFolder"/T2wToT1wDistortionCorrectAndReg ] ; then
    rm -r "$T2wFolder"/T2wToT1wDistortionCorrectAndReg
  fi
  mkdir -p "$T2wFolder"/T2wToT1wDistortionCorrectAndReg    
 "$PipelineScripts"/T2wToT1wDistortionCorrectAndReg.sh "$T2wFolder"/T2wToT1wDistortionCorrectAndReg "$T1wFolder"/"$T1wImage"_acpc "$T1wFolder"/"$T1wImage"_acpc_brain "$T2wFolder"/"$T2wImage"_acpc "$T2wFolder"/"$T2wImage"_acpc_brain "$FieldMapImageFolder"/"$MagnitudeInputName" "$FieldMapImageFolder"/"$PhaseInputName" "$TE" "$T1wSampleSpacing" "$T2wSampleSpacing" "$UnwarpDir" "$T1wFolder"/"$T1wImage"_acpc_dc "$T1wFolder"/"$T1wImage"_acpc_dc_brain "$T1wFolder"/xfms/"$T1wImage"_dc "$T1wFolder"/"$T2wImage"_acpc_dc "$T1wFolder"/xfms/"$T2wImage"_reg_dc "$GlobalScripts" "$GradientDistortionCoeffs"
else
  if [ -e "$T2wFolder"/T2wToT1wReg ] ; then
    rm -r "$T2wFolder"/T2wToT1wReg
  fi
  mkdir -p "$T2wFolder"/T2wToT1wReg   
  "$PipelineScripts"/T2wToT1wReg.sh "$T2wFolder"/T2wToT1wReg "$T1wFolder"/"$T1wImage"_acpc "$T1wFolder"/"$T1wImage"_acpc_brain "$T2wFolder"/"$T2wImage"_acpc "$T2wFolder"/"$T2wImage"_acpc_brain "$T1wFolder"/"$T1wImage"_acpc_dc "$T1wFolder"/"$T1wImage"_acpc_dc_brain "$T1wFolder"/xfms/"$T1wImage"_dc "$T1wFolder"/"$T2wImage"_acpc_dc "$T1wFolder"/xfms/"$T2wImage"_reg_dc
fi  

#Bias Field Correction: Calculate bias field using square root of the product of T1w and T2w iamges.  Remove some additional non-brain tissue before dilating and smoothing bias field according to sigma
mkdir -p "$T1wFolder"/BiasFieldCorrection_sqrtT1wXT1w 
"$PipelineScripts"/BiasFieldCorrection_sqrtT1wXT1w.sh "$T1wFolder"/BiasFieldCorrection_sqrtT1wXT1w "$T1wFolder"/"$T1wImage"_acpc_dc "$T1wFolder"/"$T1wImage"_acpc_dc_brain "$T1wFolder"/"$T2wImage"_acpc_dc "$T1wFolder"/BiasField_acpc_dc "$T1wFolder"/"$T1wImage"_acpc_dc_restore "$T1wFolder"/"$T1wImage"_acpc_dc_restore_brain "$T1wFolder"/"$T2wImage"_acpc_dc_restore "$T1wFolder"/"$T2wImage"_acpc_dc_restore_brain "$Caret5_Command"

#Atlas Registration to MNI152: FLIRT + FNIRT  #Also applies registration to T1w and T2w images #Consider combining all transforms and recreating files with single resampling steps
"$PipelineScripts"/AtlasRegistrationToMNI152_FLIRTandFNIRT.sh "$AtlasSpaceFolder" "$T1wFolder"/"$T1wImage"_acpc_dc "$T1wFolder"/"$T1wImage"_acpc_dc_restore "$T1wFolder"/"$T1wImage"_acpc_dc_restore_brain "$T1wFolder"/"$T2wImage"_acpc_dc "$T1wFolder"/"$T2wImage"_acpc_dc_restore "$T1wFolder"/"$T2wImage"_acpc_dc_restore_brain "$T1wTemplate" "$T1wTemplateBrain" "$TemplateMask" "$T1wTemplate2mm" "$Template2mmMask" "$AtlasSpaceFolder"/xfms/acpc_dc2standard.nii.gz "$AtlasSpaceFolder"/xfms/standard2acpc_dc.nii.gz "$AtlasSpaceFolder"/"$T1wImage" "$AtlasSpaceFolder"/"$T1wImage"_restore "$AtlasSpaceFolder"/"$T1wImage"_restore_brain "$AtlasSpaceFolder"/"$T2wImage" "$AtlasSpaceFolder"/"$T2wImage"_restore "$AtlasSpaceFolder"/"$T2wImage"_restore_brain "$FNIRTConfig"

#FreeSurfer Script Generates Its Input
