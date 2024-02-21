#!/bin/bash 

# Requirements for this script
#  installed versions of: FSL, gradunwarp (HCP version)
#  environment: HCPPIPEDIR, FSLDIR, HCPPIPEDIR_Global, PATH for gradient_unwarp.py

# -----------------------------------------------------------------------------------
#  Constants for specification of Averaging and Readout Distortion Correction Method
# -----------------------------------------------------------------------------------

SIEMENS_METHOD_OPT="SiemensFieldMap"

GE_HEALTHCARE_LEGACY_METHOD_OPT="GEHealthCareLegacyFieldMap"
# "GEHealthCareLegacyFieldMap" refers to fieldmap in the form of a single NIfTI file 
# with 2 volumes in it (volume-1: the Fieldmap in Hertz; volume-2: the magnitude image). 
# Note: dcm2niix (pre-v1.0.20210410) used to convert the GEHC B0Maps in this format (a single NIFTI file with 2 volumes). 

GE_HEALTHCARE_METHOD_OPT="GEHealthCareFieldMap"
# "GEHealthCareFieldMap" refers to fieldmap in the form of 2 separate NIfTI files.
# One file with the Fieldmap in Hz and another file with the magnitude image). 
# Note: dcm2niix (v1.0.20210410 and later) convert the GEHC B0Maps as 2 separate NIFTI files
# using the suffix '_fieldmaphz' for the fieldmap in Hz and no suffix for the magnitude image. 

PHILIPS_METHOD_OPT="PhilipsFieldMap"

set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

# Load function libraries
source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/fsl_version.shlib"          # FSL-version checks functions

opts_SetScriptDescription "Script for generating a fieldmap suitable for FSL from a dual-echo Gradient Echo field map acquisition, and also do gradient non-linearity distortion correction of these"

opts_AddMandatory '--method' 'DistortionCorrection' 'method' "method to use for susceptibility distortion correction (SDC)
        '${SIEMENS_METHOD_OPT}'
             use Siemens specific Gradient Echo Field Maps for SDC
        '${GE_HEALTHCARE_LEGACY_METHOD_OPT}'
             use GE HealthCare Legacy specific Gradient Echo Field Maps for SDC (field map in Hz and magnitude image in a single NIfTI file, via --fmapcombined argument).
        '${GE_HEALTHCARE_METHOD_OPT}'
             use GE HealthCare specific Gradient Echo Field Maps for SDC (field map in Hz and magnitude image in two separate NIfTI files).
        '${PHILIPS_METHOD_OPT}'
             use Philips specific Gradient Echo Field Maps for SDC"

opts_AddMandatory '--ofmapmag' 'MagnitudeOutput' 'image' "output distortion corrected fieldmap magnitude image"

opts_AddMandatory '--ofmapmagbrain' 'MagnitudeBrainOutput' 'image' "output distortion-corrected brain-extracted fieldmap magnitude image"

opts_AddMandatory '--ofmap' 'FieldMapOutput' 'image' "output distortion corrected fieldmap image (rad/s)"

# options --echodiff is now mandatory; used by all "--method" options (and necessary for processing of all vendors). 
opts_AddMandatory '--echodiff' 'DeltaTE' 'number (milliseconds)' "echo time difference for fieldmap images (in milliseconds)"

# Optional Arguments
opts_AddOptional '--fmapcombined' 'GEB0InputName' 'image (Hz and magnitude)' "GE HealthCare Legacy fieldmap with field map in Hz and magnitude image included as two volumes in a single file" '' '--fmap'

opts_AddOptional '--fmapphase' 'PhaseInputName' 'image (radians or Hz)' "phase image in radians for Siemens/Philips fieldmap and in Hertz for GE HealthCare fieldmap"

opts_AddOptional '--fmapmag' 'MagnitudeInputName' 'image' "Siemens/Philips/GE HealthCare fieldmap magnitude image; multiple volumes (i.e., magnitude images from both echoes) are allowed"

opts_AddOptional '--workingdir' 'WD' 'path' 'working dir' "."

opts_AddOptional '--gdcoeffs' 'GradientDistortionCoeffs' 'path' "gradient distortion coefficients file" "NONE"

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

log_Check_Env_Var FSLDIR

case $DistortionCorrection in

    $SIEMENS_METHOD_OPT)

        # --------------------------------------
        # -- Siemens Gradient Echo Field Maps --
        # --------------------------------------
        if [[ $MagnitudeInputName == "" ||  $PhaseInputName == "" ]]
        then 
            log_Err_Abort "$DistortionCorrection method requires --fmapmag and --fmapphase"
        fi
        ;;

    ${GE_HEALTHCARE_LEGACY_METHOD_OPT})

        # ---------------------------------------------------
        # -- GE HealthCare Legacy Gradient Echo Field Maps --
        # --------------------------------------------------- 

        if [[ $GEB0InputName == "" ]]
        then 
            log_Err_Abort "$DistortionCorrection method requires --fmapcombined"
        fi
        
        # Check that FSL is at least the minimum required FSL version, abort if needed (and log FSL-version)
        # GEHEALTHCARE_MINIMUM_FSL_VERSION defined in global/scripts/fsl_version.shlib
        fsl_minimum_required_version_check "$GEHEALTHCARE_MINIMUM_FSL_VERSION" \
            "For $DistortionCorrection method the minimum required FSL version is ${GEHEALTHCARE_MINIMUM_FSL_VERSION}."

        ;;

    ${GE_HEALTHCARE_METHOD_OPT})
        
        # --------------------------------------------
        # -- GE HealthCare Gradient Echo Field Maps --
        # --------------------------------------------

        if [[ $MagnitudeInputName == "" ||  $PhaseInputName == "" ]]
        then 
            log_Err_Abort "$DistortionCorrection method requires --fmapmag and --fmapphase"
        fi
        
        # Check that FSL is at least the minimum required FSL version, abort if needed (and log FSL-version)
        # GEHEALTHCARE_MINIMUM_FSL_VERSION defined in global/scripts/fsl_version.shlib
        fsl_minimum_required_version_check "$GEHEALTHCARE_MINIMUM_FSL_VERSION" \
            "For $DistortionCorrection method the minimum required FSL version is ${GEHEALTHCARE_MINIMUM_FSL_VERSION}."
        
        ;;

    ${PHILIPS_METHOD_OPT})

        # --------------------------------------
        # -- Philips Gradient Echo Field Maps --
        # --------------------------------------
        if [[ $MagnitudeInputName == "" ||  $PhaseInputName == "" ]]
        then 
            log_Err_Abort "$DistortionCorrection method requires --fmapmag and --fmapphase"
        fi
        ;;

    *)
        log_Err "Unable to create FSL-suitable readout distortion correction field map"
        log_Err_Abort "Unrecognized distortion correction method: ${DistortionCorrection}"
esac

# default parameters
GlobalScripts=${HCPPIPEDIR_Global}

log_Msg "Field Map Preprocessing and Gradient Unwarping"
log_Msg "START"

mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt

########################################## DO WORK ########################################## 

case $DistortionCorrection in

    $SIEMENS_METHOD_OPT)

        # --------------------------------------
        # -- Siemens Gradient Echo Field Maps --
        # --------------------------------------

        ${FSLDIR}/bin/fslmaths ${MagnitudeInputName} -Tmean ${WD}/Magnitude
        ${FSLDIR}/bin/bet ${WD}/Magnitude ${WD}/Magnitude_brain -f 0.35 -m #Brain extract the magnitude image
        ${FSLDIR}/bin/imcp ${PhaseInputName} ${WD}/Phase
        ${FSLDIR}/bin/fsl_prepare_fieldmap SIEMENS ${WD}/Phase ${WD}/Magnitude_brain ${WD}/FieldMap ${DeltaTE}

        ;;

    ${GE_HEALTHCARE_LEGACY_METHOD_OPT})

        # ---------------------------------------------------
        # -- GE HealthCare Legacy Gradient Echo Field Maps --
        # --------------------------------------------------- 

        ${FSLDIR}/bin/fslsplit ${GEB0InputName}     # split image into vol0000=fieldmap and vol0001=magnitude
        ${FSLDIR}/bin/immv vol0000 ${WD}/FieldMapHertz
        ${FSLDIR}/bin/immv vol0001 ${WD}/Magnitude
        ${FSLDIR}/bin/bet ${WD}/Magnitude ${WD}/Magnitude_brain -f 0.35 -m #Brain extract the magnitude image
        ${FSLDIR}/bin/fsl_prepare_fieldmap GEHC_FIELDMAPHZ ${WD}/FieldMapHertz ${WD}/Magnitude_brain ${WD}/FieldMap ${DeltaTE}

        ;;
    ${GE_HEALTHCARE_METHOD_OPT})

        # --------------------------------------------
        # -- GE HealthCare Gradient Echo Field Maps --
        # -------------------------------------------- 
        	
        ${FSLDIR}/bin/fslmaths ${MagnitudeInputName} -Tmean ${WD}/Magnitude #normally only one volume 
        ${FSLDIR}/bin/bet ${WD}/Magnitude ${WD}/Magnitude_brain -f 0.35 -m #Brain extract the magnitude image
        ${FSLDIR}/bin/imcp ${PhaseInputName} ${WD}/FieldMapHertz
        ${FSLDIR}/bin/fsl_prepare_fieldmap GEHC_FIELDMAPHZ ${WD}/FieldMapHertz ${WD}/Magnitude_brain ${WD}/FieldMap ${DeltaTE}

        ;;
    ${PHILIPS_METHOD_OPT})

        # --------------------------------------
        # -- Philips Gradient Echo Field Maps --
        # --------------------------------------

        ${FSLDIR}/bin/fslmaths ${MagnitudeInputName} -Tmean ${WD}/Magnitude
        # Brain extract the magnitude image
        ${FSLDIR}/bin/bet ${WD}/Magnitude ${WD}/Magnitude_brain -f 0.35 -m
        ${FSLDIR}/bin/fslmaths ${WD}/Magnitude_brain -ero ${WD}/Magnitude_brain_ero
        rm ${WD}/Magnitude_brain.nii.gz
        mv ${WD}/Magnitude_brain_ero.nii.gz ${WD}/Magnitude_brain.nii.gz

        # Take the absolute value of the magnitude data (some images used negative values for the coding)
        ${FSLDIR}/bin/fslmaths ${WD}/Magnitude_brain.nii.gz -abs ${WD}/Magnitude_brain.nii.gz
        # Create a binary brain mask
        ${FSLDIR}/bin/fslmaths ${WD}/Magnitude_brain.nii.gz -thr 0.00000001 -bin ${WD}/Mask_brain.nii.gz
        # Convert fieldmap in Hz to rad/s
        $FSLDIR/bin/fslmaths ${PhaseInputName} -mul 6.28318 -mas ${WD}/Mask_brain.nii.gz ${WD}/FieldMap_rad_per_s -odt float

        # If echodiff was passed unwrap the fieldmap
        if [ ! -z $DeltaTE ] && [ $DeltaTE != "NONE" ]
        then
            # DeltaTE is echo time difference in ms
            asym=`echo ${DeltaTE} / 1000 | bc -l`
            # Convert fieldmap in rad/s back to phasediff image in rad for unwrapping
            $FSLDIR/bin/fslmaths ${WD}/FieldMap_rad_per_s -mul $asym -mas ${WD}/Mask_brain.nii.gz ${WD}/Phasediff_rad -odt float
            # Unwrap fieldmap
            $FSLDIR/bin/prelude -p ${WD}/Phasediff_rad -a ${WD}/Magnitude_brain.nii.gz -m ${WD}/Mask_brain.nii.gz -o ${WD}/Phasediff_rad_unwrapped -v
            # Convert to fiedlmap in rads/sec
            $FSLDIR/bin/fslmaths ${WD}/Phasediff_rad_unwrapped -div $asym ${WD}/FieldMap_rad_per_s -odt float 
        fi

        # Call FUGUE to extrapolate from mask (fill holes, etc)
        $FSLDIR/bin/fugue --loadfmap=${WD}/FieldMap_rad_per_s --mask=${WD}/Mask_brain.nii.gz --savefmap=${WD}/FieldMap.nii.gz
        # Demean the image (avoid voxel translation)
        $FSLDIR/bin/fslmaths ${WD}/FieldMap.nii.gz -sub `${FSLDIR}/bin/fslstats ${WD}/FieldMap.nii.gz -k ${WD}/Mask_brain.nii.gz -P 50` -mas ${WD}/Mask_brain.nii.gz ${WD}/FieldMap.nii.gz -odt float

        ;;

    *)
        log_Err "Unable to create FSL-suitable readout distortion correction field map"
        log_Err_Abort "Unrecognized distortion correction method: ${DistortionCorrection}"
esac

log_Msg "DONE: fsl_prepare_fieldmap.sh"

if [ ! $GradientDistortionCoeffs = "NONE" ] ; then
  ${GlobalScripts}/GradientDistortionUnwarp.sh \
      --workingdir=${WD} \
      --coeffs=${GradientDistortionCoeffs} \
      --in=${WD}/Magnitude \
      --out=${WD}/Magnitude_gdc \
      --owarp=${WD}/Magnitude_gdc_warp
      
  ${FSLDIR}/bin/applywarp --rel --interp=nn -i ${WD}/Magnitude_brain -r ${WD}/Magnitude_brain -w ${WD}/Magnitude_gdc_warp -o ${WD}/Magnitude_brain_gdc
  ${FSLDIR}/bin/fslmaths ${WD}/Magnitude_gdc -mas ${WD}/Magnitude_brain_gdc ${WD}/Magnitude_brain_gdc
  ${FSLDIR}/bin/fslmaths ${WD}/Magnitude_brain_gdc -bin -ero -ero ${WD}/Magnitude_brain_gdc_ero
  ${FSLDIR}/bin/fslmaths ${WD}/FieldMap -mas ${WD}/Magnitude_brain_gdc_ero -dilM -dilM -dilM -dilM -dilM ${WD}/FieldMap_dil
  ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/FieldMap_dil -r ${WD}/FieldMap_dil -w ${WD}/Magnitude_gdc_warp -o ${WD}/FieldMap_gdc
  ${FSLDIR}/bin/fslmaths ${WD}/FieldMap_gdc -mas ${WD}/Magnitude_brain_gdc ${WD}/FieldMap_gdc

  ${FSLDIR}/bin/imcp ${WD}/Magnitude_gdc ${MagnitudeOutput}
  ${FSLDIR}/bin/imcp ${WD}/Magnitude_brain_gdc ${MagnitudeBrainOutput}
  cp ${WD}/FieldMap_gdc.nii.gz ${FieldMapOutput}.nii.gz
else
  ${FSLDIR}/bin/imcp ${WD}/Magnitude ${MagnitudeOutput}
  ${FSLDIR}/bin/imcp ${WD}/Magnitude_brain ${MagnitudeBrainOutput}
  cp ${WD}/FieldMap.nii.gz ${FieldMapOutput}.nii.gz
fi

log_Msg "Field Map Preprocessing and Gradient Unwarping"
log_Msg "END"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ########################################## 

if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# Check the brain extraction and distortion correction of the fieldmap magnitude image" >> $WD/qa.txt
echo "fslview ${WD}/Magnitude ${MagnitudeOutput} ${MagnitudeBrainOutput} -l Red -t 0.5" >> $WD/qa.txt
echo "# Check the range (largish values around 600 rad/s) and general smoothness/look of fieldmap (should be large in inferior/temporal areas mainly)" >> $WD/qa.txt
echo "fslview ${FieldMapOutput}" >> $WD/qa.txt

##############################################################################################

