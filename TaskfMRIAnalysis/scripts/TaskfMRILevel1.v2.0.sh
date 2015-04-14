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
RegName="${14}"
Parcellation="${15}"
ParcellationFile="${16}"

if [ ! ${Parcellation} = "NONE" ] ; then
  ParcellationString="_${Parcellation}"
  Extension="ptseries.nii"
else
  ParcellationString=""
  Extension="dtseries.nii"
fi

if [ ! ${RegName} = "NONE" ] ; then
  RegString="_${RegName}"
else
  RegString=""
fi

#Parcellate data if a Parcellation was provided
if [ ! ${Parcellation} = "NONE" ] ; then
  ${CARET7DIR}/wb_command -cifti-parcellate ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}.dtseries.nii ${ParcellationFile} COLUMN ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${ParcellationString}.ptseries.nii
fi

TR_vol=`${CARET7DIR}/wb_command -file-information ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${ParcellationString}.${Extension} -no-map-info -only-step-interval`

#Only do the additional smoothing required to hit the target final smoothing for CIFTI.  Additional smoothing is not recommended, if looking for area-sized effects use parcellation for greater sensitivity and satistical power
AdditionalSmoothingFWHM=`echo "sqrt(( $FinalSmoothingFWHM ^ 2 ) - ( $OriginalSmoothingFWHM ^ 2 ))" | bc -l`

AdditionalSigma=`echo "$AdditionalSmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`

SmoothingString="_s${FinalSmoothingFWHM}"
TemporalFilterString="_hp""$TemporalFilter"

FEATDir="${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefsfName}${TemporalFilterString}${SmoothingString}_level1${RegString}${ParcellationString}.feat"
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
cat ${FEATDir}/temp.fsf | sed s/"set fmri(smooth) \"4\""/"set fmri(smooth) \"${AdditionalSmoothingFWHM}\""/g | sed s/_hp200_s4/${TemporalFilterString}${SmoothingString}${RegString}${ParcellationString}/g > ${FEATDir}/design.fsf
rm ${FEATDir}/temp.fsf

#Change number of timepoints to match timeseries so that template fsf files can be used
fsfnpts=`cat ${FEATDir}/design.fsf | grep "set fmri(npts)" | cut -d " " -f 3 | sed 's/"//g'`
CIFTInpts=`${CARET7DIR}/wb_command -file-information ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${ParcellationString}.${Extension} -no-map-info -only-number-of-maps`
if [ $fsfnpts -ne $CIFTInpts ] ; then
  cat ${FEATDir}/design.fsf | sed s/"set fmri(npts) \"\?${fsfnpts}\"\?"/"set fmri(npts) ${CIFTInpts}"/g > ${FEATDir}/temp.fsf
  mv ${FEATDir}/temp.fsf ${FEATDir}/design.fsf
  echo "Short Run! Reseting FSF Number of Timepoints (""${fsfnpts}"") to Match CIFTI (""${CIFTInpts}"")"
fi

#Create design files, model confounds if desired
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


###CIFTI Processing###
#Add any additional smoothing, does not do anything if parcellation has been specified. Additional smoothing is not recommended, if looking for area-sized effects use parcellation for greater sensitivity and satistical power
if [[ ! $FinalSmoothingFWHM -eq $OriginalSmoothingFWHM && -z ${ParcellationString} ]] ; then
  ${CARET7DIR}/wb_command -cifti-smoothing ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}.dtseries.nii ${AdditionalSigma} ${AdditionalSigma} COLUMN ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$SmoothingString"${RegString}.dtseries.nii -left-surface "$DownSampleFolder"/"$Subject".L.midthickness."$LowResMesh"k_fs_LR.surf.gii -right-surface "$DownSampleFolder"/"$Subject".R.midthickness."$LowResMesh"k_fs_LR.surf.gii
else
  cp ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas${RegString}${ParcellationString}.${Extension} ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$SmoothingString"${RegString}${ParcellationString}.${Extension}
fi

#Add temporal filtering
${CARET7DIR}/wb_command -cifti-convert -to-nifti ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$SmoothingString"${RegString}${ParcellationString}.${Extension} ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$SmoothingString"${RegString}${ParcellationString}_FAKENIFTI.nii.gz
fslmaths ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$SmoothingString"${RegString}${ParcellationString}_FAKENIFTI.nii.gz -Tmean ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$SmoothingString"${RegString}${ParcellationString}_FAKENIFTI_mean.nii.gz
fslmaths ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$SmoothingString"${RegString}${ParcellationString}_FAKENIFTI.nii.gz -bptf `echo "0.5 * $TemporalFilter / $TR_vol" | bc -l` 0 -add ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$SmoothingString"${RegString}${ParcellationString}_FAKENIFTI_mean.nii.gz ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$SmoothingString"${RegString}${ParcellationString}_FAKENIFTI.nii.gz
${CARET7DIR}/wb_command -cifti-convert -from-nifti ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$SmoothingString"${RegString}${ParcellationString}_FAKENIFTI.nii.gz ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$SmoothingString"${RegString}${ParcellationString}.${Extension} ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$TemporalFilterString""$SmoothingString"${RegString}${ParcellationString}.${Extension}
rm ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$SmoothingString"${RegString}${ParcellationString}_FAKENIFTI.nii.gz ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$SmoothingString"${RegString}${ParcellationString}_FAKENIFTI_mean.nii.gz

#Check if data are Parcellated, if not, do Dense Grayordinates Analysis#
if [ -z ${ParcellationString} ] ; then

  ###Dense Grayordinates Processing###
  #Split into surface and volume
  ${CARET7DIR}/wb_command -cifti-separate-all ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$TemporalFilterString""$SmoothingString"${RegString}.dtseries.nii -volume ${FEATDir}/${LevelOnefMRIName}_AtlasSubcortical"$TemporalFilterString""$SmoothingString".nii.gz -left ${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}${RegString}.atlasroi.L."$LowResMesh"k_fs_LR.func.gii -right ${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}${RegString}.atlasroi.R."$LowResMesh"k_fs_LR.func.gii

  #Run film_gls on subcortical volume data
  film_gls --rn=${FEATDir}/SubcorticalVolumeStats --sa --ms=5 --in=${FEATDir}/${LevelOnefMRIName}_AtlasSubcortical"$TemporalFilterString""$SmoothingString".nii.gz --pd="$DesignMatrix" --con=${DesignContrasts} --fcon=${DesignfContrasts} --thr=1 --mode=volumetric
  rm ${FEATDir}/${LevelOnefMRIName}_AtlasSubcortical"$TemporalFilterString""$SmoothingString".nii.gz

  #Run film_gls on cortical surface data 
  for Hemisphere in L R ; do
    #Prepare for film_gls  
    ${CARET7DIR}/wb_command -metric-dilate ${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}${RegString}.atlasroi."$Hemisphere"."$LowResMesh"k_fs_LR.func.gii "$DownSampleFolder"/"$Subject"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii 50 ${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}${RegString}.atlasroi_dil."$Hemisphere"."$LowResMesh"k_fs_LR.func.gii -nearest

    #Run film_gls on surface data
    film_gls --rn=${FEATDir}/"$Hemisphere"_SurfaceStats --sa --ms=15 --epith=5 --in2="$DownSampleFolder"/"$Subject"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii --in=${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}${RegString}.atlasroi_dil."$Hemisphere"."$LowResMesh"k_fs_LR.func.gii --pd="$DesignMatrix" --con=${DesignContrasts} --fcon=${DesignfContrasts} --mode=surface
    rm ${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}${RegString}.atlasroi_dil."$Hemisphere"."$LowResMesh"k_fs_LR.func.gii ${FEATDir}/${LevelOnefMRIName}${TemporalFilterString}${SmoothingString}${RegString}.atlasroi."$Hemisphere"."$LowResMesh"k_fs_LR.func.gii
  done

  #Merge Cortical Surface and Subcortical Volume into Grayordinates
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
  ${CARET7DIR}/wb_command -cifti-convert -to-nifti ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_Atlas"$TemporalFilterString""$SmoothingString"${RegString}${ParcellationString}.${Extension} ${FEATDir}/${LevelOnefMRIName}_Atlas"$TemporalFilterString""$SmoothingString"${RegString}${ParcellationString}_FAKENIFTI.nii.gz
  film_gls --rn=${FEATDir}/ParcellatedStats --in=${FEATDir}/${LevelOnefMRIName}_Atlas"$TemporalFilterString""$SmoothingString"${RegString}${ParcellationString}_FAKENIFTI.nii.gz --pd="$DesignMatrix" --con=${DesignContrasts} --fcon=${DesignfContrasts} --thr=1 --mode=volumetric
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
if [ $VolumeBasedProcessing = "YES" ] ; then
  #Add volume smoothing
  FinalSmoothingSigma=`echo "$FinalSmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`
  fslmaths ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_SBRef.nii.gz -bin -kernel gauss ${FinalSmoothingSigma} -fmean ${FEATDir}/mask_weight -odt float
  fslmaths ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}.nii.gz -kernel gauss ${FinalSmoothingSigma} -fmean -div ${FEATDir}/mask_weight -mas ${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefMRIName}_SBRef.nii.gz ${FEATDir}/${LevelOnefMRIName}"$SmoothingString".nii.gz -odt float
  
  #Add temporal filtering
  fslmaths ${FEATDir}/${LevelOnefMRIName}"$SmoothingString".nii.gz -bptf `echo "0.5 * $TemporalFilter / $TR_vol" | bc -l` -1 ${FEATDir}/${LevelOnefMRIName}"$TemporalFilterString""$SmoothingString".nii.gz

  #Run film_gls on subcortical volume data
  film_gls --rn=${FEATDir}/StandardVolumeStats --sa --ms=5 --in=${FEATDir}/${LevelOnefMRIName}"$TemporalFilterString""$SmoothingString".nii.gz --pd="$DesignMatrix" --con=${DesignContrasts} --fcon=${DesignfContrasts} --thr=1000
fi


