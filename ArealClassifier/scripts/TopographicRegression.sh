#!/bin/bash
#set -xv
StudyFolder="${1}"
Subject="${2}"
GroupData="${3}"
rfMRINames="${4}"
OutrfMRIName="${5}"
LowResMesh="${6}"
Caret7_Command="${7}"
ResultLocation="${8}"
RegName="${9}"
ProcSTRING="${10}"
LeftAreaBorder="${11}"
RightAreaBorder="${12}"
AreaName="${13}"
AreaIINames="${14}"
AxisOneBorder="${15}"
AxisTwoBorder="${16}"
AxisOneLeftParameters="${17}"
AxisOneRightParameters="${18}"
AxisTwoLeftParameters="${19}"
AxisTwoRightParameters="${20}"
GradientSmoothingFWHM="${21}"
LinearGradientSmoothingFWHM="${22}"
DilationAmount="${23}"
GenerateGradients="${24}"
ReRun="${25}"
AxisOnePalette="${26}"
AxisTwoPalette="${27}"
numit="${28}"
AxisOneFactor="${29}"
AxisTwoFactor="${30}"
GroupROILocation="${31}"
BC="${32}"
NuisanceROIBorder="${33}"
SaveDCONN="${34}"

AtlasFolder="${StudyFolder}/${Subject}/MNINonLinear"
ResultsFolder="${AtlasFolder}/Results/${OutrfMRIName}"
DownSampleFolder="${AtlasFolder}/fsaverage_LR${LowResMesh}k"
ROILocation="${ResultsFolder}/${ResultLocation}/ROIs"
ResultLocation="${ResultsFolder}/${ResultLocation}"

GradientSmoothingSigma=`echo "${GradientSmoothingFWHM} / (2 * sqrt(2 * l(2)))" | bc -l`

if [ ${RegName} = "NONE" ] ; then
  RegSTRING=""
else
  RegSTRING="_${RegName}"
fi

if [ ${GroupData} = "1" ] ; then
  VAFolderName="MNINonLinear"
else
  VAFolderName="T1w"
fi

rfMRINames=`echo "${rfMRINames}" | sed 's/@/ /g'`

AreaIINames=`echo "${AreaIINames}" | sed 's/@/ /g'`

if [ ! -e ${ROILocation} ] ; then
  mkdir -p ${ROILocation}
fi

if [ ${GenerateGradients} = "YES" ] ; then
  #Generate axis one and axis two gradients from borders
  for Hemisphere in L R ; do
    if [ $Hemisphere = "L" ] ; then
      AreaBorder="${LeftAreaBorder}"
      HemiAreaName="L_${AreaName}"
      AxisOneParameters="${AxisOneLeftParameters}"
      AxisTwoParameters="${AxisTwoLeftParameters}"
      Structure="CORTEX_LEFT"
    elif [ $Hemisphere = "R" ] ; then
      AreaBorder="${RightAreaBorder}"
      HemiAreaName="R_${AreaName}"
      AxisOneParameters="${AxisOneRightParameters}"
      AxisTwoParameters="${AxisTwoRightParameters}"
      Structure="CORTEX_RIGHT"
    fi

    ${Caret7_Command} -cifti-separate ${StudyFolder}/${Subject}/${VAFolderName}/fsaverage_LR${LowResMesh}k/${Subject}.midthickness${RegSTRING}_va.${LowResMesh}k_fs_LR.dscalar.nii COLUMN -metric ${Structure} ${DownSampleFolder}/temp${Hemisphere}Area.func.gii
    ${Caret7_Command} -metric-dilate ${DownSampleFolder}/temp${Hemisphere}Area.func.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii 10 ${DownSampleFolder}/temp${Hemisphere}Area.func.gii -nearest 

    ${Caret7_Command} -border-to-rois ${DownSampleFolder}/${Subject}.${Hemisphere}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii ${AreaBorder} ${ROILocation}/${HemiAreaName}.func.gii -border ${HemiAreaName}


    ${Caret7_Command} -border-to-vertices ${DownSampleFolder}/${Subject}.${Hemisphere}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii ${GroupROILocation}/${Hemisphere}_${AxisOneBorder}.border ${ROILocation}/${Hemisphere}_${AxisOneBorder}.func.gii

    ${Caret7_Command} -metric-reduce ${ROILocation}/${Hemisphere}_${AxisOneBorder}.func.gii SUM ${ROILocation}/${Hemisphere}_${AxisOneBorder}_sum.func.gii
    ${Caret7_Command} -metric-reduce ${ROILocation}/${Hemisphere}_${AxisOneBorder}.func.gii INDEXMAX ${ROILocation}/${Hemisphere}_${AxisOneBorder}_max.func.gii
    ${Caret7_Command} -metric-math "(ROI < 2) * (ROI > 0) * Var" ${ROILocation}/${Hemisphere}_${AxisOneBorder}.func.gii -var Var ${ROILocation}/${Hemisphere}_${AxisOneBorder}_max.func.gii -var ROI ${ROILocation}/${Hemisphere}_${AxisOneBorder}_sum.func.gii

    ${Caret7_Command} -border-to-vertices ${DownSampleFolder}/${Subject}.${Hemisphere}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii ${GroupROILocation}/${Hemisphere}_${AxisTwoBorder}.border ${ROILocation}/${Hemisphere}_${AxisTwoBorder}.func.gii
  
    ${Caret7_Command} -metric-reduce ${ROILocation}/${Hemisphere}_${AxisTwoBorder}.func.gii SUM ${ROILocation}/${Hemisphere}_${AxisTwoBorder}_sum.func.gii
    ${Caret7_Command} -metric-reduce ${ROILocation}/${Hemisphere}_${AxisTwoBorder}.func.gii INDEXMAX ${ROILocation}/${Hemisphere}_${AxisTwoBorder}_max.func.gii
    ${Caret7_Command} -metric-math "(ROI < 2) * (ROI > 0) * Var" ${ROILocation}/${Hemisphere}_${AxisTwoBorder}.func.gii -var Var ${ROILocation}/${Hemisphere}_${AxisTwoBorder}_max.func.gii -var ROI ${ROILocation}/${Hemisphere}_${AxisTwoBorder}_sum.func.gii

    i=1
    AxisOneFormula="0"
    for AxisOneParameter in `echo ${AxisOneParameters} | sed 's/@/ /g' | cut -d "%" -f 1` ; do
      AxisOneFormula=`echo "${AxisOneFormula} + (((Var > (${i} - 1)) * (Var < (${i} + 1))) * ${AxisOneParameter})"`
      i=$((${i}+1))
    done
    ${Caret7_Command} -metric-math "${AxisOneFormula}" ${ROILocation}/${Hemisphere}_${AxisOneBorder}.func.gii -var Var ${ROILocation}/${Hemisphere}_${AxisOneBorder}.func.gii

    i=1
    AxisTwoFormula="0"
    for AxisTwoParameter in `echo ${AxisTwoParameters} | sed 's/@/ /g' | cut -d "%" -f 1` ; do
      AxisTwoFormula=`echo "${AxisTwoFormula} + (((Var > (${i} - 1)) * (Var < (${i} + 1))) * ${AxisTwoParameter})"`
      i=$((${i}+1))
    done

    ${Caret7_Command} -metric-math "${AxisTwoFormula}" ${ROILocation}/${Hemisphere}_${AxisTwoBorder}.func.gii -var Var ${ROILocation}/${Hemisphere}_${AxisTwoBorder}.func.gii

    ${Caret7_Command} -metric-math "(abs(VarI) + abs(VarII) + abs(VarIII)) > 0" ${ROILocation}/${HemiAreaName}.func.gii -var VarI ${ROILocation}/${HemiAreaName}.func.gii -var VarII ${ROILocation}/${Hemisphere}_${AxisOneBorder}.func.gii -var VarIII ${ROILocation}/${Hemisphere}_${AxisTwoBorder}.func.gii
    ${Caret7_Command} -metric-fill-holes ${DownSampleFolder}/${Subject}.${Hemisphere}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii ${ROILocation}/${HemiAreaName}.func.gii ${ROILocation}/${HemiAreaName}.func.gii

    ${Caret7_Command} -metric-dilate ${ROILocation}/${Hemisphere}_${AxisOneBorder}.func.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii ${DilationAmount} ${ROILocation}/${Hemisphere}_${AxisOneBorder}_dil.func.gii -linear -corrected-areas ${DownSampleFolder}/temp${Hemisphere}Area.func.gii
    ${Caret7_Command} -metric-smoothing ${DownSampleFolder}/${Subject}.${Hemisphere}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii ${ROILocation}/${Hemisphere}_${AxisOneBorder}_dil.func.gii `echo "${LinearGradientSmoothingFWHM} / (2 * sqrt(2 * l(2)))" | bc -l` ${ROILocation}/${Hemisphere}_${AxisOneBorder}_dil.func.gii -roi ${ROILocation}/${HemiAreaName}.func.gii -corrected-areas ${DownSampleFolder}/temp${Hemisphere}Area.func.gii

    AxisOneScaling=`echo ${AxisOneParameters} | cut -d "%" -f 2`
    ${Caret7_Command} -metric-math "${AxisOneScaling}" ${ROILocation}/${Hemisphere}_${AxisOneBorder}_dil.func.gii -var Var ${ROILocation}/${Hemisphere}_${AxisOneBorder}_dil.func.gii
    ${Caret7_Command} -metric-mask ${ROILocation}/${Hemisphere}_${AxisOneBorder}_dil.func.gii ${ROILocation}/${HemiAreaName}.func.gii ${ROILocation}/${Hemisphere}_${AxisOneBorder}_dil.func.gii
  
    ${Caret7_Command} -metric-dilate ${ROILocation}/${Hemisphere}_${AxisTwoBorder}.func.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii ${DilationAmount} ${ROILocation}/${Hemisphere}_${AxisTwoBorder}_dil.func.gii -linear -corrected-areas ${DownSampleFolder}/temp${Hemisphere}Area.func.gii
    ${Caret7_Command} -metric-smoothing ${DownSampleFolder}/${Subject}.${Hemisphere}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii ${ROILocation}/${Hemisphere}_${AxisTwoBorder}_dil.func.gii `echo "${LinearGradientSmoothingFWHM} / (2 * sqrt(2 * l(2)))" | bc -l` ${ROILocation}/${Hemisphere}_${AxisTwoBorder}_dil.func.gii -roi ${ROILocation}/${HemiAreaName}.func.gii -corrected-areas ${DownSampleFolder}/temp${Hemisphere}Area.func.gii

    AxisTwoScaling=`echo ${AxisTwoParameters} | cut -d "%" -f 2`
    ${Caret7_Command} -metric-math "${AxisTwoScaling}" ${ROILocation}/${Hemisphere}_${AxisTwoBorder}_dil.func.gii -var Var ${ROILocation}/${Hemisphere}_${AxisTwoBorder}_dil.func.gii
    ${Caret7_Command} -metric-mask ${ROILocation}/${Hemisphere}_${AxisTwoBorder}_dil.func.gii ${ROILocation}/${HemiAreaName}.func.gii ${ROILocation}/${Hemisphere}_${AxisTwoBorder}_dil.func.gii

    rm ${DownSampleFolder}/temp${Hemisphere}Area.func.gii
  done

  ${Caret7_Command} -cifti-create-dense-from-template "$HCPPIPEDIR"/global/templates/91282_Greyordinates/91282_Greyordinates.dscalar.nii ${ROILocation}/${AreaName}.dscalar.nii -metric CORTEX_LEFT ${ROILocation}/L_${AreaName}.func.gii -metric CORTEX_RIGHT ${ROILocation}/R_${AreaName}.func.gii
  ${Caret7_Command} -cifti-create-dense-from-template "$HCPPIPEDIR"/global/templates/91282_Greyordinates/91282_Greyordinates.dscalar.nii ${ROILocation}/${AxisOneBorder}_dil.dscalar.nii -metric CORTEX_LEFT ${ROILocation}/L_${AxisOneBorder}_dil.func.gii -metric CORTEX_RIGHT ${ROILocation}/R_${AxisOneBorder}_dil.func.gii
  ${Caret7_Command} -cifti-create-dense-from-template "$HCPPIPEDIR"/global/templates/91282_Greyordinates/91282_Greyordinates.dscalar.nii ${ROILocation}/${AxisTwoBorder}_dil.dscalar.nii -metric CORTEX_LEFT ${ROILocation}/L_${AxisTwoBorder}_dil.func.gii -metric CORTEX_RIGHT ${ROILocation}/R_${AxisTwoBorder}_dil.func.gii
  
  if [ ! "${AreaIINames}" = "NONE" ] ; then
    AreaIINamesMERGESTRING=""
    AreaNuisanceNames=""
    i=1
    for AreaIIName in ${AreaIINames} ; do
      for Hemisphere in L R ; do
        if [ $Hemisphere = "L" ] ; then
          HemiAreaIIName="L_${AreaIIName}"
          AreaBorder="${LeftAreaBorder}"
        elif [ $Hemisphere = "R" ] ; then
          HemiAreaIIName="R_${AreaIIName}"
          AreaBorder="${RightAreaBorder}"
        fi
        ${Caret7_Command} -border-to-rois ${DownSampleFolder}/${Subject}.${Hemisphere}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii ${AreaBorder} ${ROILocation}/${HemiAreaIIName}.func.gii -border ${HemiAreaIIName}   
      done 
      AreaNuisanceNames=`echo "${AreaNuisanceNames}${Subject}_${AreaIIName} "`
      ${Caret7_Command} -cifti-create-dense-from-template "$HCPPIPEDIR"/global/templates/91282_Greyordinates/91282_Greyordinates.dscalar.nii ${ROILocation}/${AreaIIName}.dscalar.nii -metric CORTEX_LEFT ${ROILocation}/L_${AreaIIName}.func.gii -metric CORTEX_RIGHT ${ROILocation}/R_${AreaIIName}.func.gii
      AreaIINamesMERGESTRING=`echo "${AreaIINamesMERGESTRING} -cifti ${ROILocation}/${AreaIIName}.dscalar.nii"` 
      i=$((${i}+1))
    done
    ${Caret7_Command} -cifti-merge ${ROILocation}/AreaMeans.dscalar.nii ${AreaIINamesMERGESTRING} 
    NumAreas="${i}"
  else 
    NumAreas="0"
  fi

  if [ ! "${NuisanceROIBorder}" = "NONE" ] ; then
    for Hemisphere in L R ; do
      if [ $Hemisphere = "L" ] ; then
        HemiAreaIIName="L_${AreaIIName}"
        AreaBorder="${ROILocation}/${Hemisphere}_${NuisanceROIBorder}.border"
      elif [ $Hemisphere = "R" ] ; then
        HemiAreaIIName="R_${AreaIIName}"
        AreaBorder="${ROILocation}/${Hemisphere}_${NuisanceROIBorder}.border"
      fi
      ${Caret7_Command} -border-to-rois ${DownSampleFolder}/${Subject}.${Hemisphere}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii ${AreaBorder} ${ROILocation}/${Hemisphere}_${NuisanceROIBorder}.func.gii   
    done
    NumROIs=`${Caret7_Command} -file-information ${ROILocation}/L_${NuisanceROIBorder}.func.gii -no-map-info -only-number-of-maps`
    ${Caret7_Command} -cifti-create-dense-from-template "$HCPPIPEDIR"/global/templates/91282_Greyordinates/91282_Greyordinates.dscalar.nii ${ROILocation}/${NuisanceROIBorder}.dscalar.nii -metric CORTEX_LEFT ${ROILocation}/L_${NuisanceROIBorder}.func.gii -metric CORTEX_RIGHT ${ROILocation}/R_${NuisanceROIBorder}.func.gii
    NuisanceROIs="${ROILocation}/${NuisanceROIBorder}.dscalar.nii"
    rm "${ROILocation}/L_${NuisanceROIBorder}.func.gii" "${ROILocation}/R_${NuisanceROIBorder}.func.gii"
    NuisanceNames=""
    i=1
    while [ ${i} -le ${NumROIs} ] ; do 
      NuisanceNames=`echo "${NuisanceNames}${Subject}_Nuisance_${i} "`
      i=$((${i}+1))
    done
  else
    NuisanceROIs="NONE"
  fi

fi

#ColumnNames="${Subject}_Lower-Upper ${Subject}_Left-Right ${Subject}_Horizontal-Vertical ${Subject}_45s ${Subject}_Foveal-Peripheral ${Subject}_Foveal-Peripheral2 ${Subject}_Foveal-Peripheral3 ${Subject}_V1 ${NuisanceNames} ${Subject}_Global ${AreaNuisanceNames}"
#ColumnNames="${Subject}_Lower-Upper ${Subject}_Left-Right ${Subject}_Horizontal-Vertical ${Subject}_45s ${Subject}_Foveal-Peripheral ${Subject}_Foveal-Peripheral3 ${Subject}_V1 ${NuisanceNames} ${Subject}_Global ${AreaNuisanceNames}"
ColumnNames="${Subject}_Lower-Upper ${Subject}_Left-Right ${Subject}_Horizontal-Vertical ${Subject}_45s ${Subject}_Foveal-Peripheral ${Subject}_Foveal-Peripheral2 ${Subject}_Foveal-Peripheral3 ${Subject}_V1 ${NuisanceNames} ${Subject}_Global ${AreaNuisanceNames}"
SetColumnNames=""
i=1
for ColumnName in ${ColumnNames} ; do
  SetColumnNames=`echo "${SetColumnNames}-map ${i} ${ColumnName} "` 
  i=$((${i}+1))
done
NumColumnNames="${i}"
NumPermanentColumnNames=$((${NumColumnNames}-${NumAreas}))

#Run functional connectivity from within ROI
#Find the biggest on functional connectivity for each brain vertex, map two axes coordinates to two find the biggest maps
#Generate Max Correlation Map (value of find the biggest correlation)

if [[ ! -e ${outputresults} || ${ReRun} = "YES" ]] ; then

inputdtseriestxt="${ResultLocation}/dtseries.txt"
inputvntxt="${ResultLocation}/vn_files.txt"

rm -f "$inputdtseriestxt" "$inputvntxt"

for rfMRIName in ${rfMRINames} ; do 
  echo "${AtlasFolder}/Results/${rfMRIName}/${rfMRIName}${ProcSTRING}.dtseries.nii" >> "${inputdtseriestxt}"
  echo "${AtlasFolder}/Results/${rfMRIName}/${rfMRIName}${ProcSTRING}_vn.dscalar.nii" >> "${inputvntxt}"
done

inputarea="${ROILocation}/${AreaName}.dscalar.nii"
if [ ! "${AreaIINames}" = "NONE" ] ; then
  inputareaII="${ROILocation}/AreaMeans.dscalar.nii"
  inputareaIISTRING="_AreaMeans"
else
  inputareaII="NONE"
  inputareaIISTRING=""
fi


TestSTRING=""

inputaxisone="${ROILocation}/${AxisOneBorder}_dil.dscalar.nii"
inputaxistwo="${ROILocation}/${AxisTwoBorder}_dil.dscalar.nii"
outputresults="${ResultLocation}/${OutrfMRIName}${ProcSTRING}${inputareaIISTRING}${TestSTRING}_resultsregression"
outputgradient="${ResultLocation}/${OutrfMRIName}${ProcSTRING}${inputareaIISTRING}${TestSTRING}_resultsregression_grad"
outputregressors="${ResultLocation}/${OutrfMRIName}${ProcSTRING}${inputareaIISTRING}${TestSTRING}_resultsregressors"
outputaxisonecorr="${ResultLocation}/${OutrfMRIName}${ProcSTRING}${inputareaIISTRING}${TestSTRING}_${AxisOneBorder}_resultscorr"
outputaxistwocorr="${ResultLocation}/${OutrfMRIName}${ProcSTRING}${inputareaIISTRING}${TestSTRING}_${AxisTwoBorder}_resultscorr"
Distortion="${StudyFolder}/${Subject}/${VAFolderName}/fsaverage_LR${LowResMesh}k/${Subject}.midthickness${RegSTRING}_va.${LowResMesh}k_fs_LR.dscalar.nii"

VectorNumbers="1 2 3 4 5"
NumVectors=`echo ${VectorNumbers} | wc -w`
EccentricityNumber="5"
DotAbsNumber="1"
CrossAbsNumber="0" #3 Doesn't work
NumAbsVectors=`echo ${DotAbsNumber} ${CrossAbsNumber} | wc -w`
VectorSmoothingSigma=$((${LinearGradientSmoothingFWHM}*2))

i=0
while [ ${i} -le ${numit} ] ; do
  File="${ResultLocation}/${i}.sh"
  echo "${Caret7_Command} -cifti-palette ${outputaxisonecorr}_${i}.dscalar.nii `echo ${AxisOnePalette} | cut -d \"@\" -f 1` ${outputaxisonecorr}_${i}.dscalar.nii `echo ${AxisOnePalette} | cut -d \"@\" -f 2 | sed 's/_/ /g'`" > ${File}
  echo "${Caret7_Command} -set-map-names ${outputaxisonecorr}_${i}.dscalar.nii -map 1 ${Subject}_${AxisOneBorder}_resultscorr_${i}" >> ${File}
  echo "${Caret7_Command} -cifti-math \"Var * ${AxisOneFactor}\" ${outputaxisonecorr}_${i}.dscalar.nii -var Var ${outputaxisonecorr}_${i}.dscalar.nii" >> ${File}
  echo "${Caret7_Command} -cifti-palette ${outputaxistwocorr}_${i}.dscalar.nii `echo ${AxisTwoPalette} | cut -d \"@\" -f 1` ${outputaxistwocorr}_${i}.dscalar.nii `echo ${AxisTwoPalette} | cut -d \"@\" -f 2 | sed 's/_/ /g'`" >> ${File}
  echo "${Caret7_Command} -set-map-names ${outputaxistwocorr}_${i}.dscalar.nii -map 1 ${Subject}_${AxisTwoBorder}_resultscorr_${i}" >> ${File}
  echo "${Caret7_Command} -cifti-math \"Var * ${AxisTwoFactor}\" ${outputaxistwocorr}_${i}.dscalar.nii -var Var ${outputaxistwocorr}_${i}.dscalar.nii" >> ${File}
  echo "${Caret7_Command} -cifti-math \"Var * (Var > 0.01) + ((Var < 0.01)*0.01)\" ${outputaxistwocorr}_${i}.dscalar.nii -var Var ${outputaxistwocorr}_${i}.dscalar.nii" >> ${File}
  echo "cp ${outputresults}_${i}.dscalar.nii ${outputresults}_${i}_gradvectowardDOT.dscalar.nii" >> ${File}
  echo "${Caret7_Command} -cifti-math \"var * 0\" ${outputresults}_${i}_gradvectowardDOT.dscalar.nii -var var ${outputresults}_${i}_gradvectowardDOT.dscalar.nii" >> ${File}
  echo "for Hemisphere in L R ; do" >> ${File}
  echo "  if [ "'${Hemisphere}'" = \"L\" ] ; then" >> ${File}
  echo "    Structure=\"CORTEX_LEFT\"" >> ${File}
  echo "  elif [ "'${Hemisphere}'" = \"R\" ] ; then" >> ${File}
  echo "    Structure=\"CORTEX_RIGHT\"" >> ${File}
  echo "  fi" >> ${File}
  echo "  ${Caret7_Command} -cifti-separate ${outputregressors}_${i}.dscalar.nii COLUMN -metric "'${Structure}'" ${outputregressors}_${i}_"'${Hemisphere}'".func.gii" >> ${File}
  echo "  ${Caret7_Command} -cifti-separate ${inputarea} COLUMN -metric "'${Structure}'" ${inputarea}_"'${Hemisphere}'".func.gii" >> ${File}
  echo "  ${Caret7_Command} -metric-math \"((Var - 1) * -1) * ROI\" ${inputarea}_inv_"'${Hemisphere}'".func.gii -var Var ${inputarea}_"'${Hemisphere}'".func.gii -var ROI ${DownSampleFolder}/${Subject}."'${Hemisphere}'".atlasroi.${LowResMesh}k_fs_LR.shape.gii" >> ${File}
  echo "  ${Caret7_Command} -cifti-separate ${StudyFolder}/${Subject}/${VAFolderName}/fsaverage_LR${LowResMesh}k/${Subject}.midthickness${RegSTRING}_va.${LowResMesh}k_fs_LR.dscalar.nii COLUMN -metric "'${Structure}'" ${DownSampleFolder}/temp"'${Hemisphere}'"Area.func.gii" >> ${File}
  echo "  ${Caret7_Command} -metric-dilate ${DownSampleFolder}/temp"'${Hemisphere}'"Area.func.gii ${DownSampleFolder}/${Subject}."'${Hemisphere}'".midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii 10 ${DownSampleFolder}/temp"'${Hemisphere}'"Area.func.gii -nearest" >> ${File}
  echo "  ${Caret7_Command} -metric-vector-toward-roi ${DownSampleFolder}/${Subject}."'${Hemisphere}'".midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii ${inputarea}_"'${Hemisphere}'".func.gii ${inputarea}_vector_"'${Hemisphere}'".func.gii" >> ${File}
  echo "  ${Caret7_Command} -metric-smoothing ${DownSampleFolder}/${Subject}."'${Hemisphere}'".midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii ${inputarea}_vector_"'${Hemisphere}'".func.gii ${VectorSmoothingSigma} ${inputarea}_vector_s${VectorSmoothingSigma}_"'${Hemisphere}'".func.gii -roi ${inputarea}_inv_"'${Hemisphere}'".func.gii -corrected-areas ${DownSampleFolder}/temp"'${Hemisphere}'"Area.func.gii" >> ${File}
  echo "  ${Caret7_Command} -cifti-separate ${outputresults}_${i}.dscalar.nii COLUMN -metric "'${Structure}'" ${outputresults}_${i}_"'${Hemisphere}'".func.gii" >> ${File}
  echo "  ${Caret7_Command} -surface-normals ${DownSampleFolder}/${Subject}."'${Hemisphere}'".midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii ${inputarea}_normals_"'${Hemisphere}'".func.gii" >> ${File}
  echo "  ${Caret7_Command} -metric-merge ${outputresults}_${i}_${EccentricityNumber}_"'${Hemisphere}'".func.gii -metric ${outputresults}_${i}_"'${Hemisphere}'".func.gii -column ${EccentricityNumber}" >> ${File}
  echo "  ${Caret7_Command} -metric-gradient ${DownSampleFolder}/${Subject}."'${Hemisphere}'".midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii ${outputresults}_${i}_${EccentricityNumber}_"'${Hemisphere}'".func.gii ${outputresults}_grad_${i}_${EccentricityNumber}_"'${Hemisphere}'".func.gii -presmooth ${GradientSmoothingSigma} -vectors ${outputresults}_gradvec_${i}_${EccentricityNumber}_"'${Hemisphere}'".func.gii -corrected-areas ${DownSampleFolder}/temp"'${Hemisphere}'"Area.func.gii" >> ${File}
  echo "  ${Caret7_Command} -metric-smoothing ${DownSampleFolder}/${Subject}."'${Hemisphere}'".midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii ${outputresults}_gradvec_${i}_${EccentricityNumber}_"'${Hemisphere}'".func.gii ${VectorSmoothingSigma} ${outputresults}_gradvec_${i}_${EccentricityNumber}_s${VectorSmoothingSigma}_"'${Hemisphere}'".func.gii -corrected-areas ${DownSampleFolder}/temp"'${Hemisphere}'"Area.func.gii" >> ${File}
  echo "  Names="'""'"" >> ${File}
  echo "  MetricMergeSTRING="'""'"" >> ${File}
  echo "  n=1" >> ${File}
  echo "  for i in ${VectorNumbers} ; do" >> ${File} 
  echo "    Name=\`echo ${ColumnNames} | cut -d \" \" -f "'${i}'"\`" >> ${File} 
  echo "    Names=\`echo \""'${Names}'" "'${Name}'" \"\`" >> ${File}
  echo "    MetricMergeSTRING=\`echo \""'${MetricMergeSTRING}'" -metric ${outputresults}_${i}_"'${Hemisphere}'".func.gii -column "'${i}'" \"\`" >> ${File}
  echo "    n="'$((${n}+1))'"" >> ${File}
  echo "  done" >> ${File}
  echo "  DotAbsNumber=0" >> ${File}
  echo "  CrossAbsNumber=0" >> ${File}  
  echo "  for i in ${DotAbsNumber} ${CrossAbsNumber} ; do" >> ${File}
  echo "    if [ "'${i}'" -gt 0 ] ; then " >> ${File}
  echo "      Name=\`echo ${ColumnNames} | cut -d \" \" -f "'${i}'"\`" >> ${File} 
  echo "      Names=\`echo \""'${Names}'" "'${Name}'"_abs \"\`" >> ${File}
  echo "      MetricMergeSTRING=\`echo \""'${MetricMergeSTRING}'" -metric ${outputresults}_${i}_"'${Hemisphere}'".func.gii -column "'${i}'" \"\`" >> ${File}
  echo "      if [ "'${i}'" = ${DotAbsNumber} ] ; then" >> ${File} 
  echo "        DotAbsNumber="'${n}'"" >> ${File} 
  echo "      fi" >> ${File}
  echo "      if [ "'${i}'" = ${CrossAbsNumber} ] ; then" >> ${File} 
  echo "        CrossAbsNumber="'${n}'"" >> ${File} 
  echo "      fi" >> ${File}
  echo "      n="'$((${n}+1))'"" >> ${File}
  echo "    fi" >> ${File}
  echo "  done" >> ${File}
  echo "  ${Caret7_Command} -metric-merge ${outputresults}_${i}_"'${Hemisphere}'".func.gii "'${MetricMergeSTRING}'"" >> ${File}
  echo "  VectorNumbers=\"${VectorNumbers} "'${DotAbsNumber}'" "'${CrossAbsNumber}'"\"" >> ${File}
  echo "  tDOTMetricMergeSTRING="'""'"" >> ${File}
  echo "  tCROSSMetricMergeSTRING="'""'"" >> ${File}
  echo "  vDOTMetricMergeSTRING="'""'"" >> ${File}
  echo "  vCROSSMetricMergeSTRING="'""'"" >> ${File}
  echo "  CIFTIMergeSTRING="'""'"" >> ${File}
  echo "  rmSTRING="'""'"" >> ${File} 
  echo "  tDOTNameSTRING="'""'"" >> ${File} 
  echo "  tCROSSNameSTRING="'""'"" >> ${File} 
  echo "  vDOTNameSTRING="'""'"" >> ${File} 
  echo "  vCROSSNameSTRING="'""'"" >> ${File} 
  echo "  for i in "'${VectorNumbers}'" ; do" >> ${File} 
  echo "    if [ "'${i}'" -gt 0 ] ; then " >> ${File}
  echo "      Name=\`echo "'${Names}'" | cut -d \" \" -f "'${i}'"\`" >> ${File}  
  echo "      ${Caret7_Command} -metric-merge ${outputresults}_${i}_"'${i}'"_"'${Hemisphere}'".func.gii -metric ${outputresults}_${i}_"'${Hemisphere}'".func.gii -column "'${i}'"" >> ${File}
  echo "      if [ "'${i}'" = "'${DotAbsNumber}'" ] ; then" >> ${File} 
  echo "        ${Caret7_Command} -metric-math \"abs(Var)\" ${outputresults}_${i}_"'${i}'"_"'${Hemisphere}'".func.gii -var Var ${outputresults}_${i}_"'${i}'"_"'${Hemisphere}'".func.gii" >> ${File} 
  echo "      fi" >> ${File}
  echo "      if [ "'${i}'" = "'${CrossAbsNumber}'" ] ; then" >> ${File} 
  echo "        ${Caret7_Command} -metric-math \"abs(Var)\" ${outputresults}_${i}_"'${i}'"_"'${Hemisphere}'".func.gii -var Var ${outputresults}_${i}_"'${i}'"_"'${Hemisphere}'".func.gii" >> ${File} 
  echo "      fi" >> ${File}
  echo "      ${Caret7_Command} -metric-gradient ${DownSampleFolder}/${Subject}."'${Hemisphere}'".midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii ${outputresults}_${i}_"'${i}'"_"'${Hemisphere}'".func.gii ${outputresults}_grad_${i}_"'${i}'"_"'${Hemisphere}'".func.gii -presmooth ${GradientSmoothingSigma} -vectors ${outputresults}_gradvec_${i}_"'${i}'"_"'${Hemisphere}'".func.gii -corrected-areas ${DownSampleFolder}/temp"'${Hemisphere}'"Area.func.gii" >> ${File}
  echo "      ${Caret7_Command} -metric-vector-operation ${outputresults}_gradvec_${i}_"'${i}'"_"'${Hemisphere}'".func.gii ${inputarea}_vector_s${VectorSmoothingSigma}_"'${Hemisphere}'".func.gii DOT ${outputresults}_gradvectowardDOT_${i}_"'${i}'"_"'${Hemisphere}'".func.gii -normalize-b" >> ${File}
  echo "      ${Caret7_Command} -metric-vector-operation ${outputresults}_gradvec_${i}_"'${i}'"_"'${Hemisphere}'".func.gii ${inputarea}_vector_s${VectorSmoothingSigma}_"'${Hemisphere}'".func.gii CROSS ${outputresults}_gradvectowardCROSS_${i}_"'${i}'"_"'${Hemisphere}'".func.gii -normalize-b" >> ${File}
  echo "      ${Caret7_Command} -metric-vector-operation ${inputarea}_normals_"'${Hemisphere}'".func.gii ${outputresults}_gradvectowardCROSS_${i}_"'${i}'"_"'${Hemisphere}'".func.gii DOT ${outputresults}_gradvectowardCROSS_${i}_"'${i}'"_"'${Hemisphere}'".func.gii -normalize-a" >> ${File}
  echo "      ${Caret7_Command} -metric-mask ${outputresults}_gradvectowardDOT_${i}_"'${i}'"_"'${Hemisphere}'".func.gii ${inputarea}_inv_"'${Hemisphere}'".func.gii ${outputresults}_gradvectowardDOT_${i}_"'${i}'"_"'${Hemisphere}'".func.gii" >> ${File}
  echo "      ${Caret7_Command} -metric-mask ${outputresults}_gradvectowardCROSS_${i}_"'${i}'"_"'${Hemisphere}'".func.gii ${inputarea}_inv_"'${Hemisphere}'".func.gii ${outputresults}_gradvectowardCROSS_${i}_"'${i}'"_"'${Hemisphere}'".func.gii" >> ${File}
  echo "      ${Caret7_Command} -metric-merge ${outputresults}_${i}_"'${i}'"_"'${Hemisphere}'".func.gii -metric ${outputresults}_${i}_"'${Hemisphere}'".func.gii -column "'${i}'"" >> ${File}
  echo "      ${Caret7_Command} -metric-gradient ${DownSampleFolder}/${Subject}."'${Hemisphere}'".midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii ${outputresults}_${i}_"'${i}'"_"'${Hemisphere}'".func.gii ${outputresults}_grad_${i}_"'${i}'"_"'${Hemisphere}'".func.gii -presmooth ${GradientSmoothingSigma} -vectors ${outputresults}_gradvec_${i}_"'${i}'"_"'${Hemisphere}'".func.gii -corrected-areas ${DownSampleFolder}/temp"'${Hemisphere}'"Area.func.gii" >> ${File}
  echo "      ${Caret7_Command} -metric-vector-operation ${outputresults}_gradvec_${i}_"'${i}'"_"'${Hemisphere}'".func.gii ${outputresults}_gradvec_${i}_${EccentricityNumber}_s${VectorSmoothingSigma}_"'${Hemisphere}'".func.gii DOT ${outputresults}_gradvecvertexwiseDOT_${i}_"'${i}'"_"'${Hemisphere}'".func.gii -normalize-b" >> ${File}
  echo "      ${Caret7_Command} -metric-vector-operation ${outputresults}_gradvec_${i}_"'${i}'"_"'${Hemisphere}'".func.gii ${outputresults}_gradvec_${i}_${EccentricityNumber}_s${VectorSmoothingSigma}_"'${Hemisphere}'".func.gii CROSS ${outputresults}_gradvecvertexwiseCROSS_${i}_"'${i}'"_"'${Hemisphere}'".func.gii -normalize-b" >> ${File}
  echo "      ${Caret7_Command} -metric-vector-operation ${inputarea}_normals_"'${Hemisphere}'".func.gii ${outputresults}_gradvecvertexwiseCROSS_${i}_"'${i}'"_"'${Hemisphere}'".func.gii DOT ${outputresults}_gradvecvertexwiseCROSS_${i}_"'${i}'"_"'${Hemisphere}'".func.gii -normalize-a" >> ${File}
  echo "      if [ "'${Hemisphere}'" = \"R\" ] ; then" >> ${File}  
  echo "        ${Caret7_Command} -metric-math \"Var * -1\" ${outputresults}_gradvectowardCROSS_${i}_"'${i}'"_"'${Hemisphere}'".func.gii -var Var ${outputresults}_gradvectowardCROSS_${i}_"'${i}'"_"'${Hemisphere}'".func.gii" >> ${File}
  echo "        if [[ "'${i}'" = \"1\" || "'${i}'" = \"3\" ]] ; then" >> ${File}
  echo "          ${Caret7_Command} -metric-math \"Var * -1\" ${outputresults}_gradvecvertexwiseCROSS_${i}_"'${i}'"_"'${Hemisphere}'".func.gii -var Var ${outputresults}_gradvecvertexwiseCROSS_${i}_"'${i}'"_"'${Hemisphere}'".func.gii" >> ${File}
  echo "        fi" >> ${File}
  echo "      fi" >> ${File}
  echo "      rm ${outputresults}_${i}_"'${i}'"_"'${Hemisphere}'".func.gii ${outputresults}_grad_${i}_"'${i}'"_"'${Hemisphere}'".func.gii ${outputresults}_gradvec_${i}_"'${i}'"_"'${Hemisphere}'".func.gii" >> ${File}  
  echo "      tDOTMetricMergeSTRING=\`echo \""'${tDOTMetricMergeSTRING}'" -metric ${outputresults}_gradvectowardDOT_${i}_"'${i}'"_"'${Hemisphere}'".func.gii \"\`" >> ${File}
  echo "      tCROSSMetricMergeSTRING=\`echo \""'${tCROSSMetricMergeSTRING}'" -metric ${outputresults}_gradvectowardCROSS_${i}_"'${i}'"_"'${Hemisphere}'".func.gii \"\`" >> ${File}
  echo "      vDOTMetricMergeSTRING=\`echo \""'${vDOTMetricMergeSTRING}'" -metric ${outputresults}_gradvecvertexwiseDOT_${i}_"'${i}'"_"'${Hemisphere}'".func.gii \"\`" >> ${File}
  echo "      vCROSSMetricMergeSTRING=\`echo \""'${vCROSSMetricMergeSTRING}'" -metric ${outputresults}_gradvecvertexwiseCROSS_${i}_"'${i}'"_"'${Hemisphere}'".func.gii \"\`" >> ${File}
  echo "      CIFTIMergeSTRING=\`echo \""'${CIFTIMergeSTRING}'" -cifti ${outputresults}_${i}_gradvectowardDOT.dscalar.nii -column 1 \"\`" >> ${File}
  echo "      rmSTRING=\`echo \""'${rmSTRING}'"${outputresults}_gradvectowardDOT_${i}_"'${i}'"_"'${Hemisphere}'".func.gii ${outputresults}_gradvectowardCROSS_${i}_"'${i}'"_"'${Hemisphere}'".func.gii ${outputresults}_gradvecvertexwiseDOT_${i}_"'${i}'"_"'${Hemisphere}'".func.gii ${outputresults}_gradvecvertexwiseCROSS_${i}_"'${i}'"_"'${Hemisphere}'".func.gii \"\`" >> ${File}
  echo "      tDOTName=\""'${Name}'"_gradvectowardDOT\"" >> ${File} 
  echo "      tCROSSName=\""'${Name}'"_gradvectowardCROSS\"" >> ${File} 
  echo "      vDOTName=\""'${Name}'"_gradvecvertexwiseDOT\"" >> ${File} 
  echo "      vCROSSName=\""'${Name}'"_gradvecvertexwiseCROSS\"" >> ${File} 
  echo "      tDOTNameSTRING=\`echo \""'${tDOTNameSTRING}'" -map "'${i}'" "'${tDOTName}' "\"\`" >> ${File}
  echo "      tCROSSNameSTRING=\`echo \""'${tCROSSNameSTRING}'" -map "'${i}'" "'${tCROSSName}' "\"\`" >> ${File}
  echo "      vDOTNameSTRING=\`echo \""'${vDOTNameSTRING}'" -map "'${i}'" "'${vDOTName}' "\"\`" >> ${File}
  echo "      vCROSSNameSTRING=\`echo \""'${vCROSSNameSTRING}'" -map "'${i}'" "'${vCROSSName}' "\"\`" >> ${File}
  echo "    fi" >> ${File}
  echo "  done" >> ${File}
  echo "  ${Caret7_Command} -metric-merge ${outputresults}_${i}_gradvectowardDOT_"'${Hemisphere}'".func.gii "'${tDOTMetricMergeSTRING}'"" >> ${File}
  echo "  ${Caret7_Command} -metric-merge ${outputresults}_${i}_gradvectowardCROSS_"'${Hemisphere}'".func.gii "'${tCROSSMetricMergeSTRING}'"" >> ${File}
  echo "  ${Caret7_Command} -metric-merge ${outputresults}_${i}_gradvecvertexwiseDOT_"'${Hemisphere}'".func.gii "'${vDOTMetricMergeSTRING}'"" >> ${File}
  echo "  ${Caret7_Command} -metric-merge ${outputresults}_${i}_gradvecvertexwiseCROSS_"'${Hemisphere}'".func.gii "'${vCROSSMetricMergeSTRING}'"" >> ${File}
  echo "  if [ "'${Hemisphere}'" = \"L\" ] ; then" >> ${File}  
  echo "    ${Caret7_Command} -cifti-merge ${outputresults}_${i}_gradvectowardDOT.dscalar.nii "'${CIFTIMergeSTRING}'"" >> ${File}
  echo "    ${Caret7_Command} -cifti-merge ${outputresults}_${i}_gradvectowardCROSS.dscalar.nii "'${CIFTIMergeSTRING}'"" >> ${File}
  echo "    ${Caret7_Command} -cifti-merge ${outputresults}_${i}_gradvecvertexwiseDOT.dscalar.nii "'${CIFTIMergeSTRING}'"" >> ${File}
  echo "    ${Caret7_Command} -cifti-merge ${outputresults}_${i}_gradvecvertexwiseCROSS.dscalar.nii "'${CIFTIMergeSTRING}'"" >> ${File}
  echo "  fi" >> ${File}
  echo "  ${Caret7_Command} -cifti-replace-structure ${outputresults}_${i}_gradvectowardDOT.dscalar.nii COLUMN -metric "'${Structure}'" ${outputresults}_${i}_gradvectowardDOT_"'${Hemisphere}'".func.gii" >> ${File}
  echo "  ${Caret7_Command} -cifti-replace-structure ${outputresults}_${i}_gradvectowardCROSS.dscalar.nii COLUMN -metric "'${Structure}'" ${outputresults}_${i}_gradvectowardCROSS_"'${Hemisphere}'".func.gii" >> ${File}
  echo "  ${Caret7_Command} -cifti-replace-structure ${outputresults}_${i}_gradvecvertexwiseDOT.dscalar.nii COLUMN -metric "'${Structure}'" ${outputresults}_${i}_gradvecvertexwiseDOT_"'${Hemisphere}'".func.gii" >> ${File}
  echo "  ${Caret7_Command} -cifti-replace-structure ${outputresults}_${i}_gradvecvertexwiseCROSS.dscalar.nii COLUMN -metric "'${Structure}'" ${outputresults}_${i}_gradvecvertexwiseCROSS_"'${Hemisphere}'".func.gii" >> ${File}
  echo "  rm ${outputresults}_${i}_"'${Hemisphere}'".func.gii ${inputarea}_"'${Hemisphere}'".func.gii ${inputarea}_inv_"'${Hemisphere}'".func.gii ${inputarea}_normals_"'${Hemisphere}'".func.gii ${outputregressors}_${i}_"'${Hemisphere}'".func.gii ${inputarea}_vector_"'${Hemisphere}'".func.gii ${inputarea}_vector_s${VectorSmoothingSigma}_"'${Hemisphere}'".func.gii ${outputresults}_gradvec_${i}_${EccentricityNumber}_s${VectorSmoothingSigma}_"'${Hemisphere}'".func.gii "'${rmSTRING}'" ${outputresults}_${i}_gradvectowardDOT_"'${Hemisphere}'".func.gii ${outputresults}_${i}_gradvectowardCROSS_"'${Hemisphere}'".func.gii ${outputresults}_${i}_gradvecvertexwiseDOT_"'${Hemisphere}'".func.gii ${outputresults}_${i}_gradvecvertexwiseCROSS_"'${Hemisphere}'".func.gii" >> ${File}  
  echo "done" >> ${File}
  echo "${Caret7_Command} -cifti-gradient ${outputresults}_${i}.dscalar.nii COLUMN ${outputgradient}_${i}.dscalar.nii -left-surface ${DownSampleFolder}/${Subject}.L.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii -left-corrected-areas ${DownSampleFolder}/tempLArea.func.gii -right-surface ${DownSampleFolder}/${Subject}.R.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii -right-corrected-areas ${DownSampleFolder}/tempRArea.func.gii -surface-presmooth 1 -volume-presmooth 1" >> ${File}
  #echo "${Caret7_Command} -cifti-palette ${outputgradient}_${i}.dscalar.nii MODE_AUTO_SCALE_PERCENTAGE ${outputgradient}_${i}.dscalar.nii -pos-percent 0 100 -interpolate true -disp-pos true -disp-neg false -disp-zero false -palette-name videen_style" >> ${File}
  #echo "${Caret7_Command} -cifti-palette ${outputresults}_${i}_gradvectowardDOT.dscalar.nii MODE_USER_SCALE ${outputresults}_${i}_gradvectowardDOT.dscalar.nii -pos-user 0 0.03 -neg-user 0 -0.03 -interpolate true -disp-pos true -disp-neg true -disp-zero false -palette-name ROY-BIG-BL" >> ${File}
  #echo "${Caret7_Command} -cifti-palette ${outputresults}_${i}_gradvectowardCROSS.dscalar.nii MODE_USER_SCALE ${outputresults}_${i}_gradvectowardCROSS.dscalar.nii -pos-user 0 0.03 -neg-user 0 -0.03 -interpolate true -disp-pos true -disp-neg true -disp-zero false -palette-name ROY-BIG-BL" >> ${File}
  #echo "${Caret7_Command} -cifti-palette ${outputresults}_${i}_gradvecvertexwiseDOT.dscalar.nii MODE_USER_SCALE ${outputresults}_${i}_gradvecvertexwiseDOT.dscalar.nii -pos-user 0 0.03 -neg-user 0 -0.03 -interpolate true -disp-pos true -disp-neg true -disp-zero false -palette-name ROY-BIG-BL" >> ${File}
  #echo "${Caret7_Command} -cifti-palette ${outputresults}_${i}_gradvecvertexwiseCROSS.dscalar.nii MODE_USER_SCALE ${outputresults}_${i}_gradvecvertexwiseCROSS.dscalar.nii -pos-user 0 0.03 -neg-user 0 -0.03 -interpolate true -disp-pos true -disp-neg true -disp-zero false -palette-name ROY-BIG-BL" >> ${File}
  echo "" >> ${File}
  echo "if [ ${i} -gt 0 ] ; then" >> ${File}
  echo "MapNames=\"\"" >> ${File}
  echo "  i=1" >> ${File}
  echo "  while [ "'${i}'" -le ${NumPermanentColumnNames} ] ; do" >> ${File}
  echo "    MapName=\`echo ${ColumnNames} | cut -d \" \" -f "'${i}'"\`" >> ${File}
  echo "    MapNames=\`echo \""'${MapNames}'" -map "'${i}'" "'${MapName}'"\"\`" >> ${File}
  echo "    i="'$((${i}+1))'"" >> ${File}
  echo "  done" >> ${File}
  echo "  i=1" >> ${File}
  echo "  while [ "'${i}'" -le ${i} ] ; do" >> ${File}
  echo "    MapNames=\`echo \""'${MapNames}'" -map \$((${NumPermanentColumnNames}+"'${i}'")) ${Subject}_ICA_"'${i}'"\"\`" >> ${File}
  echo "    i="'$((${i}+1))'"" >> ${File}
  echo "  done" >> ${File}
  echo "else" >> ${File}
  echo "  MapNames=\"${SetColumnNames}\"" >> ${File}
  echo "fi" >> ${File}
  echo "${Caret7_Command} -set-map-names ${outputregressors}_${i}.dscalar.nii "'${MapNames}'"" >> ${File}
  echo "${Caret7_Command} -set-map-names ${outputresults}_${i}.dscalar.nii "'${MapNames}'"" >> ${File}
  echo "${Caret7_Command} -set-map-names ${outputgradient}_${i}.dscalar.nii "'${MapNames}'"" >> ${File}
  echo "${Caret7_Command} -set-map-names ${outputresults}_${i}_gradvectowardDOT.dscalar.nii "'${tDOTNameSTRING}'"" >> ${File} 
  echo "${Caret7_Command} -set-map-names ${outputresults}_${i}_gradvectowardCROSS.dscalar.nii "'${tCROSSNameSTRING}'"" >> ${File} 
  echo "${Caret7_Command} -set-map-names ${outputresults}_${i}_gradvecvertexwiseDOT.dscalar.nii "'${vDOTNameSTRING}'"" >> ${File} 
  echo "${Caret7_Command} -set-map-names ${outputresults}_${i}_gradvecvertexwiseCROSS.dscalar.nii "'${vCROSSNameSTRING}'"" >> ${File} 
  echo "for Hemisphere in L R ; do" >> ${File}
  echo "  rm ${DownSampleFolder}/temp"'${Hemisphere}'"Area.func.gii" >> ${File}
  echo "done" >> ${File}
  chmod +x ${File}
  i=$((${i}+1))
done
fi

#if [ ! ${BC} = "NONE" ] ; then
#  inputdtseriesBC="${AtlasFolder}/Results/${OutrfMRIName}/${OutrfMRIName}${ProcSTRING}_BC"
#  BC=`echo ${BC} | sed 's/@/ /g'`
#  ReferenceFile=`echo ${BC} | cut -d " " -f 1`
#  VNOneFile=`echo ${BC} | cut -d " " -f 2`
#  VNTwoFile=`echo ${BC} | cut -d " " -f 3`
#  if [ ! -z ${VNTwoFile} ] ; then
#    ${Caret7_Command} -cifti-math "Reference / (VNOne * VNTwo)" ${inputdtseriesBC}_norm.dscalar.nii -var Reference ${ReferenceFile} -var VNOne ${VNOneFile} -var VNTwo ${VNTwoFile}
#  else
#    ${Caret7_Command} -cifti-math "Reference / VNOne" ${inputdtseriesBC}_norm.dscalar.nii -var Reference ${ReferenceFile} -var VNOne ${VNOneFile}
#  fi
#  BC="${inputdtseriesBC}_norm.dscalar.nii"
#fi

if [ ! ${SaveDCONN} = "NO" ] ; then
  ${Caret7_Command} -cifti-merge ${ResultLocation}/tmp.dtseries.nii -cifti ${ResultsFolder}/${OutrfMRIName}${ProcSTRING}.dtseries.nii -column 1
  ${Caret7_Command} -cifti-correlation ${ResultLocation}/tmp.dtseries.nii ${ResultLocation}/${OutrfMRIName}${ProcSTRING}${inputareaIISTRING}${TestSTRING}.dconn.nii -roi-override -cifti-roi ${inputarea}
  ${Caret7_Command} -cifti-transpose ${ResultLocation}/${OutrfMRIName}${ProcSTRING}${inputareaIISTRING}${TestSTRING}.dconn.nii ${ResultLocation}/${OutrfMRIName}${ProcSTRING}${inputareaIISTRING}${TestSTRING}.dconn.nii
  rm ${ResultLocation}/tmp.dtseries.nii
  DCONNFile="${ResultLocation}/${OutrfMRIName}${ProcSTRING}${inputareaIISTRING}${TestSTRING}.dconn.nii"
else
  DCONNFile="NONE"
fi

echo "running matlab:
addpath('$HCPPIPEDIR/ArealClassifier/scripts');
TopographicRegression('${inputdtseriestxt}', '${inputvntxt}', '${inputarea}', '${inputareaII}', '${inputaxisone}', '${inputaxistwo}', '${outputresults}', '${outputregressors}', '${Caret7_Command}', '${outputaxisonecorr}', '${outputaxistwocorr}',${numit},'${ResultLocation}', '${Distortion}', 'NOTNONE', '${NuisanceROIs}', '${DCONNFile}');"

matlab -nodisplay -nosplash <<<"
addpath('$HCPPIPEDIR/ArealClassifier/scripts');
TopographicRegression('${inputdtseriestxt}', '${inputvntxt}', '${inputarea}', '${inputareaII}', '${inputaxisone}', '${inputaxistwo}', '${outputresults}', '${outputregressors}', '${Caret7_Command}', '${outputaxisonecorr}', '${outputaxistwocorr}',${numit},'${ResultLocation}', '${Distortion}', 'NOTNONE', '${NuisanceROIs}', '${DCONNFile}');"
echo

rm -f "${inputdtseriestxt}" "${inputvntxt}"

#exit

i=0
while [ ${i} -le ${numit} ] ; do
  File="${ResultLocation}/${i}.sh"
  if [ -e ${File} ] ; then
    rm ${File}
  fi
  i=$((${i}+1))
done


