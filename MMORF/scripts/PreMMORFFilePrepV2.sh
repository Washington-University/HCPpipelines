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

opts_AddMandatory '--t1rest' 'T1wRestore' 'image' 'bias corrected t1w image'

opts_AddMandatory '--t2rest' 'T2wRestore' 'image' 'bias corrected t2w image'

opts_AddMandatory '--brainmask_fs' 'brainmask_fs' 'mask' 'Brainmask for t1w or t2w image'

opts_AddMandatory '--ref' 'Reference' 'image' 'reference image'

opts_AddMandatory '--ref2' 'Reference2' 'image' 'reference image 2'

opts_AddMandatory '--refmask' 'ReferenceMask' 'mask' 'reference brain mask'

opts_AddMandatory "--Diffusion" "Diffusion" "image" "Diffusion including bvecs, bvals, and data.nii.gz"

opts_AddMandatory "--DTImask" "DTImask" "image" "Mask for DTI"


opts_AddMandatory '--DTIref' 'DTIref' 'mask' 'reference for DTI'


opts_AddMandatory '--DTIrefmask' 'DTIrefMask' 'mask' 'reference brain mask for DTI'

opts_AddMandatory '--templateini' 'template' 'file' 'template ini file for MMORF'


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
