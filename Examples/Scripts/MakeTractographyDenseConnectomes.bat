#!/bin/bash
Subjlist="PostMortem1"

for Subject in $Subjlist ; do
  #Input Variables
  StudyFolder="/media/myelin/brainmappers/Connectome_Project/Macaques" #Path to subject's data folder
  Subject="$Subject"
  DownSampleNameI="32"
  DiffusionResolution="0.43"
  Caret7_Command="wb_command"
  HemisphereSTRING="L R" #L@R or L or R or Whole
  MatrixNumberSTRING="1 3"
  HemisphereSTRING="R" #L@R or L or R or Whole
  MatrixNumberSTRING="1"

  GitRepo="/media/2TBB/Connectome_Project/Pipelines" 
  for MatrixNumber in $MatrixNumberSTRING ; do
    for Hemisphere in $HemisphereSTRING ; do  
      fsl_sub -q long.q "$GitRepo"/MakeTractographyDenseConnectomes.sh "$StudyFolder" "$Subject" "$DownSampleNameI" "$DiffusionResolution" "$Caret7_Command" "$Hemisphere" "$MatrixNumber"
      echo "set -- $StudyFolder $Subject $DownSampleNameI $DiffusionResolution $Caret7_Command $Hemisphere $MatrixNumber"
    done
  done
done

