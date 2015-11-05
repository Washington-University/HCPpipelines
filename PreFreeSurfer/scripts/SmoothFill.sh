#!/usr/bin/env bash
set -e

# Requirements for this script
#  installed versions of: FSL (version 5.0.6)
#  environment: as in SetUpHCPPipeline.sh   (or individually: FSLDIR)
#  give Lennart Verhagen (lennart.verhagen@psy.ox.ac.uk) a coffee or a pint


################################################ SUPPORT FUNCTIONS ##################################################

Usage() {
  echo "`basename $0`: Smooth fill a given mask, or non-positive values"
  echo " "
  echo "Usage: `basename $0` --in=<input image> [--fillmask=<mask image to fill>] [--out=<output image>]"
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


################################################## OPTION PARSING #####################################################

# Just give usage if no arguments specified
if [[ $# -eq 0 ]] ; then Usage; exit 0; fi
# check for correct options
if [[ $# -lt 1 ]] ; then Usage; exit 1; fi

# parse arguments
Input=$(getopt1 "--in" $@)  # "$1"
FillMask=$(getopt1 "--fillmask" $@)  # "$2"
Output=$(getopt1 "--out" $@)  # "$3"

# default parameters
Output=$(defaultopt $Output $Input)

# piping a comparison string to bc (echo "1 > 0" | bc) while running on fsl_sub gives a strange error: "(standard_in) 2: Error: comparison in expression" So far this doesn't seem to be a critical error.
# it can probably be solved by unsetting POSIXLY_CORRECT (set by fsl)
#unset POSIXLY_CORRECT
# or: export POSIXLY_CORRECT=0

# instead I've opted to use awful awk instead of simple bc, here are some suggestions
# [[ $(echo | awk -v m=${MinMax[0]} '{if (m>0) printf (1); else printf (0);}') = 1 ]] && echo yeah || echo nope
# [[ $(echo | awk -v m=${MinMax[0]} '{if (m>0) printf ("TRUE");}') = "TRUE" ]] && echo yeah || echo nope
# [[ $(echo | awk -v m=${MinMax[0]} '{if (m>0) print (1);}') = 1 ]] && echo yeah || echo nope
# [[ ! $(awk -v m=${MinMax[0]} 'BEGIN{ print m>0 }') ]] && echo yeah || echo nope

########################################## DO WORK ##########################################

# get base names of the in- and output
BaseIn=$(${FSLDIR}/bin/remove_ext $Input)
BaseOut=$(${FSLDIR}/bin/remove_ext $Output)

# Create the mask of voxels to keep
if [[ -n $FillMask ]] ; then

  # invert the fill mask
  ${FSLDIR}/bin/fslmaths $FillMask -bin -mul -1 -add 1 ${BaseIn}_posmask

else

  # return quickly if all values are higher than zero
  MinMax=($(fslstats $Input -R))
  if [[ $(echo | awk -v m=${MinMax[0]} '{if (m>0) print (1);}') = 1 ]] ; then
    [[ $Input != $Output ]] && ${FSLDIR}/bin/imcp $Input $Output
    exit 0
  fi

  # create a mask of positive value voxels
  ${FSLDIR}/bin/fslmaths $Input -bin ${BaseIn}_posmask

fi

# smooth interpolate the zeros in the images (but redirect stdout)
${FSLDIR}/bin/fslsmoothfill -i $Input -m ${BaseIn}_posmask -o $Output > /dev/null

# ensure only zero or positive values in the image
[[ -z $FillMask ]] && ${FSLDIR}/bin/fslmaths $Output -thr 0 $Output

# clean up the mask and intermediate images
${FSLDIR}/bin/imrm ${BaseIn}_posmask ${BaseOut}_init ${BaseOut}_vol2 ${BaseOut}_vol32 ${BaseOut}_idxmask

##############################################################################################
