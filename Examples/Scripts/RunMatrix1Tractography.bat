Subjlist="PostMortem1"


GitRepo="/media/2TBB/Connectome_Project/Pipelines" 

for Subject in $Subjlist ; do
  #Input Variables
  StudyFolder="/media/myelin/brainmappers/Connectome_Project/Macaques" #Path to subject's data folder
  Subject="$Subject"
  DownSampleNameI="32"
  DiffusionResolution="0.43"
  Caret7_Command="wb_command"
  HemisphereSTRING="L R" #L@R or L or R or Whole
  NumberOfSamples="5000" #1 sample then 2 and calculate total time required per sample
  StepSize="0.11" #1/4 diffusion resolution recommended
  Curvature="0" #Inverse cosine of this value is the angle, default 0.2=~78 degrees, 0=90 degrees
  DistanceThreshold="0" #Start at zero?

  GlobalBinariesDir="${GitRepo}/global/binaries"

  for Hemisphere in $HemisphereSTRING ; do
    fsl_sub -q long.q "$GitRepo"/RunMatrix1Tractography.sh "$StudyFolder" "$Subject" "$DownSampleNameI" "$DiffusionResolution" "$Caret7_Command" "$Hemisphere" "$NumberOfSamples" "$StepSize" "$Curvature" "$DistanceThreshold" "$GlobalBinariesDir"
    echo "set -- $StudyFolder $Subject $DownSampleNameI $DiffusionResolution $Caret7_Command $Hemisphere $NumberOfSamples $StepSize $Curvature $DistanceThreshold $GlobalBinariesDir"
  done
done

