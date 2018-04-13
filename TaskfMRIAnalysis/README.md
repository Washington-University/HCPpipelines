# HCP Pipelines TaskfMRIAnalysis subdirectory

This subdirectory contains scripts to run GLM analyses on HCP-style data. There are separate scripts in the "scripts" subdirectory to run Level 1 (within-timeseries) analyses and Level 2 (within-subject, multi-session) analyses.

## Files

* `TaskfMRIAnalysis.sh`
	* Wrapper to launch scripts for one task for an individual subject
* `scripts/TaskfMRILevel1.sh`
	* Script to run GLM timeseries analysis on single scan run
* `scripts/TaskfMRILevel2.sh`
	* Script to "combine" lower-level analyses to compute subject-level activity estimates


## Requirements
* FSL 5.0.7 or greater
* wb_command
