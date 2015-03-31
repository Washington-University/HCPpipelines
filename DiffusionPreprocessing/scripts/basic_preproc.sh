#!/bin/bash
set -e
scriptName="basic_preproc.sh"
echo -e "\n START: ${scriptName}"

workingdir=$1
echo_spacing=$2
PEdir=$3
b0dist=$4
b0maxbval=$5

echo "${scriptName}: Input Parameter: workingdir: ${workingdir}"
echo "${scriptName}: Input Parameter: echo_spacing: ${echo_spacing}"
echo "${scriptName}: Input Parameter: PEdir: ${PEdir}"
echo "${scriptName}: Input Parameter: b0dist: ${b0dist}"
echo "${scriptName}: Input Parameter: b0maxbval: ${b0maxbval}"

isodd(){
	echo "$(( $1 % 2 ))"
}

rawdir=${workingdir}/rawdata
topupdir=${workingdir}/topup
eddydir=${workingdir}/eddy
if [ ${PEdir} -eq 1 ]; then    #RL/LR phase encoding
	basePos="RL"
	baseNeg="LR"
elif [ ${PEdir} -eq 2 ]; then  #PA/AP phase encoding
	basePos="PA"
	baseNeg="AP"
else
	echo -e "\n ${scriptName}: ERROR: basic_preproc: Unrecognized PEdir: ${PEdir}"
fi


#Compute Total_readout in secs with up to 6 decimal places
any=`ls ${rawdir}/${basePos}*.nii* |head -n 1`
if [ ${PEdir} -eq 1 ]; then    #RL/LR phase encoding
	dimP=`${FSLDIR}/bin/fslval ${any} dim1`
elif [ ${PEdir} -eq 2 ]; then  #PA/AP phase encoding
	dimP=`${FSLDIR}/bin/fslval ${any} dim2`
fi
nPEsteps=$(($dimP - 1))                         #If GRAPPA is used this needs to include the GRAPPA factor!
#Total_readout=Echo_spacing*(#of_PE_steps-1)   
ro_time=`echo "${echo_spacing} * ${nPEsteps}" | bc -l`
ro_time=`echo "scale=6; ${ro_time} / 1000" | bc -l`
echo "${scriptName}: Total readout time is $ro_time secs"


################################################################################################
## Intensity Normalisation across Series 
################################################################################################
echo "${scriptName}: Rescaling series to ensure consistency across baseline intensities"
entry_cnt=0
for entry in ${rawdir}/${basePos}*.nii* ${rawdir}/${baseNeg}*.nii*  #For each series, get the mean b0 and rescale to match the first series baseline
do
	basename=`imglob ${entry}`
	echo "${scriptName}: Processing $basename"
	
	echo "${scriptName}: About to fslmaths ${entry} -Xmean -Ymean -Zmean ${basename}_mean"
	${FSLDIR}/bin/fslmaths ${entry} -Xmean -Ymean -Zmean ${basename}_mean
	if [ ! -e ${basename}_mean.nii.gz ] ; then
		echo "${scriptName}: ERROR: Mean file: ${basename}_mean.nii.gz not created"
		exit 1
	fi
	
	echo "${scriptName}: Getting Posbvals from ${basename}.bval"
	Posbvals=`cat ${basename}.bval`
	echo "${scriptName}: Posbvals: ${Posbvals}"
	
	mcnt=0
	for i in ${Posbvals} #extract all b0s for the series
	do
		echo "${scriptName}: Posbvals i: ${i}"
		cnt=`$FSLDIR/bin/zeropad $mcnt 4`
		echo "${scriptName}: cnt: ${cnt}"
		if [ $i -lt ${b0maxbval} ]; then
			echo "${scriptName}: About to fslroi ${basename}_mean ${basename}_b0_${cnt} ${mcnt} 1"
			$FSLDIR/bin/fslroi ${basename}_mean ${basename}_b0_${cnt} ${mcnt} 1
		fi
		mcnt=$((${mcnt} + 1))
	done
	
	echo "${scriptName}: About to fslmerge -t ${basename}_mean `echo ${basename}_b0_????.nii*`"
	${FSLDIR}/bin/fslmerge -t ${basename}_mean `echo ${basename}_b0_????.nii*`
	
	echo "${scriptName}: About to fslmaths ${basename}_mean -Tmean ${basename}_mean"
	${FSLDIR}/bin/fslmaths ${basename}_mean -Tmean ${basename}_mean #This is the mean baseline b0 intensity for the series
	${FSLDIR}/bin/imrm ${basename}_b0_????
	if [ ${entry_cnt} -eq 0 ]; then      #Do not rescale the first series
		rescale=`fslmeants -i ${basename}_mean`
	else
		scaleS=`fslmeants -i ${basename}_mean`
		${FSLDIR}/bin/fslmaths ${basename} -mul ${rescale} -div ${scaleS} ${basename}_new
		${FSLDIR}/bin/imrm ${basename}   #For the rest, replace the original dataseries with the rescaled one
		${FSLDIR}/bin/immv ${basename}_new ${basename}
	fi
	entry_cnt=$((${entry_cnt} + 1))
	${FSLDIR}/bin/imrm ${basename}_mean
done


################################################################################################
## b0 extraction and Creation of Index files for topup/eddy 
################################################################################################
echo "Extracting b0s from PE_Positive volumes and creating index and series files"
declare -i sesdimt #declare sesdimt as integer
tmp_indx=1
while read line ; do  #Read SeriesCorrespVolNum.txt file
	PCorVolNum[${tmp_indx}]=`echo $line | awk {'print $1'}`
	tmp_indx=$((${tmp_indx}+1))
done < ${rawdir}/${basePos}_SeriesCorrespVolNum.txt

scount=1
scount2=1
indcount=0
for entry in ${rawdir}/${basePos}*.nii*  #For each Pos volume
do
	#Extract b0s and create index file
	basename=`imglob ${entry}`
	Posbvals=`cat ${basename}.bval`
	count=0  #Within series counter
	count3=$((${b0dist} + 1))
	for i in ${Posbvals}
	do
		if [ $count -ge ${PCorVolNum[${scount2}]} ]; then
			tmp_ind=${indcount}
			if [ $[tmp_ind] -eq 0 ]; then
				tmp_ind=$((${indcount}+1))
			fi
			echo ${tmp_ind} >>${rawdir}/index.txt
		else  #Consider a b=0 a volume that has a bvalue<50 and is at least 50 volumes away from the previous
			if [ $i -lt ${b0maxbval} ] && [ ${count3} -gt ${b0dist} ]; then
				cnt=`$FSLDIR/bin/zeropad $indcount 4`
				echo "Extracting Pos Volume $count from ${entry} as a b=0. Measured b=$i" >>${rawdir}/extractedb0.txt
				$FSLDIR/bin/fslroi ${entry} ${rawdir}/Pos_b0_${cnt} ${count} 1
				if [ ${PEdir} -eq 1 ]; then    #RL/LR phase encoding
					echo 1 0 0 ${ro_time} >> ${rawdir}/acqparams.txt
				elif [ ${PEdir} -eq 2 ]; then  #AP/PA phase encoding
					echo 0 1 0 ${ro_time} >> ${rawdir}/acqparams.txt
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
	sesdimt=`${FSLDIR}/bin/fslval ${entry} dim4` #Number of datapoints per Pos series
	for (( j=0; j<${sesdimt}; j++ ))
	do
		echo ${scount} >> ${rawdir}/series_index.txt
	done
	scount=$((${scount} + 1))
	scount2=$((${scount2} + 1))
done

echo "Extracting b0s from PE_Negative volumes and creating index and series files"
tmp_indx=1
while read line ; do  #Read SeriesCorrespVolNum.txt file
	NCorVolNum[${tmp_indx}]=`echo $line | awk {'print $1'}`
	tmp_indx=$((${tmp_indx}+1))
done < ${rawdir}/${baseNeg}_SeriesCorrespVolNum.txt

Poscount=${indcount}
indcount=0
scount2=1
for entry in ${rawdir}/${baseNeg}*.nii* #For each Neg volume
do
	#Extract b0s and create index file
	basename=`imglob ${entry}`
	Negbvals=`cat ${basename}.bval`
	count=0
	count3=$((${b0dist} + 1))
	for i in ${Negbvals}
	do
		if [ $count -ge ${NCorVolNum[${scount2}]} ]; then
			tmp_ind=${indcount}
			if [ $[tmp_ind] -eq 0 ]; then
				tmp_ind=$((${indcount}+1))
			fi
			echo $((${tmp_ind} + ${Poscount})) >>${rawdir}/index.txt
		else #Consider a b=0 a volume that has a bvalue<50 and is at least 50 volumes away from the previous
			if [ $i -lt ${b0maxbval} ] && [ ${count3} -gt ${b0dist} ]; then
				cnt=`$FSLDIR/bin/zeropad $indcount 4`
				echo "Extracting Neg Volume $count from ${entry} as a b=0. Measured b=$i" >>${rawdir}/extractedb0.txt
				$FSLDIR/bin/fslroi ${entry} ${rawdir}/Neg_b0_${cnt} ${count} 1
				if [ ${PEdir} -eq 1 ]; then    #RL/LR phase encoding
					echo -1 0 0 ${ro_time} >> ${rawdir}/acqparams.txt
				elif [ ${PEdir} -eq 2 ]; then  #AP/PA phase encoding
					echo 0 -1 0 ${ro_time} >> ${rawdir}/acqparams.txt
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
	sesdimt=`${FSLDIR}/bin/fslval ${entry} dim4`
	for (( j=0; j<${sesdimt}; j++ ))
	do
		echo ${scount} >> ${rawdir}/series_index.txt #Create series file
	done
	scount=$((${scount} + 1))
	scount2=$((${scount2} + 1))
done

################################################################################################
## Merging Files and correct number of slices 
################################################################################################
echo "Merging Pos and Neg images"
${FSLDIR}/bin/fslmerge -t ${rawdir}/Pos_b0 `${FSLDIR}/bin/imglob ${rawdir}/Pos_b0_????.*`
${FSLDIR}/bin/fslmerge -t ${rawdir}/Neg_b0 `${FSLDIR}/bin/imglob ${rawdir}/Neg_b0_????.*`
${FSLDIR}/bin/imrm ${rawdir}/Pos_b0_????
${FSLDIR}/bin/imrm ${rawdir}/Neg_b0_????
${FSLDIR}/bin/fslmerge -t ${rawdir}/Pos `echo ${rawdir}/${basePos}*.nii*`
${FSLDIR}/bin/fslmerge -t ${rawdir}/Neg `echo ${rawdir}/${baseNeg}*.nii*`

paste `echo ${rawdir}/${basePos}*.bval` >${rawdir}/Pos.bval
paste `echo ${rawdir}/${basePos}*.bvec` >${rawdir}/Pos.bvec
paste `echo ${rawdir}/${baseNeg}*.bval` >${rawdir}/Neg.bval
paste `echo ${rawdir}/${baseNeg}*.bvec` >${rawdir}/Neg.bvec


dimz=`${FSLDIR}/bin/fslval ${rawdir}/Pos dim3`
if [ `isodd $dimz` -eq 1 ];then
	echo "Remove one slice from data to get even number of slices"
	${FSLDIR}/bin/fslroi ${rawdir}/Pos ${rawdir}/Posn 0 -1 0 -1 1 -1
	${FSLDIR}/bin/fslroi ${rawdir}/Neg ${rawdir}/Negn 0 -1 0 -1 1 -1
	${FSLDIR}/bin/fslroi ${rawdir}/Pos_b0 ${rawdir}/Pos_b0n 0 -1 0 -1 1 -1
	${FSLDIR}/bin/fslroi ${rawdir}/Neg_b0 ${rawdir}/Neg_b0n 0 -1 0 -1 1 -1
	${FSLDIR}/bin/imrm ${rawdir}/Pos
	${FSLDIR}/bin/imrm ${rawdir}/Neg
	${FSLDIR}/bin/imrm ${rawdir}/Pos_b0
	${FSLDIR}/bin/imrm ${rawdir}/Neg_b0
	${FSLDIR}/bin/immv ${rawdir}/Posn ${rawdir}/Pos
	${FSLDIR}/bin/immv ${rawdir}/Negn ${rawdir}/Neg
	${FSLDIR}/bin/immv ${rawdir}/Pos_b0n ${rawdir}/Pos_b0
	${FSLDIR}/bin/immv ${rawdir}/Neg_b0n ${rawdir}/Neg_b0
fi

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

echo -e "\n END: basic_preproc"


