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
opts_AddOptional '--hippunfold-dir' 'PhysicalHippUnfoldDIR' 'path' "location of HippUnfold outputs"
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

if [ -z ${PhysicalHippUnfoldDIR} ] ; then
  PhysicalHippUnfoldDIR="${T1wFolder}/HippUnfold"
fi 

if [ -z ${AtlasHippUnfoldDIR} ] ; then
  AtlasHippUnfoldDIR="${AtlasFolder}/HippUnfold"
fi 

function PostHippUnfold {
HippUnfoldFolderOut=${1}
PhysicalHippUnfoldFolder=${2}
AtlasHippUnfoldFolder=${3}
T1wFolder=${4}
AtlasFolder=${5}
Subject=${6}
Modality=${7}
Mesh=${8}

if [ ${Modality} = "T1wT2w" ] ; then
  Modality="T1w"
  Flag="On"
else
  Flag="Off"
fi

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

Structures="dentate hipp" #TODO: Put both hipp and dentate in the same CIFTI files
Surfaces="inner@PIAL midthickness@MIDTHICKNESS outer@GRAY_WHITE" #TODO: Need inner and outer secondary types
Scalars="curvature@GRAY@Curvature gyrification@GRAY@Gyrification surfarea@VIDEEN@SurfaceArea thickness@VIDEEN@Thickness myelin@VIDEEN@MyelinMap"
Labels="atlas-multihist7_subfields@HippocampalSubfields"

for Structure in $Structures ; do
  if [ ${Structure} = "dentate" ] ; then
    Left="HIPPOCAMPUS_DENTATE_LEFT"
    Right="HIPPOCAMPUS_DENTATE_RIGHT"
    for Hemisphere in L R ; do 
      #No dentate thickness if computed by HippUnfold
      ${CARET7DIR}/wb_command -surface-to-surface-3d-distance $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-${Mesh}_label-${Structure}_inner.surf.gii $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-${Mesh}_label-${Structure}_outer.surf.gii $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-${Mesh}_label-${Structure}_thickness.shape.gii
    done
    #No dentate thickness if computed by HippUnfold
    ${CARET7DIR}/wb_command -cifti-create-dense-scalar $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-${Mesh}_label-${Structure}_thickness.dscalar.nii -left-metric $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-L_space-${Modality}_den-${Mesh}_label-${Structure}_thickness.shape.gii -right-metric $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-R_space-${Modality}_den-${Mesh}_label-${Structure}_thickness.shape.gii 
  elif [ ${Structure} = "hipp" ] ; then
    Left="HIPPOCAMPUS_LEFT"
    Right="HIPPOCAMPUS_RIGHT"
  fi
  #No surface area CIFTI is made by HippUnfold
  ${CARET7DIR}/wb_command -cifti-create-dense-scalar $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-${Mesh}_label-${Structure}_surfarea.dscalar.nii -left-metric $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-L_space-${Modality}_den-${Mesh}_label-${Structure}_surfarea.shape.gii -right-metric $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-R_space-${Modality}_den-${Mesh}_label-${Structure}_surfarea.shape.gii 
  for Hemisphere in L R ; do
    if [ ${Hemisphere} = "L" ] ; then
      if [ ${Structure} = "dentate" ] ; then
        HemiStructure="HIPPOCAMPUS_DENTATE_LEFT"
      elif [ ${Structure} = "hipp" ] ; then
        HemiStructure="HIPPOCAMPUS_LEFT"
      fi
    elif [ ${Hemisphere} = "R" ] ; then
      if [ ${Structure} = "dentate" ] ; then
        HemiStructure="HIPPOCAMPUS_DENTATE_RIGHT"
      elif [ ${Structure} = "hipp" ] ; then
        HemiStructure="HIPPOCAMPUS_RIGHT"
      fi
    fi
    
    #Anatomical Surfaces
    for Surface in $Surfaces ; do
      SurfaceType=`echo $Surface | cut -d "@" -f 2`
      Surface=`echo $Surface | cut -d "@" -f 1`
      if [ -e $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-${Mesh}_label-${Structure}_${Surface}.surf.gii ] ; then
        cp $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-${Mesh}_label-${Structure}_${Surface}.surf.gii ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.${Mesh}.surf.gii
        ${CARET7DIR}/wb_command -set-structure ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.${Mesh}.surf.gii ${HemiStructure} -surface-type ANATOMICAL -surface-secondary-type ${SurfaceType}
        ${CARET7DIR}/wb_command -add-to-spec-file ${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec ${HemiStructure} ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.${Mesh}.surf.gii
        ${CARET7DIR}/wb_command -surface-apply-warpfield ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.${Mesh}.surf.gii ${AtlasFolder}/xfms/standard2acpc_dc.nii.gz ${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.${Mesh}.surf.gii -fnirt ${AtlasFolder}/T1w_restore.nii.gz
        ${CARET7DIR}/wb_command -add-to-spec-file ${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec ${HemiStructure} ${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.${Mesh}.surf.gii
      fi
    done
    
    #Flat Surfaces
    if [ -e $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-${Mesh}_label-${Structure}_${Surface}.surf.gii ] ; then
      cp $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-unfold_den-${Mesh}_label-${Structure}_midthickness.surf.gii ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_flat.${Mesh}.surf.gii
      ${CARET7DIR}/wb_command -set-structure ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_flat.${Mesh}.surf.gii ${HemiStructure} -surface-type FLAT
      ${CARET7DIR}/wb_command -add-to-spec-file ${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec ${HemiStructure} ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_flat.${Mesh}.surf.gii
      cp ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_flat.${Mesh}.surf.gii ${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_flat.${Mesh}.surf.gii
      ${CARET7DIR}/wb_command -add-to-spec-file ${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec ${HemiStructure} ${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_flat.${Mesh}.surf.gii
    fi
    
    #GIFTI Metrics
    #Don't add GIFTI to Specs
    for Scalar in $Scalars ; do
      Name=`echo $Scalar | cut -d "@" -f 3`
      Color=`echo $Scalar | cut -d "@" -f 2`
      Scalar=`echo $Scalar | cut -d "@" -f 1`
      if [ -e $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-${Mesh}_label-${Structure}_${Scalar}.shape.gii ] ; then
        cp $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-${Mesh}_label-${Structure}_${Scalar}.shape.gii ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii
        ${CARET7DIR}/wb_command -set-structure ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii ${HemiStructure}
        PALETTE ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii ${Color} metric ${CARET7DIR}/wb_command
        ${CARET7DIR}/wb_command -set-map-names ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii -map 1 "${Subject}_${Name}"
        if [ $Scalar = "surfarea" ] ; then
          ${CARET7DIR}/wb_command -surface-vertex-areas ${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_midthickness.${Mesh}.surf.gii ${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii
        else
          cp ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii ${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii #TODO: mv to have maps in AtlasFolder like Cerebral Cortex?
        fi
      fi
    done
    
    #GIFTI Labels
    #Don't add GIFTI to Specs
    for Label in $Labels ; do
      Name=`echo $Label | cut -d "@" -f 2`
      Label=`echo $Label | cut -d "@" -f 1`
      if [ -e $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-${Mesh}_label-${Structure}_${Label}.label.gii ] ; then
        cp $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-${Mesh}_label-${Structure}_${Label}.label.gii ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.label.gii
        ${CARET7DIR}/wb_command -set-structure ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.label.gii ${HemiStructure}
        ${CARET7DIR}/wb_command -set-map-names ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.label.gii -map 1 "${Subject}_${Name}"
        cp ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.label.gii ${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.label.gii #TODO: mv to have maps in AtlasFolder like Cerebral Cortex?
      fi
    done
    
    #NIFTI Hemispheric Labels
    if [ -e $HippUnfoldFolderOut/hippunfold/sub-${Subject}/anat/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_desc-subfields_atlas-multihist7_dseg.nii.gz ] ; then
      cp $HippUnfoldFolderOut/hippunfold/sub-${Subject}/anat/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_desc-subfields_atlas-multihist7_dseg.nii.gz ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.HippocampalSubfields.nii.gz
    fi
  done
  
  #TODO: Put both hipp and dentate in the same CIFTI files, end structure loop above this comment
  #CIFTI Scalars
  for Scalar in $Scalars ; do
    Name=`echo $Scalar | cut -d "@" -f 3`
    Color=`echo $Scalar | cut -d "@" -f 2`
    Scalar=`echo $Scalar | cut -d "@" -f 1`
    if [ -e $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-${Mesh}_label-${Structure}_${Scalar}.dscalar.nii ] ; then
      cp $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-${Mesh}_label-${Structure}_${Scalar}.dscalar.nii ${PhysicalHippUnfoldFolder}/${Subject}.${Structure}_${Scalar}.${Mesh}.dscalar.nii
      MATLABHACK ${PhysicalHippUnfoldFolder}/${Subject}.${Structure}_${Scalar}.${Mesh}.dscalar.nii ${Left} ${Right} > /dev/null 2>&1 #TODO: Replace hack with just recreating the CIFTIs
      PALETTE ${PhysicalHippUnfoldFolder}/${Subject}.${Structure}_${Scalar}.${Mesh}.dscalar.nii ${Color} cifti ${CARET7DIR}/wb_command
      ${CARET7DIR}/wb_command -set-map-names ${PhysicalHippUnfoldFolder}/${Subject}.${Structure}_${Scalar}.${Mesh}.dscalar.nii -map 1 "${Subject}_${Name}"
      ${CARET7DIR}/wb_command -add-to-spec-file ${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec INVALID ${PhysicalHippUnfoldFolder}/${Subject}.${Structure}_${Scalar}.${Mesh}.dscalar.nii #TODO: mv to have maps in AtlasFolder like Cerebral Cortex?
      if [ $Scalar = "surfarea" ] ; then
        ${CARET7DIR}/wb_command -cifti-create-dense-scalar ${AtlasHippUnfoldFolder}/${Subject}.${Structure}_${Scalar}.${Mesh}.dscalar.nii -left-metric ${AtlasHippUnfoldFolder}/${Subject}.L.${Structure}_${Scalar}.${Mesh}.shape.gii -right-metric ${AtlasHippUnfoldFolder}/${Subject}.R.${Structure}_${Scalar}.${Mesh}.shape.gii
        MATLABHACK ${AtlasHippUnfoldFolder}/${Subject}.${Structure}_${Scalar}.${Mesh}.dscalar.nii ${Left} ${Right} > /dev/null 2>&1 #TODO: Replace hack with just recreating the CIFTIs
        PALETTE ${AtlasHippUnfoldFolder}/${Subject}.${Structure}_${Scalar}.${Mesh}.dscalar.nii ${Color} cifti ${CARET7DIR}/wb_command
        ${CARET7DIR}/wb_command -set-map-names ${AtlasHippUnfoldFolder}/${Subject}.${Structure}_${Scalar}.${Mesh}.dscalar.nii -map 1 "${Subject}_${Name}"
      else
        cp ${PhysicalHippUnfoldFolder}/${Subject}.${Structure}_${Scalar}.${Mesh}.dscalar.nii ${AtlasHippUnfoldFolder}/${Subject}.${Structure}_${Scalar}.${Mesh}.dscalar.nii #TODO: mv to have maps in AtlasFolder like Cerebral Cortex?
      fi
      ${CARET7DIR}/wb_command -add-to-spec-file ${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec INVALID ${AtlasHippUnfoldFolder}/${Subject}.${Structure}_${Scalar}.${Mesh}.dscalar.nii #TODO: mv to have maps in AtlasFolder like Cerebral Cortex?
    fi
  done
  
  #CIFTI Labels
  for Label in $Labels ; do
    Name=`echo $Label | cut -d "@" -f 2`
    Label=`echo $Label | cut -d "@" -f 1`
    if [ -e $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-${Mesh}_label-${Structure}_${Label}.dlabel.nii ] ; then
      cp $HippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-${Mesh}_label-${Structure}_${Label}.dlabel.nii ${PhysicalHippUnfoldFolder}/${Subject}.${Structure}_${Label}.${Mesh}.dlabel.nii
      MATLABHACK ${PhysicalHippUnfoldFolder}/${Subject}.${Structure}_${Label}.${Mesh}.dlabel.nii ${Left} ${Right} > /dev/null 2>&1 #TODO: Replace hack with just recreating the CIFTIs
      ${CARET7DIR}/wb_command -set-map-names ${PhysicalHippUnfoldFolder}/${Subject}.${Structure}_${Label}.${Mesh}.dlabel.nii -map 1 "${Subject}_${Name}"
      ${CARET7DIR}/wb_command -add-to-spec-file ${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec INVALID ${PhysicalHippUnfoldFolder}/${Subject}.${Structure}_${Label}.${Mesh}.dlabel.nii #TODO: mv to have maps in AtlasFolder like Cerebral Cortex?
      cp ${PhysicalHippUnfoldFolder}/${Subject}.${Structure}_${Label}.${Mesh}.dlabel.nii ${AtlasHippUnfoldFolder}/${Subject}.${Structure}_${Label}.${Mesh}.dlabel.nii #TODO: mv to have maps in AtlasFolder like Cerebral Cortex?
      ${CARET7DIR}/wb_command -add-to-spec-file ${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec INVALID ${AtlasHippUnfoldFolder}/${Subject}.${Structure}_${Label}.${Mesh}.dlabel.nii #TODO: mv to have maps in AtlasFolder like Cerebral Cortex?
    fi
  done
done

#NIFTI Label Volumes
fslmaths ${PhysicalHippUnfoldFolder}/${Subject}.R.HippocampalSubfields.nii.gz -add 8 -mas ${PhysicalHippUnfoldFolder}/${Subject}.R.HippocampalSubfields.nii.gz -add ${PhysicalHippUnfoldFolder}/${Subject}.L.HippocampalSubfields.nii.gz ${PhysicalHippUnfoldFolder}/${Subject}.HippocampalSubfields.nii.gz
${CARET7DIR}/wb_command -volume-label-import ${PhysicalHippUnfoldFolder}/${Subject}.HippocampalSubfields.nii.gz $HCPPIPEDIR/global/config/HippUnfoldLut.txt ${PhysicalHippUnfoldFolder}/${Subject}.HippocampalSubfields.nii.gz
rm ${PhysicalHippUnfoldFolder}/${Subject}.L.HippocampalSubfields.nii.gz ${PhysicalHippUnfoldFolder}/${Subject}.R.HippocampalSubfields.nii.gz
${CARET7DIR}/wb_command -add-to-spec-file ${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec INVALID ${PhysicalHippUnfoldFolder}/${Subject}.HippocampalSubfields.nii.gz
${CARET7DIR}/wb_command -volume-resample ${PhysicalHippUnfoldFolder}/${Subject}.HippocampalSubfields.nii.gz ${AtlasFolder}/T1w_restore.nii.gz ENCLOSING_VOXEL ${AtlasHippUnfoldFolder}/${Subject}.HippocampalSubfields.nii.gz -warp ${AtlasFolder}/xfms/acpc_dc2standard.nii.gz -fnirt ${AtlasFolder}/T1w_restore.nii.gz
${CARET7DIR}/wb_command -add-to-spec-file ${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec INVALID ${AtlasHippUnfoldFolder}/${Subject}.HippocampalSubfields.nii.gz

#NIFTI Input Volumes
${CARET7DIR}/wb_command -add-to-spec-file ${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec INVALID ${T1wFolder}/T1w_acpc_dc_restore.nii.gz
${CARET7DIR}/wb_command -add-to-spec-file ${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec INVALID ${T1wFolder}/T2w_acpc_dc_restore.nii.gz
${CARET7DIR}/wb_command -add-to-spec-file ${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec INVALID ${AtlasFolder}/T1w_restore.nii.gz
${CARET7DIR}/wb_command -add-to-spec-file ${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec INVALID ${AtlasFolder}/T2w_restore.nii.gz

#TODO: How to combine hippocampal and cerebral cortex?  Merge spec files using merge wb_command

if [ ${Flag} = "On" ] ; then
  Modality="T1wT2w"
fi

}

for Modality in T1w T2w T1wT2w ; do 
  for Mesh in 0p5mm 1mm 2mm ; do #TODO: Native meshes not yet available from HippUnfold: "Native" Folder Name "native" Mesh Name 
    
    PhysicalHippUnfoldFolderOut="$PhysicalHippUnfoldDIR/${Modality}_hippunfold"
    AtlasHippUnfoldolderOut="$AtlasHippUnfoldDIR/${Modality}_hippunfold"

    PhysicalHippUnfoldFolder="$PhysicalHippUnfoldFolderOut/$Mesh"
    AtlasHippUnfoldFolder="$AtlasHippUnfoldolderOut/$Mesh"
    
    mkdir -p ${PhysicalHippUnfoldFolder} ${AtlasHippUnfoldFolder}

    log_Msg "Processing $Modality $Mesh"
    PostHippUnfold $PhysicalHippUnfoldFolderOut $PhysicalHippUnfoldFolder $AtlasHippUnfoldFolder $T1wFolder $AtlasFolder $Subject $Modality $Mesh
  done
done

log_Msg "PostHippUnfold pipeline completed successfully for subject: $Subject"


#HippUnfold Outputs Used By HCP
#Scalars
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-${Mesh}_label-dentate_curvature.shape.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-${Mesh}_label-dentate_gyrification.shape.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-${Mesh}_label-dentate_myelin.shape.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-${Mesh}_label-dentate_surfarea.shape.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-${Mesh}_label-dentate_thickness.shape.gii #Not created by default
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-${Mesh}_label-hipp_curvature.shape.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-${Mesh}_label-hipp_gyrification.shape.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-${Mesh}_label-hipp_myelin.shape.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-${Mesh}_label-hipp_surfarea.shape.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-${Mesh}_label-hipp_thickness.shape.gii

#Surfaces
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-${Mesh}_label-dentate_inner.surf.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-${Mesh}_label-dentate_midthickness.surf.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-${Mesh}_label-dentate_outer.surf.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-${Mesh}_label-hipp_inner.surf.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-${Mesh}_label-hipp_midthickness.surf.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-${Mesh}_label-hipp_outer.surf.gii

#Flat Surfaces
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-unfold_den-${Mesh}_label-dentate_midthickness.surf.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-unfold_den-${Mesh}_label-hipp_midthickness.surf.gii

#Labels
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-${Mesh}_label-hipp_atlas-multihist7_subfields.label.gii

#Specs
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_den-${Mesh}_label-dentate_surfaces.spec
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}den-${Mesh}_label-hipp_surfaces.spec
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}den-${Mesh}_label-dentate_surfaces.spec
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-${Mesh}_label-hipp_surfaces.spec

#CIFTIScalars
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-${Mesh}_label-dentate_curvature.dscalar.nii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-${Mesh}_label-dentate_gyrification.dscalar.nii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-${Mesh}_label-dentate_myelin.dscalar.nii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-${Mesh}_label-dentate_surfarea.dscalar.nii #Not created by default
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-${Mesh}_label-dentate_thickness.dscalar.nii #Not created by default
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-${Mesh}_label-hipp_curvature.dscalar.nii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-${Mesh}_label-hipp_gyrification.dscalar.nii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-${Mesh}_label-hipp_myelin.dscalar.nii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-${Mesh}_label-hipp_surfarea.dscalar.nii #Not created by default
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-${Mesh}_label-hipp_thickness.dscalar.nii

#CIFTILabels
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Modality}_den-${Mesh}_label-hipp_atlas-multihist7_subfields.dlabel.nii

#VolumeLabels
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/anat/sub-${Subject}_hemi-${Hemisphere}_space-${Modality}_desc-subfields_atlas-multihist7_dseg.nii.gz

