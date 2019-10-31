#!/bin/bash 

# Requirements for this script
#  installed versions of: FSL, FreeSurfer (version 5.3.0-HCP), Connectome Workbench (wb_command)
#  environment: HCPPIPEDIR, FSLDIR, FREESURFER_HOME, CARET7DIR 

########################################## PIPELINE OVERVIEW ########################################## 

#TODO

########################################## OUTPUT DIRECTORIES ########################################## 

#TODO


# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

script_name=$(basename "${0}")

show_usage() {
	cat <<EOF

${script_name}: Run FreeSurfer processing pipeline using FS v5.3-HCP

Usage: ${script_name} [options]

Usage information To Be Written

EOF
}

# Allow script to return a Usage statement, before any other output or checking
if [ "$#" = "0" ]; then
    show_usage
    exit 1
fi

# ------------------------------------------------------------------------------
#  Check that HCPPIPEDIR is defined and Load Function Libraries
# ------------------------------------------------------------------------------

if [ -z "${HCPPIPEDIR}" ]; then
  echo "${script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
  exit 1
fi

source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source ${HCPPIPEDIR}/global/scripts/opts.shlib                   # Command line option functions
source ${HCPPIPEDIR}/global/scripts/processingmodecheck.shlib

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
log_Check_Env_Var FSLDIR
log_Check_Env_Var FREESURFER_HOME
log_Check_Env_Var CARET7DIR

 HCPPIPEDIR_FS=${HCPPIPEDIR}/FreeSurfer/scripts

########################################## SUPPORT FUNCTIONS ########################################## 

# NONE

################################################## OPTION PARSING #####################################################

log_Msg "Platform Information Follows: "
uname -a

log_Msg "Parsing Command Line Options"

# Input Variables
SubjectID=`opts_GetOpt1 "--subject" $@` #FreeSurfer Subject ID Name
SubjectDIR=`opts_GetOpt1 "--subjectDIR" $@` #Location to Put FreeSurfer Subject's Folder
T1wImage=`opts_GetOpt1 "--t1" $@` #T1w FreeSurfer Input (Full Resolution)
T1wImageBrain=`opts_GetOpt1 "--t1brain" $@` 
T2wImage=`opts_GetOpt1 "--t2" $@` #T2w FreeSurfer Input (Full Resolution)
recon_all_seed=`opts_GetOpt1 "--seed" $@`

# ------------------------------------------------------------------------------
#  Show Command Line Options
# ------------------------------------------------------------------------------

log_Msg "Finished Parsing Command Line Options"
log_Msg "SubjectID: ${SubjectID}"
log_Msg "SubjectDIR: ${SubjectDIR}"
log_Msg "T1wImage: ${T1wImage}"
log_Msg "T1wImageBrain: ${T1wImageBrain}"
log_Msg "T2wImage: ${T2wImage}"
log_Msg "recon_all_seed: ${recon_all_seed}"

# figure out whether to include a random seed generator seed in all the recon-all command lines
seed_cmd_appendix=""
if [ -z "${recon_all_seed}" ] ; then
	seed_cmd_appendix=""
else
	seed_cmd_appendix="-norandomness -rng-seed ${recon_all_seed}"
fi
log_Msg "seed_cmd_appendix: ${seed_cmd_appendix}"


# ------------------------------------------------------------------------------
#  Compliance check
# ------------------------------------------------------------------------------

ProcessingMode=`opts_GetOpt1 "--processing-mode" $@`
ProcessingMode=`opts_DefaultOpt $ProcessingMode "HCPStyleData"`
Compliance="HCPStyleData"
ComplianceMsg=""

# -- T2w image

if [ "${T2wInputImages}" = "NONE" ]; then
  ComplianceMsg+=" --t2=NONE"
  Compliance="LegacyStyleData"
fi

check_mode_compliance "${ProcessingMode}" "${Compliance}" "${ComplianceMsg}"

# ------------------------------------------------------------------------------
#  Identify Tools
# ------------------------------------------------------------------------------

which_flirt=`which flirt`
flirt_version=`flirt -version`
log_Msg "which flirt: ${which_flirt}"
log_Msg "flirt -version: ${flirt_version}"

which_applywarp=`which applywarp`
log_Msg "which applywarp: ${which_applywarp}"

which_fslstats=`which fslstats`
log_Msg "which fslstats: ${which_fslstats}"

which_fslmaths=`which fslmaths`
log_Msg "which fslmaths: ${which_fslmaths}"

which_recon_all=`which recon-all`
recon_all_version=`recon-all --version`
log_Msg "which recon-all: ${which_recon_all}"
log_Msg "recon-all --version: ${recon_all_version}"

which_mri_convert=`which mri_convert`
log_Msg "which mri_convert: ${which_mri_convert}"

which_mri_em_register=`which mri_em_register`
mri_em_register_version=`mri_em_register --version`
log_Msg "which mri_em_register: ${which_mri_em_register}"
log_Msg "mri_em_register --version: ${mri_em_register_version}"

which_mri_watershed=`which mri_watershed`
mri_watershed_version=`mri_watershed --version`
log_Msg "which mri_watershed: ${which_mri_watershed}"
log_Msg "mri_watershed --version: ${mri_watershed_version}"

# ------------------------------------------------------------------------------
#  Start work
# ------------------------------------------------------------------------------

T1wImageFile=`remove_ext $T1wImage`;
T1wImageBrainFile=`remove_ext $T1wImageBrain`;

PipelineScripts=${HCPPIPEDIR_FS}

if [ -e "$SubjectDIR"/"$SubjectID"/scripts/IsRunning.lh+rh ] ; then
  rm "$SubjectDIR"/"$SubjectID"/scripts/IsRunning.lh+rh
fi

#Make Spline Interpolated Downsample to 1mm
log_Msg "Make Spline Interpolated Downsample to 1mm"

Mean=`fslstats $T1wImageBrain -M`
flirt -interp spline -in "$T1wImage" -ref "$T1wImage" -applyisoxfm 1 -out "$T1wImageFile"_1mm.nii.gz
applywarp --rel --interp=spline -i "$T1wImage" -r "$T1wImageFile"_1mm.nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$T1wImageFile"_1mm.nii.gz
applywarp --rel --interp=nn -i "$T1wImageBrain" -r "$T1wImageFile"_1mm.nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$T1wImageBrainFile"_1mm.nii.gz
fslmaths "$T1wImageFile"_1mm.nii.gz -div $Mean -mul 150 -abs "$T1wImageFile"_1mm.nii.gz

#Initial Recon-all Steps
log_Msg "Initial Recon-all Steps"

# Both the SGE and PBS cluster schedulers use the environment variable NSLOTS to indicate the number of cores
# a job will use.  If this environment variable is set, we will use it to determine the number of cores to
# tell recon-all to use.

if [[ -z ${NSLOTS} ]]
then
    num_cores=8
else
    num_cores="${NSLOTS}"
fi

# Call recon-all with flags that are part of "-autorecon1", with the exception of -skullstrip.
# -skullstrip of FreeSurfer not reliable for Phase II data because of poor FreeSurfer mri_em_register registrations with Skull on, 
# so run registration with PreFreeSurfer masked data and then generate brain mask as usual.
recon-all -i "$T1wImageFile"_1mm.nii.gz -subjid $SubjectID -sd $SubjectDIR -motioncor -talairach -nuintensitycor -normalization -openmp ${num_cores} ${seed_cmd_appendix}

# Generate brain mask
mri_convert "$T1wImageBrainFile"_1mm.nii.gz "$SubjectDIR"/"$SubjectID"/mri/brainmask.mgz --conform
mri_em_register -mask "$SubjectDIR"/"$SubjectID"/mri/brainmask.mgz "$SubjectDIR"/"$SubjectID"/mri/nu.mgz $FREESURFER_HOME/average/RB_all_2008-03-26.gca "$SubjectDIR"/"$SubjectID"/mri/transforms/talairach_with_skull.lta
mri_watershed -T1 -brain_atlas $FREESURFER_HOME/average/RB_all_withskull_2008-03-26.gca "$SubjectDIR"/"$SubjectID"/mri/transforms/talairach_with_skull.lta "$SubjectDIR"/"$SubjectID"/mri/T1.mgz "$SubjectDIR"/"$SubjectID"/mri/brainmask.auto.mgz 
cp "$SubjectDIR"/"$SubjectID"/mri/brainmask.auto.mgz "$SubjectDIR"/"$SubjectID"/mri/brainmask.mgz 

# Call recon-all to run most of the "-autorecon2" stages, but turning off smooth2, inflate2, curvstats, and segstats stages
recon-all -subjid $SubjectID -sd $SubjectDIR -autorecon2 -nosmooth2 -noinflate2 -nocurvstats -nosegstats -openmp ${num_cores} ${seed_cmd_appendix}

#Highres white stuff and Fine Tune T2w to T1w Reg
log_Msg "High resolution white matter and fine tune T2w to T1w registration"
"$PipelineScripts"/FreeSurferHiresWhite.sh "$SubjectID" "$SubjectDIR" "$T1wImage" "$T2wImage"

#Intermediate Recon-all Steps
log_Msg "Intermediate Recon-all Steps"
recon-all -subjid $SubjectID -sd $SubjectDIR -smooth2 -inflate2 -curvstats -sphere -surfreg -jacobian_white -avgcurv -cortparc -openmp ${num_cores} ${seed_cmd_appendix}

#Highres pial stuff (this module adjusts the pial surface based on the the T2w image)
log_Msg "High Resolution pial surface"
"$PipelineScripts"/FreeSurferHiresPial.sh "$SubjectID" "$SubjectDIR" "$T1wImage" "$T2wImage"

#Final Recon-all Steps
log_Msg "Final Recon-all Steps"
recon-all -subjid $SubjectID -sd $SubjectDIR -surfvolume -parcstats -cortparc2 -parcstats2 -cortparc3 -parcstats3 -cortribbon -segstats -aparc2aseg -wmparc -balabels -label-exvivo-ec -openmp ${num_cores} ${seed_cmd_appendix}

log_Msg "Completed!"

