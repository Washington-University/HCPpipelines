#!/bin/bash
function createHeadMask() {
    # createHeadMask - Create head mask from T1w and T2w images
    #
    # Usage: createHeadMask --study-folder=<path> --subject=<subj> [--t1w=<filename>] [--t2w=<filename>] [--brain-mask=<filename>] [--output-filename=<filename>]
    #
    # Required arguments:
    #   --study-folder=<path>    Path to study folder
    #   --subject=<subj>         Subject ID
    #
    # Optional arguments:
    # (All of these files are expected to be in the subject's /T1w folder))
    #   --t1w=<filename>         T1w image filename (default: T1w_acpc_dc_restore.nii.gz)
    #   --t2w=<filename>         T2w image filename (default: T2w_acpc_dc_restore.nii.gz)
    #   --brain-mask=<filename>  Brain mask filename (default: brainmask_fs.nii.gz)
    #   --output-filename=<filename> Output head mask filename (default: Head.nii.gz)
    #
    # Output:
    #   Head mask file in the subject's T1w folder
    
    local StudyFolder=""
    local Subj=""
    local T1w="T1w_acpc_dc_restore.nii.gz"
    local T2w="T2w_acpc_dc_restore.nii.gz"
    local brainMask="brainmask_fs.nii.gz"
    local outputFilename="Head.nii.gz"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --study-folder=*)
                StudyFolder="${1#*=}"
                ;;
            --subject=*)
                Subj="${1#*=}"
                ;;
            --t1w=*)
                T1w="${1#*=}"
                ;;
            --t2w=*)
                T2w="${1#*=}"
                ;;
            --brain-mask=*)
                brainMask="${1#*=}"
                ;;
            --output-filename=*)
                outputFilename="${1#*=}"
                ;;
            *)
                echo "ERROR: Unrecognized option: $1" >&2
                return 1
                ;;
        esac
        shift
    done
    
    # Validate required arguments
    if [[ -z "$StudyFolder" ]]; then
        echo "ERROR: --study-folder is required" >&2
        return 1
    fi
    
    if [[ -z "$Subj" ]]; then
        echo "ERROR: --subject is required" >&2
        return 1
    fi
    
    if [[ ! -d "$StudyFolder" ]]; then
        echo "ERROR: StudyFolder does not exist: $StudyFolder" >&2
        return 1
    fi
    
    # Set input and output paths
    local T1wFolder="${StudyFolder}/${Subj}/T1w"
    local headMask="${T1wFolder}/${outputFilename}"
    
    # Validate input files exist
    if [[ ! -f "${T1wFolder}/${T1w}" ]]; then
        echo "ERROR: T1w image not found: ${T1wFolder}/${T1w}" >&2
        return 1
    fi
    
    if [[ ! -f "${T1wFolder}/${T2w}" ]]; then
        echo "ERROR: T2w image not found: ${T1wFolder}/${T2w}" >&2
        return 1
    fi
    
    if [[ ! -f "${T1wFolder}/${brainMask}" ]]; then
        echo "ERROR: Brain mask not found: ${T1wFolder}/${brainMask}" >&2
        return 1
    fi
    
    # Prepare temp files
    source "$HCPPIPEDIR/global/scripts/tempfiles.shlib" "$@"
    tempfiles_create HeadSize_bottomslice_XXXXXX.nii.gz botslicetemp
    tempfiles_create HeadSize_Head_XXXXXX.nii.gz headtemp
    
    # Main Processing
    # taken from https://github.com/Washington-University/HCPpipelines/blob/39b9e03c90b80cdc22c81342defe5db7b674a642/TransmitBias/scripts/CreateTransmitBiasROIs.sh#L49C1-L54C71 
    fslmaths "${T1wFolder}/${T1w}" -mul "${T1wFolder}/${T2w}" -sqrt "$headtemp"
    brainmean=$(fslstats "$headtemp" -k "${T1wFolder}/${brainMask}" -M | tr -d ' ')
    fslmaths "$headtemp" -div "$brainmean" -thr 0.25 -bin -dilD -dilD -dilD -dilD -ero -ero -ero "$headtemp"
    fslmaths "$headtemp" -mul 0 -add 1 -roi 0 -1 0 -1 0 1 0 1 "$botslicetemp"
    fslmaths "$headtemp" -add "$botslicetemp" -bin -fillh -ero "$headtemp"
    wb_command -volume-remove-islands "$headtemp" "$headMask"
    
    echo "Head mask created: $headMask"
}

# Run the function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    createHeadMask "$@"
fi