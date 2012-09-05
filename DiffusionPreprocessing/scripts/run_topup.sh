#!/bin/bash


workingdir=$1
globaldir=$2
#topup_config_file=${FSLDIR}/bin/b02b0.cnf  #Should be in FSLDIR for FSL5.0, no need of globalscriptsdir
topup_config_file=${globaldir}/config/b02b0.cnf

${FSLDIR}/bin/topup --imain=${workingdir}/Pos_Neg_b0 --datain=${workingdir}/acqparams.txt --config=${topup_config_file} --out=${workingdir}/topup_Pos_Neg_b0 -v

dimt=`${FSLDIR}/bin/fslval ${workingdir}/Pos_b0 dim4`
dimt=$(($dimt + 1))

echo "Applying topup to get a hifi b0"
${FSLDIR}/bin/applytopup --imain=${workingdir}/Pos_b0,${workingdir}/Neg_b0 --topup=${workingdir}/topup_Pos_Neg_b0 --datain=${workingdir}/acqparams.txt --inindex=1,$dimt --out=${workingdir}/hifib0

${FSLDIR}/bin/imrm ${workingdir}/Pos_b0
${FSLDIR}/bin/imrm ${workingdir}/Neg_b0

echo "Running BET on the hifi b0"
${FSLDIR}/bin/bet ${workingdir}/hifib0 ${workingdir}/nodif_brain -m -f 0.2