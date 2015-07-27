#!/bin/bash
set -e
echo -e "\n START: eddy_postproc"

#Hard-Coded filename. Flag from eddy to indicate that the jac method has been used for resampling
EddyJacFlag="JacobianResampling" 

workingdir=$1
GdCoeffs=$2  #Coefficients for gradient nonlinearity distortion correction. If "NONE" this corrections is turned off
CombineDataFlag=$3   #2 for including in the ouput all volumes uncombined (i.e. output file of eddy)
                     #1 for including in the ouput and combine only volumes where both LR/RL (or AP/PA) pairs have been acquired
                     #0 As 1, but also include uncombined single volumes"

configdir=${HCPPIPEDIR_Config}
globalscriptsdir=${HCPPIPEDIR_Global}

eddydir=${workingdir}/eddy
datadir=${workingdir}/data

#Prepare for next eddy Release
#if [ ! -e ${eddydir}/${EddyJacFlag} ]; then 
#    echo "LSR resampling has been used. Eddy Output has already been combined."
#    cp ${eddydir}/Pos.bval ${datadir}/bvals
#    cp ${eddydir}/Pos.bvec ${datadir}/bvecs
#    $FSLDIR/bin/imcp ${eddydir}/eddy_unwarped_images ${datadir}/data
#else
    if [ ${CombineDataFlag} -eq 2 ]; then
	${FSLDIR}/bin/imcp  ${eddydir}/eddy_unwarped_images ${datadir}/data
	cp ${eddydir}/Pos_Neg.bvals ${datadir}/bvals
	cp ${eddydir}/Pos_Neg.bvecs ${datadir}/bvecs
    else
	echo "JAC resampling has been used. Eddy Output is now combined."
	PosVols=`wc ${eddydir}/Pos.bval | awk {'print $2'}`
	NegVols=`wc ${eddydir}/Neg.bval | awk {'print $2'}`    #Split Pos and Neg Volumes
	${FSLDIR}/bin/fslroi ${eddydir}/eddy_unwarped_images ${eddydir}/eddy_unwarped_Pos 0 ${PosVols}
	${FSLDIR}/bin/fslroi ${eddydir}/eddy_unwarped_images ${eddydir}/eddy_unwarped_Neg ${PosVols} ${NegVols}
	${FSLDIR}/bin/eddy_combine ${eddydir}/eddy_unwarped_Pos ${eddydir}/Pos.bval ${eddydir}/Pos.bvec ${eddydir}/Pos_SeriesVolNum.txt \
                                        ${eddydir}/eddy_unwarped_Neg ${eddydir}/Neg.bval ${eddydir}/Neg.bvec ${eddydir}/Neg_SeriesVolNum.txt ${datadir} ${CombineDataFlag}

	${FSLDIR}/bin/imrm ${eddydir}/eddy_unwarped_Pos
	${FSLDIR}/bin/imrm ${eddydir}/eddy_unwarped_Neg
	#rm ${eddydir}/Pos.bv*
	#rm ${eddydir}/Neg.bv*
    fi
#fi


if [ ! $GdCoeffs = "NONE" ] ; then
    echo "Correcting for gradient nonlinearities"
    ${FSLDIR}/bin/immv ${datadir}/data ${datadir}/data_warped
    ${globalscriptsdir}/GradientDistortionUnwarp.sh --workingdir="${datadir}" --coeffs="${GdCoeffs}" --in="${datadir}/data_warped" --out="${datadir}/data" --owarp="${datadir}/fullWarp"

    echo "Computing gradient coil tensor to correct for gradient nonlinearities"
    ${FSLDIR}/bin/calc_grad_perc_dev --fullwarp=${datadir}/fullWarp -o ${datadir}/grad_dev
    ${FSLDIR}/bin/fslmerge -t ${datadir}/grad_dev ${datadir}/grad_dev_x ${datadir}/grad_dev_y ${datadir}/grad_dev_z
    ${FSLDIR}/bin/fslmaths ${datadir}/grad_dev -div 100 ${datadir}/grad_dev #Convert from % deviation to absolute
    ${FSLDIR}/bin/imrm ${datadir}/grad_dev_?
    ${FSLDIR}/bin/imrm ${datadir}/trilinear
    ${FSLDIR}/bin/imrm ${datadir}/data_warped_vol1
    
    #Keep the original warped data and warp fields
    mkdir -p ${datadir}/warped
    ${FSLDIR}/bin/immv ${datadir}/data_warped ${datadir}/warped
    ${FSLDIR}/bin/immv ${datadir}/fullWarp ${datadir}/warped
    ${FSLDIR}/bin/immv ${datadir}/fullWarp_abs ${datadir}/warped
fi

#Remove negative intensity values (caused by spline interpolation) from final data
${FSLDIR}/bin/fslmaths ${datadir}/data -thr 0 ${datadir}/data
b0maxbval=100
mcnt=0
for i in `cat ${datadir}/bvals`
do
	if [ $i -lt ${b0maxbval} ]; then
		b0idx1=${mcnt}
		break
	fi
	mcnt=$((${mcnt} + 1))
done
${FSLDIR}/bin/fslroi ${datadir}/data ${datadir}/nodif ${b0idx1} 1
${FSLDIR}/bin/bet ${datadir}/nodif ${datadir}/nodif_brain -m -f 0.1

echo -e "\n END: eddy_postproc"

