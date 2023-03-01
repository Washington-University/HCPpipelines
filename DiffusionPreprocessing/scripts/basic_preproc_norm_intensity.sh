#!/bin/bash
source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@" # Debugging functions; also sources log.shlib
scriptName="basic_preproc_norm_intensity.sh"
echo -e "\n START: ${scriptName}"

workingdir=$1
b0maxbval=$2

echo "${scriptName}: Input Parameter: workingdir: ${workingdir}"
echo "${scriptName}: Input Parameter: b0maxbval: ${b0maxbval}"

# Use same convention for basePos and baseNeg names as in DiffPreprocPipeline_PreEddy.sh
basePos="Pos"
baseNeg="Neg"

rawdir=${workingdir}/rawdata
topupdir=${workingdir}/topup
eddydir=${workingdir}/eddy

################################################################################################
## Intensity Normalisation across Series
################################################################################################
echo "${scriptName}: Rescaling series to ensure consistency across baseline intensities"
entry_cnt=0
for entry in ${rawdir}/${basePos}_[0-9]*.nii* ${rawdir}/${baseNeg}_[0-9]*.nii*; do #For each series, get the mean b0 and rescale to match the first series baseline
	basename=$(imglob ${entry})
	echo "${scriptName}: Processing $basename"

	echo "${scriptName}: About to fslmaths ${entry} -Xmean -Ymean -Zmean ${basename}_mean"
	${FSLDIR}/bin/fslmaths ${entry} -Xmean -Ymean -Zmean ${basename}_mean
	if [ ! -e ${basename}_mean.nii.gz ]; then
		echo "${scriptName}: ERROR: Mean file: ${basename}_mean.nii.gz not created"
		exit 1
	fi

	echo "${scriptName}: Getting Posbvals from ${basename}.bval"
	Posbvals=$(cat ${basename}.bval)
	echo "${scriptName}: Posbvals: ${Posbvals}"

	mcnt=0
	for i in ${Posbvals}; do #extract all b0s for the series
		echo "${scriptName}: Posbvals i: ${i}"
		cnt=$($FSLDIR/bin/zeropad $mcnt 4)
		echo "${scriptName}: cnt: ${cnt}"
		if [ $i -lt ${b0maxbval} ]; then
			echo "${scriptName}: About to fslroi ${basename}_mean ${basename}_b0_${cnt} ${mcnt} 1"
			$FSLDIR/bin/fslroi ${basename}_mean ${basename}_b0_${cnt} ${mcnt} 1
		fi
		mcnt=$((${mcnt} + 1))
	done

	echo "${scriptName}: About to fslmerge -t ${basename}_mean $(echo ${basename}_b0_????.nii*)"
	${FSLDIR}/bin/fslmerge -t ${basename}_mean $(echo ${basename}_b0_????.nii*)

	echo "${scriptName}: About to fslmaths ${basename}_mean -Tmean ${basename}_mean"
	${FSLDIR}/bin/fslmaths ${basename}_mean -Tmean ${basename}_mean #This is the mean baseline b0 intensity for the series
	# Include nii in filename of imrm command due to bug in behavior of imrm introduced in FSL 6.0.6
	${FSLDIR}/bin/imrm ${basename}_b0_????.nii*
	if [ ${entry_cnt} -eq 0 ]; then #Do not rescale the first series
		rescale=$(fslmeants -i ${basename}_mean)
	else
		scaleS=$(fslmeants -i ${basename}_mean)
		${FSLDIR}/bin/fslmaths ${basename} -mul ${rescale} -div ${scaleS} ${basename}_new
		${FSLDIR}/bin/imrm ${basename} #For the rest, replace the original dataseries with the rescaled one
		${FSLDIR}/bin/immv ${basename}_new ${basename}
	fi
	entry_cnt=$((${entry_cnt} + 1))
	${FSLDIR}/bin/imrm ${basename}_mean
done

echo -e "\n END: ${scriptName}"
