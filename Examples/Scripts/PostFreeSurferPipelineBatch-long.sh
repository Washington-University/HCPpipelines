#!/bin/bash 

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
#The list of subject labels, space separated
Subjects=(HCA6002236 HCA6002237 HCA6002238)
#The list of possible visits that each subject may have. Timepoint (visit) is expected to be named <Subject>_<Visit>.
PossibleVisits=(V1_MR V2_MR V3_MR)
#Actual visits (timepoints) are determined based on existing directories that match the visit name pattern <Subject>_<visit>.
#Excluded timepoint directories
#ExcludeVisits=(HCA6002237_V1_MR HCA6002238_V1_MR)
ExcludeVisits=()
#Longitudinal template labels, one per each subject.
Templates=(HCA6002236_V1_V2 HCA6002237_V1_V2 HCA6002238_V1_V2)
#EnvironmentScript="${HOME}/projects/HCPPipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script
EnvironmentScript="${HOME}/projects/HCPPipelines/Examples/Scripts/SetUpHCPPipeline.sh"
source "$EnvironmentScript"

##################################################################################################
# Input variables used by PostFreeSurferPipelineLongPrep
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

##################################################################################################
# Input variables used by PostFreesurferPipeline (longitudinal mode)
##################################################################################################
SurfaceAtlasDIR="${HCPPIPEDIR_Templates}/standard_mesh_atlases"
GrayordinatesSpaceDIR="${HCPPIPEDIR_Templates}/91282_Greyordinates"
GrayordinatesResolutions="2" #Usually 2mm, if multiple delimit with @, must already exist in templates dir
HighResMesh="164" #Usually 164k vertices
LowResMeshes="32" #Usually 32k vertices, if multiple delimit with @, must already exist in templates dir
SubcorticalGrayLabels="${HCPPIPEDIR_Config}/FreeSurferSubcorticalLabelTableLut.txt"
FreeSurferLabels="${HCPPIPEDIR_Config}/FreeSurferAllLut.txt"
ReferenceMyelinMaps="${HCPPIPEDIR_Templates}/standard_mesh_atlases/Conte69.MyelinMap_BC.164k_fs_LR.dscalar.nii"
RegName="MSMSulc" #MSMSulc is recommended, if binary is not available use FS (FreeSurfer)

# Requirements for this script
#  installed versions of: FSL, Connectome Workbench (wb_command)
#  environment: HCPPIPEDIR, FSLDIR, CARET7DIR

#fslsub queue
#QUEUE=short.q
#top level parallelization

QUEUE="long.q"

#pipeline level parallelization
#parallel mode: FSLSUB, BUILTIN, NONE
parallel_mode=BUILTIN

if [ "$parallel_mode" != FSLSUB ]; then #fsl_sub does not allow nested submissions
if [[ "${command_line_specified_run_local}" == "TRUE" || "$QUEUE" == "" ]] ; then
    echo "About to locally run ${HCPPIPEDIR}/PostFreeSurfer/PostFreeSurferPipelineLongLauncher.sh"
#    #NOTE: fsl_sub without -q runs locally and captures output in files
    queuing_command=("$FSLDIR/bin/fsl_sub")
     QUEUE=long.q
else
    echo "About to use fsl_sub to queue ${HCPPIPEDIR}/FreeSurfer/PostFreeSurferPipelineLongLauncher.sh"
    queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE")
    QUEUE=""    
fi
else
    queuing_command=""
fi
# This setting is for BUILTIN mode. Set to -1 to auto-detect the # of CPU cores on the node where each per-subject job is run.
# Note that in case when multiple subject jobs are run on the same node and are submitted 
# in parallel by e.g. fsl_sub, it may be inefficient to have the 
# (number of fsl_sub jobs running per node) * (BUILTIN parallelism) substantially exceed
# the number of cores per node
max_jobs=-1
#max_jobs=4

# Stages to run. Must be run in the following order:
# 1. PREP-TP, 2.PREP-T, 3. POSTFS-TP1, 4. POSTFS-T, 5. POSTFS-TP2
start_stage=PREP-TP
end_stage=POSTFS-TP2


function identify_timepoints
{
    local subject=$1
    local tplist=""
    local tp visit n

    #build the list of timepoints
    n=0
    for visit in ${PossibleVisits[*]}; do
        tp="${subject}_${visit}"
        if [ -d "$StudyFolder/$tp" ] && ! [[ " ${ExcludeVisits[*]+${ExcludeVisits[*]}} " =~ [[:space:]]"$tp"[[:space:]] ]]; then
             if (( n==0 )); then 
                    tplist="$tp"
             else
                    tplist="$tplist@$tp"
             fi
        fi
        ((n++))
    done
    echo $tplist
}

#iterate over all subjects.
for i in ${!Subjects[@]}; do
  Subject=${Subjects[i]}
  LongitudinalTemplate=${Templates[i]}
  Timepoint_list=(`identify_timepoints $Subject`)
  
  echo Subject: $Subject
  echo Template: $LongitudinalTemplate
  echo Timepoints: $Timepoint_list

  cmd=(${queuing_command[@]+"${queuing_command[@]}"} ${HCPPIPEDIR}/PostFreeSurfer/PostFreeSurferPipelineLongLauncher.sh \
    --study-folder="$StudyFolder"                       \
    --subject="$Subject"                                \
    --longitudinal-template="$LongitudinalTemplate"     \
    --sessions="$Timepoint_list"                        \
    --parallel-mode=$parallel_mode                      \
    --fslsub-queue=$QUEUE                               \
    --start-stage=$start_stage                          \
    --end-stage=$end_stage                              \
    --t1template="$T1wTemplate"                         \
    --t1templatebrain="$T1wTemplateBrain"               \
    --t1template2mm="$T1wTemplate2mm"                   \
    --t2template="$T2wTemplate"                         \
    --t2templatebrain="$T2wTemplateBrain"               \
    --t2template2mm="$T2wTemplate2mm"                   \
    --templatemask="$TemplateMask"                      \
    --template2mmmask="$Template2mmMask"                \
    --fnirtconfig="$FNIRTConfig"                        \
    --freesurferlabels="$FreeSurferLabels"              \
    --surfatlasdir="$SurfaceAtlasDIR"                   \
    --grayordinatesres="$GrayordinatesResolutions"      \
    --grayordinatesdir="$GrayordinatesSpaceDIR"         \
    --hiresmesh="$HighResMesh"                          \
    --lowresmesh="$LowResMeshes"                        \
    --subcortgraylabels="$SubcorticalGrayLabels"        \
    --refmyelinmaps="$ReferenceMyelinMaps"              \
    --regname="$RegName"                                \    
    )
    echo "Running $cmd"
    "${cmd[@]}"
done
