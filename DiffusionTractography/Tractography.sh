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


# Perform the steps of the HCP Diffusion Preprocessing Pipeline
opts_SetScriptDescription "Run probabilistic tractography"

opts_AddMandatory '--path' 'StudyFolder' 'Path' "path to session's data folder"
opts_AddMandatory '--subject' 'Subject' 'subject ID' "subject"
opts_AddMandatory '--results-folder' 'Folder' 'folder' "folder"
opts_AddMandatory '--diffresmesh' 'DiffResMesh' 'number' 'diffusion res mesh number'
opts_AddMandatory '--bpxdirs' 'BedpostXFolders' 'Full path to bedpostx folders' 'BEDPOSTX Folders delimited by @'
opts_AddMandatory '--regname' 'RegName' 'Name of Registration' 'NONE for MSMSulc, else RegName such as MSMAll'
opts_AddMandatory '--matrix4' 'Matrix4' 'If we are running matrix 4' 'true'
opts_AddMandatory '--seeding-strategy' 'SeedingStrategy' 'Matrix3 or Matrix1' 'true'
opts_AddMandatory '--nsamples' 'nsamples' 'number of samples we run per voxel for speed.' '100'
opts_AddMandatory '--nsteps' 'nsteps' 'number of steps we take per streamline.' '2000'
opts_AddOptional '--whim' 'Whim' 'full path to whim folder' ""
opts_AddOptional '--mask' 'Mask' 'full path to Whim group mask' ""
opts_ParseArguments "$@"

opts_ShowValues


T1wDiffusionFolder="${StudyFolder}/${Subject}/T1w/Diffusion"
DiffusionResolution=`${FSLDIR}/bin/fslval ${T1wDiffusionFolder}/data pixdim1`
DiffusionResolution=`printf "%0.2f" ${DiffusionResolution}`
STEPLENGTH=$(echo "$DiffusionResolution / 4" | bc -l)
STEPLENGTH=$(printf "%g" "$STEPLENGTH")   # removes trailing zeros
PipelineScripts=${HCPPIPEDIR}/DiffusionTractography/scripts #TODO: Delete when commited and in setup script


if [[ "$SeedingStrategy" == "Matrix3" ]]; then
    mkdir -p "${StudyFolder}/${Subject}/${Folder}/Results/Matrix3WholeBrainTractography"
fi
if [[ "$SeedingStrategy" == "Matrix1" ]]; then
    mkdir -p "${StudyFolder}/${Subject}/${Folder}/Results/Matrix1WholeBrainTractography"
fi

if [[ "$SeedingStrategy" == "Matrix3" ]]; then
    OUTDIR="${StudyFolder}/${Subject}/${Folder}/Results/Matrix3WholeBrainTractography"
    SEED="${StudyFolder}/${Subject}/${Folder}/Whole_Brain_WhiteMatter_${DiffusionResolution}.nii.gz"
    mkdir -p "$OUTDIR"
else
    OUTDIR="${StudyFolder}/${Subject}/${Folder}/Results/Matrix1WholeBrainTractography"
    SEED="${StudyFolder}/${Subject}/${Folder}/ROIs/${Subject}.GreyROI_${RegName}.${DiffResMesh}k_fs_LR_${DiffusionResolution}.txt"
    mkdir -p "$OUTDIR"
fi

COMMON_ARGS=(
    --samples="${BedpostXFolders}"
    --mask="${StudyFolder}/${Subject}/T1w/Whole_Brain_Trajectory_${DiffusionResolution}.nii.gz"
    --seed="${SEED}"
    --waypoints="${StudyFolder}/${Subject}/${Folder}/Whole_Brain_WhiteMatter_${DiffusionResolution}.nii.gz"
    --stop="${StudyFolder}/${Subject}/${Folder}/ROIs/${Subject}.StopROI_${RegName}.${DiffResMesh}k_fs_LR.txt"
    --wtstop="${StudyFolder}/${Subject}/${Folder}/ROIs/${Subject}.GreyROI_${RegName}.${DiffResMesh}k_fs_LR_${DiffusionResolution}.txt"
    --seedref="${StudyFolder}/${Subject}/${Folder}/Whole_Brain_Trajectory_${DiffusionResolution}.nii.gz"
    --dir="${OUTDIR}"
    --nsamples="${nsamples}"
    --cthr=0
    --steplength="${STEPLENGTH}"
    --distthresh=0
    --forcedir
    --meshspace=caret
    --nsteps="${nsteps}"
    --fibthresh=0.05
    --loopcheck
    --randfib=2
    --forcefirststep
    --opd
    --ompl
    --sampvox="${DiffusionResolution}"
    --verbose=1
)

EXTRA_ARGS=()

if [[ "$SeedingStrategy" == "Matrix3" ]]; then
    EXTRA_ARGS+=(
        --target3="${StudyFolder}/${Subject}/T1w/ROIs/${Subject}.GreyROI_${RegName}.${DiffResMesh}k_fs_LR_${DiffusionResolution}.txt"
        --distthresh3=0
        --omatrix3
    )
else
    EXTRA_ARGS+=(
        --distthresh1=0
        --omatrix1
    )
fi

if [[ "$Matrix4" == "true" ]]; then
    EXTRA_ARGS+=(
        --target4="${StudyFolder}/${Subject}/T1w/Whole_Brain_Trajectory_${DiffusionResolution}.nii.gz"
        --omatrix4
    )

    if [[ "$SeedingStrategy" == "Matrix3" ]]; then
        EXTRA_ARGS+=(
            --colmask4="${StudyFolder}/${Subject}/T1w/ROIs/${Subject}.GreyROI_${RegName}.${DiffResMesh}k_fs_LR_${DiffusionResolution}.txt"
        )
    fi
fi

WHIM_ARGS=()

if [[ -n "${Whim:-}" ]]; then
    WHIM_ARGS+=(
        --whim="${Whim}"
        --mask1="${Mask}"
    )
fi


${FSLDIR}/bin/probtrackx2_gpu \
    "${COMMON_ARGS[@]}" \
    "${EXTRA_ARGS[@]}" \
    "${WHIM_ARGS[@]}"