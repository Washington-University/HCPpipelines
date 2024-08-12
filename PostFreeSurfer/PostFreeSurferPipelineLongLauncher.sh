#!/bin/bash

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/processingmodecheck.shlib" "$@" # Check processing mode requirements

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects" 
opts_AddMandatory '--subject' 'Subject' 'subject ID' "subject label"
opts_AddMandatory '--template' 'LongitudinalTemplate' 'template ID' "longitudinal template label (matching the one used in FreeSurferPipeline-long)"
opts_AddMandatory '--timepoints' 'Timepoint_list' '@ separated list of timepoints (should match directory names)'
opts_AddMandatory '--common-prep-args' 'PrepArgs' 'args' "common arguments for PostFreeSurferPipelineLongPrep"
opts_AddMandatory '--common-postfs-args' 'PostFSArgs' 'args' "common arguments for PostFreesurferPipeline"
opts_AddMandatory '--queuing-command' 'queuing_command' 'string' "queueing command"

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

log_Check_Env_Var FSLDIR
verbose_red_echo "---> Starting ${log_ToolName}"
verbose_echo " "
verbose_echo " Using environment setting ..."
verbose_echo "          HCPPIPEDIR: ${HCPPIPEDIR}"
verbose_echo " "

IFS=@ read -r -a Timepoints <<< "${Timepoint_list[i]}"

##########################################################################################
# PostFreesurferPipelineLongPrep.sh processing
##########################################################################################
#process timepoints
job_list=()
for TP in ${Timepoints[@]}; do
    echo "Running ppFS-long for timepoint: $TP"
    job=$($queuing_command ${HCPPIPEDIR}/PostFreeSurfer/PostFreesurferPipelineLongPrep.sh --subject="$Subject" --path="$StudyFolder" \
            --template="$LongitudinalTemplate" --timepoints="$TP" --template_processing=0 $PrepArgs)
    echo "submitted timepoint job $job"
    job_list+=("$job")
done
jl="${job_list[@]}"
#Process template and finalize timepoints. This must wait until all timepoints are finished.
echo "Running ppFS-long for template $Template"
template_job=$($queuing_command -j ${jl// /,} ${HCPPIPEDIR}/PostFreeSurfer/PostFreesurferPipelineLongPrep.sh --subject="$Subject" --path="$StudyFolder" \
	--template="$LongitudinalTemplate" --timepoints="$Timepoint_list" --template_processing=1 $PrepArgs)
echo "submitted template job $job"

echo "Template processing job $template_job will wait for timepoint jobs $jl"

##########################################################################################
# PostFreesurferPipeline.sh processing
##########################################################################################
echo "PostFS Timepoint processing, stage 1"
job_list=()
for Timepoint in ${Timepoints[@]}; do
	#process each timepoint
	job=$($queuing_command -j $template_job "$HCPPIPEDIR"/PostFreeSurfer/PostFreeSurferPipeline.sh \
	      --study-folder="$StudyFolder" --subject="$Subject" --longitudinal-mode="TIMEPOINT_STAGE1" \
          --longitudinal-template="$LongitudinalTemplate" --longitudinal-timepoint="$Timepoint" $PostFSArgs)
	job_list+=("$job")
done
jl=$(IFS=','; echo "${job_list[*]}")
echo "Launched stage 1 timepoint jobs: $jl (waiting for the prep template job $template_job)"

#process template. Must finish before timepoints are processed if MSMSulc is run.
echo "PostFS longitudinal template processing"
template_job=$($queuing_command -j $jl "$HCPPIPEDIR"/PostFreeSurfer/PostFreeSurferPipeline.sh \
      --study-folder="$StudyFolder" --subject="$Subject" --longitudinal-mode="TEMPLATE" --longitudinal-template="$LongitudinalTemplate" \
      --longitudinal-timepoint-list="$Timepoint_list" $PostFSArgs)

echo "Launched template job $template_job"
echo "Template job $template_job will wait for Stage 1 timepoint jobs: $jl" 

job_list=()
for Timepoint in ${Timepoints[@]}; do
    #process each timepoint
	job=$($queuing_command -j $template_job "$HCPPIPEDIR"/PostFreeSurfer/PostFreeSurferPipeline.sh \
	      --study-folder="$StudyFolder" --subject="$Subject" --longitudinal-mode="TIMEPOINT_STAGE2" \
          --longitudinal-template="$LongitudinalTemplate" --longitudinal-timepoint="$Timepoint" $PostFSArgs)          
    job_list+=("$job")
done

echo "launched stage 2 timepoint jobs: ${job_list[@]}"
echo "Stage 2 timepoint jobs (${job_list[*]}) will wait for the template job: $template_job"
