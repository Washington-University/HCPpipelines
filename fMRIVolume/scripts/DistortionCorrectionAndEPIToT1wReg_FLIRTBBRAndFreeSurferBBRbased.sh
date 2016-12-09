#!/bin/bash 
set -e

# Requirements for this script
#  installed versions of: FSL (version 5.0.6) and FreeSurfer (version 5.3.0-HCP)
#  environment: FSLDIR, FREESURFER_HOME + others

# ---------------------------------------------------------------------
#  Constants for specification of Readout Distortion Correction Method
# ---------------------------------------------------------------------

FIELDMAP_METHOD_OPT="FIELDMAP"
SIEMENS_METHOD_OPT="SiemensFieldMap"
GENERAL_ELECTRIC_METHOD_OPT="GeneralElectricFieldMap"
SPIN_ECHO_METHOD_OPT="TOPUP"

################################################ SUPPORT FUNCTIONS ##################################################

# --------------------------------------------------------------------------------
#  Load Function Libraries
# --------------------------------------------------------------------------------

source $HCPPIPEDIR_Global/log.shlib # Logging related functions

Usage() {
  echo "`basename $0`: Script to register EPI to T1w, with distortion correction"
  echo " "
  echo "Usage: `basename $0` [--workingdir=<working dir>]"
  echo "             --scoutin=<input scout image (pre-sat EPI)>"
  echo "             --t1=<input T1-weighted image>"
  echo "             --t1restore=<input bias-corrected T1-weighted image>"
  echo "             --t1brain=<input bias-corrected, brain-extracted T1-weighted image>"
  echo "             --fmapmag=<input Siemens field map magnitude image>"
  echo "             --fmapphase=<input Siemens field map phase image>"
  echo "             --fmapgeneralelectric=<input General Electric field map image>"
  echo "             --echodiff=<difference of echo times for fieldmap, in milliseconds>"
  echo "             --SEPhaseNeg=<input spin echo negative phase encoding image>"
  echo "             --SEPhasePos=<input spin echo positive phase encoding image>"
  echo "             --echospacing=<effective echo spacing of fMRI image, in seconds>"
  echo "             --unwarpdir=<unwarping direction: x/y/z/-x/-y/-z>"
  echo "             --owarp=<output filename for warp of EPI to T1w>"
  echo "             --biasfield=<input T1w bias field estimate image, in fMRI space>"
  echo "             --oregim=<output registered image (EPI to T1w)>"
  echo "             --freesurferfolder=<directory of FreeSurfer folder>"
  echo "             --freesurfersubjectid=<FreeSurfer Subject ID>"
  echo "             --gdcoeffs=<gradient non-linearity distortion coefficients (Siemens format)>"
  echo "             [--qaimage=<output name for QA image>]"
  echo ""
  echo "             --method=<method used for readout distortion correction>"
  echo ""
  echo "               \"${FIELDMAP_METHOD_OPT}\""
  echo "                 equivalent to ${SIEMENS_METHOD_OPT} (see below)"
  echo ""
  echo "               \"${SIEMENS_METHOD_OPT}\""
  echo "                 use Siemens specific Gradient Echo Field Maps for"
  echo "                 readout distortion correction"
  echo ""
  echo "               \"${SPIN_ECHO_METHOD_OPT}\""
  echo "                 use Spin Echo Field Maps for readout distortion correction"
  echo ""
  echo "               \"${GENERAL_ELECTRIC_METHOD_OPT}\""
  echo "                 use General Electric specific Gradient Echo Field Maps"
  echo "                 for readout distortion correction"
  echo ""
  echo "             [--topupconfig=<topup config file>]"
  echo "             --ojacobian=<output filename for Jacobian image (in T1w space)>"
  echo "             --dof=<degrees of freedom for EPI-T1 FLIRT> (default 6)"
  echo "             --fmriname=<name of fmri run> (only needed for SEBASED bias correction method)"
  echo "             --subjectfolder=<subject processing folder> (only needed for TOPUP distortion correction method)"
  echo "             --biascorrection=<method of bias correction>"
  echo ""
  echo "               \"SEBASED\""
  echo "                 use bias field derived from spin echo, must also use --method=${SPIN_ECHO_METHOD_OPT}"
  echo ""
  echo "               \"LEGACY\""
  echo "                 use the bias field derived from T1w and T2w images, same as pipeline version 3.14.1 or older"
  echo ""
  echo "               \"NONE\""
  echo "                 don't do bias correction"
  echo ""
  echo "             --usejacobian=<\"true\" or \"false\">"
}

# function for parsing options
getopt1() {
    sopt="$1"
    shift 1
    for fn in $@ ; do
        if [ `echo $fn | grep -- "^${sopt}=" | wc -w` -gt 0 ] ; then
            echo $fn | sed "s/^${sopt}=//"
            return 0
        fi
    done
}

defaultopt() {
    echo $1
}

# --------------------------------------------------------------------------------
#  Establish tool name for logging
# --------------------------------------------------------------------------------

log_SetToolName "DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased.sh"

################################################### OUTPUT FILES #####################################################

# Outputs (in $WD):
#  
#    FIELDMAP, SiemensFieldMap, and GeneralElectricFieldMap: 
#      Magnitude  Magnitude_brain  FieldMap
#
#    FIELDMAP and TOPUP sections: 
#      Jacobian2T1w
#      ${ScoutInputFile}_undistorted  
#      ${ScoutInputFile}_undistorted2T1w_init   
#      ${ScoutInputFile}_undistorted_warp
#
#    FreeSurfer section: 
#      fMRI2str.mat  fMRI2str
#      ${ScoutInputFile}_undistorted2T1w  
#
# Outputs (not in $WD):
#
#       ${RegOutput}  ${OutputTransform}  ${JacobianOut}  ${QAImage}

################################################## OPTION PARSING #####################################################


# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options
if [ $# -lt 21 ] ; then Usage; exit 1; fi

# parse arguments
WD=`getopt1 "--workingdir" $@`
ScoutInputName=`getopt1 "--scoutin" $@`
T1wImage=`getopt1 "--t1" $@`
T1wRestoreImage=`getopt1 "--t1restore" $@`
T1wBrainImage=`getopt1 "--t1brain" $@`
SpinEchoPhaseEncodeNegative=`getopt1 "--SEPhaseNeg" $@`
SpinEchoPhaseEncodePositive=`getopt1 "--SEPhasePos" $@`
DwellTime=`getopt1 "--echospacing" $@`
MagnitudeInputName=`getopt1 "--fmapmag" $@`
PhaseInputName=`getopt1 "--fmapphase" $@`
GEB0InputName=`getopt1 "--fmapgeneralelectric" $@`
deltaTE=`getopt1 "--echodiff" $@`
UnwarpDir=`getopt1 "--unwarpdir" $@`
OutputTransform=`getopt1 "--owarp" $@`
BiasField=`getopt1 "--biasfield" $@`
RegOutput=`getopt1 "--oregim" $@`
FreeSurferSubjectFolder=`getopt1 "--freesurferfolder" $@`
FreeSurferSubjectID=`getopt1 "--freesurfersubjectid" $@`
GradientDistortionCoeffs=`getopt1 "--gdcoeffs" $@`
QAImage=`getopt1 "--qaimage" $@`
DistortionCorrection=`getopt1 "--method" $@`
TopupConfig=`getopt1 "--topupconfig" $@`
JacobianOut=`getopt1 "--ojacobian" $@`
dof=`getopt1 "--dof" $@`
NameOffMRI=`getopt1 "--fmriname" $@`
SubjectFolder=`getopt1 "--subjectfolder" $@`
BiasCorrection=`getopt1 "--biascorrection" $@`
UseJacobian=`getopt1 "--usejacobian" $@`

if [[ -n $HCPPIPEDEBUG ]]
then
    set -x
fi

#error check bias correction opt
case "$BiasCorrection" in
    NONE)
        UseBiasField=""
    ;;
    
    LEGACY)
        UseBiasField="${BiasField}"
    ;;
    
    SEBASED)
        if [[ "$DistortionCorrection" != "${SPIN_ECHO_METHOD_OPT}" ]]
        then
            log_Msg "SEBASED bias correction is only available with --method=${SPIN_ECHO_METHOD_OPT}"
            exit 1
        fi
        #note, this file doesn't exist yet, gets created by ComputeSpinEchoBiasField.sh
        UseBiasField="${WD}/ComputeSpinEchoBiasField/${NameOffMRI}_sebased_bias.nii.gz"
    ;;
    
    "")
        log_Msg "--biascorrection option not specified"
        exit 1
    ;;
    
    *)
        log_Msg "unrecognized value for bias correction: $BiasCorrection"
        exit 1
esac


ScoutInputFile=`basename $ScoutInputName`
T1wBrainImageFile=`basename $T1wBrainImage`

# default parameters
RegOutput=`$FSLDIR/bin/remove_ext $RegOutput`
WD=`defaultopt $WD ${RegOutput}.wdir`
dof=`defaultopt $dof 6`
GlobalScripts=${HCPPIPEDIR_Global}
TopupConfig=`defaultopt $TopupConfig ${HCPPIPEDIR_Config}/b02b0.cnf`

#sanity check the jacobian option
if [[ "$UseJacobian" != "true" && "$UseJacobian" != "false" ]]
then
    log_Msg "the --usejacobian option must be 'true' or 'false'"
    exit 1
fi

log_Msg "START"

mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt

if [ ! -e ${WD}/FieldMap ] ; then
  mkdir ${WD}/FieldMap
fi

########################################## DO WORK ########################################## 

cp ${T1wBrainImage}.nii.gz ${WD}/${T1wBrainImageFile}.nii.gz

case $DistortionCorrection in

    ${FIELDMAP_METHOD_OPT} | ${SIEMENS_METHOD_OPT} | ${GENERAL_ELECTRIC_METHOD_OPT})

        if [ $DistortionCorrection = "${FIELDMAP_METHOD_OPT}" ] || [ $DistortionCorrection = "${SIEMENS_METHOD_OPT}" ] ; then
            # --------------------------------------
            # -- Siemens Gradient Echo Field Maps --
            # --------------------------------------

            # process fieldmap with gradient non-linearity distortion correction
            ${GlobalScripts}/SiemensFieldMapPreprocessingAll.sh \
                --workingdir=${WD}/FieldMap \
                --fmapmag=${MagnitudeInputName} \
                --fmapphase=${PhaseInputName} \
                --echodiff=${deltaTE} \
                --ofmapmag=${WD}/Magnitude \
                --ofmapmagbrain=${WD}/Magnitude_brain \
                --ofmap=${WD}/FieldMap \
                --gdcoeffs=${GradientDistortionCoeffs}

        elif [ $DistortionCorrection = "${GENERAL_ELECTRIC_METHOD_OPT}" ] ; then
            # -----------------------------------------------
            # -- General Electric Gradient Echo Field Maps --
            # -----------------------------------------------

            # process fieldmap with gradient non-linearity distortion correction
            ${GlobalScripts}/GeneralElectricFieldMapPreprocessingAll.sh \
                --workingdir=${WD}/FieldMap \
                --fmap=${GEB0InputName} \
                --ofmapmag=${WD}/Magnitude \
                --ofmapmagbrain=${WD}/Magnitude_brain \
                --ofmap=${WD}/FieldMap \
                --gdcoeffs=${GradientDistortionCoeffs}

        else
            log_Msg "Script programming error. Unhandled Distortion Correction Method: ${DistortionCorrection}"
            exit 1
        fi

        cp ${ScoutInputName}.nii.gz ${WD}/Scout.nii.gz

        # Test if Magnitude Brain and T1w Brain Are Similar in Size, if not, assume Magnitude Brain Extraction 
        # Failed and Must Be Retried After Removing Bias Field
        MagnitudeBrainSize=`${FSLDIR}/bin/fslstats ${WD}/Magnitude_brain -V | cut -d " " -f 2`
        T1wBrainSize=`${FSLDIR}/bin/fslstats ${WD}/${T1wBrainImageFile} -V | cut -d " " -f 2`

        if [[ X`echo "if ( (${MagnitudeBrainSize} / ${T1wBrainSize}) > 1.25 ) {1}" | bc -l` = X1 || X`echo "if ( (${MagnitudeBrainSize} / ${T1wBrainSize}) < 0.75 ) {1}" | bc -l` = X1 ]] ; then
            ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/Magnitude.nii.gz -ref ${T1wImage} -omat "$WD"/Mag2T1w.mat -out ${WD}/Magnitude2T1w.nii.gz -searchrx -30 30 -searchry -30 30 -searchrz -30 30
            ${FSLDIR}/bin/convert_xfm -omat "$WD"/T1w2Mag.mat -inverse "$WD"/Mag2T1w.mat
            ${FSLDIR}/bin/applywarp --interp=nn -i ${WD}/${T1wBrainImageFile} -r ${WD}/Magnitude.nii.gz --premat="$WD"/T1w2Mag.mat -o ${WD}/Magnitude_brain_mask.nii.gz    
            fslmaths ${WD}/Magnitude_brain_mask.nii.gz -bin ${WD}/Magnitude_brain_mask.nii.gz
            fslmaths ${WD}/Magnitude.nii.gz -mas ${WD}/Magnitude_brain_mask.nii.gz ${WD}/Magnitude_brain.nii.gz

            ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/Scout.nii.gz -ref ${T1wImage} -omat "$WD"/Scout2T1w.mat -out ${WD}/Scout2T1w.nii.gz -searchrx -30 30 -searchry -30 30 -searchrz -30 30
            ${FSLDIR}/bin/convert_xfm -omat "$WD"/T1w2Scout.mat -inverse "$WD"/Scout2T1w.mat
            ${FSLDIR}/bin/applywarp --interp=nn -i ${WD}/${T1wBrainImageFile} -r ${WD}/Scout.nii.gz --premat="$WD"/T1w2Scout.mat -o ${WD}/Scout_brain_mask.nii.gz    
            fslmaths ${WD}/Scout_brain_mask.nii.gz -bin ${WD}/Scout_brain_mask.nii.gz
            fslmaths ${WD}/Scout.nii.gz -mas ${WD}/Scout_brain_mask.nii.gz ${WD}/Scout_brain.nii.gz
       
            # register scout to T1w image using fieldmap
            ${HCPPIPEDIR_Global}/epi_reg_dof --dof=${dof} --epi=${WD}/Scout_brain.nii.gz --t1=${T1wImage} --t1brain=${WD}/${T1wBrainImageFile} --out=${WD}/${ScoutInputFile}_undistorted --fmap=${WD}/FieldMap.nii.gz --fmapmag=${WD}/Magnitude.nii.gz --fmapmagbrain=${WD}/Magnitude_brain.nii.gz --echospacing=${DwellTime} --pedir=${UnwarpDir}

        else
            # register scout to T1w image using fieldmap
            ${HCPPIPEDIR_Global}/epi_reg_dof --dof=${dof} --epi=${WD}/Scout.nii.gz --t1=${T1wImage} --t1brain=${WD}/${T1wBrainImageFile} --out=${WD}/${ScoutInputFile}_undistorted --fmap=${WD}/FieldMap.nii.gz --fmapmag=${WD}/Magnitude.nii.gz --fmapmagbrain=${WD}/Magnitude_brain.nii.gz --echospacing=${DwellTime} --pedir=${UnwarpDir}

        fi

        # create spline interpolated output for scout to T1w + apply bias field correction
        ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${ScoutInputName} -r ${T1wImage} -w ${WD}/${ScoutInputFile}_undistorted_warp.nii.gz -o ${WD}/${ScoutInputFile}_undistorted_1vol.nii.gz
        ${FSLDIR}/bin/immv ${WD}/${ScoutInputFile}_undistorted_1vol.nii.gz ${WD}/${ScoutInputFile}_undistorted2T1w_init.nii.gz
        ${FSLDIR}/bin/immv ${WD}/${ScoutInputFile}_undistorted_warp.nii.gz ${WD}/${ScoutInputFile}_undistorted2T1w_init_warp.nii.gz
        cp "${WD}/${ScoutInputFile}_undistorted_init.mat" "${WD}/${ScoutInputFile}_undistorted2T1w_init.mat"
        #real jacobian, of just fieldmap warp (from epi_reg_dof)
        #NOTE: convertwarp requires an output argument regardless
        ${FSLDIR}/bin/convertwarp --rel -w ${WD}/${ScoutInputFile}_undistorted2T1w_init_warp.nii.gz -r ${WD}/${ScoutInputFile}_undistorted2T1w_init_warp.nii.gz --jacobian=${WD}/Jacobian2T1w.nii.gz -o ${WD}/junk_warp
        #but, convertwarp's --jacobian output has 8 volumes, as it outputs all combinations of one-sided differences
        #so, average them together
        ${FSLDIR}/bin/fslmaths ${WD}/Jacobian2T1w.nii.gz -Tmean ${WD}/Jacobian2T1w.nii.gz
        ${FSLDIR}/bin/imcp ${WD}/Jacobian2T1w.nii.gz ${WD}/Jacobian.nii.gz
        
        #jacobian and bias field are applied outside the case, as they are done the same as topup
        ;;

    ${SPIN_ECHO_METHOD_OPT})
    
        # --------------------------
        # -- Spin Echo Field Maps --
        # --------------------------

        # Use topup to distortion correct the scout scans
        # using a blip-reversed SE pair "fieldmap" sequence
        ${GlobalScripts}/TopupPreprocessingAll.sh \
            --workingdir=${WD}/FieldMap \
            --phaseone=${SpinEchoPhaseEncodeNegative} \
            --phasetwo=${SpinEchoPhaseEncodePositive} \
            --scoutin=${ScoutInputName} \
            --echospacing=${DwellTime} \
            --unwarpdir=${UnwarpDir} \
            --owarp=${WD}/WarpField \
            --ojacobian=${WD}/Jacobian \
            --gdcoeffs=${GradientDistortionCoeffs} \
            --topupconfig=${TopupConfig} \
            --usejacobian=${UseJacobian}

        #If NHP, brain extract scout for registration
        if [ -e ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}_1mm ] ; then
            cp ${ScoutInputName}.nii.gz ${WD}/Scout.nii.gz
            ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/Scout.nii.gz -ref ${T1wImage} -omat "$WD"/Scout2T1w.mat -out ${WD}/Scout2T1w.nii.gz -searchrx -30 30 -searchry -30 30 -searchrz -30 30
            ${FSLDIR}/bin/convert_xfm -omat "$WD"/T1w2Scout.mat -inverse "$WD"/Scout2T1w.mat
            ${FSLDIR}/bin/applywarp --interp=nn -i ${WD}/${T1wBrainImageFile} -r ${ScoutInputName} --premat="$WD"/T1w2Scout.mat -o ${WD}/Scout_brain_mask.nii.gz    
            fslmaths ${WD}/Scout_brain_mask.nii.gz -bin ${WD}/Scout_brain_mask.nii.gz
            fslmaths ${WD}/Scout.nii.gz -mas ${WD}/Scout_brain_mask.nii.gz ${WD}/Scout_brain.nii.gz

            # create a spline interpolated image of scout (distortion corrected in same space)
            log_Msg "create a spline interpolated image of scout (distortion corrected in same space)"
            ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/Scout_brain.nii.gz -r ${WD}/Scout_brain.nii.gz -w ${WD}/WarpField.nii.gz -o ${WD}/${ScoutInputFile}_undistorted
        else
            # create a spline interpolated image of scout (distortion corrected in same space)
            log_Msg "create a spline interpolated image of scout (distortion corrected in same space)"
            ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${ScoutInputName} -r ${ScoutInputName} -w ${WD}/WarpField.nii.gz -o ${WD}/${ScoutInputFile}_undistorted
        fi
        
        # apply Jacobian correction to scout image (optional)
        # gdc jacobian is already applied in main script, where the gdc call for the scout is
        if [[ $UseJacobian == "true" ]]
        then
            log_Msg "apply Jacobian correction to scout image"
            ${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFile}_undistorted -mul ${WD}/Jacobian.nii.gz ${WD}/${ScoutInputFile}_undistorted
        fi

        # register undistorted scout image to T1w
        # this is just an initial registration, refined later in this script, but it is actually pretty good
        log_Msg "register undistorted scout image to T1w"
        ${HCPPIPEDIR_Global}/epi_reg_dof --dof=${dof} --epi=${WD}/${ScoutInputFile}_undistorted --t1=${T1wImage} --t1brain=${WD}/${T1wBrainImageFile} --out=${WD}/${ScoutInputFile}_undistorted2T1w_init

        #copy the initial registration into the final affine's filename, as it is pretty good
        #we need something to get between the spaces to compute an initial bias field
        cp "${WD}/${ScoutInputFile}_undistorted2T1w_init.mat" "${WD}/fMRI2str.mat"

        # generate combined warpfields and spline interpolated images + apply bias field correction
        log_Msg "generate combined warpfields and spline interpolated images and apply bias field correction"
        ${FSLDIR}/bin/convertwarp --relout --rel -r ${T1wImage} --warp1=${WD}/WarpField.nii.gz --postmat=${WD}/${ScoutInputFile}_undistorted2T1w_init.mat -o ${WD}/${ScoutInputFile}_undistorted2T1w_init_warp
        ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/Jacobian.nii.gz -r ${T1wImage} --premat=${WD}/${ScoutInputFile}_undistorted2T1w_init.mat -o ${WD}/Jacobian2T1w.nii.gz
        #1-step resample from input (gdc) scout - NOTE: no longer includes jacobian correction, if specified
        ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${ScoutInputName} -r ${T1wImage} -w ${WD}/${ScoutInputFile}_undistorted2T1w_init_warp -o ${WD}/${ScoutInputFile}_undistorted2T1w_init
        
        #resample phase images to T1w space
        #these files were obtained by the import script from the FieldMap directory, save them into the package and resample them
        #we don't have the final transform to actual T1w space yet, that occurs later in this script
        #but, we need the T1w segmentation to make the bias field, so use the initial registration above, then compute the bias field again at the end
        Files="PhaseOne_gdc_dc PhaseTwo_gdc_dc SBRef_dc"
        for File in ${Files}
        do
            #NOTE: this relies on TopupPreprocessingAll generating _jac versions of the files
            if [[ $UseJacobian == "true" ]]
            then
                ${FSLDIR}/bin/applywarp --interp=spline -i "${WD}/FieldMap/${File}_jac" -r ${SubjectFolder}/T1w/T2w_acpc_dc.nii.gz --premat=${WD}/fMRI2str.mat -o ${WD}/${File}
            else
                ${FSLDIR}/bin/applywarp --interp=spline -i "${WD}/FieldMap/${File}" -r ${SubjectFolder}/T1w/T2w_acpc_dc.nii.gz --premat=${WD}/fMRI2str.mat -o ${WD}/${File}
            fi
        done
        
        #correct filename is already set in UseBiasField, but we have to compute it if using SEBASED
        #we compute it in this script because it needs outputs from topup, and because it should be applied to the scout image
        if [[ "$BiasCorrection" == "SEBASED" ]]
        then
            mkdir -p "$WD/ComputeSpinEchoBiasField"
            "${HCPPIPEDIR_fMRIVol}/ComputeSpinEchoBiasField.sh" \
                --workingdir="$WD/ComputeSpinEchoBiasField" \
                --subjectfolder="$SubjectFolder" \
                --fmriname="$NameOffMRI" \
                --corticallut="$HCPPIPEDIR/global/config/FreeSurferCorticalLabelTableLut.txt" \
                --subcorticallut="$HCPPIPEDIR/global/config/FreeSurferSubcorticalLabelTableLut.txt" \
                --smoothingfwhm="2" \
                --inputdir="$WD"
        fi
            

        ;;

    *)

        log_Msg "UNKNOWN DISTORTION CORRECTION METHOD: ${DistortionCorrection}"
        exit 1

esac

# apply Jacobian correction and bias correction options to scout image
if [[ $UseJacobian == "true" ]] ; then
    log_Msg "apply Jacobian correction to scout image"
    if [[ "$UseBiasField" != "" ]]
    then
        ${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFile}_undistorted2T1w_init -div ${UseBiasField} -mul ${WD}/Jacobian2T1w.nii.gz ${WD}/${ScoutInputFile}_undistorted2T1w_init.nii.gz
    else
        ${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFile}_undistorted2T1w_init -mul ${WD}/Jacobian2T1w.nii.gz ${WD}/${ScoutInputFile}_undistorted2T1w_init.nii.gz
    fi
else
    log_Msg "do not apply Jacobian correction to scout image"
    if [[ "$UseBiasField" != "" ]]
    then
        ${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFile}_undistorted2T1w_init -div ${UseBiasField} ${WD}/${ScoutInputFile}_undistorted2T1w_init.nii.gz
    fi
    #these all overwrite the input, no 'else' needed for "do nothing"
fi


### FREESURFER BBR - found to be an improvement, probably due to better GM/WM boundary
SUBJECTS_DIR=${FreeSurferSubjectFolder}
export SUBJECTS_DIR
#Check to see if FreeSurferNHP.sh was used
log_Msg "Check to see if FreeSurferNHP.sh was used"
if [ -e ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}_1mm ] ; then
  #Perform Registration in FreeSurferNHP 1mm Space
  log_Msg "${FreeSurferSubjectFolder}/${FreeSurferSubjectID}_1mm exists. FreeSurferNHP.sh was used."
  log_Msg "Perform Registration in FreeSurferNHP 1mm Space"
  ScoutImage="${WD}/${ScoutInputFile}_undistorted2T1w_init.nii.gz"
  ScoutImageFile="${WD}/${ScoutInputFile}_undistorted2T1w_init"

  res=`fslorient -getsform $ScoutImage | cut -d " " -f 1 | cut -d "-" -f 2`
  oldsform=`fslorient -getsform $ScoutImage`
  newsform=""
  i=1
  while [ $i -le 12 ] ; do
    oldelement=`echo $oldsform | cut -d " " -f $i`
    newelement=`echo "scale=1; $oldelement / $res" | bc -l`
    newsform=`echo "$newsform""$newelement"" "`
    if [ $i -eq 4 ] ; then
      originx="$newelement"
    fi
    if [ $i -eq 8 ] ; then
      originy="$newelement"
    fi
    if [ $i -eq 12 ] ; then
      originz="$newelement"
    fi
    i=$(($i+1))
  done
  newsform=`echo "$newsform""0 0 0 1" | sed 's/  / /g'`

  cp "$ScoutImage" "$ScoutImageFile"_1mm.nii.gz
  fslorient -setsform $newsform "$ScoutImageFile"_1mm.nii.gz
  fslhd -x "$ScoutImageFile"_1mm.nii.gz | sed s/"dx = '${res}'"/"dx = '1'"/g | sed s/"dy = '${res}'"/"dy = '1'"/g | sed s/"dz = '${res}'"/"dz = '1'"/g | fslcreatehd - "$ScoutImageFile"_1mm_head.nii.gz
  fslmaths "$ScoutImageFile"_1mm_head.nii.gz -add "$ScoutImageFile"_1mm.nii.gz "$ScoutImageFile"_1mm.nii.gz
  fslorient -copysform2qform "$ScoutImageFile"_1mm.nii.gz
  rm "$ScoutImageFile"_1mm_head.nii.gz
  dimex=`fslval "$ScoutImageFile"_1mm dim1`
  dimey=`fslval "$ScoutImageFile"_1mm dim2`
  dimez=`fslval "$ScoutImageFile"_1mm dim3`
  padx=`echo "(256 - $dimex) / 2" | bc`
  pady=`echo "(256 - $dimey) / 2" | bc`
  padz=`echo "(256 - $dimez) / 2" | bc`
  fslcreatehd $padx $dimey $dimez 1 1 1 1 1 0 0 0 16 "$ScoutImageFile"_1mm_padx
  fslmerge -x "$ScoutImageFile"_1mm "$ScoutImageFile"_1mm_padx "$ScoutImageFile"_1mm "$ScoutImageFile"_1mm_padx
  fslcreatehd 256 $pady $dimez 1 1 1 1 1 0 0 0 16 "$ScoutImageFile"_1mm_pady
  fslmerge -y "$ScoutImageFile"_1mm "$ScoutImageFile"_1mm_pady "$ScoutImageFile"_1mm "$ScoutImageFile"_1mm_pady
  fslcreatehd 256 256 $padz 1 1 1 1 1 0 0 0 16 "$ScoutImageFile"_1mm_padz
  fslmerge -z "$ScoutImageFile"_1mm "$ScoutImageFile"_1mm_padz "$ScoutImageFile"_1mm "$ScoutImageFile"_1mm_padz
  fslorient -setsformcode 1 "$ScoutImageFile"_1mm
  fslorient -setsform -1 0 0 `echo "$originx + $padx" | bc -l` 0 1 0 `echo "$originy - $pady" | bc -l` 0 0 1 `echo "$originz - $padz" | bc -l` 0 0 0 1 "$ScoutImageFile"_1mm
  rm "$ScoutImageFile"_1mm_padx.nii.gz "$ScoutImageFile"_1mm_pady.nii.gz "$ScoutImageFile"_1mm_padz.nii.gz

  # Use "hidden" bbregister DOF options
  log_Msg "Use \"hidden\" bbregister DOF options"
  ${FREESURFER_HOME}/bin/bbregister --s "${FreeSurferSubjectID}_1mm" --mov ${WD}/${ScoutInputFile}_undistorted2T1w_init_1mm.nii.gz --surf white.deformed --init-reg ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}_1mm/mri/transforms/eye.dat --bold --reg ${WD}/EPItoT1w.dat --${dof} --o ${WD}/${ScoutInputFile}_undistorted2T1w_1mm.nii.gz
  tkregister2 --noedit --reg ${WD}/EPItoT1w.dat --mov ${WD}/${ScoutInputFile}_undistorted2T1w_init_1mm.nii.gz --targ ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}_1mm/mri/T1w_hires.nii.gz --fslregout ${WD}/fMRI2str_1mm.mat
  applywarp --interp=spline -i ${WD}/${ScoutInputFile}_undistorted2T1w_init_1mm.nii.gz -r ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}_1mm/mri/T1w_hires.nii.gz --premat=${WD}/fMRI2str_1mm.mat -o ${WD}/${ScoutInputFile}_undistorted2T1w_1mm.nii.gz

  convert_xfm -omat ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}_1mm/mri/transforms/temp.mat -concat ${WD}/fMRI2str_1mm.mat ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}_1mm/mri/transforms/real2fs.mat
  convert_xfm -omat ${WD}/fMRI2str_refinement.mat -concat ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}_1mm/mri/transforms/fs2real.mat ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}_1mm/mri/transforms/temp.mat
  rm ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}_1mm/mri/transforms/temp.mat

else
  log_Msg "${FreeSurferSubjectFolder}/${FreeSurferSubjectID}_1mm does not exist. FreeSurferNHP.sh was not used."

  # Run Normally
  log_Msg "Run Normally" 
  # Use "hidden" bbregister DOF options
  log_Msg "Use \"hidden\" bbregister DOF options"
  ${FREESURFER_HOME}/bin/bbregister --s ${FreeSurferSubjectID} --mov ${WD}/${ScoutInputFile}_undistorted2T1w_init.nii.gz --surf white.deformed --init-reg ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}/mri/transforms/eye.dat --bold --reg ${WD}/EPItoT1w.dat --${dof} --o ${WD}/${ScoutInputFile}_undistorted2T1w.nii.gz
  # Create FSL-style matrix and then combine with existing warp fields
  log_Msg "Create FSL-style matrix and then combine with existing warp fields"
  ${FREESURFER_HOME}/bin/tkregister2 --noedit --reg ${WD}/EPItoT1w.dat --mov ${WD}/${ScoutInputFile}_undistorted2T1w_init.nii.gz --targ ${T1wImage}.nii.gz --fslregout ${WD}/fMRI2str_refinement.mat
fi
${FSLDIR}/bin/convertwarp --relout --rel --warp1=${WD}/${ScoutInputFile}_undistorted2T1w_init_warp.nii.gz --ref=${T1wImage} --postmat=${WD}/fMRI2str_refinement.mat --out=${WD}/fMRI2str.nii.gz

#create final affine from undistorted fMRI space to T1w space, will need it if it making SEBASED bias field
#overwrite old version of ${WD}/fMRI2str.mat, as it was just the initial registration
#${WD}/${ScoutInputFile}_undistorted_initT1wReg.mat is from the above epi_reg_dof, initial registration from fMRI space to T1 space
${FSLDIR}/bin/convert_xfm -omat ${WD}/fMRI2str.mat -concat ${WD}/fMRI2str_refinement.mat ${WD}/${ScoutInputFile}_undistorted2T1w_init.mat

if [[ $DistortionCorrection == $SPIN_ECHO_METHOD_OPT ]]
then
    #resample SE field maps, so we can copy to results directories
    #the MNI space versions get made in OneStepResampling, but they aren't actually 1-step resampled
    #we need them before the final bias field computation
    Files="PhaseOne_gdc_dc PhaseTwo_gdc_dc SBRef_dc"
    for File in ${Files}
    do
        if [[ $UseJacobian == "true" ]]
        then
            ${FSLDIR}/bin/applywarp --interp=spline -i "${WD}/FieldMap/${File}_jac" -r ${SubjectFolder}/T1w/T2w_acpc_dc.nii.gz --premat=${WD}/fMRI2str.mat -o ${WD}/${File}
        else
            ${FSLDIR}/bin/applywarp --interp=spline -i "${WD}/FieldMap/${File}" -r ${SubjectFolder}/T1w/T2w_acpc_dc.nii.gz --premat=${WD}/fMRI2str.mat -o ${WD}/${File}
        fi
    done
        
    if [[ $BiasCorrection == "SEBASED" ]]
    then
        #final bias field computation
        
        #run bias field computation script, go ahead and reuse the same working dir as previous run
        "${HCPPIPEDIR_fMRIVol}/ComputeSpinEchoBiasField.sh" \
            --workingdir="$WD/ComputeSpinEchoBiasField" \
            --subjectfolder="$SubjectFolder" \
            --fmriname="$NameOffMRI" \
            --corticallut="$HCPPIPEDIR/global/config/FreeSurferCorticalLabelTableLut.txt" \
            --subcorticallut="$HCPPIPEDIR/global/config/FreeSurferSubcorticalLabelTableLut.txt" \
            --smoothingfwhm="2" \
            --inputdir="$WD"
        
        #don't need to do anything more with scout, it is 1-step resampled and bias correction, jacobians reapplied
        Files="PhaseOne_gdc_dc PhaseTwo_gdc_dc"
        for File in ${Files}
        do
            #we need to apply the new bias field to them for output
            ${FSLDIR}/bin/fslmaths ${WD}/${File} -div "$UseBiasField" ${WD}/${File}_unbias
            
            #don't need the T1w versions
            #${FSLDIR}/bin/imcp ${WD}/${File}_unbias ${SubjectFolder}/T1w/Results/${NameOffMRI}/${NameOffMRI}_${File}
        done
        
        #copy bias field and dropouts, etc to results dir
        ${FSLDIR}/bin/imcp "$WD/ComputeSpinEchoBiasField/${NameOffMRI}_dropouts" "$SubjectFolder/T1w/Results/$NameOffMRI/${NameOffMRI}_dropouts"
        ${FSLDIR}/bin/imcp "$WD/ComputeSpinEchoBiasField/${NameOffMRI}_sebased_bias" "$SubjectFolder/T1w/Results/$NameOffMRI/${NameOffMRI}_sebased_bias"
        ${FSLDIR}/bin/imcp "$WD/ComputeSpinEchoBiasField/${NameOffMRI}_sebased_reference" "$SubjectFolder/T1w/Results/$NameOffMRI/${NameOffMRI}_sebased_reference"
        
    else
        #don't need to do anything more with scout, it is 1-step resampled and bias correction, jacobians reapplied
        Files="PhaseOne_gdc_dc PhaseTwo_gdc_dc"
        for File in ${Files}
        do
            if [[ $UseBiasField ]]
            then
                #we need to apply the bias field to them for output (really only the phase images, but whatever)
                ${FSLDIR}/bin/fslmaths ${WD}/${File} -div "$UseBiasField" ${WD}/${File}_unbias
            else
                ${FSLDIR}/bin/imcp ${WD}/${File} ${WD}/${File}_unbias
            fi
            #don't need the T1w versions
            #${FSLDIR}/bin/imcp ${WD}/${File}_unbias ${SubjectFolder}/T1w/Results/${NameOffMRI}/${NameOffMRI}_${File}
        done
    fi
fi

# Create warped image with spline interpolation, bias correction and (optional) Jacobian modulation
# NOTE: Jacobian2T1w should be only the topup or fieldmap warpfield's jacobian, not including the gdc warp
# the input scout is the gdc scout, which should already have had the gdc jacobian applied by the main script
log_Msg "Create warped image with spline interpolation, bias correction and (optional) Jacobian modulation"
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${ScoutInputName} -r ${T1wImage}.nii.gz -w ${WD}/fMRI2str.nii.gz -o ${WD}/${ScoutInputFile}_undistorted2T1w

# resample fieldmap jacobian with new registration
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/Jacobian.nii.gz -r ${T1wImage} --premat=${WD}/fMRI2str.mat -o ${WD}/Jacobian2T1w.nii.gz

if [[ $UseJacobian == "true" ]]
then
    log_Msg "applying Jacobian modulation"
    if [[ "$UseBiasField" != "" ]]
    then
        ${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFile}_undistorted2T1w -div ${UseBiasField} -mul ${WD}/Jacobian2T1w.nii.gz ${WD}/${ScoutInputFile}_undistorted2T1w
    else
        ${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFile}_undistorted2T1w -mul ${WD}/Jacobian2T1w.nii.gz ${WD}/${ScoutInputFile}_undistorted2T1w
    fi
else
    log_Msg "not applying Jacobian modulation"
    if [[ "$UseBiasField" != "" ]]
    then
        ${FSLDIR}/bin/fslmaths ${WD}/${ScoutInputFile}_undistorted2T1w -div ${UseBiasField} ${WD}/${ScoutInputFile}_undistorted2T1w
    fi
    #no else, the commands are overwriting their input
fi

log_Msg "cp ${WD}/${ScoutInputFile}_undistorted2T1w.nii.gz ${RegOutput}.nii.gz"
cp ${WD}/${ScoutInputFile}_undistorted2T1w.nii.gz ${RegOutput}.nii.gz

OutputTransformDir=$(dirname ${OutputTransform})
if [ ! -e ${OutputTransformDir} ] ; then
    log_Msg "mkdir -p ${OutputTransformDir}"
    mkdir -p ${OutputTransformDir}
fi

log_Msg "cp ${WD}/fMRI2str.nii.gz ${OutputTransform}.nii.gz"
cp ${WD}/fMRI2str.nii.gz ${OutputTransform}.nii.gz

log_Msg "cp ${WD}/Jacobian2T1w.nii.gz ${JacobianOut}.nii.gz"
cp ${WD}/Jacobian2T1w.nii.gz ${JacobianOut}.nii.gz

# QA image (sqrt of EPI * T1w)
log_Msg 'generating QA image (sqrt of EPI * T1w)'
${FSLDIR}/bin/fslmaths ${T1wRestoreImage}.nii.gz -mul ${RegOutput}.nii.gz -sqrt ${QAImage}.nii.gz

log_Msg "END"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ########################################## 

if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# Check registration of EPI to T1w (with all corrections applied)" >> $WD/qa.txt
echo "fslview ${T1wRestoreImage} ${RegOutput} ${QAImage}" >> $WD/qa.txt
echo "# Check undistortion of the scout image" >> $WD/qa.txt
echo "fslview `dirname ${ScoutInputName}`/GradientDistortionUnwarp/Scout ${WD}/${ScoutInputFile}_undistorted" >> $WD/qa.txt

##############################################################################################

