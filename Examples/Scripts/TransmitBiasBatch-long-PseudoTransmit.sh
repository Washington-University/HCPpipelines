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
Subjlist=(HCA6002236)
#list of possible visits. Visit folder is expected to be named <Subject>_<Visit>
PossibleVisits="V1_MR V2_MR V3_MR"
#Space delimited list of longitudinal template ID's, one per subject.
Templates=(HCA6002236_V1_V2_V3)

GMWMTemplate="/group-directory/MNINonLinear/GMWMTemplate.nii.gz"

#general settings
#set this to a text file that has the scanner transmit voltages for all subjects in the provided list, in order
GradientDistortionCoeffs=
RegName=MSMAll
mode="PseudoTransmit"

#PseudoTransmit-specific settings
fMRINames=rfMRI_REST1_AP@rfMRI_REST1_PA
ptbbrthresh=0.5
#set this to an already transmit-corrected group average myelin map
ReferenceTemplate="/path/Group/MNINonLinear/fsaverage_LR32k/GoodAFI.MyelinMap_GroupCorr_MSMAll.32k_fs_LR.dscalar.nii"
GroupUncorrectedMyelin="/path/Group/MNINonLinear/fsaverage_LR32k/GoodAFI.MyelinMap_MSMAll.32k_fs_LR.dscalar.nii"

PTRefValFile="/path/PT_refval.txt"

for (( i=0; i<${#Subjlist[@]}; i++ )); do

    subject="${Subjlist[i]}"
    TemplateLong="${Templates[i]}"
    Timepoints=$(identify_timepoints "$subject")

    fsl_sub -q "long.q" "$HCPPIPEDIR/TransmitBias/TransmitBiasLong.sh" \
        --study-folder="$StudyFolder" \
        --subject="$subject" \
        --sessions="$Timepoints" \
        --longitudinal-template="$TemplateLong" \
        --mode="$mode" \
        --reg-name="$RegName" \
        --gmwm-template="$GMWMTemplate" \
        --pt-fmri-names="$fMRINames" \
        --pt-bbr-threshold="$ptbbrthresh" \
        --myelin-template="$ReferenceTemplate" \
        --group-uncorrected-myelin="$GroupUncorrectedMyelin" \
        --pt-reference-value-file="$PTRefValFile" \
        --scanner-grad-coeffs="$GradientDistortionCoeffs"
done