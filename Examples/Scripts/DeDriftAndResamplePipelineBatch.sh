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

        case "$argument" in
            --StudyFolder=*)
                command_line_specified_study_folder=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --Subjlist=*)
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

EnvironmentScript="/media/myelin/brainmappers/Connectome_Project/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

#Set up pipeline environment variables and software
source "$EnvironmentScript"

# Requirements for this script
#  installed versions of: FSL, Connectome Workbench (wb_command)
#  environment: HCPPIPEDIR, FSLDIR, CARET7DIR 

# NOTE: this script will error on subjects that are missing some fMRI runs that are specified in the MR FIX arguments

########################################## INPUTS ########################################## 

#This example script is set up for a single subject from the CCF development project

######################################### DO WORK ##########################################

#Example of how CCF Development was run
StudyFolder="/media/myelin/brainmappers/Connectome_Project/CCF_HCD_STG" #Location of Subject folders (named by subjectID)
Subjlist=(HCD0001305_V1_MR HCD0008117_V1_MR) #List of subject IDs
#Don't edit things between here and MRFixConcatNames unless you know what you are doing
HighResMesh="164"
LowResMesh="32"
#Do not use RegName from MSMAllPipelineBatch.sh
RegName="MSMAll_InitalReg_2_d40_WRN"
DeDriftRegFiles="${HCPPIPEDIR}/global/templates/MSMAll/DeDriftingGroup.L.sphere.DeDriftMSMAll.164k_fs_LR.surf.gii@${HCPPIPEDIR}/global/templates/MSMAll/DeDriftingGroup.R.sphere.DeDriftMSMAll.164k_fs_LR.surf.gii"
ConcatRegName="MSMAll"
#standard maps to resample
Maps=(sulc curvature corrThickness thickness)
MyelinMaps=(MyelinMap SmoothedMyelinMap) #No _BC, this will be reapplied
#MRFixConcatNames and MRFixNames must exactly match the way MR FIX was run on the subjects
MRFixConcatNames=(fMRI_CONCAT_ALL)
#SPECIAL: if your data used two (or more) MR FIX runs (which is generally not recommended), specify them like this, with no whitespace before or after the %:
#MRFixConcatNames=(concat12 concat34)
#MRFixNames=(run1 run2%run3 run4)
MRFixNames=(rfMRI_REST1_AP rfMRI_REST1_PA tfMRI_GUESSING_PA tfMRI_GUESSING_AP tfMRI_CARIT_PA tfMRI_CARIT_AP tfMRI_EMOTION_PA rfMRI_REST2_AP rfMRI_REST2_PA)
#fixNames are for if single-run ICA FIX was used (not recommended)
fixNames=()
#dontFixNames are for runs that didn't have any kind of ICA artifact removal run on them (very not recommended)
dontFixNames=()
SmoothingFWHM="2" #Should equal previous grayordinates smoothing (because we are resampling from unsmoothed native mesh timeseries)
HighPass="0"
MotionRegression=FALSE
MatlabMode="0" #Mode=0 compiled Matlab, Mode=1 interpreted Matlab, Mode=2 octave

#Example of how older HCP-YA results were originally run
#These settings are no longer recommended - recommendations are to do MR FIX using all of a subject's runs, in the order they were acquired, no motion regression, HighPass 0
#StudyFolder="/media/myelin/brainmappers/Connectome_Project/YA_HCP_Final" #Location of Subject folders (named by subjectID)
#Subjlist=(100307 101006) #List of subject IDs
#HighResMesh="164"
#LowResMesh="32"
#RegName="MSMAll_InitalReg_2_d40_WRN"
#DeDriftRegFiles="${HCPPIPEDIR}/global/templates/MSMAll/DeDriftingGroup.L.sphere.DeDriftMSMAll.164k_fs_LR.surf.gii@${HCPPIPEDIR}/global/templates/MSMAll/DeDriftingGroup.R.sphere.DeDriftMSMAll.164k_fs_LR.surf.gii"
#ConcatRegName="MSMAll"
#Maps=(sulc curvature corrThickness thickness)
#MyelinMaps=(MyelinMap SmoothedMyelinMap) #No _BC, this will be reapplied
#MRFixConcatNames=()
#MRFixNames=()
#fixNames=(rfMRI_REST1_LR rfMRI_REST1_RL rfMRI_REST2_LR rfMRI_REST2_RL)
#dontFixNames=(tfMRI_EMOTION_LR tfMRI_EMOTION_RL tfMRI_GAMBLING_LR tfMRI_GAMBLING_RL tfMRI_LANGUAGE_LR tfMRI_LANGUAGE_RL tfMRI_MOTOR_LR tfMRI_MOTOR_RL tfMRI_RELATIONAL_LR tfMRI_RELATIONAL_RL tfMRI_SOCIAL_LR tfMRI_SOCIAL_RL tfMRI_WM_LR tfMRI_WM_RL)
#SmoothingFWHM="2" #Should equal previous grayordinates smoothing (because we are resampling from unsmoothed native mesh timeseries)
#HighPass="2000"
#MotionRegression=TRUE
#MatlabMode="0" #Mode=0 compiled Matlab, Mode=1 interpreted Matlab, Mode=2 octave

MSMAllTemplates="${HCPPIPEDIR}/global/templates/MSMAll"
MyelinTargetFile="${MSMAllTemplates}/Q1-Q6_RelatedParcellation210.MyelinMap_BC_MSMAll_2_d41_WRN_DeDrift.32k_fs_LR.dscalar.nii"

if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi

if [ -n "${command_line_specified_subj}" ]; then
    Subjlist="${command_line_specified_subj}"
fi

# Log the originating call
echo "$0" "$@"

#NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
#DO NOT include "-q " at the beginning
#default to no queue, implying run local
QUEUE=""
#QUEUE="hcp_priority.q"

Maps=$(IFS=@; echo "${Maps[*]}")
MyelinMaps=$(IFS=@; echo "${MyelinMaps[*]}")
MRFixConcatNames=$(IFS=@; echo "${MRFixConcatNames[*]}")
MRFixNames=$(IFS=@; echo "${MRFixNames[*]}")
fixNames=$(IFS=@; echo "${fixNames[*]}")
dontFixNames=$(IFS=@; echo "${dontFixNames[*]}")

for Subject in "${Subjlist[@]}" ; do
    echo "    ${Subject}"

    if [[ "${command_line_specified_run_local}" == "TRUE" || "$QUEUE" == "" ]] ; then
        echo "About to locally run ${HCPPIPEDIR}/DeDriftAndResample/DeDriftAndResamplePipeline.sh"
        queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
    else
        echo "About to use fsl_sub to queue ${HCPPIPEDIR}/DeDriftAndResample/DeDriftAndResamplePipeline.sh"
        queuing_command=("$FSLDIR"/bin/fsl_sub -q "$QUEUE")
    fi

    "${queuing_command[@]}" "$HCPPIPEDIR"/DeDriftAndResample/DeDriftAndResamplePipeline.sh \
        --path="$StudyFolder" \
        --subject="$Subject" \
        --high-res-mesh="$HighResMesh" \
        --low-res-meshes="$LowResMesh" \
        --registration-name="$RegName" \
        --dedrift-reg-files="$DeDriftRegFiles" \
        --concat-reg-name="$ConcatRegName" \
        --maps="$Maps" \
        --myelin-maps="$MyelinMaps" \
        --multirun-fix-concat-names="$MRFixConcatNames" \
        --multirun-fix-names="$MRFixNames" \
        --fix-names="$fixNames" \
        --dont-fix-names="$dontFixNames" \
        --smoothing-fwhm="$SmoothingFWHM" \
        --high-pass="$HighPass" \
        --matlab-run-mode="$MatlabMode" \
        --motion-regression="$MotionRegression" \
        --myelin-target-file="$MyelinTargetFile"
done

