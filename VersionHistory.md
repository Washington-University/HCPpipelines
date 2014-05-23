# HCP Pipeline Tools Version History

## v3.3.1

* v3.3 included version of wb_command with bugs in the following sub-commands
  * -volume-warpfiled-resample
  * -volume-affine-resample
  * -cifti-resample
  * -surface-apply-affine
  * -surface-apply-warpfield
  * -convert-affine
  * -convert-warpfield
* This version replaces that wb_command with a build 
  (commit date: 2014-05-15 19:41:22 -0500) for which that bug is fixed

## v3.1RC5

* Changes to handle change in CIFTI file field name from "TimeStep" to "SeriesStep"  
* Uses version of wb_command (Workbench command) to support the above field name change
* Changed output of mcflirt_acc.sh to the mc.par file to allow values to be as 
  wide as necessary and guarantee a single space between each value
  
## v3.1RC4

* Diffusion Preprocessing Pipeline broken out into 3 parts 
  (PreEddy, Eddy, and PostEddy)

## v3.1RC3

* Added code to use GPU-enabled version of FSL eddy program 
  if available

## v3.1RC2

* Uses CIFTI-2 version of wb_command (Workbench command) 
* Updated ReadMe and added this version history file

## v3.1RC1

* Badly tagged version - do not use

