#!/bin/bash
set -e

# Requirements for this script
#  installed versions of: FSL6.0.4 or higher , FreeSurfer (version 5.3.0 or higher) ,
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET7DIR

usage () {
echo "Usage: $0 <SubjectID> <SubjectDIR> <T1w_acpc_dc_restore> <T2w_acpc_dc_restore> <T2wType> <MaxThickness> <VariableSigma> <GreySigma> <T2w LowPass>"
exit 1;
}
[ "$6" = "" ] && usage

echo -e "\n START: FreeSurferHiresPial"
echo -e "\n with flags $@"

SubjectID="$1"
SubjectDIR="$2"
T1wImage="$3" #T1w FreeSurfer Input (Full Resolution)
T2wImage="$4" #T2w FreeSurfer Input (Full Resolution)
T2wType="$5"
# SPECIES specific params - TH Jan 2018 - Feb 2023
MaxThickness=$6
VariableSigma="$7"
#Sigma controls smoothness of within grey matter tissue contrast field being removed
GreySigma="$8"
LowPass="$9"  # Used for sigma of T2w biasfield, which is likely related to brain size

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source ${HCPPIPEDIR}/global/scripts/opts.shlib                 # Command line option functions
log_SetToolName "FreeSurferHiresPial.sh"

log_Msg "SPECIES: $SPECIES"
log_Msg "VARIABLESIGMA: $VariableSigma"
log_Msg "MAXTHICKNESS: $MaxThickness"
log_Msg "T2wType: $T2wType"
if [ "${T2wType}" = "T2w" ] ; then
  T2wFlag="-T2"
elif [ "${T2wType}" = "FLAIR" ] ; then
  T2wFlag="-FLAIR"
fi
log_Msg "T2wFlag: $T2wFlag"
log_Msg "GreySigma: $GreySigma"

nsigma_below=3  # default 3  M167:4
nsigma_above=2.5  # default 2. M167:3 
if [ $SPECIES = Marmoset ] ; then
	nsigma_below=6
	nsigma_above=2
fi
if [ $T2wFlag = "-FLAIR" ] ; then
	nsigma_below=3     # FS5
	nsigma_above=3     # FS5
#	nsigma_below=0.5   # FS6 in NHP?
#	nsigma_above=3     # FS6 in NHP?
#	opts="-erase_cerebellum" # FS6 in NHP
fi
log_Msg "nsigma_below: $nsigma_below"
log_Msg "nsigma_above: $nsigma_above"

export SUBJECTS_DIR="$SubjectDIR"

niter=1
if [ $SPECIES = Marmoset ] ; then
	niter=5
fi

mridir=$SubjectDIR/$SubjectID/mri
surfdir=$SubjectDIR/$SubjectID/surf
reg=${mridir}/transforms/hires21mm.dat
regII=${mridir}/transforms/1mm2hires.dat

T1wImageFile=`remove_ext $T1wImage`;

if [[ ! $T2wImage =~ NONE ]] ; then
	# biasfield correction of T2w_hires. T2w bias field is likely related to brain size - TH Apr 2023
	mri_convert "$mridir"/T2w_hires.nii.gz "$mridir"/T2w_hires.mgz  # T2w_hires.nii.gz is already in RSP in hires white 
	${HCPPIPEDIR_FS}/IntensityCor.sh "$mridir"/T2w_hires.mgz "$mridir"/T1w_hires.masked.norm.mgz "$mridir"/T2w_hires.intensitycor.mgz -t2 $mridir/wm.roi.hires.mgz -m FAST $LowPass  
	cp "$mridir"/T2w_hires.intensitycor.mgz "$mridir"/T2w_hires.norm.mgz
fi

# T1wHiresNorm is used for estimating initial pial surface. 'T1w_hires.masked.norm' maybe useful to avoid the pial surface placed outward from the true pial 
# (e.g. in the dura and bone marrow). This is often seen if the MPRAGE was obtained with FAT SAT=OFF or with a single channnel coil. -TH Mar 2023

T1wHiresNorm="T1w_hires.masked.norm" 
#T1wHiresNorm="T1w_hires.norm"    # T1w_hires.norm or T1w_hires.masked.norm

# Replace accumbens,caudate and lateral ventricle to putamen in aseg to avoid subgenual pial errors - TH, Nov 2019
DIR=`pwd`
cd $mridir
mri_convert -rl "$mridir"/T1w_hires.nii.gz -rt nearest aseg+claustrum.mgz aseg+claustrum.nii.gz
if [[ ! $Subcort2Putamen = NONE ]] ; then
	fslmaths aseg+claustrum -bin -mul 0 appendputamen.rh
	fslmaths aseg+claustrum -bin -mul 0 appendputamen.lh
	fslmaths aseg+claustrum -thr 58 -uthr 58 -bin -mul 51 -add appendputamen.rh appendputamen.rh  # accumbens rh
	fslmaths aseg+claustrum -thr 26 -uthr 26 -bin -mul 12 -add appendputamen.lh appendputamen.lh  # accumbens lh
	fslmaths aseg+claustrum -thr 50 -uthr 50 -bin -mul 51 -add appendputamen.rh appendputamen.rh # caudate rh
	fslmaths aseg+claustrum -thr 11 -uthr 11 -bin -mul 12 -add appendputamen.lh appendputamen.lh # caudate lh
	fslmaths aseg+claustrum -thr 43 -uthr 43 -bin -mul 51 -add appendputamen.rh appendputamen.rh # lateral ventricle rh
	fslmaths aseg+claustrum -thr  4 -uthr  4 -bin -mul 12 -add appendputamen.lh appendputamen.lh # lateral ventricle lh
	fslmaths aseg+claustrum -thr 58 -uthr 58 -bin -mul -32 -add aseg+claustrum -thr 26 -uthr 26 -binv -mul aseg+claustrum aseg.pial
	fslmaths aseg.pial -thr 50 -uthr 50 -bin -mul -39 -add aseg.pial -thr 11 -uthr 11 -binv -mul aseg.pial aseg.pial
	fslmaths aseg.pial -thr 43 -uthr 43 -bin -mul -39 -add aseg.pial -thr  4 -uthr  4 -binv -mul aseg.pial aseg.pial
	fslmaths aseg.pial -add appendputamen.lh -add appendputamen.rh aseg.pial -odt char
	imrm appendputamen.?h.nii.gz
else 
	fslmaths aseg+claustrum aseg.pial
fi

## Fix pial at pericallosal area and suppress incorrect callosomarginal sulcus in marmoset - TH Oct 2021
if [[ $SPECIES =~ Marmoset ]] ; then
	applywarp -i "$GCAdir"/paracallosum -r ../../T1w_acpc_dc_restore -w \
	../../../MNINonLinear/xfms/standard2acpc_dc -o paracallosum --interp=nn
	$CARET7DIR/wb_command -volume-reorient paracallosum.nii.gz RSP paracallosum.nii.gz 
	# Replace mid and paracallosal voxels to 3rd ventricle
	fslmaths paracallosum -s 0.2 -thr 0.2 -bin paracallosum.roi
	fslmaths aseg.pial -mas paracallosum.roi -thr 2 -uthr 2 -bin -mul 14 paracallosum_wm.lh
	fslmaths aseg.pial -mas paracallosum.roi -thr 41 -uthr 41 -bin -mul 14 paracallosum_wm.rh
	fslmaths aseg.pial -mas paracallosum.roi -thr 251 -uthr 255 -bin -mul 14 paracallosum_cc
	fslmaths paracallosum_wm.lh -add paracallosum_wm.rh -add paracallosum_cc paracallosum_seg
	# Replace zero to 3rd ventricle in the neighbouring paracallosal voxels 
	fslmaths aseg.pial -binv -mas paracallosum.roi aseg.pial.inv.roi 
	fslmaths paracallosum_seg -dilM -mas aseg.pial.inv.roi -add paracallosum_seg paracallosum_seg
	fslmaths paracallosum_seg -binv paracallosum_seg_inv
	fslmaths aseg.pial -mas paracallosum_seg_inv -add paracallosum_seg aseg.pial
	imrm paracallosum paracallosum.roi paracallosum_wm.?h paracallosum_cc paracallosum_seg_inv aseg.pial.inv.roi
fi
mri_convert -ns 1 -odt uchar aseg.pial.nii.gz aseg.pial.mgz
mri_convert -rl "$mridir"/T1w_hires.nii.gz -rt nearest $mridir/aseg.pial.mgz $mridir/aseg.hires.pial.mgz
rm aseg+claustrum.nii.gz aseg.pial.mgz aseg.pial.nii.gz

cd $DIR

log_Msg "mris_make_surface 1 using T1w hires"
MrisMakeSurfacesDir=/usr/local/freesurfer-v5.3.0-HCP/bin

$MrisMakeSurfacesDir/mris_make_surfaces -max $MaxThickness -variablesigma $VariableSigma -white NOWRITE -aseg aseg.hires.pial -orig white -filled filled.hires -wm wm.hires -sdir $SubjectDIR -mgz -T1 "$T1wHiresNorm" $SubjectID lh
$MrisMakeSurfacesDir/mris_make_surfaces -max $MaxThickness -variablesigma $VariableSigma -white NOWRITE -aseg aseg.hires.pial -orig white -filled filled.hires -wm wm.hires -sdir $SubjectDIR -mgz -T1 "$T1wHiresNorm" $SubjectID rh

mris_smooth -n $niter -nw $surfdir/lh.pial  $surfdir/lh.pial 
mris_smooth -n $niter -nw $surfdir/rh.pial  $surfdir/rh.pial 

cp --preserve=timestamps $surfdir/lh.pial $surfdir/lh.pial.preT2.pass1
cp --preserve=timestamps $surfdir/rh.pial $surfdir/rh.pial.preT2.pass1

if [[ ! "$T2wFlag" =~ "NONE" && ! $T2wImage =~ NONE ]] ; then 

	log_Msg "mris_make_surface 1 using T2wHires"
	#For mris_make_surface with correct arguments #Could go from 3 to 2 potentially...
	outputSuffix1=".postT2.pass1"  
	
	$MrisMakeSurfacesDir/mris_make_surfaces -nsigma_above $nsigma_above -nsigma_below $nsigma_below -sdir $SubjectDIR -orig white -filled filled.hires -wm wm.hires -nowhite -orig_white white -orig_pial pial $T2wFlag $mridir/T2w_hires.norm -T1 "$T1wHiresNorm" -aseg aseg.hires.pial -output $outputSuffix1 $SubjectID lh $opts
	$MrisMakeSurfacesDir/mris_make_surfaces -nsigma_above $nsigma_above -nsigma_below $nsigma_below -sdir $SubjectDIR -orig white -filled filled.hires -wm wm.hires -nowhite -orig_white white -orig_pial pial $T2wFlag $mridir/T2w_hires.norm -T1 "$T1wHiresNorm" -aseg aseg.hires.pial -output $outputSuffix1 $opts $SubjectID rh $opts

	mris_smooth -n $niter -nw $surfdir/lh.pial${outputSuffix1}  $surfdir/lh.pial${outputSuffix1} 
	mris_smooth -n $niter -nw $surfdir/rh.pial${outputSuffix1}  $surfdir/rh.pial${outputSuffix1} 

else
	verbose_red_echo "---> No T2w image, skipping generation of pial first pass surfaces with T2 adjustment."
	outputSuffix1=".preT2.pass1"
fi

# Bring pial surfaces out of highres space into the 1 mm (FS conformed) space
# [Note that $regII, although named 1mm2hires.dat, actually maps from the hires space into the FS conformed space].
if [ `cat ${FREESURFER_HOME}/build-stamp.txt | grep v6.0` ] ; then 
	mri_surf2surf --s $SubjectID --sval-xyz pial${outputSuffix1} --reg $regII $mridir/orig.mgz --tval-xyz "$mridir"/T1w_hires.nii.gz --tval pial --hemi lh
	mri_surf2surf --s $SubjectID --sval-xyz pial${outputSuffix1} --reg $regII $mridir/orig.mgz --tval-xyz "$mridir"/T1w_hires.nii.gz --tval pial --hemi rh
elif [ `cat ${FREESURFER_HOME}/build-stamp.txt | grep v5.3.0` ] ; then 
	mri_surf2surf --s $SubjectID --sval-xyz pial${outputSuffix1} --reg $regII $mridir/orig.mgz --tval-xyz  --tval pial --hemi lh
	mri_surf2surf --s $SubjectID --sval-xyz pial${outputSuffix1} --reg $regII $mridir/orig.mgz --tval-xyz  --tval pial --hemi rh
fi


cp --preserve=timestamps $surfdir/lh.pial $surfdir/lh.pial${outputSuffix1}.conformed
cp --preserve=timestamps $surfdir/rh.pial $surfdir/rh.pial${outputSuffix1}.conformed

# Deal with FreeSurfer c_ras offset (might be able to simplify this with FS 6.0)
# -- Corrected code using native mri_info --cras function to build the needed variables
MatrixXYZ=`mri_info --cras ${mridir}/brain.finalsurfs.mgz`
MatrixX=`echo ${MatrixXYZ} | awk '{print $1;}'`
MatrixY=`echo ${MatrixXYZ} | awk '{print $2;}'`
MatrixZ=`echo ${MatrixXYZ} | awk '{print $3;}'`
echo "1 0 0 ${MatrixX}" >  ${mridir}/c_ras.mat
echo "0 1 0 ${MatrixY}" >> ${mridir}/c_ras.mat
echo "0 0 1 ${MatrixZ}" >> ${mridir}/c_ras.mat
echo "0 0 0 1"          >> ${mridir}/c_ras.mat

	log_Msg "Calculating T1w_hires.graynorm"
	mris_convert "$surfdir"/lh.white "$surfdir"/lh.white.surf.gii
	${CARET7DIR}/wb_command -set-structure "$surfdir"/lh.white.surf.gii CORTEX_LEFT 
	${CARET7DIR}/wb_command -surface-apply-affine "$surfdir"/lh.white.surf.gii $mridir/c_ras.mat "$surfdir"/lh.white.surf.gii
	${CARET7DIR}/wb_command -create-signed-distance-volume "$surfdir"/lh.white.surf.gii "$mridir"/T1w_hires.nii.gz "$surfdir"/lh.white.nii.gz

	mris_convert "$surfdir"/lh.pial "$surfdir"/lh.pial.surf.gii
	${CARET7DIR}/wb_command -set-structure "$surfdir"/lh.pial.surf.gii CORTEX_LEFT 
	${CARET7DIR}/wb_command -surface-apply-affine "$surfdir"/lh.pial.surf.gii $mridir/c_ras.mat "$surfdir"/lh.pial.surf.gii
	${CARET7DIR}/wb_command -create-signed-distance-volume "$surfdir"/lh.pial.surf.gii "$mridir"/T1w_hires.nii.gz "$surfdir"/lh.pial.nii.gz

	mris_convert "$surfdir"/rh.white "$surfdir"/rh.white.surf.gii
	${CARET7DIR}/wb_command -set-structure "$surfdir"/rh.white.surf.gii CORTEX_RIGHT 
	${CARET7DIR}/wb_command -surface-apply-affine "$surfdir"/rh.white.surf.gii $mridir/c_ras.mat "$surfdir"/rh.white.surf.gii
	${CARET7DIR}/wb_command -create-signed-distance-volume "$surfdir"/rh.white.surf.gii "$mridir"/T1w_hires.nii.gz "$surfdir"/rh.white.nii.gz

	mris_convert "$surfdir"/rh.pial "$surfdir"/rh.pial.surf.gii
	${CARET7DIR}/wb_command -set-structure "$surfdir"/rh.pial.surf.gii CORTEX_RIGHT 
	${CARET7DIR}/wb_command -surface-apply-affine "$surfdir"/rh.pial.surf.gii $mridir/c_ras.mat "$surfdir"/rh.pial.surf.gii
	${CARET7DIR}/wb_command -create-signed-distance-volume "$surfdir"/rh.pial.surf.gii "$mridir"/T1w_hires.nii.gz "$surfdir"/rh.pial.nii.gz

	# Normalize T1w image for low spatial frequency variations in myelin content (especially to improve pial surface capture of very lightly myelinated cortex)
	#fslmaths "$surfdir"/lh.white.nii.gz -mul "$surfdir"/lh.pial.nii.gz -uthr 0 -mul -1 -bin "$mridir"/lh.ribbon.nii.gz
	#fslmaths "$surfdir"/rh.white.nii.gz -mul "$surfdir"/rh.pial.nii.gz -uthr 0 -mul -1 -bin "$mridir"/rh.ribbon.nii.gz
	# Avoid errors from (occational) positive values 'inside' the surface in the output of wb_command -create-signed-distance-volume 
	fslmaths "$surfdir"/lh.pial.nii.gz -uthr 0 -abs -mul "$surfdir"/lh.white.nii.gz -thr 0 -bin "$mridir"/lh.ribbon.nii.gz
	fslmaths "$surfdir"/rh.pial.nii.gz -uthr 0 -abs -mul "$surfdir"/rh.white.nii.gz -thr 0 -bin "$mridir"/rh.ribbon.nii.gz
	fslmaths "$mridir"/lh.ribbon.nii.gz -add "$mridir"/rh.ribbon.nii.gz -bin "$mridir"/ribbon.nii.gz
	mri_convert "$mridir"/"$T1wHiresNorm".mgz "$mridir"/"$T1wHiresNorm".nii.gz
  	fslcpgeom "$mridir"/"$T1wHiresNorm".nii.gz "$mridir"/ribbon.nii.gz

	fslmaths "$mridir"/ribbon.nii.gz -s $GreySigma "$mridir"/ribbon_s"$GreySigma".nii.gz
	fslmaths "$mridir"/"$T1wHiresNorm".nii.gz -mas "$mridir"/ribbon.nii.gz "$mridir"/"$T1wHiresNorm"_ribbon.nii.gz
	greymean=`fslstats "$mridir"/"$T1wHiresNorm"_ribbon.nii.gz -M`
	fslmaths "$mridir"/ribbon.nii.gz -sub 1 -mul -1 "$mridir"/ribbon_inv.nii.gz

	fslmaths "$mridir"/"$T1wHiresNorm"_ribbon.nii.gz -s $GreySigma -div "$mridir"/ribbon_s"$GreySigma".nii.gz -div $greymean -mas "$mridir"/ribbon.nii.gz -add "$mridir"/ribbon_inv.nii.gz 	"$mridir"/"$T1wHiresNorm"_ribbon_myelin.nii.gz

	fslmaths "$surfdir"/lh.white.nii.gz -uthr 0 -mul -1 -bin "$mridir"/lh.white.nii.gz
	fslmaths "$surfdir"/rh.white.nii.gz -uthr 0 -mul -1 -bin "$mridir"/rh.white.nii.gz
	fslmaths "$mridir"/lh.white.nii.gz -add "$mridir"/rh.white.nii.gz -bin "$mridir"/white.nii.gz
	rm "$mridir"/lh.white.nii.gz "$mridir"/rh.white.nii.gz

	fslmaths "$mridir"/"$T1wHiresNorm"_ribbon_myelin.nii.gz -mas "$mridir"/ribbon.nii.gz -add "$mridir"/white.nii.gz -uthr 1.9 "$mridir"/"$T1wHiresNorm"_grey_myelin.nii.gz
	fslmaths "$mridir"/"$T1wHiresNorm"_grey_myelin.nii.gz -dilM -dilM -dilM -dilM -dilM "$mridir"/"$T1wHiresNorm"_grey_myelin.nii.gz
	fslmaths "$mridir"/"$T1wHiresNorm"_grey_myelin.nii.gz -binv "$mridir"/dilribbon_inv.nii.gz
	fslmaths "$mridir"/"$T1wHiresNorm"_grey_myelin.nii.gz -add "$mridir"/dilribbon_inv.nii.gz "$mridir"/"$T1wHiresNorm"_grey_myelin.nii.gz

	fslmaths "$mridir"/"$T1wHiresNorm".nii.gz -div "$mridir"/"$T1wHiresNorm"_ribbon_myelin.nii.gz "$mridir"/T1w_hires.greynorm_ribbon.nii.gz
	fslmaths "$mridir"/"$T1wHiresNorm".nii.gz -div "$mridir"/"$T1wHiresNorm"_grey_myelin.nii.gz "$mridir"/T1w_hires.greynorm.nii.gz

	mri_convert "$mridir"/T1w_hires.greynorm.nii.gz "$mridir"/T1w_hires.greynorm.mgz
	imrm "$mridir"/T1w_hires.greynorm.nii.gz "$mridir"/white.nii.gz
## ------ Second pass ------

#Check if FreeSurfer is version 5.2.0 or not.
if [ -z `cat ${FREESURFER_HOME}/build-stamp.txt | grep v5.2.0` ] ; then  #Not using v5.2.0
  VARIABLESIGMA="4"
else  #Using v5.2.0
  VARIABLESIGMA="2"
fi

log_Msg "mris_make_surface 2 using T1w_hires.greynorm"
$MrisMakeSurfacesDir/mris_make_surfaces -max $MaxThickness -variablesigma $VariableSigma -white NOWRITE -aseg aseg.hires.pial -orig white -filled filled.hires -wm wm.hires -sdir $SubjectDIR -mgz -T1 T1w_hires.greynorm $SubjectID lh 
mris_smooth -n $niter -nw $surfdir/lh.pial  $surfdir/lh.pial 
$MrisMakeSurfacesDir/mris_make_surfaces -max $MaxThickness -variablesigma $VariableSigma -white NOWRITE -aseg aseg.hires.pial -orig white -filled filled.hires -wm wm.hires -sdir $SubjectDIR -mgz -T1 T1w_hires.greynorm $SubjectID rh
mris_smooth -n $niter -nw $surfdir/rh.pial  $surfdir/rh.pial 

cp --preserve=timestamps $surfdir/lh.pial $surfdir/lh.pial.preT2.pass2
cp --preserve=timestamps $surfdir/rh.pial $surfdir/rh.pial.preT2.pass2
cp --preserve=timestamps $surfdir/lh.thickness $surfdir/lh.thickness.preT2.pass2
cp --preserve=timestamps $surfdir/rh.thickness $surfdir/rh.thickness.preT2.pass2
cp --preserve=timestamps $surfdir/lh.area.pial $surfdir/lh.area.pial.preT2.pass2
cp --preserve=timestamps $surfdir/rh.area.pial $surfdir/rh.area.pial.preT2.pass2
cp --preserve=timestamps $surfdir/lh.curv.pial $surfdir/lh.curv.pial.preT2.pass2
cp --preserve=timestamps $surfdir/rh.curv.pial $surfdir/rh.curv.pial.preT2.pass2

if [ ! "${T2wImage}" = "NONE" ] ; then
 	verbose_red_echo "---> Generating pial second pass surfaces with T2 adjustment."
  	# Generate pial surfaces with T2 adjustment, second pass.
  	# Same 4 files created as above, but have $outputSuffix2 ("postT2.pass2") appended through use of -output flag
	#Could go from 3 to 2 potentially...

	log_Msg "mris_make_surface 2 using T2w_hires"
	outputSuffix2=".postT2.pass2"
	$MrisMakeSurfacesDir/mris_make_surfaces -max $MaxThickness -nsigma_above $nsigma_above -nsigma_below $nsigma_below -aseg aseg.hires.pial -mgz -sdir $SubjectDIR -orig white -filled filled.hires -wm wm.hires -nowhite -orig_white white -orig_pial pial $T2wFlag $mridir/T2w_hires.norm -T1 "$T1wHiresNorm" -output $outputSuffix2 $SubjectID lh $opts
	mris_smooth -n $niter -nw $surfdir/lh.pial${outputSuffix2}  $surfdir/lh.pial${outputSuffix2} 
	$MrisMakeSurfacesDir/mris_make_surfaces -max $MaxThickness -nsigma_above $nsigma_above -nsigma_below $nsigma_below -aseg aseg.hires.pial -mgz -sdir $SubjectDIR -orig white -filled filled.hires -wm wm.hires -nowhite -orig_white white -orig_pial pial $T2wFlag $mridir/T2w_hires.norm -T1 "$T1wHiresNorm" -output $outputSuffix2 $SubjectID rh $opts
	mris_smooth -n $niter -nw $surfdir/rh.pial${outputSuffix2}  $surfdir/rh.pial${outputSuffix2} 

else
	verbose_red_echo "---> No T2w image, skipping generation of pial second pass surfaces with T2 adjustment."
	outputSuffix2=".preT2.pass2"
fi

if [ `cat ${FREESURFER_HOME}/build-stamp.txt | grep v6.0` ] ; then 
	mri_surf2surf --s $SubjectID --sval-xyz pial${outputSuffix2} --reg $regII $mridir/orig.mgz --tval-xyz "$mridir"/T1w_hires.nii.gz --tval pial --hemi lh
	mri_surf2surf --s $SubjectID --sval-xyz pial${outputSuffix2} --reg $regII $mridir/orig.mgz --tval-xyz "$mridir"/T1w_hires.nii.gz --tval pial --hemi rh
elif [ `cat ${FREESURFER_HOME}/build-stamp.txt | grep v5.3.0` ] ; then 
	mri_surf2surf --s $SubjectID --sval-xyz pial${outputSuffix2} --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi lh
	mri_surf2surf --s $SubjectID --sval-xyz pial${outputSuffix2} --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi rh
fi
# Copy other outputs from final call to 'mris_make_surfaces' to their default FS file names
# (At this point, this could be a 'mv' operation instead).
cp --preserve=timestamps $surfdir/lh.thickness${outputSuffix2} $surfdir/lh.thickness
cp --preserve=timestamps $surfdir/rh.thickness${outputSuffix2} $surfdir/rh.thickness

cp --preserve=timestamps $surfdir/lh.area.pial${outputSuffix2} $surfdir/lh.area.pial
cp --preserve=timestamps $surfdir/rh.area.pial${outputSuffix2} $surfdir/rh.area.pial

cp --preserve=timestamps $surfdir/lh.curv.pial${outputSuffix2} $surfdir/lh.curv.pial
cp --preserve=timestamps $surfdir/rh.curv.pial${outputSuffix2} $surfdir/rh.curv.pial

# Other cleanup
# Remove some intermediate "Xh.pial.*" files that were generated following the 1st pass,
# but which no longer correspond to the final pial surfaces (after the 2nd pass)
rm "$surfdir"/lh.pial.surf.gii "$surfdir"/lh.pial.nii.gz
rm "$surfdir"/rh.pial.surf.gii "$surfdir"/rh.pial.nii.gz
# Move all the "ribbon" related files generated following the 1st pass into a dedicated
# subdirectory since those also do not correspond to the final ribbon
cd "$mridir"
ribbon1Dir=ribbon${outputSuffix1}
mkdir $ribbon1Dir
mv lh.ribbon.nii.gz rh.ribbon.nii.gz ribbon.nii.gz ribbon_s"$GreySigma".nii.gz $ribbon1Dir/.
mv "$T1wHiresNorm"_ribbon.nii.gz ribbon_inv.nii.gz "$T1wHiresNorm"_ribbon_myelin.nii.gz $ribbon1Dir/.
mv dilribbon_inv.nii.gz T1w_hires.greynorm_ribbon.nii.gz $ribbon1Dir/.

echo -e "\n END: FreeSurferHiresPial"
