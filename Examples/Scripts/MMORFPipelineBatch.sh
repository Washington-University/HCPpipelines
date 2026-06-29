#!/bin/bash 
###Mandatory Arguments###
MAX_JOBS=2  ###The script uses sub shells to run the MMORF registration for each subject. This variable controls how many of those sub shells can run at once. If you have a lot of subjects, you may want to increase this number to speed up the processing. If you are running on a cluster, you may want to decrease this number to avoid overloading the cluster.
StudyFolder="${HOME}/projects/HCPpipelines_ExampleData"
Sessionlist="100307 100610"
T1wTemplate="${TemplateDir}/MMORF_T1.nii.gz"
T2wTemplate="${TemplateDir}/MMORF_T2.nii.gz"
refmask="${TemplateDir}/MMORF_T1_brainmask_fs.nii.gz"
DiffusionRef="${TemplateDir}/MMORF_DiffusionRef.nii.gz"
DTIMask="${TemplateDir}/MMORF_nodif_brainmask.nii.gz"
#########OPTIONAL ARGUMENTS#########
###Only fill these in if you are running on a cluster and need to specify the host, header, mount point, and home directory for the cluster. If you are running locally, leave these blank.
Host="" # Fill in with your cluster alias, e.g. CHPC, Local, etc. This alias when ssh needs to be able to access the cluster. You need ssh config setup so your alias gives you access to the cluster
CHPCHeader="" ##A file that gives you access to MMORF. See template.sh in scripts under MMORF for an example. You will need to edit it to your needs.
LocalHost="" # Fill in with your local host name.
mountpoint="" # Fill in with your mount point for the cluster, this should be the directory where your remote is mounting to
ClusterHomeDirectory="" # Fill in with your home directory on the cluster
#####################################

${HCPPIPEDIR}/MMORF/MMORFPipeline.sh \
  --StudyFolder="${StudyFolder}" \
  --Sessionlist="${Sessionlist}" \
  --t1-template="${T1wTemplate}" \
  --t2-template="${T2wTemplate}" \
  --refmask="${refmask}" \
  --diffusion-ref="${DiffusionRef}" \
  --dti-mask="${DTIMask}" \
  --runlocally="false" \
  --Host=$Host \
  --CHPCHeader=$CHPCHeader \
  --LocalHost=$LocalHost \ 
  --mount-point=$mountpoint \
  --ClusterHomeDirectory=$ClusterHomeDirectory"
