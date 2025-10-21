#!/bin/bash 


Usage () {
    echo "$(basename $0) --StudyFolder=<path> --Subject=<id> --Species=<species> --RunMode=<mode> [--BrainExtract=<method>] [--StrucRes=<resolution>]"
    echo ""
    echo "Required Options:"
    echo "  --StudyFolder: Path to the study folder containing subject data"
    echo "  --Subject: Subject identifier"
    echo "  --Species: Species type (Human, Chimp, Mac, Marmoset, etc.)"
    echo "  --RunMode: Pipeline run mode (Default, ACPCAlignment, BrainExtraction, T2wToT1wRegAndBiasCorrection, AtlasRegistration)"
    echo ""
    echo "Optional Options:"
    echo "  --BrainExtract: INVIVO (default) or EXVIVO"
    echo "  --StrucRes: Structural resolution in mm (species-specific default will be used if not specified)"
    echo ""
    exit 1;
}


# Parse command line arguments
get_batch_options() {
    local arguments=("$@")
    
    local index=0
    local numArgs=${#arguments[@]}
    local argument
    
    while [ ${index} -lt ${numArgs} ]; do
        argument=${arguments[index]}
        
        case ${argument} in
            --StudyFolder=*)
                StudyFolder=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --Subject=*)
                Subjlist=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --Species=*)
                SPECIES=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --RunMode=*)
                RunMode=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --BrainExtract=*)
                BrainExtract=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --StrucRes=*)
                StrucRes=${argument#*=}
                index=$(( index + 1 ))
                ;;
            *)
                echo ""
                echo "ERROR: Unrecognized Option: ${argument}"
                echo ""
                Usage
                ;;
        esac
    done
}

# Parse arguments
get_batch_options "$@"

# Check required parameters
if [ -z "$StudyFolder" ] || [ -z "$Subjlist" ] || [ -z "$SPECIES" ] || [ -z "$RunMode" ]; then
    echo "ERROR: Missing required parameters"
    Usage
fi



echo "$(basename $0) $@"

if [ -z ${EnvironmentScript} ] ; then
    EnvironmentScript="$HCPPIPEDIR/Examples/Scripts/SetUpHCPPipeline.sh"
fi
source $EnvironmentScript

# species specific config
# If StrucRes is not provided, SetUpSPECIES.sh will use species-specific default
source "$HCPPIPEDIR"/Examples/Scripts/SetUpSPECIES.sh "$SPECIES" "$StrucRes"

for Subject in $Subjlist ; do
    echo $Subject

    # ------------------------------------------------------------------------------
    # Load scan-specific configuration parameters
    # The file ${StudyFolder}/${Subject}/RawData/hcppipe_conf.txt defines:
    #   ## Structural MRI
    #   - T1wInputImages, T2wInputImages
    #
    #   ## Readout Distortion Correction
    #   - T1wSampleSpacing, T2wSampleSpacing
    #
    #   ## Gradient Nonlinearity Correction
    #   - Gradient, UnwarpDir
    #
    #   ## Resting-state fMRI
    #   - Tasklist, Taskreflist, PhaseEncodinglist, Fmriconcatlist
    #
    #   ## TopUp (Distortion correction for sMRI/fMRI)
    #   - TopupNegative, TopupPositive, TopupNegative2, TopupPositive2, DwellTime
    #
    #   ## Diffusion MRI
    #   - DmrilistPositive, DmrilistNegative, EchoSpacing, PEdir
    #
    # If the config file is not found, please set values manually.
    # ------------------------------------------------------------------------------
    if [ -f "${StudyFolder}/${Subject}/RawData/hcppipe_conf.txt" ]; then
        source "${StudyFolder}/${Subject}/RawData/hcppipe_conf.txt"
    else
        echo "  WARNING: ${StudyFolder}/${Subject}/RawData/hcppipe_conf.txt not found. Please set values manually."

        ## Structural MRI
        T1wInputImages=
        T2wInputImages=

        ## Readout Distortion Correction
        T1wSampleSpacing=
        T2wSampleSpacing=

        ## Gradient Nonlinearity Correction
        Gradient=
        UnwarpDir=

        ## Resting-state fMRI
        Tasklist=
        Taskreflist=
        PhaseEncodinglist=
        Fmriconcatlist=

        ## TopUp
        TopupNegative=
        TopupPositive=
        TopupNegative2=
        TopupPositive2=
        DwellTime=

        ## Diffusion MRI
        DmrilistPositive=
        DmrilistNegative=
        EchoSpacing=
        PEdir=
    fi
  
    if [[ $T1wSampleSpacing != "" && $T1wSampleSpacing != "NONE" && $T1wSampleSpacing != "None" && $T2wSampleSpacing != "" && $T2wSampleSpacing != "NONE" && $T2wSampleSpacing != "None" && $StrucSEUnwarpDir != "None" && $StrucSEUnwarpDir != "" ]] ; then
        T1wSampleSpacing=$T1wSampleSpacing  # read from Seriesinfo.txt
        T2wSampleSpacing=$T2wSampleSpacing  # read from Seriesinfo.txt
        UnwarpDir="$StrucUnwarpDir"         # Read direction of structural scan. read from Seriesinfo.txt
        if [[ -n $StrucTopupPositive && -n $StrucTopupNegative && -n $StrucSEDwellTime && "$StrucTopupPositive" != NONE ]] ; then
            SpinEchoPhaseEncodeNegative=${StudyFolder}/${Subject}/RawData/$(echo $StrucTopupNegative | awk '{print $1}') # first SEfield will be used
            SpinEchoPhaseEncodePositive=${StudyFolder}/${Subject}/RawData/$(echo $StrucTopupPositive | awk '{print $1}') # first SEfield will be used
            if [[ -n $StrucTopupPositive2  && -n $StrucTopupNegative2 && "$StrucTopupPositive2" != NONE ]] ; then
                SpinEchoPhaseEncodeNegative2=${StudyFolder}/${Subject}/RawData/$(echo $StrucTopupNegative2 | awk '{print $1}') # first SEfield will be used
                SpinEchoPhaseEncodePositive2=${StudyFolder}/${Subject}/RawData/$(echo $StrucTopupPositive2 | awk '{print $1}') # first SEfield will be used
            fi
            DwellTime="$(echo $StrucSEDwellTime | awk '{print $1}')"    # dwell time for SE field, read from Dwelltime in Seriesinfo.txt
            SEUnwarpDir="$(echo $StrucSEUnwarpDir | awk '{print $1}')"  # read from PhaseEncodinglist in Seriesinfo.txt. x or y (minus or not does not matter)
            AvgrdcSTRING="TOPUP" #Averaging and readout distortion correction methods: "NONE" = average any repeats with no readout correction "FIELDMAP" = average any repeats and use field map for readout correction "TOPUP" = Use Spin Echo FieldMap
        elif [[ $(imtest $StrucMagnitudeInputName) = 1 && $(imtest $StrucPhaseInputName) = 1 && -n $StrucDwelltime ]] ; then
            MagnitudeInputName="${StudyFolder}/${Subject}/RawData/${StrucMagnitudeInputName}" #Expects 4D magitude volume with two 3D timepoints or "NONE" if not used
            PhaseInputName="${StudyFolder}/${Subject}/RawData/${StrucPhaseInputName}" #Expects 3D phase difference volume or "NONE" if not used
            DiffTE="${DiffTE:-2.46}"   # default for 3T
            AvgrdcSTRING="FIELDMAP" #Averaging and readout distortion correction methods: "NONE" = average any repeats with no readout correction "FIELDMAP" = average any repeats and use field map for readout correction "TOPUP" = Use Spin Echo FieldMap
        else
            SpinEchoPhaseEncodeNegative="NONE"
            SpinEchoPhaseEncodePositive="NONE" 
            AvgrdcSTRING="NONE"
        fi
    else
        SpinEchoPhaseEncodeNegative="NONE" #For the spin echo field map volume with a negative phase encoding direction (LR in HCP data), set to NONE if using regular FIELDMAP
        SpinEchoPhaseEncodePositive="NONE" #For the spin echo field map volume with a positive phase encoding direction (RL in HCP data), set to NONE if using regular FIELDMAP
        TE="NONE" # "2.46" delta TE in ms for field map or "NONE" if not used
        DwellTime="NONE" # Echo Spacing or Dwelltime of SE Field Map image (or "NONE" if not used) = 1/(BandwidthPerPixelPhaseEncode * # of phase encoding samples): DICOM field (0019,1028) = BandwidthPerPixelPhaseEncode, DICOM field (0051,100b) AcquisitionMatrixText first value (# of phase encoding samples)
        SEUnwarpDir="NONE" # x or y (minus or not does not matter) "NONE" if not used
        UnwarpDir="NONE"
        AvgrdcSTRING="NONE" #Averaging and readout distortion correction methods: "NONE" = average any repeats with no readout correction "FIELDMAP" = average any repeats and use field map for readout correction   "TOPUP" = Use Spin Echo FieldMap"${
        TopupConfig="NONE" #Config for topup or "NONE" if not used
        T1wSampleSpacing="${T1wSampleSpacing:-NONE}" #"0.0000150" DICOM field (0019,1018) in s or "NONE" if not used
        T2wSampleSpacing="${T2wSampleSpacing:-NONE}" #"0.0000036" DICOM field (0019,1018) in s or "NONE" if not used
        AvgrdcSTRING="NONE"
    fi

    if [[ $Gradient = "" || $Gradient = "NONE" || $Gradient = "None" ]] ; then
        GradientDistortionCoeffs="NONE"               #Location of Coeffs file or "NONE" to skip
    else
        GradientDistortionCoeffs=${GradientDistortionCoeffsDIR}/coeff_${Gradient}.grad
    fi
    BiasFieldSmoothingSigma="${BiasFieldSmoothingSigma:-5}"  # Useally set to 5. "NONE" if not used

    # adapt human convention
    if [ "$T1wInputImages" = "" ] && [ "$T1wlist" != "" ] ; then T1wInputImages="$T1wlist";fi
    if [ "$T2wInputImages" = "" ] && [ "$T2wlist" != "" ] ; then T2wInputImages="$T2wlist";fi

    # set input paths
    IMGS=""; for i in $T1wInputImages ; do  IMGS="${IMGS}@${StudyFolder}/${Subject}/RawData/$i"; done
    T1wInputImages="$IMGS"

    if [[ ! $T2wInputImages = NONE ]] ; then 
        IMGS=""; for i in $T2wInputImages ; do IMGS="${IMGS}@${StudyFolder}/${Subject}/RawData/$i"; done
        T2wInputImages="$IMGS"
    fi

    TruePatientPosition=${StrucTruePatientPosition:-HFS}
    ScannerPatientPosition=${StrucScannerPatientPosition:-HFS}
    echo "BrainExtract=$BrainExtract"

# ${FSLDIR}/bin/fsl_sub ${QUEUE} ${LOG} \
    ${HCPPIPEDIR}/PreFreeSurfer/PreFreeSurferPipeline.sh \
        --path="$StudyFolder" \
        --subject="$Subject" \
        --t1="$T1wInputImages" \
        --t2="$T2wInputImages" \
        --t1template="$T1wTemplate" \
        --t1templatebrain="$T1wTemplateBrain" \
        --t1template2mm="$T1wTemplate2mm" \
        --t2template="$T2wTemplate" \
        --t2templatebrain="$T2wTemplateBrain" \
        --t2template2mm="$T2wTemplate2mm" \
        --templatemask="$TemplateMask" \
        --template2mmmask="$Template2mmMask" \
        --brainsize="$BrainSize" \
        --fnirtconfig="$FNIRTConfig" \
        --fmapmag="$MagnitudeInputName" \
        --fmapphase="$PhaseInputName" \
        --echodiff="$DiffTE" \
        --SEPhaseNeg="$SpinEchoPhaseEncodeNegative" \
        --SEPhasePos="$SpinEchoPhaseEncodePositive" \
        --SEPhaseNeg2="$SpinEchoPhaseEncodeNegative2" \
        --SEPhasePos2="$SpinEchoPhaseEncodePositive2" \
        --seechospacing="$DwellTime" \
        --seunwarpdir="$SEUnwarpDir" \
        --t1samplespacing="$T1wSampleSpacing" \
        --t2samplespacing="$T2wSampleSpacing" \
        --unwarpdir="$UnwarpDir" \
        --gdcoeffs="$GradientDistortionCoeffs" \
        --avgrdcmethod="$AvgrdcSTRING" \
        --topupconfig="$TopupConfig" \
        --bfsigma="$BiasFieldSmoothingSigma" \
        --brainextract="$BrainExtract" \
        --t2wtype="$T2wType" \
        --runmode="$RunMode" \
        --species=${SPECIES} \
        --truepatientposition=${TruePatientPosition} \
        --scannerpatientposition=${ScannerPatientPosition} \
        --betcenter=${betcenter} \
        --betradius=${betradius} \
        --betfraction=${betfraction} \
        --bettop2center=${bettop2center} \
        --betspecieslabel=${betspecieslabel}
      
    # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...

    echo "set -- --path=${StudyFolder} \
        --subject=${Subject} \
        --t1=${T1wInputImages} \
        --t2=${T2wInputImages} \
        --t1template=${T1wTemplate} \
        --t1templatebrain=${T1wTemplateBrain} \
        --t1template2mm=${T1wTemplate2mm} \
        --t2template=${T2wTemplate} \
        --t2templatebrain=${T2wTemplateBrain} \
        --t2template2mm=${T2wTemplate2mm} \
        --templatemask=${TemplateMask} \
        --template2mmmask=${Template2mmMask} \
        --brainsize=${BrainSize} \
        --fnirtconfig=${FNIRTConfig} \
        --fmapmag=${MagnitudeInputName} \
        --fmapphase=${PhaseInputName} \
        --echodiff=${TE} \
        --SEPhaseNeg=${SpinEchoPhaseEncodeNegative} \
        --SEPhasePos=${SpinEchoPhaseEncodePositive} \
        --SEPhaseNeg2=${SpinEchoPhaseEncodeNegative2} \
        --SEPhasePos2=${SpinEchoPhaseEncodePositive2} \
        --seechospacing=${DwellTime} \
        --seunwarpdir=${SEUnwarpDir} \
        --t1samplespacing=${T1wSampleSpacing} \
        --t2samplespacing=${T2wSampleSpacing} \
        --unwarpdir=${UnwarpDir} \
        --gdcoeffs=${GradientDistortionCoeffs} \
        --avgrdcmethod=${AvgrdcSTRING} \
        --topupconfig=${TopupConfig} \
        --bfsigma=${BiasFieldSmoothingSigma} \
        --brainextract=${BrainExtract} \
        --t2wtype=${T2wType} \
        --runmode=${RunMode} \
        --species=${SPECIES} \
        --truepatientposition=${TruePatientPosition} \
        --scannerpatientposition=${ScannerPatientPosition} \
        --betcenter=${betcenter} \
        --betradius=${betradius} \
        --betfraction=${betfraction} \
        --bettop2center=${bettop2center} \
        --betspecieslabel=${betspecieslabel} "

    echo ". ${EnvironmentScript}"

done

