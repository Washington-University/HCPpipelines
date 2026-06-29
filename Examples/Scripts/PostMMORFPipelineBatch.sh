#bin/bash

StudyFolder="${HOME}/projects/HCPpipelines_ExampleData"
Subjectlist="100307@100610"
highResMesh='164'
lowResMeshes='32@80'
regName="MSMAll"
regNameOrig="MSMSulc"
inflateExtraScale='1'

${HCPPIPEDIR}/MMORF/PostMMORFPipeline.sh \
  --StudyFolder="${StudyFolder}" \
  --subject-list="${Subjectlist}" \
  --high-res-mesh="${highResMesh}" \
  --low-res-meshes="${lowResMeshes}" \
  --RegName="${regName}" \
  --RegNameOrig="${regNameOrig}" \
  --InflateExtraScale="${inflateExtraScale}"
