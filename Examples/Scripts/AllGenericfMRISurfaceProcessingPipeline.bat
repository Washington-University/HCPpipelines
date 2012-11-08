Subjlist="792564"
GitRepo="/media/2TBB/Connectome_Project/Pipelines"
StudyFolder="/media/myelin/brainmappers/Connectome_Project/TestStudyFolder" #Path to subject's data folder


Tasklist="EMOTION1 EMOTION2"

for Subject in $Subjlist ; do
  for Task in $Tasklist ; do
    if [ -z `echo $Task | grep REST` ] ; then
      Type="tfMRI"
    else
      Type="rfMRI"
    fi
    Subject="$Subject"
    OutputNameOffMRI="${Type}_${Task}"
    DownSampleNameI="32"
    FinalfMRIResolution="2"
    SmoothingFWHM="2"
    Caret5_Command="/usr/bin/caret_command" #Location of Caret5 caret_command
    Caret7_Command="wb_command"
    PipelineScripts="${GitRepo}/fMRISurface/scripts"
    AtlasParcellation="${GitRepo}/global/templates/standard_mesh_atlases/CCNMD_MyelinMapping_Avgwmparc.nii.gz"
    AtlasSurfaceROIs="${GitRepo}/global/templates/standard_mesh_atlases/fs_L/CCNMD_MyelinMapping.L.Atlas_Cortex_ROI.164k_fs_LR.func.gii@${GitRepo}/global/templates/standard_mesh_atlases/fs_R/CCNMD_MyelinMapping.R.Atlas_Cortex_ROI.164k_fs_LR.func.gii" #delimit left and right files with @
    BrainOrdinatesResolution="2" #Could be the same as FinalfRMIResolution something different, which will call a different module for subcortical processing
    SubcorticalBrainOrdinatesLabels="${GitRepo}/global/config/FreeSurferSubcorticalLabelTableLut.txt"
    
    if [ -e "$StudyFolder"/"$Subject"/MNINonLinear/Results/"$OutputNameOffMRI"/"$OutputNameOffMRI".nii.gz ] ; then
      fsl_sub -q long.q ${GitRepo}/fMRISurface/GenericfMRISurfaceProcessingPipeline.sh $StudyFolder $Subject $OutputNameOffMRI $DownSampleNameI $FinalfMRIResolution $SmoothingFWHM $Caret5_Command $Caret7_Command $PipelineScripts $AtlasParcellation $AtlasSurfaceROIs $BrainOrdinatesResolution $SubcorticalBrainOrdinatesLabels
      echo "set -- $StudyFolder $Subject $OutputNameOffMRI $DownSampleNameI $FinalfMRIResolution $SmoothingFWHM $Caret5_Command $Caret7_Command $PipelineScripts $AtlasParcellation $AtlasSurfaceROIs $BrainOrdinatesResolution $SubcorticalBrainOrdinatesLabels"
    else
      echo "fMRI Run ""$OutputNameOffMRI"" Not Found"
    fi      
  done
done

