#!/bin/bash
set -e

Path=$1
SurfaceInput=$2
SurfaceOutput=$3
VolumeInput=$4
VolumeReference=$5
WarpField=$6
GlobalScripts=$7
Caret5_Command="${8}"

# The cd below means ALL FILENAMES MUST BE ABSOLUTE (OUTPUT ONES MAY BE RELATIVE TO WD)

cd $Path
Rand="$RANDOM"
$Caret5_Command -file-convert -format-convert ASCII $SurfaceInput
"$GlobalScripts"/split.pl $SurfaceInput header"$Rand".txt coords"$Rand".txt
Coords=`std2imgcoord -mm -std "$VolumeInput" -img "$VolumeReference" -warp "$WarpField" coords"$Rand".txt` #Use fast inverse warp method
pwd
echo "$Coords" | wc -l
echo "$Coords" > coords_nonlin"$Rand".txt
Var=`cat coords_nonlin"$Rand".txt | wc -l`
Var=`echo "$Var - 1" | bc`
cat coords_nonlin"$Rand".txt | head -$Var > coords_nonlinII"$Rand".txt 
"$GlobalScripts"/merge.pl header"$Rand".txt coords_nonlinII"$Rand".txt $SurfaceOutput
$Caret5_Command -file-convert -format-convert XML_BASE64_GZIP $SurfaceInput
$Caret5_Command -file-convert -format-convert XML_BASE64_GZIP $SurfaceOutput
rm header"$Rand".txt coords"$Rand".txt coords_nonlin"$Rand".txt coords_nonlinII"$Rand".txt 

