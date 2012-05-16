Subjlist="CP10104_v1"
#Subjlist="CP10051_v3 CP10079_v2 CP10081_v3 CP10081_v6 CP10098_v2 CP10101_v1 CP10102_v1 CP10103_v1 CP10103_v4 CP10104_v1 CP10105_v1 CP10105_v4 CP10107_v1 CP10107_v4"

# MG environment...
# StudyFolder="/media/myelin/brainmappers/Connectome_Project/ParcellationPilot"
# FinalTemplateSpace="/media/2TBB/Connectome_Project/Pipelines/global/templates/MNI152_T1_0.8mm.nii.gz"
# CaretAtlasFolder="/media/2TBB/Connectome_Project/Pipelines/global/templates/standard_mesh_atlases"
# DownSampleI="32000"
# DownSampleNameI="32"
# PipelineScripts="/media/2TBB/Connectome_Project/Pipelines/PostFreeSurfer/scripts"
# PipelineBinaries="/media/2TBB/Connectome_Project/Pipelines/global/binaries"
# GlobalScripts="/media/2TBB/Connectome_Project/Pipelines/global/scripts" #Location where the global pipeline modules are
# Caret5_Command="/usr/bin/caret_command" #Location of Caret5 caret_command
# Caret7_Command="/media/myelin/distribution/caret7_distribution/workbench/bin_linux64/wb_command"
  
# NRG environment...
StudyFolder="/home/NRG/jwilso01/nifti/" 
FinalTemplateSpace="/home/NRG/jwilso01/dev/Pipelines/global/templates/MNI152_T1_0.8mm.nii.gz"
CaretAtlasFolder="/home/NRG/jwilso01/dev/Pipelines/global/templates/standard_mesh_atlases"
DownSampleI="32000"
DownSampleNameI="32"
PipelineScripts="/home/NRG/jwilso01/dev/Pipelines/PostFreeSurfer/scripts"
PipelineBinaries="/home/NRG/jwilso01/dev/Pipelines/global/binaries"
GlobalScripts="/home/NRG/jwilso01/dev/Pipelines/global/scripts" #Location where the global pipeline modules are
Caret5_Command="/home/NRG/jwilso01/dev/Pipelines/global/binaries/caret5/caret_command"
Caret7_Command=" /home/NRG/jwilso01/dev/Pipelines/global/binaries/caret7/exe_linux64/wb_command"

for Subject in $Subjlist ; do

  Subject="$Subject"

  #set -- "$StudyFolder" "$Subject" "$FinalTemplateSpace" "$CaretAtlasFolder" "$DownSampleI" "$DownSampleNameI" "$PipelineScripts" "$PipelineBinaries" "$GlobalScripts" "$Caret5_Command" "$Caret7_Command" 
  # fsl_sub -q long.q /media/2TBB/Connectome_Project/Pipelines/PostFreeSurfer/PostFreeSurferPipeline.sh "$StudyFolder" "$Subject" "$FinalTemplateSpace" "$CaretAtlasFolder" "$DownSampleI" "$DownSampleNameI" "$PipelineScripts" "$PipelineBinaries" "$GlobalScripts" "$Caret5_Command" "$Caret7_Command" 
  # echo "$StudyFolder" "$Subject" "$FinalTemplateSpace" "$CaretAtlasFolder" "$DownSampleI" "$DownSampleNameI" "$PipelineScripts" "$PipelineBinaries" "$GlobalScripts" "$Caret5_Command" "$Caret7_Command" 
  
  echo -e "$StudyFolder\n" "$Subject\n" "$FinalTemplateSpace\n" "$CaretAtlasFolder\n" "$DownSampleI\n" "$DownSampleNameI\n" "$PipelineScripts\n" "$PipelineBinaries\n" "$GlobalScripts\n" "$Caret5_Command\n" "$Caret7_Command" 
  /home/NRG/jwilso01/dev/Pipelines/PostFreeSurfer/PostFreeSurferPipeline.sh "$StudyFolder" "$Subject" "$FinalTemplateSpace" "$CaretAtlasFolder" "$DownSampleI" "$DownSampleNameI" "$PipelineScripts" "$PipelineBinaries" "$GlobalScripts" "$Caret5_Command" "$Caret7_Command" 
  
done

