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
            (--existing-subject)
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
opts_SetScriptDescription "Runs the FreeSurfer HCP pipline on data processed by prefresurfer"

# Show usage information
opts_AddMandatory '--subject' 'SubjectID' 'subject' "Subject ID (required).  Used with --path input to create full path to root directory for all outputs generated as path/subject"

opts_AddOptional '--subjectDIR' 'SubjectDIR' 'subject' 'path to subject directory required, unless --existing-subject is set' "" "--subject-dir"

opts_AddOptional '--t1w-image' 'T1wImage' "T1" 'path to T1w image required, unless --existing-subject is set' "" "--t1"

opts_AddOptional '--t1w-brain' 'T1wImageBrain' "T1Brain" 'path to T1w brain mask required, unless --existing-subject is set' "" "--t1brain"

opts_AddOptional '--t2w-image' 'T2wImage' "T2" "path to T2w image required, unless --existing-subject is set" "" "--t2"

opts_AddOptional '--seed' 'recon_all_seed' "Seed" 'recon-all seed value'

opts_AddOptional '--flair' 'flairString' 'TRUE/FALSE' "Indicates that recon-all is to be run with the -FLAIR/-FLAIRpial options (rather than the -T2/-T2pial options).  The FLAIR input image itself should still be provided via the '--t2' argument. NOTE: This is experimental" "FALSE"

opts_AddOptional '--existing-subject' 'existing_subjectString' 'TRUE/FALSE' "Indicates that the script is to be run on top of an already existing analysis/subject.  This excludes the '-i' and '-T2/-FLAIR' flags from the invocation of recon-all (i.e., uses previous input volumes).  The --t1w-image, --t1w-brain and --t2w-image arguments, if provided, are ignored.  It also excludes the -all' flag from the invocation of recon-all.  Consequently, user needs to explicitly specify which recon-all stage(s) to run using the --extra-reconall-arg flag.  This flag allows for the application of FreeSurfer edits." "FALSE"

#TSC: repeatable options aren't currently supported in newopts, do them manually and fake the help info for now
opts_AddOptional '--extra-reconall-arg' 'extra_reconall_args' 'token' "(repeatable) Generic single token argument to pass to recon-all.  Provides a mechanism to: (i) customize the recon-all command (ii) specify the recon-all stage(s) to be run (e.g., in the case of FreeSurfer edits)  If you want to avoid running all the stages inherent to the '-all' flag in recon-all, you also need to include the --existing-subject flag.  The token itself may include dashes and equal signs (although Freesurfer doesn't currently use equal signs in its argument specification).  e.g., --extra-reconall-arg=-3T is the correct syntax for adding the stand-alone '-3T' flag to recon-all.  But, --extra-reconall-arg='-norm3diters 3' is NOT acceptable.  For recon-all flags that themselves require an argument, you can handle that by specifying  --extra-reconall-arg multiple times (in the proper sequential fashion).  e.g., --extra-reconall-arg=-norm3diters --extra-reconall-arg=3 will be translated to '-norm3diters 3' when passed to recon-all."

opts_AddOptional '--conf2hires' 'conf2hiresString' 'TRUE/FALSE' "Indicates that the script should include -conf2hires as an argument to recon-all.  By default, -conf2hires is included, so that recon-all will place the surfaces on the hires T1 (and T2).  Setting this to false is an advanced option, intended for situations where: (i) the original T1w and T2w images are NOT 'hires' (i.e., they are 1 mm isotropic or worse), or  (ii) you want to be able to run some flag in recon-all, without also regenerating the surfaces.  e.g., --existing-subject --extra-reconall-arg=-show-edits --conf2hires=FALSE" "TRUE"

opts_AddOptional '--processing-mode' 'ProcessingMode' 'HCPStyleData or LegacyStyleData' "Controls whether the HCP acquisition and processing guidelines should be treated as requirements.  'HCPStyleData' (the default) follows the processing steps described in Glasser et al. (2013) and requires 'HCP-Style' data acquistion.  'LegacyStyleData' allows additional processing functionality and use of some acquisitions that do not conform to 'HCP-Style' expectations.  In this script, it allows not having a high-resolution T2w image." "HCPStyleData"

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
flair=$(opts_StringToBool "$flairString")
existing_subject=$(opts_StringToBool "$existing_subjectString")
conf2hires=$(opts_StringToBool "$conf2hiresString")

#deal with NONE convention
if [[ "$T1wImage" == "NONE" ]]; then
    T1wImage=""
fi
if [[ "$T1wImageBrain" == "NONE" ]]; then
    T1wImage=""
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
uname -a

configure_custom_tools()
{
    local which_recon_all
    local which_conf2hires
    local which_longmc

    which_recon_all=$(which recon-all.v6.hires || true)
    which_conf2hires=$(which conf2hires || true)
    which_longmc=$(which longmc || true)

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
}

# Show tool versions
show_tool_versions()
{
    # Show HCP pipelines version
    log_Msg "Showing HCP Pipelines version"
    ${HCPPIPEDIR}/show_version

    # Show recon-all version
    log_Msg "Showing recon-all.v6.hires version"
    local which_recon_all=$(which recon-all.v6.hires || true)
    log_Msg ${which_recon_all}
    recon-all.v6.hires -version
    
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


T2wtoT1wFile="T2wtoT1w.mat"      # Calling this file T2wtoT1w.mat regardless of whether the input to recon-all was -T2 or -FLAIR
OutputOrigT1wToT1w="OrigT1w2T1w" # Needs to match name used in PostFreeSurfer (N.B. "OrigT1" here refers to the T1w/T1w.nii.gz file; NOT FreeSurfer's "orig" space)

# ----------------------------------------------------------------------
log_Msg "Starting main functionality"
# ----------------------------------------------------------------------

# ----------------------------------------------------------------------
log_Msg "Retrieve positional parameters"
# ----------------------------------------------------------------------
SubjectDIR="${SubjectDIR}"
SubjectID="${SubjectID}"
T1wImage="${T1wImage}"       # Irrelevant if '--existing-subject' flag is set
T1wImageBrain="${T1wImageBrain}"  # Irrelevant if '--existing-subject' flag is set
T2wImage="${T2wImage}"       # Irrelevant if '--existing-subject' flag is set
recon_all_seed="${recon_all_seed}"


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
log_Msg "extra_reconall_args: ${extra_reconall_args[*]+"${extra_reconall_args[*]}"}"
log_Msg "conf2hires: ${conf2hires}"

if ((! existing_subject)); then

    # If --existing-subject is NOT set, AND PostFreeSurfer has been run, then
    # certain files need to be reverted to their PreFreeSurfer output versions
    if [ `imtest ${SubjectDIR}/xfms/${OutputOrigT1wToT1w}` = 1 ]; then
        log_Err "The --existing-subject flag was not invoked AND PostFreeSurfer has already been run."
        log_Err "If attempting to run FreeSurfer de novo, certain files (e.g., <subj>/T1w/{T1w,T2w}_acpc_dc*) need to be reverted to their PreFreeSurfer outputs."
        log_Err_Abort "If this is the goal, delete ${SubjectDIR}/${SubjectID} AND re-run PreFreeSurfer, before invoking FreeSurfer again."
    fi

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
fi

# ----------------------------------------------------------------------
log_Msg "Call custom recon-all: recon-all.v6.hires"
# ----------------------------------------------------------------------

recon_all_cmd=(recon-all.v6.hires -subjid "$SubjectID" -sd "$SubjectDIR")
if ((! existing_subject)); then  # input volumes only necessary first time through
    recon_all_cmd+=(-all -i "$zero_threshold_T1wImage" -emregmask "$T1wImageBrain")
    if [ "${T2wImage}" != "" ]; then
        if ((flair)); then
            recon_all_cmd+=(-FLAIR "$T2wImage")
        else
            recon_all_cmd+=(-T2 "$T2wImage")
        fi
    fi
fi

# By default, refine pial surfaces using T2 (if T2w image provided).
# If for some other reason the -T2pial flag needs to be excluded from recon-all, 
# this can be accomplished using --extra-reconall-arg=-noT2pial
if [ "${T2wImage}" != "" ]; then
    if ((flair)); then
        recon_all_cmd+=(-FLAIRpial)
    else
        recon_all_cmd+=(-T2pial)
    fi
fi

if [ ! -z "${recon_all_seed}" ]; then
    recon_all_cmd+=(-norandomness -rng-seed "$recon_all_seed")
fi

#add any extra args
recon_all_cmd+=(${extra_reconall_args[@]+"${extra_reconall_args[@]}"})

# The -conf2hires flag should come after the ${extra_reconall_args[@]} array, since it needs
# to have the "final say" over a couple settings within recon-all
if ((conf2hires)); then
    recon_all_cmd+=(-conf2hires)
fi

log_Msg "...recon_all_cmd: ${recon_all_cmd[*]}"
"${recon_all_cmd[@]}"
return_code=$?
if [ "${return_code}" != "0" ]; then
    log_Err_Abort "recon-all command failed with return_code: ${return_code}"
fi

if ((! existing_subject)); then
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

if [[ "${T2wImage}" != "" ]]; then
    # ----------------------------------------------------------------------
    log_Msg "Making T2w to T1w registration available in FSL format"
    # ----------------------------------------------------------------------

    pushd ${mridir}

    if ((flair)); then
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

if [[ "${T2wImage}" != "" ]]; then

    make_t2w_hires_nifti_file "${mridir}"

    make_t1wxt2w_qc_file "${mridir}"
fi

# ----------------------------------------------------------------------
log_Msg "Completing main functionality"
# ----------------------------------------------------------------------


log_Msg "Completed!"
exit 0
