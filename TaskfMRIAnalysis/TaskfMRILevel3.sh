#!/bin/bash

Subjlist="$1"
Path="$2"
CommonFolder="$3"
GroupAverageName="$4"
LevelThreeDesignTemplate="$5"
LevelTwofMRIName="$6"
LevelTwofsfName="$7"
LowResMesh="$8"
FinalSmoothingFWHM="$9"
TemporalFilter="${10}"
VolumeBasedProcessing="${11}"
RegName="${12}"

#Naming Conventions
CommonAtlasFolder="${CommonFolder}/MNINonLinear"
CommonResultsFolder="${CommonAtlasFolder}/Results"

#Set up some things
Subjlist=`echo $Subjlist | sed 's/@/ /g'`

SmoothingString="_s${FinalSmoothingFWHM}"
TemporalFilterString="_hp""$TemporalFilter"
if [ ! $RegName = NONE ] ; then 
  RegString="_${RegName}"
else
  RegString=""
fi

LevelTwoFEATDirSTRING=""
for Subject in $Subjlist ; do 
  AtlasFolder="${Path}/${Subject}/MNINonLinear"
  ResultsFolder="${AtlasFolder}/Results"
  LevelTwoFEATDirSTRING="${LevelTwoFEATDirSTRING}${ResultsFolder}/${LevelTwofMRIName}/${LevelTwofsfName}${TemporalFilterString}${SmoothingString}_level2${RegString}.feat "
  i=$(($i+1))
done
NumSecondLevelFolders=`echo ${LevelTwoFEATDirSTRING} | wc -w`

FirstFolder=`echo $LevelTwoFEATDirSTRING | cut -d " " -f 1`
ContrastNames=`cat ${FirstFolder}/Contrasts.txt`
NumContrasts=`echo ${ContrastNames} | wc -w`
LevelThreeFEATDir="${CommonResultsFolder}/${LevelTwofMRIName}/${LevelTwofsfName}${TemporalFilterString}${SmoothingString}_level3${RegString}.feat"
if [ -e ${LevelThreeFEATDir} ] ; then
  rm -r ${LevelThreeFEATDir}
  mkdir ${LevelThreeFEATDir}
else
  mkdir -p ${LevelThreeFEATDir}
fi

cat ${LevelThreeDesignTemplate} > ${LevelThreeFEATDir}/design.fsf

#Make design files
DIR=`pwd`
cd ${LevelThreeFEATDir}
feat_model ${LevelThreeFEATDir}/design
cd $DIR

#Loop over Grayordinates and Standard Volume (if requested) Level 2 Analyses
if [ ${VolumeBasedProcessing} = "YES" ] ; then
  Analyses="GrayordinatesStats StandardVolumeStats"
else
  Analyses="GrayordinatesStats"
fi
for Analysis in ${Analyses} ; do
  mkdir -p ${LevelThreeFEATDir}/${Analysis}
  
  #Copy over level one folders and convert CIFTI to NIFTI if required
  if [ -e ${FirstFolder}/${Analysis}/cope1.feat/cope1.nii.gz ] ; then
    Grayordinates="NO"
    i=1
    while [ $i -le $NumContrasts ] ; do
      j=1
      for Subject in ${Subjlist} ; do
        mkdir -p ${LevelThreeFEATDir}/${Analysis}/${i}/${j}
        LevelTwoFEATDir=`echo ${LevelTwoFEATDirSTRING} | cut -d " " -f $j`
        cp ${LevelTwoFEATDir}/${Analysis}/cope${i}.feat/* ${LevelThreeFEATDir}/${Analysis}/${i}/${j}
        j=$(($j+1))
      done
      i=$(($i+1))
    done
  elif [ -e ${FirstFolder}/${Analysis}/cope1.feat/cope1.dtseries.nii ] ; then
    Grayordinates="YES"
    i=1
    while [ $i -le $NumContrasts ] ; do
      j=1
      for Subject in ${Subjlist} ; do
        mkdir -p ${LevelThreeFEATDir}/${Analysis}/${i}/${j}
        LevelTwoFEATDir=`echo ${LevelTwoFEATDirSTRING} | cut -d " " -f $j`
        cp ${LevelTwoFEATDir}/${Analysis}/cope${i}.feat/* ${LevelThreeFEATDir}/${Analysis}/${i}/${j}
        cd ${LevelThreeFEATDir}/${Analysis}/${i}/${j}
        Files=`ls | grep .dtseries.nii | cut -d "." -f 1`
        cd $DIR
        for File in $Files ; do
          ${CARET7DIR}/wb_command -cifti-convert -to-nifti ${LevelThreeFEATDir}/${Analysis}/${i}/${j}/${File}.dtseries.nii ${LevelThreeFEATDir}/${Analysis}/${i}/${j}/${File}.nii.gz
          rm ${LevelThreeFEATDir}/${Analysis}/${i}/${j}/${File}.dtseries.nii
        done
        j=$(($j+1))
      done
      i=$(($i+1))
    done
  else
    echo "Level Two Folder Not Found"
  fi
   
  #Merge Masks tdof_t1s COPES and VARCOPES and run 3rd level analysis
  i=1
  while [ $i -le ${NumContrasts} ] ; do
    MASKMERGE=""
    COPEMERGE=""
    VARCOPEMERGE=""
    DOFMERGE=""
    j=1
    while [ $j -le ${NumSecondLevelFolders} ] ; do
      MASKMERGE="${MASKMERGE}${LevelThreeFEATDir}/${Analysis}/${i}/${j}/mask.nii.gz "
      COPEMERGE="${COPEMERGE}${LevelThreeFEATDir}/${Analysis}/${i}/${j}/cope1.nii.gz "
      VARCOPEMERGE="${VARCOPEMERGE}${LevelThreeFEATDir}/${Analysis}/${i}/${j}/varcope1.nii.gz "
      DOFMERGE="${DOFMERGE}${LevelThreeFEATDir}/${Analysis}/${i}/${j}/tdof_t1.nii.gz "
      j=$(($j+1))
    done
    fslmerge -t ${LevelThreeFEATDir}/${Analysis}/mask${i}.nii.gz $MASKMERGE
    fslmaths ${LevelThreeFEATDir}/${Analysis}/mask${i}.nii.gz -Tmin ${LevelThreeFEATDir}/${Analysis}/mask${i}.nii.gz
    fslmerge -t ${LevelThreeFEATDir}/${Analysis}/cope${i}.nii.gz $COPEMERGE
    fslmaths ${LevelThreeFEATDir}/${Analysis}/cope${i}.nii.gz -mas ${LevelThreeFEATDir}/${Analysis}/mask${i}.nii.gz ${LevelThreeFEATDir}/${Analysis}/cope${i}.nii.gz
    fslmerge -t ${LevelThreeFEATDir}/${Analysis}/varcope${i}.nii.gz $VARCOPEMERGE
    fslmaths ${LevelThreeFEATDir}/${Analysis}/varcope${i}.nii.gz -mas ${LevelThreeFEATDir}/${Analysis}/mask${i}.nii.gz ${LevelThreeFEATDir}/${Analysis}/varcope${i}.nii.gz
    fslmerge -t ${LevelThreeFEATDir}/${Analysis}/tdof_t1${i}.nii.gz $DOFMERGE
    fslmaths ${LevelThreeFEATDir}/${Analysis}/tdof_t1${i}.nii.gz -mas ${LevelThreeFEATDir}/${Analysis}/mask${i}.nii.gz ${LevelThreeFEATDir}/${Analysis}/tdof_t1${i}.nii.gz
    flameo --cope=${LevelThreeFEATDir}/${Analysis}/cope${i}.nii.gz --vc=${LevelThreeFEATDir}/${Analysis}/varcope${i}.nii.gz --dvc=${LevelThreeFEATDir}/${Analysis}/tdof_t1${i}.nii.gz --mask=${LevelThreeFEATDir}/${Analysis}/mask${i}.nii.gz --ld=${LevelThreeFEATDir}/${Analysis}/cope${i}.feat --dm=${LevelThreeFEATDir}/design.mat --cs=${LevelThreeFEATDir}/design.grp --tc=${LevelThreeFEATDir}/design.con --runmode=flame1
    i=$(($i+1))
  done

  #Cleanup Temporary Files
  i=1
  while [ $i -le ${NumContrasts} ] ; do
    rm -r ${LevelThreeFEATDir}/${Analysis}/${i}
    i=$(($i+1))
  done

  #Convert NIFTI Files to CIFTI if necessary
  if [ $Grayordinates = "YES" ] ; then
    cd ${LevelThreeFEATDir}/${Analysis}
    Files=`ls | grep .nii.gz | cut -d "." -f 1`
    cd $DIR
    for File in $Files ; do
      ${CARET7DIR}/wb_command -cifti-convert -from-nifti ${LevelThreeFEATDir}/${Analysis}/${File}.nii.gz ${LevelTwoFEATDir}/${Analysis}/cope1.feat/pe1.dtseries.nii ${LevelThreeFEATDir}/${Analysis}/${File}.dtseries.nii -reset-timepoints 1 1 
      rm ${LevelThreeFEATDir}/${Analysis}/${File}.nii.gz
    done
    i=1
    while [ $i -le ${NumContrasts} ] ; do
      cd ${LevelThreeFEATDir}/${Analysis}/cope${i}.feat
      Files=`ls | grep .nii.gz | cut -d "." -f 1`
      cd $DIR
      for File in $Files ; do
        ${CARET7DIR}/wb_command -cifti-convert -from-nifti ${LevelThreeFEATDir}/${Analysis}/cope${i}.feat/${File}.nii.gz ${LevelTwoFEATDir}/${Analysis}/cope${i}.feat/pe1.dtseries.nii ${LevelThreeFEATDir}/${Analysis}/cope${i}.feat/${File}.dtseries.nii -reset-timepoints 1 1 
        rm ${LevelThreeFEATDir}/${Analysis}/cope${i}.feat/${File}.nii.gz
      done
      i=$(($i+1))
    done        
  fi
done  

#Genereate Files for Viewing
i=1
MergeSTRING=""
if [ ${VolumeBasedProcessing} = "YES" ] ; then
  VolMergeSTRING=""
fi
if [ -e ${LevelThreeFEATDir}/Contrasts.txt ] ; then
  rm ${LevelThreeFEATDir}/Contrasts.txt
fi
while [ $i -le ${NumContrasts} ] ; do
  Contrast=`echo $ContrastNames | cut -d " " -f $i`
  echo "${GroupAverageName}_${LevelTwofsfName}_level3_${Contrast}${TemporalFilterString}${SmoothingString}" >> ${LevelThreeFEATDir}/Contrasttemp.txt
  echo ${Contrast} >> ${LevelThreeFEATDir}/Contrasts.txt
  ${CARET7DIR}/wb_command -cifti-convert-to-scalar ${LevelThreeFEATDir}/GrayordinatesStats/cope${i}.feat/zstat1.dtseries.nii ROW ${LevelThreeFEATDir}/${GroupAverageName}_${LevelTwofsfName}_level3_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}.dscalar.nii -name-file ${LevelThreeFEATDir}/Contrasttemp.txt
  MergeSTRING=`echo "${MergeSTRING}-cifti ${LevelThreeFEATDir}/${GroupAverageName}_${LevelTwofsfName}_level3_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}.dscalar.nii "`
  if [ ${VolumeBasedProcessing} = "YES" ] ; then
    echo "OTHER" >> ${LevelThreeFEATDir}/wbtemp.txt
    echo "1 255 255 255 255" >> ${LevelThreeFEATDir}/wbtemp.txt
    ${CARET7DIR}/wb_command -volume-label-import ${LevelThreeFEATDir}/StandardVolumeStats/mask${i}.nii.gz ${LevelThreeFEATDir}/wbtemp.txt ${LevelThreeFEATDir}/StandardVolumeStats/mask${i}.nii.gz -discard-others -unlabeled-value 0
    rm ${LevelThreeFEATDir}/wbtemp.txt
    ${CARET7DIR}/wb_command -cifti-create-dense-timeseries ${LevelThreeFEATDir}/${GroupAverageName}_${LevelTwofsfName}_level3vol_${Contrast}${TemporalFilterString}${SmoothingString}.dtseries.nii -volume ${LevelThreeFEATDir}/StandardVolumeStats/cope${i}.feat/zstat1.nii.gz ${LevelThreeFEATDir}/StandardVolumeStats/mask${i}.nii.gz -timestep 1 -timestart 1
    ${CARET7DIR}/wb_command -cifti-convert-to-scalar ${LevelThreeFEATDir}/${GroupAverageName}_${LevelTwofsfName}_level3vol_${Contrast}${TemporalFilterString}${SmoothingString}.dtseries.nii ROW ${LevelThreeFEATDir}/${GroupAverageName}_${LevelTwofsfName}_level3vol_${Contrast}${TemporalFilterString}${SmoothingString}.dscalar.nii -name-file ${LevelThreeFEATDir}/Contrasttemp.txt
    rm ${LevelThreeFEATDir}/${GroupAverageName}_${LevelTwofsfName}_level3vol_${Contrast}${TemporalFilterString}${SmoothingString}.dtseries.nii
    VolMergeSTRING=`echo "${VolMergeSTRING}-cifti ${LevelThreeFEATDir}/${GroupAverageName}_${LevelTwofsfName}_level3vol_${Contrast}${TemporalFilterString}${SmoothingString}.dscalar.nii "`
  fi
  rm ${LevelThreeFEATDir}/Contrasttemp.txt
  i=$(($i+1))
done
${CARET7DIR}/wb_command -cifti-merge ${LevelThreeFEATDir}/${GroupAverageName}_${LevelTwofsfName}_level3${TemporalFilterString}${SmoothingString}${RegString}.dscalar.nii ${MergeSTRING}
if [ ${VolumeBasedProcessing} = "YES" ] ; then
  ${CARET7DIR}/wb_command -cifti-merge ${LevelThreeFEATDir}/${GroupAverageName}_${LevelTwofsfName}_level3vol${TemporalFilterString}${SmoothingString}.dscalar.nii ${VolMergeSTRING}  
fi


