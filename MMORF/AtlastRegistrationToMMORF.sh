#!/bin/bash 

# Requirements for this script
#  installed versions of: FSL
#  environment: HCPPIPEDIR, FSLDIR

# ------------------------------------------------------------------------------
#  Usage Description Function
# ------------------------------------------------------------------------------

set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

#Helper function here to correct for temp_dir for mountpoint. This has to be done. After experimenting, CHPC only allows read+write in using temp directory mounts.
#No short cut can be exploted here.
emit() {
    local line="$1"
    if [[ "$line" == ${mountPoint}/* ]]; then
        printf '%s\n' "\$temp_dir/${line#${mountPoint}/}"
    else
        printf '%s\n' "$line"
    fi
}


source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source "${HCPPIPEDIR}/global/scripts/newopts.shlib" "$@"

opts_SetScriptDescription "Tool for non-linearly registering DTI, T1w, T2w to MMORF space. Need to have T1w, T2w in the same space"

opts_AddMandatory '--t1' 'T1wImage' 'image' 't1w image'

opts_AddMandatory '--t1rest' 'T1wRestore' 'image' 'bias corrected t1w image'

opts_AddMandatory '--t1restbrain' 'T1wRestoreBrain' 'image' 'bias corrected brain extracted t1w image'

opts_AddMandatory '--t2' 'T2wImage' 't2w image' 't2w image'

opts_AddMandatory '--t2rest' 'T2wRestore' 'image' 'bias corrected t2w image'

opts_AddMandatory '--t2restbrain' 'T2wRestoreBrain' 'image' 'bias corrected, brain extracted t2w image'

opts_AddMandatory '--brainmask_fs' 'brainmask_fs' 'mask' 'Brainmask for t1w or t2w image'

opts_AddMandatory '--ref' 'Reference' 'image' 'reference image'

#opts_AddMandatory '--refbrain' 'ReferenceBrain' 'image' 'reference brain image'

opts_AddMandatory '--ref2' 'Reference2' 'image' 'reference image 2'

#opts_AddMandatory '--ref2brain' 'Reference2Brain' 'image' 'reference image brain 2'

opts_AddMandatory '--refmask' 'ReferenceMask' 'mask' 'reference brain mask'

opts_AddMandatory "--Diffusion" "Diffusion" "image" "Diffusion including bvecs, bvals, and data.nii.gz"

opts_AddMandatory "--DTImask" "DTImask" "image" "Mask for DTI"


opts_AddMandatory '--DTIref' 'DTIref' 'mask' 'reference for DTI'


opts_AddMandatory '--DTIrefmask' 'DTIrefMask' 'mask' 'reference brain mask for DTI'

opts_AddMandatory '--owarp' 'OutputTransform' 'number' 'output warp'

opts_AddMandatory '--oinvwarp' 'OutputInvTransform' 'inverse' 'output inverse warp'

opts_AddMandatory '--ot1' 'OutputT1wImage' 'image' 'output t1w to MNI'

opts_AddMandatory '--ot1rest' 'OutputT1wImageRestore' 'image' 'output bias corrected t1w to MNI'

opts_AddMandatory '--ot1restbrain' 'OutputT1wImageRestoreBrain' 'image' 'output bias corrected, brain extracted t1w to MNI'

opts_AddMandatory '--ot2' 'OutputT2wImage' 'image' 'output t2w to MNI'

opts_AddMandatory '--ot2rest' 'OutputT2wImageRestore' 'image' 'output bias corrected t2w to MNI'

opts_AddMandatory '--ot2restbrain' 'OutputT2wImageRestoreBrain' 'image' 'output bias corrected, brain extracted t2w to MNI'

opts_AddMandatory '--runlocally' 'runlocally' 'bool' 'If there is local GPU and is powerful enough'



##optional args
opts_AddOptional '--ref1mm' 'Reference1mm' 'image' 'reference 1mm image' "${HCPPIPEDIR_Templates}/MMORF_T1_1mm.nii.gz"

opts_AddOptional '--workingdir' 'WD' 'path' 'working directory' "."

opts_AddOptional '--mountPoint' 'mountPoint' 'mount point for CHPC' ""

opts_AddOptional '--Host' 'Host' 'Host for CHPC access' ""

opts_AddOptional '--CHPCHeader' 'CHPCHeader' 'The header to generate the .sh file' ""

opts_AddOptional '--LocalHost' 'LocalHost' 'The name of the local machine we are mounting to, make sure sshfs is set up.' ""

opts_AddOptional "--ClusterHomeDirectory" "ClusterHomeDirectory" "The directory of Cluster Home" ""


opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues


log_Check_Env_Var FSLDIR

T1wRestoreBasename=`remove_ext $T1wRestore`;
T1wRestoreBasename=`basename $T1wRestoreBasename`;
#T1wRestoreBrainBasename=`remove_ext $T1wRestoreBrain`;
#T1wRestoreBrainBasename=`basename $T1wRestoreBrainBasename`;

log_Msg "START: AtlasRegistration to MNMORF"

verbose_echo " "
verbose_red_echo " ===> Running Atlas Registration to MMORF"
verbose_echo " "

mkdir -p $WD
mkdir -p $WD/xfms
mkdir -p $WD/Diffusion

# Record the input options in a log file
echo "$0 $@" >> $WD/xfms/log.txt
echo "PWD = `pwd`" >> $WD/xfms/log.txt
echo "date: `date`" >> $WD/xfms/log.txt
echo " " >> $WD/xfms/log.txt

########################################## DO WORK ##########################################


##I should filter it here.
${HCPPIPEDIR}/MMORF/scripts/MMORFPreprossDiffusion.sh "${Diffusion}" "${WD}/TMP" "${FSLDIR}"




#transform brain mask to fit with the MMORF alogrithm
${FSLDIR}/bin/fslmaths ${brainmask_fs} -mul 7 -add 1 -div 8 "${WD}/TMP/brainmask_fs_transformed.nii.gz"

# Linear then non-linear registration to MMORF
verbose_echo " --> Linear then non-linear registration to MMORF"
${FSLDIR}/bin/flirt -interp spline -in ${T1wRestore} -ref ${Reference} -omat "${WD}/xfms/acpc2MMORFLinear.mat" -out "${WD}/xfms/${T1wRestoreBasename}_to_MMORFLinear"
#Generationg config file
verbose_echo " --> Generating Config file for MMORF"
template=${HCPPIPEDIR}/MMORF/scripts/template.ini
output=${WD}/xfms/${T1wRestoreBasename}.ini
sed -e "s|{{Reference1}}|$Reference|g" \
    -e "s|{{T1wRestore}}|$T1wRestore|g" \
    -e "s|{{wd}}|$WD|g" \
    -e "s|{{ReferenceMask}}|$ReferenceMask|g" \
    -e "s|{{brainmaskedited}}|$WD/TMP/brainmask_fs_transformed.nii.gz|g" \
    -e "s|{{Reference2}}|$Reference2|g" \
    -e "s|{{T2wRestore}}|$T2wRestore|g" \
    -e "s|{{DTI}}|$Diffusion/data_tensor|g" \
    -e "s|{{DTIref}}|$DTIref|g" \
    -e "s|{{DTIrefMask}}|$DTIrefMask|g" \
    -e "s|{{FSLDIR}}|$FSLDIR|g" \
    -e "s|{{DTImask}}|$DTImask|g" \
    "$template" > "$output"
verbose_echo " --> running mmorf"

if [[ "${runlocally}" == "true" ]]; then
    "${FSLDIR}/bin/mmorf" --config "${output}"
else
    ScriptName="${WD}/xfms/command_$(date +%Y%m%d_%H%M%S)_$RANDOM.sh"
    if [[ -f "${CHPCHeader}" ]]; then
        cat "${CHPCHeader}" > "${ScriptName}"
        echo "" >> "${ScriptName}"  # blank line after header
    fi
    #some variables

    # Rewrite to runtime temp_dir
    target_file="\$temp_dir${output#${mountPoint}}"

    # Append SSHFS mount instructions and mmorf command
    {
        echo "# ============================================================"
        echo "#  SSHFS Mount Instructions"
        echo "# ============================================================"
        echo 'temp_dir=$(mktemp -d)'
        echo "if [[ ! -d \"\$temp_dir${mountPoint}\" ]];"        
        echo "     then"
        echo 'fusermount3 -u "$temp_dir" || true'
        echo "sshfs ${LocalHost}:${mountPoint} \$temp_dir"
        echo "fi"
        echo "cd ${ClusterHomeDirectory}"
        echo "temp_file=$target_file.tmp"
        echo "sed \"s|${mountPoint}/|\$temp_dir/|g\" $target_file > \$temp_file"
        echo "mv \$temp_file $target_file"
        echo "# ============================================================"
        echo "#  MMORF Command"
        echo "# ============================================================"
        echo "mmorf --config \"${target_file}\""
        echo 'fusermount -u $temp_dir   # Linux'
        echo 'rmdir "$temp_dir"'
    } >> "${ScriptName}"
    ${HCPPIPEDIR}/global/scripts/jobSubmissionHelper.sh $Host $ClusterHomeDirectory $ScriptName "" "" 2> /dev/null 
    rm ${ScriptName}
fi

verbose_echo "--> Computing combined warp"
${FSLDIR}/bin/convertwarp -m "${WD}/xfms/acpc2MMORFLinear.mat" -w "${WD}/xfms/mov_to_ref_mm_warp" -r "${Reference1mm}" -o "${OutputTransform}" --rel --relout 

# Input and reference spaces are the same, using normal reference because of tractography
verbose_echo " --> Computing warp"
${FSLDIR}/bin/invwarp -w "${OutputTransform}" -o ${OutputInvTransform} -r ${Reference1mm} 

# T1w set of warped outputs (brain/whole-head + restored/orig)
verbose_echo " --> Generarting T1w set of warped outputs"
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${T1wImage} -r ${Reference} -w ${OutputTransform} -o ${OutputT1wImage}
${FSLDIR}/bin/applywarp --rel --interp=spline -i ${T1wRestore} -r ${Reference} -w ${OutputTransform} -o ${OutputT1wImageRestore}
${FSLDIR}/bin/applywarp --rel --interp=nn -i ${T1wRestoreBrain} -r ${Reference} -w ${OutputTransform} -o ${OutputT1wImageRestoreBrain}
${FSLDIR}/bin/fslmaths ${OutputT1wImageRestore} -mas ${OutputT1wImageRestoreBrain} ${OutputT1wImageRestoreBrain}

verbose_echo " --> Generating DTI set of warped outputs"
${FSLDIR}/bin/vecreg --interp=spline -i "${Diffusion}/data_tensor.nii.gz" --premat="${WD}/xfms/acpc2MMORFLinear.mat" -w "${WD}/xfms/mov_to_ref_mm_warp" -r "${Reference}" -o "${WD}/Diffusion/data_tensor.nii.gz" 
${FSLDIR}/bin/fslmaths "${WD}/Diffusion/data_tensor.nii.gz" -tensor_decomp "${WD}/Diffusion/data"
rm "${WD}/Diffusion/data.nii.gz"

# T2w set of warped outputs (brain/whole-head + restored/orig)
if [ ! "${T2wImage}" = "NONE" ] ; then
  verbose_echo " --> Creating T2w set of warped outputs"
  ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${T2wImage} -r ${Reference} -w ${OutputTransform} -o ${OutputT2wImage}
  ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${T2wRestore} -r ${Reference} -w ${OutputTransform} -o ${OutputT2wImageRestore}
  ${FSLDIR}/bin/applywarp --rel --interp=nn -i ${T2wRestoreBrain} -r ${Reference} -w ${OutputTransform} -o ${OutputT2wImageRestoreBrain}
  ${FSLDIR}/bin/fslmaths ${OutputT2wImageRestore} -mas ${OutputT2wImageRestoreBrain} ${OutputT2wImageRestoreBrain}
else
  verbose_echo " ... skipping T2w processing"
fi

verbose_green_echo "---> Finished Atlas Registration to MMORF"
verbose_echo " "

##Clean up##
verbose_echo "Clean up starting"
rm -rf "${WD}/TMP"

log_Msg "END: AtlasRegistration to MMORF"
echo " END: `date`" >> $WD/xfms/log.txt

########################################## QA STUFF ##########################################

#if [ -e $WD/xfms/qa.txt ] ; then rm -f $WD/xfms/qa.txt ; fi
#echo "cd `pwd`" >> $WD/xfms/qa.txt
#echo "# Check quality of alignment with MNI image" >> $WD/MMORF/qa.txt
#echo "fslview ${Reference} ${OutputT1wImageRestore}" >> $WD/MMORF/qa.txt
#echo "fslview ${Reference} ${OutputT2wImageRestore}" >> $WD/MMORF/qa.txt

##############################################################################################
