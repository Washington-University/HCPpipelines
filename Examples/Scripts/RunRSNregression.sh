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
            --Subject=*|--Subjlist=*)
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

###################################### DEFAULT PARAMETERS ######################################
# Command-line options override the corresponding defaults.
StudyFolder="${HOME}/projects/Pipelines_ExampleData" #Location of Subject folders (named by SubjectID) 
Subjlist="100307 100610" #Space delimited list of subject IDs 
EnvironmentScript="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script 


# Requirements for this script
#  installed versions of: FSL, Connectome Workbench (wb_command)
#  environment: HCPPIPEDIR, FSLDIR
source "$EnvironmentScript"


#NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
#DO NOT include "-q " at the beginning
#default to no queue, implying run local
QUEUE=""
#QUEUE="hcp_priority.q"


# Assign variables
GroupMaps="Path2File/GroupMap.dscalar.nii" #Absolute path to ICA or PFM cifti group map
VolumeTemplateCIFTI="" #Set path to cifti file to generate voxel-based outputs
fMRINames="rfMRI_REST1_RL@rfMRI_REST1_LR@rfMRI_REST2_LR@rfMRI_REST2_RL"
LowResMesh="32" # Cerebral-Cortex cortical mesh
RegName="MSMAll"
CortexProcString="_hp2000_clean_rclean_tclean"
CortexVNProcString="_hp2000_clean_rclean_tclean"
HippocampalOutput="YES" # Use "NO" if RunHippUnfoldHCP, PostHippUnfoldHCP, and GenericfMRISurfaceProcessingPipeline (with Hippocampus enabled) were not executed 
HippMesh="2k" # Future releases will enable alternative mesh resolutions. Leave empty if HippocampalOutput=NO.
HippProcString="_s2_hp2000_clean_rclean_tclean" #Leave empty if HippocampalOutput=NO.
HippVNProcString="_hp2000_clean_rclean_tclean" #Leave empty if HippocampalOutput=NO.
Method="weighted" #options are: dual. weighted, single, tICA_weighted
LowICADims="7@8@9@10@11@12@13@14@15@16@17@18@19@20@21" #Remove if method is dual or single
ICATemplateName="Path2File/rfMRI__PCA.ica_dREPLACEDIM_ROW_vn/melodic_oIC.dscalar.nii" #Remove if method is dual or single. REPLACEDIM is substitute for number of components in folder name (eg rfMRI__PCA.ica_d7_ROW_vn)
OutputSpectra="4800" # Set to 0 to omit spectra
FixLegacyBias="NO"
ScaleFactor="0.01"
WF="0"
DoZ="NO" #set to YES to generate Z stat and ZMM (mixture model Z stat) output files
MatlabMode="1"
OutString="OutputFileName" # Output file name
# Set VolumeTemplateCIFTI="" to omit additional volume outputs.

if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi
if [ -n "${command_line_specified_subj}" ]; then
    Subjlist="${command_line_specified_subj}"
fi

if [[ ! -f "$EnvironmentScript" ]]; then
    echo "ERROR: Environment script does not exist: $EnvironmentScript" >&2
    exit 1
fi

if [[ "$command_line_specified_run_local" == TRUE ]]; then
    RunLocal="TRUE"
else
    RunLocal="FALSE"
fi

case "${HippocampalOutput}" in
    YES|NO) ;;
    *) echo "ERROR: HippocampalOutput must be YES or NO"; exit 1 ;;
esac
case "${HippMesh}" in
    512|2k|8k|18k) ;;
    *) echo "ERROR: HippMesh must be 512, 2k, 8k, or 18k"; exit 1 ;;
esac 

# Log the originating call.
echo "$@"


########################################## INPUTS ##########################################

# Group maps remain the shared PFM template for every subject.
# Hippocampal inputs must match the filenames expected by RSNregression.sh.

######################################### DO WORK ##########################################
for Subject in $Subjlist ; do
    echo "    ${Subject}"

    if [[ "$RunLocal" == "TRUE" || "$QUEUE" == "" ]] ; then
        echo "About to locally run ${HCPPIPEDIR}/global/scripts/RSNregression.sh"
        queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
    else
        echo "About to use fsl_sub to queue ${HCPPIPEDIR}/global/scripts/RSNregression.sh"
        queuing_command=("${FSLDIR}/bin/fsl_sub" -q "$QUEUE")
    fi
    "${queuing_command[@]}" "$HCPPIPEDIR"/global/scripts/RSNregression.sh \
        --study-folder="$StudyFolder" \
        --subject="$Subject" \
        --group-maps="$GroupMaps" \
        --subject-timeseries="$fMRINames" \
        --surf-reg-name="$RegName" \
        --low-res="$LowResMesh" \
        --cortex-proc-string="$CortexProcString" \
        --hipp-proc-string="$HippProcString" \
        --cortex-vn-proc-string="$CortexVNProcString" \
        --hipp-vn-proc-string="$HippVNProcString" \
        --method="$Method" \
        --output-string="$OutString" \
        --output-spectra="$OutputSpectra" \
        --volume-template-cifti="$VolumeTemplateCIFTI" \
        --output-z="$DoZ" \
        --low-ica-dims="$LowICADims" \
        --low-ica-template-name="$ICATemplateName" \
        --fix-legacy-bias="$FixLegacyBias" \
        --scale-factor="$ScaleFactor" \
        --wf="$WF" \
        --matlab-run-mode="$MatlabMode" \
        --hippocampal-output="$HippocampalOutput" \
        --hippocampal-mesh="$HippMesh"
    
    # Interactive debugging setup, matching the Examples/Scripts wrappers.
    echo "set -- --study-folder=$StudyFolder --subject=$Subject --group-maps=$GroupMaps --subject-timeseries=$fMRINames --surf-reg-name=$RegName --low-res=$LowResMesh --cortex-proc-string=$CortexProcString --hipp-proc-string=$HippProcString --cortex-vn-proc-string=$CortexVNProcString --hipp-vn-proc-string=$HippVNProcString --method=$Method --output-string=$OutString --output-spectra=$OutputSpectra --volume-template-cifti=$VolumeTemplateCIFTI --output-z=$DoZ  --low-ica-dims="$LowICADims" --low-ica-template-name="$ICATemplateName" --fix-legacy-bias=$FixLegacyBias --scale-factor=$ScaleFactor --wf=$WF --matlab-run-mode=$MatlabMode --hippocampal-output=$HippocampalOutput --hippocampal-mesh=$HippMesh"
done

