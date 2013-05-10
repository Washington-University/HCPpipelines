#!/bin/bash
set -e
echo -e "\n START: eddy"

workingdir=$1

binarydir=${HCPPIPEDIR_Bin}
topupdir=`dirname ${workingdir}`/topup

${FSLDIR}/bin/imcp ${topupdir}/nodif_brain_mask ${workingdir}/

${binarydir}/eddy --imain=${workingdir}/Pos_Neg --mask=${workingdir}/nodif_brain_mask --index=${workingdir}/index.txt --acqp=${workingdir}/acqparams.txt --bvecs=${workingdir}/Pos_Neg.bvecs --bvals=${workingdir}/Pos_Neg.bvals --fwhm=0 --topup=${topupdir}/topup_Pos_Neg_b0 --out=${workingdir}/eddy_unwarped_images --flm=quadratic -v #--resamp=lsr #--session=${workingdir}/series_index.txt

echo -e "\n END: eddy"

