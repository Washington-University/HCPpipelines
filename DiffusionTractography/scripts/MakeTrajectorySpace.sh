#!/bin/bash
set -e
echo -e "\n START: MakeTrajectorySpace"
pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"

opts_SetScriptDescription "Make a trajectory space for Tractography"

opts_AddMandatory '--path' 'StudyFolder' 'folder' 'path to Generic Study folder'
opts_AddMandatory '--subject' 'Subject' 'subject' 'subject ID'
opts_AddMandatory '--folder' 'TrajectorySpaceFolder' 'folder' 'trajectory space folder'
opts_AddMandatory '--diffresol' 'DiffusionResolution' 'number' 'diffusion resolution in mm'

opts_AddOptional '--wholebrainlabels' 'WholeBrainTrajectoryLabels' 'file' 'whole brain trajectory labels'
opts_AddOptional '--leftcerebrallabels' 'LeftCerebralTrajectoryLabels' 'file' 'left cerebral trajectory labels'
opts_AddOptional '--rightcerebrallabels' 'RightCerebralTrajectoryLabels' 'file' 'right cerebral trajectory labels'

opts_AddOptional '--wholebrainsubcorticallabels' 'WholeBrainSubcorticalLabels' 'file' 'whole brain subcortical labels'
opts_AddOptional '--leftsubcorticallabels' 'LeftSubcorticalLabels' 'file' 'left subcortical labels'
opts_AddOptional '--rightsubcorticallabels' 'RightSubcorticalLabels' 'file' 'right subcortical labels'

opts_AddOptional '--wholebrainwhitelabels' 'WholeBrainWhiteLabels' 'file' 'whole brain white matter labels'
opts_AddOptional '--freesurferlabels' 'FreeSurferLabels' 'file' 'FreeSurfer labels'

opts_AddMandatory '--warp' 'Warp' 'file' 'warp from T1w to trajectory space'
opts_AddOptional '--whim' 'Whim' 'folder' 'WHIM folder'

opts_ParseArguments "$@"

opts_ShowValues

Caret7_Command=${CARET7DIR}/wb_command

TrajectorySpaceFolderCopy=$TrajectorySpaceFolder
#NamingConventions
NativeFolder="Native"
#If not T1w, adjust to T1w

if [ "$TrajectorySpaceFolder" = "T1w" ]; then
    T1wImage="T1w_acpc_dc_restore"
else
    T1wImage="T1w_restore"
fi
ROIsFolder="ROIs"
ResultsFolder="Results"
wmparc="wmparc"
ribbon="ribbon"
trajectory="Trajectory"
subcortical="SubCortical_GreyMatter"
white="WhiteMatter"

#Make Paths
TrajectorySpaceFolder="${StudyFolder}/${Subject}/${TrajectorySpaceFolder}"
ROIsFolder="${TrajectorySpaceFolder}/${ROIsFolder}"
ResultsFolder="${TrajectorySpaceFolder}/${ResultsFolder}"

if [ ! -e ${ResultsFolder} ] ; then
  mkdir ${ResultsFolder}
fi

if [ ! -e ${ROIsFolder} ] ; then
  mkdir ${ROIsFolder}
fi

if [ -e "$ROIsFolder"/temp ] ; then
  rm -r "$ROIsFolder"/temp
  mkdir "$ROIsFolder"/temp
else
  mkdir "$ROIsFolder"/temp
fi
####Note not all inputs have 1.25. We need to make that then.
#Inputs: wmparc at DiffusionResolution
#Inputs: Ribbon Volume at DiffusionResolution
##Again if not T1w, do apply warp only with xfms
###We are creating the diffusion resolution reference
if [ ! -e "$TrajectorySpaceFolder"/"$T1wImage"_"$DiffusionResolution" ] ; then
  ${FSLDIR}/bin/flirt -interp spline -in "$TrajectorySpaceFolder"/"$T1wImage".nii.gz -ref "$TrajectorySpaceFolder"/"$T1wImage".nii.gz -applyisoxfm "$DiffusionResolution" -out "$TrajectorySpaceFolder"/"$T1wImage"_"$DiffusionResolution"
fi
if [[ "$Whim" != "true" ]]; then
  if [ ! -e "${StudyFolder}"/"${Subject}"/T1w/wmparc_1mm.nii.gz ] ; then
    FreeSurferFolder="$TrajectorySpaceFolder"/"$Subject"
    mri_convert -rt nearest -rl "$TrajectorySpaceFolder"/"$T1wImage".nii.gz "$FreeSurferFolder"/mri/wmparc.mgz "$TrajectorySpaceFolder"/wmparc_1mm.nii.gz
  fi

  if [ "$TrajectorySpaceFolderCopy" = "T1w" ]; then
    ${FSLDIR}/bin/applywarp --rel --interp=nn -i "$TrajectorySpaceFolder"/wmparc_1mm.nii.gz -r "$TrajectorySpaceFolder"/"$T1wImage"_"$DiffusionResolution" --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$TrajectorySpaceFolder"/"$wmparc"_"$DiffusionResolution"
  else
    ${FSLDIR}/bin/applywarp --rel --interp=nn -i ${StudyFolder}/${Subject}/T1w/wmparc_1mm.nii.gz -r "$TrajectorySpaceFolder"/"$T1wImage"_"$DiffusionResolution" --warp="$Warp" -o "$TrajectorySpaceFolder"/"$wmparc"_"$DiffusionResolution"
  fi
  ${Caret7_Command} -volume-label-import "$TrajectorySpaceFolder"/"$wmparc"_"$DiffusionResolution".nii.gz "$FreeSurferLabels" "$TrajectorySpaceFolder"/"$wmparc"_"$DiffusionResolution".nii.gz -drop-unused-labels
fi
###That is already done in the pre script. I think for consistensy sake, we need them to provide this.

LeftGreyRibbonValue="3"
LeftWhiteMaskValue="2"
RightGreyRibbonValue="42"
RightWhiteMaskValue="41"
###OK in theory we don't need this either if we have whim. But it is also good to have??
for Hemisphere in L R ; do
  if [ $Hemisphere = "L" ] ; then
    GreyRibbonValue="$LeftGreyRibbonValue"
    WhiteMaskValue="$LeftWhiteMaskValue"
  elif [ $Hemisphere = "R" ] ; then
    GreyRibbonValue="$RightGreyRibbonValue"
    WhiteMaskValue="$RightWhiteMaskValue"
  fi    
  ${Caret7_Command} -create-signed-distance-volume "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white.native.surf.gii "$TrajectorySpaceFolder"/"$T1wImage"_"$DiffusionResolution".nii.gz "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white.native.nii.gz
  ${Caret7_Command} -create-signed-distance-volume "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial.native.surf.gii "$TrajectorySpaceFolder"/"$T1wImage"_"$DiffusionResolution".nii.gz "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial.native.nii.gz
  ${FSLDIR}/bin/fslmaths "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white.native.nii.gz -thr 0 -bin -mul 255 "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz
  ${FSLDIR}/bin/fslmaths "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz -bin "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz
  ${FSLDIR}/bin/fslmaths "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial.native.nii.gz -uthr 0 -abs -bin -mul 255 "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz
  ${FSLDIR}/bin/fslmaths "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz -bin "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz
  ${FSLDIR}/bin/fslmaths "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz -mas "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz -mul 255 "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".ribbon.nii.gz
  ${FSLDIR}/bin/fslmaths "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".ribbon.nii.gz -bin -mul $GreyRibbonValue "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".ribbon.nii.gz
  ${FSLDIR}/bin/fslmaths "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white.native.nii.gz -uthr 0 -abs -bin -mul 255 "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_uthr0.native.nii.gz
  ${FSLDIR}/bin/fslmaths "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_uthr0.native.nii.gz -bin "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_uthr0.native.nii.gz
  ${FSLDIR}/bin/fslmaths "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_uthr0.native.nii.gz -mul $WhiteMaskValue "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_mask.native.nii.gz
  ${FSLDIR}/bin/fslmaths "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".ribbon.nii.gz -add "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_mask.native.nii.gz "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".ribbon.nii.gz
  rm "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white.native.nii.gz "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial.native.nii.gz "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_uthr0.native.nii.gz "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_mask.native.nii.gz
done

${FSLDIR}/bin/fslmaths "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject".L.ribbon.nii.gz -add "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject".R.ribbon.nii.gz "$TrajectorySpaceFolder"/ribbon_"$DiffusionResolution".nii.gz
rm "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject".L.ribbon.nii.gz "$TrajectorySpaceFolder"/"$NativeFolder"/"$Subject".R.ribbon.nii.gz
${Caret7_Command} -volume-label-import "$TrajectorySpaceFolder"/ribbon_"$DiffusionResolution".nii.gz "$FreeSurferLabels" "$TrajectorySpaceFolder"/ribbon_"$DiffusionResolution".nii.gz -drop-unused-labels

${FSLDIR}/bin/fslmaths "$TrajectorySpaceFolder"/"$ribbon"_"$DiffusionResolution" -sub "$TrajectorySpaceFolder"/"$ribbon"_"$DiffusionResolution" "$ROIsFolder"/temp/trajectory
${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/trajectory -mul 1 "$ROIsFolder"/temp/delete_mask.nii.gz
${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/trajectory -mul 1 "$ROIsFolder"/temp/CC_mask.nii.gz

#LeftLateralVentricle, LeftInfLatVent, 3rdVentricle, 4thVentricle, CSF, LeftChoroidPlexus, RightLateralVentricle, RightInfLatVent, RightChoroidPlexus
wmparcStructuresToDeleteSTRING="4 5 14 15 24 31 43 44 63"
for Structure in $wmparcStructuresToDeleteSTRING ; do
  ${FSLDIR}/bin/fslmaths "$TrajectorySpaceFolder"/"$wmparc"_"$DiffusionResolution" -thr $Structure -uthr $Structure -bin "$ROIsFolder"/temp/$Structure
  ${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/$Structure -add "$ROIsFolder"/temp/delete_mask.nii.gz "$ROIsFolder"/temp/delete_mask.nii.gz
done
${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/delete_mask.nii.gz  -bin -sub 1 -mul -1 "$ROIsFolder"/temp/inverse_delete_mask.nii.gz
  
#CEREBELLAR_WHITE_MATTER_LEFT CEREBELLUM_LEFT THALAMUS_LEFT CAUDATE_LEFT PUTAMEN_LEFT PALLIDUM_LEFT BRAIN_STEM HIPPOCAMPUS_LEFT AMYGDALA_LEFT ACCUMBENS_LEFT DIENCEPHALON_VENTRAL_LEFT CEREBELLAR_WHITE_MATTER_RIGHT CEREBELLUM_RIGHT THALAMUS_RIGHT CAUDATE_RIGHT PUTAMEN_RIGHT PALLIDUM_RIGHT HIPPOCAMPUS_RIGHT AMYGDALA_RIGHT ACCUMBENS_RIGHT DIENCEPHALON_VENTRAL_RIGHT
wmparcStructuresToKeepSTRING="7 8 10 11 12 13 16 17 18 26 28 46 47 49 50 51 52 53 54 58 60"
for Structure in $wmparcStructuresToKeepSTRING ; do
  ${FSLDIR}/bin/fslmaths "$TrajectorySpaceFolder"/"$wmparc"_"$DiffusionResolution" -thr $Structure -uthr $Structure -bin "$ROIsFolder"/temp/$Structure
  ${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/$Structure -mul $Structure -add "$ROIsFolder"/temp/trajectory "$ROIsFolder"/temp/trajectory
done

${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/trajectory -bin -sub 1 -mul -1 "$ROIsFolder"/temp/inverse_trajectory_mask

#CORTEX_LEFT CEREBRAL_WHITE_MATTER_LEFT CORTEX_RIGHT CEREBRAL_WHITE_MATTER_RIGHT
RibbonStructures="2 3 41 42"
for Structure in $RibbonStructures ; do
  ${FSLDIR}/bin/fslmaths "$TrajectorySpaceFolder"/"$ribbon"_"$DiffusionResolution" -thr $Structure -uthr $Structure -bin "$ROIsFolder"/temp/$Structure
  ${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/$Structure -mas "$ROIsFolder"/temp/inverse_trajectory_mask -mul $Structure -add "$ROIsFolder"/temp/trajectory "$ROIsFolder"/temp/trajectory
done

#Fornix, CC_Posterior, CC_Mid_Posterior, CC_Central, CC_MidAnterior, CC_Anterior
CorpusCallosumToAdd="250 251 252 253 254 255"
for Structure in $CorpusCallosumToAdd ; do 
  ${FSLDIR}/bin/fslmaths "$TrajectorySpaceFolder"/"$wmparc"_"$DiffusionResolution" -thr $Structure -uthr $Structure -bin "$ROIsFolder"/temp/$Structure
  ${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/$Structure -add "$ROIsFolder"/temp/CC_mask.nii.gz "$ROIsFolder"/temp/CC_mask.nii.gz
done

${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/trajectory -bin -sub 1 -mul -1 "$ROIsFolder"/temp/inverse_trajectory_mask.nii.gz
${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/CC_mask.nii.gz -mas "$ROIsFolder"/temp/inverse_trajectory_mask.nii.gz "$ROIsFolder"/temp/CC_to_add
${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/CC_to_add -mul 2 -add "$ROIsFolder"/temp/trajectory "$ROIsFolder"/temp/trajectory
${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/trajectory -mas "$ROIsFolder"/temp/inverse_delete_mask.nii.gz "$ROIsFolder"/temp/trajectory

${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/trajectory -bin "$ROIsFolder"/Whole_Brain_"$trajectory"_ROI_"$DiffusionResolution"
${FSLDIR}/bin/fslmaths "$ROIsFolder"/Whole_Brain_"$trajectory"_ROI_"$DiffusionResolution" -sub 1 -mul -1 "$ROIsFolder"/Whole_Brain_"$trajectory"_invROI_"$DiffusionResolution"

${Caret7_Command} -volume-label-import "$ROIsFolder"/temp/trajectory.nii.gz $WholeBrainTrajectoryLabels "$TrajectorySpaceFolder"/Whole_Brain_"$trajectory"_"$DiffusionResolution".nii.gz -discard-others -unlabeled-value 0
${Caret7_Command} -volume-label-import "$ROIsFolder"/temp/trajectory.nii.gz $LeftCerebralTrajectoryLabels "$TrajectorySpaceFolder"/L_Cerebral_"$trajectory"_"$DiffusionResolution".nii.gz -discard-others -unlabeled-value 0
${Caret7_Command} -volume-label-import "$ROIsFolder"/temp/trajectory.nii.gz $RightCerebralTrajectoryLabels "$TrajectorySpaceFolder"/R_Cerebral_"$trajectory"_"$DiffusionResolution".nii.gz -discard-others -unlabeled-value 0

${Caret7_Command} -volume-label-import "$ROIsFolder"/temp/trajectory.nii.gz $WholeBrainSubcorticalLabels "$TrajectorySpaceFolder"/Whole_Brain_${subcortical}_"$DiffusionResolution".nii.gz -discard-others -unlabeled-value 0
${Caret7_Command} -volume-label-import "$ROIsFolder"/temp/trajectory.nii.gz $LeftSubcorticalLabels "$TrajectorySpaceFolder"/L_Cerebral_${subcortical}_"$DiffusionResolution".nii.gz -discard-others -unlabeled-value 0
${Caret7_Command} -volume-label-import "$ROIsFolder"/temp/trajectory.nii.gz $RightSubcorticalLabels "$TrajectorySpaceFolder"/R_Cerebral_${subcortical}_"$DiffusionResolution".nii.gz -discard-others -unlabeled-value 0

${Caret7_Command} -volume-label-import "$ROIsFolder"/temp/trajectory.nii.gz $WholeBrainWhiteLabels "$TrajectorySpaceFolder"/Whole_Brain_${white}_"$DiffusionResolution".nii.gz -discard-others -unlabeled-value 0

${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/trajectory.nii.gz -sub "$ROIsFolder"/temp/trajectory.nii.gz -add "$TrajectorySpaceFolder"/L_Cerebral_"$trajectory"_"$DiffusionResolution".nii.gz -bin "$ROIsFolder"/L_Cerebral_"$trajectory"_ROI_"$DiffusionResolution"
${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/trajectory.nii.gz -sub "$ROIsFolder"/temp/trajectory.nii.gz -add "$TrajectorySpaceFolder"/R_Cerebral_"$trajectory"_"$DiffusionResolution".nii.gz -bin "$ROIsFolder"/R_Cerebral_"$trajectory"_ROI_"$DiffusionResolution"
${FSLDIR}/bin/fslmaths "$ROIsFolder"/L_Cerebral_"$trajectory"_ROI_"$DiffusionResolution" -sub 1 -mul -1 "$ROIsFolder"/L_Cerebral_"$trajectory"_invROI_"$DiffusionResolution"
${FSLDIR}/bin/fslmaths "$ROIsFolder"/R_Cerebral_"$trajectory"_ROI_"$DiffusionResolution" -sub 1 -mul -1 "$ROIsFolder"/R_Cerebral_"$trajectory"_invROI_"$DiffusionResolution"

#Outputs: Trajectory Space (Label Volume) "$TrajectorySpaceFolder"/$trajectory_"$DiffusionResolution"
#Outputs: Trajectory Space Mask (Regular Volume)
rm -r "$ROIsFolder"/temp

echo -e "\n END: MakeTrajectorySpace"