#!/bin/bash

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

script_name=$(basename "${0}")

show_usage() {
    cat <<EOF

${script_name}: Sub-script of MMORFPipeline.sh

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


T1wImage="$6"
log_Msg "T1wImage: ${T1wImage}"

T2wImage="$7"
log_Msg "T2wImage: ${T2wImage}"



HighResMesh="${8}"
log_Msg "HighResMesh: ${HighResMesh}"

LowResMeshes="${9}"
log_Msg "LowResMeshes: ${LowResMeshes}"

AtlasTransform="${10}"
log_Msg "AtlasTransform: ${AtlasTransform}"

InverseAtlasTransform="${11}"
log_Msg "InverseAtlasTransform: ${InverseAtlasTransform}"

AtlasSpaceT1wImage="${12}"
log_Msg "AtlasSpaceT1wImage: ${AtlasSpaceT1wImage}"

AtlasSpaceT2wImage="${13}"
log_Msg "AtlasSpaceT2wImage: ${AtlasSpaceT2wImage}"

T1wImageBrainMask="${14}"
log_Msg "T1wImageBrainMask: ${T1wImageBrainMask}"


RegName="${15}"
log_Msg "RegName: ${RegName}"

RegNameOrig="${16}"
log_Msg "RegNameOrig: ${RegNameOrig}"

InflateExtraScale="${17}"
log_Msg "InflateExtraScale: ${InflateExtraScale}"


MNINonLinearFolder="$StudyFolder"/"$Session"/"MNINonLinear"


LowResMeshes=${LowResMeshes//@/ }
log_Msg "LowResMeshes: ${LowResMeshes}"

#if [ ! -e "$AtlasSpaceFolder"/Results ] ; then
#    mkdir "$AtlasSpaceFolder"/Results
#fi
if [ ! -e "$AtlasSpaceFolder"/"$NativeFolder" ] ; then
    mkdir "$AtlasSpaceFolder"/"$NativeFolder"
fi
#if [ ! -e "$AtlasSpaceFolder"/fsaverage ] ; then
#    mkdir "$AtlasSpaceFolder"/fsaverage
#fi
for LowResMesh in ${LowResMeshes} ; do
    if [ ! -e "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k ] ; then
        mkdir "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k
    fi
done

if [ ! -e "$AtlasSpaceFolder"/fsaverage_LR"$HighResMesh"k ] ; then
    mkdir "$AtlasSpaceFolder"/fsaverage_LR"$HighResMesh"k
fi

if [ ! -e "$AtlasSpaceFolder"/ROIs ] ; then
    mkdir -p "$AtlasSpaceFolder"/ROIs
fi

if [ ! -e "$AtlasSpaceFolder"/Results ] ; then
    mkdir "$AtlasSpaceFolder"/Results
fi


[ "${T2wImage}" != "NONE" ] && ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/"$NativeFolder"/"$Session".native.wb.spec INVALID "$AtlasSpaceFolder"/"$AtlasSpaceT2wImage".nii.gz
${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/"$NativeFolder"/"$Session".native.wb.spec INVALID "$AtlasSpaceFolder"/"$AtlasSpaceT1wImage".nii.gz

[ "${T2wImage}" != "NONE" ] && ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$HighResMesh"k/"$Session"."$HighResMesh"k_fs_LR.wb.spec INVALID "$AtlasSpaceFolder"/"$AtlasSpaceT2wImage".nii.gz
${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$HighResMesh"k/"$Session"."$HighResMesh"k_fs_LR.wb.spec INVALID "$AtlasSpaceFolder"/"$AtlasSpaceT1wImage".nii.gz

[ "${T2wImage}" != "NONE" ] && ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$HighResMesh"k/"$Session"."$RegName"."$HighResMesh"k_fs_LR.wb.spec INVALID "$AtlasSpaceFolder"/"$AtlasSpaceT2wImage".nii.gz
${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$HighResMesh"k/"$Session"."$RegName"."$HighResMesh"k_fs_LR.wb.spec INVALID "$AtlasSpaceFolder"/"$AtlasSpaceT1wImage".nii.gz

for LowResMesh in ${LowResMeshes} ; do
    [ "${T2wImage}" != "NONE" ] && ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$LowResMesh"k_fs_LR.wb.spec INVALID "$AtlasSpaceFolder"/"$AtlasSpaceT2wImage".nii.gz
    ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$LowResMesh"k_fs_LR.wb.spec INVALID "$AtlasSpaceFolder"/"$AtlasSpaceT1wImage".nii.gz

    [ "${T2wImage}" != "NONE" ] && ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$RegName"."$LowResMesh"k_fs_LR.wb.spec INVALID "$AtlasSpaceFolder"/"$AtlasSpaceT2wImage".nii.gz
    ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$RegName"."$LowResMesh"k_fs_LR.wb.spec INVALID "$AtlasSpaceFolder"/"$AtlasSpaceT1wImage".nii.gz
done


LabelStems=(
    aparc.a2009s
    aparc
    BA
)

ScalarStems=(
    corrThickness
    curvature
    MyelinMap_BC
    SmoothedMyelinMap_BC
    sulc
    thickness
    MRcorrThickness
)

# -----------------------------
# Function: add a file to a spec
# -----------------------------
add_to_spec() {
    local Spec="$1"
    local File="$2"
    local Path="$3"

    [[ -f "$Path" ]] || echo "Warning: file not found $Path"
    ${CARET7DIR}/wb_command -add-to-spec-file "$Spec" INVALID "$Path"
}

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
    for Surface in white pial ; do
        Type=$(echo "$Types" | cut -d " " -f $i)
        Secondary=$(echo "$Type" | cut -d "@" -f 2)
        Type=$(echo "$Type" | cut -d "@" -f 1)
        if [ ! $Secondary = $Type ] ; then
            Secondary=$(echo " -surface-secondary-type ""$Secondary")
        else
            Secondary=""
        fi

        
        ${CARET7DIR}/wb_command -surface-apply-warpfield "$T1wFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$Surface".native.surf.gii "$InverseAtlasTransform".nii.gz "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$Surface".native.surf.gii -fnirt "$AtlasTransform".nii.gz
        ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/"$NativeFolder"/"$Session".native.wb.spec $Structure "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$Surface".native.surf.gii
        i=$(( i+1 ))
    done

        #Create midthickness by averaging white and pial surfaces and use it to make inflated surfacess
    for Folder in "$AtlasSpaceFolder" ; do
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

    
            
    CurrentSphere="${MNINonLinearFolder}/${NativeFolder}/${Session}.${Hemisphere}.sphere.${RegNameOrig}.native.surf.gii"

    NewSphere="${HCPPIPEDIR}/global/templates/standard_mesh_atlases/${Hemisphere}.sphere.${HighResMesh}k_fs_LR.surf.gii"
    [ ! -f "${MNINonLinearFolder}/${Session}.${Hemisphere}.sphere."$HighResMesh"k_fs_LR.surf.gii" ] && cp "$NewSphere" "${MNINonLinearFolder}/${Session}.${Hemisphere}.sphere."$HighResMesh"k_fs_LR.surf.gii"
    [ ! -f "${MNINonLinearFolder}/${Session}.${Hemisphere}.atlasroi."$HighResMesh"k_fs_LR.shape.gii" ] && cp "${HCPPIPEDIR}/global/templates/standard_mesh_atlases/${Hemisphere}.atlasroi."$HighResMesh"k_fs_LR.shape.gii" "${MNINonLinearFolder}/${Session}.${Hemisphere}.atlasroi."$HighResMesh"k_fs_LR.shape.gii"
    [ ! -f "${MNINonLinearFolder}/${Session}.${Hemisphere}.flat."$HighResMesh"k_fs_LR.surf.gii" ] && cp "${HCPPIPEDIR}/global/templates/standard_mesh_atlases/colin.cerebral.${Hemisphere}.flat."$HighResMesh"k_fs_LR.surf.gii" "${MNINonLinearFolder}/${Session}.${Hemisphere}.flat."$HighResMesh"k_fs_LR.surf.gii"

    add_to_spec "$AtlasSpaceFolder/fsaverage_LR"$HighResMesh"k/"$Session"."$HighResMesh"k_fs_LR.wb.spec" "" "${MNINonLinearFolder}/${Session}.${Hemisphere}.sphere."$HighResMesh"k_fs_LR.surf.gii"
    add_to_spec "$AtlasSpaceFolder/fsaverage_LR"$HighResMesh"k/"$Session"."$HighResMesh"k_fs_LR.wb.spec" "" "${MNINonLinearFolder}/${Session}.${Hemisphere}.atlasroi."$HighResMesh"k_fs_LR.shape.gii"
    add_to_spec "$AtlasSpaceFolder/fsaverage_LR"$HighResMesh"k/"$Session"."$HighResMesh"k_fs_LR.wb.spec" "" "${MNINonLinearFolder}/${Session}.${Hemisphere}.flat."$HighResMesh"k_fs_LR.surf.gii"

    add_to_spec "$AtlasSpaceFolder/fsaverage_LR"$HighResMesh"k/"$Session"."$RegName"."$HighResMesh"k_fs_LR.wb.spec" "" "${MNINonLinearFolder}/${Session}.${Hemisphere}.sphere."$HighResMesh"k_fs_LR.surf.gii"
    add_to_spec "$AtlasSpaceFolder/fsaverage_LR"$HighResMesh"k/"$Session"."$RegName"."$HighResMesh"k_fs_LR.wb.spec" "" "${MNINonLinearFolder}/${Session}.${Hemisphere}.atlasroi."$HighResMesh"k_fs_LR.shape.gii"
    add_to_spec "$AtlasSpaceFolder/fsaverage_LR"$HighResMesh"k/"$Session"."$RegName"."$HighResMesh"k_fs_LR.wb.spec" "" "${MNINonLinearFolder}/${Session}.${Hemisphere}.flat."$HighResMesh"k_fs_LR.surf.gii"


    #Populate Highres fs_LR spec file.  Deform surfaces and other data according to native to folding-based registration selected above.  Regenerate inflated surfaces.
    for Surface in white midthickness pial ; do
        ${CARET7DIR}/wb_command -surface-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$Surface".native.surf.gii ${CurrentSphere} ${NewSphere} BARYCENTRIC "$AtlasSpaceFolder"/fsaverage_LR"$HighResMesh"k/"$Session"."$Hemisphere"."$Surface"."$HighResMesh"k_fs_LR.surf.gii
        ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$HighResMesh"k/"$Session"."$HighResMesh"k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/fsaverage_LR"$HighResMesh"k/"$Session"."$Hemisphere"."$Surface"."$HighResMesh"k_fs_LR.surf.gii
    done

    #HCP fsaverage_LR32k used -iterations-scale 0.75. Compute new param value for high res mesh density
    HighResInflationScale=$(echo "scale=4; $InflateExtraScale * 0.75 * $HighResMesh / 32" | bc -l)

    ${CARET7DIR}/wb_command -surface-generate-inflated "$AtlasSpaceFolder"/fsaverage_LR"$HighResMesh"k/"$Session"."$Hemisphere".midthickness."$HighResMesh"k_fs_LR.surf.gii "$AtlasSpaceFolder"/fsaverage_LR"$HighResMesh"k/"$Session"."$Hemisphere".inflated."$HighResMesh"k_fs_LR.surf.gii "$AtlasSpaceFolder"/fsaverage_LR"$HighResMesh"k/"$Session"."$Hemisphere".very_inflated."$HighResMesh"k_fs_LR.surf.gii -iterations-scale $HighResInflationScale
    ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$HighResMesh"k/"$Session"."$HighResMesh"k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/fsaverage_LR"$HighResMesh"k/"$Session"."$Hemisphere".inflated."$HighResMesh"k_fs_LR.surf.gii
    ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$HighResMesh"k/"$Session"."$HighResMesh"k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/fsaverage_LR"$HighResMesh"k/"$Session"."$Hemisphere".very_inflated."$HighResMesh"k_fs_LR.surf.gii

    CurrentSphere="${MNINonLinearFolder}/${NativeFolder}/${Session}.${Hemisphere}.sphere.${RegName}.native.surf.gii"

    #Populate Highres fs_LR spec file.  Deform surfaces and other data according to native to folding-based registration selected above.  Regenerate inflated surfaces.
    for Surface in white midthickness pial ; do
        ${CARET7DIR}/wb_command -surface-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$Surface".native.surf.gii ${CurrentSphere} ${NewSphere} BARYCENTRIC "$AtlasSpaceFolder"/fsaverage_LR"$HighResMesh"k/"$Session"."$Hemisphere"."$Surface"_${RegName}."$HighResMesh"k_fs_LR.surf.gii
        ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$HighResMesh"k/"$Session"."$RegName"."$HighResMesh"k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/fsaverage_LR"$HighResMesh"k/"$Session"."$Hemisphere"."$Surface"_${RegName}."$HighResMesh"k_fs_LR.surf.gii
    done

    #HCP fsaverage_LR32k used -iterations-scale 0.75. Compute new param value for high res mesh density
    HighResInflationScale=$(echo "scale=4; $InflateExtraScale * 0.75 * $HighResMesh / 32" | bc -l)

    ${CARET7DIR}/wb_command -surface-generate-inflated "$AtlasSpaceFolder"/fsaverage_LR"$HighResMesh"k/"$Session"."$Hemisphere".midthickness_${RegName}."$HighResMesh"k_fs_LR.surf.gii "$AtlasSpaceFolder"/fsaverage_LR"$HighResMesh"k/"$Session"."$Hemisphere".inflated_${RegName}."$HighResMesh"k_fs_LR.surf.gii "$AtlasSpaceFolder"/fsaverage_LR"$HighResMesh"k/"$Session"."$Hemisphere".very_inflated_${RegName}."$HighResMesh"k_fs_LR.surf.gii -iterations-scale $HighResInflationScale
    ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$HighResMesh"k/"$Session"."$RegName"."$HighResMesh"k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/fsaverage_LR"$HighResMesh"k/"$Session"."$Hemisphere".inflated_${RegName}."$HighResMesh"k_fs_LR.surf.gii
    ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$HighResMesh"k/"$Session"."$RegName"."$HighResMesh"k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/fsaverage_LR"$HighResMesh"k/"$Session"."$Hemisphere".very_inflated_${RegName}."$HighResMesh"k_fs_LR.surf.gii
    for LowResMesh in ${LowResMeshes} ; do
        #Create downsampled fs_LR spec file in structural space.
        if [[ ! -d "${MNINonLinearFolder}/fsaverage_LR"$LowResMesh"k" ]]; then
            mkdir -p "${MNINonLinearFolder}/fsaverage_LR"$LowResMesh"k"
        fi


        LowResMeshTemp="${LowResMesh}k"
        CurrentSphere="${MNINonLinearFolder}/${NativeFolder}/${Session}.${Hemisphere}.sphere.${RegNameOrig}.native.surf.gii"
        NewSphere="${HCPPIPEDIR}/global/templates/standard_mesh_atlases/${Hemisphere}.sphere.${LowResMeshTemp}_fs_LR.surf.gii"

        [ ! -f "${MNINonLinearFolder}/fsaverage_LR"$LowResMesh"k/${Session}.${Hemisphere}.sphere."$LowResMesh"k_fs_LR.surf.gii" ] && cp "$NewSphere" "${MNINonLinearFolder}/fsaverage_LR"$LowResMesh"k/${Session}.${Hemisphere}.sphere."$LowResMesh"k_fs_LR.surf.gii"
        [ ! -f "${MNINonLinearFolder}/fsaverage_LR"$LowResMesh"k/${Session}.${Hemisphere}.atlasroi."$LowResMesh"k_fs_LR.shape.gii" ] && cp "${HCPPIPEDIR}/global/templates/standard_mesh_atlases/${Hemisphere}.atlasroi."$LowResMesh"k_fs_LR.shape.gii" "${MNINonLinearFolder}/fsaverage_LR"$LowResMesh"k/${Session}.${Hemisphere}.atlasroi."$LowResMesh"k_fs_LR.shape.gii"
        [ ! -f "${MNINonLinearFolder}/fsaverage_LR"$LowResMesh"k/${Session}.${Hemisphere}.flat."$LowResMesh"k_fs_LR.surf.gii" ] && cp "${HCPPIPEDIR}/global/templates/standard_mesh_atlases/colin.cerebral.${Hemisphere}.flat."$LowResMesh"k_fs_LR.surf.gii" "${MNINonLinearFolder}/fsaverage_LR"$LowResMesh"k/${Session}.${Hemisphere}.flat."$LowResMesh"k_fs_LR.surf.gii"

        add_to_spec "$AtlasSpaceFolder/fsaverage_LR"$LowResMesh"k/"$Session"."$LowResMesh"k_fs_LR.wb.spec" "" "${MNINonLinearFolder}/fsaverage_LR"$LowResMesh"k/${Session}.${Hemisphere}.sphere."$LowResMesh"k_fs_LR.surf.gii"
        add_to_spec "$AtlasSpaceFolder/fsaverage_LR"$LowResMesh"k/"$Session"."$LowResMesh"k_fs_LR.wb.spec" "" "${MNINonLinearFolder}/fsaverage_LR"$LowResMesh"k/${Session}.${Hemisphere}.atlasroi."$LowResMesh"k_fs_LR.shape.gii"
        add_to_spec "$AtlasSpaceFolder/fsaverage_LR"$LowResMesh"k/"$Session"."$LowResMesh"k_fs_LR.wb.spec" "" "${MNINonLinearFolder}/fsaverage_LR"$LowResMesh"k/${Session}.${Hemisphere}.flat."$LowResMesh"k_fs_LR.surf.gii"

        add_to_spec "$AtlasSpaceFolder/fsaverage_LR"$LowResMesh"k/"$Session"."$RegName"."$LowResMesh"k_fs_LR.wb.spec" "" "${MNINonLinearFolder}/fsaverage_LR"$LowResMesh"k/${Session}.${Hemisphere}.sphere."$LowResMesh"k_fs_LR.surf.gii"
        add_to_spec "$AtlasSpaceFolder/fsaverage_LR"$LowResMesh"k/"$Session"."$RegName"."$LowResMesh"k_fs_LR.wb.spec" "" "${MNINonLinearFolder}/fsaverage_LR"$LowResMesh"k/${Session}.${Hemisphere}.atlasroi."$LowResMesh"k_fs_LR.shape.gii"
        add_to_spec "$AtlasSpaceFolder/fsaverage_LR"$LowResMesh"k/"$Session"."$RegName"."$LowResMesh"k_fs_LR.wb.spec" "" "${MNINonLinearFolder}/fsaverage_LR"$LowResMesh"k/${Session}.${Hemisphere}.flat."$LowResMesh"k_fs_LR.surf.gii"


        for Surface in white midthickness pial ; do
            ${CARET7DIR}/wb_command -surface-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$Surface".native.surf.gii ${CurrentSphere} ${NewSphere} BARYCENTRIC "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere"."$Surface"."$LowResMesh"k_fs_LR.surf.gii
            ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$LowResMesh"k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere"."$Surface"."$LowResMesh"k_fs_LR.surf.gii
        done

        #HCP fsaverage_LR32k used -iterations-scale 0.75. Recalculate in case using a different mesh
        LowResInflationScale=$(echo "scale=4; $InflateExtraScale * 0.75 * $LowResMesh / 32" | bc -l)

        ${CARET7DIR}/wb_command -surface-generate-inflated "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".inflated."$LowResMesh"k_fs_LR.surf.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".very_inflated."$LowResMesh"k_fs_LR.surf.gii -iterations-scale $LowResInflationScale
        ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$LowResMesh"k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".inflated."$LowResMesh"k_fs_LR.surf.gii
        ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$LowResMesh"k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".very_inflated."$LowResMesh"k_fs_LR.surf.gii

        CurrentSphere="${MNINonLinearFolder}/${NativeFolder}/${Session}.${Hemisphere}.sphere.${RegName}.native.surf.gii"


    #Populate Highres fs_LR spec file.  Deform surfaces and other data according to native to folding-based registration selected above.  Regenerate inflated surfaces.
        for Surface in white midthickness pial ; do
            ${CARET7DIR}/wb_command -surface-resample "$AtlasSpaceFolder"/"$NativeFolder"/"$Session"."$Hemisphere"."$Surface".native.surf.gii ${CurrentSphere} ${NewSphere} BARYCENTRIC "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere"."$Surface"_"$RegName"."$LowResMesh"k_fs_LR.surf.gii
            ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$RegName"."$LowResMesh"k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere"."$Surface"_"$RegName"."$LowResMesh"k_fs_LR.surf.gii
        done

    #HCP fsaverage_LR32k used -iterations-scale 0.75. Compute new param value for high res mesh density
        LowResInflationScale=$(echo "scale=4; $InflateExtraScale * 0.75 * $LowResMesh / 32" | bc -l)

        ${CARET7DIR}/wb_command -surface-generate-inflated "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".midthickness_"$RegName"."$LowResMesh"k_fs_LR.surf.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".inflated_"$RegName"."$LowResMesh"k_fs_LR.surf.gii "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".very_inflated_"$RegName"."$LowResMesh"k_fs_LR.surf.gii -iterations-scale $LowResInflationScale
        ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$RegName"."$LowResMesh"k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".inflated_"$RegName"."$LowResMesh"k_fs_LR.surf.gii
        ${CARET7DIR}/wb_command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$RegName"."$LowResMesh"k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/fsaverage_LR"$LowResMesh"k/"$Session"."$Hemisphere".very_inflated_"$RegName"."$LowResMesh"k_fs_LR.surf.gii
    done
done

# -----------------------------
# Function: resample CIFTI to mesh if missing
# -----------------------------
resample_cifti_to_mesh() {
    local InCifti="$1"
    local Mesh="$2"
    local MeshFolder="$3"
    local RegName="$4"  # optional registration name

    [[ "$Mesh" != *k ]] && Mesh="${Mesh}k"

    local Base
    Base=$(basename "$InCifti")
    local OutCifti

    if [[ ! -d "${MNINonLinearFolder}/${MeshFolder}" ]]; then
        mkdir -p "${MNINonLinearFolder}/${MeshFolder}"
    fi

    # Default output name
    OutCifti="${MNINonLinearFolder}/${MeshFolder}/${Base/.native./.${Mesh}_fs_LR.}"

    # If RegName exists, change output name
    if [[ -n "$RegName" ]]; then
        OutCifti="${MNINonLinearFolder}/${MeshFolder}/${Base/.native./_${RegName}.${Mesh}_fs_LR.}"
    fi

    [[ -f "$OutCifti" ]] && { echo "CIFTI already exists: $OutCifti"; return; }

    echo "Resampling CIFTI to ${Mesh} mesh:"
    echo "  IN : $InCifti"
    echo "  OUT: $OutCifti"

    # --- Native geometry ---
    local L_SPHERE_NATIVE="${MNINonLinearFolder}/${NativeFolder}/${Session}.L.sphere.${RegNameOrig}.native.surf.gii"
    local R_SPHERE_NATIVE="${MNINonLinearFolder}/${NativeFolder}/${Session}.R.sphere.${RegNameOrig}.native.surf.gii"

    # If RegName is provided, replace native spheres with registered spheres
    if [[ -n "$RegName" ]]; then
        L_SPHERE_NATIVE="${MNINonLinearFolder}/${NativeFolder}/${Session}.L.sphere.${RegName}.native.surf.gii"
        R_SPHERE_NATIVE="${MNINonLinearFolder}/${NativeFolder}/${Session}.R.sphere.${RegName}.native.surf.gii"
    fi

    local L_AREA_NATIVE="${AtlasSpaceFolder}/${NativeFolder}/${Session}.L.midthickness.native.surf.gii"
    local R_AREA_NATIVE="${AtlasSpaceFolder}/${NativeFolder}/${Session}.R.midthickness.native.surf.gii"

    # --- Output geometry ---
    local L_SPHERE_OUT
    local R_SPHERE_OUT
    L_SPHERE_OUT="${HCPPIPEDIR}/global/templates/standard_mesh_atlases/L.sphere.${Mesh}_fs_LR.surf.gii"
    R_SPHERE_OUT="${HCPPIPEDIR}/global/templates/standard_mesh_atlases/R.sphere.${Mesh}_fs_LR.surf.gii"

    local L_AREA_OUT="${AtlasSpaceFolder}/${MeshFolder}/${Session}.L.midthickness.${Mesh}_fs_LR.surf.gii"
    local R_AREA_OUT="${AtlasSpaceFolder}/${MeshFolder}/${Session}.R.midthickness.${Mesh}_fs_LR.surf.gii"

    if [[ -n "$RegName" ]]; then
        L_AREA_OUT="${AtlasSpaceFolder}/${MeshFolder}/${Session}.L.midthickness_${RegName}.${Mesh}_fs_LR.surf.gii"
        R_AREA_OUT="${AtlasSpaceFolder}/${MeshFolder}/${Session}.R.midthickness_${RegName}.${Mesh}_fs_LR.surf.gii"
    fi

    local GREYORD
    GREYORD="${HCPPIPEDIR}/global/templates/AtlasROI_80k.dscalar.nii"

    ${CARET7DIR}/wb_command -cifti-resample \
        "$InCifti" COLUMN \
        "$GREYORD" COLUMN \
        ADAP_BARY_AREA CUBIC "$OutCifti" \
        -left-spheres "$L_SPHERE_NATIVE" "$L_SPHERE_OUT" \
        -left-area-surfs "$L_AREA_NATIVE" "$L_AREA_OUT" \
        -right-spheres "$R_SPHERE_NATIVE" "$R_SPHERE_OUT" \
        -right-area-surfs "$R_AREA_NATIVE" "$R_AREA_OUT"
}





# -----------------------------
# Helper: process a mesh folder (dlabel + dscalar + optional Myelin)
# -----------------------------
process_mesh_folder() {
    local MeshFolder="$1"
    local Prefix="$2"
    local RegName="$3"
    local IncludeMyelin="$4"  # "yes" or "no"
    local Mesh="$5"           # e.g., "32k", "59k"

    local Spec="${AtlasSpaceFolder}/${MeshFolder}/${Session}${Prefix}.wb.spec"

    # --- dlabel files ---
    for Stem in "${LabelStems[@]}"; do
        File="${Session}.${Stem}${Prefix}.dlabel.nii"
        Path="${MNINonLinearFolder}/${MeshFolder}/${File}"
        local InCifti="${MNINonLinearFolder}/${NativeFolder}/${Session}.${Stem}.native.dlabel.nii"

        # HighResMesh special case
        [[ "$MeshFolder" == "fsaverage_LR${HighResMesh}k" ]] && Path="${MNINonLinearFolder}/${File}"
        [[ ! -f "$Path" ]] && resample_cifti_to_mesh "$InCifti" "$Mesh" "$MeshFolder" ""

        add_to_spec "$Spec" "$File" "$Path"
    done

    # --- dscalar files ---
    for Stem in "${ScalarStems[@]}"; do
        if [[ "$MeshFolder" == "$NativeFolder" ]]; then
            File="${Session}.${Stem}${Prefix}.dscalar.nii"
            Path="${MNINonLinearFolder}/${MeshFolder}/${File}"
        else
            # LowResMesh: resample from native if missing
            local InCifti="${MNINonLinearFolder}/${NativeFolder}/${Session}.${Stem}.native.dscalar.nii"
            File="${Session}.${Stem}.${Mesh}_fs_LR.dscalar.nii"
            Path="${MNINonLinearFolder}/${MeshFolder}/${File}"
            
            [[ "$MeshFolder" == "fsaverage_LR${HighResMesh}k" ]] && Path="${MNINonLinearFolder}/${File}"
            [[ ! -f "$Path" ]] && resample_cifti_to_mesh "$InCifti" "$Mesh" "$MeshFolder" ""
        fi
        add_to_spec "$Spec" "$File" "$Path"
    done
        
    local Spec="${AtlasSpaceFolder}/${MeshFolder}/${Session}.${RegName}${Prefix}.wb.spec"

    for Stem in "${ScalarStems[@]}"; do
        if [[ "$MeshFolder" == "$NativeFolder" ]]; then
            continue
        else
            # LowResMesh: resample from native if missing
            local InCifti="${MNINonLinearFolder}/${NativeFolder}/${Session}.${Stem}.native.dscalar.nii"
            File="${Session}.${Stem}_${RegName}.${Mesh}_fs_LR.dscalar.nii"
            Path="${MNINonLinearFolder}/${MeshFolder}/${File}"
            [[ "$MeshFolder" == "fsaverage_LR${HighResMesh}k" ]] && Path="${MNINonLinearFolder}/${File}"
            [[ ! -f "$Path" ]] && resample_cifti_to_mesh "$InCifti" "$Mesh" "$MeshFolder" "$RegName"
        fi
        add_to_spec "$Spec" "$File" "$Path"
    done
        
    local Spec="${AtlasSpaceFolder}/${MeshFolder}/${Session}${Prefix}.wb.spec"

    # --- Myelin maps for native only ---
    if [[ "$IncludeMyelin" == "yes" ]]; then
        for Map in "MyelinMap_BC_${RegName}" "SmoothedMyelinMap_BC_${RegName}"; do
            File="${Session}.${Map}${Prefix}.dscalar.nii"
            Path="${MNINonLinearFolder}/${MeshFolder}/${File}"
            add_to_spec "$Spec" "$File" "$Path"
        done
    fi
}


process_mesh_folder "$NativeFolder" ".native" "$RegName" "yes" "native"

MeshFolder="fsaverage_LR${HighResMesh}k"
Mesh="${HighResMesh}k"
process_mesh_folder "$MeshFolder" ".${Mesh}_fs_LR" "$RegName" "no" "$Mesh"

for LowResMesh in ${LowResMeshes}; do
    MeshFolder="fsaverage_LR${LowResMesh}k"
    Mesh="${LowResMesh}k"
    process_mesh_folder "$MeshFolder" ".${Mesh}_fs_LR" "$RegName" "no" "$Mesh"
done


log_Msg "END"

