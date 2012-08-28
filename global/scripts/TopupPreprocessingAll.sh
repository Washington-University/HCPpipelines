#!/bin/bash 
set -e

echo -e "\n START: Topup Field Map Generation and Gradient Unwarping"

WorkingDirectory="$1"
PhaseEncodeOne="$2"
PhaseEncodeTwo="$3"
DwellTime="$4"
UnwarpDir="$5"
MagnitudeOutput="$6"
MagnitudeBrainOutput="$7"
TopUpFieldOutput="$8"
FieldMapOutput="$9"
GradientDistortionCoeffs="${10}"
GlobalScripts="${11}"
TopupConfig="${12}"

cp $PhaseEncodeOne "$WorkingDirectory"/PhaseOne.nii.gz
cp $PhaseEncodeTwo "$WorkingDirectory"/PhaseTwo.nii.gz

if [ ! $GradientDistortionCoeffs = "NONE" ] ; then
  "$GlobalScripts"/GradientDistortionUnwarp.sh "$WorkingDirectory" "$GradientDistortionCoeffs" "$WorkingDirectory"/PhaseOne "$WorkingDirectory"/PhaseOne_gdc "$WorkingDirectory"/PhaseOne_gdc_warp
  "$GlobalScripts"/GradientDistortionUnwarp.sh "$WorkingDirectory" "$GradientDistortionCoeffs" "$WorkingDirectory"/PhaseTwo "$WorkingDirectory"/PhaseTwo_gdc "$WorkingDirectory"/PhaseTwo_gdc_warp
fi

echo "fslmerge -t "$WorkingDirectory"/BothPhases "$WorkingDirectory"/PhaseOne_gdc "$WorkingDirectory"/PhaseTwo_gdc"
fslmerge -t "$WorkingDirectory"/BothPhases "$WorkingDirectory"/PhaseOne_gdc "$WorkingDirectory"/PhaseTwo_gdc

txtfname="$WorkingDirectory"/acqparams.txt
if [ -e $txtfname ] ; then
  rm $txtfname
fi

dimtOne=`fslval "$WorkingDirectory"/PhaseOne dim4`
dimtTwo=`fslval "$WorkingDirectory"/PhaseTwo dim4`


if [[ $UnwarpDir = "x" || $UnwarpDir = "x-" || $UnwarpDir = "-x" ]] ; then
  dimx=`fslval "$WorkingDirectory"/PhaseOne dim1`
  nPEsteps=$(($dimx - 1))
  #Total_readout=Echo_spacing*(#of_PE_steps-1)
  ro_time=`echo "scale=6; ${DwellTime} * ${nPEsteps}" | bc -l` #Compute Total_readout in secs with up to 6 decimal places
  echo "Total readout time is $ro_time secs"
  i=1
  while [ $i -le $dimtOne ] ; do
    echo "-1 0 0 $ro_time" >> $txtfname
    i=`echo "$i +1" | bc`
  done
  i=1
  while [ $i -le $dimtTwo ] ; do
    echo "1 0 0 $ro_time" >> $txtfname
    i=`echo "$i +1" | bc`
  done
elif [[ $UnwarpDir = "y" || $UnwarpDir = "y-" || $UnwarpDir = "-y" ]] ; then
  dimy=`fslval "$WorkingDirectory"/PhaseOne dim2`
  nPEsteps=$(($dimy - 1))
  #Total_readout=Echo_spacing*(#of_PE_steps-1)
  ro_time=`echo "scale=6; ${DwellTime} * ${nPEsteps}" | bc -l` #Compute Total_readout in secs with up to 6 decimal places
  i=1
  while [ $i -le $dimtOne ] ; do
    echo "0 -1 0 $ro_time" >> $txtfname
    i=`echo "$i +1" | bc`
  done
  i=1
  while [ $i -le $dimtTwo ] ; do
    echo "0 1 0 $ro_time" >> $txtfname
    i=`echo "$i +1" | bc`
  done
fi

echo "topup --imain="$WorkingDirectory"/BothPhases --datain=$txtfname --config="$TopupConfig" --out="$WorkingDirectory"/Coefficents --fout="$WorkingDirectory"/TopupField --iout="$WorkingDirectory"/Magnitudes"
topup --imain="$WorkingDirectory"/BothPhases --datain=$txtfname --config="$TopupConfig" --out="$WorkingDirectory"/Coefficents --fout="$WorkingDirectory"/TopupField --iout="$WorkingDirectory"/Magnitudes

fslmaths "$WorkingDirectory"/Magnitudes -Tmean "$WorkingDirectory"/Magnitude.nii.gz
bet "$WorkingDirectory"/Magnitude.nii.gz "$WorkingDirectory"/Magnitude_brain.nii.gz -f .3 -m #Brain extract the magnitude image

fslmaths "$WorkingDirectory"/TopupField -mul 6.283 "$WorkingDirectory"/FieldMap.nii.gz

cp "$WorkingDirectory"/Magnitude.nii.gz "$MagnitudeOutput".nii.gz
cp "$WorkingDirectory"/Magnitude_brain.nii.gz "$MagnitudeBrainOutput".nii.gz
cp "$WorkingDirectory"/TopupField.nii.gz "$TopUpFieldOutput".nii.gz
cp "$WorkingDirectory"/FieldMap.nii.gz "$FieldMapOutput".nii.gz

echo -e "\n END: Topup Field Map Generation and Gradient Unwarping"

