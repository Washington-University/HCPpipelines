#!/bin/bash 
set -e

# Requirements for this script
#  installed versions of: FSL5.0.1 or higher (including python with numpy, needed to run aff2rigid - part of FSL)
#  environment: FSLDIR

################################################ SUPPORT FUNCTIONS ##################################################

Usage() {
  echo "`basename $0`: Tool for creating a 6 DOF alignment of the AC, ACPC line and hemispheric plane in MNI space"
  echo " "
  echo "Usage: `basename $0` --workingdir=<working dir> --in=<input image> [--ref=<reference image> --ref=<reference brain image>] --out=<output image> --omat=<output matrix> [--brainsize=<brainsize>] [--brainextract=<EXVIVO or INVIVO (default)>] [--contrast=<T1w (default), T2w, FLAIR> requried for ANTS brain extraction]"
  echo ""
  exit
}
[[ $2 = "" ]] && Usage

if [ -z ${HCPPIPEDIR} ] ; then
	echo "ERROR: please set HCPPIPEDIR"
	exit
fi
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

# All except $Output variables, are saved in the Working Directory:
#     roi2full.mat, full2roi.mat, roi2std.mat, full2std.mat
#     robustroi.nii.gz  (the result of the initial cropping)
#     acpc_final.nii.gz (the 12 DOF registration result)
#     "$OutputMatrix"  (a 6 DOF mapping from the original image to the ACPC aligned version)
#     "$Output"  (the ACPC aligned image)

################################################## OPTION PARSING #####################################################

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options
if [ $# -lt 5 ] ; then Usage; exit 1; fi

# parse arguments
WD=`getopt1 "--workingdir" $@`  # "$1"
Input=`getopt1 "--in" $@`  # "$2"
Reference=`getopt1 "--ref" $@`  # "$3"
ReferenceBrain=`getopt1 "--refbrain" $@`  # "$4"
Output=`getopt1 "--out" $@`  # "$5"
OutputMatrix=`getopt1 "--omat" $@`  # "$6"
BrainSizeOpt=`getopt1 "--brainsize" $@`  # "$7"
BrainExtract=`getopt1 "--brainextract" $@`  # "$8"
Contrast=`getopt1 "--contrast" $@`  # "$9"
BetFraction=`getopt1 "--betfraction" $@` # "$10"
BetRadius=`getopt1 "--betradius" $@` # "$11"
BetTop2Center=`getopt1 "--bettop2center" $@` # "$12"
Reference2mm=`getopt1 "--ref2mm" $@` # "$13"
Reference2mmMask=`getopt1 "--ref2mmmask" $@` # "$14"
SPECIES=`getopt1 "--species" $@`

# default parameters
Reference=$(remove_ext `defaultopt ${Reference} ${FSLDIR}/data/standard/MNI152_T1_1mm`)
ReferenceMask=$(remove_ext `defaultopt ${ReferenceMask} MNI152_T1_1mm_brain_mask_dil.nii.gz`)
Output=$(remove_ext `$FSLDIR/bin/remove_ext $Output`)
WD=`defaultopt $WD ${Output}.wdir`
Input=$(remove_ext $Input)
Contrast=`defaultopt $Contrast T1w`

# make optional arguments truly optional  (as -b without a following argument would crash robustfov)
if [ X${BrainSizeOpt} != X ] ; then BrainSizeOpt="-b ${BrainSizeOpt}" ; fi

if [[ "$SPECIES" =~ Human ]] ; then
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

# Crop the FOV
verbose_echo " --> Croping the FOV with $BrainSizeOpt"
${FSLDIR}/bin/robustfov -i "$Input" -m "$WD"/roi2full.mat -r "$WD"/robustroi.nii.gz $BrainSizeOpt

# Invert the matrix (to get full FOV to ROI)
verbose_echo " --> Inverting the materix"
${FSLDIR}/bin/convert_xfm -omat "$WD"/full2roi.mat -inverse "$WD"/roi2full.mat
fslmaths "$Reference2mm" -mas "$Reference2mmMask" "$WD"/ReferenceBrain

# Register cropped image to MNI152 (12 DOF)

if [ $(imtest $(dirname "$Input")/custom_mask.nii.gz) = 1 ] ; then
	verbose_echo " --> Using custom_mask for linear registration"
	fslmaths "$Input" -mas $(dirname "$Input")/custom_mask.nii.gz "$Input"_custom_brain
	flirt -in "$Input"_custom_brain -ref "$WD"/robustroi.nii.gz -applyxfm -init "$WD"/full2roi.mat -o  "$WD"/robustroi_brain.nii.gz
	${FSLDIR}/bin/flirt -interp spline -in "$WD"/robustroi_brain.nii.gz -ref "$WD"/ReferenceBrain -omat "$WD"/roi2std.mat -out "$WD"/acpc_final.nii.gz -searchrx -30 30 -searchry -30 30 -searchrz -30 30 -dof 12
	if [ $(imtest "$Input"_dc_restore) = 1 ] ; then
		imrm  "$Input"_dc_restore
	fi
elif [ $BrainExtract = EXVIVO ] ; then
	verbose_echo " --> Run EXVIVO brain registration using ReferenceBrain"
	${FSLDIR}/bin/flirt -interp spline -in "$WD"/robustroi.nii.gz -ref "$WD"/ReferenceBrain -omat "$WD"/roi2std.mat -out "$WD"/acpc_final.nii.gz -searchrx -30 30 -searchry -30 30 -searchrz -30 30
elif [ $BrainExtract = ANTS ] ; then
	verbose_echo " --> Run BrainExtraction_ANTSbased"
	# TH Feb 2023
	verbose_echo " --> Apply BrainExtraction_ANTSbased"
	fslmaths "$ReferenceBrain" -bin "$WD"/ReferenceMask
	${HCPPIPEDIR_PreFS}/BrainExtraction_ANTSbased_RIKEN.sh --workingdir="$WD"/BrainExtraction_ANTSbased --in="$WD"/robustroi.nii.gz --ref="$Reference2mm"  --refmask="$Reference2mmMask" --outbrain="$WD"/robustroi_brain.nii.gz --outbrainmask="$WD"/robustroi_brain_mask.nii.gz --contrast=$Contrast
	verbose_echo " --> Run flirt using ANTS-based brain extracted volume"
	${FSLDIR}/bin/flirt -interp spline -in "$WD"/robustroi_brain.nii.gz -ref "$WD"/ReferenceBrain -omat "$WD"/roi2std.mat -out "$WD"/acpc_final.nii.gz -searchrx -30 30 -searchry -30 30 -searchrz -30 30
elif [ $BrainExtract = FSL ] ; then
	isopixdim=$(fslval "$Reference2mm" pixdim1)
	#flirt -in "$WD"/robustroi.nii.gz -ref "$WD"/robustroi.nii.gz -applyisoxfm $isopixdim -o "$WD"/robustroi2mm.nii.gz -interp sinc
	dim1=$(fslval "$WD"/robustroi.nii.gz dim1)
	dim2=$(fslval "$WD"/robustroi.nii.gz dim2)
	dim3=$(fslval "$WD"/robustroi.nii.gz dim3)
        pixdim3=$(fslval "$WD"/robustroi.nii.gz pixdim3)
	centerx=$(echo "$dim1*0.5" | bc | awk '{printf "%d", $1}')
	centery=$(echo "$dim2*0.5" | bc| awk '{printf "%d", $1}')
 	centerz=$(echo "$dim3 - $BetTop2Center/$pixdim3" | bc | awk '{printf "%d", $1}') 

	verbose_echo " --> Run initial BET with options: -m -r $BetRadius -c $centerx $centery $centerz -f $BetFraction -B -z $species"
	${HCPPIPEDIR_Global}/bet4animal "$WD"/robustroi.nii.gz "$WD"/robustroi_brain -m -r $BetRadius -c $centerx $centery $centerz -f $BetFraction -B -z $species
	verbose_echo " --> Registering brain extracted image to MNI152 (12 DOF)"
	${FSLDIR}/bin/flirt -interp spline -in "$WD"/robustroi_brain.nii.gz -ref "$WD"/ReferenceBrain -omat "$WD"/roi2std_init.mat -out "$WD"/acpc_final_init.nii.gz -searchrx -30 30 -searchry -30 30 -searchrz -30 30 -dof 6
	if [[ ! "$SPECIES" =~ Marmoset ]] ; then 
		verbose_echo " --> Registering cropped image to MNI152 (12 DOF)"
		${FSLDIR}/bin/flirt -interp spline -in "$WD"/robustroi.nii.gz -ref "$Reference2mm" -init "$WD"/roi2std_init.mat -omat "$WD"/roi2std.mat -out "$WD"/acpc_final.nii.gz -nosearch -dof 12 # -inweight "$WD"/robustroi_brain_mask -refweight "$Reference2mmMask" - 0609 did not work with these inweight & refweight
	else    # Marmoset is not needed for further registration
		cp "$WD"/roi2std_init.mat "$WD"/roi2std.mat
		${FSLDIR}/bin/flirt -interp spline -in "$WD"/robustroi.nii.gz -ref "$Reference2mm" -applyxfm -init "$WD"/roi2std.mat -out "$WD"/acpc_final.nii.gz 
	fi
else
	verbose_echo " --> Registering cropped image to MNI152 (12 DOF)"
	${FSLDIR}/bin/flirt -interp spline -in "$WD"/robustroi.nii.gz -ref "$Reference2mm" -omat "$WD"/roi2std.mat -out "$WD"/acpc_final.nii.gz -searchrx -30 30 -searchry -30 30 -searchrz -30 30
fi

verbose_echo " --> Geting a 6 DOF approximation"
# Concatenate matrices to get full FOV to MNI
${FSLDIR}/bin/convert_xfm -omat "$WD"/full2std.mat -concat "$WD"/roi2std.mat "$WD"/full2roi.mat

# Get a 6 DOF approximation which does the ACPC alignment (AC, ACPC line, and hemispheric plane)
#${FSLDIR}/bin/aff2rigid "$WD"/full2std.mat "$OutputMatrix"
${CARET7DIR}/wb_command -convert-affine -from-flirt "$WD"/full2std.mat "$Input".nii.gz "$Reference".nii.gz -to-world "$WD"/full2std_world.mat
${HCPPIPEDIR}/global/scripts/aff2rigid_world "$WD"/full2std_world.mat "$WD"/full2std_rigid_world.mat
${CARET7DIR}/wb_command -convert-affine -from-world "$WD"/full2std_rigid_world.mat -to-flirt "$OutputMatrix" "$Input".nii.gz "$Reference".nii.gz 

# Create a resampled image (ACPC aligned) using spline interpolation
verbose_echo " --> Creating a resampled image"
${FSLDIR}/bin/applywarp --rel --interp=spline -i "$Input" -r "$Reference" --premat="$OutputMatrix" -o "$Output"

if [ $(imtest $(dirname "$Input")/custom_mask.nii.gz) = 1 ] ; then
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
