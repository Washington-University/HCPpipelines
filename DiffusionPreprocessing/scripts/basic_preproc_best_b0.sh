#!/bin/bash
source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@" # Debugging functions; also sources log.shlib
scriptName="basic_preproc_best_b0.sh"
echo -e "\n START: ${scriptName}"

workingdir=$1
ro_time=$2  #in sec
PEdir=$3
b0dist=$4
b0maxbval=$5

echo "${scriptName}: Input Parameter: workingdir: ${workingdir}"
echo "${scriptName}: Input Parameter: ro_time: ${ro_time}"  # Readout time in ms
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


################################################################################################
## Identifying the best b0's to use in topup
################################################################################################
# This code in this section was adapted from a script written for the developing HCP (https://git.fmrib.ox.ac.uk/matteob/dHCP_neo_dMRI_pipeline_release/blob/master/utils/pickBestB0s.sh)
# The original script was released under the Apache license 2.0 (https://git.fmrib.ox.ac.uk/matteob/dHCP_neo_dMRI_pipeline_release/blob/master/LICENSE)

# Merge b0's for both phase encoding directions
for pe_sign in ${basePos} ${baseNeg} ; do
  merge_command=("${FSLDIR}/bin/fslmerge" -t "${rawdir}/all_${pe_sign}_b0s")
  for entry in ${rawdir}/${pe_sign}_[0-9]*.nii*
  do
    basename=`imglob ${entry}`
    ${FSLDIR}/bin/select_dwi_vols ${basename} ${basename}.bval ${basename}_b0s 0
    merge_command+=("${basename}_b0s")
  done
  echo about to "${merge_command[@]}"
  "${merge_command[@]}"
  for entry in ${rawdir}/${pe_sign}_[0-9]*_b0s.nii*
  do
      ${FSLDIR}/bin/imrm ${entry}
  done
done


for pe_sign in ${basePos} ${baseNeg} ; do
  echo "Identifying best b0's for ${pe_sign} phase encoding"
  if [ ${pe_sign} = ${basePos} ] ; then
    pe_other=${baseNeg}
  else
    pe_other=${basePos}
  fi
  select_b0_dir=${rawdir}/select_b0_${pe_sign}
  mkdir -p ${select_b0_dir}

  N_b0s=`${FSLDIR}/bin/fslval ${rawdir}/all_${pe_sign}_b0s dim4`

  # if there are less than 5 B0's for a specific phase encoding use topup to find the best ones
  # otherwise simply register the B0's of the same phase encoding to each other
  if [[ ${N_b0s} -lt 5 ]] ; then
    N_other=`${FSLDIR}/bin/fslval ${rawdir}/all_${pe_other}_b0s dim4`
    if [[ ${N_other} -gt 4 ]] ; then N_other=4 ; fi
    echo "Score all ${N_b0s} ${pe_sign} B0's based on alignment with mean B0 after topup with ${N_other} ${pe_other} B0's"

    # Select sub-set of other B0's to run topup on
    ${FSLDIR}/bin/fslroi ${rawdir}/all_${pe_other}_b0s ${select_b0_dir}/opposite_b0s 0 ${N_other}

    # Merge all b0's to do a rough initial aligment using topup
    ${FSLDIR}/bin/fslmerge -t ${select_b0_dir}/all_b0s ${rawdir}/all_${pe_sign}_b0s ${select_b0_dir}/opposite_b0s

    # Create the acqparams file for the initial alignment
    for idx in $(seq 1 ${N_b0s}) ; do
        if [ ${PEdir} -eq 1 ]; then    #RL/LR phase encoding
          echo 1 0 0 ${ro_time} >> ${select_b0_dir}/acqparams.txt
        elif [ ${PEdir} -eq 2 ]; then  #AP/PA phase encoding
          echo 0 1 0 ${ro_time} >> ${select_b0_dir}/acqparams.txt
        fi
    done

    for idx in $(seq 1 ${N_other}) ; do
        if [ ${PEdir} -eq 1 ]; then    #RL/LR phase encoding
          echo -1 0 0 ${ro_time} >> ${select_b0_dir}/acqparams.txt
        elif [ ${PEdir} -eq 2 ]; then  #AP/PA phase encoding
          echo 0 -1 0 ${ro_time} >> ${select_b0_dir}/acqparams.txt
        fi
    done

    dimz=`${FSLDIR}/bin/fslval ${select_b0_dir}/all_b0s dim3`
    if [ `isodd $dimz` -eq 1 ];then
        ${FSLDIR}/bin/fslroi ${select_b0_dir}/all_b0s ${select_b0_dir}/all_b0s_even 0 -1 0 -1 1 -1
    else
        ${FSLDIR}/bin/imcp ${select_b0_dir}/all_b0s ${select_b0_dir}/all_b0s_even
    fi
    # run topup to roughly align the b0's
    configdir=${HCPPIPEDIR_Config}
    topup_config_file=${configdir}/best_b0.cnf
    ${FSLDIR}/bin/topup --imain=${select_b0_dir}/all_b0s_even \
       --datain=${select_b0_dir}/acqparams.txt \
       --config=${topup_config_file} \
       --fout=${select_b0_dir}/fieldmap \
       --iout=${select_b0_dir}/topup_b0s \
       --out=${select_b0_dir}/topup_results \
       -v

    # compute squared residual from the mean b0
    ${FSLDIR}/bin/fslmaths ${select_b0_dir}/topup_b0s -Tmean ${select_b0_dir}/topup_b0s_avg
    for ((i=1;i<=3;i++));
    do
      ${FSLDIR}/bin/fslmaths ${select_b0_dir}/topup_b0s -sub ${select_b0_dir}/topup_b0s_avg -sqr ${select_b0_dir}/topup_b0s_res

      # Get brain mask from averaged results
      ${FSLDIR}/bin/bet ${select_b0_dir}/topup_b0s_avg.nii.gz ${select_b0_dir}/nodif_brain -m -R -f 0.3

      # compute average squared residual over brain mask
      scores=( `${FSLDIR}/bin/fslstats -t ${select_b0_dir}/topup_b0s_res -k ${select_b0_dir}/nodif_brain_mask -M` )
      scores_str="${scores[@]}"

      # Recomputes the average using only the b0's with scores below (median(score) + 2 * mad(score)),
      # where mad is the median absolute deviation.
      idx=`fslpython -c "from numpy import median, where; sc = [float(s) for s in '${scores_str}'.split()]; print(','.join(str(idx) for idx in where(sc < median(abs(sc - median(sc)) * 2 + median(sc)))[0]))"`
      ${FSLDIR}/bin/fslselectvols -i ${select_b0_dir}/topup_b0s -o ${select_b0_dir}/topup_b0s_avg --vols=${idx} -m
    done

    # compute offsets for only the polarity of interest
    ${FSLDIR}/bin/fslmaths ${select_b0_dir}/topup_b0s -sub ${select_b0_dir}/topup_b0s_avg -sqr ${select_b0_dir}/topup_b0s_res
    ${FSLDIR}/bin/fslroi ${select_b0_dir}/topup_b0s_res ${select_b0_dir}/topup_b0s_res_${pe_sign} 0 ${N_b0s}

    # Get brain mask from averaged results
    ${FSLDIR}/bin/bet ${select_b0_dir}/topup_b0s_avg.nii.gz ${select_b0_dir}/nodif_brain -m -R -f 0.3

    # compute average squared residual over brain mask
    scores=( `${FSLDIR}/bin/fslstats -t ${select_b0_dir}/topup_b0s_res_${pe_sign} -k ${select_b0_dir}/nodif_brain_mask -M` )
  else
    echo "Score all ${pe_sign} B0's based on similarity with the mean ${pe_sign} B0"
    echo ${FSLDIR}/bin/mcflirt -in ${rawdir}/all_${pe_sign}_b0s -out ${select_b0_dir}/all_b0s_mcf
    ${FSLDIR}/bin/mcflirt -in ${rawdir}/all_${pe_sign}_b0s -out ${select_b0_dir}/all_b0s_mcf
    ${FSLDIR}/bin/fslmaths ${select_b0_dir}/all_b0s_mcf -Tmean ${select_b0_dir}/all_b0s_mcf_avg
    for ((i=1;i<=3;i++));
    do
      ${FSLDIR}/bin/fslmaths ${select_b0_dir}/all_b0s_mcf -sub ${select_b0_dir}/all_b0s_mcf_avg -sqr ${select_b0_dir}/all_b0s_mcf_res

      # Get brain mask from averaged results
      ${FSLDIR}/bin/bet ${select_b0_dir}/all_b0s_mcf_avg.nii.gz ${select_b0_dir}/nodif_brain -m -R -f 0.3
      scores=( `${FSLDIR}/bin/fslstats -t ${select_b0_dir}/all_b0s_mcf_res -k ${select_b0_dir}/nodif_brain_mask -M` )
      scores_str="${scores[@]}"

      # Recomputes the average using only the b0's with scores below (median(score) + 2 * mad(score)),
      # where mad is the median absolute deviation.
      idx=`fslpython -c "from numpy import median, where; sc = [float(s) for s in '${scores_str}'.split()]; print(','.join(str(idx) for idx in where(sc < median(abs(sc - median(sc)) * 2 + median(sc)))[0]))"`
      ${FSLDIR}/bin/fslselectvols -i ${select_b0_dir}/all_b0s_mcf -o ${select_b0_dir}/all_b0s_mcf_avg --vols=${idx} -m
    done
  fi
  echo "b0 scores for ${pe_sign}: " "${scores[@]}"

  printf "%s\n" "${scores[@]}" > ${select_b0_dir}/scores.txt
done


################################################################################################
## b0 extraction and Creation of acquisition paramater file for topup/eddy
################################################################################################
echo "Find the best B0 in the positive and negative volumes"

if [[ -f ${rawdir}/index_best_b0s.txt ]] ; then rm ${rawdir}/index_best_b0s.txt ; fi

for pe_sign in ${basePos} ${baseNeg} ; do
  # find index of minimum score
  scores=()
  while read line; do scores+=("$line"); done < ${rawdir}/select_b0_${pe_sign}/scores.txt
  min_idx=0
  for idx in $(seq 0 $((`${FSLDIR}/bin/fslval ${rawdir}/all_${pe_sign}_b0s dim4` - 1))) ; do
    if [ $(echo "${scores[${idx}]} < ${scores[${min_idx}]}" | bc -l) -eq 1 ] ; then min_idx=$idx ; fi
  done
  echo "Selecting ${pe_sign} B0 with index ${min_idx}" 
  echo "${pe_sign} ${min_idx}" >> ${rawdir}/index_best_b0s.txt
  ${FSLDIR}/bin/fslroi ${rawdir}/all_${pe_sign}_b0s ${rawdir}/best_${pe_sign}_b0 ${min_idx} 1
done

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

paste -d' ' `echo ${rawdir}/${basePos}*.bval` >${rawdir}/Pos.bval
paste -d' ' `echo ${rawdir}/${basePos}*.bvec` >${rawdir}/Pos.bvec
paste -d' ' `echo ${rawdir}/${baseNeg}*.bval` >${rawdir}/Neg.bval
paste -d' ' `echo ${rawdir}/${baseNeg}*.bvec` >${rawdir}/Neg.bvec

# start index file with a 1 to indicate the reference B0 image
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
	${FSLDIR}/bin/fslroi ${rawdir}/best_Pos_b0 ${rawdir}/best_Pos_b0n 0 -1 0 -1 1 -1
	${FSLDIR}/bin/fslroi ${rawdir}/best_Neg_b0 ${rawdir}/best_Neg_b0n 0 -1 0 -1 1 -1
	${FSLDIR}/bin/imrm ${rawdir}/Pos
	${FSLDIR}/bin/imrm ${rawdir}/Neg
	${FSLDIR}/bin/imrm ${rawdir}/best_Pos_b0
	${FSLDIR}/bin/imrm ${rawdir}/best_Neg_b0
	${FSLDIR}/bin/immv ${rawdir}/Posn ${rawdir}/Pos
	${FSLDIR}/bin/immv ${rawdir}/Negn ${rawdir}/Neg
	${FSLDIR}/bin/immv ${rawdir}/best_Pos_b0n ${rawdir}/best_Pos_b0
	${FSLDIR}/bin/immv ${rawdir}/best_Neg_b0n ${rawdir}/best_Neg_b0
fi

echo "Perform final merge"
${FSLDIR}/bin/fslmerge -t ${rawdir}/Pos_Neg_b0 ${rawdir}/best_Pos_b0 ${rawdir}/best_Neg_b0
# include Pos_b0 as the first volume of Pos_Neg, so that eddy will use it as reference
${FSLDIR}/bin/fslmerge -t ${rawdir}/Pos_Neg ${rawdir}/best_Pos_b0 ${rawdir}/Pos ${rawdir}/Neg
echo 0 `paste -d' ' ${rawdir}/Pos.bval ${rawdir}/Neg.bval` >${rawdir}/Pos_Neg.bvals
echo 1. > ${rawdir}/zero.bvecs
echo 0. >> ${rawdir}/zero.bvecs
echo 0. >> ${rawdir}/zero.bvecs
paste -d' ' ${rawdir}/zero.bvecs ${rawdir}/Pos.bvec ${rawdir}/Neg.bvec >${rawdir}/Pos_Neg.bvecs
rm ${rawdir}/zero.bvecs

${FSLDIR}/bin/imrm ${rawdir}/Pos
${FSLDIR}/bin/imrm ${rawdir}/Neg


################################################################################################
## Move files to appropriate directories 
################################################################################################
echo "Move files to appropriate directories"
mv ${rawdir}/index_best_b0s.txt ${topupdir}
mv ${rawdir}/acqparams.txt ${topupdir}
${FSLDIR}/bin/immv ${rawdir}/Pos_Neg_b0 ${topupdir}
${FSLDIR}/bin/immv ${rawdir}/best_Pos_b0 ${topupdir}/Pos_b0
${FSLDIR}/bin/immv ${rawdir}/best_Neg_b0 ${topupdir}/Neg_b0

cp ${topupdir}/acqparams.txt ${eddydir}
mv ${rawdir}/index.txt ${eddydir}
${FSLDIR}/bin/immv ${rawdir}/Pos_Neg ${eddydir}
mv ${rawdir}/Pos_Neg.bvals ${eddydir}
mv ${rawdir}/Pos_Neg.bvecs ${eddydir}
mv ${rawdir}/Pos.bv?? ${eddydir}
mv ${rawdir}/Neg.bv?? ${eddydir}

echo -e "\n END: basic_preproc"


