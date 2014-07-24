#!/bin/bash
set -e
echo -e "\n START: MakeTrajectorySpace"

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
DiffusionResolution=`getopt1 "--diffresol" $@`   # "$3" #Diffusion Resolution in mm
WholeBrainTrajectoryLabels=`getopt1 "--wholebrainlabels" $@`
LeftCerebralTrajectoryLabels=`getopt1 "--leftcerebrallabels" $@`
RightCerebralTrajectoryLabels=`getopt1 "--rightcerebrallabels" $@`
FreeSurferLabels=`getopt1 "--freesurferlabels" $@`

Caret7_Command="${CARET7DIR}/wb_command"

#NamingConventions
T1wFolder="T1w"
NativeFolder="Native"
T1wImage="T1w_acpc_dc_restore"
ROIsFolder="ROIs"
ResultsFolder="Results"
wmparc="wmparc"
ribbon="ribbon"
trajectory="Trajectory"

#Make Paths
T1wFolder="${StudyFolder}/${Subject}/${T1wFolder}"
ROIsFolder="${T1wFolder}/${ROIsFolder}"
ResultsFolder="${T1wFolder}/${ResultsFolder}"

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

#Inputs: wmparc at DiffusionResolution
#Inputs: Ribbon Volume at DiffusionResolution

${FSLDIR}/bin/applywarp --rel --interp=nn -i "$T1wFolder"/wmparc.nii.gz -r "$T1wFolder"/"$T1wImage"_"$DiffusionResolution" --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$T1wFolder"/"$wmparc"_"$DiffusionResolution"
${Caret7_Command} -volume-label-import "$T1wFolder"/"$wmparc"_"$DiffusionResolution".nii.gz "$FreeSurferLabels" "$T1wFolder"/"$wmparc"_"$DiffusionResolution".nii.gz 

LeftGreyRibbonValue="3"
LeftWhiteMaskValue="2"
RightGreyRibbonValue="42"
RightWhiteMaskValue="41"

for Hemisphere in L R ; do
  if [ $Hemisphere = "L" ] ; then
    GreyRibbonValue="$LeftGreyRibbonValue"
    WhiteMaskValue="$LeftWhiteMaskValue"
  elif [ $Hemisphere = "R" ] ; then
    GreyRibbonValue="$RightGreyRibbonValue"
    WhiteMaskValue="$RightWhiteMaskValue"
  fi    
  ${Caret7_Command} -create-signed-distance-volume "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white.native.surf.gii "$T1wFolder"/"$T1wImage"_"$DiffusionResolution".nii.gz "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white.native.nii.gz
  ${Caret7_Command} -create-signed-distance-volume "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial.native.surf.gii "$T1wFolder"/"$T1wImage"_"$DiffusionResolution".nii.gz "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial.native.nii.gz
  ${FSLDIR}/bin/fslmaths "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white.native.nii.gz -thr 0 -bin -mul 255 "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz
  ${FSLDIR}/bin/fslmaths "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz -bin "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz
  ${FSLDIR}/bin/fslmaths "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial.native.nii.gz -uthr 0 -abs -bin -mul 255 "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz
  ${FSLDIR}/bin/fslmaths "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz -bin "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz
  ${FSLDIR}/bin/fslmaths "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz -mas "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz -mul 255 "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".ribbon.nii.gz
  ${FSLDIR}/bin/fslmaths "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".ribbon.nii.gz -bin -mul $GreyRibbonValue "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".ribbon.nii.gz
  ${FSLDIR}/bin/fslmaths "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white.native.nii.gz -uthr 0 -abs -bin -mul 255 "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_uthr0.native.nii.gz
  ${FSLDIR}/bin/fslmaths "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_uthr0.native.nii.gz -bin "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_uthr0.native.nii.gz
  ${FSLDIR}/bin/fslmaths "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_uthr0.native.nii.gz -mul $WhiteMaskValue "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_mask.native.nii.gz
  ${FSLDIR}/bin/fslmaths "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".ribbon.nii.gz -add "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_mask.native.nii.gz "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".ribbon.nii.gz
  rm "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white.native.nii.gz "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_thr0.native.nii.gz "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial.native.nii.gz "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial_uthr0.native.nii.gz "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_uthr0.native.nii.gz "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white_mask.native.nii.gz
done

${FSLDIR}/bin/fslmaths "$T1wFolder"/"$NativeFolder"/"$Subject".L.ribbon.nii.gz -add "$T1wFolder"/"$NativeFolder"/"$Subject".R.ribbon.nii.gz "$T1wFolder"/ribbon_"$DiffusionResolution".nii.gz
rm "$T1wFolder"/"$NativeFolder"/"$Subject".L.ribbon.nii.gz "$T1wFolder"/"$NativeFolder"/"$Subject".R.ribbon.nii.gz
${Caret7_Command} -volume-label-import "$T1wFolder"/ribbon_"$DiffusionResolution".nii.gz "$FreeSurferLabels" "$T1wFolder"/ribbon_"$DiffusionResolution".nii.gz 

${FSLDIR}/bin/fslmaths "$T1wFolder"/"$ribbon"_"$DiffusionResolution" -sub "$T1wFolder"/"$ribbon"_"$DiffusionResolution" "$ROIsFolder"/temp/trajectory
${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/trajectory -mul 1 "$ROIsFolder"/temp/delete_mask.nii.gz
${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/trajectory -mul 1 "$ROIsFolder"/temp/CC_mask.nii.gz

#LeftLateralVentricle, LeftInfLatVent, 3rdVentricle, 4thVentricle, CSF, LeftChoroidPlexus, RightLateralVentricle, RightInfLatVent, RightChoroidPlexus
wmparcStructuresToDeleteSTRING="4 5 14 15 24 31 43 44 63"
for Structure in $wmparcStructuresToDeleteSTRING ; do
  ${FSLDIR}/bin/fslmaths "$T1wFolder"/"$wmparc"_"$DiffusionResolution" -thr $Structure -uthr $Structure -bin "$ROIsFolder"/temp/$Structure
  ${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/$Structure -add "$ROIsFolder"/temp/delete_mask.nii.gz "$ROIsFolder"/temp/delete_mask.nii.gz
done
${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/delete_mask.nii.gz  -bin -sub 1 -mul -1 "$ROIsFolder"/temp/inverse_delete_mask.nii.gz
  
#CEREBELLAR_WHITE_MATTER_LEFT CEREBELLUM_LEFT THALAMUS_LEFT CAUDATE_LEFT PUTAMEN_LEFT PALLIDUM_LEFT BRAIN_STEM HIPPOCAMPUS_LEFT AMYGDALA_LEFT ACCUMBENS_LEFT DIENCEPHALON_VENTRAL_LEFT CEREBELLAR_WHITE_MATTER_RIGHT CEREBELLUM_RIGHT THALAMUS_RIGHT CAUDATE_RIGHT PUTAMEN_RIGHT PALLIDUM_RIGHT HIPPOCAMPUS_RIGHT AMYGDALA_RIGHT ACCUMBENS_RIGHT DIENCEPHALON_VENTRAL_RIGHT
wmparcStructuresToKeepSTRING="7 8 10 11 12 13 16 17 18 26 28 46 47 49 50 51 52 53 54 58 60"
for Structure in $wmparcStructuresToKeepSTRING ; do
  ${FSLDIR}/bin/fslmaths "$T1wFolder"/"$wmparc"_"$DiffusionResolution" -thr $Structure -uthr $Structure -bin "$ROIsFolder"/temp/$Structure
  ${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/$Structure -mul $Structure -add "$ROIsFolder"/temp/trajectory "$ROIsFolder"/temp/trajectory
done

${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/trajectory -bin -sub 1 -mul -1 "$ROIsFolder"/temp/inverse_trajectory_mask

#CORTEX_LEFT CEREBRAL_WHITE_MATTER_LEFT CORTEX_RIGHT CEREBRAL_WHITE_MATTER_RIGHT
RibbonStructures="2 3 41 42"
for Structure in $RibbonStructures ; do
  ${FSLDIR}/bin/fslmaths "$T1wFolder"/"$ribbon"_"$DiffusionResolution" -thr $Structure -uthr $Structure -bin "$ROIsFolder"/temp/$Structure
  ${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/$Structure -mas "$ROIsFolder"/temp/inverse_trajectory_mask -mul $Structure -add "$ROIsFolder"/temp/trajectory "$ROIsFolder"/temp/trajectory
done

#Fornix, CC_Posterior, CC_Mid_Posterior, CC_Central, CC_MidAnterior, CC_Anterior
CorpusCallosumToAdd="250 251 252 253 254 255"
for Structure in $CorpusCallosumToAdd ; do 
  ${FSLDIR}/bin/fslmaths "$T1wFolder"/"$wmparc"_"$DiffusionResolution" -thr $Structure -uthr $Structure -bin "$ROIsFolder"/temp/$Structure
  ${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/$Structure -add "$ROIsFolder"/temp/CC_mask.nii.gz "$ROIsFolder"/temp/CC_mask.nii.gz
done

${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/trajectory -bin -sub 1 -mul -1 "$ROIsFolder"/temp/inverse_trajectory_mask.nii.gz
${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/CC_mask.nii.gz -mas "$ROIsFolder"/temp/inverse_trajectory_mask.nii.gz "$ROIsFolder"/temp/CC_to_add
${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/CC_to_add -mul 2 -add "$ROIsFolder"/temp/trajectory "$ROIsFolder"/temp/trajectory
${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/trajectory -mas "$ROIsFolder"/temp/inverse_delete_mask.nii.gz "$ROIsFolder"/temp/trajectory

${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/trajectory -bin "$ROIsFolder"/Whole_Brain_"$trajectory"_ROI_"$DiffusionResolution"
${FSLDIR}/bin/fslmaths "$ROIsFolder"/Whole_Brain_"$trajectory"_ROI_"$DiffusionResolution" -sub 1 -mul -1 "$ROIsFolder"/Whole_Brain_"$trajectory"_invROI_"$DiffusionResolution"

${Caret7_Command} -volume-label-import "$ROIsFolder"/temp/trajectory.nii.gz $WholeBrainTrajectoryLabels "$T1wFolder"/Whole_Brain_"$trajectory"_"$DiffusionResolution".nii.gz -discard-others -unlabeled-value 0
${Caret7_Command} -volume-label-import "$ROIsFolder"/temp/trajectory.nii.gz $LeftCerebralTrajectoryLabels "$T1wFolder"/L_Cerebral_"$trajectory"_"$DiffusionResolution".nii.gz -discard-others -unlabeled-value 0
${Caret7_Command} -volume-label-import "$ROIsFolder"/temp/trajectory.nii.gz $RightCerebralTrajectoryLabels "$T1wFolder"/R_Cerebral_"$trajectory"_"$DiffusionResolution".nii.gz -discard-others -unlabeled-value 0

${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/trajectory.nii.gz -sub "$ROIsFolder"/temp/trajectory.nii.gz -add "$T1wFolder"/L_Cerebral_"$trajectory"_"$DiffusionResolution".nii.gz -bin "$ROIsFolder"/L_Cerebral_"$trajectory"_ROI_"$DiffusionResolution"
${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/trajectory.nii.gz -sub "$ROIsFolder"/temp/trajectory.nii.gz -add "$T1wFolder"/R_Cerebral_"$trajectory"_"$DiffusionResolution".nii.gz -bin "$ROIsFolder"/R_Cerebral_"$trajectory"_ROI_"$DiffusionResolution"
${FSLDIR}/bin/fslmaths "$ROIsFolder"/L_Cerebral_"$trajectory"_ROI_"$DiffusionResolution" -sub 1 -mul -1 "$ROIsFolder"/L_Cerebral_"$trajectory"_invROI_"$DiffusionResolution"
${FSLDIR}/bin/fslmaths "$ROIsFolder"/R_Cerebral_"$trajectory"_ROI_"$DiffusionResolution" -sub 1 -mul -1 "$ROIsFolder"/R_Cerebral_"$trajectory"_invROI_"$DiffusionResolution"

#Outputs: Trajectory Space (Label Volume) "$T1wFolder"/$trajectory_"$DiffusionResolution"
#Outputs: Trajectory Space Mask (Regular Volume)
rm -r "$ROIsFolder"/temp

echo -e "\n END: MakeTrajectorySpace"
