#!/bin/bash 

get_batch_options() {
    local arguments=("$@")

    unset command_line_specified_study_folder
    unset command_line_specified_subj
    unset command_line_specified_run_local

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
Subjlist="100307" #Space delimited list of subject IDs
EnvironmentScript="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi

if [ -n "${command_line_specified_subj}" ]; then
    Subjlist="${command_line_specified_subj}"
fi

# Requirements for this script
#  installed versions of: FSL (version 5.0.6), FreeSurfer (version 5.3.0-HCP) , gradunwarp (HCP version 1.0.1)
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET7DIR , PATH (for gradient_unwarp.py)

#Set up pipeline environment variables and software
source ${EnvironmentScript}

# Log the originating call
echo "$@"

#if [ X$SGE_ROOT != X ] ; then
#    QUEUE="-q long.q"
    QUEUE="-q hcp_priority.q"
#fi

if [[ -n $HCPPIPEDEBUG ]]
then
    set -x
fi

PRINTCOM=""
#PRINTCOM="echo"
#QUEUE="-q veryshort.q"

########################################## INPUTS ########################################## 

# Scripts called by this script do NOT assume anything about the form of the input names or paths.
# This batch script assumes the HCP raw data naming convention.
#
# For example, if phase encoding directions are LR and RL, for tfMRI_EMOTION_LR and tfMRI_EMOTION_RL:
#
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_LR/${Subject}_3T_tfMRI_EMOTION_LR.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_LR/${Subject}_3T_tfMRI_EMOTION_LR_SBRef.nii.gz
#
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_RL/${Subject}_3T_tfMRI_EMOTION_RL.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_RL/${Subject}_3T_tfMRI_EMOTION_RL_SBRef.nii.gz
#
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_LR/${Subject}_3T_SpinEchoFieldMap_LR.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_LR/${Subject}_3T_SpinEchoFieldMap_RL.nii.gz
#
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_RL/${Subject}_3T_SpinEchoFieldMap_LR.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_RL/${Subject}_3T_SpinEchoFieldMap_RL.nii.gz
#
# If phase encoding directions are PA and AP:
#
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_PA/${Subject}_3T_tfMRI_EMOTION_PA.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_PA/${Subject}_3T_tfMRI_EMOTION_PA_SBRef.nii.gz
#
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_AP/${Subject}_3T_tfMRI_EMOTION_AP.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_AP/${Subject}_3T_tfMRI_EMOTION_AP_SBRef.nii.gz
#
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_PA/${Subject}_3T_SpinEchoFieldMap_PA.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_PA/${Subject}_3T_SpinEchoFieldMap_AP.nii.gz
#
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_AP/${Subject}_3T_SpinEchoFieldMap_PA.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_AP/${Subject}_3T_SpinEchoFieldMap_AP.nii.gz
#
#
# Change Scan Settings: Dwelltime, FieldMap Delta TE (if using), and $PhaseEncodinglist to match your images
# These are set to match the HCP Protocol by default
#
# If using gradient distortion correction, use the coefficents from your scanner
# The HCP gradient distortion coefficents are only available through Siemens
# Gradient distortion in standard scanners like the Trio is much less than for the HCP Skyra.
#
# To get accurate EPI distortion correction with TOPUP, the flags in PhaseEncodinglist must match the phase encoding
# direction of the EPI scan, and you must have used the correct images in SpinEchoPhaseEncodeNegative and Positive
# variables.  If the distortion is twice as bad as in the original images, flip either the order of the spin echo
# images or reverse the phase encoding list flag.  The pipeline expects you to have used the same phase encoding
# axis in the fMRI data as in the spin echo field map data (x/-x or y/-y).  

######################################### DO WORK ##########################################

# The PhaseEncodinglist contains phase encoding direction indicators for each corresponding
# task in the Tasklist.  Therefore, the Tasklist and the PhaseEncodinglist should have the
# same number of (space-delimited) elements.
Tasklist=""
PhaseEncodinglist=""

Tasklist="${Tasklist} rfMRI_REST1_RL"
PhaseEncodinglist="${PhaseEncodinglist} x"

Tasklist="${Tasklist} rfMRI_REST1_LR"
PhaseEncodinglist="${PhaseEncodinglist} x-"

Tasklist="${Tasklist} rfMRI_REST2_RL"
PhaseEncodinglist="${PhaseEncodinglist} x"

Tasklist="${Tasklist} rfMRI_REST2_LR"
PhaseEncodinglist="${PhaseEncodinglist} x-"

Tasklist="${Tasklist} tfMRI_EMOTION_RL"
PhaseEncodinglist="${PhaseEncodinglist} x"

Tasklist="${Tasklist} tfMRI_EMOTION_LR"
PhaseEncodinglist="${PhaseEncodinglist} x-"

Tasklist="${Tasklist} tfMRI_GAMBLING_RL"
PhaseEncodinglist="${PhaseEncodinglist} x"

Tasklist="${Tasklist} tfMRI_GAMBLING_LR"
PhaseEncodinglist="${PhaseEncodinglist} x-"

Tasklist="${Tasklist} tfMRI_LANGUAGE_RL"
PhaseEncodinglist="${PhaseEncodinglist} x"

Tasklist="${Tasklist} tfMRI_LANGUAGE_LR"
PhaseEncodinglist="${PhaseEncodinglist} x-"

Tasklist="${Tasklist} tfMRI_MOTOR_RL"
PhaseEncodinglist="${PhaseEncodinglist} x"

Tasklist="${Tasklist} tfMRI_MOTOR_LR"
PhaseEncodinglist="${PhaseEncodinglist} x-"

Tasklist="${Tasklist} tfMRI_RELATIONAL_RL"
PhaseEncodinglist="${PhaseEncodinglist} x"

Tasklist="${Tasklist} tfMRI_RELATIONAL_LR"
PhaseEncodinglist="${PhaseEncodinglist} x-"

Tasklist="${Tasklist} tfMRI_SOCIAL_RL"
PhaseEncodinglist="${PhaseEncodinglist} x"

Tasklist="${Tasklist} tfMRI_SOCIAL_LR"
PhaseEncodinglist="${PhaseEncodinglist} x-"

Tasklist="${Tasklist} tfMRI_WM_RL"
PhaseEncodinglist="${PhaseEncodinglist} x"

Tasklist="${Tasklist} tfMRI_WM_LR"
PhaseEncodinglist="${PhaseEncodinglist} x-"

# Verify that Tasklist and PhaseEncodinglist have the same number of elements
TaskArray=($Tasklist)
PhaseEncodingArray=($PhaseEncodinglist)

nTaskArray=${#TaskArray[@]}
nPhaseEncodingArray=${#PhaseEncodingArray[@]}

if [ "${nTaskArray}" -ne "${nPhaseEncodingArray}" ] ; then
    echo "Tasklist and PhaseEncodinglist do not have the same number of elements."
    echo "Exiting without processing"
    exit 1
fi

# Start or launch pipeline processing for each subject
for Subject in $Subjlist ; do
  echo $Subject

  i=1
  for fMRIName in $Tasklist ; do
    echo "  ${fMRIName}"
    UnwarpDir=`echo $PhaseEncodinglist | cut -d " " -f $i`
    fMRITimeSeries="${StudyFolder}/${Subject}/unprocessed/3T/${fMRIName}/${Subject}_3T_${fMRIName}.nii.gz"
    fMRISBRef="${StudyFolder}/${Subject}/unprocessed/3T/${fMRIName}/${Subject}_3T_${fMRIName}_SBRef.nii.gz" #A single band reference image (SBRef) is recommended if using multiband, set to NONE if you want to use the first volume of the timeseries for motion correction
    DwellTime="0.00058" #Echo Spacing or Dwelltime of fMRI image, set to NONE if not used. Dwelltime = 1/(BandwidthPerPixelPhaseEncode * # of phase encoding samples): DICOM field (0019,1028) = BandwidthPerPixelPhaseEncode, DICOM field (0051,100b) AcquisitionMatrixText first value (# of phase encoding samples).  On Siemens, iPAT/GRAPPA factors have already been accounted for.   
    DistortionCorrection="TOPUP" # FIELDMAP, SiemensFieldMap, GeneralElectricFieldMap, or TOPUP: distortion correction is required for accurate processing
    BiasCorrection="SEBASED" #NONE, LEGACY, or SEBASED: LEGACY uses the T1w bias field, SEBASED calculates bias field from spin echo images (which requires TOPUP distortion correction)
    SpinEchoPhaseEncodeNegative="${StudyFolder}/${Subject}/unprocessed/3T/${fMRIName}/${Subject}_3T_SpinEchoFieldMap_LR.nii.gz" #For the spin echo field map volume with a negative phase encoding direction (LR in HCP data, AP in 7T HCP data), set to NONE if using regular FIELDMAP
    SpinEchoPhaseEncodePositive="${StudyFolder}/${Subject}/unprocessed/3T/${fMRIName}/${Subject}_3T_SpinEchoFieldMap_RL.nii.gz" #For the spin echo field map volume with a positive phase encoding direction (RL in HCP data, PA in 7T HCP data), set to NONE if using regular FIELDMAP
    MagnitudeInputName="NONE" #Expects 4D Magnitude volume with two 3D timepoints, set to NONE if using TOPUP
    PhaseInputName="NONE" #Expects a 3D Phase volume, set to NONE if using TOPUP

    # Path to General Electric style B0 fieldmap with two volumes
    #   1. field map in degrees
    #   2. magnitude
    # Set to "NONE" if not using "GeneralElectricFieldMap" as the value for the DistortionCorrection variable
    #
    # Example Value: 
    #  GEB0InputName="${StudyFolder}/${Subject}/unprocessed/3T/${fMRIName}/${Subject}_3T_GradientEchoFieldMap.nii.gz" 
    GEB0InputName="NONE"

    DeltaTE="NONE" #2.46ms for 3T, 1.02ms for 7T, set to NONE if using TOPUP
    FinalFMRIResolution="2" #Target final resolution of fMRI data. 2mm is recommended for 3T HCP data, 1.6mm for 7T HCP data (i.e. should match acquired resolution).  Use 2.0 or 1.0 to avoid standard FSL templates
    # GradientDistortionCoeffs="${HCPPIPEDIR_Config}/coeff_SC72C_Skyra.grad" #Gradient distortion correction coefficents, set to NONE to turn off
    GradientDistortionCoeffs="NONE" # Set to NONE to skip gradient distortion correction
    TopUpConfig="${HCPPIPEDIR_Config}/b02b0.cnf" #Topup config if using TOPUP, set to NONE if using regular FIELDMAP

    # Use mcflirt motion correction
    MCType="MCFLIRT"
		
    if [ -n "${command_line_specified_run_local}" ] ; then
        echo "About to run ${HCPPIPEDIR}/fMRIVolume/GenericfMRIVolumeProcessingPipeline.sh"
        queuing_command=""
    else
        echo "About to use fsl_sub to queue or run ${HCPPIPEDIR}/fMRIVolume/GenericfMRIVolumeProcessingPipeline.sh"
        queuing_command="${FSLDIR}/bin/fsl_sub ${QUEUE}"
    fi

    ${queuing_command} ${HCPPIPEDIR}/fMRIVolume/GenericfMRIVolumeProcessingPipeline.sh \
      --path=$StudyFolder \
      --subject=$Subject \
      --fmriname=$fMRIName \
      --fmritcs=$fMRITimeSeries \
      --fmriscout=$fMRISBRef \
      --SEPhaseNeg=$SpinEchoPhaseEncodeNegative \
      --SEPhasePos=$SpinEchoPhaseEncodePositive \
      --fmapmag=$MagnitudeInputName \
      --fmapphase=$PhaseInputName \
      --fmapgeneralelectric=$GEB0InputName \
      --echospacing=$DwellTime \
      --echodiff=$DeltaTE \
      --unwarpdir=$UnwarpDir \
      --fmrires=$FinalFMRIResolution \
      --dcmethod=$DistortionCorrection \
      --gdcoeffs=$GradientDistortionCoeffs \
      --topupconfig=$TopUpConfig \
      --printcom=$PRINTCOM \
      --biascorrection=$BiasCorrection \
      --mctype=${MCType}

  # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...

  echo "set -- --path=$StudyFolder \
      --subject=$Subject \
      --fmriname=$fMRIName \
      --fmritcs=$fMRITimeSeries \
      --fmriscout=$fMRISBRef \
      --SEPhaseNeg=$SpinEchoPhaseEncodeNegative \
      --SEPhasePos=$SpinEchoPhaseEncodePositive \
      --fmapmag=$MagnitudeInputName \
      --fmapphase=$PhaseInputName \
      --fmapgeneralelectric=$GEB0InputName \
      --echospacing=$DwellTime \
      --echodiff=$DeltaTE \
      --unwarpdir=$UnwarpDir \
      --fmrires=$FinalFMRIResolution \
      --dcmethod=$DistortionCorrection \
      --gdcoeffs=$GradientDistortionCoeffs \
      --topupconfig=$TopUpConfig \
      --printcom=$PRINTCOM \
      --biascorrection=$BiasCorrection \
      --mctype=${MCType}"

  echo ". ${EnvironmentScript}"
	
    i=$(($i+1))
  done
done


