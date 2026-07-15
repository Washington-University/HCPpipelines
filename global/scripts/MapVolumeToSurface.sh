#!/bin/bash
set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/tempfiles.shlib"

#this function gets called by opts_ParseArguments when --help is specified
function usage()
{
    #header text
    echo "
$log_ToolName: script for the most-common forms of mapping HCP subject data onto surfaces

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
opts_AddMandatory '--input-vol' 'InputVol' 'file' "the volume file to map to surface"
opts_AddMandatory '--hemisphere' 'Hem' 'L or R' "which hemisphere to map to"
opts_AddMandatory '--out-metric' 'OutMetric' 'file' "what file to write the output to"
opts_AddOptional '--vol-mask' 'VolMask' 'file' "a volume ROI specifying which voxels are usable"
opts_AddOptional '--native-dilate' 'NativeDilate' 'number' "dilation distance in mm to fix holes from native mesh triangle size and volume mask, default 10" '10'
opts_AddOptional '--surf-reg-name' 'RegName' 'name' "the registration to use for the output, default MSMAll" 'MSMAll'
opts_AddOptional '--out-resolution' 'OutMesh' 'number' "what standard mesh to use for the output, default 32" '32'
opts_AddOptional '--vol-space' 'VolumeSpace' 'T1w or MNINonLinear' "the volume space the input is in, default MNINonLinear" 'MNINonLinear'
opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

#naming conventions are hidden in here to make it much more convenient to call this script, it is almost a pipeline by itself
whitesurf="$StudyFolder/$Subject/$VolumeSpace/Native/$Subject.$Hem.white.native.surf.gii"
pialsurf="$StudyFolder/$Subject/$VolumeSpace/Native/$Subject.$Hem.pial.native.surf.gii"
midsurf="$StudyFolder/$Subject/$VolumeSpace/Native/$Subject.$Hem.midthickness.native.surf.gii"
#probably slightly more correct to use anatomical space for vertex areas, old code always used MNI
areanativesurf="$StudyFolder/$Subject/T1w/Native/$Subject.$Hem.midthickness.native.surf.gii"

if [[ ! -e "$whitesurf" ]]
then
    log_Err_Abort "please check your paths and volume space settings, '$whitesurf' does not exist"
fi

regstring=""
if [[ "$RegName" == "" ]]
then
    #freesurfer registration, only accessible by specifying something like '--surf-reg-name=""'
    regsphere="$StudyFolder/$Subject/MNINonLinear/Native/$Subject.$Hem.sphere.reg.reg_LR.native.surf.gii"
else
    regsphere="$StudyFolder/$Subject/MNINonLinear/Native/$Subject.$Hem.sphere.$RegName.native.surf.gii"
    regstring="_$RegName"
fi

if [[ ! -e "$regsphere" ]]
then
    log_Err_Abort "please check your surface registration setting, '$regsphere' does not exist"
fi

if [[ "$OutMesh" == "164" ]]
then
    stdsphere="$HCPPIPEDIR/global/templates/standard_mesh_atlases/fsaverage.${Hem}_LR.spherical_std.${OutMesh}k_fs_LR.surf.gii"
    areastdsurf="$StudyFolder/$Subject/T1w/$Subject.$Hem.midthickness$regstring.${OutMesh}k_fs_LR.surf.gii"
else
    stdsphere="$HCPPIPEDIR/global/templates/standard_mesh_atlases/$Hem.sphere.${OutMesh}k_fs_LR.surf.gii"
    areastdsurf="$StudyFolder/$Subject/T1w/fsaverage_LR${OutMesh}k/$Subject.$Hem.midthickness$regstring.${OutMesh}k_fs_LR.surf.gii"
fi

if [[ ! -e "$stdsphere" ]]
then
    log_Err_Abort "please check your output resolution, '$stdsphere' does not exist"
fi

if [[ ! -e "$areastdsurf" ]]
then
    log_Err_Abort "please check your output resolution, '$areastdsurf' does not exist"
fi

nativemapped="$(mktemp --tmpdir XXXXXX.func.gii)"
tempfiles_add "$nativemapped"
nativedilated="$nativemapped.dilate.func.gii"
tempfiles_add "$nativedilated"
badvertices="$nativemapped.badvert.func.gii"
tempfiles_add "$badvertices"

maskargs=()
if [[ "$VolMask" != "" ]]
then
    maskargs=(-volume-roi "$VolMask")
fi

wb_command -volume-to-surface-mapping \
    "$InputVol" \
    "$midsurf" \
    "$nativemapped" \
    -ribbon-constrained \
        "$whitesurf" \
        "$pialsurf" \
        ${maskargs[@]+"${maskargs[@]}"} \
        -thin-columns \
        -bad-vertices-out \
            "$badvertices"

#hidden feature: negative values disable dilation - 0 dilates to neighbors only
if (($(echo "$NativeDilate >= 0" | bc)))
then
    #nearest dilation will have noise characteristics similar to the bordering vertices - weighted would be smoother, but also take somewhat longer
    wb_command -metric-dilate \
        "$nativemapped" \
        "$midsurf" \
        "$NativeDilate" \
        "$nativedilated" \
        -bad-vertex-roi \
            "$badvertices" \
        -nearest
else
    #it doesn't matter if we tempfiles_add a nonexistent file
    nativedilated="$nativemapped"
fi

#for now, don't use freesurfer medial wall, as it can cause issues that would need to be dilated back out

wb_command -metric-resample \
    "$nativedilated" \
    "$regsphere" \
    "$stdsphere" \
    ADAP_BARY_AREA \
    "$OutMetric" \
    -area-surfs \
        "$areanativesurf" \
        "$areastdsurf"

#also skip final medial wall masking, that will happen automatically when put into cifti

