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
    ${wb_command} -metric-palette "$File" MODE_AUTO_SCALE_PERCENTAGE ${command}
  elif [ ${Type} = 'cifti' ] ; then
    ${wb_command} -cifti-palette "$File" MODE_AUTO_SCALE_PERCENTAGE "$File" ${command}
  fi
}

for Modality in T1w T2w T1wT2w ; do
  for Mesh in native 512 2k 8k 18k ; do #Native:??? 512=2mm 2k=1mm, 8k=0.5mm 18k=0.3mm #Was: 0p5mm 1mm 2mm

    PhysicalHippUnfoldFolderOut="$PhysicalHippUnfoldDIR"/"$Modality"
    AtlasHippUnfoldolderOut="$AtlasHippUnfoldDIR"/"$Modality"

    PhysicalHippUnfoldFolder="$PhysicalHippUnfoldFolderOut/$Mesh"
    AtlasHippUnfoldFolder="$AtlasHippUnfoldolderOut/$Mesh"
    
    mkdir -p "$PhysicalHippUnfoldFolder" "$AtlasHippUnfoldFolder"

    log_Msg "Processing $Modality $Mesh"
    
    #T1wT2w modality seems to run in BIDS "T1w" space, so let's make a separate variable for space
    Space="$Modality"
    if [[ "$Modality" == "T1wT2w" ]]
    then
      Space="T2w"
    fi

    Structures="dentate hipp"
    Surfaces="inner@INNER midthickness@MIDTHICKNESS outer@OUTER"
    Scalars="curvature@GRAY@Curvature gyrification@GRAY@Gyrification surfarea@VIDEEN@SurfaceArea thickness@VIDEEN@Thickness myelin@VIDEEN@MyelinMap"
    Labels="atlas-multihist7_subfields@HippocampalSubfields"

    for Structure in $Structures ; do
      for Hemisphere in L R ; do
        #surfacea no longer computed by HippUnfold
        ${CARET7DIR}/wb_command -surface-vertex-areas $PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-${Structure}_midthickness.surf.gii $PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/metric/sub-${Subject}_hemi-${Hemisphere}_den-${Mesh}_label-${Structure}_surfarea.shape.gii
      done
      if [ ${Structure} = "dentate" ] ; then
        Left="HIPPOCAMPUS_DENTATE_LEFT"
        Right="HIPPOCAMPUS_DENTATE_RIGHT"
        #for Hemisphere in L R ; do
          #Already exists #Was: No dentate thickness is computed by HippUnfold
          #${CARET7DIR}/wb_command -surface-to-surface-3d-distance $PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-${Structure}_inner.surf.gii $PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-${Structure}_outer.surf.gii $PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/metric/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-${Structure}_thickness.shape.gii
        #done
      elif [ ${Structure} = "hipp" ] ; then
        Left="HIPPOCAMPUS_LEFT"
        Right="HIPPOCAMPUS_RIGHT"
      fi
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
          cp $PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-${Structure}_${Surface}.surf.gii ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.${Mesh}.surf.gii
          ${CARET7DIR}/wb_command -set-structure ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.${Mesh}.surf.gii ${HemiStructure} -surface-type ANATOMICAL -surface-secondary-type ${SurfaceType}
          ${CARET7DIR}/wb_command -add-to-spec-file ${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec ${HemiStructure} ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.${Mesh}.surf.gii
          ${CARET7DIR}/wb_command -surface-apply-warpfield ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.${Mesh}.surf.gii ${AtlasFolder}/xfms/standard2acpc_dc.nii.gz ${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.${Mesh}.surf.gii -fnirt ${AtlasFolder}/T1w_restore.nii.gz
          ${CARET7DIR}/wb_command -add-to-spec-file ${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec ${HemiStructure} ${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.${Mesh}.surf.gii
        done
        
        #Flat Surfaces
        cp $PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-unfold_den-${Mesh}_label-${Structure}_midthickness.surf.gii ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_flat.${Mesh}.surf.gii
        ${CARET7DIR}/wb_command -set-structure ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_flat.${Mesh}.surf.gii ${HemiStructure} -surface-type FLAT
        ${CARET7DIR}/wb_command -add-to-spec-file ${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec ${HemiStructure} ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_flat.${Mesh}.surf.gii
        cp ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_flat.${Mesh}.surf.gii ${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_flat.${Mesh}.surf.gii
        ${CARET7DIR}/wb_command -add-to-spec-file ${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec ${HemiStructure} ${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_flat.${Mesh}.surf.gii
        
        #GIFTI Metrics
        #Don't add GIFTI to Specs
        for Scalar in $Scalars ; do
          Name=`echo $Scalar | cut -d "@" -f 3`
          Color=`echo $Scalar | cut -d "@" -f 2`
          Scalar=`echo $Scalar | cut -d "@" -f 1`
          cp $PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/metric/sub-${Subject}_hemi-${Hemisphere}_den-${Mesh}_label-${Structure}_${Scalar}.shape.gii ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii
          ${CARET7DIR}/wb_command -set-structure ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii ${HemiStructure}
          PALETTE ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii ${Color} metric ${CARET7DIR}/wb_command
          ${CARET7DIR}/wb_command -set-map-names ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii -map 1 "${Subject}_${Name}"
          if [ $Scalar = "surfarea" ] ; then
            ${CARET7DIR}/wb_command -surface-vertex-areas ${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_midthickness.${Mesh}.surf.gii ${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii
          else
            cp ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii ${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii #TODO: mv to have maps in AtlasFolder like Cerebral Cortex?
          fi
        done
        
        #GIFTI Labels
        #Don't add GIFTI to Specs
        for Label in $Labels ; do
          Name=`echo $Label | cut -d "@" -f 2`
          Label=`echo $Label | cut -d "@" -f 1`
          if [ ${Structure} = "hipp" ] ; then
            if [ ${Hemisphere} = "L" ] ; then
              Expression="Var"
            elif [ ${Hemisphere} = "R" ] ; then
              Expression="Var + 8"
            fi
            ${CARET7DIR}/wb_command -metric-math "${Expression}" ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.shape.gii -var Var $PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/metric/sub-${Subject}_hemi-${Hemisphere}_den-${Mesh}_label-${Structure}_${Label}.label.gii |& grep -v NIFTI_INTENT_LABEL
            ${CARET7DIR}/wb_command -metric-label-import ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.shape.gii $HCPPIPEDIR/global/config/HippUnfoldLut.txt ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.label.gii
          elif [ ${Structure} = "dentate" ] ; then
            if [ ${Hemisphere} = "L" ] ; then
              Expression="6"
            elif [ ${Hemisphere} = "R" ] ; then
              Expression="6 + 8"
            fi
            ${CARET7DIR}/wb_command -metric-math "${Expression}" ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.shape.gii -var Var $PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/metric/sub-${Subject}_hemi-${Hemisphere}_den-${Mesh}_label-${Structure}_${Scalar}.shape.gii |& grep -v NIFTI_INTENT_LABEL
            ${CARET7DIR}/wb_command -metric-label-import ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.shape.gii $HCPPIPEDIR/global/config/HippUnfoldLut.txt ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.label.gii
          fi
          ${CARET7DIR}/wb_command -set-structure ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.label.gii ${HemiStructure}
          ${CARET7DIR}/wb_command -set-map-names ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.label.gii -map 1 "${Subject}_${Name}"
          cp ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.label.gii ${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.label.gii #TODO: mv to have maps in AtlasFolder like Cerebral Cortex?
        done
        
        #NIFTI Hemispheric Labels
        cp $PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/anat/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_label-hipp_desc-subfields_atlas-multihist7_dseg.nii.gz ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.HippocampalSubfields.nii.gz
      done
    done
    
    #CIFTI Scalars
    for Scalar in $Scalars ; do
      Name=`echo $Scalar | cut -d "@" -f 3`
      Color=`echo $Scalar | cut -d "@" -f 2`
      Scalar=`echo $Scalar | cut -d "@" -f 1`
      ${CARET7DIR}/wb_command -cifti-create-dense-scalar ${PhysicalHippUnfoldFolder}/${Subject}.hippocampus_${Scalar}.${Mesh}.dscalar.nii -metric HIPPOCAMPUS_LEFT ${PhysicalHippUnfoldFolder}/${Subject}.L.hipp_${Scalar}.${Mesh}.shape.gii -metric HIPPOCAMPUS_RIGHT ${PhysicalHippUnfoldFolder}/${Subject}.R.hipp_${Scalar}.${Mesh}.shape.gii -metric HIPPOCAMPUS_DENTATE_LEFT ${PhysicalHippUnfoldFolder}/${Subject}.L.dentate_${Scalar}.${Mesh}.shape.gii -metric HIPPOCAMPUS_DENTATE_RIGHT ${PhysicalHippUnfoldFolder}/${Subject}.R.dentate_${Scalar}.${Mesh}.shape.gii
      PALETTE ${PhysicalHippUnfoldFolder}/${Subject}.hippocampus_${Scalar}.${Mesh}.dscalar.nii ${Color} cifti ${CARET7DIR}/wb_command
      ${CARET7DIR}/wb_command -set-map-names ${PhysicalHippUnfoldFolder}/${Subject}.hippocampus_${Scalar}.${Mesh}.dscalar.nii -map 1 "${Subject}_${Name}"
      ${CARET7DIR}/wb_command -add-to-spec-file ${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec INVALID ${PhysicalHippUnfoldFolder}/${Subject}.hippocampus_${Scalar}.${Mesh}.dscalar.nii #TODO: mv to have maps in AtlasFolder like Cerebral Cortex?
      cp ${PhysicalHippUnfoldFolder}/${Subject}.hippocampus_${Scalar}.${Mesh}.dscalar.nii ${AtlasHippUnfoldFolder}/${Subject}.hippocampus_${Scalar}.${Mesh}.dscalar.nii #TODO: mv to have maps in AtlasFolder like Cerebral Cortex?
      ${CARET7DIR}/wb_command -add-to-spec-file ${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec INVALID ${AtlasHippUnfoldFolder}/${Subject}.hippocampus_${Scalar}.${Mesh}.dscalar.nii #TODO: mv to have maps in AtlasFolder like Cerebral Cortex?
    done

    
    #CIFTI Labels
    for Label in $Labels ; do
      Name=`echo $Label | cut -d "@" -f 2`
      Label=`echo $Label | cut -d "@" -f 1`
      ${CARET7DIR}/wb_command -cifti-create-label ${PhysicalHippUnfoldFolder}/${Subject}.hippocampus_${Label}.${Mesh}.dlabel.nii -label HIPPOCAMPUS_LEFT ${PhysicalHippUnfoldFolder}/${Subject}.L.hipp_${Label}.${Mesh}.label.gii -label HIPPOCAMPUS_RIGHT ${PhysicalHippUnfoldFolder}/${Subject}.R.hipp_${Label}.${Mesh}.label.gii -label HIPPOCAMPUS_DENTATE_LEFT ${PhysicalHippUnfoldFolder}/${Subject}.L.dentate_${Label}.${Mesh}.label.gii -label HIPPOCAMPUS_DENTATE_RIGHT ${PhysicalHippUnfoldFolder}/${Subject}.R.dentate_${Label}.${Mesh}.label.gii
      ${CARET7DIR}/wb_command -set-map-names ${PhysicalHippUnfoldFolder}/${Subject}.hippocampus_${Label}.${Mesh}.dlabel.nii -map 1 "${Subject}_${Name}"
      ${CARET7DIR}/wb_command -add-to-spec-file ${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec INVALID ${PhysicalHippUnfoldFolder}/${Subject}.hippocampus_${Label}.${Mesh}.dlabel.nii #TODO: mv to have maps in AtlasFolder like Cerebral Cortex?
      cp ${PhysicalHippUnfoldFolder}/${Subject}.hippocampus_${Label}.${Mesh}.dlabel.nii ${AtlasHippUnfoldFolder}/${Subject}.hippocampus_${Label}.${Mesh}.dlabel.nii #TODO: mv to have maps in AtlasFolder like Cerebral Cortex?
      ${CARET7DIR}/wb_command -add-to-spec-file ${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec INVALID ${AtlasHippUnfoldFolder}/${Subject}.hippocampus_${Label}.${Mesh}.dlabel.nii #TODO: mv to have maps in AtlasFolder like Cerebral Cortex?
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

    #TODO: Anything with 8k and 18k meshes?
    if [ $Mesh = "native" ] ; then
      ${CARET7DIR}/wb_command -spec-file-merge ${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec ${T1wFolder}/Native/${Subject}.native.wb.spec ${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.native.wb_spec #TODO: Don't Hardcode Cortex
      ${CARET7DIR}/wb_command -spec-file-merge ${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec ${AtlasFolder}/Native/${Subject}.native.wb.spec ${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.native.wb_spec #TODO: Don't Hardcode Cortex
    elif [ $Mesh = "512" ] ; then
      ${CARET7DIR}/wb_command -spec-file-merge ${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec ${T1wFolder}/fsaverage_LR32k/${Subject}.MSMAll.32k_fs_LR.wb.spec ${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.MSMAll.32k.wb_spec #TODO: Don't Hardcode Cortex
      ${CARET7DIR}/wb_command -spec-file-merge ${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec ${AtlasFolder}/fsaverage_LR32k/${Subject}.MSMAll.32k_fs_LR.wb.spec ${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.MSMAll.32k.wb_spec #TODO: Don't Hardcode Cortex
    elif [ $Mesh = "2k" ] ; then
      ${CARET7DIR}/wb_command -spec-file-merge ${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec ${AtlasFolder}/${Subject}.MSMAll.164k_fs_LR.wb.spec ${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.MSMAll.164k.wb_spec #TODO: Don't Hardcode Cortex
    fi
  done
done

log_Msg "PostHippUnfold pipeline completed successfully for subject: $Subject"


#HippUnfold Outputs Used By HCP

#Version 2.0.0
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/anat:
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/anat/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_label-hipp_desc-subfields_atlas-multihist7_dseg.nii.gz

##$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/anat/sub-${Subject}_desc-preproc_T1w.nii.gz
##$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/anat/sub-${Subject}_desc-preproc_T2w.nii.gz
##$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/anat/sub-${Subject}_hemi-L_space-cropT1w_desc-preproc_T1w.nii.gz
##$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/anat/sub-${Subject}_hemi-L_space-cropT1w_label-hipp_desc-subfields_atlas-multihist7_dseg.nii.gz
##$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/anat/sub-${Subject}_hemi-R_space-cropT1w_desc-preproc_T1w.nii.gz
##$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/anat/sub-${Subject}_hemi-R_space-cropT1w_label-hipp_desc-subfields_atlas-multihist7_dseg.nii.gz
##$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/anat/sub-${Subject}_space-cropT1w_desc-subfields_atlas-multihist7_volumes.tsv

#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/cifti:
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/cifti/sub-${Subject}_den-${Mesh}_label-dentate_curvature.dscalar.nii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/cifti/sub-${Subject}_den-${Mesh}_label-dentate_gyrification.dscalar.nii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/cifti/sub-${Subject}_den-${Mesh}_label-dentate_myelin.dscalar.nii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/cifti/sub-${Subject}_den-${Mesh}_label-dentate_surfarea.dscalar.nii #Not created by default
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/cifti/sub-${Subject}_den-${Mesh}_label-dentate_thickness.dscalar.nii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/cifti/sub-${Subject}_den-${Mesh}_label-hipp_atlas-multihist7_subfields.dlabel.nii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/cifti/sub-${Subject}_den-${Mesh}_label-hipp_curvature.dscalar.nii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/cifti/sub-${Subject}_den-${Mesh}_label-hipp_gyrification.dscalar.nii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/cifti/sub-${Subject}_den-${Mesh}_label-hipp_myelin.dscalar.nii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/cifti/sub-${Subject}_den-${Mesh}_label-hipp_surfarea.dscalar.nii #Not created by default
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/cifti/sub-${Subject}_den-${Mesh}_label-hipp_thickness.dscalar.nii

#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/metric:
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/metric/sub-${Subject}_hemi-${Hemisphere}_den-${Mesh}_label-dentate_curvature.shape.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/metric/sub-${Subject}_hemi-${Hemisphere}_den-${Mesh}_label-dentate_gyrification.shape.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/metric/sub-${Subject}_hemi-${Hemisphere}_den-${Mesh}_label-dentate_myelin.shape.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/metric/sub-${Subject}_hemi-${Hemisphere}_den-${Mesh}_label-dentate_surfarea.shape.gii #Not created by default
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/metric/sub-${Subject}_hemi-${Hemisphere}_den-${Mesh}_label-dentate_thickness.shape.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/metric/sub-${Subject}_hemi-${Hemisphere}_den-${Mesh}_label-hipp_atlas-multihist7_subfields.label.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/metric/sub-${Subject}_hemi-${Hemisphere}_den-${Mesh}_label-hipp_curvature.shape.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/metric/sub-${Subject}_hemi-${Hemisphere}_den-${Mesh}_label-hipp_gyrification.shape.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/metric/sub-${Subject}_hemi-${Hemisphere}_den-${Mesh}_label-hipp_myelin.shape.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/metric/sub-${Subject}_hemi-${Hemisphere}}_den-${Mesh}_label-hipp_surfarea.shape.gii #Not created by default
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/metric/sub-${Subject}_hemi-${Hemisphere}_den-${Mesh}_label-hipp_thickness.shape.gii

##$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/metric/sub-${Subject}_dir-AP_hemi-${Hemisphere}_den-${Mesh}_label-dentate_desc-laplace_coords.shape.gii
##$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/metric/sub-${Subject}_dir-AP_hemi-${Hemisphere}_den-${Mesh}_label-hipp_desc-laplace_coords.shape.gii
##$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/metric/sub-${Subject}_dir-PD_hemi-${Hemisphere}_den-${Mesh}_label-dentate_desc-laplace_coords.shape.gii
##$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/metric/sub-${Subject}_dir-PD_hemi-${Hemisphere}_den-${Mesh}_label-hipp_desc-laplace_coords.shape.gii

#/media/myelin/brainmappers/Connectome_Project/YA_HCP_Final/100307/T1w/HippUnfold/T1w/hippunfold/sub-100307/surf:
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-dentate_inner.surf.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-dentate_midthickness.surf.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-dentate_outer.surf.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-hipp_inner.surf.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-hipp_midthickness.surf.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-hipp_outer.surf.gii

#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-unfold_den-${Mesh}_label-dentate_midthickness.surf.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-unfold_den-${Mesh}_label-hipp_midthickness.surf.gii

##$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_den-${Mesh}_surfaces.spec


#OLD
#Scalars
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-dentate_curvature.shape.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-dentate_gyrification.shape.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-dentate_myelin.shape.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-dentate_surfarea.shape.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-dentate_thickness.shape.gii #Not created by default
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-hipp_curvature.shape.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-hipp_gyrification.shape.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-hipp_myelin.shape.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-hipp_surfarea.shape.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-hipp_thickness.shape.gii

#Surfaces
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-dentate_inner.surf.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-dentate_midthickness.surf.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-dentate_outer.surf.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-hipp_inner.surf.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-hipp_midthickness.surf.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-hipp_outer.surf.gii

#Flat Surfaces
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-unfold_den-${Mesh}_label-dentate_midthickness.surf.gii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-unfold_den-${Mesh}_label-hipp_midthickness.surf.gii

#Labels
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-hipp_atlas-multihist7_subfields.label.gii

#Specs
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-dentate_surfaces.spec
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}den-${Mesh}_label-hipp_surfaces.spec
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Space}den-${Mesh}_label-dentate_surfaces.spec
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Space}_den-${Mesh}_label-hipp_surfaces.spec

#CIFTIScalars (recreated by the script)
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Space}_den-${Mesh}_label-dentate_curvature.dscalar.nii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Space}_den-${Mesh}_label-dentate_gyrification.dscalar.nii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Space}_den-${Mesh}_label-dentate_myelin.dscalar.nii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Space}_den-${Mesh}_label-dentate_surfarea.dscalar.nii #Not created by default
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Space}_den-${Mesh}_label-dentate_thickness.dscalar.nii #Not created by default
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Space}_den-${Mesh}_label-hipp_curvature.dscalar.nii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Space}_den-${Mesh}_label-hipp_gyrification.dscalar.nii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Space}_den-${Mesh}_label-hipp_myelin.dscalar.nii
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Space}_den-${Mesh}_label-hipp_surfarea.dscalar.nii #Not created by default
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Space}_den-${Mesh}_label-hipp_thickness.dscalar.nii

#CIFTILabels (recreated by the script)
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/surf/sub-${Subject}_space-${Space}_den-${Mesh}_label-hipp_atlas-multihist7_subfields.dlabel.nii

#VolumeLabels
#$PhysicalHippUnfoldFolderOut/hippunfold/sub-${Subject}/anat/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_desc-subfields_atlas-multihist7_dseg.nii.gz

