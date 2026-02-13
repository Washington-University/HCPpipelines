#! /bin/bash

# Normalize intensity of cortical grey or white matter of input volumes
# Takuya Hayashi, RIKEN Brain Connectomics Imaging Laboratory, 2024
# set -eux

Usage () {
echo "Normalize intensity of cortical grey or white matter of input volumes"
echo ""
echo "Usage: $(basename $0) <input> <brainmask.mgz> <aseg.mgz> <arguments> "
echo ""
echo "<input>                : input volume to be normalized (e.g. brain.finalsurfs.mgz or conf.T2.mgz)"
echo "<brainmask.mgz>        : input brainmask"
echo "<aseg.mgz>             : input aseg"

echo ""
echo "Compulsory arguments (either of):"
echo "  -g <ribbon.mgz>      : normalizing cortical grey matter using aseg and ribbon.mgz"
echo "  -w                   : normalizing white matter using aseg"   
echo ""
echo "Optional arguments"
echo "  -o <outputroot>      : output filename without extension"
echo ""
echo "Useful for suppressing surface errors due to signal inhomogeneity of cortical ribbon (e.g. high myelin, B1 bias) or white matter "
echo "(e.g. white matter lesions, vascular malformation). Default outputs are <input>.edit.mgz and <input>.edit.biasfield.mgz"
echo ""
echo "MANNUALS TO BE WRITTEN"

exit 1;
}
[ "$4" = "" ] && Usage

convertout () {
odt=$1; innifti=$2
if [ "$odt" = char ] ; then
	mri_convert -odt uchar -ns 1 ${innifti}.nii.gz ${innifti}.mgz
else
	mri_convert -ns 1 ${innifti}.nii.gz ${innifti}.mgz
fi
}

InputVolume=$(echo $1 | sed -e 's/.mgz//g')
BrainMask=$(echo $2 | sed -e 's/.mgz//g')
EditAseg=$(echo $3 | sed -e 's/.mgz//g')
Matter=$4

odt=char
tmp=$$
expectedribbon="80" 
expectedwhite="110"

adjribbon="1"
adjwhite="1"
adjnoncerebrum="1"

echo ""
echo "START: IntensityNormalize"

if   [ "$Matter" = "-g" ] ; then
	shift 4
	EditRibbon=$(echo $1 | sed -e 's/.mgz//g')
	echo " normalizing cortical grey matter of input volume using ${EditAseg}.mgz and ${EditRibbon}.mgz"
	shift 1
elif [ "$Matter" = "-w" ] ; then
	echo " normalizing white matter of input volume using ${EditAseg}.mgz"
	shift 4;
else
	Usage
fi

if [ "$1" = "-o" ] ; then
	if [ ! -z "$2" ] ; then
		out=$2
	else
		echo "ERROR: cannot find output filename"
		exit 1;
	fi
else
	out=${InputVolume}.edit 
fi

if [[ $(mri_info ${InputVolume}.mgz | grep type | tail -1) =~ UCHAR ]] ; then
	odt=char
else
	odt=float
fi

mri_convert ${InputVolume}.mgz ${InputVolume}.nii.gz
mri_convert ${EditAseg}.mgz ${EditAseg}.nii.gz
fslmaths ${EditAseg} -thr 2 -uthr 2 -bin -mul 41 -max ${EditAseg} -thr 41 -uthr 41 -bin ${EditAseg}.wm

meanwhite=$(fslstats ${InputVolume} -k ${EditAseg}.wm -M)

if [ "$Matter" = "-g" ] ; then 

	GreySigma=4.5   # cortical biasfield sigma  4.5 

	PSigma=0.5      # partial volume effect in biasfield 0.5

	mri_convert ${EditRibbon}.mgz ${EditRibbon}.nii.gz
	if [ $(fslstats ${EditRibbon} -R | awk '{printf "%d",$2}') = 42 ] ; then
		fslmaths ${EditRibbon} -thr 3 -uthr 3 -bin -mul 39 -add ${EditRibbon} -thr 42 -uthr 42 -bin ${EditRibbon}${tmp}
		fslmaths ${EditRibbon} -thr 3 -uthr 3 -bin ${EditRibbon}${tmp}.L
		fslmaths ${EditRibbon} -thr 42 -uthr 42 -bin ${EditRibbon}${tmp}.R
		fslmaths ${EditRibbon} -binv ${EditRibbon}${tmp}.binvcerebrum
	else
		echo "ERROR: cannnot find ribbon voxels - values of \"3 and 42\" are not found. "
		exit 1;
	fi
	fslmaths ${InputVolume} -mas  ${EditRibbon}${tmp}.nii.gz ${InputVolume}.ribbon
	fslmaths ${EditRibbon}${tmp} -binv ${InputVolume}.binvribbon
	fslmaths ${InputVolume}.binvribbon -mas ${EditAseg}.nii.gz ${InputVolume}.binvribbon_brain
 
	meanribbon=$(fslstats ${InputVolume} -k ${EditRibbon}${tmp} -M)
	meanribbonL=$(fslstats ${InputVolume} -k ${EditRibbon}${tmp}.L -M)
	meanribbonR=$(fslstats ${InputVolume} -k ${EditRibbon}${tmp}.R -M)

	echo "mean ribbon: $meanribbon"
	echo "mean ribbon L: $meanribbonL"
	echo "mean ribbon R: $meanribbonR"
	echo "mean white: $meanwhite"

	if [ ! -z "$expectedribbon" ] ; then
		adjribbon=$(echo $expectedribbon/$meanribbon | bc -l)
	fi
	if [ ! -z "$expectedwhite" ] ; then
		adjwhite=$(echo $expectedwhite/$meanwhite | bc -l)
	fi

	if [ $(echo "$meanwhite > $meanribbon" | bc -l) = 1 ] ; then
		phase="-"
	else
		phase=""		
	fi

	fslmaths ${EditRibbon}${tmp} -s $GreySigma ${EditRibbon}${tmp}_s$GreySigma
	fslmaths ${InputVolume}.ribbon -s $GreySigma -div $meanribbon -div ${EditRibbon}${tmp}_s$GreySigma -mas ${EditRibbon}${tmp} ${InputVolume}.ribbon
	fslmaths ${InputVolume}.ribbon -div $adjribbon ${InputVolume}.ribbon
	fslmaths ${InputVolume} -mas ${InputVolume}.binvribbon -bin -div $adjwhite ${InputVolume}.binvribbon
	fslmaths ${InputVolume}.ribbon -add ${InputVolume}.binvribbon bias${tmp}
	fslmaths ${EditRibbon}${tmp}.binvcerebrum -mul $(echo "${phase}l($adjnoncerebrum)" | bc -l) -exp -mul bias${tmp} -s $PSigma bias${tmp}
	fslmaths ${InputVolume} -div bias${tmp} ${out}${tmp} -odt $odt
	imrm ${InputVolume}.ribbon ${InputVolume}.binvribbon ${EditRibbon}${tmp} bias${tmp} ${EditRibbon} ${EditRibbon}${tmp}_s$GreySigma ${InputVolume}.binvribbon_brain ${EditRibbon}${tmp}.R ${EditRibbon}${tmp}.L ${EditRibbon}${tmp}.binvcerebrum
	convertout $odt ${out}${tmp}
	
elif [ "$Matter" = "-w" ] ; then 

	limit=1.5  #  outlier threshold for abnormal voxel intensity

	IQRs=$(fslstats ${InputVolume} -k ${EditAseg}.wm -P 25 -P 50 -P 75)
	UL=$(echo $IQRs | awk '{printf "%0.8f", $3+($3-$1)*'$limit'}')
	LL=$(echo $IQRs | awk '{printf "%0.8f", $1-($3-$1)*'$limit'}')
	fslmaths ${InputVolume} -mas ${EditAseg}.wm -thr  $UL -bin ${EditAseg}.wm.outlierUL 
	fslmaths ${InputVolume} -mas ${EditAseg}.wm -uthr $LL -bin ${EditAseg}.wm.outlierLL 
	fslmaths ${EditAseg}.wm.outlierUL -add ${EditAseg}.wm.outlierLL ${EditAseg}.wm.outlier
	fslmaths ${EditAseg}.wm.outlier -binv -mul ${InputVolume} -mas ${EditAseg}.wm -dilM -dilM -dilM -dilM -dilM -mas ${EditAseg}.wm.outlier ${out}${tmp}
	fslmaths ${EditAseg}.wm.outlier -binv -mul ${InputVolume} -add ${out}${tmp} ${out}${tmp} -odt char

	echo "mean white: $meanwhite"
	meanwhite=$(fslstat s${out}${tmp} -k ${EditAseg}.wm -M)
	echo "mean white after removal of outliers: $meanwhite"
	if [ ! -z "$expectedwhite" ] ; then
		adjwhite=$(echo $expectedwhite/$meanwhite | bc -l)
	fi
	fslmaths ${out}${tmp} -div $adjwhite ${out}${tmp} -odt char
	fslmaths ${InputVolume} -div ${out}${tmp} ${out}.biasfield
	imrm ${EditAseg}.wm.outlierUL ${EditAseg}.wm.outlierLL
	convertout $odt ${out}${tmp}

fi

# normalize with FreeSurfer
echo "...normalize brain.finalsurfs.edit using aseg and brainmask"
mri_normalize -mprage -aseg ${EditAseg}.mgz -mask ${BrainMask}.mgz ${out}${tmp}.mgz ${out}.mgz
fscalc ${InputVolume}.mgz div ${out}.mgz --o ${out}.biasfield.mgz --odt float

imrm ${InputVolume}.nii.gz ${out}.nii.gz ${EditAseg}.wm.nii.gz ${EditAseg}.nii.gz ${out}${tmp}.nii.gz
rm ${out}${tmp}.mgz

echo ""
echo "END: IntensityNormalize"
