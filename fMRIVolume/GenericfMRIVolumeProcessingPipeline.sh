#!/bin/bash 
set -e

# Requirements for this script
#  installed versions of: FSL5.0.2 or higher , FreeSurfer (version 5 or higher) , gradunwarp (python code from MGH) 
#  environment: use SetUpHCPPipeline.sh  (or individually set FSLDIR, FREESURFER_HOME, HCPPIPEDIR, PATH - for gradient_unwarp.py)

# make pipeline engine happy...
if [ $# -eq 1 ]
then
    echo "Version unknown..."
    exit 0
fi

########################################## PIPELINE OVERVIEW ########################################## 

# TODO

########################################## OUTPUT DIRECTORIES ########################################## 

# TODO

################################################ SUPPORT FUNCTIONS ##################################################

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

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options
if [ $# -lt 15 ] ; then Usage; exit 1; fi

# parse arguments
Path=`getopt1 "--path" $@`  # "$1"
Subject=`getopt1 "--subject" $@`  # "$2"
fMRIFolder=`getopt1 "--fmridir" $@`  # "$3"
FieldMapImageFolder=`getopt1 "--fmapdir" $@`  # "$4"
ScoutFolder=`getopt1 "--scoutdir" $@`  # "$5"
InputNameOffMRI=`getopt1 "--fmriinname" $@`  # "$6"
OutputNameOffMRI=`getopt1 "--fmrioutname" $@`  # "$7"
MagnitudeInputName=`getopt1 "--fmapmag" $@`  # "$8" #Expects 4D volume with two 3D timepoints
PhaseInputName=`getopt1 "--fmapphase" $@`  # "$9"
ScoutInputName=`getopt1 "--scoutin" $@`  # "${10}" #Can be set to NONE, to fake, but this is not recommended
DwellTime=`getopt1 "--echospacing" $@`  # "${11}"
TE=`getopt1 "--echodiff" $@`  # "${12}"
UnwarpDir=`getopt1 "--unwarpdir" $@`  # "${13}"
FinalfMRIResolution=`getopt1 "--fmrires" $@`  # "${14}"
#PipelineScripts="${15}"
#GlobalScripts="${16}"
DistortionCorrection=`getopt1 "--dcmethod" $@`  # "${17}" #FIELDMAP or TOPUP (not functional currently)
GradientDistortionCoeffs=`getopt1 "--gdcoeffs" $@`  # "${18}"
FNIRTConfig=`getopt1 "--fnirtconfig" $@`  # "${19}" #NONE to turn off approximate zblip correction
TopupConfig=`getopt1 "--topupconfig" $@`  # "${20}" #NONE if Topup is not being used
#GlobalBinaries="${21}"
RUN=`getopt1 "--printcom" $@`  # use ="echo" for just printing everything and not running the commands (default is to run)

# Setup PATHS
PipelineScripts=${HCPPIPEDIR_fMRIVol}
GlobalScripts=${HCPPIPEDIR_Global}
GlobalBinaries=${HCPPIPEDIR_Bin}

#Naming Conventions
T1wImage="T1w_acpc_dc"
T1wRestoreImage="T1w_acpc_dc_restore"
T1wRestoreImageBrain="T1w_acpc_dc_restore_brain"
T1wFolder="T1w" #Location of T1w images
AtlasSpaceFolder="MNINonLinear"
ResultsFolder="Results"
BiasField="BiasField_acpc_dc"
BiasFieldMNI="BiasField"
T1wAtlasName="T1w_restore"
MovementRegressor="Movement_Regressors" #No extension, .txt appended
MotionMatrixFolder="MotionMatrices"
MotionMatrixPrefix="MAT_"
FieldMapOutputName="FieldMap"
MagnitudeOutputName="Magnitude"
MagnitudeBrainOutputName="Magnitude_brain"
ScoutName="Scout"
FreeSurferBrainMask="brainmask_fs"
fMRI2strOutputTransform="${OutputNameOffMRI}2str"
RegOutput="Scout2T1w"
AtlasTransform="acpc_dc2standard"
OutputfMRI2StandardTransform="${OutputNameOffMRI}2standard"
T2wRestoreImage="T2w_acpc_dc_restore"
QAImage="T1wMulEPI"
JacobianOut="Jacobian"

fMRIFolder="$Path"/"$Subject"/"$fMRIFolder"
FieldMapImageFolder="$Path"/"$Subject"/"$FieldMapImageFolder"
ScoutFolder="$Path"/"$Subject"/"$ScoutFolder"
T1wFolder="$Path"/"$Subject"/"$T1wFolder"
AtlasSpaceFolder="$Path"/"$Subject"/"$AtlasSpaceFolder"
ResultsFolder="$AtlasSpaceFolder"/"$ResultsFolder"/"$OutputNameOffMRI"

########################################## DO WORK ########################################## 

#Create fake "Scout" if it doesn't exist
if [ $ScoutInputName = "NONE" ] ; then
  ScoutInputName="FakeScoutInput"
  ScoutFolder="${fMRIFolder}_SBRef"
  mkdir -p $ScoutFolder
  ${RUN} ${FSLDIR}/bin/fslroi "$fMRIFolder"/"$InputNameOffMRI" "$fMRIFolder"_SBRef/"$ScoutInputName" 0 1
fi

#Gradient Distortion Correction of fMRI
if [ ! $GradientDistortionCoeffs = "NONE" ] ; then
    mkdir -p "$fMRIFolder"/GradientDistortionUnwarp
    ${RUN} ${FSLDIR}/bin/imcp "$fMRIFolder"/"$InputNameOffMRI" "$fMRIFolder"/GradientDistortionUnwarp/"$OutputNameOffMRI".nii.gz
    ${RUN} "$GlobalScripts"/GradientDistortionUnwarp.sh \
	--workingdir="$fMRIFolder"/GradientDistortionUnwarp \
	--coeffs="$GradientDistortionCoeffs" \
	--in="$fMRIFolder"/GradientDistortionUnwarp/"$OutputNameOffMRI" \
	--out="$fMRIFolder"/"$OutputNameOffMRI"_gdc \
	--owarp="$fMRIFolder"/"$OutputNameOffMRI"_gdc_warp
	
     mkdir -p "$ScoutFolder"/GradientDistortionUnwarp
     ${RUN} cp "$ScoutFolder"/"$ScoutInputName" "$ScoutFolder"/GradientDistortionUnwarp/"$ScoutName".nii.gz
     ${RUN} "$GlobalScripts"/GradientDistortionUnwarp.sh \
	 --workingdir="$ScoutFolder"/GradientDistortionUnwarp \
	 --coeffs="$GradientDistortionCoeffs" \
	 --in="$ScoutFolder"/GradientDistortionUnwarp/"$ScoutName" \
	 --out="$ScoutFolder"/"$ScoutName"_gdc \
	 --owarp="$ScoutFolder"/"$ScoutName"_gdc_warp
else
    echo "NOT PERFORMING GRADIENT DISTORTION CORRECTION"
    ${RUN} ${FSLDIR}/bin/imcp "$fMRIFolder"/"$InputNameOffMRI" "$fMRIFolder"/"$OutputNameOffMRI"_gdc
    ${RUN} ${FSLDIR}/bin/fslroi "$fMRIFolder"/"$OutputNameOffMRI"_gdc "$fMRIFolder"/"$OutputNameOffMRI"_gdc_warp 0 3
    ${RUN} ${FSLDIR}/bin/fslmaths "$fMRIFolder"/"$OutputNameOffMRI"_gdc_warp -mul 0 "$fMRIFolder"/"$OutputNameOffMRI"_gdc_warp
    ${RUN} ${FSLDIR}/bin/imcp "$ScoutFolder"/"$ScoutInputName" "$ScoutFolder"/"$ScoutName"_gdc
fi

mkdir -p "$fMRIFolder"/MotionCorrection_FLIRTbased
${RUN} "$PipelineScripts"/MotionCorrection_FLIRTbased.sh \
    "$fMRIFolder"/MotionCorrection_FLIRTbased \
    "$fMRIFolder"/"$OutputNameOffMRI"_gdc \
    "$ScoutFolder"/"$ScoutName"_gdc \
    "$fMRIFolder"/"$OutputNameOffMRI"_mc \
    "$fMRIFolder"/"$MovementRegressor" \
    "$fMRIFolder"/"$MotionMatrixFolder" \
    "$MotionMatrixPrefix" \
    "$PipelineScripts" \
    "$GlobalScripts"

#EPI Distortion Correction and EPI to T1w Registration
if [ -e ${fMRIFolder}/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased ] ; then
  rm -r ${fMRIFolder}/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased
fi
mkdir -p ${fMRIFolder}/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased

${RUN} ${PipelineScripts}/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased.sh \
    --workingdir=${fMRIFolder}/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased \
    --scoutin=${ScoutFolder}/${ScoutName}_gdc \
    --t1=${T1wFolder}/${T1wImage} \
    --t1restore=${T1wFolder}/${T1wRestoreImage} \
    --t1brain=${T1wFolder}/${T1wRestoreImageBrain} \
    --fmapmag=${FieldMapImageFolder}/${MagnitudeInputName} \
    --fmapphase=${FieldMapImageFolder}/${PhaseInputName} \
    --echodiff=${TE} \
    --echospacing=${DwellTime} \
    --unwarpdir=${UnwarpDir} \
    --owarp=${T1wFolder}/xfms/${fMRI2strOutputTransform} \
    --biasfield=${T1wFolder}/${BiasField} \
    --oregim=${fMRIFolder}/${RegOutput} \
    --freesurferfolder=${T1wFolder} \
    --freesurfersubjectid=${Subject} \
    --gdcoeffs=${GradientDistortionCoeffs} \
    --t2restore=${T1wFolder}/${T2wRestoreImage} \
    --fnirtconfig=${FNIRTConfig} \
    --qaimage=${fMRIFolder}/${QAImage} \
    --method=${DistortionCorrection} \
    --topupconfig=${TopupConfig} \
    --ojacobian=${fMRIFolder}/${JacobianOut} \
#    ${{GlobalBinaries}}
#    ${GlobalScripts} \
    
#One Step Resampling
mkdir -p ${fMRIFolder}/OneStepResampling
${RUN} ${PipelineScripts}/OneStepResampling.sh \
    --workingdir=${fMRIFolder}/OneStepResampling \
    --infmri=${fMRIFolder}/${InputNameOffMRI} \
    --t1=${AtlasSpaceFolder}/${T1wAtlasName} \
    --fmriresout=${FinalfMRIResolution} \
    --atlasspacedir=${AtlasSpaceFolder} \
    --fmri2structin=${T1wFolder}/xfms/${fMRI2strOutputTransform} \
    --struct2std=${AtlasSpaceFolder}/xfms/${AtlasTransform} \
    --owarp=${AtlasSpaceFolder}/xfms/${OutputfMRI2StandardTransform} \
    --motionmatdir=${fMRIFolder}/${MotionMatrixFolder} \
    --motionmatprefix=${MotionMatrixPrefix} \
    --ofmri=${fMRIFolder}/${OutputNameOffMRI}_nonlin \
    --freesurferbrainmask=${AtlasSpaceFolder}/${FreeSurferBrainMask} \
    --biasfield=${AtlasSpaceFolder}/${BiasFieldMNI} \
    --gdfield=${fMRIFolder}/${OutputNameOffMRI}_gdc_warp \
    --scoutin=${ScoutFolder}/${ScoutInputName} \
    --oscout=${fMRIFolder}/${OutputNameOffMRI}_SBRef_nonlin \
    --jacobianin=${fMRIFolder}/${JacobianOut} \
    --ojacobian=${fMRIFolder}/${JacobianOut}_MNI.${FinalfMRIResolution}
    
#Intensity Normalization and Bias Removal
${RUN} ${PipelineScripts}/IntensityNormalization.sh \
    --infmri=${fMRIFolder}/${OutputNameOffMRI}_nonlin \
    --biasfield=${AtlasSpaceFolder}/${BiasFieldMNI}.${FinalfMRIResolution} \
    --jacobian=${fMRIFolder}/${JacobianOut}_MNI.${FinalfMRIResolution} \
    --brainmask=${AtlasSpaceFolder}/${FreeSurferBrainMask}.${FinalfMRIResolution} \
    --ofmri=${fMRIFolder}/${OutputNameOffMRI}_nonlin_norm \
    --inscout=${fMRIFolder}/${OutputNameOffMRI}_SBRef_nonlin \
    --oscout=${fMRIFolder}/${OutputNameOffMRI}_SBRef_nonlin_norm \
    --usejacobian=false

mkdir -p ${ResultsFolder}
# MJ QUERY: WHY THE -r OPTIONS BELOW?
${RUN} cp -r ${fMRIFolder}/${OutputNameOffMRI}_nonlin_norm.nii.gz ${ResultsFolder}/${OutputNameOffMRI}.nii.gz
${RUN} cp -r ${fMRIFolder}/${MovementRegressor}.txt ${ResultsFolder}/${MovementRegressor}.txt
${RUN} cp -r ${fMRIFolder}/${MovementRegressor}_dt.txt ${ResultsFolder}/${MovementRegressor}_dt.txt
${RUN} cp -r ${fMRIFolder}/${OutputNameOffMRI}_SBRef_nonlin_norm.nii.gz ${ResultsFolder}/${OutputNameOffMRI}_SBRef.nii.gz
${RUN} cp -r ${fMRIFolder}/${JacobianOut}_MNI.${FinalfMRIResolution}.nii.gz ${ResultsFolder}/${OutputNameOffMRI}_${JacobianOut}.nii.gz

