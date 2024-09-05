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
source "$HCPPIPEDIR/global/scripts/parallel.shlib" "$@"

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects" 
opts_AddMandatory '--subject' 'Subject' 'subject ID' "subject label"
opts_AddMandatory '--template' 'LongitudinalTemplate' 'template ID' "longitudinal template label (matching the one used in FreeSurferPipeline-long)"
opts_AddMandatory '--timepoints' 'Timepoint_list' 'list' 'comma separated list of timepoints/sessions (should match directory names)'

#parallel mode options
opts_AddOptional '--parallel-mode' 'parallel_mode' 'string' "parallel mode, one of FSLSUB, BUILTIN, NONE [NONE]" 'NONE'
opts_AddOptional '--fslsub-queue' 'queue' 'name' "FSLSUB queue name" "short.q"
opts_AddOptional '--max-jobs' 'max_jobs' 'number' "Maximum number of concurrent processes in BUILTIN mode [4]." 4
opts_AddOptional '--start-stage' 'StartStage' 'stage_id' "Starting stage [PREP-TP]. One of PREP-TP (PostFSPrepLong timepoint processing), PREP-T (PostFSPrepLong build template, skip timepoint processing), POSTFS-TP1 (PostFreeSurfer timepoint stage 1), POSTFS-T (PostFreesurfer template), POSTFS-TP2 (PostFreesurfer timepoint stage 2)" "PREP-T"
opts_AddOptional '--end-stage' 'EndStage' 'stage_id' "End stage [POSTFS-TP2]. Options are the same as for --start-stage." "POSTFS-TP2"


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
		if [ -n "$queue" ]; then 
		queuing_command="$FSLDIR/bin/fsl_sub -q $queue"
		else
			queuing_command="$FSLDIR/bin/fsl_sub"
		fi		
		;;
	BUILTIN)
		queuing_command="par_addjob"
		max_jobs=$parallel_mode_param
		;;
	NONE)
		queuing_command=""
		;;
	*)	
		log_Err_Abort "Unknown parallel mode. Plese specify one of FSLSUB, BUILTIN, NONE"
		;;
esac
start_stage=0
if [ -n "$StartStage" ]; then	
	case $StartStage in
		PREP-TP) start_stage=0 ;;
		PREP-T) start_stage=1 ;;
		POSTFS-TP1) start_stage=2 ;;
		POSTFS-T) start_stage=3 ;;
		POSTFS-TP2) start_stage=4 ;;
		*) log_Err_Abort "Unrecognized option for start-stage: $StartStage"
	esac
fi
end_stage=4
if [ -n "$EndStage" ]; then	
	case $EndStage in
		PREP-TP) end_stage=0 ;;
		PREP-T) end_stage=1 ;;
		POSTFS-TP1) end_stage=2 ;;
		POSTFS-T) end_stage=3 ;;
		POSTFS-TP2) end_stage=4 ;;
		*) log_Err_Abort "Unrecognized option for end-stage: $EndStage"
	esac
fi

##########################################################################################
# PostFreesurferPipelineLongPrep.sh processing
##########################################################################################
#process timepoints
if (( start_stage==0 )); then 
	job_list=()
	echo "################# PREP-TP Stage processing ########################"
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
		if [ $PARALLEL_MODE == "FSLSUB" ]; then 
				job=$(${cmd[@]}); job_list+=("$job")
		else 
			${cmd[@]}
			if [ $PARALLEL_MODE == NONE ] && (( $? )); then log_Err_Abort "one of parallel jobs failed, exiting"; fi
		fi
	done
	echo "waiting for all PREP-TP jobs to finish"
	if [ $PARALLEL_MODE == "FSLSUB" ]; then 
		par_waitjobs_fslsub ${job_list[@]}
	else 
		par_runjobs $max_jobs
		if (( $? )); then log_Err_Abort "one of parallel jobs failed, exiting"; fi
	fi
fi

if (( start_stage <= 1 )) && (( end_stage >= 1 )); then 
	#Process template and finalize timepoints. This must wait until all timepoints are finished.
	echo "################# PREP-T Stage processing ########################"
	cmd=($queuing_command ${HCPPIPEDIR}/PostFreeSurfer/PostFreesurferPipelineLongPrep.sh \
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

	template_job=""
	echo launching: ${cmd[*]}
	echo "waiting for PREP-T job to finish"
	if [ $PARALLEL_MODE == "FSLSUB" ]; then 
			template_job=$(${cmd[@]})
			par_waitjobs_fslsub $template_job
	else 
		${cmd[@]}
		par_runjobs $max_jobs
		if (( $? )); then log_Err_Abort "PREP-T job failed, exiting"; fi
	fi
fi

##########################################################################################
# PostFreesurferPipeline.sh processing
##########################################################################################

if (( start_stage <=2 )) && (( end_stage >= 2 )); then 
	echo "################# POSTFS-TP1 Stage processing ########################"
	job_list=()
	for Timepoint in ${Timepoints[@]}; do
		#process each timepoint
		cmd=($queuing_command "$HCPPIPEDIR"/PostFreeSurfer/PostFreeSurferPipeline.sh \
		--study-folder="$StudyFolder"               	\ 
		--subject-long="$Subject"                       \
		--longitudinal-mode="TIMEPOINT_STAGE1"          \
		--longitudinal-template="$LongitudinalTemplate" \
		--session="$Timepoint"           		  		\
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
		if [ $PARALLEL_MODE == "FSLSUB" ]; then 
				job=$(${cmd[@]}); job_list+=("$job")
		else 
			${cmd[@]}
		fi
	done

	echo "waiting for all POSTFS-TP1 jobs to finish"
	if [ $PARALLEL_MODE == "FSLSUB" ]; then 
		par_waitjobs_fslsub ${job_list[@]}
	else
		par_runjobs $max_jobs
		if (( $? )); then log_Err_Abort "one of parallel jobs failed, exiting"; fi
	fi
fi

#process template. Must finish before timepoints are processed if MSMSulc is run.
if (( start_stage <=3 )) && (( end_stage >=3 )); then 
	template_job=""
	echo "################# POSTFS-T Stage processing ########################"
	cmd=($queuing_command "$HCPPIPEDIR"/PostFreeSurfer/PostFreeSurferPipeline.sh \
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
	template_job=""
	echo launching: ${cmd[*]}
	echo "waiting for POSTFS-T job to finish"
	if [ $PARALLEL_MODE == "FSLSUB" ]; then
			template_job=$(${cmd[@]})
			par_waitjobs_fslsub $template_job
	else 
		${cmd[@]}
		par_runjobs $max_jobs
		if (( $? )); then log_Err_Abort "POSTFS-T job failed, exiting"; fi
	fi
fi

if (( start_stage <= 4 )) && (( end_stage >=4 )); then 
	job_list=()
	echo "################# POSTFS-TP2 Stage processing ########################"
	for Timepoint in ${Timepoints[@]}; do
	    #process each timepoint
		cmd=($queuing_command "$HCPPIPEDIR"/PostFreeSurfer/PostFreeSurferPipeline.sh \
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
	    echo launching: ${cmd[*]}
		if [ $PARALLEL_MODE == "FSLSUB" ]; then 
				job=$(${cmd[@]}); job_list+=("$job")
		else 
			${cmd[@]}
		fi
	done
	echo "waiting for all jobs to finish for stage POSTFS-TP2"
	if [ $PARALLEL_MODE == "FSLSUB" ]; then
		par_waitjobs_fslsub ${job_list[@]}
	else 
		par_runjobs $max_jobs
		if (( $? )); then log_Err_Abort "one of parallel jobs failed, exiting"; fi
	fi
fi
