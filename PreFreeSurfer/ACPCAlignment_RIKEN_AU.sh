#!/bin/bash

# Requirements for this script
#  installed versions of: FSL (including python with numpy, needed to run aff2rigid - part of FSL)
#  environment: HCPPIPEDIR, FSLDIR

# ------------------------------------------------------------------------------
#  Usage Description Function
# ------------------------------------------------------------------------------


set -e

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

opts_AddMandatory '--in' 'Input' 'image' 'inputvimage'

opts_AddMandatory '--out' 'Output' 'image' 'output_image'

opts_AddMandatory '--omat' 'OutputMatrix' 'matrix' 'output matrix'

#optional args
opts_AddOptional '--ref' 'Reference' 'image' 'reference image' "${FSLDIR}/data/standard/MNI152_T1_1mm"

opts_AddOptional '--brainsize' 'BrainSizeOpt' 'value' 'brainsize'

opts_AddOptional '--identmat' 'IdentMat' 'NONE or TRUE' "Do regisration in ACPCAlignment, T2wToT1Reg and AtlasRegistration (NONE) or not (TRUE)" # added by A.Uematsu on 2024/2/3

opts_AddOptional '--species' 'SPECIES' 'Human, Macaque, or Marmoset' "Processing either Human or Nonhuman primates paramteters.  'Humans' (the default) follows the HCP processing steps" # added by A.Uematsu on 2024/2/3

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

# Record the input options in a log files
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt

########################################## DO WORK ##########################################

if [ $IdentMat = "NONE" ] ; then

	# Crop the FOV
	verbose_echo " --> Croping the FOV"
	if [ `${FSLDIR}/bin/imtest ${Input}_brain` = 1 ] ; then
		${FSLDIR}/bin/robustfov -i "$Input"_brain -m "$WD"/roi2full.mat -r "$WD"/robustroi.nii.gz #$BrainSizeOpt
	else
	echo "Not found ${Input}_brain.nii.gz. Use $Input for init registration"
		${FSLDIR}/bin/robustfov -i "$Input" -m "$WD"/roi2full.mat -r "$WD"/robustroi.nii.gz #$BrainSizeOpt
	fi
	# Invert the matrix (to get full FOV to ROI)
	verbose_echo " --> Inverting the matrix"
	${FSLDIR}/bin/convert_xfm -omat "$WD"/full2roi.mat -inverse "$WD"/roi2full.mat

	# Register cropped image to MNI152 (12 DOF)
	verbose_echo " --> Registering cropped image to MNI152 (12 DOF)"
	${FSLDIR}/bin/flirt -interp spline -in "$WD"/robustroi.nii.gz -ref "$Reference" -omat "$WD"/roi2std.mat -out "$WD"/acpc_final.nii.gz -searchrx -30 30 -searchry -30 30 -searchrz -30 30

	# Concatenate matrices to get full FOV to MNI
	verbose_echo " --> Concatenating matrices to get full FOV to MNI"
	${FSLDIR}/bin/convert_xfm -omat "$WD"/full2std.mat -concat "$WD"/roi2std.mat "$WD"/full2roi.mat

	# Get a 6 DOF approximation which does the ACPC alignment (AC, ACPC line, and hemispheric plane)
	verbose_echo " --> Geting a 6 DOF approximation"
	if [[ $SPECIES == "Marmoset" ]] ; then
		verbose_echo " --> marmoset"
		${HCPPIPEDIR}/PreFreeSurfer/scripts/aff2rigid_marmoset "$WD"/full2std.mat "$OutputMatrix"
	elif [[ $SPECIES == "Macaque" ]] ; then
			verbose_echo " --> macaque"
	#	${HCPPIPEDIR}/global/scripts/aff2rigid_world "$WD"/full2std.mat "$OutputMatrix"
	#${HCPPIPEDIR}/PreFreeSurfer/scripts/aff2rigid_macaque2 "$WD"/full2std.mat "$OutputMatrix"
	${HCPPIPEDIR}/global/scripts/aff2rigid_world "$WD"/full2std_world.mat "$WD"/full2std_rigid_world.mat
    ${CARET7DIR}/wb_command -convert-affine -from-world "$WD"/full2std_rigid_world.mat -to-flirt "$OutputMatrix" "$Input".nii.gz "$Reference"

	else
		${FSLDIR}/bin/aff2rigid "$WD"/full2std.mat "$OutputMatrix"
	fi

	# Create a resampled image (ACPC aligned) using spline interpolation
	verbose_echo " --> Creating a resampled image"
	${FSLDIR}/bin/applywarp --rel --interp=spline -i "$Input" -r "$Reference" --premat="$OutputMatrix" -o "$Output"

	if [[ `${FSLDIR}/bin/imtest ${Input}_brain` = 1 ]] ; then
	 fslmaths "$Input"_brain -thr 0 -bin "$Input"_brain_mask # Inserted by Takuya Hayashi
	 ${FSLDIR}/bin/applywarp --rel --interp=nn -i "$Input"_brain_mask -r "$Reference" --premat="$OutputMatrix" -o $(dirname ${Input})/custom_acpc_dc_restore_mask.nii.gz
	 fslmaths "$Output" -mas $(dirname ${Input})/custom_acpc_dc_restore_mask.nii.gz "$Output"_brain # Inserted by Takuya Hayashi
	fi

else
	verbose_echo " --> Copy ident.mat"
	cp -v ${FSLDIR}/etc/flirtsch/ident.mat "$OutputMatrix" # Inserted by Takuya Hayashi
	${FSLDIR}/bin/imcp "$Input" "$Output" # Inserted by Takuya Hayashi
	${FSLDIR}/bin/imcp "$Input"_brain "$Output"_brain # Inserted by Takuya Hayashi
fi

verbose_green_echo "---> Finished AC-PC Alignment"
verbose_echo " "

log_Msg "END"
echo " END: `date`" >> $WD/log.txt

########################################## QA STUFF ##########################################

if [ -e $WD/qa.txt ] ; then rm -f $WD/qa.txt ; fi
echo "cd `pwd`" >> $WD/qa.txt
echo "# Check that the following image does not cut off any brain tissue" >> $WD/qa.txt
echo "fsleyes $WD/robustroi" >> $WD/qa.txt
echo "# Check that the alignment to the reference image is acceptable (the top/last image is spline interpolated)" >> $WD/qa.txt
echo "fsleyes $Reference $WD/acpc_final $Output" >> $WD/qa.txt

##############################################################################################
