#!/bin/bash -e

#   Copyright (C) 2004-2011 University of Oxford
#
#   SHCOPYRIGHT

Usage() {
    echo ""
    echo "Usage: mcflirt.sh <4dinput> <4doutput> [<scout_image> [<mcref_image>]]"
    echo ""
    echo " If neither <scout_image> nor <mcref_image> is specified, a reference image"
    echo "    will be generated automatically from volumes 10-20 in the input series."
    echo ""
    echo " If only <scout_image> is specified, motion correction will use <scout_image> "
    echo "    for reference"
    echo ""
    echo " If both <scout_image> and <mcref_image> are specified, motion correction "
    echo "    will use <mcref_image> as its reference, but an additional mcref->scout"
    echo "    coregistration will be appended so that the final outputs are aligned"
    echo "    with <scout_image>"
    echo ""
    exit
}

[ "$2" = "" ] && Usage

input=`${FSLDIR}/bin/remove_ext ${1}`
output=`${FSLDIR}/bin/remove_ext ${2}`
TR=`fslval $input pixdim4`

if [ `${FSLDIR}/bin/imtest $input` -eq 0 ];then
    echo "Input does not exist or is not in a supported format"
    exit
fi

/bin/rm -rf $output ; mkdir $output
/bin/rm -rf $output.mat



if [ x$3 = x ]; then
  ref=${output}_ref
  ${FSLDIR}/bin/fslroi ${input} ${ref} 10 10
  ${FSLDIR}/bin/mcflirt -in $ref -refvol 0 -o ${output}_tmp >> ${output}.ecclog
  ${FSLDIR}/bin/immv ${output}_tmp $ref
  ${FSLDIR}/bin/fslmaths $ref -Tmean $ref
else
  ref=$3
fi

if [ x$4 = x ] ; then
  mcref=$ref
else
  mcref=$4
fi

mcref2scout=${output}_mcref2scout.mat

if [ "$mcref" = "$ref" ]; then
  echo "1 0 0 0" > ${mcref2scout}
  echo "0 1 0 0" >> ${mcref2scout}
  echo "0 0 1 0" >> ${mcref2scout}
  echo "0 0 0 1" >> ${mcref2scout}
else
  ${FSLDIR}/bin/flirt -in ${mcref} -ref ${ref} -nosearch -dof 6 -paddingsize 1 -omat ${mcref2scout} >> ${output}.ecclog
fi

# Do motion correction
${FSLDIR}/bin/mcflirt -in ${input} -r ${mcref} -mats -plots -o $output >> ${output}.ecclog

# Make masks
pi=$(echo "scale=10; 4*a(1)" | bc -l)
${FSLDIR}/bin/fslmaths ${ref} -mul 0 -add 1 ${output}_allones
for i in `ls ${output}.mat/*` ; do
    echo processing $i
    echo processing $i >> ${output}.ecclog
    ii=`basename $i`
    ${FSLDIR}/bin/convert_xfm -omat ${output}/${ii}.mat -concat ${mcref2scout} ${i} 
    maskname=${output}`basename ${i} | sed "s/MAT_/_mask/"`
    ${FSLDIR}/bin/flirt -in ${output}_allones -ref ${mcref} -o $maskname -paddingsize 1 -setbackground 0 -init ${output}/${ii}.mat -applyxfm -noresampblur 
    mm=`${FSLDIR}/bin/avscale --allparams ${output}/${ii}.mat $mcref | grep "Translations" | awk '{print $5 " " $6 " " $7}'`
    mmx=`echo $mm | cut -d " " -f 1`
    mmy=`echo $mm | cut -d " " -f 2`
    mmz=`echo $mm | cut -d " " -f 3`
    radians=`${FSLDIR}/bin/avscale --allparams ${output}/${ii}.mat $mcref | grep "Rotation Angles" | awk '{print $6 " " $7 " " $8}'`
    radx=`echo $radians | cut -d " " -f 1`
    degx=`echo "$radx * (180 / $pi)" | bc -l`
    rady=`echo $radians | cut -d " " -f 2`
    degy=`echo "$rady * (180 / $pi)" | bc -l`
    radz=`echo $radians | cut -d " " -f 3`
    degz=`echo "$radz * (180 / $pi)" | bc -l`
    # The "%.6f" formatting specifier allows the numeric value to be as wide as it needs to be to accomodate the number
    # Then we mandate (include) a single space as a delimiter between values.
    echo `printf "%.6f" $mmx` `printf "%.6f" $mmy` `printf "%.6f" $mmz` `printf "%.6f" $degx` `printf "%.6f" $degy` `printf "%.6f" $degz` >> ${output}/mc.par
done

${FSLDIR}/bin/fslmerge -t ${output}_mask `${FSLDIR}/bin/imglob ${output}_mask????.*`
${FSLDIR}/bin/fslmaths ${output}_mask -Tmean -mul `$FSLDIR/bin/fslval ${output}_mask dim4` ${output}_mask

${FSLDIR}/bin/imrm `${FSLDIR}/bin/imglob ${output}_mask????` ${output}_allones ${output}_ref
/bin/rm -rf ${output}.mat ${mcref2scout} 

