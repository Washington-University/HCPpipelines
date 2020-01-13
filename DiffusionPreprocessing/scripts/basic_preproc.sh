short.q#!/bin/bash
source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@" # Debugging functions; also sources log.shlib
scriptName="basic_preproc.sh"
echo -e "\n START: ${scriptName}"

workingdir=$1
echo_spacing=$2  #in msec
PEdir=$3
b0dist=$4
b0maxbval=$5

echo "${scriptName}: Input Parameter: workingdir: ${workingdir}"
echo "${scriptName}: Input Parameter: echo_spacing: ${echo_spacing}"  # *Effective* Echo Spacing, in msec
echo "${scriptName}: Input Parameter: PEdir: ${PEdir}"
echo "${scriptName}: Input Parameter: b0dist: ${b0dist}"
echo "${scriptName}: Input Parameter: b0maxbval: ${b0maxbval}"

isodd(){
	echo "$(( $1 % 2 ))"
}

rawdir=${workingdir}/rawdata
topupdir=${workingdir}/topup
eddydir=${workingdir}/eddy

if [[ ${PEdir} -ne 1 && ${PEdir} -ne 2 ]] ; then
	echo -e "\n ${scriptName}: ERROR: basic_preproc: Unrecognized PEdir: ${PEdir}"
	exit 1
fi

# Use same convention for basePos and baseNeg names as in DiffPreprocPipeline_PreEddy.sh
basePos="Pos"
baseNeg="Neg"

#Compute Total_readout in secs with up to 6 decimal places
any=`ls ${rawdir}/${basePos}*.nii* | head -n 1`
if [ ${PEdir} -eq 1 ]; then    #RL/LR phase encoding
	dimP=`${FSLDIR}/bin/fslval ${any} dim1`
elif [ ${PEdir} -eq 2 ]; then  #PA/AP phase encoding
	dimP=`${FSLDIR}/bin/fslval ${any} dim2`
fi
dimPminus1=$(($dimP - 1))
#Total_readout=EffectiveEchoSpacing*(ReconMatrixPE-1)
# Factors such as in-plane acceleration, phase oversampling, phase resolution, phase field-of-view, and interpolation
# must already be accounted for as part of the "EffectiveEchoSpacing"
ro_time=`echo "${echo_spacing} * ${dimPminus1}" | bc -l`
ro_time=`echo "scale=6; ${ro_time} / 1000" | bc -l`  # Convert from ms to sec
echo "${scriptName}: Total readout time is $ro_time secs"


################################################################################################
## Intensity Normalisation across Series 
################################################################################################
echo "${scriptName}: Rescaling series to ensure consistency across baseline intensities"
entry_cnt=0
for entry in ${rawdir}/${basePos}_[0-9]*.nii* ${rawdir}/${baseNeg}_[0-9]*.nii*  #For each series, get the mean b0 and rescale to match the first series baseline
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
## Identifying the best b0's to use in topup
################################################################################################
# This code in this section was adapted from a script written for the developing HCP (https://git.fmrib.ox.ac.uk/matteob/dHCP_neo_dMRI_pipeline_release/blob/master/utils/pickBestB0s.sh)
# The original script was released under the Apache license 2.0 (https://git.fmrib.ox.ac.uk/matteob/dHCP_neo_dMRI_pipeline_release/blob/master/LICENSE)

echo "Score all B0's based on alignment with mean B0 after topup"

select_b0_dir=${rawdir}/select_b0
mkdir -p ${select_b0_dir}

# Merge all b0's to do a rough initial aligment using topup
merge_command=("${FSLDIR}/bin/fslmerge" -t "${select_b0_dir}/all_b0s")
for entry in ${rawdir}/${basePos}_[0-9]*.nii* ${rawdir}/${baseNeg}_[0-9]*.nii*
do
	basename=`imglob ${entry}`
	${FSLDIR}/bin/select_dwi_vols ${basename} ${basename}.bval ${basename}_b0s 0
    merge_command+=("${basename}_b0s")
done
"${merge_command[@]}"

# Create the acqparams file for the initial alignment
for entry in ${rawdir}/${basePos}_[0-9]*_b0s.nii*
do
	basename_b0s=`imglob ${entry}`
  for idx in $(seq 1 `${FSLDIR}/bin/fslval ${basename_b0s} dim4`) ; do
      if [ ${PEdir} -eq 1 ]; then    #RL/LR phase encoding
        echo 1 0 0 ${ro_time} >> ${select_b0_dir}/acqparams.txt
      elif [ ${PEdir} -eq 2 ]; then  #AP/PA phase encoding
        echo 0 1 0 ${ro_time} >> ${select_b0_dir}/acqparams.txt
      fi
  done
done

for entry in ${rawdir}/${baseNeg}_[0-9]*_b0s.nii*
do
	basename_b0s=`imglob ${entry}`
    for idx in $(seq 1 `${FSLDIR}/bin/fslval ${basename_b0s} dim4`) ; do
      if [ ${PEdir} -eq 1 ]; then    #RL/LR phase encoding
        echo -1 0 0 ${ro_time} >> ${select_b0_dir}/acqparams.txt
      elif [ ${PEdir} -eq 2 ]; then  #AP/PA phase encoding
        echo 0 -1 0 ${ro_time} >> ${select_b0_dir}/acqparams.txt
      fi
  done
done

# run topup to roughly align the b0's
configdir=${HCPPIPEDIR_Config}
topup_config_file=${configdir}/best_b0.cnf
${FSLDIR}/bin/topup --imain=${select_b0_dir}/all_b0s \
	 --datain=${select_b0_dir}/acqparams.txt \
	 --config=${topup_config_file} \
	 --fout=${select_b0_dir}/fieldmap \
	 --iout=${select_b0_dir}/topup_b0s \
	 --out=${select_b0_dir}/topup_results \
	 -v

# compute squared residual from the mean b0
${FSLDIR}/bin/fslmaths ${select_b0_dir}/topup_b0s -Tmean ${select_b0_dir}/topup_b0s_avg
${FSLDIR}/bin/fslmaths ${select_b0_dir}/topup_b0s -sub ${select_b0_dir}/topup_b0s_avg -sqr ${select_b0_dir}/topup_b0s_res

# Get brain mask from averaged results
${FSLDIR}/bin/bet ${select_b0_dir}/topup_b0s_avg.nii.gz ${select_b0_dir}/nodif_brain -m -R -f 0.3

# compute average squared residual over brain mask
scores=( `${FSLDIR}/bin/fslstats -t ${select_b0_dir}/topup_b0s_res -k ${select_b0_dir}/nodif_brain_mask -M` )
echo "b0 scores: " ${scores[@]}

# store scores for each series
idx_all_b0s=1
for entry in ${rawdir}/${basePos}_[0-9]*.nii* ${rawdir}/${baseNeg}_[0-9]*.nii*
do
	basename=`imglob ${entry}`
	rm ${basename}_scores
    for idx in $(seq 1 `${FSLDIR}/bin/fslval ${basename}_b0s dim4`) ; do
    echo scores[${idx_all_b0s}] >> ${basename}_scores
    idx_all_b0s=$((${idx_all_b0s}+1))
  done
done


################################################################################################
## b0 extraction and Creation of acquisition paramater file for topup/eddy
################################################################################################
echo "Find the best B0 in the positive and negative volumes"
idx_all_b0s=1

# argmin for positive volumes
pos_idx=idx_all_b0s
min_score=scores[${idx_all_b0s}]
for entry in ${rawdir}/${basePos}_[0-9]*.nii*
do
	basename=`imglob ${entry}`
    for idx in $(seq 1 `${FSLDIR}/bin/fslval ${basename}_b0s dim4`) ; do
    if [[ scores[${idx_all_b0s}] -lt scores[${pos_idx}] ]] ; then
      pos_idx=idx_all_b0s
    fi
    idx_all_b0s=$((${idx_all_b0s}+1))
  done
done

# argmin for negative volumes
npos=idx_all_b0s
neg_idx=idx_all_b0s
min_score=scores[${idx_all_b0s}]
for entry in ${rawdir}/${basePos}_[0-9]*.nii*
do
	basename=`imglob ${entry}`
    for idx in $(seq 1 `${FSLDIR}/bin/fslval ${basename}_b0s dim4`) ; do
    if [[ scores[${idx_all_b0s}] -lt scores[${neg_idx}] ]] ; then
      neg_idx=idx_all_b0s
    fi
    idx_all_b0s=$((${idx_all_b0s}+1))
  done
done

# merge selected b0's
echo ${pos_idx} > ${select_b0_dir}/index_selected_b0s.txt
echo ${neg_idx} >> ${select_b0_dir}/index_selected_b0s.txt
fslroi ${select_b0_dir}/topup_b0s ${select_b0}/Pos_b0 ${pos_idx} 1
fslroi ${select_b0_dir}/topup_b0s ${select_b0}/Neg_b0 ${neg_idx} 1

# producing acqparams.txt
if [ ${PEdir} -eq 1 ]; then    #RL/LR phase encoding
  echo 1 0 0 ${ro_time} > ${rawdir}/acqparams.txt
  echo -1 0 0 ${ro_time} >> ${rawdir}/acqparams.txt
elif [ ${PEdir} -eq 2 ]; then  #AP/PA phase encoding
  echo 0 1 0 ${ro_time} > ${rawdir}/acqparams.txt
  echo 0 -1 0 ${ro_time} >> ${rawdir}/acqparams.txt
fi

################################################################################################
## Merging Files and correct number of slices 
################################################################################################
echo "Merging Pos and Neg images"
${FSLDIR}/bin/fslmerge -t ${rawdir}/Pos `echo ${rawdir}/${basePos}_[0-9]*.nii*`
${FSLDIR}/bin/fslmerge -t ${rawdir}/Neg `echo ${rawdir}/${baseNeg}_[0-9]*.nii*`

paste `echo ${rawdir}/${basePos}*.bval` >${rawdir}/Pos.bval
paste `echo ${rawdir}/${basePos}*.bvec` >${rawdir}/Pos.bvec
paste `echo ${rawdir}/${baseNeg}*.bval` >${rawdir}/Neg.bval
paste `echo ${rawdir}/${baseNeg}*.bvec` >${rawdir}/Neg.bvec

# start with reference Pos_b0 volume
echo 1 > ${rawdir}/index.txt
for idx in $(seq 1 `${FSLDIR}/bin/fslval ${rawdir}/Pos dim4`) ; do
  echo 1 >> ${rawdir}/index.txt
done
for idx in $(seq 1 `${FSLDIR}/bin/fslval ${rawdir}/Neg dim4`) ; do
  echo 2 >> ${rawdir}/index.txt
done

dimz=`${FSLDIR}/bin/fslval ${rawdir}/Pos dim3`
if [ `isodd $dimz` -eq 1 ];then
	echo "Remove one slice from data to get even number of slices"
	${FSLDIR}/bin/fslroi ${rawdir}/Pos ${rawdir}/Posn 0 -1 0 -1 1 -1
	${FSLDIR}/bin/fslroi ${rawdir}/Neg ${rawdir}/Negn 0 -1 0 -1 1 -1
	${FSLDIR}/bin/fslroi ${select_b0_dir}/Pos_b0 ${select_b0_dir}/Pos_b0n 0 -1 0 -1 1 -1
	${FSLDIR}/bin/fslroi ${select_b0_dir}/Neg_b0 ${select_b0_dir}/Neg_b0n 0 -1 0 -1 1 -1
	${FSLDIR}/bin/imrm ${rawdir}/Pos
	${FSLDIR}/bin/imrm ${rawdir}/Neg
	${FSLDIR}/bin/imrm ${select_b0_dir}/Pos_b0
	${FSLDIR}/bin/imrm ${select_b0_dir}/Neg_b0
	${FSLDIR}/bin/immv ${rawdir}/Posn ${rawdir}/Pos
	${FSLDIR}/bin/immv ${rawdir}/Negn ${rawdir}/Neg
	${FSLDIR}/bin/immv ${select_b0_dir}/Pos_b0n ${select_b0_dir}/Pos_b0
	${FSLDIR}/bin/immv ${select_b0_dir}/Neg_b0n ${select_b0_dir}/Neg_b0
fi

echo "Perform final merge"
${FSLDIR}/bin/fslmerge -t ${select_b0_dir}/Pos_Neg_b0 ${select_b0_dir}/Pos_b0 ${select_b0_dir}/Neg_b0
# include Pos_b0 as the first volume of Pos_Neg, so that eddy will use it as reference
${FSLDIR}/bin/fslmerge -t ${rawdir}/Pos_Neg ${select_b0_dir}/Pos_b0 ${rawdir}/Pos ${rawdir}/Neg
echo 0 >${rawdir}/Pos_Neg.bvals
paste ${rawdir}/Pos_Neg.bvals ${rawdir}/Pos.bval ${rawdir}/Neg.bval >${rawdir}/Pos_Neg.bvals
echo 0 >${rawdir}/Pos_Neg.bvecs
echo 0 >${rawdir}/Pos_Neg.bvecs
echo 0 >${rawdir}/Pos_Neg.bvecs
paste ${rawdir}/Pos_Neg.bvecs ${rawdir}/Pos.bvec ${rawdir}/Neg.bvec >${rawdir}/Pos_Neg.bvecs

${FSLDIR}/bin/imrm ${rawdir}/Pos
${FSLDIR}/bin/imrm ${rawdir}/Neg


################################################################################################
## Move files to appropriate directories 
################################################################################################
echo "Move files to appropriate directories"
mv ${rawdir}/extractedb0.txt ${topupdir}
mv ${rawdir}/acqparams.txt ${topupdir}
${FSLDIR}/bin/immv ${select_b0_dir}/Pos_Neg_b0 ${topupdir}
${FSLDIR}/bin/immv ${select_b0_dir}/Pos_b0 ${topupdir}
${FSLDIR}/bin/immv ${select_b0_dir}/Neg_b0 ${topupdir}

cp ${topupdir}/acqparams.txt ${eddydir}
mv ${rawdir}/index.txt ${eddydir}
${FSLDIR}/bin/immv ${rawdir}/Pos_Neg ${eddydir}
mv ${rawdir}/Pos_Neg.bvals ${eddydir}
mv ${rawdir}/Pos_Neg.bvecs ${eddydir}
mv ${rawdir}/Pos.bv?? ${eddydir}
mv ${rawdir}/Neg.bv?? ${eddydir}

echo -e "\n END: basic_preproc"


