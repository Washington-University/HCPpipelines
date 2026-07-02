#!/bin/bash 
###Mandatory Arguments###
StudyFolder="${HOME}/projects/HCPpipelines_ExampleData"
Sessionlist="100307 100610"
T1wTemplate="${TemplateDir}/MMORF_T1.nii.gz"

#####################################
EnvironmentScript="${HOME}/projects/HCPpipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

source "${EnvironmentScript}"

opts_AddMandatory '--study-folder' 'StudyFolder' 'Path to the study folder containing session folders' ""
opts_AddMandatory '--session' 'Session' 'Subject ID' ""
opts_AddMandatory '--t1-template' 'T1wTemplate' 'Path to the T1w template image' ""

QUEUE=""


for Session in ${Sessionlist}; do
    echo "Launching MMORF registration for session ${Session}"
    $FSLDIR/bin/fsl_sub \
    -q ${QUEUE} \
    ${HCPPIPEDIR}/MMORF/MMORFPipeline.sh \
    --studey-folder="${StudyFolder}" \
    --session="${Session}" \
    --t1-template="${T1wTemplate}"
done