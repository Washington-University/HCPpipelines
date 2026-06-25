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
            --Species=*)
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
Subjlist="Macaque1 Macaque2" #Space delimited list of subject IDs
EnvironmentScript="${HOME}/projects/HCPPipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script
Species="MacaqueRhesus"
#StructRes is mandatory
StructRes="0.5"

if [ -z "$Species" ]; then 
    Species="MacaqueRhesus"
fi
if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi

if [ -n "${command_line_specified_subj}" ]; then
    Subjlist="${command_line_specified_subj}"
fi

#Set up pipeline environment variables and software
source "$EnvironmentScript"

source "$HCPPIPEDIR"/Examples/Scripts/SetUpSPECIES.sh --species="$Species" --structres="$StructRes"

#The following values are set in SetUpSPECIES.sh:
# Example for MacaqueRhesus:
# MyelinMappingFWHM="3" 
# SurfaceSmoothingFWHM="2" 
# CorrectionSigma=5
# SurfaceAtlasDIR="${HCPPIPEDIR_Templates}/NHP_NNP/Mac25Rhesus/standard_mesh_atlases"
# GrayordinatesSpaceDIR="${HCPPIPEDIR_Templates}/NHP_NNP/Mac25Rhesus/standard_mesh_atlases"
# ReferenceMyelinMaps="${HCPPIPEDIR_Templates}/NHP_NNP/Mac25Rhesus/standard_mesh_atlases/Mac25Rhesus_v5.Partial.MyelinMap_GroupCorr.164k_fs_LR.dscalar.nii"
# LowResMeshes="32@10" 
# FinalfMRIResolution="1.2" #Needs to match what is in fMRIVolume
# SmoothingFWHM="1.2" #Recommended to be roughly the voxel size
# GrayordinatesResolution="1.2"  


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

#Scripts called by this script do assume they run on the outputs of the FreeSurfer Pipeline

######################################### DO WORK ##########################################


for Subject in $Subjlist ; do
    echo $Subject

    #Input Variables    
    #SurfaceAtlasDIR="${HCPPIPEDIR_Templates}/NHP_NNP/Mac25Rhesus/standard_mesh_atlases"
    #GrayordinatesSpaceDIR="${HCPPIPEDIR_Templates}/NHP_NNP/Mac25Rhesus/standard_mesh_atlases"
    #GrayordinatesResolutions="1.2" #Usually 1.2mm, if multiple delimit with @, must already exist in templates dir
    HighResMesh="164" #Usually 164k vertices
    #LowResMeshes="32" #Usually 32k vertices, if multiple delimit with @, must already exist in templates dir

    # These are values for MacaqueRhesus from SetUpSpecies.sh:
    # CorrectionSigma=5
    # MyelinMappingFWHM=3
    # SurfaceSmoothingFWHM=2
    # MSMSulcConf=MSMSulcStrainFinalconfMacaque
    # FlatMapRootName=Mac25Rhesus

    SubcorticalGrayLabels="${HCPPIPEDIR_Config}/FreeSurferSubcorticalLabelTableLut.txt"
    FreeSurferLabels="${HCPPIPEDIR_Config}/FreeSurferAllLut.txt"
    #ReferenceMyelinMaps="${HCPPIPEDIR_Templates}/NHP_NNP/Mac25Rhesus/standard_mesh_atlases/Mac25Rhesus_v5.Partial.MyelinMap_GroupCorr.164k_fs_LR.dscalar.nii"
    RegName="MSMSulc" #MSMSulc is recommended, if binary is not available use FS (FreeSurfer)
    UseIndMean="YES"
    if [[ "${command_line_specified_run_local}" == "TRUE" || "$QUEUE" == "" ]] ; then
        echo "About to locally run ${HCPPIPEDIR}/PostFreeSurfer/PostFreeSurferPipeline.sh"
        queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
    else
        echo "About to use fsl_sub to queue ${HCPPIPEDIR}/PostFreeSurfer/PostFreeSurferPipeline.sh"
        queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE")
    fi
    args=(
        --study-folder="$StudyFolder"
        --subject="$Subject"
        --surfatlasdir="$SurfaceAtlasDIR"
        --grayordinatesdir="$GrayordinatesSpaceDIR"
        --grayordinatesres="$GrayordinatesResolution"
        --hiresmesh="$HighResMesh"
        --lowresmesh="$LowResMeshes"
        --subcortgraylabels="$SubcorticalGrayLabels"
        --freesurferlabels="$FreeSurferLabels"
        --refmyelinmaps="$ReferenceMyelinMaps"
        --regname="$RegName"
        --use-ind-mean="$UseIndMean"
        --species="$Species"
        --mcsigma="$CorrectionSigma"
        --myelin-volume-fwhm="$MyelinMappingFWHM"
        --myelin-surface-fwhm="$SurfaceSmoothingFWHM"
        --msmsulc-conf="$MSMSulcConf"
        --flatmap-root-name="$FlatMapRootName"
        
        )

    job=("${queuing_command[@]}" "$HCPPIPEDIR"/PostFreeSurfer/PostFreeSurferPipeline.sh "${args[@]}")
    "${job[@]}"

    # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...
    echo "set -- ${args[*]}"

    echo ". ${EnvironmentScript}"
done
