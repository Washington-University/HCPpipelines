#!/bin/bash 

# Requirements for this script
#  installed versions of: FSL, FreeSurfer, gradunwarp (HCP version) 
#  environment: HCPPIPEDIR, FSLDIR, FREESURFER_HOME, HCPPIPEDIR_Global, PATH for gradient_unwarp.py


########################################## OUTPUT DIRECTORIES ########################################## 

# TODO

########################################## SUPPORT FUNCTIONS ##########################################

# ---------------------------------------------------------------------------
#  Constants for specification of susceptibility distortion Correction Method
# ---------------------------------------------------------------------------

set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@" 
source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "${HCPPIPEDIR}/global/scripts/processingmodecheck.shlib"  # Check processing mode requirements
source "${HCPPIPEDIR}/global/scripts/fsl_version.shlib"          # Functions for getting FSL version
g_matlab_default_mode=1

FIELDMAP_METHOD_OPT="FIELDMAP"
SIEMENS_METHOD_OPT="SiemensFieldMap"
# For GE HealthCare Fieldmap Distortion Correction methods 
# see explanations in global/scripts/FieldMapPreprocessingAll.sh
GE_HEALTHCARE_LEGACY_METHOD_OPT="GEHealthCareLegacyFieldMap" 
GE_HEALTHCARE_METHOD_OPT="GEHealthCareFieldMap"
PHILIPS_METHOD_OPT="PhilipsFieldMap"
SPIN_ECHO_METHOD_OPT="TOPUP"
NONE_METHOD_OPT="NONE"

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------
opts_SetScriptDescription "Run fMRIVolume processing"

opts_AddMandatory '--studyfolder' 'Path' 'path' "folder containing all subject" "--path"

opts_AddMandatory '--subject' 'Subject' 'subject ID' ""

opts_AddMandatory '--fmritcs' 'fMRITimeSeries' 'file' 'input fMRI time series (NIFTI)'

opts_AddMandatory '--fmriname' 'NameOffMRI' 'string' 'name (prefix) to use for the output'

opts_AddMandatory '--fmrires' 'FinalfMRIResolution' 'number' 'final resolution (mm) of the output data'

opts_AddMandatory '--biascorrection' 'BiasCorrection' 'method' "Method for receive bias correction, accepted values are:

SEBASED: use bias field derived from spin echo images, must also use --dcmethod='${SPIN_ECHO_METHOD_OPT}'

LEGACY: use the bias field derived from T1w and T2w images, same as was used in pipeline version 3.14.1 or older (No longer recommended) 

NONE: don't do bias correction"

opts_AddOptional '--fmriscout' 'fMRIScout' 'volume' "Used as the target for motion correction and for BBR registration to the structurals.  In HCP-Style acquisitions, the 'SBRef' (single-band reference) volume associated with a run is   typically used as the 'scout'. Default: 'NONE' (in which case the first volume of the time-series is extracted and used as the 'scout')  It must have identical dimensions, voxel resolution, and distortions (i.e., phase-encoding   polarity and echo-spacing) as the input fMRI time series" "NONE"

opts_AddOptional '--mctype' 'MotionCorrectionType' 'MCFLIRT OR FLIRT' "What type of motion correction to use MCFLIRT or FLIRT, Default is MCFLIRT" "MCFLIRT"

opts_AddMandatory '--gdcoeffs' 'GradientDistortionCoeffs' 'file' "Set to 'NONE' to skip gradient non-linearity distortion correction (GDC)."

opts_AddMandatory '--dcmethod' 'DistortionCorrection' 'method' "Which method to use for susceptibility distortion correction (SDC):

        '${FIELDMAP_METHOD_OPT}'
            equivalent to '${SIEMENS_METHOD_OPT}' (see below)

        '${SIEMENS_METHOD_OPT}'
             use Siemens specific Gradient Echo Field Maps for SDC

        '${SPIN_ECHO_METHOD_OPT}'
             use a pair of Spin Echo EPI images ('Spin Echo Field Maps') acquired with
             opposing polarity for SDC

        '${GE_HEALTHCARE_LEGACY_METHOD_OPT}'
             use GE HealthCare Legacy specific Gradient Echo Field Maps for SDC (field map in Hz and magnitude iimage n a single NIfTI file via, --fmapcombined argument).
             This option is maintained for backward compatibility.

        '${GE_HEALTHCARE_METHOD_OPT}'
             use GE HealthCare specific Gradient Echo Field Maps for SDC (field map in Hz and magnitude image in two separate NIfTI files, via --fmapphase and --fmapmag).

        '${PHILIPS_METHOD_OPT}'
             use Philips specific Gradient Echo Field Maps for SDC

        '${NONE_METHOD_OPT}'
             do not use any SDC
             NOTE: Only valid when Pipeline is called with --processing-mode='LegacyStyleData'"

opts_AddOptional '--echospacing' 'EchoSpacing' 'number' "effective echo spacing of fMRI input or  in seconds"

opts_AddOptional '--unwarpdir' 'UnwarpDir' '{x,y,z,x-,y-,z-} or {i,j,k,i-,j-,k-}' "PE direction for unwarping according to the *voxel* axes, Polarity matters!  If your distortions are twice as bad as in the original images, try using the opposite polarity for --unwarpdir."

opts_AddOptional '--SEPhaseNeg' 'SpinEchoPhaseEncodeNegative' 'file' "negative polarity SE-EPI image"

opts_AddOptional '--SEPhasePos' 'SpinEchoPhaseEncodePositive' 'file' "positive polarity SE-EPI image"

opts_AddOptional '--topupconfig' 'TopupConfig' 'file' "Which topup config file to use"

opts_AddOptional '--fmapmag' 'MagnitudeInputName' 'file' "field map magnitude image"

opts_AddOptional '--fmapphase' 'PhaseInputName' 'file' "fieldmap phase images in radians (Siemens/Philips) or in Hz (GE HealthCare)"

opts_AddOptional '--echodiff' 'deltaTE' 'milliseconds' "Difference of echo times for fieldmap, in milliseconds"

opts_AddOptional '--fmapcombined' 'GEB0InputName' 'file' "GE HealthCare Legacy field map only (two volumes: 1. field map in Hz and 2. magnitude image)" '' '--fmap'

# OTHER OPTIONS:

opts_AddOptional '--dof' 'dof' '6 OR 9 OR 12' "Degrees of freedom for the EPI to T1 registration: 6 (default) or 9 or or 12" "6"

opts_AddOptional '--usejacobian' 'UseJacobian' 'TRUE OR FALSE' "Controls whether the jacobian of the *distortion corrections* (GDC and SDC) are applied to the output data.  (The jacobian of the nonlinear T1 to template (MNI152) registration is NOT applied, regardless of value). Default: 'TRUE' if using --dcmethod='${SPIN_ECHO_METHOD_OPT}'; 'FALSE' for all other SDC methods."

opts_AddOptional '--processing-mode' 'ProcessingMode' 'HCPStyleData or LegacyStyleData' "Controls whether the HCP acquisition and processing guidelines should be treated as requirements.  'HCPStyleData' (the default) follows the processing steps described in Glasser et al. (2013)   and requires 'HCP-Style' data acquistion.   'LegacyStyleData' allows additional processing functionality and use of some acquisitions  that do not conform to 'HCP-Style' expectations.  In this script, it allows not having a high-resolution T2w image." "HCPStyleData"

opts_AddOptional '--wb-resample' 'useWbResample' 'true/false' "Use wb command to do volume resampling instead of applywarp, requires wb_command version newer than 1.5.0" "0"

opts_AddOptional '--echoTE' 'echoTE' '@ delimited list of numbers' "TE for each echo (unused for single echo)" "0"

opts_AddOptional '--matlab-run-mode' 'MatlabMode' '0 (compiled), 1 (interpreted), or 2 (Octave)' "defaults to $g_matlab_default_mode" "$g_matlab_default_mode"

# -------- "LegacyStyleData" MODE OPTIONS --------

#  Use --processing-mode-info to see important additional information and warnings about the use of 
#  the following options!

opts_AddOptional '--preregistertool' 'PreregisterTool' 'epi_reg or flirt' "Specifies which software tool to use to preregister the fMRI to T1w image (prior to the final FreeSurfer BBR registration). 'epi_reg' is default, whereas 'flirt' might give better results with some legacy type data (e.g., single band, low resolution)." "epi_reg"

opts_AddOptional '--doslicetime' 'DoSliceTimeCorrection' 'FALSE or TRUE' "Specifies whether slice timing correction should be run on the fMRI input. If set to 'TRUE' FSLs 'slicetimer' is run before motion correction. Please run with --processing-mode-info flag for additional information on the issues relevant for --doslicetime." "FALSE"

opts_AddOptional '--slicetimerparams' 'SliceTimerCorrectionParameters' 'param@param...' "Enables passing additional parameters to FSL's 'slicetimer' if --doslicetime='TRUE'. The parameters to pass should be provided as a '@' separated string, e.g.:  --slicetimerparams='--odd@--ocustom=<CustomInterleaveFile>' For details about valid parameters please consult FSL's 'slicetimer' documentation." 

opts_AddOptional '--fmrimask' 'fMRIMask' 'file' "Specifies the type of final mask to apply to the volumetric fMRI data. Valid options are: 'T1_fMRI_FOV' (default) - T1w brain based mask combined with fMRI FOV mask
'T1_DILATED_fMRI_FOV' - once dilated T1w brain based mask combined with fMRI FOV
'T1_DILATED2x_fMRI_FOV' - twice dilated T1w brain based mask combined with fMRI FOV
'fMRI_FOV' - fMRI FOV mask only (i.e., voxels having spatial coverage at all time points)
Note that mask is used in IntensityNormalization.sh, so the mask type affects the final results." "T1_fMRI_FOV"

opts_AddOptional '--fmriref' 'fMRIReference' 'folder' "Specifies whether to use another (already processed) fMRI run as a reference for processing. (i.e., --fmriname from the run to be used as *reference*). The specified run will be used as a reference for motion correction and its distortion correction and atlas (MNI152) registration will be copied over and used. The reference fMRI has to have been fully processed using the fMRIVolume pipeline, so that a distortion correction and atlas (MNI152) registration solution for the reference fMRI already exists. The reference fMRI must have been acquired using the same imaging parameters (e.g., phase encoding polarity and echo spacing), or it can not serve as a valid reference. (NO checking is performed to verify this). WARNING: This option excludes the use of the --fmriscout option, as the scout from the specified reference fMRI run is used instead. Please run with --processing-mode-info flag for additional information on the issues related to the use of --fmriref." "NONE" 

opts_AddOptional '--fmrirefreg' 'fMRIReferenceReg' 'linear or nonlinear' "Specifies whether to compute and apply a nonlinear transform to align the inputfMRI to the reference fMRI, if one is specified using --fmriref. The nonlinear transform is computed using 'fnirt' following the motion correction using the mean motion corrected fMRI image." "linear"

# opts_AddOptional '--printcom' 'RUN' 'print-command' "DO NOT USE THIS! IT IS NOT IMPLEMENTED!"
# Disable RUN
RUN=""

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

opts_ShowValues

script_name=$(basename "$0")

show_processing_mode_info() {
  cat <<EOF

Processing mode additional information
--------------------------------------

HCPpipelines were designed to provide state-of-the-art processing of MR datasets. To achieve 
optimal results HCPpipelines expects the data to conform to a set of requirements such as the 
presence of high resolution T1w and T2w images and an appropriate set of images (i.e., field map 
images) that enable performing susceptibility distortion correction (SDC). In addition 
HCPpipelines expect the data to be of sufficiently high quality to ensure best results, e.g., 
multiband high-resolution fMRI images with short TR for which slice timing correction is
not necessary.

Many datasets do not meet the requirements and expectations of HCPpipelines, either because
they are older and have been acquired using imaging protocols and sequences that are considered 
outdated (e.g., single-band low-resolution, long TR fMRI images, no high-resolution T2w image), 
or the specifics of the study or the equipment used does not allow optimal data collection.
In these cases, the HCPpipelines can not ensure the standard of quality enabled by 
the use of appropriate data -- nonetheless, a need to process these datasets to the best 
possible extent is acknowledged. 

To enable processing of datasets that do not meet HCPpipelines reqirements and expectations,
HCPpipelines offers a set of parameters and parameter choices that either extend the 
processing options (e.g., enable slice timing correction) or allow processing despite
missing data, which is required for ensuring optimal results (e.g., no T2w or field map images).
To clearly distinguish between processing that meets HCPpipelines requirements and 
expectations and processing of suboptimal data that does not meet HCP standards, these options
are only enabled when legacy processing mode is explicitly turned on by setting
--processing-mode="LegacyStyleData". 

The following paragraphs describe the specific considerations when using the "LegacyStyleData" 
processing options associated with ${script_name}.

Slice timing correction:
--doslicetime enables slice timing correction in the cases of fMRI images with longer TR. 
If turned on, slice timing correction is performed before motion correction and thus implicitly 
assumes that the brain is motionless. Errors in temporal interpolation will occur in the presence
of head motion and may also disrupt data quality measures as shown in Power et al (2017, PLOS One, 
"Temporal interpolation alters motion in fMRI scans: Magnitudes and consequences for artifact 
detection"). Slice timing correction and motion correction would ideally be performed 
simultaneously; however, this is not currently supported by any major software tool. HCP-Style 
fast TR fMRI data acquisitions (TR<=1s) avoid the need for slice timing correction, provide 
major advantages for fMRI denoising, and are recommended. 

Use of expanded fMRI masks:
As the final step in processing of fMRI data, the data is intensity normalized. This is 
optimally done when only the brain voxels are taken into account and the regions outside of
the brain are masked out. When working with legacy data, e.g., when no field map images are 
available to support SDC, fMRI data might not be fully contained within the brain mask 
generated from the T1w image. To identify such issues in quality control or to enable full use 
of the data in analysis of volume data, the --fmrimask parameter allows widening the T1w mask 
(T1_DILATED_fMRI_FOV, T1_DILATED2x_fMRI_FOV) or extending the mask to the complete available 
field of view (fMRI_FOV, i.e., voxels having spatial coverage at all time points). 
Do consider that these options will impact intensity normalization.

Use of a reference fMRI run:
In the cases of low-resolution fMRI images, registering the input fMRI images directly to
another fMRI run and using a common SDC and translation to atlas space can lead to better 
between-run fMRI registration, compared to performing both independently for each fMRI run. 
This is enabled using the --fmriref parameter. Note that using this parameter requires the 
reference fMRI to be acquired using the same parameters (e.g., phase encoding polarity and
echo spacing) and already processed. Also note that the use of this parameter is 
incompatible with the use of the --fmriscout parameter as the scout from the reference image 
is used instead.

Nonlinear registration to reference fMRI run:
In cases when the input fMRI images are registered to a reference fMRI and there is significant
movement between the two scanning runs, it can be beneficial to perform nonlinear registration 
(using 'fnirt') to the reference fMRI image. 
In this case --fmrirefreg can be set to "nonlinear"; otherwise a linear registration is used.

No available SDC method:
When no field map images are available and therefore no SDC method can be used to correct
the distortion, --dcmethod can be set to "NONE". In this case fMRIVolume pipeline is run without 
appropriate distortion correction of the fMRI images. This is NOT RECOMMENDED under normal 
circumstances. The pipeline will attempt 6 DOF FreeSurfer BBR registration of the distorted 
fMRI to the T1w image. Distorted portions of the fMRI data will not align with the cortical ribbon.
In HCP data 30% of the cortical surface will be misaligned by at least half cortical thickness 
and 10% of the cortical surface will be completely misaligned by a full cortical thickness. 
At a future time, we may be able to add support for fieldmap-less distortion correction. 
At this time, however, despite ongoing efforts, this problem is unsolved and no extant approach 
has been successfully shown to demonstrate clear improvement according to the accuracy standards
of HCP-Style data analysis when compared to gold-standard fieldmap-based correction.

EOF
}

"$HCPPIPEDIR"/show_version

# ------------------------------------------------------------------------------
#  Verify required environment variables are set and log value
# ------------------------------------------------------------------------------

log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FSLDIR
log_Check_Env_Var FREESURFER_HOME
log_Check_Env_Var HCPPIPEDIR_Global

HCPPIPEDIR_fMRIVol=${HCPPIPEDIR}/fMRIVolume/scripts

# ------------------------------------------------------------------------------
#  Check for incompatible FSL version - abort if incompatible
# ------------------------------------------------------------------------------

fsl_minimum_required_version_check "6.0.1" "FSL version 6.0.0 is unsupported. Please upgrade to at least version 6.0.1"


case "$MatlabMode" in
    (0)
        if [[ "${MATLAB_COMPILER_RUNTIME:-}" == "" ]]
        then
            log_Err_Abort "To use compiled matlab, you must set and export the variable MATLAB_COMPILER_RUNTIME"
        fi
        ;;
    (1)
        matlab_interpreter=(matlab -nodisplay -nosplash)
        ;;
    (2)
        matlab_interpreter=(octave-cli -q --no-window-system)
        ;;
    (*)
        log_Err_Abort "unrecognized matlab mode '$MatlabMode', use 0, 1, or 2"
        ;;
esac

## Case checking for which distortion correction was used ## 

case "$DistortionCorrection" in
    ${SPIN_ECHO_METHOD_OPT})
        if [ -z ${SpinEchoPhaseEncodeNegative} ]; then
            log_Err_Abort "--SEPhaseNeg must be specified with --dcmethod=${DistortionCorrection}"
        fi
        if [ -z ${SpinEchoPhaseEncodePositive} ]; then
            log_Err_Abort "--SEPhasePos must be specified with --dcmethod=${DistortionCorrection}"
        fi
        if [ -z ${TopupConfig} ]; then
            log_Err_Abort "--topupconfig must be specified with --dcmethod=${DistortionCorrection}"
        fi
        ;;

    ${FIELDMAP_METHOD_OPT}|${SIEMENS_METHOD_OPT})
        if [ -z ${MagnitudeInputName} ]; then
            log_Err_Abort "--fmapmag must be specified with --dcmethod=${DistortionCorrection}"
        fi
        if [ -z ${PhaseInputName} ]; then
            log_Err_Abort "--fmapphase must be specified with --dcmethod=${DistortionCorrection}"
        fi
        if [ -z ${deltaTE} ]; then
            log_Err_Abort "--echodiff must be specified with --dcmethod=${DistortionCorrection}"
        fi
        ;;

    ${GE_HEALTHCARE_LEGACY_METHOD_OPT})
        if [ -z ${GEB0InputName} ]; then
            log_Err_Abort "--fmapcombined must be specified with --dcmethod=${DistortionCorrection}"
        fi
        if [ -z ${deltaTE} ]; then
            log_Err_Abort "--echodiff must be specified with --dcmethod=${DistortionCorrection}"
        fi
        # Check that FSL is at least the minimum required FSL version, abort if needed (and log FSL-version)
        # This FSL version check is duplicated in global/scripts/FieldMapPreprocessingAll.sh
        # The intention is to catch the error as early as possible. 
        # GEHEALTHCARE_MINIMUM_FSL_VERSION defined in global/scripts/fsl_version.shlib
        fsl_minimum_required_version_check "$GEHEALTHCARE_MINIMUM_FSL_VERSION" \
            "For ${DistortionCorrection} method the minimum required FSL version is ${GEHEALTHCARE_MINIMUM_FSL_VERSION}. " 
        ;;
  
  ${GE_HEALTHCARE_METHOD_OPT})
        if [ -z ${MagnitudeInputName} ]; then
            log_Err_Abort "--fmapmag must be specified with --dcmethod=${DistortionCorrection}"
        fi
        if [ -z ${PhaseInputName} ]; then
            log_Err_Abort "--fmapphase must be specified with --dcmethod=${DistortionCorrection}"
        fi
        if [ -z ${deltaTE} ]; then
            log_Err_Abort "--echodiff must be specified with --dcmethod=${DistortionCorrection}"
        fi
        # Check that FSL is at least the minimum required FSL version, abort if needed (and log FSL-version)
        # This FSL version check is duplicated in global/scripts/FieldMapPreprocessingAll.sh
        # The intention is to catch the error as early as possible. 
        # GEHEALTHCARE_MINIMUM_FSL_VERSION defined in global/scripts/fsl_version.shlib
        fsl_minimum_required_version_check "$GEHEALTHCARE_MINIMUM_FSL_VERSION" \
            "For ${DistortionCorrection} method the minimum required FSL version is ${GEHEALTHCARE_MINIMUM_FSL_VERSION}. "
        ;;

    ${PHILIPS_METHOD_OPT})
        if [ -z ${MagnitudeInputName} ]; then
            log_Err_Abort "--fmapmag must be specified with --dcmethod=${DistortionCorrection}"
        fi
        if [ -z ${PhaseInputName} ]; then
            log_Err_Abort "--fmapphase must be specified with --dcmethod=${DistortionCorrection}"
        fi
        if [ -z ${deltaTE} ]; then
            log_Err_Abort "--echodiff must be specified with --dcmethod=${DistortionCorrection}"
        fi
        ;;

    ${NONE_METHOD_OPT})
        # Do nothing
        ;;

    *)
        log_Err_Abort "unrecognized value for --dcmethod (${DistortionCorrection})"
        ;;

esac
# Additionally, EchoSpacing and UnwarpDir needed for all except NONE
if [[ $DistortionCorrection != "${NONE_METHOD_OPT}" ]]; then
    if [ -z ${EchoSpacing} ]; then
        log_Err_Abort "--echospacing must be specified with --dcmethod=${DistortionCorrection}"
    fi
    if [ -z ${UnwarpDir} ]; then
        log_Err_Abort "--unwarpdir must be specified with --dcmethod=${DistortionCorrection}"
    fi
fi


# Convert BiasCorrection value to all UPPERCASE (to allow the user the flexibility to use NONE, None, none, legacy, Legacy, etc.)
BiasCorrection="$(echo ${BiasCorrection} | tr '[:lower:]' '[:upper:]')"
log_Msg "BiasCorrection: ${BiasCorrection}"

case "$MotionCorrectionType" in 
    MCFLIRT|FLIRT)
        log_Msg "MotionCorrectionType: ${MotionCorrectionType}"
    ;; 
    *)
        log_Err_Abort "--mctype must be 'MCFLIRT' (default) or 'FLIRT'"
    ;;
esac

if [ -z ${GradientDistortionCoeffs} ]; then
  log_Err_Abort "--gdcoeffs must be specified"
fi

#NOTE: the jacobian option only applies the jacobian of the distortion corrections to the fMRI data, and NOT from the nonlinear T1 to template registration


# Convert UseJacobian value to all lowercase (to allow the user the flexibility to use True, true, TRUE, False, False, false, etc.)
UseJacobian="$(echo ${UseJacobian} | tr '[:upper:]' '[:lower:]')"

JacobianDefault="true"
if [[ $DistortionCorrection != "${SPIN_ECHO_METHOD_OPT}" ]]
then
    #because the measured fieldmap can cause the warpfield to fold over, default to doing nothing about any jacobians
    JacobianDefault="false"
    #warn if the user specified it
    if [[ $UseJacobian == "true" ]]
    then
        log_Msg "WARNING: using --jacobian=true with --dcmethod other than ${SPIN_ECHO_METHOD_OPT} is not recommended, as the distortion warpfield is less stable than ${SPIN_ECHO_METHOD_OPT}"
    fi
fi

if [[ "$UseJacobian" == "" ]]
then
    UseJacobian="$JacobianDefault"
fi

#sanity check the jacobian option
if [[ "$UseJacobian" != "true" && "$UseJacobian" != "false" ]]
then
    log_Err_Abort "the --usejacobian option must be 'true' or 'false'"
fi


if [[ "$RUN" != "" ]]
then
    log_Err_Abort "--printcom is not consistently implemented, do not rely on it"
fi
log_Msg "RUN: ${RUN}"

# Setup PATHS
GlobalScripts=${HCPPIPEDIR_Global}
PipelineScripts=${HCPPIPEDIR_fMRIVol}

# #Naming Conventions
T1wImage="T1w_acpc_dc"
T1wRestoreImage="T1w_acpc_dc_restore"
T1wRestoreImageBrain="T1w_acpc_dc_restore_brain"
T1wFolder="T1w" #Location of T1w images
AtlasSpaceFolder="MNINonLinear"
ResultsFolder="Results"
BiasField="BiasField_acpc_dc"
BiasFieldMNI="BiasField"
T1wAtlasName="T1w_restore"
MovementRegressor="Movement_Regressors" #No extension, .txt appended
MotionMatrixFolder="MotionMatrices"
MotionMatrixPrefix="MAT_"
FieldMapOutputName="FieldMap"
MagnitudeOutputName="Magnitude"
MagnitudeBrainOutputName="Magnitude_brain"
ScoutName="Scout"
OrigScoutName="${ScoutName}_orig"
OrigTCSName="${NameOffMRI}_orig"
FreeSurferBrainMask="brainmask_fs"
fMRI2strOutputTransform="${NameOffMRI}2str"
RegOutput="Scout2T1w"
AtlasTransform="acpc_dc2standard"
OutputfMRI2StandardTransform="${NameOffMRI}2standard"
Standard2OutputfMRITransform="standard2${NameOffMRI}"
QAImage="T1wMulEPI"
JacobianOut="Jacobian"
SubjectFolder="$Path"/"$Subject"

#note, this file doesn't exist yet, gets created by ComputeSpinEchoBiasField.sh during DistortionCorrectionAnd...
sebasedBiasFieldMNI="$SubjectFolder/$AtlasSpaceFolder/Results/$NameOffMRI/${NameOffMRI}_sebased_bias.nii.gz"

fMRIFolder="$Path"/"$Subject"/"$NameOffMRI"

# Set UseBiasFieldMNI variable, and error check BiasCorrection variable
# (needs to go after "Naming Conventions" rather than the the initial argument parsing)
case "$BiasCorrection" in
    NONE)
        UseBiasFieldMNI=""
        ;;
    LEGACY)
        UseBiasFieldMNI="${fMRIFolder}/${BiasFieldMNI}.${FinalfMRIResolution}"
        ;;    
    SEBASED)
        if [[ "$DistortionCorrection" != "${SPIN_ECHO_METHOD_OPT}" ]]
        then
            log_Err_Abort "--biascorrection=SEBASED is only available with --dcmethod=${SPIN_ECHO_METHOD_OPT}"
        fi
        UseBiasFieldMNI="$sebasedBiasFieldMNI"
        ;;
    "")
        log_Err_Abort "--biascorrection option not specified"
        ;;
    *)
        log_Err_Abort "unrecognized value for bias correction: $BiasCorrection"
        ;;
esac

# ------------------------------------------------------------------------------
#  Compliance check of Legacy Style Data options
# ------------------------------------------------------------------------------

Compliance="HCPStyleData"
ComplianceMsg=""
ComplianceWarn=""

# -- No distortion correction method

if [ "${DistortionCorrection}" = 'NONE' ]; then
  ComplianceMsg+=" --dcmethod=NONE"
  Compliance="LegacyStyleData"
  log_Warn "The fMRIVolume pipeline is being run without appropriate distortion correction"
  log_Warn "  of the fMRI images. This is NOT RECOMMENDED under normal circumstances. We will "
  log_Warn "  attempt 6 DOF FreeSurfer BBR registration of the distorted fMRI to the T1w image."
  log_Warn "  Distorted portions of the fMRI data will not align with the cortical ribbon."
  log_Warn "  In HCP data 30% of the cortical surface will be misaligned by at least half cortical "
  log_Warn "  thickness and 10% of the cortical surface will be completely misaligned by a full "
  log_Warn "  cortical thickness. At a future time, we may be able to add support for fieldmap-less "
  log_Warn "  distortion correction. At this time, however, despite ongoing efforts, this problem is"
  log_Warn "  unsolved and no extant approach has been successfully shown to demonstrate clear "
  log_Warn "  improvement according to the accuracy standards of HCP-Style data analysis when compared"
  log_Warn "  to gold-standard fieldmap-based correction."
fi

# -- Slice timing correction

if [ "${DoSliceTimeCorrection}" = 'TRUE' ]; then
  ComplianceMsg+=" --doslicetime=TRUE --slicetimerparams=${SliceTimerCorrectionParameters}"
  Compliance="LegacyStyleData"
  log_Warn "This LegacyStyleData option of slice timing correction is performed before motion correction "
  log_Warn "   and thus assumes that the brain is motionless. Errors in temporal interpolation will occur in the presence"
  log_Warn "   of head motion and may also disrupt data quality measures as shown in Power et al 2017 PLOS One 'Temporal "
  log_Warn "   interpolation alters motion in fMRI scans: Magnitudes and consequences for artifact detection.' Slice timing"
  log_Warn "   correction and motion correction would ideally be performed simultaneously; however, this is not currently "
  log_Warn "   supported by any major software tool. HCP-Style fast TR fMRI data acquisitions (TR<=1s) avoid the need for "
  log_Warn "   slice timing correction, provide major advantages for fMRI denoising, and are recommended. "
  log_Warn "   No slice timing correction is done by default"
fi

# -- Use of nonstandard fMRI mask

if [ "${fMRIMask}" != 'T1_fMRI_FOV' ]; then
  if [ "${fMRIMask}" != "T1_DILATED_fMRI_FOV" ] && [ "${fMRIMask}" != "T1_DILATED2x_fMRI_FOV" ] && [ "${fMRIMask}" != "fMRI_FOV" ] ; then
    log_Err_Abort "--fmrimask=${fMRIMask} is invalid! Valid options are: T1_fMRI_FOV (default), T1_DILATED_fMRI_FOV, T1_DILATED2x_fMRI_FOV, fMRI_FOV."
  fi
  ComplianceMsg+=" --fmrimask=${fMRIMask}"
  Compliance="LegacyStyleData"
fi

# -- Use of external fMRI reference

if [ "$fMRIReference" = "NONE" ]; then
  fMRIReferenceReg="NONE"    
  fMRIReferencePath="NONE"
  ReferenceResultsFolder="NONE"
else
  # --fmriref and --fmriscout are mutally exclusive
  if [ $fMRIScout != "NONE" ] ; then
    log_Err_Abort "Both fMRI Reference (--fmriref=${fMRIReference}) and fMRI Scout (--fmriscout=${fMRIScout}) were specified! The two options are mutually exclusive."
  fi

  # set reference and check if external reference (if one is specified) exists 

  fMRIReferencePath="$Path"/"$Subject"/"$fMRIReference"
  log_Msg "Using reference image from ${fMRIReferencePath}"
  fMRIReferenceImage="$fMRIReferencePath"/"$ScoutName"_gdc
  fMRIReferenceImageMask="$fMRIReferencePath"/"$ScoutName"_gdc_mask
  ReferenceResultsFolder="$Path"/"$Subject"/"$AtlasSpaceFolder"/"$ResultsFolder"/"$fMRIReference"

  if [ "$fMRIReferencePath" = "$fMRIFolder" ] ; then
    log_Err_Abort "Specified fMRI reference (--fmriref=${fMRIReference}) is the same as the current fMRI (--fmriname=${NameOffMRI})!"
  fi

  if [ $(${FSLDIR}/bin/imtest ${fMRIReferenceImage}) -eq 0 ] ; then
    log_Err_Abort "Intended fMRI Reference does not exist (${fMRIReferenceImage})!"
  fi 

  if [ $(${FSLDIR}/bin/imtest ${fMRIReferenceImageMask}) -eq 0 ] ; then
    log_Err_Abort "Intended fMRI Reference mask does not exist (${fMRIReferenceImageMask})!"
  fi 

  if [ ! -d "$ReferenceResultsFolder" ] ; then
    log_Err_Abort "Reference results folder does not exist and can not be used (${ReferenceResultsFolder})!"
  fi 

  # print warning

  log_Warn "You are using an external reference (--fmriref=${fMRIReference}) for motion registration and"
  log_Warn "  distortion correction and registration to T1w image. Please consider using this option only"
  log_Warn "  in cases when only one scout ('SBRef') image is available or when processing low spatial"
  log_Warn "  resolution legacy fMRI images (for which between fMRI registration might be more robust"
  log_Warn "  than independent registration to structural images). Please make sure that the reference fMRI"
  log_Warn "  (--fmriref=${fMRIReference}) and the current fMRI (--fmriname=${NameOffMRI}) were acquired "
  log_Warn "  using the same acquisition parameters, e.g., phase encoding polarity and echo spacing."
fi

# -- Use of nonlinear registration to external fMRI reference

if [ "${fMRIReferenceReg}" = "nonlinear" ] ; then
  ComplianceMsg+=" --fmrirefreg=${fMRIReferenceReg}"
  Compliance="LegacyStyleData"
fi

if [[ "$ProcessingMode" != "HCPStyleData" || "$Compliance" != "HCPStyleData" ]]
then
    log_Warn "Pipeline is being run with non-HCP-style options, please read the following:"
    show_processing_mode_info
fi

check_mode_compliance "${ProcessingMode}" "${Compliance}" "${ComplianceMsg}"

# -- Multi-echo fMRI
echoTE=$(echo ${echoTE} | sed 's/@/ /g')
nEcho=$(echo ${echoTE} | wc -w)

# -- Slice time correction for multiecho scans
if [[ $DoSliceTimeCorrection = "TRUE" ]] && [[ $nEcho -gt 1 ]] ; then
    log_Err_Abort "Slice time correction for multiecho scans is not supported."
fi

# ------------------------------------------------------------------------------
#  End Compliance check
# ------------------------------------------------------------------------------


########################################## DO WORK ########################################## 

T1wFolder="$Path"/"$Subject"/"$T1wFolder"
AtlasSpaceFolder="$Path"/"$Subject"/"$AtlasSpaceFolder"
ResultsFolder="$AtlasSpaceFolder"/"$ResultsFolder"/"$NameOffMRI"

mkdir -p ${T1wFolder}/Results/${NameOffMRI}

if [ ! -e "$fMRIFolder" ] ; then
    log_Msg "mkdir ${fMRIFolder}"
    mkdir "$fMRIFolder"
fi
${FSLDIR}/bin/imcp "$fMRITimeSeries" "$fMRIFolder"/"$OrigTCSName"


if [[ $nEcho -gt 1 ]] ; then
    log_Msg "$nEcho TE's supplied, running in multi-echo mode"
    NumFrames=$("${FSLDIR}"/bin/fslval "${fMRIFolder}/${OrigTCSName}" dim4)
    FramesPerEcho=$((NumFrames / nEcho))
    EchoDir="${fMRIFolder}/MultiEcho"
    mkdir -p "$EchoDir"
fi


# --- Do slice time correction if indicated
# Note that in the case of STC, $fMRIFolder/$OrigTCSName will NOT be the "original" time-series
# but rather the slice-time corrected version thereof.

if [ $DoSliceTimeCorrection = "TRUE" ] ; then
    log_Msg "Running slice timing correction using FSL's 'slicetimer' tool ..."
    log_Msg "... $fMRIFolder/$OrigTCSName will be a slice-time-corrected version of the original data"
    TR=$(${FSLDIR}/bin/fslval "$fMRIFolder"/"$OrigTCSName" pixdim4)
    log_Msg "TR: ${TR}"

    IFS='@' read -a SliceTimerCorrectionParametersArray <<< "$SliceTimerCorrectionParameters"
    ${FSLDIR}/bin/immv "$fMRIFolder"/"$OrigTCSName" "$fMRIFolder"/"$OrigTCSName"_prestc
    ${FSLDIR}/bin/slicetimer -i "$fMRIFolder"/"$OrigTCSName"_prestc -o "$fMRIFolder"/"$OrigTCSName" -r ${TR} -v "${SliceTimerCorrectionParametersArray[@]}"
    ${FSLDIR}/bin/imrm "$fMRIFolder"/"$OrigTCSName"_prestc
fi

# --- Copy over scout (own or reference if specified), create fake if none exists

if [ "$fMRIReference" != "NONE" ]; then
    # --- copy over existing scout images
    log_Msg "Copying Scout from Reference fMRI"
    ${FSLDIR}/bin/imcp ${fMRIReferencePath}/Scout* ${fMRIFolder}

    for simage in SBRef_nonlin SBRef_nonlin_norm
    do
        ${FSLDIR}/bin/imcp ${fMRIReferencePath}/"${fMRIReference}_${simage}" ${fMRIFolder}/"${NameOffMRI}_${simage}"
    done

    mkdir -p ${ResultsFolder}
    ${FSLDIR}/bin/imcp ${ReferenceResultsFolder}/"${fMRIReference}_SBRef" ${ResultsFolder}/"${NameOffMRI}_SBRef"
else    
    # --- Create fake "Scout" if it doesn't exist
    if [ $fMRIScout = "NONE" ] ; then
        ${RUN} ${FSLDIR}/bin/fslroi "$fMRIFolder"/"$OrigTCSName" "$fMRIFolder"/"$OrigScoutName" 0 1
    else
        ${FSLDIR}/bin/imcp "$fMRIScout" "$fMRIFolder"/"$OrigScoutName"
    fi
fi

if [ $DistortionCorrection = "NONE" ] ; then
    # Processing is more robust to registration problems if the fMRI is in the same orientation as the
    # standard template (MNI152) images, which can be accomplished using FSL's `fslreorient2std`.
    # HOWEVER, if you reorient, other parameters (such as UnwarpDir) need to be adjusted accordingly.
    # Rather than deal with those complications here, we limit reorienting to DistortionCorrection=NONE condition.

    # First though, detect if reorienting is even necessary
    xorient=$($FSLDIR/bin/fslval "$fMRIFolder"/"$OrigTCSName" qform_xorient | tr -d ' ')
    yorient=$($FSLDIR/bin/fslval "$fMRIFolder"/"$OrigTCSName" qform_yorient | tr -d ' ')
    zorient=$($FSLDIR/bin/fslval "$fMRIFolder"/"$OrigTCSName" qform_zorient | tr -d ' ')

    log_Msg "$fMRIFolder/$OrigTCSName: xorient=${xorient}, yorient=${yorient}, zorient=${zorient}"

    if [[ "$xorient" != "Right-to-Left" && "$xorient" != "Left-to-Right" || \
          "$yorient" != "Posterior-to-Anterior" || \
          "$zorient" != "Inferior-to-Superior" ]] ; then
        reorient=TRUE
    else 
        reorient=FALSE
    fi

    if [ $reorient = "TRUE" ] ; then
        log_Warn "Performing fslreorient2std! Please take that into account when using the volume fMRI images in further analyses!"

        # --- reorient fMRI
        ${FSLDIR}/bin/immv "$fMRIFolder"/"$OrigTCSName" "$fMRIFolder"/"$OrigTCSName"_pre2std
        ${FSLDIR}/bin/fslreorient2std "$fMRIFolder"/"$OrigTCSName"_pre2std "$fMRIFolder"/"$OrigTCSName"
        ${FSLDIR}/bin/imrm "$fMRIFolder"/"$OrigTCSName"_pre2std

        # --- reorient SCOUT
        if [ "$fMRIReference" = "NONE" ]; then
            ${FSLDIR}/bin/immv "$fMRIFolder"/"$OrigScoutName" "$fMRIFolder"/"$OrigScoutName"_pre2std
            ${FSLDIR}/bin/fslreorient2std "$fMRIFolder"/"$OrigScoutName"_pre2std "$fMRIFolder"/"$OrigScoutName"
            ${FSLDIR}/bin/imrm "$fMRIFolder"/"$OrigScoutName"_pre2std
        fi
    fi
fi


#Gradient Distortion Correction of fMRI
log_Msg "Gradient Distortion Correction of fMRI"
if [ ! $GradientDistortionCoeffs = "NONE" ] ; then
    log_Msg "mkdir -p ${fMRIFolder}/GradientDistortionUnwarp"
    mkdir -p "$fMRIFolder"/GradientDistortionUnwarp
    ${RUN} "$GlobalScripts"/GradientDistortionUnwarp.sh \
        --workingdir="$fMRIFolder"/GradientDistortionUnwarp \
        --coeffs="$GradientDistortionCoeffs" \
        --in="$fMRIFolder"/"$OrigTCSName" \
        --out="$fMRIFolder"/"$NameOffMRI"_gdc \
        --owarp="$fMRIFolder"/"$NameOffMRI"_gdc_warp

    log_Msg "mkdir -p ${fMRIFolder}/${ScoutName}_GradientDistortionUnwarp"
    mkdir -p "$fMRIFolder"/"$ScoutName"_GradientDistortionUnwarp
    ${RUN} "$GlobalScripts"/GradientDistortionUnwarp.sh \
        --workingdir="$fMRIFolder"/"$ScoutName"_GradientDistortionUnwarp \
        --coeffs="$GradientDistortionCoeffs" \
        --in="$fMRIFolder"/"$OrigScoutName" \
        --out="$fMRIFolder"/"$ScoutName"_gdc \
        --owarp="$fMRIFolder"/"$ScoutName"_gdc_warp

    if [[ $UseJacobian == "true" ]]
    then
        ${RUN} ${FSLDIR}/bin/fslmaths "$fMRIFolder"/"$NameOffMRI"_gdc -mul "$fMRIFolder"/"$NameOffMRI"_gdc_warp_jacobian "$fMRIFolder"/"$NameOffMRI"_gdc
        ${RUN} ${FSLDIR}/bin/fslmaths "$fMRIFolder"/"$ScoutName"_gdc -mul "$fMRIFolder"/"$ScoutName"_gdc_warp_jacobian "$fMRIFolder"/"$ScoutName"_gdc
    fi
else
    log_Msg "NOT PERFORMING GRADIENT DISTORTION CORRECTION"
    ${RUN} ${FSLDIR}/bin/imcp "$fMRIFolder"/"$OrigTCSName" "$fMRIFolder"/"$NameOffMRI"_gdc
    ${RUN} ${FSLDIR}/bin/fslroi "$fMRIFolder"/"$NameOffMRI"_gdc "$fMRIFolder"/"$NameOffMRI"_gdc_warp 0 3
    ${RUN} ${FSLDIR}/bin/fslmaths "$fMRIFolder"/"$NameOffMRI"_gdc_warp -mul 0 "$fMRIFolder"/"$NameOffMRI"_gdc_warp
    ${RUN} ${FSLDIR}/bin/imcp "$fMRIFolder"/"$OrigScoutName" "$fMRIFolder"/"$ScoutName"_gdc
    #make fake jacobians of all 1s, for completeness
    ${RUN} ${FSLDIR}/bin/fslmaths "$fMRIFolder"/"$OrigScoutName" -mul 0 -add 1 "$fMRIFolder"/"$ScoutName"_gdc_warp_jacobian
    ${RUN} ${FSLDIR}/bin/fslroi "$fMRIFolder"/"$NameOffMRI"_gdc_warp "$fMRIFolder"/"$NameOffMRI"_gdc_warp_jacobian 0 1
    ${RUN} ${FSLDIR}/bin/fslmaths "$fMRIFolder"/"$NameOffMRI"_gdc_warp_jacobian -mul 0 -add 1 "$fMRIFolder"/"$NameOffMRI"_gdc_warp_jacobian
fi

#Split echos
if [[ ${nEcho} -gt 1 ]]; then
    log_Msg "Splitting echo(s)"
    tcsEchoesOrig=();sctEchoesOrig=();tcsEchoesGdc=();sctEchoesGdc=();
    for iEcho in $(seq 0 $((nEcho-1))) ; do
        tcsEchoesOrig[iEcho]="${OrigTCSName}_E$(printf "%02d" "$iEcho")"
        tcsEchoesGdc[iEcho]="${NameOffMRI}_gdc_E$(printf "%02d" "$iEcho")" # Is only first echo needed for the gdc tcs?
        sctEchoesOrig[iEcho]="${OrigScoutName}_E$(printf "%02d" "$iEcho")"
        sctEchoesGdc[iEcho]="${ScoutName}_gdc_E$(printf "%02d" "$iEcho")"
        wb_command -volume-merge "${fMRIFolder}/${tcsEchoesOrig[iEcho]}.nii.gz" -volume "${fMRIFolder}/${OrigTCSName}.nii.gz" \
            -subvolume $((1 + FramesPerEcho * iEcho)) -up-to $((FramesPerEcho * (iEcho + 1)))
        wb_command -volume-merge "${fMRIFolder}/${sctEchoesOrig[iEcho]}.nii.gz" -volume "${fMRIFolder}/${OrigScoutName}.nii.gz" \
            -subvolume "$(( iEcho + 1 ))"
        wb_command -volume-merge "${fMRIFolder}/${tcsEchoesGdc[iEcho]}.nii.gz" -volume "${fMRIFolder}/${NameOffMRI}_gdc.nii.gz" \
            -subvolume $((1 + FramesPerEcho * iEcho)) -up-to $((FramesPerEcho * (iEcho + 1)))
        wb_command -volume-merge "${fMRIFolder}/${sctEchoesGdc[iEcho]}.nii.gz" -volume "${fMRIFolder}/${ScoutName}_gdc.nii.gz" \
            -subvolume "$(( iEcho + 1 ))"
    done
else
    tcsEchoesOrig[0]="${OrigTCSName}"
    sctEchoesOrig[0]="${OrigScoutName}"
    tcsEchoesGdc[0]="${NameOffMRI}_gdc"
    sctEchoesGdc[0]="${ScoutName}_gdc"
fi

log_Msg "mkdir -p ${fMRIFolder}/MotionCorrection"
mkdir -p "$fMRIFolder"/MotionCorrection

${RUN} "$PipelineScripts"/MotionCorrection.sh \
       "$fMRIFolder"/MotionCorrection \
       "$fMRIFolder/${tcsEchoesGdc[0]}" \
       "$fMRIFolder/${sctEchoesGdc[0]}" \
       "$fMRIFolder"/"$NameOffMRI"_mc \
       "$fMRIFolder"/"$MovementRegressor" \
       "$fMRIFolder"/"$MotionMatrixFolder" \
       "$MotionMatrixPrefix" \
       "$MotionCorrectionType" \
       "$fMRIReferenceReg"

#EPI Distortion Correction and EPI to T1w Registration
DCFolderName=DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased
DCFolder=${fMRIFolder}/${DCFolderName}

if [ $fMRIReference = "NONE" ] ; then
    log_Msg "EPI Distortion Correction and EPI to T1w Registration"

    if [ -e ${DCFolder} ] ; then
       ${RUN} rm -r ${DCFolder}
    fi
    log_Msg "mkdir -p ${DCFolder}"
    mkdir -p ${DCFolder}

    ${RUN} ${PipelineScripts}/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased.sh \
        --workingdir=${DCFolder} \
        --scoutin="${fMRIFolder}/${sctEchoesGdc[0]}" \
        --t1=${T1wFolder}/${T1wImage} \
        --t1restore=${T1wFolder}/${T1wRestoreImage} \
        --t1brain=${T1wFolder}/${T1wRestoreImageBrain} \
        --fmapmag=${MagnitudeInputName} \
        --fmapphase=${PhaseInputName} \
        --fmapcombined=${GEB0InputName} \
        --echodiff=${deltaTE} \
        --SEPhaseNeg=${SpinEchoPhaseEncodeNegative} \
        --SEPhasePos=${SpinEchoPhaseEncodePositive} \
        --echospacing=${EchoSpacing} \
        --unwarpdir=${UnwarpDir} \
        --owarp=${T1wFolder}/xfms/${fMRI2strOutputTransform} \
        --biasfield=${T1wFolder}/${BiasField} \
        --oregim=${fMRIFolder}/${RegOutput} \
        --freesurferfolder=${T1wFolder} \
        --freesurfersubjectid=${Subject} \
        --gdcoeffs=${GradientDistortionCoeffs} \
        --qaimage=${fMRIFolder}/${QAImage} \
        --method=${DistortionCorrection} \
        --topupconfig=${TopupConfig} \
        --ojacobian=${fMRIFolder}/${JacobianOut} \
        --dof=${dof} \
        --fmriname=${NameOffMRI} \
        --subjectfolder=${SubjectFolder} \
        --biascorrection=${BiasCorrection} \
        --usejacobian=${UseJacobian} \
        --preregistertool=${PreregisterTool}

else
    log_Msg "linking EPI distortion correction and T1 registration from ${fMRIReference}"
    if [ -d ${DCFolder} ] ; then
        log_Warn "     ... removing preexisiting files"
        rm -r ${DCFolder}
    fi
    if [ -h ${DCFolder} ] ; then
        log_Warn "     ... removing stale link"
        rm ${DCFolder}
    fi
    ln -s ${fMRIReferencePath}/${DCFolderName} ${DCFolder}
 
    if [ $("${FSLDIR}/bin/imtest ${T1wFolder}/xfms/${fMRIReference}2str") -eq 0 ]; then
        log_Err_Abort "The expected ${T1wFolder}/xfms/${fMRIReference}2str from the reference (${fMRIReference}) does not exist!"    
    else
        ${FSLDIR}/bin/imcp ${T1wFolder}/xfms/${fMRIReference}2str ${T1wFolder}/xfms/${fMRI2strOutputTransform}
    fi
fi

#One Step Resampling
log_Msg "One Step Resampling"
log_Msg "mkdir -p ${fMRIFolder}/OneStepResampling"
mkdir -p ${fMRIFolder}/OneStepResampling
tscArgs="";sctArgs="";
for iEcho in $(seq 0 $((nEcho-1))) ; do
    ${RUN} ${PipelineScripts}/OneStepResampling.sh \
        --workingdir=${fMRIFolder}/OneStepResampling \
        --infmri="${fMRIFolder}/${tcsEchoesOrig[iEcho]}.nii.gz" \
        --t1=${AtlasSpaceFolder}/${T1wAtlasName} \
        --fmriresout=${FinalfMRIResolution} \
        --fmrifolder=${fMRIFolder} \
        --fmri2structin=${T1wFolder}/xfms/${fMRI2strOutputTransform} \
        --struct2std=${AtlasSpaceFolder}/xfms/${AtlasTransform} \
        --owarp=${AtlasSpaceFolder}/xfms/${OutputfMRI2StandardTransform} \
        --oiwarp=${AtlasSpaceFolder}/xfms/${Standard2OutputfMRITransform} \
        --motionmatdir=${fMRIFolder}/${MotionMatrixFolder} \
        --motionmatprefix=${MotionMatrixPrefix} \
        --ofmri="${fMRIFolder}/${tcsEchoesOrig[iEcho]}_nonlin" \
        --freesurferbrainmask=${AtlasSpaceFolder}/${FreeSurferBrainMask} \
        --biasfield=${AtlasSpaceFolder}/${BiasFieldMNI} \
        --gdfield=${fMRIFolder}/${NameOffMRI}_gdc_warp \
        --scoutin="${fMRIFolder}/${sctEchoesOrig[iEcho]}" \
        --scoutgdcin="${fMRIFolder}/${sctEchoesGdc[iEcho]}" \
        --oscout="${fMRIFolder}/${tcsEchoesOrig[iEcho]}_SBRef_nonlin" \
        --ojacobian=${fMRIFolder}/${JacobianOut}_MNI.${FinalfMRIResolution} \
        --fmrirefpath=${fMRIReferencePath} \
        --fmrirefreg=${fMRIReferenceReg} \
        --wb-resample=${useWbResample}
    tscArgs="$tscArgs -volume ${fMRIFolder}/${tcsEchoesOrig[iEcho]}_nonlin.nii.gz"
    sctArgs="$sctArgs -volume ${fMRIFolder}/${tcsEchoesOrig[iEcho]}_SBRef_nonlin.nii.gz"
done
wb_command -volume-merge ${fMRIFolder}/${NameOffMRI}_nonlin.nii.gz ${tscArgs} # reconcatenate resampled outputs
wb_command -volume-merge ${fMRIFolder}/${NameOffMRI}_SBRef_nonlin.nii.gz ${sctArgs}
${FSLDIR}/bin/immv "${fMRIFolder}/${tcsEchoesOrig[iEcho]}_nonlin_mask.nii.gz" "${fMRIFolder}/${NameOffMRI}_nonlin_mask.nii.gz"

log_Msg "mkdir -p ${ResultsFolder}"
mkdir -p ${ResultsFolder}

#now that we have the final MNI fMRI space, resample the T1w-space sebased bias field related outputs
#the alternative is to add a bunch of optional arguments to OneStepResampling that just do the same thing
#we need to do this before intensity normalization, as it uses the bias field output
if [[ ${DistortionCorrection} == "${SPIN_ECHO_METHOD_OPT}" ]]
then
    if [ "$fMRIReference" = "NONE" ]; then        
        #create MNI space corrected fieldmap images
        ${FSLDIR}/bin/applywarp --rel --interp=spline --in=${DCFolder}/PhaseOne_gdc_dc_unbias -w ${AtlasSpaceFolder}/xfms/${AtlasTransform} -r ${fMRIFolder}/${NameOffMRI}_SBRef_nonlin -o ${ResultsFolder}/${NameOffMRI}_PhaseOne_gdc_dc
        ${FSLDIR}/bin/fslmaths ${ResultsFolder}/${NameOffMRI}_PhaseOne_gdc_dc -mas ${fMRIFolder}/${FreeSurferBrainMask}.${FinalfMRIResolution}.nii.gz ${ResultsFolder}/${NameOffMRI}_PhaseOne_gdc_dc
        ${FSLDIR}/bin/applywarp --rel --interp=spline --in=${DCFolder}/PhaseTwo_gdc_dc_unbias -w ${AtlasSpaceFolder}/xfms/${AtlasTransform} -r ${fMRIFolder}/${NameOffMRI}_SBRef_nonlin -o ${ResultsFolder}/${NameOffMRI}_PhaseTwo_gdc_dc
        ${FSLDIR}/bin/fslmaths ${ResultsFolder}/${NameOffMRI}_PhaseTwo_gdc_dc -mas ${fMRIFolder}/${FreeSurferBrainMask}.${FinalfMRIResolution}.nii.gz ${ResultsFolder}/${NameOffMRI}_PhaseTwo_gdc_dc    
    else        
        #as these have been already computed, we can copy them from the reference fMRI
        ${FSLDIR}/bin/imcp ${ReferenceResultsFolder}/${fMRIReference}_PhaseOne_gdc_dc ${ResultsFolder}/${NameOffMRI}_PhaseOne_gdc_dc
        ${FSLDIR}/bin/imcp ${ReferenceResultsFolder}/${fMRIReference}_PhaseOne_gdc_dc ${ResultsFolder}/${NameOffMRI}_PhaseOne_gdc_dc
        ${FSLDIR}/bin/imcp ${ReferenceResultsFolder}/${fMRIReference}_PhaseTwo_gdc_dc ${ResultsFolder}/${NameOffMRI}_PhaseTwo_gdc_dc
        ${FSLDIR}/bin/imcp ${ReferenceResultsFolder}/${fMRIReference}_PhaseTwo_gdc_dc ${ResultsFolder}/${NameOffMRI}_PhaseTwo_gdc_dc
    fi

    #create MNINonLinear final fMRI resolution bias field outputs
    if [[ ${BiasCorrection} == "SEBASED" ]]
    then
        if [ "$fMRIReference" = "NONE" ]; then  
            ${FSLDIR}/bin/applywarp --interp=trilinear -i ${DCFolder}/ComputeSpinEchoBiasField/sebased_bias_dil.nii.gz -r ${fMRIFolder}/${NameOffMRI}_SBRef_nonlin -w ${AtlasSpaceFolder}/xfms/${AtlasTransform} -o ${ResultsFolder}/${NameOffMRI}_sebased_bias.nii.gz
            ${FSLDIR}/bin/fslmaths ${ResultsFolder}/${NameOffMRI}_sebased_bias.nii.gz -mas ${fMRIFolder}/${FreeSurferBrainMask}.${FinalfMRIResolution}.nii.gz ${ResultsFolder}/${NameOffMRI}_sebased_bias.nii.gz

            ${FSLDIR}/bin/applywarp --interp=trilinear -i ${DCFolder}/ComputeSpinEchoBiasField/sebased_reference_dil.nii.gz -r ${fMRIFolder}/${NameOffMRI}_SBRef_nonlin -w ${AtlasSpaceFolder}/xfms/${AtlasTransform} -o ${ResultsFolder}/${NameOffMRI}_sebased_reference.nii.gz
            ${FSLDIR}/bin/fslmaths ${ResultsFolder}/${NameOffMRI}_sebased_reference.nii.gz -mas ${fMRIFolder}/${FreeSurferBrainMask}.${FinalfMRIResolution}.nii.gz ${ResultsFolder}/${NameOffMRI}_sebased_reference.nii.gz       

            ${FSLDIR}/bin/applywarp --interp=trilinear -i ${DCFolder}/ComputeSpinEchoBiasField/${NameOffMRI}_dropouts.nii.gz -r ${fMRIFolder}/${NameOffMRI}_SBRef_nonlin -w ${AtlasSpaceFolder}/xfms/${AtlasTransform} -o ${ResultsFolder}/${NameOffMRI}_dropouts.nii.gz

            ${FSLDIR}/bin/applywarp --interp=trilinear -i ${DCFolder}/ComputeSpinEchoBiasField/${NameOffMRI}_pseudo_transmit_raw.nii.gz -r ${fMRIFolder}/${NameOffMRI}_SBRef_nonlin -w ${AtlasSpaceFolder}/xfms/${AtlasTransform} -o ${ResultsFolder}/${NameOffMRI}_pseudo_transmit_raw.nii.gz
            ${FSLDIR}/bin/fslmaths ${ResultsFolder}/${NameOffMRI}_pseudo_transmit_raw.nii.gz -mas ${fMRIFolder}/${FreeSurferBrainMask}.${FinalfMRIResolution}.nii.gz ${ResultsFolder}/${NameOffMRI}_pseudo_transmit_raw.nii.gz
            ${FSLDIR}/bin/applywarp --interp=trilinear -i ${DCFolder}/ComputeSpinEchoBiasField/${NameOffMRI}_pseudo_transmit_field.nii.gz -r ${fMRIFolder}/${NameOffMRI}_SBRef_nonlin -w ${AtlasSpaceFolder}/xfms/${AtlasTransform} -o ${ResultsFolder}/${NameOffMRI}_pseudo_transmit_field.nii.gz
            ${FSLDIR}/bin/fslmaths ${ResultsFolder}/${NameOffMRI}_pseudo_transmit_field.nii.gz -mas ${fMRIFolder}/${FreeSurferBrainMask}.${FinalfMRIResolution}.nii.gz ${ResultsFolder}/${NameOffMRI}_pseudo_transmit_field.nii.gz
        else
            #as these have been already computed, we can copy them from the reference fMRI
            ${FSLDIR}/bin/imcp ${ReferenceResultsFolder}/${fMRIReference}_sebased_bias.nii.gz ${ResultsFolder}/${NameOffMRI}_sebased_bias.nii.gz
            ${FSLDIR}/bin/imcp ${ReferenceResultsFolder}/${fMRIReference}_sebased_reference.nii.gz ${ResultsFolder}/${NameOffMRI}_sebased_reference.nii.gz
            ${FSLDIR}/bin/imcp ${ReferenceResultsFolder}/${fMRIReference}_dropouts.nii.gz ${ResultsFolder}/${NameOffMRI}_dropouts.nii.gz
            ${FSLDIR}/bin/imcp ${ReferenceResultsFolder}/${fMRIReference}_pseudo_transmit_raw.nii.gz ${ResultsFolder}/${NameOffMRI}_pseudo_transmit_raw.nii.gz
            ${FSLDIR}/bin/imcp ${ReferenceResultsFolder}/${fMRIReference}_pseudo_transmit_field.nii.gz ${ResultsFolder}/${NameOffMRI}_pseudo_transmit_field.nii.gz
        fi
    fi
fi

#Intensity Normalization and Bias Removal
log_Msg "Intensity Normalization and Bias Removal"
${RUN} ${PipelineScripts}/IntensityNormalization.sh \
    --infmri=${fMRIFolder}/${NameOffMRI}_nonlin \
    --biasfield=${UseBiasFieldMNI} \
    --jacobian=${fMRIFolder}/${JacobianOut}_MNI.${FinalfMRIResolution} \
    --brainmask=${fMRIFolder}/${FreeSurferBrainMask}.${FinalfMRIResolution} \
    --ofmri=${fMRIFolder}/${NameOffMRI}_nonlin_norm \
    --inscout=${fMRIFolder}/${NameOffMRI}_SBRef_nonlin \
    --oscout=${fMRIFolder}/${NameOffMRI}_SBRef_nonlin_norm \
    --usejacobian=${UseJacobian} \
    --fmrimask=${fMRIMask}


if [[ ${nEcho} -gt 1 ]]; then
    log_Msg "Creating echoMeans"
    # Calculate echoMeans of intensity normalized result
    tcsEchoes=(); tcsEchoesMu=();args=""
    for iE in $(seq 0 $((nEcho-1))); do
        tcsEchoes[iE]="${EchoDir}/${NameOffMRI}_nonlin_norm_E$(printf "%02d" "$iE").nii.gz"
        tcsEchoesMu[iE]="${EchoDir}/${NameOffMRI}_nonlin_norm_E$(printf "%02d" "$iE")Mean.nii.gz"
        wb_command -volume-merge "${tcsEchoes[iE]}" -volume "${fMRIFolder}/${NameOffMRI}_nonlin_norm.nii.gz" -subvolume $((1 + FramesPerEcho * iE)) -up-to $((FramesPerEcho * (iE + 1)))
        wb_command -volume-reduce "${tcsEchoes[iE]}" MEAN "${tcsEchoesMu[iE]}"
        args="${args} -volume ${tcsEchoesMu[iE]} -subvolume 1"
    done # iE
    wb_command -volume-merge ${EchoDir}/${NameOffMRI}_nonlin_norm_EchoMeans.nii.gz ${args}

    # # fit T2* and S0 then Combine Echoes
    log_Msg "Fitting T2* and combining Echoes"

    ${RUN} ln -sf ${fMRIFolder}/${NameOffMRI}_nonlin_norm.nii.gz ${EchoDir}/${NameOffMRI}_nonlin_norm.nii.gz 
    ${RUN} ln -sf ${fMRIFolder}/${NameOffMRI}_SBRef_nonlin_norm.nii.gz ${EchoDir}/${NameOffMRI}_SBRef_nonlin_norm.nii.gz 

    echo ${echoTE} > ${EchoDir}/TEs.txt

    case "$MatlabMode" in
        (0)
            matlab_cmd=("$PipelineScripts/Compiled_multiEchoCombine/run_multiEchoCombine.sh" "$MATLAB_COMPILER_RUNTIME" \
                "${EchoDir}/${NameOffMRI}_nonlin_norm.nii.gz" \
                "${EchoDir}/TEs.txt" \
                "${EchoDir}/${NameOffMRI}_nonlin_norm_EchoMeans.nii.gz" \
                "${EchoDir}/${NameOffMRI}_SBRef_nonlin_norm.nii.gz")
            log_Msg "Run compiled MATLAB: ${matlab_cmd[*]}"
            "${matlab_cmd[@]}"
            ;;
        (1 | 2)
            matlab_code="
                addpath('${PipelineScripts}');
                multiEchoCombine('${EchoDir}/${NameOffMRI}_nonlin_norm.nii.gz', '${EchoDir}/TEs.txt', '${EchoDir}/${NameOffMRI}_nonlin_norm_EchoMeans.nii.gz', '${EchoDir}/${NameOffMRI}_SBRef_nonlin_norm.nii.gz');"
            log_Msg "running matlab code: $matlab_code"
            "${matlab_interpreter[@]}" <<<"${matlab_code}"
            echo
            ;;
    esac
fi

#Copy selected files to ResultsFolder
if [[ ${nEcho} -gt 1 ]]; then
    ${RUN} cp ${EchoDir}/${NameOffMRI}_nonlin_norm_CombEchoes.nii.gz ${ResultsFolder}/${NameOffMRI}.nii.gz
    ${RUN} cp ${EchoDir}/${NameOffMRI}_SBRef_nonlin_norm_CombEchoes.nii.gz ${ResultsFolder}/${NameOffMRI}_SBRef.nii.gz

    ${RUN} cp ${fMRIFolder}/${NameOffMRI}_nonlin_norm.nii.gz ${ResultsFolder}/${NameOffMRI}_Echoes.nii.gz
    ${RUN} cp ${fMRIFolder}/${NameOffMRI}_SBRef_nonlin_norm.nii.gz ${ResultsFolder}/${NameOffMRI}_SBRef_Echoes.nii.gz

    ${RUN} cp ${EchoDir}/${NameOffMRI}_nonlin_norm_T2star.nii.gz ${ResultsFolder}/${NameOffMRI}_T2star.nii.gz
    ${RUN} cp ${EchoDir}/${NameOffMRI}_nonlin_norm_S0.nii.gz ${ResultsFolder}/${NameOffMRI}_S0.nii.gz
    ${RUN} cp ${EchoDir}/${NameOffMRI}_nonlin_norm_EchoWeights.nii.gz ${ResultsFolder}/${NameOffMRI}_EchoWeights.nii.gz
    ${RUN} cp ${EchoDir}/${NameOffMRI}_nonlin_norm_EchoMeans.nii.gz ${ResultsFolder}/${NameOffMRI}_EchoMeans.nii.gz
else
    ${RUN} cp ${fMRIFolder}/${NameOffMRI}_nonlin_norm.nii.gz ${ResultsFolder}/${NameOffMRI}.nii.gz
    ${RUN} cp ${fMRIFolder}/${NameOffMRI}_SBRef_nonlin_norm.nii.gz ${ResultsFolder}/${NameOffMRI}_SBRef.nii.gz
fi

${RUN} cp ${fMRIFolder}/${NameOffMRI}_SBRef_nonlin_norm_nomask.nii.gz ${ResultsFolder}/${NameOffMRI}_SBRef_nomask.nii.gz
${RUN} cp ${fMRIFolder}/${JacobianOut}_MNI.${FinalfMRIResolution}.nii.gz ${ResultsFolder}/${NameOffMRI}_${JacobianOut}.nii.gz
${RUN} cp ${fMRIFolder}/${FreeSurferBrainMask}.${FinalfMRIResolution}.nii.gz ${ResultsFolder}
${RUN} cp ${fMRIFolder}/${NameOffMRI}_nonlin_mask.nii.gz ${ResultsFolder}/${NameOffMRI}_fovmask.nii.gz
${RUN} cp ${fMRIFolder}/${NameOffMRI}_nonlin_finalmask.nii.gz ${ResultsFolder}/${NameOffMRI}_finalmask.nii.gz

${RUN} cp ${fMRIFolder}/${NameOffMRI}_nonlin_finalmask.stats.txt ${ResultsFolder}/${NameOffMRI}_finalmask.stats.txt
${RUN} cp ${fMRIFolder}/${MovementRegressor}.txt ${ResultsFolder}
${RUN} cp ${fMRIFolder}/${MovementRegressor}_dt.txt ${ResultsFolder}
${RUN} cp ${fMRIFolder}/Movement_RelativeRMS.txt ${ResultsFolder}
${RUN} cp ${fMRIFolder}/Movement_AbsoluteRMS.txt ${ResultsFolder}
${RUN} cp ${fMRIFolder}/Movement_RelativeRMS_mean.txt ${ResultsFolder}
${RUN} cp ${fMRIFolder}/Movement_AbsoluteRMS_mean.txt ${ResultsFolder}

#Basic Cleanup
${FSLDIR}/bin/imrm ${fMRIFolder}/${NameOffMRI}_nonlin_norm

#Econ
#${FSLDIR}/bin/imrm "$fMRIFolder"/"$OrigTCSName"
${FSLDIR}/bin/imrm "$fMRIFolder"/"$NameOffMRI"_gdc #This can be checked with the SBRef
${FSLDIR}/bin/imrm "$fMRIFolder"/"$NameOffMRI"_mc #This can be checked with the unmasked spatially corrected data

# clean up split echo(s)
if [[ $nEcho -gt 1 ]]; then
    for iEcho in $(seq 0 $((nEcho-1))) ; do
        ${FSLDIR}/bin/imrm "${fMRIFolder}/${tcsEchoesOrig[iEcho]}"
        ${FSLDIR}/bin/imrm "${fMRIFolder}/${tcsEchoesOrig[iEcho]}_nonlin"
        ${FSLDIR}/bin/imrm "${fMRIFolder}/${tcsEchoesOrig[iEcho]}_nonlin_mask"
        ${FSLDIR}/bin/imrm "${fMRIFolder}/${tcsEchoesOrig[iEcho]}_SBRef_nonlin"

        ${FSLDIR}/bin/imrm "${fMRIFolder}/${tcsEchoesGdc[iEcho]}"

        ${FSLDIR}/bin/imrm "${fMRIFolder}/${sctEchoesOrig[iEcho]}"
        ${FSLDIR}/bin/imrm "${fMRIFolder}/${sctEchoesGdc[iEcho]}"
        ${FSLDIR}/bin/imrm "${fMRIFolder}/${sctEchoesGdc[iEcho]}_mask"
    done
    ${FSLDIR}/bin/imrm "${tcsEchoes[@]}"
    ${FSLDIR}/bin/imrm "${tcsEchoesMu[@]}"
fi

log_Msg "Completed!"

