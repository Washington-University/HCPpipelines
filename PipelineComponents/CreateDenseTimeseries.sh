#!/bin/bash

DownSampleFolder="$1"
Subject="$2"
DownSampleNameI="$3"
NameOffMRI="$4"
SmoothingFWHM="$5"
FinalfMRIResolution="$6"
ROIFolder="$7"
OutputDenseTimeseries="$8"
OutputAtlasDenseTimeseries="$9"

CIFTILabels="CIFTI_STRUCTURE_ACCUMBENS_LEFT CIFTI_STRUCTURE_AMYGDALA_LEFT CIFTI_STRUCTURE_CAUDATE_LEFT CIFTI_STRUCTURE_CEREBELLUM_LEFT CIFTI_STRUCTURE_HIPPOCAMPUS_LEFT CIFTI_STRUCTURE_PALLIDUM_LEFT CIFTI_STRUCTURE_PUTAMEN_LEFT CIFTI_STRUCTURE_THALAMUS_LEFT CIFTI_STRUCTURE_DIENCEPHALON_VENTRAL_LEFT CIFTI_STRUCTURE_ACCUMBENS_RIGHT CIFTI_STRUCTURE_AMYGDALA_RIGHT CIFTI_STRUCTURE_CAUDATE_RIGHT CIFTI_STRUCTURE_CEREBELLUM_RIGHT CIFTI_STRUCTURE_HIPPOCAMPUS_RIGHT CIFTI_STRUCTURE_PALLIDUM_RIGHT CIFTI_STRUCTURE_PUTAMEN_RIGHT CIFTI_STRUCTURE_THALAMUS_RIGHT CIFTI_STRUCTURE_DIENCEPHALON_VENTRAL_RIGHT CIFTI_STRUCTURE_BRAIN_STEM"
Structures="L_Accumbens_ROI L_Amygdala_ROI L_Caudate_ROI L_Cerebellum_ROI L_Hippocampus_ROI L_Pallidum_ROI L_Putamen_ROI L_Thalamus_ROI L_VentralDC_ROI R_Accumbens_ROI R_Amygdala_ROI R_Caudate_ROI R_Cerebellum_ROI R_Hippocampus_ROI R_Pallidum_ROI R_Putamen_ROI R_Thalamus_ROI R_VentralDC_ROI BrainStem_ROI"

TR_vol=`fslval "$NameOffMRI" pixdim4 | cut -d " " -f 1`

CIFTIString=""
CIFTIAtlasString=""
i=1
#One Loop to Rule Them All
for Structure in $Structures ; do
  CIFTILabel=`echo "$CIFTILabels" | cut -d " " -f $i`
  if [ $i -eq 1 ] ; then
    CIFTIString=`echo "$CIFTIString""-cifti-structure-name CIFTI_STRUCTURE_CORTEX_LEFT -input-surface-roi "$DownSampleFolder"/"$Subject".L.roi."$DownSampleNameI"k_fs_LR.shape.gii -input-timeseries "$NameOffMRI"_s"$SmoothingFWHM".roi.L."$DownSampleNameI"k_fs_LR.func.gii "`
    CIFTIAtlasString=`echo "$CIFTIAtlasString""-cifti-structure-name CIFTI_STRUCTURE_CORTEX_LEFT -input-surface-roi "$DownSampleFolder"/"$Subject".L.atlasroi."$DownSampleNameI"k_fs_LR.shape.gii -input-timeseries "$NameOffMRI"_s"$SmoothingFWHM".atlasroi.L."$DownSampleNameI"k_fs_LR.func.gii "`
  fi
  if [ $i -eq 9 ] ; then
    CIFTIString=`echo "$CIFTIString""-cifti-structure-name CIFTI_STRUCTURE_CORTEX_RIGHT -input-surface-roi "$DownSampleFolder"/"$Subject".R.roi."$DownSampleNameI"k_fs_LR.shape.gii -input-timeseries "$NameOffMRI"_s"$SmoothingFWHM".roi.R."$DownSampleNameI"k_fs_LR.func.gii "`
    CIFTIAtlasString=`echo "$CIFTIAtlasString""-cifti-structure-name CIFTI_STRUCTURE_CORTEX_RIGHT -input-surface-roi "$DownSampleFolder"/"$Subject".R.atlasroi."$DownSampleNameI"k_fs_LR.shape.gii -input-timeseries "$NameOffMRI"_s"$SmoothingFWHM".atlasroi.R."$DownSampleNameI"k_fs_LR.func.gii "`
  fi
  CIFTIString=`echo "$CIFTIString""-cifti-structure-name ""$CIFTILabel"" -input-volumetric-roi ""$ROIFolder"/"$Structure"."$FinalfMRIResolution"".nii.gz "`
  CIFTIAtlasString=`echo "$CIFTIAtlasString""-cifti-structure-name ""$CIFTILabel"" -input-volumetric-roi ""$ROIFolder"/Atlas_"$Structure"."$FinalfMRIResolution"".nii.gz "`
  i=$(($i+1))
done
gunzip "$NameOffMRI"_AtlasSubcortical_s"$SmoothingFWHM".nii.gz
caret_command -create-cifti-dense-timeseries -time-step "$TR_vol" -input-volume "$NameOffMRI"_AtlasSubcortical_s"$SmoothingFWHM".nii $CIFTIAtlasString -output-cifti-file "$OutputAtlasDenseTimeseries".dtseries.nii 
echo "caret_command -create-cifti-dense-timeseries -time-step "$TR_vol" -input-volume "$NameOffMRI"_AtlasSubcortical_s"$SmoothingFWHM".nii $CIFTIAtlasString -output-cifti-file "$OutputAtlasDenseTimeseries".dtseries.nii"
gzip "$NameOffMRI"_AtlasSubcortical_s"$SmoothingFWHM".nii

gunzip "$NameOffMRI"_Subcortical_s"$SmoothingFWHM".nii.gz
caret_command -create-cifti-dense-timeseries -time-step "$TR_vol" -input-volume "$NameOffMRI"_Subcortical_s"$SmoothingFWHM".nii $CIFTIString -output-cifti-file "$OutputDenseTimeseries".dtseries.nii
echo "caret_command -create-cifti-dense-timeseries -time-step "$TR_vol" -input-volume "$NameOffMRI"_Subcortical_s"$SmoothingFWHM".nii $CIFTIString -output-cifti-file "$OutputDenseTimeseries".dtseries.nii"
gzip "$NameOffMRI"_Subcortical_s"$SmoothingFWHM".nii

