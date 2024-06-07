#!/bin/bash 

get_usage_and_exit(){
    echo "usage: "
    echo "PostFreeSurferPipelineBatch-long.sh [options]"
    echo "options:"
    echo "  --runlocal                      run locally [FALSE]"
    exit -1
}

command_line_specified_run_local=FALSE
while [ -n "$1" ]; do
    case "$1" in
        --runlocal) shift; command_line_specified_run_local=TRUE ;;
        *) shift ;;
    esac
done

#################################################################################################
# General input variables
##################################################################################################
StudyFolder=/media/myelin/brainmappers/Connectome_Project/MishaLongitudinal/hcp/FSLong-test
#StudyFolder="${HOME}/projects/Pipelines_ExampleData" #Location of Subject folders (named by subjectID)
#list of subject labels, space separated
Subjlist="HCA6002236"
#list of timepoints per each subject. Subject timepoint groups are space separated, timepoints within group are @ separated
Timepoint_list="HCA6002236_V1_MR@HCA6002236_V2_MR"
#list of longitudinal template labels, one per subject, space separated
Template_list="HCA6002236_V1_V2"
#EnvironmentScript="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script
EnvironmentScript=/media/myelin/brainmappers/Connectome_Project/MishaLongitudinal/hcp/scripts/SetUpHCPPipeline-long.sh
source "$EnvironmentScript"

##################################################################################################
# Input variables used by PostFreesurferPipelineLongPrep
##################################################################################################
# Hires T1w MNI template
T1wTemplate="${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm.nii.gz"
# Hires brain extracted MNI template1
T1wTemplateBrain="${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm_brain.nii.gz"
# Lowres T1w MNI template
T1wTemplate2mm="${HCPPIPEDIR_Templates}/MNI152_T1_2mm.nii.gz"
# Hires T2w MNI Template
T2wTemplate="${HCPPIPEDIR_Templates}/MNI152_T2_0.7mm.nii.gz"
# Hires T2w brain extracted MNI Template
T2wTemplateBrain="${HCPPIPEDIR_Templates}/MNI152_T2_0.7mm_brain.nii.gz"
# Lowres T2w MNI Template
T2wTemplate2mm="${HCPPIPEDIR_Templates}/MNI152_T2_2mm.nii.gz"
# Hires MNI brain mask template
TemplateMask="${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm_brain_mask.nii.gz"
# Lowres MNI brain mask template
Template2mmMask="${HCPPIPEDIR_Templates}/MNI152_T1_2mm_brain_mask_dil.nii.gz"
# FNIRT 2mm T1w Config
FNIRTConfig="${HCPPIPEDIR_Config}/T1_2_MNI152_2mm.cnf"
FreeSurferLabels="${HCPPIPEDIR_Config}/FreeSurferAllLut.txt"

##################################################################################################
# Input variables used by PostFreesurferPipeline (longitudinal mode)
##################################################################################################
SurfaceAtlasDIR="${HCPPIPEDIR_Templates}/standard_mesh_atlases"
GrayordinatesSpaceDIR="${HCPPIPEDIR_Templates}/91282_Greyordinates"
GrayordinatesResolution="2" #Usually 2mm, if multiple delimit with @, must already exist in templates dir
HighResMesh="164" #Usually 164k vertices
LowResMeshes="32" #Usually 32k vertices, if multiple delimit with @, must already exist in templates dir
SubcorticalGrayLabels="${HCPPIPEDIR_Config}/FreeSurferSubcorticalLabelTableLut.txt"
FreeSurferLabels="${HCPPIPEDIR_Config}/FreeSurferAllLut.txt"
ReferenceMyelinMaps="${HCPPIPEDIR_Templates}/standard_mesh_atlases/Conte69.MyelinMap_BC.164k_fs_LR.dscalar.nii"
RegName="MSMSulc" #MSMSulc is recommended, if binary is not available use FS (FreeSurfer)

# Requirements for this script
#  installed versions of: FSL, Connectome Workbench (wb_command)
#  environment: HCPPIPEDIR, FSLDIR, CARET7DIR

# Log the originating call
echo "$@"

#NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
#DO NOT include "-q " at the beginning
#default to no queue, implying run local
QUEUE=""
#QUEUE="hcp_priority.q"

########################################## INPUTS ########################################## 
#Scripts called by this script do assume they run on the outputs of the longitudinal FreeSurfer Pipeline
######################################### DO WORK ##########################################

Template_list=( ${Template_list[@]} )
Timepoint_list=( ${Timepoint_list[@]} )
Subjlist=( ${Subjlist[@]} )

#iterate over all subjects.
for i in ${!Subjlist[@]}; do
  Subject=${Subjlist[i]}
  LongitudinalTemplate=${Template_list[i]}
  IFS=@ read -r -a Timepoints <<< "${Timepoint_list[i]}"
  
  echo Subject: $Subject
  echo Template: $LongitudinalTemplate
  echo Timepoints: ${Timepoints[@]}

  if [[ "${command_line_specified_run_local}" == "TRUE" || "$QUEUE" == "" ]] ; then
      echo "About to locally run longitudinal mode of ${HCPPIPEDIR}/PostFreeSurfer/PostFreeSurferPipeline.sh "
      #NOTE: fsl_sub without -q runs locally and captures output in files
      queuing_command=("$FSLDIR/bin/fsl_sub")
  else
      echo "About to use fsl_sub to queue longitudinal mode of ${HCPPIPEDIR}/PostFreeSurfer/PostFreeSurferPipeline.sh"
      queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE")	
  fi

  ##########################################################################################
  # PostFreesurferPipelineLongPrep.sh processing
  ##########################################################################################
  #process timepoints
  job_list=()
  for TP in ${Timepoints[@]}; do
	echo "Running ppFS-long for timepoint: $TP"
        job=$($queuing_command ${HCPPIPEDIR}/PostFreeSurfer/PostFreesurferPipelineLongPrep.sh --subject="$Subject" --path="$StudyFolder" \
            --template="$Longitudinal_Template" --timepoints="$TP" --template_processing=0 --t1template="$T1wTemplate" \
            --t1templatebrain="$T1wTemplateBrain" --t1template2mm="$T1wTemplate2mm" --t2template="T2wTemplate" \
            --t2templatebrain="$T2wTemplateBrain" --t2template2mm="$T2wTemplate2mm" --templatemask="$TemplateMask" \
            --template2mmmask="$Template2mmMask" --fnirtconfig="$FNIRTConfig" --freesurferlabels="$FreeSurferLabels")
        echo "submitted timepoint job $job"
        job_list+=("$job")
  done
  #fi
  jl="${job_list[@]}"  
  #Process template and finalize timepoints. This must wait until all timepoints are finished.
  echo "Running ppFS-long for template $Template"
  template_job=$($queuing_command -j ${jl// /,} ${HCPPIPEDIR}/PostFreeSurfer/PostFreesurferPipelineLongPrep.sh --subject="$Subject" --path="$StudyFolder" \
	--template="$Longitudinal_Template" --timepoints="${Timepoint_list[i]}" --template_processing=1 --t1template="$T1wTemplate" \
        --t1templatebrain="$T1wTemplateBrain" --t1template2mm="$T1wTemplate2mm" --t2template="T2wTemplate" \
        --t2templatebrain="$T2wTemplateBrain" --t2template2mm="$T2wTemplate2mm" --templatemask="$TemplateMask" \
        --template2mmmask="$Template2mmMask" --fnirtconfig="$FNIRTConfig" --freesurferlabels="$FreeSurferLabels")
        echo "submitted template job $job"

  echo "Template processing job $template_job will wait for timepoint jobs $jl"

  ##########################################################################################
  # PostFreesurferPipeline.sh processing
  ##########################################################################################
  echo "Timepoint processing, stage 1"
  job_list=()
  for Timepoint in ${Timepoints[@]}; do
  	#input variables specific for timepoint mode (if any)  		  
  	# ...
	
	#DEBUG
	#continue
	#process each timepoint
	job=$($queuing_command -j $template_job "$HCPPIPEDIR"/PostFreeSurfer/PostFreeSurferPipeline.sh \
	      --study-folder="$StudyFolder" \
	      --subject="$Subject" \
	      --surfatlasdir="$SurfaceAtlasDIR" \
	      --grayordinatesdir="$GrayordinatesSpaceDIR" \
	      --grayordinatesres="$GrayordinatesResolution" \
	      --hiresmesh="$HighResMesh" \
	      --lowresmesh="$LowResMeshes" \
	      --subcortgraylabels="$SubcorticalGrayLabels" \
	      --freesurferlabels="$FreeSurferLabels" \
	      --refmyelinmaps="$ReferenceMyelinMaps" \
	      --regname="$RegName" \
	      --longitudinal_mode="TIMEPOINT_STAGE1" \
	      --longitudinal_template="$LongitudinalTemplate" \
	      --longitudinal_timepoint="$Timepoint")
	job_list+=("$job")
	#DEBUG
	#break
  done
  jl="${job_list[@]}"

  echo "Launched stage 1 timepoint jobs: $jl (waiting for the prep template job $template_job)"

  #process template. Must finish before timepoints are processed if MSMSulc is run.
  echo "template processing"
  template_job=$($queuing_command -j ${jl// /,} "$HCPPIPEDIR"/PostFreeSurfer/PostFreeSurferPipeline.sh \
      --study-folder="$StudyFolder" \
      --subject="$Subject" \
      --surfatlasdir="$SurfaceAtlasDIR" \
      --grayordinatesdir="$GrayordinatesSpaceDIR" \
      --grayordinatesres="$GrayordinatesResolution" \
      --hiresmesh="$HighResMesh" \
      --lowresmesh="$LowResMeshes" \
      --subcortgraylabels="$SubcorticalGrayLabels" \
      --freesurferlabels="$FreeSurferLabels" \
      --refmyelinmaps="$ReferenceMyelinMaps" \
      --regname="$RegName" \
      --longitudinal_mode="TEMPLATE" \
      --longitudinal_template="$LongitudinalTemplate" \
      --longitudinal_timepoint_list="${Timepoint_list[i]}" \
      --longitudinal_timepoint="$Timepoint")

  echo "Launched template job $template_job"
  echo "Template job $template_job will wait for Stage 1 timepoint jobs: $jl" 
  #DEBUG
  #break;

  job_list=()
  for Timepoint in ${Timepoints[@]}; do
  	#input variables specific for timepoint mode (if any)
  	# ...
	
	#DEBUG
	#continue
	#process each timepoint
	job=$($queuing_command -j $template_job "$HCPPIPEDIR"/PostFreeSurfer/PostFreeSurferPipeline.sh \
	      --study-folder="$StudyFolder" \
	      --subject="$Subject" \
	      --surfatlasdir="$SurfaceAtlasDIR" \
	      --grayordinatesdir="$GrayordinatesSpaceDIR" \
	      --grayordinatesres="$GrayordinatesResolution" \
	      --hiresmesh="$HighResMesh" \
	      --lowresmesh="$LowResMeshes" \
	      --subcortgraylabels="$SubcorticalGrayLabels" \
	      --freesurferlabels="$FreeSurferLabels" \
	      --refmyelinmaps="$ReferenceMyelinMaps" \
	      --regname="$RegName" \
	      --longitudinal_mode="TIMEPOINT_STAGE2" \
	      --longitudinal_template="$LongitudinalTemplate" \
	      --longitudinal_timepoint="$Timepoint")
    job_list+=("$job")
	#DEBUG
	#break
  done
  echo "launched stage 2 timepoint jobs: ${job_list[@]}"
  echo "Stage 2 timepoint jobs (${job_list[*]}) will wait for the template job: $template_job"
    
  # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...
  
  # echo "set -- --study-folder=$StudyFolder \
  #    --subject=$Subject \
  #    --surfatlasdir=$SurfaceAtlasDIR \
  #    --grayordinatesdir=$GrayordinatesSpaceDIR \
  #    --grayordinatesres=$GrayordinatesResolutions \
  #    --hiresmesh=$HighResMesh \
  #    --lowresmesh=$LowResMeshes \
  #    --subcortgraylabels=$SubcorticalGrayLabels \
  #    --freesurferlabels=$FreeSurferLabels \
  #    --refmyelinmaps=$ReferenceMyelinMaps \
  #    --regname=$RegName"
      
  # echo ". ${EnvironmentScript}"
done

