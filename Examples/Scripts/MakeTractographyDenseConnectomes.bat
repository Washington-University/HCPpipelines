#!/bin/bash
Subjlist="PostMortem1"

for Subject in $Subjlist ; do
  #Input Variables
  StudyFolder="/media/myelin/brainmappers/Connectome_Project/Macaques" #Path to subject's data folder
  Subject="$Subject"
  DownSampleNameI="32"
  DiffusionResolution="0.43" #Set to diffusion voxel resolution
  Caret7_Command="wb_command"
  HemisphereSTRING="L R" #L@R or L or R or Whole
  MatrixNumberSTRING="1" #1 or 3
  #PD="NO" #Set to YES if you used --pd flag in probtrackx or NO if you did not use it
  PD="YES" #Set to YES if you used --pd flag in probtrackx or NO if you did not use it
  #StepSize="0.11" #1/4 diffusion resolution recommended???
  StepSize="0.43" #1 diffusion resolution recommended???


  GitRepo="/media/2TBB/Connectome_Project/Pipelines" 
  for MatrixNumber in $MatrixNumberSTRING ; do
    for Hemisphere in $HemisphereSTRING ; do  
      fsl_sub -q long.q "$GitRepo"/DiffusionTractography/scripts/MakeTractographyDenseConnectomes.sh "$StudyFolder" "$Subject" "$DownSampleNameI" "$DiffusionResolution" "$Caret7_Command" "$Hemisphere" "$MatrixNumber" "$PD" "$StepSize"
      echo "set -- $StudyFolder $Subject $DownSampleNameI $DiffusionResolution $Caret7_Command $Hemisphere $MatrixNumber $PD $StepSize"
    done
  done
done

