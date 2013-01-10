#!/bin/bash 
set -e

echo -e "\n START: Topup Field Map Generation and Gradient Unwarping"

WorkingDirectory="$1"
PhaseEncodeOne="$2" #SCRIPT REQUIRES LR/X-/-1 VOLUME FIRST (SAME IS TRUE OF AP/PA)
PhaseEncodeTwo="$3" #SCRIPT REQUIRES RL/X/1 VOLUME SECOND (SAME IS TRUE OF AP/PA)
ScoutInputName="$4"
DwellTime="$5"
UnwarpDir="$6"
DistortionCorrectionWarpFieldOutput="$7"
JacobianOutput="$8"
GradientDistortionCoeffs="$9"
GlobalScripts="${10}"
TopupConfig="${11}"
GlobalBinaries="${12}"

cp $PhaseEncodeOne "$WorkingDirectory"/PhaseOne.nii.gz
cp $PhaseEncodeTwo "$WorkingDirectory"/PhaseTwo.nii.gz
cp $ScoutInputName.nii.gz "$WorkingDirectory"/SBRef.nii.gz

if [ ! $GradientDistortionCoeffs = "NONE" ] ; then
  "$GlobalScripts"/GradientDistortionUnwarp.sh "$WorkingDirectory" "$GradientDistortionCoeffs" "$WorkingDirectory"/PhaseOne "$WorkingDirectory"/PhaseOne_gdc "$WorkingDirectory"/PhaseOne_gdc_warp
  "$GlobalScripts"/GradientDistortionUnwarp.sh "$WorkingDirectory" "$GradientDistortionCoeffs" "$WorkingDirectory"/PhaseTwo "$WorkingDirectory"/PhaseTwo_gdc "$WorkingDirectory"/PhaseTwo_gdc_warp
fi

fslmaths "$WorkingDirectory"/PhaseOne -abs -bin -dilD "$WorkingDirectory"/PhaseOne_mask
applywarp --interp=nn -i "$WorkingDirectory"/PhaseOne_mask -r "$WorkingDirectory"/PhaseOne_mask -w "$WorkingDirectory"/PhaseOne_gdc_warp -o "$WorkingDirectory"/PhaseOne_mask_gdc
fslmaths "$WorkingDirectory"/PhaseTwo -abs -bin -dilD "$WorkingDirectory"/PhaseTwo_mask
applywarp --interp=nn -i "$WorkingDirectory"/PhaseTwo_mask -r "$WorkingDirectory"/PhaseTwo_mask -w "$WorkingDirectory"/PhaseTwo_gdc_warp -o "$WorkingDirectory"/PhaseTwo_mask_gdc

fslmaths "$WorkingDirectory"/PhaseOne_mask_gdc -mas "$WorkingDirectory"/PhaseTwo_mask_gdc -ero -bin "$WorkingDirectory"/Mask

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
    ShiftOne="x-"
    i=`echo "$i +1" | bc`
  done
  i=1
  while [ $i -le $dimtTwo ] ; do
    echo "1 0 0 $ro_time" >> $txtfname
    ShiftTwo="x"
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
    ShiftOne="y-"
    i=`echo "$i +1" | bc`
  done
  i=1
  while [ $i -le $dimtTwo ] ; do
    echo "0 1 0 $ro_time" >> $txtfname
    ShiftTwo="y"
    i=`echo "$i +1" | bc`
  done
fi

fslmaths "$WorkingDirectory"/BothPhases -abs -add 1 -mas "$WorkingDirectory"/Mask -dilD -dilD -dilD -dilD -dilD "$WorkingDirectory"/BothPhases

topup --imain="$WorkingDirectory"/BothPhases --datain=$txtfname --config="$TopupConfig" --out="$WorkingDirectory"/Coefficents --iout="$WorkingDirectory"/Magnitudes --fout="$WorkingDirectory"/TopupField --dfout="$WorkingDirectory"/WarpField --rbmout="$WorkingDirectory"/MotionMatrix --jacout="$WorkingDirectory"/Jacobian -v 

if [ $UnwarpDir = "x" ] ; then
  VolumeNumber=$(($dimtOne + 1))
  flirt -dof 6 -interp spline -in "$WorkingDirectory"/SBRef.nii.gz -ref "$WorkingDirectory"/PhaseTwo_gdc -omat "$WorkingDirectory"/SBRef2PhaseTwo_gdc.mat -out "$WorkingDirectory"/SBRef2PhaseTwo_gdc
  convert_xfm -omat "$WorkingDirectory"/SBRef2WarpField.mat -concat "$WorkingDirectory"/MotionMatrix_`zeropad $VolumeNumber 2`.mat "$WorkingDirectory"/SBRef2PhaseTwo_gdc.mat
  convertwarp -r "$WorkingDirectory"/PhaseTwo_gdc --premat="$WorkingDirectory"/SBRef2WarpField.mat --warp1="$WorkingDirectory"/WarpField_`zeropad $VolumeNumber 2` --out="$WorkingDirectory"/WarpField.nii.gz
  cp "$WorkingDirectory"/Jacobian_`zeropad $VolumeNumber 2`.nii.gz "$WorkingDirectory"/Jacobian.nii.gz
elif [[ $UnwarpDir = "x-" || $UnwarpDir = "-x" ]] ; then
  VolumeNumber=$((0 + 1))
  flirt -dof 6 -interp spline -in "$WorkingDirectory"/SBRef.nii.gz -ref "$WorkingDirectory"/PhaseOne_gdc -omat "$WorkingDirectory"/SBRef2PhaseOne_gdc.mat -out "$WorkingDirectory"/SBRef2PhaseOne_gdc
  convert_xfm -omat "$WorkingDirectory"/SBRef2WarpField.mat -concat "$WorkingDirectory"/MotionMatrix_`zeropad $VolumeNumber 2`.mat "$WorkingDirectory"/SBRef2PhaseOne_gdc.mat
  convertwarp -r "$WorkingDirectory"/PhaseOne_gdc --premat="$WorkingDirectory"/SBRef2WarpField.mat --warp1="$WorkingDirectory"/WarpField_`zeropad $VolumeNumber 2` --out="$WorkingDirectory"/WarpField.nii.gz
  cp "$WorkingDirectory"/Jacobian_`zeropad $VolumeNumber 2`.nii.gz "$WorkingDirectory"/Jacobian.nii.gz
fi

VolumeNumber=$(($dimtOne + 1))
applywarp --interp=spline -i "$WorkingDirectory"/PhaseTwo_gdc -r "$WorkingDirectory"/PhaseTwo_gdc --premat="$WorkingDirectory"/MotionMatrix_`zeropad $VolumeNumber 2`.mat -w "$WorkingDirectory"/WarpField_`zeropad $VolumeNumber 2` -o "$WorkingDirectory"/PhaseTwo_gdc_dc
fslmaths "$WorkingDirectory"/PhaseTwo_gdc_dc -mul "$WorkingDirectory"/Jacobian_`zeropad $VolumeNumber 2` "$WorkingDirectory"/PhaseTwo_gdc_dc_jac
VolumeNumber=$((0 + 1))
applywarp --interp=spline -i "$WorkingDirectory"/PhaseOne_gdc -r "$WorkingDirectory"/PhaseOne_gdc --premat="$WorkingDirectory"/MotionMatrix_`zeropad $VolumeNumber 2`.mat -w "$WorkingDirectory"/WarpField_`zeropad $VolumeNumber 2` -o "$WorkingDirectory"/PhaseOne_gdc_dc
fslmaths "$WorkingDirectory"/PhaseOne_gdc_dc -mul "$WorkingDirectory"/Jacobian_`zeropad $VolumeNumber 2` "$WorkingDirectory"/PhaseOne_gdc_dc_jac


applywarp --interp=spline -i "$WorkingDirectory"/SBRef.nii.gz -r "$WorkingDirectory"/SBRef.nii.gz -w "$WorkingDirectory"/WarpField.nii.gz -o "$WorkingDirectory"/SBRef_dc.nii.gz
fslmaths "$WorkingDirectory"/SBRef_dc.nii.gz -mul "$WorkingDirectory"/Jacobian.nii.gz "$WorkingDirectory"/SBRef_dc_jac.nii.gz

  #For first phase encoding direction given to topup the rigid body registration between the field and the spin echo image is the identity
  #For the second phase encoding direction given to topup the rigid body registration to one input spin echo volume is given by one of registration matricies, the SBRef needs to be registered to this same spin echo image
  #The SBRef images of each phase encoding direction need to be registered to the spin echo images (1st and 4th)
  #Apply topup warpfield to SBRef in FNIRT warpfield format (--dfout= one field per image that was given to topup do not include rigid body transforms)


#cp "$WorkingDirectory"/Magnitudes.nii.gz "$WorkingDirectory"/Magnitudes_TopupOut.nii.gz

#fslmaths "$WorkingDirectory"/TopupField -mul 6.283 "$WorkingDirectory"/FieldMap.nii.gz

#fugue --loadfmap="$WorkingDirectory"/FieldMap.nii.gz --dwell=${DwellTime} --saveshift="$WorkingDirectory"/FieldMap_ShiftMap.nii.gz
#convertwarp --ref="$WorkingDirectory"/FieldMap.nii.gz --shiftmap="$WorkingDirectory"/FieldMap_ShiftMap.nii.gz --shiftdir="$ShiftOne" --out="$WorkingDirectory"/FieldMap_Warp_"$ShiftOne".nii.gz
#convertwarp --ref="$WorkingDirectory"/FieldMap.nii.gz --shiftmap="$WorkingDirectory"/FieldMap_ShiftMap.nii.gz --shiftdir="$ShiftTwo" --out="$WorkingDirectory"/FieldMap_Warp_"$ShiftTwo".nii.gz

#applywarp --interp=spline -i "$WorkingDirectory"/PhaseOne_gdc.nii.gz -r "$WorkingDirectory"/PhaseOne_gdc.nii.gz -w "$WorkingDirectory"/FieldMap_Warp_"$ShiftOne".nii.gz -o "$WorkingDirectory"/PhaseOne_gdc_dc.nii.gz
#applywarp --interp=spline -i "$WorkingDirectory"/PhaseTwo_gdc.nii.gz -r "$WorkingDirectory"/PhaseTwo_gdc.nii.gz -w "$WorkingDirectory"/FieldMap_Warp_"$ShiftTwo".nii.gz -o "$WorkingDirectory"/PhaseTwo_gdc_dc.nii.gz

#fslmerge -t "$WorkingDirectory"/Magnitudes.nii.gz "$WorkingDirectory"/PhaseOne_gdc_dc.nii.gz "$WorkingDirectory"/PhaseTwo_gdc_dc.nii.gz

#dimt=`fslval "$WorkingDirectory"/PhaseOne_gdc dim4`
#dimt=$(($dimt + 1))
#${GlobalBinaries}/applytopup --interp=spline --imain="$WorkingDirectory"/PhaseOne_gdc,"$WorkingDirectory"/PhaseTwo_gdc --datain=$txtfname --inindex=1,$dimt --topup="$WorkingDirectory"/Coefficents --out="$WorkingDirectory"/Magnitudes

#fslmaths "$WorkingDirectory"/Magnitudes -Tmean "$WorkingDirectory"/Magnitude.nii.gz
#bet "$WorkingDirectory"/Magnitude.nii.gz "$WorkingDirectory"/Magnitude_brain.nii.gz -f .3 -m #Brain extract the magnitude image


#cp "$WorkingDirectory"/Magnitude.nii.gz "$MagnitudeOutput".nii.gz
#cp "$WorkingDirectory"/Magnitude_brain.nii.gz "$MagnitudeBrainOutput".nii.gz
#cp "$WorkingDirectory"/TopupField.nii.gz "$TopUpFieldOutput".nii.gz
#cp "$WorkingDirectory"/FieldMap.nii.gz "$FieldMapOutput".nii.gz

cp "$WorkingDirectory"/WarpField.nii.gz "$DistortionCorrectionWarpFieldOutput".nii.gz
cp "$WorkingDirectory"/Jacobian.nii.gz "$JacobianOutput".nii.gz

echo -e "\n END: Topup Field Map Generation and Gradient Unwarping"

