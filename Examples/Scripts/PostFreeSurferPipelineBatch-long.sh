#!/bin/bash 

function identify_timepoints
{
    local subject=$1
    local tplist=""
    local tp visit n

    #build the list of timepoints
    n=0
    for visit in ${PossibleVisits[*]}; do
        tp="${subject}_${visit}"
        if [ -d "$tp" ] && ! [[ " ${ExcludeVisits[*]} " =~ [[:space:]]${ExcludeVisits[*]}[[:space:]] ]]; then
            if (( n==0 )); then 
                tplist="$tp"
            else
                tplist="$tplist@tp"
            fi
        fi
    done
    echo $tplist
}

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
#Location of Subject folders (named by subjectID)
StudyFolder="<MyStudyPath>"
#list of subject labels, space separated
Subjects=(HCA6002236 HCA6002237 HCA6002238)
#The list of possible visits that each subject may have. Timepoint (visit) is expected to be named <Subject>_<Visit>.
#Actual visits (timepoints) are determined based on existing directories that match the visit name pattern.
PossibleVisits=(V1_MR V2_MR V3_MR V4_MR V5_MR V6_MR V7_MR V8_MR V9_MR V10_MR)
#list of visits to exclude across all subjects
ExcludeVisits=(HCA6002237_V1_MR HCA6002238_V1_MR)
#longitudinal template labels, one per each subject.
Templates=(HCA6002236_V1_V2 HCA6002237_V1_V2 HCA6002238_V1_V2)
#EnvironmentScript="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script
EnvironmentScript="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh"
source "$EnvironmentScript"

##################################################################################################
# Input variables used by PostFreesurferPipelineLongPrep
##################################################################################################
# Hires T1w MNI template
T1wTemplate="${HCPPIPEDIR_Templates}/MNI152_T1_0.8mm.nii.gz"
# Hires brain extracted MNI template1
T1wTemplateBrain="${HCPPIPEDIR_Templates}/MNI152_T1_0.8mm_brain.nii.gz"
# Lowres T1w MNI template
T1wTemplate2mm="${HCPPIPEDIR_Templates}/MNI152_T1_2mm.nii.gz"
# Hires T2w MNI Template
T2wTemplate="${HCPPIPEDIR_Templates}/MNI152_T2_0.8mm.nii.gz"
# Hires T2w brain extracted MNI Template
T2wTemplateBrain="${HCPPIPEDIR_Templates}/MNI152_T2_0.8mm_brain.nii.gz"
# Lowres T2w MNI Template
T2wTemplate2mm="${HCPPIPEDIR_Templates}/MNI152_T2_2mm.nii.gz"
# Hires MNI brain mask template
TemplateMask="${HCPPIPEDIR_Templates}/MNI152_T1_0.8mm_brain_mask.nii.gz"
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

#iterate over all subjects.
for i in ${!Subjects[@]}; do
  Subject=${Subjects[i]}
  LongitudinalTemplate=${Templates[i]}
  Timepoint_list=(`identify_timepoints $Subject`)
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
            --template="$LongitudinalTemplate" --timepoints="$TP" --template_processing=0 --t1template="$T1wTemplate" \
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
	--template="$LongitudinalTemplate" --timepoints="${Timepoint_list[i]}" --template_processing=1 --t1template="$T1wTemplate" \
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
	      --longitudinal-mode="TIMEPOINT_STAGE1" \
	      --longitudinal-template="$LongitudinalTemplate" \
	      --longitudinal-timepoint="$Timepoint")
	job_list+=("$job")
	#DEBUG
	#break
  done
  jl=$(IFS=','; echo "${job_list[*]}")

  echo "Launched stage 1 timepoint jobs: $jl (waiting for the prep template job $template_job)"

  #process template. Must finish before timepoints are processed if MSMSulc is run.
  echo "template processing"
  template_job=$($queuing_command -j $jl "$HCPPIPEDIR"/PostFreeSurfer/PostFreeSurferPipeline.sh \
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
      --longitudinal-mode="TEMPLATE" \
      --longitudinal-template="$LongitudinalTemplate" \
      --longitudinal-timepoint_list="${Timepoint_list[i]}" \
      --longitudinal-timepoint="$Timepoint")

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
	      --longitudinal-mode="TIMEPOINT_STAGE2" \
	      --longitudinal-template="$LongitudinalTemplate" \
	      --longitudinal-timepoint="$Timepoint")
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

