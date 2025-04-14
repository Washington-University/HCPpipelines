#!/bin/bash

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

script_name=$(basename "${0}")

show_usage() {
    cat <<EOF

${script_name}: Sub-script of PostFreeSurferPipeline.sh

EOF
}

# Allow script to return a Usage statement, before any other output or checking
if [ "$#" = "0" ]; then
    show_usage
    exit 1
fi

# ------------------------------------------------------------------------------
#  Check that HCPPIPEDIR is defined and Load Function Libraries
# ------------------------------------------------------------------------------

if [ -z "${HCPPIPEDIR}" ]; then
  echo "${script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
  exit 1
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source ${HCPPIPEDIR}/global/scripts/opts.shlib                 # Command line option functions

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
    show_usage
    exit 0
fi

# ------------------------------------------------------------------------------
#  Verify required environment variables are set and log value
# ------------------------------------------------------------------------------

log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FSLDIR
log_Check_Env_Var CARET7DIR
log_Check_Env_Var MSMBINDIR
log_Check_Env_Var MSMCONFIGDIR

# ------------------------------------------------------------------------------
#  Gather and show positional parameters
# ------------------------------------------------------------------------------

log_Msg "START"

StudyFolder="$1"
log_Msg "StudyFolder: ${StudyFolder}"

Session="$2"
log_Msg "Session: ${Session}"

T1wFolder="$3"
log_Msg "T1wFolder: ${T1wFolder}"

AtlasSpaceFolder="$4"
log_Msg "AtlasSpaceFolder: ${AtlasSpaceFolder}"

NativeFolder="$5"
log_Msg "NativeFolder: ${NativeFolder}"

FreeSurferFolder="$6"
log_Msg "FreeSurferFolder: ${FreeSurferFolder}"

FreeSurferInput="$7"
log_Msg "FreeSurferInput: ${FreeSurferInput}"

T1wImage="$8"
log_Msg "T1wImage: ${T1wImage}"

T2wImage="$9"
log_Msg "T2wImage: ${T2wImage}"

SurfaceAtlasDIR="${10}"
log_Msg "SurfaceAtlasDIR: ${SurfaceAtlasDIR}"

HighResMesh="${11}"
log_Msg "HighResMesh: ${HighResMesh}"

LowResMeshes="${12}"
log_Msg "LowResMeshes: ${LowResMeshes}"

AtlasTransform="${13}"
log_Msg "AtlasTransform: ${AtlasTransform}"

InverseAtlasTransform="${14}"
log_Msg "InverseAtlasTransform: ${InverseAtlasTransform}"

AtlasSpaceT1wImage="${15}"
log_Msg "AtlasSpaceT1wImage: ${AtlasSpaceT1wImage}"

AtlasSpaceT2wImage="${16}"
log_Msg "AtlasSpaceT2wImage: ${AtlasSpaceT2wImage}"

T1wImageBrainMask="${17}"
log_Msg "T1wImageBrainMask: ${T1wImageBrainMask}"

FreeSurferLabels="${18}"
log_Msg "FreeSurferLabels: ${FreeSurferLabels}"

GrayordinatesSpaceDIR="${19}"
log_Msg "GrayordinatesSpaceDIR: ${GrayordinatesSpaceDIR}"

GrayordinatesResolutions="${20}"
log_Msg "GrayordinatesResolutions: ${GrayordinatesResolutions}"

SubcorticalGrayLabels="${21}"
log_Msg "SubcorticalGrayLabels: ${SubcorticalGrayLabels}"

RegName="${22}"
log_Msg "RegName: ${RegName}"

InflateExtraScale="${23}"
log_Msg "InflateExtraScale: ${InflateExtraScale}"

#NONE, TIMEPOINT_STAGE1, TIMEPOINT_STAGE2, or TEMPLATE
LongitudinalMode="${24}"

#Subject variable is retired, renamed to Session to reflect (possibliy) multi-session nature of subject data.
#In long TIMEPOINT mode, $Session=$ExperimentRoot, which is defined as <LongSubjectLabel>.long.<Timepoint>
#In long TEMPLATE mode, $Session=$ExperimentRoot, defined as <LongSubjectLabel>.long.<LongTemplate>
#In long TEMPLATE mode we also need LongTemplate, LongSubjectLabel and all LongitudinalTimepoint labels to perform
#surface averaging for MSMSulc.

#Actual subject label which is part of longitudinal timepoint and template experiment roots, see comment above.
Subject="${25}"
#Longitudinal template label
LongitudinalTemplate="${26}"
#LIST of all timepoints, @ separated
LongitudinalTimepoints="${27}"

LowResMeshes=${LowResMeshes//@/ }
log_Msg "LowResMeshes: ${LowResMeshes}"

LongitudinalTimepoints="${LongitudinalTimepoints//@/ }"
log_Msg "LongitudinalTimepoints: $LongitudinalTimepoints"

GrayordinatesResolutions=${GrayordinatesResolutions//@/ }
log_Msg "GrayordinatesResolutions: ${GrayordinatesResolutions}"

#Make some folders for this and later scripts
if [ ! -e "$T1wFolder"/"$NativeFolder" ] ; then
    mkdir -p "$T1wFolder"/"$NativeFolder"
fi
if [ ! -e "$AtlasSpaceFolder"/ROIs ] ; then
    mkdir -p "$AtlasSpaceFolder"/ROIs
fi
if [ ! -e "$AtlasSpaceFolder"/Results ] ; then
    mkdir "$AtlasSpaceFolder"/Results
fi
if [ ! -e "$AtlasSpaceFolder"/"$NativeFolder" ] ; then
    mkdir "$AtlasSpaceFolder"/"$NativeFolder"
fi
if [ ! -e "$AtlasSpaceFolder"/fsaverage ] ; then
    mkdir "$AtlasSpaceFolder"/fsaverage
fi
for LowResMesh in ${LowResMeshes} ; do
    if [ ! -e "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k ] ; then
        mkdir "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k
    fi
    if [ ! -e "$T1wFolder"/fsaverage_LR"$LowResMesh"k ] ; then
        mkdir "$T1wFolder"/fsaverage_LR"$LowResMesh"k
    fi
done

#To prevent the code inside the if clause to be executed repeatedly when TIMEPOINT_STAGE2 mode is on
if [ "$LongitudinalMode" != "TIMEPOINT_STAGE2" ]; then

    # Find c_ras offset between FreeSurfer surface and volume and generate matrix to transform surfaces
    # -- Corrected code using native mri_info --cras function to build the needed variables
    MatrixXYZ=`mri_info --cras ${FreeSurferFolder}/mri/brain.finalsurfs.mgz`
    MatrixX=`echo ${MatrixXYZ} | awk '{print $1;}'`
    MatrixY=`echo ${MatrixXYZ} | awk '{print $2;}'`
    MatrixZ=`echo ${MatrixXYZ} | awk '{print $3;}'`
    echo "1 0 0 ${MatrixX}" >  ${FreeSurferFolder}/mri/c_ras.mat
    echo "0 1 0 ${MatrixY}" >> ${FreeSurferFolder}/mri/c_ras.mat
    echo "0 0 1 ${MatrixZ}" >> ${FreeSurferFolder}/mri/c_ras.mat
    echo "0 0 0 1"          >> ${FreeSurferFolder}/mri/c_ras.mat


    #TODO (maybe) wmparc is also converted in ppFS-longtwice in longitudinal run. Code run there is identical.

    #Convert FreeSurfer Volumes
    for Image in wmparc aparc.a2009s+aseg aparc+aseg ; do
        if [ -e "$FreeSurferFolder"/mri/"$Image".mgz ] ; then
        mri_convert -rt nearest -rl "$T1wFolder"/"$T1wImage".nii.gz "$FreeSurferFolder"/mri/"$Image".mgz "$T1wFolder"/"$Image"_1mm.nii.gz
        applywarp --rel --interp=nn -i "$T1wFolder"/"$Image"_1mm.nii.gz -r "$T1wFolder"/"$T1wImage".nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$T1wFolder"/"$Image".nii.gz
        applywarp --rel --interp=nn -i "$T1wFolder"/"$Image"_1mm.nii.gz -r "$AtlasSpaceFolder"/"$AtlasSpaceT1wImage" -w "$AtlasTransform" -o "$AtlasSpaceFolder"/"$Image".nii.gz
        ${CARET7DIR}/wb_command -volume-label-import "$T1wFolder"/"$Image".nii.gz "$FreeSurferLabels" "$T1wFolder"/"$Image".nii.gz -drop-unused-labels
        ${CARET7DIR}/wb_command -volume-label-import "$AtlasSpaceFolder"/"$Image".nii.gz "$FreeSurferLabels" "$AtlasSpaceFolder"/"$Image".nii.gz -drop-unused-labels
        fi
    done

    #The following processing is done in PrePostFreesurfer-long pipeline in the case of longitudinal pipelines.
    if [ "$LongitudinalMode" == "NONE" ]; then
        #Create FreeSurfer Brain Mask
        fslmaths "$T1wFolder"/wmparc_1mm.nii.gz -bin -dilD -dilD -dilD -ero -ero "$T1wFolder"/"$T1wImageBrainMask"_1mm.nii.gz
        ${CARET7DIR}/wb_command -volume-fill-holes "$T1wFolder"/"$T1wImageBrainMask"_1mm.nii.gz "$T1wFolder"/"$T1wImageBrainMask"_1mm.nii.gz
        fslmaths "$T1wFolder"/"$T1wImageBrainMask"_1mm.nii.gz -bin "$T1wFolder"/"$T1wImageBrainMask"_1mm.nii.gz
        applywarp --rel --interp=nn -i "$T1wFolder"/"$T1wImageBrainMask"_1mm.nii.gz -r "$T1wFolder"/"$T1wImage".nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$T1wFolder"/"$T1wImageBrainMask".nii.gz
        applywarp --rel --interp=nn -i "$T1wFolder"/"$T1wImageBrainMask"_1mm.nii.gz -r "$AtlasSpaceFolder"/"$AtlasSpaceT1wImage" -w "$AtlasTransform" -o "$AtlasSpaceFolder"/"$T1wImageBrainMask".nii.gz
    fi

    #Add volume files to spec files

    [ "${T2wImage}" != "NONE" ] && ${CARET7DIR}/wb_command -add-to-spec-file "$T1wFolder"/"$NativeFolder"/"$Session".native.wb.spec INVALID "$T1wFolder"/"$T2wImage".nii.gz
    ${CARET7DIR}/wb_command -add-to-spec-file "$T1wFolder"/"$NativeFolder"/"$Session".native.wb.spec INVALID "$T1wFolder"/"$T1wImage".nii.gz

    [ "${T2wImage}" != "NONE" ] && ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/"$NativeFolder"/"$Session".native.wb.spec INVALID "$AtlasSpaceFolder"/"$AtlasSpaceT2wImage".nii.gz
    ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/"$NativeFolder"/"$Session".native.wb.spec INVALID "$AtlasSpaceFolder"/"$AtlasSpaceT1wImage".nii.gz

    [ "${T2wImage}" != "NONE" ] && ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/"$Session"."$HighResMesh"k_fs_LR.wb.spec INVALID "$AtlasSpaceFolder"/"$AtlasSpaceT2wImage".nii.gz
    ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/"$Session"."$HighResMesh"k_fs_LR.wb.spec INVALID "$AtlasSpaceFolder"/"$AtlasSpaceT1wImage".nii.gz

    for LowResMesh in ${LowResMeshes} ; do
      [ "${T2wImage}" != "NONE" ] && ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$LowResMesh"k_fs_LR.wb.spec INVALID "$AtlasSpaceFolder"/"$AtlasSpaceT2wImage".nii.gz
      ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$LowResMesh"k_fs_LR.wb.spec INVALID "$AtlasSpaceFolder"/"$AtlasSpaceT1wImage".nii.gz

      [ "${T2wImage}" != "NONE" ] && ${CARET7DIR}/wb_command -add-to-spec-file "$T1wFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$LowResMesh"k_fs_LR.wb.spec INVALID "$T1wFolder"/"$T2wImage".nii.gz
      ${CARET7DIR}/wb_command -add-to-spec-file "$T1wFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$LowResMesh"k_fs_LR.wb.spec INVALID "$T1wFolder"/"$T1wImage".nii.gz
    done

    #Import Subcortical ROIs
    for GrayordinatesResolution in ${GrayordinatesResolutions} ; do
        cp "$GrayordinatesSpaceDIR"/Atlas_ROIs."$GrayordinatesResolution".nii.gz "$AtlasSpaceFolder"/ROIs/Atlas_ROIs."$GrayordinatesResolution".nii.gz
        applywarp --interp=nn -i "$AtlasSpaceFolder"/wmparc.nii.gz -r "$AtlasSpaceFolder"/ROIs/Atlas_ROIs."$GrayordinatesResolution".nii.gz -o "$AtlasSpaceFolder"/ROIs/wmparc."$GrayordinatesResolution".nii.gz
        ${CARET7DIR}/wb_command -volume-label-import "$AtlasSpaceFolder"/ROIs/wmparc."$GrayordinatesResolution".nii.gz "$FreeSurferLabels" "$AtlasSpaceFolder"/ROIs/wmparc."$GrayordinatesResolution".nii.gz -drop-unused-labels
        applywarp --interp=nn -i "$SurfaceAtlasDIR"/Avgwmparc.nii.gz -r "$AtlasSpaceFolder"/ROIs/Atlas_ROIs."$GrayordinatesResolution".nii.gz -o "$AtlasSpaceFolder"/ROIs/Atlas_wmparc."$GrayordinatesResolution".nii.gz
        ${CARET7DIR}/wb_command -volume-label-import "$AtlasSpaceFolder"/ROIs/Atlas_wmparc."$GrayordinatesResolution".nii.gz "$FreeSurferLabels" "$AtlasSpaceFolder"/ROIs/Atlas_wmparc."$GrayordinatesResolution".nii.gz -drop-unused-labels
        ${CARET7DIR}/wb_command -volume-label-import "$AtlasSpaceFolder"/ROIs/wmparc."$GrayordinatesResolution".nii.gz ${SubcorticalGrayLabels} "$AtlasSpaceFolder"/ROIs/ROIs."$GrayordinatesResolution".nii.gz -discard-others
        [ "${T2wImage}" != "NONE" ] && applywarp --interp=spline -i "$AtlasSpaceFolder"/"$AtlasSpaceT2wImage".nii.gz -r "$AtlasSpaceFolder"/ROIs/Atlas_ROIs."$GrayordinatesResolution".nii.gz -o "$AtlasSpaceFolder"/"$AtlasSpaceT2wImage"."$GrayordinatesResolution".nii.gz
        applywarp --interp=spline -i "$AtlasSpaceFolder"/"$AtlasSpaceT1wImage".nii.gz -r "$AtlasSpaceFolder"/ROIs/Atlas_ROIs."$GrayordinatesResolution".nii.gz -o "$AtlasSpaceFolder"/"$AtlasSpaceT1wImage"."$GrayordinatesResolution".nii.gz

        ### Report on subcortical segmentation (missing voxels and overlap with Atlas)

        # Generate brain mask at appropriate resolution
        applywarp --interp=nn -i "$AtlasSpaceFolder"/"$T1wImageBrainMask".nii.gz -r "$AtlasSpaceFolder"/ROIs/Atlas_ROIs."$GrayordinatesResolution".nii.gz -o "$AtlasSpaceFolder"/"$T1wImageBrainMask"."$GrayordinatesResolution".nii.gz

        # Compute subcortical grayordinates missing from the "Atlas" space (CIFTI standard space) based on the overall brain mask
        MissingGrayordinates="$AtlasSpaceFolder"/ROIs/MissingGrayordinates."$GrayordinatesResolution"
        ${CARET7DIR}/wb_command -volume-math "(!Brainmask)*CIFTIStandardSpace" ${MissingGrayordinates}.nii.gz -var Brainmask "$AtlasSpaceFolder"/"$T1wImageBrainMask"."$GrayordinatesResolution".nii.gz -var CIFTIStandardSpace "$AtlasSpaceFolder"/ROIs/Atlas_ROIs."$GrayordinatesResolution".nii.gz
        MissingGrayordinatesTotal=$(fslstats ${MissingGrayordinates}.nii.gz -V | awk '{print $1}')

        # Repeat with brain mask dilated by 2 x GrayordinatesResolution
        # Use -volume-dilate rather than 'fslmaths -dilF -dilF', for explicit control over the dilation distance
        dilDist=$(echo "2 * $GrayordinatesResolution" | bc -l)
        ${CARET7DIR}/wb_command -volume-dilate "$AtlasSpaceFolder"/"$T1wImageBrainMask"."$GrayordinatesResolution".nii.gz $dilDist NEAREST "$AtlasSpaceFolder"/"$T1wImageBrainMask"."$GrayordinatesResolution".dil2x.nii.gz
        ${CARET7DIR}/wb_command -volume-math "(!BrainmaskDil2x)*CIFTIStandardSpace" ${MissingGrayordinates}.dil2xBrainMask.nii.gz -var BrainmaskDil2x "$AtlasSpaceFolder"/"$T1wImageBrainMask"."$GrayordinatesResolution".dil2x.nii.gz -var CIFTIStandardSpace "$AtlasSpaceFolder"/ROIs/Atlas_ROIs."$GrayordinatesResolution".nii.gz
        MissingGrayordinatesDil2xTotal=$(fslstats ${MissingGrayordinates}.dil2xBrainMask.nii.gz -V | awk '{print $1}')

        # Split the Atlas and session-specific ROIs into individual structures, so we can compute counts of missing voxels and overlap relative to specific structures
        AtlasROIsSplit="$AtlasSpaceFolder"/ROIs/Atlas_ROIs."$GrayordinatesResolution".split
        SubjROIsSplit="$AtlasSpaceFolder"/ROIs/ROIs."$GrayordinatesResolution".split
        MissingSplit=${MissingGrayordinates}.split
        ${CARET7DIR}/wb_command -volume-all-labels-to-rois "$AtlasSpaceFolder"/ROIs/Atlas_ROIs."$GrayordinatesResolution".nii.gz 1 ${AtlasROIsSplit}.nii.gz
        ${CARET7DIR}/wb_command -volume-all-labels-to-rois "$AtlasSpaceFolder"/ROIs/ROIs."$GrayordinatesResolution".nii.gz 1 ${SubjROIsSplit}.nii.gz

        # Create a version of session-specific ROIs, dilated by 2 x GrayordinatesResolution
        ${CARET7DIR}/wb_command -volume-dilate ${SubjROIsSplit}.nii.gz $dilDist NEAREST ${SubjROIsSplit}.dil2x.nii.gz

        # Volume with the *brainmask* voxels missing from the Atlas, with each structure as a separate frame
        # (Note: need to binarize "Missing" to turn it into a mask, since it uses the original label values)
        ${CARET7DIR}/wb_command -volume-math "(Missing > 0) * Atlas" ${MissingSplit}.nii.gz -var Missing ${MissingGrayordinates}.nii.gz -repeat -var Atlas ${AtlasROIsSplit}.nii.gz

        # Volume with the *brainmask* voxels after 2x dilation that are missing from the Atlas, with each structure as a separate frame
        ${CARET7DIR}/wb_command -volume-math "(MissingDil2x > 0) * Atlas" ${MissingSplit}.dil2xBrainMask.nii.gz -var MissingDil2x ${MissingGrayordinates}.dil2xBrainMask.nii.gz -repeat -var Atlas ${AtlasROIsSplit}.nii.gz

        # Volume with the session-specific subcortical labels that are *missing* from the corresponding Atlas label, with each structure as a separate frame
        ${CARET7DIR}/wb_command -volume-math "Atlas * (!Subj)" ${SubjROIsSplit}.missing.nii.gz -var Atlas ${AtlasROIsSplit}.nii.gz -var Subj ${SubjROIsSplit}.nii.gz

        # Volume with the session-specific subcortical labels that *overlap* with the corresponding Atlas label, with each structure as a separate frame
        ${CARET7DIR}/wb_command -volume-math "(Atlas) * Subj" ${SubjROIsSplit}.overlap.nii.gz -var Atlas ${AtlasROIsSplit}.nii.gz -var Subj ${SubjROIsSplit}.nii.gz

        # Volume with the session-specific subcortical labels that are *outside* of the corresponding Atlas label, with each structure as a separate frame
        ${CARET7DIR}/wb_command -volume-math "(!Atlas) * Subj" ${SubjROIsSplit}.outside.nii.gz -var Atlas ${AtlasROIsSplit}.nii.gz -var Subj ${SubjROIsSplit}.nii.gz

        # Volume with the session-specific subcortical labels after 2x dilation that *overlap* with the corresponding Atlas label, with each structure as a separate frame
        ${CARET7DIR}/wb_command -volume-math "(Atlas) * SubjDil2x" ${SubjROIsSplit}.dil2x.overlap.nii.gz -var Atlas ${AtlasROIsSplit}.nii.gz -var SubjDil2x ${SubjROIsSplit}.dil2x.nii.gz

        # Extract summary counts
        ${CARET7DIR}/wb_command -volume-stats ${MissingSplit}.dil2xBrainMask.nii.gz -reduce SUM -show-map-name > ${MissingSplit}.dil2xBrainMask.stats.txt
        ${CARET7DIR}/wb_command -volume-stats ${MissingSplit}.nii.gz -reduce SUM -show-map-name > ${MissingSplit}.stats.txt
        ${CARET7DIR}/wb_command -volume-stats ${SubjROIsSplit}.missing.nii.gz -reduce SUM -show-map-name > ${SubjROIsSplit}.missing.stats.txt
        ${CARET7DIR}/wb_command -volume-stats ${SubjROIsSplit}.overlap.nii.gz -reduce SUM -show-map-name > ${SubjROIsSplit}.overlap.stats.txt
        ${CARET7DIR}/wb_command -volume-stats ${SubjROIsSplit}.outside.nii.gz -reduce SUM -show-map-name > ${SubjROIsSplit}.outside.stats.txt
        ${CARET7DIR}/wb_command -volume-stats ${SubjROIsSplit}.dil2x.overlap.nii.gz -reduce SUM -show-map-name > ${SubjROIsSplit}.dil2x.overlap.stats.txt

        # Assemble output csv
        # We assume in the following (without checking) that the structures from -volume-stats -show-map-name are consistent across all files
        cut -d ':' -f 2 ${MissingSplit}.stats.txt > ${MissingSplit}.stats.roinames.txt
        cut -d ':' -f 3 ${MissingSplit}.dil2xBrainMask.stats.txt > ${MissingSplit}.dil2xBrainMask.stats.value.txt
        cut -d ':' -f 3 ${MissingSplit}.stats.txt > ${MissingSplit}.stats.value.txt
        cut -d ':' -f 3 ${SubjROIsSplit}.missing.stats.txt > ${SubjROIsSplit}.missing.stats.value.txt
        cut -d ':' -f 3 ${SubjROIsSplit}.overlap.stats.txt > ${SubjROIsSplit}.overlap.stats.value.txt
        cut -d ':' -f 3 ${SubjROIsSplit}.outside.stats.txt > ${SubjROIsSplit}.outside.stats.value.txt
        cut -d ':' -f 3 ${SubjROIsSplit}.dil2x.overlap.stats.txt > ${SubjROIsSplit}.dil2x.overlap.stats.value.txt

        outFile="$AtlasSpaceFolder"/ROIs/MissingGrayordinates."$GrayordinatesResolution".txt
        echo "Structure,nMissing2xDilBrainMaskFromAtlas,nMissingBrainMaskFromAtlas,nMissingROIFromAtlas,nOverlapROIWithAtlas,nROIOutsideAtlas,nOverlap2xDilROIWithAtlas" > ${outFile}
        echo "ALL,${MissingGrayordinatesDil2xTotal},${MissingGrayordinatesTotal},,,," >> ${outFile}
        paste -d ',' ${MissingSplit}.stats.roinames.txt ${MissingSplit}.dil2xBrainMask.stats.value.txt ${MissingSplit}.stats.value.txt ${SubjROIsSplit}.missing.stats.value.txt ${SubjROIsSplit}.overlap.stats.value.txt ${SubjROIsSplit}.outside.stats.value.txt ${SubjROIsSplit}.dil2x.overlap.stats.value.txt | tr -d '[:blank:]' >> ${outFile}

        # Cleanup
        rm ${AtlasROIsSplit}* ${SubjROIsSplit}* ${MissingSplit}*
        rm ${MissingGrayordinates}.dil2xBrainMask.nii.gz
        #rm "$AtlasSpaceFolder"/"$T1wImageBrainMask"."$GrayordinatesResolution".dil2x.nii.gz

        ### End report on subcortical segmentation
    done
fi #end code that is excluded from TIMEPOINT_STAGE2 run.

#Loop through left and right hemispheres
for Hemisphere in L R ; do
    #Set a bunch of different ways of saying left and right
    if [ $Hemisphere = "L" ] ; then
        hemisphere="l"
        Structure="CORTEX_LEFT"
    elif [ $Hemisphere = "R" ] ; then
        hemisphere="r"
        Structure="CORTEX_RIGHT"
    fi

    #native Mesh Processing
    #Convert and volumetrically register white and pial surfaces makign linear and nonlinear copies, add each to the appropriate spec file
    Types="ANATOMICAL@GRAY_WHITE ANATOMICAL@PIAL"
    i=1
    if [ "$LongitudinalMode" != "TIMEPOINT_STAGE2" ]; then #the following code is skipped in TIMEPOINT_STAGE2.
        for Surface in white pial ; do
        Type=$(echo "$Types" | cut -d " " -f $i)
        Secondary=$(echo "$Type" | cut -d "@" -f 2)
        Type=$(echo "$Type" | cut -d "@" -f 1)
        if [ ! $Secondary = $Type ] ; then
            Secondary=$(echo " -surface-secondary-type ""$Secondary")
        else
            Secondary=""
        fi
        mris_convert "$FreeSurferFolder"/surf/"$hemisphere"h."$Surface" "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$Surface".native.surf.gii
        ${CARET7DIR}/wb_command -set-structure "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$Surface".native.surf.gii ${Structure} -surface-type $Type$Secondary
        ${CARET7DIR}/wb_command -surface-apply-affine "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$Surface".native.surf.gii "$FreeSurferFolder"/mri/c_ras.mat "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$Surface".native.surf.gii
        ${CARET7DIR}/wb_command -add-to-spec-file "$T1wFolder"/"$NativeFolder"/"$Session".native.wb.spec $Structure "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$Surface".native.surf.gii
        ${CARET7DIR}/wb_command -surface-apply-warpfield "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$Surface".native.surf.gii "$InverseAtlasTransform".nii.gz "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$Surface".native.surf.gii -fnirt "$AtlasTransform".nii.gz
        ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/"$NativeFolder"/"$Session".native.wb.spec $Structure "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$Surface".native.surf.gii
        i=$(( i+1 ))
        done

        #Create midthickness by averaging white and pial surfaces and use it to make inflated surfacess
        for Folder in "$T1wFolder" "$AtlasSpaceFolder" ; do
        ${CARET7DIR}/wb_command -surface-average "$Folder"/"$NativeFolder"/"$Session"."$Hemisphere".midthickness.native.surf.gii -surf "$Folder"/"$NativeFolder"/"$Session"."$Hemisphere".white.native.surf.gii -surf "$Folder"/"$NativeFolder"/"$Session"."$Hemisphere".pial.native.surf.gii
        ${CARET7DIR}/wb_command -set-structure "$Folder"/"$NativeFolder"/"$Session"."$Hemisphere".midthickness.native.surf.gii ${Structure} -surface-type ANATOMICAL -surface-secondary-type MIDTHICKNESS
        ${CARET7DIR}/wb_command -add-to-spec-file "$Folder"/"$NativeFolder"/"$Session".native.wb.spec $Structure "$Folder"/"$NativeFolder"/"$Session"."$Hemisphere".midthickness.native.surf.gii

        #get number of vertices from native file
        NativeVerts=$(${CARET7DIR}/wb_command -file-information "$Folder"/"$NativeFolder"/"$Session"."$Hemisphere".midthickness.native.surf.gii | grep 'Number of Vertices:' | cut -f2 -d: | tr -d '[:space:]')

        #HCP fsaverage_LR32k used -iterations-scale 0.75. Compute new param value for native mesh density
        NativeInflationScale=$(echo "scale=4; $InflateExtraScale * 0.75 * $NativeVerts / 32492" | bc -l)

        ${CARET7DIR}/wb_command -surface-generate-inflated "$Folder"/"$NativeFolder"/"$Session"."$Hemisphere".midthickness.native.surf.gii "$Folder"/"$NativeFolder"/"$Session"."$Hemisphere".inflated.native.surf.gii "$Folder"/"$NativeFolder"/"$Session"."$Hemisphere".very_inflated.native.surf.gii -iterations-scale $NativeInflationScale
        ${CARET7DIR}/wb_command -add-to-spec-file "$Folder"/"$NativeFolder"/"$Session".native.wb.spec $Structure "$Folder"/"$NativeFolder"/"$Session"."$Hemisphere".inflated.native.surf.gii
        ${CARET7DIR}/wb_command -add-to-spec-file "$Folder"/"$NativeFolder"/"$Session".native.wb.spec $Structure "$Folder"/"$NativeFolder"/"$Session"."$Hemisphere".very_inflated.native.surf.gii
        done

        #Convert original and registered spherical surfaces and add them to the nonlinear spec file
        for Surface in sphere.reg sphere ; do
        mris_convert "$FreeSurferFolder"/surf/"$hemisphere"h."$Surface" "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$Surface".native.surf.gii
        ${CARET7DIR}/wb_command -set-structure "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$Surface".native.surf.gii ${Structure} -surface-type SPHERICAL
        done
        ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/"$NativeFolder"/"$Session".native.wb.spec $Structure "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".sphere.native.surf.gii

        #Add more files to the spec file and convert other FreeSurfer surface data to metric/GIFTI including sulc, curv, and thickness.
        for Map in sulc@sulc@Sulc thickness@thickness@Thickness curv@curvature@Curvature ; do
            fsname=$(echo $Map | cut -d "@" -f 1)
            wbname=$(echo $Map | cut -d "@" -f 2)
            mapname=$(echo $Map | cut -d "@" -f 3)
            
            mris_convert -c "$FreeSurferFolder"/surf/"$hemisphere"h."$fsname" "$FreeSurferFolder"/surf/"$hemisphere"h.white "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$wbname".native.shape.gii
            ${CARET7DIR}/wb_command -set-structure "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$wbname".native.shape.gii ${Structure}
            ${CARET7DIR}/wb_command -metric-math "var * -1" "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$wbname".native.shape.gii -var var "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$wbname".native.shape.gii
            ${CARET7DIR}/wb_command -set-map-names "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$wbname".native.shape.gii -map 1 "$Session"_"$Hemisphere"_"$mapname"
            ${CARET7DIR}/wb_command -metric-palette "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$wbname".native.shape.gii MODE_AUTO_SCALE_PERCENTAGE -pos-percent 2 98 -palette-name Gray_Interp -disp-pos true -disp-neg true -disp-zero true
        done
        #Thickness specific operations
        ${CARET7DIR}/wb_command -metric-math "abs(thickness)" "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".thickness.native.shape.gii -var thickness "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".thickness.native.shape.gii
        ${CARET7DIR}/wb_command -metric-palette "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".thickness.native.shape.gii MODE_AUTO_SCALE_PERCENTAGE -pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false
        
        # for longitudinal runs, medial wall ROIs are only created in template mode, and then copied over to timepoints
        if [[ "$LongitudinalMode" == "NONE" || "$LongitudinalMode" == "TEMPLATE" ]]; then 
            ${CARET7DIR}/wb_command -metric-math "thickness > 0" "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".roi.native.shape.gii -var thickness "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".thickness.native.shape.gii
            ${CARET7DIR}/wb_command -metric-fill-holes "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".midthickness.native.surf.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".roi.native.shape.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".roi.native.shape.gii
            ${CARET7DIR}/wb_command -metric-remove-islands "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".midthickness.native.surf.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".roi.native.shape.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".roi.native.shape.gii
            ${CARET7DIR}/wb_command -set-map-names "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".roi.native.shape.gii -map 1 "$Session"_"$Hemisphere"_ROI
        fi
        ${CARET7DIR}/wb_command -metric-dilate "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".thickness.native.shape.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".midthickness.native.surf.gii 10 "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".thickness.native.shape.gii -nearest
        ${CARET7DIR}/wb_command -metric-dilate "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".curvature.native.shape.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".midthickness.native.surf.gii 10 "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".curvature.native.shape.gii -nearest

        #Label operations
        for Map in aparc aparc.a2009s ; do #Remove BA because it doesn't convert properly
        if [ -e "$FreeSurferFolder"/label/"$hemisphere"h."$Map".annot ] ; then
            mris_convert --annot "$FreeSurferFolder"/label/"$hemisphere"h."$Map".annot "$FreeSurferFolder"/surf/"$hemisphere"h.white "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$Map".native.label.gii
            ${CARET7DIR}/wb_command -set-structure "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$Map".native.label.gii $Structure
            ${CARET7DIR}/wb_command -set-map-names "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$Map".native.label.gii -map 1 "$Session"_"$Hemisphere"_"$Map"
            ${CARET7DIR}/wb_command -gifti-label-add-prefix "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$Map".native.label.gii "${Hemisphere}_" "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$Map".native.label.gii
        fi
        done
        #End main native mesh processing

        #Copy Atlas Files
        cp "$SurfaceAtlasDIR"/fs_"$Hemisphere"/fsaverage."$Hemisphere".sphere."$HighResMesh"k_fs_"$Hemisphere".surf.gii "$AtlasSpaceFolder"/fsaverage/"$Session"."$Hemisphere".sphere."$HighResMesh"k_fs_"$Hemisphere".surf.gii
        cp "$SurfaceAtlasDIR"/fs_"$Hemisphere"/fs_"$Hemisphere"-to-fs_LR_fsaverage."$Hemisphere"_LR.spherical_std."$HighResMesh"k_fs_"$Hemisphere".surf.gii "$AtlasSpaceFolder"/fsaverage/"$Session"."$Hemisphere".def_sphere."$HighResMesh"k_fs_"$Hemisphere".surf.gii
        cp "$SurfaceAtlasDIR"/fsaverage."$Hemisphere"_LR.spherical_std."$HighResMesh"k_fs_LR.surf.gii "$AtlasSpaceFolder"/"$Session"."$Hemisphere".sphere."$HighResMesh"k_fs_LR.surf.gii
        ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/"$Session"."$HighResMesh"k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/"$Session"."$Hemisphere".sphere."$HighResMesh"k_fs_LR.surf.gii
        cp "$SurfaceAtlasDIR"/"$Hemisphere".atlasroi."$HighResMesh"k_fs_LR.shape.gii "$AtlasSpaceFolder"/"$Session"."$Hemisphere".atlasroi."$HighResMesh"k_fs_LR.shape.gii
        cp "$SurfaceAtlasDIR"/"$Hemisphere".refsulc."$HighResMesh"k_fs_LR.shape.gii "$AtlasSpaceFolder"/${Session}.${Hemisphere}.refsulc."$HighResMesh"k_fs_LR.shape.gii
        if [ -e "$SurfaceAtlasDIR"/colin.cerebral."$Hemisphere".flat."$HighResMesh"k_fs_LR.surf.gii ] ; then
            cp "$SurfaceAtlasDIR"/colin.cerebral."$Hemisphere".flat."$HighResMesh"k_fs_LR.surf.gii "$AtlasSpaceFolder"/"$Session"."$Hemisphere".flat."$HighResMesh"k_fs_LR.surf.gii
            ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/"$Session"."$HighResMesh"k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/"$Session"."$Hemisphere".flat."$HighResMesh"k_fs_LR.surf.gii
        fi

        #Concatenate FS registration to FS --> FS_LR registration
        ${CARET7DIR}/wb_command -surface-sphere-project-unproject "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".sphere.reg.native.surf.gii "$AtlasSpaceFolder"/fsaverage/"$Session"."$Hemisphere".sphere."$HighResMesh"k_fs_"$Hemisphere".surf.gii "$AtlasSpaceFolder"/fsaverage/"$Session"."$Hemisphere".def_sphere."$HighResMesh"k_fs_"$Hemisphere".surf.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".sphere.reg.reg_LR.native.surf.gii

        #Make FreeSurfer Registration Areal Distortion Maps
        ${CARET7DIR}/wb_command -surface-vertex-areas "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".sphere.native.surf.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".sphere.native.shape.gii
        ${CARET7DIR}/wb_command -surface-vertex-areas "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".sphere.reg.reg_LR.native.surf.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".sphere.reg.reg_LR.native.shape.gii
        ${CARET7DIR}/wb_command -metric-math "ln(spherereg / sphere) / ln(2)" "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".ArealDistortion_FS.native.shape.gii -var sphere "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".sphere.native.shape.gii -var spherereg "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".sphere.reg.reg_LR.native.shape.gii
        rm "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".sphere.native.shape.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".sphere.reg.reg_LR.native.shape.gii
        ${CARET7DIR}/wb_command -set-map-names "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".ArealDistortion_FS.native.shape.gii -map 1 "$Session"_"$Hemisphere"_Areal_Distortion_FS
        ${CARET7DIR}/wb_command -metric-palette "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".ArealDistortion_FS.native.shape.gii MODE_AUTO_SCALE -palette-name ROY-BIG-BL -thresholding THRESHOLD_TYPE_NORMAL THRESHOLD_TEST_SHOW_OUTSIDE -1 1

        ${CARET7DIR}/wb_command -surface-distortion "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".sphere.native.surf.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".sphere.reg.reg_LR.native.surf.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".EdgeDistortion_FS.native.shape.gii -edge-method

        ${CARET7DIR}/wb_command -surface-distortion "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".sphere.native.surf.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".sphere.reg.reg_LR.native.surf.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".Strain_FS.native.shape.gii -local-affine-method
        ${CARET7DIR}/wb_command -metric-merge "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".StrainJ_FS.native.shape.gii -metric "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".Strain_FS.native.shape.gii -column 1
        ${CARET7DIR}/wb_command -metric-merge "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".StrainR_FS.native.shape.gii -metric "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".Strain_FS.native.shape.gii -column 2
        ${CARET7DIR}/wb_command -metric-math "ln(var) / ln (2)" "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".StrainJ_FS.native.shape.gii -var var "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".StrainJ_FS.native.shape.gii
        ${CARET7DIR}/wb_command -metric-math "ln(var) / ln (2)" "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".StrainR_FS.native.shape.gii -var var "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".StrainR_FS.native.shape.gii
        rm "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".Strain_FS.native.shape.gii

        #Calculate Affine Transform and Apply
        ${CARET7DIR}/wb_command -surface-affine-regression "$AtlasSpaceFolder"/"$NativeFolder"/${Session}.${Hemisphere}.sphere.native.surf.gii "$AtlasSpaceFolder"/"$NativeFolder"/${Session}.${Hemisphere}.sphere.reg.reg_LR.native.surf.gii "$AtlasSpaceFolder"/"$NativeFolder"/rotate.${Hemisphere}.mat
        ${CARET7DIR}/wb_command -surface-apply-affine "$AtlasSpaceFolder"/"$NativeFolder"/${Session}.${Hemisphere}.sphere.native.surf.gii "$AtlasSpaceFolder"/"$NativeFolder"/rotate.${Hemisphere}.mat "$AtlasSpaceFolder"/"$NativeFolder"/${Hemisphere}.sphere_rot.surf.gii
        ${CARET7DIR}/wb_command -surface-modify-sphere "$AtlasSpaceFolder"/"$NativeFolder"/${Hemisphere}.sphere_rot.surf.gii 100 "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".sphere.rot.native.surf.gii

        rm -f "$AtlasSpaceFolder"/"$NativeFolder"/${Hemisphere}.sphere_rot.surf.gii rotate.${Hemisphere}.mat
    fi #end TIMEPOINT_STAGE2 condition

    if [ "$LongitudinalMode" == "TIMEPOINT_STAGE1" ]; then continue; fi #Stage 1 timepoint processing loop ends here.

    #If desired, run MSMSulc folding-based registration to FS_LR initialized with FS affine
    if [ ${RegName} == "MSMSulc" ] ; then
        mkdir -p "$AtlasSpaceFolder"/"$NativeFolder"/MSMSulc
        if [ "$LongitudinalMode" == "NONE" ]; then
            cp "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".sphere.rot.native.surf.gii "$AtlasSpaceFolder"/"$NativeFolder"/MSMSulc/${Hemisphere}.sphere_rot.surf.gii
            $HCPPIPEDIR/global/scripts/MSMSulc.sh --subject-dir="$StudyFolder" --subject="$Session" --regname="$RegName" --hemi "$Hemisphere"
        elif [ "$LongitudinalMode" == "TEMPLATE" ]; then
            #average surfaces from different timepoints
            average_cmd_args=()
            for timepoint in $LongitudinalTimepoints; do
                experiment_root="$StudyFolder/$timepoint.long.$LongitudinalTemplate"
                average_cmd_args+=("-surf" "$experiment_root/MNINonLinear/$NativeFolder/$timepoint.long.$LongitudinalTemplate.$Hemisphere.sphere.rot.native.surf.gii")
            done
            ${CARET7DIR}/wb_command -surface-average "${average_cmd_args[@]}" "$AtlasSpaceFolder/$NativeFolder/MSMSulc/${Hemisphere}.sphere_rot_average.surf.gii"
            #fix the averaged surface to convert it into sphere
            ${CARET7DIR}/wb_command -surface-modify-sphere "$AtlasSpaceFolder"/$NativeFolder/MSMSulc/${Hemisphere}.sphere_rot_average.surf.gii 100 "$AtlasSpaceFolder"/"$NativeFolder"/MSMSulc/"${Hemisphere}.sphere_rot.surf.gii"

            #run MSMSulc.sh on average surface
            $HCPPIPEDIR/global/scripts/MSMSulc.sh --subject-dir="$StudyFolder" --subject="$Session" --regname="$RegName" --hemi "$Hemisphere"

            #copy the registration result to each timepoint
            for timepoint in $LongitudinalTimepoints; do
                experiment_root="$StudyFolder/$timepoint.long.$LongitudinalTemplate"
                cp -r "$AtlasSpaceFolder"/"$NativeFolder"/MSMSulc $experiment_root/MNINonLinear/$NativeFolder/

                #copy the output of MSMSulc to each of the timepoint native folders
                for file in "$AtlasSpaceFolder"/"$NativeFolder"/${Subject}.long.${LongitudinalTemplate}.*${RegName}.*; do
                    file_base=$(basename $file)
                    new_file=${file_base/${Subject}.long.$LongitudinalTemplate/$timepoint.long.$LongitudinalTemplate}
                    cp $file $experiment_root/MNINonLinear/$NativeFolder/$new_file
                done
            done
        fi
        RegSphere="${AtlasSpaceFolder}/${NativeFolder}/${Session}.${Hemisphere}.sphere."$RegName".native.surf.gii"
    else
        RegSphere="${AtlasSpaceFolder}/${NativeFolder}/${Session}.${Hemisphere}.sphere.reg.reg_LR.native.surf.gii"
    fi

    #Ensure no zeros in atlas medial wall ROI
    ${CARET7DIR}/wb_command -metric-resample "$AtlasSpaceFolder"/"$Session"."$Hemisphere".atlasroi."$HighResMesh"k_fs_LR.shape.gii "$AtlasSpaceFolder"/"$Session"."$Hemisphere".sphere."$HighResMesh"k_fs_LR.surf.gii ${RegSphere} BARYCENTRIC "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".atlasroi.native.shape.gii -largest
    
    # for longitudinal runs, medial wall ROIs are only created in template mode, and then copied over to timepoints in PostFreeSurferPipeline.sh
    if [[ "$LongitudinalMode" == "NONE" || "$LongitudinalMode" == "TEMPLATE" ]]; then 
	    ${CARET7DIR}/wb_command -metric-math "(atlas + individual) > 0" "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".roi.native.shape.gii -var atlas "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".atlasroi.native.shape.gii -var individual "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".roi.native.shape.gii
    fi

    ${CARET7DIR}/wb_command -metric-mask "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".thickness.native.shape.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".roi.native.shape.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".thickness.native.shape.gii
    ${CARET7DIR}/wb_command -metric-mask "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".curvature.native.shape.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".roi.native.shape.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".curvature.native.shape.gii


    #Populate Highres fs_LR spec file.  Deform surfaces and other data according to native to folding-based registration selected above.  Regenerate inflated surfaces.
    for Surface in white midthickness pial ; do
        ${CARET7DIR}/wb_command -surface-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$Surface".native.surf.gii ${RegSphere} "$AtlasSpaceFolder"/"$Session"."$Hemisphere".sphere."$HighResMesh"k_fs_LR.surf.gii BARYCENTRIC "$AtlasSpaceFolder"/"$Session"."$Hemisphere"."$Surface"."$HighResMesh"k_fs_LR.surf.gii
        ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/"$Session"."$HighResMesh"k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/"$Session"."$Hemisphere"."$Surface"."$HighResMesh"k_fs_LR.surf.gii
    done

    #HCP fsaverage_LR32k used -iterations-scale 0.75. Compute new param value for high res mesh density
    HighResInflationScale=$(echo "scale=4; $InflateExtraScale * 0.75 * $HighResMesh / 32" | bc -l)

    ${CARET7DIR}/wb_command -surface-generate-inflated "$AtlasSpaceFolder"/"$Session"."$Hemisphere".midthickness."$HighResMesh"k_fs_LR.surf.gii "$AtlasSpaceFolder"/"$Session"."$Hemisphere".inflated."$HighResMesh"k_fs_LR.surf.gii "$AtlasSpaceFolder"/"$Session"."$Hemisphere".very_inflated."$HighResMesh"k_fs_LR.surf.gii -iterations-scale $HighResInflationScale
    ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/"$Session"."$HighResMesh"k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/"$Session"."$Hemisphere".inflated."$HighResMesh"k_fs_LR.surf.gii
    ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/"$Session"."$HighResMesh"k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/"$Session"."$Hemisphere".very_inflated."$HighResMesh"k_fs_LR.surf.gii

    for Map in thickness curvature ; do
        ${CARET7DIR}/wb_command -metric-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$Map".native.shape.gii ${RegSphere} "$AtlasSpaceFolder"/"$Session"."$Hemisphere".sphere."$HighResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$AtlasSpaceFolder"/"$Session"."$Hemisphere"."$Map"."$HighResMesh"k_fs_LR.shape.gii -area-surfs "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".midthickness.native.surf.gii "$AtlasSpaceFolder"/"$Session"."$Hemisphere".midthickness."$HighResMesh"k_fs_LR.surf.gii -current-roi "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".roi.native.shape.gii
        ${CARET7DIR}/wb_command -metric-mask "$AtlasSpaceFolder"/"$Session"."$Hemisphere"."$Map"."$HighResMesh"k_fs_LR.shape.gii "$AtlasSpaceFolder"/"$Session"."$Hemisphere".atlasroi."$HighResMesh"k_fs_LR.shape.gii "$AtlasSpaceFolder"/"$Session"."$Hemisphere"."$Map"."$HighResMesh"k_fs_LR.shape.gii
    done
    ${CARET7DIR}/wb_command -metric-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".ArealDistortion_FS.native.shape.gii ${RegSphere} "$AtlasSpaceFolder"/"$Session"."$Hemisphere".sphere."$HighResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$AtlasSpaceFolder"/"$Session"."$Hemisphere".ArealDistortion_FS."$HighResMesh"k_fs_LR.shape.gii -area-surfs "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".midthickness.native.surf.gii "$AtlasSpaceFolder"/"$Session"."$Hemisphere".midthickness."$HighResMesh"k_fs_LR.surf.gii
    ${CARET7DIR}/wb_command -metric-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".EdgeDistortion_FS.native.shape.gii ${RegSphere} "$AtlasSpaceFolder"/"$Session"."$Hemisphere".sphere."$HighResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$AtlasSpaceFolder"/"$Session"."$Hemisphere".EdgeDistortion_FS."$HighResMesh"k_fs_LR.shape.gii -area-surfs "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".midthickness.native.surf.gii "$AtlasSpaceFolder"/"$Session"."$Hemisphere".midthickness."$HighResMesh"k_fs_LR.surf.gii
    ${CARET7DIR}/wb_command -metric-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".StrainJ_FS.native.shape.gii ${RegSphere} "$AtlasSpaceFolder"/"$Session"."$Hemisphere".sphere."$HighResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$AtlasSpaceFolder"/"$Session"."$Hemisphere".StrainJ_FS."$HighResMesh"k_fs_LR.shape.gii -area-surfs "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".midthickness.native.surf.gii "$AtlasSpaceFolder"/"$Session"."$Hemisphere".midthickness."$HighResMesh"k_fs_LR.surf.gii
    ${CARET7DIR}/wb_command -metric-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".StrainR_FS.native.shape.gii ${RegSphere} "$AtlasSpaceFolder"/"$Session"."$Hemisphere".sphere."$HighResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$AtlasSpaceFolder"/"$Session"."$Hemisphere".StrainR_FS."$HighResMesh"k_fs_LR.shape.gii -area-surfs "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".midthickness.native.surf.gii "$AtlasSpaceFolder"/"$Session"."$Hemisphere".midthickness."$HighResMesh"k_fs_LR.surf.gii
    if [ ${RegName} = "MSMSulc" ] ; then
        ${CARET7DIR}/wb_command -metric-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".ArealDistortion_MSMSulc.native.shape.gii ${RegSphere} "$AtlasSpaceFolder"/"$Session"."$Hemisphere".sphere."$HighResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$AtlasSpaceFolder"/"$Session"."$Hemisphere".ArealDistortion_MSMSulc."$HighResMesh"k_fs_LR.shape.gii -area-surfs "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".midthickness.native.surf.gii "$AtlasSpaceFolder"/"$Session"."$Hemisphere".midthickness."$HighResMesh"k_fs_LR.surf.gii
        ${CARET7DIR}/wb_command -metric-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".EdgeDistortion_MSMSulc.native.shape.gii ${RegSphere} "$AtlasSpaceFolder"/"$Session"."$Hemisphere".sphere."$HighResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$AtlasSpaceFolder"/"$Session"."$Hemisphere".EdgeDistortion_MSMSulc."$HighResMesh"k_fs_LR.shape.gii -area-surfs "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".midthickness.native.surf.gii "$AtlasSpaceFolder"/"$Session"."$Hemisphere".midthickness."$HighResMesh"k_fs_LR.surf.gii
        ${CARET7DIR}/wb_command -metric-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".StrainJ_MSMSulc.native.shape.gii ${RegSphere} "$AtlasSpaceFolder"/"$Session"."$Hemisphere".sphere."$HighResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$AtlasSpaceFolder"/"$Session"."$Hemisphere".StrainJ_MSMSulc."$HighResMesh"k_fs_LR.shape.gii -area-surfs "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".midthickness.native.surf.gii "$AtlasSpaceFolder"/"$Session"."$Hemisphere".midthickness."$HighResMesh"k_fs_LR.surf.gii
        ${CARET7DIR}/wb_command -metric-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".StrainR_MSMSulc.native.shape.gii ${RegSphere} "$AtlasSpaceFolder"/"$Session"."$Hemisphere".sphere."$HighResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$AtlasSpaceFolder"/"$Session"."$Hemisphere".StrainR_MSMSulc."$HighResMesh"k_fs_LR.shape.gii -area-surfs "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".midthickness.native.surf.gii "$AtlasSpaceFolder"/"$Session"."$Hemisphere".midthickness."$HighResMesh"k_fs_LR.surf.gii
    fi
    ${CARET7DIR}/wb_command -metric-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".sulc.native.shape.gii ${RegSphere} "$AtlasSpaceFolder"/"$Session"."$Hemisphere".sphere."$HighResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$AtlasSpaceFolder"/"$Session"."$Hemisphere".sulc."$HighResMesh"k_fs_LR.shape.gii -area-surfs "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".midthickness.native.surf.gii "$AtlasSpaceFolder"/"$Session"."$Hemisphere".midthickness."$HighResMesh"k_fs_LR.surf.gii

    for Map in aparc aparc.a2009s ; do #Remove BA because it doesn't convert properly
        if [ -e "$FreeSurferFolder"/label/"$hemisphere"h."$Map".annot ] ; then
            ${CARET7DIR}/wb_command -label-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$Map".native.label.gii ${RegSphere} "$AtlasSpaceFolder"/"$Session"."$Hemisphere".sphere."$HighResMesh"k_fs_LR.surf.gii BARYCENTRIC "$AtlasSpaceFolder"/"$Session"."$Hemisphere"."$Map"."$HighResMesh"k_fs_LR.label.gii -largest
        fi
    done

    for LowResMesh in ${LowResMeshes} ; do
        #Copy Atlas Files
        cp "$SurfaceAtlasDIR"/"$Hemisphere".sphere."$LowResMesh"k_fs_LR.surf.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".sphere."$LowResMesh"k_fs_LR.surf.gii
        ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$LowResMesh"k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".sphere."$LowResMesh"k_fs_LR.surf.gii
        cp "$GrayordinatesSpaceDIR"/"$Hemisphere".atlasroi."$LowResMesh"k_fs_LR.shape.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".atlasroi."$LowResMesh"k_fs_LR.shape.gii
        if [ -e "$SurfaceAtlasDIR"/colin.cerebral."$Hemisphere".flat."$LowResMesh"k_fs_LR.surf.gii ] ; then
            cp "$SurfaceAtlasDIR"/colin.cerebral."$Hemisphere".flat."$LowResMesh"k_fs_LR.surf.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".flat."$LowResMesh"k_fs_LR.surf.gii
            ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$LowResMesh"k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".flat."$LowResMesh"k_fs_LR.surf.gii
        fi

        #Create downsampled fs_LR spec files.
        for Surface in white midthickness pial ; do
            ${CARET7DIR}/wb_command -surface-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$Surface".native.surf.gii ${RegSphere} "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".sphere."$LowResMesh"k_fs_LR.surf.gii BARYCENTRIC "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere"."$Surface"."$LowResMesh"k_fs_LR.surf.gii
            ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$LowResMesh"k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere"."$Surface"."$LowResMesh"k_fs_LR.surf.gii
        done

        #HCP fsaverage_LR32k used -iterations-scale 0.75. Recalculate in case using a different mesh
        LowResInflationScale=$(echo "scale=4; $InflateExtraScale * 0.75 * $LowResMesh / 32" | bc -l)

        ${CARET7DIR}/wb_command -surface-generate-inflated "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".inflated."$LowResMesh"k_fs_LR.surf.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".very_inflated."$LowResMesh"k_fs_LR.surf.gii -iterations-scale "$LowResInflationScale"
        ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$LowResMesh"k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".inflated."$LowResMesh"k_fs_LR.surf.gii
        ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$LowResMesh"k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".very_inflated."$LowResMesh"k_fs_LR.surf.gii

        for Map in sulc thickness curvature ; do
            ${CARET7DIR}/wb_command -metric-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$Map".native.shape.gii ${RegSphere} "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".sphere."$LowResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere"."$Map"."$LowResMesh"k_fs_LR.shape.gii -area-surfs "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".midthickness.native.surf.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii -current-roi "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".roi.native.shape.gii
            ${CARET7DIR}/wb_command -metric-mask "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere"."$Map"."$LowResMesh"k_fs_LR.shape.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".atlasroi."$LowResMesh"k_fs_LR.shape.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere"."$Map"."$LowResMesh"k_fs_LR.shape.gii
        done
        ${CARET7DIR}/wb_command -metric-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".ArealDistortion_FS.native.shape.gii ${RegSphere} "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".sphere."$LowResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".ArealDistortion_FS."$LowResMesh"k_fs_LR.shape.gii -area-surfs "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".midthickness.native.surf.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii
        ${CARET7DIR}/wb_command -metric-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".EdgeDistortion_FS.native.shape.gii ${RegSphere} "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".sphere."$LowResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".EdgeDistortion_FS."$LowResMesh"k_fs_LR.shape.gii -area-surfs "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".midthickness.native.surf.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii
        ${CARET7DIR}/wb_command -metric-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".StrainJ_FS.native.shape.gii ${RegSphere} "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".sphere."$LowResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".StrainJ_FS."$LowResMesh"k_fs_LR.shape.gii -area-surfs "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".midthickness.native.surf.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii
        ${CARET7DIR}/wb_command -metric-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".StrainR_FS.native.shape.gii ${RegSphere} "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".sphere."$LowResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".StrainR_FS."$LowResMesh"k_fs_LR.shape.gii -area-surfs "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".midthickness.native.surf.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii
        if [ ${RegName} = "MSMSulc" ] ; then
            ${CARET7DIR}/wb_command -metric-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".ArealDistortion_MSMSulc.native.shape.gii ${RegSphere} "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".sphere."$LowResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".ArealDistortion_MSMSulc."$LowResMesh"k_fs_LR.shape.gii -area-surfs "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".midthickness.native.surf.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii
            ${CARET7DIR}/wb_command -metric-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".EdgeDistortion_MSMSulc.native.shape.gii ${RegSphere} "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".sphere."$LowResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".EdgeDistortion_MSMSulc."$LowResMesh"k_fs_LR.shape.gii -area-surfs "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".midthickness.native.surf.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii
            ${CARET7DIR}/wb_command -metric-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".StrainJ_MSMSulc.native.shape.gii ${RegSphere} "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".sphere."$LowResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".StrainJ_MSMSulc."$LowResMesh"k_fs_LR.shape.gii -area-surfs "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".midthickness.native.surf.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii
            ${CARET7DIR}/wb_command -metric-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".StrainR_MSMSulc.native.shape.gii ${RegSphere} "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".sphere."$LowResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".StrainR_MSMSulc."$LowResMesh"k_fs_LR.shape.gii -area-surfs "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".midthickness.native.surf.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii
        fi
        ${CARET7DIR}/wb_command -metric-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere".sulc.native.shape.gii ${RegSphere} "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".sphere."$LowResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".sulc."$LowResMesh"k_fs_LR.shape.gii -area-surfs "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere".midthickness.native.surf.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii

        for Map in aparc aparc.a2009s ; do #Remove BA because it doesn't convert properly
            if [ -e "$FreeSurferFolder"/label/"$hemisphere"h."$Map".annot ] ; then
                ${CARET7DIR}/wb_command -label-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$Map".native.label.gii ${RegSphere} "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".sphere."$LowResMesh"k_fs_LR.surf.gii BARYCENTRIC "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere"."$Map"."$LowResMesh"k_fs_LR.label.gii -largest
            fi
        done

        #Create downsampled fs_LR spec file in structural space.
        for Surface in white midthickness pial ; do
            ${CARET7DIR}/wb_command -surface-resample "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$Surface".native.surf.gii ${RegSphere} "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".sphere."$LowResMesh"k_fs_LR.surf.gii BARYCENTRIC "$T1wFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere"."$Surface"."$LowResMesh"k_fs_LR.surf.gii
            ${CARET7DIR}/wb_command -add-to-spec-file "$T1wFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$LowResMesh"k_fs_LR.wb.spec $Structure "$T1wFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere"."$Surface"."$LowResMesh"k_fs_LR.surf.gii
        done

        #HCP fsaverage_LR32k used -iterations-scale 0.75. Recalculate in case using a different mesh
        LowResInflationScale=$(echo "scale=4; $InflateExtraScale * 0.75 * $LowResMesh / 32" | bc -l)

        ${CARET7DIR}/wb_command -surface-generate-inflated "$T1wFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii "$T1wFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".inflated."$LowResMesh"k_fs_LR.surf.gii "$T1wFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".very_inflated."$LowResMesh"k_fs_LR.surf.gii -iterations-scale "$LowResInflationScale"
        ${CARET7DIR}/wb_command -add-to-spec-file "$T1wFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$LowResMesh"k_fs_LR.wb.spec $Structure "$T1wFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".inflated."$LowResMesh"k_fs_LR.surf.gii
        ${CARET7DIR}/wb_command -add-to-spec-file "$T1wFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$LowResMesh"k_fs_LR.wb.spec $Structure "$T1wFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".very_inflated."$LowResMesh"k_fs_LR.surf.gii
    done
done


if [ "$LongitudinalMode" == "TIMEPOINT_STAGE1" ]; then
    log_Msg "Timepoint Stage 1 end"
    exit 0
fi #Stage 1 longitudinal timepoint processing ends here.

STRINGII=""
for LowResMesh in ${LowResMeshes} ; do
    STRINGII=$(echo "${STRINGII}${AtlasSpaceFolder}/fsaverage_LR${LowResMesh}k@${LowResMesh}k_fs_LR@atlasroi ")
done

#Create CIFTI Files
for STRING in "$AtlasSpaceFolder"/"$NativeFolder"@native@roi "$AtlasSpaceFolder"@"$HighResMesh"k_fs_LR@atlasroi ${STRINGII} ; do
    Folder=$(echo $STRING | cut -d "@" -f 1)
    Mesh=$(echo $STRING | cut -d "@" -f 2)
    ROI=$(echo $STRING | cut -d "@" -f 3)

    ${CARET7DIR}/wb_command -cifti-create-dense-scalar "$Folder"/"$Session".sulc."$Mesh".dscalar.nii -left-metric "$Folder"/"$Session".L.sulc."$Mesh".shape.gii -right-metric "$Folder"/"$Session".R.sulc."$Mesh".shape.gii
    ${CARET7DIR}/wb_command -set-map-names "$Folder"/"$Session".sulc."$Mesh".dscalar.nii -map 1 "${Session}_Sulc"
    ${CARET7DIR}/wb_command -cifti-palette "$Folder"/"$Session".sulc."$Mesh".dscalar.nii MODE_AUTO_SCALE_PERCENTAGE "$Folder"/"$Session".sulc."$Mesh".dscalar.nii -pos-percent 2 98 -palette-name Gray_Interp -disp-pos true -disp-neg true -disp-zero true

    ${CARET7DIR}/wb_command -cifti-create-dense-scalar "$Folder"/"$Session".curvature."$Mesh".dscalar.nii -left-metric "$Folder"/"$Session".L.curvature."$Mesh".shape.gii -roi-left "$Folder"/"$Session".L."$ROI"."$Mesh".shape.gii -right-metric "$Folder"/"$Session".R.curvature."$Mesh".shape.gii -roi-right "$Folder"/"$Session".R."$ROI"."$Mesh".shape.gii
    ${CARET7DIR}/wb_command -set-map-names "$Folder"/"$Session".curvature."$Mesh".dscalar.nii -map 1 "${Session}_Curvature"
    ${CARET7DIR}/wb_command -cifti-palette "$Folder"/"$Session".curvature."$Mesh".dscalar.nii MODE_AUTO_SCALE_PERCENTAGE "$Folder"/"$Session".curvature."$Mesh".dscalar.nii -pos-percent 2 98 -palette-name Gray_Interp -disp-pos true -disp-neg true -disp-zero true

    ${CARET7DIR}/wb_command -cifti-create-dense-scalar "$Folder"/"$Session".thickness."$Mesh".dscalar.nii -left-metric "$Folder"/"$Session".L.thickness."$Mesh".shape.gii -roi-left "$Folder"/"$Session".L."$ROI"."$Mesh".shape.gii -right-metric "$Folder"/"$Session".R.thickness."$Mesh".shape.gii -roi-right "$Folder"/"$Session".R."$ROI"."$Mesh".shape.gii
    ${CARET7DIR}/wb_command -set-map-names "$Folder"/"$Session".thickness."$Mesh".dscalar.nii -map 1 "${Session}_Thickness"
    ${CARET7DIR}/wb_command -cifti-palette "$Folder"/"$Session".thickness."$Mesh".dscalar.nii MODE_AUTO_SCALE_PERCENTAGE "$Folder"/"$Session".thickness."$Mesh".dscalar.nii -pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false

    ${CARET7DIR}/wb_command -cifti-create-dense-scalar "$Folder"/"$Session".ArealDistortion_FS."$Mesh".dscalar.nii -left-metric "$Folder"/"$Session".L.ArealDistortion_FS."$Mesh".shape.gii -right-metric "$Folder"/"$Session".R.ArealDistortion_FS."$Mesh".shape.gii
    ${CARET7DIR}/wb_command -set-map-names "$Folder"/"$Session".ArealDistortion_FS."$Mesh".dscalar.nii -map 1 "${Session}_ArealDistortion_FS"
    ${CARET7DIR}/wb_command -cifti-palette "$Folder"/"$Session".ArealDistortion_FS."$Mesh".dscalar.nii MODE_USER_SCALE "$Folder"/"$Session".ArealDistortion_FS."$Mesh".dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false

    ${CARET7DIR}/wb_command -cifti-create-dense-scalar "$Folder"/"$Session".EdgeDistortion_FS."$Mesh".dscalar.nii -left-metric "$Folder"/"$Session".L.EdgeDistortion_FS."$Mesh".shape.gii -right-metric "$Folder"/"$Session".R.EdgeDistortion_FS."$Mesh".shape.gii
    ${CARET7DIR}/wb_command -set-map-names "$Folder"/"$Session".EdgeDistortion_FS."$Mesh".dscalar.nii -map 1 "${Session}_EdgeDistortion_FS"
    ${CARET7DIR}/wb_command -cifti-palette "$Folder"/"$Session".EdgeDistortion_FS."$Mesh".dscalar.nii MODE_USER_SCALE "$Folder"/"$Session".EdgeDistortion_FS."$Mesh".dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false

    ${CARET7DIR}/wb_command -cifti-create-dense-scalar "$Folder"/"$Session".StrainJ_FS."$Mesh".dscalar.nii -left-metric "$Folder"/"$Session".L.StrainJ_FS."$Mesh".shape.gii -right-metric "$Folder"/"$Session".R.StrainJ_FS."$Mesh".shape.gii
    ${CARET7DIR}/wb_command -set-map-names "$Folder"/"$Session".StrainJ_FS."$Mesh".dscalar.nii -map 1 "${Session}_StrainJ_FS"
    ${CARET7DIR}/wb_command -cifti-palette "$Folder"/"$Session".StrainJ_FS."$Mesh".dscalar.nii MODE_USER_SCALE "$Folder"/"$Session".StrainJ_FS."$Mesh".dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false

    ${CARET7DIR}/wb_command -cifti-create-dense-scalar "$Folder"/"$Session".StrainR_FS."$Mesh".dscalar.nii -left-metric "$Folder"/"$Session".L.StrainR_FS."$Mesh".shape.gii -right-metric "$Folder"/"$Session".R.StrainR_FS."$Mesh".shape.gii
    ${CARET7DIR}/wb_command -set-map-names "$Folder"/"$Session".StrainR_FS."$Mesh".dscalar.nii -map 1 "${Session}_StrainR_FS"
    ${CARET7DIR}/wb_command -cifti-palette "$Folder"/"$Session".StrainR_FS."$Mesh".dscalar.nii MODE_USER_SCALE "$Folder"/"$Session".StrainR_FS."$Mesh".dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false

    if [ ${RegName} = "MSMSulc" ] ; then
        ${CARET7DIR}/wb_command -cifti-create-dense-scalar "$Folder"/"$Session".ArealDistortion_MSMSulc."$Mesh".dscalar.nii -left-metric "$Folder"/"$Session".L.ArealDistortion_MSMSulc."$Mesh".shape.gii -right-metric "$Folder"/"$Session".R.ArealDistortion_MSMSulc."$Mesh".shape.gii
        ${CARET7DIR}/wb_command -set-map-names "$Folder"/"$Session".ArealDistortion_MSMSulc."$Mesh".dscalar.nii -map 1 "${Session}_ArealDistortion_MSMSulc"
        ${CARET7DIR}/wb_command -cifti-palette "$Folder"/"$Session".ArealDistortion_MSMSulc."$Mesh".dscalar.nii MODE_USER_SCALE "$Folder"/"$Session".ArealDistortion_MSMSulc."$Mesh".dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false

        ${CARET7DIR}/wb_command -cifti-create-dense-scalar "$Folder"/"$Session".EdgeDistortion_MSMSulc."$Mesh".dscalar.nii -left-metric "$Folder"/"$Session".L.EdgeDistortion_MSMSulc."$Mesh".shape.gii -right-metric "$Folder"/"$Session".R.EdgeDistortion_MSMSulc."$Mesh".shape.gii
        ${CARET7DIR}/wb_command -set-map-names "$Folder"/"$Session".EdgeDistortion_MSMSulc."$Mesh".dscalar.nii -map 1 "${Session}_EdgeDistortion_MSMSulc"
        ${CARET7DIR}/wb_command -cifti-palette "$Folder"/"$Session".EdgeDistortion_MSMSulc."$Mesh".dscalar.nii MODE_USER_SCALE "$Folder"/"$Session".EdgeDistortion_MSMSulc."$Mesh".dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false

        ${CARET7DIR}/wb_command -cifti-create-dense-scalar "$Folder"/"$Session".StrainJ_MSMSulc."$Mesh".dscalar.nii -left-metric "$Folder"/"$Session".L.StrainJ_MSMSulc."$Mesh".shape.gii -right-metric "$Folder"/"$Session".R.StrainJ_MSMSulc."$Mesh".shape.gii
        ${CARET7DIR}/wb_command -set-map-names "$Folder"/"$Session".StrainJ_MSMSulc."$Mesh".dscalar.nii -map 1 "${Session}_StrainJ_MSMSulc"
        ${CARET7DIR}/wb_command -cifti-palette "$Folder"/"$Session".StrainJ_MSMSulc."$Mesh".dscalar.nii MODE_USER_SCALE "$Folder"/"$Session".StrainJ_MSMSulc."$Mesh".dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false

        ${CARET7DIR}/wb_command -cifti-create-dense-scalar "$Folder"/"$Session".StrainR_MSMSulc."$Mesh".dscalar.nii -left-metric "$Folder"/"$Session".L.StrainR_MSMSulc."$Mesh".shape.gii -right-metric "$Folder"/"$Session".R.StrainR_MSMSulc."$Mesh".shape.gii
        ${CARET7DIR}/wb_command -set-map-names "$Folder"/"$Session".StrainR_MSMSulc."$Mesh".dscalar.nii -map 1 "${Session}_StrainR_MSMSulc"
        ${CARET7DIR}/wb_command -cifti-palette "$Folder"/"$Session".StrainR_MSMSulc."$Mesh".dscalar.nii MODE_USER_SCALE "$Folder"/"$Session".StrainR_MSMSulc."$Mesh".dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false
    fi

    for Map in aparc aparc.a2009s ; do #Remove BA because it doesn't convert properly
        if [ -e "$Folder"/"$Session".L.${Map}."$Mesh".label.gii ] ; then
            ${CARET7DIR}/wb_command -cifti-create-label "$Folder"/"$Session".${Map}."$Mesh".dlabel.nii -left-label "$Folder"/"$Session".L.${Map}."$Mesh".label.gii -roi-left "$Folder"/"$Session".L."$ROI"."$Mesh".shape.gii -right-label "$Folder"/"$Session".R.${Map}."$Mesh".label.gii -roi-right "$Folder"/"$Session".R."$ROI"."$Mesh".shape.gii
            ${CARET7DIR}/wb_command -set-map-names "$Folder"/"$Session".${Map}."$Mesh".dlabel.nii -map 1 "$Session"_${Map}
        fi
    done
done

STRINGII=""
for LowResMesh in ${LowResMeshes} ; do
    STRINGII=$(echo "${STRINGII}${AtlasSpaceFolder}/fsaverage_LR${LowResMesh}k@${AtlasSpaceFolder}/fsaverage_LR${LowResMesh}k@${LowResMesh}k_fs_LR ${T1wFolder}/fsaverage_LR${LowResMesh}k@${AtlasSpaceFolder}/fsaverage_LR${LowResMesh}k@${LowResMesh}k_fs_LR ")
done

#Add CIFTI Maps to Spec Files
for STRING in "$T1wFolder"/"$NativeFolder"@"$AtlasSpaceFolder"/"$NativeFolder"@native "$AtlasSpaceFolder"/"$NativeFolder"@"$AtlasSpaceFolder"/"$NativeFolder"@native "$AtlasSpaceFolder"@"$AtlasSpaceFolder"@"$HighResMesh"k_fs_LR ${STRINGII} ; do
    FolderI=$(echo $STRING | cut -d "@" -f 1)
    FolderII=$(echo $STRING | cut -d "@" -f 2)
    Mesh=$(echo $STRING | cut -d "@" -f 3)
    for STRINGII in sulc@dscalar thickness@dscalar curvature@dscalar aparc@dlabel aparc.a2009s@dlabel ; do #Remove BA@dlabel because it doesn't convert properly
        Map=$(echo $STRINGII | cut -d "@" -f 1)
        Ext=$(echo $STRINGII | cut -d "@" -f 2)
        if [ -e "$FolderII"/"$Session"."$Map"."$Mesh"."$Ext".nii ] ; then
            ${CARET7DIR}/wb_command -add-to-spec-file "$FolderI"/"$Session"."$Mesh".wb.spec INVALID "$FolderII"/"$Session"."$Map"."$Mesh"."$Ext".nii
        fi
    done
done

# Create midthickness Vertex Area (VA) maps
log_Msg "Create midthickness Vertex Area (VA) maps"

for LowResMesh in ${LowResMeshes} ; do

    log_Msg "Creating midthickness Vertex Area (VA) maps for LowResMesh: ${LowResMesh}"

    # DownSampleT1wFolder             - path to folder containing downsampled T1w files
    # midthickness_va_file            - path to non-normalized midthickness vertex area file
    # normalized_midthickness_va_file - path ot normalized midthickness vertex area file
    # surface_to_measure              - path to surface file on which to measure surface areas
    # output_metric                   - path to metric file generated by -surface-vertex-areas subcommand

    DownSampleT1wFolder=${T1wFolder}/fsaverage_LR${LowResMesh}k
    DownSampleFolder=${AtlasSpaceFolder}/fsaverage_LR${LowResMesh}k
    midthickness_va_file=${DownSampleT1wFolder}/${Session}.midthickness_va.${LowResMesh}k_fs_LR.dscalar.nii
    normalized_midthickness_va_file=${DownSampleT1wFolder}/${Session}.midthickness_va_norm.${LowResMesh}k_fs_LR.dscalar.nii

    for Hemisphere in L R ; do
        surface_to_measure=${DownSampleT1wFolder}/${Session}.${Hemisphere}.midthickness.${LowResMesh}k_fs_LR.surf.gii
        output_metric=${DownSampleT1wFolder}/${Session}.${Hemisphere}.midthickness_va.${LowResMesh}k_fs_LR.shape.gii
        ${CARET7DIR}/wb_command -surface-vertex-areas ${surface_to_measure} ${output_metric}
    done

    # left_metric  - path to left hemisphere VA metric file
    # roi_left     - path to file of ROI vertices to use from left surface
    # right_metric - path to right hemisphere VA metric file
    # roi_right    - path to file of ROI vertices to use from right surface

    left_metric=${DownSampleT1wFolder}/${Session}.L.midthickness_va.${LowResMesh}k_fs_LR.shape.gii
    roi_left=${DownSampleFolder}/${Session}.L.atlasroi.${LowResMesh}k_fs_LR.shape.gii
    right_metric=${DownSampleT1wFolder}/${Session}.R.midthickness_va.${LowResMesh}k_fs_LR.shape.gii
    roi_right=${DownSampleFolder}/${Session}.R.atlasroi.${LowResMesh}k_fs_LR.shape.gii

    ${CARET7DIR}/wb_command -cifti-create-dense-scalar ${midthickness_va_file} \
                -left-metric  ${left_metric} \
                -roi-left     ${roi_left} \
                -right-metric ${right_metric} \
                -roi-right    ${roi_right}

    # VAMean - mean of surface area accounted for for each vertex - used for normalization
    VAMean=$(${CARET7DIR}/wb_command -cifti-stats ${midthickness_va_file} -reduce MEAN)
    log_Msg "VAMean: ${VAMean}"

    ${CARET7DIR}/wb_command -cifti-math "VA / ${VAMean}" ${normalized_midthickness_va_file} -var VA ${midthickness_va_file}

    log_Msg "Done creating midthickness Vertex Area (VA) maps for LowResMesh: ${LowResMesh}"

done

log_Msg "Done creating midthickness Vertex Area (VA) maps"

log_Msg "END"


