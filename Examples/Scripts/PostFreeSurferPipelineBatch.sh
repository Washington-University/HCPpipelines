#!/bin/bash 

get_batch_options() {
    local arguments=("$@")

    command_line_specified_study_folder=""
    command_line_specified_subj=""
    command_line_specified_run_local="FALSE"

    local index=0
    local numArgs=${#arguments[@]}
    local argument

    while [ ${index} -lt ${numArgs} ]; do
        argument=${arguments[index]}

        case ${argument} in
            --StudyFolder=*)
                command_line_specified_study_folder=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --Subject=*)
                command_line_specified_subj=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --runlocal)
                command_line_specified_run_local="TRUE"
                index=$(( index + 1 ))
                ;;
            *)
                echo ""
                echo "ERROR: Unrecognized Option: ${argument}"
                echo ""
                exit 1
                ;;
        esac
    done
}

get_batch_options "$@"

StudyFolder="${HOME}/projects/Pipelines_ExampleData" #Location of Subject folders (named by subjectID)
Subjlist="100307 100610" #Space delimited list of subject IDs
EnvironmentScript="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi

if [ -n "${command_line_specified_subj}" ]; then
    Subjlist="${command_line_specified_subj}"
fi

# Requirements for this script
#  installed versions of: FSL, Connectome Workbench (wb_command)
#  environment: HCPPIPEDIR, FSLDIR, CARET7DIR

#Set up pipeline environment variables and software
source "$EnvironmentScript"

# Log the originating call
echo "$@"

#NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
#DO NOT include "-q " at the beginning
#default to no queue, implying run local
QUEUE=""
#QUEUE="hcp_priority.q"

########################################## INPUTS ########################################## 

#Scripts called by this script do assume they run on the outputs of the FreeSurfer Pipeline

######################################### DO WORK ##########################################


for Subject in $Subjlist ; do
    echo $Subject

    #Input Variables
    SurfaceAtlasDIR="${HCPPIPEDIR_Templates}/standard_mesh_atlases"
    GrayordinatesSpaceDIR="${HCPPIPEDIR_Templates}/91282_Greyordinates"
    GrayordinatesResolutions="2" #Usually 2mm, if multiple delimit with @, must already exist in templates dir
    HighResMesh="164" #Usually 164k vertices
    LowResMeshes="32" #Usually 32k vertices, if multiple delimit with @, must already exist in templates dir
    SubcorticalGrayLabels="${HCPPIPEDIR_Config}/FreeSurferSubcorticalLabelTableLut.txt"
    FreeSurferLabels="${HCPPIPEDIR_Config}/FreeSurferAllLut.txt"
    ReferenceMyelinMaps="${HCPPIPEDIR_Templates}/standard_mesh_atlases/Conte69.MyelinMap_BC.164k_fs_LR.dscalar.nii"
    RegName="MSMSulc" #MSMSulc is recommended, if binary is not available use FS (FreeSurfer)
    UseIndMean="YES"
    if [[ "${command_line_specified_run_local}" == "TRUE" || "$QUEUE" == "" ]] ; then
        echo "About to locally run ${HCPPIPEDIR}/PostFreeSurfer/PostFreeSurferPipeline.sh"
        queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
    else
        echo "About to use fsl_sub to queue ${HCPPIPEDIR}/PostFreeSurfer/PostFreeSurferPipeline.sh"
        queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE")
    fi

    "${queuing_command[@]}" "$HCPPIPEDIR"/PostFreeSurfer/PostFreeSurferPipeline.sh \
        --study-folder="$StudyFolder" \
        --subject="$Subject" \
        --surfatlasdir="$SurfaceAtlasDIR" \
        --grayordinatesdir="$GrayordinatesSpaceDIR" \
        --grayordinatesres="$GrayordinatesResolutions" \
        --hiresmesh="$HighResMesh" \
        --lowresmesh="$LowResMeshes" \
        --subcortgraylabels="$SubcorticalGrayLabels" \
        --freesurferlabels="$FreeSurferLabels" \
        --refmyelinmaps="$ReferenceMyelinMaps" \
        --regname="$RegName" \
        --use-ind-mean="$UseIndMean"

    # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...

    echo "set -- --study-folder=$StudyFolder \
        --subject=$Subject \
        --surfatlasdir=$SurfaceAtlasDIR \
        --grayordinatesdir=$GrayordinatesSpaceDIR \
        --grayordinatesres=$GrayordinatesResolutions \
        --hiresmesh=$HighResMesh \
        --lowresmesh=$LowResMeshes \
        --subcortgraylabels=$SubcorticalGrayLabels \
        --freesurferlabels=$FreeSurferLabels \
        --refmyelinmaps=$ReferenceMyelinMaps \
        --regname=$RegName \
        --use-ind-mean="$UseIndMean""

    echo ". ${EnvironmentScript}"
done
