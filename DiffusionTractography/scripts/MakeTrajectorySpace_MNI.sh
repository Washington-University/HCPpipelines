#!/bin/bash
set -e
echo -e "\n START: MakeTrajectorySpace_MNI"


########################################## SUPPORT FUNCTIONS #####################################################
# function for parsing options
getopt1() {
    sopt="$1"
    shift 1
    for fn in $@ ; do
	if [ `echo $fn | grep -- "^${sopt}=" | wc -w` -gt 0 ] ; then
	    echo $fn | sed "s/^${sopt}=//"
	    return 0
	fi
    done
}

defaultopt() {
    echo $1
}

################################################## OPTION PARSING ###################################################
# Input Variables
StudyFolder=`getopt1 "--path" $@`                # "$1" #Path to Generic Study folder
Subject=`getopt1 "--subject" $@`                 # "$2" #SubjectID
StandardResolution=`getopt1 "--standresol" $@`   # "$3" #MNI space Resolution in mm
WholeBrainTrajectoryLabels=`getopt1 "--wholebrainlabels" $@`
LeftCerebralTrajectoryLabels=`getopt1 "--leftcerebrallabels" $@`
RightCerebralTrajectoryLabels=`getopt1 "--rightcerebrallabels" $@`
FreeSurferLabels=`getopt1 "--freesurferlabels" $@`

Caret7_Command=${CARET7DIR}/wb_command

#NamingConventions
MNIFolder="MNINonLinear"
ROIsFolder="ROIs"
wmparc="wmparc"
ribbon="ribbon"
trajectory="Trajectory"

#Make Paths
MNIFolder="${StudyFolder}/${Subject}/${MNIFolder}"
ROIsFolder="${MNIFolder}/${ROIsFolder}"

if [ ! -e ${ROIsFolder} ] ; then
  mkdir ${ROIsFolder}
fi

if [ -e "$ROIsFolder"/temp ] ; then
  rm -r "$ROIsFolder"/temp
  mkdir "$ROIsFolder"/temp
else
  mkdir "$ROIsFolder"/temp
fi

#Uses pre-existing $ROIsFolder/wmparc.2.nii.gz
#Create riboon at standard 2mm resolution
${FSLDIR}/bin/flirt -interp nearestneighbour -in "${MNIFolder}"/"${ribbon}" -ref ${FSLDIR}/data/standard/MNI152_T1_2mm.nii.gz -applyisoxfm ${StandardResolution} -out "${ROIsFolder}"/ribbon."${StandardResolution}"
${Caret7_Command} -volume-label-import "$ROIsFolder"/ribbon."${StandardResolution}".nii.gz "$FreeSurferLabels" "$ROIsFolder"/ribbon."${StandardResolution}".nii.gz

${FSLDIR}/bin/fslmaths "$ROIsFolder"/ribbon."${StandardResolution}".nii.gz -sub "$ROIsFolder"/ribbon."${StandardResolution}".nii.gz "$ROIsFolder"/temp/trajectory
${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/trajectory -mul 1 "$ROIsFolder"/temp/delete_mask.nii.gz
${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/trajectory -mul 1 "$ROIsFolder"/temp/CC_mask.nii.gz

#LeftLateralVentricle, LeftInfLatVent, 3rdVentricle, 4thVentricle, CSF, LeftChoroidPlexus, RightLateralVentricle, RightInfLatVent, RightChoroidPlexus
wmparcStructuresToDeleteSTRING="4 5 14 15 24 31 43 44 63"
for Structure in $wmparcStructuresToDeleteSTRING ; do
  ${FSLDIR}/bin/fslmaths "$ROIsFolder"/"$wmparc"."$StandardResolution" -thr $Structure -uthr $Structure -bin "$ROIsFolder"/temp/$Structure
  ${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/$Structure -add "$ROIsFolder"/temp/delete_mask.nii.gz "$ROIsFolder"/temp/delete_mask.nii.gz
done
${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/delete_mask.nii.gz  -bin -sub 1 -mul -1 "$ROIsFolder"/temp/inverse_delete_mask.nii.gz
  
#CEREBELLAR_WHITE_MATTER_LEFT CEREBELLUM_LEFT THALAMUS_LEFT CAUDATE_LEFT PUTAMEN_LEFT PALLIDUM_LEFT BRAIN_STEM HIPPOCAMPUS_LEFT AMYGDALA_LEFT ACCUMBENS_LEFT DIENCEPHALON_VENTRAL_LEFT CEREBELLAR_WHITE_MATTER_RIGHT CEREBELLUM_RIGHT THALAMUS_RIGHT CAUDATE_RIGHT PUTAMEN_RIGHT PALLIDUM_RIGHT HIPPOCAMPUS_RIGHT AMYGDALA_RIGHT ACCUMBENS_RIGHT DIENCEPHALON_VENTRAL_RIGHT
wmparcStructuresToKeepSTRING="7 8 10 11 12 13 16 17 18 26 28 46 47 49 50 51 52 53 54 58 60"
for Structure in $wmparcStructuresToKeepSTRING ; do
  ${FSLDIR}/bin/fslmaths "$ROIsFolder"/"$wmparc"."$StandardResolution" -thr $Structure -uthr $Structure -bin "$ROIsFolder"/temp/$Structure
  ${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/$Structure -mul $Structure -add "$ROIsFolder"/temp/trajectory "$ROIsFolder"/temp/trajectory
done
${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/trajectory -bin -sub 1 -mul -1 "$ROIsFolder"/temp/inverse_trajectory_mask

#CORTEX_LEFT CEREBRAL_WHITE_MATTER_LEFT CORTEX_RIGHT CEREBRAL_WHITE_MATTER_RIGHT
RibbonStructures="2 3 41 42"
for Structure in $RibbonStructures ; do
  ${FSLDIR}/bin/fslmaths "${ROIsFolder}"/ribbon."${StandardResolution}" -thr $Structure -uthr $Structure -bin "$ROIsFolder"/temp/$Structure
  ${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/$Structure -mas "$ROIsFolder"/temp/inverse_trajectory_mask -mul $Structure -add "$ROIsFolder"/temp/trajectory "$ROIsFolder"/temp/trajectory
done

#Fornix, CC_Posterior, CC_Mid_Posterior, CC_Central, CC_MidAnterior, CC_Anterior
CorpusCallosumToAdd="250 251 252 253 254 255"
for Structure in $CorpusCallosumToAdd ; do 
  ${FSLDIR}/bin/fslmaths "$ROIsFolder"/"$wmparc"."$StandardResolution" -thr $Structure -uthr $Structure -bin "$ROIsFolder"/temp/$Structure
  ${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/$Structure -add "$ROIsFolder"/temp/CC_mask.nii.gz "$ROIsFolder"/temp/CC_mask.nii.gz
done

${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/trajectory -bin -sub 1 -mul -1 "$ROIsFolder"/temp/inverse_trajectory_mask.nii.gz
${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/CC_mask.nii.gz -mas "$ROIsFolder"/temp/inverse_trajectory_mask.nii.gz "$ROIsFolder"/temp/CC_to_add
${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/CC_to_add -mul 2 -add "$ROIsFolder"/temp/trajectory "$ROIsFolder"/temp/trajectory
${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/trajectory -mas "$ROIsFolder"/temp/inverse_delete_mask.nii.gz "$ROIsFolder"/temp/trajectory

${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/trajectory -bin "$ROIsFolder"/Whole_Brain_"$trajectory"_ROI_"$StandardResolution"

${Caret7_Command} -volume-label-import "$ROIsFolder"/temp/trajectory.nii.gz $WholeBrainTrajectoryLabels "$MNIFolder"/Whole_Brain_"$trajectory"_"$StandardResolution".nii.gz -discard-others -unlabeled-value 0
${Caret7_Command} -volume-label-import "$ROIsFolder"/temp/trajectory.nii.gz $LeftCerebralTrajectoryLabels "$MNIFolder"/L_Cerebral_"$trajectory"_"$StandardResolution".nii.gz -discard-others -unlabeled-value 0
${Caret7_Command} -volume-label-import "$ROIsFolder"/temp/trajectory.nii.gz $RightCerebralTrajectoryLabels "$MNIFolder"/R_Cerebral_"$trajectory"_"$StandardResolution".nii.gz -discard-others -unlabeled-value 0

${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/trajectory.nii.gz -sub "$ROIsFolder"/temp/trajectory.nii.gz -add "$MNIFolder"/L_Cerebral_"$trajectory"_"$StandardResolution".nii.gz -bin "$ROIsFolder"/L_Cerebral_"$trajectory"_ROI_"$StandardResolution"
${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/trajectory.nii.gz -sub "$ROIsFolder"/temp/trajectory.nii.gz -add "$MNIFolder"/R_Cerebral_"$trajectory"_"$StandardResolution".nii.gz -bin "$ROIsFolder"/R_Cerebral_"$trajectory"_ROI_"$StandardResolution"

rm -r "$ROIsFolder"/temp

echo -e "\n END: MakeTrajectorySpace_MNI"
