#!/bin/bash


get_batch_options() {
    local arguments=("$@")

    command_line_specified_study_folder=""
    command_line_specified_subj=""
    command_line_specified_run_local="FALSE"

    local index=0
    local numArgs=${#arguments[@]}
    local argument

    while [ ${index} -lt ${numArgs} ]; do
        argument=${arguments[index]}

        case ${argument} in
            --StudyFolder=*)
                command_line_specified_study_folder=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --Subject=*)
                command_line_specified_subj=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --runlocal)
                command_line_specified_run_local="TRUE"
                index=$(( index + 1 ))
                ;;
            *)
                echo ""
                echo "ERROR: Unrecognized Option: ${argument}"
                echo ""
                exit 1
                ;;
        esac
    done
}

get_batch_options "$@"

########################################## EDIT BELOW ##########################################

# Location of Subject folders (named by subjectID)
StudyFolder="${HOME}/projects/NHP_Data"

# Space delimited list of subject IDs
Subjlist="SubjectA"

# Pipeline environment script
EnvironmentScript="${HOME}/projects/Pipelines/Examples/Scripts/SetUpHCPPipeline.sh"

# Species label (Macaque, MacaqueCyno, MacaqueRhesus, Marmoset, NightMonkey, Chimp, Human)
SPECIES="Macaque"

# BBR contrast for EPI to T1w registration (NONE, T1w, or T2w)
#   NONE: no boundary-based registration
#   T1w:  T1w-based BBR (e.g. for MION fMRI)
#   T2w:  T2w-based BBR (default)
BBR="T2w"

# Receive coil bias field correction method (NONE, LEGACY, or SEBASED)
#   SEBASED calculates bias field from spin echo images (requires TOPUP)
#   LEGACY uses the T1w bias field
BiasCorrection="NONE"

# Motion correction type (MCFLIRT or FLIRT)
MCType="MCFLIRT"

# RunMode: which stages to run
#   1: MotionCorrection and all subsequent steps (default)
#   2: DistortionCorrectionAndEPI2T1wReg and subsequent steps
#   3: OneStepResampling and IntensityNormalization only
RunMode="1"

# Jacobian correction (True or False)
# Defaults to True for TOPUP, False for FIELDMAP if not set
UseJacobian="True"

# Use T2w image as phase-zero reference (TRUE or FALSE)
# Set to FALSE when fMRI was scanned in a different session from T2w
UseT2wAsPhaseZero="TRUE"

# Dry run mode (TRUE or FALSE)
# When TRUE, prints pipeline commands without executing them
DryRun="FALSE"

# Session filter: leave empty to process all sessions
# Set to specific session number(s), e.g., "1" or "1 3"
SpecSessionlist=""

# fMRI name filter: leave empty to process all fMRI runs in each session
# Set to a specific fMRI name (without extension) to process only that run
fmriname=""

# Species-specific variables
# These are set by SetUpSPECIES.sh (sourced after EnvironmentScript).
# Override here only if you need non-default values for your dataset.
# Example values for Macaque:
#   FinalFMRIResolution="1.25"
#   TopUpConfig="${HCPPIPEDIR_Config}/b02b0.cnf"
#   WMProjAbs="1"
#   BrainScaleFactor="0.36"
#   betspecieslabel="1"

########################################## END EDIT ##########################################

# Use any command line specified options to override variable settings above
if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi

if [ -n "${command_line_specified_subj}" ]; then
    Subjlist="${command_line_specified_subj}"
fi

# Report major script control variables
echo "StudyFolder: ${StudyFolder}"
echo "Subjlist: ${Subjlist}"
echo "EnvironmentScript: ${EnvironmentScript}"
echo "SPECIES: ${SPECIES}"
echo "Run locally: ${command_line_specified_run_local}"

# Set up pipeline environment variables and software
source "$EnvironmentScript"

# Set up species-specific environment variables
source "$HCPPIPEDIR"/Examples/Scripts/SetUpSPECIES.sh --species="$SPECIES"
source "$HCPPIPEDIR"/FreeSurfer/custom/SetUpFSNHP.sh

# The script ${HCPPIPEDIR}/Examples/Scripts/SetUpSPECIES.sh defines:
#
#BrainScaleFactor="1"        # Brain scale factor relative to human (e.g. 0.36 for macaque)
#CorticalScaleFactor="1"     # Cortical scale factor
#
#### fMRIVolume-relevant variables
#FinalFMRIResolution="2"     # Target final resolution of fMRI data in mm
#TopupConfig="${HCPPIPEDIR_Config}/b02b0.cnf"  # Config for topup or "NONE" if not used
#WMProjAbs="2"               # FreeSurfer wm-proj-abs value
#betspecieslabel="1"          # Species label for bet4animal (0=smallest, 4=largest brain)
#betfraction="0.3"            # Fractional intensity threshold for bet
#
#### PreFreeSurfer-relevant variables (not used in fMRIVolume)
#BrainSize="150"              # BrainSize in mm, distance between top of FOV and bottom of brain
#betcenter="45,55,39"         # Comma separated voxel coordinates in T1wTemplate2mm
#betradius="75"               # Brain radius for bet
#betbiasfieldcor="FALSE"      # Whether to correct bias field for BET
#bettop2center="86"           # Distance between top of FOV and center of brain
#BiasFieldSmoothingSigma="5.0"
#FNIRTConfig="${HCPPIPEDIR_Config}/T1_2_NHP_NNP_Human_2mm.cnf"
#T1wTemplate, T1wTemplateBrain, T1wTemplate2mm, T2wTemplate, etc.
#
# If you want to override SetUpSPECIES.sh values, uncomment and edit the
# relevant lines above after the source command.

# Export species-specific environment variables used by subscripts
export betspecieslabel

# Log the originating call
echo "$@"

#NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
#DO NOT include "-q " at the beginning
#default to no queue, implying run local
QUEUE=""
#QUEUE="hcp_priority.q"

if [[ -n $HCPPIPEDEBUG ]]
then
    set -x
fi

########################################## INPUTS ##########################################

# NHP data layout:
#
#   ${StudyFolder}/${Subject}/RawData/<fMRIName>.nii.gz
#   ${StudyFolder}/${Subject}/RawData/<SBRefName>.nii.gz
#   ${StudyFolder}/${Subject}/RawData/<TopupPositive>.nii.gz
#   ${StudyFolder}/${Subject}/RawData/<TopupNegative>.nii.gz
#   ${StudyFolder}/${Subject}/RawData/hcppipe_conf.txt
#
# The hcppipe_conf.txt file defines per-session task lists, fieldmap files,
# encoding directions, dwell times, patient positions, etc.
# Sessions are separated by @ delimiters within each variable.

######################################### DO WORK ##########################################

SCRIPT_NAME=$(basename "$0")
echo "$SCRIPT_NAME"

for Subject in $Subjlist ; do
    echo "${SCRIPT_NAME}: Processing Subject: ${Subject}"

    # Source per-subject configuration
    # If hcppipe_conf.txt exists, it will be sourced to set the variables below.
    # Otherwise, set these variables manually in this section.
    if [ -e "${StudyFolder}/${Subject}/RawData/hcppipe_conf.txt" ] ; then
        source "${StudyFolder}/${Subject}/RawData/hcppipe_conf.txt"
    else
        echo "${SCRIPT_NAME}: hcppipe_conf.txt not found for ${Subject}, using inline defaults"
        # Set these variables manually when hcppipe_conf.txt is not available.
        # Sessions are separated by @ delimiters. Within each session, runs are space-delimited.
        # Example for a single session with two fMRI runs:
        #   Tasklist="rest1 task1"
        #   Taskreflist="rest1_SBRef task1_SBRef"
        #   TopupPositive="SE_AP SE_AP"
        #   TopupNegative="SE_PA SE_PA"
        #   PhaseEncodinglist="y y"
        #   DwellTime="0.00058"
        #   TruePatientPosition="HFS"
        #   ScannerPatientPosition="HFS"
        # Example for two sessions (separated by @):
        #   Tasklist="rest1 task1@rest2 task2"
        Tasklist=""
        Taskreflist=""
        TopupPositive=""
        TopupNegative=""
        PhaseEncodinglist=""
        Fmriconcatlist=""
        DwellTime=""
        InitWorldMat=""
        ScannerPatientPosition=""
        TruePatientPosition=""
        TopupPositive2=""
        TopupNegative2=""
        Gradient=""
        MagnitudeInputName=""
        PhaseInputName=""
    fi

    # Parse @-delimited session variables from hcppipe_conf.txt
    OrigTasklist=$(echo $Tasklist | sed -e 's/^@//g' | sed -e 's/@$//g')
    OrigTaskreflist=$(echo $Taskreflist | sed -e 's/^@//g' | sed -e 's/@$//g')
    OrigTopupPositive=$(echo $TopupPositive | sed -e 's/^@//g' | sed -e 's/@$//g')
    OrigTopupNegative=$(echo $TopupNegative | sed -e 's/^@//g' | sed -e 's/@$//g')
    OrigPhaseEncodinglist=$(echo $PhaseEncodinglist | sed -e 's/^@//g' | sed -e 's/@$//g')
    OrigFmriconcatlist=$(echo $Fmriconcatlist | sed -e 's/^@//g' | sed -e 's/@$//g')
    OrigDwellTime=$(echo $DwellTime | sed -e 's/^@//g' | sed -e 's/@$//g')
    OrigInitWorldMat=$(echo $InitWorldMat | sed -e 's/^@//g' | sed -e 's/@$//g')
    OrigScannerPatientPosition=$(echo $ScannerPatientPosition | sed -e 's/^@//g' | sed -e 's/@$//g')
    OrigTruePatientPosition=$(echo $TruePatientPosition | sed -e 's/^@//g' | sed -e 's/@$//g')
    OrigTopupPositive2=$(echo $TopupPositive2 | sed -e 's/^@//g' | sed -e 's/@$//g')
    OrigTopupNegative2=$(echo $TopupNegative2 | sed -e 's/^@//g' | sed -e 's/@$//g')

    # Determine session list
    if [ -n "$SpecSessionlist" ] ; then
        Sessionlist="$SpecSessionlist"
    else
        nsession=$(echo $OrigTasklist | awk -F"@" '{print NF}')
        Sessionlist=$(seq 1 $nsession)
    fi

    for session in $Sessionlist ; do
        echo "  ${SCRIPT_NAME}: Processing Session: ${session}"

        # Extract session-specific variables
        SessionTasklist=$(echo $OrigTasklist | cut -d '@' -f ${session})
        SessionTaskreflist=$(echo $OrigTaskreflist | cut -d '@' -f ${session})
        SessionTopupPositive=$(echo $OrigTopupPositive | cut -d '@' -f ${session})
        SessionTopupNegative=$(echo $OrigTopupNegative | cut -d '@' -f ${session})
        PhaseEncodinglist=$(echo $OrigPhaseEncodinglist | cut -d '@' -f ${session})
        fmriconcat=$(echo $OrigFmriconcatlist | cut -d '@' -f ${session} | sed -e 's/ //g')
        DwellTime=$(echo $OrigDwellTime | cut -d '@' -f ${session} | sed -e 's/ //g')
        ScannerPatientPosition=$(echo $OrigScannerPatientPosition | cut -d '@' -f ${session} | sed -e 's/ //g')
        TruePatientPosition=$(echo $OrigTruePatientPosition | cut -d '@' -f ${session} | sed -e 's/ //g')
        SessionTopupPositive2=$(echo $OrigTopupPositive2 | cut -d '@' -f ${session})
        SessionTopupNegative2=$(echo $OrigTopupNegative2 | cut -d '@' -f ${session})

        # Validate InitWorldMat if specified
        if [ -n "$OrigInitWorldMat" ] ; then
            InitWorldMat="${StudyFolder}/${Subject}/RawData/$(echo $OrigInitWorldMat | cut -d '@' -f ${session} | sed -e 's/ //g')"
            if [ ! -e "$InitWorldMat" ] ; then
                echo "ERROR: cannot find $InitWorldMat"
                exit 1
            fi
        fi

        # Default patient positions to HFS if not specified
        if [ -z "$TruePatientPosition" ] ; then
            TruePatientPosition=HFS
        fi
        if [ -z "$ScannerPatientPosition" ] ; then
            ScannerPatientPosition=HFS
        fi

        # Determine fMRI run list
        nSessionTasklist=$(echo $SessionTasklist | wc -w)
        fmrinumlist=""
        if [ -n "$fmriname" ] ; then
            j=1
            for i in $SessionTasklist; do
                if [[ "$(remove_ext $i)" = "$fmriname" ]] ; then
                    fmrinumlist="$j"
                fi
                j=$((j + 1))
            done
        else
            fmrinumlist=$(seq 1 $nSessionTasklist)
        fi

        for fmrinum in $fmrinumlist ; do
            fMRINameOrig=$(echo $SessionTasklist | cut -d " " -f $fmrinum)
            UnwarpDir=$(echo $PhaseEncodinglist | cut -d " " -f $fmrinum)
            fMRIName=$(basename $(remove_ext $fMRINameOrig))

            echo "    ${SCRIPT_NAME}: Processing fMRI: ${fMRIName}"

            fMRITimeSeries=$(imglob -extension "${StudyFolder}/${Subject}/RawData/${fMRIName}")
            fMRISBRef=$(imglob -extension "${StudyFolder}/${Subject}/RawData/$(echo $SessionTaskreflist | cut -d " " -f $fmrinum)")

            if [[ "$fMRITimeSeries" = "" || "$fMRISBRef" = "" ]] ; then
                echo "ERROR: cannot find fMRI runs for ${fMRIName}"
                exit 1
            fi

            # Distortion correction setup
            if [[ -n $SessionTopupPositive && -n $SessionTopupNegative ]] ; then
                DistortionCorrection="TOPUP"

                if [ -n "$(echo $SessionTopupNegative | cut -d " " -f $fmrinum)" ] ; then
                    SpinEchoPhaseEncodeNegative=$(imglob -extension "${StudyFolder}/${Subject}/RawData/$(echo $SessionTopupNegative | cut -d " " -f $fmrinum)")
                else
                    SpinEchoPhaseEncodeNegative=$(imglob -extension "${StudyFolder}/${Subject}/RawData/$(echo $SessionTopupNegative | cut -d " " -f 1)")
                fi

                if [ -n "$(echo $SessionTopupPositive | cut -d " " -f $fmrinum)" ] ; then
                    SpinEchoPhaseEncodePositive=$(imglob -extension "${StudyFolder}/${Subject}/RawData/$(echo $SessionTopupPositive | cut -d " " -f $fmrinum)")
                else
                    SpinEchoPhaseEncodePositive=$(imglob -extension "${StudyFolder}/${Subject}/RawData/$(echo $SessionTopupPositive | cut -d " " -f 1)")
                fi

                PhaseInputName="NONE"
                MagnitudeInputName="NONE"
                GEB0InputName="NONE"
                DeltaTE="NONE"
                UseJacobian="${UseJacobian:-True}"

                # Second SE Phase (optional)
                if [[ -n $SessionTopupPositive2 && -n $SessionTopupNegative2 ]] ; then
                    if [ -n "$(echo $SessionTopupNegative2 | cut -d " " -f $fmrinum)" ] ; then
                        SpinEchoPhaseEncodeNegative2=$(imglob -extension "${StudyFolder}/${Subject}/RawData/$(echo $SessionTopupNegative2 | cut -d " " -f $fmrinum)")
                    else
                        SpinEchoPhaseEncodeNegative2=$(imglob -extension "${StudyFolder}/${Subject}/RawData/$(echo $SessionTopupNegative2 | cut -d " " -f 1)")
                    fi
                    if [ -n "$(echo $SessionTopupPositive2 | cut -d " " -f $fmrinum)" ] ; then
                        SpinEchoPhaseEncodePositive2=$(imglob -extension "${StudyFolder}/${Subject}/RawData/$(echo $SessionTopupPositive2 | cut -d " " -f $fmrinum)")
                    else
                        SpinEchoPhaseEncodePositive2=$(imglob -extension "${StudyFolder}/${Subject}/RawData/$(echo $SessionTopupPositive2 | cut -d " " -f 1)")
                    fi
                else
                    SpinEchoPhaseEncodeNegative2=NONE
                    SpinEchoPhaseEncodePositive2=NONE
                fi

                # Use T2w as a phase zero reference
                if [[ $(imtest "${StudyFolder}/${Subject}/T2w/T2w") = 1 && "$UseT2wAsPhaseZero" = "TRUE" ]] ; then
                    SpinEchoPhaseEncodeZero="${StudyFolder}/${Subject}/T2w/T2w"
                    SpinEchoPhaseEncodeZeroFSBrainmask="${StudyFolder}/${Subject}/T2w/T2w_brainmask_fs"
                else
                    SpinEchoPhaseEncodeZero=NONE
                    SpinEchoPhaseEncodeZeroFSBrainmask=NONE
                fi

            elif [[ "$MagnitudeInputName" != "" && "$PhaseInputName" != "" ]] ; then

                MagnitudeInputName="$(imglob -extension "${StudyFolder}/${Subject}/RawData/${MagnitudeInputName}")"
                PhaseInputName="$(imglob -extension "${StudyFolder}/${Subject}/RawData/${PhaseInputName}")"
                DistortionCorrection="FIELDMAP"
                DeltaTE="2.46" # 2.46ms for 3T, 1.02ms for 7T
                GEB0InputName="NONE"
                UseJacobian="${UseJacobian:-False}"
                SpinEchoPhaseEncodeNegative="NONE"
                SpinEchoPhaseEncodePositive="NONE"
                SpinEchoPhaseEncodeNegative2="NONE"
                SpinEchoPhaseEncodePositive2="NONE"
                SpinEchoPhaseEncodeZero="NONE"
                SpinEchoPhaseEncodeZeroFSBrainmask="NONE"

            else
                echo "ERROR: no fieldmap data supplied"
                exit 1
            fi

            # Gradient distortion correction
            GradientDistortionCoeffs="NONE"
            if [ -n "$Gradient" ] ; then
                GradientDistortionCoeffs="${GradientDistortionCoeffsDIR}/coeff_${Gradient}.grad"
            fi

            # Establish queuing command
            if [[ "${command_line_specified_run_local}" == "TRUE" || "$QUEUE" == "" ]] ; then
                echo "About to locally run ${HCPPIPEDIR}/fMRIVolume/GenericfMRIVolumeProcessingPipeline.sh"
                queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
            else
                echo "About to use fsl_sub to queue ${HCPPIPEDIR}/fMRIVolume/GenericfMRIVolumeProcessingPipeline.sh"
                queuing_command=("$FSLDIR/bin/fsl_sub" -q "$QUEUE")
            fi

            # Override queuing for dry run
            if [ "$DryRun" = "TRUE" ] ; then
                queuing_command=(echo)
            fi

            "${queuing_command[@]}" "$HCPPIPEDIR"/fMRIVolume/GenericfMRIVolumeProcessingPipeline.sh \
                --path="$StudyFolder" \
                --subject="$Subject" \
                --fmriname="$fMRIName" \
                --fmritcs="$fMRITimeSeries" \
                --fmriscout="$fMRISBRef" \
                --SEPhaseNeg="$SpinEchoPhaseEncodeNegative" \
                --SEPhasePos="$SpinEchoPhaseEncodePositive" \
                --SEPhaseNeg2="$SpinEchoPhaseEncodeNegative2" \
                --SEPhasePos2="$SpinEchoPhaseEncodePositive2" \
                --SEPhaseZero="$SpinEchoPhaseEncodeZero" \
                --SEPhaseZeroFSBrainmask="$SpinEchoPhaseEncodeZeroFSBrainmask" \
                --fmapmag="$MagnitudeInputName" \
                --fmapphase="$PhaseInputName" \
                --fmapcombined="$GEB0InputName" \
                --echospacing="$DwellTime" \
                --echodiff="$DeltaTE" \
                --unwarpdir="$UnwarpDir" \
                --fmrires="$FinalFMRIResolution" \
                --dcmethod="$DistortionCorrection" \
                --gdcoeffs="$GradientDistortionCoeffs" \
                --topupconfig="$TopUpConfig" \
                --biascorrection="$BiasCorrection" \
                --usejacobian="$UseJacobian" \
                --mctype="$MCType" \
                --bbr="$BBR" \
                --wmprojabs="$WMProjAbs" \
                --initworldmat="$InitWorldMat" \
                --scannerpatientposition="$ScannerPatientPosition" \
                --truepatientposition="$TruePatientPosition" \
                --species="$SPECIES" \
                --brainscalefactor="$BrainScaleFactor" \
                --runmode="$RunMode"

            # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...

            echo "set -- --path=$StudyFolder \
                --subject=$Subject \
                --fmriname=$fMRIName \
                --fmritcs=$fMRITimeSeries \
                --fmriscout=$fMRISBRef \
                --SEPhaseNeg=$SpinEchoPhaseEncodeNegative \
                --SEPhasePos=$SpinEchoPhaseEncodePositive \
                --SEPhaseNeg2=$SpinEchoPhaseEncodeNegative2 \
                --SEPhasePos2=$SpinEchoPhaseEncodePositive2 \
                --SEPhaseZero=$SpinEchoPhaseEncodeZero \
                --SEPhaseZeroFSBrainmask=$SpinEchoPhaseEncodeZeroFSBrainmask \
                --fmapmag=$MagnitudeInputName \
                --fmapphase=$PhaseInputName \
                --fmapcombined=$GEB0InputName \
                --echospacing=$DwellTime \
                --echodiff=$DeltaTE \
                --unwarpdir=$UnwarpDir \
                --fmrires=$FinalFMRIResolution \
                --dcmethod=$DistortionCorrection \
                --gdcoeffs=$GradientDistortionCoeffs \
                --topupconfig=$TopUpConfig \
                --biascorrection=$BiasCorrection \
                --usejacobian=$UseJacobian \
                --mctype=$MCType \
                --bbr=$BBR \
                --wmprojabs=$WMProjAbs \
                --initworldmat=$InitWorldMat \
                --scannerpatientposition=$ScannerPatientPosition \
                --truepatientposition=$TruePatientPosition \
                --species=$SPECIES \
                --brainscalefactor=$BrainScaleFactor \
                --runmode=$RunMode"

            echo ". ${EnvironmentScript}"

        done
    done
done
