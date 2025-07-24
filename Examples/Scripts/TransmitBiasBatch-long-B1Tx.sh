#!/bin/bash
set -eu

# Function description
#
# For the given subject, identify_timepoins creates a string listing @ separated visits/timepoints to process
# Uses StudyFolder, ExcludeVisits, PossibleVisits global variables as input.
# Subject must be supplied as the first argument. 

function identify_timepoints
{
    local subject=$1
    local tplist=""
    local tp visit n

    #build the list of timepoints
    n=0
    for visit in ${PossibleVisits[*]}; do
        tp="${subject}_${visit}"
        if [ -d "$StudyFolder/$tp" ] && ! [[ " ${ExcludeVisits[*]+${ExcludeVisits[*]}} " =~ [[:space:]]"$tp"[[:space:]] ]]; then
             if (( n==0 )); then 
                    tplist="$tp"
             else
                    tplist="$tplist@$tp"
             fi
        fi
        ((n++))
    done
    echo $tplist
}

#environment configuration
queue="long.q"
StudyFolder="${HOME}/data/Pipelines_ExampleData"
EnvironmentScript="${StudyFolder}/scripts/SetUpHCPPipeline.sh" #Pipeline environment script
source "$EnvironmentScript"

#data location
#Space delimited list of subject IDs
Subjlist=(MySubject)
#list of possible visits. Visit folder is expected to be named <Subject>_<Visit>
PossibleVisits=(V1 V2)
#Space delimited list of longitudinal template ID's, one per subject.
Templates=(MySubject_V1_V2)

GMWMTemplate="/group-directory/MNINonLinear/GMWMTemplate.nii.gz"
GroupCorrectedMyelin="/group-directory/MNINonLinear/fsaverage_LR32k/Partial.MyelinMap_GroupCorr_MSMAll.32k_fs_LR.dscalar.nii"

#general settings
#set this to a text file that has the scanner transmit voltages for all subjects in the provided list, in order
VoltagesFile="$StudyFolder"/voltages-MySubject.txt
GradientDistortionCoeffs="/path-to-gradient-distortion-coefs/coefs.grad"
RegName=MSMAll
LowResMesh=32
grayordRes=2
transmitRes="$grayordRes"
MyelinMappingFWHM=5
oldMyelinMapping=TRUE
#0 for compiled, 1 for interpreted, 2 for octave
MatlabMode=1

#transmit field acquisition details
mode="B1Tx"


#B1Tx-specific settings
#the value in the phase image where the flip angle was ideal
B1TxPhaseDivisor=800

for (( i=0; i<${#Subjlist[@]}; i++ )); do

    subject="${Subjlist[i]}"
    echo $subject
    TemplateLong="${Templates[i]}"
    Timepoints=$(identify_timepoints "$subject")
    echo $Timepoints

    fsl_sub -q "$queue" "$HCPPIPEDIR/TransmitBias/TransmitBiasLong.sh" \
        --study-folder="$StudyFolder" \
        --subject="$subject" \
        --sessions="$Timepoints" \
        --mode="$mode" \
        --reg-name="$RegName" \
        --gmwm-template="$GMWMTemplate" \
        --group-corrected-myelin="$GroupCorrectedMyelin" \
        --b1tx-phase-divisor="$B1TxPhaseDivisor"\
        --longitudinal-template="$TemplateLong" \
        --scanner-grad-coeffs="$GradientDistortionCoeffs"
done
