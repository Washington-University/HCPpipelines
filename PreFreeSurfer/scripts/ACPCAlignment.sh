#!/bin/bash 
set -e

# Requirements for this script
#  installed versions of: FSL (including python with numpy, needed to run aff2rigid - part of FSL)
#  environment: HCPPIPEDIR, FSLDIR

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


opts_SetScriptDescription "Tool for creating a 6 DOF alignment of the AC, ACPC line and hemispheric plane in MNI space"

opts_AddMandatory '--workingdir' 'WD' 'path' 'working directory'

opts_AddMandatory '--in' 'Input' 'image' 'input image'

opts_AddMandatory '--out' 'Output' 'image' 'output_image'

opts_AddMandatory '--omat' 'OutputMatrix' 'matrix' 'output matrix'

#optional args
opts_AddOptional '--ref' 'Reference' 'image' 'reference image' "${FSLDIR}/data/standard/MNI152_T1_1mm"

opts_AddOptional '--brainsize' 'BrainSizeOpt' 'value' 'brainsize'

opts_AddOptional '--brainextract' 'BrainExtract' 'method' 'brain extraction method: EXVIVO or INVIVO (default)' "INVIVO"

opts_AddOptional '--contrast' 'Contrast' 'type' 'image contrast: T1w (default), T2w, FLAIR - required for ANTS brain extraction' "T1w"

opts_AddOptional '--betfraction' 'BetFraction' 'value' 'BET fractional intensity threshold' "0.3"

opts_AddOptional '--betradius' 'BetRadius' 'value' 'BET head radius' "75"

opts_AddOptional '--bettop2center' 'BetTop2Center' 'value' 'BET top to center distance' "86"

opts_AddOptional '--ref2mm' 'Reference2mm' 'image' '2mm reference image' ""

opts_AddOptional '--ref2mmmask' 'Reference2mmMask' 'image' '2mm reference mask' ""

opts_AddOptional '--betspecieslabel' 'betspecieslabel' 'value' 'BET species label' "0"

opts_AddOptional '--custommask' 'CustomMask' 'image' 'custom brain mask' "NONE"

opts_AddOptional '--species' 'SPECIES' 'string' 'species' "Human"


opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

log_Check_Env_Var FSLDIR

################################################### OUTPUT FILES #####################################################

# All except $Output variables, are saved in the Working Directory:
#     roi2full.mat, full2roi.mat, roi2std.mat, full2std.mat
#     robustroi.nii.gz  (the result of the initial cropping)
#     acpc_final.nii.gz (the 12 DOF registration result)
#     "$OutputMatrix"  (a 6 DOF mapping from the original image to the ACPC aligned version)
#     "$Output"  (the ACPC aligned image)

Output=`$FSLDIR/bin/remove_ext $Output`
if [[ "$WD" == "" ]]
then
    WD="${Output}.wdir"
fi


# make optional arguments truly optional  (as -b without a following argument would crash robustfov)
if [ X${BrainSizeOpt} != X ] ; then BrainSizeOpt="-b ${BrainSizeOpt}" ; fi

log_Msg "START"

verbose_echo " "
verbose_red_echo " ===> Running AC-PC Alignment"
verbose_echo " "
mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt

########################################## DO WORK ########################################## 

fslmaths "$Reference2mm" "$WD"/Reference
fslmaths "$Reference2mm" -mas "$Reference2mmMask" "$WD"/ReferenceBrain

# Crop the FOV
if [[ "$SPECIES" != "Human" ]] && [ $(imtest ${CustomMask}) = 1 ] ; then
  verbose_echo " --> Cropping the FOV with custom mask"
  fslmaths "$Input" -mas "$CustomMask" "$Input"_custom_brain
  ${FSLDIR}/bin/flirt -in "$Input"_custom_brain -ref "$WD"/ReferenceBrain -omat "$WD"/full2roi.mat -out "$WD"/robustroi_brain -searchrx -30 30 -searchry -30 30 -searchrz -30 30 -dof 6
  # Invert the matrix (to get ROI to full FOV)
  verbose_echo " --> Inverting the matrix"
  ${FSLDIR}/bin/convert_xfm -omat "$WD"/roi2full.mat -inverse "$WD"/full2roi.mat
else
  verbose_echo " --> Cropping the FOV with $BrainSizeOpt"
  ${FSLDIR}/bin/robustfov -i "$Input" -m "$WD"/roi2full.mat -r "$WD"/robustroi.nii.gz $BrainSizeOpt
  # Invert the matrix (to get full FOV to ROI)
  verbose_echo " --> Inverting the matrix"
  ${FSLDIR}/bin/convert_xfm -omat "$WD"/full2roi.mat -inverse "$WD"/roi2full.mat
fi

# Register cropped image to MNI152 (12 DOF)

if [[ "$SPECIES" != "Human" ]] && [ $(imtest ${CustomMask}) = 1 ] ; then
  verbose_echo " --> Using custom_mask for linear registration"
  ${FSLDIR}/bin/flirt -interp spline -in "$WD"/robustroi_brain.nii.gz -ref "$WD"/ReferenceBrain -omat "$WD"/roi2std.mat -out "$WD"/acpc_final.nii.gz -searchrx -30 30 -searchry -30 30 -searchrz -30 30 -dof 12
  if [ $(imtest "$Input"_dc_restore) = 1 ] ; then
    imrm  "$Input"_dc_restore
  fi
elif [[ "$SPECIES" != "Human" ]] && [ $BrainExtract = EXVIVO ] ; then
  verbose_echo " --> Run EXVIVO brain registration using ReferenceBrain"
  ${FSLDIR}/bin/flirt -interp spline -in "$WD"/robustroi.nii.gz -ref "$WD"/ReferenceBrain -omat "$WD"/roi2std.mat -out "$WD"/acpc_final.nii.gz -searchrx -30 30 -searchry -30 30 -searchrz -30 30
elif [[ "$SPECIES" != "Human" ]] && [ $BrainExtract = INVIVO ] ; then
  isopixdim=$(fslval "$Reference2mm" pixdim1)
  #flirt -in "$WD"/robustroi.nii.gz -ref "$WD"/robustroi.nii.gz -applyisoxfm $isopixdim -o "$WD"/robustroi2mm.nii.gz -interp sinc
  dim1=$(fslval "$WD"/robustroi.nii.gz dim1)
  dim2=$(fslval "$WD"/robustroi.nii.gz dim2)
  dim3=$(fslval "$WD"/robustroi.nii.gz dim3)
  pixdim3=$(fslval "$WD"/robustroi.nii.gz pixdim3)
  centerx=$(echo "$dim1*0.5" | bc | awk '{printf "%d", $1}')
  centery=$(echo "$dim2*0.48" | bc| awk '{printf "%d", $1}')
  centerz=$(echo "$dim3 - $BetTop2Center/$pixdim3" | bc | awk '{printf "%d", $1}') 
  if [ "$BiasfieldCor" = TRUE ] ; then
    BC="-B"
  fi
  verbose_echo " --> Run initial BET with options: -m -r $BetRadius -c $centerx $centery $centerz -f $BetFraction -z $betspecieslabel $BC"
  ${HCPPIPEDIR_Global}/bet4animal "$WD"/robustroi.nii.gz "$WD"/robustroi_brain -m -r $BetRadius -c $centerx $centery $centerz -f $BetFraction -z $betspecieslabel $BC
  verbose_echo " --> Registering brain extracted image to MNI152 (12 DOF)"
  ${FSLDIR}/bin/flirt -interp spline -in "$WD"/robustroi_brain.nii.gz -ref "$WD"/ReferenceBrain -omat "$WD"/roi2std_init.mat -out "$WD"/acpc_final_init.nii.gz -searchrx -30 30 -searchry -30 30 -searchrz -30 30 -dof 6
  verbose_echo " --> Registering cropped image to MNI152 (12 DOF)"
  ${FSLDIR}/bin/flirt -interp spline -in "$WD"/robustroi.nii.gz -ref "$WD"/Reference -init "$WD"/roi2std_init.mat -omat "$WD"/roi2std.mat -out "$WD"/acpc_final.nii.gz -nosearch -dof 12 # -inweight "$WD"/robustroi_brain_mask -refweight "$Reference2mmMask" - 0609 did not work with these inweight & refweight
else              # NONE 
  verbose_echo " --> Registering cropped image to MNI152 (12 DOF)"
  ${FSLDIR}/bin/flirt -interp spline -in "$WD"/robustroi.nii.gz -ref "$Reference2mm" -omat "$WD"/roi2std.mat -out "$WD"/acpc_final.nii.gz -searchrx -30 30 -searchry -30 30 -searchrz -30 30
fi

verbose_echo " --> Getting a 6 DOF approximation"
# Concatenate matrices to get full FOV to MNI
verbose_echo " --> Concatenating matrices to get full FOV to MNI"
${FSLDIR}/bin/convert_xfm -omat "$WD"/full2std.mat -concat "$WD"/roi2std.mat "$WD"/full2roi.mat

# Get a 6 DOF approximation which does the ACPC alignment (AC, ACPC line, and hemispheric plane)
verbose_echo " --> Geting a 6 DOF approximation"
#${FSLDIR}/bin/aff2rigid "$WD"/full2std.mat "$OutputMatrix"
${CARET7DIR}/wb_command -convert-affine -from-flirt "$WD"/full2std.mat "$Input".nii.gz "$Reference".nii.gz -to-world "$WD"/full2std_world.mat
${HCPPIPEDIR}/global/scripts/aff2rigid_world "$WD"/full2std_world.mat "$WD"/full2std_rigid_world.mat
${CARET7DIR}/wb_command -convert-affine -from-world "$WD"/full2std_rigid_world.mat -to-flirt "$OutputMatrix" "$Input".nii.gz "$Reference".nii.gz 

# Create a resampled image (ACPC aligned) using spline interpolation
verbose_echo " --> Creating a resampled image"
${FSLDIR}/bin/applywarp --rel --interp=spline -i "$Input" -r "$Reference" --premat="$OutputMatrix" -o "$Output"

if [[ "$SPECIES" != "Human" ]] && [ $(imtest ${CustomMask}) = 1 ] ; then
  ${FSLDIR}/bin/applywarp --rel --interp=nn -i $(dirname "$Input")/custom_mask.nii.gz -r "$Reference" --premat="$OutputMatrix" -o "$Output"_custom_brain_mask
  fslmaths "$Output" -mas "$Output"_custom_brain_mask "$Output"_custom_brain
fi

verbose_green_echo "---> Finished AC-PC Alignment"
verbose_echo " "

log_Msg "END"
echo "END: `date`" >> $WD/log.txt

########################################## QA STUFF ########################################## 

if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# Check that the following image does not cut off any brain tissue" >> $WD/qa.txt
echo "fslview $WD/robustroi" >> $WD/qa.txt
echo "# Check that the alignment to the reference image is acceptable (the top/last image is spline interpolated)" >> $WD/qa.txt
echo "fslview $Reference $WD/acpc_final $Output" >> $WD/qa.txt

##############################################################################################
