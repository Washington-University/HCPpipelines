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
g_matlab_default_mode=1
#add steps to this array and in the switch cases below
pipelineSteps=(MIGP GroupSICA indProjSICA ConcatGroupSICA ComputeGroupTICA indProjTICA ComputeTICAFeatures ClassifyTICA CleanData)
defaultStart="${pipelineSteps[0]}"
defaultStopAfter="${pipelineSteps[${#pipelineSteps[@]} - 1]}"
stepsText="$(IFS=$'\n'; echo "${pipelineSteps[*]}")"

#description to use in usage - syntax of parameters is now explained automatically
opts_SetScriptDescription "implements temporal ICA decomposition and cleanup"

#mandatory (mrfix name must be specified if applicable, so including it here despite being mechanically optional)
#general inputs
opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder that contains all sessions"
opts_AddMandatory '--session-list' 'SesslistRaw' '100206@100307...' "list of session IDs separated by @s. In longitudinal mode, list sessions for a single subject." "--subject-list"
opts_AddMandatory '--fmri-names' 'fMRINames' 'rfMRI_REST1_LR@rfMRI_REST1_RL...' "list of fmri run names separated by @s" #Needs to be the single fMRI run names only (for DVARS and GS code) for MR+FIX, is also the SR+FIX input names
opts_AddOptional '--mrfix-concat-name' 'MRFixConcatName' 'rfMRI_REST' "if multi-run FIX was used, you must specify the concat name with this option"
opts_AddMandatory '--output-fmri-name' 'OutputfMRIName' 'rfMRI_REST' "name to use for tICA pipeline outputs"
opts_AddMandatory '--proc-string' 'fMRIProcSTRING' 'string' "file name component representing the preprocessing already done, e.g. '_Atlas_MSMAll_hp0_clean'"
opts_AddMandatory '--fix-high-pass' 'HighPass' 'integer' 'the high pass value that was used when running FIX' '--melodic-high-pass'
opts_AddMandatory '--out-group-name' 'GroupAverageName' 'string' 'name to use for the group output folder'
opts_AddMandatory '--fmri-resolution' 'fMRIResolution' 'string' "resolution of data, like '2' or '1.60'"
#TSC: doesn't default to MSMAll because we don't have that default string in the MSMAll pipeline
opts_AddMandatory '--surf-reg-name' 'RegName' 'MSMAll' "the registration string corresponding to the input files"
#sICA
opts_AddConfigMandatory '--num-wishart' 'numWisharts' 'numWisharts' 'integer' "how many wisharts to use in icaDim" #FIXME - We will need to think about how to help users set this.  Ideally it is established by running a null model, but that is timeconsuming. Valid values for humans have been WF5 or WF6.
#sICA individual projection
opts_AddConfigMandatory '--low-res' 'LowResMesh' 'LowResMesh' 'meshnum' "mesh resolution, like '32' for 32k_fs_LR"
opts_AddMandatory '--session-expected-timepoints' 'sessionExpectedTimepoints' 'string' "output spectra size for sICA individual projection, RunsXNumTimePoints, like '4800'" "--subject-expected-timepoints"


#optional
#general
opts_AddOptional '--ica-mode' 'ICAmode' 'string' "whether to use parts of a previous tICA run (for instance, if this group has too few sessions to simply estimate a new tICA).  Defaults to NEW, all other modes require specifying the --precomputed-* options.  Value must be one of:
NEW - estimate a new sICA and a new tICA
REUSE_SICA_ONLY - reuse an existing sICA and estimate a new tICA
INITIALIZE_TICA - reuse an existing sICA and use an existing tICA to start the estimation
REUSE_TICA - reuse an existing sICA and an existing tICA (this mode is mandatory for longitudinal processing)" \
    'NEW'
#TSC: this is the output group folder, one above MNINonLinear
opts_AddConfigOptional '--precomputed-clean-folder' 'precomputeTICAFolder' 'precomputeTICAFolder' 'folder' "group folder containing an existing tICA cleanup to make use of for REUSE or INITIALIZE modes"
opts_conf_SetIsPath 'precomputeTICAFolder'
opts_AddConfigOptional '--precomputed-clean-fmri-name' 'precomputeTICAfMRIName' 'precomputeTICAfMRIName' 'rfMRI_REST' "the output fMRI name used in the previously computed tICA"
opts_AddConfigOptional '--precomputed-group-name' 'precomputeGroupName' 'precomputeGroupName' 'PrecomputedGroupName' "the group name used during the previously computed tICA"
opts_AddOptional '--extra-output-suffix' 'extraSuffix' 'string' "add something extra to most output filenames, for collision avoidance"

#MIGP
opts_AddConfigOptional '--pca-out-dim' 'PCAOutputDim' 'PCAOutputDim' 'integer' 'override number of PCA components to use for group sICA' #defaults to sessionExpectedTimepoints
opts_AddConfigOptional '--pca-internal-dim' 'PCAInternalDim' 'PCAInternalDim' 'integer' 'override internal MIGP dimensionality'
opts_AddOptional '--migp-resume' 'migpResume' 'YES or NO' 'resume from a previous interrupted MIGP run, if present, default YES' 'YES'

#sICA
opts_AddOptional '--sicadim-iters' 'sicadimIters' 'integer' "number of iterations or mode for estimating sICA dimensionality, default 100" '100'
opts_AddConfigOptional '--sicadim-override' 'sicadimOverride' 'sicadimOverride' 'integer' "use this dimensionality instead of icaDim's estimate"

#sICA individual projection
opts_AddOptional '--low-sica-dims' 'LowsICADims' 'num@num@num...' "the low sICA dimensionalities to use for determining weighting for individual projection, defaults to '7@8@9@10@11@12@13@14@15@16@17@18@19@20@21'" '7@8@9@10@11@12@13@14@15@16@17@18@19@20@21'

#sICA concatenation
#uses hardcoded conventions

#tICA
#TODO: sanity check that tICADim (when specified) is not higher than sICADim (once it is known)
#FIXME: ComputeGroupTICA.m hardcodes "tICAdim = sICAdim;", line 76
#TSC: remove option until ComputeGroupTICA.m allows different dimensionalities
#opts_AddConfigOptional '--tica-dim' 'tICADim' 'tICADim' 'integer' "override the default of tICA dimensionality = sICA dimensionality. Must be less than or equal to sICA dimensionality"
tICADim=""

#tICA Individual Projection
#uses hardcoded conventions

#tICA feature generation
opts_AddOptional '--reclean-mode' 'RecleanModeString' 'YES or NO' 'whether the data should use ReCleanSignal.txt for DVARS' 'NO'

#tICA Component Classification
#not integrated yet

#tICA Cleanup
opts_AddOptional '--manual-components-to-remove' 'NuisanceListTxt' 'file' "text file containing the component numbers to be removed by cleanup, separated by spaces, requires either --ica-mode=REUSE_TICA or --starting-step=CleanData"
# It can either be a mandatory general input or optional input, even a varaible created by a check on process string
# 'YES' only when dealing with old 3T HCP data with 'hp2000', 'NO' otherwise
opts_AddOptional '--fix-legacy-bias' 'FixLegacyBiasString' 'YES or NO' 'whether the input data used the legacy bias correction' 'NO'
opts_AddOptional '--extract-fmri-name-list' 'concatNamesToUse' 'name@name@name...' "list of fMRI run names to concatenate into the --extract-fmri-out output after tICA cleanup"
opts_AddOptional '--extract-fmri-out' 'extractNameOut' 'name' "fMRI name for concatenated extracted runs, requires --extract-fmri-name-list"

#longitudinal mode specific options
opts_AddOptional '--is-longitudinal' 'IsLongitudinal' 'TRUE or FALSE' "longitudinal processing mode. By default, fMRI runs under --extract-fmri-out will be concatenated and stored under base template results directory. Specify --longitudinal-extract-all=TRUE to separately output runs under --fmri-names." "FALSE"
opts_AddOptional '--longitudinal-template' 'TemplateLong' 'template ID' 'Longitudinal base template ID' ""
opts_AddOptional '--longitudinal-subject' 'Subject' 'Subject' 'Subject ID, required in longitudinal mode' ""
opts_AddOptional '--longitudinal-extract-all' 'ExtractAllRunsLong' 'TRUE or FALSE' 'Extract all runs specified in --fmri-names, with output name matching the one from --mrfix-concat-name' "FALSE"

#general settings
opts_AddOptional '--config-out' 'confoutfile' 'file' "generate config file for rerunning with similar settings, or for reusing these results for future cleaning"
opts_AddOptional '--starting-step' 'startStep' 'step' "what step to start processing at, one of:
$stepsText" "$defaultStart"
opts_AddOptional '--stop-after-step' 'stopAfterStep' 'step' "what step to stop processing after, same valid values as --starting-step" "$defaultStopAfter"
opts_AddOptional '--parallel-limit' 'parLimit' 'integer' "set how many sessions to do in parallel (local, not cluster-distributed) during individual projection and cleanup, defaults to all detected physical cores" '-1'
opts_AddOptional '--matlab-run-mode' 'MatlabMode' '0, 1, or 2' "defaults to $g_matlab_default_mode
0 = compiled MATLAB
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
IFS='@' read -a fMRINamesArray <<<"$fMRINames"

FixLegacyBias=$(opts_StringToBool "$FixLegacyBiasString")
RecleanMode=$(opts_StringToBool "$RecleanModeString")
migpResumeBool=$(opts_StringToBool "$migpResume")
IsLongitudinal=$(opts_StringToBool "$IsLongitudinal")
ExtractAllRunsLong=$(opts_StringToBool "$ExtractAllRunsLong")

extractNameAllLong=""

if ! [[ "$parLimit" == "-1" || "$parLimit" =~ [1-9][0-9]* ]]
then
    log_Err_Abort "--parallel-limit must be a positive integer or -1, provided value: '$parLimit'"
fi

if [[ "$extractNameOut" != "" ]]
then
    if [[ "$MRFixConcatName" == "" ]]
    then
        log_Err_Abort "--mrfix-concat-name is required when using --extract-fmri-out"
    fi
    if [[ "$concatNamesToUse" == "" ]]
    then
        log_Err_Abort "--extract-fmri-name-list is required when using --extract-fmri-out"
    fi
fi

signalTxtName="Signal.txt"
if ((RecleanMode))
then
    #alternatively, put the equivalent of this 'if' in the .m or .sh of the DVARS code, and pass the boolean
    signalTxtName="ReCleanSignal.txt"
fi

if ((IsLongitudinal)); then
    if [[ "$ICAmode" != "REUSE_TICA" ]]; then
        log_Err_Abort "mode other than REUSE_TICA is not supported in longitudinal processing"
    fi
    if [[ "$TemplateLong" == "" || "$Subject" == "" || "$extractNameOut" == "" ]]; then
        log_Err_Abort "--extract-fmri-out, --longitudinal-template and --longitudinal-subject are required in longitudinal mode."
    fi
    if ((ExtractAllRunsLong)); then
        extractNameAllLong="$MRFixConcatName"
    fi
    IFS='@' read -a SesslistCross <<<"$SesslistRaw"
    Sesslist=()
    for sess in "${SesslistCross[@]}"; do
        Sesslist+=("${sess}.long.$TemplateLong")
    done
else
    IFS='@' read -a Sesslist <<<"$SesslistRaw"
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

if [[ "$RegName" == "" || "$RegName" == "MSMSulc" ]]
then
    log_Err_Abort "folding-based alignment is insufficient for tICA"
fi

#TSC: if we don't support using MSMSulc anyway, then we don't need to special case it
RegString=""
if [[ "$RegName" != "" ]]
then
    RegString="_$RegName"
fi

if [[ "$PCAOutputDim" == "" ]]
then
    PCAOutputDim="$sessionExpectedTimepoints"
fi
if [[ "$PCAInternalDim" == "" ]]
then
    PCAInternalDim=$((PCAOutputDim + 1))
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
        log_Err_Abort "--manual-components-to-remove requires either --ica-mode=REUSE_TICA or --starting-step=CleanData"
    fi
fi

#generate a new brainmask if we don't have one for this resolution
VolumeTemplateFile="${StudyFolder}/${GroupAverageName}/MNINonLinear/${GroupAverageName}_CIFTIVolumeTemplate_${OutputfMRIName}.${fMRIResolution}.dscalar.nii"

tICACleaningGroupAverageName="$GroupAverageName"
tICACleaningFolder="${StudyFolder}/${GroupAverageName}"
tICACleaningfMRIName="$OutputfMRIName"

#TSC: nothing should use the "cleaning" folder for output, outputs should always use the StudyFolder/GroupAverageName variables for output paths, this just selects input location based on mode
#TSC: currently, run ComputeGroupTICA.sh in all modes, so all modes can use the output folder as input for later steps
if [[ "$sICAmode" == "USE" ]]
then
    #all these modes operate almost identically (other than skipping things and compute tica mode), they don't need separate path variables
    if [[ "$precomputeTICAFolder" == "" || "$precomputeTICAfMRIName" == "" || "$precomputeGroupName" == "" ]]
    then
        log_Err_Abort "you must specify --precomputed-clean-folder, --precomputed-clean-fmri-name and --precomputed-group-name when using --ica-mode=$ICAmode"
    fi

    tICACleaningFolder="$precomputeTICAFolder"
    tICACleaningfMRIName="$precomputeTICAfMRIName"
    tICACleaningGroupAverageName="$precomputeGroupName"

    #if we have a brainmask for the current fmri resolution, use it instead of making a new one, to support running CleanData in a per-session fashion
    if [[ -f "$tICACleaningFolder/MNINonLinear/${tICACleaningGroupAverageName}_CIFTIVolumeTemplate_${tICACleaningfMRIName}.${fMRIResolution}.dscalar.nii" ]]
    then
        VolumeTemplateFile="$tICACleaningFolder/MNINonLinear/${tICACleaningGroupAverageName}_CIFTIVolumeTemplate_${tICACleaningfMRIName}.${fMRIResolution}.dscalar.nii"
    fi

    #TODO: can't run USE/INITIALIZE modes using outputs generated with an extra suffix without another optional parameter, do we need to support this?
fi

#set things needed for starting after the GroupSICA step
#don't set sICAActualDim to something invalid, to catch errors
#sICAActualDim=""
if [[ "$sicadimOverride" == "" ]]
then
    #dim override not provided, check that we are not starting after the GroupSICA step
    groupSICAind=$(stepNameToInd "GroupSICA")
    if ((startInd > groupSICAind))
    then
        log_Err_Abort "starting step is after GroupSICA, you must specify --sicadim-override to set the dimensionality to use"
    fi
    #or that we would skip it
    if [[ "$sICAmode" != "ESTIMATE" ]]
    then
        log_Err_Abort "this --ica-mode skips doing the GroupSICA step, you must specify --sicadim-override to set the dimensionality to use"
    fi
else
    #dim override provided, use it and set OutputString since we know all the pieces
    sICAActualDim="$sicadimOverride"
    if [[ "$tICADim" == "" ]]
    then
        tICADim="$sICAActualDim"
    fi
    OutputString="$OutputfMRIName"_d"$sICAActualDim"_WF"$numWisharts"_"$tICACleaningGroupAverageName""$extraSuffixSTRING"
fi
#leave OutputString unset if we don't know the dimensionality yet

#this doesn't get changed later, it is for convenience
#we only write things here in NEW (sICA ESTIMATE) mode, which means tICACleaningfMRIName is OutputfMRIName and tICACleaningGroupAverageName is OutputfMRIName
sICAoutfolder="${tICACleaningFolder}/MNINonLinear/Results/${tICACleaningfMRIName}/sICA"

#functions so that we can do certain things across sessions in parallel
function sessionMaxBrainmask()
{
    local Session="$1"
    local subjMergeArgs=()
    for fMRIName in "${fMRINamesArray[@]}"
    do
        if [[ -f "${StudyFolder}/${Session}/MNINonLinear/Results/${fMRIName}/${fMRIName}${fMRIProcSTRING}.dtseries.nii" ]]
        then
            if [[ -f "${StudyFolder}/${Session}/MNINonLinear/Results/${fMRIName}/${fMRIName}_brain_mask.nii.gz" ]]
            then
                subjMergeArgs+=(-volume "${StudyFolder}/${Session}/MNINonLinear/Results/${fMRIName}/${fMRIName}_brain_mask.nii.gz")
            elif [[ -f "${StudyFolder}/${Session}/MNINonLinear/Results/${fMRIName}/brainmask_fs.${fMRIResolution}.nii.gz" ]]
            then
                subjMergeArgs+=(-volume "${StudyFolder}/${Session}/MNINonLinear/Results/${fMRIName}/brainmask_fs.${fMRIResolution}.nii.gz")
            else
                log_Err_Abort "Session $1 doesn't have a brainmask for run $fMRIName, please remove the ${fMRIName}${fMRIProcSTRING}.dtseries.nii file if processing was unsuccessful"
            fi
        fi
    done
    if ((${#subjMergeArgs[@]} <= 0))
    then
        log_Err_Abort "No valid fMRI runs found for session $1"
    fi
    wb_command -volume-merge "${StudyFolder}/${Session}/MNINonLinear/Results/brain_mask_all_${OutputfMRIName}.${fMRIResolution}.nii.gz" \
        "${subjMergeArgs[@]}"
    wb_command -volume-reduce "${StudyFolder}/${Session}/MNINonLinear/Results/brain_mask_all_${OutputfMRIName}.${fMRIResolution}.nii.gz" \
        MAX \
        "${StudyFolder}/${Session}/MNINonLinear/Results/brain_mask_max_${OutputfMRIName}.${fMRIResolution}.nii.gz"
    #remove this early rather than waiting for tempfiles to clean up
    rm -f "${StudyFolder}/${Session}/MNINonLinear/Results/brain_mask_all_${OutputfMRIName}.${fMRIResolution}.nii.gz"
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
                --subject-list="$SesslistRaw" \
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

            #now we have the dimensionality, set the output string
            OutputString="$OutputfMRIName"_d"$sICAActualDim"_WF"$numWisharts"_"$tICACleaningGroupAverageName""$extraSuffixSTRING"

            ;;
        (indProjSICA)
            #generate volume template cifti
            #use parallel and do sessions separately first to reduce memory (some added IO)

            #in REUSE_TICA mode, VolumeTemplateFile may point to an existing file in the precomputed folder, don't try to write to it if so
            #side effect: only computes the brainmask on first run in REUSE_TICA mode when resolution doesn't match
            if [[ "$tICAmode" != "USE" || ! -f "$VolumeTemplateFile" ]]
            then
                mergeArgs=()
                for Session in "${Sesslist[@]}"
                do
                    tempfiles_add "${StudyFolder}/${Session}/MNINonLinear/Results/brain_mask_all_${OutputfMRIName}.${fMRIResolution}.nii.gz" \
                        "${StudyFolder}/${Session}/MNINonLinear/Results/brain_mask_max_${OutputfMRIName}.${fMRIResolution}.nii.gz"
                    #this function is above the stepInd loop
                    par_addjob sessionMaxBrainmask "$Session"
                    mergeArgs+=(-volume "${StudyFolder}/${Session}/MNINonLinear/Results/brain_mask_max_${OutputfMRIName}.${fMRIResolution}.nii.gz")
                done
                par_runjobs "$parLimit"

                tempfiles_add "${StudyFolder}/${GroupAverageName}/MNINonLinear/brain_mask_all_${OutputfMRIName}.${fMRIResolution}.nii.gz" \
                    "${StudyFolder}/${GroupAverageName}/MNINonLinear/${GroupAverageName}_CIFTIVolumeTemplate_${OutputfMRIName}.${fMRIResolution}.txt" \
                    "${StudyFolder}/${GroupAverageName}/MNINonLinear/brain_mask_label_${OutputfMRIName}.${fMRIResolution}.nii.gz"

                    #"${StudyFolder}/${GroupAverageName}/MNINonLinear/brain_mask_max_${OutputfMRIName}.${fMRIResolution}.nii.gz" \ should be kept for feature processing
                wb_command -volume-merge "${StudyFolder}/${GroupAverageName}/MNINonLinear/brain_mask_all_${OutputfMRIName}.${fMRIResolution}.nii.gz" \
                    "${mergeArgs[@]}"
                wb_command -volume-reduce "${StudyFolder}/${GroupAverageName}/MNINonLinear/brain_mask_all_${OutputfMRIName}.${fMRIResolution}.nii.gz" \
                    MAX \
                    "${StudyFolder}/${GroupAverageName}/MNINonLinear/brain_mask_max_${OutputfMRIName}.${fMRIResolution}.nii.gz"
                #this is a big file, don't keep it around
                rm -f "${StudyFolder}/${GroupAverageName}/MNINonLinear/brain_mask_all_${OutputfMRIName}.${fMRIResolution}.nii.gz"
                echo $'OTHER\n1 255 255 255 255' > "${StudyFolder}/${GroupAverageName}/MNINonLinear/${GroupAverageName}_CIFTIVolumeTemplate_${OutputfMRIName}.${fMRIResolution}.txt"
                wb_command -volume-label-import "${StudyFolder}/${GroupAverageName}/MNINonLinear/brain_mask_max_${OutputfMRIName}.${fMRIResolution}.nii.gz" \
                    "${StudyFolder}/${GroupAverageName}/MNINonLinear/${GroupAverageName}_CIFTIVolumeTemplate_${OutputfMRIName}.${fMRIResolution}.txt" \
                    "${StudyFolder}/${GroupAverageName}/MNINonLinear/brain_mask_label_${OutputfMRIName}.${fMRIResolution}.nii.gz"
                wb_command -cifti-create-dense-scalar "$VolumeTemplateFile" \
                    -volume "${StudyFolder}/${GroupAverageName}/MNINonLinear/brain_mask_max_${OutputfMRIName}.${fMRIResolution}.nii.gz" \
                        "${StudyFolder}/${GroupAverageName}/MNINonLinear/brain_mask_label_${OutputfMRIName}.${fMRIResolution}.nii.gz"
            fi

            for Session in "${Sesslist[@]}"
            do
                if [[ "$MRFixConcatName" != "" ]]
                then
                    fMRINamesForSub="$MRFixConcatName"
                else
                    #build list of fMRI files, can either be generated by a function or just like this
                    fMRIExist=()
                    for fMRIName in "${fMRINamesArray[@]}"
                    do
                        if [[ -f "${StudyFolder}/${Session}/MNINonLinear/Results/${fMRIName}/${fMRIName}${fMRIProcSTRING}.dtseries.nii" ]]
                        then
                            fMRIExist+=("${fMRIName}")
                        fi
                    done
                    fMRINamesForSub=$(IFS='@'; echo "${fMRIExist[*]}")
                fi
                #queue (local) parallel job
                par_addjob "$HCPPIPEDIR"/global/scripts/RSNregression.sh \
                    --study-folder="$StudyFolder" \
                    --subject="$Session" \
                    --group-maps="${sICAoutfolder}/melodic_oIC_${sICAActualDim}.dscalar.nii" \
                    --subject-timeseries="$fMRINamesForSub" \
                    --surf-reg-name="$RegName" \
                    --low-res="$LowResMesh" \
                    --proc-string="${fMRIProcSTRING/_Atlas${RegString}/}" \
                    --method=weighted \
                    --low-ica-dims="$LowsICADims" \
                    --low-ica-template-name="$sICAoutfolder/melodic_oIC_REPLACEDIM.dscalar.nii" \
                    --output-string="$OutputString" \
                    --output-spectra="$sessionExpectedTimepoints" \
                    --volume-template-cifti="$VolumeTemplateFile" \
                    --output-z=1 \
                    --fix-legacy-bias="$FixLegacyBias" \
                    --scale-factor=0.01 \
                    --matlab-run-mode="$MatlabMode"
            done
            #run the jobs, this line also waits until they are complete
            par_runjobs "$parLimit"
            ;;
        (ConcatGroupSICA)
            if [[ "$sICAmode" != "ESTIMATE" ]]
            then
                mkdir -p "${StudyFolder}/${GroupAverageName}/MNINonLinear/Results/${OutputfMRIName}/sICA"
                cp "${tICACleaningFolder}/MNINonLinear/Results/${tICACleaningfMRIName}/sICA/iq_${sICAActualDim}.wb_annsub.csv" "${StudyFolder}/${GroupAverageName}/MNINonLinear/Results/${OutputfMRIName}/sICA/"
            fi
            "$HCPPIPEDIR"/tICA/scripts/ConcatGroupSICA.sh \
                --study-folder="$StudyFolder" \
                --subject-list="$SesslistRaw" \
                --out-folder="${StudyFolder}/${GroupAverageName}" \
                --fmri-concat-name="$OutputfMRIName" \
                --surf-reg-name="$RegName" \
                --ica-dim="$sICAActualDim" \
                --subject-expected-timepoints="$sessionExpectedTimepoints" \
                --low-res-mesh="$LowResMesh" \
                --sica-proc-string="${OutputString}_WR" \
                --matlab-run-mode="$MatlabMode"
            ;;
        (ComputeGroupTICA)
            #running this step in USE mode generates files in the output folder, which removes the need for a second OutputString to track the input naming for that mode
            tica_cmd=("$HCPPIPEDIR"/tICA/scripts/ComputeGroupTICA.sh
                        --study-folder="$StudyFolder"
                        --subject-list="$SesslistRaw"
                        --fmri-list="$fMRINames"
                        --out-folder="${StudyFolder}/${GroupAverageName}"
                        --fmri-concat-name="$OutputfMRIName"
                        --surf-reg-name="$RegName"
                        --ica-dim="$tICADim"
                        --subject-expected-timepoints="$sessionExpectedTimepoints"
                        --low-res-mesh="$LowResMesh"
                        --sica-proc-string="${OutputString}_WR"
                        --tICA-mode="$tICAmode"
                        --matlab-run-mode="$MatlabMode"
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
                tica_cmd+=(--tICA-mixing-matrix="$tICACleaningFolder/MNINonLinear/Results/$tICACleaningfMRIName/tICA_d$tICADim/melodic_mix_${tICADim}_tanhF")
            fi

            "${tica_cmd[@]}"

            ;;
        (indProjTICA)
            for Session in "${Sesslist[@]}"
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
                        if [[ -f "${StudyFolder}/${Session}/MNINonLinear/Results/${fMRIName}/${fMRIName}${fMRIProcSTRING}.dtseries.nii" ]]
                        then
                            fMRIExist+=("${fMRIName}")
                        fi
                    done
                    fMRINamesForSub=$(IFS='@'; echo "${fMRIExist[*]}")
                fi
    #Comment:
    #OutString=${OutputfMRIName}_d${sICAActualDim}_WF${numWisharts}_${GroupAverageName}_WR #OutString for --timeseries
    #if [ ${Method} == "single" ] ; then
       #Timeseries="${StudyFolder}/${Session}/MNINonLinear/fsaverage_LR32k/${Session}.${OutString}_${RegName}_ts.32k_fs_LR.sdseries.nii" #2.0mm Used this
    #fi
    #--output-string="${OutputfMRIName}_d${sICAActualDim}_WF${numWisharts}_${GroupAverageName}_WR_tICA" #This is correct
    #--group-maps is not needed

                par_addjob "$HCPPIPEDIR"/global/scripts/RSNregression.sh \
                    --study-folder="$StudyFolder" \
                    --subject="$Session" \
                    --timeseries="${StudyFolder}/${Session}/MNINonLinear/fsaverage_LR32k/${Session}.${OutputString}_WR_tICA${RegString}_ts.32k_fs_LR.sdseries.nii" \
                    --subject-timeseries="$fMRINamesForSub" \
                    --surf-reg-name="$RegName" \
                    --low-res="$LowResMesh" \
                    --proc-string="${fMRIProcSTRING/_Atlas${RegString}/}" \
                    --method=single \
                    --output-string="${OutputString}_WR_tICA" \
                    --output-spectra="$sessionExpectedTimepoints" \
                    --volume-template-cifti="$VolumeTemplateFile" \
                    --output-z=1 \
                    --fix-legacy-bias="$FixLegacyBias" \
                    --scale-factor=0.01 \
                    --matlab-run-mode="$MatlabMode"
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
            "$HCPPIPEDIR"/tICA/scripts/ComputeTICAFeatures.sh \
                --study-folder="$StudyFolder" \
                --out-group-name="$GroupAverageName" \
                --subject-list="$SesslistRaw" \
                --fmri-list="$fMRINames" \
                --fmri-output-name="$OutputfMRIName" \
                --ica-dim="$tICADim" \
                --proc-string="${fMRIProcSTRING/_Atlas${RegString}/}" \
                --tica-proc-string="${OutputString}_WR_tICA" \
                --fmri-resolution="$fMRIResolution" \
                --surf-reg-name="$RegName" \
                --low-res="$LowResMesh" \
                --melodic-high-pass="$HighPass" \
                --mrfix-concat-name="$MRFixConcatName" \
                --reclean-mode="$RecleanModeString" \
                --matlab-run-mode="$MatlabMode"
            ;;
        (ClassifyTICA)
            #REUSE_TICA mode shouldn't attempt this (or give an error)
            if [[ "$tICAmode" == "USE" ]]
            then
                #skip to next pipeline stage
                continue
            fi
            #don't abort for "not implemented", we still want it to write the config if possible
            log_Err "automated classification not currently implemented, please classify manually, then rerun with '--starting-step=CleanData'"
            break
            ;;
        (CleanData)
            if [[ "$NuisanceListTxt" == "" ]]
            then
                NuisanceListTxt="$tICACleaningFolder/MNINonLinear/Results/${tICACleaningfMRIName}/tICA_d${sICAActualDim}/Noise.txt"
            fi
            for Session in "${Sesslist[@]}"
            do
                #build list of fMRI files, can either be generated by a function or just like this
                fMRIExist=()
                for fMRIName in "${fMRINamesArray[@]}"
                do
                    if [[ -f "${StudyFolder}/${Session}/MNINonLinear/Results/${fMRIName}/${fMRIName}${fMRIProcSTRING}.dtseries.nii" ]]
                    then
                        fMRIExist+=("${fMRIName}")
                    fi
                done
                fMRINamesForSub=$(IFS='@'; echo "${fMRIExist[*]}")
                #for now, always do volume outputs
                par_addjob "$HCPPIPEDIR"/tICA/scripts/tICACleanData.sh \
                    --study-folder="$StudyFolder" \
                    --subject="$Session" \
                    --noise-list="$NuisanceListTxt" \
                    --timeseries="${StudyFolder}/${Session}/MNINonLinear/fsaverage_LR32k/${Session}.${OutputString}_WR_tICA${RegString}_ts.32k_fs_LR.sdseries.nii" \
                    --subject-timeseries="$fMRINamesForSub" \
                    --subject-concat-timeseries="$MRFixConcatName" \
                    --fix-high-pass="$HighPass" \
                    --surf-reg-name="$RegName" \
                    --low-res="$LowResMesh" \
                    --proc-string="${fMRIProcSTRING/_Atlas${RegString}/}" \
                    --output-string="${fMRIProcSTRING/_Atlas${RegString}/}_tclean" \
                    --do-vol=YES \
                    --fix-legacy-bias="$FixLegacyBias" \
                    --matlab-run-mode="$MatlabMode" \
                    --extract-fmri-name-list="$concatNamesToUse" \
                    --extract-fmri-out="$extractNameOut"
            done
            par_runjobs "$parLimit"
            ;;
        (*) #NOTE: this case MUST be last
            log_Err_Abort "internal error: unimplemented pipeline step '$stepName'"
            ;;
    esac
    log_Msg "step $stepName complete"
done

if [[ "$confoutfile" != "" ]]
then
    #copy actual dims to the override option that is used for REUSE modes
    #sICAActualDim could be unset if they do --stop-after-step=MIGP, so use this special construction
    sicadimOverride="${sICAActualDim+"${sICAActualDim}"}"
    opts_conf_WriteConfig "$confoutfile"
fi

if (( IsLongitudinal )); then
    #Split, group variance normalize and concatenate cleaned timeseries across all sessions, storing in longitudinal template output.
    #Also create averages across sessions for cleaned variance.
    "$HCPPIPEDIR"/tICA/scripts/tICAMakeCleanLongitudinalTemplate.sh \
        --study-folder="$StudyFolder"       \
        --subject="$Subject"                \
        --session-list="$SesslistRaw"       \
        --template-long="$TemplateLong"     \
        --extract-fmri-name-list="$concatNamesToUse" \
        --highpass="$HighPass"              \
        --extract-fmri-name="$extractNameOut" \
        --reg-name="$RegName"               \
        --fmri-name-concat-all="$extractNameAllLong" \
        --fmri-names="$fMRINames"
fi
