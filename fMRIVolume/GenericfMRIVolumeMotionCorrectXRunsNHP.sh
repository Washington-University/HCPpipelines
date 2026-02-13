#! /bin/bash 

# This script is designed to enhance registration of fMRI to structure and across fMRI runs. It may
# be particularly useful when the fMRIVolume pipeline in each run doesn't achieve satisfactory
# registration. - TH 2024
# The script performes the following processes:
# 1. Resample SBRef into T1w space at fMRI resolution
# 2. Create an initial target by averaging SBRef across runs
# 3. Iterate motion correction (w/ weighted mask) and create taragets
# 4. Fine tune registration using averaged SBRef to T1w using BBR (effective for USPIO fMRI/pial BBR not for BOLD fMRI/white BBR)
# 5. Create combined warpfields and matrices, then resample
# Subsequent steps include OneStepResampling and IntensityNormalization

Usage () {
echo "$(basename $0) <StudyFolder> <Subject> <fMRINames> <RunMode> "
echo ""
echo "RumMode"
echo " -x                         : Registration Xruns"
echo " -r <BBR type (T1w or T2w)> : Registration to T1w with specified BBR type and resample Xruns"
exit
}
[ "$3" = "" ] && Usage

source $HCPPIPEDIR_Global/log.shlib # Logging related functions

StudyFolder=$1
Subject=$2
fMRINames=$3
opt=$4
BBR=$5   # T1w T2w NONE
UseJacobian="true"
BiasCorrection="NONE"
BiasField=""

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

#StudyFolder=`getopt1 "--path" $@`
#Subject=`getopt1 "--subject" $@`
#fMRINames=`getopt1 "--fMRINames" $@`
#BiasField=`getopt1 "--biasfield" $@`
#BiasCorrection=`getopt1 "--biascorrection" $@`
#UseJacobian=`getopt1 "--usejacobian" $@`

fMRINames=($(echo $fMRINames | sed -e 's/@/ /g'))
FreeSurferSubjectFolder=${StudyFolder}/${Subject}/T1w
FreeSurferSubjectID=${Subject}
fMRIRegFolder=fMRIReg
BBR=${BBR:-T2w}
T1wImage=${StudyFolder}/${Subject}/T1w/T1w_acpc_dc_restore
T1wImageBrain=${StudyFolder}/${Subject}/T1w/T1w_acpc_dc_restore_brain
dof=6
WMProjAbs=0.7
ScoutInputName=Scout_gdc
fMRIRes=1.25

FreeSurferSubjectFolder=${StudyFolder}/${Subject}/T1w
FreeSurferSubjectID=${Subject}
AtlasFolderT1wImagefMRIRes=${StudyFolder}/${Subject}/MNINonLinear/T1w_restore.${fMRIRes}
T1wfMRIRegFolder=${StudyFolder}/${Subject}/T1w/${fMRIRegFolder}

Scout2T1wPaths=()
vol=()

# error check bias correction opt
case "$BiasCorrection" in
    NONE)
        UseBiasField=""
    ;;
    
    LEGACY)
        UseBiasField="${BiasField}"
    ;;
    
    SEBASED)
        if [[ "$DistortionCorrection" != "${SPIN_ECHO_METHOD_OPT}" ]]
        then
        #    log_Msg "SEBASED bias correction is only available with --method=${SPIN_ECHO_METHOD_OPT}"
            exit 1
        fi
        #note, this file doesn't exist yet, gets created by ComputeSpinEchoBiasField.sh
        UseBiasField="${WD}/ComputeSpinEchoBiasField/${NameOffMRI}_sebased_bias.nii.gz"
    ;;
    
    "")
       # log_Msg "--biascorrection option not specified"
        exit 1
    ;;
    
    *)
       # log_Msg "unrecognized value for bias correction: $BiasCorrection"
        exit 1
esac


CreateAverageScout () {
mkdir -p ${T1wfMRIRegFolder}

# 1. Resample SBRef in T1w space at fMRI resolution
for fMRIName in ${fMRINames[@]} ; do
	DCWD=${StudyFolder}/${Subject}/${fMRIName}/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased

	log_Msg "Resampling ${fMRIName}/${ScoutInputName}.nii.gz"

	${FSLDIR}/bin/applywarp --rel --interp=spline -i ${StudyFolder}/${Subject}/${fMRIName}/${ScoutInputName}.nii.gz -r ${AtlasFolderT1wImagefMRIRes}.nii.gz -w ${DCWD}/fMRI2str.nii.gz -o ${T1wfMRIRegFolder}/${fMRIName}2struc_${ScoutInputName}.nii.gz
	${FSLDIR}/bin/applywarp --rel --interp=spline -i ${DCWD}/Jacobian.nii.gz -r ${AtlasFolderT1wImagefMRIRes}.nii.gz --premat=${DCWD}/fMRI2str.mat -o ${T1wfMRIRegFolder}/${fMRIName}2struc_Jacobian.nii.gz

	if [[ $UseJacobian == "true" ]]
	then
	    log_Msg "applying Jacobian modulation"
	    if [[ "$UseBiasField" != "" ]]
	    then
		flirt -in $UseBiasField -ref ${AtlasFolderT1wImagefMRIRes}.nii.gz -applyisoxfm $fMRIRes -o ${T1wfMRIRegFolder}/BiasField_acpc_dc.${fMRIRes}.nii.gz -interp sinc
	        ${FSLDIR}/bin/fslmaths${T1wfMRIRegFolder}/${fMRIName}2struc_${ScoutInputName}.nii.gz -div ${T1wfMRIRegFolder}/BiasField_acpc_dc.${fMRIRes}.nii.gz -mul ${T1wfMRIRegFolder}/${fMRIName}2struc_Jacobian.nii.gz  ${T1wfMRIRegFolder}/${fMRIName}2struc_${ScoutInputName}.nii.gz
	    else
	        ${FSLDIR}/bin/fslmaths ${T1wfMRIRegFolder}/${fMRIName}2struc_${ScoutInputName}.nii.gz -mul ${T1wfMRIRegFolder}/${fMRIName}2struc_Jacobian.nii.gz ${T1wfMRIRegFolder}/${fMRIName}2struc_${ScoutInputName}.nii.gz
	    fi
	else
	    log_Msg "not applying Jacobian modulation"
	    if [[ "$UseBiasField" != "" ]]
	    then
		flirt -in $UseBiasField -ref ${AtlasFolderT1wImagefMRIRes}.nii.gz -applyisoxfm $fMRIRes -o ${T1wfMRIRegFolder}/BiasField_acpc_dc.${fMRIRes}.nii.gz -interp sinc
	        ${FSLDIR}/bin/fslmaths ${T1wfMRIRegFolder}/${fMRIName}2struc_${ScoutInputName}.nii.gz -div ${T1wfMRIRegFolder}/BiasField_acpc_dc.${fMRIRes}.nii.gz ${T1wfMRIRegFolder}/${fMRIName}2struc_${ScoutInputName}.nii.gz
	    fi
	    #no else, the commands are overwriting their input
	fi
	Scout2T1wPaths+=(${T1wfMRIRegFolder}/${fMRIName}2struc_${ScoutInputName}.nii.gz)
done

# 2. Create initial target
log_Msg "Create initial target"
fslmerge -t ${T1wfMRIRegFolder}/Scout2T1w_init1_merge ${Scout2T1wPaths[@]}
fslmaths ${T1wfMRIRegFolder}/Scout2T1w_init1_merge -Tstd ${T1wfMRIRegFolder}/Scout2T1w_init1_std
fslmaths ${T1wfMRIRegFolder}/Scout2T1w_init1_merge -Tmean ${T1wfMRIRegFolder}/Scout2T1w_init1_mean

flirt -in ${StudyFolder}/${Subject}/T1w/brainmask_fs -ref ${StudyFolder}/${Subject}/T1w/brainmask_fs -applyisoxfm $fMRIRes -o ${StudyFolder}/${Subject}/T1w/brainmask_fs.${fMRIRes} -interp nearestneighbour
fslmaths ${StudyFolder}/${Subject}/T1w/brainmask_fs.${fMRIRes}  -dilD -dilD ${T1wfMRIRegFolder}/brainmask_fs_dilD_dilD

# 3. Iterate motion correction (w/ weighted mask) and creating of taraget
for j in $(seq 1 3); do
	k=$((j + 1)); vol=()
	log_Msg "Create target $k"
	for i in ${!Scout2T1wPaths[@]} ; 
	do
		num=$(zeropad $i 4);
		echo -n "vol${num} "
		flirt -in ${Scout2T1wPaths[$i]} -ref ${T1wfMRIRegFolder}/Scout2T1w_init${j}_mean -inweight ${T1wfMRIRegFolder}/brainmask_fs_dilD_dilD -refweight ${T1wfMRIRegFolder}/brainmask_fs_dilD_dilD -dof 6 -omat ${T1wfMRIRegFolder}/vol${num}.mat -o ${T1wfMRIRegFolder}/vol${num}
		vol[$i]=${T1wfMRIRegFolder}/vol${num}.nii.gz
		if [ $j = 3 ] ; then
			cp ${T1wfMRIRegFolder}/vol${num}.mat ${Scout2T1wPaths[$i]}2meanScout.mat
		fi
	done
	echo ""
	fslmerge -t ${T1wfMRIRegFolder}/Scout2T1w_init${k}_merge ${vol[@]}
	fslmaths ${T1wfMRIRegFolder}/Scout2T1w_init${k}_merge -Tstd ${T1wfMRIRegFolder}/Scout2T1w_init${k}_std
	fslmaths ${T1wfMRIRegFolder}/Scout2T1w_init${k}_merge -Tmean ${T1wfMRIRegFolder}/Scout2T1w_init${k}_mean

done

imcp ${T1wfMRIRegFolder}/Scout2T1w_init${k}_mean ${T1wfMRIRegFolder}/Scout2T1w_init
rm ${vol[@]} ${vol[@]/.nii.gz/.mat}

}

fMRI2strucReg () {
# 4. Fine tune registration using averaged Scout to T1w
if [ $BBR = "T1w" ] ; then

	# Note that BBR=T1w is done using brain outer boundary using flipped slope. - TH 2023
	log_Msg "register T1w contrast scout to T1w struc with FSL-BBR"

	# use flipped bbrslope and brain boundary
	${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${T1wfMRIRegFolder}/Scout2T1w_init -ref ${T1wImageBrain} -omat ${T1wfMRIRegFolder}/Scout2T1w_FSLBBR.mat -wmseg ${StudyFolder}/${Subject}/T1w/brainmask_fs.nii.gz -cost bbr -schedule ${FSLDIR}/etc/flirtsch/bbr.sch -bbrslope 0.5 -out ${T1wfMRIRegFolder}/Scout2T1w_FSLBBR.nii.gz

	BBRopt="--t1 --gm-proj-abs 0.2 --wm-proj-abs 1.4 --6"  # macaque USPIO fMRI
	SUBJECTS_DIR=${FreeSurferSubjectFolder}
	export SUBJECTS_DIR
	log_Msg "Use \"hidden\" bbregister DOF options"  
	${FREESURFER_HOME}/bin/bbregister --s ${FreeSurferSubjectID} --mov ${T1wfMRIRegFolder}/Scout2T1w_FSLBBR.nii.gz --surf pial.deformed --init-reg ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}/mri/transforms/eye.dat ${BBRopt} --reg ${T1wfMRIRegFolder}/Scout2T1w_FSBBR.dat

	${FREESURFER_HOME}/bin/tkregister2 --noedit --reg ${T1wfMRIRegFolder}/Scout2T1w_FSBBR.dat --mov ${T1wfMRIRegFolder}/Scout2T1w_FSLBBR.nii.gz --targ ${T1wImage}.nii.gz --fslregout ${T1wfMRIRegFolder}/Scout2T1w_FSBBR.mat

	convert_xfm -omat ${T1wfMRIRegFolder}/Scout2T1w.mat -concat ${T1wfMRIRegFolder}/Scout2T1w_FSBBR.mat ${T1wfMRIRegFolder}/Scout2T1w_FSLBBR.mat

	${FSLDIR}/bin/applywarp -i  ${T1wfMRIRegFolder}/Scout2T1w_init.nii.gz -r ${T1wImage}.nii.gz --premat=${T1wfMRIRegFolder}/Scout2T1w.mat -o ${T1wfMRIRegFolder}/Scout2T1w.nii.gz
          
elif [ $BBR = "T2w" ] ; then
	log_Msg "register T2w contrast scout to T1w struc with FSL BBR"
	${HCPPIPEDIR_Global}/epi_reg_dof --dof=${dof} --epi=${T1wfMRIRegFolder}/Scout2T1w_init --t1=${T1wImage} --t1brain=${T1wImageBrain} --out=${T1wfMRIRegFolder}/Scout2T1w_FSLBBR

	BBRopt="--t2"
	log_Msg "Run FreeSurfer bbregister" 
	### FREESURFER BBR - found to be an improvement, probably due to better GM/WM boundary
	SUBJECTS_DIR=${FreeSurferSubjectFolder}
	export SUBJECTS_DIR

	# Run Normally
	log_Msg "Run Normally" 
	# Use "hidden" bbregister DOF options
	log_Msg "Use \"hidden\" bbregister DOF options"
	${FREESURFER_HOME}/bin/bbregister --s ${FreeSurferSubjectID} --mov ${T1wfMRIRegFolder}/Scout2T1w_FSLBBR.nii.gz --surf white.deformed --init-reg ${FreeSurferSubjectFolder}/${FreeSurferSubjectID}/mri/transforms/eye.dat ${BBRopt} --reg ${T1wfMRIRegFolder}/Scout2T1w_FSBBR.dat --${dof} --wm-proj-abs ${WMProjAbs}

	# Create FSL-style matrix and then combine with existing warp fields
	log_Msg "Create FSL-style matrix and then combine with existing warp fields"
	${FREESURFER_HOME}/bin/tkregister2 --noedit --reg ${T1wfMRIRegFolder}/Scout2T1w_FSBBR.dat --mov  ${T1wfMRIRegFolder}/Scout2T1w_FSLBBR.nii.gz --targ ${T1wImage}.nii.gz --fslregout ${T1wfMRIRegFolder}/Scout2T1w_FSBBR.mat

	convert_xfm -omat ${T1wfMRIRegFolder}/Scout2T1w.mat -concat ${T1wfMRIRegFolder}/Scout2T1w_FSBBR.mat ${T1wfMRIRegFolder}/Scout2T1w_FSLBBR.mat

	${FSLDIR}/bin/applywarp -i  ${T1wfMRIRegFolder}/Scout2T1w_init.nii.gz -r ${T1wImage}.nii.gz --premat=${T1wfMRIRegFolder}/Scout2T1w.mat -o ${T1wfMRIRegFolder}/Scout2T1w.nii.gz

elif [ $BBR = "NONE" ] ; then
         
	log_Msg "register scout to T1w with cost function of normmi" 
	${FSLDIR}/bin/flirt -interp spline -dof 6 -in ${T1wfMRIRegFolder}/Scout2T1w_init -ref ${T1wImageBrain}  -omat ${T1wfMRIRegFolder}/Scout2T1w.mat -out ${T1wfMRIRegFolder}/Scout2T1w.nii.gz -nosearch

fi

}

ApplyReg () {

# 5. Create combined warpfields and matrices and resample

for fMRIName in ${fMRINames[@]} ; do

	log_Msg "Processing $fMRIName"
	DCWD=${StudyFolder}/${Subject}/${fMRIName}/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased
	OutputTransform=${StudyFolder}/${Subject}/T1w/xfms/${fMRIName}2str
	RegOutput=${StudyFolder}/${Subject}/${fMRIName}/Scout2T1w
	JacobianOut=${StudyFolder}/${Subject}/${fMRIName}/Jacobian
	QAImage=${StudyFolder}/${Subject}/${fMRIName}/T1wMulEPI

 	flirt -in ${T1wfMRIRegFolder}/${fMRIName}2struc_${ScoutInputName}.nii.gz -ref ${T1wfMRIRegFolder}/Scout2T1w -applyxfm -dof 6 -init ${T1wfMRIRegFolder}/${fMRIName}2struc_${ScoutInputName}2meanScout.mat -o ${T1wfMRIRegFolder}/${fMRIName}2struc_${ScoutInputName}2meanScout

	if [ "${fMRIReferenceReg}" == "nonlinear" ] ; then
		${FSLDIR}/bin/fnirt --in=${T1wfMRIRegFolder}/${fMRIName}2struc_${ScoutInputName}.nii.gz --aff=${T1wfMRIRegFolder}/${fMRIName}2struc_${ScoutInputName}2meanScout.mat --ref=${T1wfMRIRegFolder}/Scout2T1w --iout=${T1wfMRIRegFolder}/${fMRIName}2struc_${ScoutInputName}2meanScout_nonlin --fout=${T1wfMRIRegFolder}/${fMRIName}2struc_${ScoutInputName}2meanScout_warp
	fi

	if [ "${fMRIReferenceReg}" != "nonlinear" ] ; then
		${FSLDIR}/bin/convert_xfm -omat ${DCWD}/fMRI2str_refinementII.mat -concat ${T1wfMRIRegFolder}/Scout2T1w.mat ${T1wfMRIRegFolder}/${fMRIName}2struc_${ScoutInputName}2meanScout.mat
		${FSLDIR}/bin/convert_xfm -omat ${DCWD}/fMRI2strII.mat -concat ${DCWD}/fMRI2str_refinementII.mat ${DCWD}/Scout_gdc_undistorted2T1w_init.mat
		${FSLDIR}/bin/convertwarp --relout --rel --warp1=${DCWD}/fMRI2str.nii.gz --ref=${T1wImage} --postmat=${DCWD}/fMRI2str_refinementII.mat --out=${DCWD}/fMRI2strII.nii.gz	
	else
		echo "ERROR: to do"
		exit 1
	fi

	log_Msg "Create warped image with spline interpolation, bias correction and (optional) Jacobian modulation"
	${FSLDIR}/bin/applywarp --rel --interp=spline -i ${StudyFolder}/${Subject}/${fMRIName}/${ScoutInputName}.nii.gz -r ${T1wImage} -w ${DCWD}/fMRI2strII.nii.gz -o ${DCWD}/${ScoutInputName}_undistorted2T1w

	# resample fieldmap jacobian with new registration
	${FSLDIR}/bin/applywarp --rel --interp=spline -i ${DCWD}/Jacobian.nii.gz -r ${T1wImage} --premat=${DCWD}/fMRI2strII.mat -o ${DCWD}/Jacobian2T1w.nii.gz

	if [[ $UseJacobian == "true" ]]
	then
	    log_Msg "applying Jacobian modulation"
	    if [[ "$UseBiasField" != "" ]]
	    then
	        ${FSLDIR}/bin/fslmaths ${DCWD}/${ScoutInputName}_undistorted2T1w -div ${UseBiasField} -mul ${DCWD}/Jacobian2T1w.nii.gz ${DCWD}/${ScoutInputName}_undistorted2T1w
	    else
	        ${FSLDIR}/bin/fslmaths ${DCWD}/${ScoutInputName}_undistorted2T1w -mul ${DCWD}/Jacobian2T1w.nii.gz ${DCWD}/${ScoutInputName}_undistorted2T1w
	    fi
	else
	    log_Msg "not applying Jacobian modulation"
	    if [[ "$UseBiasField" != "" ]]
	    then
	        ${FSLDIR}/bin/fslmaths ${DCWD}/${ScoutInputName}_undistorted2T1w -div ${UseBiasField} ${DCWD}/${ScoutInputName}_undistorted2T1w
	    fi
	    #no else, the commands are overwriting their input
	fi

	log_Msg "cp ${DCWD}/${ScoutInputName}_undistorted2T1w.nii.gz ${RegOutput}.nii.gz"
	cp ${DCWD}/${ScoutInputName}_undistorted2T1w.nii.gz ${RegOutput}.nii.gz

	log_Msg "cp ${DCWD}/fMRI2strII.nii.gz ${OutputTransform}.nii.gz"
	cp ${DCWD}/fMRI2strII.nii.gz ${OutputTransform}.nii.gz

	log_Msg "cp ${DCWD}/Jacobian2T1w.nii.gz ${JacobianOut}.nii.gz"
	cp ${DCWD}/Jacobian2T1w.nii.gz ${JacobianOut}.nii.gz

	# QA image (sqrt of EPI * T1w)
	log_Msg 'generating QA image (sqrt of EPI * T1w)'
	${FSLDIR}/bin/fslmaths ${T1wImage}.nii.gz -mul ${RegOutput}.nii.gz -sqrt ${QAImage}.nii.gz

done

}

if [ $opt = "-x" ] ; then

	CreateAverageScout

elif [ $opt = "-r" ] ; then

	fMRI2strucReg
	ApplyReg

fi

log_Msg "Finished!"

