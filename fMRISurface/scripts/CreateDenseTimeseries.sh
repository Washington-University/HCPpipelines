#!/bin/bash 
set -e
echo -e "\n START: CreateDenseTimeSeries"

DownSampleFolder="$1"
Subject="$2"
LowResMesh="$3"
NameOffMRI="$4"
SmoothingFWHM="$5"
ROIFolder="$6"
OutputAtlasDenseTimeseries="$7"
GrayordinatesResolution="$8"

TR_vol=`fslval "$NameOffMRI" pixdim4 | cut -d " " -f 1`

#Some way faster and more concise code:

${CARET7DIR}/wb_command -cifti-create-dense-timeseries \
			"$OutputAtlasDenseTimeseries".dtseries.nii \
			-volume "$NameOffMRI"_AtlasSubcortical_s"$SmoothingFWHM".nii.gz "$ROIFolder"/Atlas_ROIs."$GrayordinatesResolution".nii.gz \
			-left-metric "$NameOffMRI"_s"$SmoothingFWHM".atlasroi.L."$LowResMesh"k_fs_LR.func.gii -roi-left "$DownSampleFolder"/"$Subject".L.atlasroi."$LowResMesh"k_fs_LR.shape.gii \
			-right-metric "$NameOffMRI"_s"$SmoothingFWHM".atlasroi.R."$LowResMesh"k_fs_LR.func.gii -roi-right "$DownSampleFolder"/"$Subject".R.atlasroi."$LowResMesh"k_fs_LR.shape.gii \
			-timestep "$TR_vol"

#Assess for zeros in the final dtseries (e.g., due to incomplete spatial coverage)
# (Note that earlier steps do an appreciable amount of dilation to eliminate zeros,
# so zeros remaining in the CIFTI at this point represent a non-trivial issue with spatial coverage)
${CARET7DIR}/wb_command -cifti-reduce "$OutputAtlasDenseTimeseries".dtseries.nii STDEV "$OutputAtlasDenseTimeseries".stdev.dscalar.nii
Nnonzero=`${CARET7DIR}/wb_command -cifti-stats "$OutputAtlasDenseTimeseries".stdev.dscalar.nii -reduce COUNT_NONZERO`
Ngrayordinates=`${CARET7DIR}/wb_command -file-information "$OutputAtlasDenseTimeseries".stdev.dscalar.nii | grep "Number of Rows" | awk '{print $4}'`
PctCoverage=`echo "scale=4; 100 * ${Nnonzero} / ${Ngrayordinates}" | bc -l`
echo "PctCoverage, Nnonzero, Ngrayordinates" >| "$OutputAtlasDenseTimeseries"_nonzero.stats.txt
echo "${PctCoverage}, ${Nnonzero}, ${Ngrayordinates}" >> "$OutputAtlasDenseTimeseries"_nonzero.stats.txt
# If we don't have full grayordinate coverage, save out a mask to identify those locations
if [ "$Nnonzero" -ne "$Ngrayordinates" ]; then
	${CARET7DIR}/wb_command -cifti-math 'x > 0' "$OutputAtlasDenseTimeseries"_nonzero.dscalar.nii -var "$OutputAtlasDenseTimeseries".stdev.dscalar.nii
fi
rm -f "$OutputAtlasDenseTimeseries".stdev.dscalar.nii
	
#Basic Cleanup
rm "$NameOffMRI"_AtlasSubcortical_s"$SmoothingFWHM".nii.gz
rm "$NameOffMRI"_s"$SmoothingFWHM".atlasroi.L."$LowResMesh"k_fs_LR.func.gii
rm "$NameOffMRI"_s"$SmoothingFWHM".atlasroi.R."$LowResMesh"k_fs_LR.func.gii

echo " END: CreateDenseTimeSeries"
