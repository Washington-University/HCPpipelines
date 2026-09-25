
#!/bin/bash
set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

# Load function libraries
source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"    # Debugging functions; also sources log.shlib
source "${HCPPIPEDIR}/global/scripts/newopts.shlib" "$@"  # Command line option functions

opts_SetScriptDescription "Generate group Subcortical Gray from group Wmparc"
opts_AddMandatory '--path' 'StudyFolder' 'Path' "path to session's data folder"
opts_AddMandatory '--results-folder' 'Folder' 'The specific folder in which the seed of tractography is located. This should follow HCP standards' ""
opts_AddOptional '--groupname' 'GroupName' 'Group Folder_Name' ""
opts_ParseArguments "$@"

T1wFolder=${StudyFolder}/${GroupName}/${Folder}
wmparc=${GroupName}_Averagewmparc
for dir in "$StudyFolder"/*; do
    Subject=$(basename "$dir")

    [[ -d "$dir" ]] || continue
    [[ "$Subject" =~ ^[0-9]+$ ]] || continue

    echo "$Subject"
    break
done

T1wDiffusionFolder="${StudyFolder}/${Subject}/T1w/Diffusion"
DiffusionResolution=`${FSLDIR}/bin/fslval ${T1wDiffusionFolder}/data pixdim1`
DiffusionResolution=`printf "%0.2f" ${DiffusionResolution}`
mkdir -p ${T1wFolder}/temp
ROIsFolder=${T1wFolder}
WholeBrainSubcorticalLabels=${HCPPIPEDIR_Config}/WholeBrainSubcorticalFreeSurferTrajectoryLabelTableLut.txt
subcortical="SubCortical_GreyMatter"
mkdir -p "$ROIsFolder/temp"
${FSLDIR}/bin/fslmaths "$T1wFolder"/"$wmparc"_"$DiffusionResolution" -sub "$T1wFolder"/"$wmparc"_"$DiffusionResolution" "$ROIsFolder"/temp/trajectory
#LeftLateralVentricle, LeftInfLatVent, 3rdVentricle, 4thVentricle, CSF, LeftChoroidPlexus, RightLateralVentricle, RightInfLatVent, RightChoroidPlexus
wmparcStructuresToDeleteSTRING="4 5 14 15 24 31 43 44 63"
for Structure in $wmparcStructuresToDeleteSTRING ; do
  ${FSLDIR}/bin/fslmaths "$T1wFolder"/"$wmparc"_"$DiffusionResolution" -thr $Structure -uthr $Structure -bin "$ROIsFolder"/temp/$Structure
done
  
#CEREBELLAR_WHITE_MATTER_LEFT CEREBELLUM_LEFT THALAMUS_LEFT CAUDATE_LEFT PUTAMEN_LEFT PALLIDUM_LEFT BRAIN_STEM HIPPOCAMPUS_LEFT AMYGDALA_LEFT ACCUMBENS_LEFT DIENCEPHALON_VENTRAL_LEFT CEREBELLAR_WHITE_MATTER_RIGHT CEREBELLUM_RIGHT THALAMUS_RIGHT CAUDATE_RIGHT PUTAMEN_RIGHT PALLIDUM_RIGHT HIPPOCAMPUS_RIGHT AMYGDALA_RIGHT ACCUMBENS_RIGHT DIENCEPHALON_VENTRAL_RIGHT
wmparcStructuresToKeepSTRING="7 8 10 11 12 13 16 17 18 26 28 46 47 49 50 51 52 53 54 58 60"
for Structure in $wmparcStructuresToKeepSTRING ; do
  ${FSLDIR}/bin/fslmaths "$T1wFolder"/"$wmparc"_"$DiffusionResolution" -thr $Structure -uthr $Structure -bin "$ROIsFolder"/temp/$Structure
  ${FSLDIR}/bin/fslmaths "$ROIsFolder"/temp/$Structure -mul $Structure -add "$ROIsFolder"/temp/trajectory "$ROIsFolder"/temp/trajectory
done


#Fornix, CC_Posterior, CC_Mid_Posterior, CC_Central, CC_MidAnterior, CC_Anterior
CorpusCallosumToAdd="250 251 252 253 254 255"
for Structure in $CorpusCallosumToAdd ; do 
  ${FSLDIR}/bin/fslmaths "$T1wFolder"/"$wmparc"_"$DiffusionResolution" -thr $Structure -uthr $Structure -bin "$ROIsFolder"/temp/$Structure
done
wb_command -volume-label-import "$ROIsFolder"/temp/trajectory.nii.gz $WholeBrainSubcorticalLabels "$T1wFolder"/Whole_Brain_${subcortical}_"$DiffusionResolution".nii.gz -discard-others -unlabeled-value 0

rm -r "$ROIsFolder/temp"
