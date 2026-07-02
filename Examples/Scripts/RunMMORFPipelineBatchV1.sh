StudyFolder="${HOME}/projects/HCPpipelines_ExampleData"
Sessionlist="100307 100610"
T1wTemplate="${TemplateDir}/MMORF_T1.nii.gz"
T2wTemplate="${TemplateDir}/MMORF_T2.nii.gz"
refmask="${TemplateDir}/MMORF_T1_brainmask_fs.nii.gz"
DiffusionRef="${TemplateDir}/MMORF_DiffusionRef.nii.gz"
DTIMask="${TemplateDir}/MMORF_nodif_brainmask.nii.gz"

EnvironmentScript="${HOME}/projects/HCPpipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

source "${EnvironmentScript}"

QUEUE=""

for Session in ${Sessionlist}; do
    echo "Launching MMORF registration for session ${Session}"
    $FSLDIR/bin/fsl_sub \
    -q ${QUEUE} \
    ${HCPPIPEDIR}/MMORF/MMORFPipelineV1.sh \
    --study-folder="${StudyFolder}" \
    --session="${Session}" \
    --t1-template="${T1wTemplate}" \
    --t2-template="${T2wTemplate}" \
    --ref-mask="${refmask}" \
    --diffusion-ref="${DiffusionRef}" \
    --dti-mask="${DTIMask}"
done