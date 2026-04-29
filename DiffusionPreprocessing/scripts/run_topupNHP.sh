#!/bin/bash

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@" # Debugging functions; also sources log.shlib
echo -e "\n START: run_topup"

workingdir=$1
topup_config_file=$2
SpeciesLabel=$3

#configdir=${HCPPIPEDIR_Config}
# toupp conifig for high res distortion correction in each species - TH Jan 2023
#default_topup_config_file=${configdir}/b02b0.cnf
#if [[ $SPECIES = "" || $SPECIES = "Human" ]] ; then
#	topup_config_file=${configdir}/b02b0_HARP_dMRI.cnf
#elif [[ $SPECIES =~ "Macaque" ]] ; then
#	topup_config_file=${configdir}/b02b0_macaque_dMRI.cnf
#	deprecated_topup_config_file=${configdir}/b02b0_macaque.cnf
#elif [[ $SPECIES =~ "Marmoset" ]] ; then
#	topup_config_file=${configdir}/b02b0_marmoset_dMRI.cnf
#fi

echo -e "\n About to run toup"

# set up libraries
export LD_LIBRARY_PATH=/usr/lib64/openmpi/lib/openmpi:$LD_LIBRARY_PATH
echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"

echo "topup config: ${topup_config_file}"
echo "SpeciesLabel: ${SpeciesLabel}"


#${FSLDIR}/bin/topup --imain=${workingdir}/Pos_Neg_b0 --datain=${workingdir}/acqparams.txt --config=${topup_config_file} --out=${workingdir}/topup_Pos_Neg_b0 -v --fout=${workingdir}/topup_Pos_Neg_b0_field.nii.gz
# parallel version of topup - TH Jan 2023
# added T2w as a phase zero volume - TH Jan 2023
partopupdir=/usr/local/topup.env/bin
partopupdir=$FSLDIR/bin

# deprecated config
#echo " Running topup with deprecated config"
#${partopupdir}/topup --nthr=6 --imain=${workingdir}/Pos_Neg_b0 --datain=${workingdir}/acqparams.txt --config=${deprecated_topup_config_file} --out=${workingdir}/topup_Pos_Neg_b0_deprecatedcnf -v --fout=${workingdir}/topup_Pos_Neg_b0_deprecatedcnf_field.nii.gz --iout=${workingdir}/topup_Pos_Neg_b0_deprecatedcnf
#mv ${workingdir}/Pos_Neg_b0.topup_log ${workingdir}/Pos_Neg_b0.topup_deprecatedcnf_log
#${FSLDIR}/bin/fslmaths ${workingdir}/topup_Pos_Neg_b0_deprecatedcnf_field.nii.gz -mul 6.283 ${workingdir}/TopupField_deprecatedcnf
#$CARET7DIR/wb_command -volume-gradient ${workingdir}/TopupField_deprecatedcnf.nii.gz ${workingdir}/TopupField_deprecatedcnf_grad.nii.gz -vectors ${workingdir}/TopupField_deprecatedcnf_gradvectors.nii.gz

echo " Running topup"
${partopupdir}/topup --nthr=6 --imain=${workingdir}/Pos_Neg_b0 --datain=${workingdir}/acqparams.txt --config=${topup_config_file} --out=${workingdir}/topup_Pos_Neg_b0 -v --fout=${workingdir}/topup_Pos_Neg_b0_field.nii.gz --iout=${workingdir}/topup_Pos_Neg_b0
${FSLDIR}/bin/fslmaths ${workingdir}/topup_Pos_Neg_b0_field.nii.gz -mul 6.283 ${workingdir}/TopupField
$CARET7DIR/wb_command -volume-gradient ${workingdir}/TopupField.nii.gz ${workingdir}/TopupField_grad.nii.gz -vectors ${workingdir}/TopupField_gradvectors.nii.gz

if [ $($FSLDIR/bin/imtest ${workingdir}/Pos_Neg_NoZero_b0.nii.gz) = 1 ] ; then # No T2w registration
	echo " Running topup with no phase zero and deprecated config"
	${partopupdir}/topup --nthr=6 --imain=${workingdir}/Pos_Neg_NoZero_b0 --datain=${workingdir}/acqparams_NoZero.txt --config=${deprecated_topup_config_file} --out=${workingdir}/topup_Pos_Neg_NoZero_b0_deprecatedcnf -v --fout=${workingdir}/topup_Pos_Neg_NoZero_b0_deprecatedcnf_field.nii.gz --iout=${workingdir}/topup_Pos_Neg_NoZero_b0_deprecatedcnf
	mv ${workingdir}/Pos_Neg_NoZero_b0.topup_log ${workingdir}/Pos_Neg_NoZero_b0.topup_deprecated_log
	${FSLDIR}/bin/fslmaths ${workingdir}/topup_Pos_Neg_NoZero_b0_deprecatedcnf_field.nii.gz -mul 6.283 ${workingdir}/TopupField_NoZero_deprecatedcnf
	$CARET7DIR/wb_command -volume-gradient ${workingdir}/TopupField_NoZero_deprecatedcnf.nii.gz ${workingdir}/TopupField_NoZero_deprecatedcnf_grad.nii.gz -vectors ${workingdir}/TopupField_NoZero_deprecatedcnf_gradvectors.nii.gz
	echo "Running topup with no phase zero and new config"
	${partopupdir}/topup --nthr=6 --imain=${workingdir}/Pos_Neg_NoZero_b0 --datain=${workingdir}/acqparams_NoZero.txt --config=${topup_config_file} --out=${workingdir}/topup_Pos_Neg_NoZero_b0 -v --fout=${workingdir}/topup_Pos_Neg_NoZero_b0_field.nii.gz --iout=${workingdir}/topup_Pos_Neg_NoZero_b0
	${FSLDIR}/bin/fslmaths ${workingdir}/topup_Pos_Neg_NoZero_b0_field.nii.gz -mul 6.283 ${workingdir}/TopupField_NoZero
	$CARET7DIR/wb_command -volume-gradient ${workingdir}/TopupField_NoZero.nii.gz ${workingdir}/TopupField_NoZero_grad.nii.gz -vectors ${workingdir}/TopupField_NoZero_gradvectors.nii.gz
fi

dimt=$(${FSLDIR}/bin/fslval ${workingdir}/Pos_b0 dim4)
dimt=$((${dimt} + 1))

echo " Applying topup to get a hifi b0"
${FSLDIR}/bin/fslroi ${workingdir}/Pos_b0 ${workingdir}/Pos_b01 0 1
${FSLDIR}/bin/fslroi ${workingdir}/Neg_b0 ${workingdir}/Neg_b01 0 1
${FSLDIR}/bin/applytopup --imain=${workingdir}/Pos_b01,${workingdir}/Neg_b01 --topup=${workingdir}/topup_Pos_Neg_b0 --datain=${workingdir}/acqparams.txt --inindex=1,${dimt} --out=${workingdir}/hifib0
#${FSLDIR}/bin/applytopup --imain=${workingdir}/Pos_b01,${workingdir}/Neg_b01 --topup=${workingdir}/topup_Pos_Neg_b0_deprecatedcnf --datain=${workingdir}/acqparams.txt --inindex=1,${dimt} --out=${workingdir}/hifib0_deprecatedcnf
if [ $($FSLDIR/bin/imtest ${workingdir}/Pos_Neg_NoZero_b0.nii.gz) = 1 ] ; then # No T2w registration
	${FSLDIR}/bin/applytopup --imain=${workingdir}/Pos_b01,${workingdir}/Neg_b01 --topup=${workingdir}/topup_Pos_Neg_NoZero_b0 --datain=${workingdir}/acqparams_NoZero.txt --inindex=1,${dimt} --out=${workingdir}/hifib0_NoZero
	${FSLDIR}/bin/applytopup --imain=${workingdir}/Pos_b01,${workingdir}/Neg_b01 --topup=${workingdir}/topup_Pos_Neg_NoZero_b0_deprecatedcnf --datain=${workingdir}/acqparams_NoZero.txt --inindex=1,${dimt} --out=${workingdir}/hifib0_NoZero_deprecatedcnf
fi

if [ ! -f ${workingdir}/hifib0.nii.gz ]; then
	echo "run_topup.sh -- ERROR -- ${FSLDIR}/bin/applytopup failed to generate ${workingdir}/hifib0.nii.gz"
	# Need to add mechanism whereby scripts that invoke this script (run_topup.sh)
	# check for a return code to determine success or failure
fi

${FSLDIR}/bin/imrm ${workingdir}/Pos_b0*
${FSLDIR}/bin/imrm ${workingdir}/Neg_b0*

echo " Running BET on the hifi b0"
           if   [ $SpeciesLabel = 0 ] ; then
             betfraction=0.2
           elif [ $SpeciesLabel = 1 ] ; then
             betfraction=0.3
           elif [ $SpeciesLabel = 2 ] ; then 
             betfraction=0.4
           elif [ $SpeciesLabel = 3 ] ; then
             betfraction=0.5
           elif [ $SpeciesLabel -gt 3 ] ; then
             betfraction=0.6
           fi

${FSLDIR}/bin/bet4animal ${workingdir}/hifib0 ${workingdir}/nodif_brain -m -f ${betfraction} -z ${SpeciesLabel}

if [ ! -f ${workingdir}/nodif_brain.nii.gz ]; then
	echo "run_topup.sh -- ERROR -- ${FSLDIR}/bin/bet failed to generate ${workingdir}/nodif_brain.nii.gz"
	# Need to add mechanism whereby scripts that invoke this script (run_topup.sh)
	# check for a return code to determine success or failure
fi

echo -e "\n END: run_topup"
