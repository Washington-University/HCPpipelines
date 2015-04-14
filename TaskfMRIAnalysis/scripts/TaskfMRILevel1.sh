#!/bin/bash
set -e

Subject="$1"
ResultsFolder="$2"
ROIsFolder="$3"
DownSampleFolder="$4"
LevelOnefMRIName="$5"
LevelOnefsfName="$6"
LowResMesh="$7"
GrayordinatesResolution="$8"
OriginalSmoothingFWHM="$9"
Confound="${10}"
FinalSmoothingFWHM="${11}"
TemporalFilter="${12}"
VolumeBasedProcessing="${13}"

# Load Function Libraries
source ${HCPPIPEDIR}/global/scripts/log.shlib  # Logging related functions

# Establish tool name for logging
log_SetToolName "TaskfMRILevel1.sh"
log_Msg "Use wb_command to calculate TR_vol"

TR_vol=`${CARET7DIR}/wb_command -file-information ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas.dtseries.nii -no-map-info -only-step-interval`

#Only do the additional smoothing required to hit the target final smoothing for CIFTI
log_Msg "Only do the additional smoothing required to hit the target final smoothing for CIFTI"
AdditionalSmoothingFWHM=`echo "sqrt(( $FinalSmoothingFWHM ^ 2 ) - ( $OriginalSmoothingFWHM ^ 2 ))" | bc -l`

AdditionalSigma=`echo "$AdditionalSmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`

SmoothingString="_s${FinalSmoothingFWHM}"
TemporalFilterString="_hp""$TemporalFilter"

FEATDir="${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefsfName}${TemporalFilterString}${SmoothingString}_level1.feat"
if [ -e ${FEATDir} ] ; then
  rm -r ${FEATDir}
  mkdir ${FEATDir}
else
  mkdir -p ${FEATDir}
fi

if [ $TemporalFilter = "200" ] ; then
  #Don't edit the fsf file if the temporal filter is the same
  cp ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefsfName}_hp200_s4_level1.fsf ${FEATDir}/temp.fsf
else
  #Change the highpass filter string to the desired highpass filter
  cat ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefsfName}_hp200_s4_level1.fsf | sed s/"set fmri(paradigm_hp) \"200\""/"set fmri(paradigm_hp) \"${TemporalFilter}\""/g > ${FEATDir}/temp.fsf
fi

#Change smoothing to be equal to additional smoothing in FSF file and change output directory to match total smoothing and highpass
log_Msg "Change smoothing to be equal to additional smoothing in FSF file and change output directory to match total smoothing and highpass"
cat ${FEATDir}/temp.fsf | sed s/"set fmri(smooth) \"4\""/"set fmri(smooth) \"${AdditionalSmoothingFWHM}\""/g | sed s/_hp200_s4/${TemporalFilterString}${SmoothingString}/g > ${FEATDir}/design.fsf
rm ${FEATDir}/temp.fsf

#Change number of timepoints to match timeseries so that template fsf files can be used
log_Msg "Change number of timepoints to match timeseries so that template fsf files can be used"
fsfnpts=`cat ${FEATDir}/design.fsf | grep "set fmri(npts)" | cut -d " " -f 3 | sed 's/"//g'`

log_Msg "CARET7DIR: ${CARET7DIR}"
CIFTInpts=`${CARET7DIR}/wb_command -file-information ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas.dtseries.nii -no-map-info -only-number-of-maps`
log_Msg "CIFTInpts: ${CIFTInpts}"
if [ $fsfnpts -ne $CIFTInpts ] ; then
  cat ${FEATDir}/design.fsf | sed s/"set fmri(npts) \"\?${fsfnpts}\"\?"/"set fmri(npts) ${CIFTInpts}"/g > ${FEATDir}/temp.fsf
  mv ${FEATDir}/temp.fsf ${FEATDir}/design.fsf
  echo "Short Run! Reseting FSF Number of Timepoints (""${fsfnpts}"") to Match CIFTI (""${CIFTInpts}"")"
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
DesignMatrix=${FEATDir}/design.mat
DesignContrasts=${FEATDir}/design.con
DesignfContrasts=${FEATDir}/design.fts

###Grayordinates Processing###
#Add any additional smoothing
log_Msg "Grayordinates Processing - Add any additional smoothing"
if [ ! $FinalSmoothingFWHM -eq $OriginalSmoothingFWHM ] ; then
  ${CARET7DIR}/wb_command -cifti-smoothing ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas.dtseries.nii ${AdditionalSigma} ${AdditionalSigma} COLUMN ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$SmoothingString".dtseries.nii -left-surface "$DownSampleFolder"/"$Subject".L.midthickness."$LowResMesh"k_fs_LR.surf.gii -right-surface "$DownSampleFolder"/"$Subject".R.midthickness."$LowResMesh"k_fs_LR.surf.gii
else
  cp ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas.dtseries.nii ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$SmoothingString".dtseries.nii
fi

#Add temporal filtering
log_Msg "Add temporal filtering"
dtseries_file=${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$SmoothingString".dtseries.nii
fake_nifti_file=${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$SmoothingString"_FAKENIFTI.nii.gz
temporal_filter_dtseries_file=${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$TemporalFilterString""$SmoothingString".dtseries.nii 

${CARET7DIR}/wb_command -cifti-convert -to-nifti ${dtseries_file} ${fake_nifti_file}

which_fslmaths=`which fslmaths`
fsl_bin_directory=`dirname ${which_fslmaths}`
fsl_version_file="${fsl_bin_directory}/../etc/fslversion"
fsl_version=`cat ${fsl_version_file}`

if [ "${fsl_version}" != "5.0.6" ] ; then
    message="This script, TaskfMRILevel1.sh, assumes fslmaths behavior that is available in version 5.0.6 of FSL. You are using FSL version ${fsl_version}. Please install FSL version 5.0.6 before continuing."
    log_Msg ${message}
    echo ${message} 1>&2
    exit
fi
fslmaths ${fake_nifti_file} -bptf `echo "0.5 * $TemporalFilter / $TR_vol" | bc -l` 0 ${fake_nifti_file}

${CARET7DIR}/wb_command -cifti-convert -from-nifti ${fake_nifti_file} ${dtseries_file} ${temporal_filter_dtseries_file}
rm ${fake_nifti_file}

#Split into surface and volume
log_Msg "Split into surface and volume"
volume_file=${FEATDir}/${LevelOnefMRIName}_AtlasSubcortical"$TemporalFilterString""$SmoothingString".nii.gz
left_file=${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}.atlasroi.L."$LowResMesh"k_fs_LR.func.gii
right_file=${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}.atlasroi.R."$LowResMesh"k_fs_LR.func.gii

${CARET7DIR}/wb_command -cifti-separate-all ${temporal_filter_dtseries_file} -volume ${volume_file} -left ${left_file} -right ${right_file}

# Verify file creation
if [ ! -f ${volume_file} ] ; then
    log_Msg "Volume file not created: ${volume_file}"
fi

if [ ! -f ${left_file} ] ; then
    log_Msg "Left surface file not created: ${left_file}"
fi

if [ ! -f ${right_file} ] ; then
    log_Msg "Right surface file not created: ${right_file}"
fi

###Subcortical Volume Processing###
#Run film_gls on subcortical volume data
log_Msg "Subcortical Volume Processing - run film_gls on subcortical volume data"

${FSLDIR}/bin/film_gls --rn=${FEATDir}/SubcorticalVolumeStats --sa --ms=5 --in=${volume_file} --pd="$DesignMatrix" --thr=1 --mode=volumetric 2>&1

log_Msg "Remove subcortical volume file"
rm -v ${volume_file}

###Cortical Surface Processing###
log_Msg "Cortical Surface Processing"
for Hemisphere in L R ; do
  #Prepare for film_gls  
  ${CARET7DIR}/wb_command -metric-dilate ${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}.atlasroi."$Hemisphere"."$LowResMesh"k_fs_LR.func.gii "$DownSampleFolder"/"$Subject"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii 50 ${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}.atlasroi_dil."$Hemisphere"."$LowResMesh"k_fs_LR.func.gii -nearest

  #Run film_gls on surface data
  ${FSLDIR}/bin/film_gls --rn=${FEATDir}/"$Hemisphere"_SurfaceStats --sa --ms=15 --epith=5 --in2="$DownSampleFolder"/"$Subject"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii --in=${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}.atlasroi_dil."$Hemisphere"."$LowResMesh"k_fs_LR.func.gii --pd="$DesignMatrix" --mode=surface
  rm ${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}.atlasroi_dil."$Hemisphere"."$LowResMesh"k_fs_LR.func.gii ${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}.atlasroi."$Hemisphere"."$LowResMesh"k_fs_LR.func.gii
done


###Grayordinates Processing###
#Merge Surface and Subcortical Gray into Grayordinates
log_Msg "Grayordinates Processing - Merge Surface and Subcortical Gray into Grayordinates"
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

#Run contrast_mgr on grayordinates data
log_Msg "run contrast_mgr on grayordinates data"
cd ${FEATDir}/GrayordinatesStats
Files=`ls | grep .dtseries.nii | cut -d "." -f 1`
cd $DIR
for File in $Files ; do
  log_Msg "File: ${File} from Files"
  ${CARET7DIR}/wb_command -cifti-convert -to-nifti ${FEATDir}/GrayordinatesStats/${File}.dtseries.nii ${FEATDir}/GrayordinatesStats/${File}.nii.gz
  log_Msg "wb_command -cifti-convert -to-nifti: return status: $?"
done
contrast_mgr -f ${DesignfContrasts} ${FEATDir}/GrayordinatesStats "$DesignContrasts"
cd ${FEATDir}/GrayordinatesStats
FilesII=`ls | grep .nii.gz | cut -d "." -f 1`
cd $DIR
for File in $FilesII ; do
  echo $File
  log_Msg "File: ${File} from FilesII"
  if [ -z "$(echo $Files | grep $File)" ] ; then 
    log_Msg "About to wb_command -cifti-convert -from-nifti"
    log_Msg "Command: ${CARET7DIR}/wb_command -cifti-convert -from-nifti ${FEATDir}/GrayordinatesStats/${File}.nii.gz ${FEATDir}/GrayordinatesStats/pe1.dtseries.nii ${FEATDir}/GrayordinatesStats/${File}.dtseries.nii"
    ${CARET7DIR}/wb_command -cifti-convert -from-nifti ${FEATDir}/GrayordinatesStats/${File}.nii.gz ${FEATDir}/GrayordinatesStats/pe1.dtseries.nii ${FEATDir}/GrayordinatesStats/${File}.dtseries.nii
    log_Msg "wb_command -cifti-convert -from-nifti: return status: $?"
  fi
  rm ${FEATDir}/GrayordinatesStats/${File}.nii.gz
done

###Standard Volume-based Processing###
log_Msg "Standard Volume-based Processing"
if [ $VolumeBasedProcessing = "YES" ] ; then

  #Add edge-constrained volume smoothing
  log_Msg "Add edge-constrained volume smoothing"
  FinalSmoothingSigma=`echo "$FinalSmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`
  InputfMRI=${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}
  InputSBRef=${InputfMRI}_SBRef
  OrigMask="mask_orig"
  fslmaths ${InputSBRef} -bin ${FEATDir}/${OrigMask}
  fslmaths ${FEATDir}/${OrigMask} -kernel gauss ${FinalSmoothingSigma} -fmean ${FEATDir}/mask_weight -odt float
  fslmaths ${InputfMRI} -kernel gauss ${FinalSmoothingSigma} -fmean \
    -div ${FEATDir}/mask_weight -mas ${FEATDir}/${OrigMask} \
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

  DilationString="_dilM"

  # Dilate the original BOLD time series, then do (edge-constrained) smoothing
  fslmaths ${FEATDir}/${OrigMask} -dilM -bin ${FEATDir}/mask${DilationString}
  fslmaths ${FEATDir}/mask${DilationString} \
    -kernel gauss ${FinalSmoothingSigma} -fmean ${FEATDir}/mask${DilationString}_weight -odt float
  fslmaths ${InputfMRI} -dilM -kernel gauss ${FinalSmoothingSigma} -fmean \
    -div ${FEATDir}/mask${DilationString}_weight -mas ${FEATDir}/mask${DilationString} \
    ${FEATDir}/${LevelOnefMRIName}${DilationString}"$SmoothingString".nii.gz -odt float

  # Take just the additional "rim" voxels from the dilated then smoothed time series, and add them
  # into the smoothed time series (that didn't have any dilation)
  DilationString2="${DilationString}rim"
  SmoothedDilatedResultFile=${FEATDir}/${LevelOnefMRIName}"$SmoothingString"${DilationString2}
  fslmaths ${FEATDir}/${OrigMask} -binv ${FEATDir}/${OrigMask}_inv
  fslmaths ${FEATDir}/${LevelOnefMRIName}${DilationString}"$SmoothingString" \
    -mas ${FEATDir}/${OrigMask}_inv \
    -add ${FEATDir}/${LevelOnefMRIName}"$SmoothingString" \
    ${SmoothedDilatedResultFile}
    
  #Add temporal filtering to the output from above
  # (Here, we drop the "DilationString" from the output file name, so as to avoid breaking
  # any downstream scripts).
  fslmaths ${SmoothedDilatedResultFile} -bptf `echo "0.5 * $TemporalFilter / $TR_vol" | bc -l` -1 \
    ${FEATDir}/${LevelOnefMRIName}"$TemporalFilterString""$SmoothingString".nii.gz

  #Run film_gls on subcortical volume data
  ${FSLDIR}/bin/film_gls --rn=${FEATDir}/StandardVolumeStats --sa --ms=5 --in=${FEATDir}/${LevelOnefMRIName}"$TemporalFilterString""$SmoothingString".nii.gz --pd="$DesignMatrix" --thr=1000

  #Run contrast_mgr on subcortical volume data
  contrast_mgr -f ${DesignfContrasts} ${FEATDir}/StandardVolumeStats "$DesignContrasts"
fi

log_Msg "Complete"
