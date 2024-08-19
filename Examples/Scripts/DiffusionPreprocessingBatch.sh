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
#  installed versions of: FSL, FreeSurfer, Connectome Workbench (wb_command), gradunwarp (HCP version)
#  environment: HCPPIPEDIR, FSLDIR, FREESURFER_HOME, CARET7DIR, PATH for gradient_unwarp.py

#Set up pipeline environment variables and software
source "$EnvironmentScript"

# Log the originating call
echo "$@"

#Assume that submission nodes have OPENMP enabled (needed for eddy - at least 8 cores suggested for HCP data)
#NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
#DO NOT include "-q " at the beginning
#default to no queue, implying run local
QUEUE=""
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

#	${StudyFolder}/${Subject}/unprocessed/3T/Diffusion/${SubjectID}_3T_DWI_dir95_RL.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/Diffusion/${SubjectID}_3T_DWI_dir96_RL.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/Diffusion/${SubjectID}_3T_DWI_dir97_RL.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/Diffusion/${SubjectID}_3T_DWI_dir95_LR.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/Diffusion/${SubjectID}_3T_DWI_dir96_LR.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/Diffusion/${SubjectID}_3T_DWI_dir97_LR.nii.gz

#Change Scan Settings: Echo Spacing and PEDir to match your images
#These are set to match the HCP Protocol by default

#If using gradient distortion correction, use the coefficents from your scanner
#The HCP gradient distortion coefficents are only available through Siemens
#Gradient distortion in standard scanners like the Trio is much less than for the HCP Skyra.

######################################### DO WORK ##########################################

for Subject in $Subjlist ; do
  echo $Subject

  #Input Variables
  SubjectID="$Subject" #Subject ID Name
  RawDataDir="$StudyFolder/$SubjectID/unprocessed/3T/Diffusion" #Folder where unprocessed diffusion data are

  # PosData is a list of files (separated by ‘@‘ symbol) having the same phase encoding (PE) direction 
  # and polarity. Similarly for NegData, which must have the opposite PE polarity of PosData.
  # The PosData files will come first in the merged data file that forms the input to ‘eddy’.
  # The particular PE polarity assigned to PosData/NegData is not relevant; the distortion and eddy 
  # current correction will be accurate either way.
  #
  # NOTE that PosData defines the reference space in 'topup' and 'eddy' AND it is assumed that
  # each scan series begins with a b=0 acquisition, so that the reference space in both
  # 'topup' and 'eddy' will be defined by the same (initial b=0) volume.
  #
  # On Siemens scanners, we typically use 'R>>L' ("RL") as the 'positive' direction for left-right
  # PE data, and 'P>>A' ("PA") as the 'positive' direction for anterior-posterior PE data.
  # And conversely, "LR" and "AP" are then the 'negative' direction data.
  # However, see preceding comment that PosData defines the reference space; so if you want the
  # first temporally acquired volume to define the reference space, then that series needs to be
  # the first listed series in PosData.
  #
  # Note that only volumes (gradient directions) that have matched Pos/Neg pairs are ultimately
  # propagated to the final output, *and* these pairs will be averaged to yield a single
  # volume per pair. This reduces file size by 2x (and thence speeds subsequent processing) and
  # avoids having volumes with different SNR features/ residual distortions.
  # [This behavior can be changed through the hard-coded 'CombineDataFlag' variable in the 
  # DiffPreprocPipeline_PostEddy.sh script if necessary].
  
  PosData="${RawDataDir}/${SubjectID}_3T_DWI_dir95_RL.nii.gz@${RawDataDir}/${SubjectID}_3T_DWI_dir96_RL.nii.gz@${RawDataDir}/${SubjectID}_3T_DWI_dir97_RL.nii.gz"
  NegData="${RawDataDir}/${SubjectID}_3T_DWI_dir95_LR.nii.gz@${RawDataDir}/${SubjectID}_3T_DWI_dir96_LR.nii.gz@${RawDataDir}/${SubjectID}_3T_DWI_dir97_LR.nii.gz"
  
  # "Effective" Echo Spacing of dMRI image (now specified in seconds for the dMRI processing)
  # EchoSpacing = 1/(BWPPPE * ReconMatrixPE)
  #   where BWPPPE is the "BandwidthPerPixelPhaseEncode" = DICOM field (0019,1028) for Siemens, and
  #   ReconMatrixPE = size of the reconstructed image in the PE dimension
  # In-plane acceleration, phase oversampling, phase resolution, phase field-of-view, and interpolation
  # all potentially need to be accounted for (which they are in Siemen's reported BWPPPE)
  EchoSpacingSec=0.00078
  
  PEdir=1 #Use 1 for Left-Right Phase Encoding, 2 for Anterior-Posterior

  # Gradient distortion correction
  # Set to NONE to skip gradient distortion correction
  # (These files are considered proprietary and therefore not provided as part of the HCP Pipelines -- contact Siemens to obtain)
  # Gdcoeffs="${HCPPIPEDIR_Config}/coeff_SC72C_Skyra.grad"
  Gdcoeffs="NONE"

  if [[ "${command_line_specified_run_local}" == "TRUE" || "$QUEUE" == "" ]] ; then
      echo "About to locally run ${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline.sh"
      queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
  else
      echo "About to use fsl_sub to queue ${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline.sh"
      queuing_command=("${FSLDIR}/bin/fsl_sub" -q "$QUEUE")
  fi

  "${queuing_command[@]}" "${HCPPIPEDIR}"/DiffusionPreprocessing/DiffPreprocPipeline.sh \
      --posData="${PosData}" --negData="${NegData}" \
      --path="${StudyFolder}" --subject="${SubjectID}" \
      --echospacing-seconds="${EchoSpacingSec}" --PEdir="${PEdir}" \
      --gdcoeffs="${Gdcoeffs}" \
      --printcom="$PRINTCOM"

done

