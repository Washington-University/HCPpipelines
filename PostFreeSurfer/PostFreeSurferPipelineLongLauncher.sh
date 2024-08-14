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
opts_AddMandatory '--queuing-command' 'queuing_command' 'string' "queuing command"

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

IFS=@ read -r -a Timepoints <<< "${Timepoint_list[i]}"

##########################################################################################
# PostFreesurferPipelineLongPrep.sh processing
##########################################################################################
#process timepoints
job_list=()
for TP in ${Timepoints[@]}; do
    echo "Running ppFS-long for timepoint: $TP"
    job=$($queuing_command ${HCPPIPEDIR}/PostFreeSurfer/PostFreesurferPipelineLongPrep.sh \
        --subject-long="$Subject" --path="$StudyFolder" \
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
    echo "submitted timepoint job $job"
    job_list+=("$job")
done
jl="${job_list[@]}"
#Process template and finalize timepoints. This must wait until all timepoints are finished.
echo "Running ppFS-long for template $Template"
template_job=$($queuing_command -j ${jl// /,} ${HCPPIPEDIR}/PostFreeSurfer/PostFreesurferPipelineLongPrep.sh \
    --subject-long="$Subject"                       \
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
)
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
	    --study-folder="$StudyFolder"                   \ 
        --subject-long="$Subject"                            \
        --longitudinal-mode="TIMEPOINT_STAGE1"          \
        --longitudinal-template="$LongitudinalTemplate" \
        --session="$Timepoint"           \
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
	job_list+=("$job")
done
jl=$(IFS=','; echo "${job_list[*]}")
echo "Launched stage 1 timepoint jobs: $jl (waiting for the prep template job $template_job)"

#process template. Must finish before timepoints are processed if MSMSulc is run.
echo "PostFS longitudinal template processing"
template_job=$($queuing_command -j $jl "$HCPPIPEDIR"/PostFreeSurfer/PostFreeSurferPipeline.sh \
	--study-folder="$StudyFolder"                   \ 
    --subject-long="$Subject"                            \
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

echo "Launched template job $template_job"
echo "Template job $template_job will wait for Stage 1 timepoint jobs: $jl" 

job_list=()
for Timepoint in ${Timepoints[@]}; do
    #process each timepoint
	job=$($queuing_command -j $template_job "$HCPPIPEDIR"/PostFreeSurfer/PostFreeSurferPipeline.sh \
	    --study-folder="$StudyFolder"                   \ 
        --subject-long="$Subject"                            \
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
    job_list+=("$job")
done

echo "launched stage 2 timepoint jobs: ${job_list[@]}"
echo "Stage 2 timepoint jobs (${job_list[*]}) will wait for the template job: $template_job"
