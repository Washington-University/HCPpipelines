#!/usr/bin/env bash
set -e    # stop immediately on error

# Requirements for this script
#  installed versions of: FSL (version 5.0.6)
#  environment: as in SetUpHCPPipeline.sh   (or individually: FSLDIR)
#  give Lennart Verhagen (lennart.verhagen@psy.ox.ac.uk) a coffee or a pint


################################################ SUPPORT FUNCTIONS ##################################################

Usage() {
  echo "`basename $0`: Ensure the image does not contain negative values."
  echo "    1) by thresholding"
  echo "    2) by taking absolute values"
  echo "    3) by smooth filling non-positive values (or a mask)"
  echo "    4) other: do nothing and return quickly)"
  echo " "
  echo "Usage:"
  echo "  `basename $0`"
  echo "      --in=<input image>"
  echo "     [--method=<fix method>] : \"thr\" (default) \"abs\" \"smooth\" \"none\""
  echo "     [--fillmask=<mask image to smooth fill>]"
  echo "     [--out=<output image>]"
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
# check for correct number of input arguments
if [[ $# -lt 1 ]] ; then >&2 Usage; exit 1; fi

# parse arguments
Input=$(getopt1 "--in" $@)
Method=$(getopt1 "--method" $@)
FillMask=$(getopt1 "--fillmask" $@)
Output=$(getopt1 "--out" $@)

# default parameters
Method=$(defaultopt $Method "thr")
Output=$(defaultopt $Output $Input)

# force lower case
Method=$(echo "$Method" | tr '[:upper:]' '[:lower:]')

# Piping a comparison string to bc (echo "1 > 0" | bc) while running on fsl_sub
# gives a strange error: "(standard_in) 2: Error: comparison in expression".
# So far this doesn't seem to be a critical error.
# It can probably be solved by unsetting POSIXLY_CORRECT (set by fsl)
#   unset POSIXLY_CORRECT
#   or: export POSIXLY_CORRECT=0

# To circumvent this I've chosen to use awk instead of bc, here are two examples
# [[ $(echo ${MinMax[0]} | awk '($1>0){print 1}') ]] && echo yeah || echo nope
# [[ ! $(awk -v m=${MinMax[0]} 'BEGIN{ print m>0 }') ]] && echo yeah || echo nope

########################################## DO WORK ##########################################

# get base names of the in- and output
BaseIn=$(${FSLDIR}/bin/remove_ext $Input)
BaseOut=$(${FSLDIR}/bin/remove_ext $Output)

case $Method in
  thr )
    ${FSLDIR}/bin/fslmaths $Input -thr 0 $Output
    ;;

  abs )
    ${FSLDIR}/bin/fslmaths $Input -abs $Output
    ;;

  smooth )
    # return quickly if no fill-mask is provided and all values are higher than zero
    if [[ -z $FillMask ]] && [[ $(fslstats $Input -R | awk '($1>0){print 1}') ]] ; then
      [[ $Input != $Output ]] && ${FSLDIR}/bin/imcp $Input $Output
      exit 0
    fi

    # create a tmpdir
    tmpdir=$(mktemp -d "/tmp/FixNegVal.XXXXXXXXXX")
    betbase=$tmpdir/$(basename $base)

    # Use the provided mask if available, or create one
    if [[ -n $FillMask ]] ; then
      # invert the fill mask
      ${FSLDIR}/bin/fslmaths $FillMask -binv $tmpdir/posmask
    else
      # create a mask of positive value voxels
      ${FSLDIR}/bin/fslmaths $Input -bin $tmpdir/posmask
    fi

    # smooth interpolate the zeros in the images (but redirect stdout)
    ${FSLDIR}/bin/fslsmoothfill -i $Input -m $tmpdir/posmask -o $tmpdir/img > /dev/null
    # move the result to the desired output
    ${FSLDIR}/bin/immv $tmpdir/img $Output
    # remove the tmpdir
    rm -rf $tmpdir

    # ensure only zero or positive values in the image
    [[ -z $FillMask ]] && ${FSLDIR}/bin/fslmaths $Output -thr 0 $Output
    ;;

  * )
    # return without doing anything (no supported method was requested)
    exit 0
    ;;
esac




##############################################################################################
