#Subjlist="CP10051_v3 CP10079_v2 CP10081_v3 CP10081_v6 CP10098_v2 CP10101_v1 CP10102_v1 CP10103_v1 CP10103_v4 CP10104_v1 CP10105_v1 CP10105_v4 CP10107_v1 CP10107_v4"
Subjlist="CP10101_v1"

for Subject in $Subjlist ; do
  #Input Variables
  StudyFolder="/media/myelin/brainmappers/Connectome_Project/ParcellationPilot" #Path to subject's data folder
  SubjectID="$Subject" #FreeSurfer Subject ID Name
  SubjectDIR="${StudyFolder}/${Subject}/T1w" #Location to Put FreeSurfer Subject's Folder
  T1wImage="${StudyFolder}/${Subject}/T1w/T1w_acpc_dc_restore.nii.gz" #T1w FreeSurfer Input (Full Resolution)
  T1wImageBrain="${StudyFolder}/${Subject}/T1w/T1w_acpc_dc_restore_brain.nii.gz" #T1w FreeSurfer Input (Full Resolution)
  T2wImage="${StudyFolder}/${Subject}/T1w/T2w_acpc_dc_restore.nii.gz" #T2w FreeSurfer Input (Full Resolution)
  PipelineScripts="/media/2TBB/Connectome_Project/Pipelines/FreeSurfer/scripts"
  PipelineBinaries="/media/2TBB/Connectome_Project/Pipelines/global/binaries"
  #set -- "$SubjectID" "$SubjectDIR" "$T1wImage" "$T1wImageBrain" "$T2wImage" "$PipelineScripts" "$PipelineBinaries"
  fsl_sub -q short.q /media/2TBB/Connectome_Project/Pipelines/FreeSurfer/FreeSurferPipeline.sh "$SubjectID" "$SubjectDIR" "$T1wImage" "$T1wImageBrain" "$T2wImage" "$PipelineScripts" "$PipelineBinaries"
  echo "$SubjectID" "$SubjectDIR" "$T1wImage" "$T1wImageBrain" "$T2wImage" "$PipelineScripts" "$PipelineBinaries"
done

