#!/bin/bash

set -e
echo -e "\n START: DiffusionToStructural"


########################################## SUPPORT FUNCTIONS ########################################## 

# function for parsing options
getopt1() {
    sopt="$1"
    shift 1
    for fn in $@ ; do
	if [ `echo $fn | grep -- "^${sopt}=" | wc -w` -gt 0 ] ; then
	    echo $fn | sed "s/^${sopt}=//"
	    return 0
	fi
    done
}

defaultopt() {
    echo $1
}

################################################## OPTION PARSING #####################################################
# Input Variables

FreeSurferSubjectFolder=`getopt1 "--t1folder" $@`  # "$1" #${StudyFolder}/${Subject}/T1w
FreeSurferSubjectID=`getopt1 "--subject" $@`       # "$2" #Subject ID
WorkingDirectory=`getopt1 "--workingdir" $@`       # "$3" #Path to registration working dir, e.g. ${StudyFolder}/${Subject}/Diffusion/reg
DataDirectory=`getopt1 "--datadiffdir" $@`         # "$4" #Path to diffusion space diffusion data, e.g. ${StudyFolder}/${Subject}/Diffusion/data
T1wImage=`getopt1 "--t1" $@`                       # "$5" #T1w_acpc_dc image
T1wRestoreImage=`getopt1 "--t1restore" $@`         # "$6" #T1w_acpc_dc_restore image
T1wBrainImage=`getopt1 "--t1restorebrain" $@`      # "$7" #T1w_acpc_dc_restore_brain image
BiasField=`getopt1 "--biasfield" $@`               # "$8" #Bias_Field_acpc_dc
InputBrainMask=`getopt1 "--brainmask" $@`          # "$9" #Freesurfer Brain Mask, e.g. brainmask_fs
GdcorrectionFlag=`getopt1 "--gdflag" $@`           # "$10"#Flag for gradient nonlinearity correction (0/1 for Off/On) 
DiffRes=`getopt1 "--diffresol" $@`                 # "$11"#Diffusion resolution in mm (assume isotropic)
dof=`getopt1 "--dof" $@`                           # Degrees of freedom for registration to T1w (defaults to 6)

# Output Variables
T1wOutputDirectory=`getopt1 "--datadiffT1wdir" $@` # "$12" #Path to T1w space diffusion data (for producing output)
RegOutput=`getopt1 "--regoutput" $@`               # "$13" #Temporary file for sanity checks 
QAImage=`getopt1 "--QAimage" $@`                   # "$14" #Temporary file for sanity checks 

# Set default option values
dof=`defaultopt $dof 6`

echo $T1wOutputDirectory

# Paths for scripts etc (uses variables defined in SetUpHCPPipeline.sh)
GlobalScripts=${HCPPIPEDIR_Global}

T1wBrainImageFile=`basename $T1wBrainImage`
regimg="nodif"

${FSLDIR}/bin/imcp "$T1wBrainImage" "$WorkingDirectory"/"$T1wBrainImageFile"

#b0 FLIRT BBR and bbregister to T1w
${GlobalScripts}/epi_reg_dof --dof=${dof} --epi="$DataDirectory"/"$regimg" --t1="$T1wImage" --t1brain="$WorkingDirectory"/"$T1wBrainImageFile" --out="$WorkingDirectory"/"$regimg"2T1w_initII

${FSLDIR}/bin/applywarp --rel --interp=spline -i "$DataDirectory"/"$regimg" -r "$T1wImage" --premat="$WorkingDirectory"/"$regimg"2T1w_initII_init.mat -o "$WorkingDirectory"/"$regimg"2T1w_init.nii.gz
${FSLDIR}/bin/applywarp --rel --interp=spline -i "$DataDirectory"/"$regimg" -r "$T1wImage" --premat="$WorkingDirectory"/"$regimg"2T1w_initII.mat -o "$WorkingDirectory"/"$regimg"2T1w_initII.nii.gz
${FSLDIR}/bin/fslmaths "$WorkingDirectory"/"$regimg"2T1w_initII.nii.gz -div "$BiasField" "$WorkingDirectory"/"$regimg"2T1w_restore_initII.nii.gz

SUBJECTS_DIR="$FreeSurferSubjectFolder"
export SUBJECTS_DIR
${FREESURFER_HOME}/bin/bbregister --s "$FreeSurferSubjectID" --mov "$WorkingDirectory"/"$regimg"2T1w_restore_initII.nii.gz --surf white.deformed --init-reg "$FreeSurferSubjectFolder"/"$FreeSurferSubjectID"/mri/transforms/eye.dat --bold --reg "$WorkingDirectory"/EPItoT1w.dat --o "$WorkingDirectory"/"$regimg"2T1w.nii.gz
${FREESURFER_HOME}/bin/tkregister2 --noedit --reg "$WorkingDirectory"/EPItoT1w.dat --mov "$WorkingDirectory"/"$regimg"2T1w_restore_initII.nii.gz --targ "$T1wImage".nii.gz --fslregout "$WorkingDirectory"/diff2str_fs.mat

${FSLDIR}/bin/convert_xfm -omat "$WorkingDirectory"/diff2str.mat -concat "$WorkingDirectory"/diff2str_fs.mat "$WorkingDirectory"/"$regimg"2T1w_initII.mat
${FSLDIR}/bin/convert_xfm -omat "$WorkingDirectory"/str2diff.mat -inverse "$WorkingDirectory"/diff2str.mat

${FSLDIR}/bin/applywarp --rel --interp=spline -i "$DataDirectory"/"$regimg" -r "$T1wImage".nii.gz --premat="$WorkingDirectory"/diff2str.mat -o "$WorkingDirectory"/"$regimg"2T1w
${FSLDIR}/bin/fslmaths "$WorkingDirectory"/"$regimg"2T1w -div "$BiasField" "$WorkingDirectory"/"$regimg"2T1w_restore

#Are the next two scripts needed?
${FSLDIR}/bin/imcp "$WorkingDirectory"/"$regimg"2T1w_restore "$RegOutput"
${FSLDIR}/bin/fslmaths "$T1wRestoreImage".nii.gz -mul "$WorkingDirectory"/"$regimg"2T1w_restore.nii.gz -sqrt "$QAImage"_"$regimg".nii.gz

#Generate 1.25mm structural space for resampling the diffusion data into
${FSLDIR}/bin/flirt -interp spline -in "$T1wRestoreImage" -ref "$T1wRestoreImage" -applyisoxfm ${DiffRes} -out "$T1wRestoreImage"_${DiffRes}
${FSLDIR}/bin/applywarp --rel --interp=spline -i "$T1wRestoreImage" -r "$T1wRestoreImage"_${DiffRes} -o "$T1wRestoreImage"_${DiffRes}

#Generate 1.25mm mask in structural space
${FSLDIR}/bin/flirt -interp nearestneighbour -in "$InputBrainMask" -ref "$InputBrainMask" -applyisoxfm ${DiffRes} -out "$T1wOutputDirectory"/nodif_brain_mask
${FSLDIR}/bin/fslmaths "$T1wOutputDirectory"/nodif_brain_mask -kernel 3D -dilM "$T1wOutputDirectory"/nodif_brain_mask

DilationsNum=6 #Dilated mask for masking the final data and grad_dev
${FSLDIR}/bin/imcp "$T1wOutputDirectory"/nodif_brain_mask "$T1wOutputDirectory"/nodif_brain_mask_temp
for (( j=0; j<${DilationsNum}; j++ ))
do
    ${FSLDIR}/bin/fslmaths "$T1wOutputDirectory"/nodif_brain_mask_temp -kernel 3D -dilM "$T1wOutputDirectory"/nodif_brain_mask_temp
done

#Rotate bvecs from diffusion to structural space
${GlobalScripts}/Rotate_bvecs.sh "$DataDirectory"/bvecs "$WorkingDirectory"/diff2str.mat "$T1wOutputDirectory"/bvecs
cp "$DataDirectory"/bvals "$T1wOutputDirectory"/bvals

#Register diffusion data to T1w space. Account for gradient nonlinearities if requested
if [ ${GdcorrectionFlag} -eq 1 ]; then
    echo "Correcting Diffusion data for gradient nonlinearities and registering to structural space"
    ${FSLDIR}/bin/convertwarp --rel --relout --warp1="$DataDirectory"/warped/fullWarp --postmat="$WorkingDirectory"/diff2str.mat --ref="$T1wRestoreImage"_${DiffRes} --out="$WorkingDirectory"/grad_unwarp_diff2str
    ${FSLDIR}/bin/applywarp --rel -i "$DataDirectory"/warped/data_warped -r "$T1wRestoreImage"_${DiffRes} -w "$WorkingDirectory"/grad_unwarp_diff2str --interp=spline -o "$T1wOutputDirectory"/data

    #Now register the grad_dev tensor 
    ${FSLDIR}/bin/vecreg -i "$DataDirectory"/grad_dev -o "$T1wOutputDirectory"/grad_dev -r "$T1wRestoreImage"_${DiffRes} -t "$WorkingDirectory"/diff2str.mat --interp=spline
    ${FSLDIR}/bin/fslmaths "$T1wOutputDirectory"/grad_dev -mas "$T1wOutputDirectory"/nodif_brain_mask_temp "$T1wOutputDirectory"/grad_dev  #Mask-out values outside the brain 
else
    #Register diffusion data to T1w space without considering gradient nonlinearities
    ${FSLDIR}/bin/flirt -in "$DataDirectory"/data -ref "$T1wRestoreImage"_${DiffRes} -applyxfm -init "$WorkingDirectory"/diff2str.mat -interp spline -out "$T1wOutputDirectory"/data
fi

${FSLDIR}/bin/fslmaths "$T1wOutputDirectory"/data -mas "$T1wOutputDirectory"/nodif_brain_mask_temp "$T1wOutputDirectory"/data  #Mask-out data outside the brain 
${FSLDIR}/bin/fslmaths "$T1wOutputDirectory"/data -thr 0 "$T1wOutputDirectory"/data      #Remove negative intensity values (caused by spline interpolation) from final data
${FSLDIR}/bin/imrm "$T1wOutputDirectory"/nodif_brain_mask_temp

${FSLDIR}/bin/fslmaths "$T1wOutputDirectory"/data -Tmean "$T1wOutputDirectory"/temp
${FSLDIR}/bin/immv "$T1wOutputDirectory"/nodif_brain_mask.nii.gz "$T1wOutputDirectory"/nodif_brain_mask_old.nii.gz
${FSLDIR}/bin/fslmaths "$T1wOutputDirectory"/nodif_brain_mask_old.nii.gz -mas "$T1wOutputDirectory"/temp "$T1wOutputDirectory"/nodif_brain_mask
${FSLDIR}/bin/imrm "$T1wOutputDirectory"/temp

echo " END: DiffusionToStructural"
