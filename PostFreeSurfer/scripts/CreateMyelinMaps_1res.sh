#!/bin/bash
set -e

# ------------------------------------------------------------------------------
#  Verify required environment variables are set
# ------------------------------------------------------------------------------

if [ -z "${CARET7DIR}" ]; then
	echo "$(basename ${0}): ABORTING: CARET7DIR environment variable must be set"
	exit 1
else
	echo "$(basename ${0}): CARET7DIR: ${CARET7DIR}"
fi

if [ -z "${HCPPIPEDIR}" ]; then
	echo "$(basename ${0}): ABORTING: HCPPIPEDIR environment variable must be set"
	exit 1
else
	echo "$(basename ${0}): HCPPIPEDIR: ${HCPPIPEDIR}"
fi

source ${HCPPIPEDIR}/global/scripts/log.shlib # Logging related functions

log_Msg "START: CreateMyelinMaps_1res"

StudyFolder="${1}"
Subject="${2}"
AtlasSpaceFolder="${3}"
NativeFolder="${4}"
T1wFolder="${5}"
HighResMesh="${6}"
LowResMeshes="${7}"
OrginalT1wImage="${8}"
OrginalT2wImage="${9}"
T1wImageBrainMask="${10}"
InitialT1wTransform="${11}"
dcT1wTransform="${12}"
InitialT2wTransform="${13}"
dcT2wTransform="${14}"
FinalT2wTransform="${15}"
AtlasTransform="${16}"
BiasField="${17}"
OutputT1wImage="${18}"
OutputT1wImageRestore="${19}"
OutputT1wImageRestoreBrain="${20}"
OutputMNIT1wImage="${21}"
OutputMNIT1wImageRestore="${22}"
OutputMNIT1wImageRestoreBrain="${23}"
OutputT2wImage="${24}"
OutputT2wImageRestore="${25}"
OutputT2wImageRestoreBrain="${26}"
OutputMNIT2wImage="${27}"
OutputMNIT2wImageRestore="${28}"
OutputMNIT2wImageRestoreBrain="${29}"
OutputOrigT1wToT1w="${30}"
OutputOrigT1wToStandard="${31}"
OutputOrigT2wToT1w="${32}"
OutputOrigT2wToStandard="${33}"
BiasFieldOutput="${34}"
T1wMNIImageBrainMask="${35}"
Jacobian="${36}"
ReferenceMyelinMaps="${37}"
CorrectionSigma="${38}"
RegName="${39}"

log_Msg "CreateMyelinMaps_1res.sh: RegName: ${RegName}"

verbose_echo " "
verbose_red_echo " ===> Running CreateMyelinMaps_1res"
verbose_echo " "

# -- check for presence of T2w image
if [ `${FSLDIR}/bin/imtest ${OrginalT2wImage}` -eq 0 ]; then
  T2wPresent="NO"
else
  T2wPresent="YES"
fi

LeftGreyRibbonValue="3"
RightGreyRibbonValue="42"
MyelinMappingFWHM="5"
SurfaceSmoothingFWHM="4"
MyelinMappingSigma=`echo "$MyelinMappingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`
SurfaceSmoothingSigma=`echo "$SurfaceSmoothingFWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l`

LowResMeshes=`echo ${LowResMeshes} | sed 's/@/ /g'`

STRINGList="corrThickness@shape"
if [ "${T2wPresent}" = "YES" ] ; then
  STRINGList+=" MyelinMap@func SmoothedMyelinMap@func MyelinMap_BC@func SmoothedMyelinMap_BC@func"
fi

for Hemisphere in L R ; do
  if [ $Hemisphere = "L" ] ; then
    Structure="CORTEX_LEFT"
    ribbon="$LeftGreyRibbonValue"
  elif [ $Hemisphere = "R" ] ; then
    Structure="CORTEX_RIGHT"
    ribbon="$RightGreyRibbonValue"
  fi
  if [ ${RegName} = "MSMSulc" ] ; then
    RegSphere="${AtlasSpaceFolder}/${NativeFolder}/${Subject}.${Hemisphere}.sphere.MSMSulc.native.surf.gii"
  else
    RegSphere="${AtlasSpaceFolder}/${NativeFolder}/${Subject}.${Hemisphere}.sphere.reg.reg_LR.native.surf.gii"
  fi

  for STRING in $STRINGList ; do
    Map=`echo $STRING | cut -d "@" -f 1`
    Ext=`echo $STRING | cut -d "@" -f 2`

    for LowResMesh in ${LowResMeshes} ; do
      ${CARET7DIR}/wb_command -metric-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Map".native."$Ext".gii ${RegSphere} "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere".sphere."$LowResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere"."$Map"."$LowResMesh"k_fs_LR."$Ext".gii -area-surfs "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii -current-roi "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".roi.native.shape.gii
      ${CARET7DIR}/wb_command -metric-mask "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere"."$Map"."$LowResMesh"k_fs_LR."$Ext".gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere".atlasroi."$LowResMesh"k_fs_LR.shape.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere"."$Map"."$LowResMesh"k_fs_LR."$Ext".gii
    done
  done
done

STRINGII=""
for LowResMesh in ${LowResMeshes} ; do
  STRINGII=`echo "${STRINGII}${AtlasSpaceFolder}/fsaverage_LR${LowResMesh}k@${LowResMesh}k_fs_LR@atlasroi "`
done

#Create CIFTI Files
for STRING in ${STRINGII} ; do
  Folder=`echo $STRING | cut -d "@" -f 1`
  Mesh=`echo $STRING | cut -d "@" -f 2`
  ROI=`echo $STRING | cut -d "@" -f 3`

  for STRINGII in $STRINGList ; do
    Map=`echo $STRINGII | cut -d "@" -f 1`
    Ext=`echo $STRINGII | cut -d "@" -f 2`
    ${CARET7DIR}/wb_command -cifti-create-dense-scalar "$Folder"/"$Subject".${Map}."$Mesh".dscalar.nii -left-metric "$Folder"/"$Subject".L.${Map}."$Mesh"."$Ext".gii -roi-left "$Folder"/"$Subject".L."$ROI"."$Mesh".shape.gii -right-metric "$Folder"/"$Subject".R.${Map}."$Mesh"."$Ext".gii -roi-right "$Folder"/"$Subject".R."$ROI"."$Mesh".shape.gii
    ${CARET7DIR}/wb_command -set-map-names "$Folder"/"$Subject".${Map}."$Mesh".dscalar.nii -map 1 "${Subject}_${Map}"
    ${CARET7DIR}/wb_command -cifti-palette "$Folder"/"$Subject".${Map}."$Mesh".dscalar.nii MODE_AUTO_SCALE_PERCENTAGE "$Folder"/"$Subject".${Map}."$Mesh".dscalar.nii -pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false
  done
done

STRINGII=""
for LowResMesh in ${LowResMeshes} ; do
  STRINGII=`echo "${STRINGII}${AtlasSpaceFolder}/fsaverage_LR${LowResMesh}k@${AtlasSpaceFolder}/fsaverage_LR${LowResMesh}k@${LowResMesh}k_fs_LR ${T1wFolder}/fsaverage_LR${LowResMesh}k@${AtlasSpaceFolder}/fsaverage_LR${LowResMesh}k@${LowResMesh}k_fs_LR "`
done

#Add CIFTI Maps to Spec Files

STRINGIIList="corrThickness@dscalar"
if [ "${T2wPresent}" = "YES" ] ; then
  STRINGIIList+=" MyelinMap_BC@dscalar SmoothedMyelinMap_BC@dscalar"
fi
  
for STRING in ${STRINGII} ; do
  FolderI=`echo $STRING | cut -d "@" -f 1`
  FolderII=`echo $STRING | cut -d "@" -f 2`
  Mesh=`echo $STRING | cut -d "@" -f 3`

  for STRINGII in $STRINGIIList ; do
    Map=`echo $STRINGII | cut -d "@" -f 1`
    Ext=`echo $STRINGII | cut -d "@" -f 2`
    ${CARET7DIR}/wb_command -add-to-spec-file "$FolderI"/"$Subject"."$Mesh".wb.spec INVALID "$FolderII"/"$Subject"."$Map"."$Mesh"."$Ext".nii
  done
done

verbose_green_echo "---> Finished CreateMyelinMaps_1res"
verbose_echo " "

log_Msg "END: CreateMyelinMaps_1res"
