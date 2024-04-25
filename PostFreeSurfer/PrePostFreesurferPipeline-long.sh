#!/bin/bash

# # PreFreeSurferPipeline.sh
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
# See the [LICENSE](https://github.com/Washington-University/Pipelines/blob/master/LICENSE.md) file


function create_zero_warp
{
    local target_image=$1 warp_file=$2

    # Step 1: Extract dimensions from the target image
    local dim1=$(fslval $target_image dim1)
    local dim2=$(fslval $target_image dim2)
    local dim3=$(fslval $target_image dim3)
    local pixdim1=$(fslval $target_image pixdim1)
    local pixdim2=$(fslval $target_image pixdim2)
    local pixdim3=$(fslval $target_image pixdim3)

    local temp=`mktemp volXXX`.nii.gz

    # Step 2: Create a zero-filled image with the same dimensions
    fslmaths $target_image -mul 0 $temp

    # Step 3: Merge it into a 4D file with three volumes (all zeros)
    fslmerge -t $warp_file $temp $temp $temp

    # Optional: Set the voxel dimensions correctly if needed
    fslcreatehd $dim1 $dim2 $dim3 3 $pixdim1 $pixdim2 $pixdim3 1 0 0 0 16 $warp_file
}


set -eu

# Requirements for this script
#  installed versions of: FSL
#  environment: HCPPIPEDIR, FSLDIR


source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/processingmodecheck.shlib" "$@" # Check processing mode requirements

log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var FSLDIR
log_Check_Env_Var HCPPIPEDIR_Global


log_Msg "Platform Information Follows: "
uname -a
"$HCPPIPEDIR"/show_version

#this function gets called by opts_ParseArguments when --help is specified
function usage()
{
    #header text
    echo "
$log_ToolName: takes cross-sectional pre-Freesurfer output, as well as longitudinal FreeSurfer output folders.
Creates volumes and transforms analogous to those produced by preFreesurferPipeline, but in longitudinal template space.

Usage: $log_ToolName PARAMETER...

PARAMETERs are [ ] = optional; < > = user supplied value
"
    #automatic argument descriptions
    opts_ShowArguments
    
    #do not use exit, the parsing code takes care of it
}

#arguments to opts_Add*: switch, variable to set, name for inside of <> in help text, description, [default value if AddOptional], [compatibility flag, ...]
#help info for option gets printed like "--foo=<$3> - $4"

#TSC:should --path or --study-folder be the flag displayed by the usage?
opts_AddMandatory '--path' 'StudyFolder' 'path' "folder containing all timepoins and templates" "--path"
#question: is 'subject ID' appropriate internal data type?
opts_AddMandatory '--subject'   'Subject'   'subject ID' "Subject label"
opts_AddMandatory '--template'  'Template'  'FS template ID' "Longitudinal template ID (same as Freesurfer template ID)"
opts_AddMandatory '--timepoints' 'Timepoints_cross' 'FS timepoint ID(s)' "Freesurfer timepoint ID(s). For timepoint\
                    processing, specify current timepoint. For template processing, must specify all timepoints, '@' separated"
opts_AddMandatory '--template_processing' 'TemplateProcessing' 'create template flag' "0 if TP processing; 1 if template processing (must be run after all TP's)"

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

#display the parsed/default values
opts_ShowValues

# Naming Conventions
T1wImage="T1w"
T1wImageBrainMask="brainmask_fs"
T1wFolder="T1w" #Location of T1w images
T2wImage="T2w"
T2wFolder="T2w" #Location of T2w images
Modalities="T1w T2w"
MNI_08mm_template="$HCPPIPEDIR/global/templates/MNI152_T1_0.8mm.nii.gz"

IFS='@' read -r -a timepoints <<< "$Timepoints_cross"
Timepoint_cross=${timepoints[0]}

############################################################################################################
# The next block computes the transform from T1w_acpc_dc (cross) to T1w_acpc_dc (long_template).
Timepoint_long=$Timepoint_cross.long.$Template
T1w_dir_cross=$StudyFolder/$Timepoint_cross/T1w
T1w_dir_long=$StudyFolder/$Timepoint_long/T1w
T1w_dir_template=$StudyFolder/$Subject.long.$Template/T1w
LTA_norm_to_template=$T1w_dir_template/$Template/mri/transforms/${Timepoint_cross}_to_${Template}.lta

if (( TemplateProcessing == 0 )); then #timepoint mode

    mkdir -p $T1w_dir_long/xfms
    #Snorm=$T1w_dir_long/$Timepoint_long/mri/norm
    Snorm=$T1w_dir_cross/$Timepoint_cross/mri/norm
    mri_convert $Snorm.mgz $Snorm.nii.gz

    T1w_cross=$T1w_dir_cross/T1w_acpc_dc_restore.nii.gz
    T1w_long=$T1w_dir_long/T1w_acpc_dc_restore.nii.gz
    T2w_long=$T1w_dir_long/T2w_acpc_dc_restore.nii.gz

    #1. create resample transform from timepoints' T1w to 'norm' (equiv. to 'orig') space. This only applies reorient/resample, no actual registration
    lta_convert --inlta identity.nofile --src $T1w_cross --trg $Snorm.nii.gz --outlta $T1w_dir_long/xfms/T1w_cross_to_norm.lta	

    #2. concatnate previous transform with TP(orig)->template(orig) transform computed by FS.
    mri_concatenate_lta $T1w_dir_long/xfms/T1w_cross_to_norm.lta $LTA_norm_to_template $T1w_dir_long/xfms/T1w_cross_to_template.lta
    #3. Invert TP->norm transforms. Again, this is only reorient/resample, this isn't an actual registration transform.
    lta_convert --inlta $T1w_dir_long/xfms/T1w_cross_to_norm.lta --outlta $T1w_dir_long/xfms/norm_to_T1w_cross.lta --invert
    #4. Combine TP->template and orig->TP transforms to get TP->TP(HCP template) transform.
    mri_concatenate_lta $T1w_dir_long/xfms/T1w_cross_to_template.lta $T1w_dir_long/xfms/norm_to_T1w_cross.lta $T1w_dir_long/xfms/T1w_cross_to_T1w_long.lta	
    #5. convert the final TP_T1w->TP_T1w(HCP template) LTA transform to .mat(FSL).
    lta_convert --inlta $T1w_dir_long/xfms/T1w_cross_to_T1w_long.lta --src $T1w_cross --trg $T1w_cross --outfsl $T1w_dir_long/xfms/T1w_cross_to_T1w_long.mat
else #Template mode
    :
fi    
#end block

#################################################################################################################
# The next block resamples T1w from native to the longitudinal acpc_dc template space, using cross-sectional 
# readout distortion correction warp.

if (( TemplateProcessing == 0 )); then 
    T1w_cross_gdc_warp=$T1w_dir_cross/xfms/${T1wImage}1_gdc_warp.nii.gz
    if [ ! -f "$T1w_cross_gdc_warp" ]; then
        log_Msg "NOT USING GRADIENT DISTORTION CORRECTION WARP"
        create_zero_warp $T1w_dir_cross/${T1wImage}1_gdc.nii.gz $T1w_cross_gdc_warp
    fi

    #first, create the warp transform.
    convertwarp --premat="$T1w_dir_cross/xfms/acpc.mat" --ref=$MNI_08mm_template \
        --warp1=$T1w_dir_cross/xfms/T1w_dc.nii.gz --postmat=$T1w_dir_long/xfms/T1w_cross_to_T1w_long.mat --out=$T1w_dir_long/xfms/T1w_acpc_dc_long.nii.gz
    #second, apply warp.
    applywarp --interp=spline -i $T1w_dir_cross/T1w.nii.gz -r $MNI_08mm_template \
        -w $T1w_dir_long/xfms/T1w_acpc_dc_long.nii.gz -o $T1w_dir_long/T1w_acpc_dc.nii.gz
else 
    :
fi
#end block


##############################################################################################################
# The next block creates the warp from T2w to template space, including readout distortion correction, and applies it

T2w_dir_cross=$StudyFolder/$Timepoint_cross/T2w
T2w_dir_long=$StudyFolder/$Timepoint_long/T2w
T2w_dir_template=$StudyFolder/$Subject.long.$Template/T1w
Use_T2w=1

if (( TemplateProcessing == 0 )); then 
    mkdir -p $T2w_dir_long/xfms

    #This uses combined transform from T1w to T2w, whish is always generated. Should replace the if statements below.
    if [ -f "$T1w_dir_cross/xfms/T2w_reg_dc.nii.gz" ]; then
        convertwarp --premat=$T2w_dir_cross/xfms/acpc.mat --ref=$MNI_08mm_template \
            --warp1=$T1w_dir_cross/xfms/T2w_reg_dc.nii.gz --postmat=$T1w_dir_long/xfms/T1w_cross_to_T1w_long.mat --out=$T2w_dir_long/xfms/T2w2template.nii.gz
    else
        log_Msg "T2w->T1w TRANSFORM NOT FOUND, T2w IMAGE WILL NOT BE USED"
        Use_T2w=0
    fi
    if (( Use_T2w )); then
        applywarp --interp=spline -i $T2w_dir_cross/T2w.nii.gz -r $MNI_08mm_template \
            -w $T2w_dir_long/xfms/T2w2template.nii.gz -o $T1w_dir_long/T2w_acpc_dc.nii.gz
    fi
else 
    :
fi
#end block

############################################################################################################
# The next block creates brain mask from wmparc.mgz
#Convert FreeSurfer Volumes
FreeSurferFolder_TP_long="$StudyFolder/$Timepoint_long/T1w/$Timepoint_long"
FreeSurferFolder_Template="$T1w_dir_template/$Template"
Image="wmparc"

if (( TemplateProcessing == 0 )); then 
    if [ -e "$FreeSurferFolder_TP_long"/mri/"$Image".mgz ] ; then
        mri_convert -rt nearest -rl "$T1w_dir_long/T1w_acpc_dc.nii.gz" "$FreeSurferFolder_TP_long"/mri/wmparc.mgz "$T1w_dir_long"/wmparc_1mm.nii.gz
        applywarp --rel --interp=nn -i "$T1w_dir_long"/wmparc_1mm.nii.gz -r "$T1w_dir_long"/"${T1wImage}_acpc_dc".nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$T1w_dir_long"/wmparc.nii.gz
    fi

    #Create FreeSurfer Brain Mask
    fslmaths "$T1w_dir_long"/wmparc_1mm.nii.gz -bin -dilD -dilD -dilD -ero -ero "$T1w_dir_long"/"$T1wImageBrainMask"_1mm.nii.gz
    ${CARET7DIR}/wb_command -volume-fill-holes "$T1w_dir_long"/"$T1wImageBrainMask"_1mm.nii.gz "$T1w_dir_long"/"$T1wImageBrainMask"_1mm.nii.gz
    fslmaths "$T1w_dir_long"/"$T1wImageBrainMask"_1mm.nii.gz -bin "$T1w_dir_long"/"$T1wImageBrainMask"_1mm.nii.gz
    applywarp --rel --interp=nn -i "$T1w_dir_long"/"$T1wImageBrainMask"_1mm.nii.gz -r "$T1w_dir_long"/"$T1wImage"_acpc_dc.nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$T1w_dir_long"/"$T1wImageBrainMask".nii.gz
    #applywarp --rel --interp=nn -i "$T1wFolder"/"$T1wImageBrainMask"_1mm.nii.gz -r "$AtlasSpaceFolder"/"$AtlasSpaceT1wImage" -w "$AtlasTransform" -o "$AtlasSpaceFolder"/"$T1wImageBrainMask".nii.gz
else 
    mri_convert -rt nearest -rl "$T1w_dir_long/T1w_acpc_dc.nii.gz" "$FreeSurferFolder_Template"/mri/wmparc.mgz "$T1w_dir_template"/wmparc_1mm.nii.gz
    applywarp --rel --interp=nn -i "$T1w_dir_template"/wmparc_1mm.nii.gz -r "$T1w_dir_long"/"${T1wImage}_acpc_dc".nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$T1w_dir_template"/wmparc.nii.gz

    fslmaths "$T1w_dir_template"/wmparc_1mm.nii.gz -bin -dilD -dilD -dilD -ero -ero "$T1w_dir_template"/"$T1wImageBrainMask"_1mm.nii.gz
    ${CARET7DIR}/wb_command -volume-fill-holes "$T1w_dir_template"/"$T1wImageBrainMask"_1mm.nii.gz "$T1w_dir_template"/"$T1wImageBrainMask"_1mm.nii.gz
    fslmaths "$T1w_dir_template"/"$T1wImageBrainMask"_1mm.nii.gz -bin "$T1w_dir_template"/"$T1wImageBrainMask"_1mm.nii.gz
    applywarp --rel --interp=nn -i "$T1w_dir_template"/"$T1wImageBrainMask"_1mm.nii.gz -r "$T1w_dir_long"/"$T1wImage"_acpc_dc.nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$T1w_dir_template"/"$T1wImageBrainMask".nii.gz    
fi

##############################################################################################################
# The next block runs gain field correction in the template space for the TXw images.


# Applies warp field from the one computed for cross-sectional runs.
BiasField_cross="$T1w_dir_cross/BiasField_acpc_dc"
BiasField_long="$T1w_dir_long/BiasField_acpc_dc"

if (( TemplateProcessing == 0 )); then 

    if [ -f "$BiasField_cross.nii.gz" ]; then
        applywarp --interp=spline -i $BiasField_cross -r $MNI_08mm_template \
            --premat=$T1w_dir_long/xfms/T1w_cross_to_T1w_long.mat -o $BiasField_long

    fi
else #no bias field in case of template is output.
    :
fi
#end block

#################################################################################################
# This block finalizes the output of TXw images (re-create the _restore version) before atlas registration.
 log_Msg "Creating one-step resampled version of {T1w,T2w}_acpc_dc outputs"

 # T1w
#Applies GFC to T1w and T2w
if (( TemplateProcessing == 0 )); then 

  OutputT1wImage=${T1w_dir_long}/${T1wImage}_acpc_dc
  ${FSLDIR}/bin/fslmaths $T1w_dir_long/T1w_acpc_dc.nii.gz -div $BiasField_long -mas "$T1w_dir_long"/"$T1wImageBrainMask".nii.gz $T1w_long -odt float

  fslmaths ${OutputT1wImage} -abs ${OutputT1wImage} -odt float  # Use -abs (rather than '-thr 0') to avoid introducing zeros
  fslmaths ${OutputT1wImage} -div ${T1w_dir_long}/BiasField_acpc_dc ${OutputT1wImage}_restore
  fslmaths ${OutputT1wImage}_restore -mas "$T1w_dir_long"/"$T1wImageBrainMask".nii.gz ${OutputT1wImage}_restore_brain

  if (( Use_T2w )); then
    OutputT2wImage=${T1w_dir_long}/${T2wImage}_acpc_dc
    fslmaths ${OutputT2wImage} -abs ${OutputT2wImage} -odt float  # Use -abs (rather than '-thr 0') to avoid introducing zeros
    fslmaths ${OutputT2wImage} -div ${T1w_dir_long}/BiasField_acpc_dc ${OutputT2wImage}_restore
    fslmaths ${OutputT2wImage}_restore -mas "$T1w_dir_long"/"$T1wImageBrainMask".nii.gz ${OutputT2wImage}_restore_brain
  fi
else #make restored tempate images
    OutputT1wImage=${T1w_dir_template}/${T1wImage}_acpc_dc_restore
    OutputT2wImage=${T1w_dir_template}/${T2wImage}_acpc_dc_restore

    nTP=${#timepoints[@]}
    tp=${timepoints[0]}
    template_cmd="fslmaths $StudyFolder/$tp.long.$Template/T1w/${T1wImage}_acpc_dc_restore"
    template_cmd_t2w="fslmaths $StudyFolder/$tp.long.$Template/T1w/${T2wImage}_acpc_dc_restore"
    for (( i=1; i<nTP; i++)); do
        tp=${timepoints[i]}
        template_cmd+=" -add $StudyFolder/$tp.long.$Template/T1w/${T1wImage}_acpc_dc_restore"
        template_cmd_t2w+=" -add $StudyFolder/$tp.long.$Template/T1w/${T2wImage}_acpc_dc_restore"
    done
    template_cmd+=" -div $nTP $OutputT1wImage -odt float"
    template_cmd_t2w+=" -div $nTP $OutputT2wImage -odt float"
    $template_cmd
    cp $OutputT1wImage.nii.gz ${T1w_dir_template}/${T1wImage}_acpc_dc    
    fslmaths $OutputT1wImage -mas "$T1w_dir_template/$T1wImageBrainMask.nii.gz" ${OutputT1wImage}_brain
    cp ${OutputT1wImage}_brain.nii.gz ${T1w_dir_template}/${T1wImage}_acpc_dc_brain.nii.gz
    if (( Use_T2w )); then 
        $template_cmd_t2w
        fslmaths $OutputT2wImage -mas "$T1w_dir_template/$T1wImageBrainMask.nii.gz" ${OutputT2wImage}_brain
        cp $OutputT2wImage.nii.gz ${T1w_dir_template}/${T2wImage}_acpc_dc
        cp ${OutputT2wImage}_brain.nii.gz ${T1w_dir_template}/${T2wImage}_acpc_dc_brain
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
    log_Msg "Performing Atlas Registration from longitudinal template to MNI152 (FLIRT and FNIRT)"    

    ${HCPPIPEDIR_PreFS}/AtlasRegistrationToMNI152_FLIRTandFNIRT.sh \
        --workingdir=${AtlasSpaceFolder_template} \
        --t1=${T1w_dir_template}/${T1wImage}_acpc_dc_restore \
        --t1rest=${T1w_dir_template}/${T1wImage}_acpc_dc_restore \
        --t1restbrain=${T1w_dir_template}/${T1wImage}_acpc_dc_restore_brain \
        --t2=${T1w_dir_template}/${T2wImage}_acpc_dc_restore \
        --t2rest=${T1w_dir_template}/${T2wImage}_acpc_dc_restore \
        --t2restbrain=${T1w_dir_template}/${T2wImage}_acpc_dc_restore_brain \
        --ref=${T1wTemplate} \
        --refbrain=${T1wTemplateBrain} \
        --refmask=${TemplateMask} \
        --ref2mm=${T1wTemplate2mm} \
        --ref2mmmask=${Template2mmMask} \
        --owarp=${AtlasSpaceFolder_template}/$WARP \
        --oinvwarp=${AtlasSpaceFolder_template}/$INVWARP \
        --ot1=${AtlasSpaceFolder_template}/${T1wImage} \
        --ot1rest=${AtlasSpaceFolder_template}/${T1wImage}_restore \
        --ot1restbrain=${AtlasSpaceFolder_template}/${T1wImage}_restore_brain \
        --ot2=${AtlasSpaceFolder_template}/${T2wImage} \
        --ot2rest=${AtlasSpaceFolder_template}/${T2wImage}_restore \
        --ot2restbrain=${AtlasSpaceFolder_template}/${T2wImage}_restore_brain \
        --fnirtconfig=${FNIRTConfig} 
        
        #Q. Should we remove _acpc_dc images from the AtlasSpaceFolder?

    # Resample brain mask (FS) to atlas space
    applywarp --rel --interp=nn -i "$T1w_dir_template"/"$T1wImageBrainMask"_1mm.nii.gz -r "$AtlasSpaceFolder_template"/"${T1wImage}_restore" -w "${AtlasSpaceFolder_template}"/"$WARP" -o "$AtlasSpaceFolder_template"/"$T1wImageBrainMask".nii.gz


    #finalize all TP's with template to MNI152 atlas transform
    for tp in ${timepoints[@]}; do
        #These variables are redefined
        Timepoint_long=$tp.long.$Template
        AtlasSpaceFolder_timepoint=$StudyFolder/$Timepoint_long/MNINonLinear
        T1w_dir_long=$StudyFolder/$Timepoint_long/T1w
        mkdir -p $AtlasSpaceFolder_timepoint/xfms

        #copy altas transforms to the timepoint directory.
        cp ${AtlasSpaceFolder_template}/$WARP ${AtlasSpaceFolder_timepoint}/$WARP
        cp ${AtlasSpaceFolder_template}/$INVWARP ${AtlasSpaceFolder_timepoint}/$INVWARP
        cp ${AtlasSpaceFolder_template}/$WARP_JACOBIANS ${AtlasSpaceFolder_timepoint}/$WARP_JACOBIANS
        
        # T1w set of warped outputs (brain/whole-head + restored/orig)
        verbose_echo " --> Generarting T1w set of warped outputs"

        ${FSLDIR}/bin/applywarp --rel --interp=spline -i $T1w_dir_long/${T1wImage}_acpc_dc -r ${T1wTemplate} -w ${AtlasSpaceFolder_template}/$WARP \
            -o ${AtlasSpaceFolder_timepoint}/${T1wImage}
        ${FSLDIR}/bin/applywarp --rel --interp=spline -i $T1w_dir_long/${T1wImage}_acpc_dc_restore -r ${T1wTemplate} -w ${AtlasSpaceFolder_template}/$WARP \
            -o ${AtlasSpaceFolder_timepoint}/${T1wImage}_restore
        ${FSLDIR}/bin/applywarp --rel --interp=nn -i $T1w_dir_long/${T1wImage}_acpc_dc_restore_brain -r ${T1wTemplate} -w ${AtlasSpaceFolder_template}/$WARP \
            -o ${AtlasSpaceFolder_timepoint}/${T1wImage}_restore_brain
        ${FSLDIR}/bin/fslmaths ${AtlasSpaceFolder_timepoint}/${T1wImage}_restore \
            -mas ${AtlasSpaceFolder_timepoint}/${T1wImage}_restore_brain ${AtlasSpaceFolder_timepoint}/${T1wImage}_restore_brain

        # Resample brain mask (FS) to atlas space
        applywarp --rel --interp=nn -i "$T1w_dir_long"/"$T1wImageBrainMask"_1mm.nii.gz -r "$AtlasSpaceFolder_timepoint"/"${T1wImage}_restore" -w "${AtlasSpaceFolder_template}"/"$WARP" -o "$AtlasSpaceFolder_timepoint"/"$T1wImageBrainMask".nii.gz

        # T2w set of warped outputs (brain/whole-head + restored/orig)
        if (( Use_T2w )); then
            verbose_echo " --> Creating T2w set of warped outputs"

            ${FSLDIR}/bin/applywarp --rel --interp=spline -i $T1w_dir_long/${T2wImage}_acpc_dc -r ${T1wTemplate} -w ${AtlasSpaceFolder_template}/$WARP \
                    -o ${AtlasSpaceFolder_timepoint}/${T2wImage}
            ${FSLDIR}/bin/applywarp --rel --interp=spline -i $T1w_dir_long/${T2wImage}_acpc_dc_restore -r ${T1wTemplate} -w ${AtlasSpaceFolder_template}/$WARP \
                    -o ${AtlasSpaceFolder_timepoint}/${T2wImage}_restore
            ${FSLDIR}/bin/applywarp --rel --interp=nn -i $T1w_dir_long/${T2wImage}_acpc_dc_restore_brain -r ${T1wTemplate} -w ${AtlasSpaceFolder_template}/$WARP \
                    -o ${AtlasSpaceFolder_timepoint}/${T2wImage}_restore_brain
            ${FSLDIR}/bin/fslmaths ${AtlasSpaceFolder_timepoint}/${T2wImage}_restore \
                    -mas ${AtlasSpaceFolder_timepoint}/${T2wImage}_restore_brain ${AtlasSpaceFolder_timepoint}/${T2wImage}_restore_brain
        else
            verbose_echo " ... skipping T2w processing"
        fi
    done
fi
#end block
