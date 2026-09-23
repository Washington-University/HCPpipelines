#!/bin/bash
set -eu
pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
   pipedirguessed=1
   #fix this if the script is more than one level below HCPPIPEDIR
   export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"


opts_SetScriptDescription "Organize HippUnfold outputs in T1w, MNINonLinear, and MMORF spaces"

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject' 'Subject' 'subject ID' ""
opts_AddOptional '--hippunfold-dir' 'PhysicalHippUnfoldDIR' 'path' "location of HippUnfold outputs"
opts_AddOptional '--atlas-hippunfold-dir' 'AtlasHippUnfoldDIR' 'path' "location of Atlas HippUnfold outputs"
opts_AddOptional '--hippunfold-mesh' 'HippUnfoldMesh' '@-delimited list' "HippUnfold meshes to generate, ordered to match --brain-mesh" 'native@512@2k@8k@18k'
opts_AddOptional '--brain-mesh' 'BrainMesh' '@-delimited list' "whole-brain meshes paired by position with --hippunfold-mesh" 'native@32k@32k@164k@164k'

opts_ParseArguments "$@"
if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

opts_ShowValues

log_Msg "Starting PostHippUnfold pipeline for subject: $Subject"

T1wFolder="$StudyFolder/$Subject/T1w"
AtlasFolder="$StudyFolder/$Subject/MNINonLinear"
MMORFFolder="$StudyFolder/$Subject/MMORFNonLinear"
MMORFHippUnfoldDIR="${MMORFFolder}/HippUnfold"

MMORFVolumeWarp="${MMORFFolder}/xfms/acpc_dc2mmorf.nii.gz"
MMORFSurfaceWarp="${MMORFFolder}/xfms/mmorf2acpc_dc.nii.gz"
MMORFReferenceVolume="${MMORFFolder}/T1w_restore.nii.gz"

runMMORF=false

if [[ -f "$MMORFVolumeWarp" && -f "$MMORFSurfaceWarp" && -f "$MMORFReferenceVolume" ]]; then
    runMMORF=true
else
    log_Msg "WARNING: MMORF files are incomplete; skipping MMORF HippUnfold outputs"
fi

if [ -z ${PhysicalHippUnfoldDIR-} ] ; then
  PhysicalHippUnfoldDIR="${T1wFolder}/HippUnfold"
fi 

if [ -z ${AtlasHippUnfoldDIR-} ] ; then
  AtlasHippUnfoldDIR="${AtlasFolder}/HippUnfold"
fi 

RawHippUnfoldFolder="${PhysicalHippUnfoldDIR}/sub-${Subject}"

IFS='@' read -r -a Meshes <<< "$HippUnfoldMesh"
IFS='@' read -r -a BrainMeshes <<< "$BrainMesh"

if [[ "${#Meshes[@]}" -ne "${#BrainMeshes[@]}" ]]; then
    log_Err_Abort "--hippunfold-mesh and --brain-mesh must contain the same number of entries"
fi

for Mesh in "${Meshes[@]}"; do
    case "$Mesh" in
        native|512|2k|8k|18k)
            ;;
        *)
            log_Err_Abort "Unrecognized HippUnfold mesh '$Mesh'"
            ;;
    esac
done

for Mesh in "${BrainMeshes[@]}"; do
    case "$Mesh" in
        native|32k|59k|164k)
            ;;
        *)
            log_Err_Abort "Unrecognized Brain mesh '$Mesh'"
            ;;
    esac
done

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

for MeshIndex in "${!Meshes[@]}"; do
    Mesh="${Meshes[$MeshIndex]}"
    AttachedBrainMesh="${BrainMeshes[$MeshIndex]}"

    if [[ "$Mesh" == "native" ]]; then
        MeshFolder="Native"
    else
        MeshFolder="$Mesh"
    fi

    PhysicalHippUnfoldFolderOut="$PhysicalHippUnfoldDIR"
    AtlasHippUnfoldFolderOut="$AtlasHippUnfoldDIR"

    PhysicalHippUnfoldFolder="$PhysicalHippUnfoldFolderOut/$MeshFolder"
    AtlasHippUnfoldFolder="$AtlasHippUnfoldFolderOut/$MeshFolder"

    mkdir -p "$PhysicalHippUnfoldFolder" "$AtlasHippUnfoldFolder"

    if $runMMORF; then
        MMORFHippUnfoldFolder="${MMORFHippUnfoldDIR}/${MeshFolder}"
        mkdir -p "$MMORFHippUnfoldFolder"
    fi
    
    log_Msg "Processing $Mesh"

    Space="T2w"
    Structures="dentate hipp"
    Surfaces="inner@INNER midthickness@MIDTHICKNESS outer@OUTER"
    Scalars="curvature@GRAY@Curvature gyrification@GRAY@Gyrification surfarea@VIDEEN@SurfaceArea thickness@VIDEEN@Thickness myelin@VIDEEN@MyelinMap"
    Labels="atlas-multihist7_subfields@HippocampalSubfields"
    for Structure in $Structures ; do
        for Hemisphere in L R ; do
        #surfacea no longer computed by HippUnfold
        wb_command -surface-vertex-areas $RawHippUnfoldFolder/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-${Structure}_midthickness.surf.gii $RawHippUnfoldFolder/metric/sub-${Subject}_hemi-${Hemisphere}_den-${Mesh}_label-${Structure}_surfarea.shape.gii
        done
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
        for SurfaceEntry in $Surfaces ; do
            SurfaceType=$(echo "$SurfaceEntry" | cut -d "@" -f 2)
            Surface=$(echo "$SurfaceEntry" | cut -d "@" -f 1)
            cp $RawHippUnfoldFolder/surf/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_den-${Mesh}_label-${Structure}_${Surface}.surf.gii ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.${Mesh}.surf.gii
            wb_command -set-structure ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.${Mesh}.surf.gii ${HemiStructure} -surface-type ANATOMICAL -surface-secondary-type ${SurfaceType}
            wb_command -spec-file-modify ${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec -add ${HemiStructure} ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.${Mesh}.surf.gii
            # $FNIRT registration
            wb_command -surface-apply-warpfield ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.${Mesh}.surf.gii ${AtlasFolder}/xfms/standard2acpc_dc.nii.gz ${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.${Mesh}.surf.gii -fnirt "${AtlasFolder}/xfms/acpc_dc2standard.nii.gz"
            wb_command -spec-file-modify ${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec -add ${HemiStructure} ${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.${Mesh}.surf.gii
            # MMORF registration
            if $runMMORF; then
                wb_command -surface-apply-warpfield ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.${Mesh}.surf.gii $MMORFSurfaceWarp ${MMORFHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.${Mesh}.surf.gii
                wb_command -spec-file-modify ${MMORFHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec -add $HemiStructure ${MMORFHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Surface}.${Mesh}.surf.gii
            fi
        done
        
        #Flat Surfaces
        cp $RawHippUnfoldFolder/surf/sub-${Subject}_hemi-${Hemisphere}_space-unfold_den-${Mesh}_label-${Structure}_midthickness.surf.gii ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_flat.${Mesh}.surf.gii
        wb_command -set-structure ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_flat.${Mesh}.surf.gii ${HemiStructure} -surface-type FLAT
        wb_command -spec-file-modify ${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec -add ${HemiStructure} ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_flat.${Mesh}.surf.gii
        cp ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_flat.${Mesh}.surf.gii ${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_flat.${Mesh}.surf.gii
        wb_command -spec-file-modify ${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec -add ${HemiStructure} ${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_flat.${Mesh}.surf.gii
        if $runMMORF; then
            cp ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_flat.${Mesh}.surf.gii ${MMORFHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_flat.${Mesh}.surf.gii
            wb_command -spec-file-modify ${MMORFHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec -add $HemiStructure ${MMORFHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_flat.${Mesh}.surf.gii
        fi
        
        #GIFTI Metrics
        #Don't add GIFTI to Specs
        for ScalarEntry in $Scalars ; do
            Name=`echo $ScalarEntry | cut -d "@" -f 3`
            Color=`echo $ScalarEntry | cut -d "@" -f 2`
            Scalar=`echo $ScalarEntry | cut -d "@" -f 1`
            cp $RawHippUnfoldFolder/metric/sub-${Subject}_hemi-${Hemisphere}_den-${Mesh}_label-${Structure}_${Scalar}.shape.gii ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii
            wb_command -set-structure ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii ${HemiStructure}
            PALETTE ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii ${Color} metric wb_command
            wb_command -set-map-names ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii -map 1 "${Subject}_${Name}"
            if [ $Scalar = "surfarea" ] ; then
                wb_command -surface-vertex-areas ${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_midthickness.${Mesh}.surf.gii ${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii
            else
                cp ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii ${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii
            fi
            if $runMMORF && [[ $Scalar = "surfarea" ]] ; then
                wb_command -surface-vertex-areas ${MMORFHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_midthickness.${Mesh}.surf.gii ${MMORFHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii
            else
                cp ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii ${MMORFHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Scalar}.${Mesh}.shape.gii
            fi
        done
        
        #GIFTI Labels
        #Don't add GIFTI to Specs
        for LabelEntry in $Labels ; do
            Name=$(echo "$LabelEntry" | cut -d "@" -f 2)
            Label=$(echo "$LabelEntry" | cut -d "@" -f 1)
            if [ ${Structure} = "hipp" ] ; then
            if [ ${Hemisphere} = "L" ] ; then
                Expression="Var"
            elif [ ${Hemisphere} = "R" ] ; then
                Expression="Var + 8"
            fi
            wb_command -metric-math "${Expression}" ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.shape.gii -var Var $RawHippUnfoldFolder/metric/sub-${Subject}_hemi-${Hemisphere}_den-${Mesh}_label-${Structure}_${Label}.label.gii |& grep -v NIFTI_INTENT_LABEL
            wb_command -metric-label-import ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.shape.gii $HCPPIPEDIR/global/config/HippUnfoldLut.txt ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.label.gii
            elif [ ${Structure} = "dentate" ] ; then
            if [ ${Hemisphere} = "L" ] ; then
                Expression="6"
            elif [ ${Hemisphere} = "R" ] ; then
                Expression="6 + 8"
            fi
            wb_command -metric-math "${Expression}" ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.shape.gii -var Var $RawHippUnfoldFolder/metric/sub-${Subject}_hemi-${Hemisphere}_den-${Mesh}_label-${Structure}_thickness.shape.gii |& grep -v NIFTI_INTENT_LABEL
            wb_command -metric-label-import ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.shape.gii $HCPPIPEDIR/global/config/HippUnfoldLut.txt ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.label.gii
            fi
            wb_command -set-structure ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.label.gii ${HemiStructure}
            wb_command -set-map-names ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.label.gii -map 1 "${Subject}_${Name}"
            cp ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.label.gii ${AtlasHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.label.gii
            if $runMMORF; then
                cp ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.label.gii ${MMORFHippUnfoldFolder}/${Subject}.${Hemisphere}.${Structure}_${Label}.${Mesh}.label.gii
            fi
        done
        
        #NIFTI Hemispheric Labels
        cp $RawHippUnfoldFolder/anat/sub-${Subject}_hemi-${Hemisphere}_space-${Space}_label-hipp_desc-subfields_atlas-multihist7_dseg.nii.gz ${PhysicalHippUnfoldFolder}/${Subject}.${Hemisphere}.HippocampalSubfields.nii.gz
        done
    done

    #CIFTI Scalars
    for ScalarEntry in $Scalars ; do
        Name=`echo $ScalarEntry | cut -d "@" -f 3`
        Color=`echo $ScalarEntry | cut -d "@" -f 2`
        Scalar=`echo $ScalarEntry | cut -d "@" -f 1`
        wb_command -cifti-create-dense-scalar ${PhysicalHippUnfoldFolder}/${Subject}.hippocampus_${Scalar}.${Mesh}.dscalar.nii -metric HIPPOCAMPUS_LEFT ${PhysicalHippUnfoldFolder}/${Subject}.L.hipp_${Scalar}.${Mesh}.shape.gii -metric HIPPOCAMPUS_RIGHT ${PhysicalHippUnfoldFolder}/${Subject}.R.hipp_${Scalar}.${Mesh}.shape.gii -metric HIPPOCAMPUS_DENTATE_LEFT ${PhysicalHippUnfoldFolder}/${Subject}.L.dentate_${Scalar}.${Mesh}.shape.gii -metric HIPPOCAMPUS_DENTATE_RIGHT ${PhysicalHippUnfoldFolder}/${Subject}.R.dentate_${Scalar}.${Mesh}.shape.gii
        PALETTE ${PhysicalHippUnfoldFolder}/${Subject}.hippocampus_${Scalar}.${Mesh}.dscalar.nii ${Color} cifti wb_command
        wb_command -set-map-names ${PhysicalHippUnfoldFolder}/${Subject}.hippocampus_${Scalar}.${Mesh}.dscalar.nii -map 1 "${Subject}_${Name}"
        wb_command -spec-file-modify ${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec -add INVALID ${PhysicalHippUnfoldFolder}/${Subject}.hippocampus_${Scalar}.${Mesh}.dscalar.nii

        wb_command -cifti-create-dense-scalar ${MMORFHippUnfoldFolder}/${Subject}.hippocampus_${Scalar}.${Mesh}.dscalar.nii -metric HIPPOCAMPUS_LEFT ${MMORFHippUnfoldFolder}/${Subject}.L.hipp_${Scalar}.${Mesh}.shape.gii -metric HIPPOCAMPUS_RIGHT ${MMORFHippUnfoldFolder}/${Subject}.R.hipp_${Scalar}.${Mesh}.shape.gii -metric HIPPOCAMPUS_DENTATE_LEFT ${MMORFHippUnfoldFolder}/${Subject}.L.dentate_${Scalar}.${Mesh}.shape.gii -metric HIPPOCAMPUS_DENTATE_RIGHT ${MMORFHippUnfoldFolder}/${Subject}.R.dentate_${Scalar}.${Mesh}.shape.gii
        PALETTE ${MMORFHippUnfoldFolder}/${Subject}.hippocampus_${Scalar}.${Mesh}.dscalar.nii $Color cifti wb_command
        wb_command -set-map-names ${MMORFHippUnfoldFolder}/${Subject}.hippocampus_${Scalar}.${Mesh}.dscalar.nii -map 1 ${Subject}_${Name}
        wb_command -spec-file-modify ${MMORFHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec -add INVALID ${MMORFHippUnfoldFolder}/${Subject}.hippocampus_${Scalar}.${Mesh}.dscalar.nii

        wb_command -cifti-create-dense-scalar ${AtlasHippUnfoldFolder}/${Subject}.hippocampus_${Scalar}.${Mesh}.dscalar.nii -metric HIPPOCAMPUS_LEFT ${AtlasHippUnfoldFolder}/${Subject}.L.hipp_${Scalar}.${Mesh}.shape.gii -metric HIPPOCAMPUS_RIGHT ${AtlasHippUnfoldFolder}/${Subject}.R.hipp_${Scalar}.${Mesh}.shape.gii -metric HIPPOCAMPUS_DENTATE_LEFT ${AtlasHippUnfoldFolder}/${Subject}.L.dentate_${Scalar}.${Mesh}.shape.gii -metric HIPPOCAMPUS_DENTATE_RIGHT ${AtlasHippUnfoldFolder}/${Subject}.R.dentate_${Scalar}.${Mesh}.shape.gii
        PALETTE ${AtlasHippUnfoldFolder}/${Subject}.hippocampus_${Scalar}.${Mesh}.dscalar.nii $Color cifti wb_command
        wb_command -set-map-names ${AtlasHippUnfoldFolder}/${Subject}.hippocampus_${Scalar}.${Mesh}.dscalar.nii -map 1 ${Subject}_${Name}
        wb_command -spec-file-modify ${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec -add INVALID ${AtlasHippUnfoldFolder}/${Subject}.hippocampus_${Scalar}.${Mesh}.dscalar.nii
    done


    #CIFTI Labels
    for LabelEntry in $Labels ; do
        Name=$(echo "$LabelEntry" | cut -d "@" -f 2)
        Label=$(echo "$LabelEntry" | cut -d "@" -f 1)
        wb_command -cifti-create-label ${PhysicalHippUnfoldFolder}/${Subject}.hippocampus_${Label}.${Mesh}.dlabel.nii -label HIPPOCAMPUS_LEFT ${PhysicalHippUnfoldFolder}/${Subject}.L.hipp_${Label}.${Mesh}.label.gii -label HIPPOCAMPUS_RIGHT ${PhysicalHippUnfoldFolder}/${Subject}.R.hipp_${Label}.${Mesh}.label.gii -label HIPPOCAMPUS_DENTATE_LEFT ${PhysicalHippUnfoldFolder}/${Subject}.L.dentate_${Label}.${Mesh}.label.gii -label HIPPOCAMPUS_DENTATE_RIGHT ${PhysicalHippUnfoldFolder}/${Subject}.R.dentate_${Label}.${Mesh}.label.gii
        wb_command -set-map-names ${PhysicalHippUnfoldFolder}/${Subject}.hippocampus_${Label}.${Mesh}.dlabel.nii -map 1 "${Subject}_${Name}"
        wb_command -spec-file-modify ${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec -add INVALID ${PhysicalHippUnfoldFolder}/${Subject}.hippocampus_${Label}.${Mesh}.dlabel.nii #TODO: mv to have maps in AtlasFolder like Cerebral Cortex?
        cp ${PhysicalHippUnfoldFolder}/${Subject}.hippocampus_${Label}.${Mesh}.dlabel.nii ${AtlasHippUnfoldFolder}/${Subject}.hippocampus_${Label}.${Mesh}.dlabel.nii #TODO: mv to have maps in AtlasFolder like Cerebral Cortex?
        wb_command -spec-file-modify ${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec -add INVALID ${AtlasHippUnfoldFolder}/${Subject}.hippocampus_${Label}.${Mesh}.dlabel.nii #TODO: mv to have maps in AtlasFolder like Cerebral Cortex?

        wb_command -cifti-create-label ${MMORFHippUnfoldFolder}/${Subject}.hippocampus_${Label}.${Mesh}.dlabel.nii -label HIPPOCAMPUS_LEFT ${MMORFHippUnfoldFolder}/${Subject}.L.hipp_${Label}.${Mesh}.label.gii -label HIPPOCAMPUS_RIGHT ${MMORFHippUnfoldFolder}/${Subject}.R.hipp_${Label}.${Mesh}.label.gii -label HIPPOCAMPUS_DENTATE_LEFT ${MMORFHippUnfoldFolder}/${Subject}.L.dentate_${Label}.${Mesh}.label.gii -label HIPPOCAMPUS_DENTATE_RIGHT ${MMORFHippUnfoldFolder}/${Subject}.R.dentate_${Label}.${Mesh}.label.gii
        wb_command -set-map-names ${MMORFHippUnfoldFolder}/${Subject}.hippocampus_${Label}.${Mesh}.dlabel.nii -map 1 "${Subject}_${Name}"
        wb_command -spec-file-modify ${MMORFHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec -add INVALID ${MMORFHippUnfoldFolder}/${Subject}.hippocampus_${Label}.${Mesh}.dlabel.nii
    done

    #NIFTI Label Volumes
    fslmaths ${PhysicalHippUnfoldFolder}/${Subject}.R.HippocampalSubfields.nii.gz -add 8 -mas ${PhysicalHippUnfoldFolder}/${Subject}.R.HippocampalSubfields.nii.gz -add ${PhysicalHippUnfoldFolder}/${Subject}.L.HippocampalSubfields.nii.gz ${PhysicalHippUnfoldFolder}/${Subject}.HippocampalSubfields.nii.gz
    wb_command -volume-label-import ${PhysicalHippUnfoldFolder}/${Subject}.HippocampalSubfields.nii.gz $HCPPIPEDIR/global/config/HippUnfoldLut.txt ${PhysicalHippUnfoldFolder}/${Subject}.HippocampalSubfields.nii.gz
    rm ${PhysicalHippUnfoldFolder}/${Subject}.L.HippocampalSubfields.nii.gz ${PhysicalHippUnfoldFolder}/${Subject}.R.HippocampalSubfields.nii.gz
    wb_command -spec-file-modify ${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec -add INVALID ${PhysicalHippUnfoldFolder}/${Subject}.HippocampalSubfields.nii.gz
    wb_command -volume-resample ${PhysicalHippUnfoldFolder}/${Subject}.HippocampalSubfields.nii.gz ${AtlasFolder}/T1w_restore.nii.gz ENCLOSING_VOXEL ${AtlasHippUnfoldFolder}/${Subject}.HippocampalSubfields.nii.gz -warp ${AtlasFolder}/xfms/acpc_dc2standard.nii.gz -fnirt ${AtlasFolder}/T1w_restore.nii.gz
    wb_command -spec-file-modify ${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec -add INVALID ${AtlasHippUnfoldFolder}/${Subject}.HippocampalSubfields.nii.gz

    #NIFTI Input Volumes
    wb_command -spec-file-modify ${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec -add INVALID ${T1wFolder}/T1w_acpc_dc_restore.nii.gz
    wb_command -spec-file-modify ${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec -add INVALID ${T1wFolder}/T2w_acpc_dc_restore.nii.gz
    wb_command -spec-file-modify ${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec -add INVALID ${AtlasFolder}/T1w_restore.nii.gz
    wb_command -spec-file-modify ${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec -add INVALID ${AtlasFolder}/T2w_restore.nii.gz

    if $runMMORF; then
        wb_command -volume-resample ${PhysicalHippUnfoldFolder}/${Subject}.HippocampalSubfields.nii.gz ${MMORFFolder}/T1w_restore.nii.gz ENCLOSING_VOXEL ${MMORFHippUnfoldFolder}/${Subject}.HippocampalSubfields.nii.gz -warp ${MMORFVolumeWarp}
        wb_command -spec-file-modify ${MMORFHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec -add INVALID ${MMORFHippUnfoldFolder}/${Subject}.HippocampalSubfields.nii.gz
        wb_command -spec-file-modify ${MMORFHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec -add INVALID ${MMORFFolder}/T1w_restore.nii.gz
    fi

    log_Msg "Pairing HippUnfold mesh '$Mesh' with brain mesh '$AttachedBrainMesh'"

    case "$AttachedBrainMesh" in
        native)
            PhysicalBrainSpec="${T1wFolder}/Native/${Subject}.native.wb.spec"
            AtlasBrainSpec="${AtlasFolder}/Native/${Subject}.native.wb.spec"
            MMORFBrainSpec="${MMORFFolder}/Native/${Subject}.native.wb.spec"

            CombinedSpecName="${Subject}.${Mesh}.native.wb_spec"
            MMORFCombinedSpecName="${Subject}.${Mesh}.native.wb_spec"
            ;;

        32k|59k)
            PhysicalBrainSpec="${T1wFolder}/fsaverage_LR${AttachedBrainMesh}/${Subject}.MSMAll.${AttachedBrainMesh}_fs_LR.wb.spec"
            AtlasBrainSpec="${AtlasFolder}/fsaverage_LR${AttachedBrainMesh}/${Subject}.MSMAll.${AttachedBrainMesh}_fs_LR.wb.spec"
            MMORFBrainSpec="${MMORFFolder}/fsaverage_LR${AttachedBrainMesh}/${Subject}.MSMAll.${AttachedBrainMesh}_fs_LR.wb.spec"

            CombinedSpecName="${Subject}.${Mesh}.MSMAll.${AttachedBrainMesh}.wb_spec"
            MMORFCombinedSpecName="$CombinedSpecName"
            ;;

        164k)
            PhysicalBrainSpec="${T1wFolder}/${Subject}.MSMAll.164k_fs_LR.wb.spec"
            AtlasBrainSpec="${AtlasFolder}/${Subject}.MSMAll.164k_fs_LR.wb.spec"
            MMORFBrainSpec="${MMORFFolder}/fsaverage_LR164k/${Subject}.MSMAll.164k_fs_LR.wb.spec"

            CombinedSpecName="${Subject}.${Mesh}.MSMAll.164k.wb_spec"
            MMORFCombinedSpecName="$CombinedSpecName"
            ;;
    esac

    if [[ -f "$PhysicalBrainSpec" ]]; then
        wb_command -spec-file-merge "${PhysicalHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec" "$PhysicalBrainSpec" "${PhysicalHippUnfoldFolder}/${CombinedSpecName}"
    else
        log_Msg "WARNING: Skipping T1w Brain merge; spec does not exist: $PhysicalBrainSpec"
    fi

    if [[ -f "$AtlasBrainSpec" ]]; then
        wb_command -spec-file-merge "${AtlasHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec" "$AtlasBrainSpec" "${AtlasHippUnfoldFolder}/${CombinedSpecName}"
    else
        log_Msg "WARNING: Skipping MNINonLinear Brain merge; spec does not exist: $AtlasBrainSpec"
    fi

    if $runMMORF && [[ -f "$MMORFBrainSpec" ]]; then
        wb_command -spec-file-merge "${MMORFHippUnfoldFolder}/${Subject}.${Mesh}.wb_spec" "$MMORFBrainSpec" "${MMORFHippUnfoldFolder}/${MMORFCombinedSpecName}"
    else
        log_Msg "WARNING: Skipping MMORF Brain merge; spec does not exist: $MMORFBrainSpec"
    fi
done

log_Msg "PostHippUnfold pipeline completed successfully for subject: $Subject"
