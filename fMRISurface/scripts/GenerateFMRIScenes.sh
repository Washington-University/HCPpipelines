#!/bin/bash
set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
    pipedirguessed=1
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/relativePath.shlib" "$@"

#this function gets called by opts_ParseArguments when --help is specified
function usage()
{
    #header text
    echo "
$log_ToolName: makes QC scenes and captures for HCP fMRIVolume pipeline

Usage: $log_ToolName PARAMETER...

PARAMETERs are [ ] = optional; < > = user supplied value
"
    #automatic argument descriptions
    opts_ShowArguments
    
    #do not use exit, the parsing code takes care of it
}

#arguments to opts_Add*: switch, variable to set, name for inside of <> in help text, description, [default value if AddOptional], [compatibility flag, ...]
#help info for option gets printed like "--foo=<$3> - $4"
opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject' 'Subject' 'subject ID' ""
opts_AddMandatory '--fmriname' 'fMRIName' 'fMRI run name' ""
opts_AddMandatory '--output-folder' 'OutputSceneFolder' 'path' "output location for QC scene and snapshots"

opts_AddOptional '--verbose' 'verboseArg' 'true|false' "whether to output more messages, default 'false'" 'false'

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

#processing code goes here

### --------------------------------------------- ###
### Set Defaults
### --------------------------------------------- ###

TemplatesFolder="$HCPPIPEDIR/global/templates/fMRIQC"

verbose=$(opts_StringToBool "$verboseArg")

### --------------------------------------------- ###
### From here onward should not need any modification

mkdir -p "$OutputSceneFolder"

# Convert TemplatesFolder, StudyFolder, and OutputSceneFolder to absolute paths (for convenience in reporting locations).
TemplatesFolder=$(cd "$TemplatesFolder"; pwd)
StudyFolder=$(cd "$StudyFolder"; pwd)
OutputSceneFolder=$(cd "$OutputSceneFolder"; pwd)

# ----------------------------
# Define variables containing the "dummy strings" used in the template scene
# ----------------------------

# The following are matched to actual strings in the TEMPLATE_fMRIQC.scene file
StudyFolderDummyStr="STUDYDIR"
SubjectIDDummyStr="SESSION"
fMRINameDummyStr="FMRINAME"

# ----------------------------
# Begin main action of script
# ----------------------------

scriptDir=$(pwd)

mkdir -p "$OutputSceneFolder"
relPathToStudy=$(relativePath "$OutputSceneFolder" "$StudyFolder")
if ((verbose)); then
   echo "TemplatesFolder: $TemplatesFolder"
   echo "StudyFolder: $StudyFolder"
   echo "OutputSceneFolder: $OutputSceneFolder"
   echo "... relative path to StudyFolder (from OutputSceneFolder): $relPathToStudy"
fi

# Replace dummy strings in the template scenes to generate
# a scene file appropriate for each subject and fMRI run
sceneFile="${Subject}_${fMRIName}.fMRIQC.wb_scene"  # No path (file name only)
sed -e "s|${StudyFolderDummyStr}|${relPathToStudy}|g" \
    -e "s|${SubjectIDDummyStr}|${Subject}|g" \
    -e "s|${fMRINameDummyStr}|${fMRIName}|g" \
    "$TemplatesFolder"/TEMPLATE_fMRIQC.scene > "$OutputSceneFolder/$sceneFile"

# Generate snapshots
pngDir="$OutputSceneFolder/snapshots"
mkdir -p "${pngDir}"
#numScenes=$(grep "SceneInfo Index" "$OutputSceneFolder/$sceneFile" | wc -l)
#for ((ind = 1; ind <= numScenes; ind++)); do
scenesToCapture="1 2"
for ind in $scenesToCapture; do
    wb_command -show-scene "$OutputSceneFolder/$sceneFile" $ind "${pngDir}/${sceneFile}${ind}.png" 1400 600 -logging OFF
done

log_Msg "fMRI QC scene generation completed"
