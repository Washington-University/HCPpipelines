#!/bin/bash 
set -e

# make pipeline engine happy...
if [ $# -eq 1 ]
	then
		echo "Version unknown..."
		exit 0
fi

#Input Variables
StudyFolder="$1" #Path to subject's data
Subject="$2" #SubjectID
T1wInputImage1="$3"  #T1w image name 1
T1wInputImage2="$4"  #T1w image name 2
T2wInputImage1="$5" #T2w image name 1
T2wInputImage2="$6" #T2w image name 2
T1wTemplate="$7" #MNI0.8mm T1wTemplate
T1wTemplateBrain="$8" #Brain extracted MNI0.8mm T1wTemplate
T1wTemplate2mm="$9" #MNI2mm T1wTemplate
T2wTemplate="${10}" #MNI0.8mm T2wTemplate
T2wTemplateBrain="${11}" #Brain extracted MNI0.8mm T2wTemplate
T2wTemplate2mm="${12}" #MNI2mm T2wTemplate
TemplateMask="${13}" #Brain mask MNI0.8mm Template
Template2mmMask="${14}" #Brain mask MNI2mm Template 
StandardFOVMask="${15}" #StandardFOV mask for averaging structurals
FNIRTConfig="${16}"
FieldMapImageFolder="${17}"
MagnitudeInputName="${18}" #Expects 4D volume with two 3D timepoints
PhaseInputName="${19}"
TE="${20}"
T1wSampleSpacing="${21}"
T2wSampleSpacing="${22}"
UnwarpDir="${23}"
PipelineScripts="${24}" #Location where the pipeline scripts are
Caret5_Command="${25}"
GlobalScripts="${26}"

#Naming Conventions
T1wImage="T1w"
T1wFolder="T1w" #Location of T1w images
T2wImage="T2w" 
T2wFolder="T2w" #Location of T2w images
AtlasSpaceFolder="MNINonLinear"
FieldMapOutputName="FieldMap"
MagnitudeOutputName="Magnitude"
MagnitudeBrainOutputName="Magnitude_brain"

#Build Paths
T1wFolder="$StudyFolder"/"$Subject"/"$T1wFolder" 
T2wFolder="$StudyFolder"/"$Subject"/"$T2wFolder" 
AtlasSpaceFolder="$StudyFolder"/"$Subject"/"$AtlasSpaceFolder" 

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

#T1w and T2w gradient nonlinearity correction goes here?
cp "$T1wInputImage1" "$T1wFolder"/"$T1wImage"1_gdc.nii.gz
cp "$T1wInputImage2" "$T1wFolder"/"$T1wImage"2_gdc.nii.gz
cp "$T2wInputImage1" "$T2wFolder"/"$T2wImage"1_gdc.nii.gz
cp "$T2wInputImage2" "$T2wFolder"/"$T2wImage"2_gdc.nii.gz

#Average Like Scans
mkdir -p "$T1wFolder"/AverageT1wImages
cd "$T1wFolder"/AverageT1wImages
"$PipelineScripts"/DO_avg_mprage.sh -n "$T1wFolder"/"$T1wImage"1_gdc.nii.gz "$T1wFolder"/"$T1wImage"2_gdc.nii.gz "$T1wFolder"/"$T1wImage" "$T1wTemplate" "$TemplateMask" "$StandardFOVMask"
mkdir -p "$T2wFolder"/AverageT2wImages
cd "$T2wFolder"/AverageT2wImages
"$PipelineScripts"/DO_avg_mprage.sh -n "$T2wFolder"/"$T2wImage"1_gdc.nii.gz "$T2wFolder"/"$T2wImage"2_gdc.nii.gz "$T2wFolder"/"$T2wImage" "$T1wTemplate" "$TemplateMask" "$StandardFOVMask"
cd $DIR

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

#FieldMap Preprocessing
mkdir -p "$T1wFolder"/FieldMapPreProcessing
"$GlobalScripts"/FieldMapPreProcessing.sh "$T1wFolder"/FieldMapPreProcessing "$FieldMapImageFolder"/"$MagnitudeInputName" "$FieldMapImageFolder"/"$PhaseInputName" "$FieldMapOutputName" "$MagnitudeOutputName" "$MagnitudeBrainOutputName" "$TE"

#Register T2w image of individual to T1w image of individual linearlly using FLIRT BBR
mkdir -p "$T2wFolder"/T2wToT1wDistortionCorrectAndReg
"$PipelineScripts"/T2wToT1wDistortionCorrectAndReg.sh "$T2wFolder"/T2wToT1wDistortionCorrectAndReg "$T1wFolder"/"$T1wImage"_acpc "$T1wFolder"/"$T1wImage"_acpc_brain "$T2wFolder"/"$T2wImage"_acpc "$T2wFolder"/"$T2wImage"_acpc_brain "$T1wFolder"/FieldMapPreProcessing/"$FieldMapOutputName" "$T1wFolder"/FieldMapPreProcessing/"$MagnitudeOutputName" "$T1wFolder"/FieldMapPreProcessing/"$MagnitudeBrainOutputName" "$T1wSampleSpacing" "$T2wSampleSpacing" "$UnwarpDir" "$T1wFolder"/"$T1wImage"_acpc_dc "$T1wFolder"/"$T1wImage"_acpc_dc_brain "$T1wFolder"/xfms/"$T1wImage"_dc "$T1wFolder"/"$T2wImage"_acpc_dc "$T1wFolder"/xfms/"$T2wImage"_reg_dc "$GlobalScripts"

#Bias Field Correction: Calculate bias field using square root of the product of T1w and T2w iamges.  Remove some additional non-brain tissue before dilating and smoothing bias field according to sigma
mkdir -p "$T1wFolder"/BiasFieldCorrection_sqrtT1wXT1w 
"$PipelineScripts"/BiasFieldCorrection_sqrtT1wXT1w.sh "$T1wFolder"/BiasFieldCorrection_sqrtT1wXT1w "$T1wFolder"/"$T1wImage"_acpc_dc "$T1wFolder"/"$T1wImage"_acpc_dc_brain "$T1wFolder"/"$T2wImage"_acpc_dc "$T1wFolder"/BiasField_acpc_dc "$T1wFolder"/"$T1wImage"_acpc_dc_restore "$T1wFolder"/"$T1wImage"_acpc_dc_restore_brain "$T1wFolder"/"$T2wImage"_acpc_dc_restore "$T1wFolder"/"$T2wImage"_acpc_dc_restore_brain "$Caret5_Command"

#Atlas Registration to MNI152: FLIRT + FNIRT  #Also applies registration to T1w and T2w images #Consider combining all transforms and recreating files with single resampling steps
"$PipelineScripts"/AtlasRegistrationToMNI152_FLIRTandFNIRT.sh "$AtlasSpaceFolder" "$T1wFolder"/"$T1wImage"_acpc_dc "$T1wFolder"/"$T1wImage"_acpc_dc_restore "$T1wFolder"/"$T1wImage"_acpc_dc_restore_brain "$T1wFolder"/"$T2wImage"_acpc_dc "$T1wFolder"/"$T2wImage"_acpc_dc_restore "$T1wFolder"/"$T2wImage"_acpc_dc_restore_brain "$T1wTemplate" "$T1wTemplateBrain" "$TemplateMask" "$T1wTemplate2mm" "$Template2mmMask" "$AtlasSpaceFolder"/xfms/acpc_dc2standard.nii.gz "$AtlasSpaceFolder"/xfms/standard2acpc_dc.nii.gz "$AtlasSpaceFolder"/"$T1wImage" "$AtlasSpaceFolder"/"$T1wImage"_restore "$AtlasSpaceFolder"/"$T1wImage"_restore_brain "$AtlasSpaceFolder"/"$T2wImage" "$AtlasSpaceFolder"/"$T2wImage"_restore "$AtlasSpaceFolder"/"$T2wImage"_restore_brain "$FNIRTConfig"

#FreeSurfer Script Generates Its Input
