#!/bin/bash 

#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # FreeSurferPipeline.sh
#
# ## Copyright Notice
#
# Copyright (C) 2015-2017 The Human Connectome Project/Connectome Coordination Facility
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
	cat "${HCPPIPEDIR}"/version.txt

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

main()
{
	log_Msg "Starting main functionality"

	# Retrieve positional parameters
	local SubjectDIR="${1}"
	local SubjectID="${2}"
	local T1wImage="${3}"
	local T1wImageBrain="${4}"
	local T2wImage="${5}"
	local recon_all_seed="${6}"

	# Log values retrieved from positional parameters
	log_Msg "SubjectDIR: ${SubjectDIR}"
	log_Msg "SubjectID: ${SubjectID}"
	log_Msg "T1wImage: ${T1wImage}"
	log_Msg "T1wImageBrain: ${T1wImageBrain}"
	log_Msg "T2wImage: ${T2wImage}"
	log_Msg "recon_all_seed: ${recon_all_seed}"
	
	# Figure out the number of cores to use.
	# Both the SGE and PBS cluster schedulers use the environment variable NSLOTS to indicate the
	# number of cores a job will use. If this environment variable is set, we will use it to
	# determine the number of cores to tell recon-all to use.

	local num_cores=0
	if [[ -z ${NSLOTS} ]]; then
		num_cores=8
	else
		num_cores="${NSLOTS}"
	fi
	log_Msg "num_cores: ${num_cores}"
	
	# Call recon-all
	recon_all_cmd="recon-all.v6.hires"
	recon_all_cmd+=" -i ${T1wImage}"
	recon_all_cmd+=" -emregmask ${T1wImageBrain}"
	recon_all_cmd+=" -T2 ${T2wImage}"
	recon_all_cmd+=" -subjid ${SubjectID}"
	recon_all_cmd+=" -sd ${SubjectDIR}"
	recon_all_cmd+=" -hires"
	recon_all_cmd+=" -openmp ${num_cores}"
	recon_all_cmd+=" -all"
	recon_all_cmd+=" -T2pial"
	
	if [ ! -z "${recon_all_seed}" ]; then
		recon_all_cmd+=" -norandomness -rng-seed ${recon_all_seed}"
	fi

	log_Msg "recon_all_cmd: ${recon_all_cmd}"
	${recon_all_cmd}
	return_code=$?
	if [ "${return_code}" != "0" ]; then
		log_Err_Abort "recon-all command failed with return_code: ${return_code}"
	fi
	
	mridir=${SubjectDIR}/${SubjectID}/mri
	log_Msg "Creating ${mridir}/transforms/eye.dat"
	mkdir -p ${mridir}/transforms

	echo "${SubjectID}" > "${mridir}"/transforms/eye.dat
	echo "1" >> "${mridir}"/transforms/eye.dat
	echo "1" >> "${mridir}"/transforms/eye.dat
	echo "1" >> "${mridir}"/transforms/eye.dat
	echo "1 0 0 0" >> "${mridir}"/transforms/eye.dat
	echo "0 1 0 0" >> "${mridir}"/transforms/eye.dat
	echo "0 0 1 0" >> "${mridir}"/transforms/eye.dat
	echo "0 0 0 1" >> "${mridir}"/transforms/eye.dat
	echo "round" >> "${mridir}"/transforms/eye.dat

	log_Msg "Making T1w to T2w registration available in FSL format"
	
	pushd ${mridir}

	log_Msg "...Create a registration between the original conformed space and the rawavg space"
	# This produces deleteme.data and P.lta
	log_Msg "cmd: tkregister --targ rawavg.mgz --mov orig.mgz --regheader --reg deleteme.dat --ltaout P.lta --noedit"
	tkregister --targ rawavg.mgz --mov orig.mgz --regheader --reg deleteme.dat --ltaout P.lta --noedit
	return_code=$?
	if [ "${return_code}" != "0" ]; then
		log_Err_Abort "tkregister command failed with return_code: ${return_code}"
	fi

	log_Msg "...Concatenate the T1raw-->orig transform with the T2raw-->orig transform"
	# This concatenates transforms/T2raw.tla and P.lta to get Q.lta
	log_Msg "cmd: mri_concatenate_lta transforms/T2raw.lta P.lta Q.lta"
	mri_concatenate_lta transforms/T2raw.lta P.lta Q.lta
	return_code=$?
	if [ "${return_code}" != "0" ]; then
		log_Err_Abort "mri_concatenate_lta command failed with return_code: ${return_code}"
	fi

	log_Msg "...Convert to FSL format"
	# This produces the ${mridir}/transforms/T2wtoT1w.mat file that we need
	log_Msg "cmd: tkregister --mov orig/T2raw.mgz --targ rawavg.mgz --reg Q.lta --fslregout transforms/T2wtoT1w.mat --noedit"
	tkregister --mov orig/T2raw.mgz --targ rawavg.mgz --reg Q.lta --fslregout transforms/T2wtoT1w.mat --noedit
	return_code=$?
	if [ "${return_code}" != "0" ]; then
		log_Err_Abort "tkregister command failed with return_code: ${return_code}"
	fi

	log_Msg "...clean up"
	rm --verbose deleteme.dat
	rm --verbose P.lta
	rm --verbose Q.lta
	
	popd 

	log_Msg "Generating QC file"
	log_Msg "cmd: fslmaths ${mridir}/T1w_hires.nii.gz -mul ${mridir}/T2w_hires.nii.gz -sqrt ${mridir}/T1wMulT2w_hires.nii.gz"
	fslmaths ${mridir}/T1w_hires.nii.gz -mul ${mridir}/T2w_hires.nii.gz -sqrt ${mridir}/T1wMulT2w_hires.nii.gz
	return_code=$?
	if [ "${return_code}" -ne "0" ]; then
		log_Err_Abort "fslmaths command failed with return_code: ${return_code}"
	fi
	
	log_Msg "Completing main functionality"
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
