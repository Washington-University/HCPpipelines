#!/bin/bash

# # PostFreeSurferPipelineLongLauncher.sh
#
# ## Copyright Notice
#
# Copyright (C) 2022-2024 The Human Connectome Project
#
# * Washington University in St. Louis
# * University of Minnesota
# * Oxford University
#
# ## Author(s)
#
# * Mikhail Milchenko, Department of Radiology, Washington University in St. Louis
#
# ## Product
#
# [Human Connectome Project][HCP] (HCP) Longitudinal Pipelines
#
# ## License
#
# See the [LICENSE](https://github.com/Washington-University/HCPPipelines/blob/master/LICENSE.md) file

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/parallel.shlib" "$@"

opts_SetScriptDescription "launches longitudinal post-Freesurfer processing."

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject' 'Subject' 'subject ID' "subject label"
opts_AddMandatory '--longitudinal-template' 'LongitudinalTemplate' 'template ID' "longitudinal template label (matching the one used in FreeSurferPipeline-long)"
opts_AddMandatory '--sessions' 'Timepoint_list' 'list' '@ separated list of timepoints/sessions (should match directory names)'

#parallel mode options
opts_AddOptional '--parallel-mode' 'parallel_mode' 'string' "parallel mode, one of FSLSUB, BUILTIN, NONE [NONE]" 'NONE'
opts_AddOptional '--fslsub-queue' 'fslsub_queue' 'name' "FSLSUB queue name" ""
opts_AddOptional '--max-jobs' 'max_jobs' 'number' "Maximum number of concurrent processes in BUILTIN mode. Set to -1 to auto-detect [-1]." -1
opts_AddOptional '--start-stage' 'StartStage' 'stage_id' "Starting stage [PREP-TP]. One of PREP-TP (PostFSPrepLong timepoint processing), PREP-T (PostFSPrepLong build template, skip timepoint processing), POSTFS-TP1 (PostFreeSurfer timepoint stage 1), POSTFS-T (PostFreesurfer template), POSTFS-TP2 (PostFreesurfer timepoint stage 2)" "PREP-TP"
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
opts_AddMandatory '--surfatlasdir' 'SurfaceAtlasDIR' 'path' "<HCPpipelines>/global/templates/standard_mesh_atlases or equivalent"
opts_AddMandatory '--grayordinatesres' 'GrayordinatesResolutions' 'number' "usually '2', resolution of grayordinates to use"
opts_AddMandatory '--grayordinatesdir' 'GrayordinatesSpaceDIR' 'path' "<HCPpipelines>/global/templates/<num>_Greyordinates or equivalent, for the given --grayordinatesres"
opts_AddMandatory '--hiresmesh' 'HighResMesh' 'number' "usually '164', the standard mesh for T1w-resolution data data"
opts_AddMandatory '--lowresmesh' 'LowResMeshes' 'number' "usually '32', the standard mesh for fMRI data"
opts_AddMandatory '--subcortgraylabels' 'SubcorticalGrayLabels' 'file' "location of FreeSurferSubcorticalLabelTableLut.txt"
opts_AddMandatory '--refmyelinmaps' 'ReferenceMyelinMaps' 'file' "group myelin map to use for bias correction"
opts_AddOptional '--regname' 'RegName' 'name' "surface registration to use, default 'MSMSulc'" 'MSMSulc'
opts_AddOptional '--logdir' 'LogDir' 'string' "directory where logs will be written (default: current directory)" ""
opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

log_Check_Env_Var FSLDIR
log_Msg "HCPPIPEDIR: ${HCPPIPEDIR}"

IFS=@ read -r -a Timepoints <<< "${Timepoint_list[i]}"

if [ -n "$LogDir" ]; then
  mkdir -p "$LogDir"
  if [ -d "$LogDir" ]; then
    par_set_log_dir "$LogDir"
  else
    log_Err_Abort "Directory specified for logs $LogDir does not exist and cannot be created."
  fi
fi

if [ "$parallel_mode" != "NONE" -a "$parallel_mode" != "BUILTIN" -a "$parallel_mode" != "FSLSUB" ]; then
  log_Err_Abort "Unknown parallel mode $parallel_mode. Plese specify one of FSLSUB, BUILTIN, NONE"
fi

start_stage=0
if [ -n "$StartStage" ]; then
  case $StartStage in
    PREP-TP) start_stage=0 ;;
    PREP-T) start_stage=1 ;;
    POSTFS-TP1) start_stage=2 ;;
    POSTFS-T) start_stage=3 ;;
    POSTFS-TP2) start_stage=4 ;;
    *) log_Err_Abort "Unrecognized option for start-stage: $StartStage. Must be one of PREP-TP, PREP-T, POSTFS-TP1, POSTFS-T, POSTFS-TP2"
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
    *) log_Err_Abort "Unrecognized option for end-stage: $EndStage. Must be one of PREP-TP, PREP-T, POSTFS-TP1, POSTFS-T, POSTFS-TP2"
  esac
fi

if ((end_stage < 1)); then exit 0; fi

##########################################################################################
# PostFreeSurferPipelineLongPrep.sh processing
##########################################################################################
#process timepoints
if (( start_stage==0 )); then
  echo "################# PREP-TP Stage processing ########################"
  for TP in ${Timepoints[@]}; do
    echo "################# PREP-TP Stage processing ########################"
      echo "Running ppFS-long for timepoint: $TP"
      cmd=(${HCPPIPEDIR}/PostFreeSurfer/PostFreeSurferPipelineLongPrep.sh \
    --subject="$Subject" --path="$StudyFolder"                            \
    --longitudinal-template="$LongitudinalTemplate"                       \
    --sessions="$TP"                                                      \
    --template_processing=0                                               \
    --t1template="$T1wTemplate"                                           \
    --t1templatebrain="$T1wTemplateBrain"                                 \
    --t1template2mm="$T1wTemplate2mm"                                     \
    --t2template="$T2wTemplate"                                           \
    --t2templatebrain="$T2wTemplateBrain"                                 \
    --t2template2mm="$T2wTemplate2mm"                                     \
    --templatemask="$TemplateMask"                                        \
    --template2mmmask="$Template2mmMask"                                  \
    --fnirtconfig="$FNIRTConfig"                                          \
    --freesurferlabels="$FreeSurferLabels"                                \
      )
      par_add_job_to_stage $parallel_mode "$fslsub_queue" "${cmd[@]}"
  done
  par_finalize_stage $parallel_mode $max_jobs
fi

if ((end_stage < 1)); then exit 0; fi

if (( start_stage <= 1 )) && (( end_stage >= 1 )); then
  #Process template and finalize timepoints. This must wait until all timepoints are finished.
  echo "################# PREP-T Stage processing ########################"
  cmd=(${HCPPIPEDIR}/PostFreeSurfer/PostFreeSurferPipelineLongPrep.sh \
      --subject="$Subject"                                  \
      --path="$StudyFolder"                                 \
      --longitudinal-template="$LongitudinalTemplate"       \
      --sessions="$Timepoint_list"                          \
      --template_processing=1                               \
      --t1template="$T1wTemplate"                           \
      --t1templatebrain="$T1wTemplateBrain"                 \
      --t1template2mm="$T1wTemplate2mm"                     \
      --t2template="$T2wTemplate"                           \
      --t2templatebrain="$T2wTemplateBrain"                 \
      --t2template2mm="$T2wTemplate2mm"                     \
      --templatemask="$TemplateMask"                        \
      --template2mmmask="$Template2mmMask"                  \
      --fnirtconfig="$FNIRTConfig"                          \
      --freesurferlabels="$FreeSurferLabels"                \
  )
  par_add_job_to_stage $parallel_mode "$fslsub_queue" "${cmd[@]}"
  par_finalize_stage $parallel_mode $max_jobs
fi

##########################################################################################
# PostFreesurferPipeline.sh processing
##########################################################################################

if (( start_stage <=2 )) && (( end_stage >= 2 )); then
  echo "################# POSTFS-TP1 Stage processing ########################"
  job_list=()
  for Timepoint in ${Timepoints[@]}; do
    #process each timepoint
    cmd=("$HCPPIPEDIR"/PostFreeSurfer/PostFreeSurferPipeline.sh \
    --study-folder="$StudyFolder"                   \
    --subject-long="$Subject"                       \
    --longitudinal-mode="TIMEPOINT_STAGE1"          \
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
    par_add_job_to_stage $parallel_mode "$fslsub_queue" "${cmd[@]}"
  done
  par_finalize_stage $parallel_mode $max_jobs
fi

#process template. Must finish before timepoints are processed if MSMSulc is run.
if (( start_stage <=3 )) && (( end_stage >=3 )); then
  template_job=""
  echo "################# POSTFS-T Stage processing ########################"
  cmd=("$HCPPIPEDIR"/PostFreeSurfer/PostFreeSurferPipeline.sh \
    --study-folder="$StudyFolder"                     \
      --subject-long="$Subject"                       \
      --session="${Timepoints[0]}"                    \
      --longitudinal-mode="TEMPLATE"                  \
      --longitudinal-template="$LongitudinalTemplate" \
      --sessions="$Timepoint_list"                    \
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
  par_add_job_to_stage $parallel_mode "$fslsub_queue" "${cmd[@]}"
  par_finalize_stage $parallel_mode $max_jobs
fi

if (( start_stage <= 4 )) && (( end_stage >=4 )); then
  job_list=()
  echo "################# POSTFS-TP2 Stage processing ########################"
  for Timepoint in ${Timepoints[@]}; do
      #process each timepoint
    cmd=("$HCPPIPEDIR"/PostFreeSurfer/PostFreeSurferPipeline.sh \
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
    par_add_job_to_stage $parallel_mode "$fslsub_queue" "${cmd[@]}"
  done
  par_finalize_stage $parallel_mode $max_jobs
fi

# ----------------------------------------------------------------------
log_Msg "Completed main functionality"
# ----------------------------------------------------------------------
