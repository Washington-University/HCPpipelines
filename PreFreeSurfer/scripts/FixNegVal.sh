#!/usr/bin/env bash
set -e    # stop immediately on error

# Requirements for this script
#  installed versions of: FSL (version 5.0.6)
#  environment: as in SetUpHCPPipeline.sh   (or individually: FSLDIR)
#  give Lennart Verhagen (lennart.verhagen@psy.ox.ac.uk) a coffee or a pint


#==============================
# overhead
#==============================

Usage() {
cat <<EOF

`basename $0`: Ensure the image does not contain negative values.
    1) by thresholding
    2) by taking absolute values
    3) by smooth filling non-positive values (or a mask)
    4) other: do nothing and return quickly)

Usage:
  `basename $0`
      --in=<input image>
     [--method=<fix method>] : none, thr (default), abs, smooth
     [--fillmask=<mask image to smooth fill>]
     [--out=<output image>]

EOF
}

# if no arguments given, return the usage
if [[ $# -eq 0 ]] ; then usage; exit 0; fi

# if too few arguments given, return the usage, exit with error
if [[ $# -lt 1 ]] ; then >&2 usage; exit 1; fi

# default parameters
args=""
Method=thr

# parse the input arguments
for a in "$@" ; do
  case $a in
    --in=*)       Input="${a#*=}"; shift ;;
    --method=*)   Method="${a#*=}"; shift ;;
    --fillmask=*) FillMask="${a#*=}"; shift ;;
    --output=*)   Output="${a#*=}"; shift ;;
    *)            args="$args $a"; shift ;; # unsupported argument
  esac
done

# check if no redundant arguments have been set
if [[ -n $args ]] ; then
  >&2 echo ""; >&2 echo "unsupported arguments are given:" $args
  exit 1
fi

# default output to input
[[ -z $Output ]] && Output="$Input"

# force lower case
Method=$(echo "$Method" | tr '[:upper:]' '[:lower:]')

# random remark:
# Piping a comparison string to bc (echo "1 > 0" | bc) while running on fsl_sub
# gives a strange error: "(standard_in) 2: Error: comparison in expression".
# So far this doesn't seem to be a critical error.
# It can probably be solved by unsetting POSIXLY_CORRECT (set by fsl)
#   unset POSIXLY_CORRECT
#   or: export POSIXLY_CORRECT=0

# To circumvent this I've chosen to use awk instead of bc, here are two examples
# [[ $(echo ${MinMax[0]} | awk '($1>0){print 1}') ]] && echo yeah || echo nope
# [[ ! $(awk -v m=${MinMax[0]} 'BEGIN{ print m>0 }') ]] && echo yeah || echo nope


#==============================
# main code
#==============================

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
