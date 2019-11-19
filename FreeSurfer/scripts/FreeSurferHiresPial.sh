#!/bin/bash

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

script_name=$(basename "${0}")

show_usage() {
	cat <<EOF

${script_name}

Usage: ${script_name} [options]

Usage information To Be Written

EOF
}

# Allow script to return a Usage statement, before any other output or checking
if [ "$#" = "0" ]; then
    show_usage
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
source ${HCPPIPEDIR}/global/scripts/opts.shlib                 # Command line option functions

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
	show_usage
	exit 0
fi

# ------------------------------------------------------------------------------
#  Verify required environment variables are set and log value
# ------------------------------------------------------------------------------

log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FREESURFER_HOME
log_Check_Env_Var CARET7DIR

# ------------------------------------------------------------------------------
#  Start work
# ------------------------------------------------------------------------------

echo -e "\n START: FreeSurferHighResPial"

SubjectID="$1"
SubjectDIR="$2"
T1wImage="$3" #T1w FreeSurfer Input (Full Resolution)
T2wImage="$4" #T2w FreeSurfer Input (Full Resolution)

#Sigma controls smoothness of within grey matter tissue contrast field being removed
Sigma="5" #in mm

export SUBJECTS_DIR="$SubjectDIR"

mridir=$SubjectDIR/$SubjectID/mri
surfdir=$SubjectDIR/$SubjectID/surf

reg=$mridir/transforms/hires21mm.dat
regII=$mridir/transforms/1mm2hires.dat
hires="$mridir"/T1w_hires.nii.gz
T2="$mridir"/T2w_hires.norm.mgz
Ratio="$mridir"/T1wDividedByT2w_sqrt.nii.gz

#Normalize T1w and T2w images for the benefit of mris_make_surfaces
mri_convert "$mridir"/wm.hires.mgz "$mridir"/wm.hires.nii.gz
fslmaths "$mridir"/wm.hires.nii.gz -thr 110 -uthr 110 "$mridir"/wm.hires.nii.gz
wmMeanT1=`fslstats "$mridir"/T1w_hires.nii.gz -k "$mridir"/wm.hires.nii.gz -M`
fslmaths "$mridir"/T1w_hires.nii.gz -div $wmMeanT1 -mul 110 "$mridir"/T1w_hires.norm.nii.gz
mri_convert "$mridir"/T1w_hires.norm.nii.gz "$mridir"/T1w_hires.norm.mgz

if [ ! "${T2wImage}" = "NONE" ] ; then
  wmMeanT2=`fslstats "$mridir"/T2w_hires.nii.gz -k "$mridir"/wm.hires.nii.gz -M`
  fslmaths "$mridir"/T2w_hires.nii.gz -div $wmMeanT2 -mul 57 "$mridir"/T2w_hires.norm.nii.gz -odt float
  mri_convert "$mridir"/T2w_hires.norm.nii.gz "$mridir"/T2w_hires.norm.mgz
fi

## Overview of what follows:
## 1) First pass attempts to capture all grey matter (and plenty of vessels/dura) with permissive variable sigma.
## 2) Remove vessels and dura using T2w image.
## 3) Normalize T1w image to reduce the effects of low spatial-frequency myelin content changes.
## 4) Generate second pass pial surface using more precise gaussian tissue distributions
##    (grey matter peak is narrower because of less variability in myelin content).
## 5) Remove veins and dura from pial surface using T2w image again.

## ------ First pass ------

# Different variable sigmas for different FS versions of mris_make_surfaces
# Check if FreeSurfer is version 5.2.0 or not.
if [ -z `cat ${FREESURFER_HOME}/build-stamp.txt | grep v5.2.0` ] ; then  #Not using v5.2.0
  VARIABLESIGMA="8"
else  #Using v5.2.0
  VARIABLESIGMA="4"
fi

# Generate pial surfaces, first pass, no T2 adjustment.  Files created are Xh.pial, Xh.curv.pial, Xh.area.pial, Xh.thickness
mris_make_surfaces -variablesigma ${VARIABLESIGMA} -white NOWRITE -aseg aseg.hires -orig white.deformed -filled filled.hires -wm wm.hires -sdir $SubjectDIR -mgz -T1 T1w_hires.norm "$SubjectID" lh
mris_make_surfaces -variablesigma ${VARIABLESIGMA} -white NOWRITE -aseg aseg.hires -orig white.deformed -filled filled.hires -wm wm.hires -sdir $SubjectDIR -mgz -T1 T1w_hires.norm "$SubjectID" rh

# Preserve a copy of these pial surfaces for debugging purposes
# (Use "cp --preserve=timestamps" to preserve time stamps when copying, so time stamps maintain temporal order of file creation).
cp --preserve=timestamps $SubjectDIR/$SubjectID/surf/lh.pial $SubjectDIR/$SubjectID/surf/lh.pial.preT2.pass1
cp --preserve=timestamps $SubjectDIR/$SubjectID/surf/rh.pial $SubjectDIR/$SubjectID/surf/rh.pial.preT2.pass1
cp --preserve=timestamps $SubjectDIR/$SubjectID/surf/lh.thickness $SubjectDIR/$SubjectID/surf/lh.thickness.preT2.pass1
cp --preserve=timestamps $SubjectDIR/$SubjectID/surf/rh.thickness $SubjectDIR/$SubjectID/surf/rh.thickness.preT2.pass1

if [ ! "${T2wImage}" = "NONE" ] ; then
  verbose_red_echo "---> Generating pial first pass surfaces with T2 adjustment."
  # Generate pial surfaces with T2 adjustment, still first pass.
  # Same 4 files created as above, but have $outputSuffix1 ("postT2.pass1") appended through use of -output flag.
  # Use -T2 flag (rather than -T2dura), since -T2 is the flag used within recon-all script of FS 5.3 (but -T2 and -T2dura generate same results)
  # For mris_make_surface with correct arguments #Could go from 3 to 2 potentially...
  outputSuffix1=".postT2.pass1"
  mris_make_surfaces -nsigma_above 2 -nsigma_below 3 -aseg aseg.hires -filled filled.hires -wm wm.hires -mgz -sdir $SubjectDIR -orig white.deformed -nowhite -orig_white white.deformed -orig_pial pial -T2 "$mridir"/T2w_hires.norm -T1 T1w_hires.norm -output $outputSuffix1 $SubjectID lh
  mris_make_surfaces -nsigma_above 2 -nsigma_below 3 -aseg aseg.hires -filled filled.hires -wm wm.hires -mgz -sdir $SubjectDIR -orig white.deformed -nowhite -orig_white white.deformed -orig_pial pial -T2 "$mridir"/T2w_hires.norm -T1 T1w_hires.norm -output $outputSuffix1 $SubjectID rh
else
  verbose_red_echo "---> No T2w image, skipping generation of pial first pass surfaces with T2 adjustment."
  outputSuffix1=".preT2.pass1"
fi


# Bring pial surfaces out of highres space into the 1 mm (FS conformed) space
# [Note that $regII, although named 1mm2hires.dat, actually maps from the hires space into the FS conformed space].
mri_surf2surf --s $SubjectID --sval-xyz pial${outputSuffix1} --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi lh
mri_surf2surf --s $SubjectID --sval-xyz pial${outputSuffix1} --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi rh

cp --preserve=timestamps $SubjectDIR/$SubjectID/surf/lh.pial $SubjectDIR/$SubjectID/surf/lh.pial${outputSuffix1}.conformed
cp --preserve=timestamps $SubjectDIR/$SubjectID/surf/rh.pial $SubjectDIR/$SubjectID/surf/rh.pial${outputSuffix1}.conformed


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
fslmaths "$surfdir"/lh.white.nii.gz -mul "$surfdir"/lh.pial.nii.gz -uthr 0 -mul -1 -bin "$mridir"/lh.ribbon.nii.gz
fslmaths "$surfdir"/rh.white.nii.gz -mul "$surfdir"/rh.pial.nii.gz -uthr 0 -mul -1 -bin "$mridir"/rh.ribbon.nii.gz
fslmaths "$mridir"/lh.ribbon.nii.gz -add "$mridir"/rh.ribbon.nii.gz -bin "$mridir"/ribbon.nii.gz
fslcpgeom "$mridir"/T1w_hires.norm.nii.gz "$mridir"/ribbon.nii.gz

fslmaths "$mridir"/ribbon.nii.gz -s $Sigma "$mridir"/ribbon_s"$Sigma".nii.gz
fslmaths "$mridir"/T1w_hires.norm.nii.gz -mas "$mridir"/ribbon.nii.gz "$mridir"/T1w_hires.norm_ribbon.nii.gz
greymean=`fslstats "$mridir"/T1w_hires.norm_ribbon.nii.gz -M`
fslmaths "$mridir"/ribbon.nii.gz -sub 1 -mul -1 "$mridir"/ribbon_inv.nii.gz
fslmaths "$mridir"/T1w_hires.norm_ribbon.nii.gz -s $Sigma -div "$mridir"/ribbon_s"$Sigma".nii.gz -div $greymean -mas "$mridir"/ribbon.nii.gz -add "$mridir"/ribbon_inv.nii.gz "$mridir"/T1w_hires.norm_ribbon_myelin.nii.gz

fslmaths "$surfdir"/lh.white.nii.gz -uthr 0 -mul -1 -bin "$mridir"/lh.white.nii.gz
fslmaths "$surfdir"/rh.white.nii.gz -uthr 0 -mul -1 -bin "$mridir"/rh.white.nii.gz
fslmaths "$mridir"/lh.white.nii.gz -add "$mridir"/rh.white.nii.gz -bin "$mridir"/white.nii.gz
rm "$mridir"/lh.white.nii.gz "$mridir"/rh.white.nii.gz
fslmaths "$mridir"/T1w_hires.norm_ribbon_myelin.nii.gz -mas "$mridir"/ribbon.nii.gz -add "$mridir"/white.nii.gz -uthr 1.9 "$mridir"/T1w_hires.norm_grey_myelin.nii.gz
fslmaths "$mridir"/T1w_hires.norm_grey_myelin.nii.gz -dilM -dilM -dilM -dilM -dilM "$mridir"/T1w_hires.norm_grey_myelin.nii.gz
fslmaths "$mridir"/T1w_hires.norm_grey_myelin.nii.gz -binv "$mridir"/dilribbon_inv.nii.gz
fslmaths "$mridir"/T1w_hires.norm_grey_myelin.nii.gz -add "$mridir"/dilribbon_inv.nii.gz "$mridir"/T1w_hires.norm_grey_myelin.nii.gz

fslmaths "$mridir"/T1w_hires.norm.nii.gz -div "$mridir"/T1w_hires.norm_ribbon_myelin.nii.gz "$mridir"/T1w_hires.greynorm_ribbon.nii.gz
fslmaths "$mridir"/T1w_hires.norm.nii.gz -div "$mridir"/T1w_hires.norm_grey_myelin.nii.gz "$mridir"/T1w_hires.greynorm.nii.gz

mri_convert "$mridir"/T1w_hires.greynorm.nii.gz "$mridir"/T1w_hires.greynorm.mgz


## ------ Second pass ------

#Check if FreeSurfer is version 5.2.0 or not.
if [ -z `cat ${FREESURFER_HOME}/build-stamp.txt | grep v5.2.0` ] ; then  #Not using v5.2.0
  VARIABLESIGMA="4"
else  #Using v5.2.0
  VARIABLESIGMA="2"
fi

# Generate pial surfaces, second pass, no T2 adjustment.  Files created are Xh.pial, Xh.curv.pial, Xh.area.pial, Xh.thickness
mris_make_surfaces -variablesigma ${VARIABLESIGMA} -white NOWRITE -aseg aseg.hires -orig white.deformed -filled filled.hires -wm wm.hires -sdir $SubjectDIR -mgz -T1 T1w_hires.greynorm "$SubjectID" lh
mris_make_surfaces -variablesigma ${VARIABLESIGMA} -white NOWRITE -aseg aseg.hires -orig white.deformed -filled filled.hires -wm wm.hires -sdir $SubjectDIR -mgz -T1 T1w_hires.greynorm "$SubjectID" rh

# Preserve a copy of these pial surfaces for debugging purposes
cp --preserve=timestamps $SubjectDIR/$SubjectID/surf/lh.pial $SubjectDIR/$SubjectID/surf/lh.pial.preT2.pass2
cp --preserve=timestamps $SubjectDIR/$SubjectID/surf/rh.pial $SubjectDIR/$SubjectID/surf/rh.pial.preT2.pass2
cp --preserve=timestamps $SubjectDIR/$SubjectID/surf/lh.thickness $SubjectDIR/$SubjectID/surf/lh.thickness.preT2.pass2
cp --preserve=timestamps $SubjectDIR/$SubjectID/surf/rh.thickness $SubjectDIR/$SubjectID/surf/rh.thickness.preT2.pass2


if [ ! "${T2wImage}" = "NONE" ] ; then
  verbose_red_echo "---> Generating pial second pass surfaces with T2 adjustment."
  # Generate pial surfaces with T2 adjustment, second pass.
  # Same 4 files created as above, but have $outputSuffix2 ("postT2.pass2") appended through use of -output flag
  #Could go from 3 to 2 potentially...
  outputSuffix2=".postT2.pass2"
  mris_make_surfaces -nsigma_above 2 -nsigma_below 3 -aseg aseg.hires -filled filled.hires -wm wm.hires -mgz -sdir $SubjectDIR -orig white.deformed -nowhite -orig_white white.deformed -orig_pial pial -T2 "$mridir"/T2w_hires.norm -T1 T1w_hires.norm -output $outputSuffix2 $SubjectID lh
  mris_make_surfaces -nsigma_above 2 -nsigma_below 3 -aseg aseg.hires -filled filled.hires -wm wm.hires -mgz -sdir $SubjectDIR -orig white.deformed -nowhite -orig_white white.deformed -orig_pial pial -T2 "$mridir"/T2w_hires.norm -T1 T1w_hires.norm -output $outputSuffix2 $SubjectID rh
else
  verbose_red_echo "---> No T2w image, skipping generation of pial second pass surfaces with T2 adjustment."
  outputSuffix2="preT2.pass2"
fi

# Create final Xh.pial surfaces in FS conformed space
mri_surf2surf --s $SubjectID --sval-xyz pial${outputSuffix2} --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi lh
mri_surf2surf --s $SubjectID --sval-xyz pial${outputSuffix2} --reg $regII $mridir/orig.mgz --tval-xyz --tval pial --hemi rh

# Copy other outputs from final call to 'mris_make_surfaces' to their default FS file names
# (At this point, this could be a 'mv' operation instead).
cp --preserve=timestamps $SubjectDIR/$SubjectID/surf/lh.thickness${outputSuffix2} $SubjectDIR/$SubjectID/surf/lh.thickness
cp --preserve=timestamps $SubjectDIR/$SubjectID/surf/rh.thickness${outputSuffix2} $SubjectDIR/$SubjectID/surf/rh.thickness

cp --preserve=timestamps $SubjectDIR/$SubjectID/surf/lh.area.pial${outputSuffix2} $SubjectDIR/$SubjectID/surf/lh.area.pial
cp --preserve=timestamps $SubjectDIR/$SubjectID/surf/rh.area.pial${outputSuffix2} $SubjectDIR/$SubjectID/surf/rh.area.pial

cp --preserve=timestamps $SubjectDIR/$SubjectID/surf/lh.curv.pial${outputSuffix2} $SubjectDIR/$SubjectID/surf/lh.curv.pial
cp --preserve=timestamps $SubjectDIR/$SubjectID/surf/rh.curv.pial${outputSuffix2} $SubjectDIR/$SubjectID/surf/rh.curv.pial

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
mv lh.ribbon.nii.gz rh.ribbon.nii.gz ribbon.nii.gz ribbon_s"$Sigma".nii.gz $ribbon1Dir/.
mv T1w_hires.norm_ribbon.nii.gz ribbon_inv.nii.gz T1w_hires.norm_ribbon_myelin.nii.gz $ribbon1Dir/.
mv dilribbon_inv.nii.gz T1w_hires.greynorm_ribbon.nii.gz $ribbon1Dir/.

echo -e "\n END: FreeSurferHighResPial"
