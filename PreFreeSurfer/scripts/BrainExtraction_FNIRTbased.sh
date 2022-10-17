#!/bin/bash 

# Requirements for this script
#  installed versions of: FSL
#  environment: HCPPIPEDIR, FSLDIR, HCPPIPEDIR_Templates

# ------------------------------------------------------------------------------
#  Usage Description Function
# ------------------------------------------------------------------------------

script_name=$(basename "${0}")

Usage() {
	cat <<EOF

${script_name}: Tool for performing brain extraction using non-linear (FNIRT) results

Usage: ${script_name}
  [--workingdir=<working dir>]
  --in=<input image>
  [--ref=<reference highres image>]
  [--refmask=<reference brain mask>]
  [--ref2mm=<reference image 2mm>]
  [--ref2mmmask=<reference brain mask 2mm>]
  --outbrain=<output brain extracted image>
  --outbrainmask=<output brain mask>
  [--fnirtconfig=<fnirt config file>]

EOF
}

# Allow script to return a Usage statement, before any other output or checking
if [ "$#" = "0" ]; then
    Usage
    exit 1
fi

# ------------------------------------------------------------------------------
#  Check that HCPPIPEDIR is defined and Load Function Libraries
# ------------------------------------------------------------------------------

if [ -z "${HCPPIPEDIR}" ]; then
  echo "${script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
  exit 1
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib

# ------------------------------------------------------------------------------
#  Verify required environment variables are set and log value
# ------------------------------------------------------------------------------

log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FSLDIR
log_Check_Env_Var HCPPIPEDIR_Templates

################################################ SUPPORT FUNCTIONS ##################################################

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

# All except variables starting with $Output are saved in the Working Directory:
#     roughlin.mat "$BaseName"_to_MNI_roughlin.nii.gz   (flirt outputs)
#     NonlinearRegJacobians.nii.gz IntensityModulatedT1.nii.gz NonlinearReg.txt NonlinearIntensities.nii.gz
#     NonlinearReg.nii.gz (the coefficient version of the warpfield)
#     str2standard.nii.gz standard2str.nii.gz   (both warpfields in field format)
#     "$BaseName"_to_MNI_nonlin.nii.gz   (spline interpolated output)
#    "$OutputBrainMask" "$OutputBrainExtractedImage"

################################################## OPTION PARSING #####################################################

# parse arguments
WD=`getopt1 "--workingdir" $@`  # "$1"
Input=`getopt1 "--in" $@`  # "$2"
Reference=`getopt1 "--ref" $@` # "$3"
ReferenceMask=`getopt1 "--refmask" $@` # "$4"
Reference2mm=`getopt1 "--ref2mm" $@` # "$5"
Reference2mmMask=`getopt1 "--ref2mmmask" $@` # "$6"
OutputBrainExtractedImage=`getopt1 "--outbrain" $@` # "$7"
OutputBrainMask=`getopt1 "--outbrainmask" $@` # "$8"
FNIRTConfig=`getopt1 "--fnirtconfig" $@` # "$9"

# default parameters
WD=`defaultopt $WD .`
Reference=`defaultopt $Reference ${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm.nii.gz`
ReferenceMask=`defaultopt $ReferenceMask ${HCPPIPEDIR_Templates}/MNI152_T1_0.7mm_brain_mask.nii.gz`  # dilate to be conservative with final brain mask
Reference2mm=`defaultopt $Reference2mm ${HCPPIPEDIR_Templates}/MNI152_T1_2mm.nii.gz`
Reference2mmMask=`defaultopt $Reference2mmMask ${HCPPIPEDIR_Templates}/MNI152_T1_2mm_brain_mask_dil.nii.gz`  # dilate to be conservative with final brain mask
FNIRTConfig=`defaultopt $FNIRTConfig $FSLDIR/etc/flirtsch/T1_2_MNI152_2mm.cnf`

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


