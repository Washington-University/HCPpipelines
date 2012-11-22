Subjlist="792564"
GitRepo="/media/2TBB/Connectome_Project/Pipelines"
StudyFolder="/media/myelin/brainmappers/Connectome_Project/TestStudyFolder" #Path to subject's data folder


for Subject in $Subjlist ; do
  #Input Variables
  SubjectID="$Subject" #FreeSurfer Subject ID Name
  SubjectDIR="${StudyFolder}/${Subject}/T1w" #Location to Put FreeSurfer Subject's Folder
  T1wImage="${StudyFolder}/${Subject}/T1w/T1w_acpc_dc_restore.nii.gz" #T1w FreeSurfer Input (Full Resolution)
  T1wImageBrain="${StudyFolder}/${Subject}/T1w/T1w_acpc_dc_restore_brain.nii.gz" #T1w FreeSurfer Input (Full Resolution)
  T2wImage="${StudyFolder}/${Subject}/T1w/T2w_acpc_dc_restore.nii.gz" #T2w FreeSurfer Input (Full Resolution)
  PipelineScripts="${GitRepo}/FreeSurfer/scripts"
  PipelineBinaries="${GitRepo}/global/binaries"
  Caret5_Command="${GitRepo}/global/binaries/caret5/caret_command" #Location of Caret5 caret_command
  Caret7_Command="${GitRepo}/global/binaries/caret7/bin_linux64/wb_command"

  fsl_sub -q short.q ${GitRepo}/FreeSurfer/FreeSurferPipeline.sh "$SubjectID" "$SubjectDIR" "$T1wImage" "$T1wImageBrain" "$T2wImage" "$PipelineScripts" "$PipelineBinaries" "$Caret5_Command" "$Caret7_Command"
  echo "set -- $SubjectID $SubjectDIR $T1wImage $T1wImageBrain $T2wImage $PipelineScripts $PipelineBinaries $Caret5_Command $Caret7_Command"
done

