#!/bin/bash
set -e
g_script_name=`basename ${0}`

# Load Function Libraries
source ${HCPPIPEDIR}/global/scripts/log.shlib # Logging related functions
source ${HCPPIPEDIR}/global/scripts/fsl_version.shlib # Function for getting FSL version

# Establish tool name for logging
log_SetToolName "${g_script_name}"

show_tool_versions()
{
	# Show HCP pipelines version
	log_Msg "Showing HCP Pipelines version"
	cat ${HCPPIPEDIR}/version.txt

	# Show wb_command version
	log_Msg "Showing Connectome Workbench (wb_command) version"
	${CARET7DIR}/wb_command -version

	# Show fsl version
	log_Msg "Showing FSL version"
	fsl_version_get fsl_ver
	log_Msg "FSL version: ${fsl_ver}"
}

Subject="$1"
log_Msg "Subject: ${Subject}"

ResultsFolder="$2"
log_Msg "ResultsFolder: ${ResultsFolder}"

ROIsFolder="$3"
log_Msg "ROIsFolder: ${ROIsFolder}"

DownSampleFolder="$4"
log_Msg "DownSampleFolder: ${DownSampleFolder}"

LevelOnefMRIName="$5"
log_Msg "LevelOnefMRIName: ${LevelOnefMRIName}"

LevelOnefsfName="$6"
log_Msg "LevelOnefsfName: ${LevelOnefsfName}"

LowResMesh="$7"
log_Msg "LowResMesh: ${LowResMesh}"

GrayordinatesResolution="$8"
log_Msg "GrayordinatesResolution: ${GrayordinatesResolution}"

OriginalSmoothingFWHM="$9"
log_Msg "OriginalSmoothingFWHM: ${OriginalSmoothingFWHM}"

Confound="${10}"
log_Msg "Confound: ${Confound}"

FinalSmoothingFWHM="${11}"
log_Msg "FinalSmoothingFWHM: ${FinalSmoothingFWHM}"

TemporalFilter="${12}"
log_Msg "TemporalFilter: ${TemporalFilter}"

VolumeBasedProcessing="${13}"
log_Msg "VolumeBasedProcessing: ${VolumeBasedProcessing}"

RegName="${14}"
log_Msg "RegName: ${RegName}"

Parcellation="${15}"
log_Msg "Parcellation: ${Parcellation}"

ParcellationFile="${16}"
log_Msg "ParcellationFile: ${ParcellationFile}" 

show_tool_versions

if [ ! ${Parcellation} = "NONE" ] ; then
  ParcellationString="_${Parcellation}"
  Extension="ptseries.nii"
else
  ParcellationString=""
  Extension="dtseries.nii"
fi
log_Msg "ParcellationString: ${ParcellationString}"
log_Msg "Extension: ${Extension}"


if [ ! ${RegName} = "NONE" ] ; then
  RegString="_${RegName}"
else
  RegString=""
fi
log_Msg "RegString: ${RegString}"

#Parcellate data if a Parcellation was provided
log_Msg "Parcellate data if a Parcellation was provided"
if [ ! ${Parcellation} = "NONE" ] ; then
  log_Msg "Parcellating data"
  ${CARET7DIR}/wb_command -cifti-parcellate ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}.dtseries.nii ${ParcellationFile} COLUMN ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${ParcellationString}.ptseries.nii
fi

TR_vol=`${CARET7DIR}/wb_command -file-information ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${ParcellationString}.${Extension} -no-map-info -only-step-interval`
log_Msg "TR_vol: ${TR_vol}"

#Only do the additional spatial smoothing required to hit the target (theoretical) final smoothing for CIFTI.
#Additional smoothing is not recommended -- if looking for area-sized effects, use parcellation for
#greater sensitivity and statistical power
AdditionalSmoothingFWHM=`echo "sqrt(( $FinalSmoothingFWHM ^ 2 ) - ( $OriginalSmoothingFWHM ^ 2 ))" | bc -l`
log_Msg "AdditionalSmoothingFWHM: ${AdditionalSmoothingFWHM}"

AdditionalSigma=`echo "$AdditionalSmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`
log_Msg "AdditionalSigma: ${AdditionalSigma}"

SmoothingString="_s${FinalSmoothingFWHM}"
TemporalFilterString="_hp""$TemporalFilter"
log_Msg "SmoothingString: ${SmoothingString}"
log_Msg "TemporalFilterString: ${TemporalFilterString}"

FEATDir="${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefsfName}${TemporalFilterString}${SmoothingString}_level1${RegString}${ParcellationString}.feat"
log_Msg "FEATDir: ${FEATDir}"
if [ -e ${FEATDir} ] ; then
  rm -r ${FEATDir}
  mkdir ${FEATDir}
else
  mkdir -p ${FEATDir}
fi

if [ $TemporalFilter = "200" ] ; then
  #Don't edit the fsf file if the temporal filter is the same
  log_Msg "Don't edit the fsf file if the temporal filter is the same"
  cp ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefsfName}_hp200_s4_level1.fsf ${FEATDir}/temp.fsf
else
  #Change the highpass filter string to the desired highpass filter
  log_Msg "Change the highpass filter string to the desired highpass filter"
  cat ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefsfName}_hp200_s4_level1.fsf | sed s/"set fmri(paradigm_hp) \"200\""/"set fmri(paradigm_hp) \"${TemporalFilter}\""/g > ${FEATDir}/temp.fsf
fi

#Change smoothing to be equal to additional smoothing in FSF file and change output directory to match total smoothing and highpass
log_Msg "Change smoothing to be equal to additional smoothing in FSF file and change output directory to match total smoothing and highpass"
cat ${FEATDir}/temp.fsf | sed s/"set fmri(smooth) \"4\""/"set fmri(smooth) \"${AdditionalSmoothingFWHM}\""/g | sed s/_hp200_s4/${TemporalFilterString}${SmoothingString}${RegString}${ParcellationString}/g > ${FEATDir}/design.fsf
rm ${FEATDir}/temp.fsf

#Change number of timepoints to match timeseries so that template fsf files can be used
log_Msg "Change number of timepoints to match timeseries so that template fsf files can be used"
fsfnpts=`cat ${FEATDir}/design.fsf | grep "set fmri(npts)" | cut -d " " -f 3 | sed 's/"//g'`
log_Msg "fsfnpts: ${fsfnpts}"
CIFTInpts=`${CARET7DIR}/wb_command -file-information ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${ParcellationString}.${Extension} -no-map-info -only-number-of-maps`
log_Msg "CIFTInpts: ${CIFTInpts}"
if [ $fsfnpts -ne $CIFTInpts ] ; then
  cat ${FEATDir}/design.fsf | sed s/"set fmri(npts) \"\?${fsfnpts}\"\?"/"set fmri(npts) ${CIFTInpts}"/g > ${FEATDir}/temp.fsf
  mv ${FEATDir}/temp.fsf ${FEATDir}/design.fsf
  log_Msg "Short Run! Reseting FSF Number of Timepoints (""${fsfnpts}"") to Match CIFTI (""${CIFTInpts}"")"
fi

#Create design files, model confounds if desired
log_Msg "Create design files, model confounds if desired"
DIR=`pwd`
cd ${FEATDir}
if [ $Confound = "NONE" ] ; then
  feat_model ${FEATDir}/design
else 
  feat_model ${FEATDir}/design ${ResultsFolder}/${LevelOnefMRIName}/${Confound}
fi
cd $DIR

#Prepare files and folders
log_Msg "Prepare files and folders"
DesignMatrix=${FEATDir}/design.mat
DesignContrasts=${FEATDir}/design.con
DesignfContrasts=${FEATDir}/design.fts

# An F-test may not always be requested as part of the design.fsf
ExtraArgs=""
if [ -e ${DesignfContrasts} ] ; then
	ExtraArgs="$ExtraArgs --fcon=${DesignfContrasts}"
fi

###CIFTI Processing###
log_Msg "CIFTI Processing"
#Add any additional spatial smoothing, does not do anything if parcellation has been specified.
#Additional smoothing is not recommended -- if looking for area-sized effects, use parcellation for
#greater sensitivity and statistical power
if [[ ! $FinalSmoothingFWHM -eq $OriginalSmoothingFWHM && -z ${ParcellationString} ]] ; then
  ${CARET7DIR}/wb_command -cifti-smoothing ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}.dtseries.nii ${AdditionalSigma} ${AdditionalSigma} COLUMN ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$SmoothingString"${RegString}.dtseries.nii -left-surface "$DownSampleFolder"/"$Subject".L.midthickness."$LowResMesh"k_fs_LR.surf.gii -right-surface "$DownSampleFolder"/"$Subject".R.midthickness."$LowResMesh"k_fs_LR.surf.gii
else
  cp ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${ParcellationString}.${Extension} ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$SmoothingString"${RegString}${ParcellationString}.${Extension}
fi

#Add temporal filtering
log_Msg "Add temporal filtering"
# Temporal filtering is conducted by fslmaths. 
# First, fslmaths is not CIFTI-compliant. 
# So, convert CIFTI to fake NIFTI file, use fslmaths, then convert fake NIFTI back to CIFTI.
# Second, fslmaths -bptf removes timeseries mean (for FSL 5.0.7 onward), which is expected by film_gls. 
# So, save the mean to file, then add it back after -bptf.
${CARET7DIR}/wb_command -cifti-convert -to-nifti ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$SmoothingString"${RegString}${ParcellationString}.${Extension} ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$SmoothingString"${RegString}${ParcellationString}_FAKENIFTI.nii.gz
fslmaths ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$SmoothingString"${RegString}${ParcellationString}_FAKENIFTI.nii.gz -Tmean ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$SmoothingString"${RegString}${ParcellationString}_FAKENIFTI_mean.nii.gz
hp_sigma=`echo "0.5 * $TemporalFilter / $TR_vol" | bc -l`
fslmaths ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$SmoothingString"${RegString}${ParcellationString}_FAKENIFTI.nii.gz -bptf ${hp_sigma} -1 \
		 -add ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$SmoothingString"${RegString}${ParcellationString}_FAKENIFTI_mean.nii.gz \
		 ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$SmoothingString"${RegString}${ParcellationString}_FAKENIFTI.nii.gz
${CARET7DIR}/wb_command -cifti-convert -from-nifti ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$SmoothingString"${RegString}${ParcellationString}_FAKENIFTI.nii.gz ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$SmoothingString"${RegString}${ParcellationString}.${Extension} ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$TemporalFilterString""$SmoothingString"${RegString}${ParcellationString}.${Extension}
rm ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$SmoothingString"${RegString}${ParcellationString}_FAKENIFTI.nii.gz ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$SmoothingString"${RegString}${ParcellationString}_FAKENIFTI_mean.nii.gz

#Check if data are Parcellated, if not, do Dense Grayordinates Analysis#
log_Msg "Check if data are Parcellated, if not, do Dense Grayordinates Analysis"
if [ -z ${ParcellationString} ] ; then

  ###Dense Grayordinates Processing###
  log_Msg "Dense Grayordinates Processing"
  #Split into surface and volume
  log_Msg "Split into surface and volume"
  ${CARET7DIR}/wb_command -cifti-separate-all ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$TemporalFilterString""$SmoothingString"${RegString}.dtseries.nii -volume ${FEATDir}/${LevelOnefMRIName}_AtlasSubcortical"$TemporalFilterString""$SmoothingString".nii.gz -left ${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}${RegString}.atlasroi.L."$LowResMesh"k_fs_LR.func.gii -right ${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}${RegString}.atlasroi.R."$LowResMesh"k_fs_LR.func.gii

  #Run film_gls on subcortical volume data
  log_Msg "Run film_gls on subcortical volume data"
  film_gls --rn=${FEATDir}/SubcorticalVolumeStats --sa --ms=5 --in=${FEATDir}/${LevelOnefMRIName}_AtlasSubcortical"$TemporalFilterString""$SmoothingString".nii.gz --pd="$DesignMatrix" --con=${DesignContrasts} ${ExtraArgs} --thr=1 --mode=volumetric
  rm ${FEATDir}/${LevelOnefMRIName}_AtlasSubcortical"$TemporalFilterString""$SmoothingString".nii.gz

  #Run film_gls on cortical surface data 
  log_Msg "Run film_gls on cortical surface data"
  for Hemisphere in L R ; do
    #Prepare for film_gls  
	log_Msg "Prepare for film_gls"
    ${CARET7DIR}/wb_command -metric-dilate ${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}${RegString}.atlasroi."$Hemisphere"."$LowResMesh"k_fs_LR.func.gii "$DownSampleFolder"/"$Subject"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii 50 ${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}${RegString}.atlasroi_dil."$Hemisphere"."$LowResMesh"k_fs_LR.func.gii -nearest

    #Run film_gls on surface data
    log_Msg "Run film_gls on surface data"
    film_gls --rn=${FEATDir}/"$Hemisphere"_SurfaceStats --sa --ms=15 --epith=5 --in2="$DownSampleFolder"/"$Subject"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii --in=${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}${RegString}.atlasroi_dil."$Hemisphere"."$LowResMesh"k_fs_LR.func.gii --pd="$DesignMatrix" --con=${DesignContrasts} ${ExtraArgs} --mode=surface
    rm ${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}${RegString}.atlasroi_dil."$Hemisphere"."$LowResMesh"k_fs_LR.func.gii ${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}${RegString}.atlasroi."$Hemisphere"."$LowResMesh"k_fs_LR.func.gii
  done

  #Merge Cortical Surface and Subcortical Volume into Grayordinates
  log_Msg "Merge Cortical Surface and Subcortical Volume into Grayordinates"
  mkdir ${FEATDir}/GrayordinatesStats
  cat ${FEATDir}/SubcorticalVolumeStats/dof > ${FEATDir}/GrayordinatesStats/dof
  cat ${FEATDir}/SubcorticalVolumeStats/logfile > ${FEATDir}/GrayordinatesStats/logfile
  cat ${FEATDir}/L_SurfaceStats/logfile >> ${FEATDir}/GrayordinatesStats/logfile
  cat ${FEATDir}/R_SurfaceStats/logfile >> ${FEATDir}/GrayordinatesStats/logfile
  cd ${FEATDir}/SubcorticalVolumeStats
  Files=`ls | grep .nii.gz | cut -d "." -f 1`
  cd $DIR
  for File in $Files ; do
    ${CARET7DIR}/wb_command -cifti-create-dense-timeseries ${FEATDir}/GrayordinatesStats/${File}.dtseries.nii -volume ${FEATDir}/SubcorticalVolumeStats/${File}.nii.gz $ROIsFolder/Atlas_ROIs.${GrayordinatesResolution}.nii.gz -left-metric ${FEATDir}/L_SurfaceStats/${File}.func.gii -roi-left "$DownSampleFolder"/"$Subject".L.atlasroi."$LowResMesh"k_fs_LR.shape.gii -right-metric ${FEATDir}/R_SurfaceStats/${File}.func.gii -roi-right "$DownSampleFolder"/"$Subject".R.atlasroi."$LowResMesh"k_fs_LR.shape.gii
  done
  rm -r ${FEATDir}/SubcorticalVolumeStats ${FEATDir}/L_SurfaceStats ${FEATDir}/R_SurfaceStats

else

  ###Parcellated Processing###
  log_Msg "Parcellated Processing"
  ${CARET7DIR}/wb_command -cifti-convert -to-nifti ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$TemporalFilterString""$SmoothingString"${RegString}${ParcellationString}.${Extension} ${FEATDir}/${LevelOnefMRIName}_Atlas"$TemporalFilterString""$SmoothingString"${RegString}${ParcellationString}_FAKENIFTI.nii.gz
  film_gls --rn=${FEATDir}/ParcellatedStats --in=${FEATDir}/${LevelOnefMRIName}_Atlas"$TemporalFilterString""$SmoothingString"${RegString}${ParcellationString}_FAKENIFTI.nii.gz --pd="$DesignMatrix" --con=${DesignContrasts} ${ExtraArgs} --thr=1 --mode=volumetric
  rm ${FEATDir}/${LevelOnefMRIName}_Atlas"$TemporalFilterString""$SmoothingString"${RegString}${ParcellationString}_FAKENIFTI.nii.gz
  cd ${FEATDir}/ParcellatedStats
  Files=`ls | grep .nii.gz | cut -d "." -f 1`
  cd $DIR
  for File in $Files ; do
    ${CARET7DIR}/wb_command -cifti-convert -from-nifti ${FEATDir}/ParcellatedStats/${File}.nii.gz ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$TemporalFilterString""$SmoothingString"${RegString}${ParcellationString}.ptseries.nii ${FEATDir}/ParcellatedStats/${File}.ptseries.nii -reset-timepoints 1 1
  done
  rm ${FEATDir}/ParcellatedStats/*.nii.gz
fi

###Standard NIFTI Volume-based Processsing###
log_Msg "Standard NIFTI Volume-based Processsing"
if [ $VolumeBasedProcessing = "YES" ] ; then

  #Add edge-constrained volume smoothing
  log_Msg "Add edge-constrained volume smoothing"
  FinalSmoothingSigma=`echo "$FinalSmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`
  InputfMRI=${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}
  InputSBRef=${InputfMRI}_SBRef
  fslmaths ${InputSBRef} -bin ${FEATDir}/mask_orig
  fslmaths ${FEATDir}/mask_orig -kernel gauss ${FinalSmoothingSigma} -fmean ${FEATDir}/mask_orig_weight -odt float
  fslmaths ${InputfMRI} -kernel gauss ${FinalSmoothingSigma} -fmean \
    -div ${FEATDir}/mask_orig_weight -mas ${FEATDir}/mask_orig \
    ${FEATDir}/${LevelOnefMRIName}"$SmoothingString" -odt float

  #Add volume dilation
  #
  # For some subjects, FreeSurfer-derived brain masks (applied to the time 
  # series data in IntensityNormalization.sh as part of 
  # GenericfMRIVolumeProcessingPipeline.sh) do not extend to the edge of brain
  # in the MNI152 space template. This is due to the limitations of volume-based
  # registration. So, to avoid a lack of coverage in a group analysis around the
  # penumbra of cortex, we will add a single dilation step to the input prior to
  # creating the Level1 maps.
  #
  # Ideally, we would condition this dilation on the resolution of the fMRI 
  # data.  Empirically, a single round of dilation gives very good group 
  # coverage of MNI brain for the 2 mm resolution of HCP fMRI data. So a single
  # dilation is what we use below.
  #
  # Note that for many subjects, this dilation will result in signal extending
  # BEYOND the limits of brain in the MNI152 template.  However, that is easily
  # fixed by masking with the MNI space brain template mask if so desired.
  #
  # The specific implementation involves:
  # a) Edge-constrained spatial smoothing on the input fMRI time series (and masking
  #    that back to the original mask).  This step was completed above.
  # b) Spatial dilation of the input fMRI time series, followed by edge constrained smoothing
  # c) Adding the voxels from (b) that are NOT part of (a) into (a).
  #
  # The motivation for this implementation is that:
  # 1) Identical voxel-wise results are obtained within the original mask.  So, users
  #    that desire the original ("tight") FreeSurfer-defined brain mask (which is
  #    implicitly represented as the non-zero voxels in the InputSBRef volume) can
  #    mask back to that if they chose, with NO impact on the voxel-wise results.
  # 2) A simpler possible approach of just dilating the result of step (a) results in 
  #    an unnatural pattern of dark/light/dark intensities at the edge of brain,
  #    whereas the combination of steps (b) and (c) yields a more natural looking 
  #    transition of intensities in the added voxels.
  log_Msg "Add volume dilation"

  # Dilate the original BOLD time series, then do (edge-constrained) smoothing
  fslmaths ${FEATDir}/mask_orig -dilM -bin ${FEATDir}/mask_dilM
  fslmaths ${FEATDir}/mask_dilM \
    -kernel gauss ${FinalSmoothingSigma} -fmean ${FEATDir}/mask_dilM_weight -odt float
  fslmaths ${InputfMRI} -dilM -kernel gauss ${FinalSmoothingSigma} -fmean \
    -div ${FEATDir}/mask_dilM_weight -mas ${FEATDir}/mask_dilM \
    ${FEATDir}/${LevelOnefMRIName}_dilM"$SmoothingString" -odt float

  # Take just the additional "rim" voxels from the dilated then smoothed time series, and add them
  # into the smoothed time series (that didn't have any dilation)
  SmoothedDilatedResultFile=${FEATDir}/${LevelOnefMRIName}"$SmoothingString"_dilMrim
  fslmaths ${FEATDir}/mask_orig -binv ${FEATDir}/mask_orig_inv
  fslmaths ${FEATDir}/${LevelOnefMRIName}_dilM"$SmoothingString" \
    -mas ${FEATDir}/mask_orig_inv \
    -add ${FEATDir}/${LevelOnefMRIName}"$SmoothingString" \
    ${SmoothedDilatedResultFile}

  #Add temporal filtering to the output from above
  log_Msg "Add temporal filtering"
  # Temporal filtering is conducted by fslmaths. 
  # fslmaths -bptf removes timeseries mean (for FSL 5.0.7 onward), which is expected by film_gls. 
  # So, save the mean to file, then add it back after -bptf.
  # We drop the "dilMrim" string from the output file name, so as to avoid breaking
  # any downstream scripts.
  fslmaths ${SmoothedDilatedResultFile} -Tmean ${SmoothedDilatedResultFile}_mean
  hp_sigma=`echo "0.5 * $TemporalFilter / $TR_vol" | bc -l`
  fslmaths ${SmoothedDilatedResultFile} -bptf ${hp_sigma} -1 \
	-add ${SmoothedDilatedResultFile}_mean \
    ${FEATDir}/${LevelOnefMRIName}"$TemporalFilterString""$SmoothingString".nii.gz

  #Run film_gls on volume data
  log_Msg "Run film_gls on volume data"
  film_gls --rn=${FEATDir}/StandardVolumeStats --sa --ms=5 --in=${FEATDir}/${LevelOnefMRIName}"$TemporalFilterString""$SmoothingString".nii.gz --pd="$DesignMatrix" --con=${DesignContrasts} ${ExtraArgs} --thr=1000

  #Cleanup
  rm -f ${FEATDir}/mask_*.nii.gz
  rm -f ${FEATDir}/${LevelOnefMRIName}"$SmoothingString".nii.gz
  rm -f ${FEATDir}/${LevelOnefMRIName}_dilM"$SmoothingString".nii.gz
  rm -f ${SmoothedDilatedResultFile}*.nii.gz

fi

log_Msg "Complete"
