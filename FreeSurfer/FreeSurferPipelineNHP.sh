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


#  Define Sources and pipe-dir
# -----------------------------------------------------------------------------------

set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "${HCPPIPEDIR}/global/scripts/processingmodecheck.shlib"  # Check processing mode requirements

#process legacy syntax and repeatable arguments
if (($# > 0))
then
    newargs=()
    origargs=("$@")
    extra_reconall_args_manual=()
    changeargs=0
    for ((i = 0; i < ${#origargs[@]}; ++i))
    do
        case "${origargs[i]}" in
            (--flair)
                #--flair true and similar works as-is, detect it and copy it as-is, but don't trigger the argument change
                if ((i + 1 < ${#origargs[@]})) && (opts_StringToBool "${origargs[i + 1]}" &> /dev/null)
                then
                    newargs+=(--flair "${origargs[i + 1]}")
                    #skip the boolean value, we took care of it
                    i=$((i + 1))
                else
                    newargs+=(--flair=TRUE)
                    changeargs=1
                fi
                ;;
            (--existing-session|--existing-subject)
                #same logic
                if ((i + 1 < ${#origargs[@]})) && (opts_StringToBool "${origargs[i + 1]}" &> /dev/null)
                then
                    newargs+=(--existing-subject "${origargs[i + 1]}")
                    i=$((i + 1))
                else
                    newargs+=(--existing-subject=TRUE)
                    changeargs=1
                fi
                ;;
            (--no-conf2hires)
                #this doesn't match a new argument, so we can just replace it
                newargs+=(--conf2hires=FALSE)
                changeargs=1
                ;;
            (--extra-reconall-arg=*)
                #repeatable options aren't yet a thing in newopts (indirect assignment to arrays seems to need eval)
                #figure out whether these extra arguments could have a better syntax (if whitespace is supported, probably not)
                extra_reconall_args_manual+=("${origargs[i]#*=}")
                changeargs=1
                ;;
            (--extra-reconall-arg)
                #also support --extra-reconall-arg foo, for fewer surprises
                if ((i + 1 >= ${#origargs[@]}))
                then
                    log_Err_Abort "--extra-reconall-arg requires an argument"
                fi
                extra_reconall_args_manual+=("${origargs[i + 1]#*=}")
                #skip the next argument, we took care of it
                i=$((i + 1))
                changeargs=1
                ;;
            (*)
                #copy anything unrecognized
                newargs+=("${origargs[i]}")
                ;;
        esac
    done
    if ((changeargs))
    then
        echo "original arguments: $*"
        set -- "${newargs[@]}"
        echo "new arguments: $*"
        echo "extra recon-all arguments: ${extra_reconall_args_manual[*]+"${extra_reconall_args_manual[*]}"}"
    fi
fi

#description to use in usage - syntax of parameters is now explained automatically
opts_SetScriptDescription "Runs the FreeSurfer HCP pipeline on data processed by prefreesurfer"

# Show usage information
opts_AddMandatory '--subject' 'SubjectID' 'subject' "Subject ID (required).  Used with --path input to create full path to root directory for all outputs generated as path/subject"

opts_AddOptional '--session-dir' 'SubjectDIR' 'session' 'path to subject directory required' "--subject-dir" "--subjectDIR"

opts_AddOptional '--t1w-image' 'T1wImage' "T1" 'path to T1w image required, unless --existing-subject is set' "" "--t1"

opts_AddOptional '--t1w-brain' 'T1wImageBrain' "T1Brain" 'path to T1w brain mask required, unless --existing-subject is set' "" "--t1brain"

opts_AddOptional '--t2w-image' 'T2wImage' "T2" "path to T2w image required, unless --existing-subject is set" "" "--t2"

opts_AddOptional '--seed' 'recon_all_seed' "Seed" 'recon-all seed value'

opts_AddOptional '--flair' 'flair' 'TRUE/FALSE' "Indicates that recon-all is to be run with the -FLAIR/-FLAIRpial options (rather than the -T2/-T2pial options).  The FLAIR input image itself should still be provided via the '--t2' argument. NOTE: This is experimental" "FALSE"

opts_AddOptional '--existing-subject' 'existing_subject' 'TRUE/FALSE' "Indicates that the script is to be run on top of an already existing analysis/subject.  This excludes the '-i' and '-T2/-FLAIR' flags from the invocation of recon-all (i.e., uses previous input volumes).  The --t1w-image, --t1w-brain and --t2w-image arguments, if provided, are ignored.  It also excludes the -all' flag from the invocation of recon-all.  Consequently, user needs to explicitly specify which recon-all stage(s) to run using the --extra-reconall-arg flag.  This flag allows for the application of FreeSurfer edits." "FALSE" "--existing-subject"

#TSC: repeatable options aren't currently supported in newopts, do them manually and fake the help info for now
opts_AddOptional '--extra-reconall-arg' 'extra_reconall_args' 'token' "(repeatable) Generic single token argument to pass to recon-all.  Provides a mechanism to customize the recon-all command and/or specify the recon-all stage(s) to be run (e.g., in the case of FreeSurfer edits).  If you want to avoid running all the stages inherent to the '-all' flag in recon-all, you also need to include the --existing-subject flag.  The token itself may include dashes and equal signs (although Freesurfer doesn't currently use equal signs in its argument specification).  e.g., --extra-reconall-arg=-3T is the correct syntax for adding the stand-alone '-3T' flag to recon-all, but --extra-reconall-arg='-norm3diters 3' is NOT acceptable.  For recon-all flags that themselves require an argument, you can handle that by specifying  --extra-reconall-arg multiple times (in the proper sequential fashion), e.g. --extra-reconall-arg=-norm3diters --extra-reconall-arg=3 will be translated to '-norm3diters 3' when passed to recon-all."

opts_AddOptional '--conf2hires' 'conf2hires' 'TRUE/FALSE' "Indicates that the script should include -conf2hires as an argument to recon-all.  By default, -conf2hires is included, so that recon-all will place the surfaces on the hires T1 (and T2).  Setting this to false is an advanced option, intended for situations where: (i) the original T1w and T2w images are NOT 'hires' (i.e., they are 1 mm isotropic or worse), or  (ii) you want to be able to run some flag in recon-all, without also regenerating the surfaces, e.g. --existing-subject --extra-reconall-arg=-show-edits --conf2hires=FALSE" "TRUE"

opts_AddOptional '--processing-mode' 'ProcessingMode' 'HCPStyleData or LegacyStyleData' "Controls whether the HCP acquisition and processing guidelines should be treated as requirements.  'HCPStyleData' (the default) follows the processing steps described in Glasser et al. (2013) and requires 'HCP-Style' data acquistion.  'LegacyStyleData' allows additional processing functionality and use of some acquisitions that do not conform to 'HCP-Style' expectations.  In this script, it allows not having a high-resolution T2w image." "HCPStyleData"

# NHP options
opts_AddMandatory '--species' 'Species' 'Human|Chimp|MacaqueCyno|MacaqueRhesus|MacaqueSnow|NightMonkey|Marmoset' "Species type (required).  Controls species-specific processing parameters" 

opts_AddOptional '--runmode' 'RunMode' 'Default|FSinit|FSbrainseg|FSsurfinit|FShires|FSFinish' "specify from which step to resume the processing instead of starting from the beginning. Value must be one of: Default, FSinit, FSbrainseg, FSsurfinit, FShires, FSFinish (default: Default)" "Default"

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#TSC: hack around the lack of repeatable option support, use a single string for display
extra_reconall_args=${extra_reconall_args_manual[*]+"${extra_reconall_args_manual[*]}"}

#display the parsed/default values
opts_ShowValues

#TSC: now use an array for proper argument handling
extra_reconall_args=(${extra_reconall_args_manual[@]+"${extra_reconall_args_manual[@]}"})

#parse booleans
flair=$(opts_StringToBool "$flair")
existing_subject=$(opts_StringToBool "$existing_subject")
conf2hires=$(opts_StringToBool "$conf2hires")

#deal with NONE convention
if [[ "$T1wImage" == "NONE" ]]; then
    T1wImage=""
fi
if [[ "$T1wImageBrain" == "NONE" ]]; then
    T1wImageBrain=""
fi
if [[ "$T2wImage" == "NONE" ]]; then
    T2wImage=""
fi




#check if existing_subject is set, if not t1 has to be set, and if t2 is not set, set processing mode flag to legacy 
Compliance="HCPStyleData"
ComplianceMsg=""


if ((! existing_subject))
then
    if [[ "${T1wImage}" = "" ]]
    then
        log_Err_Abort "--t1 not set and '--existing-subject' not used"
    fi
    if [[ "${T1wImageBrain}" = "" ]]
    then
        log_Err_Abort "--t1brain not set and '--existing-subject' not used"
    fi

    if [[ "${T2wImage}" = "" ]]
    then
        ComplianceMsg+=" --t2w-image= or --t2= not present or set to NONE"
        Compliance="LegacyStyleData"
    fi

	if [[ "${Species}" = "" ]]
    then
        log_Err_Abort "--species not set and '--existing-subject' not used"
    fi
fi

check_mode_compliance "${ProcessingMode}" "${Compliance}" "${ComplianceMsg}"


${HCPPIPEDIR}/show_version

#processing code goes here

# ------------------------------------------------------------------------------
#  Verify required environment variables are set and log value
# ------------------------------------------------------------------------------

log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FREESURFER_HOME

# Platform info
log_Msg "Platform Information Follows: "
log_Msg "Species: ${Species}"
log_Msg "RunMode: ${RunMode:-1}"
uname -a

configure_custom_tools()
{
    local which_recon_all
    local which_conf2hires
    local which_longmc

    which_recon_all=$(which recon-all.v6.hiresNHP)
    which_conf2hires=$(which conf2hiresNHP)
    which_longmc=$(which longmc)
    which_setupfsnhp=$(which SetUpFSNHP.sh)

    if [[ "${which_recon_all}" = "" || "${which_conf2hires}" == "" || "${which_setupfsnhp}" = "" ||  "${which_longmc}" = "" ]] ; then
        export PATH="${HCPPIPEDIR}/FreeSurfer/custom:${PATH}"
        log_Warn "We were not able to locate one of the following required tools:"
        log_Warn "recon-all.v6.hiresNHP, conf2hiresNHP, SetUpFSNHP.sh or longmc"
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
    log_Msg "Showing tkregister2 version"
    which tkregister2
    tkregister2 -version

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
    if [ -z "${FREESURFER_HOME}" ] ; then
        log_Err_Abort "FREESURFER_HOME must be set"
    fi
    
    freesurfer_version_file="${FREESURFER_HOME}/build-stamp.txt"

    if [ -f "${freesurfer_version_file}" ] ; then
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
        log_Err_Abort "FreeSurfer version 6.0.0 or greater is required. (Use FreeSurferPipeline-v5.3.0-HCP-NHP.sh if you want to continue using FreeSurfer 5.3)"
    fi
}

# Configure the use of FreeSurfer v6 custom tools
configure_custom_tools

# Show tool versions
show_tool_versions

# Validate version of FreeSurfer in use
validate_freesurfer_version

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

    if ((flair)); then
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

    popd
}


T2wtoT1wFile="T2wtoT1w.mat"      # Calling this file T2wtoT1w.mat regardless of whether the input to recon-all was -T2 or -FLAIR
OutputOrigT2wToT1w="OrigT2w2T1w" # Needs to match name used in PostFreeSurfer (N.B. "OrigT1" here refers to the T1w/T1w.nii.gz file; NOT FreeSurfer's "orig" space)

# ----------------------------------------------------------------------
log_Msg "Starting main functionality"
# ----------------------------------------------------------------------



source "$HCPPIPEDIR"/FreeSurfer/custom/SetUpFSNHP.sh "$Species" "$flair"
ScaleSuffix="_scaled"

# Convert the --runmode string argument into a numeric code
case "$RunMode" in
	Default)
		RunMode=1
		;;
	FSinit)
		RunMode=1
		;;
	FSbrainseg)
		RunMode=2
		;;
	FSsurfinit)
		RunMode=3
		;;
	FShires)
		RunMode=4
		;;
	FSfinish)
		RunMode=5
		;;
	*)
		echo "Error: invalid runmode '$RunMode'"
		exit 1
		;;
esac

if ((! existing_subject)) ; then

	# If --existing-subject is NOT set, AND PostFreeSurfer has been run, then
	# certain files need to be reverted to their PreFreeSurfer output versions
	if [ `imtest ${SubjectDIR}/xfms/${OutputOrigT2wToT1w}` = 1 ] ; then
		log_Msg "revert PreFreeSurfer resampling"	
		${HCPPIPEDIR_FS}/RevertPreFreeSurferResampling.sh $(dirname $(dirname "$SubjectDIR")) "$SubjectID"
		imrm ${SubjectDIR}/xfms/${OutputOrigT2wToT1w}
	fi
fi

if [ "${existing_subject}" = "TRUE" ] ; then

	if [ -e "$SubjectDIR"/"$SubjectID"_scaled ] ; then
		rm -rf "$SubjectDIR"/"$SubjectID" 
		mv "$SubjectDIR"/"$SubjectID"_scaled "$SubjectDIR"/"$SubjectID"
	fi
	if [ `imtest ${SubjectDIR}/xfms/${OutputOrigT2wToT1w}` = 1 ] ; then
		if [ $(dirname $(dirname "$SubjectDIR"))/"$SubjectID"/T1w/T1w_acpc_dc_restore.nii.gz -nt $(dirname $(dirname "$SubjectDIR"))/"$SubjectID"/T1w/T1w_acpc_dc_restore_scaled.nii.gz ] ; then
			log_Msg "revert PreFreeSurfer resampling"	
			${HCPPIPEDIR_FS}/RevertPreFreeSurferResampling.sh $(dirname $(dirname "$SubjectDIR")) "$SubjectID"
		fi
		imrm ${SubjectDIR}/xfms/${OutputOrigT2wToT1w}
	fi

	if [ -e "$SubjectDIR"/"$SubjectID"/scripts/IsRunning.lh+rh ] ; then
		rm "$SubjectDIR"/"$SubjectID"/scripts/IsRunning.lh+rh
	fi
fi

recon_all_cmd=(recon-all.v6.hiresNHP -subjid "$SubjectID" -sd "$SubjectDIR")
if [ ! -z "${recon_all_seed}" ] ; then
	extra_reconall_args+=(-norandomness -rng-seed "$recon_all_seed")
fi
if [[ -n "${GCSdir:-}" && -n "${GCS:-}" ]] ; then
    extra_reconall_args+=(-gcs-dir "$GCSdir" -gcs "$GCS")
fi
# The -conf2hires flag should come after the ${extra_reconall_args} string, since it needs
# to have the "final say" over a couple settings within recon-all
#-conf2hires is more of a step than a setting, can't just include it in all calls
conf2hiresflag=""
if ((conf2hires)); then
	conf2hiresflag="-conf2hires"
fi

# expert options for recon-all
rm -f "$SubjectDIR"/"$SubjectID".expert.opts

for cmd in mri_normalize mri_segment mri_fill mris_inflate1 mris_inflate2 mris_smooth mris_make_surfaces mris_register bbregister; do    
	cmd_args=${cmd}_args
	if [[ "${!cmd_args+${!cmd_args}}" != "" ]] ; then
		log_Msg "expert opts: $cmd ${!cmd_args+${!cmd_args}}"
		echo "$cmd ${!cmd_args+${!cmd_args}}" >> "$SubjectDIR"/"$SubjectID".expert.opts
	fi
done

# options for conf2hires
c2hxopts=""
if [ -n "${T1normSigma:-}" ] ; then
	c2hxopts+=" --t1norm-sigma ${T1normSigma}"
fi
if [ -n "${T2normSigma:-}" ] ; then
	c2hxopts+=" --t2norm-sigma ${T2normSigma}"
fi
if [ -n "${VariableSigma:-}" ] ; then
	c2hxopts+=" --variablesigma ${VariableSigma}"
fi
if [ -n "${PialSigma:-}" ] ; then
	c2hxopts+=" --psigma ${PialSigma}"
fi
if [ -n "${WhiteSigma:-}" ] ; then
	c2hxopts+=" --wsigma ${WhiteSigma}"
fi
if [ -n "${SmoothNiter:-}" ] ; then
	c2hxopts+=" --smooth ${SmoothNiter}"
fi
if [ -n "${NSigmaAbove:-}" ] ; then
	c2hxopts+=" --nsigma_above ${NSigmaAbove}"
fi
if [ -n "${NSigmaBelow:-}" ] ; then
	c2hxopts+=" --nsigma_below ${NSigmaBelow}"
fi
if [ -n "${WMProjAbs:-}" ] ; then
	c2hxopts+=" --wm-proj-abs ${WMProjAbs}"
fi
if [ -n "${WMSeg_wlo:-}" ] ; then
	c2hxopts+=" --wlo ${WMSeg_wlo}"
fi
if [ -n "${WMSeg_ghi:-}" ] ; then
	c2hxopts+=" --ghi ${WMSeg_ghi}"
fi
if [ -n "${MIN_GRAY_AT_WHITE_BORDER:-}" ] ; then
	c2hxopts+=" --min_gray_at_white_border ${MIN_GRAY_AT_WHITE_BORDER}"
fi
if [ -n "${MAX_GRAY_AT_CSF_BORDER:-}" ] ; then
	c2hxopts+=" --max_gray_at_csf_border ${MAX_GRAY_AT_CSF_BORDER}"
fi
if [ -n "${MIN_GRAY_AT_CSF_BORDER:-}" ] ; then
	c2hxopts+=" --min_gray_at_csf_border ${MIN_GRAY_AT_CSF_BORDER}"
fi
if [ -n "${MAX_GRAY:-}" ] ; then
	c2hxopts+=" --max_gray ${MAX_GRAY}"
fi
if [ -n "${MAX_CSF:-}" ] ; then
	c2hxopts+=" --max_csf ${MAX_CSF}"
fi
if [ -n "${SmoothNiterPial:-}" ] ; then
	c2hxopts+=" --smoothpial ${SmoothNiterPial}"
fi
if [ -n "${MaxThickness:-}" ] ; then
	c2hxopts+=" --max ${MaxThickness}"
fi
if [ "${CopyBiasFromConf:-}" = "TRUE" ] ; then
	c2hxopts+=" --copy-bias-from-conf"
fi	
if [ -n "${c2hxopts:-}" ] ; then
	log_Msg "conf2hires expert opts: $c2hxopts"
	echo "conf2hiresNHP $c2hxopts" >> "$SubjectDIR"/"$SubjectID".expert.opts
fi
extra_reconall_args+=(-expert "$SubjectDIR"/"$SubjectID".expert.opts -xopts-overwrite)

log_Msg "recon-all log: $SubjectDIR/$SubjectID/scripts/recon-all.log"
LF="$SubjectDIR"/"$SubjectID"/scripts/recon-all.log



if [ "$RunMode" -lt 2 ] ; then
	if ((! existing_subject)) ; then

		# ----------------------------------------------------------------------
		log_Msg "Thresholding T1w image to eliminate negative voxel values"
		# ----------------------------------------------------------------------
		zero_threshold_T1wImage=$(remove_ext ${T1wImage})_zero_threshold.nii.gz
		log_Msg "...This produces a new file named: ${zero_threshold_T1wImage}"

		fslmaths ${T1wImage} -thr 0 ${zero_threshold_T1wImage}

		## This section scales them so that FreeSurfer 6 can work properly in scaled space. The data will be
		## rescaled to the original space by a script, RescaleVolumeAndSurface.sh, after FS was finished - TH 2017-2023 
		log_Msg "Scale T1w brain volume"		
		${HCPPIPEDIR}/global/scripts/ScaleVolume.sh "${zero_threshold_T1wImage}" "$ScaleFactor" $(remove_ext ${T1wImage})_scaled "$SubjectDIR"/xfms/real2fs.world.mat
		${HCPPIPEDIR}/global/scripts/ScaleVolume.sh "$T1wImageBrain" "$ScaleFactor" $(remove_ext ${T1wImageBrain})_scaled 

		if [[ "${T2wImage}" != "" ]] ; then
			log_Msg "Scale T2w volume"
			${HCPPIPEDIR}/global/scripts/ScaleVolume.sh "$T2wImage" "$ScaleFactor" $(remove_ext ${T2wImage})_scaled
		fi

	fi

	# ----------------------------------------------------------------------
	log_Msg "Call custom recon-all: recon-all.v6.hires"
	# ----------------------------------------------------------------------
	
	if [ -e "$SubjectDIR"/"$SubjectID" ] ; then
		rm -rf "$SubjectDIR"/"$SubjectID"
	fi
	if [ -e "$SubjectDIR"/"$SubjectID""$ScaleSuffix" ] ; then
		rm -rf "$SubjectDIR"/"$SubjectID""$ScaleSuffix"
	fi
	
	recon_all_initrun=(-motioncor)
	if ((! existing_subject))
	then
	    recon_all_initrun+=(-i "$(remove_ext "$T1wImage")_scaled.nii.gz"
	    -emregmask "$(remove_ext "$T1wImageBrain")_scaled.nii.gz")
	fi
    # By default, refine pial surfaces using T2 (if T2w image provided).
    # If for some other reason the -T2pial flag needs to be excluded from recon-all, 
    # this can be accomplished using --extra-reconall-arg=-noT2pial
    if [[ "${T2wImage}" != "" ]] ; then
        if ((flair)) ; then
            recon_all_pial="-FLAIRpial"
            recon_all_initrun+=(-FLAIR "$(remove_ext "$T2wImage")_scaled.nii.gz")
            T2Type=FLAIR
        else
            recon_all_pial="-T2pial"
            recon_all_initrun+=(-T2 "$(remove_ext "$T2wImage")_scaled.nii.gz")
            T2Type=T2
        fi
        rm -f "$SubjectDIR"/"$SubjectID"/mri/transforms/"$T2Type"raw.lta # remove this otherwise conf2hires will not update this - TH
    else
            recon_all_pial=""
            T2Type="NONE"		
    fi

	log_Msg "...recon_all_cmd: ${recon_all_cmd[*]} ${recon_all_initrun[*]} ${extra_reconall_args[*]}"
	"${recon_all_cmd[@]}" "${recon_all_initrun[@]}" "${extra_reconall_args[@]}"

	log_Msg "...brainmasking, intensitycor"
	cmd=(fslmaths $(remove_ext ${T1wImageBrain})_scaled.nii.gz -thr 0 "$SubjectDIR"/"$SubjectID"/mri/brainmask.orig.nii.gz)
	echo -e "$(date)\n#===============================\n${cmd[@]}\n" |& tee -a $LF; ${cmd[@]} |& tee -a $LF

	cmd=(mri_convert "$SubjectDIR"/"$SubjectID"/mri/brainmask.orig.nii.gz "$SubjectDIR"/"$SubjectID"/mri/brainmask.conf.mgz --conform)
	echo -e "$(date)\n#===============================\n${cmd[@]}\n" |& tee -a $LF; ${cmd[@]} |& tee -a $LF

	## This section replaces 'FS -nuintensirycor' for NHP - TH 2017-2023
	cmd=("$PipelineScripts"/IntensityCor.sh "$SubjectDIR"/"$SubjectID"/mri/orig.mgz "$SubjectDIR"/"$SubjectID"/mri/brainmask.conf.mgz "$SubjectDIR"/"$SubjectID"/mri/nu.mgz -t1 -m "$IntensityCor","$BiasFieldFastSmoothingSigma" "$StrongBias_args")
	echo -e "$(date)\n#===============================\n${cmd[@]}\n" |& tee -a $LF; ${cmd[@]} |& tee -a $LF

	log_Msg "...second recon-all for normalization"
	"${recon_all_cmd[@]}" -normalization "${extra_reconall_args[@]}"

fi

if [ "$RunMode" -lt 3 ] ; then
	log_Msg "...skullstripping"      ## This section replaces 'FS -skullstrip' for NHP - TH 2017-2024

	mridir=${SubjectDIR}/${SubjectID}/mri

	if [ ! -e "$mridir"/brainmask.edit.mgz ] ; then

		if [ "$SkullStripMethod" = PreFS ] ; then

			DilateDistance=1 

			cmd=(mri_convert "$mridir"/brainmask.conf.mgz "$mridir"/brainmask.conf.nii.gz)
			echo -e "$(date)\n#===============================\n${cmd[@]}\n" |& tee -a $LF; ${cmd[@]} |& tee -a $LF

			cmd=(fslmaths "$mridir"/brainmask.conf.nii.gz -bin  "$mridir"/brainmask.conf.bin.nii.gz)
			echo -e "$(date)\n#===============================\n${cmd[@]}\n" |& tee -a $LF; ${cmd[@]} |& tee -a $LF

			cmd=($CARET7DIR/wb_command -volume-dilate "$mridir"/brainmask.conf.bin.nii.gz $DilateDistance NEAREST "$mridir"/brainmask.bin.nii.gz)
			echo -e "$(date)\n#===============================\n${cmd[@]}\n" |& tee -a $LF; ${cmd[@]} |& tee -a $LF

			cmd=(mri_convert "$mridir"/brainmask.bin.nii.gz "$mridir"/brainmask.bin.mgz)
			echo -e "$(date)\n#===============================\n${cmd[@]}\n" |& tee -a $LF; ${cmd[@]} |& tee -a $LF

			cmd=(mri_mask "$mridir"/T1.mgz "$mridir"/brainmask.bin.mgz "$mridir"/brainmask.mgz)
			echo -e "$(date)\n#===============================\n${cmd[@]}\n" |& tee -a $LF; ${cmd[@]} |& tee -a $LF
			
			cmd=(rm "$mridir"/brainmask.bin.nii.gz "$mridir"/brainmask.conf.nii.gz "$mridir"/brainmask.conf.bin.nii.gz "$mridir"/brainmask.bin.mgz)
			echo -e "$(date)\n#===============================\n${cmd[@]}\n" |& tee -a $LF; ${cmd[@]} |& tee -a $LF

		elif [ "$SkullStripMethod" = FS ] ; then

			cmd=(mri_em_register -uns 3 -mask "$mridir"/brainmask.conf.mgz "$mridir"/nu.mgz "$GCAdir"/"$GCA" "$mridir"/transforms/talairach_init.lta)
			echo -e "$(date)\n#===============================\n${cmd[@]}\n" |& tee -a $LF; ${cmd[@]} |& tee -a $LF

			cmd=(mri_convert "$mridir"/brainmask.conf.mgz "$mridir"/brainmask.conf.nii.gz)
			echo -e "$(date)\n#===============================\n${cmd[@]}\n" |& tee -a $LF; ${cmd[@]} |& tee -a $LF

			cmd=(fslmaths "$mridir"/brainmask.conf.nii.gz -bin -dilM -dilM "$mridir"/brainmask.conf.dil2.nii.gz)
			echo -e "$(date)\n#===============================\n${cmd[@]}\n" |& tee -a $LF; ${cmd[@]} |& tee -a $LF

			cmd=(mri_convert "$mridir"/brainmask.conf.dil2.nii.gz "$mridir"/brainmask.conf.dil2.mgz)
			echo -e "$(date)\n#===============================\n${cmd[@]}\n" |& tee -a $LF; ${cmd[@]} |& tee -a $LF

			cmd=(mri_mask "$mridir"/T1.mgz "$mridir"/brainmask.conf.dil2.mgz "$mridir"/T1_prebrainmask.mgz)
			echo -e "$(date)\n#===============================\n${cmd[@]}\n" |& tee -a $LF; ${cmd[@]} |& tee -a $LF

			# mri_watershed in NHP requires pre-masked input to minimize probability of failure (<5%)- TH Jan 2024
			cmd=(mri_watershed -T1 -less -r 70 -c 127 107 108 -atlas "$GCAdir"/"$GCA" "$mridir"/transforms/talairach_init.lta "$mridir"/T1_prebrainmask.mgz "$mridir"/brainmask.auto.mgz)
			echo -e "$(date)\n#===============================\n${cmd[@]}\n" |& tee -a $LF; ${cmd[@]} |& tee -a $LF

			cmd=(cp "$mridir"/brainmask.auto.mgz "$mridir"/brainmask.mgz)
			echo -e "$(date)\n#===============================\n${cmd[@]}\n" |& tee -a $LF; ${cmd[@]} |& tee -a $LF

			cmd=(rm "$mridir"/brainmask.conf.dil2.nii.gz "$mridir"/brainmask.conf.nii.gz "$mridir"/brainmask.conf.dil2.mgz)
			echo -e "$(date)\n#===============================\n${cmd[@]}\n" |& tee -a $LF; ${cmd[@]} |& tee -a $LF
		fi

	else
		log_Msg "Found brainmask.edit.mgz. Use it for subsequent analysis"
		vol="brainmask.edit"
		while [ -e "$mridir"/${vol}.mgz ] ; do
			vol="${vol}+"
		done
		cmd=(cp "$mridir"/brainmask.edit.mgz "$mridir"/${vol}.mgz)
		echo -e "$(date)\n#===============================\n${cmd[@]}\n" |& tee -a $LF; ${cmd[@]} |& tee -a $LF

		cmd=(cp "$mridir"/brainmask.edit.mgz "$mridir"/brainmask.mgz)
		echo -e "$(date)\n#===============================\n${cmd[@]}\n" |& tee -a $LF; ${cmd[@]} |& tee -a $LF

		checkfile="$mridir"/brainmask.finalsurfs.mgz
		if [ -e "$checkfile" ] ; then
			if [ ! -w "$checkfile" ] ; then
				log_Err_Abort "no permission to write $checkfile"
			fi
		fi
	fi

	## This section replaces function of 'recon-all -gcareg, -canorm and -careg' using FLIRT and FNIRT - TH 2017-2024
	log_Msg "...registration to GCA template"
	cmd=("$PipelineScripts"/Conf2GCAReg_FNIRTbased.sh "$SubjectDIR" "$SubjectID" "$GCAdir/$GCA")
	echo -e "$(date)\n#===============================\n${cmd[@]}\n" |& tee -a $LF; ${cmd[@]} |& tee -a $LF

	log_Msg "...third recon-all steps for segmentation with GCA"
	"${recon_all_cmd[@]}" -calabel -gca-dir "$GCAdir" -gca "$GCA" -normalization2 -maskbfs "${extra_reconall_args[@]}"
fi

if [ "$RunMode" -lt 4 ]; then

	## This section replaces function of 'recon-all -segmentation'  - TH 2017-2024
	## Paste claustrum and deweight cortical gray in wm.mgz. If any of wm.edit.mgz, brainmask.edit.mgz, brain.finalsurfs.edit.mgz
	## or aseg.presurf.edit.mgz was found, the script uses each as wm.mgz, brainmask.mnz, brain.finalsurfs.mgz and aseg.presurf.mgz respectively.
	## ${PipelineScripts}/IntensityNormalize.sh may be useful for normalizing intensity of white matter or grey matter to create
	## brain.finalsurfs.edit.mgz,
	cmd=("$PipelineScripts"/SubcortSegment.sh "$SubjectDIR" "$SubjectID" "$T1wImage" "$TemplateWMSkeleton" "$SubjectDIR"/xfms/real2fs.world.mat ${mri_segment_args:-${mri_segment_args}})
	echo -e "$(date)\n#===============================\n${cmd[@]}\n" |& tee -a $LF; ${cmd[@]} |& tee -a $LF

	mridir=${SubjectDIR}/${SubjectID}/mri

	## if filled.edit.mgz is found, it is used as filled.mgz - TH 2025
	if [ -e ${mridir}/filled.edit.mgz ] ; then
			log_Msg "Found ${mridir}/filled.edit.mgz. Replace filled.mgz with it"
			if [ ! -e ${mridir}/filled.orig.mgz ] ; then
				cp ${mridir}/filled.mgz ${mridir}/filled.orig.mgz
			fi
			vol="${mridir}/filled.edit"
				while [ -e ${vol}.mgz ] ; do
				vol="${vol}+"
			done
			cp ${mridir}/filled.edit.mgz ${mridir}/filled.mgz
			mv ${mridir}/filled.edit.mgz ${vol}.mgz
			FILL=""
	else
			FILL="-fill"
	fi
	
	log_Msg "...fourth recon-all steps with edited filled.mgz"
    #don't quote $FILL, we don't want to pass an empty string
	"${recon_all_cmd[@]}" $FILL -tessellate -smooth1 -inflate1 -qsphere -fix -white -smooth2 -inflate2 -curvHK -sphere -surfreg -avgcurvtifpath "$GCAdir" -avgcurvtif "$AvgCurvTif" -jacobian_white -cortparc "${extra_reconall_args[@]}"
fi

if [ "$RunMode" -lt 5 ]; then

	mridir=${SubjectDIR}/${SubjectID}/mri
 
	## if brain.finalsurfs.edit.mgz is found, it is used as brain.finalsurfs.mgz - TH 2024
	if [ -e ${mridir}/brain.finalsurfs.edit.mgz ] ; then
		log_Msg "Found ${mridir}/brain.finalsurfs.edit.mgz. Replace brain.finalsurfs.mgz with it"
		if [ ! -e ${mridir}/brain.finalsurfs.orig.mgz ] ; then
			cp ${mridir}/brain.finalsurfs.mgz ${mridir}/brain.finalsurfs.orig.mgz
		fi
		vol="${mridir}/brain.finalsurfs.edit"
		while [ -e ${vol}.mgz ] ; do
			vol="${vol}+"
		done
		cp ${mridir}/brain.finalsurfs.edit.mgz ${mridir}/brain.finalsurfs.mgz
		mv ${mridir}/brain.finalsurfs.edit.mgz ${vol}.mgz
	fi

	if [ -e ${mridir}/brainmask.edit.mgz ] ; then
		log_Msg "Found brainmask.edit.mgz. Use it for subsequent analysis"
		vol="brainmask.edit"
		while [ -e "$mridir"/${vol}.mgz ] ; do
			vol="${vol}+"
		done
		cp "$mridir"/brainmask.edit.mgz "$mridir"/brainmask.mgz
		mv "$mridir"/brainmask.edit.mgz "$mridir"/${vol}.mgz
		mri_mask "${mridir}"/brain.finalsurfs.mgz "$mridir"/brainmask.mgz "${mridir}"/brain.finalsurfs.mgz
	fi

	## if aseg.presurf.edit.mgz is found, it is used as aseg.presurfs.mgz - TH 2024
	if [ -e ${mridir}/aseg.presurf.edit.mgz ] ; then
		log_Msg "Found ${mridir}/aseg.presurf.edit.mgz. Replace aseg.presurf.mgz with it"
		if [ ! -e ${mridir}/aseg.finalsurf.orig.mgz ] ; then
			cp ${mridir}/aseg.presurf.mgz ${mridir}/aseg.presurf.orig.mgz
		fi
		vol="${mridir}/aseg.presurf.edit"
		while [ -e ${vol}.mgz ] ; do
			vol="${vol}+"
		done
		cp ${mridir}/aseg.presurf.edit.mgz ${mridir}/aseg.presurf.mgz
		mv ${mridir}/aseg.presurf.edit.mgz ${vol}.mgz
	fi

	if [ $(echo "$ScaleFactor < 6" | bc) = 1 ] ; then  # brain is larger than the rat
		log_Msg "...fifth recon-all steps for hires white and pial using conf2hires"
		#don't quote $recon_all_pial or $conf2hiresflag, we don't want to pass an empty string
		"${recon_all_cmd[@]}" -cortribbon ${recon_all_pial} "${extra_reconall_args[@]}" ${conf2hiresflag}
		log_Msg "...rescale volume and surface to native space"
		cmd=("$PipelineScripts"/RescaleVolumeAndSurface.sh "$SubjectDIR" "$SubjectID" "$SubjectDIR"/xfms/real2fs.world.mat "$T1wImage" "$T2wImage" "$T2Type" "$ScaleSuffix")
		echo -e "$(date)\n#===============================\n${cmd[@]}\n" |& tee -a $LF; "${cmd[@]}" |& tee -a $LF
	else
		log_Msg "...rescale volume and surface to native space"
		cmd=("$PipelineScripts"/RescaleVolumeAndSurface.sh "$SubjectDIR" "$SubjectID" "$SubjectDIR"/xfms/real2fs.world.mat "$T1wImage" "$T2wImage" "$T2Type" "$ScaleSuffix")
		echo -e "$(date)\n#===============================\n${cmd[@]}\n" |& tee -a $LF; "${cmd[@]}" |& tee -a $LF
		log_Msg "...fifth recon-all steps for hires white and pial using conf2hires"
		"${recon_all_cmd[@]}" -cortribbon ${recon_all_pial} "${extra_reconall_args[@]}" ${conf2hiresflag}
	fi

	# ----------------------------------------------------------------------
	log_Msg "Generating QC file" in scaled space
	# ----------------------------------------------------------------------
	mridir=${SubjectDIR}/${SubjectID}/mri

	make_t1w_hires_nifti_file "${mridir}"

		if [[ "${T2wImage}" != "" ]] ; then

		make_t2w_hires_nifti_file "${mridir}"

		make_t1wxt2w_qc_file "${mridir}"
	fi

fi

if [ "$RunMode" -lt 6 ]; then

	if [ "$SPECIES" = Human ] ; then
		log_Msg "CurvStat, CortParc etc for Human"
		${recon_all_cmd} -curvstats -avgcurv -parcstats -cortparc2 -parcstats2 -cortparc3 -parcstats3 -pctsurfcon -hyporelabel -aparc2aseg -apas2aseg -segstats -wmparc -balabels
	fi
	
	if [ "${existing_subject}" != "TRUE" ] ; then
		# ----------------------------------------------------------------------
		log_Msg "Clean up file: ${zero_threshold_T1wImage}"
		# ----------------------------------------------------------------------
		rm ${zero_threshold_T1wImage}

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

	if [[ "${T2wImage}" != "" ]] ; then
		# ----------------------------------------------------------------------
		log_Msg "Making T2w to T1w registration available in FSL format"
		# ----------------------------------------------------------------------

		pushd ${mridir}

		if ((flair)) ; then
			t2_or_flair="FLAIR"
		else
			t2_or_flair="T2"
		fi

		log_Msg "...Create a registration between the original conformed space and the rawavg space"
		tkregister_cmd="tkregister2"
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

		log_Msg "...Concatenate the ${t2_or_flair}raw->orig and orig->rawavg transforms"
		mri_concatenate_lta_cmd="mri_concatenate_lta"
		mri_concatenate_lta_cmd+=" transforms/${t2_or_flair}raw.lta"
		mri_concatenate_lta_cmd+=" transforms/orig-to-rawavg.lta"
		mri_concatenate_lta_cmd+=" Q.lta"

		log_Msg "......The following concatenates transforms/${t2_or_flair}raw.lta and transforms/orig-to-rawavg.lta to get Q.lta"
		log_Msg "......mri_concatenate_lta_cmd: ${mri_concatenate_lta_cmd}"
		${mri_concatenate_lta_cmd}

		log_Msg "...Convert to FSL format"
		tkregister_cmd="tkregister2"
		tkregister_cmd+=" --mov orig/${t2_or_flair}raw.mgz"
		tkregister_cmd+=" --targ rawavg.mgz"
		tkregister_cmd+=" --reg Q.lta"
		tkregister_cmd+=" --fslregout transforms/${T2wtoT1wFile}"
		tkregister_cmd+=" --noedit"

		log_Msg "......The following produces the transforms/${T2wtoT1wFile} file that we need"
		log_Msg "......tkregister_cmd: ${tkregister_cmd}"

		${tkregister_cmd}

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
	#The ?h.pial.deformed surfaces are used for USPIO fMRI registration - TH 2024
	for hemi in lh rh; do
		for surf in white pial; do
			mri_surf2surf --s ${SubjectID} --sval-xyz "$surf" --reg "$reg" --tval-xyz ${mridir}/rawavg.mgz --tval "$surf".deformed --surfreg "$surf" --hemi "$hemi"
		done
	done
	
	popd
	
	# ----------------------------------------------------------------------
	log_Msg "Generating QC file"
	# ----------------------------------------------------------------------

	make_t1w_hires_nifti_file "${mridir}"

	if [[ "${T2wImage}" != "" ]] ; then
	
		make_t2w_hires_nifti_file "${mridir}"

		make_t1wxt2w_qc_file "${mridir}"
	fi
fi
# ----------------------------------------------------------------------
log_Msg "Completing main functionality"
# ----------------------------------------------------------------------








log_Msg "Completed!"
exit 0
