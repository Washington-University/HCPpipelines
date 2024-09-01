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
opts_AddMandatory '--timepoints' 'Timepoint_list' 'list' 'comma separated list of timepoints/sessions (should match directory names)'
opts_AddMandatory '--parallel-mode' 'parallel_mode' 'string' "parallelization execution mode, one of FSLSUB, BUILTIN"
opts_AddOptional '--parallel-mode-param' 'parallel_mode_param' 'custom' "FSLSUB: queue name [long.q]; BUILTIN: maximum number of threads [4]"

#Options needed for PreFreesurferPipeline functionality
opts_AddMandatory '--t1template' 'T1wTemplate' 'file_path' "MNI T1w template"
opts_AddMandatory '--t1templatebrain' 'T1wTemplateBrain' 'file_path' "Brain extracted MNI T1wTemplate"
opts_AddMandatory '--t1template2mm' 'T1wTemplate2mm' 'file_path' "MNI 2mm T1wTemplate"
opts_AddMandatory '--t2template' 'T2wTemplate' 'file_path' "MNI T2w template"
opts_AddMandatory '--t2templatebrain' 'T2wTemplateBrain' 'file_path' "Brain extracted MNI T2wTemplate"
opts_AddMandatory '--t2template2mm' 'T2wTemplate2mm' 'file_path' "MNI 2mm T2wTemplate"
opts_AddMandatory '--templatemask' 'TemplateMask' 'file_path' "Brain mask MNI Template"
opts_AddMandatory '--template2mmmask' 'Template2mmMask' 'file_path' "Brain mask MNI 2mm Template"
opts_AddMandatory '--fnirtconfig' 'FNIRTConfig' 'file_path' "FNIRT 2mm T1w Configuration file"

#PostFreeSurfer options
opts_AddMandatory '--freesurferlabels' 'FreeSurferLabels' 'file' "location of FreeSurferAllLut.txt"
opts_AddMandatory '--surfatlasdir' 'SurfaceAtlasDIR' 'path' "<pipelines>/global/templates/standard_mesh_atlases or equivalent"
opts_AddMandatory '--grayordinatesres' 'GrayordinatesResolutions' 'number' "usually '2', resolution of grayordinates to use"
opts_AddMandatory '--grayordinatesdir' 'GrayordinatesSpaceDIR' 'path' "<pipelines>/global/templates/<num>_Greyordinates or equivalent, for the given --grayordinatesres"
opts_AddMandatory '--hiresmesh' 'HighResMesh' 'number' "usually '164', the standard mesh for T1w-resolution data data"
opts_AddMandatory '--lowresmesh' 'LowResMeshes' 'number' "usually '32', the standard mesh for fMRI data"
opts_AddMandatory '--subcortgraylabels' 'SubcorticalGrayLabels' 'file' "location of FreeSurferSubcorticalLabelTableLut.txt"
opts_AddMandatory '--refmyelinmaps' 'ReferenceMyelinMaps' 'file' "group myelin map to use for bias correction"
opts_AddOptional '--regname' 'RegName' 'name' "surface registration to use, default 'MSMSulc'" 'MSMSulc'
opts_AddOptional '--start-stage' 'StartStage' 'stage_id' "Starting stage [NONE]. One of PREP-T (PostFSPrepLong build template, skip timepoint processing), POSTFS-TP1 (PostFreeSurfer timepoint stage 1), POSTFS-T (PostFreesurfer template), POSTFS-TP2 (PostFreesurfer timepoint stage 2)" 

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

IFS=, read -r -a Timepoints <<< "${Timepoint_list[i]}"
echo "parallel mode: $parallel_mode"

case $parallel_mode in
	FSLSUB) 
		if [ -z "$parallel_mode_param" ]; then parallel_mode_param=long.q; fi
		queuing_command="$FSLDIR/bin/fsl_sub -q $parallel_mode_param"		
		;;
	BUILTIN)
		if [ -z "$parallel_mode_param" ]; then parallel_mode_param=4; fi
		queuing_command="custom_submit"
		;;
	NONE)
		if [ -z "$parallel_mode_param" ]; then parallel_mode_param=""; fi
		queuing_command=""
		;;
	*)	
		log_Err_Abort "Unknown parallel mode. Plese specify one of FSLSUB, BUILTIN, NONE"
		;;
esac		
start_stage=0

if [ -n "$StartStage" ]; then
	
	case $StartStage in
		PREP-T) start_stage=1 ;;
		POSTFS-TP1) start_stage=2 ;;
		POSTFS-T) start_stage=3 ;;
		POSTFS-TP2) start_stage=4 ;;
		*) log_Err_Abort "Unrecognized option for start-stage: $StartStage"
	esac
fi

##########################################################################################
# PostFreesurferPipelineLongPrep.sh processing
##########################################################################################
#process timepoints
job_list=()

if (( start_stage==0 )); then 
	for TP in ${Timepoints[@]}; do
	    echo "Running ppFS-long for timepoint: $TP"
	    cmd=($queuing_command ${HCPPIPEDIR}/PostFreeSurfer/PostFreesurferPipelineLongPrep.sh \
		--subject="$Subject" --path="$StudyFolder" \
		--template="$LongitudinalTemplate"         \
		--timepoints="$TP"                         \
		--template_processing=0                    \
		--t1template="$T1wTemplate"                \
		--t1templatebrain="$T1wTemplateBrain"      \
		--t1template2mm="$T1wTemplate2mm"          \
		--t2template="$T2wTemplate"                \
		--t2templatebrain="$T2wTemplateBrain"      \
		--t2template2mm="$T2wTemplate2mm"          \
		--templatemask="$TemplateMask"             \
		--template2mmmask="$Template2mmMask"       \
		--fnirtconfig="$FNIRTConfig"               \
		--freesurferlabels="$FreeSurferLabels"     \
	    )
	    echo launching: ${cmd[*]}
	    job=$(${cmd[@]})
	    echo "submitted timepoint job $job"
	    job_list+=("$job")
	done
	jl="${job_list[@]}"
fi	

wait_for_jobs_option=""
if [ "$parallel_mode" != "NONE" ]; then
	if [ -n "$job_list" ]; then wait_for_jobs_option="-j ${jl// /,}"; fi
fi

template_job=""
if (( start_stage <= 1 )); then 
	#Process template and finalize timepoints. This must wait until all timepoints are finished.
	echo "Running ppFS-long for template $Template"
	cmd=($queuing_command $wait_for_jobs_option ${HCPPIPEDIR}/PostFreeSurfer/PostFreesurferPipelineLongPrep.sh \
	    --subject="$Subject"                       \
	    --path="$StudyFolder"                      \
		--template="$LongitudinalTemplate"         \
	    --timepoints="$Timepoint_list"             \
	    --template_processing=1                    \
	    --t1template="$T1wTemplate"                \
	    --t1templatebrain="$T1wTemplateBrain"      \
	    --t1template2mm="$T1wTemplate2mm"          \
	    --t2template="$T2wTemplate"                \
	    --t2templatebrain="$T2wTemplateBrain"      \
	    --t2template2mm="$T2wTemplate2mm"          \
	    --templatemask="$TemplateMask"             \
	    --template2mmmask="$Template2mmMask"       \
	    --fnirtconfig="$FNIRTConfig"               \
	    --freesurferlabels="$FreeSurferLabels"	 \
	)
	echo launching: ${cmd[*]}
	template_job=$(${cmd[@]})
	echo "submitted template job $job"
	echo "Template processing job $template_job will wait for timepoint jobs, if any: $jl"
fi
wait_for_jobs_option=""
if [ "$parallel_mode" != "NONE" ]; then
	if [ -n "$template_job" ]; then wait_for_jobs_option="-j $template_job"; fi
fi

##########################################################################################
# PostFreesurferPipeline.sh processing
##########################################################################################
job_list=()
if (( start_stage <=2 )); then 
	echo "PostFS Timepoint processing, stage 1"

	for Timepoint in ${Timepoints[@]}; do
		#process each timepoint
		cmd=($queuing_command $wait_for_jobs_option "$HCPPIPEDIR"/PostFreeSurfer/PostFreeSurferPipeline.sh \
		    --study-folder="$StudyFolder"               \ 
		--subject-long="$Subject"                       \
		--longitudinal-mode="TIMEPOINT_STAGE1"          \
		--longitudinal-template="$LongitudinalTemplate" \
		--session="$Timepoint"           		  \
		--freesurferlabels="$FreeSurferLabels"          \
		--surfatlasdir="$SurfaceAtlasDIR"               \
		--grayordinatesres="$GrayordinatesResolutions"  \
		--grayordinatesdir="$GrayordinatesSpaceDIR"     \
		--hiresmesh="$HighResMesh"                      \
		--lowresmesh="$LowResMeshes"                    \
		--subcortgraylabels="$SubcorticalGrayLabels"    \
		--refmyelinmaps="$ReferenceMyelinMaps"          \
		--regname="$RegName"
		)
	    	echo "launching: ${cmd[*]}"
	    	job=$(${cmd[@]})
	    	echo "launched, job number: $job"
		job_list+=("$job")
	done
	jl=$(IFS=','; echo "${job_list[*]}")
	echo "Launched stage 1 timepoint jobs: $jl (waiting for the prep template job, if any: $template_job)"
fi

wait_for_jobs_option=""
template_job=""
if [ "$parallel_mode" != "NONE" ]; then
	if [ -n "$job_list" ]; then wait_for_jobs_option="-j $jl"; fi
fi

#process template. Must finish before timepoints are processed if MSMSulc is run.
if (( start_stage <=3 )); then 
	echo "PostFS longitudinal template processing"
	cmd=($queuing_command $wait_for_jobs_option "$HCPPIPEDIR"/PostFreeSurfer/PostFreeSurferPipeline.sh \
		--study-folder="$StudyFolder"               \ 
	    --subject-long="$Subject"                       \
	    --session="${Timepoints[0]}"		      \ 
	    --longitudinal-mode="TEMPLATE"                  \
	    --longitudinal-template="$LongitudinalTemplate" \
	    --longitudinal-timepoint-list="$Timepoint_list" \
	    --freesurferlabels="$FreeSurferLabels"          \
	    --surfatlasdir="$SurfaceAtlasDIR"               \
	    --grayordinatesres="$GrayordinatesResolutions"  \
	    --grayordinatesdir="$GrayordinatesSpaceDIR"     \
	    --hiresmesh="$HighResMesh"                      \
	    --lowresmesh="$LowResMeshes"                    \
	    --subcortgraylabels="$SubcorticalGrayLabels"    \
	    --refmyelinmaps="$ReferenceMyelinMaps"          \
	    --regname="$RegName"
	)
	echo "launching: ${cmd[*]}"
	template_job=$(${cmd[@]})
	
	echo "Launched template job $template_job"
	echo "Template job $template_job will wait for Stage 1 timepoint jobs, if any: $jl" 
fi
job_list=()
wait_for_jobs_option=""
if [ "$parallel_mode" != "NONE" ]; then
	if [ -n "$template_job" ]; then wait_for_jobs_option="-j $template_job"; fi
fi

if (( start_stage <= 4 )); then 
	for Timepoint in ${Timepoints[@]}; do
	    #process each timepoint
		cmd=($queuing_command $wait_for_jobs_option "$HCPPIPEDIR"/PostFreeSurfer/PostFreeSurferPipeline.sh \
		    --study-folder="$StudyFolder"               \ 
		--subject-long="$Subject"                       \
		--longitudinal-mode="TIMEPOINT_STAGE2"          \
		--longitudinal-template="$LongitudinalTemplate" \
		--session="$Timepoint"                          \
		--freesurferlabels="$FreeSurferLabels"          \
		--surfatlasdir="$SurfaceAtlasDIR"               \
		--grayordinatesres="$GrayordinatesResolutions"  \
		--grayordinatesdir="$GrayordinatesSpaceDIR"     \
		--hiresmesh="$HighResMesh"                      \
		--lowresmesh="$LowResMeshes"                    \
		--subcortgraylabels="$SubcorticalGrayLabels"    \
		--refmyelinmaps="$ReferenceMyelinMaps"          \
		--regname="$RegName"
	    )
	    echo "launching: ${cmd[*]}"
	    job=$(${cmd[@]})
	    job_list+=("$job")
	done

	echo "launched stage 2 timepoint jobs: ${job_list[@]}"
	echo "Stage 2 timepoint jobs (${job_list[*]}) will wait for the template job, if any: $template_job"
fi
