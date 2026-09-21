#!/bin/bash 

StudyFolder="${HOME}/projects/HCPpipelines_ExampleData"
Sessionlist="100307 100610"

#set this so that all the bvals in the lowest diffusion shell are below it (nominal shell value plus 200 will usually work)
DiffusionLowestShellThreshold="1200"
#True or False depending on the study whether to apply gradient nonlinearity correction to the diffusion data
GradientNonLinear="True"

#####################################
EnvironmentScript="${HOME}/projects/HCPpipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

source "${EnvironmentScript}"

T1wTemplateBrain="${TemplateDir}/MMORF_T1_Brain.nii.gz"

QUEUE=""


for Session in ${Sessionlist}; do
    echo "${Session}"
    if [[ "$QUEUE" == "" ]] ; then
        echo "About to locally run ${HCPPIPEDIR}/MMORF/PreMMORFPipeline.sh"
        queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
    else
        echo "About to use fsl_sub to queue ${HCPPIPEDIR}/MMORF/PreMMORFPipeline.sh"
        queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE")
    fi
    
    "${queuing_command[@]}" ${HCPPIPEDIR}/MMORF/PreMMORFPipeline.sh \
        --study-folder="${StudyFolder}" \
        --session="${Session}" \
        --t1-brain-template="${T1wTemplateBrain}" \
        --lowest-shell-threshold="${DiffusionLowestShellThreshold}" \
        --gradnonlin="${GradientNonLinear}"
done