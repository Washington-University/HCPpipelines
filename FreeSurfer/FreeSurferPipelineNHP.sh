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

# Configure custom tools
# - Determine if the PATH is configured so that the custom FreeSurfer v6 tools used by this script
#   (the recon-all.v6.hires script and other scripts called by the recon-all.v6.hires script)
#   are found on the PATH. If all such custom scripts are found, then we do nothing here.
#   If any one of them is not found on the PATH, then we change the PATH so that the
#   versions of these scripts found in ${HCPPIPEDIR}/FreeSurfer/custom are used.
configure_custom_tools()
{
	local which_recon_all
	local which_conf2hires
	local which_longmc

	which_recon_all=$(which recon-all.v6.hiresNHP)
	which_conf2hires=$(which conf2hiresNHP)
	which_longmc=$(which longmc)

	if [[ "${which_recon_all}" = "" || "${which_conf2hires}" == "" || "${which_longmc}" = "" ]] ; then
		export PATH="${HCPPIPEDIR}/FreeSurfer/custom:${PATH}"
		log_Warn "We were not able to locate one of the following required tools:"
		log_Warn "recon-all.v6.hires, conf2hires, or longmc"
		log_Warn ""
		log_Warn "To be able to run this script using the standard versions of these tools,"
		log_Warn "we added ${HCPPIPEDIR}/FreeSurfer/custom to the beginning of the PATH."
		log_Warn ""
		log_Warn "If you intended to use some other version of these tools, please configure"
		log_Warn "your PATH before invoking this script, such that the tools you intended to"
		log_Warn "use can be found on the PATH."
		log_Warn ""
		log_Warn "PATH set to: ${PATH}"
	fi	
	PipelineScripts=${HCPPIPEDIR}/FreeSurfer/scripts
}

# Show tool versions
show_tool_versions()
{
	# Show HCP pipelines version
	log_Msg "Showing HCP Pipelines version"
	${HCPPIPEDIR}/show_version

	# Show recon-all version
	log_Msg "Showing recon-all.v6.hiresNHP version"
	local which_recon_all=$(which recon-all.v6.hiresNHP)
	log_Msg ${which_recon_all}
	recon-all.v6.hiresNHP -version
	
	# Show tkregister version
	log_Msg "Showing tkregister version"
	which tkregister
	tkregister -version

	# Show mri_concatenate_lta version
	log_Msg "Showing mri_concatenate_lta version"
	which mri_concatenate_lta
	mri_concatenate_lta -version

	# Show mri_surf2surf version
	log_Msg "Showing mri_surf2surf version"
	which mri_surf2surf
	mri_surf2surf -version

	# Show fslmaths location
	log_Msg "Showing fslmaths location"
	which fslmaths
}

validate_freesurfer_version()
{
	if [ -z "${FREESURFER_HOME}" ]; then
		log_Err_Abort "FREESURFER_HOME must be set"
	fi
	
	freesurfer_version_file="${FREESURFER_HOME}/build-stamp.txt"

	if [ -f "${freesurfer_version_file}" ]; then
		freesurfer_version_string=$(cat "${freesurfer_version_file}")
		log_Msg "INFO: Determined that FreeSurfer full version string is: ${freesurfer_version_string}"
	else
		log_Err_Abort "Cannot tell which version of FreeSurfer you are using."
	fi

	# strip out extraneous stuff from FreeSurfer version string
	freesurfer_version_string_array=(${freesurfer_version_string//-/ })
	freesurfer_version=${freesurfer_version_string_array[5]}
	freesurfer_version=${freesurfer_version#v} # strip leading "v"

	log_Msg "INFO: Determined that FreeSurfer version is: ${freesurfer_version}"

	# break FreeSurfer version into components
	# primary, secondary, and tertiary
	# version X.Y.Z ==> X primary, Y secondary, Z tertiary
	freesurfer_version_array=(${freesurfer_version//./ })

	freesurfer_primary_version="${freesurfer_version_array[0]}"
	freesurfer_primary_version=${freesurfer_primary_version//[!0-9]/}

	freesurfer_secondary_version="${freesurfer_version_array[1]}"
	freesurfer_secondary_version=${freesurfer_secondary_version//[!0-9]/}

	freesurfer_tertiary_version="${freesurfer_version_array[2]}"
	freesurfer_tertiary_version=${freesurfer_tertiary_version//[!0-9]/}

	if [[ $(( ${freesurfer_primary_version} )) -lt 6 ]]; then
		# e.g. 4.y.z, 5.y.z
		log_Err_Abort "FreeSurfer version 6.0.0 or greater is required. (Use FreeSurferPipeline-v5.3.0-HCP.sh if you want to continue using FreeSurfer 5.3)"
	fi
}

# Show usage information
show_usage()
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

  one from the following group is required, unless --existing-subject is set

	 --t1w-image=<path to T1w image>
	 --t1=<path to T1w image>

  one from the following group is required, unless --existing-subject is set

	 --t1w-brain=<path to T1w brain mask>
	 --t1brain=<path to T1w brain mask>

  one from the following group is required, unless --existing-subject is set

	 --t2w-image=<path to T2w image>
	 --t2=<path to T2w image>

  --species=<Chimp|MacaqueCyno|MacaqueRhes|MacaqueFusc|NightMonkey|Marmoset>

  [--seed=<recon-all seed value>]

  [--flair]  (experimental)
      Indicates that recon-all is to be run with the -FLAIR/-FLAIRpial options
      (rather than the -T2/-T2pial options).
      The FLAIR input image itself should still be provided via the '--t2' argument.

  [--existing-subject]
      This flag allows for the application of FreeSurfer edits using extra-reconall-args. This is automatically set ON if
      --runmode of >1 was specified. 

  [--extra-reconall-arg=token] (repeatable)
      Generic single token (no whitespace) argument to pass to recon-all.
      Provides a mechanism to:
         (i) customize the recon-all command
         (ii) specify the recon-all stage(s) to be run (e.g., in the case of FreeSurfer edits)
      If you want to avoid running all the stages inherent to the '-all' flag in recon-all,
         you also need to include the --existing-subject flag.
      The token itself may include dashes and equal signs (although Freesurfer doesn't currently use
         equal signs in its argument specification).
         e.g., [--extra-reconall-arg=-3T] is the correct syntax for adding the stand-alone "-3T" flag to recon-all.
               But, [--extra-reconall-arg="-norm3diters 3"] is NOT acceptable.
      For recon-all flags that themselves require an argument, you can handle that by specifying
         --extra-reconall-arg multiple times (in the proper sequential fashion).
         e.g., [--extra-reconall-arg=-norm3diters --extra-reconall-arg=3]
         will be translated to "-norm3diters 3" when passed to recon-all

  [--no-conf2hires]
      Indicates that the script should NOT include -conf2hires as an argument to recon-all.
         By default, -conf2hires *IS* included, so that recon-all will place the surfaces on the 
         hires T1 (and T2).
         This is an advanced option, intended for situations where:
            (i) the original T1w and T2w images are NOT "hires" (i.e., they are 1 mm isotropic or worse), or
            (ii) you want to be able to run some flag in recon-all, without also regenerating the surfaces.
                 e.g., [--existing-subject --extra-reconall-arg=-show-edits --no-conf2hires]

  [--processing-mode=(HCPStyleData|LegacyStyleData)]
      Controls whether the HCP acquisition and processing guidelines should be treated as requirements.
      "HCPStyleData" (the default) follows the processing steps described in Glasser et al. (2013) 
         and requires 'HCP-Style' data acquistion. 
      "LegacyStyleData" allows additional processing functionality and use of some acquisitions
         that do not conform to 'HCP-Style' expectations.
         In this script, it allows not having a high-resolution T2w image.

  [--runmode=(1|2|3)]
      Run mode controls the step of FreeSurferPIpelineNHP (1: run all (default), 2: FSwhite, 3: FSfinish)
      For rum mode 2, wm.edit.mgz may be saved in the FS/mri directory, then this pipeline use it for reestimating
      white surfaces. Note that run mode 2 and 3 will set existing-subject=TRUE and that flags for stage(s) in 
      --extra-reconall-arg will be ignored.
  
PARAMETERs can also be specified positionally as:

  ${g_script_name} <path to subject directory> <subject ID> <path to T1w image> <path to T1w brain mask> <path to T2w image> [<recon-all seed value>]

  Note that the positional approach to specifying parameters does NOT support the 
      --existing-subject, --extra-reconall-arg, --no-conf2hires, and --processing-mode options.
  The positional approach should be considered deprecated, and may be removed in a future version.

EOF
}

get_options()
{
	local arguments=($@)
	# Note that the ($@) construction parses the arguments into an array of values using spaces as the delimiter

	# initialize global output variables
	unset p_subject_dir
	unset p_subject
	unset p_t1w_image
	unset p_t1w_brain
	unset p_t2w_image
	unset p_seed
	unset p_flair
	unset p_existing_subject
	unset p_extra_reconall_args
	unset p_runmode
	p_conf2hires="TRUE"  # Default is to include -conf2hires flag; do NOT make this variable 'local'

	# parse arguments
	local num_args=${#arguments[@]}
	local argument
	local index=0
	local extra_reconall_arg

	while [ "${index}" -lt "${num_args}" ]; do
		argument=${arguments[index]}

		case ${argument} in
			--help)
				show_usage
				exit 0
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
			--flair)
				p_flair="TRUE"
				index=$(( index + 1 ))
				;;
			--existing-subject)
				p_existing_subject="TRUE"
				index=$(( index + 1 ))
				;;
			--extra-reconall-arg=*)
				extra_reconall_arg=${argument#*=}
				p_extra_reconall_args+="${extra_reconall_arg} "
				index=$(( index + 1 ))
				;;
			--processing-mode=*)
				p_processing_mode=${argument#*=}
				index=$(( index + 1 ))
				;;
			--no-conf2hires)
				p_conf2hires="FALSE"
				index=$(( index + 1 ))
				;;
			--species=*)
				p_species=${argument#*=}
				index=$(( index + 1 ))
				;;						
			--runmode=*)
				p_runmode=${argument#*=}
				index=$(( index + 1 ))
				;;			
			*)
				show_usage
				log_Err_Abort "unrecognized option: ${argument}"
				;;
		esac

	done

	local error_count=0

	# ------------------------------------------------------------------------------
	#  Compliance check
	# ------------------------------------------------------------------------------
	
	ProcessingMode=${p_processing_mode:-HCPStyleData}	
    Compliance="HCPStyleData"
    ComplianceMsg=""
    p_runmode=${p_runmode:-1}
    if [ "$p_runmode" -gt 0 ] ; then
        p_existing_subject="TRUE"
    fi
    
    # -- T2w image

    if [ -z "${p_t2w_image}" ] || [ "${p_t2w_image}" = "NONE" ]; then
        if [ -z "${p_existing_subject}" ]; then
            ComplianceMsg+=" --t2w-image= or --t2= not present or set to NONE"
            Compliance="LegacyStyleData"
        fi
        p_t2w_image="NONE"
    fi

    check_mode_compliance "${ProcessingMode}" "${Compliance}" "${ComplianceMsg}"

	# ------------------------------------------------------------------------------
	#  check required parameters
	# ------------------------------------------------------------------------------

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

	if [ -z "${p_species}" ]; then
		log_Err "Species (--species=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Species: ${p_species}"
	fi

	if [ -z "${p_t1w_image}" ]; then
		if [ -z "${p_existing_subject}" ]; then
			log_Err "T1w Image (--t1w-image= or --t1=) required"
			error_count=$(( error_count + 1 ))
		else
			p_t1w_image="NONE"  # Need something assigned as a placeholder for positional parameters
		fi
	else
		log_Msg "T1w Image: ${p_t1w_image}"
	fi

	if [ -z "${p_t1w_brain}" ]; then
		if [ -z "${p_existing_subject}" ]; then
			log_Err "T1w Brain (--t1w-brain= or --t1brain=) required"
			error_count=$(( error_count + 1 ))
		else
			p_t1w_brain="NONE"  # Need something assigned as a placeholder for positional parameters
		fi
	else
		log_Msg "T1w Brain: ${p_t1w_brain}"
	fi


	# NOTE: Check for T2w image has moved upwards, as missing T2w is allowed in LegacyStyleData processing mode.


	# show optional parameters if specified
	if [ ! -z "${p_seed}" ]; then
		log_Msg "Seed: ${p_seed}"
	fi
	if [ ! -z "${p_flair}" ]; then
		log_Msg "FLAIR (using -FLAIR/-FLAIRpial rather than -T2/-T2pial in recon-all): ${p_flair}"
	fi
	if [ ! -z "${p_existing_subject}" ]; then
		log_Msg "Existing subject (exclude -all, -i, -T2/-FLAIR, and -emregmask flags from recon-all): ${p_existing_subject}"
	fi
	if [ ! -z "${p_extra_reconall_args}" ]; then
		log_Msg "Extra recon-all arguments: ${p_extra_reconall_args}"
	fi
	if [ ! -z "${p_conf2hires}" ]; then
		log_Msg "Include -conf2hires flag in recon-all: ${p_conf2hires}"
	fi
	if [ ! -z "${p_processing_mode}" ] ; then
  		log_Msg "ProcessingMode: ${p_processing_mode}"
	fi

	if [ ! -z "${p_rundmode}" ] ; then
		log_Msg "RunMode: ${p_rundmode}"
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
	local t2_or_flair

	working_dir="${1}"

	pushd "${working_dir}"

	if [ "${p_flair}" = "TRUE" ]; then
		t2_or_flair="FLAIR"
	else
		t2_or_flair="T2"
	fi

	# The rawavg.${t2_or_flair}.prenorm.mgz file must exist.
	# Then we need to move (resample) it to
	# the target volume and convert it to NIFTI format.

	t2w_input_file="rawavg.${t2_or_flair}.prenorm.mgz"
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
make_t1wxt2w_qc_file()
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

#main()

FSsetup ()
{
#	local SubjectDIR
#	local SubjectID
#	local T1wImage
#	local T1wImageBrain
#	local T2wImage
#	local recon_all_seed
#	local flair="FALSE"
#	local existing_subject="FALSE"
#	local extra_reconall_args
#	local conf2hires="TRUE"

#	local num_cores
#	local zero_threshold_T1wImage
#	local return_code
#	local recon_all_cmd
#	local mridir
#	local transformsdir
#	local eye_dat_file

#	local tkregister_cmd
#	local mri_concatenate_lta_cmd
#	local mri_surf2surf_cmd
#	local t2_or_flair

	T2wtoT1wFile="T2wtoT1w.mat"      # Calling this file T2wtoT1w.mat regardless of whether the input to recon-all was -T2 or -FLAIR
	OutputOrigT1wToT1w="OrigT1w2T1w" # Needs to match name used in PostFreeSurfer (N.B. "OrigT1" here refers to the T1w/T1w.nii.gz file; NOT FreeSurfer's "orig" space)

	# ----------------------------------------------------------------------
	log_Msg "Starting main functionality"
	# ----------------------------------------------------------------------

	# Species-specific environments
	# Environments
	# Following variables need to be set by SetUpHCPPipeline.sh
	# TemplateWMSkeleton : white matter skeleon for each species
	
	IntensityCor=FAST
	if [ "$TemplateWMSkeleton" = "" ] ; then
		TemplateWMSkeleton=NONE
	fi 

	if [[ $SPECIES =~ Human ]] ; then
		ScaleFactor=1
		mri_segment_args=""		
		mri_fill_args=""
		MMnormSigma=""
		VariableSigma=""
		PialSigma=""
		SmoothNiter=""
		NSigmaAbove=""
		NSigmaBelow=""		
		WMProjAbs="2"	
		BiasFieldFastSmoothingSigma=""  # = 20*$ScaleFactor
		FSAverageDir="${FREESURFER_HOME}/average"
		GCA="RB_all_2016-05-10.vc700.gca"
		AvgCurvTif="average.curvature.filled.buckner40.tif"
	elif [[ $SPECIES =~ Chimp ]] ; then
		ScaleFactor=1.25
		mri_segment_args=""		
		mri_fill_args="-C 0 -8 21"          # mm coordinate in orig.mgz and wm.mgz
		mris_inflate_args="-n 250"
		MMnormSigma="10"
		VariableSigma="3"
		PialSigma="2"
		SmoothNiter="1"
		NSigmaAbove="2"
		NSigmaBelow="3"
		WMProjAbs="1"		
		BiasFieldFastSmoothingSigma=20  # = 20*$ScaleFactor
		FSAverageDir=$HCPPIPEDIR/global/templates/ChimpYerkes29
		GCA="RB_all_2016-05-10.vc700.gca"
		AvgCurvTif="average.curvature.filled.buckner40.tif"

	elif [[ $SPECIES =~ Macaque ]] ; then 
		ScaleFactor=2
		WMSeg_wlo="95"      # 105 for T2w Unnorm data (A16 A17 macaque data) 
		WMSeg_ghi="100"  
		#WMSeg_wlo="100"    # for high res T1w/FLAIR data 
		#WMSeg_ghi="105"    # for high res T1w/FLAIR data
		mri_segment_args="-wlo $WMSeg_wlo -ghi $WMSeg_ghi"
		mri_fill_args="-C 0 -3 8 -fillven 1 -topofix norm.mgz"      # mm coordinate in orig.mgz and wm.mgz
		mris_inflate_args="-n 250"
		mris_smooth_args=""
		mris_sphere_args=" -RADIUS 55 -remove_negative 1"
		mris_make_surfaces_args="-wlo $WMSeg_wlo -ghi $WMSeg_ghi"
		MMnormSigma="20"
		VariableSigma="6"   # NHP_NNP 6 
		PialSigma="4"       # NHP_NNP 4
		SmoothNiter="3"
		if [ "${p_flair}" != "TRUE" ] ; then	# control T2 pial
			NSigmaAbove="2"
			NSigmaBelow="3"
		else						# control T2-FLAIR pial
			PialSigma="6"       		# tuned for hires (0.32mm) FLAIR 
			NSigmaAbove="4"			# tuned for hires (0.32mm) FLAIR
			NSigmaBelow="3"
		fi		
		WMProjAbs="0.7"
		BiasFieldFastSmoothingSigma=40   # = 20*$ScaleFactor but 8> 10 >> 40 for A16101401, 20 is the best among 5,10,20,40 for A21051401
		if [ $SPECIES = MacaqueCyno ] ; then
			FSAverageDir=$HCPPIPEDIR/global/templates/NHP_NNP/SpecMac25Cyno/fsaverage
		elif [ $SPECIES = MacaqueRhes ] ; then
			FSAverageDir=$HCPPIPEDIR/global/templates/NHP_NNP/SpecMac25Rhesus/fsaverage
		elif [ $SPECIES = MacaqueFusc ] ; then
			FSAverageDir=$HCPPIPEDIR/global/templates/NHP_NNP/SpecMac6Snow/fsaverage
		fi
		GCA="RB_all_2016-05-10.vc700.gca"
		AvgCurvTif="average.curvature.filled.buckner40.tif"
		
	elif [[ $SPECIES =~ NightMonkey ]] ; then
		ScaleFactor=4
		mri_segment_args=""
		mri_fill_args="-C 0 -15 21 -fillven 1 -topofix norm.mgz"
		mris_inflate_args="-n 250"
		mris_smooth_args=""
		mris_sphere_args=" -RADIUS 35 -remove_negative 1"
		MMnormSigma="30"
		VariableSigma="9"
		PialSigma="6"
		SmoothNiter="5"
		if [ "${p_flair}" != "TRUE" ] ; then  # pial adjustment with T2w in conf2hires
			NSigmaAbove="3"    # 2: FS6 default, 3: NHP_NHP
			NSigmaBelow="4"    # 2: FS6 default, 4: NHP_NNP
		else
			NSigmaAbove="3"
			NSigmaBelow="3"
		fi		
		WMProjAbs="0.5"		
		BiasFieldFastSmoothingSigma=80
		FSAverageDir=$HCPPIPEDIR/global/templates/BICAN/NightMonkey/fsaverage
		GCA="RB_all_2016-05-10.vc700.gca"
		AvgCurvTif="average.curvature.filled.buckner40.tif"
		
	elif [[ $SPECIES =~ Marmoset ]] ; then
		ScaleFactor=5
		WMSeg_wlo="75"
		WMSeg_ghi="80"		
		mri_segment_args="-wlo $WMSeg_wlo -ghi $WMSeg_ghi"v
		mri_fill_args="-C 0 -3 3 -fillven 1 -topofix norm.mgz"
		mris_inflate_args="-n 250"
		mris_smooth_args=""
		mris_sphere_args=" -RADIUS 15 -remove_negative 1"
		mris_make_surfaces_args="-wlo $WMSeg_wlo -ghi $WMSeg_ghi"
		MMnormSigma="50"
		VariableSigma="20" # 16 is not enough?
		PialSigma="20"  # 10 is not enough?
		SmoothNiter="8"
		if [ "${p_flair}" != "TRUE" ] ; then	# control T2 pial
			NSigmaAbove="3"
			NSigmaBelow="3"
		else						# control T2-FLAIR pial
			NSigmaAbove="3"
			NSigmaBelow="3"
		fi		
		WMProjAbs="0.2"
		mris_register_args="-dist 20 -max_degrees 30"    # to avoid initialization error
		BiasFieldFastSmoothingSigma=100
		FSAverageDir=$HCPPIPEDIR/global/templates/BICAN/Marmoset/fsaverage
		GCA="RB_all_2016-05-10.vc700.gca"	
		AvgCurvTif="average.curvature.filled.buckner40.tif"

	fi

	# ----------------------------------------------------------------------
	log_Msg "Retrieve positional parameters"
	# ----------------------------------------------------------------------
	SubjectDIR="${1}"
	SubjectID="${2}"
	T1wImage="${3}"       # Irrelevant if '--existing-subject' flag is set
	T1wImageBrain="${4}"  # Irrelevant if '--existing-subject' flag is set
	T2wImage="${5}"       # Irrelevant if '--existing-subject' flag is set
	recon_all_seed="${6}"

	RunMode="$p_runmode"
	SPECIES="$p_species"
	
	## MPH: Hack!
	# For backwards compatibility, continue to allow positional specification of parameters for the above set of 6 parameters.
	# But any new parameters/options in the script will only be accessible via a named parameter/flag.
	# Here, we retrieve those from the global variable that was set in get_options()
	if [ "${p_flair}" = "TRUE" ]; then
		flair=${p_flair}
	fi
	if [ "${p_existing_subject}" = "TRUE" ]; then
		existing_subject=${p_existing_subject}
	fi
	if [ ! -z "${p_extra_reconall_args}" ]; then
		extra_reconall_args="${p_extra_reconall_args}"
	fi
	if [ ! -z "${p_conf2hires}" ]; then
		conf2hires=${p_conf2hires}
	fi

	# ----------------------------------------------------------------------
	# Log values retrieved from positional parameters
	# ----------------------------------------------------------------------
	log_Msg "SubjectDIR: ${SubjectDIR}"
	log_Msg "SubjectID: ${SubjectID}"
	log_Msg "T1wImage: ${T1wImage}"
	log_Msg "T1wImageBrain: ${T1wImageBrain}"
	log_Msg "T2wImage: ${T2wImage}"
	log_Msg "recon_all_seed: ${recon_all_seed}"
	log_Msg "flair: ${flair}"
	log_Msg "existing_subject: ${existing_subject}"
	log_Msg "extra_reconall_args: ${extra_reconall_args}"
	log_Msg "conf2hires: ${conf2hires}"
	log_Msg "runmode: ${RunMode}"
	# ----------------------------------------------------------------------
	log_Msg "Figure out the number of cores to use."
	# ----------------------------------------------------------------------
	# Both the SGE and PBS cluster schedulers use the environment variable NSLOTS to indicate the
	# number of cores a job will use. If this environment variable is set, we will use it to
	num_cores=0
	# determine the number of cores to tell recon-all to use.

	if [[ -z ${NSLOTS} ]]; then
		num_cores=8
	else
		num_cores="${NSLOTS}"
	fi
	log_Msg "num_cores: ${num_cores}"

	if [ "${existing_subject}" != "TRUE" ]; then

		# If --existing-subject is NOT set, AND PostFreeSurfer has been run, then
		# certain files need to be reverted to their PreFreeSurfer output versions
		if [ `imtest ${SubjectDIR}/xfms/${OutputOrigT1wToT1w}` = 1 ]; then
			log_Err "The --existing-subject flag was not invoked AND PostFreeSurfer has already been run."
			log_Err "If attempting to run FreeSurfer de novo, certain files (e.g., <subj>/T1w/{T1w,T2w}_acpc_dc*) need to be reverted to their PreFreeSurfer outputs."
			log_Err_Abort "If this is the goal, delete ${SubjectDIR}/${SubjectID} AND re-run PreFreeSurfer, before invoking FreeSurfer again."
		fi
	fi
	
	if [ "${existing_subject}" = "TRUE" ]; then

		if [ -e "$SubjectDIR"/"$SubjectID"_scaled ] ; then
			rm -rf "$SubjectDIR"/"$SubjectID" 
			mv "$SubjectDIR"/"$SubjectID"_scaled "$SubjectDIR"/"$SubjectID"
		fi
		if [ -e "$SubjectDIR"/"$SubjectID"/scripts/IsRunning.lh+rh ] ; then
	  		rm "$SubjectDIR"/"$SubjectID"/scripts/IsRunning.lh+rh
		fi
	fi
		
	# By default, refine pial surfaces using T2 (if T2w image provided).
	# If for some other reason the -T2pial flag needs to be excluded from recon-all, 
	# this can be accomplished using --extra-reconall-arg=-noT2pial
	if [ "${T2wImage}" != "NONE" ]; then
		if [ "${flair}" = "TRUE" ]; then
			recon_all_pial=" -FLAIRpial"
			if [ "$SPECIES" = Human ] ; then 
				recon_all_T2input=" -FLAIR $(remove_ext ${T2wImage}).nii.gz"
			else
				recon_all_T2input=" -FLAIR $(remove_ext ${T2wImage})_scaled.nii.gz"
			fi
			T2Type=FLAIR
		else
			recon_all_pial=" -T2pial"
			if [ "$SPECIES" = Human ] ; then 
				recon_all_T2input=" -T2 $(remove_ext ${T2wImage}).nii.gz"
			else
				recon_all_T2input=" -T2 $(remove_ext ${T2wImage})_scaled.nii.gz"
			fi
			T2Type=T2
		fi
		if [ -e "$SubjectDIR"/"$SubjectID"/mri/transforms/${T2Type}raw.lta ] ; then
			rm "$SubjectDIR"/"$SubjectID"/mri/transforms/${T2Type}raw.lta # remove this otherwise conf2hires will not update this - TH
		fi
	else
			recon_all_T2input=""
			recon_all_pial=""
			T2Type=NONE		
	fi
	
	if [ $SPECIES = Human ] ; then
		HumanProc="-curvstats -avgcurv -parcstats -cortparc2 -parcstats2 -cortparc3 -parcstats3 -pctsurfcon -hyporelabel -aparc2aseg -apas2aseg -segstats -wmparc -balabels"
	else
		HumanProc=""
	fi

	recon_all_cmd="recon-all.v6.hiresNHP"
	recon_all_cmd+=" -subjid ${SubjectID}"
	recon_all_cmd+=" -sd ${SubjectDIR}"
	
	if [ ! -z "${extra_reconall_args}" ]; then
		extra_reconall_args=" ${extra_reconall_args}"
	fi
	extra_reconall_args+=" -openmp ${num_cores}"	
	if [ ! -z "${recon_all_seed}" ]; then
		extra_reconall_args+=" -norandomness -rng-seed ${recon_all_seed}"
	fi
	log_Msg "seed_cmd_appendix: ${seed_cmd_appendix}"

	# The -conf2hires flag should come after the ${extra_reconall_args} string, since it needs
	# to have the "final say" over a couple settings within recon-all
	if [ "${conf2hires}" = "TRUE" ]; then
		conf2hiresflag=" -conf2hires"
	fi

	# expert options
	if [ -e "$SubjectDIR"/"$SubjectID".expert.opts ] ; then
		rm "$SubjectDIR"/"$SubjectID".expert.opts
	fi
	
	for cmd in mri_segment mri_fill mris_inflate mris_smooth mris_make_surfaces mris_register bbregister; do
		cmd_args=${cmd}_args
		if [ ! -z "${!cmd_args}" ] ; then 
			echo "$cmd ${!cmd_args}" >> "$SubjectDIR"/"$SubjectID".expert.opts
		fi
	done
		
	# opts for conf2hires
	if [ ! -z "$MMnormSigma" ] ; then
		c2hxopts=" --mm-norm-sigma $MMnormSigma"
	fi
	if [ ! -z "$VariableSigma" ] ; then
		c2hxopts+=" --variablesigma $VariableSigma"
	fi
	if [ ! -z "$PialSigma" ] ; then
		c2hxopts+=" --psigma $PialSigma"
	fi
	if [ ! -z "$SmoothNiter" ] ; then
		c2hxopts+=" --smooth $SmoothNiter"
	fi
	if [ ! -z "$NSigmaAbove" ] ; then
		c2hxopts+=" --nsigma_above $NSigmaAbove"
	fi
	if [ ! -z "$NSigmaBelow" ] ; then
		c2hxopts+=" --nsigma_below $NSigmaBelow"
	fi
	if [ ! -z "$WMProjAbs" ] ; then
		c2hxopts+=" --wm-proj-abs $WMProjAbs"
	fi
	if [ ! -z "$WMSeg_wlo" ] ; then
		c2hxopts+=" --wlo $WMSeg_wlo"
	fi
	if [ ! -z "$WMSeg_ghi" ] ; then
		c2hxopts+=" --ghi $WMSeg_ghi"
	fi
	if [ ! -z "$c2hxopts" ] ; then
		echo "conf2hiresNHP $c2hxopts" >> "$SubjectDIR"/"$SubjectID".expert.opts
	fi
	ExpertOpts="-expert "$SubjectDIR"/"$SubjectID".expert.opts -xopts-overwrite"
}

FSinit ()
{

#	if [ "${existing_subject}" != "TRUE" ]; then

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

		if [ "$SPECIES" = Human ] ; then
			recon_all_T1input=" -i ${zero_threshold_T1wImage}"
			recon_all_T1braininput=" -emregmask $(remove_ext ${T1wImageBrain}).nii.gz"	
		else
			## This section imports NHP data and scales them so that FreeSurfer 6 can work properly in scaled space. The data will be
			## rescaled to the original space by a script, RescaleVolumeAndSurface.sh, after FS was finished - TH 2017-2023 
			log_Msg "Scale T1w brain volume"		
			"$PipelineScripts"/ScaleVolume.sh "${zero_threshold_T1wImage}" "$ScaleFactor" $(remove_ext ${T1wImage})_scaled "$SubjectDIR"/xfms/real2fs.world.mat
			"$PipelineScripts"/ScaleVolume.sh "$T1wImageBrain" "$ScaleFactor" $(remove_ext ${T1wImageBrain})_scaled 
			recon_all_T1input=" -i $(remove_ext ${T1wImage})_scaled.nii.gz"
			recon_all_T1braininput=" -emregmask $(remove_ext ${T1wImageBrain})_scaled.nii.gz"
		fi

		if [ "${T2wImage}" != "NONE" ] ; then
			log_Msg "Scale T2w volume"
			"$PipelineScripts"/ScaleVolume.sh "$T2wImage" "$ScaleFactor" $(remove_ext ${T2wImage})_scaled
		fi
#	fi

	# ----------------------------------------------------------------------
	log_Msg "Call custom recon-all: recon-all.v6.hires"
	# ----------------------------------------------------------------------
	
	if [ -e "$SubjectDIR"/"$SubjectID" ] ; then
		rm -rf "$SubjectDIR"/"$SubjectID"
	fi
	
	recon_all_initrun=" -motioncor"
	recon_all_initrun+="$recon_all_T1input"
	recon_all_initrun+="$recon_all_T1braininput"
	recon_all_initrun+="$recon_all_T2input"

	log_Msg "...recon_all_cmd: ${recon_all_cmd} ${recon_all_initrun} ${extra_reconall_args}"
	${recon_all_cmd} ${recon_all_initrun} ${extra_reconall_args}
	return_code=$?
	if [ "${return_code}" != "0" ]; then
		log_Err_Abort "recon-all command failed with return_code: ${return_code}"
	fi

	fslmaths $(remove_ext ${T1wImageBrain})_scaled.nii.gz -thr 0 "$SubjectDIR"/"$SubjectID"/mri/brainmask.orig.nii.gz
	mri_convert "$SubjectDIR"/"$SubjectID"/mri/brainmask.orig.nii.gz "$SubjectDIR"/"$SubjectID"/mri/brainmask.conf.mgz --conform

	## This section replaces 'FS -nuintensirycor' for NHP - TH 2017-2023			
	"$PipelineScripts"/IntensityCor.sh "$SubjectDIR"/"$SubjectID"/mri/orig.mgz "$SubjectDIR"/"$SubjectID"/mri/brainmask.conf.mgz "$SubjectDIR"/"$SubjectID"/mri/nu.mgz -t1 -m "$IntensityCor" "$BiasFieldFastSmoothingSigma"
	log_Msg "Second recon-all steps for normaliztion 1"
	${recon_all_cmd} -normalization ${extra_reconall_args}

	## This section replaces 'FS -skullstrip' for NHP
	mri_mask "$SubjectDIR"/"$SubjectID"/mri/nu.mgz "$SubjectDIR"/"$SubjectID"/mri/brainmask.conf.mgz "$SubjectDIR"/"$SubjectID"/mri/brainmask.mgz
	
	log_Msg "Third recon-all steps for registration, normalization and segmentation with GCA"
	${recon_all_cmd} -gcareg -canorm -careg -calabel -gca-dir $FSAverageDir -gca $GCA -normalization2 -maskbfs ${extra_reconall_args}
	
}

FSwhite () 
{

	log_Msg "Run SubcortSegment.sh" 
	## This section adds function of'recon-all -segmentation' for creating improved wm.mgz in NHP
	## Paste claustrum and deweight cortical gray in wm.mgz. If wm.edit.mgz, or brain.edit.mgz or aseg.edit.mgz was found, the script
	## uses as wm.mgz, brainmask.mnz, and aseg.mgz respectively - TH 2017-2023
	"$PipelineScripts"/SubcortSegment.sh "$SubjectDIR" "$SubjectID" "$T1wImage" "$TemplateWMSkeleton" "$SubjectDIR"/xfms/real2fs.world.mat "$mri_segment_args"

	log_Msg "Fourth recon-all steps for white"
	${recon_all_cmd} -fill -tessellate -smooth1 -inflate1 -qsphere -fix -white -smooth2 -inflate2 -curvHK -sphere -surfreg -avgcurvtifpath $FSAverageDir -avgcurvtif $AvgCurvTif -jacobian_white -cortparc  ${extra_reconall_args} ${ExpertOpts}

}

FSpial ()
{
	if [ ! "$SPECIES" = Human ] ; then
		log_Msg "Rescale volume and surface to native space"
		"$PipelineScripts"/RescaleVolumeAndSurface.sh "$SubjectDIR" "$SubjectID" "$SubjectDIR"/xfms/real2fs.world.mat "$T1wImage" "$T2wImage" "$T2Type"
	fi

	${recon_all_cmd} -cortribbon ${recon_all_pial} ${ExpertOpts} ${conf2hiresflag}
	# ----------------------------------------------------------------------
	log_Msg "Generating QC file" in scaled space
	# ----------------------------------------------------------------------
	mridir=${SubjectDIR}/${SubjectID}/mri

	make_t1w_hires_nifti_file "${mridir}"

	if [ "${T2wImage}" != "NONE" ]; then

		make_t2w_hires_nifti_file "${mridir}"

		make_t1wxt2w_qc_file "${mridir}"
	fi

}

FSfinish () 
{

	if [ "$SPECIES" = Human ] ; then
		log_Msg "CurvStat, CortParc etc for Human"
		${recon_all_cmd} -curvstats -avgcurv -parcstats -cortparc2 -parcstats2 -cortparc3 -parcstats3 -pctsurfcon -hyporelabel -aparc2aseg -apas2aseg -segstats -wmparc -balabels
	fi
	
	if [ "${existing_subject}" != "TRUE" ]; then
		# ----------------------------------------------------------------------
		log_Msg "Clean up file: ${zero_threshold_T1wImage}"
		# ----------------------------------------------------------------------
		rm ${zero_threshold_T1wImage}
		return_code=$?
		if [ "${return_code}" != "0" ]; then
			log_Err_Abort "rm ${zero_threshold_T1wImage} failed with return_code: ${return_code}"
		fi

	fi

	## MPH: Portions of the following are unnecesary in the case of ${existing_subject} = "TRUE"
	## but rather than identify what is and isn't strictly necessary (which itself may interact
	## with the specific stages run in recon-all), we'll simply run it all to be safe that all
	## files created following recon-all are appropriately updated
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

	if [ "${T2wImage}" != "NONE" ]; then
		# ----------------------------------------------------------------------
		log_Msg "Making T2w to T1w registration available in FSL format"
		# ----------------------------------------------------------------------

		pushd ${mridir}

		if [ "${flair}" = "TRUE" ]; then
			t2_or_flair="FLAIR"
		else
			t2_or_flair="T2"
		fi

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

		log_Msg "...Concatenate the ${t2_or_flair}raw->orig and orig->rawavg transforms"
		mri_concatenate_lta_cmd="mri_concatenate_lta"
		mri_concatenate_lta_cmd+=" transforms/${t2_or_flair}raw.lta"
		mri_concatenate_lta_cmd+=" transforms/orig-to-rawavg.lta"
		mri_concatenate_lta_cmd+=" Q.lta"

		log_Msg "......The following concatenates transforms/${t2_or_flair}raw.lta and transforms/orig-to-rawavg.lta to get Q.lta"
		log_Msg "......mri_concatenate_lta_cmd: ${mri_concatenate_lta_cmd}"
		${mri_concatenate_lta_cmd}
		return_code=$?
		if [ "${return_code}" != "0" ]; then
			log_Err_Abort "mri_concatenate_lta command failed with return_code: ${return_code}"
		fi

		log_Msg "...Convert to FSL format"
		tkregister_cmd="tkregister"
		tkregister_cmd+=" --mov orig/${t2_or_flair}raw.mgz"
		tkregister_cmd+=" --targ rawavg.mgz"
		tkregister_cmd+=" --reg Q.lta"
		tkregister_cmd+=" --fslregout transforms/${T2wtoT1wFile}"
		tkregister_cmd+=" --noedit"

		log_Msg "......The following produces the transforms/${T2wtoT1wFile} file that we need"
		log_Msg "......tkregister_cmd: ${tkregister_cmd}"

		${tkregister_cmd}
		return_code=$?
		if [ "${return_code}" != "0" ]; then
			log_Err_Abort "tkregister command failed with return_code: ${return_code}"
		fi

		log_Msg "...Clean up"
		rm deleteme.dat
		rm Q.lta

		popd
	fi

	# ----------------------------------------------------------------------
	log_Msg "Creating white surface files in rawavg space"
	# ----------------------------------------------------------------------

	pushd ${mridir}
	
	export SUBJECTS_DIR="$SubjectDIR"
	
	reg=$mridir/transforms/orig2rawavg.dat
	# generate registration between conformed and hires based on headers
	# Note that the convention of tkregister2 is that the resulting $reg is the registration
	# matrix that maps from the "--targ" space into the "--mov" space. 
	
	tkregister2 --mov ${mridir}/rawavg.mgz --targ ${mridir}/orig.mgz --noedit --regheader --reg $reg
	
	#The ?h.white.deformed surfaces are used in FreeSurfer BBR registrations for fMRI and diffusion and have been moved into the HCP's T1w space so that BBR produces a transformation containing only the minor adjustment to the registration.  
	mri_surf2surf --s ${SubjectID} --sval-xyz white --reg $reg --tval-xyz ${mridir}/rawavg.mgz --tval white.deformed --surfreg white --hemi lh
	return_code=$?
	if [ "${return_code}" != "0" ]; then
		log_Err_Abort "mri_surf2surf command for left hemisphere failed with return_code: ${return_code}"
	fi
	
	mri_surf2surf --s ${SubjectID} --sval-xyz white --reg $reg --tval-xyz ${mridir}/rawavg.mgz --tval white.deformed --surfreg white --hemi rh
	return_code=$?
	if [ "${return_code}" != "0" ]; then
		log_Err_Abort "mri_surf2surf command for right hemisphere failed with return_code: ${return_code}"
	fi
	
	popd
	
	# ----------------------------------------------------------------------
	log_Msg "Generating QC file"
	# ----------------------------------------------------------------------

	make_t1w_hires_nifti_file "${mridir}"

	if [ "${T2wImage}" != "NONE" ]; then

		make_t2w_hires_nifti_file "${mridir}"

		make_t1wxt2w_qc_file "${mridir}"
	fi

	# ----------------------------------------------------------------------
	log_Msg "Completing main functionality"
	# ----------------------------------------------------------------------
}

main () 
{

	FSsetup $@ 
	if   [ "$RunMode" = 1 ] ; then
		FSinit; FSwhite; FSpial; FSfinish
	elif [ "$RunMode" = 2 ] ; then
		log_Msg "RunMode 2: run FSwhite"
		        FSwhite; FSpial; FSfinish
	elif [ "$RunMode" = 3 ] ; then
		log_Msg "RunMode 3: run FSpial"
		                 FSpial; FSfinish
	elif [ "$RunMode" = 4 ] ; then
		log_Msg "RunMode 4: run FSfinish"
		                         FSfinish
	fi
}


# Global processing - everything above here should be in a function

g_script_name=$(basename "${0}")

# Allow script to return a Usage statement, before any other output or checking
if [ "$#" = "0" ]; then
    show_usage
    exit 1
fi

# ------------------------------------------------------------------------------
#  Check that HCPPIPEDIR is defined and Load Function Libraries
# ------------------------------------------------------------------------------

if [ -z "${HCPPIPEDIR}" ]; then
	echo "${g_script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
	exit 1
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source ${HCPPIPEDIR}/global/scripts/opts.shlib                 # Command line option functions
source ${HCPPIPEDIR}/global/scripts/processingmodecheck.shlib  # Check processing mode requirements

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
	show_usage
	exit 0
fi

${HCPPIPEDIR}/show_version

# ------------------------------------------------------------------------------
#  Verify required environment variables are set and log value
# ------------------------------------------------------------------------------

log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FREESURFER_HOME

# Platform info
log_Msg "Platform Information Follows: "
uname -a

# Configure the use of FreeSurfer v6 custom tools
configure_custom_tools

# Show tool versions
show_tool_versions

# Validate version of FreeSurfer in use
validate_freesurfer_version

# Determine whether named or positional parameters are used
if [[ ${1} == --* ]]; then
	# Named parameters (e.g. --parameter-name=parameter-value) are used
	log_Msg "Using named parameters"

	# Get command line options
	# Sets the following parameter variables:
	#   p_subject_dir, p_subject, p_t1w_image, p_t2w_image, p_seed (optional)
	get_options "$@"

	# Invoke main functionality using positional parameters
	#     ${1}                 ${2}              ${3}               ${4}                ${5}               ${6}        
	main "${p_subject_dir}" "${p_subject}" "${p_t1w_image}" "${p_t1w_brain}" "${p_t2w_image}" "${p_seed}"

else
	# Positional parameters are used
	log_Msg "Using positional parameters"
	main $@

fi

log_Msg "Completed!"
exit 0
