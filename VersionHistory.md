# HCP Pipeline Tools Version History

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

