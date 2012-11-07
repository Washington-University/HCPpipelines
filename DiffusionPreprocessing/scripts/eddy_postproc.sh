#!/bin/bash
set -e
echo -e "\n START: postproc"

#Hard-Coded filename. Flag from eddy to indicate that the jac method has been used for resampling
EddyJacFlag="JacobianResampling" 

workingdir=$1
globaldir=$2

eddydir=${workingdir}/eddy
datadir=${workingdir}/data

#Prepare for next eddy Release
#if [ ! -e ${eddydir}/${EddyJacFlag} ]; then 
#    echo "LSR resampling has been used. Eddy Output has already been combined."
#    cp ${eddydir}/Pos.bval ${datadir}/bvals
#    cp ${eddydir}/Pos.bvec ${datadir}/bvecs
#    $FSLDIR/bin/imcp ${eddydir}/eddy_unwarped_images ${datadir}/data
#else
     echo "JAC resampling has been used. Eddy Output is now combined."
     PosVols=`wc ${eddydir}/Pos.bval | awk {'print $2'}`
     NegVols=`wc ${eddydir}/Neg.bval | awk {'print $2'}`    #Split Pos and Neg Volumes
     ${FSLDIR}/bin/fslroi ${eddydir}/eddy_unwarped_images ${eddydir}/eddy_unwarped_Pos 0 ${PosVols}
     ${FSLDIR}/bin/fslroi ${eddydir}/eddy_unwarped_images ${eddydir}/eddy_unwarped_Neg ${PosVols} ${NegVols}
     ${globaldir}/binaries/eddy_combine ${eddydir}/eddy_unwarped_Pos ${eddydir}/Pos.bval ${eddydir}/Pos.bvec ${eddydir}/Pos_SeriesVolNum.txt \
                                        ${eddydir}/eddy_unwarped_Neg ${eddydir}/Neg.bval ${eddydir}/Neg.bvec ${eddydir}/Neg_SeriesVolNum.txt ${datadir} 1

     ${FSLDIR}/bin/imrm ${eddydir}/eddy_unwarped_Pos
     ${FSLDIR}/bin/imrm ${eddydir}/eddy_unwarped_Neg
     #rm ${eddydir}/Pos.bv*
     #rm ${eddydir}/Neg.bv*
#fi

$FSLDIR/bin/bet ${datadir}/data ${datadir}/nodif_brain -m -f 0.1

echo "Computing gradient coil tensor"
curdir=`pwd`
cd ${datadir}
${globaldir}/binaries/gradient_unwarp.py nodif_brain.nii.gz nodif_brain_unwarped.nii.gz siemens -g ${globaldir}/config/coeff_SC72C_Skyra.grad -n
${globaldir}/binaries/calc_grad_perc_dev --fullwarp=fullWarp -o grad_dev
${FSLDIR}/bin/fslmerge -t grad_dev grad_dev_x grad_dev_y grad_dev_z
${FSLDIR}/bin/fslmaths grad_dev -div 100 grad_dev 
${FSLDIR}/bin/imrm grad_dev_?


#In the future, we want this applywarp to be part of eddy and avoid second resampling step.
echo "Correcting for gradient nonlinearities"
${FSLDIR}/bin/immv data data_warped
${FSLDIR}/bin/applywarp -i data_warped -r nodif_brain -w fullWarp --premat=shiftMatrix.mat --interp=spline -o data
${FSLDIR}/bin/immv nodif_brain nodif_brain_warped
${FSLDIR}/bin/immv nodif_brain_mask nodif_brain_mask_warped
${FSLDIR}/bin/imrm nodif_brain_unwarped
${FSLDIR}/bin/bet data nodif_brain -m -f 0.1

cd ${curdir}
mkdir -p ${datadir}/warped
${FSLDIR}/bin/immv ${datadir}/nodif_brain_mask_warped ${datadir}/warped
${FSLDIR}/bin/immv ${datadir}/nodif_brain_warped ${datadir}/warped
${FSLDIR}/bin/immv ${datadir}/data_warped ${datadir}/warped
${FSLDIR}/bin/immv ${datadir}/fullWarp ${datadir}/warped
mv ${datadir}/shiftMatrix.mat ${datadir}/warped

echo -e "\n END: postproc"

