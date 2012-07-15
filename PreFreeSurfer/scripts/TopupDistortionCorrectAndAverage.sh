#!/bin/bash 
set -e

WorkingDirectory="$1"
InputFiles="$2"
OutputFile="$3"
TopupConfig="$4"

#HACK FOR TOPUP NOT ACCEPTING z-direction distortion correction
echo "0 1 0 1" > "$WorkingDirectory"/topupdatain.txt
echo "0 -1 0 1" >> "$WorkingDirectory"/topupdatain.txt
Files=""
i="1"
Directions="up dn"
for File in $InputFiles ; do
  Direction=`echo $Directions | cut -d " " -f $i`
  fslswapdim "$File".nii.gz -x z y "$WorkingDirectory"/"$Direction".nii.gz
  Files=`echo "$Files""$WorkingDirectory""/""$Direction"".nii.gz "`
  i=$(($i+1))
done
fslmerge -t "$WorkingDirectory"/imain $Files

topup --verbose --imain="$WorkingDirectory"/imain --datain="$WorkingDirectory"/topupdatain.txt --config="$TopupConfig" --out="$WorkingDirectory"/topupfield

applytopup --imain=`echo $Files | sed 's/ /,/g'` --datain="$WorkingDirectory"/topupdatain.txt --topup="$WorkingDirectory"/topupfield --inindex=1,2 --method=lsr --out="$WorkingDirectory"/rdc_avg

#More HACK
fslswapdim "$WorkingDirectory"/rdc_avg -x z y "$OutputFile"
