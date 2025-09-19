#!/bin/bash

# # PostFreeSurferPipelineLongPrep.sh
#
# ## Copyright Notice
#
# Copyright (C) 2022-2024 The Human Connectome Project
#
# * Washington University in St. Louis
# * University of Minnesota
# * Oxford University
#
# ## Author(s)
#
# * Mikhail Milchenko, Department of Radiology, Washington University in St. Louis
# * Matthew F. Glasser, Department of Anatomy and Neurobiology, Washington University in St. Louis
#
# ## Product
#
# [Human Connectome Project][HCP] (HCP) Longitudinal Pipelines
#
# ## License
#
# See the [LICENSE](https://github.com/Washington-University/HCPPipelines/blob/master/LICENSE.md) file

set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi


# Requirements for this script
#  installed versions of: FSL
#  environment: HCPPIPEDIR, FSLDIR


source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
#pending resolution on T1w-only mode support by longitudinal scripts.
#source "$HCPPIPEDIR/global/scripts/processingmodecheck.shlib" "$@" # Check processing mode requirements

log_Msg "Platform Information Follows: "
uname -a
"$HCPPIPEDIR"/show_version

opts_SetScriptDescription "takes cross-sectional PreFreeSurfer output, as well as longitudinal FreeSurfer output folders. \
Creates volumes and transforms analogous to those produced by PreFreeSurferPipeline, but in longitudinal template space"

opts_AddMandatory '--path' 'StudyFolder' 'path' "folder containing all timepoins and templates" "--path"
opts_AddMandatory '--subject'   'Subject'   'subject ID' "Subject ID. Note: this is distinct subject ID. It is to be used \
                    in the output folder name as <Subject>.long.<Template> for the template and <Subject>.long.<Session> for timepoint"
opts_AddMandatory '--longitudinal-template'  'Template'  'FS template ID' "Longitudinal template ID (same as Freesurfer long template ID)"
opts_AddMandatory '--sessions' 'Timepoints_string' 'FS timepoint ID(s)' "Freesurfer timepoint ID(s). For timepoint (session)\
                    processing, specify current timepoint. For template processing, must specify all timepoints, @ separated.\
                    Timepoint ID and Session are synonyms in HCP structural pipelines."
opts_AddMandatory '--template_processing' 'TemplateProcessing' 'create template flag' "0 if TP processing; 1 if template processing (must be run after all TP's)"

#the following options have the same meaning as in PreFreesurferPipeline.
opts_AddMandatory '--t1template' 'T1wTemplate' 'file_path' "MNI T1w template"
opts_AddMandatory '--t1templatebrain' 'T1wTemplateBrain' 'file_path' "Brain extracted MNI T1wTemplate"
opts_AddMandatory '--t1template2mm' 'T1wTemplate2mm' 'file_path' "MNI 2mm T1wTemplate"
opts_AddMandatory '--t2template' 'T2wTemplate' 'file_path' "MNI T2w template"
opts_AddMandatory '--t2templatebrain' 'T2wTemplateBrain' 'file_path' "Brain extracted MNI T2wTemplate"
opts_AddMandatory '--t2template2mm' 'T2wTemplate2mm' 'file_path' "MNI 2mm T2wTemplate"
opts_AddMandatory '--templatemask' 'TemplateMask' 'file_path' "Brain mask MNI Template"
opts_AddMandatory '--template2mmmask' 'Template2mmMask' 'file_path' "Brain mask MNI 2mm Template"
opts_AddMandatory '--fnirtconfig' 'FNIRTConfig' 'file_path' "FNIRT 2mm T1w Configuration file"

#needed to transform Freesurfer mask to MNI space.
opts_AddMandatory '--freesurferlabels' 'FreeSurferLabels' 'file' "location of FreeSurferAllLut.txt"


opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FSLDIR
log_Check_Env_Var HCPPIPEDIR_Global

# Naming Conventions

T1wImageBrainMask="brainmask_fs"
MNI_hires_template="$HCPPIPEDIR/global/templates/MNI152_T1_0.8mm.nii.gz"
TemplateProcessing=$(opts_StringToBool "$TemplateProcessing")
echo "Timepoints_string: $Timepoints_string"

if [[ "$Timepoints_string" =~ "@" ]]; then
    if (( ! TemplateProcessing )); then
            log_Err_Abort "More than one timepoint is specified in timepoint mode, please check calling script."
    fi
    IFS='@' read -r -a timepoints <<< "$Timepoints_string"
    #Timepoint_cross in template mode must point to the first specified timepoint, used to detect if T2w images are available.
    Timepoint_cross=${timepoints[0]}
    echo "timepoints: ${timepoints[@]}"
    echo "timepoints[0]: ${timepoints[0]}"
else
    if (( TemplateProcessing )); then
        log_Err_Abort "At least two timepoints must be specified in template processing mode, please check calling script."
    fi
    #Timepoint_cross in timepoint mode must point to the current timepoint.
    Timepoint_cross=$Timepoints_string
    echo "Timepoint_cross: $Timepoint_cross"
fi

#########################################################################################
# Organizing and cleaning up the folder structure
#########################################################################################
if (( ! TemplateProcessing )); then

    LongDIR="${StudyFolder}/${Subject}.long.${Template}/T1w"

    log_Msg "Organizing the folder structure for: ${Timepoint_cross}"
    # create the symlink
    TargetDIR="${StudyFolder}/${Timepoint_cross}.long.${Template}/T1w"
    mkdir -p "${TargetDIR}"

    tp_folder_fslong="${LongDIR}/${Timepoint_cross}.long.${Template}"
    if [ ! -d "$tp_folder_fslong" ]; then
    	log_Err_Abort "Folder $tp_folder_fslong does not exist, was longitudinal FreeSurfer run?"
    fi

    tp_folder_hcp="${TargetDIR}/${Timepoint_cross}.long.${Template}"
    ln -sf "$tp_folder_fslong" "$tp_folder_hcp"
    if [ ! -d "$tp_folder_hcp" ]; then
    	log_Err_Abort "Could not create required symlink from $tp_folder_fslong to $tp_folder_hcp"
    fi

    # remove the symlink in the subject's folder
    rm -rf "${LongDIR}/${Timepoint_cross}"
fi

############################################################################################################
# The next block computes the transform from T1w_acpc_dc (cross) to T1w_acpc_dc (long_template).
Timepoint_long=$Timepoint_cross.long.$Template
T1w_dir_cross=$StudyFolder/$Timepoint_cross/T1w
T1w_dir_long=$StudyFolder/$Timepoint_long/T1w
T1w_dir_template=$StudyFolder/$Subject.long.$Template/T1w

if (( TemplateProcessing == 0 )); then #timepoint mode

    LTA_norm_to_template=$T1w_dir_template/$Template/mri/transforms/${Timepoint_cross}_to_${Template}.lta
    log_Msg "Timepoint processing: computing the transform from T1w_acpc_dc (cross) to T1w_acpc_dc (longitudinal template)"
    mkdir -p $T1w_dir_long/xfms
    #Snorm=$T1w_dir_long/$Timepoint_long/mri/norm
    Snorm=$T1w_dir_cross/$Timepoint_cross/mri/norm
    mri_convert $Snorm.mgz $Snorm.nii.gz

    T1w_cross=$T1w_dir_cross/T1w_acpc_dc_restore.nii.gz
    T1w_long=$T1w_dir_long/T1w_acpc_dc_restore.nii.gz
    T2w_long=$T1w_dir_long/T2w_acpc_dc_restore.nii.gz

    #1. create resample transform from timepoints' T1w to 'norm' (equiv. to 'orig') space. This only applies reorient/resample,
    #no actual registration -- it is just a coordinate conversion between the HCP volume space and freesurfer's.
    lta_convert --inlta identity.nofile --src $T1w_cross --trg $Snorm.nii.gz --outlta $T1w_dir_long/xfms/T1w_cross_to_norm.lta
    #2. Invert TP->norm transforms. Again, this is only reorient/resample, this isn't an actual registration transform.
    lta_convert --inlta $T1w_dir_long/xfms/T1w_cross_to_norm.lta --outlta $T1w_dir_long/xfms/norm_to_T1w_cross.lta --invert
    #3. concatnate previous transform with TP(orig)->template(orig) transform computed by FS.
    mri_concatenate_lta $T1w_dir_long/xfms/T1w_cross_to_norm.lta $LTA_norm_to_template $T1w_dir_long/xfms/T1w_cross_to_template.lta
    #4. Combine TP->template and orig->TP transforms to get TP->TP(HCP template) transform.
    mri_concatenate_lta $T1w_dir_long/xfms/T1w_cross_to_template.lta $T1w_dir_long/xfms/norm_to_T1w_cross.lta $T1w_dir_long/xfms/T1w_cross_to_T1w_long.lta
    #5. convert the final TP_T1w->TP_T1w(HCP template) LTA transform to .mat(FSL).
    lta_convert --inlta $T1w_dir_long/xfms/T1w_cross_to_T1w_long.lta --src $T1w_cross --trg $T1w_cross --outfsl $T1w_dir_long/xfms/T1w_cross_to_T1w_long.mat
fi
#nothing to do in template mode for this block.
#end block

#################################################################################################################
# The next block resamples T1w from native to the longitudinal acpc_dc template space, using cross-sectional
# readout distortion correction warp.

if (( TemplateProcessing == 0 )); then
    log_Msg "Timepoint $Timepoint_long: combining warps and resampling T1w_acpc_dc to longitudinal template space"

    #first, create the warp transform.
    convertwarp --premat="$T1w_dir_cross/xfms/acpc.mat" --ref=$MNI_hires_template \
        --warp1=$T1w_dir_cross/xfms/T1w_dc.nii.gz --postmat=$T1w_dir_long/xfms/T1w_cross_to_T1w_long.mat --out=$T1w_dir_long/xfms/T1w_acpc_dc_long.nii.gz
    #second, apply warp.
    applywarp --interp=spline -i $T1w_dir_cross/T1w.nii.gz -r $MNI_hires_template \
        -w $T1w_dir_long/xfms/T1w_acpc_dc_long.nii.gz -o $T1w_dir_long/T1w_acpc_dc.nii.gz
fi
#nothing to do in template mode for this block.
#end block

# Detect if T2w is used - all modes.
# $T1w_dir_cross points to the first timepoint (template mode) or current timepoint (timepoint mode)
if [ -f "$T1w_dir_cross/xfms/T2w_reg_dc.nii.gz" ]; then
    Use_T2w=1
else
    log_Msg "T2w->T1w TRANSFORM NOT FOUND, T2w IMAGE WILL NOT BE USED"
    Use_T2w=0
fi

##############################################################################################################
# The next block creates the warp from T2w to template space, including readout distortion correction, and applies it

if (( TemplateProcessing == 0 )); then

    T2w_dir_cross=$StudyFolder/$Timepoint_cross/T2w
    T2w_dir_long=$StudyFolder/$Timepoint_long/T2w
    mkdir -p $T2w_dir_long/xfms

    #This uses combined transform from T1w to T2w, whish is always generated. Should replace the if statements below.
    if [ -f "$T1w_dir_cross/xfms/T2w_reg_dc.nii.gz" ]; then

        #Freesurfer BBR refinement after T2w_cross->T1w_cross transform
        T2w_on_T1w_to_T1w_cross_BBR=$T1w_dir_cross/$Timepoint_cross/mri/transforms/T2wtoT1w.mat
        if [ ! -f "$T2w_on_T1w_to_T1w_cross_BBR" ]; then
            log_Err_Abort "FreeSurfer BBR refinement T2w->T1w transform not found, cannot continue."
        fi
        #concat BBR refinement T2w_on_T1w_cross->T2w_on_T1w_cross (refined)->T1w_long
        T2w_on_T1w_BBR_to_T1w_long=$T1w_dir_long/xfms/T2w_on_T1w_cross_BBR_to_T1w_long.mat
        convert_xfm -omat $T2w_on_T1w_BBR_to_T1w_long -concat $T1w_dir_long/xfms/T1w_cross_to_T1w_long.mat $T2w_on_T1w_to_T1w_cross_BBR
        log_Msg "Timepoint $Timepoint_long: warping T2-weighted image to T2w_acpc_dc in longitudinal template space"
        convertwarp --premat=$T2w_dir_cross/xfms/acpc.mat --ref=$MNI_hires_template \
            --warp1=$T1w_dir_cross/xfms/T2w_reg_dc.nii.gz --postmat=$T2w_on_T1w_BBR_to_T1w_long --out=$T2w_dir_long/xfms/T2w2template.nii.gz
    else
        log_Msg "T2w->T1w TRANSFORM NOT FOUND, T2w IMAGE WILL NOT BE USED"
        Use_T2w=0
    fi
    if (( Use_T2w )); then
        applywarp --interp=spline -i $T2w_dir_cross/T2w.nii.gz -r $MNI_hires_template \
            -w $T2w_dir_long/xfms/T2w2template.nii.gz -o $T1w_dir_long/T2w_acpc_dc.nii.gz
    fi
fi
#Nothing to do in template mode.
#end block

############################################################################################################
# The next block creates original brain masks from wmparc.mgz. The final brain mask will be computed later.
# Convert FreeSurfer Volumes

T1wImageBrainMask_orig="$T1wImageBrainMask"_orig

if (( TemplateProcessing == 0 )); then
    FreeSurferFolder_TP_long="$StudyFolder/$Timepoint_long/T1w/$Timepoint_long"
    log_Msg "Timepoint $Timepoint_long: creating brain mask in template acpc_dc space"
    mri_convert -rt nearest -rl "$T1w_dir_long/T1w_acpc_dc.nii.gz" "$FreeSurferFolder_TP_long"/mri/wmparc.mgz "$T1w_dir_long"/wmparc_1mm.nii.gz
    applywarp --rel --interp=nn -i "$T1w_dir_long"/wmparc_1mm.nii.gz -r "$T1w_dir_long"/"T1w_acpc_dc".nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$T1w_dir_long"/wmparc.nii.gz

    #Create FreeSurfer Brain Mask
    fslmaths "$T1w_dir_long"/wmparc_1mm.nii.gz -bin -dilD -dilD -dilD -ero -ero "$T1w_dir_long"/"$T1wImageBrainMask_orig"_1mm.nii.gz
    ${CARET7DIR}/wb_command -volume-fill-holes "$T1w_dir_long"/"$T1wImageBrainMask_orig"_1mm.nii.gz "$T1w_dir_long"/"$T1wImageBrainMask_orig"_1mm.nii.gz
    fslmaths "$T1w_dir_long"/"$T1wImageBrainMask_orig"_1mm.nii.gz -bin "$T1w_dir_long"/"$T1wImageBrainMask_orig"_1mm.nii.gz
    applywarp --rel --interp=nn -i "$T1w_dir_long"/"$T1wImageBrainMask_orig"_1mm.nii.gz -r "$T1w_dir_long"/T1w_acpc_dc.nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$T1w_dir_long"/"$T1wImageBrainMask_orig".nii.gz
else
    #template mode
    FreeSurferFolder_Template="$T1w_dir_template/$Template"
    log_Msg "Template $Template: creating brain mask in template acpc_dc space"
    mri_convert -rt nearest -rl "$T1w_dir_long/T1w_acpc_dc.nii.gz" "$FreeSurferFolder_Template"/mri/wmparc.mgz "$T1w_dir_template"/wmparc_1mm.nii.gz
    applywarp --rel --interp=nn -i "$T1w_dir_template"/wmparc_1mm.nii.gz -r "$T1w_dir_long"/"T1w_acpc_dc".nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$T1w_dir_template"/wmparc.nii.gz
    fslmaths "$T1w_dir_template"/wmparc_1mm.nii.gz -bin -dilD -dilD -dilD -ero -ero "$T1w_dir_template"/"$T1wImageBrainMask_orig"_1mm.nii.gz
    ${CARET7DIR}/wb_command -volume-fill-holes "$T1w_dir_template"/"$T1wImageBrainMask_orig"_1mm.nii.gz "$T1w_dir_template"/"$T1wImageBrainMask_orig"_1mm.nii.gz
    fslmaths "$T1w_dir_template"/"$T1wImageBrainMask_orig"_1mm.nii.gz -bin "$T1w_dir_template"/"$T1wImageBrainMask_orig"_1mm.nii.gz
    applywarp --rel --interp=nn -i "$T1w_dir_template"/"$T1wImageBrainMask_orig"_1mm.nii.gz -r "$T1w_dir_long"/T1w_acpc_dc.nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$T1w_dir_template"/"$T1wImageBrainMask_orig".nii.gz
fi

##############################################################################################################
# The next block applies warp field from the one computed for cross-sectional runs.

if (( TemplateProcessing == 0 )); then
    BiasField_cross="$T1w_dir_cross/BiasField_acpc_dc"
    BiasField_long="$T1w_dir_long/BiasField_acpc_dc"
    log_Msg "Timepoint $Timepoint_long: warping bias field to longitudinal template space"
    if [ -f "$BiasField_cross.nii.gz" ]; then
        applywarp --interp=spline -i $BiasField_cross -r $MNI_hires_template \
            --premat=$T1w_dir_long/xfms/T1w_cross_to_T1w_long.mat -o $BiasField_long
    fi
fi
#nothing to do in template mode
#end block

#################################################################################################
# This block finalizes the output of TXw images (re-create the _restore version) before atlas registration.
 log_Msg "Creating one-step resampled version of {T1w,T2w}_acpc_dc outputs"

 # T1w
#Applies GFC to T1w and T2w
if (( TemplateProcessing == 0 )); then

  log_Msg "Timepoint $Timepoint_long: applying gain field to T1w,T2w images in longitudinal acpc_dc template space"
  OutputT1wImage=${T1w_dir_long}/T1w_acpc_dc
  #${FSLDIR}/bin/fslmaths $T1w_dir_long/T1w_acpc_dc.nii.gz -div $BiasField_long -mas "$T1w_dir_long"/"$T1wImageBrainMask"_orig.nii.gz $T1w_long -odt float

  fslmaths ${OutputT1wImage} -abs ${OutputT1wImage} -odt float  # Use -abs (rather than '-thr 0') to avoid introducing zeros
  fslmaths ${OutputT1wImage} -div ${T1w_dir_long}/BiasField_acpc_dc ${OutputT1wImage}_restore
  #fslmaths ${OutputT1wImage}_restore -mas "$T1w_dir_long"/"$T1wImageBrainMask".nii.gz ${OutputT1wImage}_restore_brain

  if (( Use_T2w )); then
    OutputT2wImage=${T1w_dir_long}/T2w_acpc_dc
    fslmaths ${OutputT2wImage} -abs ${OutputT2wImage} -odt float  # Use -abs (rather than '-thr 0') to avoid introducing zeros
    fslmaths ${OutputT2wImage} -div ${T1w_dir_long}/BiasField_acpc_dc ${OutputT2wImage}_restore
    #fslmaths ${OutputT2wImage}_restore -mas "$T1w_dir_long"/"$T1wImageBrainMask".nii.gz ${OutputT2wImage}_restore_brain
  fi

else #make tempate images
    log_Msg "Template $Template: creating average templates and masks from timepoints"
    OutputBrainMask="${T1w_dir_template}/$T1wImageBrainMask"
    OutputT1wImage_unrestore="${T1w_dir_template}/T1w_acpc_dc"
    OutputT1wImage="${OutputT1wImage_unrestore}_restore"

    OutputT2wImage_unrestore="${T1w_dir_template}/T2w_acpc_dc"
    OutputT2wImage="${OutputT2wImage_unrestore}_restore"

    nTP=${#timepoints[@]}
    tp=${timepoints[0]}

    brainmask_cmd="fslmaths $StudyFolder/$tp.long.$Template/T1w/$T1wImageBrainMask_orig"
    template_cmd="fslmaths $StudyFolder/$tp.long.$Template/T1w/T1w_acpc_dc_restore"
    template_cmd_unrestore="fslmaths $StudyFolder/$tp.long.$Template/T1w/T1w_acpc_dc"
    template_cmd_t2w="fslmaths $StudyFolder/$tp.long.$Template/T1w/T2w_acpc_dc_restore"
    template_cmd_t2w_unrestore="fslmaths $StudyFolder/$tp.long.$Template/T1w/T2w_acpc_dc"

    for (( i=1; i<nTP; i++)); do
        tp=${timepoints[i]}
        brainmask_cmd+=" -max $StudyFolder/$tp.long.$Template/T1w/$T1wImageBrainMask_orig"
        template_cmd+=" -add $StudyFolder/$tp.long.$Template/T1w/T1w_acpc_dc_restore"
        template_cmd_unrestore+=" -add $StudyFolder/$tp.long.$Template/T1w/T1w_acpc_dc"
        template_cmd_t2w+=" -add $StudyFolder/$tp.long.$Template/T1w/T2w_acpc_dc_restore"
        template_cmd_t2w_unrestore+=" -add $StudyFolder/$tp.long.$Template/T1w/T2w_acpc_dc"
    done

    brainmask_cmd+=" $OutputBrainMask -odt float"
    template_cmd+=" -div $nTP $OutputT1wImage -odt float"
    template_cmd_unrestore+=" -div $nTP $OutputT1wImage_unrestore -odt float"
    template_cmd_t2w+=" -div $nTP $OutputT2wImage -odt float"
    template_cmd_t2w_unrestore+=" -div $nTP $OutputT2wImage_unrestore -odt float"

    $template_cmd
    $template_cmd_unrestore
    $brainmask_cmd

    fslmaths "$OutputT1wImage" -mas "$T1w_dir_template/$T1wImageBrainMask.nii.gz" "${OutputT1wImage}_brain"
    fslmaths "$OutputT1wImage_unrestore" -mas "$T1w_dir_template/$T1wImageBrainMask.nii.gz" "${OutputT1wImage_unrestore}_brain"

    if (( Use_T2w )); then
        $template_cmd_t2w
        $template_cmd_t2w_unrestore
        fslmaths $OutputT2wImage -mas "$T1w_dir_template/$T1wImageBrainMask.nii.gz" ${OutputT2wImage}_brain
        fslmaths $OutputT2wImage_unrestore -mas "$T1w_dir_template/$T1wImageBrainMask.nii.gz" ${OutputT2wImage_unrestore}_brain
    fi
fi
# end block

################################################################################################################
# Register template to MNI space and resample all timepoints to MNI space using acquired transform.

if (( TemplateProcessing ==  1 )); then
    AtlasSpaceFolder_template=$StudyFolder/$Subject.long.$Template/MNINonLinear
    WARP=xfms/acpc_dc2standard.nii.gz
    INVWARP=xfms/standard2acpc_dc.nii.gz
    WARP_JACOBIANS=xfms/NonlinearRegJacobians.nii.gz

    # run template->MNI registration

    #NB. _acpc_dc images will be the same as acpc_dc_restore as 'unrestore' version is meaningless for the template.
    log_Msg "template $Template: performing atlas registration from longitudinal template to MNI152 (FLIRT and FNIRT)"

    ${HCPPIPEDIR_PreFS}/AtlasRegistrationToMNI152_FLIRTandFNIRT.sh \
        --workingdir=${AtlasSpaceFolder_template} \
        --t1=${T1w_dir_template}/T1w_acpc_dc \
        --t1rest=${T1w_dir_template}/T1w_acpc_dc_restore \
        --t1restbrain=${T1w_dir_template}/T1w_acpc_dc_restore_brain \
        --t2=${T1w_dir_template}/T2w_acpc_dc \
        --t2rest=${T1w_dir_template}/T2w_acpc_dc_restore \
        --t2restbrain=${T1w_dir_template}/T2w_acpc_dc_restore_brain \
        --ref=${T1wTemplate} \
        --refbrain=${T1wTemplateBrain} \
        --refmask=${TemplateMask} \
        --ref2mm=${T1wTemplate2mm} \
        --ref2mmmask=${Template2mmMask} \
        --owarp=${AtlasSpaceFolder_template}/$WARP \
        --oinvwarp=${AtlasSpaceFolder_template}/$INVWARP \
        --ot1=${AtlasSpaceFolder_template}/T1w \
        --ot1rest=${AtlasSpaceFolder_template}/T1w_restore \
        --ot1restbrain=${AtlasSpaceFolder_template}/T1w_restore_brain \
        --ot2=${AtlasSpaceFolder_template}/T2w \
        --ot2rest=${AtlasSpaceFolder_template}/T2w_restore \
        --ot2restbrain=${AtlasSpaceFolder_template}/T2w_restore_brain \
        --fnirtconfig=${FNIRTConfig}

    # Resample brain mask (FS) to atlas space
    #applywarp --rel --interp=nn -i "$T1w_dir_template"/"$T1wImageBrainMask"_1mm.nii.gz -r "$AtlasSpaceFolder_template"/"T1w_restore" -w "${AtlasSpaceFolder_template}"/"$WARP" -o "$AtlasSpaceFolder_template"/"$T1wImageBrainMask".nii.gz
    log_Msg "Template $Template: warping brain mask to MNI space"
    applywarp --rel --interp=nn -i "$T1w_dir_template"/"$T1wImageBrainMask".nii.gz -r "$AtlasSpaceFolder_template"/"T1w_restore" -w "${AtlasSpaceFolder_template}"/"$WARP" -o "$AtlasSpaceFolder_template"/"$T1wImageBrainMask".nii.gz

    #finalize all TP's with template to MNI152 atlas transform
    for tp in ${timepoints[@]}; do
        log_Msg "Timepoint $tp: applying MNI152 atlas transform and brain mask"
        #These variables are redefined
        Timepoint_long=$tp.long.$Template
        AtlasSpaceFolder_timepoint=$StudyFolder/$Timepoint_long/MNINonLinear
        T1w_dir_long=$StudyFolder/$Timepoint_long/T1w
        Timepoint_brain_mask_acpc_dc="$T1w_dir_long"/"$T1wImageBrainMask".nii.gz
        Timepoint_brain_mask_MNI="${AtlasSpaceFolder_timepoint}"/"$T1wImageBrainMask".nii.gz

        #link altas transforms to the timepoint directory.
        if [ -d "$AtlasSpaceFolder_timepoint/xfms" ]; then
            rm -rf "$AtlasSpaceFolder_timepoint/xfms"
        fi
        mkdir -p "${AtlasSpaceFolder_timepoint}"
        ln -sf "${AtlasSpaceFolder_template}/xfms" "${AtlasSpaceFolder_timepoint}/"

        #one mask for all timepoints.
        cp "${AtlasSpaceFolder_template}/$T1wImageBrainMask".nii.gz "$Timepoint_brain_mask_MNI"
        cp "${T1w_dir_template}/$T1wImageBrainMask".nii.gz "$Timepoint_brain_mask_acpc_dc"

        #mask the acpc_dc space images.
        ${FSLDIR}/bin/fslmaths $T1w_dir_long/T1w_acpc_dc -mas "$Timepoint_brain_mask_acpc_dc" $T1w_dir_long/T1w_acpc_dc_brain
        ${FSLDIR}/bin/fslmaths $T1w_dir_long/T1w_acpc_dc_restore -mas "$Timepoint_brain_mask_acpc_dc" $T1w_dir_long/T1w_acpc_dc_restore_brain

        # Bias field in MNI space.
        ${FSLDIR}/bin/applywarp --rel --interp=spline -i $T1w_dir_long/BiasField_acpc_dc -r ${T1wTemplate} -w ${AtlasSpaceFolder_template}/$WARP \
            -o ${AtlasSpaceFolder_timepoint}/BiasField

        # T1w set of warped outputs (brain/whole-head + restored/orig)
        verbose_echo " --> Generarting T1w set of warped outputs"

        ${FSLDIR}/bin/applywarp --rel --interp=spline -i $T1w_dir_long/T1w_acpc_dc -r ${T1wTemplate} -w ${AtlasSpaceFolder_template}/$WARP \
            -o ${AtlasSpaceFolder_timepoint}/T1w
        ${FSLDIR}/bin/applywarp --rel --interp=spline -i $T1w_dir_long/T1w_acpc_dc_restore -r ${T1wTemplate} -w ${AtlasSpaceFolder_template}/$WARP \
            -o ${AtlasSpaceFolder_timepoint}/T1w_restore
        #mask in MNI space
        ${FSLDIR}/bin/fslmaths ${AtlasSpaceFolder_timepoint}/T1w_restore -mas $Timepoint_brain_mask_MNI ${AtlasSpaceFolder_timepoint}/T1w_restore_brain

        # T2w set of warped outputs (brain/whole-head + restored/orig)
        if (( Use_T2w )); then
            verbose_echo " --> Creating T2w set of warped outputs"

            ${FSLDIR}/bin/applywarp --rel --interp=spline -i $T1w_dir_long/T2w_acpc_dc -r ${T1wTemplate} -w ${AtlasSpaceFolder_template}/$WARP \
                    -o ${AtlasSpaceFolder_timepoint}/T2w
            ${FSLDIR}/bin/applywarp --rel --interp=spline -i $T1w_dir_long/T2w_acpc_dc_restore -r ${T1wTemplate} -w ${AtlasSpaceFolder_template}/$WARP \
                    -o ${AtlasSpaceFolder_timepoint}/T2w_restore
            ${FSLDIR}/bin/fslmaths ${AtlasSpaceFolder_timepoint}/T2w_restore -mas $Timepoint_brain_mask_MNI ${AtlasSpaceFolder_timepoint}/T2w_restore_brain
        else
            verbose_echo " ... skipping T2w processing"
        fi
    done
fi
#end block
