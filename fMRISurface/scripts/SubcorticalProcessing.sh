#!/bin/bash -e
echo -e "\n START: SubcorticalProcessing"

WorkingDirectory="$1"
AtlasSpaceFolder="$2"
ROIFolder="$3"
AtlasParcellation="$4"
FinalfMRIResolution="$5"
DownSampleNameI="$6"
VolumefMRI="$7"
SmoothingFWHM="$8"
Caret5_Command="$9"

Sigma=`echo "$SmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`

if [ ! -e "$ROIFolder"/Atlas_wmparc."$FinalfMRIResolution".nii.gz ] ; then
  flirt -interp nearestneighbour -usesqform -in "$AtlasParcellation" -ref "$AtlasSpaceFolder"/wmparc."$FinalfMRIResolution" -applyxfm -out "$ROIFolder"/Atlas_wmparc."$FinalfMRIResolution"
fi

# if nifti has already been unzipped do not try again...
if [ -f "$VolumefMRI".nii.gz ] ; then
	gunzip "$VolumefMRI".nii.gz
fi
fslmaths "$VolumefMRI".nii -sub "$VolumefMRI".nii "$VolumefMRI"_AtlasSubcortical_s"$SmoothingFWHM".nii.gz
fslmaths "$VolumefMRI".nii -sub "$VolumefMRI".nii "$VolumefMRI"_Subcortical_s"$SmoothingFWHM".nii.gz


Structures="L_Accumbens_ROI L_Amygdala_ROI L_Caudate_ROI L_Cerebellum_ROI L_Hippocampus_ROI L_Pallidum_ROI L_Putamen_ROI L_Thalamus_ROI L_VentralDC_ROI R_Accumbens_ROI R_Amygdala_ROI R_Caudate_ROI R_Cerebellum_ROI R_Hippocampus_ROI R_Pallidum_ROI R_Putamen_ROI R_Thalamus_ROI R_VentralDC_ROI BrainStem_ROI"
FreeSurferNumberSTRING="26 18 11 8 17 13 12 10 28 58 54 50 47 53 52 51 49 60 16"

i=1
#One Loop to Rule Them All
for Structure in $Structures ; do
  FreeSurferNumber=`echo "$FreeSurferNumberSTRING" | cut -d " " -f $i`
  if [ ! -e "$ROIFolder"/"$Structure"."$FinalfMRIResolution".nii.gz ] ; then
    fslmaths "$AtlasSpaceFolder"/wmparc."$FinalfMRIResolution" -thr $FreeSurferNumber -uthr $FreeSurferNumber -bin "$ROIFolder"/"$Structure"."$FinalfMRIResolution"
  fi
  if [ ! -e "$ROIFolder"/Atlas_"$Structure"."$FinalfMRIResolution".nii.gz ] ; then
    fslmaths "$ROIFolder/"Atlas_wmparc."$FinalfMRIResolution" -thr $FreeSurferNumber -uthr $FreeSurferNumber -bin "$ROIFolder"/Atlas_"$Structure"."$FinalfMRIResolution"
  fi
  
  $Caret5_Command -volume-roi-smoothing "$VolumefMRI".nii "$ROIFolder"/"$Structure"."$FinalfMRIResolution".nii.gz "$WorkingDirectory"/temp.nii $Sigma
  fslmaths "$VolumefMRI"_Subcortical_s"$SmoothingFWHM".nii.gz -add "$WorkingDirectory"/temp.nii "$VolumefMRI"_Subcortical_s"$SmoothingFWHM".nii.gz
  rm "$WorkingDirectory"/temp.nii      

  $Caret5_Command -volume-atlas-resampling-and-smoothing "$VolumefMRI".nii "$ROIFolder"/"$Structure"."$FinalfMRIResolution".nii.gz "$ROIFolder"/Atlas_"$Structure"."$FinalfMRIResolution".nii.gz "$WorkingDirectory"/temp.nii $Sigma
  fslmaths "$VolumefMRI"_AtlasSubcortical_s"$SmoothingFWHM".nii.gz -add "$WorkingDirectory"/temp.nii "$VolumefMRI"_AtlasSubcortical_s"$SmoothingFWHM".nii.gz
  rm "$WorkingDirectory"/temp.nii      
  i=$(($i+1))
done
gzip "$VolumefMRI".nii

echo " END: SubcorticalProcessing"

