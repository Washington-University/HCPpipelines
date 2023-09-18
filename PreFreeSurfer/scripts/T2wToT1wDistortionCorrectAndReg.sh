#!/bin/bash 
set -e
# Requirements for this script
#  installed versions of: FSL (version 5.0.6), HCP-gradunwarp (HCP version 1.0.2)
#  environment: FSLDIR and PATH for gradient_unwarp.py

SCRIPT_NAME="T2WToT1wDistortionCorrectAndReg.sh"

# -----------------------------------------------------------------------------------
#  Constants for specification of Averaging and Readout Distortion Correction Method
# -----------------------------------------------------------------------------------

SIEMENS_METHOD_OPT="SiemensFieldMap"
SPIN_ECHO_METHOD_OPT="TOPUP"
GENERAL_ELECTRIC_METHOD_OPT="GeneralElectricFieldMap"
FIELDMAP_METHOD_OPT="FIELDMAP"

################################################ SUPPORT FUNCTIONS ##################################################

Usage() {
  echo "`basename $0`: Script for performing gradient-nonlinearity and susceptibility-inducted distortion correction on T1w and T2w images, then also registering T2w to T1w"
  echo " "
  echo "Usage: `basename $0` [--workingdir=<working directory>]"
  echo "            --t1=<input T1w image>"
  echo "            --t1brain=<input T1w brain-extracted image>"
  echo "            --t2=<input T2w image>"
  echo "            --t2brain=<input T2w brain-extracted image>"
  echo "            [--fmapmag=<input fieldmap magnitude image>]"
  echo "            [--fmapphase=<input fieldmap phase images (single 4D image containing 2x3D volumes)>]"
  echo "            [--fmapgeneralelectric=<input General Electric field map (two volumes: 1. field map in deg, 2. magnitude)>]"
  echo "            [--echodiff=<echo time difference for fieldmap images (in milliseconds)>]"
  echo "            [--SEPhaseNeg=<input spin echo negative phase encoding image>]"
  echo "            [--SEPhasePos=<input spin echo positive phase encoding image>]"
  echo "            [--echospacing=<effective echo spacing of fMRI image, in seconds>]"
  echo "            [--seunwarpdir=<direction of distortion according to voxel axes>]"
  echo "            --t1sampspacing=<sample spacing (readout direction) of T1w image - in seconds>"
  echo "            --t2sampspacing=<sample spacing (readout direction) of T2w image - in seconds>"
  echo "            --unwarpdir=<direction of distortion according to voxel axes (post reorient2std)>"
  echo "            --ot1=<output corrected T1w image>"
  echo "            --ot1brain=<output corrected, brain-extracted T1w image>"
  echo "            --ot1warp=<output warpfield for distortion correction of T1w image>"
  echo "            --ot2=<output corrected T2w image>"
  echo "            --ot2brain=<output corrected, brain-extracted T2w image>"
  echo "            --ot2warp=<output warpfield for distortion correction of T2w image>"
  echo "            --method=<method used for readout distortion correction>"
  echo ""
  echo "                ${FIELDMAP_METHOD_OPT}"
  echo "                  equivalent to ${SIEMENS_METHOD_OPT} (see below)"
  echo "                  ${SIEMENS_METHOD_OPT} is preferred. This option is maintained for"
  echo "                  backward compatibility."
  echo "                ${SPIN_ECHO_METHOD_OPT}"
  echo "                  use Spin Echo Field Maps for readout distortion correction"
  echo "                ${GENERAL_ELECTRIC_METHOD_OPT}"
  echo "                  use General Electric specific Gradient Echo Field Maps for"
  echo "                  readout distortion correction"
  echo "                ${SIEMENS_METHOD_OPT}"
  echo "                  use Siemens specific Gradient Echo Field Maps for readout"
  echo "                  distortion correction"
  echo ""
  echo "            [--topupconfig=<topup config file>]"
  echo "            [--gdcoeffs=<gradient distortion coefficients (SIEMENS file)>]"
}

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib

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

################################################### OUTPUT FILES #####################################################

# For distortion correction:
#
# Output files (in $WD): Magnitude  Magnitude_brain  Phase  FieldMap
#                        Magnitude_brain_warpedT1w  Magnitude_brain_warpedT1w2${TXwImageBrainBasename}
#                        fieldmap2${T1wImageBrainBasename}.mat   FieldMap2${T1wImageBrainBasename}
#                        FieldMap2${T1wImageBrainBasename}_ShiftMap  
#                        FieldMap2${T1wImageBrainBasename}_Warp ${T1wImageBasename}  ${T1wImageBrainBasename}
#        Plus the versions with T1w -> T2w
#
# Output files (not in $WD):  ${OutputT1wTransform}   ${OutputT1wImage}  ${OutputT1wImageBrain}
#        Note that these outputs are actually copies of the last three entries in the $WD list
#
#
# For registration:
#
# Output images (in $WD/T2w2T1w):  sqrtT1wbyT2w  T2w_reg.mat  T2w_reg_init.mat
#                                  T2w_dc_reg  (the warp field)
#                                  T2w_reg     (the warped image)
# Output images (not in $WD):  ${OutputT2wTransform}   ${OutputT2wImage}
#        Note that these outputs are copies of the last two images (respectively) from the T2w2T1w subdirectory

################################################## OPTION PARSING #####################################################

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options
if [ $# -lt 17 ] ; then Usage; exit 1; fi

# parse arguments
WD=`getopt1 "--workingdir" $@`  
T1wImage=`getopt1 "--t1" $@`  
T1wImageBrain=`getopt1 "--t1brain" $@`  
T2wImage=`getopt1 "--t2" $@` 
T2wImageBrain=`getopt1 "--t2brain" $@`  
MagnitudeInputName=`getopt1 "--fmapmag" $@`  
PhaseInputName=`getopt1 "--fmapphase" $@`  
GEB0InputName=`getopt1 "--fmapgeneralelectric" $@` 
TE=`getopt1 "--echodiff" $@`  
SpinEchoPhaseEncodeNegative=`getopt1 "--SEPhaseNeg" $@`  
SpinEchoPhaseEncodePositive=`getopt1 "--SEPhasePos" $@`  
DwellTime=`getopt1 "--echospacing" $@` 
SEUnwarpDir=`getopt1 "--seunwarpdir" $@`  
T1wSampleSpacing=`getopt1 "--t1sampspacing" $@`  
T2wSampleSpacing=`getopt1 "--t2sampspacing" $@`  
UnwarpDir=`getopt1 "--unwarpdir" $@`  
OutputT1wImage=`getopt1 "--ot1" $@`  
OutputT1wImageBrain=`getopt1 "--ot1brain" $@`  
OutputT1wTransform=`getopt1 "--ot1warp" $@`  
OutputT2wImage=`getopt1 "--ot2" $@`  
OutputT2wTransform=`getopt1 "--ot2warp" $@`  
DistortionCorrection=`getopt1 "--method" $@`  
TopupConfig=`getopt1 "--topupconfig" $@`  
GradientDistortionCoeffs=`getopt1 "--gdcoeffs" $@`  
UseJacobian=`getopt1 "--usejacobian" $@`

# default parameters
WD=`defaultopt $WD .`

T1wImage=`${FSLDIR}/bin/remove_ext $T1wImage`
T1wImageBrain=`${FSLDIR}/bin/remove_ext $T1wImageBrain`
T2wImage=`${FSLDIR}/bin/remove_ext $T2wImage`
T2wImageBrain=`${FSLDIR}/bin/remove_ext $T2wImageBrain`

T1wImageBrainBasename=`basename "$T1wImageBrain"`
T1wImageBasename=`basename "$T1wImage"`
T2wImageBrainBasename=`basename "$T2wImageBrain"`
T2wImageBasename=`basename "$T2wImage"`

Modalities="T1w T2w"

log_Msg " START: ${SCRIPT_NAME}"

mkdir -p $WD
mkdir -p ${WD}/FieldMap

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt


########################################## DO WORK ########################################## 

case $DistortionCorrection in

    ${FIELDMAP_METHOD_OPT} | ${SIEMENS_METHOD_OPT})
    
        # --------------------------------------
        # -- Siemens Gradient Echo Field Maps --
        # --------------------------------------

        ### Create fieldmaps (and apply gradient non-linearity distortion correction)
        echo " "
        echo " "
        echo " "

        ${HCPPIPEDIR_Global}/SiemensFieldMapPreprocessingAll.sh \
            --workingdir=${WD}/FieldMap \
            --fmapmag=${MagnitudeInputName} \
            --fmapphase=${PhaseInputName} \
            --echodiff=${TE} \
            --ofmapmag=${WD}/Magnitude \
            --ofmapmagbrain=${WD}/Magnitude_brain \
            --ofmap=${WD}/FieldMap \
            --gdcoeffs=${GradientDistortionCoeffs}

        ;;

    ${GENERAL_ELECTRIC_METHOD_OPT})

        # -----------------------------------------------
        # -- General Electric Gradient Echo Field Maps --
        # -----------------------------------------------

        ### Create fieldmaps (and apply gradient non-linearity distortion correction)
        echo " "
        echo " " 
        echo " " 

        ${HCPPIPEDIR_Global}/GeneralElectricFieldMapPreprocessingAll.sh \
            --workingdir=${WD}/FieldMap \
            --fmap=${GEB0InputName} \
            --ofmapmag=${WD}/Magnitude \
            --ofmapmagbrain=${WD}/Magnitude_brain \
            --ofmap=${WD}/FieldMap \
            --gdcoeffs=${GradientDistortionCoeffs}

        ;;

    ${SPIN_ECHO_METHOD_OPT})

        # --------------------------
        # -- Spin Echo Field Maps --  
        # --------------------------

        if [[ ${SEUnwarpDir} = "x" || ${SEUnwarpDir} = "y" ]] ; then
          ScoutInputName="${SpinEchoPhaseEncodePositive}"
        elif [[ ${SEUnwarpDir} = "-x" || ${SEUnwarpDir} = "-y" || ${SEUnwarpDir} = "x-" || ${SEUnwarpDir} = "y-" ]] ; then
          ScoutInputName="${SpinEchoPhaseEncodeNegative}"
        fi
	# added T2w as a phase zero volume - TH Jan 2023
        if [ $(imtest $(dirname $T1wImage)/../T2w/T2w.nii.gz) = 1 ] ; then
              PhaseZero=$(dirname $T1wImage)/../T2w/T2w.nii.gz
        else
              PhaseZero=NONE
        fi

        # Use topup to distortion correct the scout scans
        #    using a blip-reversed SE pair "fieldmap" sequence
        ${HCPPIPEDIR_Global}/TopupPreprocessingAll.sh \
            --workingdir=${WD}/FieldMap \
            --phaseone=${SpinEchoPhaseEncodeNegative} \
            --phasetwo=${SpinEchoPhaseEncodePositive} \
            --scoutin=${ScoutInputName} \
            --echospacing=${DwellTime} \
            --unwarpdir=${SEUnwarpDir} \
            --ofmapmag=${WD}/Magnitude \
            --ofmapmagbrain=${WD}/Magnitude_brain \
            --ofmap=${WD}/FieldMap \
            --ojacobian=${WD}/Jacobian \
            --gdcoeffs=${GradientDistortionCoeffs} \
            --topupconfig=${TopupConfig} \
	    --phasezero=${PhaseZero} \
            --usejacobian=${UseJacobian}
        ;;

    *)
        echo "${SCRIPT_NAME} - ERROR - Unable to create FSL-suitable readout distortion correction field map"
        echo "${SCRIPT_NAME}           Unrecognized distortion correction method: ${DistortionCorrection}"
        exit 1
esac

if [ "${UnwarpDir}" = "-x" ] ; then
  UnwarpDir="x-"
fi

if [ "${UnwarpDir}" = "-y" ] ; then
  UnwarpDir="y-"
fi

if [ "${UnwarpDir}" = "-z" ] ; then
  UnwarpDir="z-"
fi

### LOOP over available modalities ###

for TXw in $Modalities ; do
    # set up required variables
    if [ $TXw = T1w ] ; then
	TXwImage=$T1wImage
	TXwImageBrain=$T1wImageBrain
	TXwSampleSpacing=$T1wSampleSpacing
	TXwImageBasename=$T1wImageBasename
	TXwImageBrainBasename=$T1wImageBrainBasename
    else
	TXwImage=$T2wImage
	TXwImageBrain=$T2wImageBrain
	TXwSampleSpacing=$T2wSampleSpacing
	TXwImageBasename=$T2wImageBasename
	TXwImageBrainBasename=$T2wImageBrainBasename
    fi

    if [ "${TXwImage}" = "NONE" ] ; then
      verbose_echo "      ... Skipping $TXw"
      continue
    else
      verbose_echo "      ... $TXw"
    fi

    # Forward warp the fieldmap magnitude and register to TXw image (transform phase image too)
    ${FSLDIR}/bin/fugue --loadfmap=${WD}/FieldMap --dwell=${TXwSampleSpacing} --saveshift=${WD}/FieldMap_ShiftMap${TXw}.nii.gz    
    ${FSLDIR}/bin/convertwarp --relout --rel --ref=${WD}/Magnitude --shiftmap=${WD}/FieldMap_ShiftMap${TXw}.nii.gz --shiftdir=${UnwarpDir} --out=${WD}/FieldMap_Warp${TXw}.nii.gz    

    case $DistortionCorrection in
        ${FIELDMAP_METHOD_OPT} | ${SIEMENS_METHOD_OPT} | ${GENERAL_ELECTRIC_METHOD_OPT})
          ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/Magnitude -r ${WD}/Magnitude -w ${WD}/FieldMap_Warp${TXw}.nii.gz -o ${WD}/Magnitude_warped${TXw}
          if [[ ! $SPECIES =~ Marmoset ]] ; then
            ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/Magnitude_warped${TXw} -ref ${TXwImage}.nii.gz -out ${WD}/Magnitude_warped${TXw}2${TXwImageBasename} -omat ${WD}/Fieldmap2${TXwImageBasename}.mat -searchrx -30 30 -searchry -30 30 -searchrz -30 30
          else
            ${CARET7DIR}/wb_command -convert-affine -from-world ${FSLDIR}/etc/flirtsch/ident.mat -to-flirt ${WD}/Fieldmap2${TXw}.mat ${WD}/Magnitude.nii.gz ${WD}/../../${TXw}/${TXw}.nii.gz
            ${FSLDIR}/bin/convert_xfm -omat ${WD}/Fieldmap2${TXwImageBasename}_init.mat -concat ${WD}/../../${TXw}/xfms/acpc.mat ${WD}/Fieldmap2${TXw}.mat
            ${FSLDIR}/bin/flirt -in  ${WD}/Magnitude_warped${TXw} -ref ${TXwImage} -applyxfm -init ${WD}/Fieldmap2${TXwImageBasename}_init.mat -interp spline -out ${WD}/Magnitude_warped${TXw}2${TXwImageBasename}_init
            ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/Magnitude_warped${TXw}2${TXwImageBasename}_init -ref ${TXwImage} -out ${WD}/Magnitude_warped${TXw}2${TXwImageBasename} -omat ${WD}/Fieldmap2${TXwImageBasename}_tmp.mat -finesearch 2
            ${FSLDIR}/bin/convert_xfm -omat ${WD}/Fieldmap2${TXwImageBasename}.mat -concat ${WD}/Fieldmap2${TXwImageBasename}_tmp.mat  ${WD}/Fieldmap2${TXwImageBasename}_init.mat
            rm -f ${WD}/Fieldmap2${TXwImageBasename}_tmp.mat                        
          fi
            ;;

        ${SPIN_ECHO_METHOD_OPT})
          if [[ ! $SPECIES =~ Marmoset ]] ; then
            ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/Magnitude_brain -r ${WD}/Magnitude_brain -w ${WD}/FieldMap_Warp${TXw}.nii.gz -o ${WD}/Magnitude_brain_warped${TXw}
            ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/Magnitude_brain_warped${TXw} -ref ${TXwImageBrain} -out ${WD}/Magnitude_brain_warped${TXw}2${TXwImageBasename} -omat ${WD}/Fieldmap2${TXwImageBasename}.mat -searchrx -30 30 -searchry -30 30 -searchrz -30 30
          else  # Marmoset data does not work well for BET-based brain extraction, thus start from the head image and scanner coordinates
            ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/Magnitude -r ${WD}/Magnitude -w ${WD}/FieldMap_Warp${TXw}.nii.gz -o ${WD}/Magnitude_warped${TXw}
            # Register fieldmap to ACPC space assuming that head is not much moving during scans between SEfield and structure
            ${CARET7DIR}/wb_command -convert-affine -from-world ${FSLDIR}/etc/flirtsch/ident.mat -to-flirt ${WD}/Fieldmap2${TXw}.mat ${WD}/Magnitude.nii.gz ${WD}/../../${TXw}/${TXw}.nii.gz
            ${FSLDIR}/bin/convert_xfm -omat ${WD}/Fieldmap2${TXwImageBasename}_init.mat -concat ${WD}/../../${TXw}/xfms/acpc.mat ${WD}/Fieldmap2${TXw}.mat
            ${FSLDIR}/bin/flirt -in ${WD}/Magnitude_warped${TXw} -ref ${TXwImage} -applyxfm -init ${WD}/Fieldmap2${TXwImageBasename}_init.mat -interp spline -out ${WD}/Magnitude_warped${TXw}2${TXwImageBasename}_init

            # Brain extract fieldmap assuming that head is not much moving during scans between SEField and structure
            ${FSLDIR}/bin/fslmaths ${TXwImageBrain} -bin -dilM -dilM -dilM ${WD}/${TXw}_acpc_brain_mask_dil
            ${FSLDIR}/bin/fslmaths ${WD}/Magnitude_warped${TXw}2${TXwImageBasename}_init -mas ${WD}/${TXw}_acpc_brain_mask_dil ${WD}/Magnitude_warped${TXw}2${TXwImageBasename}_init_brain

            # Fine-tuning resitration with BBR for T1w - but does not work for marmoset TH Apr 20223
            #if [[ ${TXw} = T1w ]] ; then
            #      ${FSLDIR}/bin/fast -o ${WD}/${TXw}_acpc_fast -l 10 -n 3 ${TXwImageBrain}     #NHP data generally has strong bias
            #      $FSLDIR/bin/fslmaths ${WD}/${TXw}_acpc_fast_pve_2 -thr 0.5 -bin ${WD}/${TXw}_acpc_wmseg
            #      $FSLDIR/bin/fslmaths ${WD}/${TXw}_acpc_wmseg -edge -bin -mas ${WD}/${TXw}_acpc_wmseg ${WD}/${TXw}_acpc_wmedge
            #      $FSLDIR/bin/imrm ${WD}/${TXw}_acpc_fast_mixeltype ${WD}/${TXw}_acpc_fast_pve* ${WD}/${TXw}_acpc_fast_seg
            #      Cost="-cost bbr -wmseg ${WD}/${TXw}_acpc_wmseg"
            #      Schedule="-schedule ${FSLDIR}/etc/flirtsch/bbr.sch"
            #else
          	    Cost=""
          	    Schedule=""
            #fi
            # Register fieldmap magnitude (head) to structure
            ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/Magnitude_warped${TXw}2${TXwImageBasename}_init -ref ${TXwImage} -out ${WD}/Magnitude_warped${TXw}2${TXwImageBasename}_TMP1 -omat ${WD}/Fieldmap2${TXwImageBasename}_TMP1.mat -nosearch $Cost $Schedule

            ${FSLDIR}/bin/flirt -in ${WD}/Magnitude_warped${TXw}2${TXwImageBasename}_init -ref ${TXwImage} -schedule $FSLDIR/etc/flirtsch/measurecost1.sch -init ${WD}/Fieldmap2${TXwImageBasename}_TMP1.mat $Cost | head -1 | cut -f1 -d' ' >  ${WD}/Magnitude_warped${TXw}2${TXwImageBasename}_cost.txt
            ${FSLDIR}/bin/flirt -in ${WD}/Magnitude_warped${TXw}2${TXwImageBasename}_init_brain -ref ${TXwImageBrain} -schedule $FSLDIR/etc/flirtsch/measurecost1.sch -init ${WD}/Fieldmap2${TXwImageBasename}_TMP1.mat $Cost | head -1 | cut -f1 -d' ' >>  ${WD}/Magnitude_warped${TXw}2${TXwImageBasename}_cost.txt
            # Register fieldmap magnitude (brain) to structure
            ${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${WD}/Magnitude_warped${TXw}2${TXwImageBasename}_init_brain -ref ${TXwImageBrain} -out ${WD}/Magnitude_warped${TXw}2${TXwImageBasename}_TMP2 -omat ${WD}/Fieldmap2${TXwImageBasename}_TMP2.mat -nosearch $Cost $Schedule
            ${FSLDIR}/bin/flirt -in ${WD}/Magnitude_warped${TXw}2${TXwImageBasename}_init -ref ${TXwImage} -schedule $FSLDIR/etc/flirtsch/measurecost1.sch -init ${WD}/Fieldmap2${TXwImageBasename}_TMP2.mat $Cost | head -1 | cut -f1 -d' ' >>  ${WD}/Magnitude_warped${TXw}2${TXwImageBasename}_cost.txt
            ${FSLDIR}/bin/flirt -in ${WD}/Magnitude_warped${TXw}2${TXwImageBasename}_init_brain -ref ${TXwImageBrain} -schedule $FSLDIR/etc/flirtsch/measurecost1.sch -init ${WD}/Fieldmap2${TXwImageBasename}_TMP2.mat $Cost | head -1 | cut -f1 -d' ' >>  ${WD}/Magnitude_warped${TXw}2${TXwImageBasename}_cost.txt
            # Find smaller mincost registration matrix between those for brain and head and use it to concat matrices
            MinCost=($(cat ${WD}/Magnitude_warped${TXw}2${TXwImageBasename}_cost.txt))
            if [[ $(echo "${MinCost[1]} < ${MinCost[3]}" | bc ) == 1 ]] ; then
               MinMat=${WD}/Fieldmap2${TXwImageBasename}_TMP1.mat
            else
               MinMat=${WD}/Fieldmap2${TXwImageBasename}_TMP2.mat
            fi
            ${FSLDIR}/bin/convert_xfm -omat ${WD}/Fieldmap2${TXwImageBasename}.mat -concat ${MinMat}  ${WD}/Fieldmap2${TXwImageBasename}_init.mat
            # Resampling with the concat matrix
            ${FSLDIR}/bin/flirt -in ${WD}/Magnitude_warped${TXw} -ref ${TXwImage} -applyxfm -init ${WD}/Fieldmap2${TXwImageBasename}.mat -interp spline -out ${WD}/Magnitude_warped${TXw}2${TXwImageBasename}            
            #rm -f ${WD}/Fieldmap2${TXwImageBasename}_TMP1.mat ${WD}/Fieldmap2${TXwImageBasename}_TMP2.mat ${WD}/Fieldmap2${TXwImageBasename}_TMP1.nii.gz ${WD}/Fieldmap2${TXwImageBasename}_TMP2.nii.gz
          fi
           ;;

        *)
            echo "${SCRIPT_NAME} - ERROR - Unable to apply readout distortion correction"
            echo "${SCRIPT_NAME}           Unrecognized distortion correction method: ${DistortionCorrection}"
            exit 1
    esac
    
    ${FSLDIR}/bin/flirt -in ${WD}/FieldMap.nii.gz -ref ${TXwImage} -applyxfm -init ${WD}/Fieldmap2${TXwImageBasename}.mat -out ${WD}/FieldMap2${TXwImageBasename}
    
    # Convert to shift map then to warp field and unwarp the TXw
    ${FSLDIR}/bin/fugue --loadfmap=${WD}/FieldMap2${TXwImageBasename} --dwell=${TXwSampleSpacing} --saveshift=${WD}/FieldMap2${TXwImageBasename}_ShiftMap.nii.gz    
    ${FSLDIR}/bin/convertwarp --relout --rel --ref=${TXwImageBrain} --shiftmap=${WD}/FieldMap2${TXwImageBasename}_ShiftMap.nii.gz --shiftdir=${UnwarpDir} --out=${WD}/FieldMap2${TXwImageBasename}_Warp.nii.gz    
    ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${TXwImage} -r ${TXwImage} -w ${WD}/FieldMap2${TXwImageBasename}_Warp.nii.gz -o ${WD}/${TXwImageBasename}

    # Make a brain image (transform to make a mask, then apply it)
    ${FSLDIR}/bin/applywarp --rel --interp=nn -i ${TXwImageBrain} -r ${TXwImageBrain} -w ${WD}/FieldMap2${TXwImageBasename}_Warp.nii.gz -o ${WD}/${TXwImageBrainBasename} 
    ${FSLDIR}/bin/fslmaths ${WD}/${TXwImageBasename} -mas ${WD}/${TXwImageBrainBasename} ${WD}/${TXwImageBrainBasename}

    # Copy files to specified destinations
    if [ $TXw = T1w ] ; then 
       ${FSLDIR}/bin/imcp ${WD}/FieldMap2${TXwImageBasename}_Warp ${OutputT1wTransform}
       ${FSLDIR}/bin/imcp ${WD}/${TXwImageBasename} ${OutputT1wImage}
       ${FSLDIR}/bin/imcp ${WD}/${TXwImageBrainBasename} ${OutputT1wImageBrain}
    fi

done

### END LOOP over modalities ###

if [ "${T2wImage}" == "NONE" ] ; then
  verbose_echo ""
  verbose_red_echo " ---> Skipping T2w to T1w registration"

else
        
  verbose_echo ""
  verbose_red_echo " ---> Running T2w to T1w registration"

  ### Create tentative biasfield corrected image - TH Jan 2021, improved T2w to T1w reg for high-res T1w and T2w
  mkdir -p ${WD}/T2w2T1w
  PipelineScripts=${HCPPIPEDIR_PreFS}
  if [ ! -z ${BiasFieldSmoothingSigma} ] ; then
  	BiasFieldSmoothingSigma="--bfsigma=${BiasFieldSmoothingSigma}"
  fi
  ${PipelineScripts}/BiasFieldCorrection_sqrtT1wXT2w_RIKEN.sh \
    --workingdir=${WD}/T2w2T1w/BiasFieldCorrection_sqrtT1wXT2w \
    --T1im=${WD}/${T1wImageBasename} \
    --T1brain=${WD}/${T1wImageBrainBasename} \
    --T2im=${WD}/${T2wImageBasename} \
    --obias=${WD}/T2w2T1w/BiasField_acpc \
    --oT1im=${WD}/${T1wImageBasename}_restore \
    --oT1brain=${WD}/${T1wImageBasename}_restore_brain \
    --oT2im=${WD}/${T2wImageBasename}_restore \
    --oT2brain=${WD}/${T2wImageBasename}_restore_brain \
    ${BiasFieldSmoothingSigma}

  ### Now do T2w to T1w registration
  # Main registration: between corrected T2w and corrected T1w
  #${FSLDIR}/bin/epi_reg --epi=${WD}/${T2wImageBrainBasename} --t1=${WD}/${T1wImageBasename} --t1brain=${WD}/${T1wImageBrainBasename} --out=${WD}/T2w2T1w/T2w_reg
  ${FSLDIR}/bin/epi_reg --epi=${WD}/${T2wImageBasename}_restore_brain --t1=${WD}/${T1wImageBasename}_restore --t1brain=${WD}/${T1wImageBasename}_restore_brain --out=${WD}/T2w2T1w/T2w_reg
  
  # Make a warpfield directly from original (non-corrected) T2w to corrected T1w  (and apply it)
  ${FSLDIR}/bin/convertwarp --relout --rel --ref=${T1wImage} --warp1=${WD}/FieldMap2${T2wImageBasename}_Warp.nii.gz --postmat=${WD}/T2w2T1w/T2w_reg.mat -o ${WD}/T2w2T1w/T2w_dc_reg
    
  ${FSLDIR}/bin/applywarp --rel --interp=spline --in=${T2wImage} --ref=${T1wImage} --warp=${WD}/T2w2T1w/T2w_dc_reg --out=${WD}/T2w2T1w/T2w_reg
   
  # Add 1 to avoid exact zeros within the image (a problem for myelin mapping?)
  ${FSLDIR}/bin/fslmaths ${WD}/T2w2T1w/T2w_reg.nii.gz -add 1 ${WD}/T2w2T1w/T2w_reg.nii.gz -odt float

  # QA image
  #${FSLDIR}/bin/fslmaths ${WD}/T2w2T1w/T2w_reg -mul ${T1wImage} -sqrt ${WD}/T2w2T1w/sqrtT1wbyT2w -odt float
  ${FSLDIR}/bin/fslmaths ${WD}/T2w2T1w/T2w_reg -mul ${WD}/${T1wImageBasename}_restore -sqrt ${WD}/T2w2T1w/sqrtT1wbyT2w -odt float
  # Copy files to specified destinations
  ${FSLDIR}/bin/imcp ${WD}/T2w2T1w/T2w_dc_reg ${OutputT2wTransform}
  ${FSLDIR}/bin/imcp ${WD}/T2w2T1w/T2w_reg ${OutputT2wImage}
fi

log_Msg " END: ${SCRIPT_NAME}"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ########################################## 

if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# View registration result of corrected T2w to corrected T1w image: showing both images + sqrt(T1w*T2w)" >> $WD/qa.txt
echo "fslview ${OutputT1wImage} ${OutputT2wImage} ${WD}/T2w2T1w/sqrtT1wbyT2w" >> $WD/qa.txt
echo "# Compare pre- and post-distortion correction for T1w" >> $WD/qa.txt
echo "fslview ${T1wImage} ${OutputT1wImage}" >> $WD/qa.txt
echo "# Compare pre- and post-distortion correction for T2w" >> $WD/qa.txt
echo "fslview ${T2wImage} ${WD}/${T2wImageBasename}" >> $WD/qa.txt

##############################################################################################

