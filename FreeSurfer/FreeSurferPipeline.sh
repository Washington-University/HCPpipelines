#!/bin/bash

#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # FreeSurferPipeline.sh
#
# ## Copyright Notice
#
# Copyright (C) 2015-2018 The Human Connectome Project/Connectome Coordination Facility
#
# * Washington University in St. Louis
# * University of Minnesota
# * Oxford University
#
# ## Author(s)
#
# * Matthew F. Glasser, Department of Anatomy and Neurobiology, Washington University in St. Louis
# * Timothy B. Brown, Neuroinformatics Research Group, Washington University in St. Louis
#
# ## Product
#
# [Human Connectome Project](http://www.humanconnectome.org) (HCP) Pipelines
#
# ## License
#
# See the [LICENSE](https://github.com/Washington-University/Pipelines/blob/master/LICENSE.md) file
#
#~ND~END~

# Show tool versions
show_tool_versions()
{
	# Show HCP pipelines version
	log_Msg "Showing HCP Pipelines version"
	${HCPPIPEDIR}/show_version

	# Show recon-all version
	log_Msg "Showing recon-all.v6.hires version"
	which recon-all.v6.hires
	recon-all.v6.hires -version

	# Show tkregister version
	log_Msg "Showing tkregister version"
	which tkregister
	tkregister -version

	# Show fslmaths version
	log_Msg "Showing fslmaths version"
	which fslmaths

	# Show fslstats version
	log_Msg "Showing fslstats version"
	which fslstats

	# Show mri_concatenate_lta version
	log_Msg "Showing mri_concatenate_lta version"
	which mri_concatenate_lta
	mri_concatenate_lta -version

	# Show mri_surf2surf version
	log_Msg "Showing mri_surf2surf version"
	which mri_surf2surf --version
}

# Show usage information
usage()
{
	cat <<EOF

${g_script_name}: Run FreeSurfer processing pipeline

Usage: ${g_script_name}: PARAMETER...

PARAMETERs are: [ ] = optional; < > = user supplied value

  [--help] : show usage information and exit

  one from the following group is required

	 --subject-dir=<path to subject directory>
	 --subjectDIR=<path to subject directory>

  --subject=<subject ID>

  one from the following group is required

	 --t1w-image=<path to T1w image>
	 --t1=<path to T1w image>

  one from the following group is required

	 --t1brain=<path to T1w brain mask>
	 --t1w-brain=<path to T1w brain mask>

  one from the following group is required

	 --t2w-image=<path to T2w image>
	 --t2=<path to T2w image>

  [--seed=<recon-all seed value>]

PARAMETERs can also be specified positionally as:

  ${g_script_name} <path to subject directory> <subject ID> <path to T1 image> <path to T1w brain mask> <path to T2w image> [<recon-all seed value>]

EOF
}

get_options()
{
	local arguments=($@)

	# initialize global output variables
	unset p_subject_dir
	unset p_subject
	unset p_t1w_image
	unset p_t1w_brain
	unset p_t2w_image
	unset p_seed

	# parse arguments
	local num_args=${#arguments[@]}
	local argument
	local index=0

	while [ "${index}" -lt "${num_args}" ]; do
		argument=${arguments[index]}

		case ${argument} in
			--help)
				usage
				exit 1
				;;
			--subject-dir=*)
				p_subject_dir=${argument#*=}
				index=$(( index + 1 ))
				;;
			--subjectDIR=*)
				p_subject_dir=${argument#*=}
				index=$(( index + 1 ))
				;;
			--subject=*)
				p_subject=${argument#*=}
				index=$(( index + 1 ))
				;;
			--t1w-image=*)
				p_t1w_image=${argument#*=}
				index=$(( index + 1 ))
				;;
			--t1=*)
				p_t1w_image=${argument#*=}
				index=$(( index + 1 ))
				;;
			--t1brain=*)
				p_t1w_brain=${argument#*=}
				index=$(( index + 1 ))
				;;
			--t1w-brain=*)
				p_t1w_brain=${argument#*=}
				index=$(( index + 1 ))
				;;
			--t2w-image=*)
				p_t2w_image=${argument#*=}
				index=$(( index + 1 ))
				;;
			--t2=*)
				p_t2w_image=${argument#*=}
				index=$(( index + 1 ))
				;;
			--seed=*)
				p_seed=${argument#*=}
				index=$(( index + 1 ))
				;;
			*)
				usage
				log_Err_Abort "unrecognized option: ${argument}"
				;;
		esac

	done

	local error_count=0

	# check required parameters
	if [ -z "${p_subject_dir}" ]; then
		log_Err "Subject Directory (--subject-dir= or --subjectDIR= or --path= or --study-folder=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Subject Directory: ${p_subject_dir}"
	fi

	if [ -z "${p_subject}" ]; then
		log_Err "Subject (--subject=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Subject: ${p_subject}"
	fi

	if [ -z "${p_t1w_image}" ]; then
		log_Err "T1w Image (--t1w-image= or --t1=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "T1w Image: ${p_t1w_image}"
	fi

	if [ -z "${p_t1w_brain}" ]; then
		log_Err "T1w Brain (--t1brain= or --t1w-brain=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "T1w Brain: ${p_t1w_brain}"
	fi

	if [ -z "${p_t2w_image}" ]; then
		log_Err "T2w Image (--t2w-image= or --t2=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "T2w Image: ${p_t2w_image}"
	fi

	# show optional parameters if specified
	if [ ! -z "${p_seed}" ]; then
		log_Msg "Seed: ${p_seed}"
	fi

	if [ ${error_count} -gt 0 ]; then
		log_Err_Abort "For usage information, use --help"
	fi
}

#
# Generate T1w in NIFTI format and in rawavg space
# that has been aligned by BBR but not undergone
# FreeSurfer intensity normalization
# 
make_t1w_hires_nifti_file()
{
	local working_dir
	local t1w_input_file
	local t1w_output_file
	local mri_convert_cmd
	local return_code
	
	working_dir="${1}"
	
	pushd "${working_dir}"

	# We should already have the necessary T1w volume.
	# It's the rawavg.mgz file. We just need to convert
	# it to NIFTI format.

	t1w_input_file="rawavg.mgz"
	t1w_output_file="T1w_hires.nii.gz"
	
	if [ ! -e "${t1w_input_file}" ]; then
		log_Err_Abort "Expected t1w_input_file: ${t1w_input_file} DOES NOT EXIST"
	fi

	mri_convert_cmd="mri_convert ${t1w_input_file} ${t1w_output_file}"

	log_Msg "Creating ${t1w_output_file} with mri_convert_cmd: ${mri_convert_cmd}"
	${mri_convert_cmd}
	return_code=$?
	if [ "${return_code}" != "0" ]; then
		log_Err_Abort "mri_convert command failed with return code: ${return_code}"
	fi
		
	popd 
}

#
# Generate T2w in NIFTI format and in rawavg space
# that has been aligned by BBR but not undergone
# FreeSurfer intensity normalization
#
make_t2w_hires_nifti_file()
{
	local working_dir
	local t2w_input_file
	local target_volume
	local t2w_output_file
	local mri_vol2vol_cmd
	local return_code
	
	working_dir="${1}"

	pushd "${working_dir}"

	# The rawavg.T2.prenorm.mgz file must exist.
	# Then we need to move (resample) it to
	# the target volume and convert it to NIFTI format.

	t2w_input_file="rawavg.T2.prenorm.mgz"
	target_volume="rawavg.mgz"
	t2w_output_file="T2w_hires.nii.gz"
	
	if [ ! -e "${t2w_input_file}" ]; then
		log_Err_Abort "Expected t2w_input_file: ${t2w_input_file} DOES NOT EXIST"
	fi

	if [ ! -e "${target_volume}" ]; then
		log_Err_Abort "Expected target_volume: ${target_volume} DOES NOT EXIST"
	fi
	
	mri_vol2vol_cmd="mri_vol2vol"
	mri_vol2vol_cmd+=" --mov ${t2w_input_file}"
	mri_vol2vol_cmd+=" --targ ${target_volume}"
	mri_vol2vol_cmd+=" --regheader"
	mri_vol2vol_cmd+=" --o ${t2w_output_file}"
	
	log_Msg "Creating ${t2w_output_file} with mri_vol2vol_cmd: ${mri_vol2vol_cmd}"
	${mri_vol2vol_cmd}
	return_code=$?
	if [ "${return_code}" != 0 ]; then
		log_Err_Abort "mri_vol2vol command failed with return code: ${return_code}"
	fi

	popd
}

#
# Generate QC file - T1w X T2w
# 
make_t1wxtw2_qc_file()
{
	local working_dir
	local t1w_input_file
	local t2w_input_file
	local output_file
	local fslmaths_cmd
	local return_code
	
	working_dir="${1}"

	pushd "${working_dir}"

	# We should already have generated the T1w_hires.nii.gz and T2w_hires.nii.gz files
	t1w_input_file="T1w_hires.nii.gz"
	t2w_input_file="T2w_hires.nii.gz"
	output_file="T1wMulT2w_hires.nii.gz"
	
 	if [ ! -e "${t1w_input_file}" ]; then
		log_Err_Abort "Expected t1w_input_file: ${t1w_input_file} DOES NOT EXIST"
	fi

 	if [ ! -e "${t2w_input_file}" ]; then
		log_Err_Abort "Expected t2w_input_file: ${t2w_input_file} DOES NOT EXIST"
	fi

	fslmaths_cmd="fslmaths"
	fslmaths_cmd+=" ${t1w_input_file}"
	fslmaths_cmd+=" -mul ${t2w_input_file}"
	fslmaths_cmd+=" -sqrt ${output_file}"

	log_Msg "Creating ${output_file} with fslmaths_cmd: ${fslmaths_cmd}" 
	${fslmaths_cmd}
	return_code=$?
	if [ "${return_code}" != "0" ]; then
		log_Err_Abort "fslmaths command failed with return code: ${return_code}"
	fi
	
	popd
}

main()
{
	local SubjectDIR
	local SubjectID
	local T1wImage
	local T1wImageBrain
	local T2wImage
	local recon_all_seed

	local num_cores
	local zero_threshold_T1wImage
	local return_code
	local recon_all_cmd
	local mridir
	local transformsdir
	local eye_dat_file

	local tkregister_cmd
	local mri_concatenate_lta_cmd
	local mri_surf2surf_cmd

	# ----------------------------------------------------------------------
	log_Msg "Starting main functionality"
	# ----------------------------------------------------------------------

	# ----------------------------------------------------------------------
	log_Msg "Retrieve positional parameters"
	# ----------------------------------------------------------------------
	SubjectDIR="${1}"
	SubjectID="${2}"
	T1wImage="${3}"
	T1wImageBrain="${4}"
	T2wImage="${5}"
	recon_all_seed="${6}"

	# ----------------------------------------------------------------------
	# Log values retrieved from positional parameters
	# ----------------------------------------------------------------------
	log_Msg "SubjectDIR: ${SubjectDIR}"
	log_Msg "SubjectID: ${SubjectID}"
	log_Msg "T1wImage: ${T1wImage}"
	log_Msg "T1wImageBrain: ${T1wImageBrain}"
	log_Msg "T2wImage: ${T2wImage}"
	log_Msg "recon_all_seed: ${recon_all_seed}"

	# ----------------------------------------------------------------------
	log_Msg "Figure out the number of cores to use."
	# ----------------------------------------------------------------------
	# Both the SGE and PBS cluster schedulers use the environment variable NSLOTS to indicate the
	# number of cores a job will use. If this environment variable is set, we will use it to
	# determine the number of cores to tell recon-all to use.

	num_cores=0
	if [[ -z ${NSLOTS} ]]; then
		num_cores=8
	else
		num_cores="${NSLOTS}"
	fi
	log_Msg "num_cores: ${num_cores}"

	# ----------------------------------------------------------------------
	log_Msg "Thresholding T1w image to eliminate negative voxel values"
	# ----------------------------------------------------------------------
	zero_threshold_T1wImage=$(remove_ext ${T1wImage})_zero_threshold.nii.gz
	log_Msg "...This produces a new file named: ${zero_threshold_T1wImage}"

	fslmaths ${T1wImage} -thr 0 ${zero_threshold_T1wImage}
	return_code=$?
	if [ "${return_code}" != "0" ]; then
		log_Err_Abort "fslmaths command failed with return_code: ${return_code}"
	fi

	# ----------------------------------------------------------------------
	log_Msg "Call FreeSurfer's recon-all"
	# ----------------------------------------------------------------------
#	recon_all_cmd="recon-all.v6.hires"
#	recon_all_cmd+=" -i ${zero_threshold_T1wImage}"
#	recon_all_cmd+=" -emregmask ${T1wImageBrain}"
#	recon_all_cmd+=" -T2 ${T2wImage}"
#	recon_all_cmd+=" -subjid ${SubjectID}"
#	recon_all_cmd+=" -sd ${SubjectDIR}"
#	recon_all_cmd+=" -hires"
#	recon_all_cmd+=" -openmp ${num_cores}"
#	recon_all_cmd+=" -all"
#	recon_all_cmd+=" -T2pial"

	recon_all_cmd="recon-all.v6.hires"
	recon_all_cmd+=" -subjid ${SubjectID}"
	recon_all_cmd+=" -sd ${SubjectDIR}"
	recon_all_cmd+=" -all"
	recon_all_cmd+=" -conf2hires"
	recon_all_cmd+=" -i ${zero_threshold_T1wImage}"
	recon_all_cmd+=" -T2 ${T2wImage}"
	recon_all_cmd+=" -T2pial"
	recon_all_cmd+=" -emregmask ${T1wImageBrain}"
	recon_all_cmd+=" -openmp ${num_cores}"
	
	if [ ! -z "${recon_all_seed}" ]; then
		recon_all_cmd+=" -norandomness -rng-seed ${recon_all_seed}"
	fi

	log_Msg "...recon_all_cmd: ${recon_all_cmd}"
	${recon_all_cmd}
	return_code=$?
	if [ "${return_code}" != "0" ]; then
		log_Err_Abort "recon-all command failed with return_code: ${return_code}"
	fi

	# ----------------------------------------------------------------------
	log_Msg "Clean up file: ${zero_threshold_T1wImage}"
	# ----------------------------------------------------------------------
	rm ${zero_threshold_T1wImage}
	return_code=$?
	if [ "${return_code}" != "0" ]; then
		log_Err_Abort "rm ${zero_threshold_T1wImage} failed with return_code: ${return_code}"
	fi

	# ----------------------------------------------------------------------
	log_Msg "Creating eye.dat"
	# ----------------------------------------------------------------------
	mridir=${SubjectDIR}/${SubjectID}/mri

	transformsdir=${mridir}/transforms
	mkdir -p ${transformsdir}

	eye_dat_file=${transformsdir}/eye.dat

	log_Msg "...This creates ${eye_dat_file}"
	echo "${SubjectID}" > ${eye_dat_file}
	echo "1" >> ${eye_dat_file}
	echo "1" >> ${eye_dat_file}
	echo "1" >> ${eye_dat_file}
	echo "1 0 0 0" >> ${eye_dat_file}
	echo "0 1 0 0" >> ${eye_dat_file}
	echo "0 0 1 0" >> ${eye_dat_file}
	echo "0 0 0 1" >> ${eye_dat_file}
	echo "round" >> ${eye_dat_file}

	# ----------------------------------------------------------------------
	log_Msg "Making T1w to T2w registration available in FSL format"
	# ----------------------------------------------------------------------

	pushd ${mridir}

	log_Msg "...Create a registration between the original conformed space and the rawavg space"
	tkregister_cmd="tkregister"
	tkregister_cmd+=" --mov orig.mgz"
	tkregister_cmd+=" --targ rawavg.mgz"
	tkregister_cmd+=" --regheader"
	tkregister_cmd+=" --noedit"
	tkregister_cmd+=" --reg deleteme.dat"
	tkregister_cmd+=" --ltaout transforms/orig-to-rawavg.lta"
	tkregister_cmd+=" --s ${SubjectID}"

	log_Msg "......The following produces deleteme.dat and transforms/orig-to-rawavg.lta"
	log_Msg "......tkregister_cmd: ${tkregister_cmd}"

	${tkregister_cmd}
	return_code=$?
	if [ "${return_code}" != "0" ]; then
		log_Err_Abort "tkregister command failed with return_code: ${return_code}"
	fi

	log_Msg "...Concatenate the T1raw-->orig transform with the T2raw-->orig transform"
	mri_concatenate_lta_cmd="mri_concatenate_lta"
	mri_concatenate_lta_cmd+=" transforms/T2raw.lta"
	mri_concatenate_lta_cmd+=" transforms/orig-to-rawavg.lta"
	mri_concatenate_lta_cmd+=" Q.lta"

	log_Msg "......The following concatenates transforms/T2raw.tla and transforms/orig-to-rawavg.lta to get Q.lta"
	log_Msg "......mri_concatenate_lta_cmd: ${mri_concatenate_lta_cmd}"
	${mri_concatenate_lta_cmd}
	return_code=$?
	if [ "${return_code}" != "0" ]; then
		log_Err_Abort "mri_concatenate_lta command failed with return_code: ${return_code}"
	fi

	log_Msg "...Convert to FSL format"
	tkregister_cmd="tkregister"
	tkregister_cmd+=" --mov orig/T2raw.mgz"
	tkregister_cmd+=" --targ rawavg.mgz"
	tkregister_cmd+=" --reg Q.lta"
	tkregister_cmd+=" --fslregout transforms/T2wtoT1w.mat"
	tkregister_cmd+=" --noedit"

	log_Msg "......The following produces the transforms/T2wtoT1w.mat file that we need"
	log_Msg "......tkregister_cmd: ${tkregister_cmd}"

	${tkregister_cmd}
	return_code=$?
	if [ "${return_code}" != "0" ]; then
		log_Err_Abort "tkregister command failed with return_code: ${return_code}"
	fi

	log_Msg "...Clean up"
	rm --verbose deleteme.dat
	rm --verbose Q.lta

	popd

	# ----------------------------------------------------------------------
	log_Msg "Creating white surface files in rawavg space"
	# ----------------------------------------------------------------------

	# Note: The orig-to-rawavg.lta file was created back in the previous
	#       step when we are making the T1w to T2w registration available
	#       in FSL format.
	
	pushd ${mridir}

	mri_surf2surf_cmd="mri_surf2surf"
	mri_surf2surf_cmd+=" --s ${SubjectID}"
	mri_surf2surf_cmd+=" --sval-xyz white"
	mri_surf2surf_cmd+=" --reg transforms/orig-to-rawavg.lta"
	mri_surf2surf_cmd+=" --tval-xyz rawavg.mgz"
	mri_surf2surf_cmd+=" --tval white.deformed"
	mri_surf2surf_cmd+=" --surfreg white"
	mri_surf2surf_cmd+=" --hemi lh"
	mri_surf2surf_cmd+=" --sd ${SubjectDIR}"

	log_Msg "......The following produces the white left hemisphere surface in rawavg space"
	log_Msg "......mri_surf2surf_cmd: ${mri_surf2surf_cmd}"

	${mri_surf2surf_cmd}
	return_code=$?
	if [ "${return_code}" != "0" ]; then
		log_Err_Abort "mri_surf2surf command failed with return_code: ${return_code}"
	fi

	mri_surf2surf_cmd="mri_surf2surf"
	mri_surf2surf_cmd+=" --s ${SubjectID}"
	mri_surf2surf_cmd+=" --sval-xyz white"
	mri_surf2surf_cmd+=" --reg transforms/orig-to-rawavg.lta"
	mri_surf2surf_cmd+=" --tval-xyz rawavg.mgz"
	mri_surf2surf_cmd+=" --tval white.deformed"
	mri_surf2surf_cmd+=" --surfreg white"
	mri_surf2surf_cmd+=" --hemi rh"
	mri_surf2surf_cmd+=" --sd ${SubjectDIR}"

	log_Msg "......The following produces the white right hemisphere surface in rawavg space"
	log_Msg "......mri_surf2surf_cmd: ${mri_surf2surf_cmd}"

	${mri_surf2surf_cmd}
	return_code=$?
	if [ "${return_code}" != "0" ]; then
		log_Err_Abort "mri_surf2surf command failed with return_code: ${return_code}"
	fi

	popd

	# ----------------------------------------------------------------------
	log_Msg "Generating QC file"
	# ----------------------------------------------------------------------
	
	make_t1w_hires_nifti_file "${mridir}"
	
	make_t2w_hires_nifti_file "${mridir}"
	
	make_t1wxtw2_qc_file "${mridir}"
	
	# ----------------------------------------------------------------------
	log_Msg "Completing main functionality"
	# ----------------------------------------------------------------------
}

# Global processing - everything above here should be in a function

g_script_name=$(basename "${0}")

if [ -z "${HCPPIPEDIR}" ]; then
	echo "${g_script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
	exit 1
fi

# Load Function Libraries

# Logging related functions
source ${HCPPIPEDIR}/global/scripts/log.shlib
log_Msg "HCPPIPEDIR: ${HCPPIPEDIR}"

# Show tool versions
show_tool_versions

# Determine whether named or positional parameters are used
if [[ ${1} == --* ]]; then
	# Named parameters (e.g. --parameter-name=parameter-value) are used
	log_Msg "Using named parameters"

	# Get command line options
	# Sets the following parameter variables:
	#   p_subject_dir, p_subject, p_t1w_image, p_t2w_image, p_seed (optional)
	get_options "$@"

	# Invoke main functionality using positional parameters
	#     ${1}               ${2}           ${3}             ${4}             ${5}             ${6}
	main "${p_subject_dir}" "${p_subject}" "${p_t1w_image}" "${p_t1w_brain}" "${p_t2w_image}" "${p_seed}"

else
	# Positional parameters are used
	log_Msg "Using positional parameters"
	main $@

fi

log_Msg "Complete"
exit 0
