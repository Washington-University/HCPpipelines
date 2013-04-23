The HCP Pipelines have the following software requirements:
*OS: 64bit Linux

*FSL 5.0.2 installed and config properly sourced
*FreeSurfer 5.2 installed and config properly sourced
*${HCPPIPEDIR}/src/gradient_unwarping installed with dependancies (source code located in this folder) if using gradient distortion correction

The HCP Pipelines reside in a root folder called ${HCPPIPEDIR}

${HCPPIPEDIR}/Examples/Scripts/SetUpHCPPipeline.sh will need to be edited to set the absolute path to this folder on your system.
This setup script must be sourced before running an HCP pipeline (examples below)

To test that the pipelines work, there is example data located in:
${HCPPIPEDIR}/Examples/792564

There are example batch scripts to call the pipelines on this data located in:
${HCPPIPEDIR}/Examples/Scripts

In all example batch scripts, the following variables will need to be modified prior to use:
StudyFolder="/media/myelin/brainmappers/Connectome_Project/TestStudyFolder" #Path to subject's data folder

${StudyFolder} needs to be changed to the location of the data that will be run.

Also EnvironmentScript="/media/2TBB/Connectome_Project/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script
Needs to be edited to reflect where this script is located on your system


