#!/bin/bash 

StudyFolder="${HOME}/projects/HCPpipelines_ExampleData" #Location of Subject folders (named by subjectID)
Subjects=(HCA6002236) #list of subject IDs
PossibleVisits=(V1_MR V2_MR V3_MR)
ExcludeVisits=()
Templates=(HCA6002236_V1_V2_V3)

EnvironmentScript="${HOME}/projects/HCPpipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

# Requirements for this script
#  installed versions of: FSL, FreeSurfer, Connectome Workbench (wb_command), gradunwarp (HCP version)
#  environment: HCPPIPEDIR, FSLDIR, FREESURFER_HOME, CARET7DIR, PATH for gradient_unwarp.py

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

#Assume that submission nodes have OPENMP enabled (needed for eddy - at least 8 cores suggested for HCP data)
#NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
#DO NOT include "-q " at the beginning
#default to no queue, implying run local
QUEUE="long.q"
#QUEUE="hcp_priority.q"

#specify PRINTCOM="echo" to echo commands the pipeline would run, instead of running them
#this appears to be fully implemented in the diffusion pipeline
PRINTCOM=""
#PRINTCOM="echo"

########################################## INPUTS ########################################## 

#Scripts called by this script do assume they run on the outputs of the PreFreeSurfer Pipeline,
#which is a prerequisite for this pipeline

#Scripts called by this script do NOT assume anything about the form of the input names or paths.
#This batch script assumes the HCP raw data naming convention, e.g.

#	${StudyFolder}/${Subject}/unprocessed/3T/Diffusion/${SessionID}_3T_DWI_dir95_RL.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/Diffusion/${SessionID}_3T_DWI_dir96_RL.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/Diffusion/${SessionID}_3T_DWI_dir97_RL.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/Diffusion/${SessionID}_3T_DWI_dir95_LR.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/Diffusion/${SessionID}_3T_DWI_dir96_LR.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/Diffusion/${SessionID}_3T_DWI_dir97_LR.nii.gz

#If using gradient distortion correction, use the coefficents from your scanner
#The HCP gradient distortion coefficents are only available through Siemens
#Gradient distortion in standard scanners like the Trio is much less than for the HCP Skyra.

######################################### DO WORK ##########################################
for i in "${!Subjects[@]}"; do
	Subject="${Subjects[i]}"
	echo $Subject
	TemplateLong="${Templates[i]}"
	Timepoint_list_cross_at_separated=$(identify_timepoints "$Subject")
	IFS=@ read -r -a Timepoint_list_cross <<< "${Timepoint_list_cross_at_separated}"
	echo "${SCRIPT_NAME}: Processing Subject: ${Subject}"
	
	for TimepointCross in "${Timepoint_list_cross[@]}"; do		
		TimepointLong=${TimepointCross}.long.${TemplateLong}
		echo "Processing Timepoint: ${TimepointLong}"
	    #Input Variables
	    RawDataDir="$StudyFolder/$TimepointCross/unprocessed/Diffusion" #Folder where unprocessed diffusion data are

	    # Gradient distortion correction
	    # Set to NONE to skip gradient distortion correction
	    # (These files are considered proprietary and therefore not provided as part of the HCP Pipelines -- contact Siemens to obtain)
	    # Gdcoeffs="${HCPPIPEDIR_Config}/coeff_SC72C_Skyra.grad"
	    Gdcoeffs="NONE"

	    if [[ "$QUEUE" == "" ]] ; then
		    echo "About to locally run ${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline.sh"
  		    queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
	    else
		    echo "About to use fsl_sub to queue ${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline.sh"
		    queuing_command=("${FSLDIR}/bin/fsl_sub" -q "$QUEUE")
	    fi

	    "${queuing_command[@]}" "${HCPPIPEDIR}"/DiffusionPreprocessing/DiffPreprocPipeline.sh \
		  --path="${StudyFolder}" --session="${TimepointCross}" \
		  --gdcoeffs="${Gdcoeffs}" \
		  --is-longitudinal=TRUE \
		  --longitudinal-session="$TimepointLong" \
  		  --printcom="$PRINTCOM"		  
	done
done
