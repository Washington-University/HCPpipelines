#!/bin/bash 

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

mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt

########################################## DO WORK ##########################################


# Register to 2mm reference image (linear then non-linear)
verbose_echo " ... linear registration to 2mm reference"
${FSLDIR}/bin/flirt -interp spline -dof 12 -in "$Input" -ref "$Reference" -omat "$WD"/roughlin.mat -out "$WD"/"$BaseName"_to_MNI_roughlin.nii.gz -nosearch
verbose_echo " ... non-linear registration to 2mm reference"
${FSLDIR}/bin/fnirt --in="$Input" --ref="$Reference2mm" --aff="$WD"/roughlin.mat --refmask="$Reference2mmMask" --fout="$WD"/str2standard.nii.gz --jout="$WD"/NonlinearRegJacobians.nii.gz --refout="$WD"/IntensityModulatedT1.nii.gz --iout="$WD"/"$BaseName"_to_MNI_nonlin.nii.gz --logout="$WD"/NonlinearReg.txt --intout="$WD"/NonlinearIntensities.nii.gz --cout="$WD"/NonlinearReg.nii.gz --config="$FNIRTConfig"

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


