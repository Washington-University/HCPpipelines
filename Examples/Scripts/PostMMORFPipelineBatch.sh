#bin/bash

StudyFolder="${HOME}/projects/HCPpipelines_ExampleData"
Subjectlist="100307 100610"
highResMesh='164'
lowResMeshes='32@79'
regName="MSMAll"
regNameOrig="MSMSulc"
inflateExtraScale='1'
EnvironmentScript="${HOME}/projects/HCPpipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

source "${EnvironmentScript}"

for subj in $Subjectlist; do
    ${HCPPIPEDIR}/MMORF/PostMMORFPipeline.sh \
    --StudyFolder="${StudyFolder}" \
    --subject="${subj}" \
    --high-res-mesh="${highResMesh}" \
    --low-res-meshes="${lowResMeshes}" \
    --RegName="${regName}" \
    --RegNameOrig="${regNameOrig}" \
    --InflateExtraScale="${inflateExtraScale}"
done

