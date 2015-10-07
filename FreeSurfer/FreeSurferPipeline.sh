#!/bin/bash
set -e

# Requirements for this script
#  installed versions of: FSL (version 5.0.6), FreeSurfer (version 5.3.0-HCP)
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET7DIR

########################################## PIPELINE OVERVIEW ##########################################

#TODO

########################################## OUTPUT DIRECTORIES ##########################################

#TODO

# --------------------------------------------------------------------------------
#  Load Function Libraries
# --------------------------------------------------------------------------------

source $HCPPIPEDIR/global/scripts/log.shlib  # Logging related functions
source $HCPPIPEDIR/global/scripts/opts.shlib # Command line option functions

########################################## SUPPORT FUNCTIONS ##########################################

# --------------------------------------------------------------------------------
#  Usage Description Function
# --------------------------------------------------------------------------------

show_usage() {
    echo "Usage information To Be Written"
    exit 1
}

# --------------------------------------------------------------------------------
#   Establish tool name for logging
# --------------------------------------------------------------------------------
log_SetToolName "FreeSurferPipeline.sh"

# running the intial recon-all on fsl_sub gives a strange error: "(standard_in) 2: Error: comparison in expression" So far this doesn't seem to be a critical error.
# it can probably be solved by unsetting POSIXLY_CORRECT (set by fsl)
unset POSIXLY_CORRECT
# or: export POSIXLY_CORRECT=0

################################################## OPTION PARSING #####################################################

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
    show_usage
fi

log_Msg "Parsing Command Line Options"

# Input Variables
SubjectID=`opts_GetOpt1 "--subject" $@` #FreeSurfer Subject ID Name
SubjectDIR=`opts_GetOpt1 "--subjectDIR" $@` #Location to Put FreeSurfer Subject's Folder
T1wImage=`opts_GetOpt1 "--t1" $@` #T1w FreeSurfer Input (Full Resolution)
T1wImageBrain=`opts_GetOpt1 "--t1brain" $@`
T2wImage=`opts_GetOpt1 "--t2" $@` #T2w FreeSurfer Input (Full Resolution)

# ------------------------------------------------------------------------------
#  Show Command Line Options
# ------------------------------------------------------------------------------

log_Msg "Finished Parsing Command Line Options"
log_Msg "SubjectID: ${SubjectID}"
log_Msg "SubjectDIR: ${SubjectDIR}"
log_Msg "T1wImage: ${T1wImage}"
log_Msg "T1wImageBrain: ${T1wImageBrain}"
log_Msg "T2wImage: ${T2wImage}"

# ------------------------------------------------------------------------------
#  Show Environment Variables
# ------------------------------------------------------------------------------

log_Msg "HCPPIPEDIR: ${HCPPIPEDIR}"
log_Msg "HCPPIPEDIR_FS: ${HCPPIPEDIR_FS}"

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

# Start work

T1wImageFile=`remove_ext $T1wImage`;
T1wImageBrainFile=`remove_ext $T1wImageBrain`;

PipelineScripts=${HCPPIPEDIR_FS}


if [ -e "$SubjectDIR"/"$SubjectID"/scripts/IsRunning.lh+rh ] ; then
  rm "$SubjectDIR"/"$SubjectID"/scripts/IsRunning.lh+rh
fi

# get voxel dimensions for the T1w image
voxdim=$(fslinfo $T1wImage | awk '$1 ~ /pixdim[1-3]/ {print $2} ')
# test if they are high resolution or not
FlgRes=$(echo $voxdim | awk '{if($1==1 && $2==1 && $3==1) print(1); else if($1>1 || $2>1 || $3>1) print(2); else print(0)}')

# Downsample, or copy based on voxel dimensions
if [[ $FlgRes = 0 ]] ; then
  FlgHiRes="TRUE"

  #Make Spline Interpolated Downsample to 1mm
  log_Msg "Make Spline Interpolated Downsample to 1mm"

  Mean=`fslstats $T1wImageBrain -M`
  flirt -interp spline -in "$T1wImage" -ref "$T1wImage" -applyisoxfm 1 -out "$T1wImageFile"_1mm.nii.gz
  applywarp --rel --interp=spline -i "$T1wImage" -r "$T1wImageFile"_1mm.nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$T1wImageFile"_1mm.nii.gz
  applywarp --rel --interp=nn -i "$T1wImageBrain" -r "$T1wImageFile"_1mm.nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$T1wImageBrainFile"_1mm.nii.gz
  fslmaths "$T1wImageFile"_1mm.nii.gz -div $Mean -mul 150 -abs "$T1wImageFile"_1mm.nii.gz

else
  FlgHiRes="FALSE"

  #just copy and rename the files 1mm
  if [[ $FlgRes = 1 ]] ; then
    log_Msg "Copying and renaming the 1mm images for scripting conventions"
  else
    log_Msg "The T1w images are low-resolution (>1mm isotropic). Renaming them to 1mm for scripting conventions. Results might be poor."
  fi

  Mean=`fslstats $T1wImageBrain -M`
  cp "$T1wImage" "$T1wImageFile"_1mm.nii.gz
  cp "$T1wImageBrain" "$T1wImageBrainFile"_1mm.nii.gz
  fslmaths "$T1wImageFile"_1mm.nii.gz -div $Mean -mul 150 -abs "$T1wImageFile"_1mm.nii.gz

fi

# Both the SGE and PBS cluster schedulers use the environment variable NSLOTS to indicate the number of cores
# a job will use.  If this environment variable is set, we will use it to determine the number of cores to
# tell recon-all to use.
if [[ -z ${NSLOTS} ]] ; then
    num_cores=8
else
    num_cores="${NSLOTS}"
fi

#Initial Recon-all Steps
log_Msg "Initial Recon-all Steps"
#-skullstrip of FreeSurfer not reliable for Phase II data because of poor FreeSurfer mri_em_register registrations with Skull on, run registration with PreFreeSurfer masked data and then generate brain mask as usual
recon-all -i "$T1wImageFile"_1mm.nii.gz -subjid $SubjectID -sd $SubjectDIR -motioncor -talairach -nuintensitycor -normalization
mri_convert "$T1wImageBrainFile"_1mm.nii.gz "$SubjectDIR"/"$SubjectID"/mri/brainmask.mgz --conform
mri_em_register -mask "$SubjectDIR"/"$SubjectID"/mri/brainmask.mgz "$SubjectDIR"/"$SubjectID"/mri/nu.mgz $FREESURFER_HOME/average/RB_all_2008-03-26.gca "$SubjectDIR"/"$SubjectID"/mri/transforms/talairach_with_skull.lta
mri_watershed -T1 -brain_atlas $FREESURFER_HOME/average/RB_all_withskull_2008-03-26.gca "$SubjectDIR"/"$SubjectID"/mri/transforms/talairach_with_skull.lta "$SubjectDIR"/"$SubjectID"/mri/T1.mgz "$SubjectDIR"/"$SubjectID"/mri/brainmask.auto.mgz
cp "$SubjectDIR"/"$SubjectID"/mri/brainmask.auto.mgz "$SubjectDIR"/"$SubjectID"/mri/brainmask.mgz
recon-all -subjid $SubjectID -sd $SubjectDIR -autorecon2 -nosmooth2 -noinflate2 -nocurvstats -nosegstats -openmp ${num_cores}

<<"COMMENT_BLOCK"
#Highres white stuff and Fine Tune T2w to T1w Reg
[[ $FlgHiRes = "TRUE" ]] && [[ -n $T2wImage ]] && log_Msg "High resolution white matter and fine tune T2w to T1w registration"
[[ $FlgHiRes = "TRUE" ]] && [[ -z $T2wImage ]] && log_Msg "High resolution white matter, but no T2w available to register to T1w"
[[ $FlgHiRes = "FALSE" ]] && [[ -n $T2wImage ]] && log_Msg "No high resolution white matter available, but fine tuning T2w to T1w registration"
[[ $FlgHiRes = "FALSE" ]] && [[ -z $T2wImage ]] && log_Msg "No high resolution white matter available, nor a T2w to register to T1w"
"$PipelineScripts"/FreeSurferHiresWhite.sh "$SubjectID" "$SubjectDIR" "$T1wImage" "$T2wImage" "$FlgHiRes"

#Intermediate Recon-all Steps
log_Msg "Intermediate Recon-all Steps"
recon-all -subjid $SubjectID -sd $SubjectDIR -smooth2 -inflate2 -curvstats -sphere -surfreg -jacobian_white -avgcurv -cortparc

#Highres pial stuff (this module adjusts the pial surface based on the the T2w image)
[[ $FlgHiRes = "TRUE" ]] && [[ -n $T2wImage ]] && log_Msg "High resolution pial surface, using T2w for enhanced contrast"
[[ $FlgHiRes = "TRUE" ]] && [[ -z $T2wImage ]] && log_Msg "High resolution pial surface, but no T2w available for enhanced contrast"
[[ $FlgHiRes = "FALSE" ]] && [[ -n $T2wImage ]] && log_Msg "No high resolution pial surface available, using T2w for enhanced contrast"
[[ $FlgHiRes = "FALSE" ]] && [[ -z $T2wImage ]] && log_Msg "No high resolution pial surface available, nor a T2w for enhanced contrast"
"$PipelineScripts"/FreeSurferHiresPial.sh "$SubjectID" "$SubjectDIR" "$T1wImage" "$T2wImage" "$FlgHiRes"

#Final Recon-all Steps
log_Msg "Final Recon-all Steps"
recon-all -subjid $SubjectID -sd $SubjectDIR -surfvolume -parcstats -cortparc2 -parcstats2 -cortparc3 -parcstats3 -cortribbon -segstats -aparc2aseg -wmparc -balabels -label-exvivo-ec
COMMENT_BLOCK

log_Msg "Completed"
