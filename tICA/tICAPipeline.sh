#!/bin/bash
set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/tempfiles.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/parallel.shlib" "$@"
#FIXME: no compiled matlab support
g_matlab_default_mode=1
#add steps to this array and in the switch cases below
pipelineSteps=(MIGP GroupSICA indProjSICA ConcatGroupSICA ComputeGroupTICA indProjTICA ComputeTICAFeatures ClassifyTICA CleanData)
defaultStart="${pipelineSteps[0]}"
defaultStopAfter="${pipelineSteps[${#pipelineSteps[@]} - 1]}"
stepsText="$(IFS=$'\n'; echo "${pipelineSteps[*]}")"

#this function gets called by opts_ParseArguments when --help is specified
function usage()
{
    #header text
    echo "
$log_ToolName: does stuff

Usage: $log_ToolName PARAMETER...

PARAMETERs are [ ] = optional; < > = user supplied value
"
    #automatic argument descriptions
    opts_ShowArguments
    
    #do not use exit, the parsing code takes care of it
}

#arguments to opts_Add*: switch, variable to set, name for inside of <> in help text, description, [default value if AddOptional], [compatibility flag, ...]
#help info for option gets printed like "--foo=<$3> - $4"
#general inputs
opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder that contains all subjects"
opts_AddMandatory '--subject-list' 'SubjlistRaw' '100206@100307...' "list of subject IDs separated by @s"
opts_AddMandatory '--fmri-names' 'fMRINames' 'rfMRI_REST1_LR@rfMRI_REST1_RL...' "list of fmri run names separated by @s" #Needs to be the single fMRI run names only (for DVARS and GS code) for MR+FIX, is also the SR+FIX input names
opts_AddOptional '--mrfix-concat-name' 'MRFixConcatName' 'rfMRI_REST' "if multi-run FIX was used, you must specify the concat name with this option"
opts_AddMandatory '--output-fmri-name' 'OutputfMRIName' 'rfMRI_REST' "name to use for tICA pipeline outputs"
opts_AddMandatory '--proc-string' 'fMRIProcSTRING' 'string' "file name component representing the preprocessing already done, e.g. '_Atlas_MSMAll_hp0_clean'"
opts_AddMandatory '--melodic-high-pass' 'HighPass' 'integer' 'the high pass value that was used when running FIX'
opts_AddMandatory '--out-group-name' 'GroupAverageName' 'string' 'name to use for the group output folder'
opts_AddMandatory '--fmri-resolution' 'fMRIResolution' 'string' "resolution of data, like '2' or '1.60' "
#TSC: doesn't default to MSMAll because we don't have that default string in the MSMAll pipeline
opts_AddMandatory '--surf-reg-name' 'RegName' 'MSMAll' "the registration string corresponding to the input files"
#opts_AddOptional '--tica-mode' 'tICAmode' 'ESTIMATE, INITIALIZE, USE' "defaults to ESTIMATE, all other modes require specifying the --precomputed-* options
#ESTIMATE estimates a new tICA mixing matrix
#INITIALIZE initializes an estimation with a previously computed mixing matrix with matching sICA components
#USE just applies a previously computed mixing matrix with matching sICA components" "ESTIMATE"
#NEW, REUSE_SICA_ONLY, INITIALIZE_TICA, or REUSE_TICA
opts_AddOptional '--ica-mode' 'ICAmode' 'string' "whether to use parts of a previous tICA run (for instance, if this group has too few subjects to simply estimate a new tICA).  Defaults to NEW, all other modes require specifying the --precomputed-* options.  Value must be one of:
NEW - estimate a new sICA and a new tICA
REUSE_SICA_ONLY - reuse an existing sICA and estimate a new tICA
INITIALIZE_TICA - reuse an existing sICA and use an existing tICA to start the estimation
REUSE_TICA - reuse an existing sICA and an existing tICA" \
    'NEW'
#MFG: I see why this should be a folder, as there are the main sICA, the lowres dims, and the iq that must be handled.
#TODO: What folder level is this?  MIGP level (containing the sICA folder and tICA folder) or tICA folder level
#TSC: this is the output group folder, one above MNINonLinear
#TODO: is "precomputed" a good name for these?
opts_AddOptional '--precomputed-clean-folder' 'precomputeTICAFolder' 'folder' "group folder containing an existing tICA cleanup to make use of for USE or INITIALIZE modes"
#TODO: I don't understand the need for precomputeTICAfMRIName and all the places it is used.
#TSC: the precomputed sica/tica will use one fmriname, but the new data will probably use a different fmriname.  this argument is for the fmriname of the precomputed data
opts_AddOptional '--precomputed-clean-fmri-name' 'precomputeTICAfMRIName' 'rfMRI_REST' "the output fMRI name used in the previously computed tICA"
opts_AddOptional '--precomputed-group-name' 'precomputeGroupName' 'PrecomputedGroupName' "the group name used during the previously computed tICA"
opts_AddOptional '--extra-output-suffix' 'extraSuffix' 'string' "add something extra to most output filenames, for collision avoidance"

#MIGP
opts_AddOptional '--pca-out-dim' 'PCAOutputDim' 'integer' 'override number of PCA components to use for group sICA' #defaults to subjectExpectedTimepoints
opts_AddOptional '--pca-internal-dim' 'PCAInternalDim' 'integer' 'override internal MIGP dimensionality'
opts_AddOptional '--migp-resume' 'migpResume' 'YES or NO' 'resume from a previous interrupted MIGP run, if present, default YES' 'YES'

#sICA
opts_AddMandatory '--num-wishart' 'numWisharts' 'integer' "how many wisharts to use in icaDim" #FIXME - We will need to think about how to help users set this.  Ideally it is established by running a null model, but that is timeconsuming. Valid values for humans have been WF5 or WF6.
opts_AddOptional '--sicadim-iters' 'sicadimIters' 'integer' "number of iterations or mode for estimating sICA dimensionality, default 100" '100'
opts_AddOptional '--sicadim-override' 'sicadimOverride' 'integer' "use this dimensionality instead of icaDim's estimate"

#sICA individual projection
opts_AddMandatory '--low-res' 'LowResMesh' 'meshnum' "mesh resolution, like '32' for 32k_fs_LR"
opts_AddOptional '--low-sica-dims' 'LowsICADims' 'num@num@num...' "the low sICA dimensionalities to use for determining weighting for individual projection, defaults to '7@8@9@10@11@12@13@14@15@16@17@18@19@20@21'" '7@8@9@10@11@12@13@14@15@16@17@18@19@20@21'
opts_AddMandatory '--subject-expected-timepoints' 'subjectExpectedTimepoints' 'string' "output spectra size for sICA individual projection, RunsXNumTimePoints, like '4800'" #WONTFIX: Problem: reliably detecting a complete subject could be troublesome, leave it as mandatory for now. #TODO: This could be defaulted to the sum of the timepoints across all runs [in a complete subject] with the option to modify it and be optional.

#sICA concatenation
#uses hardcoded conventions

#tICA
#TODO: sanity check that tICADim (when specified) is not higher than sICADim (once it is known)
#FIXME: ComputeGroupTICA.m hardcodes "tICAdim = sICAdim;", line 76
#TSC: remove option until ComputeGroupTICA.m allows different dimensionalities
#opts_AddOptional '--tica-dim' 'tICADim' 'integer' "override the default of tICA dimensionality = sICA dimensionality. Must be less than or equal to sICA dimensionality"
tICADim=""

#tICA Individual Projection
#uses hardcoded conventions

#tICA feature generation
opts_AddOptional '--reclean-mode' 'RecleanModeString' 'YES or NO' 'whether the data should use ReCleanSignal.txt for DVARS' 'NO'

#tICA Component Classification
#not integrated yet

#tICA Cleanup
opts_AddOptional '--manual-components-to-remove' 'NuisanceListTxt' 'file' "text file containing the component numbers to be removed by cleanup, separated by spaces, requires either --tica-mode=USE or --starting-step=CleanData"
# It can either be a mandatory general input or optional input, even a varaible created by a check on process string
# 'YES' only when dealing with old 3T HCP data with 'hp2000', 'NO' otherwise
opts_AddOptional '--fix-legacy-bias' 'FixLegacyBiasString' 'YES or NO' 'whether the input data used the legacy bias correction' 'NO'

#general settings
opts_AddOptional '--starting-step' 'startStep' 'step' "what step to start processing at, one of:
$stepsText" "$defaultStart"
opts_AddOptional '--stop-after-step' 'stopAfterStep' 'step' "what step to stop processing after, same valid values as --starting-step" "$defaultStopAfter"
opts_AddOptional '--parallel-limit' 'parLimit' 'integer' "set how many subjects to do in parallel (local, not cluster-distributed) during individual projection" '-1'
opts_AddOptional '--matlab-run-mode' 'MatlabMode' '0, 1, or 2' "defaults to $g_matlab_default_mode
0 = compiled MATLAB (not implemented)
1 = interpreted MATLAB
2 = Octave" "$g_matlab_default_mode"
opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

#processing code goes here
IFS='@' read -a Subjlist <<<"$SubjlistRaw"
IFS='@' read -a fMRINamesArray <<<"$fMRINames"

FixLegacyBias=$(opts_StringToBool "$FixLegacyBiasString")
RecleanMode=$(opts_StringToBool "$RecleanModeString")
migpResumeBool=$(opts_StringToBool "$migpResume")

if ! [[ "$parLimit" == "-1" || "$parLimit" =~ [1-9][0-9]* ]]
then
    log_Err_Abort "--parallel-limit must be a positive integer or -1, provided value: '$parLimit'"
fi

signalTxtName="Signal.txt"
if ((RecleanMode))
then
    #alternatively, put the equivalent of this 'if' in the .m or .sh of the DVARS code, and pass the boolean
    signalTxtName="ReCleanSignal.txt"
fi

function stepNameToInd()
{
    for ((i = 0; i < ${#pipelineSteps[@]}; ++i))
    do
        if [[ "$1" == "${pipelineSteps[i]}" ]]
        then
            echo "$i"
            return
        fi
    done
    log_Err_Abort "unrecognized step name: '$1'"
}

startInd=$(stepNameToInd "$startStep")
stopAfterInd=$(stepNameToInd "$stopAfterStep")

if ((startInd > stopAfterInd))
then
    log_Err_Abort "starting step '$startStep' must not be after the stopping step '$stopAfterStep'"
fi

extraSuffixSTRING=""
if [[ "$extraSuffix" != "" ]]
then
    extraSuffixSTRING="_$extraSuffix"
fi

RegString=""
if [[ "$RegName" != "" && "$RegName" != "MSMSulc" ]]
then
    RegString="_$RegName"
fi

if [[ "$PCAOutputDim" == "" ]]
then
    PCAOutputDim="$subjectExpectedTimepoints"
fi
if [[ "$PCAInternalDim" == "" ]]
then
    PCAInternalDim=$((PCAOutputDim + 1))
fi

#set things needed for starting after the GroupSICA step
sICAActualDim=""
if [[ sicadimOverride != "" ]]
then
    sICAActualDim="$sicadimOverride"
    if [[ "$tICADim" == "" ]]
    then
        tICADim="$sICAActualDim"
    fi
fi

case "$ICAmode" in
    (NEW)
        sICAmode="ESTIMATE"
        tICAmode="ESTIMATE"
        ;;
    (REUSE_SICA_ONLY)
        sICAmode="USE"
        tICAmode="ESTIMATE"
        ;;
    (INITIALIZE_TICA)
        sICAmode="USE"
        tICAmode="INITIALIZE"
        ;;
    (REUSE_TICA)
        sICAmode="USE"
        tICAmode="USE"
        ;;
    (*)
        log_Err_Abort "unrecognized --ica-mode value '$ICAmode', valid options are NEW, REUSE_SICA_ONLY, INITIALIZE_TICA, or REUSE_TICA"
        ;;
esac

if [[ "$NuisanceListTxt" != "" ]]
then
    #manual list specified, make sure the mode setting is appropriate
    if [[ "$tICAmode" != "USE" || "$startStep" != "CleanData" ]]
    then
        log_Err_Abort "--manual-components-to-remove requires either --tica-mode=USE or --starting-step=CleanData"
    fi
fi

tICACleaningGroupAverageName="$GroupAverageName"
tICACleaningFolder="${StudyFolder}/${GroupAverageName}"
tICACleaningfMRIName="$OutputfMRIName"

#TODO: It seems we substitute an external tICA folder for the internal folder, even if we are re-estimating the tICA.  At a minimum the better thing to do seems to be to copy the folder (rather than modifying an external folder location).
#TSC: in non-estimate modes, it is not intended to write anything to the "cleaning" folder, and the output group folder uses different variables (study folder and group name)
#TSC: currently, run ComputeGroupTICA in all modes, so all modes can use the output folder as input for later steps
if [[ "$sICAmode" == "USE" ]]
then
    #all these modes operate almost identically (other than skipping things and compute tica), they don't need separate path variables
    if [[ "$precomputeTICAFolder" == "" || "$precomputeTICAfMRIName" == "" || "$precomputeGroupName" == "" ]]
    then
        log_Err_Abort "you must specify --precomputed-clean-folder, --precomputed-clean-fmri-name and --precomputed-group-name when using mode $ICAmode"
    fi
    
    tICACleaningFolder="$precomputeTICAFolder"
    tICACleaningfMRIName="$precomputeTICAfMRIName"
    tICACleaningGroupAverageName="$precomputeGroupName"
    #TODO: can't run USE/INITIALIZE modes using outputs generated with an extra suffix without another optional parameter?
fi

OutputString="$OutputfMRIName"_d"$sICAActualDim"_WF"$numWisharts"_"$tICACleaningGroupAverageName""$extraSuffixSTRING"

#this doesn't get changed later, it is for convenience
#we only write things here in ESTIMATE mode, which means tICACleaningfMRIName is OutputfMRIName and tICACleaningGroupAverageName is OutputfMRIName
sICAoutfolder="${StudyFolder}/${tICACleaningGroupAverageName}/MNINonLinear/Results/${tICACleaningfMRIName}/sICA"

#use brainmask from cleaning folder if in USE mode
if [[ "$tICAmode" == "USE" ]]
then
    VolumeTemplateFile="${tICACleaningFolder}/MNINonLinear/${tICACleaningGroupAverageName}_CIFTIVolumeTemplate.${fMRIResolution}.dscalar.nii"
    if [[ ! -f "$VolumeTemplateFile" ]]
    then
        log_Error_Abort "precomputed cleaning folder does not contain the expected cifti volume template: '$VolumeTemplateFile'"
    fi
else
    VolumeTemplateFile="${StudyFolder}/${GroupAverageName}/MNINonLinear/${GroupAverageName}_CIFTIVolumeTemplate.${fMRIResolution}.dscalar.nii"
fi

#functions so that we can do certain things across subjects in parallel
function subjectMaxBrainmask()
{
    Subject="$1"
    for fMRIName in "${fMRINamesArray[@]}"
    do
        if [[ -e "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_brain_mask.nii.gz" ]]
        then
            subjMergeArgs+=(-volume "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_brain_mask.nii.gz")
        fi
    done
    wb_command -volume-merge "${StudyFolder}/${Subject}/MNINonLinear/Results/brain_mask_all.${fMRIResolution}.nii.gz" \
        "${subjMergeArgs[@]}"
    wb_command -volume-reduce "${StudyFolder}/${Subject}/MNINonLinear/Results/brain_mask_all.${fMRIResolution}.nii.gz" \
        MAX \
        "${StudyFolder}/${Subject}/MNINonLinear/Results/brain_mask_max.${fMRIResolution}.nii.gz"
    #remove this early rather than waiting for tempfiles to clean up
    rm -f "${StudyFolder}/${Subject}/MNINonLinear/Results/brain_mask_all.${fMRIResolution}.nii.gz"
}

function splitMRFIX()
{
    Subject="$1"
    curStart=1
    for fMRIName in "${fMRINamesArray[@]}"
    do
        if [[ -f "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}${fMRIProcSTRING}.dtseries.nii" ]]
        then
            curLength=$(wb_command -file-information -only-number-of-maps "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}${fMRIProcSTRING}.dtseries.nii")
            tempfile=$(tempfiles_create tICAPipeline-mrsplit-XXXXXX.dtseries.nii)
            wb_command -cifti-merge "$tempfile" \
                -cifti "${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}${fMRIProcSTRING}_tclean.dtseries.nii" \
                    -column "$curStart" -up-to $((curStart + curLength - 1))
            wb_command -cifti-math 'split / mr_vn * orig_vn + mean' "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}${fMRIProcSTRING}_tclean.dtseries.nii" \
                -var split "$tempfile" \
                -var mr_vn "${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_Atlas_hp${HighPass}_vn.dscalar.nii" -select 1 1 -repeat \
                -var orig_vn "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas_hp${HighPass}_vn.dscalar.nii" -select 1 1 -repeat \
                -var mean "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas_mean.dscalar.nii" -select 1 1 -repeat
            
            #NOTE: we currently always do volume in cleandata, so split it too
            tempfilevol=$(tempfiles_create tICAPipeline-mrsplit-XXXXXX.nii.gz)
            wb_command -volume-merge "$tempfilevol" \
                -volume "${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}${fMRIProcSTRING/_Atlas${RegString}/''}_tclean.nii.gz" -subvolume "$curStart" -up-to $((curStart + curLength - 1))
            wb_command -volume-math 'split / mr_vn * orig_vn + mean' "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}${fMRIProcSTRING/_Atlas${RegString}/''}_tclean.nii.gz" \
                -var split "$tempfilevol" \
                -var mr_vn "${StudyFolder}/${Subject}/MNINonLinear/Results/${MRFixConcatName}/${MRFixConcatName}_hp${HighPass}_vn.nii.gz" -subvolume 1 -repeat \
                -var orig_vn "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}_vn.nii.gz" -subvolume 1 -repeat \
                -var mean "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_mean.nii.gz" -subvolume 1 -repeat
            
            curStart=$((curStart + curLength))
        fi
    done
}

for ((stepInd = startInd; stepInd <= stopAfterInd; ++stepInd))
do
    stepName="${pipelineSteps[stepInd]}"
    case "$stepName" in
        (MIGP)
            if [[ "$sICAmode" != "ESTIMATE" ]]
            then
                #skip to next pipeline stage
                continue
            fi
            migpResumeFile="$StudyFolder/$GroupAverageName/MNINonLinear/Results/$OutputfMRIName/${OutputfMRIName}${fMRIProcSTRING}_MIGP_resume.mat"
            if ((! migpResumeBool)) && [[ -f "$migpResumeFile" ]]
            then
                mv -f "$migpResumeFile" "$migpResumeFile".disabled
            fi
            fMRINamesArg="$fMRINames"
            if [[ "$MRFixConcatName" != "" ]]
            then
                fMRINamesArg="$MRFixConcatName"
            fi
            "$HCPPIPEDIR"/tICA/scripts/MIGP.sh \
                --study-folder="$StudyFolder" \
                --subject-list="$SubjlistRaw" \
                --fmri-names="$fMRINamesArg" \
                --out-fmri-name="$OutputfMRIName" \
                --proc-string="$fMRIProcSTRING" \
                --out-group-name="$GroupAverageName" \
                --pca-internal-dim="$PCAInternalDim" \
                --pca-out-dim="$PCAOutputDim" \
                --resumable="$migpResumeFile" \
                --matlab-run-mode="$MatlabMode"
            #MIGP.m deletes the checkpoint file on its own if everything was fine
            #MIGP.sh now checks for expected output and errors if not found
            ;;
        (GroupSICA)
            if [[ "$sICAmode" != "ESTIMATE" ]]
            then
                #skip to next pipeline stage
                continue
            fi
            "$HCPPIPEDIR"/tICA/scripts/GroupSICA.sh \
                --data="$StudyFolder/$GroupAverageName/MNINonLinear/Results/$OutputfMRIName/${OutputfMRIName}${fMRIProcSTRING}_PCA.dtseries.nii" \
                --vn-file="$StudyFolder/$GroupAverageName/MNINonLinear/Results/$OutputfMRIName/${OutputfMRIName}${fMRIProcSTRING}_meanvn.dscalar.nii" \
                --wf-out-name="$StudyFolder/$GroupAverageName/MNINonLinear/Results/$OutputfMRIName/${OutputfMRIName}${fMRIProcSTRING}_PCA"_WF"$numWisharts".dtseries.nii \
                --out-folder="$sICAoutfolder" \
                --num-wishart="$numWisharts" \
                --icadim-iters="$sicadimIters" \
                --process-dims="$LowsICADims" \
                --icadim-override="$sicadimOverride" \
                --matlab-run-mode="$MatlabMode"
            sICAActualDim=$(cat "$sICAoutfolder/most_recent_dim.txt")
            if [[ "$tICADim" == "" ]]
            then
                tICADim="$sICAActualDim"
            fi
            ;;
        (indProjSICA)
            if [[ "$sICAActualDim" == "" ]]
            then
                log_Err_Abort "starting step is after GroupSICA, you must specify --sicadim-override to set the dimensionality to use"
            fi
            if [[ "$tICAmode" != "USE" ]]
            then
                #generate volume template cifti
                #use parallel and do subjects separately first to reduce memory (some added IO)
                mergeArgs=()
                for Subject in "${Subjlist[@]}"
                do
                    tempfiles_add "${StudyFolder}/${Subject}/MNINonLinear/Results/brain_mask_all.${fMRIResolution}.nii.gz" \
                        "${StudyFolder}/${Subject}/MNINonLinear/Results/brain_mask_max.${fMRIResolution}.nii.gz"
                    #this function is above the stepInd loop
                    par_addjob subjectMaxBrainmask "$Subject"
                    mergeArgs+=(-volume "${StudyFolder}/${Subject}/MNINonLinear/Results/brain_mask_max.${fMRIResolution}.nii.gz")
                done
                par_runjobs "$parLimit"

                tempfiles_add "${StudyFolder}/${GroupAverageName}/MNINonLinear/brain_mask_all.${fMRIResolution}.nii.gz" \
                    "${StudyFolder}/${GroupAverageName}/MNINonLinear/${GroupAverageName}_CIFTIVolumeTemplate.${fMRIResolution}.txt" \
                    "${StudyFolder}/${GroupAverageName}/MNINonLinear/brain_mask_label.${fMRIResolution}.nii.gz"
                    
                    #"${StudyFolder}/${GroupAverageName}/MNINonLinear/brain_mask_max.${fMRIResolution}.nii.gz" \ should be kept for feature processing
                wb_command -volume-merge "${StudyFolder}/${GroupAverageName}/MNINonLinear/brain_mask_all.${fMRIResolution}.nii.gz" \
                    "${mergeArgs[@]}"
                wb_command -volume-reduce "${StudyFolder}/${GroupAverageName}/MNINonLinear/brain_mask_all.${fMRIResolution}.nii.gz" \
                    MAX \
                    "${StudyFolder}/${GroupAverageName}/MNINonLinear/brain_mask_max.${fMRIResolution}.nii.gz"
                echo $'OTHER\n1 255 255 255 255' > "${StudyFolder}/${GroupAverageName}/MNINonLinear/${GroupAverageName}_CIFTIVolumeTemplate.${fMRIResolution}.txt"
                wb_command -volume-label-import "${StudyFolder}/${GroupAverageName}/MNINonLinear/brain_mask_max.${fMRIResolution}.nii.gz" \
                    "${StudyFolder}/${GroupAverageName}/MNINonLinear/${GroupAverageName}_CIFTIVolumeTemplate.${fMRIResolution}.txt" \
                    "${StudyFolder}/${GroupAverageName}/MNINonLinear/brain_mask_label.${fMRIResolution}.nii.gz"
                wb_command -cifti-create-dense-scalar "$VolumeTemplateFile" \
                    -volume "${StudyFolder}/${GroupAverageName}/MNINonLinear/brain_mask_max.${fMRIResolution}.nii.gz" \
                        "${StudyFolder}/${GroupAverageName}/MNINonLinear/brain_mask_label.${fMRIResolution}.nii.gz"
            else
                #TODO: if "feature processing" is not supported in use mode (or takes this mask as an explicit argument), we may not need to copy this
                cp "${tICACleaningFolder}/MNINonLinear/brain_mask_max.${fMRIResolution}.nii.gz" \
                    "${StudyFolder}/${GroupAverageName}/MNINonLinear/brain_mask_max.${fMRIResolution}.nii.gz"
            fi
            
            for Subject in "${Subjlist[@]}"
            do
                #build list of fMRI files, can either be generated by a function or just like this
                fMRIExist=()
                for fMRIName in "${fMRINamesArray[@]}"
                do
                    if [[ -f "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}${fMRIProcSTRING}.dtseries.nii" ]]
                    then
                        fMRIExist+=("${fMRIName}")
                    fi
                done
                fMRINamesForSub=$(IFS='@'; echo "${fMRIExist[*]}")
                #queue (local) parallel job
                par_addjob "$HCPPIPEDIR"/global/scripts/RSNregression.sh \
                    --study-folder="$StudyFolder" \
                    --subject="$Subject" \
                    --group-maps="${sICAoutfolder}/melodic_oIC_${sICAActualDim}.dscalar.nii" \
                    --subject-timeseries="$fMRINamesForSub" \
                    --surf-reg-name="$RegName" \
                    --low-res="$LowResMesh" \
                    --proc-string="${fMRIProcSTRING/_Atlas${RegString}/''}" \
                    --method=weighted \
                    --low-ica-dims="$LowsICADims" \
                    --low-ica-template-name="$sICAoutfolder/melodic_oIC_REPLACEDIM.dscalar.nii" \
                    --output-string="$OutputString" \
                    --output-spectra="$subjectExpectedTimepoints" \
                    --volume-template-cifti="$VolumeTemplateFile" \
                    --output-z=1 \
                    --fix-legacy-bias="$FixLegacyBias" \
                    --scale-factor=0.01

            done
            #run the jobs, this line also waits until they are complete
            par_runjobs "$parLimit"
            ;;
        (ConcatGroupSICA)
            if [[ "$sICAActualDim" == "" ]]
            then
                log_Err_Abort "starting step is after GroupSICA, you must specify --sicadim-override to set the dimensionality to use"
            fi
            if [[ "$sICAmode" != "ESTIMATE" ]]
        	then 
        		mkdir -p "${StudyFolder}/${GroupAverageName}/MNINonLinear/Results/${OutputfMRIName}/sICA"
        		cp "${tICACleaningFolder}/MNINonLinear/Results/${tICACleaningfMRIName}/sICA/iq_${sICAActualDim}.wb_annsub.csv" "${StudyFolder}/${GroupAverageName}/MNINonLinear/Results/${OutputfMRIName}/sICA/"
            fi
            "$HCPPIPEDIR"/tICA/scripts/ConcatGroupSICA.sh \
                --study-folder="$StudyFolder" \
                --subject-list="$SubjlistRaw" \
                --out-folder="${StudyFolder}/${GroupAverageName}" \
                --fmri-concat-name="$OutputfMRIName" \
                --surf-reg-name="$RegName" \
                --ica-dim="$sICAActualDim" \
                --subject-expected-timepoints="$subjectExpectedTimepoints" \
                --low-res-mesh="$LowResMesh" \
                --sica-proc-string="${OutputString}_WR"
            ;;
        (ComputeGroupTICA)
            #running this step in USE mode generates files in the output folder, which removes the need for a second OutputString to track the input naming for that mode
            if [[ "$sICAActualDim" == "" ]]
            then
                log_Err_Abort "starting step is after GroupSICA, you must specify --sicadim-override to set the dimensionality to use"
            fi
            tica_cmd=("$HCPPIPEDIR"/tICA/scripts/ComputeGroupTICA.sh
                        --study-folder="$StudyFolder"
                        --subject-list="$SubjlistRaw"
                        --fmri-list="$fMRINames"
                        --out-folder="${StudyFolder}/${GroupAverageName}"
                        --fmri-concat-name="$OutputfMRIName"
                        --surf-reg-name="$RegName"
                        --ica-dim="$tICADim"
                        --subject-expected-timepoints="$subjectExpectedTimepoints"
                        --low-res-mesh="$LowResMesh"
                        --sica-proc-string="${OutputString}_WR"
                        --tICA-mode="$tICAmode"
                     )
            #estimate mode doesn't need a prior mixing matrix, and would error if given a bogus path
            if [[ "$tICAmode" != ESTIMATE ]]
            then
                #current mixing matrix naming convention is in ComputeGroupTICA.sh/m
                #"sICADim" is the --ica-dim argument, which is actually the tICA dim
                #OutputFolder="$OutGroupFolder/MNINonLinear/Results/$fMRIConcatName/tICA_d$sICAdim"
                
                #tICAmixNamePart = 'melodic_mix';
                #nlfunc = 'tanh';

                #the IT we want is presumably F, assuming we always do more than 5 iterations, here is how it is set:
                #for i = ITERATIONS
                #    if  i == 0
                #        IT = ['F'];
                #        ...
                #    elseif i == 1
                #        IT = [num2str(i)];
                #        ...
                #    elseif i > 5
                #        IT = ['F'];
                #        ...
                #    else
                #        IT = [num2str(i)];
                #        ...
                #    end

                #    nameParamPart = ['_' num2str(tICAdim) '_' nlfunc IT];
                #    dlmwrite([OutputFolder '/' tICAmixNamePart nameParamPart], tICAmix, '\t');
                tica_cmd+=(--tICA-mixing-matrix="$tICACleaningFolder/MNINonLinear/Results/$OutputfMRIName/tICA_d$tICADim/melodic_mix_${tICADim}_tanhF")
            fi
            
            "${tica_cmd[@]}"
            
            ;;
        (indProjTICA)
            if [[ "$sICAActualDim" == "" ]]
            then
                log_Err_Abort "starting step is after GroupSICA, you must specify --sicadim-override to set the dimensionality to use"
            fi
            for Subject in "${Subjlist[@]}"
            do
                #build list of fMRI files, can either be generated by a function or just like this
                #since the user may have told the pipeline to start on this step, we must do this check from scratch
                if [[ "$MRFixConcatName" != "" ]]
                then
                    fMRINamesForSub="$MRFixConcatName"
                else
                    fMRIExist=()
                    for fMRIName in "${fMRINamesArray[@]}"
                    do
                        if [[ -f "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}${fMRIProcSTRING}.dtseries.nii" ]]
                        then
                            fMRIExist+=("${fMRIName}")
                        fi
                    done
                    fMRINamesForSub=$(IFS='@'; echo "${fMRIExist[*]}")
                fi
    #Comment:
    #OutString=${OutputfMRIName}_d${sICAActualDim}_WF${numWisharts}_${GroupAverageName}_WR #OutString for --timeseries
    #if [ ${Method} == "single" ] ; then
       #Timeseries="${StudyFolder}/${Subject}/MNINonLinear/fsaverage_LR32k/${Subject}.${OutString}_${RegName}_ts.32k_fs_LR.sdseries.nii" #2.0mm Used this
    #fi
    #--output-string="${OutputfMRIName}_d${sICAActualDim}_WF${numWisharts}_${GroupAverageName}_WR_tICA" #This is correct
    #--group-maps is not needed

                par_addjob "$HCPPIPEDIR"/global/scripts/RSNregression.sh \
                    --study-folder="$StudyFolder" \
                    --subject="$Subject" \
                    --timeseries="${StudyFolder}/${Subject}/MNINonLinear/fsaverage_LR32k/${Subject}.${OutputString}_WR_tICA${RegString}_ts.32k_fs_LR.sdseries.nii" \
                    --subject-timeseries="$fMRINamesForSub" \
                    --surf-reg-name="$RegName" \
                    --low-res="$LowResMesh" \
                    --proc-string="${fMRIProcSTRING/_Atlas${RegString}/''}" \
                    --method=single \
                    --output-string="${OutputString}_WR_tICA" \
                    --output-spectra="$subjectExpectedTimepoints" \
                    --volume-template-cifti="$VolumeTemplateFile" \
                    --output-z=1 \
                    --fix-legacy-bias="$FixLegacyBias" \
                    --scale-factor=0.01
            done
            par_runjobs "$parLimit"
            ;;
        (ComputeTICAFeatures)
            #FIXME: is ComputeTICAFeatures supported in USE mode?  Should it take the brainmask as an argument instead of expecting a copy in the output folder?
            #TODO: No need for it, a prior classification must be specified in USE mode
            #detail: this output folder won't contain the features in USE mode, since we don't start with a folder copy
            if [[ "$tICAmode" == "USE" ]]
            then
                #skip to next pipeline stage
                continue
            fi
	        if [[ "$sICAActualDim" == "" ]]
	        then
	            log_Err_Abort "starting step is after GroupSICA, you must specify --sicadim-override to set the dimensionality to use"
	        fi
	        "$HCPPIPEDIR"/tICA/scripts/ComputeTICAFeatures.sh \
				--study-folder="$StudyFolder" \
				--out-group-name="$GroupAverageName" \
				--subject-list="$SubjlistRaw" \
			    --fmri-list="$fMRINames" \
			    --fmri-output-name="$OutputfMRIName" \
			    --ica-dim="$tICADim" \
			    --proc-string="${fMRIProcSTRING/_Atlas${RegString}/''}" \
			    --tica-proc-string="${OutputString}_WR_tICA" \
			    --fmri-resolution="$fMRIResolution" \
				--surf-reg-name="$RegName" \
				--low-res="$LowResMesh" \
				--melodic-high-pass="$HighPass" \
				--mrfix-concat-name="$MRFixConcatName" \
				--reclean-mode="$RecleanModeString"
            ;;
        (ClassifyTICA)
	        if [[ "$sICAActualDim" == "" ]]
	        then
	            log_Err_Abort "starting step is after GroupSICA, you must specify --sicadim-override to set the dimensionality to use"
	        fi
	        log_Err_Abort "automated classification not currently implemented, please classify manually, then rerun with '--starting-step=CleanData'"
            ;;
        (CleanData)
            if [[ "$sICAActualDim" == "" ]]
            then
                log_Err_Abort "starting step is after GroupSICA, you must specify --sicadim-override to set the dimensionality to use"
            fi
            if [[ "$NuisanceListTxt" == "" ]]
            then
                NuisanceListTxt="$tICACleaningFolder/MNINonLinear/Results/${tICACleaningfMRIName}/tICA_d${sICAActualDim}/Noise.txt"
            fi
            for Subject in "${Subjlist[@]}"
            do
                if [[ "$MRFixConcatName" != "" ]]
                then
                    fMRINamesForSub="$MRFixConcatName"
                else
                    #build list of fMRI files, can either be generated by a function or just like this
                    fMRIExist=()
                    for fMRIName in "${fMRINamesArray[@]}"
                    do
                        if [[ -f "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}${fMRIProcSTRING}.dtseries.nii" ]]
                        then
                            fMRIExist+=("${fMRIName}")
                        fi
                    done
                    fMRINamesForSub=$(IFS='@'; echo "${fMRIExist[*]}")
                fi
                #for now, always do volume outputs
                par_addjob "$HCPPIPEDIR"/tICA/scripts/tICACleanData.sh \
                    --study-folder="$StudyFolder" \
                    --subject="$Subject" \
                    --noise-list="$NuisanceListTxt" \
                    --timeseries="${StudyFolder}/${Subject}/MNINonLinear/fsaverage_LR32k/${Subject}.${OutputString}_WR_tICA${RegString}_ts.32k_fs_LR.sdseries.nii" \
                    --subject-timeseries="$fMRINamesForSub" \
                    --surf-reg-name="$RegName" \
                    --low-res="$LowResMesh" \
                    --proc-string="${fMRIProcSTRING/_Atlas${RegString}/''}" \
                    --output-string="${fMRIProcSTRING/_Atlas${RegString}/''}_tclean" \
                    --do-vol=YES \
                    --fix-legacy-bias="$FixLegacyBias" \
                    --matlab-run-mode="$MatlabMode"
            done
            par_runjobs "$parLimit"
            
            if [[ "$MRFixConcatName" != "" ]]
            then
                #split mr+fix back into pieces
                for Subject in "${Subjlist[@]}"
                do
                    par_addjob splitMRFIX "$Subject"
                done
                par_runjobs "$parLimit"
            fi
            ;;
        (*) #NOTE: this case MUST be last
            log_Err_Abort "internal error: unimplemented pipeline step '$stepName'"
            ;;
    esac
    log_Msg "step $stepName complete"
done

