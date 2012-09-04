#!/bin/bash

workingdir=$1
globalscriptsdir=$2

eddydir=${workingdir}/eddy
datadir=${workingdir}/data

cp ${eddydir}/Pos.bval ${datadir}/bvals
cp ${eddydir}/Pos.bvec ${datadir}/bvecs
dimt=`${FSLDIR}/bin/fslval ${eddydir}/eddy_unwarped_images dim4`
dimt=`echo "scale=0; ${dimt} / 2" | bc -l`

$FSLDIR/bin/fslroi ${eddydir}/eddy_unwarped_images ${datadir}/data1 0 ${dimt}
$FSLDIR/bin/fslroi ${eddydir}/eddy_unwarped_images ${datadir}/data2 ${dimt} -1

$FSLDIR/bin/fslmaths ${datadir}/data1 -add ${datadir}/data2 -div 2 ${datadir}/data
$FSLDIR/bin/bet ${datadir}/data ${datadir}/nodif_brain -m -f 0.1

$FSLDIR/bin/imrm ${datadir}/data1
$FSLDIR/bin/imrm ${datadir}/data2

echo "Computing gradient coil tensor"
curdir=`pwd`
cd ${datadir}
${globalscriptsdir}/binaries/gradient_unwarp.py nodif_brain.nii.gz nodif_brain_unwarped.nii.gz siemens -g ${globalscriptsdir}/config/coeff_SC72C_Skyra.grad -n
${globalscriptsdir}/binaries/calc_grad_perc_dev --fullwarp=fullWarp -o grad_dev
${FSLDIR}/bin/fslmerge -t grad_dev grad_dev_x grad_dev_y grad_dev_z
${FSLDIR}/bin/fslmaths grad_dev -div 100 grad_dev 
${FSLDIR}/bin/imrm grad_dev_?

echo "Correcting for gradient nonlinearities"
${FSLDIR}/bin/immv data data_warped
${FSLDIR}/bin/applywarp -i data_warped -r nodif_brain -w fullWarp --premat=shiftMatrix.mat --interp=spline -o data
${FSLDIR}/bin/immv nodif_brain nodif_brain_warped
${FSLDIR}/bin/immv nodif_brain_mask nodif_brain_mask_warped
${FSLDIR}/bin/imrm nodif_brain_unwarped
${FSLDIR}/bin/bet data nodif_brain -m -f 0.1

cd ${curdir}
mkdir ${datadir}/warped
${FSLDIR}/bin/immv ${datadir}/nodif_brain_mask_warped ${datadir}/warped
${FSLDIR}/bin/immv ${datadir}/nodif_brain_warped ${datadir}/warped
${FSLDIR}/bin/immv ${datadir}/data_warped ${datadir}/warped
${FSLDIR}/bin/immv ${datadir}/fullWarp ${datadir}/warped
mv ${datadir}/shiftMatrix.mat ${datadir}/warped
