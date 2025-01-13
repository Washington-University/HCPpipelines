#!/bin/bash 

# Requirements for this script
#  installed versions of: FSL, gradunwarp (HCP version)
#  environment: HCPPIPEDIR, FSLDIR, HCPPIPEDIR_Global, PATH for gradient_unwarp.py

# ------------------------------------------------------------------------------
#  Verify required environment variables are set
# ------------------------------------------------------------------------------

if [ -z "${HCPPIPEDIR}" ]; then
	echo "$(basename ${0}): ABORTING: HCPPIPEDIR environment variable must be set"
	exit 1
else
	echo "$(basename ${0}): HCPPIPEDIR: ${HCPPIPEDIR}"
fi

if [ -z "${FSLDIR}" ]; then
	echo "$(basename ${0}): ABORTING: FSLDIR environment variable must be set"
	exit 1
else
	echo "$(basename ${0}): FSLDIR: ${FSLDIR}"
fi

if [ -z "${HCPPIPEDIR_Global}" ]; then
	echo "$(basename ${0}): ABORTING: HCPPIPEDIR_Global environment variable must be set"
	exit 1
else
	echo "$(basename ${0}): HCPPIPEDIR_Global: ${HCPPIPEDIR_Global}"
fi

################################################ SUPPORT FUNCTIONS ##################################################

# --------------------------------------------------------------------------------
#  Load Function Libraries
# --------------------------------------------------------------------------------

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@" # Debugging functions; also sources log.shlib

Usage() {
  echo "`basename $0`: Script for using topup to do distortion correction for EPI (scout)"
  echo " "
  echo "Usage: `basename $0` [--workingdir=<working directory>]"
  echo "            --phaseone=<first set of SE EPI images: assumed to be the 'negative' PE direction>"
  echo "            --phasetwo=<second set of SE EPI images: assumed to be the 'positive' PE direction>"
  echo "            --scoutin=<scout input image: should be corrected for gradient non-linear distortions>"
  echo "            --echospacing=<effective echo spacing of EPI, in seconds>"
  echo "            --unwarpdir=<PE direction for unwarping according to the *voxel* axes: {x,y,x-,y-} or {i,j,i-,j-}>"
  echo "            --scoutinbrain=<scout input brain image: should be corrected for gradient non-linear distortions>"
  echo "            [--phasezero=<T2w assumed to be the negligible readout time, should be corrected for gradient non-linear distortions>]"
  echo "            [--phaseazerobrainmask=<T2w brainmask>]"
  echo "            [--phaseone2=<first set of SE EPI images of 2nd phase dir: assumed to be the 'negative' PE direction>"
  echo "            [--phasetwo2=<second set of SE EPI images of 2nd phase dir: assumed to be the 'positive' PE direction>"
  echo "            [--owarp=<output warpfield image: scout to distortion corrected SE EPI>]"
  echo "            [--ofmapmag=<output 'Magnitude' image: scout to distortion corrected SE EPI>]" 
  echo "            [--ofmapmagbrain=<output 'Magnitude' brain image: scout to distortion corrected SE EPI>]"   
  echo "            [--ofmap=<output scaled topup field map image>]"
  echo "            [--ojacobian=<output Jacobian image> (of the TOPUP warp field)]"
  echo "            [--scannerpatientposition=<HFS (default), HFP>]"
  echo "            [--truepatientposition=<HFS (default), HFSx, FFSx>]"
  echo "            --gdcoeffs=<gradient non-linearity distortion coefficients (Siemens format)>"
  echo "            [--topupconfig=<topup config file>]"
  echo "            [--initworldmat=<world matrix moving func to structure space>"
  echo "            --usejacobian=<\"true\" or \"false\">"
  echo "                 Whether to apply the jacobian of the gradient non-linearity distortion correction"
  echo "                 Irrelevant if --gdcoeffs=NONE"
  echo "                 (Has nothing to do with the jacobian of the TOPUP warp field)"
  echo " "
  echo "   Note: the input SE EPI images should not be distortion corrected (for gradient non-linearities)"
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

log_SetToolName "TopupPreprocessingAll.sh"

################################################### OUTPUT FILES #####################################################

# Output images (in $WD): 
#          BothPhases      (input to topup - combines both pe direction data, plus masking)
#          SBRef2PhaseOne_gdc.mat SBRef2PhaseOne_gdc   (linear registration result)
#          PhaseOne_gdc  PhaseTwo_gdc
#          PhaseOne_gdc_dc  PhaseOne_gdc_dc_jac  PhaseTwo_gdc_dc  PhaseTwo_gdc_dc_jac
#          SBRef_dc   SBRef_dc_jac
#          WarpField  Jacobian
# Output images (not in $WD): 
#          ${DistortionCorrectionWarpFieldOutput}  ${JacobianOutput}

################################################## OPTION PARSING #####################################################

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options
if [ $# -lt 7 ] ; then Usage; exit 1; fi

# parse arguments
WD=`getopt1 "--workingdir" $@`  # "$1"
PhaseEncodeOne=`getopt1 "--phaseone" $@`  # "$2" #SCRIPT ASSUMES PhaseOne is the 'negative' direction when setting up the acqparams.txt file for TOPUP
PhaseEncodeTwo=`getopt1 "--phasetwo" $@`  # "$3" #SCRIPT ASSUMES PhaseTwo is the 'positive' direction when setting up the acqparams.txt file for TOPUP
ScoutInputName=`getopt1 "--scoutin" $@`  # "$4"
EchoSpacing=`getopt1 "--echospacing" $@`  # "$5"
UnwarpDir=`getopt1 "--unwarpdir" $@`  # "$6"
DistortionCorrectionWarpFieldOutput=`getopt1 "--owarp" $@`  # "$7"
DistortionCorrectionMagnitudeOutput=`getopt1 "--ofmapmag" $@`
DistortionCorrectionMagnitudeBrainOutput=`getopt1 "--ofmapmagbrain" $@`
DistortionCorrectionFieldOutput=`getopt1 "--ofmap" $@`
JacobianOutput=`getopt1 "--ojacobian" $@`  # "$8"
GradientDistortionCoeffs=`getopt1 "--gdcoeffs" $@`  # "$9"
TopupConfig=`getopt1 "--topupconfig" $@`  # "${11}"
UseJacobian=`getopt1 "--usejacobian" $@`
PhaseEncodeZero=`getopt1 "--phasezero" $@` # TH - use T2w
PhaseEncodeOne2=`getopt1 "--phaseone2" $@` # TH - use additional phase
PhaseEncodeTwo2=`getopt1 "--phasetwo2" $@` # TH - use additional phase
ScoutInputBrainName=`getopt1 "--scoutinbrain" $@`  # 

ScannerPatientPosition=`getopt1 "--scannerpatientposition" $@` # TH - scanner's patient position (e.g., HFS, HFP)
TruePatientPosition=`getopt1 "--truepatientposition" $@` # TH - true patient position (e.g., HFS, HFSx, FFSx)
InitWorldMat=`getopt1 "--initworldmat" $@` # TH - init rigid-body transformation matrix in world format moving func to structure space, scanned on different days/sessions.
SpinEchoPhaseEncodeZeroFSBrainmask=`getopt1 "--phasezerobrainmask" $@`

if [[ -n $HCPPIPEDEBUG ]]
then
    set -x
fi

#sanity check the jacobian option
#takes things like "true", "YES", and outputs "1", "NO" is "0", throws error if unrecognized
#copied from newopts as a quick fix
function StringToBool()
{
    case "$(echo "$1" | tr '[:upper:]' '[:lower:]')" in
        (yes | true | 1)
            echo 1
            ;;
        (no | false | 0)
            echo 0
            ;;
        (*)
            log_Err_Abort "unrecognized boolean '$1', please use yes/no, true/false, or 1/0"
            ;;
    esac
}
UseJacobian=$(StringToBool "$UseJacobian")

if [[ "$SPECIES" =~ Human || "$SPECIES" = "" ]] ; then
  species=0
elif [[ "$SPECIES" =~ Chimp ]] ; then
  species=1
elif [[ "$SPECIES" =~ Macaque ]] ; then
  species=2
elif [[ "$SPECIES" =~ Marmoset ]] ; then
  species=3
elif [[ "$SPECIES" =~ NightMonkey ]] ; then
  species=4
fi

GlobalScripts=${HCPPIPEDIR_Global}

# default parameters #Breaks when --owarp becomes optional
#DistortionCorrectionWarpFieldOutput=`$FSLDIR/bin/remove_ext $DistortionCorrectionWarpFieldOutput`
#WD=`defaultopt $WD ${DistortionCorrectionWarpFieldOutput}.wdir`

log_Msg "START: Topup Field Map Generation and Gradient Unwarping"

mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt

########################################## DO WORK ########################################## 

#check dimensions of phase versus sbref images
#should we also check spacing info? could be off by tiny fractions, so probably not
if [[ `fslhd $PhaseEncodeOne | grep '^dim[123]'` != `fslhd $ScoutInputName | grep '^dim[123]'` ]]
then
    log_Err_Abort "Spin echo fieldmap has different dimensions than scout image, this requires a manual fix"
fi
#for kicks, check that the spin echo images match
if [[ `fslhd $PhaseEncodeOne | grep '^dim[123]'` != `fslhd $PhaseEncodeTwo | grep '^dim[123]'` ]]
then
    log_Err_Abort "Spin echo fieldmap images have different dimensions!"
fi

# PhaseOne and PhaseTwo are sets of SE EPI images with opposite phase encodes
${FSLDIR}/bin/imcp $PhaseEncodeOne ${WD}/PhaseOne
${FSLDIR}/bin/imcp $PhaseEncodeTwo ${WD}/PhaseTwo
${FSLDIR}/bin/imcp $ScoutInputName ${WD}/SBRef
log_Msg "SBRef: $ScoutInputName"
log_Msg "PhaseOne: $PhaseEncodeOne"
log_Msg "PhaseTwo: $PhaseEncodeTwo"

if [[ ! -z $PhaseEncodeOne2 && $PhaseEncodeOne2 != NONE ]] ; then 
	if [[ `fslhd $PhaseEncodeOne2 | grep '^dim[123]'` != `fslhd $ScoutInputName | grep '^dim[123]'` ]]
	then
		log_Err_Abort "2nd pair of spin echo fieldmap images have different dimensions!"
	fi
	${FSLDIR}/bin/imcp $PhaseEncodeOne2 ${WD}/PhaseOne2
	${FSLDIR}/bin/imcp $PhaseEncodeTwo2 ${WD}/PhaseTwo2
	log_Msg "PhaseOne2: $PhaseEncodeOne2"
	log_Msg "PhaseTwo2: $PhaseEncodeTwo2"
	Phase2ndDir=TRUE
else
	Phase2ndDir=FALSE
fi

log_Msg "Phase2ndDir: $Phase2ndDir"

# Apply gradient non-linearity distortion correction (GDC) to input images (SE pair)
# PhaseZero is assumed to be already applied GDC
if [ ! $GradientDistortionCoeffs = "NONE" ] ; then
  ${GlobalScripts}/GradientDistortionUnwarp.sh \
      --workingdir=${WD} \
      --coeffs=${GradientDistortionCoeffs} \
      --in=${WD}/PhaseOne \
      --out=${WD}/PhaseOne_gdc \
      --owarp=${WD}/PhaseOne_gdc_warp
  ${GlobalScripts}/GradientDistortionUnwarp.sh \
      --workingdir=${WD} \
      --coeffs=${GradientDistortionCoeffs} \
      --in=${WD}/PhaseTwo \
      --out=${WD}/PhaseTwo_gdc \
      --owarp=${WD}/PhaseTwo_gdc_warp

  if [ $Phase2ndDir = TRUE ] ; then
    ${GlobalScripts}/GradientDistortionUnwarp.sh \
      --workingdir=${WD} \
      --coeffs=${GradientDistortionCoeffs} \
      --in=${WD}/PhaseOne2 \
      --out=${WD}/PhaseOne2_gdc \
      --owarp=${WD}/PhaseOne2_gdc_warp

    ${GlobalScripts}/GradientDistortionUnwarp.sh \
      --workingdir=${WD} \
      --coeffs=${GradientDistortionCoeffs} \
      --in=${WD}/PhaseTwo2 \
      --out=${WD}/PhaseTwo2_gdc \
      --owarp=${WD}/PhaseTwo2_gdc_warp
  fi

  if ((UseJacobian))
  then
    ${FSLDIR}/bin/fslmaths ${WD}/PhaseOne_gdc -mul ${WD}/PhaseOne_gdc_warp_jacobian ${WD}/PhaseOne_gdc
    ${FSLDIR}/bin/fslmaths ${WD}/PhaseTwo_gdc -mul ${WD}/PhaseTwo_gdc_warp_jacobian ${WD}/PhaseTwo_gdc
    if [ $Phase2ndDir = TRUE ] ; then
      ${FSLDIR}/bin/fslmaths ${WD}/PhaseOne2_gdc -mul ${WD}/PhaseOne2_gdc_warp_jacobian ${WD}/PhaseOne2_gdc
      ${FSLDIR}/bin/fslmaths ${WD}/PhaseTwo2_gdc -mul ${WD}/PhaseTwo2_gdc_warp_jacobian ${WD}/PhaseTwo2_gdc
    fi
  fi
  #overwrites inputs, no else needed
  
  #in the below stuff, the jacobians for both phases and sbref are applied unconditionally to a separate _jac image
  #NOTE: "SBref" is actually the input scout, which is actually the _gdc scout, with gdc jacobian applied if applicable

  if [ $Phase2ndDir = TRUE ] ; then
      Phase2ndSet="PhaseOne2 PhaseTwo2 PhaseOne2_gdc PhaseTwo2_gdc PhaseOne2_gdc_warp PhaseTwo2_gdc_warp"
  else
      Phase2ndSet=""
  fi

  if [[ ("$TruePatientPosition" = "HFSx" || "$TruePatientPosition" = "FFSx" || "$TruePatientPosition" = "HFS" || "$TruePatientPosition" = "FFS" ) && ( "$TruePatientPosition" != "$ScannerPatientPosition") ]] ; then
    if [ ! -z "$InitWorldMat" ] ; then
      log_Msg "Apply init rigid-body transformation to sform"
      initmat="--init=${InitWorldMat}"
    else
      initmat=""
    fi
    log_Msg "Reorient $TruePatientPosition data with a scanner orientation of $ScannerPatientPosition"
    for vol in PhaseOne PhaseTwo PhaseOne_gdc PhaseTwo_gdc PhaseOne_gdc_warp PhaseTwo_gdc_warp $Phase2ndSet; do
	${GlobalScripts}/CorrectVolumeOrientation --in=${WD}/${vol}.nii.gz --out=${WD}/${vol} --tposition=$TruePatientPosition --sposition=$ScannerPatientPosition $initmat
    done

  else
    log_Msg "Reorient to std"
    for vol in PhaseOne PhaseTwo PhaseOne_gdc PhaseTwo_gdc PhaseOne_gdc_warp PhaseTwo_gdc_warp $Phase2ndSet; do
      fslreorient2std ${WD}/${vol} ${WD}/${vol}
    done
    if [ ! -z "$InitWorldMat" ] ; then
       log_Msg "Apply init rigid-body transformation to sform"
       for vol in PhaseOne PhaseTwo PhaseOne_gdc PhaseTwo_gdc PhaseOne_gdc_warp PhaseTwo_gdc_warp $Phase2ndSet; do
          ${CARET7DIR}/wb_command -nifti-information -print-header "$WD"/"$vol".nii.gz | grep -3 "effective sform" | tail -3 | awk '{printf "%.8f\t%.8f\t%.8f\t%.8f\n",$1,$2,$3,$4}' > "$WD"/"$vol"_effectivesform.mat
          echo "0 0 0 1" | awk '{printf "%.8f\t%.8f\t%.8f\t%.8f\n",$1,$2,$3,$4}' >> "$WD"/"$vol"_effectivesform.mat
     	   convert_xfm -omat "$WD"/${vol}_newsform.mat -concat ${InitWorldMat} "$WD"/"$vol"_effectivesform.mat
	   ${CARET7DIR}/wb_command -volume-set-space "$WD"/"$vol".nii.gz "$WD"/"$vol".nii.gz -sform $(cat "$WD"/${vol}_newsform.mat | head -3)
          rm  "$WD"/${vol}_newsform.mat "$WD"/"$vol"_effectivesform.mat
       done
    fi 
  fi

  # Make a dilated mask in the distortion corrected space
  # 6/5/2019: Ensure that the mask is a single volume (via -Tmin flag) to handle changes in behavior of flirt and
  # applywarp introduced with FSL 6 (e.g., with a 3 frame input as the ref (-r) volume, applywarp results in a 9 frame output)
  ${FSLDIR}/bin/fslmaths ${WD}/PhaseOne -abs -bin -dilD -Tmin ${WD}/PhaseOne_mask
  ${FSLDIR}/bin/applywarp --rel --interp=nn -i ${WD}/PhaseOne_mask -r ${WD}/PhaseOne_mask -w ${WD}/PhaseOne_gdc_warp -o ${WD}/PhaseOne_mask_gdc
  ${FSLDIR}/bin/fslmaths ${WD}/PhaseTwo -abs -bin -dilD -Tmin ${WD}/PhaseTwo_mask
  ${FSLDIR}/bin/applywarp --rel --interp=nn -i ${WD}/PhaseTwo_mask -r ${WD}/PhaseTwo_mask -w ${WD}/PhaseTwo_gdc_warp -o ${WD}/PhaseTwo_mask_gdc

  # Make a conservative (eroded) intersection of the two masks
  ${FSLDIR}/bin/fslmaths ${WD}/PhaseOne_mask_gdc -mas ${WD}/PhaseTwo_mask_gdc -bin ${WD}/Mask  # -ero is too aggressive for NHP - TH 2024

  if [ ! $Phase2ndDir = TRUE ] ; then
    # Merge both sets of images
    ${FSLDIR}/bin/fslmerge -t ${WD}/BothPhases ${WD}/PhaseOne_gdc ${WD}/PhaseTwo_gdc $mergezero 
  else
    ${FSLDIR}/bin/fslmaths ${WD}/PhaseOne2 -abs -bin -dilD -Tmin ${WD}/PhaseOne2_mask
    ${FSLDIR}/bin/applywarp --rel --interp=nn -i ${WD}/PhaseOne2_mask -r ${WD}/PhaseOne2_mask -w ${WD}/PhaseOne2_gdc_warp -o ${WD}/PhaseOne2_mask_gdc
    ${FSLDIR}/bin/fslmaths ${WD}/PhaseTwo2 -abs -bin -dilD -Tmin ${WD}/PhaseTwo2_mask
    ${FSLDIR}/bin/applywarp --rel --interp=nn -i ${WD}/PhaseTwo2_mask -r ${WD}/PhaseTwo2_mask -w ${WD}/PhaseTwo2_gdc_warp -o ${WD}/PhaseTwo2_mask_gdc
    ${FSLDIR}/bin/fslmaths ${WD}/Mask -mas ${WD}/PhaseOne2_mask_gdc -mas ${WD}/PhaseTwo2_mask_gdc -bin ${WD}/Mask # -ero is too aggressive for NHP - TH 2024
    ${FSLDIR}/bin/fslmerge -t ${WD}/QuadPhases ${WD}/PhaseOne_gdc ${WD}/PhaseTwo_gdc ${WD}/PhaseOne2_gdc ${WD}/PhaseTwo2_gdc
  fi
  
else 
  ${FSLDIR}/bin/imcp ${WD}/PhaseOne ${WD}/PhaseOne_gdc
  ${FSLDIR}/bin/imcp ${WD}/PhaseTwo ${WD}/PhaseTwo_gdc

  if [ $Phase2ndDir = TRUE ] ; then
    ${FSLDIR}/bin/imcp ${WD}/PhaseOne2 ${WD}/PhaseOne2_gdc
    ${FSLDIR}/bin/imcp ${WD}/PhaseTwo2 ${WD}/PhaseTwo2_gdc
  fi

  if [[ ("$TruePatientPosition" = "HFSx" || "$TruePatientPosition" = "FFSx" || "$TruePatientPosition" = "HFS" || "$TruePatientPosition" = "FFS" ) && ( "$TruePatientPosition" != "$ScannerPatientPosition") ]] ; then
      if [ ! -z "$InitWorldMat" ] ; then
        log_Msg "Apply init rigid-body transformation"
        initmat="--init=${InitWorldMat}"
      else
        initmat=""
      fi
      if [ $Phase2ndDir = TRUE ] ; then
         Phase2ndSet="PhaseOne2 PhaseTwo2 PhaseOne2_gdc PhaseTwo2_gdc"
      else
         Phase2ndSet=""
      fi
      log_Msg "Reorient $TruePatientPosition data with a scanner orientation of $ScannerPatientPosition"
      for vol in PhaseOne PhaseTwo PhaseOne_gdc PhaseTwo_gdc $Phase2ndSet; do
         ${GlobalScripts}/CorrectVolumeOrientation --in=${WD}/${vol}.nii.gz --out=${WD}/${vol} --tposition=$TruePatientPosition --sposition=$ScannerPatientPosition "$initmat"
      done
  else
      log_Msg "Reorient to std" 
      if [ $Phase2ndDir = TRUE ] ; then
         Phase2ndSet="PhaseOne2 PhaseTwo2 PhaseOne2_gdc PhaseTwo2_gdc"
      else
         Phase2ndSet=""
      fi
      for vol in PhaseOne PhaseTwo PhaseOne_gdc PhaseTwo_gdc $Phase2ndSet; do
            fslreorient2std ${WD}/${vol} ${WD}/${vol}
      done
      if [ ! -z "$InitWorldMat" ] ; then
         log_Msg "Apply init rigid-body transformation"
         for vol in PhaseOne PhaseTwo PhaseOne_gdc PhaseTwo_gdc $Phase2ndSet; do
           ${CARET7DIR}/wb_command -nifti-information -print-header "$WD"/"$vol".nii.gz | grep -3 "effective sform" | tail -3 | awk '{printf "%.8f\t%.8f\t%.8f\t%.8f\n",$1,$2,$3,$4}' > "$WD"/"$vol"_effectivesform.mat
           echo "0 0 0 1" | awk '{printf "%.8f\t%.8f\t%.8f\t%.8f\n",$1,$2,$3,$4}' >> "$WD"/"$vol"_effectivesform.mat
     	    convert_xfm -omat "$WD"/${vol}_newsform.mat -concat ${InitWorldMat} "$WD"/"$vol"_effectivesform.mat
	    ${CARET7DIR}/wb_command -volume-set-space "$WD"/"$vol".nii.gz "$WD"/"$vol".nii.gz -sform $(cat "$WD"/${vol}_newsform.mat | head -3)
           rm  "$WD"/${vol}_newsform.mat "$WD"/"$vol"_effectivesform.mat
         done
      fi 
  fi


  if [ ! $Phase2ndDir = TRUE ] ; then
    ${FSLDIR}/bin/fslmerge -t ${WD}/BothPhases ${WD}/PhaseOne_gdc ${WD}/PhaseTwo_gdc
    ${FSLDIR}/bin/fslmaths ${WD}/BothPhases -mul 0 -add 1 -Tmin ${WD}/Mask  # Single volume containing all 1's
  else
    ${FSLDIR}/bin/fslmerge -t ${WD}/QuadPhases ${WD}/PhaseOne_gdc ${WD}/PhaseTwo_gdc ${WD}/PhaseOne2_gdc ${WD}/PhaseTwo2_gdc
    ${FSLDIR}/bin/fslmaths ${WD}/QuadPhases -mul 0 -add 1 -Tmin ${WD}/Mask  # Single volume containing all 1's
  fi

fi


# Set up text files with all necessary parameters
txtfname=${WD}/acqparams.txt
if [ -e $txtfname ] ; then
  rm $txtfname
fi

dimtOne=`${FSLDIR}/bin/fslval ${WD}/PhaseOne dim4`
dimtTwo=`${FSLDIR}/bin/fslval ${WD}/PhaseTwo dim4`
if [ $Phase2ndDir = TRUE ] ; then
   dimtOne2=`${FSLDIR}/bin/fslval ${WD}/PhaseOne2 dim4`
   dimtTwo2=`${FSLDIR}/bin/fslval ${WD}/PhaseTwo2 dim4`
fi

# Calculate the readout time and populate the parameter file appropriately
# Total_readout=EffectiveEchoSpacing*(ReconMatrixPE-1)
#  Factors such as in-plane acceleration, phase oversampling, phase resolution, phase field-of-view, and interpolation
#  must already be accounted for as part of the "EffectiveEchoSpacing"

# For UnwarpDir, allow for both {x,y} and {i,j} nomenclature
# X direction phase encode
if [[ $UnwarpDir = [xi] || $UnwarpDir = [xi]- || $UnwarpDir = -[xi] ]] ; then
  dimP=`${FSLDIR}/bin/fslval ${WD}/PhaseOne dim1`
  dimPminus1=$(($dimP - 1))
  ro_time=`echo "scale=6; ${EchoSpacing} * ${dimPminus1}" | bc -l` #Compute Total_readout in secs with up to 6 decimal places
  log_Msg "Total readout time is $ro_time secs"
  i=1
  while [ $i -le $dimtOne ] ; do
    echo "-1 0 0 $ro_time" >> $txtfname
    ShiftOne="x-"
    i=`echo "$i + 1" | bc`
  done
  i=1
  while [ $i -le $dimtTwo ] ; do
    echo "1 0 0 $ro_time" >> $txtfname
    ShiftTwo="x"
    i=`echo "$i + 1" | bc`
  done
  if [ $Phase2ndDir = TRUE ] ; then
   dimP=`${FSLDIR}/bin/fslval ${WD}/PhaseOne2 dim1`
   dimPminus1=$(($dimP - 1))
   ro_time=`echo "scale=6; ${EchoSpacing} * ${dimPminus1}" | bc -l` #Compute Total_readout in secs with up to 6 decimal places
   log_Msg "Total readout time is $ro_time secs"
   i=1
   while [ $i -le $dimtOne2 ] ; do
     echo "0 -1 0 $ro_time" >> $txtfname
     i=`echo "$i + 1" | bc`
   done
   i=1
   while [ $i -le $dimtTwo2 ] ; do
    echo "0 1 0 $ro_time" >> $txtfname
    i=`echo "$i + 1" | bc`
   done
  fi
# Y direction phase encode
elif [[ $UnwarpDir = [yj] || $UnwarpDir = [yj]- || $UnwarpDir = -[yj] ]] ; then
  dimP=`${FSLDIR}/bin/fslval ${WD}/PhaseOne dim2`
  dimPminus1=$(($dimP - 1))
  ro_time=`echo "scale=6; ${EchoSpacing} * ${dimPminus1}" | bc -l` #Compute Total_readout in secs with up to 6 decimal places
  i=1
  while [ $i -le $dimtOne ] ; do
    echo "0 -1 0 $ro_time" >> $txtfname
    ShiftOne="y-"
    i=`echo "$i + 1" | bc`
  done
  i=1
  while [ $i -le $dimtTwo ] ; do
    echo "0 1 0 $ro_time" >> $txtfname
    ShiftTwo="y"
    i=`echo "$i + 1" | bc`
  done
  if [ $Phase2ndDir = TRUE ] ; then
   dimP=`${FSLDIR}/bin/fslval ${WD}/PhaseOne2 dim1`
   dimPminus1=$(($dimP - 1))
   ro_time=`echo "scale=6; ${EchoSpacing} * ${dimPminus1}" | bc -l` #Compute Total_readout in secs with up to 6 decimal places
   log_Msg "Total readout time is $ro_time secs"
   i=1
   while [ $i -le $dimtOne2 ] ; do
     echo "-1 0 0 $ro_time" >> $txtfname
     i=`echo "$i + 1" | bc`
   done
   i=1
   while [ $i -le $dimtTwo2 ] ; do
    echo "1 0 0 $ro_time" >> $txtfname
    i=`echo "$i + 1" | bc`
   done
  fi
else
	# Per Jesper Anderson, topup does NOT allow PE dir to be along Z (no good reason, other than that made implementation easier)
	log_Err_Abort "Invalid entry for --unwarpdir ($UnwarpDir)"
fi

# add T2w as a PhaseZero volume - TH 2023 
if [[ ! -z $PhaseEncodeZero && ! $PhaseEncodeZero = NONE ]] ; then
  # assume PhaseEncodeZero is already gradient distortion and orientation corrected - TH 2023
  log_Msg "Using T2w as a phasezero"
  log_Msg "PhaseZero: ${WD}/PhaseZero_gdc.nii.gz"
  ${CARET7DIR}/wb_command -volume-resample $(${FSLDIR}/bin/remove_ext $PhaseEncodeZero).nii.gz ${WD}/PhaseOne_gdc.nii.gz CUBIC ${WD}/PhaseZero_gdc.nii.gz -affine ${FSLDIR}/etc/flirtsch/ident.mat
  # Normlise mean values
  MeanOne=$(${FSLDIR}/bin/fslstats ${WD}/PhaseOne -m)
  MeanTwo=$(${FSLDIR}/bin/fslstats ${WD}/PhaseTwo -m)
  MeanZero=$(${FSLDIR}/bin/fslstats ${WD}/PhaseZero_gdc -m)

  if [ ! $Phase2ndDir = TRUE ] ; then
    MeanOneTwo=$(echo "($MeanOne + $MeanTwo) / 2" | bc -l)
    ${FSLDIR}/bin/fslmaths ${WD}/PhaseZero_gdc -div $MeanZero -mul $MeanOneTwo ${WD}/PhaseZero_gdc
    immv ${WD}/BothPhases.nii.gz ${WD}/BothPhases_NoZero.nii.gz
    ${FSLDIR}/bin/fslmerge -t ${WD}/BothPhases ${WD}/BothPhases_NoZero ${WD}/PhaseZero_gdc
    ${FSLDIR}/bin/fslmaths ${WD}/BothPhases -inm 10000 ${WD}/BothPhases
    imrm ${WD}/BothPhases_NoZero.nii.gz
  else
    MeanOne2=$(${FSLDIR}/bin/fslstats ${WD}/PhaseOne2 -m)
    MeanTwo2=$(${FSLDIR}/bin/fslstats ${WD}/PhaseTwo2 -m)
    MeanOneTwo=$(echo "($MeanOne + $MeanTwo + $MeanOne2 + $MeanTwo2) / 4" | bc -l)
    ${FSLDIR}/bin/fslmaths ${WD}/PhaseZero_gdc -div $MeanZero -mul $MeanOneTwo ${WD}/PhaseZero_gdc
    immv ${WD}/QuadPhases.nii.gz ${WD}/QuadPhases_NoZero.nii.gz
    ${FSLDIR}/bin/fslmerge -t ${WD}/QuadPhases ${WD}/QuadPhases_NoZero ${WD}/PhaseZero_gdc
    ${FSLDIR}/bin/fslmaths ${WD}/QuadPhases -inm 10000 ${WD}/QuadPhases
    imrm ${WD}/QuadPhases_NoZero.nii.gz
  fi
  cp ${WD}/acqparams.txt ${WD}/acqparams_NoZero.txt
  cat ${WD}/acqparams_NoZero.txt | tail -1 | awk '{print $1,$2,0,0.01}' >> ${WD}/acqparams.txt
  rm ${WD}/acqparams_NoZero.txt
fi

if [ ! $Phase2ndDir = TRUE ] ; then
  InputTopup=${WD}/BothPhases
else
  InputTopup=${WD}/QuadPhases
fi

#Pad in Z by one slice if odd so that topup does not complain (slice consists of zeros that will be dilated by following step)
numslice=`fslval ${InputTopup} dim3`
if [ ! $(($numslice % 2)) -eq "0" ] ; then
  log_Msg "Padding Z by one slice"
  for Image in ${InputTopup} ${WD}/Mask ; do
    fslroi ${Image} ${WD}/slice 0 -1 0 -1 0 1 0 -1
    fslmaths ${WD}/slice -mul 0 ${WD}/slice
    fslmerge -z ${Image} ${Image} ${WD}/slice
    ${FSLDIR}/bin/imrm ${WD}/slice
  done
fi

# Extrapolate the existing values beyond the mask (adding 1 just to avoid smoothing inside the mask)
${FSLDIR}/bin/fslmaths ${InputTopup} -abs -add 1 -mas ${WD}/Mask -dilM -dilM -dilM -dilM -dilM ${InputTopup}

# RUN TOPUP
# Needs FSL (version 5.0.6 or later)
# Note: All the jacobian stuff from here onward is related to the TOPUP warp field
${FSLDIR}/bin/topup --imain=${InputTopup} --datain=$txtfname --config=${TopupConfig} --out=${WD}/Coefficents --iout=${WD}/Magnitudes --fout=${WD}/TopupField --dfout=${WD}/WarpField --rbmout=${WD}/MotionMatrix --jacout=${WD}/Jacobian -v 

#Remove Z slice padding if needed
if [ ! $(($numslice % 2)) -eq "0" ] ; then
  log_Msg "Removing Z slice padding"
  for Image in ${InputTopup} ${WD}/Mask ${WD}/Coefficents_fieldcoef ${WD}/Magnitudes ${WD}/TopupField* ${WD}/WarpField* ${WD}/Jacobian* ; do
    fslroi ${Image} ${Image} 0 -1 0 -1 0 ${numslice} 0 -1
  done
fi

# UNWARP DIR = x,y
if [[ $UnwarpDir = [xyij] ]] ; then
  # select the first volume from PhaseTwo
  VolumeNumber=$(($dimtOne + 1))
  vnum=`${FSLDIR}/bin/zeropad $VolumeNumber 2`
  # register scout to SE input (PhaseTwo) + combine motion and distortion correction
  ${FSLDIR}/bin/fslroi ${WD}/PhaseTwo_gdc ${WD}/PhaseTwo_gdc_one 0 1  # For flirt in FSL 6, -ref argument must be single 3D volume
  ${FSLDIR}/bin/flirt -dof 6 -interp spline -in ${WD}/SBRef -ref ${WD}/PhaseTwo_gdc_one -omat ${WD}/SBRef2PhaseTwo_gdc.mat -out ${WD}/SBRef2PhaseTwo_gdc
  ${FSLDIR}/bin/convert_xfm -omat ${WD}/SBRef2WarpField.mat -concat ${WD}/MotionMatrix_${vnum}.mat ${WD}/SBRef2PhaseTwo_gdc.mat
  ${FSLDIR}/bin/convertwarp --relout --rel -r ${WD}/PhaseTwo_gdc_one --premat=${WD}/SBRef2WarpField.mat --warp1=${WD}/WarpField_${vnum} --out=${WD}/WarpField
  ${FSLDIR}/bin/imcp ${WD}/Jacobian_${vnum} ${WD}/Jacobian
  SBRefPhase=Two
# UNWARP DIR = -x,-y
elif [[ $UnwarpDir = [xyij]- || $UnwarpDir = -[xyij] ]] ; then
  # select the first volume from PhaseOne
  VolumeNumber=$((0 + 1))
  vnum=`${FSLDIR}/bin/zeropad $VolumeNumber 2`
  # register scout to SE input (PhaseOne) + combine motion and distortion correction
  ${FSLDIR}/bin/fslroi ${WD}/PhaseOne_gdc ${WD}/PhaseOne_gdc_one 0 1  # For flirt in FSL 6, -ref argument must be single 3D volume
  ${FSLDIR}/bin/flirt -dof 6 -interp spline -in ${WD}/SBRef -ref ${WD}/PhaseOne_gdc_one -omat ${WD}/SBRef2PhaseOne_gdc.mat -out ${WD}/SBRef2PhaseOne_gdc
  ${FSLDIR}/bin/convert_xfm -omat ${WD}/SBRef2WarpField.mat -concat ${WD}/MotionMatrix_${vnum}.mat ${WD}/SBRef2PhaseOne_gdc.mat
  ${FSLDIR}/bin/convertwarp --relout --rel -r ${WD}/PhaseOne_gdc_one --premat=${WD}/SBRef2WarpField.mat --warp1=${WD}/WarpField_${vnum} --out=${WD}/WarpField
  ${FSLDIR}/bin/imcp ${WD}/Jacobian_${vnum} ${WD}/Jacobian
  SBRefPhase=One
fi

# Make sure that the -r volume in applywarp is a single 3D volume to deal with changes (bug) in behavior
# of applywarp introduced with FSL 6

# PhaseTwo (first vol) - warp and Jacobian modulate to get distortion corrected output
VolumeNumber=$(($dimtOne + 1))
  vnum=`${FSLDIR}/bin/zeropad $VolumeNumber 2`
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/PhaseTwo_gdc -r ${WD}/Mask --premat=${WD}/MotionMatrix_${vnum}.mat -w ${WD}/WarpField_${vnum} -o ${WD}/PhaseTwo_gdc_dc
${FSLDIR}/bin/fslmaths ${WD}/PhaseTwo_gdc_dc -mul ${WD}/Jacobian_${vnum} ${WD}/PhaseTwo_gdc_dc_jac
# PhaseOne (first vol) - warp and Jacobian modulate to get distortion corrected output
VolumeNumber=$((0 + 1))
  vnum=`${FSLDIR}/bin/zeropad $VolumeNumber 2`
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/PhaseOne_gdc -r ${WD}/Mask --premat=${WD}/MotionMatrix_${vnum}.mat -w ${WD}/WarpField_${vnum} -o ${WD}/PhaseOne_gdc_dc
${FSLDIR}/bin/fslmaths ${WD}/PhaseOne_gdc_dc -mul ${WD}/Jacobian_${vnum} ${WD}/PhaseOne_gdc_dc_jac

if [ $Phase2ndDir = TRUE ] ; then
# PhaseTwo2 (first vol) - warp and Jacobian modulate to get distortion corrected output
VolumeNumber=$(($dimtOne + $dimtTwo + $dimtOne2 + 1))
  vnum=`${FSLDIR}/bin/zeropad $VolumeNumber 2`
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/PhaseTwo2_gdc -r ${WD}/Mask --premat=${WD}/MotionMatrix_${vnum}.mat -w ${WD}/WarpField_${vnum} -o ${WD}/PhaseTwo2_gdc_dc
${FSLDIR}/bin/fslmaths ${WD}/PhaseTwo2_gdc_dc -mul ${WD}/Jacobian_${vnum} ${WD}/PhaseTwo2_gdc_dc_jac

# PhaseOne2 (first vol) - warp and Jacobian modulate to get distortion corrected output
VolumeNumber=$(($dimtOne + $dimtTwo + 1))
  vnum=`${FSLDIR}/bin/zeropad $VolumeNumber 2`
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/PhaseOne2_gdc -r ${WD}/Mask --premat=${WD}/MotionMatrix_${vnum}.mat -w ${WD}/WarpField_${vnum} -o ${WD}/PhaseOne2_gdc_dc
${FSLDIR}/bin/fslmaths ${WD}/PhaseOne2_gdc_dc -mul ${WD}/Jacobian_${vnum} ${WD}/PhaseOne2_gdc_dc_jac
fi

# Scout - warp and Jacobian modulate to get distortion corrected output
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${WD}/SBRef -r ${WD}/SBRef -w ${WD}/WarpField -o ${WD}/SBRef_dc
${FSLDIR}/bin/fslmaths ${WD}/SBRef_dc -mul ${WD}/Jacobian ${WD}/SBRef_dc_jac

# Calculate Equivalent Field Map
${FSLDIR}/bin/fslmaths ${WD}/TopupField -mul 6.283 ${WD}/TopupField
${FSLDIR}/bin/fslmaths ${WD}/Magnitudes -Tmean ${WD}/Magnitude
${FSLDIR}/bin/bet ${WD}/Magnitude ${WD}/Magnitude_brain -f 0.35 -m #Brain extract the magnitude image

# copy images to specified outputs
# explicitly include .nii.gz suffix on outputs here, to avoid any ambiguity between files
# vs directories with the same (base)name
if [ ! -z ${DistortionCorrectionWarpFieldOutput} ] ; then
  ${FSLDIR}/bin/imcp ${WD}/WarpField.nii.gz ${DistortionCorrectionWarpFieldOutput}.nii.gz
fi
if [ ! -z ${JacobianOutput} ] ; then
  ${FSLDIR}/bin/imcp ${WD}/Jacobian.nii.gz ${JacobianOutput}.nii.gz
fi
if [ ! -z ${DistortionCorrectionFieldOutput} ] ; then
  ${FSLDIR}/bin/imcp ${WD}/TopupField.nii.gz ${DistortionCorrectionFieldOutput}.nii.gz
fi
if [ ! -z ${DistortionCorrectionMagnitudeOutput} ] ; then
  ${FSLDIR}/bin/imcp ${WD}/Magnitude.nii.gz ${DistortionCorrectionMagnitudeOutput}.nii.gz
fi
if [ ! -z ${DistortionCorrectionMagnitudeBrainOutput} ] ; then
  ${FSLDIR}/bin/imcp ${WD}/Magnitude_brain.nii.gz ${DistortionCorrectionMagnitudeBrainOutput}.nii.gz
fi

log_Msg "END: Topup Field Map Generation and Gradient Unwarping"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ########################################## 

if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# Inspect results of various corrections (phase one)" >> $WD/qa.txt
echo "fslview ${WD}/PhaseOne ${WD}/PhaseOne_gdc ${WD}/PhaseOne_gdc_dc ${WD}/PhaseOne_gdc_dc_jac" >> $WD/qa.txt
echo "# Inspect results of various corrections (phase two)" >> $WD/qa.txt
echo "fslview ${WD}/PhaseTwo ${WD}/PhaseTwo_gdc ${WD}/PhaseTwo_gdc_dc ${WD}/PhaseTwo_gdc_dc_jac" >> $WD/qa.txt
echo "# Check linear registration of Scout to SE EPI" >> $WD/qa.txt
echo "fslview ${WD}/Phase${SBRefPhase}_gdc ${WD}/SBRef2Phase${SBRefPhase}_gdc" >> $WD/qa.txt
echo "# Inspect results of various corrections to scout" >> $WD/qa.txt
echo "fslview ${WD}/SBRef ${WD}/SBRef_dc ${WD}/SBRef_dc_jac" >> $WD/qa.txt
echo "# Visual check of warpfield and Jacobian" >> $WD/qa.txt
echo "fslview ${DistortionCorrectionWarpFieldOutput} ${JacobianOutput}" >> $WD/qa.txt


##############################################################################################



