#Subjlist="CP10051_v3 CP10079_v2 CP10081_v3 CP10081_v6 CP10098_v2 CP10101_v1 CP10102_v1 CP10103_v1 CP10103_v4 CP10104_v1 CP10105_v1 CP10105_v4 CP10107_v1 CP10107_v4"
Subjlist="CP10101_v1"
Path="/media/myelin/brainmappers/Connectome_Project/ParcellationPilot"


#Tasklist="REST1 BIOMOTION1 LANG1 LANG2 MOTOR1 SOCIAL1 SOCIAL2 WM1 WM2 WM3 WM4"
#Tasklist="REST1"
Tasklist="BIOMOTION1"
#Tasklist="MOTOR1"

for Subject in $Subjlist ; do
  for Task in $Tasklist ; do
    if [ -z `echo $Task | grep REST` ] ; then
      Type="tfMRI"
    else
      Type="rfMRI"
    fi
    Path="/media/myelin/brainmappers/Connectome_Project/ParcellationPilot"
    Subject="$Subject"
    OutputNameOffMRI="${Type}_${Task}"
    DownSampleNameI="32"
    FinalfMRIResolution="2"
    SmoothingFWHM="2"
    Caret5_Command="/usr/bin/caret_command" #Location of Caret5 caret_command
    Caret7_Command="/media/myelin/distribution/caret7_distribution/workbench/bin_linux64/wb_command"
    PipelineScripts="/media/2TBB/Connectome_Project/Pipelines/fMRISurface/scripts"
    AtlasParcellation="/media/2TBB/Connectome_Project/Pipelines/global/templates/standard_mesh_atlases/CCNMD_MyelinMapping_Avgwmparc.nii.gz"
    AtlasSurfaceROIs="/media/2TBB/Connectome_Project/Pipelines/global/templates/standard_mesh_atlases/fs_L/CCNMD_MyelinMapping.L.Atlas_Cortex_ROI.164k_fs_LR.func.gii@/media/2TBB/Connectome_Project/Pipelines/global/templates/standard_mesh_atlases/fs_R/CCNMD_MyelinMapping.R.Atlas_Cortex_ROI.164k_fs_LR.func.gii" #delimit left and right files with @
    BrainOrdinatesResolution="SAME" #Could be "SAME" or "DIFFERENT"
    SubcorticalBrainOrdinatesLabels="/media/2TBB/Connectome_Project/Pipelines/global/config/FreeSurferSubcorticalLabelTableLut.txt"

    #fsl_sub -q dyn.q /media/2TBB/Connectome_Project/Pipelines/GenericfMRISurfaceProcessingPipeline.sh $Path $Subject $OutputNameOffMRI $DownSampleNameI $FinalfMRIResolution $SmoothingFWHM $Caret5_Command $Caret7_Command $PipelineScripts $AtlasParcellation $AtlasSurfaceROIs $BrainOrdinatesResolution $SubcorticalBrainOrdinatesLabels
    echo "set -- $Path $Subject $OutputNameOffMRI $DownSampleNameI $FinalfMRIResolution $SmoothingFWHM $Caret5_Command $Caret7_Command $PipelineScripts $AtlasParcellation $AtlasSurfaceROIs $BrainOrdinatesResolution $SubcorticalBrainOrdinatesLabels"
  done
done

