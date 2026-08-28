#!/bin/bash
set -eu
pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
  # pipedirguessed=1
   #fix this if the script is more than one level below HCPPIPEDIR
   export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@" # Debugging functions; also sources log.shlib
source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"


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

if [[ -z "${PhysicalHippUnfoldDIR:-}" ]] ; then
PhysicalHippUnfoldDIR="${T1wFolder}/HippUnfold"
fi

if [[ -z "${AtlasHippUnfoldDIR:-}" ]] ; then
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
  if [ ${Type} = "metric" ] ; then
    ${wb_command} -metric-palette "$File" MODE_AUTO_SCALE_PERCENTAGE ${command}
  elif [ ${Type} = "cifti" ] ; then
    ${wb_command} -cifti-palette "$File" MODE_AUTO_SCALE_PERCENTAGE "$File" ${command}
  fi
}

for Mesh in native 512 2k 8k 18k ; do

  PhysicalHippUnfoldFolderOut="${PhysicalHippUnfoldDIR}/"
  AtlasHippUnfoldFolderOut="${AtlasHippUnfoldDIR}/"

  PhysicalHippUnfoldFolder="${PhysicalHippUnfoldFolderOut}${Mesh}"
  AtlasHippUnfoldFolder="${AtlasHippUnfoldFolderOut}${Mesh}"

  mkdir -p "$PhysicalHippUnfoldFolder" "$AtlasHippUnfoldFolder"

  log_Msg "Processing $Mesh"

  Space="T2w"

  Structures="dentate hipp"
  Surfaces="inner@INNER midthickness@MIDTHICKNESS outer@OUTER"
  Scalars="curvature@GRAY@Curvature gyrification@GRAY@Gyrification surfarea@VIDEEN@SurfaceArea thickness@VIDEEN@Thickness myelin@VIDEEN@MyelinMap"
  Labels="atlas-multihist7_subfields@HippocampalSubfields"

  for Structure in $Structures ; do
    for Hemisphere in L R ; do
      #Surface area is no longer computed by HippUnfold
      ${CARET7DIR}/wb_command -surface-vertex-areas \
        "${RawHippUnfoldFolder}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-${Structure}_midthickness.surf.gii" \
        "${RawHippUnfoldFolder}/metric/sub-${Subject}_hemi-${Hemisphere}_den-${Mesh}_label-${Structure}_surfarea.shape.gii"
    done

    if [ "${Structure}" = "dentate" ] ; then
      Left="HIPPOCAMPUS_DENTATE_LEFT"
      Right="HIPPOCAMPUS_DENTATE_RIGHT"
    elif [ "${Structure}" = "hipp" ] ; then
      Left="HIPPOCAMPUS_LEFT"
      Right="HIPPOCAMPUS_RIGHT"
    fi

    for Hemisphere in L R ; do
      if [ "${Hemisphere}" = "L" ] ; then
        if [ "${Structure}" = "dentate" ] ; then
          HemiStructure="HIPPOCAMPUS_DENTATE_LEFT"
        elif [ "${Structure}" = "hipp" ] ; then
          HemiStructure="HIPPOCAMPUS_LEFT"
        fi
      elif [ "${Hemisphere}" = "R" ] ; then
        if [ "${Structure}" = "dentate" ] ; then
          HemiStructure="HIPPOCAMPUS_DENTATE_RIGHT"
        elif [ "${Structure}" = "hipp" ] ; then
          HemiStructure="HIPPOCAMPUS_RIGHT"
        fi
      fi

      #Anatomical Surfaces
      for SurfaceEntry in $Surfaces ; do
        SurfaceType=$(echo "$SurfaceEntry" | cut -d "@" -f 2)
        Surface=$(echo "$SurfaceEntry" | cut -d "@" -f 1)

        cp "${RawHippUnfoldFolder}/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-${Structure}_${Surface}.surf.gii" \
          "${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.${Mesh}.surf.gii"

        ${CARET7DIR}/wb_command -set-structure \
          "${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.${Mesh}.surf.gii" \
          "${HemiStructure}" \
          -surface-type ANATOMICAL \
          -surface-secondary-type "${SurfaceType}"

        ${CARET7DIR}/wb_command -add-to-spec-file \
          "${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec" \
          "${HemiStructure}" \
          "${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.${Mesh}.surf.gii"

        ${CARET7DIR}/wb_command -surface-apply-warpfield \
          "${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.${Mesh}.surf.gii" \
          "${AtlasFolder}/xfms/standard2acpc_dc.nii.gz" \
          "${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.${Mesh}.surf.gii" \
          -fnirt "${AtlasFolder}/T1w_restore.nii.gz"

        ${CARET7DIR}/wb_command -add-to-spec-file \
          "${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec" \
          "${HemiStructure}" \
          "${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.${Mesh}.surf.gii"
      done

      #Flat Surfaces
      cp "${RawHippUnfoldFolder}/surf/sub-${Subject}_hemi-${Hemisphere}_space-unfold_den-${Mesh}_label-${Structure}_midthickness.surf.gii" \
        "${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_flat.${Mesh}.surf.gii"

      ${CARET7DIR}/wb_command -set-structure \
        "${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_flat.${Mesh}.surf.gii" \
        "${HemiStructure}" \
        -surface-type FLAT

      ${CARET7DIR}/wb_command -add-to-spec-file \
        "${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec" \
        "${HemiStructure}" \
        "${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_flat.${Mesh}.surf.gii"

      cp "${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_flat.${Mesh}.surf.gii" \
        "${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_flat.${Mesh}.surf.gii"

      ${CARET7DIR}/wb_command -add-to-spec-file \
        "${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec" \
        "${HemiStructure}" \
        "${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_flat.${Mesh}.surf.gii"

      #GIFTI Metrics
      #Don't add GIFTI to Specs
      for ScalarEntry in $Scalars ; do
        Name=$(echo "$ScalarEntry" | cut -d "@" -f 3)
        Color=$(echo "$ScalarEntry" | cut -d "@" -f 2)
        Scalar=$(echo "$ScalarEntry" | cut -d "@" -f 1)

        cp "${RawHippUnfoldFolder}/metric/sub-${Subject}_hemi-${Hemisphere}_den-${Mesh}_label-${Structure}_${Scalar}.shape.gii" \
          "${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii"

        ${CARET7DIR}/wb_command -set-structure \
          "${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii" \
          "${HemiStructure}"

        PALETTE \
          "${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii" \
          "${Color}" \
          metric \
          "${CARET7DIR}/wb_command"

        ${CARET7DIR}/wb_command -set-map-names \
          "${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii" \
          -map 1 "${Subject}_${Name}"

        if [ "${Scalar}" = "surfarea" ] ; then
          ${CARET7DIR}/wb_command \
            -surface-vertex-areas \
            "${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_midthickness.${Mesh}.surf.gii" \
            "${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii"
        else
          cp \
            "${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii" \
            "${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii"
        fi
      done

      #GIFTI Labels
      #Don't add GIFTI to Specs
      for LabelEntry in $Labels ; do
        Name=$(echo "$LabelEntry" | cut -d "@" -f 2)
        Label=$(echo "$LabelEntry" | cut -d "@" -f 1)

        if [ "${Structure}" = "hipp" ] ; then
          if [ "${Hemisphere}" = "L" ] ; then
            Expression="Var"
          elif [ "${Hemisphere}" = "R" ] ; then
            Expression="Var + 8"
          fi

          ${CARET7DIR}/wb_command -metric-math \
            "${Expression}" \
            "${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.shape.gii" \
            -var Var \
            "${RawHippUnfoldFolder}/metric/sub-${Subject}_hemi-${Hemisphere}_den-${Mesh}_label-${Structure}_${Label}.label.gii" \
            |& grep -v NIFTI_INTENT_LABEL

          ${CARET7DIR}/wb_command \
            -metric-label-import \
            "${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.shape.gii" \
            "$HCPPIPEDIR/global/config/HippUnfoldLut.txt" \
            "${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.label.gii"

        elif [ "${Structure}" = "dentate" ] ; then
          if [ "${Hemisphere}" = "L" ] ; then
            Expression="6"
          elif [ "${Hemisphere}" = "R" ] ; then
            Expression="6 + 8"
          fi

          ${CARET7DIR}/wb_command \
            -metric-math \
            "${Expression}" \
            "${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.shape.gii" \
            -var Var \
            "${RawHippUnfoldFolder}/metric/sub-${Subject}_hemi-${Hemisphere}_den-${Mesh}_label-${Structure}_thickness.shape.gii" \
            |& grep -v NIFTI_INTENT_LABEL

          ${CARET7DIR}/wb_command \
            -metric-label-import \
            "${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.shape.gii" \
            "$HCPPIPEDIR/global/config/HippUnfoldLut.txt" \
            "${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.label.gii"
        fi

        ${CARET7DIR}/wb_command \
          -set-structure \
          "${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.label.gii" \
          "${HemiStructure}"

        ${CARET7DIR}/wb_command \
          -set-map-names \
          "${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.label.gii" \
          -map 1 "${Subject}_${Name}"

        cp \
          "${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.label.gii" \
          "${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.label.gii"
      done

      #NIFTI Hemispheric Labels
      cp \
        "${RawHippUnfoldFolder}/anat/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_label-hipp_desc-subfields_atlas-multihist7_dseg.nii.gz" \
        "${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.HippocampalSubfields.nii.gz"
    done
  done

  #CIFTI Scalars
  for ScalarEntry in $Scalars ; do
    Name=$(echo "$ScalarEntry" | cut -d "@" -f 3)
    Color=$(echo "$ScalarEntry" | cut -d "@" -f 2)
    Scalar=$(echo "$ScalarEntry" | cut -d "@" -f 1)

    ${CARET7DIR}/wb_command \
      -cifti-create-dense-scalar \
      "${PhysicalHippUnfoldFolder}/${Subject}.hippocampus_${Scalar}.${Mesh}.dscalar.nii" \
      -metric HIPPOCAMPUS_LEFT \
      "${PhysicalHippUnfoldFolder}/${Subject}.L.hipp_${Scalar}.${Mesh}.shape.gii" \
      -metric HIPPOCAMPUS_RIGHT \
      "${PhysicalHippUnfoldFolder}/${Subject}.R.hipp_${Scalar}.${Mesh}.shape.gii" \
      -metric HIPPOCAMPUS_DENTATE_LEFT \
      "${PhysicalHippUnfoldFolder}/${Subject}.L.dentate_${Scalar}.${Mesh}.shape.gii" \
      -metric HIPPOCAMPUS_DENTATE_RIGHT \
      "${PhysicalHippUnfoldFolder}/${Subject}.R.dentate_${Scalar}.${Mesh}.shape.gii"

    PALETTE \
      "${PhysicalHippUnfoldFolder}/${Subject}.hippocampus_${Scalar}.${Mesh}.dscalar.nii" \
      "${Color}" \
      cifti \
      "${CARET7DIR}/wb_command"

    ${CARET7DIR}/wb_command \
      -set-map-names \
      "${PhysicalHippUnfoldFolder}/${Subject}.hippocampus_${Scalar}.${Mesh}.dscalar.nii" \
      -map 1 "${Subject}_${Name}"

    ${CARET7DIR}/wb_command \
      -add-to-spec-file \
      "${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec" \
      INVALID \
      "${PhysicalHippUnfoldFolder}/${Subject}.hippocampus_${Scalar}.${Mesh}.dscalar.nii"

    cp \
      "${PhysicalHippUnfoldFolder}/${Subject}.hippocampus_${Scalar}.${Mesh}.dscalar.nii" \
      "${AtlasHippUnfoldFolder}/${Subject}.hippocampus_${Scalar}.${Mesh}.dscalar.nii"

    ${CARET7DIR}/wb_command \
      -add-to-spec-file \
      "${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec" \
      INVALID \
      "${AtlasHippUnfoldFolder}/${Subject}.hippocampus_${Scalar}.${Mesh}.dscalar.nii"
  done

  #CIFTI Labels
  for LabelEntry in $Labels ; do
    Name=$(echo "$LabelEntry" | cut -d "@" -f 2)
    Label=$(echo "$LabelEntry" | cut -d "@" -f 1)

    ${CARET7DIR}/wb_command \
      -cifti-create-label \
      "${PhysicalHippUnfoldFolder}/${Subject}.hippocampus_${Label}.${Mesh}.dlabel.nii" \
      -label HIPPOCAMPUS_LEFT \
      "${PhysicalHippUnfoldFolder}/${Subject}.L.hipp_${Label}.${Mesh}.label.gii" \
      -label HIPPOCAMPUS_RIGHT \
      "${PhysicalHippUnfoldFolder}/${Subject}.R.hipp_${Label}.${Mesh}.label.gii" \
      -label HIPPOCAMPUS_DENTATE_LEFT \
      "${PhysicalHippUnfoldFolder}/${Subject}.L.dentate_${Label}.${Mesh}.label.gii" \
      -label HIPPOCAMPUS_DENTATE_RIGHT \
      "${PhysicalHippUnfoldFolder}/${Subject}.R.dentate_${Label}.${Mesh}.label.gii"

    ${CARET7DIR}/wb_command \
      -set-map-names \
      "${PhysicalHippUnfoldFolder}/${Subject}.hippocampus_${Label}.${Mesh}.dlabel.nii" \
      -map 1 "${Subject}_${Name}"

    ${CARET7DIR}/wb_command \
      -add-to-spec-file \
      "${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec" \
      INVALID \
      "${PhysicalHippUnfoldFolder}/${Subject}.hippocampus_${Label}.${Mesh}.dlabel.nii"

    cp \
      "${PhysicalHippUnfoldFolder}/${Subject}.hippocampus_${Label}.${Mesh}.dlabel.nii" \
      "${AtlasHippUnfoldFolder}/${Subject}.hippocampus_${Label}.${Mesh}.dlabel.nii"

    ${CARET7DIR}/wb_command \
      -add-to-spec-file \
      "${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec" \
      INVALID \
      "${AtlasHippUnfoldFolder}/${Subject}.hippocampus_${Label}.${Mesh}.dlabel.nii"
  done

  #NIFTI Label Volumes
  fslmaths \
    "${PhysicalHippUnfoldFolder}/${Subject}.R.HippocampalSubfields.nii.gz" \
    -add 8 \
    -mas "${PhysicalHippUnfoldFolder}/${Subject}.R.HippocampalSubfields.nii.gz" \
    -add "${PhysicalHippUnfoldFolder}/${Subject}.L.HippocampalSubfields.nii.gz" \
    "${PhysicalHippUnfoldFolder}/${Subject}.HippocampalSubfields.nii.gz"

  ${CARET7DIR}/wb_command \
    -volume-label-import \
    "${PhysicalHippUnfoldFolder}/${Subject}.HippocampalSubfields.nii.gz" \
    "$HCPPIPEDIR/global/config/HippUnfoldLut.txt" \
    "${PhysicalHippUnfoldFolder}/${Subject}.HippocampalSubfields.nii.gz"

  rm \
    "${PhysicalHippUnfoldFolder}/${Subject}.L.HippocampalSubfields.nii.gz" \
    "${PhysicalHippUnfoldFolder}/${Subject}.R.HippocampalSubfields.nii.gz"

  ${CARET7DIR}/wb_command \
    -add-to-spec-file \
    "${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec" \
    INVALID \
    "${PhysicalHippUnfoldFolder}/${Subject}.HippocampalSubfields.nii.gz"

  ${CARET7DIR}/wb_command \
    -volume-resample \
    "${PhysicalHippUnfoldFolder}/${Subject}.HippocampalSubfields.nii.gz" \
    "${AtlasFolder}/T1w_restore.nii.gz" \
    ENCLOSING_VOXEL \
    "${AtlasHippUnfoldFolder}/${Subject}.HippocampalSubfields.nii.gz" \
    -warp "${AtlasFolder}/xfms/acpc_dc2standard.nii.gz" \
    -fnirt "${AtlasFolder}/T1w_restore.nii.gz"

  ${CARET7DIR}/wb_command \
    -add-to-spec-file \
    "${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec" \
    INVALID \
    "${AtlasHippUnfoldFolder}/${Subject}.HippocampalSubfields.nii.gz"

  #NIFTI Input Volumes
  ${CARET7DIR}/wb_command \
    -add-to-spec-file \
    "${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec" \
    INVALID \
    "${T1wFolder}/T1w_acpc_dc_restore.nii.gz"

  ${CARET7DIR}/wb_command \
    -add-to-spec-file \
    "${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec" \
    INVALID \
    "${T1wFolder}/T2w_acpc_dc_restore.nii.gz"

  ${CARET7DIR}/wb_command \
    -add-to-spec-file \
    "${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec" \
    INVALID \
    "${AtlasFolder}/T1w_restore.nii.gz"

  ${CARET7DIR}/wb_command \
    -add-to-spec-file \
    "${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec" \
    INVALID \
    "${AtlasFolder}/T2w_restore.nii.gz"

  #TODO: Anything with 8k and 18k meshes?
  if [ "${Mesh}" = "native" ] ; then
    ${CARET7DIR}/wb_command \
      -spec-file-merge \
      "${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec" \
      "${T1wFolder}/Native/${Subject}.native.wb.spec" \
      "${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.native.wb_spec"

    ${CARET7DIR}/wb_command \
      -spec-file-merge \
      "${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec" \
      "${AtlasFolder}/Native/${Subject}.native.wb.spec" \
      "${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.native.wb_spec"

  elif [ "${Mesh}" = "512" ] ; then
    ${CARET7DIR}/wb_command \
      -spec-file-merge \
      "${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec" \
      "${T1wFolder}/fsaverage_LR32k/${Subject}.MSMAll.32k_fs_LR.wb.spec" \
      "${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.MSMAll.32k.wb_spec"

    ${CARET7DIR}/wb_command \
      -spec-file-merge \
      "${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec" \
      "${AtlasFolder}/fsaverage_LR32k/${Subject}.MSMAll.32k_fs_LR.wb.spec" \
      "${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.MSMAll.32k.wb_spec"

  elif [ "${Mesh}" = "2k" ] ; then
    ${CARET7DIR}/wb_command \
      -spec-file-merge \
      "${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec" \
      "${AtlasFolder}/${Subject}.MSMAll.164k_fs_LR.wb.spec" \
      "${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.MSMAll.164k.wb_spec"
  fi
done

log_Msg "PostHippUnfold pipeline completed successfully for subject: $Subject"
