#!/bin/bash 
set -e

# Requirements for this script
#  installed versions of: FSL5.0.1+ , HCP Pipeline
#  environment: as in SetUpHCPPipeline.sh   (or individually: FSLDIR, HCPPIPEDIR_Templates)

# Requirements for this script
#  installed versions of: FSL
#  environment: HCPPIPEDIR, FSLDIR, HCPPIPEDIR_Templates

# ------------------------------------------------------------------------------
#  Usage Description Function
# ------------------------------------------------------------------------------

set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"

opts_SetScriptDescription "Tool for performing brain extraction using non-linear (FNIRT) results"

opts_AddMandatory '--in' 'Input' 'image' "input image"

opts_AddMandatory '--outbrain' 'OutputBrainExtractedImage' 'images' "output brain extracted image"

opts_AddMandatory '--outbrainmask' 'OutputBrainMask' 'mask' "output brain mask"

#optional args 

opts_AddOptional '--workingdir' 'WD' 'path' 'working dir' "."

opts_AddOptional '--ref' 'Reference' 'image' 'reference image' "${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm.nii.gz"

opts_AddOptional '--refmask' 'ReferenceMask' 'mask' 'reference brain mask' "${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm_brain_mask.nii.gz"

opts_AddOptional '--ref2mm' 'Reference2mm' 'image' 'reference 2mm image' "${HCPPIPEDIR_Templates}/MNI152_T1_2mm.nii.gz"

opts_AddOptional '--ref2mmmask' 'Reference2mmMask' 'mask' 'reference 2mm brain mask' "${HCPPIPEDIR_Templates}/MNI152_T1_2mm_brain_mask_dil.nii.gz"

opts_AddOptional '--fnirtconfig' 'FNIRTConfig' 'file' 'FNIRT configuration file' "$FSLDIR/etc/flirtsch/T1_2_MNI152_2mm.cnf"

opts_AddOptional '--brainextract' 'BrainExtract' 'string' 'EXVIVO or INVIVO (default)' "INVIVO"

opts_AddOptional '--edgesigma' 'EdgeSigma' 'float' 'edge sigma (mm) for EXVIVO' "0.01"

opts_AddOptional '--betcenter' 'BetCenter' 'string' 'x,y,z' ""

opts_AddOptional '--betradius' 'BetRadius' 'float' 'radius in mm' "75"

opts_AddOptional '--betfraction' 'BetFraction' 'float' 'fract 0 to 1' "0.3"

opts_AddOptional '--betspecieslabel' 'betspecieslabel' 'int' 'species label' "0"

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

log_Check_Env_Var FSLDIR
log_Check_Env_Var HCPPIPEDIR_Templates

################################################### OUTPUT FILES #####################################################

# All except variables starting with $Output are saved in the Working Directory:
#     roughlin.mat "$BaseName"_to_MNI_roughlin.nii.gz   (flirt outputs)
#     NonlinearRegJacobians.nii.gz IntensityModulatedT1.nii.gz NonlinearReg.txt NonlinearIntensities.nii.gz
#     NonlinearReg.nii.gz (the coefficient version of the warpfield)
#     str2standard.nii.gz standard2str.nii.gz   (both warpfields in field format)
#     "$BaseName"_to_MNI_nonlin.nii.gz   (spline interpolated output)
#    "$OutputBrainMask" "$OutputBrainExtractedImage"

################################################## OPTION PARSING #####################################################

# BET options
if [ ! -z $BetCenter ] ; then
  xcenter=$(echo "$(fslval $Input dim1)*$(echo $BetCenter | cut -d ',' -f1 )/$(fslval $Reference2mm dim1)" | bc )
  ycenter=$(echo "$(fslval $Input dim2)*$(echo $BetCenter | cut -d ',' -f2 )/$(fslval $Reference2mm dim2)" | bc )
  zcenter=$(echo "$(fslval $Input dim3)*$(echo $BetCenter | cut -d ',' -f3 )/$(fslval $Reference2mm dim3)" | bc )   
  BetOpts=" -c $xcenter $ycenter $zcenter"
fi
if [ ! -z $BetRadius ] ; then
  BetOpts+=" -r $BetRadius"
fi
if [ ! -z $BetFraction ] ; then
  BetOpts+=" -f $BetFraction"
fi
if [ "BiasfieldCor" = TRUE ] ; then 
  BetOpts+=" -B"               # bias filed correction and rubust centre estimation
fi
BetOpts+=" -z $betspecieslabel"

BaseName=`${FSLDIR}/bin/remove_ext $Input`;
BaseName=`basename $BaseName`;

verbose_echo "  "
verbose_red_echo " ===> Running FNIRT based brain extraction"
verbose_echo "  "
verbose_echo "  Parameters"
verbose_echo "  WD:                         $WD"
verbose_echo "  Input:                      $Input"
verbose_echo "  Reference:                  $Reference"
verbose_echo "  ReferenceMask:              $ReferenceMask"
verbose_echo "  Reference2mm:               $Reference2mm"
verbose_echo "  Reference2mmMask:           $Reference2mmMask"
verbose_echo "  OutputBrainExtractedImage:  $OutputBrainExtractedImage"
verbose_echo "  OutputBrainMask:            $OutputBrainMask"
verbose_echo "  FNIRTConfig:                $FNIRTConfig"
verbose_echo "  BaseName:                   $BaseName"
verbose_echo " "
verbose_echo " START: BrainExtraction_FNIRT"
log_Msg "START: BrainExtraction_FNIRT"

if [ -w $WD ] ; then rm -rf $WD; fi
mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt

########################################## DO WORK ##########################################

# Register to 2mm reference image (linear then non-linear)
if [ "$BrainExtract" = INVIVO ] ; then
  log_Msg "In-vivo brain"

  if [[ $(imtest "$Input"_custom_brain) = 1 ]] ; then
    verbose_echo " ... linear registration using predefined brain to reference brain"
    fslmaths "$Reference2mm" -mas "$Reference2mmMask" "$WD"/ReferenceBrain
    ${FSLDIR}/bin/flirt -interp spline -dof 12 -in "$Input"_custom_brain -ref "$WD"/ReferenceBrain -omat "$WD"/roughlin.mat -out "$WD"/"$BaseName"_to_MNI_roughlin.nii.gz -nosearch
  elif [ ! -z "$BetOpts" ] ; then
    verbose_echo " ... initial BET with opts: $BetOpts"
    fslmaths "$Reference2mm" -mas "$Reference2mmMask" "$WD"/ReferenceBrain
    fslmaths "$Input" "$WD"/"$BaseName"
    ${HCPPIPEDIR_Global}/bet4animal "$WD"/"$BaseName" "$WD"/"$BaseName"_brain_initI $BetOpts     # "-c 48 56 51 -r 36" for A21051401
    if [ ! $SPECIES = Human ] ; then
      verbose_echo " ... init linear registration to 2mm reference brain"
      flirt -in "$WD"/"$BaseName"_brain_initI -ref "$WD"/ReferenceBrain -omat "$WD"/roughlin_initI.mat -schedule $FSLDIR/etc/flirtsch/xyztrans.sch -o "$WD"/"$BaseName"_brain_initI_to_ReferenceBrain
    else
      verbose_echo " ... init linear registration to 2mm reference brain"
      flirt -in "$WD"/"$BaseName"_brain_initI -ref "$WD"/ReferenceBrain -omat "$WD"/roughlin_initI.mat -dof 12 -o "$WD"/"$BaseName"_brain_initI_to_ReferenceBrain
    fi
    convert_xfm -omat "$WD"/roughlin_initIinv.mat -inverse "$WD"/roughlin_initI.mat
    flirt -in "$Reference2mmMask" -ref "$WD"/"$BaseName" -applyxfm -init "$WD"/roughlin_initIinv.mat -o "$WD"/"$BaseName"_brain_initII_mask -interp nearestneighbour
    fslmaths "$WD"/"$BaseName" -mas "$WD"/"$BaseName"_brain_initII_mask "$WD"/"$BaseName"_brain_initII
    verbose_echo " ... tuned linear registration to 2mm reference brain"
    flirt -in "$WD"/"$BaseName"_brain_initII -ref "$WD"/ReferenceBrain -dof 6 -omat "$WD"/roughlin_initII.mat -o "$WD"/"$BaseName"_brain_initII_to_ReferenceBrain -nosearch
    verbose_echo " ... tuned linear registration to reference"
    flirt -in "$WD"/"$BaseName" -ref "$Reference2mm" -dof 12 -omat "$WD"/roughlin.mat -out "$WD"/"$BaseName"_to_MNI_roughlin.nii.gz -nosearch -init "$WD"/roughlin_initII.mat -inweight "$WD"/"$BaseName"_brain_initII -refweight "$Reference2mmMask"
  else
    verbose_echo " ... linear registration to reference"
    ${FSLDIR}/bin/flirt -interp spline -dof 12 -in "$Input" -ref "$Reference" -omat "$WD"/roughlin.mat -out "$WD"/"$BaseName"_to_MNI_roughlin.nii.gz -nosearch
  fi
  verbose_echo " ... non-linear registration to 2mm reference"
  ${FSLDIR}/bin/fnirt --in="$Input" --ref="$Reference2mm" --aff="$WD"/roughlin.mat --refmask="$Reference2mmMask" --fout="$WD"/str2standard.nii.gz --jout="$WD"/NonlinearRegJacobians.nii.gz --refout="$WD"/IntensityModulatedT1.nii.gz --iout="$WD"/"$BaseName"_to_MNI_nonlin.nii.gz --logout="$WD"/NonlinearReg.txt --intout="$WD"/NonlinearIntensities.nii.gz --cout="$WD"/NonlinearReg.nii.gz --config="$FNIRTConfig"

elif [ "$BrainExtract" = EXVIVO ] ; then
  log_Msg "Ex-vivo brain"
  fslmaths "$Reference" -mas "$ReferenceMask" "$WD"/ReferenceBrain
  if [ $(imtest ${Input}_custom_brain) = 1 ] ; then
    fslmaths ${Input}_custom_brain -bin "$WD"/Inputmask
  else
    fslmaths $Input -thr $(fslstats "$Input" -M | awk '{print $1*0.1}') -bin -fillh "$WD"/Inputmask
  fi
  verbose_echo " ... linear registration to 2mm reference"
  ${FSLDIR}/bin/flirt -interp spline -dof 12 -in "$Input" -ref "$WD"/ReferenceBrain -omat "$WD"/roughlin.mat -out "$WD"/"$BaseName"_to_MNI_roughlin.nii.gz -nosearch
  verbose_echo " ... synthesize head volume"
  convert_xfm -omat "$WD"/roughlininv.mat -inverse "$WD"/roughlin.mat
  applywarp -i "$Reference" -r "$Input" --premat="$WD"/roughlininv.mat -o "$WD"/Reference2str.nii.gz
  meanb=$(fslstats $Input -k "$WD"/Inputmask -M)
  meann=$(fslstats "$WD"/Reference2str.nii.gz -k "$WD"/Inputmask -M)
  fslmaths "$WD"/Reference2str.nii.gz -div $meann -mul $meanb "$WD"/Reference2str.nii.gz
  fslmaths "$WD"/Inputmask -mul $Input "$WD"/InputMasked
  fslmaths "$WD"/Inputmask -binv -mul "$WD"/Reference2str.nii.gz -add "$WD"/InputMasked "$WD"/InputHead
  verbose_echo " ... non-linear registration to 2mm reference"
  ${FSLDIR}/bin/fnirt --in="$WD"/InputHead --ref="$Reference2mm" --aff="$WD"/roughlin.mat --refmask="$Reference2mmMask" --fout="$WD"/str2standard.nii.gz --jout="$WD"/NonlinearRegJacobians.nii.gz --refout="$WD"/IntensityModulatedT1.nii.gz --iout="$WD"/"$BaseName"_to_MNI_nonlin.nii.gz --logout="$WD"/NonlinearReg.txt --intout="$WD"/NonlinearIntensities.nii.gz --cout="$WD"/NonlinearReg.nii.gz --config="$FNIRTConfig"
  imcp "$WD"/InputHead $Input
fi

# Overwrite the image output from FNIRT with a spline interpolated highres version
verbose_echo " ... creating spline interpolated hires version"
${FSLDIR}/bin/applywarp --rel --interp=spline --in="$Input" --ref="$Reference" -w "$WD"/str2standard.nii.gz --out="$WD"/"$BaseName"_to_MNI_nonlin.nii.gz

# Invert warp and transform dilated brain mask back into native space, and use it to mask input image
# Input and reference spaces are the same, using 2mm reference to save time
verbose_echo " ... computing inverse warp"
${FSLDIR}/bin/invwarp --ref="$Reference2mm" -w "$WD"/str2standard.nii.gz -o "$WD"/standard2str.nii.gz
verbose_echo " ... applying inverse warp"
${FSLDIR}/bin/applywarp --rel --interp=nn --in="$ReferenceMask" --ref="$Input" -w "$WD"/standard2str.nii.gz -o "$OutputBrainMask"
verbose_echo " ... creating mask"
${FSLDIR}/bin/fslmaths "$Input" -mas "$OutputBrainMask" "$OutputBrainExtractedImage"

verbose_green_echo "---> Finished BrainExtraction FNIRT"

log_Msg "END: BrainExtraction_FNIRT"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ########################################## 

if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# Check that the following brain mask does not exclude any brain tissue (and is reasonably good at not including non-brain tissue outside of the immediately surrounding CSF)" >> $WD/qa.txt
echo "fslview $Input $OutputBrainMask -l Red -t 0.5" >> $WD/qa.txt
echo "# Optional debugging: linear and non-linear registration result" >> $WD/qa.txt
echo "fslview $Reference2mm $WD/${BaseName}_to_MNI_roughlin.nii.gz" >> $WD/qa.txt
echo "fslview $Reference $WD/${BaseName}_to_MNI_nonlin.nii.gz" >> $WD/qa.txt

##############################################################################################
