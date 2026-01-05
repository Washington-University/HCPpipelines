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
            --Session=*)
                command_line_specified_sess=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --Species=*) #Species type (Human, Chimp, Mac, Marmoset, etc.)
                Species=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --StructRes=*) #Structural resolution in mm (species-specific default will be used if not specified)
                StructRes=${argument#*=}
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

StudyFolder="${HOME}/projects/HCPPipelines_ExampleData" #Location of Session folders (named by subjectID)
Sessionlist="100307 100610" #Space delimited list of subject IDs
EnvironmentScript="${HOME}/projects/HCPPipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script
SPECIES="Human"

if [ -z "$StructRes" ]; then 
    StructResOption=""
else 
    StructResOption="--structres=$StructRes"
fi
if [ -z "$Species" ]; then 
    Species="Human"
fi
if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi

if [ -n "${command_line_specified_sess}" ]; then
    Sesslist="${command_line_specified_sess}"
fi


#The following values are set in SetUpSPECIES.sh:
# Example for chimp:
# MyelinMappingFWHM="4" 
# SurfaceSmoothingFWHM="4" 
# CorrectionSigma=6
# SurfaceAtlasDIR="${HCPPIPEDIR_Templates}/standard_mesh_atlases_chimp"
# GrayordinatesSpaceDIR="${HCPPIPEDIR_Templates}/standard_mesh_atlases_chimp"
# ReferenceMyelinMaps="${HCPPIPEDIR_Templates}/standard_mesh_atlases_chimp/ChimpYerkes29.MyelinMap_BC.164k_fs_LR.dscalar.nii"
# LowResMeshes="32@20" #Needs to match what is in PostFreeSurfer
# FinalfMRIResolution="1.6" #Needs to match what is in fMRIVolume
# SmoothingFWHM="1.6" #Recommended to be roughly the voxel size
# GrayordinatesResolution="1.6" #should be either 1 (7T) or 2 (3T) for human.

source "$HCPPIPEDIR"/Examples/Scripts/SetUpSPECIES.sh --species="$Species" $StructResOption


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


for Session in $Sesslist ; do
    echo $Session

    #Input Variables
    #SurfaceAtlasDIR="${HCPPIPEDIR_Templates}/standard_mesh_atlases"
    #GrayordinatesSpaceDIR="${HCPPIPEDIR_Templates}/91282_Greyordinates"
    #GrayordinatesResolutions="2" #Usually 2mm, if multiple delimit with @, must already exist in templates dir
    HighResMesh="164" #Usually 164k vertices
    #LowResMeshes="32" #Usually 32k vertices, if multiple delimit with @, must already exist in templates dir
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
    job=("${queuing_command[@]}" "$HCPPIPEDIR"/PostFreeSurfer/PostFreeSurferPipeline.sh \
        --study-folder="$StudyFolder" \
        --session="$Session" \
        --surfatlasdir="$SurfaceAtlasDIR" \
        --grayordinatesdir="$GrayordinatesSpaceDIR" \
        --grayordinatesres="$GrayordinatesResolution" \
        --hiresmesh="$HighResMesh" \
        --lowresmesh="$LowResMeshes" \
        --subcortgraylabels="$SubcorticalGrayLabels" \
        --freesurferlabels="$FreeSurferLabels" \
        --refmyelinmaps="$ReferenceMyelinMaps" \
        --regname="$RegName" \
        --use-ind-mean="$UseIndMean"\
        --species="$Species"
        --mcsigma="$CorrectionSigma"
        --myelin-voume-fwhm="$MyelinMappingFWHM"
        --myelin-surface-fwhm="$SurfaceSmoothingFWHM"
        
        )
    
    "${job[@]}"

    # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...

    echo "set -- --study-folder=$StudyFolder \
        --session=$Session \
        --surfatlasdir=$SurfaceAtlasDIR \
        --grayordinatesdir=$GrayordinatesSpaceDIR \
        --grayordinatesres=$GrayordinatesResolutions \
        --hiresmesh=$HighResMesh \
        --lowresmesh=$LowResMeshes \
        --subcortgraylabels=$SubcorticalGrayLabels \
        --freesurferlabels=$FreeSurferLabels \
        --refmyelinmaps=$ReferenceMyelinMaps \
        --regname=$RegName \
        --use-ind-mean="$UseIndMean"" \
        --species="$Species"

    echo ". ${EnvironmentScript}"
done
