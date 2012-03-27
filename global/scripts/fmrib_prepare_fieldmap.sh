#! /bin/bash
#
# fmrib_prepare_fieldmap - script to process fieldmap images into form suitable for FEAT (rad/s)
#
# Mark Jenkinson, Johannes Klein and Karla Miller, FMRIB Centre
#
# Copyright (C) 2004-2008 University of Oxford 
#
#   Part of FSL - FMRIB's Software Library
#   http://www.fmrib.ox.ac.uk/fsl
#   fsl@fmrib.ox.ac.uk
#   
#   Developed at FMRIB (Oxford Centre for Functional Magnetic Resonance
#   Imaging of the Brain), Department of Clinical Neurology, Oxford
#   University, Oxford, UK
#   
#   
#   LICENCE
#   
#   FMRIB Software Library, Release 4.0 (c) 2007, The University of
#   Oxford (the "Software")
#   
#   The Software remains the property of the University of Oxford ("the
#   University").
#   
#   The Software is distributed "AS IS" under this Licence solely for
#   non-commercial use in the hope that it will be useful, but in order
#   that the University as a charitable foundation protects its assets for
#   the benefit of its educational and research purposes, the University
#   makes clear that no condition is made or to be implied, nor is any
#   warranty given or to be implied, as to the accuracy of the Software,
#   or that it will be suitable for any particular purpose or for use
#   under any specific conditions. Furthermore, the University disclaims
#   all responsibility for the use which is made of the Software. It
#   further disclaims any liability for the outcomes arising from using
#   the Software.
#   
#   The Licensee agrees to indemnify the University and hold the
#   University harmless from and against any and all claims, damages and
#   liabilities asserted by third parties (including claims for
#   negligence) which arise directly or indirectly from the use of the
#   Software or the sale of any products based on the Software.
#   
#   No part of the Software may be reproduced, modified, transmitted or
#   transferred in any form or by any means, electronic or mechanical,
#   without the express permission of the University. The permission of
#   the University is not required if the said reproduction, modification,
#   transmission or transference is done without financial return, the
#   conditions of this Licence are imposed upon the receiver of the
#   product, and all original and amended source code is included in any
#   transmitted product. You may be held legally responsible for any
#   copyright infringement that is caused or encouraged by your failure to
#   abide by these terms and conditions.
#   
#   You are not permitted under this Licence to use this Software
#   commercially. Use for which any financial return is received shall be
#   defined as commercial use, and includes (1) integration of all or part
#   of the source code or the Software into a product for sale or license
#   by or on behalf of Licensee to third parties or (2) use of the
#   Software or any derivative of it for research with the final aim of
#   developing software products for sale or license to a third party or
#   (3) use of the Software or any derivative of it for research with the
#   final aim of developing non-software products for sale or license to a
#   third party, or (4) use of the Software to provide any service to an
#   external organisation for which payment is received. If you are
#   interested in using the Software commercially, please contact Isis
#   Innovation Limited ("Isis"), the technology transfer company of the
#   University, to negotiate a licence. Contact details are:
#   innovation@isis.ox.ac.uk quoting reference DE/1112.
#
# V1 2005_07_28 Johannes Klein/Mark Jenkinson, FMRIB Centre
# V2 2007_07_05 KLM: added input for TE time (seems to be 2.46 now??)
# V2 2007_07_06 KLM: added detection of magnitude image dimensions
# V4 2007_09_15 KLM: changed to work with new fsltools
# V5 2008_03_19 MJ: major modifications to do sanity checking and work with both  VARIAN and OCMR data - first supported version in FMRIB
#

usage() {
 echo "Usage: `basename $0` <scanner> <phase_image> <magnitude_image> <out_image> <deltaTE (in ms)> [--nocheck]"
 echo " "
 echo "  Prepares a fieldmap suitable for FEAT from SIEMENS or VARIAN data - saves output in rad/s format"
 echo "  <scanner> can be SIEMENS or VARIAN"
 echo "  <magnitude image> should be Brain Extracted (with BET or otherwise)"
 echo "  <deltaTE> is the echo time difference of the fieldmap sequence - find this out form the operator (defaults are *usually* 2.46ms on SIEMENS and 2.5ms on VARIAN)"
 echo "  --nocheck supresses automatic sanity checking of image size/range/dimensions"
 echo " "
 echo "   e.g. `basename $0` SIEMENS images_3_gre_field_mapping images_4_gre_field_mapping fmap_rads 2.65"
}


bet_check() {
  # check that absolute image has been brain extracted
  imroot=$1
  nvox=`$FSLDIR/bin/fslstats ${imroot} -v | awk '{ print $1 }'`;
  nvoxnz=`$FSLDIR/bin/fslstats ${imroot} -V | awk '{ print $1 }'`;
  if [ `echo $nvoxnz / $nvox \> 0.90 | bc -l` -eq 1 ] ; then
      echo "Magntiude (abs) image should be brain extracted"
      echo "Please run BET on image ${imroot} before using it here"
      exit 2
  fi
}


clean_up_edge() {
    # does some despiking filtering to clean up the edge of the fieldmap
    # args are: <fmap> <mask> <tmpnam>
    outfile=$1
    maskim=$2
    tmpnm=$3
    $FSLDIR/bin/fugue --loadfmap=${outfile} --savefmap=${tmpnm}_tmp_fmapfilt -m ${maskim} --despike --despikethreshold=2.1
    $FSLDIR/bin/fslmaths ${maskim} -kernel 2D -ero ${tmpnm}_tmp_eromask 
    $FSLDIR/bin/fslmaths ${maskim} -sub ${tmpnm}_tmp_eromask -thr 0.5 -bin ${tmpnm}_tmp_edgemask 
    $FSLDIR/bin/fslmaths ${tmpnm}_tmp_fmapfilt -mas ${tmpnm}_tmp_edgemask ${tmpnm}_tmp_fmapfiltedge
    $FSLDIR/bin/fslmaths ${outfile} -mas ${tmpnm}_tmp_eromask -add ${tmpnm}_tmp_fmapfiltedge ${outfile}
}


demean_image() {
  # demeans image
  # args are: <image> <mask> <tmpnm>
  outim=$1
  maskim=$2
  tmpnm=$3
  $FSLDIR/bin/fslmaths ${outim} -mas ${maskim} ${tmpnm}_tmp_fmapmasked
  $FSLDIR/bin/fslmaths ${outim} -sub `$FSLDIR/bin/fslstats ${tmpnm}_tmp_fmapmasked -k ${maskim} -P 50` -mas ${maskim} ${outim} -odt float
}

###############################################################################

varian_process() {
  phaseroot=$1
  absroot=$2
  outfile=`$FSLDIR/bin/remove_ext $3`
  deltaTE=$4
  sanitycheck=$5
  tmpnm=$6

  nt=`$FSLDIR/bin/fslval ${phaseroot} dim4`;
  if [ $nt -ne 2 ] ; then
      echo "Phase image must contain two separate volumes!"
      echo "Use the 4D image containing two volumes of wrapped phase"
      exit 2
  fi

  # check range of phase data (should be close to 2*pi = 6.28)
  if [ $sanitycheck = yes ] ; then
      rr=`$FSLDIR/bin/fslstats ${phaseroot} -R`;
      rmin=`echo $rr | awk '{ print $1 }'`;
      rmax=`echo $rr | awk '{ print $2 }'`;
      range=`echo $rmax - $rmin | bc -l`;
      nrange=`echo $range / 6.28 | bc -l`;
      range_ok=yes;
      if [ `echo "$nrange < 0.9" | bc -l` -eq 1 ] ; then
	  range_ok=no;
      fi
      if [ `echo "$nrange > 1.1" | bc -l` -eq 1 ] ; then
	  range_ok=no;
      fi
      if [ $range_ok = no ] ; then
	  echo "Phase image values do not have expected range"
	  echo "Expecting range of 2*pi (6.28) but found $rmin to $rmax (range of $range)"
	  echo "Please re-scale or find correct image"
	  exit 2
      fi
      
      bet_check ${absroot}
  fi
  
  # make brain mask
  maskim=${tmpnm}_tmp_mask
  $FSLDIR/bin/fslmaths $absroot -thr 0.00000001 -bin $maskim

  # unwrap phase
  uphaseroot=${tmpnm}_tmp_uph
  $FSLDIR/bin/prelude -a $absroot -p $phaseroot -m $maskim -o $uphaseroot -v

  # create fieldmap
  asym=`echo $deltaTE / 1000 | bc -l`
  $FSLDIR/bin/fugue -p $uphaseroot --asym=$asym --mask=$maskim --savefmap=$outfile

  # Demean to avoid gross shifting
  demean_image ${outfile} ${maskim} ${tmpnm}

  # Clean up edge voxels
  clean_up_edge ${outfile} ${maskim} ${tmpnm}
}

###############################################################################

siemens_process() {
  phaseroot=$1
  absroot=$2
  outfile=`$FSLDIR/bin/remove_ext $3`
  deltaTE=$4
  sanitycheck=$5
  tmpnm=$6

  newphaseroot=${phaseroot}

  # check range of phase data (should be close to 4096)
  if [ $sanitycheck = yes ] ; then
      rr=`$FSLDIR/bin/fslstats ${phaseroot} -R;`
      rmin=`echo $rr | awk '{ print $1 }'`;
      rmax=`echo $rr | awk '{ print $2 }'`;
      range=`echo $rmax - $rmin | bc -l`;
      nrange=`echo $range / 4096 | bc -l`;
      if [ `echo "$nrange < 2.1" | bc -l` -eq 1 ] ; then
	  if [ `echo "$nrange > 1.9" | bc -l` -eq 1 ] ; then
	      # MRIcron range is typically twice that of dicom2nifti
	      newphaseroot=${tmpnm}_tmp_phase
	      $FSLDIR/bin/fslmaths ${phaseroot} -div 2 ${newphaseroot}
	  fi
      fi
      if [ `echo "$nrange < 0.9" | bc -l` -eq 1 ] ; then
	  echo "Phase image values do not have expected range"
	  echo "Expecting at least 90% of 0 to 4096, but found $rmin to $rmax"
	  echo "Please re-scale or find correct image, or force executation of this script with --nocheck"
	  exit 2
      fi
  
      # check that absolute image has been brain extracted
      bet_check ${absroot}
  fi
  
  # make brain mask
  maskim=${tmpnm}_tmp_mask
  $FSLDIR/bin/fslmaths $absroot -thr 0.00000001 -bin $maskim
  
  # Convert phasemap to radians
  $FSLDIR/bin/fslmaths ${newphaseroot} -div 2048 -sub 1 -mul 3.14159 -mas ${maskim} ${tmpnm}_tmp_ph_radians -odt float
  
  # Unwrap phasemap
  $FSLDIR/bin/prelude -p ${tmpnm}_tmp_ph_radians -a ${absroot} -m ${maskim} -o ${tmpnm}_tmp_ph_radians_unwrapped -v
  
  # Convert to rads/sec (dTE is echo time difference)
  asym=`echo $dTE / 1000 | bc -l`
  $FSLDIR/bin/fslmaths ${tmpnm}_tmp_ph_radians_unwrapped -div $asym ${tmpnm}_tmp_ph_rps -odt float
  
  # Call FUGUE to extrapolate from mask (fill holes, etc)
  $FSLDIR/bin/fugue --loadfmap=${tmpnm}_tmp_ph_rps --mask=${maskim} --savefmap=$outfile
  
  # Demean to avoid gross shifting
  demean_image ${outfile} ${maskim} ${tmpnm}
  
  # Clean up edge voxels
  clean_up_edge ${outfile} ${maskim} ${tmpnm}
}


###############################################################################

##########
## MAIN ##
##########

if [ $# -lt 5 ] ; then
  usage
  exit 1
fi

if [ `$FSLDIR/bin/imtest $2` -ne 1 ]; then
 echo "$2 not found/not an image file"
 exit 1
fi

if [ `$FSLDIR/bin/imtest $3` -ne 1 ]; then
 echo "$3 not found/not an image file"
 exit 1
fi

phaseroot=`$FSLDIR/bin/remove_ext $2`
absroot=`$FSLDIR/bin/remove_ext $3`
outfile=${phaseroot}_field_rps
if [ $# -ge 4 ]; then
  outfile=`$FSLDIR/bin/remove_ext $4`
fi

dTE=2.46
if [ $# -ge 5 ]; then
  dTE=$5
fi

sanitycheck=yes
if [ $# -ge 6 ] ; then
  if [ X$6 = X--nocheck ] ; then
      sanitycheck=no
  fi
fi  

if [ $sanitycheck = yes ] ; then
    badval=false;
    if [ `echo "$dTE < 0.1" | bc -l` -eq 1 ] ; then badval=true; fi
    if [ `echo "$dTE > 10.0" | bc -l` -eq 1 ] ; then badval=true; fi
    if [ $badval = true ] ; then
	echo "Unlikely difference in TE found: dTE = $dTE milliseconds"
	echo "Expecting values between 0.1 and 10.0 milliseconds"
	echo "To force the script to use this value use the --nocheck argument"
	exit 2
    fi
fi

tmpnm=`$FSLDIR/bin/tmpnam`

if [ $1 != SIEMENS -a $1 != OCMR -a $1 != VARIAN ] ; then
    usage
    echo " "
    echo "First argument must be SIEMENS or VARIAN"
    exit 1
fi


# check that phase and magnitude images are the same size
nz=`$FSLDIR/bin/fslval ${absroot} dim3`;
ny=`$FSLDIR/bin/fslval ${absroot} dim2`;
nx=`$FSLDIR/bin/fslval ${absroot} dim1`;
dz=`$FSLDIR/bin/fslval ${absroot} pixdim3`;
dy=`$FSLDIR/bin/fslval ${absroot} pixdim2`;
dx=`$FSLDIR/bin/fslval ${absroot} pixdim1`;
pnz=`$FSLDIR/bin/fslval ${phaseroot} dim3`;
pny=`$FSLDIR/bin/fslval ${phaseroot} dim2`;
pnx=`$FSLDIR/bin/fslval ${phaseroot} dim1`;
pdz=`$FSLDIR/bin/fslval ${phaseroot} pixdim3`;
pdy=`$FSLDIR/bin/fslval ${phaseroot} pixdim2`;
pdx=`$FSLDIR/bin/fslval ${phaseroot} pixdim1`;
samesize=true;
if [ $nz -ne $pnz ] ; then samesize=false; fi
if [ $ny -ne $pny ] ; then samesize=false; fi
if [ $nx -ne $pnx ] ; then samesize=false; fi
if [ `echo $dz != $pdz | bc -l` -eq 1 ] ; then samesize=false; fi
if [ `echo $dy != $pdy | bc -l` -eq 1 ] ; then samesize=false; fi
if [ `echo $dx != $pdx | bc -l` -eq 1 ] ; then samesize=false; fi
if [ $samesize = false ] ; then
    echo "Phase and Magnitude images must have the same number of voxels and voxel dimensions";
    echo "Current dimensions are:"
    echo "  Phase image:     $pnx x $pny x $pnz with dims of $pdx x $pdy x $pdz mm";
    echo "  Magnitude image: $nx x $ny x $nz with dims of $dx x $dy x $dz mm";
    echo "Fix this (probably in reconstruction stage) before re-running this script"
    if [ $1 = OCMR ] ; then 
	echo "Possibly try the script: fix_OCMR_fieldmaps"; 
    fi
    exit 2
fi


if [ $1 = VARIAN ] ; then
  varian_process $phaseroot $absroot $outfile $dTE $sanitycheck $tmpnm
else
  siemens_process $phaseroot $absroot $outfile $dTE $sanitycheck $tmpnm
fi

rm -rf ${tmpnm}_tmp_*
echo "Done. Created ${outfile} for use with FEAT."
exit 0
