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
source "$HCPPIPEDIR/global/scripts/tempfiles.shlib" "$@"

opts_SetScriptDescription "Use freesurfer's bbregister to do rigid alignment of a volume to anatomical surfaces"

opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "pipelines' subjects folder"
opts_AddMandatory '--subject' 'Subject' 'subject ID' "(e.g. 100610)"
opts_AddOptional '--freesurfer-folder' 'fssubjectsdir' 'path' "freesurfer's subjects folder, if different than the T1w folder of the HCP subject folder"
opts_AddMandatory '--input-image' 'inputimage' 'file' "file to register"
opts_AddMandatory '--init-target-image' 'flirttarget' 'file' "target image for flirt preregistration and rigid-aligned reference space"
opts_AddMandatory '--bbregister-regfile-out' 'bbroutprefix' 'file' "what name to use for the output, log, mincost, etc files of bbregister (used as the --reg option), must end in '.dat'"
opts_AddOptional '--init-xfm' 'initxfm' 'file' "precomputed initial alignment, instead of using flirt"
opts_AddOptional '--rerun-threshold' 'rerunthresh' 'number' "if using --init-xfm and the bbr mincost is greater than this number, rerun with flirt preregistration instead"
opts_AddOptional '--old-receive-bias' 'oldreceive' 'file' "divide out this bias field after flirt prealignment, but before BBR"
opts_AddMandatory '--contrast-type' 'contrast' 'T1w or T2w' "contrast type of the image"
opts_AddMandatory '--surface-name' 'surfname' 'string' "what freesurfer surface to use for alignment, usually pial.deformed or white.deformed depending on which boundary has more contrast in --input-image"
#sanity checking in this script may be suitable as a replacement for including all the bbr spam - freesurfer doesn't seem to use stderr for error reporting, unfortunately
opts_AddOptional '--bbr-hide-stdout' 'hideBBRstdoutSTR' 'TRUE or FALSE' "whether to silence bbregister's stdout, default TRUE" 'TRUE'

#outputs
opts_AddMandatory '--output-xfm' 'finalxfm' 'file' "the final bbr rigid alignment"
opts_AddOptional '--output-inverse-xfm' 'invxfm' 'file' "the inverse of the output alignment"
opts_AddOptional '--output-image' 'resampledimage' 'file' "the file resampled to the new alignment (using the input dims/spacing)"

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

hideBBRstdout=$(opts_StringToBool "$hideBBRstdoutSTR")

if [[ "$bbroutprefix" != *.dat ]]
then
    log_Err_Abort "--bbregister-output value doesn't end in '.dat'"
fi

case "$contrast" in
    (T1w)
        #note: bbregister actually says --t1, but our existing code used capitals, so...
        bbrargs=(--T1)
        ;;
    (T2w)
        bbrargs=(--T2)
        ;;
    (*)
        log_Err_Abort "'$contrast' is not a recognized value for --contrast, please use 'T1w' or 'T2w'"
        ;;
esac

T1wFolder="$StudyFolder/$Subject/T1w"

if [[ "$fssubjectsdir" == "" ]]
then
    fssubjectsdir="$T1wFolder"
fi

if [[ ! -d "$fssubjectsdir"/"$Subject" ]]
then
    log_Err_Abort "freesurfer directory for subject not found at $fssubjectsdir/$Subject"
fi

if [[ -d "$fssubjectsdir"/"$Subject"_1mm ]]
then
    log_Err_Abort "NHP ${Subject}_1mm folder detected, not currently supported in bbregister.sh"
fi

#deal with timeseries input
tempfiles_create bbregister_tempmean_XXXXXX.nii.gz tempmean
fslmaths "$inputimage" -Tmean "$tempmean"
#input may have weird headers
#flirt -usesqform seems to do nothing, reorient the image
#NOTE: this means the output transform (fsl convention) has to be converted back to the original input header (see below)
tempfiles_add "$tempmean"_reorient.nii.gz
wb_command -volume-reorient "$tempmean" RPI "$tempmean"_reorient.nii.gz

#we may do this twice when there is a mincost threshold, so use a function
function initAndBBR()
{
    local image="$1"
    local xfm="$2"
    local initxfmout="$3"
    local bbrout="$4"
    
    local flirttemp
    tempfiles_create flirtout_XXXXXX.nii.gz flirttemp
    tempfiles_add "$flirttemp"2str_init.nii.gz
    
    if [[ "$xfm" == "" ]]
    then
        tempfiles_add "$flirttemp"2str_init.mat
        #NOTE: flirttarget comes from outside the function
        flirt -dof 6 -in "$image" -ref "$flirttarget" -init "$xfm" -omat "$initxfmout"
    else
        cp "$xfm" "$initxfmout"
    fi
    local bbrinput="$flirttemp"2str_init.nii.gz
    wb_command -volume-resample "$image" "$flirttarget" CUBIC "$bbrinput" \
        -affine "$initxfmout" \
            -flirt "$image" "$flirttarget"
    
    #NOTE: oldreceive comes from outside the function
    if [[ "$oldreceive" != "" ]]
    then
        tempfiles_create bbrinit_biascorr_XXXXXX.nii.gz bbrinput
        wb_command -volume-math 'image / bias' "$bbrinput" -var image "$flirttemp"2str_init.nii.gz -var bias "$oldreceive"
    fi
    
    #this export will expire when the script ends, so don't bother with unset or subshell
    #NOTE: fssubjectsdir comes from outside the function
    export SUBJECTS_DIR="$fssubjectsdir"

    # Use "hidden" bbregister DOF options (--6 (default), --9, or --12 are supported)
    #NOTE: Subject, surfname, fssubjectsdir, bbrargs come from outside the function
    #TSC: don't need the --o output image, we will generate it with 1 resample if requested
    bbrcmd=("$FREESURFER_HOME"/bin/bbregister --s "$Subject" --mov "$bbrinput" --surf "$surfname" --init-reg "$fssubjectsdir"/"$Subject"/mri/transforms/eye.dat "${bbrargs[@]}" --reg "$bbrout" --6)
    echo "running ${bbrcmd[*]}"
    if ((hideBBRstdout))
    then
        log_Msg "discarding bbregister stdout, check ${bbrout}.log for details"
        "${bbrcmd[@]}" > /dev/null
    else
        "${bbrcmd[@]}"
    fi
    log_Msg "bbregister mincost result: $(cat "$bbrout".mincost | cut -d " " -f 1)"
}

whichbbr="$bbroutprefix"

tempfiles_create bbrxfm_XXXXXX.dat bbrtemp
tempfiles_add "$bbrtemp"_init.mat "$bbrtemp".mat
initAndBBR "$tempmean"_reorient.nii.gz "$initxfm" "$bbrtemp"_init.mat "$bbroutprefix"

#don't do a rerun when we already used flirt the first time
if [[ "$rerunthresh" != "" && "$initxfm" != "" ]]
then
    mincost=$(cat "$bbroutprefix".mincost | cut -d " " -f 1)
    if [[ "$(echo "$mincost > $rerunthresh" | bc)" == "1" ]]
    then
        #rerun with flirt instead of the initialization matrix
        log_Msg "bbregister with provided initialization matrix did not pass threshold, rerunning bbregister with flirt initialization..."
        #separate the rerun output
        initAndBBR "$tempmean"_reorient.nii.gz "" "$bbrtemp"_init.mat "$bbroutprefix"_rerun.dat
        #DISCUSS: could check if mincost was improved, and if not, keep the first one
        whichbbr="$bbroutprefix"_rerun.dat
    fi
fi

#this is T1w/T1w_acpc_dc (not the flirt target) because that is what the surfaces align with, and makes it simpler to use the output xfm
"$FREESURFER_HOME"/bin/tkregister2 --noedit --reg "$whichbbr" --mov "$flirttarget" --targ "$T1wFolder"/T1w_acpc_dc.nii.gz --fslregout "$bbrtemp".mat

tempfiles_create bbregister_reorientmat_XXXXXX.mat reorientfinal

convert_xfm -omat "$reorientfinal" -concat "$bbrtemp".mat "$bbrtemp"_init.mat
#undo the effects of our flirt-appeasing reorient on the affine
wb_command -convert-affine -from-flirt "$reorientfinal" "$tempmean"_reorient.nii.gz "$T1wFolder"/T1w_acpc_dc.nii.gz \
    -to-flirt "$finalxfm" "$inputimage" "$T1wFolder"/T1w_acpc_dc.nii.gz

if [[ "$invxfm" != "" ]]
then
    convert_xfm -omat "$invxfm" -inverse "$finalxfm"
fi
if [[ "$resampledimage" != "" ]]
then
    #use target image for output FoV, because that is what we are now aligned to (and is a mandatory parameter, even with an initial xfm)
    #don't apply bias field, that is just to help freesurfer make the right call
    wb_command -volume-resample "$inputimage" "$flirttarget" CUBIC "$resampledimage" \
        -affine "$finalxfm" \
            -flirt "$inputimage" "$T1wFolder"/T1w_acpc_dc.nii.gz
fi

