#!/bin/bash 

StudyFolder="${HOME}/projects/HCPpipelines_ExampleData"
Sessionlist="100307 100610"

EnvironmentScript="${HOME}/projects/HCPpipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

source "${EnvironmentScript}"

T1wTemplate="${TemplateDir}/MMORF_T1_0.7mm.nii.gz"
T2wTemplate="${TemplateDir}/MMORF_T2_0.7mm.nii.gz"
refmask="${TemplateDir}/MMORF_T1_0.7mm_brain_mask.nii.gz"
DiffusionRef="${TemplateDir}/MMORF_DTI_0.7mm_tensor.nii.gz"
DTIRefMask="${TemplateDir}/MMORF_DTI_0.7mm_brain_mask.nii.gz"

QUEUE=""

for Session in ${Sessionlist}; do
    echo "${Session}"
    if [[ "$QUEUE" == "" ]] ; then
        echo "About to locally run ${HCPPIPEDIR}/MMORF/MMORFPipeline.sh"
        queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
    else
        echo "About to use fsl_sub to queue ${HCPPIPEDIR}/MMORF/MMORFPipeline.sh"
        queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE")
    fi
    
    "${queuing_command[@]}" ${HCPPIPEDIR}/MMORF/MMORFPipeline.sh \
        --study-folder="${StudyFolder}" \
        --session="${Session}" \
        --t1-template="${T1wTemplate}" \
        --t2-template="${T2wTemplate}" \
        --ref-mask="${refmask}" \
        --diffusion-ref="${DiffusionRef}" \
        --dti-ref-mask="${DTIRefMask}"
done