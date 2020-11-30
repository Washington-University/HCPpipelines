#!/bin/bash
set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"

#this function gets called by opts_ParseArguments when --help is specified
function usage()
{
    #header text
    echo "
$log_ToolName: makes QC scenes and captures for HCP FreeSurfer pipelines

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
opts_AddMandatory '--output-folder' 'OutputSceneFolder' 'path' "output location for QC scene, etc"

opts_AddOptional '--copy-templates' 'TemplatesMethod' 'no|links|files' "how to add the template files to the output directory, default 'files'" 'files'
opts_AddOptional '--verbose' 'verboseArg' 'true|false' "whether to output more messages, default 'false'" 'false'

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

#processing code goes here

## Generating Workbench Scenes for Structural Quality Control
##
## Authors: Michael Harms, Michael Hodge, Donna Dierker, and Tim Coalson
##
## ----------------------------------------------------------

#set -x  # If you want a verbose listing of all the commands, uncomment this line


### --------------------------------------------- ###
### Set Defaults
### --------------------------------------------- ###

TemplatesFolder="$HCPPIPEDIR/PostFreeSurfer/scripts/QC_templates"

# Some of the scenes display files in $TemplatesFolder (specifically, the MNI152 
# volume template and group myelin maps from the S1200 release of HCP-YA).
# The following variable controls whether those files get copied from $TemplatesFolder
# to $OutputSceneFolder (use 'TRUE') or not (use 'FALSE', in which case the script determines
# the relative path to the $TemplatesFolder, and uses that in creating the scene).
# N.B. If you use 'TRUE', and $OutputSceneFolder is empty (""), then you'll be creating a
# copy of the template files for each individual subject.
#CopyTemplates=FALSE

# If $CopyTemplates is TRUE, you may want to copy the files as symlinks rather than making copies of the files.
# If $CopyTemplatesAs is set to "SYMLINKS", the templates will be copied as symlinks.
# Otherwise if $CopyTemplatesAs is set to "FILES" or any other value, the templates will be copied as files.
#CopyTemplatesAs=FILES

#TSC: these are now controlled by the --copy-templates option
#note that the templates folder is inside the pipelines scripts folder, so will often be a different filesystem/mountpoint than the data
#thus, copy as files is the most bulletproof default, though it uses more disk space

case "$TemplatesMethod" in
    (no)
        CopyTemplates=FALSE
        CopyTemplatesAs=FILES
        ;;
    (links)
        CopyTemplates=TRUE
        CopyTemplatesAs=SYMLINKS
        ;;
    (files)
        CopyTemplates=TRUE
        CopyTemplatesAs=FILES
        ;;
    (*)
        log_Err_Abort "unrecognized value '$TemplatesMethod' for --copy-templates"
        ;;
esac

#sanity checks
if ! [[ "$CopyTemplates" =~ ^(TRUE|FALSE)$ ]]; then
    log_Err_Abort "internal error: Invalid value '$CopyTemplates' for CopyTemplates parameter"
fi

if ! [[ "$CopyTemplatesAs" =~ ^(SYMLINKS|FILES)$ ]]; then
    log_Err_Abort "internal error: Invalid value '$CopyTemplatesAs' for CopyTemplatesAs parameter"
fi

verbose=$(opts_StringToBool "$verboseArg")

### --------------------------------------------- ###
### From here onward should not need any modification

mkdir -p "$OutputSceneFolder"

# Convert TemplatesFolder and StudyFolder to absolute paths (for convenience in reporting locations).
TemplatesFolder=$(cd "$TemplatesFolder"; pwd)
StudyFolder=$(cd "$StudyFolder"; pwd)
OutputSceneFolder=$(cd "$OutputSceneFolder"; pwd)

# ----------------------------
# Function to copy just the specific files in 'templates' that are needed
# ----------------------------
function copyTemplateFiles {
    local templateDir=$1
    local targetDir=$2

    # Remove any pre-existing template files
    rm -f "$targetDir"/S1200.{MyelinMap,sulc}* 
    rm -f "$targetDir"/MNI152_T1_0.8mm.nii.gz
    
    if [[ "$CopyTemplatesAs" != "SYMLINKS" ]]; then
        if ((verbose)); then
            echo "Copying template files to $targetDir as files"
        fi
        cp "$templateDir"/S1200.{MyelinMap,sulc}* "$targetDir"/.
        cp "$templateDir"/MNI152_T1_0.8mm.nii.gz "$targetDir"/.
    else
        if ((verbose)); then
            echo "Copying template files to $targetDir as symlinks"
        fi
        for FIL in $(find "$templateDir" -regextype posix-extended -regex  '^.*(MNI152|S1200.*(MyelinMap|sulc)).*$'); do
            FN=$(basename "$FIL")
            ln -s "$FIL" "$targetDir/$FN"
            #TSC: all paths should always be absolute now, and readlink -f doesn't do the same thing on mac (and takes an extra argument)
        done
    fi
}

# ----------------------------
# Function to determine relative paths
# ----------------------------

# We want to use relative paths in the scene file, so that it is robust
# against changes in the base directory path.  As long as the relative
# paths between $OutputSceneFolder, $TemplatesFolder, and $StudyFolder are
# preserved, the scene should still work, even if the base directory changes
# (i.e., if the files are moved, or accessed via a different mount point).

# To determine the relative paths, 'realpath --relative-to' is not a robust
# solution, as 'realpath' is not present by default on MacOS, and the 
# '--relative-to' option is not supported on older Ubuntu versions.
# So, use the following perl one-liner instead, 
# from https://stackoverflow.com/a/17110582

function relativePath {
    # both $1 and $2 are absolute paths beginning with /
    # returns relative path from $1 to $2
    local source=$(cd "$1"; pwd)
    local target=$(cd "$2"; pwd)
    perl -e 'use File::Spec; print File::Spec->abs2rel(@ARGV) . "\n"' "$target" "$source"
}

# ----------------------------
# Define variables containing the "dummy strings" used in the template scene
# ----------------------------

# The following are matched to actual strings in the TEMPLATE_structuralQC.scene file
StudyFolderDummyStr="StudyFolder"
SubjectIDDummyStr="SubjectID"
TemplatesFolderDummyStr="TemplatesFolder"

# ----------------------------
# Begin main action of script
# ----------------------------

scriptDir=$(pwd)

OutputSceneFolderSubj=$OutputSceneFolder
mkdir -p $OutputSceneFolderSubj
relPathToStudy=$(relativePath $OutputSceneFolderSubj $StudyFolder)
if [ "$CopyTemplates" = "TRUE" ]; then
   copyTemplateFiles $TemplatesFolder $OutputSceneFolderSubj
   relPathToTemplates="."
else
   relPathToTemplates=$(relativePath $OutputSceneFolderSubj $TemplatesFolder)
fi
if ((verbose)); then
   echo "TemplatesFolder: $TemplatesFolder"
   echo "StudyFolder: $StudyFolder"
   echo "OutputSceneFolder: $(cd $OutputSceneFolderSubj; pwd)"
   echo "... relative path to template files (from OutputSceneFolder): $relPathToTemplates"
   echo "... relative path to StudyFolder (from OutputSceneFolder): $relPathToStudy"
fi

# Define some convenience variables
AtlasSpaceFolder="$StudyFolder/$Subject/MNINonLinear"
mesh="164k_fs_LR"

if [[ -d "$AtlasSpaceFolder/xfms" ]]; then
    if ((verbose)); then
        echo "Subject folder appears to be okay."
    fi
else
    log_Err_Abort "ERROR:  Subject folder missing expected directory MNINonLinear/xfms"
fi

# Replace dummy strings in the template scenes to generate
# a scene file appropriate for each subject
SubjectSceneFile="$OutputSceneFolder/$Subject.structuralQC.wb_scene"
sed -e "s|${StudyFolderDummyStr}|${relPathToStudy}|g" \
    -e "s|${SubjectIDDummyStr}|${Subject}|g" \
    -e "s|${TemplatesFolderDummyStr}|${relPathToTemplates}|g" \
    "$TemplatesFolder"/TEMPLATE_structuralQC.scene > "$SubjectSceneFile"

# If StrainJ maps don't exist for the various registrations, 
# but ArealDistortion maps do, use those instead
for regName in FS MSMSulc MSMAll; do
    if [[ ! -e "$AtlasSpaceFolder/$Subject.StrainJ_$regName.$mesh.dscalar.nii" && -e "$AtlasSpaceFolder/$Subject.ArealDistortion_$regName.$mesh.dscalar.nii" ]]; then
        echo "... using ArealDistortion_${regName} map in place of StrainJ_${regName}"
        # Following version of sed "in-place" replacement should work on both Linux and MacOS
        sed -i.bak "s|StrainJ_${regName}|ArealDistortion_${regName}|g" "$SubjectSceneFile"
        rm -f "$SubjectSceneFile.bak"
    fi
done

## Map the T1w_acpc space volume into MNI152 space, using just the affine (linear) component
## [Similar to the 'MNINonLinear/xfms/T1w_acpc_dc_restore_brain_to_MNILinear.nii.gz' volume
## (created in AtlasRegistrationToMNI152_FLIRTandFNIRT.sh) 
## except applied to the NON-brain-extracted volume].
acpc2MNILinear="$AtlasSpaceFolder/xfms/acpc2MNILinear.mat"
if [[ -e "$acpc2MNILinear" ]]; then
    nativeVol=T1w_acpc_dc_restore
    volumeIn="$AtlasSpaceFolder/../T1w/$nativeVol.nii.gz"
    volumeRef="$AtlasSpaceFolder/T1w_restore.nii.gz"
    volumeOut="$OutputSceneFolder/$Subject.${nativeVol}_to_MNILinear.nii.gz"
    # Use -volume-affine-resample, rather than flirt, for resampling, to avoid adding need for FSL
    wb_command -volume-affine-resample \
        "$volumeIn" "$acpc2MNILinear" "$volumeRef" CUBIC "$volumeOut" \
        -flirt "$volumeIn" "$volumeRef"
fi

## Create a surface-mapped version of the FNIRT volume distortion (for easy visualization).
## We could use wb_command -volume-distortion on MNINonLinear/xfms/acpc_dc2standard.nii.gz, 
## but its "isotropic" distortion (1st volume) is basically the same as the -jout (Jacobian) 
## output of fnirt (highly correlated, but there is a small bias between the two, perhaps
## because the fnirt jacobian doesn't include the affine component)?
## So, since the fnirt jacobian is already part of the HCPpipelines output, we'll
## use that for convenience

# Convert FNIRT's Jacobian to log base 2
jacobian="$AtlasSpaceFolder/xfms/NonlinearRegJacobians.nii.gz"
jacobianLog2="$OutputSceneFolder/$Subject.NonlinearRegJacobians_log2.nii.gz"
wb_command -volume-math "ln(x)/ln(2)" "$jacobianLog2" -var x "$jacobian"

# Set palette properties
#NOTE: thresholds are only being used on the volume file
paletteArgs=(-pos-user 0 2 -neg-user 0 -2 -palette-name "ROY-BIG-BL"
             -interpolate true -disp-pos true -disp-neg true -disp-zero false)
thresholdArgs=(-thresholding THRESHOLD_TYPE_NORMAL THRESHOLD_TEST_SHOW_OUTSIDE -1 1)
wb_command -volume-palette "$jacobianLog2" MODE_USER_SCALE \
    "${paletteArgs[@]}" \
    "${thresholdArgs[@]}"

# Map to surface
mapName=NonlinearRegJacobians_FNIRT
for hemi in L R; do 
    surf=$AtlasSpaceFolder/$Subject.$hemi.midthickness.$mesh.surf.gii
    # Warpfields are smooth enough that trilinear interpolation is fine in -volume-to-surface-mapping
    wb_command -volume-to-surface-mapping $jacobianLog2 "$surf" \
        "$OutputSceneFolder/$Subject.$mapName.$hemi.$mesh.func.gii" -trilinear
done

# Convert to dscalar and set palette properties
wb_command -cifti-create-dense-scalar "$OutputSceneFolder/$Subject.$mapName.$mesh.dscalar.nii" \
  -left-metric "$OutputSceneFolder/$Subject.$mapName.L.$mesh.func.gii" \
  -right-metric "$OutputSceneFolder/$Subject.$mapName.R.$mesh.func.gii"
wb_command -set-map-names "$OutputSceneFolder/$Subject.$mapName.$mesh.dscalar.nii" -map 1 "${Subject}_$mapName"
wb_command -cifti-palette "$OutputSceneFolder/$Subject.$mapName.$mesh.dscalar.nii" MODE_USER_SCALE \
  "$OutputSceneFolder/$Subject.$mapName.$mesh.dscalar.nii" \
  "${paletteArgs[@]}"

pngDir="$OutputSceneFolder/snapshots"
mkdir -p "${pngDir}"
sceneFile="${Subject}.structuralQC.wb_scene"
numScenes=$(grep "SceneInfo Index" "$OutputSceneFolder/$sceneFile" | wc -l)
for ((ind = 1; ind <= numScenes; ind++)); do
    wb_command -show-scene "$OutputSceneFolder/$sceneFile" $ind "${pngDir}/${sceneFile}${ind}.png" 100 100 -use-window-size
done

# Cleanup
rm "$OutputSceneFolder/$Subject.$mapName."{L,R}".$mesh.func.gii"

