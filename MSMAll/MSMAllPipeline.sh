#!/bin/bash
set -eu

#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # MSMAllPipeline.sh
#
# ## Copyright Notice
#
# Copyright (C) 2015-2017 The Human Connectome Project
#
# * Washington University in St. Louis
# * University of Minnesota
# * Oxford University
#
# ## Author(s)
#
# * Matthew F. Glasser, Department of Anatomy and Neurobiology, Washington University in St. Louis
# * Timothy B. Brown, Neuroinformatics Research Group, Washington University in St. Louis
# * Mikhail Milchenko (longitudinal fix), Computational Imaging Center, Washington University in St. Louis
#
# ## Product
#
# [Human Connectome Project][HCP] (HCP) Pipelines
#
# ## License
#
# See the [LICENSE](https://github.com/Washington-Univesity/Pipelines/blob/master/LICENSE.md) file
#
# <!-- References -->
# [HCP]: http://www.humanconnectome.org
#
#~ND~END~

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"         # Debugging functions; also sources log.shlib
g_matlab_default_mode=1

#description to use in usage - syntax of parameters is now explained automatically
opts_SetScriptDescription "implements MSM-All Registration Pipeline"

#mandatory
#general inputs
opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder that contains all subjects" '--path'
opts_AddMandatory '--session' 'Session' '100206' "one session ID" "--subject"
opts_AddMandatory '--fmri-names-list' 'fMRINames' 'rfMRI_REST1_LR@rfMRI_REST1_RL...' "list of single-run fmri run names separated by @s"
opts_AddMandatory '--multirun-fix-names' 'mrfixNames' 'rfMRI_REST1_LR@rfMRI_REST1_RL...' "list of multi-run fmri run names separated by @s"
opts_AddMandatory '--multirun-fix-concat-name' 'mrfixConcatName' 'rfMRI_REST' "if multi-run FIX was used, you must specify the concat name with this option"
opts_AddMandatory '--multirun-fix-names-to-use' 'mrfixNamesToUse' 'rfMRI_REST1_LR@rfMRI_REST1_RL...' "MRfix run names to use, @-separated list, choose which runs should be used as resting state data"
opts_AddMandatory '--output-fmri-name' 'OutputfMRIName' 'rfMRI_REST' "name to give to concatenated single session scan"
opts_AddMandatory '--high-pass' 'HighPass' 'integer' 'the high pass value that was used when running FIX' '--melodic-high-pass'
opts_AddMandatory '--fmri-proc-string' 'fMRIProcSTRING' 'string' "file name component representing the preprocessing already done, e.g. '_Atlas_hp0_clean'"
opts_AddMandatory '--msm-all-templates' 'MSMAllTemplates' 'path' "path to directory containing MSM All template files, e.g. 'YourFolder/global/templates/MSMAll'"
opts_AddMandatory '--input-registration-name' 'InputRegName' 'MSMAll' "the registration string corresponding to the input files, e.g. 'MSMSulc'"
opts_AddMandatory '--output-registration-name' 'OutputRegName' 'MSMAll' "the registration string corresponding to the output files, e.g. 'MSMAll_InitialReg'"
opts_AddMandatory '--high-res-mesh' 'HighResMesh' 'meshnum' "high resolution mesh node count (in thousands), like '164' for 164k_fs_LR"
opts_AddMandatory '--low-res-mesh' 'LowResMesh' 'meshnum' "low resolution mesh node count (in thousands), like '32' for 32k_fs_LR"
opts_AddMandatory '--myelin-target-file' 'MyelinTarget' 'string' "myelin map target file, absolute folder, e.g. 'YourFolder/global/templates/MSMAll/Q1-Q6_RelatedParcellation210.MyelinMap_BC_MSMAll_2_d41_WRN_DeDrift.32k_fs_LR.dscalar.nii'"
#MSMAll inputs
opts_AddOptional '--module-name' 'ModuleName' 'string' "name of script or code used to run registration, defaults to 'MSMAll.sh'" 'MSMAll.sh'
opts_AddOptional '--iteration-modes' 'IterationModes' 'string' "Specifieds what modalities:
C=RSN Connectivity
A=Myelin Architecture
T=RSN Topography
and number is the number of elements delimited by _
So CA_CAT means one iteration using RSN Connectivity and Myelin
Architecture, followed by another iteration using RSN Connectivity,
Myelin Architecture, and RSN Topography. Defaults to 'CA_CAT'" \
    'CA_CAT'
opts_AddOptional '--method' 'Method' 'string' "Possible values: DR, DRZ, DRN, WR, WRZ, WRN, defaults to 'WRN'" 'WRN'
opts_AddOptional '--use-migp' 'UseMIGP' 'YES/NO' "whether to use MIGP (MELODIC's Incremental Group Principal Component Analysis), defaults to 'NO'" 'NO'
opts_AddOptional '--ica-dim' 'ICAdim' 'integer' "ICA (Independent Component Analysis) dimension, defaults to '40'" '40'
opts_AddOptional '--low-sica-dims' 'LowsICADims' 'num@num@num...' "the low sICA dimensionalities to use for determining weighting for individual projection, defaults to '7@8@9@10@11@12@13@14@15@16@17@18@19@20@21'" '7@8@9@10@11@12@13@14@15@16@17@18@19@20@21'
opts_AddOptional '--vn' 'VN' 'YES/NO' "whether to perform variance normalization, defaults to 'NO'" 'NO'
opts_AddOptional '--rerun-if-exists' 'ReRunIfExists' 'YES/NO' "whether to re-run even if output already exists, defaults to 'YES'" 'YES'
opts_AddOptional '--registration-configure-path' 'RegConfPath' 'string' "it can be either the relative path where the registration configuration exists in 'MSMCONFIGDIR', or an absolute path" 'MSMAllStrainFinalconf1to1_1to3'
opts_AddOptional '--registration-configure-override-variables' 'RegConfOverrideVars' 'string' "the registration configure variables to override instead of using the configuration file. Please use quotes, and space between parameters is not recommended. e.g. 'REGNUMBER=1,REGPOWER=3', defaults to 'NONE'" 'NONE'
opts_AddOptional '--rsn-template-file' 'RSNTemplates' 'string' "alternate rsn template file, relative to the --msm-all-templates folder" 'rfMRI_REST_Atlas_MSMAll_2_d41_WRN_DeDrift_hp2000_clean_PCA.ica_dREPLACEDIM_ROW_vn/melodic_oIC.dscalar.nii'
opts_AddOptional '--rsn-weights-file' 'RSNWeights' 'string' "alternate rsn weights file, relative to the --msm-all-templates folder" 'rfMRI_REST_Atlas_MSMAll_2_d41_WRN_DeDrift_hp2000_clean_PCA.ica_dREPLACEDIM_ROW_vn/Weights.txt'
opts_AddOptional '--topography-roi-file' 'TopographyROIs' 'string' "alternate topography roi file, relative to the --msm-all-templates folder" 'Q1-Q6_RelatedParcellation210.atlas_Topographic_ROIs.32k_fs_LR.dscalar.nii'
opts_AddOptional '--topography-target-file' 'TopographyTarget' 'string' "alternate topography target, relative to the --msm-all-templates folder" 'Q1-Q6_RelatedParcellation210.atlas_Topography.32k_fs_LR.dscalar.nii'
opts_AddOptional '--use-ind-mean' 'UseIndMean' 'YES or NO' "whether to use the mean of the individual myelin map as the group reference map's mean, defaults to 'YES'" 'YES'
opts_AddOptional '--start-frame' 'StartFrame' 'integer' "only applied for single runs when --fmri-names-list is not empty; the starting frame to choose from each fMRI run (inclusive), defaults to '1'" '1'
opts_AddOptional '--end-frame' 'EndFrame' 'integer' "only applied for single runs when --fmri-names-list is not empty; the ending frame to choose from each fMRI run (inclusive), defaults to '' which will be overrided by the minimum frame length across the given list of fMRI runs" ''
opts_AddOptional '--matlab-run-mode' 'MatlabRunMode' '0, 1, or 2' "defaults to $g_matlab_default_mode
0 = compiled MATLAB
1 = interpreted MATLAB
2 = Octave" "$g_matlab_default_mode"

#longitudinal options
opts_AddOptional '--is-longitudinal' 'IsLongitudinal' 'TRUE or FALSE' "longitudinal mode" "FALSE"
opts_AddOptional '--subject-long' 'SubjectLong' 'id' "subject ID in longitudinal mode" ""
opts_AddOptional '--sessions-long' 'Sessions' 'list' "@ separated list of longitudinal timepoints" ""
opts_AddOptional '--template-long' 'TemplateLong' 'template_id' "longitudinal template ID" ""
opts_AddOptional '--fmri-out-config-file' 'OutConfig' 'file name' 'Output file with detected fMRI run configuration [fmri_list.txt].
Specify file name only, without path. The file will be stored under [Session]/MNINonLinear/Results folder.' "fmri_list.txt"
opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

# Verify required environment variables are set and log value
log_Check_Env_Var HCPPIPEDIR
log_Check_Env_Var MSMCONFIGDIR

#display HCP Pipeline version
log_Msg "Showing HCP Pipelines version"
"${HCPPIPEDIR}"/show_version --short

#display the parsed/default values
opts_ShowValues

# ------------------------------------------------------------------------------
#  Main processing of script.
# ------------------------------------------------------------------------------
log_Msg "Starting main functionality"
# default file names
# MSMAll config file
if [[ "$RegConfPath" != /* ]]
then
    RegConfPath="${MSMCONFIGDIR}/${RegConfPath}"
fi
log_Msg "RegConfPath: ${RegConfPath}"
# MSMAll templates defaults
log_File_Must_Exist "${MyelinTarget}"
RSNTemplates="${MSMAllTemplates}/${RSNTemplates}"
log_Msg "RSNTemplates: ${RSNTemplates}"
RSNWeights="${MSMAllTemplates}/${RSNWeights}"
log_Msg "RSNWeights: ${RSNWeights}"
TopographyROIs="${MSMAllTemplates}/${TopographyROIs}"
log_File_Must_Exist "${TopographyROIs}"
TopographyTarget="${MSMAllTemplates}/${TopographyTarget}"
log_File_Must_Exist "${TopographyTarget}"

# Naming Conventions and other variables
output_proc_string="_vn" #To VN only to indicate that we did not revert the bias field before computing VN
log_Msg "output_proc_string: ${output_proc_string}"

IsLongitudinal=$(opts_StringToBool "$IsLongitudinal")
NumIterations=$(echo "${IterationModes}" | sed 's/_/ /g' | wc -w)
DeDriftRegName=${OutputRegName}_${NumIterations}_d${ICAdim}_${Method}

if (( IsLongitudinal ));  then

    if [[ -z "$SubjectLong" || -z "$Sessions" || -z "$TemplateLong" || -z "${mrfixNamesToUse}" || -z "$mrfixConcatName" ]]; then
        log_Err_Abort "--subject-long, --sessions-long, --template-long are mandatory in longitudinal mode"
    fi

    IFS=@ read -r -a SessionsLong <<< "${Sessions}"
    IFS=@ read -r -a PossibleRuns <<< "${mrfixNamesToUse}"

    ResultsTemplateDir=$StudyFolder/$SubjectLong.long.$TemplateLong/MNINonLinear/Results

    expected_concatenated_output_dir="$ResultsTemplateDir/${OutputfMRIName}"
    expected_concatenated_output_file="${expected_concatenated_output_dir}/${OutputfMRIName}${fMRIProcSTRING}${output_proc_string}.dtseries.nii"
    before_vn_output_file="${expected_concatenated_output_dir}/${OutputfMRIName}${fMRIProcSTRING}_novn.dtseries.nii"

    mkdir -p $ResultsTemplateDir
    TemplateRunsStr=""
    TimepointsStr=""
    fMRIRunsStr=""
    ConcatNamesStr=""

    # First, resolve the list of longitudinal fMRI runs and make configuration file
    TemplateSession=$SubjectLong.long.$TemplateLong             #template directory name
    NativeMyelinMap="MyelinMap.native.dscalar.nii"
    # Build the average myelin map command.
    average_cmd=("${CARET7DIR}/wb_command" -cifti-average \
        "$StudyFolder/$TemplateSession/MNINonLinear/Native/$TemplateSession.$NativeMyelinMap")

    for tp in "${SessionsLong[@]}"; do
        SessionLong=$tp.long.$TemplateLong                      #longitudinal session directory name
        average_cmd+=(-cifti "$StudyFolder/$SessionLong/MNINonLinear/Native/$SessionLong.$NativeMyelinMap")

        echo "searching $SessionLong for eligible fMRI runs"
        if [ ! -d "$StudyFolder/$SessionLong/MNINonLinear/Results" ]; then
            log_Err_Abort "ICAFix output does not exist for longitudinal session $SessionLong in $StudyFolder"
        fi
        ResultsTPLongDir=$StudyFolder/$SessionLong/MNINonLinear/Results
        # iterate over possible fMRI runs and build a list of found runs for this timepoint.
        # Found runs are copied to template directory and all relevant files/dirs are renamed
        # for the run to be unique within subject.
        # template-based fMRI naming pattern, assuming original run <fMRIRun> label is: <Session>_<fMRIRun>,
        # where <Session> is longitudinal session label. It is expected to be named <Subject>_<Visit_ID>.
        for fmriName in "${PossibleRuns[@]}"; do
            if [ -d "$ResultsTPLongDir/$fmriName" ]; then
                TemplateRun=${tp}_${fmriName}
                echo "found $TemplateRun, copying"
                mkdir -p "$ResultsTemplateDir/$TemplateRun"
                #bulk copy
                cp -r "$ResultsTPLongDir/$fmriName"/* "$ResultsTemplateDir/$TemplateRun/"
                pushd "$ResultsTemplateDir/${TemplateRun}" &> /dev/null
                for fd in ${fmriName}_* ${fmriName}.*; do
                    if [[ -e "$fd" ]]
                    then
                        if [[ -e "${fd//$fmriName/$TemplateRun}" ]]; then
                            rm -rf "${fd//$fmriName/$TemplateRun}"
                        fi
                        mv "$fd" "${fd//$fmriName/$TemplateRun}"
                    fi
                done
                popd &> /dev/null
                TemplateRunsStr="${TemplateRunsStr}@$TemplateRun"
                TimepointsStr="${TimepointsStr}@$tp"
                fMRIRunsStr="${fMRIRunsStr}@$fmriName"
                ConcatNamesStr="${ConcatNamesStr}@$mrfixConcatName"
            fi
        done
    done
    # Arrays with template fMRI names, matching timepoint labels, original run labels,
    # and per-timepoint concatenated fMRI names are stored in a configuration file under
    # MNINonLinear/Results/. Multiple configuration files may be used for the same
    # subject with different fMRI combinations or longitudinal templates.
    conf_file="$ResultsTemplateDir/$OutConfig"
    echo "${TemplateRunsStr#@}" > "$conf_file"
    echo "${TimepointsStr#@}" >> "$conf_file"
    echo "${fMRIRunsStr#@}" >> "$conf_file"
    echo "${ConcatNamesStr#@}" >> "$conf_file"

    # average myelin maps from all timepoints.
    "${average_cmd[@]}"

    # variance normalize and concatenate individual rsFMRI runs
    # of all timepoints in template folder.
    # This script reads the $conf_file.
    "${HCPPIPEDIR}"/MSMAll/scripts/SingleSubjectConcat.sh \
        --path="${StudyFolder}" \
        --subject="$SubjectLong.long.$TemplateLong" \
        --fmri-names-list="${TemplateRunsStr/#@/}" \
        --output-fmri-name="${OutputfMRIName}" \
        --fmri-proc-string="${fMRIProcSTRING}" \
        --output-proc-string="${output_proc_string}" \
        --start-frame="${StartFrame}" \
        --end-frame="${EndFrame}" \
        --is-longitudinal="TRUE" \
        --fmri-config-long="$OutConfig" \
        --template-long="$TemplateLong" \
        --subject-long="$SubjectLong"
    Session=$TemplateSession
    # log_Msg "Running MSM on longitudinal timepoints"

else #cross-sectional run
    expected_concatenated_output_dir="${StudyFolder}/${Session}/MNINonLinear/Results/${OutputfMRIName}"
    expected_concatenated_output_file="${expected_concatenated_output_dir}/${OutputfMRIName}${fMRIProcSTRING}${output_proc_string}.dtseries.nii"
    before_vn_output_file="${expected_concatenated_output_dir}/${OutputfMRIName}${fMRIProcSTRING}_novn.dtseries.nii"

    if [[ "$fMRINames" == "" ]]
    then
        log_Msg "Running MSM on Multi-run FIX timeseries"
        runSplits=()
        runIndices=()
        curTimepoints=0
        #convention: one before the first index of the run
        runSplits[0]="$curTimepoints"
        IFS='@' read -a mrNamesArray <<< "${mrfixNames}"
        IFS='@' read -a mrNamesUseArray <<< "${mrfixNamesToUse}"
        #sanity check for identical names
        for ((index = 0; index < ${#mrNamesArray[@]}; ++index))
        do
            for ((index2 = 0; index2 < ${#mrNamesArray[@]}; ++index2))
            do
                if ((index != index2)) && [[ "${mrNamesArray[$index]}" == "${mrNamesArray[$index2]}" ]]
                then
                    log_Err_Abort "MR fix names list contains '${mrNamesArray[$index]}' more than once"
                fi
            done
        done
        #calculate the timepoints where the concatenated switches runs, find which runs are used
        for ((index = 0; index < ${#mrNamesArray[@]}; ++index))
        do
            fmriName="${mrNamesArray[$index]}"
            NumTPS=$(${CARET7DIR}/wb_command -file-information "${StudyFolder}/${Session}/MNINonLinear/Results/${fmriName}/${fmriName}_Atlas.dtseries.nii" -only-number-of-maps)
            curTimepoints=$((curTimepoints + NumTPS))
            runSplits[$((index + 1))]="$curTimepoints"
            for ((index2 = 0; index2 < ${#mrNamesUseArray[@]}; ++index2))
            do
                if [[ "${mrNamesUseArray[$index2]}" == "${mrNamesArray[$index]}" ]]
                then
                    runIndices[$index2]="$index"
                fi
            done
        done
        #check that we found all requested runs, build the merge command
        mergeArgs=()
        for ((index2 = 0; index2 < ${#mrNamesUseArray[@]}; ++index2))
        do
            #element may be unset
            runIndex="${runIndices[$index2]+"${runIndices[$index2]}"}"
            if [[ "$runIndex" == "" ]]
            then
                log_Err_Abort "requested run '${mrNamesUseArray[$index2]}' not found in list of MR fix runs"
            fi
            mergeArgs+=(-column $((runSplits[runIndex] + 1)) -up-to $((runSplits[runIndex + 1])) )
        done
        mkdir -p "${expected_concatenated_output_dir}"
        ${CARET7DIR}/wb_command -cifti-merge "${before_vn_output_file}" -cifti "${StudyFolder}/${Session}/MNINonLinear/Results/${mrfixConcatName}/${mrfixConcatName}_Atlas_hp${HighPass}_clean.dtseries.nii" "${mergeArgs[@]}"
        ${CARET7DIR}/wb_command -cifti-math 'data / variance' "${expected_concatenated_output_file}" -var data "${before_vn_output_file}" -var variance "${StudyFolder}/${Session}/MNINonLinear/Results/${mrfixConcatName}/${mrfixConcatName}_Atlas_hp${HighPass}_clean_vn.dscalar.nii" -select 1 1 -repeat
        rm -f -- "${before_vn_output_file}"
    else
        log_Msg "Running MSM on full timeseries"

        "${HCPPIPEDIR}"/MSMAll/scripts/SingleSubjectConcat.sh \
            --path="${StudyFolder}" \
            --subject="${Session}" \
            --fmri-names-list="${fMRINames}" \
            --output-fmri-name="${OutputfMRIName}" \
            --fmri-proc-string="${fMRIProcSTRING}" \
            --output-proc-string="${output_proc_string}" \
            --start-frame="${StartFrame}" \
            --end-frame="${EndFrame}"
    fi
fi #cross-sectional mode

log_File_Must_Exist "${expected_concatenated_output_file}"

# fMRIProcSTRING now should reflect the name expected by registrations done below
# (e.g. MSMAll)
fMRIProcSTRING+="${output_proc_string}"
log_Msg "fMRIProcSTRING: ${fMRIProcSTRING}"

# run MSMAll
"${HCPPIPEDIR}"/MSMAll/scripts/"${ModuleName}" \
    --path="${StudyFolder}" \
    --session="${Session}" \
    --high-res-mesh="${HighResMesh}" \
    --low-res-mesh="${LowResMesh}" \
    --output-fmri-name="${OutputfMRIName}" \
    --fmri-proc-string="${fMRIProcSTRING}" \
    --input-pca-registration-name="${InputRegName}" \
    --input-registration-name="${InputRegName}" \
    --registration-name-stem="${OutputRegName}" \
    --rsn-target-file="${RSNTemplates}" \
    --rsn-cost-weights="${RSNWeights}" \
    --myelin-target-file="${MyelinTarget}" \
    --topography-roi-file="${TopographyROIs}" \
    --topography-target-file="${TopographyTarget}" \
    --iterations="${IterationModes}" \
    --method="${Method}" \
    --use-migp="${UseMIGP}" \
    --ica-dim="${ICAdim}" \
    --regression-params="${LowsICADims}" \
    --vn="${VN}" \
    --rerun="${ReRunIfExists}" \
    --reg-conf="${RegConfPath}" \
    --reg-conf-vars="${RegConfOverrideVars}" \
    --msm-all-templates="${MSMAllTemplates}" \
    --use-ind-mean="${UseIndMean}" \
    --matlab-run-mode="${MatlabRunMode}"

# 1. copy the registration result sphere from template back to timepoints.
# 2. generate some extra files for timepoints. Those files (as of 4/2025) are created by MSMAll.sh in cross-sectional mode.
if (( IsLongitudinal )); then
    for tp in "${SessionsLong[@]}"; do
        SessionLong=$tp.long.$TemplateLong
        NativeFolderTP="$StudyFolder"/"$SessionLong"/MNINonLinear/Native
        AtlasFolderTP="$StudyFolder"/"$SessionLong"/MNINonLinear
        DownsampleFolderTP="$AtlasFolderTP/fsaverage_LR${LowResMesh}k"

        for Hemisphere in L R; do
            # Copy the reg sphere
            cp "$StudyFolder/$TemplateSession/MNINonLinear/Native/$TemplateSession.$Hemisphere.sphere.${DeDriftRegName}.native.surf.gii" "$StudyFolder/$SessionLong/MNINonLinear/Native/$SessionLong.$Hemisphere.sphere.${DeDriftRegName}.native.surf.gii"

            ${CARET7DIR}/wb_command -surface-vertex-areas ${NativeFolderTP}/${SessionLong}.${Hemisphere}.midthickness.native.surf.gii ${NativeFolderTP}/${SessionLong}.${Hemisphere}.midthickness.native.shape.gii
            ${CARET7DIR}/wb_command -surface-vertex-areas ${NativeFolderTP}/${SessionLong}.${Hemisphere}.sphere.native.surf.gii ${NativeFolderTP}/${SessionLong}.${Hemisphere}.sphere.native.shape.gii

            ${CARET7DIR}/wb_command -metric-math "ln(sphere / midthickness) / ln(2)" ${NativeFolderTP}/${SessionLong}.${Hemisphere}.SphericalDistortion.native.shape.gii -var midthickness ${NativeFolderTP}/${SessionLong}.${Hemisphere}.midthickness.native.shape.gii -var sphere ${NativeFolderTP}/${SessionLong}.${Hemisphere}.sphere.native.shape.gii
            rm ${NativeFolderTP}/${SessionLong}.${Hemisphere}.midthickness.native.shape.gii ${NativeFolderTP}/${SessionLong}.${Hemisphere}.sphere.native.shape.gii
        done

        # generate some extra files for time points. Those files (as of 4/2025) are created by MSMAll.sh in cross-sectional mode
        ${CARET7DIR}/wb_command -cifti-create-dense-timeseries ${NativeFolderTP}/${SessionLong}.SphericalDistortion.native.dtseries.nii -left-metric ${NativeFolderTP}/${SessionLong}.L.SphericalDistortion.native.shape.gii -roi-left ${NativeFolderTP}/${SessionLong}.L.atlasroi.native.shape.gii -right-metric ${NativeFolderTP}/${SessionLong}.R.SphericalDistortion.native.shape.gii -roi-right ${NativeFolderTP}/${SessionLong}.R.atlasroi.native.shape.gii

        ${CARET7DIR}/wb_command -cifti-convert-to-scalar ${NativeFolderTP}/${SessionLong}.SphericalDistortion.native.dtseries.nii ROW ${NativeFolderTP}/${SessionLong}.SphericalDistortion.native.dscalar.nii
        ${CARET7DIR}/wb_command -set-map-name ${NativeFolderTP}/${SessionLong}.SphericalDistortion.native.dscalar.nii 1 ${SessionLong}_SphericalDistortion
        ${CARET7DIR}/wb_command -cifti-palette ${NativeFolderTP}/${SessionLong}.SphericalDistortion.native.dscalar.nii MODE_USER_SCALE ${NativeFolderTP}/${SessionLong}.SphericalDistortion.native.dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false
        rm ${NativeFolderTP}/${SessionLong}.SphericalDistortion.native.dtseries.nii
    done
fi
log_Msg "Completing main functionality"
