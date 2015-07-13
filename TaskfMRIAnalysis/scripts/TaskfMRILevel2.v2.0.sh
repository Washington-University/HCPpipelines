#!/bin/bash
set -e

Subject="$1"
ResultsFolder="$2"
DownSampleFolder="$3"
LevelOnefMRINames="$4"
LevelOnefsfNames="$5"
LevelTwofMRIName="$6"
LevelTwofsfName="$7"
LowResMesh="$8"
FinalSmoothingFWHM="$9"
TemporalFilter="${10}"
VolumeBasedProcessing="${11}"
RegName="${12}"
Parcellation="${13}"


#Set up some things
LevelOnefMRINames=`echo $LevelOnefMRINames | sed 's/@/ /g'`
LevelOnefsfNames=`echo $LevelOnefsfNames | sed 's/@/ /g'`

if [ ! ${Parcellation} = "NONE" ] ; then
  ParcellationString="_${Parcellation}"
  Extension="ptseries.nii"
  ScalarExtension="pscalar.nii"
else
  ParcellationString=""
  Extension="dtseries.nii"
  ScalarExtension="dscalar.nii"
fi

if [ ! ${RegName} = "NONE" ] ; then
  RegString="_${RegName}"
else
  RegString=""
fi

SmoothingString="_s${FinalSmoothingFWHM}"
TemporalFilterString="_hp""$TemporalFilter"

LevelOneFEATDirSTRING=""
i=1
for LevelOnefMRIName in $LevelOnefMRINames ; do 
  LevelOnefsfName=`echo $LevelOnefsfNames | cut -d " " -f $i`
  LevelOneFEATDirSTRING="${LevelOneFEATDirSTRING}${ResultsFolder}/${LevelOnefMRIName}/${LevelOnefsfName}${TemporalFilterString}${SmoothingString}_level1${RegString}${ParcellationString}.feat "
  i=$(($i+1))
done
NumFirstLevelFolders=$(($i-1))

FirstFolder=`echo $LevelOneFEATDirSTRING | cut -d " " -f 1`
ContrastNames=`cat ${FirstFolder}/design.con | grep "ContrastName" | cut -f 2`
NumContrasts=`echo ${ContrastNames} | wc -w`
LevelTwoFEATDir="${ResultsFolder}/${LevelTwofMRIName}/${LevelTwofsfName}${TemporalFilterString}${SmoothingString}_level2${RegString}${ParcellationString}.feat"
if [ -e ${LevelTwoFEATDir} ] ; then
  rm -r ${LevelTwoFEATDir}
  mkdir ${LevelTwoFEATDir}
else
  mkdir -p ${LevelTwoFEATDir}
fi

cat ${ResultsFolder}/${LevelTwofMRIName}/${LevelTwofsfName}_hp200_s4_level2.fsf | sed s/_hp200_s4/${TemporalFilterString}${SmoothingString}${RegString}${ParcellationString}/g > ${LevelTwoFEATDir}/design.fsf

#Make design files
DIR=`pwd`
cd ${LevelTwoFEATDir}
feat_model ${LevelTwoFEATDir}/design
cd $DIR

#Loop over Grayordinates and Standard Volume (if requested) Level 2 Analyses
if [ ${VolumeBasedProcessing} = "YES" ] ; then
  Analyses="GrayordinatesStats StandardVolumeStats"
elif [ -z ${ParcellationString} ] ; then
  Analyses="GrayordinatesStats"
else
  Analyses="ParcellatedStats"
fi
for Analysis in ${Analyses} ; do
  mkdir -p ${LevelTwoFEATDir}/${Analysis}
  
  #Copy over level one folders and convert CIFTI to NIFTI if required
  if [ -e ${FirstFolder}/${Analysis}/cope1.nii.gz ] ; then
    Grayordinates="NO"
    i=1
    for LevelOneFEATDir in ${LevelOneFEATDirSTRING} ; do
      mkdir -p ${LevelTwoFEATDir}/${Analysis}/${i}
      cp ${LevelOneFEATDir}/${Analysis}/* ${LevelTwoFEATDir}/${Analysis}/${i}
      i=$(($i+1))
    done
  elif [ -e ${FirstFolder}/${Analysis}/cope1.${Extension} ] ; then
    Grayordinates="YES"
    i=1
    for LevelOneFEATDir in ${LevelOneFEATDirSTRING} ; do
      mkdir -p ${LevelTwoFEATDir}/${Analysis}/${i}
      cp ${LevelOneFEATDir}/${Analysis}/* ${LevelTwoFEATDir}/${Analysis}/${i}
      cd ${LevelTwoFEATDir}/${Analysis}/${i}
      Files=`ls | grep .${Extension} | cut -d "." -f 1`
      cd $DIR
      for File in $Files ; do
        ${CARET7DIR}/wb_command -cifti-convert -to-nifti ${LevelTwoFEATDir}/${Analysis}/${i}/${File}.${Extension} ${LevelTwoFEATDir}/${Analysis}/${i}/${File}.nii.gz
        rm ${LevelTwoFEATDir}/${Analysis}/${i}/${File}.${Extension}
      done
      i=$(($i+1))
    done
  else
    echo "Level One Folder Not Found"
  fi
  
  #Create dof and Mask
  MERGESTRING=""
  i=1
  while [ $i -le ${NumFirstLevelFolders} ] ; do
    dof=`cat ${LevelTwoFEATDir}/${Analysis}/${i}/dof`
    fslmaths ${LevelTwoFEATDir}/${Analysis}/${i}/res4d.nii.gz -Tstd -bin -mul $dof ${LevelTwoFEATDir}/${Analysis}/${i}/dofmask.nii.gz
    MERGESTRING=`echo "${MERGESTRING}${LevelTwoFEATDir}/${Analysis}/${i}/dofmask.nii.gz "`
    i=$(($i+1))
  done
  fslmerge -t ${LevelTwoFEATDir}/${Analysis}/dof.nii.gz $MERGESTRING
  fslmaths ${LevelTwoFEATDir}/${Analysis}/dof.nii.gz -Tmin -bin ${LevelTwoFEATDir}/${Analysis}/mask.nii.gz
  
  #Merge COPES and VARCOPES and run 2nd level analysis
  i=1
  while [ $i -le ${NumContrasts} ] ; do
    COPEMERGE=""
    VARCOPEMERGE=""
    j=1
    while [ $j -le ${NumFirstLevelFolders} ] ; do
      COPEMERGE="${COPEMERGE}${LevelTwoFEATDir}/${Analysis}/${j}/cope${i}.nii.gz "
      VARCOPEMERGE="${VARCOPEMERGE}${LevelTwoFEATDir}/${Analysis}/${j}/varcope${i}.nii.gz "
      j=$(($j+1))
    done
    fslmerge -t ${LevelTwoFEATDir}/${Analysis}/cope${i}.nii.gz $COPEMERGE
    fslmerge -t ${LevelTwoFEATDir}/${Analysis}/varcope${i}.nii.gz $VARCOPEMERGE
    flameo --cope=${LevelTwoFEATDir}/${Analysis}/cope${i}.nii.gz --vc=${LevelTwoFEATDir}/${Analysis}/varcope${i}.nii.gz --dvc=${LevelTwoFEATDir}/${Analysis}/dof.nii.gz --mask=${LevelTwoFEATDir}/${Analysis}/mask.nii.gz --ld=${LevelTwoFEATDir}/${Analysis}/cope${i}.feat --dm=${LevelTwoFEATDir}/design.mat --cs=${LevelTwoFEATDir}/design.grp --tc=${LevelTwoFEATDir}/design.con --runmode=fe
    i=$(($i+1))
  done

  #Cleanup Temporary Files
  j=1
  while [ $j -le ${NumFirstLevelFolders} ] ; do
    rm -r ${LevelTwoFEATDir}/${Analysis}/${j}
    j=$(($j+1))
  done

  #Convert Grayordinates NIFTI Files to CIFTI if necessary
  if [ $Grayordinates = "YES" ] ; then
    cd ${LevelTwoFEATDir}/${Analysis}
    Files=`ls | grep .nii.gz | cut -d "." -f 1`
    cd $DIR
    for File in $Files ; do
      ${CARET7DIR}/wb_command -cifti-convert -from-nifti ${LevelTwoFEATDir}/${Analysis}/${File}.nii.gz ${LevelOneFEATDir}/${Analysis}/pe1.${Extension} ${LevelTwoFEATDir}/${Analysis}/${File}.${Extension} -reset-timepoints 1 1 
      rm ${LevelTwoFEATDir}/${Analysis}/${File}.nii.gz
    done
    i=1
    while [ $i -le ${NumContrasts} ] ; do
      cd ${LevelTwoFEATDir}/${Analysis}/cope${i}.feat
      Files=`ls | grep .nii.gz | cut -d "." -f 1`
      cd $DIR
      for File in $Files ; do
        ${CARET7DIR}/wb_command -cifti-convert -from-nifti ${LevelTwoFEATDir}/${Analysis}/cope${i}.feat/${File}.nii.gz ${LevelOneFEATDir}/${Analysis}/pe1.${Extension} ${LevelTwoFEATDir}/${Analysis}/cope${i}.feat/${File}.${Extension} -reset-timepoints 1 1 
        rm ${LevelTwoFEATDir}/${Analysis}/cope${i}.feat/${File}.nii.gz
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
if [ -e ${LevelTwoFEATDir}/Contrasts.txt ] ; then
  rm ${LevelTwoFEATDir}/Contrasts.txt
fi
while [ $i -le ${NumContrasts} ] ; do
  Contrast=`echo $ContrastNames | cut -d " " -f $i`
  echo "${Subject}_${LevelTwofsfName}_level2_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ParcellationString}" >> ${LevelTwoFEATDir}/Contrasttemp.txt
  echo ${Contrast} >> ${LevelTwoFEATDir}/Contrasts.txt
  ${CARET7DIR}/wb_command -cifti-convert-to-scalar ${LevelTwoFEATDir}/${Analysis}/cope${i}.feat/zstat1.${Extension} ROW ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ParcellationString}.${ScalarExtension} -name-file ${LevelTwoFEATDir}/Contrasttemp.txt
  ${CARET7DIR}/wb_command -cifti-convert-to-scalar ${LevelTwoFEATDir}/${Analysis}/cope${i}.feat/cope1.${Extension} ROW ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_beta_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ParcellationString}.${ScalarExtension} -name-file ${LevelTwoFEATDir}/Contrasttemp.txt
  zMergeSTRING=`echo "${zMergeSTRING}-cifti ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ParcellationString}.${ScalarExtension} "`
  bMergeSTRING=`echo "${bMergeSTRING}-cifti ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_beta_${Contrast}${TemporalFilterString}${SmoothingString}${RegString}${ParcellationString}.${ScalarExtension} "`

  if [ ${VolumeBasedProcessing} = "YES" ] ; then
    echo "OTHER" >> ${LevelTwoFEATDir}/wbtemp.txt
    echo "1 255 255 255 255" >> ${LevelTwoFEATDir}/wbtemp.txt
    ${CARET7DIR}/wb_command -volume-label-import ${LevelTwoFEATDir}/StandardVolumeStats/mask.nii.gz ${LevelTwoFEATDir}/wbtemp.txt ${LevelTwoFEATDir}/StandardVolumeStats/mask.nii.gz -discard-others -unlabeled-value 0
    rm ${LevelTwoFEATDir}/wbtemp.txt
    ${CARET7DIR}/wb_command -cifti-create-dense-timeseries ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2vol_${Contrast}${TemporalFilterString}${SmoothingString}.dtseries.nii -volume ${LevelTwoFEATDir}/StandardVolumeStats/cope${i}.feat/zstat1.nii.gz ${LevelTwoFEATDir}/StandardVolumeStats/mask.nii.gz -timestep 1 -timestart 1
    ${CARET7DIR}/wb_command -cifti-convert-to-scalar ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2vol_${Contrast}${TemporalFilterString}${SmoothingString}.dtseries.nii ROW ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2vol_${Contrast}${TemporalFilterString}${SmoothingString}.dscalar.nii -name-file ${LevelTwoFEATDir}/Contrasttemp.txt
    rm ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2vol_${Contrast}${TemporalFilterString}${SmoothingString}.dtseries.nii
    VolMergeSTRING=`echo "${VolMergeSTRING}-cifti ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2vol_${Contrast}${TemporalFilterString}${SmoothingString}.dscalar.nii "`
  fi
  rm ${LevelTwoFEATDir}/Contrasttemp.txt
  i=$(($i+1))
done
${CARET7DIR}/wb_command -cifti-merge ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2${TemporalFilterString}${SmoothingString}${RegString}${ParcellationString}.${ScalarExtension} ${zMergeSTRING}
${CARET7DIR}/wb_command -cifti-merge ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2_beta${TemporalFilterString}${SmoothingString}${RegString}${ParcellationString}.${ScalarExtension} ${bMergeSTRING}
if [ ${VolumeBasedProcessing} = "YES" ] ; then
  ${CARET7DIR}/wb_command -cifti-merge ${LevelTwoFEATDir}/${Subject}_${LevelTwofsfName}_level2vol${TemporalFilterString}${SmoothingString}.dscalar.nii ${VolMergeSTRING}  
fi


