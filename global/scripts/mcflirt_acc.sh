#!/bin/bash -e

#   Copyright (C) 2004-2011 University of Oxford
#
#   SHCOPYRIGHT

Usage() {
    echo ""
    echo "Usage: mcflirt_acc <4dinput> <4doutput> [ref_image]"
    echo ""
    exit
}

[ "$2" = "" ] && Usage

input=`${FSLDIR}/bin/remove_ext ${1}`
output=`${FSLDIR}/bin/remove_ext ${2}`
TR=`${FSLDIR}/bin/fslval $input pixdim4 | cut -d " " -f 1`
TR_units=`${FSLDIR}/bin/fslval $input time_units | cut -d " " -f 1`
TR_vol=${TR}

#adjust TR_vol according to time_units for fslmerge -tr
if [ ${TR_units} = "s" ] ; then
        #this is correct;
        break
elif [ ${TR_units} = "ms" ] ; then
        TR_vol=$( echo "scale=4;${TR_vol} / 1000.0" | bc -l );
elif [ ${TR_units} = "us" ] ; then
        TR_vol=$( echo "scale=4;${TR_vol} / 1000000.0" | bc -l );
fi


if [ `${FSLDIR}/bin/imtest $input` -eq 0 ];then
    echo "Input does not exist or is not in a supported format"
    exit
fi

/bin/rm -rf $output ; mkdir $output

if [ x$3 = x ] ; then
  ${FSLDIR}/bin/fslroi $input ${output}_ref 10 10
  ${FSLDIR}/bin/fslsplit ${output}_ref ${output}_tmp
  for i in `${FSLDIR}/bin/imglob ${output}_tmp????.*` ; do
      echo making reference: processing $i
      echo making reference: processing $i  >> ${output}.ecclog
      ${FSLDIR}/bin/flirt -in $i -ref ${output}_tmp0000 -nosearch -dof 6 -o $i -paddingsize 1 >> ${output}.ecclog
  done
  ${FSLDIR}/bin/fslmerge -t ${output}_ref ${output}_tmp????.*
  ${FSLDIR}/bin/fslmaths ${output}_ref -Tmean ${output}_ref
  ref=${output}_ref
else
  ref=${3}
fi

pi=$(echo "scale=10; 4*a(1)" | bc -l)
outputFile=`basename ${output}`
fslsplit $input ${output}_tmp
${FSLDIR}/bin/fslmaths ${output}_tmp0000 -mul 0 -add 1 ${output}_allones
for i in `${FSLDIR}/bin/imglob ${output}_tmp????.*` ; do
    echo processing $i
    echo processing $i >> ${output}.ecclog
    ii=`basename $i | sed s/${outputFile}_tmp/MAT_/g`
    ${FSLDIR}/bin/flirt -in $i -ref $ref -nosearch -dof 6 -o $i -paddingsize 1 -omat ${output}/${ii}.mat >> ${output}.ecclog
    maskname=`echo $i | sed 's/_tmp/_mask/'`
    ${FSLDIR}/bin/flirt -in ${output}_allones -ref $ref -o $maskname -paddingsize 1 -setbackground 0 -init ${output}/${ii}.mat -applyxfm -noresampblur 
    mm=`avscale --allparams ${output}/${ii}.mat $ref | grep "Translations" | awk '{print $5 " " $6 " " $7}'`
    mmx=`echo $mm | cut -d " " -f 1`
    mmy=`echo $mm | cut -d " " -f 2`
    mmz=`echo $mm | cut -d " " -f 3`
    radians=`${FSLDIR}/bin/avscale --allparams ${output}/${ii}.mat $ref | grep "Rotation Angles" | awk '{print $6 " " $7 " " $8}'`
    radx=`echo $radians | cut -d " " -f 1`
    degx=`echo "$radx * (180 / $pi)" | sed 's/[eE]+\?/*10^/g' | bc -l`
    rady=`echo $radians | cut -d " " -f 2`
    degy=`echo "$rady * (180 / $pi)" | sed 's/[eE]+\?/*10^/g' | bc -l`
    radz=`echo $radians | cut -d " " -f 3`
    degz=`echo "$radz * (180 / $pi)" | sed 's/[eE]+\?/*10^/g' | bc -l`
    # The "%.6f" formatting specifier allows the numeric value to be as wide as it needs to be to accomodate the number
    # Then we mandate (include) a single space as a delimiter between values.
    echo `printf "%.6f" $mmx` `printf "%.6f" $mmy` `printf "%.6f" $mmz` `printf "%.6f" $degx` `printf "%.6f" $degy` `printf "%.6f" $degz` >> ${output}/mc.par
done

${FSLDIR}/bin/fslmerge -tr $output `${FSLDIR}/bin/imglob ${output}_tmp????.*` $TR_vol
${FSLDIR}/bin/fslmerge -tr ${output}_mask `${FSLDIR}/bin/imglob ${output}_mask????.*` $TR_vol
${FSLDIR}/bin/fslmaths ${output}_mask -Tmean -mul `$FSLDIR/bin/fslval ${output}_mask dim4` ${output}_mask

/bin/rm ${output}_tmp????.* ${output}_mask????.* ${output}_allones.*




