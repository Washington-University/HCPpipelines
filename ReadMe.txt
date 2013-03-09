The HCP Pipelines have the following software requirements:
*OS: 64bit Linux

*FSL 5.0.1 installed and config properly sourced
*FreeSurfer 5.1 installed and config properly sourced
*${GitRepo}/src/gradient_unwarping installed with dependancies (source code located in this folder)

To test that the pipelines work, there is example data located in:
${GitRepo}/Examples/792564

There are example batch scripts to call the pipelines on this data located in:
${GitRepo}/Examples/Scripts

In all example batch scripts, the following variables will need to be modified prior to use:
GitRepo="/media/2TBB/Connectome_Project/Pipelines"
StudyFolder="/media/myelin/brainmappers/Connectome_Project/TestStudyFolder" #Path to subject's data folder

${GitRepo} needs to be changed to the directory in which the git repository was checked out.
${StudyFolder} needs to be changed to the location of the data that will be run, e.g.:
${GitRepo}/Examples if running the example dataset.  


