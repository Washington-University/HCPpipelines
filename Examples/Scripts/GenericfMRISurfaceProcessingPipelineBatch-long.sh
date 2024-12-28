#!/bin/bash 

StudyFolder="<MyStudyFolder>"
#The list of subject labels, space separated
Subjects=(HCA6002236)
PossibleVisits=(V1_MR V2_MR V3_MR)
ExcludeVisits=()
Templates=(HCA6002236_V1_V2_V3)

EnvironmentScript="<hcp-pipelines-folder>/scripts/SetUpHCPPipeline.sh" #Pipeline environment script

# Requirements for this script
#  installed versions of: FSL, Connectome Workbench (wb_command)
#  environment: HCPPIPEDIR, FSLDIR, CARET7DIR

#Set up pipeline environment variables and software
source "$EnvironmentScript"

# Log the originating call
echo "$@"

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

#NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
#DO NOT include "-q " at the beginning
#default to no queue, implying run local
QUEUE="long.q"
#QUEUE="hcp_priority.q"

########################################## INPUTS ##########################################

#Scripts called by this script do assume they run on the outputs of the FreeSurfer Pipeline

######################################### DO WORK ##########################################

TaskList=()
TaskList+=(rfMRI_REST1_AP)
TaskList+=(rfMRI_REST1_PA)
TaskList+=(rfMRI_REST2_AP)
TaskList+=(rfMRI_REST2_PA)
TaskList+=(tfMRI_FACENAME_PA)
TaskList+=(tfMRI_VISMOTOR_PA)
TaskList+=(tfMRI_CARIT_PA)

for i in "${!Subjects[@]}"; do
	Subject="${Subjects[i]}"
	TemplateLong="${Templates[i]}"
	Timepoint_list_cross_at_separated=$(identify_timepoints "$Subject")
	IFS=@ read -r -a Timepoint_list_cross <<< "${Timepoint_list_cross_at_separated}"
	echo Subject: $Subject
	
	for TimepointCross in "${Timepoint_list_cross[@]}"; do
		TimepointLong=${TimepointCross}.long.${TemplateLong}
		echo "TimepointLong: $TimepointLong"
		
		for fMRIName in "${TaskList[@]}" ; do
			echo "  ${fMRIName}"
			LowResMesh="32" #Needs to match what is in PostFreeSurfer, 32 is on average 2mm spacing between the vertices on the midthickness
			FinalfMRIResolution="2" #Needs to match what is in fMRIVolume, i.e. 2mm for 3T HCP data and 1.6mm for 7T HCP data
			SmoothingFWHM="2" #Recommended to be roughly the grayordinates spacing, i.e 2mm on HCP data 
			GrayordinatesResolution="2" #Needs to match what is in PostFreeSurfer. 2mm gives the HCP standard grayordinates space with 91282 grayordinates.  Can be different from the FinalfMRIResolution (e.g. in the case of HCP 7T data at 1.6mm)
			RegName="MSMSulc" #MSMSulc is recommended, if binary is not available use FS (FreeSurfer)

			if [[ "${command_line_specified_run_local}" == "TRUE" || "$QUEUE" == "" ]] ; then
				echo "About to locally run ${HCPPIPEDIR}/fMRISurface/GenericfMRISurfaceProcessingPipeline.sh"
				queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
			else
				echo "About to use fsl_sub to queue ${HCPPIPEDIR}/fMRISurface/GenericfMRISurfaceProcessingPipeline.sh"
				queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE")
			fi

			"${queuing_command[@]}" "$HCPPIPEDIR"/fMRISurface/GenericfMRISurfaceProcessingPipeline.sh \
				--path="$StudyFolder" \
				--session="$TimepointLong" \
				--fmriname="$fMRIName" \
				--lowresmesh="$LowResMesh" \
				--fmrires="$FinalfMRIResolution" \
				--smoothingFWHM="$SmoothingFWHM" \
				--grayordinatesres="$GrayordinatesResolution" \
				--regname="$RegName"

			# The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...

			echo "set -- --path=$StudyFolder \
				--session=$TimepointLong \
				--fmriname=$fMRIName \
				--lowresmesh=$LowResMesh \
				--fmrires=$FinalfMRIResolution \
				--smoothingFWHM=$SmoothingFWHM \
				--grayordinatesres=$GrayordinatesResolution \
				--regname=$RegName"

			echo ". ${EnvironmentScript}"
		done
	done
done
