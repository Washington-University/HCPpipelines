Subjlist="792564"
GitRepo="/media/2TBB/Connectome_Project/Pipelines"
StudyFolder="/media/myelin/brainmappers/Connectome_Project/TestStudyFolder" #Path to subject's data folder


for Subject in $Subjlist ; do
  #Input Variables
  Subject="$Subject"
  FinalTemplateSpace="${GitRepo}/global/templates/MNI152_T1_0.7mm.nii.gz"
  CaretAtlasFolder="${GitRepo}/global/templates/standard_mesh_atlases"
  DownSampleI="32000"
  DownSampleNameI="32"
  PipelineScripts="${GitRepo}/PostFreeSurfer/scripts"
  PipelineBinaries="${GitRepo}/global/binaries"
  GlobalScripts="${GitRepo}/global/scripts" #Location where the global pipeline modules are
  Caret5_Command="/usr/bin/caret_command" #Location of Caret5 caret_command
  Caret7_Command="wb_command"
  fsl_sub -q long.q ${GitRepo}/PostFreeSurfer/PostFreeSurferPipeline.sh "$StudyFolder" "$Subject" "$FinalTemplateSpace" "$CaretAtlasFolder" "$DownSampleI" "$DownSampleNameI" "$PipelineScripts" "$PipelineBinaries" "$GlobalScripts" "$Caret5_Command" "$Caret7_Command" 
  echo "set -- $StudyFolder $Subject $FinalTemplateSpace $CaretAtlasFolder $DownSampleI $DownSampleNameI $PipelineScripts $PipelineBinaries $GlobalScripts $Caret5_Command $Caret7_Command" 
done

