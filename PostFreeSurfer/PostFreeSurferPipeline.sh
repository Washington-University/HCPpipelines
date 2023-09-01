#!/bin/bash
set -eu

# Requirements for this script
#  installed versions of: FSL
#  environment: HCPPIPEDIR, FSLDIR

########################################## PIPELINE OVERVIEW ##########################################

#TODO

########################################## OUTPUT DIRECTORIES ##########################################

#TODO

########################################## ARGUMENT PARSING ##########################################

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/processingmodecheck.shlib" "$@" # Check processing mode requirements

log_Msg "Platform Information Follows: "
uname -a
"$HCPPIPEDIR"/show_version

#this function gets called by opts_ParseArguments when --help is specified
function usage()
{
    #header text
    echo "
$log_ToolName: takes FreeSurfer output folder and converts files into HCP format/organization, etc.

Usage: $log_ToolName PARAMETER...

PARAMETERs are [ ] = optional; < > = user supplied value
"
    #automatic argument descriptions
    opts_ShowArguments
    
    #do not use exit, the parsing code takes care of it
}

defaultSigma=$(echo "sqrt(200)" | bc -l)

#arguments to opts_Add*: switch, variable to set, name for inside of <> in help text, description, [default value if AddOptional], [compatibility flag, ...]
#help info for option gets printed like "--foo=<$3> - $4"

#TSC:should --path or --study-folder be the flag displayed by the usage?
opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects" "--path"
opts_AddMandatory '--subject' 'Subject' 'subject ID' ""
opts_AddMandatory '--surfatlasdir' 'SurfaceAtlasDIR' 'path' "<pipelines>/global/templates/standard_mesh_atlases or equivalent"
opts_AddMandatory '--grayordinatesres' 'GrayordinatesResolutions' 'number' "usually '2', resolution of grayordinates to use"
opts_AddMandatory '--grayordinatesdir' 'GrayordinatesSpaceDIR' 'path' "<pipelines>/global/templates/<num>_Greyordinates or equivalent, for the given --grayordinatesres"
opts_AddMandatory '--hiresmesh' 'HighResMesh' 'number' "usually '164', the standard mesh for T1w-resolution data data"
opts_AddMandatory '--lowresmesh' 'LowResMeshes' 'number' "usually '32', the standard mesh for fMRI data"
opts_AddMandatory '--subcortgraylabels' 'SubcorticalGrayLabels' 'file' "location of FreeSurferSubcorticalLabelTableLut.txt"
opts_AddMandatory '--freesurferlabels' 'FreeSurferLabels' 'file' "location of FreeSurferAllLut.txt"
opts_AddMandatory '--refmyelinmaps' 'ReferenceMyelinMaps' 'file' "group myelin map to use for bias correction"

opts_AddOptional '--mcsigma' 'CorrectionSigma' 'number' "myelin map bias correction sigma, default '$defaultSigma'" "$defaultSigma"
opts_AddOptional '--regname' 'RegName' 'name' "surface registration to use, default 'MSMSulc'" 'MSMSulc'
opts_AddOptional '--inflatescale' 'InflateExtraScale' 'number' "surface inflation scaling factor to deal with different resolutions, default '1'" '1'
opts_AddOptional '--processing-mode' 'ProcessingMode' 'HCPStyleData|LegacyStyleData' "disable some HCP preprocessing requirements to allow processing of data that doesn't meet HCP acquisition guidelines - don't use this if you don't need to" 'HCPStyleData'
opts_AddOptional '--structural-qc' 'QCMode' 'yes|no|only' "whether to run structural QC, default 'yes'" 'yes'
opts_AddOptional '--use-ind-mean' 'UseIndMean' 'YES or NO' "whether to use the mean of the subject's myelin map as reference map's myelin map mean, defaults to 'YES'" 'YES'

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

doProcessing=1
doQC=1

case "$QCMode" in
    (yes)
        ;;
    (no)
        doQC=0
        ;;
    (only)
        doProcessing=0
		log_Warn "Only generating structural QC scene and snapshots from existing data (no other processing)"
        ;;
    (*)
        log_Err_Abort "unrecognized value '$QCMode' for --structural-qc, use 'yes', 'no', or 'only'"
        ;;
esac

#processing code goes here

verbose_red_echo "---> Starting ${log_ToolName}"
verbose_echo " "
verbose_echo " Using environment setting ..."
verbose_echo "          HCPPIPEDIR: ${HCPPIPEDIR}"
verbose_echo " "

log_Check_Env_Var FSLDIR

HCPPIPEDIR_PostFS="$HCPPIPEDIR/PostFreeSurfer/scripts"
PipelineScripts="$HCPPIPEDIR_PostFS"

# ------------------------------------------------------------------------------
#  Naming Conventions
#  Do NOT include spaces in any of these names
# ------------------------------------------------------------------------------
T1wImage="T1w_acpc_dc"
T1wFolder="T1w" #Location of T1w images
T2wFolder="T2w" #Location of T1w images
T2wImage="T2w_acpc_dc"
AtlasSpaceFolder="MNINonLinear"
NativeFolder="Native"
FreeSurferFolder="$Subject"
FreeSurferInput="T1w_acpc_dc_restore_1mm"
AtlasTransform="acpc_dc2standard"
InverseAtlasTransform="standard2acpc_dc"
AtlasSpaceT1wImage="T1w_restore"
AtlasSpaceT2wImage="T2w_restore"
T1wRestoreImage="T1w_acpc_dc_restore"
T2wRestoreImage="T2w_acpc_dc_restore"
OrginalT1wImage="T1w"
OrginalT2wImage="T2w"
T1wImageBrainMask="brainmask_fs"
InitialT1wTransform="acpc.mat"
dcT1wTransform="T1w_dc.nii.gz"
InitialT2wTransform="acpc.mat"
dcT2wTransform="T2w_reg_dc.nii.gz"
FinalT2wTransform="$Subject/mri/transforms/T2wtoT1w.mat"
BiasField="BiasField_acpc_dc"
OutputT1wImage="T1w_acpc_dc"
OutputT1wImageRestore="T1w_acpc_dc_restore"
OutputT1wImageRestoreBrain="T1w_acpc_dc_restore_brain"
OutputMNIT1wImage="T1w"
OutputMNIT1wImageRestore="T1w_restore"
OutputMNIT1wImageRestoreBrain="T1w_restore_brain"
OutputT2wImage="T2w_acpc_dc"
OutputT2wImageRestore="T2w_acpc_dc_restore"
OutputT2wImageRestoreBrain="T2w_acpc_dc_restore_brain"
OutputMNIT2wImage="T2w"
OutputMNIT2wImageRestore="T2w_restore"
OutputMNIT2wImageRestoreBrain="T2w_restore_brain"
OutputOrigT1wToT1w="OrigT1w2T1w.nii.gz"
OutputOrigT1wToStandard="OrigT1w2standard.nii.gz" #File was OrigT2w2standard.nii.gz, regnerate and apply matrix
OutputOrigT2wToT1w="OrigT2w2T1w.nii.gz" #mv OrigT1w2T2w.nii.gz OrigT2w2T1w.nii.gz
OutputOrigT2wToStandard="OrigT2w2standard.nii.gz"
BiasFieldOutput="BiasField"
Jacobian="NonlinearRegJacobians.nii.gz"

T1wFolder="$StudyFolder"/"$Subject"/"$T1wFolder"
T2wFolder="$StudyFolder"/"$Subject"/"$T2wFolder"
AtlasSpaceFolder="$StudyFolder"/"$Subject"/"$AtlasSpaceFolder"
FreeSurferFolder="$T1wFolder"/"$FreeSurferFolder"
AtlasTransform="$AtlasSpaceFolder"/xfms/"$AtlasTransform"
InverseAtlasTransform="$AtlasSpaceFolder"/xfms/"$InverseAtlasTransform"

# ------------------------------------------------------------------------------
#  Compliance check
# ------------------------------------------------------------------------------

Compliance="HCPStyleData"
ComplianceMsg=""

# -- T2w image

if [[ $("$FSLDIR"/bin/imtest "$T2wFolder/T2w") == '0' ]]; then
    ComplianceMsg+=" T2w image not present"
    Compliance="LegacyStyleData"
    T2wRestoreImage="NONE"
fi

if [[ "${RegName}" == "FS" ]]; then
    log_Warn "FreeSurfer's surface registration (based on cortical folding) is deprecated in the"
    log_Warn "  HCP Pipelines as it results in poorer cross-subject functional and cortical areal "
    log_Warn "  alignment relative to MSMSulc. Additionally, FreeSurfer registration results in "
    log_Warn "  dramatically higher surface distortion (both isotropic and anisotropic). These things"
    log_Warn "  occur because FreeSurfer's registration has too little regularization of folding patterns"
    log_Warn "  that are imperfectly correlated with function and cortical areas, resulting in overfitting"
    log_Warn "  of folding patterns. See Robinson et al 2014, 2018 Neuroimage, and Coalson et al 2018 PNAS"
    log_Warn "  for more details."
fi

check_mode_compliance "${ProcessingMode}" "${Compliance}" "${ComplianceMsg}"

# ------------------------------------------------------------------------------
#  Start work
# ------------------------------------------------------------------------------

if ((doProcessing)); then
    log_Msg "Conversion of FreeSurfer Volumes and Surfaces to NIFTI and GIFTI and Create Caret Files and Registration"
    log_Msg "RegName: ${RegName}"

    argList=("$StudyFolder")                # ${1}
    argList+=("$Subject")                   # ${2}
    argList+=("$T1wFolder")                 # ${3}
    argList+=("$AtlasSpaceFolder")          # ${4}
    argList+=("$NativeFolder")              # ${5}
    argList+=("$FreeSurferFolder")          # ${6}
    argList+=("$FreeSurferInput")           # ${7}
    argList+=("$T1wRestoreImage")           # ${8}  Called T1wImage in FreeSurfer2CaretConvertAndRegisterNonlinear.sh
    argList+=("$T2wRestoreImage")           # ${9}  Called T2wImage in FreeSurfer2CaretConvertAndRegisterNonlinear.sh
    argList+=("$SurfaceAtlasDIR")           # ${10}
    argList+=("$HighResMesh")               # ${11}
    argList+=("$LowResMeshes")              # ${12}
    argList+=("$AtlasTransform")            # ${13}
    argList+=("$InverseAtlasTransform")     # ${14}
    argList+=("$AtlasSpaceT1wImage")        # ${15}
    argList+=("$AtlasSpaceT2wImage")        # ${16}
    argList+=("$T1wImageBrainMask")         # ${17}
    argList+=("$FreeSurferLabels")          # ${18}
    argList+=("$GrayordinatesSpaceDIR")     # ${19}
    argList+=("$GrayordinatesResolutions")  # ${20}
    argList+=("$SubcorticalGrayLabels")     # ${21}
    argList+=("$RegName")                   # ${22}
    argList+=("$InflateExtraScale")         # ${23}
    "$PipelineScripts"/FreeSurfer2CaretConvertAndRegisterNonlinear.sh "${argList[@]}"

    log_Msg "Create FreeSurfer ribbon file at full resolution"

    argList=("$StudyFolder")                # ${1}
    argList+=("$Subject")                   # ${2}
    argList+=("$T1wFolder")                 # ${3}
    argList+=("$AtlasSpaceFolder")          # ${4}
    argList+=("$NativeFolder")              # ${5}
    argList+=("$AtlasSpaceT1wImage")        # ${6}
    argList+=("$T1wRestoreImage")           # ${7}  Called T1wImage in CreateRibbon.sh
    argList+=("$FreeSurferLabels")          # ${8}
    "$PipelineScripts"/CreateRibbon.sh "${argList[@]}"

    log_Msg "Myelin Mapping"
    log_Msg "RegName: ${RegName}"

    argList=("$StudyFolder")                # ${1}
    argList+=("$Subject")
    argList+=("$AtlasSpaceFolder")
    argList+=("$NativeFolder")
    argList+=("$T1wFolder")                 # ${5}
    argList+=("$HighResMesh")
    argList+=("$LowResMeshes")
    argList+=("$T1wFolder"/"$OrginalT1wImage")
    argList+=("$T2wFolder"/"$OrginalT2wImage")
    argList+=("$T1wFolder"/"$T1wImageBrainMask")           # ${10}
    argList+=("$T1wFolder"/xfms/"$InitialT1wTransform")
    argList+=("$T1wFolder"/xfms/"$dcT1wTransform")
    argList+=("$T2wFolder"/xfms/"$InitialT2wTransform")
    argList+=("$T1wFolder"/xfms/"$dcT2wTransform")
    argList+=("$T1wFolder"/"$FinalT2wTransform")           # ${15}
    argList+=("$AtlasTransform")
    argList+=("$T1wFolder"/"$BiasField")
    argList+=("$T1wFolder"/"$OutputT1wImage")
    argList+=("$T1wFolder"/"$OutputT1wImageRestore")
    argList+=("$T1wFolder"/"$OutputT1wImageRestoreBrain")  # ${20}
    argList+=("$AtlasSpaceFolder"/"$OutputMNIT1wImage")
    argList+=("$AtlasSpaceFolder"/"$OutputMNIT1wImageRestore")
    argList+=("$AtlasSpaceFolder"/"$OutputMNIT1wImageRestoreBrain")
    argList+=("$T1wFolder"/"$OutputT2wImage")
    argList+=("$T1wFolder"/"$OutputT2wImageRestore")       # ${25}
    argList+=("$T1wFolder"/"$OutputT2wImageRestoreBrain")
    argList+=("$AtlasSpaceFolder"/"$OutputMNIT2wImage")
    argList+=("$AtlasSpaceFolder"/"$OutputMNIT2wImageRestore")
    argList+=("$AtlasSpaceFolder"/"$OutputMNIT2wImageRestoreBrain")
    argList+=("$T1wFolder"/xfms/"$OutputOrigT1wToT1w")     # {30}
    argList+=("$T1wFolder"/xfms/"$OutputOrigT1wToStandard")
    argList+=("$T1wFolder"/xfms/"$OutputOrigT2wToT1w")
    argList+=("$T1wFolder"/xfms/"$OutputOrigT2wToStandard")
    argList+=("$AtlasSpaceFolder"/"$BiasFieldOutput")
    argList+=("$AtlasSpaceFolder"/"$T1wImageBrainMask")    # {35}  Called T1wMNIImageBrainMask in CreateMyelinMaps.sh
    argList+=("$AtlasSpaceFolder"/xfms/"$Jacobian")
    argList+=("$ReferenceMyelinMaps")
    argList+=("$CorrectionSigma")
    argList+=("$RegName")                                  # ${39}
    argList+=("$UseIndMean")
    "$PipelineScripts"/CreateMyelinMaps.sh "${argList[@]}"
fi

if ((doQC)); then
	log_Msg "Generating structural QC scene and snapshots"
    "$PipelineScripts"/GenerateStructuralScenes.sh \
        --study-folder="$StudyFolder" \
        --subject="$Subject" \
        --output-folder="$AtlasSpaceFolder/StructuralQC"
fi

verbose_green_echo "---> Finished ${log_ToolName}"
verbose_echo " "

log_Msg "Completed!"

