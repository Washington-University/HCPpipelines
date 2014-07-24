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
LowResMesh=`getopt1 "--lowresmesh" $@`

Caret7_Command="${CARET7DIR}/wb_command"

#NamingConventions
MNIFolder="MNINonLinear"
ROIsFolder="ROIs"
wmparc="wmparc"
ribbon="ribbon"
trajectory="Trajectory"

#Make Paths
MNIFolder="${StudyFolder}/${Subject}/${MNIFolder}"
ROIsFolder="${MNIFolder}/${ROIsFolder}"
ResultsFolder="${MNIFolder}/Results/Tractography"
DownSampleFolder="${MNIFolder}/fsaverage_LR${LowResMesh}k"

if [ ! -e ${ResultsFolder} ] ; then
  mkdir -p ${ResultsFolder}
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


#Extract atlas-derived ROIs that can be used as subcortical volume seeds. 
ROIStructuresToSeed="26 58 18 54 16 11 50 8 47 28 60 17 53 13 52 12 51 10 49"
ROINames=("ACCUMBENS_LEFT" "ACCUMBENS_RIGHT" "AMYGDALA_LEFT" "AMYGDALA_RIGHT" "BRAIN_STEM" "CAUDATE_LEFT" "CAUDATE_RIGHT" "CEREBELLUM_LEFT" "CEREBELLUM_RIGHT" "DIENCEPHALON_VENTRAL_LEFT" "DIENCEPHALON_VENTRAL_RIGHT" "HIPPOCAMPUS_LEFT" "HIPPOCAMPUS_RIGHT" "PALLIDUM_LEFT" "PALLIDUM_RIGHT" "PUTAMEN_LEFT" "PUTAMEN_RIGHT" "THALAMUS_LEFT" "THALAMUS_RIGHT")
count=0
for Structure in $ROIStructuresToSeed ; do 
    ${FSLDIR}/bin/fslmaths "$ROIsFolder"/"Atlas_ROIs.${StandardResolution}" -thr $Structure -uthr $Structure -bin "$ResultsFolder"/CIFTI_STRUCTURE_${ROINames[$count]}
    #${FSLDIR}/bin/fslmaths "$ResultsFolder"/CIFTI_STRUCTURE_${ROINames[$count]} -kernel gauss 2 -ero "$ResultsFolder"/CIFTI_STRUCTURE_Ero_${ROINames[$count]}
    count=$(( $count + 1 ))
done


#Extract subject-specific, Freesurfer-obtained ROIs that can be used as subcortical volume seeds. 
#Notice that ROIs.2 file has been obtained from wmparc.2 (i.e. Freesurfer pipeline)
count=0
for Structure in $ROIStructuresToSeed ; do 
    ${FSLDIR}/bin/fslmaths "$ROIsFolder"/ROIs."$StandardResolution" -thr $Structure -uthr $Structure -bin "$ResultsFolder"/STRUCTURE_${ROINames[$count]}
    #${FSLDIR}/bin/fslmaths "$ResultsFolder"/STRUCTURE_${ROINames[$count]} -kernel gauss 2 -ero "$ResultsFolder"/STRUCTURE_Ero_${ROINames[$count]}
    count=$(( $count + 1 ))
done


#Create Subject-specific Greyordinate dense scalar 
${Caret7_Command} -cifti-create-dense-scalar "$ResultsFolder"/Subject_Greyordinates.dscalar.nii -volume "$ROIsFolder"/ROIs."$StandardResolution".nii.gz "$ROIsFolder"/ROIs."$StandardResolution".nii.gz -left-metric ${DownSampleFolder}/${Subject}.L.atlasroi.${LowResMesh}k_fs_LR.shape.gii -roi-left ${DownSampleFolder}/${Subject}.L.atlasroi.${LowResMesh}k_fs_LR.shape.gii -right-metric ${DownSampleFolder}/${Subject}.R.atlasroi.${LowResMesh}k_fs_LR.shape.gii -roi-right ${DownSampleFolder}/${Subject}.R.atlasroi.${LowResMesh}k_fs_LR.shape.gii

#Export Subject-specific volume voxel_list
${Caret7_Command} -cifti-export-dense-mapping "$ResultsFolder"/Subject_Greyordinates.dscalar.nii COLUMN -volume-all $ROIsFolder/ROIs.$StandardResolution.voxel_list.txt -no-cifti-index


#Create Probtrackx-Compatible Pial and White-matter Surfaces
${FSLDIR}/bin/surf2surf -i ${DownSampleFolder}/${Subject}.L.white.${LowResMesh}k_fs_LR.surf.gii -o ${ResultsFolder}/white.L.asc --outputtype=ASCII --values=${DownSampleFolder}/${Subject}.L.atlasroi.${LowResMesh}k_fs_LR.shape.gii
${FSLDIR}/bin/surf2surf -i ${DownSampleFolder}/${Subject}.R.white.${LowResMesh}k_fs_LR.surf.gii -o ${ResultsFolder}/white.R.asc --outputtype=ASCII --values=${DownSampleFolder}/${Subject}.R.atlasroi.${LowResMesh}k_fs_LR.shape.gii
${FSLDIR}/bin/surf2surf -i ${DownSampleFolder}/${Subject}.L.pial.${LowResMesh}k_fs_LR.surf.gii -o ${ResultsFolder}/pial.L.asc --outputtype=ASCII --values=${DownSampleFolder}/${Subject}.L.atlasroi.${LowResMesh}k_fs_LR.shape.gii
${FSLDIR}/bin/surf2surf -i ${DownSampleFolder}/${Subject}.R.pial.${LowResMesh}k_fs_LR.surf.gii -o ${ResultsFolder}/pial.R.asc --outputtype=ASCII --values=${DownSampleFolder}/${Subject}.R.atlasroi.${LowResMesh}k_fs_LR.shape.gii

echo -e "\n END: MakeTrajectorySpace_MNI"
