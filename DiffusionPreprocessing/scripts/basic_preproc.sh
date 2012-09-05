#!/bin/bash

workingdir=$1
echo_spacing=$2
PEdir=$3
b0dist=$4
b0maxbval=$5

isodd(){
    echo "$(( $1 % 2 ))"
}

rawdir=${workingdir}/rawdata
topupdir=${workingdir}/topup
eddydir=${workingdir}/eddy
if [ ${PEdir} -eq 1 ]; then    #RL/LR phase encoding
    basePos="RL"
    baseNeg="LR"
elif [ ${PEdir} -eq 2 ]; then  #AP/PA phase encoding
    basePos="AP"
    baseNeg="PA"
fi


#Compute Total_readout in secs with up to 6 decimal places
any=`ls ${rawdir}/*${basePos}*.nii* |head -n 1`
if [ ${PEdir} -eq 1 ]; then    #RL/LR phase encoding
    dimP=`${FSLDIR}/bin/fslval ${any} dim1`
elif [ ${PEdir} -eq 2 ]; then  #AP/PA phase encoding
    dimP=`${FSLDIR}/bin/fslval ${any} dim2`
fi
nPEsteps=$(($dimP - 1))
#Total_readout=Echo_spacing*(#of_PE_steps-1)
ro_time=`echo "${echo_spacing} * ${nPEsteps}" | bc -l`
ro_time=`echo "scale=6; ${ro_time} / 1000" | bc -l`
echo "Total readout time is $ro_time secs"


echo "Extracting b0s from PE_Positive volumes and creating index and session files"
declare -i sesdimt #declare sesdimt as integer
scount=1
indcount=0
for entry in ${rawdir}/*${basePos}*.nii*  #For each Pos volume
do
  #Create session file
  sesdimt=`${FSLDIR}/bin/fslval ${entry} dim4` #Number of datapoints per Pos session
  for (( j=0; j<${sesdimt}; j++ ))  
  do
      echo ${scount} >> ${rawdir}/session_index.txt
  done
  scount=$((${scount} + 1))

  #Extract b0s and create index file
  basename=`imglob ${entry}`
  Posbvals=`cat ${basename}.bval`
  count=0  #Within session counter
  count3=$((${b0dist} + 1))
  for i in ${Posbvals} 
  do  #Consider a b=0 a volume that has a bvalue<50 and is at least 50 volumes away from the previous
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
    count=$((${count} + 1))
  done

done

echo "Extracting b0s from PE_Negative volumes and creating index and session files"
Poscount=${indcount}
indcount=0
for entry in ${rawdir}/*${baseNeg}*.nii* #For each Neg volume
do
  #Create session file
  sesdimt=`${FSLDIR}/bin/fslval ${entry} dim4`
  for (( j=0; j<${sesdimt}; j++ ))
  do
      echo ${scount} >> ${rawdir}/session_index.txt #Create session file
  done
  scount=$((${scount} + 1))

  #Extract b0s and create index file
  basename=`imglob ${entry}`
  Negbvals=`cat ${basename}.bval`
  count=0
  count3=$((${b0dist} + 1))
  for i in ${Negbvals}
  do #Consider a b=0 a volume that has a bvalue<50 and is at least 50 volumes away from the previous
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
    count=$((${count} + 1))
  done
done


echo "Merging Pos and Neg images"
${FSLDIR}/bin/fslmerge -t ${rawdir}/Pos_b0 `${FSLDIR}/bin/imglob ${rawdir}/Pos_b0_????.*`
${FSLDIR}/bin/fslmerge -t ${rawdir}/Neg_b0 `${FSLDIR}/bin/imglob ${rawdir}/Neg_b0_????.*`
${FSLDIR}/bin/imrm ${rawdir}/Pos_b0_????
${FSLDIR}/bin/imrm ${rawdir}/Neg_b0_????
${FSLDIR}/bin/fslmerge -t ${rawdir}/Pos `echo ${rawdir}/*${basePos}*.nii*`
${FSLDIR}/bin/fslmerge -t ${rawdir}/Neg `echo ${rawdir}/*${baseNeg}*.nii*`

paste `echo ${rawdir}/*${basePos}*.bval` >${rawdir}/Pos.bval
paste `echo ${rawdir}/*${basePos}*.bvec` >${rawdir}/Pos.bvec
paste `echo ${rawdir}/*${baseNeg}*.bval` >${rawdir}/Neg.bval
paste `echo ${rawdir}/*${baseNeg}*.bvec` >${rawdir}/Neg.bvec


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


echo "Move files to appopriate directories"
mv ${rawdir}/extractedb0.txt ${topupdir}
mv ${rawdir}/acqparams.txt ${topupdir}
${FSLDIR}/bin/immv ${rawdir}/Pos_Neg_b0 ${topupdir}
${FSLDIR}/bin/immv ${rawdir}/Pos_b0 ${topupdir}
${FSLDIR}/bin/immv ${rawdir}/Neg_b0 ${topupdir}


cp ${topupdir}/acqparams.txt ${eddydir}
mv ${rawdir}/index.txt ${eddydir}
mv ${rawdir}/session_index.txt ${eddydir}
${FSLDIR}/bin/immv ${rawdir}/Pos_Neg ${eddydir}
mv ${rawdir}/Pos_Neg.bvals ${eddydir}
mv ${rawdir}/Pos_Neg.bvecs ${eddydir}
mv ${rawdir}/Pos.bv?? ${eddydir}
mv ${rawdir}/Neg.bv?? ${eddydir}





