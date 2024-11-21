#!/bin/bash
set -eu

#environment configuration
queue="long.q"
EnvironmentScript="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh" #Pipeline environment script

#data location
subjects=(123456 654321)
StudyFolder="${HOME}/projects/YA_HCP_Final"
GroupName="HCP_S1200"

#general settings
#identifier for the subset of subjects that have transmit field scans
#pseudotransmit doesn't have subject exclusion logic, or if you otherwise have made sure the entire group has good transmit data, you may want to set it equal to the group folder name
partialname=Partial
#partialname="$GroupName"
#set this to a text file that has the scanner transmit voltages for all subjects in the provided list, in order
VoltagesFile="$StudyFolder"/"$GroupName"/Scripts/Voltages.txt
GradientDistortionCoeffs=
RegName=MSMAll
LowResMesh=32
grayordRes=2
transmitRes="$grayordRes"
MyelinMappingFWHM=5
oldMyelinMapping=FALSE
#0 for compiled, 1 for interpreted, 2 for octave
MatlabMode=1

#transmit field acquisition details
#mode must be AFI, B1Tx, or PseudoTransmit
mode="AFI"
#mode="B1Tx"
#mode="PseudoTransmit"

#AFI-specific settings
AFITRone=20
AFITRtwo=120
AFITargetFlipAngle=50

#B1Tx-specific settings
#the value in the phase image where the flip angle was ideal
B1TxPhaseDivisor=800

#PseudoTransmit-specific settings
fMRINames=rfMRI_REST1_AP@rfMRI_REST1_PA
ptbbrthresh=0.5
#set this to an already transmit-corrected group average myelin map
ReferenceTemplate=

#IMPORTANT: also edit the input file variables inside the first loop below

#don't edit this section
if [[ "$RegName" == "" || "$RegName" == "MSMSulc" ]]
then
    RegStr=""
else
    RegStr="_$RegName"
fi
GMWMtemplate="$StudyFolder"/"$GroupName"/MNINonLinear/GMWMTemplate.nii.gz
GroupCorrected="$StudyFolder"/"$GroupName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$partialname".MyelinMap_GroupCorr"$RegStr"."$LowResMesh"k_fs_LR.dscalar.nii
GroupUncorrectedMyelin="$StudyFolder"/"$GroupName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$partialname".MyelinMap"$RegStr"."$LowResMesh"k_fs_LR.dscalar.nii
AllSubjUncorrected="$StudyFolder"/"$GroupName"/MNINonLinear/fsaverage_LR"$LowResMesh"k/"$partialname".All.MyelinMap"$RegStr"."$LowResMesh"k_fs_LR.dscalar.nii
PTRefValFile="$StudyFolder"/"$GroupName"/PT_refval.txt

source "$EnvironmentScript"

phase1jobids=()
for subject in "${subjects[@]}"
do
    #EDIT THESE SETTINGS
    #AFI-specific per-subject filenames
    AFIImage=
    
    #B1Tx-specific per-subject filenames
    B1TxMag=
    B1TxPhase=
    
    #Receive bias inputs - ignore this if you used pre-scan normalize or similar
    #unprocessed T1w and T2w are required to do receive correction
    T1wUnprocList=
    T2wUnprocList=
    #use these two if you separately acquired bodycoil and headcoil images
    BodyCoilImage=
    HeadCoilImage=
    #use these two if you acquired a PSN T1w and also saved its non-PSN reconstruction (but all the other raw image inputs are non-PSN)
    rawT1wPSN=
    rawT1wNoPSN=

    #don't edit the rest of this script
    
    phase1jobids+=($(fsl_sub -q "$queue" "$HCPPIPEDIR"/TransmitBias/Phase1_IndividualAlign.sh \
        --study-folder="$StudyFolder" \
        --subject="$subject" \
        --mode="$mode" \
        --afi-image="$AFIImage" \
        --afi-tr-one="$AFITRone" \
        --afi-tr-two="$AFITRtwo" \
        --b1tx-magnitude="$B1TxMag" \
        --b1tx-phase="$B1TxPhase" \
        --b1tx-phase-divisor="$B1TxPhaseDivisor" \
        --pt-fmri-names="$fMRINames" \
        --pt-bbr-threshold="$ptbbrthresh" \
        --unproc-t1w-list="$T1wUnprocList" \
        --unproc-t2w-list="$T2wUnprocList" \
        --receive-bias-body-coil="$BodyCoilImage" \
        --receive-bias-head-coil="$HeadCoilImage" \
        --raw-psn-t1w="$rawT1wPSN" \
        --raw-nopsn-t1w="$rawT1wNoPSN" \
        --scanner-grad-coeffs="$GradientDistortionCoeffs" \
        --reg-name="$RegName" \
        --low-res-mesh="$LowResMesh" \
        --grayordinates-res="$grayordRes" \
        --transmit-res="$transmitRes" \
        --myelin-mapping-fwhm="$MyelinMappingFWHM" \
        --old-myelin-mapping="$oldMyelinMapping"))
done

subjectsStr=$(IFS='@'; echo "${subjects[*]}")
useRCFiles=FALSE
if [[ "$T1wUnprocList" != "" ]]
then
    useRCFiles=TRUE
fi

mkdir -p "$StudyFolder"/"$GroupName"

phase1jobstr=$(IFS=','; echo "${phase1jobids[*]}")
phase2job=$(fsl_sub -q "$queue" -j "$phase1jobstr" "$HCPPIPEDIR"/TransmitBias/Phase2_GroupAverageFit.sh \
    --study-folder="$StudyFolder" \
    --subject-list="$subjectsStr" \
    --mode="$mode" \
    --group-average-name="$GroupName" \
    --transmit-group-name="$partialname" \
    --manual-receive="$useRCFiles" \
    --gmwm-template-out="$GMWMtemplate" \
    --average-myelin-out="$GroupUncorrectedMyelin" \
    --all-myelin-out="$AllSubjUncorrected" \
    --afi-tr-one="$AFITRone" \
    --afi-tr-two="$AFITRtwo" \
    --afi-angle="$AFITargetFlipAngle" \
    --reference-value-out="$PTRefValFile" \
    --reg-name="$RegName" \
    --low-res-mesh="$LowResMesh" \
    --grayordinates-res="$grayordRes" \
    --matlab-run-mode="$MatlabMode")

phase3jobids=()
for subject in "${subjects[@]}"
do
    phase3jobids+=($(fsl_sub -q "$queue" -j "$phase2job" "$HCPPIPEDIR"/TransmitBias/Phase3_IndividualAdjustment.sh \
        --study-folder="$StudyFolder" \
        --subject="$subject" \
        --mode="$mode" \
        --manual-receive="$useRCFiles" \
        --gmwm-template="$GMWMtemplate" \
        --afi-tr-one="$AFITRone" \
        --afi-tr-two="$AFITRtwo" \
        --afi-angle="$AFITargetFlipAngle" \
        --group-corrected-myelin="$GroupCorrected" \
        --myelin-template="$ReferenceTemplate" \
        --group-uncorrected-myelin="$GroupUncorrectedMyelin" \
        --pt-reference-value-file="$PTRefValFile" \
        --reg-name="$RegName" \
        --low-res-mesh="$LowResMesh" \
        --grayordinates-res="$grayordRes" \
        --transmit-res="$transmitRes" \
        --matlab-run-mode="$MatlabMode"))
done

phase3jobstr=$(IFS=','; echo "${phase3jobids[*]}")
fsl_sub -q "$queue" -j "$phase3jobstr" "$HCPPIPEDIR"/TransmitBias/Phase4_GroupAverageCorrectedMaps.sh \
    --study-folder="$StudyFolder" \
    --subject-list="$subjectsStr" \
    --mode="$mode" \
    --group-average-name="$GroupName" \
    --transmit-group-name="$partialname" \
    --voltages="$VoltagesFile" \
    --afi-tr-one="$AFITRone" \
    --afi-tr-two="$AFITRtwo" \
    --afi-angle="$AFITargetFlipAngle" \
    --average-myelin="$GroupUncorrectedMyelin" \
    --reg-name="$RegName" \
    --low-res-mesh="$LowResMesh" \
    --matlab-run-mode="$MatlabMode"

