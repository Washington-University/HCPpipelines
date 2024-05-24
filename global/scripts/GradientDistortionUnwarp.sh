#!/bin/bash 

# Requirements for this script
#  installed versions of: FSL, gradunwarp (HCP version)
#  environment: HCPPIPEDIR, FSLDIR, PATH for gradient_unwarp.py

set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

# Load function libraries
source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"


opts_SetScriptDescription "Tool for performing Gradient Non-linearity Distortion Correction for general 4D images, based on gradunwarp python package from MGH (it requires a scanner-specific Siemens coefficient file)"

opts_AddMandatory '--workingdir' 'WD' 'path' 'working dir'

opts_AddMandatory '--coeffs' 'InputCoefficients' 'path' "Siemens gradient coefficient file"

opts_AddMandatory '--in' 'InputFile' 'image' "input image"

opts_AddMandatory '--out' 'OutputFile' 'image' "output image"

opts_AddMandatory '--owarp' 'OutputTransform' 'warpfield' "output warp"

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

log_Check_Env_Var FSLDIR

################################################### OUTPUT FILES #####################################################

# Outputs (in $WD except for those starting with $Output) : 
#        ${BaseName}_vol1    (first 3D image - internal use only)
#        trilinear           (direct output of gradient_unwarp.py)
#        fullWarp_abs        (output from gradient_unwarp.py)
#        $OutputTransform    (warp in relative convention)
#        $OutputFile         (spline interpolated 4D output)

################################################## OPTION PARSING #####################################################

BaseName=`${FSLDIR}/bin/remove_ext $InputFile`;
BaseName=`basename $BaseName`;

log_Msg "START"

mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt

########################################## DO WORK ########################################## 

# Extract first volume and run gradient distortion correction on this (all others follow suit as scanner coordinate system is unchanged, even with subject motion)
${FSLDIR}/bin/fslroi "$InputFile" $WD/${BaseName}_vol1.nii.gz 0 1

# move (temporarily) into the working directory as gradient_unwarp.py outputs some files directly into pwd
InputCoeffs=`${FSLDIR}/bin/fsl_abspath $InputCoefficients`
ORIGDIR=`pwd`
cd $WD
echo "gradient_unwarp.py ${BaseName}_vol1.nii.gz trilinear.nii.gz siemens -g ${InputCoeffs} -n" >> log.txt
# NB: gradient_unwarp.py *must* have the filename extensions written out explicitly or it will crash
gradient_unwarp.py ${BaseName}_vol1.nii.gz trilinear.nii.gz siemens -g $InputCoeffs -n
cd $ORIGDIR

# Now create an appropriate warpfield output (relative convention) and apply it to all timepoints
#convertwarp's jacobian output has 8 frames, each combination of one-sided differences, so average them
${FSLDIR}/bin/convertwarp --abs --ref=$WD/trilinear.nii.gz --warp1=$WD/fullWarp_abs.nii.gz --relout --out=$OutputTransform --jacobian=${OutputTransform}_jacobian
${FSLDIR}/bin/fslmaths ${OutputTransform}_jacobian -Tmean ${OutputTransform}_jacobian
${FSLDIR}/bin/applywarp --rel --interp=spline -i $InputFile -r $WD/${BaseName}_vol1.nii.gz -w $OutputTransform -o $OutputFile

log_Msg "END"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ########################################## 

if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# Check that the image output of gradient_unwarp.py is the same as from applywarp" >> $WD/qa.txt
echo "fslview $WD/trilinear $OutputFile" >> $WD/qa.txt
echo "# Optional (further) checking - results from fslstats should be very close to zero" >> $WD/qa.txt
echo "applywarp --rel --interp=trilinear -i $InputFile -r $WD/${BaseName}_vol1.nii.gz -w $OutputTransform -o $WD/qa_aw_tri" >> $WD/qa.txt
echo "fslmaths $WD/qa_aw_tri -sub $WD/trilinear $WD/diff_tri" >> $WD/qa.txt
echo "fslstats $WD/diff_tri -a -P 100 -M" >> $WD/qa.txt

##############################################################################################
