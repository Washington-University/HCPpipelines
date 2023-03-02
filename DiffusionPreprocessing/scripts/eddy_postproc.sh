#!/bin/bash
source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@" # Debugging functions; also sources log.shlib
echo -e "\n START: eddy_postproc"

#Hard-Coded filename. Flag from eddy to indicate that the jac method has been used for resampling
EddyJacFlag="JacobianResampling"

workingdir=$1
GdCoeffs=$2        #Coefficients for gradient nonlinearity distortion correction. If "NONE" this corrections is turned off
CombineDataFlag=$3 #2 for including in the ouput all volumes uncombined (i.e. output file of eddy)
                   #1 for including in the ouput and combine only volumes where both LR/RL or AP/PA pairs have been acquired
                   #0 As 1, but also include uncombined single volumes"
SelectBestB0=$4 #0 only the actual diffusion data was fed into eddy
                #1 least distorted b0 was prepended to the eddy input
                # Note: This numeric value is used within the script as a numeric that controls
                # the number of volumes to skip, so it isn't just used as 0/1 "boolean".

globalscriptsdir=${HCPPIPEDIR_Global}

eddydir=${workingdir}/eddy
datadir=${workingdir}/data

echo "Generating eddy QC report in ${workingdir}/QC"
if [ -d "${workingdir}/QC" ]; then rm -r ${workingdir}/QC; fi
qc_command=("${FSLDIR}/bin/eddy_quad")
qc_command+=("${eddydir}/eddy_unwarped_images")
qc_command+=(-idx "${eddydir}/index.txt")
qc_command+=(-par "${eddydir}/acqparams.txt")
qc_command+=(-m "${eddydir}/nodif_brain_mask.nii.gz")
qc_command+=(-b "${eddydir}/Pos_Neg.bvals")
qc_command+=(-g "${eddydir}/eddy_unwarped_images.eddy_rotated_bvecs")
qc_command+=(-o "${workingdir}/QC")
qc_command+=(-f "${workingdir}/topup/topup_Pos_Neg_b0_field.nii.gz")
qc_command+=(-v)
"${qc_command[@]}"

#Prepare for next eddy Release
#if [ ! -e ${eddydir}/${EddyJacFlag} ]; then
#    echo "LSR resampling has been used. Eddy Output has already been combined."
#    cp ${eddydir}/Pos.bval ${datadir}/bvals
#    cp ${eddydir}/Pos.bvec ${datadir}/bvecs
#    $FSLDIR/bin/imcp ${eddydir}/eddy_unwarped_images ${datadir}/data
#else

# Across the combinations of CombineDataFlag and SelectBestB0, need to end up with each of the following
# in ${datadir}: data.nii.gz, bvals, bvecs_noRot, bvecs
if [ ${CombineDataFlag} -eq 2 ]; then
	
	if [ ${SelectBestB0} -eq 1 ]; then
		# remove first volume/value as this reflects the "best b0", which was added to the dataset before running eddy
		${FSLDIR}/bin/fslroi ${eddydir}/eddy_unwarped_images ${datadir}/data 1 -1
		cut -d' ' -f2- ${eddydir}/Pos_Neg.bvals >${datadir}/bvals
		cut -d' ' -f2- ${eddydir}/Pos_Neg.bvecs >${datadir}/bvecs_noRot
		cut -d' ' -f2- ${eddydir}/eddy_unwarped_images.eddy_rotated_bvecs >${datadir}/bvecs
	else
		${FSLDIR}/bin/imcp ${eddydir}/eddy_unwarped_images ${datadir}/data
		cp ${eddydir}/Pos_Neg.bvals ${datadir}/bvals
		cp ${eddydir}/Pos_Neg.bvecs ${datadir}/bvecs_noRot
		cp ${eddydir}/eddy_unwarped_images.eddy_rotated_bvecs ${datadir}/bvecs
	fi

else # Combining across diffusion directions with opposing phase-encoding polarities
	
	echo "JAC resampling has been used. Eddy Output is now combined."
	# Note: ${eddydir}/{Pos,Neg}.{bval,bvec} are the *original* bvals/bvecs, even if SelectBestB0=1 (i.e., are NOT prepended with BestB0)
	PosVols=$(wc ${eddydir}/Pos.bval | awk {'print $2'})
	NegVols=$(wc ${eddydir}/Neg.bval | awk {'print $2'}) # Split Pos and Neg Volumes
	${FSLDIR}/bin/fslroi ${eddydir}/eddy_unwarped_images ${eddydir}/eddy_unwarped_Pos ${SelectBestB0} ${PosVols} # ignore extra first volume if ${SelectBestB0} is 1
	${FSLDIR}/bin/fslroi ${eddydir}/eddy_unwarped_images ${eddydir}/eddy_unwarped_Neg $((PosVols + ${SelectBestB0})) ${NegVols}
	# Note: 'eddy_combine' is hard-coded to use data.nii.gz, bvals, and bvecs as its outputs
	${FSLDIR}/bin/eddy_combine ${eddydir}/eddy_unwarped_Pos ${eddydir}/Pos.bval ${eddydir}/Pos.bvec ${eddydir}/Pos_SeriesVolNum.txt \
		${eddydir}/eddy_unwarped_Neg ${eddydir}/Neg.bval ${eddydir}/Neg.bvec ${eddydir}/Neg_SeriesVolNum.txt ${datadir} ${CombineDataFlag}

	# Cleanup
	${FSLDIR}/bin/imrm ${eddydir}/eddy_unwarped_Pos
	${FSLDIR}/bin/imrm ${eddydir}/eddy_unwarped_Neg

	# At this point, have data.nii.gz, bvals, and bvecs in ${datadir}
	# But the bvecs are the non-rotated bvecs, so rename appropriately
	mv ${datadir}/bvecs ${datadir}/bvecs_noRot
	# averaged-based version of bvals get created below, but save the "non-rotated" version as well
	mv ${datadir}/bvals ${datadir}/bvals_noRot

	# The following is to average the *rotated* bvecs returned by 'eddy', accounting for $SelectBestB0.
	# Divide Eddy-Rotated bvecs to Pos and Neg
	line1=$(awk 'NR==1 {print; exit}' ${eddydir}/eddy_unwarped_images.eddy_rotated_bvecs)
	line2=$(awk 'NR==2 {print; exit}' ${eddydir}/eddy_unwarped_images.eddy_rotated_bvecs)
	line3=$(awk 'NR==3 {print; exit}' ${eddydir}/eddy_unwarped_images.eddy_rotated_bvecs)
	Posline1=""
	Posline2=""
	Posline3=""
	for ((i = $((SelectBestB0 + 1)); i <= $((PosVols + ${SelectBestB0})); i++)); do
		Posline1="$Posline1 $(echo $line1 | awk -v N=$i '{print $N}')"
		Posline2="$Posline2 $(echo $line2 | awk -v N=$i '{print $N}')"
		Posline3="$Posline3 $(echo $line3 | awk -v N=$i '{print $N}')"
	done
	echo $Posline1 >${eddydir}/Pos_rotated.bvec
	echo $Posline2 >>${eddydir}/Pos_rotated.bvec
	echo $Posline3 >>${eddydir}/Pos_rotated.bvec

	Negline1=""
	Negline2=""
	Negline3=""
	Nstart=$((PosVols + 1 + ${SelectBestB0}))
	Nend=$((PosVols + NegVols + ${SelectBestB0}))
	for ((i = $Nstart; i <= $Nend; i++)); do
		Negline1="$Negline1 $(echo $line1 | awk -v N=$i '{print $N}')"
		Negline2="$Negline2 $(echo $line2 | awk -v N=$i '{print $N}')"
		Negline3="$Negline3 $(echo $line3 | awk -v N=$i '{print $N}')"
	done
	echo $Negline1 >${eddydir}/Neg_rotated.bvec
	echo $Negline2 >>${eddydir}/Neg_rotated.bvec
	echo $Negline3 >>${eddydir}/Neg_rotated.bvec

	# Average Eddy-Rotated bvecs. Get for each direction the two b matrices, average those and then eigendecompose the average b-matrix to get the new bvec and bval.
	# Also outputs an index file (1-based) with the indices of the input (Pos/Neg) volumes that have been retained in the output
	${globalscriptsdir}/average_bvecs.py ${eddydir}/Pos.bval ${eddydir}/Pos_rotated.bvec ${eddydir}/Neg.bval ${eddydir}/Neg_rotated.bvec ${datadir}/avg_data ${CombineDataFlag} ${eddydir}/Pos_SeriesVolNum.txt ${eddydir}/Neg_SeriesVolNum.txt

	mv ${datadir}/avg_data.bval ${datadir}/bvals
	mv ${datadir}/avg_data.bvec ${datadir}/bvecs
	rm -f ${datadir}/avg_data.bv??
fi

imcp ${eddydir}/eddy_unwarped_images.eddy_cnr_maps ${datadir}/cnr_maps

# Create a mask representing voxels within the field of view for all volumes prior to dilation
# 'eddy' can return negative values in some low signal locations, so use -abs for determining the fov mask
${FSLDIR}/bin/fslmaths ${datadir}/data -abs -Tmin -bin -fillh ${datadir}/fov_mask

if [ ! $GdCoeffs = "NONE" ]; then
	echo "Correcting for gradient nonlinearities"
	# Note: data in the warped directory is eddy-current and suspectibility distortion corrected (via 'eddy'), but prior to gradient distortion correction
	# i.e., "data_posteddy_preGDC" would be another way to think of it
	warpedDir=${datadir}/warped
	mkdir -p ${warpedDir}
	${FSLDIR}/bin/immv ${datadir}/data ${warpedDir}/data_warped
	${FSLDIR}/bin/immv ${datadir}/fov_mask ${warpedDir}/fov_mask_warped
	${FSLDIR}/bin/immv ${datadir}/cnr_maps ${warpedDir}/cnr_maps_warped

	# Dilation outside of the field of view to minimise the effect of the hard field of view edge on the interpolation
	DiffRes=$(${FSLDIR}/bin/fslval ${warpedDir}/data_warped pixdim1)
	DilateDistance=$(echo "$DiffRes * 4" | bc) # Extrapolates the diffusion data up to 4 voxels outside of the FOV
	${CARET7DIR}/wb_command -volume-dilate ${warpedDir}/data_warped.nii.gz $DilateDistance NEAREST ${warpedDir}/data_dilated.nii.gz

	# apply gradient distortion correction
	${globalscriptsdir}/GradientDistortionUnwarp.sh --workingdir="${datadir}" --coeffs="${GdCoeffs}" --in="${warpedDir}/data_dilated" --out="${datadir}/data" --owarp="${datadir}/fullWarp"
	${FSLDIR}/bin/immv ${datadir}/fullWarp ${warpedDir}
	${FSLDIR}/bin/immv ${datadir}/fullWarp_abs ${warpedDir}
	${FSLDIR}/bin/imrm ${warpedDir}/data_dilated

	# Transform CNR maps
	${CARET7DIR}/wb_command -volume-dilate ${warpedDir}/cnr_maps_warped.nii.gz $DilateDistance NEAREST ${warpedDir}/cnr_maps_dilated.nii.gz
	${FSLDIR}/bin/applywarp --rel --interp=spline -i ${warpedDir}/cnr_maps_dilated -r ${warpedDir}/cnr_maps_dilated -w ${warpedDir}/fullWarp -o ${datadir}/cnr_maps
	${FSLDIR}/bin/imrm ${warpedDir}/cnr_maps_dilated

	# Transform field of view mask (using conservative trilinear interpolation with high threshold)
	${FSLDIR}/bin/applywarp --rel --interp=trilinear -i ${warpedDir}/fov_mask_warped -r ${warpedDir}/fov_mask_warped -w ${warpedDir}/fullWarp -o ${datadir}/fov_mask
	${FSLDIR}/bin/fslmaths ${datadir}/fov_mask -thr 0.999 -bin ${datadir}/fov_mask

	echo "Computing gradient coil tensor to correct for gradient nonlinearities"
	${FSLDIR}/bin/calc_grad_perc_dev --fullwarp=${warpedDir}/fullWarp -o ${datadir}/grad_dev
	${FSLDIR}/bin/fslmerge -t ${datadir}/grad_dev ${datadir}/grad_dev_x ${datadir}/grad_dev_y ${datadir}/grad_dev_z
	${FSLDIR}/bin/fslmaths ${datadir}/grad_dev -div 100 ${datadir}/grad_dev #Convert from % deviation to absolute
	# Delete each of the grad_dev files individualy due to bug in behavior of imrm introduced in FSL 6.0.6
	${FSLDIR}/bin/imrm ${datadir}/grad_dev_x
	${FSLDIR}/bin/imrm ${datadir}/grad_dev_y
	${FSLDIR}/bin/imrm ${datadir}/grad_dev_z
	${FSLDIR}/bin/imrm ${datadir}/trilinear
	${FSLDIR}/bin/imrm ${warpedDir}/data_dilated_vol1
fi

# mask out any data outside the field of view
${FSLDIR}/bin/fslmaths ${datadir}/data -mas ${datadir}/fov_mask ${datadir}/data
${FSLDIR}/bin/fslmaths ${datadir}/cnr_maps -mas ${datadir}/fov_mask ${datadir}/cnr_maps

# Remove negative intensity values (from eddy) from final data
${FSLDIR}/bin/fslmaths ${datadir}/data -thr 0 ${datadir}/data
${FSLDIR}/bin/fslroi ${datadir}/data ${datadir}/nodif 0 1
${FSLDIR}/bin/bet ${datadir}/nodif ${datadir}/nodif_brain -m -f 0.1

echo -e "\n END: eddy_postproc"
