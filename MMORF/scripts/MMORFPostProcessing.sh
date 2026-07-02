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



source "${HCPPIPEDIR}/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
source "${HCPPIPEDIR}/global/scripts/newopts.shlib" "$@"

opts_SetScriptDescription "Tool for non-linearly registering DTI, T1w, T2w to MMORF space. Need to have T1w, T2w in the same space"

opts_AddMandatory '--t1' 'T1wImage' 'image' 't1w image'

opts_AddMandatory '--t1rest' 'T1wRestore' 'image' 'bias corrected t1w image'

opts_AddMandatory '--t1restbrain' 'T1wRestoreBrain' 'image' 'bias corrected brain extracted t1w image'

opts_AddMandatory '--t2' 'T2wImage' 't2w image' 't2w image'

opts_AddMandatory '--t2rest' 'T2wRestore' 'image' 'bias corrected t2w image'

opts_AddMandatory '--t2restbrain' 'T2wRestoreBrain' 'image' 'bias corrected, brain extracted t2w image'

opts_AddMandatory '--ref' 'Reference' 'image' 'reference image'


opts_AddMandatory "--Diffusion" "Diffusion" "image" "Diffusion including bvecs, bvals, and data.nii.gz"

opts_AddMandatory '--owarp' 'OutputTransform' 'number' 'output warp'

opts_AddMandatory '--oinvwarp' 'OutputInvTransform' 'inverse' 'output inverse warp'

opts_AddMandatory '--ot1' 'OutputT1wImage' 'image' 'output t1w to MNI'

opts_AddMandatory '--ot1rest' 'OutputT1wImageRestore' 'image' 'output bias corrected t1w to MNI'

opts_AddMandatory '--ot1restbrain' 'OutputT1wImageRestoreBrain' 'image' 'output bias corrected, brain extracted t1w to MNI'

opts_AddMandatory '--ot2' 'OutputT2wImage' 'image' 'output t2w to MNI'

opts_AddMandatory '--ot2rest' 'OutputT2wImageRestore' 'image' 'output bias corrected t2w to MNI'

opts_AddMandatory '--ot2restbrain' 'OutputT2wImageRestoreBrain' 'image' 'output bias corrected, brain extracted t2w to MNI'



##optional args
opts_AddOptional '--ref1mm' 'Reference1mm' 'image' 'reference 1mm image' "${HCPPIPEDIR_Templates}/MMORF_T1_1mm.nii.gz"

opts_AddOptional '--workingdir' 'WD' 'path' 'working directory' "."


opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues


log_Check_Env_Var FSLDIR

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