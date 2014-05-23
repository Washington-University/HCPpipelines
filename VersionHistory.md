# HCP Pipeline Tools Version History

## Version numbering convention
* Versions vX.Y.Z
* X - major version number - major functionality change
* Y - minor version number - minor functionality change or code improvement
* Z - bug fix version number
* Version vX.YRC#. With RC# appended, this implies that the code is a Release Candidate
  and will (hopefully) be promoted to a release vX.Y without change after testing
   
## v3.3.1 (2014-05-23)

* BUG FIX: v3.3 included version of wb_command with bugs in the following sub-commands
  * -volume-warpfiled-resample
  * -volume-affine-resample
  * -cifti-resample
  * -surface-apply-affine
  * -surface-apply-warpfield
  * -convert-affine
  * -convert-warpfield
* This version replaces that wb_command with a build 
  (commit date: 2014-05-15 19:41:22 -0500) for which that bug is fixed

## v3.3 (2014-05-20)
* Promoted debugging and bug fix code from v3.2.1 to a release version
  
## v3.2.1 (2014-05-15)

* Added development latest version of wb_command (as of 2014-05-06) 
  * Previous version was segmentation faulting 
* Added debugging output messages to:
  * TaskfMRIAnalysis.sh
  * TaskfMRILevel1.sh
  * TaskfMRILevel2.sh
* Added --verbose switch to call to FSL program flameo in TaskfMRILevel2.sh
  * flameo was aborting with no useful error or diagnostic messages on
    Washington University Center for High Performance Computing (CHPC)
    cluster
* Changed calls to flameo to shorter line length in attempt to get 
  it to work
* BUG FIX: in functional pre-processing pipeline
  * Grayordinates timeseries in the fMRISurface pipeline were still
    using the FreeSurfer registration.  

## v3.2 (2014-05-06)

* New wb_command included (and associated libraries and changes to 
	TaskfMRILevel1.sh script to support changeover from CIFTI-1 to CIFIT-2
  
## v3.1 (2014-03-24)

* Promoted to release version from v3.1RC5

## v3.1RC5 (2014-03-21)

* Changes to handle change in CIFTI file field name from "TimeStep" to "SeriesStep"  
* Uses version of wb_command (Workbench command) to support the above field name change
* Changed output of mcflirt_acc.sh to the mc.par file to allow values to be as 
  wide as necessary and guarantee a single space between each value
  
## v3.1RC4 (2014-03-19)

* Diffusion Preprocessing Pipeline broken out into 3 parts 
  (PreEddy, Eddy, and PostEddy)

## v3.1RC3 (2014-03-05)

* Added code to use GPU-enabled version of FSL eddy program 
  if available

## v3.1RC2 (2014-02-28)

* Uses CIFTI-2 version of wb_command (Workbench command) 
* Updated ReadMe and added this version history file

## v3.1RC1

* Badly tagged version - do not use

