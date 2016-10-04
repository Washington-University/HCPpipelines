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
	cp ${datadir}/bvals ${datadir}/bvals_noRot
	cp ${datadir}/bvecs ${datadir}/bvecs_noRot
     
	#rm ${eddydir}/Pos.bv*
	#rm ${eddydir}/Neg.bv*

 
	# Divide Eddy-Rotated bvecs to Pos and Neg
	line1=`awk 'NR==1 {print; exit}' ${eddydir}/eddy_unwarped_images.eddy_rotated_bvecs`
	line2=`awk 'NR==2 {print; exit}' ${eddydir}/eddy_unwarped_images.eddy_rotated_bvecs`
	line3=`awk 'NR==3 {print; exit}' ${eddydir}/eddy_unwarped_images.eddy_rotated_bvecs`   
	Posline1=""
	Posline2=""
	Posline3=""
	for ((i=1; i<=$PosVols; i++)); do
	    Posline1="$Posline1 `echo $line1 | awk -v N=$i '{print $N}'`"
	    Posline2="$Posline2 `echo $line2 | awk -v N=$i '{print $N}'`"
	    Posline3="$Posline3 `echo $line3 | awk -v N=$i '{print $N}'`"
	done
	echo $Posline1 > ${eddydir}/Pos_rotated.bvec
	echo $Posline2 >> ${eddydir}/Pos_rotated.bvec
	echo $Posline3 >> ${eddydir}/Pos_rotated.bvec

	Negline1=""
	Negline2=""
	Negline3=""
	Nstart=$((PosVols + 1 ))
	Nend=$((PosVols + NegVols))
	for  ((i=$Nstart; i<=$Nend; i++)); do
	    Negline1="$Negline1 `echo $line1 | awk -v N=$i '{print $N}'`"
	    Negline2="$Negline2 `echo $line2 | awk -v N=$i '{print $N}'`"
	    Negline3="$Negline3 `echo $line3 | awk -v N=$i '{print $N}'`"
	done
	echo $Negline1 > ${eddydir}/Neg_rotated.bvec
	echo $Negline2 >> ${eddydir}/Neg_rotated.bvec
	echo $Negline3 >> ${eddydir}/Neg_rotated.bvec
	
	# Average Eddy-Rotated bvecs. Get for each direction the two b matrices, average those and then eigendecompose the average b-matrix to get the new bvec and bval.
	# Also outputs an index file (1-based) with the indices of the input (Pos/Neg) volumes that have been retained in the output
	${globalscriptsdir}/average_bvecs.py ${eddydir}/Pos.bval ${eddydir}/Pos_rotated.bvec ${eddydir}/Neg.bval ${eddydir}/Neg_rotated.bvec ${datadir}/avg_data ${eddydir}/Pos_SeriesVolNum.txt ${eddydir}/Neg_SeriesVolNum.txt

	mv ${datadir}/avg_data.bval ${datadir}/bvals
	mv ${datadir}/avg_data.bvec ${datadir}/bvecs
	rm -f ${datadir}/avg_data.bv??
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
${FSLDIR}/bin/bet ${datadir}/data ${datadir}/nodif_brain -m -f 0.1
$FSLDIR/bin/fslroi ${datadir}/data ${datadir}/nodif 0 1

echo -e "\n END: eddy_postproc"

