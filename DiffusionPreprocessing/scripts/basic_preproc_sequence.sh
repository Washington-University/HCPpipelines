#!/bin/bash
source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@" # Debugging functions; also sources log.shlib
scriptName="basic_preproc_sequence.sh"
echo -e "\n START: ${scriptName}"

workingdir=$1
ro_time=$2 #in sec
PEdir=$3
b0dist=$4
b0maxbval=$5

echo "${scriptName}: Input Parameter: workingdir: ${workingdir}"
echo "${scriptName}: Input Parameter: ro_time: ${ro_time}" # Readout time in sec
echo "${scriptName}: Input Parameter: PEdir: ${PEdir}"
echo "${scriptName}: Input Parameter: b0dist: ${b0dist}"
echo "${scriptName}: Input Parameter: b0maxbval: ${b0maxbval}"

rawdir=${workingdir}/rawdata
topupdir=${workingdir}/topup
eddydir=${workingdir}/eddy

if [[ ${PEdir} -ne 1 && ${PEdir} -ne 2 ]]; then
	echo -e "\n ${scriptName}: ERROR: basic_preproc: Unrecognized PEdir: ${PEdir}"
	exit 1
fi

# Use same convention for basePos and baseNeg names as in DiffPreprocPipeline_PreEddy.sh
basePos="Pos"
baseNeg="Neg"

################################################################################################
## b0 extraction and Creation of Index files for topup/eddy
################################################################################################
echo "Extracting b0s from PE_Positive volumes and creating index and series files"
declare -i sesdimt #declare sesdimt as integer
tmp_indx=1
while read line; do #Read SeriesCorrespVolNum.txt file
	PCorVolNum[${tmp_indx}]=$(echo $line | awk {'print $1'})
	tmp_indx=$((${tmp_indx} + 1))
done <${rawdir}/${basePos}_SeriesCorrespVolNum.txt

scount=1
scount2=1
indcount=0
for entry in ${rawdir}/${basePos}_[0-9]*.nii*; do #For each Pos volume
	#Extract b0s and create index file
	basename=$(imglob ${entry})
	Posbvals=$(cat ${basename}.bval)
	count=0 #Within series counter
	count3=$((${b0dist} + 1))
	for i in ${Posbvals}; do
		if [ $count -ge ${PCorVolNum[${scount2}]} ]; then
			tmp_ind=${indcount}
			if [ $((tmp_ind)) -eq 0 ]; then
				tmp_ind=$((${indcount} + 1))
			fi
			echo ${tmp_ind} >>${rawdir}/index.txt
		else #Consider a b=0 a volume that has a bvalue<${b0maxbval} and is at least ${b0dist} volumes away from the previous
			if [ $i -lt ${b0maxbval} ] && [ ${count3} -gt ${b0dist} ]; then
				cnt=$($FSLDIR/bin/zeropad $indcount 4)
				echo "Extracting Pos Volume $count from ${entry} as a b=0. Measured b=$i" >>${rawdir}/extractedb0.txt
				$FSLDIR/bin/fslroi ${entry} ${rawdir}/Pos_b0_${cnt} ${count} 1
				if [ ${PEdir} -eq 1 ]; then #RL/LR phase encoding
					echo 1 0 0 ${ro_time} >>${rawdir}/acqparams.txt
				elif [ ${PEdir} -eq 2 ]; then #AP/PA phase encoding
					echo 0 1 0 ${ro_time} >>${rawdir}/acqparams.txt
				fi
				indcount=$((${indcount} + 1))
				count3=0
			fi
			echo ${indcount} >>${rawdir}/index.txt
			count3=$((${count3} + 1))
		fi
		count=$((${count} + 1))
	done

	#Create series file
	sesdimt=$(${FSLDIR}/bin/fslval ${entry} dim4) #Number of data points per Pos series
	for ((j = 0; j < ${sesdimt}; j++)); do
		echo ${scount} >>${rawdir}/series_index.txt
	done
	scount=$((${scount} + 1))
	scount2=$((${scount2} + 1))
done

echo "Extracting b0s from PE_Negative volumes and creating index and series files"
tmp_indx=1
while read line; do #Read SeriesCorrespVolNum.txt file
	NCorVolNum[${tmp_indx}]=$(echo $line | awk {'print $1'})
	tmp_indx=$((${tmp_indx} + 1))
done <${rawdir}/${baseNeg}_SeriesCorrespVolNum.txt

Poscount=${indcount}
indcount=0
scount2=1
for entry in ${rawdir}/${baseNeg}_[0-9]*.nii*; do #For each Neg volume
	#Extract b0s and create index file
	basename=$(imglob ${entry})
	Negbvals=$(cat ${basename}.bval)
	count=0
	count3=$((${b0dist} + 1))
	for i in ${Negbvals}; do
		if [ $count -ge ${NCorVolNum[${scount2}]} ]; then
			tmp_ind=${indcount}
			if [ $((tmp_ind)) -eq 0 ]; then
				tmp_ind=$((${indcount} + 1))
			fi
			echo $((${tmp_ind} + ${Poscount})) >>${rawdir}/index.txt
		else #Consider a b=0 a volume that has a bvalue<${b0maxbval} and is at least ${b0dist} volumes away from the previous
			if [ $i -lt ${b0maxbval} ] && [ ${count3} -gt ${b0dist} ]; then
				cnt=$($FSLDIR/bin/zeropad $indcount 4)
				echo "Extracting Neg Volume $count from ${entry} as a b=0. Measured b=$i" >>${rawdir}/extractedb0.txt
				$FSLDIR/bin/fslroi ${entry} ${rawdir}/Neg_b0_${cnt} ${count} 1
				if [ ${PEdir} -eq 1 ]; then #RL/LR phase encoding
					echo -1 0 0 ${ro_time} >>${rawdir}/acqparams.txt
				elif [ ${PEdir} -eq 2 ]; then #AP/PA phase encoding
					echo 0 -1 0 ${ro_time} >>${rawdir}/acqparams.txt
				fi
				indcount=$((${indcount} + 1))
				count3=0
			fi
			echo $((${indcount} + ${Poscount})) >>${rawdir}/index.txt
			count3=$((${count3} + 1))
		fi
		count=$((${count} + 1))
	done

	#Create series file
	sesdimt=$(${FSLDIR}/bin/fslval ${entry} dim4)
	for ((j = 0; j < ${sesdimt}; j++)); do
		echo ${scount} >>${rawdir}/series_index.txt #Create series file
	done
	scount=$((${scount} + 1))
	scount2=$((${scount2} + 1))
done

################################################################################################
## Merging Files
################################################################################################
echo "Merging Pos and Neg images"
${FSLDIR}/bin/fslmerge -t ${rawdir}/Pos_b0 $(${FSLDIR}/bin/imglob ${rawdir}/Pos_b0_????.*)
${FSLDIR}/bin/fslmerge -t ${rawdir}/Neg_b0 $(${FSLDIR}/bin/imglob ${rawdir}/Neg_b0_????.*)
# Include nii in filename of imrm command due to bug in behavior of imrm introduced in FSL 6.0.6
${FSLDIR}/bin/imrm ${rawdir}/Pos_b0_????.nii*
${FSLDIR}/bin/imrm ${rawdir}/Neg_b0_????.nii*
${FSLDIR}/bin/fslmerge -t ${rawdir}/Pos $(echo ${rawdir}/${basePos}_[0-9]*.nii*)
${FSLDIR}/bin/fslmerge -t ${rawdir}/Neg $(echo ${rawdir}/${baseNeg}_[0-9]*.nii*)

paste $(echo ${rawdir}/${basePos}_[0-9]*.bval) >${rawdir}/Pos.bval
paste $(echo ${rawdir}/${basePos}_[0-9]*.bvec) >${rawdir}/Pos.bvec
paste $(echo ${rawdir}/${baseNeg}_[0-9]*.bval) >${rawdir}/Neg.bval
paste $(echo ${rawdir}/${baseNeg}_[0-9]*.bvec) >${rawdir}/Neg.bvec

echo "Perform final merge"
${FSLDIR}/bin/fslmerge -t ${rawdir}/Pos_Neg_b0 ${rawdir}/Pos_b0 ${rawdir}/Neg_b0
${FSLDIR}/bin/fslmerge -t ${rawdir}/Pos_Neg ${rawdir}/Pos ${rawdir}/Neg
paste ${rawdir}/Pos.bval ${rawdir}/Neg.bval >${rawdir}/Pos_Neg.bvals
paste ${rawdir}/Pos.bvec ${rawdir}/Neg.bvec >${rawdir}/Pos_Neg.bvecs

${FSLDIR}/bin/imrm ${rawdir}/Pos
${FSLDIR}/bin/imrm ${rawdir}/Neg

################################################################################################
## Move files to appropriate directories
################################################################################################
echo "Move files to appropriate directories"
mv ${rawdir}/extractedb0.txt ${topupdir}
mv ${rawdir}/acqparams.txt ${topupdir}
${FSLDIR}/bin/immv ${rawdir}/Pos_Neg_b0 ${topupdir}
${FSLDIR}/bin/immv ${rawdir}/Pos_b0 ${topupdir}
${FSLDIR}/bin/immv ${rawdir}/Neg_b0 ${topupdir}

cp ${topupdir}/acqparams.txt ${eddydir}
mv ${rawdir}/index.txt ${eddydir}
mv ${rawdir}/series_index.txt ${eddydir}
${FSLDIR}/bin/immv ${rawdir}/Pos_Neg ${eddydir}
mv ${rawdir}/Pos_Neg.bvals ${eddydir}
mv ${rawdir}/Pos_Neg.bvecs ${eddydir}
mv ${rawdir}/Pos.bv?? ${eddydir}
mv ${rawdir}/Neg.bv?? ${eddydir}

echo -e "\n END: ${scriptName}"
