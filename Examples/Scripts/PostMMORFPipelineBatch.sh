#!/bin/bash
StudyFolder="${HOME}/projects/HCPpipelines_ExampleData"
Subjectlist="100307 100610"
T1wTemplate="${TemplateDir}/MMORF_T1.nii.gz"
highResMesh='164'
lowResMeshes='32@79'
regName="MSMAll"
regNameOrig="MSMSulc"
inflateExtraScale='1'
EnvironmentScript="${HOME}/projects/HCPpipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

source "${EnvironmentScript}"
QUEUE=""

for subj in $Subjectlist; do
    echo "${subj}"
    if [[ "$QUEUE" == "" ]] ; then
        echo "About to locally run ${HCPPIPEDIR}/MMORF/PostMMORFPipeline.sh"
        queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
    else
        echo "About to use fsl_sub to queue ${HCPPIPEDIR}/MMORF/PostMMORFPipeline.sh"
        queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE")
    fi
    
    "${queuing_command[@]}" ${HCPPIPEDIR}/MMORF/PostMMORFPipeline.sh \
        --study-folder="${StudyFolder}" \
        --session="${subj}" \
        --t1-template="${T1wTemplate}" \
        --hiresmesh="${highResMesh}" \
        --lowresmesh="${lowResMeshes}" \
        --regname="${regName}" \
        --regnameorig="${regNameOrig}" \
        --inflatescale="${inflateExtraScale}"
done

