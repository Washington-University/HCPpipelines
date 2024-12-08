#!/bin/bash
set -eu
pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
  # pipedirguessed=1
   #fix this if the script is more than one level below HCPPIPEDIR
   export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"


opts_SetScriptDescription "Make some BIDS structures and run HippUnfold"

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject' 'Subject' 'subject ID' ""
opts_AddOptional '--hippunfold-dir' 'HippUnfoldDIR' 'path' "location of HippUnfold outputs"
opts_AddOptional '--atlas-hippunfold-dir' 'AtlasHippUnfoldDIR' 'path' "location of Atlas HippUnfold outputs"

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

opts_ShowValues

log_Msg "Starting PostHippUnfold pipeline for subject: $Subject"

T1wFolder="$StudyFolder/$Subject/T1w"
AtlasFolder="$StudyFolder/$Subject/MNINonLinear"

if [ -z ${HippUnfoldDIR} ] ; then
  HippUnfoldDIR="${T1wFolder}/HippUnfold"
fi 

if [ -z ${AtlasHippUnfoldDIR} ] ; then
  AtlasHippUnfoldDIR="${AtlasFolder}/HippUnfold"
fi 


HippUnfoldT1wFolderOut="$HippUnfoldDIR/T1w_hippunfold"
HippUnfoldT2wFolderOut="$HippUnfoldDIR/T2w_hippunfold"
HippUnfoldT1wT2wFolderOut="$HippUnfoldDIR/T1wT2w_hippunfold"
AtlasHippUnfoldT1wFolderOut="$AtlasHippUnfoldDIR/T1w_hippunfold"
AtlasHippUnfoldT2wFolderOut="$AtlasHippUnfoldDIR/T2w_hippunfold"
AtlasHippUnfoldT1wT2wFolderOut="$AtlasHippUnfoldDIR/T1wT2w_hippunfold"


#TODO: Apparently all HippUnfold surfaces have the same mesh for a given surface and thus these are not "native" meshes?
NativeFolderT1w="$HippUnfoldT1wFolderOut/Native"
NativeFolderT2w="$HippUnfoldT2wFolderOut/Native"
NativeFolderT1wT2w="$HippUnfoldT1wT2wFolderOut/Native"
AtlasNativeFolderT1w="$AtlasHippUnfoldT1wFolderOut/Native"
AtlasNativeFolderT2w="$AtlasHippUnfoldT2wFolderOut/Native"
AtlasNativeFolderT1wT2w="$AtlasHippUnfoldT1wT2wFolderOut/Native"

mkdir -p ${NativeFolderT1w} ${NativeFolderT2w} ${NativeFolderT1wT2w} ${AtlasNativeFolderT1w} ${AtlasNativeFolderT2w} ${AtlasNativeFolderT1wT2w}

function PostHippUnfold {
HippUnfoldFolderOut=${1}
NativeFolder=${2}
AtlasNativeFolder=${3}
AtlasFolder=${4}
Subject=${5}
Modality=${6}

#TODO: Replace hack with just recreating the CIFTIs
function MATLABHACK {
File=${1}
Left=${2}
Right=${3}
matlab -nojvm -nodisplay -nosplash <<M_PROG
addpath('${HCPPIPEDIR}/HippUnfoldHCP/scripts'); HippUnfoldMatlabHack('${File}','${Left}','${Right}');
M_PROG
echo "addpath('${HCPPIPEDIR}/HippUnfoldHCP/scripts'); HippUnfoldMatlabHack('${File}','${Left}','${Right}');"
}

function PALETTE {
File=${1}
Color=${2}
Type=${3}
wb_command=${4}
if [ ${Color} = "GRAY" ] ; then
  command="-pos-percent 2 98 -palette-name Gray_Interp -disp-pos true -disp-neg true -disp-zero true"
elif [ ${Color} = "VIDEEN" ] ; then
  command="-pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false"
fi
if [ ${Type} = 'metric' ] ; then
  ${wb_command} -metric-palette ${File} MODE_AUTO_SCALE_PERCENTAGE ${command}
elif [ ${Type} = 'cifti' ] ; then
  ${wb_command} -cifti-palette ${File} MODE_AUTO_SCALE_PERCENTAGE ${File} ${command}
fi
}

Structures="dentate hipp"
Surfaces="inner@PIAL midthickness@MIDTHICKNESS outer@GRAY_WHITE" #TODO: Need inner and outer secondary types
Scalars="curvature@GRAY@Curvature gyrification@GRAY@Gyrification surfarea@VIDEEN@SurfaceArea thickness@VIDEEN@Thickness myelin@VIDEEN@MyelinMap"
Labels="atlas-multihist7_subfields@HippocampalSubfields"

for Structure in $Structures ; do
  if [ ${Structure} = "dentate" ] ; then
    #Left="HIPPOCAMPUS_DENTATE_LEFT"
    #Right="HIPPCAMPUS_DENTATE_RIGHT"
    Left="HIPPOCAMPUS_LEFT" #TODO: Change to Dentate
    Right="HIPPOCAMPUS_RIGHT" #TODO: Change to Dentate
    for Hemisphere in L R ; do 
      #No dentate thickness if computed by HippUnfold
      ${CARET7DIR}/wb_command -surface-to-surface-3d-distance $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-${Structure}_inner.surf.gii $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-${Structure}_outer.surf.gii $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-${Structure}_thickness.shape.gii
      #Buggy dentate curvature computed by HippUnfold #TODO: Remove if fixed
      ${CARET7DIR}/wb_command -surface-curvature $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-${Structure}_midthickness.surf.gii -mean $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-${Structure}_curvature.shape.gii
      #HippUnfold applys a tanh normalization for some reason
      ${CARET7DIR}/wb_command -metric-math "tanh(X)" $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-${Structure}_curvature.shape.gii -var X $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-${Structure}_curvature.shape.gii
    done
    #No dentate thickness if computed by HippUnfold
    ${CARET7DIR}/wb_command -cifti-create-dense-scalar $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-0p5mm_label-${Structure}_thickness.dscalar.nii -left-metric $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-L_space-${Modality}_den-0p5mm_label-${Structure}_thickness.shape.gii -right-metric $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-R_space-${Modality}_den-0p5mm_label-${Structure}_thickness.shape.gii 
    #Buggy dentate curvature computed by HippUnfold #TODO: Remove if fixed
    ${CARET7DIR}/wb_command -cifti-create-dense-scalar $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-0p5mm_label-${Structure}_curvature.dscalar.nii -left-metric $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-L_space-${Modality}_den-0p5mm_label-${Structure}_curvature.shape.gii -right-metric $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-R_space-${Modality}_den-0p5mm_label-${Structure}_curvature.shape.gii 
  elif [ ${Structure} = "hipp" ] ; then
    Left="HIPPOCAMPUS_LEFT"
    Right="HIPPOCAMPUS_RIGHT"
  fi
  #No surface area CIFTI is made by HippUnfold
  ${CARET7DIR}/wb_command -cifti-create-dense-scalar $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-0p5mm_label-${Structure}_surfarea.dscalar.nii -left-metric $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-L_space-${Modality}_den-0p5mm_label-${Structure}_surfarea.shape.gii -right-metric $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-R_space-${Modality}_den-0p5mm_label-${Structure}_surfarea.shape.gii 
  for Hemisphere in L R ; do
    if [ ${Hemisphere} = "L" ] ; then
      if [ ${Structure} = "dentate" ] ; then
        #HemiStructure="HIPPOCAMPUS_DENTATE_LEFT"
        HemiStructure="HIPPOCAMPUS_LEFT" #TODO: Change to Dentate
      elif [ ${Structure} = "hipp" ] ; then
        HemiStructure="HIPPOCAMPUS_LEFT"
      fi
    elif [ ${Hemisphere} = "R" ] ; then
      if [ ${Structure} = "dentate" ] ; then
        #HemiStructure="HIPPOCAMPUS_DENTATE_RIGHT"
        HemiStructure="HIPPOCAMPUS_RIGHT" #TODO: Change to Dentate
      elif [ ${Structure} = "hipp" ] ; then
        HemiStructure="HIPPOCAMPUS_RIGHT"
      fi
    fi
    for Surface in $Surfaces ; do
      SurfaceType=`echo $Surface | cut -d "@" -f 2`
      Surface=`echo $Surface | cut -d "@" -f 1`
      if [ -e $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-${Structure}_${Surface}.surf.gii ] ; then
        cp $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-${Structure}_${Surface}.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.native.surf.gii
        ${CARET7DIR}/wb_command -set-structure ${NativeFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.native.surf.gii ${HemiStructure} -surface-type ANATOMICAL -surface-secondary-type ${SurfaceType}
        ${CARET7DIR}/wb_command -surface-apply-warpfield ${NativeFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.native.surf.gii ${AtlasFolder}/xfms/standard2acpc_dc.nii.gz ${AtlasNativeFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.native.surf.gii -fnirt ${AtlasFolder}/T1w_restore.nii.gz
      fi
    done
    if [ -e $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-${Structure}_${Surface}.surf.gii ] ; then
      cp $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-unfold_den-0p5mm_label-${Structure}_midthickness.surf.gii ${NativeFolder}/${Subject}.${Hemisphere}.${Structure}_flat.native.surf.gii
      ${CARET7DIR}/wb_command -set-structure ${NativeFolder}/${Subject}.${Hemisphere}.${Structure}_flat.native.surf.gii ${HemiStructure} -surface-type FLAT
      cp ${NativeFolder}/${Subject}.${Hemisphere}.${Structure}_flat.native.surf.gii ${AtlasNativeFolder}/${Subject}.${Hemisphere}.${Structure}_flat.native.surf.gii
    fi
    for Scalar in $Scalars ; do
      Name=`echo $Scalar | cut -d "@" -f 3`
      Color=`echo $Scalar | cut -d "@" -f 2`
      Scalar=`echo $Scalar | cut -d "@" -f 1`
      if [ -e $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-${Structure}_${Scalar}.shape.gii ] ; then
        cp $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-${Structure}_${Scalar}.shape.gii ${NativeFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.native.shape.gii
        ${CARET7DIR}/wb_command -set-structure ${NativeFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.native.shape.gii ${HemiStructure}
        PALETTE ${NativeFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.native.shape.gii ${Color} metric ${CARET7DIR}/wb_command
        ${CARET7DIR}/wb_command -set-map-names ${NativeFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.native.shape.gii -map 1 "${Subject}_${Name}"
        cp ${NativeFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.native.shape.gii ${AtlasNativeFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.native.shape.gii #TODO: mv to have maps in AtlasFolder like Cerebral Cortex?
      fi
    done
    for Label in $Labels ; do
      Name=`echo $Label | cut -d "@" -f 2`
      Label=`echo $Label | cut -d "@" -f 1`
      if [ -e $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-${Structure}_${Label}.label.gii ] ; then
        cp $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-${Structure}_${Label}.label.gii ${NativeFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.native.label.gii
        ${CARET7DIR}/wb_command -set-structure ${NativeFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.native.label.gii ${HemiStructure}
        ${CARET7DIR}/wb_command -set-map-names ${NativeFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.native.label.gii -map 1 "${Subject}_${Name}"
        cp ${NativeFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.native.label.gii ${AtlasNativeFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.native.label.gii #TODO: mv to have maps in AtlasFolder like Cerebral Cortex?
      fi
    done
    if [ -e $HippUnfoldFolderOut/hippunfold/sub-${Subject}/anat/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_desc-subfields_atlas-multihist7_dseg.nii.gz ] ; then
      cp $HippUnfoldFolderOut/hippunfold/sub-${Subject}/anat/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_desc-subfields_atlas-multihist7_dseg.nii.gz ${NativeFolder}/${Subject}.${Hemisphere}.HippocampalSubfields.nii.gz
    fi
  done
  for Scalar in $Scalars ; do
    Name=`echo $Scalar | cut -d "@" -f 3`
    Color=`echo $Scalar | cut -d "@" -f 2`
    Scalar=`echo $Scalar | cut -d "@" -f 1`
    if [ -e $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-0p5mm_label-${Structure}_${Scalar}.dscalar.nii ] ; then
      cp $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-0p5mm_label-${Structure}_${Scalar}.dscalar.nii ${NativeFolder}/${Subject}.${Structure}_${Scalar}.native.dscalar.nii
      MATLABHACK ${NativeFolder}/${Subject}.${Structure}_${Scalar}.native.dscalar.nii ${Left} ${Right}
      PALETTE ${NativeFolder}/${Subject}.${Structure}_${Scalar}.native.dscalar.nii ${Color} cifti ${CARET7DIR}/wb_command
      ${CARET7DIR}/wb_command -set-map-names ${NativeFolder}/${Subject}.${Structure}_${Scalar}.native.dscalar.nii -map 1 "${Subject}_${Name}"
      cp ${NativeFolder}/${Subject}.${Structure}_${Scalar}.native.dscalar.nii ${AtlasNativeFolder}/${Subject}.${Structure}_${Scalar}.native.dscalar.nii #TODO: mv to have maps in AtlasFolder like Cerebral Cortex?
    fi
  done
  for Label in $Labels ; do
    Name=`echo $Label | cut -d "@" -f 2`
    Label=`echo $Label | cut -d "@" -f 1`
    if [ -e $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-0p5mm_label-${Structure}_${Label}.dlabel.nii ] ; then
      cp $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-0p5mm_label-${Structure}_${Label}.dlabel.nii ${NativeFolder}/${Subject}.${Structure}_${Label}.native.dlabel.nii
      MATLABHACK ${NativeFolder}/${Subject}.${Structure}_${Label}.native.dlabel.nii ${Left} ${Right}
      ${CARET7DIR}/wb_command -set-map-names ${NativeFolder}/${Subject}.${Structure}_${Label}.native.dlabel.nii -map 1 "${Subject}_${Name}"
      cp ${NativeFolder}/${Subject}.${Structure}_${Label}.native.dlabel.nii ${AtlasNativeFolder}/${Subject}.${Structure}_${Label}.native.dlabel.nii #TODO: mv to have maps in AtlasFolder like Cerebral Cortex?
    fi
  done
done
fslmaths ${NativeFolder}/${Subject}.R.HippocampalSubfields.nii.gz -add 8 -mas ${NativeFolder}/${Subject}.R.HippocampalSubfields.nii.gz -add ${NativeFolder}/${Subject}.L.HippocampalSubfields.nii.gz ${NativeFolder}/${Subject}.HippocampalSubfields.nii.gz
${CARET7DIR}/wb_command -volume-label-import ${NativeFolder}/${Subject}.HippocampalSubfields.nii.gz $HCPPIPEDIR/global/config/HippUnfoldLut.txt ${NativeFolder}/${Subject}.HippocampalSubfields.nii.gz
rm ${NativeFolder}/${Subject}.L.HippocampalSubfields.nii.gz ${NativeFolder}/${Subject}.R.HippocampalSubfields.nii.gz
${CARET7DIR}/wb_command -volume-resample ${NativeFolder}/${Subject}.HippocampalSubfields.nii.gz ${AtlasFolder}/T1w_restore.nii.gz ENCLOSING_VOXEL ${AtlasNativeFolder}/${Subject}.HippocampalSubfields.nii.gz -warp ${AtlasFolder}/xfms/acpc_dc2standard.nii.gz -fnirt ${AtlasFolder}/T1w_restore.nii.gz
#TODO: Make spec files once hippocampus and dentate can both be loaded together

}
PostHippUnfold $HippUnfoldT1wFolderOut $NativeFolderT1w $AtlasNativeFolderT1w $AtlasFolder $Subject T1w
PostHippUnfold $HippUnfoldT2wFolderOut $NativeFolderT2w $AtlasNativeFolderT2w $AtlasFolder $Subject T2w
#PostHippUnfold $HippUnfoldT1wT2wFolderOut $NativeFolderT1wT2w $AtlasNativeFolderT1wT2w $Subject T1w #TODO: T1wT2w not working in HippUnfold; #Modality is still T1w
log_Msg "PostHippUnfold pipeline completed successfully for subject: $Subject"


#HippUnfold Outputs Used By HCP
#Scalars
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-dentate_curvature.shape.gii #Wrong mesh by default TODO: Remove if fixed
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-dentate_gyrification.shape.gii
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-dentate_myelin.shape.gii
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-dentate_surfarea.shape.gii
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-dentate_thickness.shape.gii #Not created by default
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-hipp_curvature.shape.gii
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-hipp_gyrification.shape.gii
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-hipp_myelin.shape.gii
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-hipp_surfarea.shape.gii
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-hipp_thickness.shape.gii

#Surfaces
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-dentate_inner.surf.gii
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-dentate_midthickness.surf.gii
#$HippUnfoldTolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-dentate_outer.surf.gii
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-hipp_inner.surf.gii
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-hipp_midthickness.surf.gii
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-hipp_outer.surf.gii

#Flat Surfaces
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-unfold_den-0p5mm_label-dentate_midthickness.surf.gii
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-unfold_den-0p5mm_label-hipp_midthickness.surf.gii

#Labels
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-hipp_atlas-multihist7_subfields.label.gii

#Specs
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-0p5mm_label-dentate_surfaces.spec
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}den-0p5mm_label-hipp_surfaces.spec
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}den-0p5mm_label-dentate_surfaces.spec
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-0p5mm_label-hipp_surfaces.spec

#CIFTIScalars
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-0p5mm_label-dentate_curvature.dscalar.nii #Wrong mesh by default TODO: Remove if fixed
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-0p5mm_label-dentate_gyrification.dscalar.nii
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-0p5mm_label-dentate_myelin.dscalar.nii
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-0p5mm_label-dentate_surfarea.dscalar.nii #Not created by default
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-0p5mm_label-dentate_thickness.dscalar.nii #Not created by default
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-0p5mm_label-hipp_curvature.dscalar.nii
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-0p5mm_label-hipp_gyrification.dscalar.nii
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-0p5mm_label-hipp_myelin.dscalar.nii
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-0p5mm_label-hipp_surfarea.dscalar.nii #Not created by default
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-0p5mm_label-hipp_thickness.dscalar.nii

#CIFTILabels
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-0p5mm_label-hipp_atlas-multihist7_subfields.dlabel.nii

#VolumeLabels
#$HippUnfoldFolderOut/hippunfold/sub-${Subject}/anat/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_desc-subfields_atlas-multihist7_dseg.nii.gz

