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

FIELDMAP_METHOD_OPT="FIELDMAP"
SIEMENS_METHOD_OPT="SiemensFieldMap"
GENERAL_ELECTRIC_METHOD_OPT="GeneralElectricFieldMap"
PHILIPS_METHOD_OPT="PhilipsFieldMap"
SPIN_ECHO_METHOD_OPT="TOPUP"
NONE_METHOD_OPT="NONE"

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

script_name=$(basename "${0}")

show_usage() {
	cat <<EOF

${script_name}: Run fMRIVolume processing pipeline

Usage: ${script_name} [options]

  [--help] : show usage information and exit
  --path=<path to study folder>
  --subject=<subject ID>
  --fmritcs=<input fMRI time series (NIFTI)>
  --fmriname=<name (prefix) to use for the output>
  --fmrires=<final resolution (mm) of the output data>

  --biascorrection=<method to use for receive coil bias field correction>

        "SEBASED"
             use bias field derived from spin echo images, must also use --dcmethod="${SPIN_ECHO_METHOD_OPT}"

        "LEGACY"
             use the bias field derived from T1w and T2w images, same as was used in 
             pipeline version 3.14.1 or older. No longer recommended.

        "NONE"
             don't do bias correction

  [--fmriscout=<input "scout" volume>]

      Used as the target for motion correction and for BBR registration to the structurals.
      In HCP-Style acquisitions, the "SBRef" (single-band reference) volume associated with a run is 
      typically used as the "scout".
      Default: "NONE" (in which case the first volume of the time-series is extracted and used as the "scout")
      It must have identical dimensions, voxel resolution, and distortions (i.e., phase-encoding 
      polarity and echo-spacing) as the input fMRI time series

  [--mctype=<type of motion correction to use: "MCFLIRT" (default) or "FLIRT">]

  --gdcoeffs=<gradient non-linearity distortion coefficients (Siemens format)>
      Set to "NONE" to skip gradient non-linearity distortion correction (GDC).

  --dcmethod=<method to use for susceptibility distortion correction (SDC)>

        "${FIELDMAP_METHOD_OPT}"
            equivalent to "${SIEMENS_METHOD_OPT}" (see below)

        "${SIEMENS_METHOD_OPT}"
             use Siemens specific Gradient Echo Field Maps for SDC

        "${SPIN_ECHO_METHOD_OPT}"
             use a pair of Spin Echo EPI images ("Spin Echo Field Maps") acquired with
             opposing polarity for SDC

        "${GENERAL_ELECTRIC_METHOD_OPT}"
             use General Electric specific Gradient Echo Field Maps for SDC

        "${PHILIPS_METHOD_OPT}"
             use Philips specific Gradient Echo Field Maps for SDC

        "${NONE_METHOD_OPT}"
             do not use any SDC
             NOTE: Only valid when Pipeline is called with --processing-mode="LegacyStyleData"

  Options required for all --dcmethod options except for "${NONE_METHOD_OPT}":

    [--echospacing=<*effective* echo spacing of fMRI input, in seconds>]
    [--unwarpdir=<PE direction for unwarping according to the *voxel* axes: 
       {x,y,z,x-,y-,z-} or {i,j,k,i-,j-,k-}>]
          Polarity matters!  If your distortions are twice as bad as in the original images, 
          try using the opposite polarity for --unwarpdir.

  Options required if using --dcmethod="${SPIN_ECHO_METHOD_OPT}":

    [--SEPhaseNeg=<"negative" polarity SE-EPI image>]
    [--SEPhasePos=<"positive" polarity SE-EPI image>]
    [--topupconfig=<topup config file>]

  Options required if using --dcmethod="${SIEMENS_METHOD_OPT}":

    [--fmapmag=<input Siemens field map magnitude image>]
    [--fmapphase=input Siemens field map phase image>]
    [--echodiff=<difference of echo times for fieldmap, in milliseconds>]

  Options required if using --dcmethod="${GENERAL_ELECTRIC_METHOD_OPT}":

    [--fmapgeneralelectric=<input General Electric field map image>]

  Options required if using --dcmethod="${PHILIPS_METHOD_OPT}":

    [--fmapmag=<input Philips field map magnitude image>]
    [--fmapphase=input Philips field map phase image>]

  OTHER OPTIONS:

  [--dof=<Degrees of freedom for the EPI to T1 registration: 6 (default), 9, or 12>]

  [--usejacobian=<"TRUE" or "FALSE">]

      Controls whether the jacobian of the *distortion corrections* (GDC and SDC) are applied 
      to the output data.  (The jacobian of the nonlinear T1 to template (MNI152) registration 
      is NOT applied, regardless of value).  
      Default: "TRUE" if using --dcmethod="${SPIN_ECHO_METHOD_OPT}"; "FALSE" for all other SDC methods.

  [--processing-mode=<"HCPStyleData" (default) or "LegacyStyleData">

      Controls whether the HCP acquisition and processing guidelines should be treated as requirements.
      "HCPStyleData" (the default) follows the processing steps described in Glasser et al. (2013) 
        and requires 'HCP-Style' data acquistion. 
      "LegacyStyleData" allows additional processing functionality and use of some acquisitions
        that do not conform to 'HCP-Style' expectations.  


  -------- "LegacyStyleData" MODE OPTIONS --------

   Use --processing-mode-info to see important additional information and warnings about the use of 
   the following options!

  [--preregistertool=<"epi_reg" (default) or "flirt">]

      Specifies which software tool to use to preregister the fMRI to T1w image 
      (prior to the final FreeSurfer BBR registration).
      "epi_reg" is default, whereas "flirt" might give better results with some 
      legacy type data (e.g., single band, low resolution).

  [--doslicetime=<"FALSE" (default) or "TRUE">]

      Specifies whether slice timing correction should be run on the fMRI input.
      If set to "TRUE" FSL's 'slicetimer' is run before motion correction. 
      Please run with --processing-mode-info flag for additional information on the issues 
      relevant for --doslicetime.

  [--slicetimerparams=<"@" separated list of slicetimer parameters>]

      Enables passing additional parameters to FSL's 'slicetimer' if --doslicetime="TRUE".
      The parameters to pass should be provided as a "@" separated string, e.g.:
        --slicetimerparams="--odd@--ocustom=<CustomInterleaveFile>"
      For details about valid parameters please consult FSL's 'slicetimer' documentation. 

  [--fmrimask=<type of final mask to use for final fMRI output volume>]

      Specifies the type of final mask to apply to the volumetric fMRI data. Valid options are:
        "T1_fMRI_FOV" (default) - T1w brain based mask combined with fMRI FOV mask
        "T1_DILATED_fMRI_FOV" - once dilated T1w brain based mask combined with fMRI FOV
        "T1_DILATED2x_fMRI_FOV" - twice dilated T1w brain based mask combined with fMRI FOV
        "fMRI_FOV" - fMRI FOV mask only (i.e., voxels having spatial coverage at all time points)
      Note that mask is used in IntensityNormalization.sh, so the mask type affects the final results.

  [--fmriref=<"NONE" (default) or reference fMRI run name>]

      Specifies whether to use another (already processed) fMRI run as a reference for processing.
      (i.e., --fmriname from the run to be used as *reference*).
      The specified run will be used as a reference for motion correction and its distortion
      correction and atlas (MNI152) registration will be copied over and used. The reference fMRI
      has to have been fully processed using the fMRIVolume pipeline, so that a distortion
      correction and atlas (MNI152) registration solution for the reference fMRI already exists. 
      The reference fMRI must have been acquired using the same imaging parameters (e.g., phase 
      encoding polarity and echo spacing), or it can not serve as a valid reference. (NO checking 
      is performed to verify this).
      WARNING: This option excludes the use of the --fmriscout option, as the scout from the
      specified reference fMRI run is used instead. 
      Please run with --processing-mode-info flag for additional information on the issues related 
      to the use of --fmriref.

  [--fmrirefreg=<"linear" (default) or "nonlinear">]

      Specifies whether to compute and apply a nonlinear transform to align the inputfMRI to the 
      reference fMRI, if one is specified using --fmriref. The nonlinear transform is computed 
      using 'fnirt' following the motion correction using the mean motion corrected fMRI image.

EOF
}

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


# Allow script to return a Usage statement, before any other output or checking
if [ "$#" = "0" ]; then
	show_usage
	exit 1
fi


# ------------------------------------------------------------------------------
#  Check that HCPPIPEDIR is defined and Load Function Libraries
# ------------------------------------------------------------------------------

if [ -z "${HCPPIPEDIR}" ]; then
	echo "${script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
	exit 1
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"           # Debugging functions; also sources log.shlib
source "${HCPPIPEDIR}/global/scripts/opts.shlib"                 # Command line option functions
source "${HCPPIPEDIR}/global/scripts/processingmodecheck.shlib"  # Check processing mode requirements
source "${HCPPIPEDIR}/global/scripts/fsl_version.shlib"          # Functions for getting FSL version

opts_ShowVersionIfRequested "$@"

if opts_CheckForHelpRequest "$@"; then
	show_usage
	exit 0
fi

if opts_CheckForFlag --processing-mode-info "$@"; then
  show_processing_mode_info
  exit 0
fi

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
#  Check for incompatible FSL version
# ------------------------------------------------------------------------------

check_fsl_version()
{
	local fsl_version=${1}
	local fsl_version_array
	local fsl_primary_version
	local fsl_secondary_version
	local fsl_tertiary_version

	# parse the FSL version information into primary, secondary, and tertiary parts
	fsl_version_array=(${fsl_version//./ })
	
	fsl_primary_version="${fsl_version_array[0]}"
	fsl_primary_version=${fsl_primary_version//[!0-9]/}

	fsl_secondary_version="${fsl_version_array[1]}"
	fsl_secondary_version=${fsl_secondary_version//[!0-9]/}

	fsl_tertiary_version="${fsl_version_array[2]}"
	fsl_tertiary_version=${fsl_tertiary_version//[!0-9]/}

	# FSL version 6.0.0 is unsupported
	if [[ $(( ${fsl_primary_version} )) -eq 6 ]]; then
		if [[ $(( ${fsl_secondary_version} )) -eq 0 ]]; then
			if [[ $(( ${fsl_tertiary_version} )) -eq 0 ]]; then
				log_Err_Abort "FSL version 6.0.0 is unsupported. Please upgrade to at least version 6.0.1"
			fi
		fi
	fi
}

fsl_version_get fsl_ver
check_fsl_version ${fsl_ver}

################################################## OPTION PARSING #####################################################

log_Msg "Platform Information Follows: "
uname -a

log_Msg "Parsing Command Line Options"

# parse arguments
Path=`opts_GetOpt1 "--path" $@`
log_Msg "Path: ${Path}"
if [ -z ${Path} ]; then
	log_Err_Abort "--path must be specified"
fi

Subject=`opts_GetOpt1 "--subject" $@`
log_Msg "Subject: ${Subject}"
if [ -z ${Subject} ]; then
	log_Err_Abort "--subject must be specified"
fi

fMRITimeSeries=`opts_GetOpt1 "--fmritcs" $@`
log_Msg "fMRITimeSeries: ${fMRITimeSeries}"
if [ -z ${fMRITimeSeries} ]; then
	log_Err_Abort "--fmritcs must be specified"
fi

NameOffMRI=`opts_GetOpt1 "--fmriname" $@`
log_Msg "NameOffMRI: ${NameOffMRI}"
if [ -z ${NameOffMRI} ]; then
	log_Err_Abort "--fmriname must be specified"
fi

FinalfMRIResolution=`opts_GetOpt1 "--fmrires" $@`  
log_Msg "FinalfMRIResolution: ${FinalfMRIResolution}"
if [ -z ${FinalfMRIResolution} ]; then
	log_Err_Abort "--fmrires must be specified"
fi

fMRIScout=`opts_GetOpt1 "--fmriscout" $@`
fMRIScout=`opts_DefaultOpt $fMRIScout NONE` # Set to NONE if no scout is provided. 
                                            # NOTE: If external fMRI reference is to be used (--fmriref), --fmriscout 
                                            #   should not be provided or it needs to be set to NONE. The two options 
                                            #   are mutually exclusive.
log_Msg "fMRIScout: ${fMRIScout}"

EchoSpacing=`opts_GetOpt1 "--echospacing" $@`  # *Effective* Echo Spacing of fMRI image, in seconds
log_Msg "EchoSpacing: ${EchoSpacing}"

UnwarpDir=`opts_GetOpt1 "--unwarpdir" $@`  
log_Msg "UnwarpDir: ${UnwarpDir}"

SpinEchoPhaseEncodeNegative=`opts_GetOpt1 "--SEPhaseNeg" $@`
log_Msg "SpinEchoPhaseEncodeNegative: ${SpinEchoPhaseEncodeNegative}"

SpinEchoPhaseEncodePositive=`opts_GetOpt1 "--SEPhasePos" $@`
log_Msg "SpinEchoPhaseEncodePositive: ${SpinEchoPhaseEncodePositive}"

TopupConfig=`opts_GetOpt1 "--topupconfig" $@`
log_Msg "TopupConfig: ${TopupConfig}"

MagnitudeInputName=`opts_GetOpt1 "--fmapmag" $@`  # Expects 4D volume with two 3D timepoints
log_Msg "MagnitudeInputName: ${MagnitudeInputName}"

PhaseInputName=`opts_GetOpt1 "--fmapphase" $@`  
log_Msg "PhaseInputName: ${PhaseInputName}"

deltaTE=`opts_GetOpt1 "--echodiff" $@`  
log_Msg "deltaTE: ${deltaTE}"

GEB0InputName=`opts_GetOpt1 "--fmapgeneralelectric" $@`
log_Msg "GEB0InputName: ${GEB0InputName}"

# FIELDMAP, SiemensFieldMap, GeneralElectricFieldMap, PhilipsFieldMap, or TOPUP
# Note: FIELDMAP and SiemensFieldMap are equivalent
DistortionCorrection=`opts_GetOpt1 "--dcmethod" $@`
log_Msg "DistortionCorrection: ${DistortionCorrection}"
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

	${GENERAL_ELECTRIC_METHOD_OPT})
		if [ -z ${GEB0InputName} ]; then
			log_Err_Abort "--fmapgeneralelectric must be specified with --dcmethod=${DistortionCorrection}"
		fi
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

	"")
		log_Err_Abort "--dcmethod must be specified"
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

BiasCorrection=`opts_GetOpt1 "--biascorrection" $@`
# Convert BiasCorrection value to all UPPERCASE (to allow the user the flexibility to use NONE, None, none, legacy, Legacy, etc.)
BiasCorrection="$(echo ${BiasCorrection} | tr '[:lower:]' '[:upper:]')"
log_Msg "BiasCorrection: ${BiasCorrection}"

MotionCorrectionType=`opts_GetOpt1 "--mctype" $@`  # use = "FLIRT" to run FLIRT-based mcflirt_acc.sh, or "MCFLIRT" to run MCFLIRT-based mcflirt.sh
MotionCorrectionType=`opts_DefaultOpt $MotionCorrectionType MCFLIRT` #use mcflirt by default
case "$MotionCorrectionType" in
    MCFLIRT|FLIRT)
		log_Msg "MotionCorrectionType: ${MotionCorrectionType}"
    ;;
    
    *)
		log_Err_Abort "--mctype must be 'MCFLIRT' (default) or 'FLIRT'"
    ;;
esac

GradientDistortionCoeffs=`opts_GetOpt1 "--gdcoeffs" $@`  
log_Msg "GradientDistortionCoeffs: ${GradientDistortionCoeffs}"
if [ -z ${GradientDistortionCoeffs} ]; then
	log_Err_Abort "--gdcoeffs must be specified"
fi

dof=`opts_GetOpt1 "--dof" $@`
dof=`opts_DefaultOpt $dof 6`
log_Msg "dof: ${dof}"

#NOTE: the jacobian option only applies the jacobian of the distortion corrections to the fMRI data, and NOT from the nonlinear T1 to template registration
UseJacobian=`opts_GetOpt1 "--usejacobian" $@`
# Convert UseJacobian value to all lowercase (to allow the user the flexibility to use True, true, TRUE, False, False, false, etc.)
UseJacobian="$(echo ${UseJacobian} | tr '[:upper:]' '[:lower:]')"
log_Msg "UseJacobian: ${UseJacobian}"

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
log_Msg "JacobianDefault: ${JacobianDefault}"

UseJacobian=`opts_DefaultOpt $UseJacobian $JacobianDefault`
log_Msg "After taking default value if necessary, UseJacobian: ${UseJacobian}"

#sanity check the jacobian option
if [[ "$UseJacobian" != "true" && "$UseJacobian" != "false" ]]
then
    log_Err_Abort "the --usejacobian option must be 'true' or 'false'"
fi

RUN=`opts_GetOpt1 "--printcom" $@`  #not fully obeyed, easy to forget when editing, and not particularly useful, phase it out?
if [[ "$RUN" != "" ]]
then
    log_Err_Abort "--printcom is not consistently implemented, do not rely on it"
fi
log_Msg "RUN: ${RUN}"

if [[ -n $HCPPIPEDEBUG ]]
then
    set -x
fi

# Setup PATHS
GlobalScripts=${HCPPIPEDIR_Global}
PipelineScripts=${HCPPIPEDIR_fMRIVol}

#Naming Conventions
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
#  Legacy Style Data Options
# ------------------------------------------------------------------------------

PreregisterTool=`opts_GetOpt1 "--preregistertool" $@`                    # what to use to preregister fMRI to T1w image before FreeSurfer BBR - epi_reg (default) or flirt
DoSliceTimeCorrection=`opts_GetOpt1 "--doslicetime" $@`                  # Whether to do slicetime correction (TRUE), FALSE to omit.
                                                                         # WARNING: This LegacyStyleData option of slice timing correction is performed before motion correction 
                                                                         #   and thus assumes that the brain is motionless. Errors in temporal interpolation will occur in the presence
                                                                         #   of head motion and may also disrupt data quality measures as shown in Power et al 2017 PLOS One "Temporal 
                                                                         #   interpolation alters motion in fMRI scans: Magnitudes and consequences for artifact detection." Slice timing
                                                                         #   correction and motion correction would ideally be performed simultaneously; however, this is not currently 
                                                                         #   supported by any major software tool. HCP-Style fast TR fMRI data acquisitions (TR<=1s) avoid the need for 
                                                                         #   slice timing correction, provide major advantages for fMRI denoising, and are recommended. 
                                                                         #   No slice timing correction is done by default.  

SliceTimerCorrectionParameters=$(opts_GetOpt1 "--slicetimerparams" "$@") # A '@' separated list of FSL slicetimer options. Please see FSL slicetimer documentation for details.
                                                                         # Verbose (-v) is already turned on. TR is read from 'pixdim4' of the input NIFTI itself.
                                                                         # e.g. --slicetimerparams="--odd@--ocustom=<CustomInterleaveFile>"

fMRIMask=`opts_GetOpt1 "--fmrimask" $@`                                  # Specifies what mask to use for the final fMRI output volume:
                                                                         #   T1_fMRI_FOV (default): T1w brain based mask combined fMRI FOV mask
                                                                         #   T1_DILATED_fMRI_FOV: once dilated T1w brain based mask combined with fMRI FOV
                                                                         #   T1_DILATED2x_fMRI_FOV: twice dilated T1w brain based mask combined with fMRI FOV
                                                                         #   fMRI_FOV: fMRI FOV mask only (i.e., voxels having spatial coverage at all time points)

fMRIReference=`opts_GetOpt1 "--fmriref" $@`                              # Reference fMRI run name (i.e., --fmriname from run to be used as *reference*) to use as 
                                                                         #   motion correction target and to copy atlas (MNI152) registration from (or NONE; default).
                                                                         #   NOTE: The reference fMRI has to have been fully processed using fMRIVolume pipeline, so
                                                                         #   that a distortion correction and atlas (MNI152) registration solution for the reference
                                                                         #   fMRI already exists. Also, the reference fMRI must have been acquired using the same
                                                                         #   phase encoding direction, or it can not serve as a valid reference. 
                                                                         # WARNING: This option excludes the use of --fmriscout option, as the scout from the specified
                                                                         #   reference fMRI is used instead.

fMRIReferenceReg=`opts_GetOpt1 "--fmrirefreg" $@`                        # In the cases when the fMRI input is registered to a specified fMRI reference, this option 
                                                                         #   specifies whether to use 'linear' or 'nonlinear' registration to the reference fMRI.
                                                                         #   Default is 'linear'.

# Defaults
PreregisterTool=`opts_DefaultOpt $PreregisterTool "epi_reg"`
DoSliceTimeCorrection=`opts_DefaultOpt $DoSliceTimeCorrection "FALSE"`   
fMRIReference=`opts_DefaultOpt $fMRIReference "NONE"`
fMRIMask=`opts_DefaultOpt $fMRIMask "T1_fMRI_FOV"`

# If --dcmethod=NONE                                                     # WARNING: The fMRIVolume pipeline is being run without appropriate distortion correction of the fMRI images. 
                                                                         #   This is NOT RECOMMENDED under normal circumstances. We will attempt 6 DOF FreeSurfer BBR registration of 
                                                                         #   the distorted fMRI to the undistorted T1w image. Distorted portions of the fMRI data will not align with 
                                                                         #   the cortical ribbon. In HCP data 30% of the cortical surface will be misaligned by at least half cortical 
                                                                         #   thickness and 10% of the cortical surface will be completely misaligned by a full cortical thickness. 
                                                                         #   At a future time, we may be able to add support for fieldmap-less distortion correction. At this time, 
                                                                         #   however, despite ongoing efforts, this problem is unsolved and no extant approach has been successfully 
                                                                         #   shown to demonstrate clear improvement according to the accuracy standards of HCP-Style data analysis when 
                                                                         #   compared to gold-standard fieldmap-based correction.


# ------------------------------------------------------------------------------
#  Compliance check of Legacy Style Data options
# ------------------------------------------------------------------------------

ProcessingMode=`opts_GetOpt1 "--processing-mode" $@`
ProcessingMode=`opts_DefaultOpt $ProcessingMode "HCPStyleData"`
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
  fMRIReferenceReg=`opts_DefaultOpt $fMRIReferenceReg "linear"`

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

  if [ `${FSLDIR}/bin/imtest ${fMRIReferenceImage}` -eq 0 ] ; then
    log_Err_Abort "Intended fMRI Reference does not exist (${fMRIReferenceImage})!"
  fi 

  if [ `${FSLDIR}/bin/imtest ${fMRIReferenceImageMask}` -eq 0 ] ; then
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

check_mode_compliance "${ProcessingMode}" "${Compliance}" "${ComplianceMsg}"

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

# --- Do slice time correction if indicated
# Note that in the case of STC, $fMRIFolder/$OrigTCSName will NOT be the "original" time-series
# but rather the slice-time corrected version thereof.

if [ $DoSliceTimeCorrection = "TRUE" ] ; then
    log_Msg "Running slice timing correction using FSL's 'slicetimer' tool ..."
    log_Msg "... $fMRIFolder/$OrigTCSName will be a slice-time-corrected version of the original data"
    TR=`${FSLDIR}/bin/fslval "$fMRIFolder"/"$OrigTCSName" pixdim4`
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
    find ${fMRIReferencePath} -maxdepth 1 -name "Scout*" -type f -exec ${FSLDIR}/bin/imcp {} ${fMRIFolder} \;

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
    xorient=`$FSLDIR/bin/fslval "$fMRIFolder"/"$OrigTCSName" qform_xorient | tr -d ' '`
    yorient=`$FSLDIR/bin/fslval "$fMRIFolder"/"$OrigTCSName" qform_yorient | tr -d ' '`
    zorient=`$FSLDIR/bin/fslval "$fMRIFolder"/"$OrigTCSName" qform_zorient | tr -d ' '`

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

log_Msg "mkdir -p ${fMRIFolder}/MotionCorrection"
mkdir -p "$fMRIFolder"/MotionCorrection

${RUN} "$PipelineScripts"/MotionCorrection.sh \
       "$fMRIFolder"/MotionCorrection \
       "$fMRIFolder"/"$NameOffMRI"_gdc \
       "$fMRIFolder"/"$ScoutName"_gdc \
       "$fMRIFolder"/"$NameOffMRI"_mc \
       "$fMRIFolder"/"$MovementRegressor" \
       "$fMRIFolder"/"$MotionMatrixFolder" \
       "$MotionMatrixPrefix" \
       "$MotionCorrectionType" \
       "$fMRIReferenceReg"

# EPI Distortion Correction and EPI to T1w Registration
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
         --scoutin=${fMRIFolder}/${ScoutName}_gdc \
         --t1=${T1wFolder}/${T1wImage} \
         --t1restore=${T1wFolder}/${T1wRestoreImage} \
         --t1brain=${T1wFolder}/${T1wRestoreImageBrain} \
         --fmapmag=${MagnitudeInputName} \
         --fmapphase=${PhaseInputName} \
         --fmapgeneralelectric=${GEB0InputName} \
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
 
    if [ `${FSLDIR}/bin/imtest ${T1wFolder}/xfms/${fMRIReference}2str` -eq 0 ]; then
      log_Err_Abort "The expected ${T1wFolder}/xfms/${fMRIReference}2str from the reference (${fMRIReference}) does not exist!"    
    else
      ${FSLDIR}/bin/imcp ${T1wFolder}/xfms/${fMRIReference}2str ${T1wFolder}/xfms/${fMRI2strOutputTransform}
    fi
fi

#One Step Resampling
log_Msg "One Step Resampling"
log_Msg "mkdir -p ${fMRIFolder}/OneStepResampling"

mkdir -p ${fMRIFolder}/OneStepResampling
${RUN} ${PipelineScripts}/OneStepResampling.sh \
       --workingdir=${fMRIFolder}/OneStepResampling \
       --infmri=${fMRIFolder}/${OrigTCSName}.nii.gz \
       --t1=${AtlasSpaceFolder}/${T1wAtlasName} \
       --fmriresout=${FinalfMRIResolution} \
       --fmrifolder=${fMRIFolder} \
       --fmri2structin=${T1wFolder}/xfms/${fMRI2strOutputTransform} \
       --struct2std=${AtlasSpaceFolder}/xfms/${AtlasTransform} \
       --owarp=${AtlasSpaceFolder}/xfms/${OutputfMRI2StandardTransform} \
       --oiwarp=${AtlasSpaceFolder}/xfms/${Standard2OutputfMRITransform} \
       --motionmatdir=${fMRIFolder}/${MotionMatrixFolder} \
       --motionmatprefix=${MotionMatrixPrefix} \
       --ofmri=${fMRIFolder}/${NameOffMRI}_nonlin \
       --freesurferbrainmask=${AtlasSpaceFolder}/${FreeSurferBrainMask} \
       --biasfield=${AtlasSpaceFolder}/${BiasFieldMNI} \
       --gdfield=${fMRIFolder}/${NameOffMRI}_gdc_warp \
       --scoutin=${fMRIFolder}/${OrigScoutName} \
       --scoutgdcin=${fMRIFolder}/${ScoutName}_gdc \
       --oscout=${fMRIFolder}/${NameOffMRI}_SBRef_nonlin \
       --ojacobian=${fMRIFolder}/${JacobianOut}_MNI.${FinalfMRIResolution} \
       --fmrirefpath=${fMRIReferencePath} \
       --fmrirefreg=${fMRIReferenceReg}

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

#Copy selected files to ResultsFolder
${RUN} cp ${fMRIFolder}/${NameOffMRI}_nonlin_norm.nii.gz ${ResultsFolder}/${NameOffMRI}.nii.gz
${RUN} cp ${fMRIFolder}/${NameOffMRI}_SBRef_nonlin_norm.nii.gz ${ResultsFolder}/${NameOffMRI}_SBRef.nii.gz
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

log_Msg "Completed!"

