#!/bin/bash

Usage () {
    echo "$(basename $0) --StudyFolder=<path> --Subject=<id> --Species=<species> [options]"
    echo ""
    echo "Required Options:"
    echo "  --StudyFolder: Path to the study folder containing subject data"
    echo "  --Subject: Subject identifier (space-separated list allowed)"
    echo "  --Species: Species type (Human, Chimp, RhesusMacaque, MacaqueMac30BS,"
    echo "             CynoMacaque, SnowMacaque, Marmoset, NightMonkey)"
    echo ""
    echo "Optional Options:"
    echo "  --runlocal: Run locally instead of queuing (default queue configured below)"
    echo ""
    exit 1
}

# ==== User-editable section ====
# Edit these variables before running
StudyFolder="${HOME}/projects/Pipelines_ExampleData"
Subjlist="nhp_session1 nhp_session2"
SPECIES="RhesusMacaque" # "Human", "Chimp", "MacaqueMac30BS", "CynoMacaque", "RhesusMacaque", "SnowMacaque", "Marmoset" or "NightMonkey"

# Parse command line arguments
get_batch_options() {
    local arguments=("$@")
    command_line_specified_run_local="FALSE"

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
            --runlocal)
                command_line_specified_run_local="TRUE"
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

get_batch_options "$@"

# Check required parameters
if [ -z "$StudyFolder" ] || [ -z "$Subjlist" ] || [ -z "$SPECIES" ]; then
    echo "ERROR: Missing required parameters"
    Usage
fi

echo "$(basename $0) $@"

# Requirements for this script
#  installed versions of: FSL, FreeSurfer, Connectome Workbench (wb_command), gradunwarp (HCP version)
#  environment: HCPPIPEDIR, FSLDIR, FREESURFER_HOME, CARET7DIR, PATH for gradient_unwarp.py

if [ -z "${EnvironmentScript}" ]; then
    EnvironmentScript="$HCPPIPEDIR/Examples/Scripts/SetUpHCPPipeline.sh"
fi
source "$EnvironmentScript"

# Set up species-specific environment variables (BrainScaleFactor, resolution, etc.)
source "$HCPPIPEDIR"/Examples/Scripts/SetUpSPECIES.sh --species="$SPECIES" --structres="0.5"
#HACK: work around the log tool name hack in SetUpSPECIES.sh
log_SetToolName "$(basename -- "$0")"

# Log the originating call
echo "$@"

# Assume that submission nodes have OPENMP enabled (needed for eddy - at least 8 cores suggested for HCP data)
# NOTE: syntax for QUEUE has changed compared to earlier pipeline releases,
# DO NOT include "-q " at the beginning
# default to no queue, implying run local
QUEUE=""
#QUEUE="hcp_priority.q"

# specify PRINTCOM="echo" to echo commands the pipeline would run, instead of running them
PRINTCOM=""
#PRINTCOM="echo"

########################################## INPUTS ##########################################

# Scripts called by this script do assume they run on the outputs of the PreFreeSurfer Pipeline,
# which is a prerequisite for this pipeline.

# Per-subject configuration is expected to be provided via
#   ${StudyFolder}/${Subject}/RawData/hcppipe_conf.txt
# When that file is absent, edit the "manual fallback" block below to match your data.

######################################### DO WORK ##########################################

for Subject in $Subjlist ; do
    echo "$Subject"

    RawDataDir="$StudyFolder/$Subject/RawData"

    if [ -f "${RawDataDir}/hcppipe_conf.txt" ]; then
        source "${RawDataDir}/hcppipe_conf.txt"
        # ------------------------------------------------------------------------------
        # Expected diffusion-related variables in hcppipe_conf.txt:
        #   DiffPosData              # @-separated list of positive PE direction DWI files (names under RawData/)
        #   DiffNegData              # @-separated list of negative PE direction DWI files
        #   DiffEchoSpacingSec       # effective echo spacing of DWI in seconds
        #   DiffPEdir                # 1 = LR/RL, 2 = AP/PA
        #   GradientDistortionCoeffs # gradient distortion coefficient file or NONE
        #   DiffTruePatientPosition  # HFS / FFS / HFSx / FFSx (true body orientation during scan)
        #   DiffScannerPatientPosition # HFS / FFS (scanner-reported orientation)
        #   DiffTopupConfig          # topup config file (optional; default b02b0.cnf)
        #   DiffResamp               # eddy --resamp value (e.g., jac, lsr). Leave unset to skip.
        #   UseDWIPhaseZero          # TRUE/FALSE - add T2w as phase-zero volume for topup
        # ------------------------------------------------------------------------------
    else
        echo "  WARNING: ${RawDataDir}/hcppipe_conf.txt not found."
        echo "  Please prepare hcppipe_conf.txt, or uncomment and edit the manual fallback block."

        # ---- Manual fallback (uncomment and edit) ------------------------------------
        #DiffPosData="DWI_dir99_RL_1 DWI_dir99_RL_2"   # space-separated file names under RawData/
        #DiffNegData="DWI_dir99_LR_1 DWI_dir99_LR_2"   # opposite PE polarity
        #DiffEchoSpacingSec="0.00078"                   # effective echo spacing in seconds
        #DiffPEdir=1                                    # 1 for LR/RL, 2 for AP/PA
        #GradientDistortionCoeffs="NONE"                # path to grad coefficient file or NONE
        #DiffTruePatientPosition="HFSx"                 # e.g., sphinx head-first for NHP
        #DiffScannerPatientPosition="HFS"               # scanner-reported orientation
        #DiffTopupConfig=""                              # leave empty to use pipeline default
        #DiffResamp=""                                   # eddy --resamp (e.g., jac or lsr); leave empty to omit
        #UseDWIPhaseZero="FALSE"                        # TRUE to add T2w as phase-zero
        # ------------------------------------------------------------------------------
    fi

    # Build @-separated lists from space-separated file names under RawData/
    if [ -n "${DiffPosData:-}" ]; then
        PosData=""; for i in $DiffPosData ; do PosData="${PosData}@${RawDataDir}/${i}"; done
        PosData="${PosData#@}"
    fi
    if [ -n "${DiffNegData:-}" ]; then
        NegData=""; for i in $DiffNegData ; do NegData="${NegData}@${RawDataDir}/${i}"; done
        NegData="${NegData#@}"
    fi

    EchoSpacingSec="${DiffEchoSpacingSec:-}"
    PEdir="${DiffPEdir:-1}"
    Gdcoeffs="${GradientDistortionCoeffs:-NONE}"
    TruePatientPosition="${DiffTruePatientPosition:-HFS}"
    ScannerPatientPosition="${DiffScannerPatientPosition:-HFS}"
    UseDWIPhaseZero="${UseDWIPhaseZero:-FALSE}"
    DiffTopupConfig="${DiffTopupConfig:-}"
    DiffResamp="${DiffResamp:-}"

    # Sanity check for required diffusion inputs
    if [ -z "${PosData:-}" ] || [ -z "${NegData:-}" ] || [ -z "${EchoSpacingSec}" ]; then
        echo "  ERROR: DiffPosData / DiffNegData / DiffEchoSpacingSec must be set (via hcppipe_conf.txt or manual fallback). Skipping ${Subject}."
        continue
    fi

    # Compose NHP-specific option block for DiffPreprocPipeline.sh
    nhp_opts=(
        "--species=${SPECIES}"
        "--wmprojabs=${DiffWMProjAbs:-2}"
        "--truepatientposition=${TruePatientPosition}"
        "--scannerpatientposition=${ScannerPatientPosition}"
        "--usephasezero=${UseDWIPhaseZero}"
    )
    if [ -n "${DiffResamp}" ]; then
        nhp_opts+=("--resamp=${DiffResamp}")
    fi
    if [ -n "${DiffTopupConfig}" ]; then
        nhp_opts+=("--topup-config-file=${DiffTopupConfig}")
    fi

    # Optional extra eddy args (e.g., slice-to-volume correction for NHP).
    # Pass each token as a separate --extra-eddy-arg (the option is repeatable).
    # Example: ExtraEddyArgs="--mporder=6 --s2v_niter=8 --s2v_lambda=1 --s2v_interp=trilinear"
    ExtraEddyArgs="${ExtraEddyArgs:-}"
    extra_args=()
    for token in ${ExtraEddyArgs}; do
        extra_args+=("--extra-eddy-arg=${token}")
    done

    if [[ "${command_line_specified_run_local}" == "TRUE" || "${QUEUE}" == "" ]]; then
        echo "About to locally run ${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline.sh"
        queuing_command=("$HCPPIPEDIR"/global/scripts/captureoutput.sh)
    else
        echo "About to use fsl_sub to queue ${HCPPIPEDIR}/DiffusionPreprocessing/DiffPreprocPipeline.sh"
        queuing_command=("${FSLDIR}/bin/fsl_sub" -q "$QUEUE")
    fi

    "${queuing_command[@]}" "${HCPPIPEDIR}"/DiffusionPreprocessing/DiffPreprocPipeline.sh \
        --path="${StudyFolder}" \
        --session="${Subject}" \
        --posData="${PosData}" \
        --negData="${NegData}" \
        --echospacing-seconds="${EchoSpacingSec}" \
        --PEdir="${PEdir}" \
        --gdcoeffs="${Gdcoeffs}" \
        --printcom="${PRINTCOM}" \
        "${nhp_opts[@]}" \
        ${extra_args[@]+"${extra_args[@]}"}

done
