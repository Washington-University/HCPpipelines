#!/bin/bash 

get_batch_options() {
    local arguments=("$@")

    command_line_specified_study_folder=""
    command_line_specified_subj=""
    command_line_specified_run_local="FALSE"
    command_line_specified_Tasklist=""
    command_line_specified_SpecSessionlist=""

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
            --Tasklist=*)
                command_line_specified_Tasklist=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --SpecSessionlist=*)
                command_line_specified_SpecSessionlist=${argument#*=}
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
StudyFolder="${HOME}/projects/NHP_Data"
# Space delimited list of subject IDs
Subjlist="SubjectA"

# Pipeline environment script
EnvironmentScript="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi

if [ -n "${command_line_specified_subj}" ]; then
    Subjlist="${command_line_specified_subj}"
fi

if [ -n "${command_line_specified_Tasklist}" ]; then
    Tasklist="${command_line_specified_Tasklist}"
fi

# Species label (Macaque, MacaqueCyno, MacaqueRhesus, Marmoset, NightMonkey, Chimp, Human)
Species="Macaque"

# Requirements for this script
#  installed versions of: FSL, Connectome Workbench (wb_command)
#  environment: HCPPIPEDIR, FSLDIR, CARET7DIR

#Structural resolution, a mandatory option for SetUpSPECIES.sh
StructRes=0.5

#Set up pipeline environment variables and software
source "$EnvironmentScript"

source "$HCPPIPEDIR"/Examples/Scripts/SetUpSPECIES.sh --species="$Species" --structres="$StructRes"

# The following variables from the SetUpSpecies.sh are used:
# LowResMeshes
# finalfMRIResolution
# SmoothingFWHM
# GrayordinatesResolution

if [[ $LowResMeshes != "" ]] ; then
  LowResMesh=$(echo $LowResMeshes | sed -e 's/@/ /g' | awk '{print $NF}')
else
  echo "ERROR: cannot find LowResMeshes"
  exit 1;
fi

RegName=MSMSulc

# Log the originating call
echo "$@"

#default to no queue, implying run local
#QUEUE=""
QUEUE="long.q"

if [[ "${command_line_specified_run_local}" == "TRUE" || "$QUEUE" == "" ]] ; then
    echo "About to locally run ${HCPPIPEDIR}/fMRISurface/GenericfMRISurfaceProcessingPipeline.sh"
    queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
else
    echo "About to use fsl_sub to queue ${HCPPIPEDIR}/fMRISurface/GenericfMRISurfaceProcessingPipeline.sh"
    queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE")
fi

########################################## INPUTS ########################################## 

# Scripts called by this script do assume they run on the outputs of the 
# GenericfMRIVolumeProcessingPipeline

######################################### DO WORK ##########################################

for Subject in $Subjlist ; do
    echo $Subject
    # The following variables from the hcppipe_conf.txt are used:
    # Tasklist
    # SpecSessionlist

    if [ -z "$Tasklist" ]; then 
        if [ -e ${StudyFolder}/${Subject}/RawData/hcppipe_conf.txt ] ; then
        source ${StudyFolder}/${Subject}/RawData/hcppipe_conf.txt
        else
            echo "Cannot find hcppipe_conf.txt in ${Subject}/RawData";
            echo "Exiting without processing.";
            exit 1;
        fi
    fi

    # command-line SpecSessionlist overrides what is in hcppipe_conf.txt
    if [ -n "${command_line_specified_SpecSessionlist}" ]; then
        SpecSessionlist="${command_line_specified_SpecSessionlist}"
    fi

    OrigTasklist=$(echo $Tasklist | sed -e 's/^@//g' | sed -e 's/@$//g')

    if [ ! -z $SpecSessionlist ] ; then
        Sessionlist=$(echo $SpecSessionlist | sed -e 's/,/ /g')
    else
        nsession=$(echo $OrigTasklist | awk -F"@" '{print NF}')
        Sessionlist=$(seq 1 $nsession);
    fi

    for session in $Sessionlist ; do
        if [ "$(echo $OrigTasklist | grep @)" != "" ] ; then
            Tasklist=$(echo $OrigTasklist | cut -d '@' -f $session)
        fi

        for fMRIName in $Tasklist ; do
            fMRIName=$(basename $(remove_ext $fMRIName))

            "${queuing_command[@]}" "$HCPPIPEDIR"/fMRISurface/GenericfMRISurfaceProcessingPipeline.sh \
                --path=$StudyFolder \
                --subject=$Subject \
                --fmriname=$fMRIName \
                --lowresmesh=$LowResMesh \
                --fmrires=$FinalfMRIResolution \
                --smoothingFWHM=$SmoothingFWHM \
                --grayordinatesres=$GrayordinatesResolution \
                --regname=$RegName

            # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...
            echo "set -- --path=$StudyFolder \
                --subject=$Subject \
                --fmriname=$fMRIName \
                --lowresmesh=$LowResMesh \
                --fmrires=$FinalfMRIResolution \
                --smoothingFWHM=$SmoothingFWHM \
                --grayordinatesres=$GrayordinatesResolution \
                --regname=$RegName"

            echo ". ${EnvironmentScript}"
        done #for fMRIName
    done #for session
done #for Subject
