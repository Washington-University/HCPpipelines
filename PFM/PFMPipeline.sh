cd #!/bin/bash
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

# add steps to this array and in the switch cases below
pipelineSteps=(RunPROFUMO PostPROFUMO RSNRegression GroupPFMs)
defaultStart="${pipelineSteps[0]}"
defaultStopAfter="${pipelineSteps[${#pipelineSteps[@]} - 1]}"
stepsText="$(IFS=$'\n'; echo "${pipelineSteps[*]}")"

#description to use in usage
opts_SetScriptDescription "implements complete PFM pipeline with four main steps: Run PROFUMO, Post-PROFUMO, RSN Regression, and Group PFM processing"

#mandatory parameters
opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder that contains all subjects"
opts_AddMandatory '--subject-list' 'SubjlistRaw' '100206@100307...' "list of subject IDs separated by @s"
opts_AddMandatory '--fmri-names' 'fMRINames' 'rfMRI_REST1_LR@rfMRI_REST1_RL...' "list of fmri run names separated by @s"
opts_AddMandatory '--output-fmri-name' 'OutputfMRIName' 'rfMRI_REST' "name to use for PFM pipeline outputs"
opts_AddMandatory '--output-string' 'OutputSTRING' 'string' "output string for individual subject files (typically includes dimension, group name, and seed)"
opts_AddMandatory '--proc-string' 'fMRIProcSTRING' 'string' "file name component representing the preprocessing already done, e.g. '_Atlas_MSMAll_hp0_clean_tclean'"
opts_AddMandatory '--group-average-name' 'GroupAverageName' 'string' 'name to use for the group output folder'
opts_AddMandatory '--pfm-dimension' 'PFMdim' 'integer' "PFM dimensionality (e.g., 76, 92, 65)"
opts_AddMandatory '--pfm-folder' 'PFMFolder' 'path' "path to PFM results folder containing Results.ppp"
opts_AddMandatory '--surf-reg-name' 'RegName' 'MSMAll' "the registration string corresponding to the input files"
opts_AddMandatory '--profumo-config' 'ProfumoConfig' 'path' "path to PROFUMO JSON configuration file"
opts_AddMandatory '--profumo-tr' 'TR' "seconds" "repetition time for PROFUMO analysis"
opts_AddMandatory '--ref-image' 'RefImage' 'path' "reference image for PROFUMO postprocessing"
opts_AddMandatory '--runs-timepoints' 'RunsXNumTimePoints' "total timepoints across runs" "total timepoints across runs"
opts_AddMandatory '--concat-name' 'ConcatName' "concatenated fMRI name if using multi-run data" ''
opts_AddMandatory '--volume-template-file' 'VolumeTemplateFile' "volume template file path" ''

#PROFUMO specific parameters
opts_AddOptional '--profumo-threads' 'ProfumoThreads' 'integer' "number of threads for PROFUMO" '-1'
opts_AddOptional '--profumo-dof-correction' 'DOFCorrection' 'float' "DOF correction for PROFUMO" '0.5'
opts_AddOptional '--profumo-cov-model' 'CovModel' 'string' "covariance model for PROFUMO" 'Subject'
opts_AddOptional '--profumo-singularity' 'ProfumoSingularity' 'path' "path to PROFUMO singularity container"
opts_AddOptional '--profumo-random-seed' 'RandomSeed' 'integer' "random seed for PROFUMO" '123'
opts_AddOptional '--profumo-multi-start-iterations' 'MultiStartIterations' 'integer' "number of iterations of group-level spatial decomposition before inferring full model" '5'
opts_AddOptional '--profumo-initial-maps' 'InitialMaps' 'path' "file to initialise the decomposition based on spatial maps"
opts_AddOptional '--profumo-load-sequentially' 'LoadSequentially' 'YES or NO' "load data sequentially in PROFUMO (useful for memory management)" 'YES'
opts_AddOptional '--num-wishart' 'NumWishart' 'integer' "number of Wishart filter iterations for prefiltering (0 to skip)" '0'
opts_AddOptional '--keep-wishart-files' 'KeepWishartFiles' 'YES or NO' "keep Wishart-filtered files after PROFUMO instead of deleting (default NO)" 'NO'
opts_AddOptional '--variance-normalization' 'VarNorm' 'YES or NO' "Variance normalize Wishart-filtered data before PROFUMO (default NO)" 'NO'
opts_AddOptional '--weight-vertex-areas' 'VAweight' 'YES or NO' "Weight Wishart-filtered data by vertex areas for PROFUMO (default NO)" 'NO'

#optional parameters
opts_AddOptional '--low-res-mesh' 'LowResMesh' 'string' "mesh resolution, like '32' for 32k_fs_LR" '32'

#RSN regression specific parameters
opts_AddOptional '--fix-legacy-bias' 'FixLegacyBias' 'YES or NO' 'whether the input data used legacy bias correction' 'NO'
opts_AddOptional '--scale-factor' 'ScaleFactor' 'float' 'scale factor for RSN regression' '0.01'


#general settings
opts_AddOptional '--starting-step' 'startStep' 'step' "what step to start processing at, one of:
$stepsText" "$defaultStart"
opts_AddOptional '--stop-after-step' 'stopAfterStep' 'step' "what step to stop processing after, same valid values as --starting-step" "$defaultStopAfter"
opts_AddOptional '--parallel-limit' 'parLimit' 'integer' "set how many subjects to do in parallel during RSN regression, defaults to all detected physical cores" '-1'
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

if [[ "$ProfumoThreads" == "-1" ]]; then
    ProfumoThreads=$(par_numphys)
fi  

#processing code goes here
IFS='@' read -a Subjlist <<<"$SubjlistRaw"
IFS='@' read -a fMRINamesArray <<<"$fMRINames"

FixLegacyBiasBool=$(opts_StringToBool "$FixLegacyBias")
KeepWishartBool=$(opts_StringToBool "$KeepWishartFiles")
VarNormBool=$(opts_StringToBool "$VarNorm")
VAweightBool=$(opts_StringToBool "$VAweight")

if ! [[ "$parLimit" == "-1" || "$parLimit" =~ [1-9][0-9]* ]]
then
    log_Err_Abort "--parallel-limit must be a positive integer or -1, provided value: '$parLimit'"
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

RegString=""
if [[ "$RegName" != "" ]]
then
    RegString="_$RegName"
fi


for ((stepInd = startInd; stepInd <= stopAfterInd; ++stepInd))
do
    stepName="${pipelineSteps[stepInd]}"
    case "$stepName" in
        (RunPROFUMO)
            log_Msg "Running PROFUMO analysis step"
            
            # Validate required PROFUMO parameters
            if [[ "$ProfumoConfig" == "" ]]
            then
                log_Err_Abort "PROFUMO config file must be specified with --profumo-config"
            fi
            if [[ "$ProfumoSingularity" == "" ]]
            then
                log_Err_Abort "PROFUMO singularity container must be specified with --profumo-singularity"
            fi
            if [[ "$RefImage" == "" ]]
            then
                log_Err_Abort "Reference image must be specified with --ref-image"
            fi
            
            ProfumoConfigToUse="${ProfumoConfig}"
            if [[ "$NumWishart" -gt 0 ]]
            then
                WFDir="${PFMFolder}/WishartFilter_WF${NumWishart}"
                # Check if WF files already exist
                wfComplete=true
                for Subject in "${Subjlist[@]}"
                do
                    for fMRIName in "${fMRINamesArray[@]}"
                    do
                        inputFile="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegString}_${fMRIProcSTRING}.dtseries.nii"
                        wfFile="${WFDir}/${Subject}/${fMRIName}_Atlas${RegString}_${fMRIProcSTRING}_WF.dtseries.nii"
                        if [[ -f "$inputFile" ]] && [[ ! -f "$wfFile" ]]
                        then
                            wfComplete=false
                            break 2
                        fi
                    done
                done
                
                if $wfComplete && [[ $KeepWishartBool == 1 ]]; then
                    log_Msg "WF files already exist in ${WFDir}"
                else
                    log_Msg "Running Wishart filtering with ${NumWishart} iterations"
                    for Subject in "${Subjlist[@]}"
                    do
                        mkdir -p "${WFDir}/${Subject}"
                        
                        if [[ "$ConcatName" != "" ]] # multi_run data
                        then
                            # Use already concatenated file
                            concatFile="${StudyFolder}/${Subject}/MNINonLinear/Results/${ConcatName}/${ConcatName}_Atlas${RegString}_${fMRIProcSTRING}.dtseries.nii"
                            clean_VN="${StudyFolder}/${Subject}/MNINonLinear/Results/${ConcatName}/${ConcatName}_Atlas${RegString}_${fMRIProcSTRING}_vn.dscalar.nii"
                            concatOutFile="${WFDir}/${Subject}/${ConcatName}_Atlas${RegString}_${fMRIProcSTRING}_WF.dtseries.nii"
                            if [[ -f "$concatFile" ]]
                            then
                                log_Msg "Applying Wishart filter to concat file for subject $Subject"
                                "$HCPPIPEDIR"/PFM/scripts/ApplyWFProfumo.sh \
                                    --input="$concatFile" \
                                    --output="$concatOutFile" \
                                    --num-wishart="$NumWishart" \
                                    --matlab-run-mode="$MatlabMode"
                                                                
                                # Split back into individual runs and restore means
                                cumTP=0
                                for fMRIName in "${fMRINamesArray[@]}"
                                do
                                    origFile="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegString}_${fMRIProcSTRING}.dtseries.nii"
                                    if [[ -f "$origFile" ]]
                                    then
                                        nTP=$(wb_command -file-information "$origFile" -only-number-of-maps)
                                        startIdx=$((cumTP + 1))
                                        endIdx=$((cumTP + nTP))
                                        outFile="${WFDir}/${Subject}/${fMRIName}_Atlas${RegString}_${fMRIProcSTRING}_WF.dtseries.nii"
                                        wb_command -cifti-merge "$outFile" -direction ROW -cifti "$concatOutFile" -index "$startIdx" -up-to "$endIdx" # naive splitting
                                        
                                        ## The concatenated timeseries are intensity normalized and differences in unstructured noise variance between runs and the means have been removed.  For model-free analyses (i.e., not task-GLM) that prefer single runs, it is best to simply deconcatenate the runs.  If variance normalization is desired, use the same _clean_vn file from the concatenated folder for each run, rather than the original _vn files, which may cause extreme values in areas of little or no signal and require more complex handling.
                                        if [[ "$VarNormBool" == 1 ]];then
                                          wb_command -cifti-math "(TCS / clean_VN)" ${outFile} \
                                            -var TCS ${outFile} \
                                            -var clean_VN ${clean_VN} -select 1 1 -repeat
                                        fi

                                        if [[ "$VAweightBool" == 1 ]];then
                                          log_Msg "Weighting data by average vertex areas"
                                          VA=${StudyFolder}/${Subject}/MNINonLinear/fsaverage_LR${LowResMesh}k/${Subject}.midthickness_va.${LowResMesh}k_fs_LR.dscalar.nii
                                          VAgray=${StudyFolder}/${Subject}/MNINonLinear/fsaverage_LR${LowResMesh}k/${Subject}.midthickness_va.grayordinates.${LowResMesh}k_fs_LR.dscalar.nii
                                          ATLASroiL=${StudyFolder}/${Subject}/MNINonLinear/fsaverage_LR${LowResMesh}k/${Subject}.L.atlasroi.${LowResMesh}k_fs_LR.shape.gii
                                          ATLASroiR=${StudyFolder}/${Subject}/MNINonLinear/fsaverage_LR${LowResMesh}k/${Subject}.R.atlasroi.${LowResMesh}k_fs_LR.shape.gii
                                          if [[ ! -f "$VAgray" ]]; then
                                            # create VA cifti with volume grayordinates filled with average of vertex areas for weighting 
                                            tempfiles_create "tmp_jnk_XXXXXX.nii.gz" tmp_jnk_file
                                            tempfiles_create "tmp_roi_XXXXXX.nii.gz" tmp_roi_file
                                            tempfiles_create "tmp_lab_XXXXXX.nii.gz" tmp_lab_file
                                            tempfiles_create "tmp_Lva_XXXXXX.shape.gii" tmp_Lva_file
                                            tempfiles_create "tmp_Rva_XXXXXX.shape.gii" tmp_Rva_file
                                            wb_command -cifti-separate ${outFile} COLUMN -volume-all "$tmp_jnk_file" -roi "$tmp_roi_file" -label "$tmp_lab_file"
                                            wb_command -cifti-separate ${VA} COLUMN -metric CORTEX_LEFT "$tmp_Lva_file" -metric CORTEX_RIGHT "$tmp_Rva_file"
                                            mean_VA=$(wb_command -cifti-stats ${VA} -reduce MEAN) # $VA is a dscalar cifti already masked by ATLASroi
                                            wb_command -volume-math "(ROI * $mean_VA)" "$tmp_roi_file" -var ROI "$tmp_roi_file"
                                            wb_command -cifti-create-dense-scalar ${VAgray} -volume "$tmp_roi_file" "$tmp_lab_file" \
                                              -left-metric "$tmp_Lva_file" -roi-left $ATLASroiL -right-metric "$tmp_Rva_file" -roi-right $ATLASroiR
                                          fi
                                          wb_command -cifti-math "(TCS * VA)" ${outFile} \
                                            -var TCS ${outFile} \
                                            -var VA ${VAgray} -select 1 1 -repeat
                                        fi

                                        cumTP=$endIdx
                                    fi
                                done
                            fi
                        else # single run data
                            echo ToDO
                            # No concat file not supplied so create a temporary one for Wishart filtering
                            # demeanVNarray=()
                            # vnScalarArray=()
                            # for fMRIName in "${fMRINamesArray[@]}"
                            # do
                            #     inputFile="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegString}_${fMRIProcSTRING}.dtseries.nii"
                            #     vnScalarFile="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegString}_${fMRIProcSTRING}_vn.dscalar.nii"
                            #     meanFile="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas_mean.dscalar.nii"
                            #     outputFile="${WFDir}/${Subject}/${fMRIName}_Atlas${RegString}_${fMRIProcSTRING}_WF.dtseries.nii"
              
                            #     # demean and variance normalize runs
                            #     wb_command -cifti-math "(TCS - MEAN) / VN" "$outputFile" -var TCS "$inputFile" -var MEAN "$meanFile" -var VN "$vnScalarFile" -select 1 1 -repeat
                            #     demeanVNarray+=("$outputFile")
                            #     vnScalarArray+=("$vnScalarFile")
                            # done

                            # # concatenate the demeaned+VN files
                            # concatOutFile="${WFDir}/${Subject}/CONCAT_Atlas${RegString}_${fMRIProcSTRING}_WF.dtseries.nii"
                            # wb_shortcuts -cifti-concatenate "${concatOutFile}" "${demeanVNarray[*]}"
                            

                            # log_Msg "Applying Wishart filter for subject $Subject"
                            # "$HCPPIPEDIR"/PFM/scripts/ApplyWFProfumo.sh \
                            #     --input="$concatOutFile" \
                            #     --output="$concatOutFile" \
                            #     --num-wishart="$NumWishart" \
                            #     --matlab-run-mode="$MatlabMode"

                            # # deconcatenate the Wishart filtered data back into individual runs
                            # # (each run has its own VN file, so un-VN with each separately)
                            # cumTP=0
                            # for fMRIName in "${fMRINamesArray[@]}"
                            # do
                            #     origFile="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegString}_${fMRIProcSTRING}.dtseries.nii"
                            #     vnScalarFile="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegString}_${fMRIProcSTRING}_vn.dscalar.nii"
                            #     meanFile="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas_mean.dscalar.nii"
                            #     if [[ -f "$origFile" ]]
                            #     then
                            #         nTP=$(wb_command -file-information "$origFile" -only-number-of-maps)
                            #         startIdx=$((cumTP + 1))
                            #         endIdx=$((cumTP + nTP))
                            #         outFile="${WFDir}/${Subject}/${fMRIName}_Atlas${RegString}_${fMRIProcSTRING}_WF.dtseries.nii"
                            #         wb_command -cifti-merge "$outFile" -direction ROW -cifti "$concatOutFile" -index "$startIdx" -up-to "$endIdx"
                                    
                            #         # un-variance normalize and un-demean each post-WF run
                            #         wb_command -cifti-math "(TCS / VN) + MEAN" "$outFile" -var TCS "$outFile" -var MEAN "$meanFile" -var VN "$vnScalarFile" -select 1 1 -repeat
                                  
                            #         cumTP=$endIdx
                            #     fi
                            # done
                        fi
                    done
                fi
                
                # Build JSON pointing at WF files
                ProfumoConfigToUse="${WFDir}/wishart_dataLocations.json"
                echo '{' > "$ProfumoConfigToUse"
                for Subject in "${Subjlist[@]}"
                do
                    echo -e "\t\"$Subject\": {" >> "$ProfumoConfigToUse"
                    for fMRIName in "${fMRINamesArray[@]}"
                    do
                        WFFile="${WFDir}/${Subject}/${fMRIName}_Atlas${RegString}_${fMRIProcSTRING}_WF.dtseries.nii"
                        if [[ -f "$WFFile" ]]
                        then
                            echo -e "\t\t\"$fMRIName\": \"$WFFile\"," >> "$ProfumoConfigToUse"
                        fi
                    done
                    perl -pi -e 'if (eof) { s/,$// }' "$ProfumoConfigToUse"
                    echo -e "\t}," >> "$ProfumoConfigToUse"
                done
                perl -pi -e 'if (eof) { s/,$// }' "$ProfumoConfigToUse"
                echo "}" >> "$ProfumoConfigToUse"
                log_Msg "WF complete"
            fi


            # Set up PROFUMO paths
            PFM_PATH="${PFMFolder}/Analysis.pfm"
            RESULTS_PATH="${PFMFolder}/Results.ppp"
            REAL_REF_IMAGE=$(readlink -f "${RefImage}")
            
            # Calculate low rank data parameter
            LowRankData=$((PFMdim * 5))
            
            # if PFM output directory exists, clear it (except dataLocations.json) because PROFUMO otherwise creates "+" files instead of overwriting
            if [[ -d "${PFMFolder}" ]]
            then
                log_Warn "PFM output folder ${PFMFolder} already exists, clearing contents"
                find "${PFMFolder}" -mindepth 1 -not -name "dataLocations.json" -not -name ".*" -not -path "*/WishartFilter_WF*" -delete 2>/dev/null || true
                # ignore errors due to nfs silly renamed files, or similar
            fi

            # Build optional initialMaps argument
            InitialMapsArg=""
            if [[ -n "${InitialMaps}" && -f "${InitialMaps}" ]]
            then
                InitialMapsArg="--initialMaps ${InitialMaps}"
            fi
            
            # Build optional loadSequentially argument
            LoadSequentiallyArg=""
            LoadSequentiallyBool=$(opts_StringToBool "$LoadSequentially")
            if ((LoadSequentiallyBool))
            then
                LoadSequentiallyArg="--loadSequentially"
            fi
            
            # files were written with an older version of cifti-matlab with 8-byte instead of 16-byte alignment. 
            if [[ "${NumWishart}" -eq 0 ]]
            then
                cat "${ProfumoConfig}" | \
                    while IFS= read -r line; do
                        if [[ "$line" != *'.nii"'* ]]; then continue;fi # Only process lines that contain .nii"
                        filePath=$(echo "$line" | sed -E 's/^[[:space:]]*"[^"]*"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')
                        wb_command -file-convert -cifti-version-convert "$filePath" 2 "$filePath"
                    done           
            fi

            # log_Msg "Running PROFUMO decomposition with dimension ${PFMdim}"
            cmd=(apptainer exec --bind $(dirname "${StudyFolder}") \
                --env PROFUMODIR=/opt/profumo \
                --env PYTHONNOUSERSITE=1 \
                "${ProfumoSingularity}" \
                /opt/profumo/C++/PROFUMO "${ProfumoConfigToUse}" \
                "${PFMdim}" "${PFM_PATH}" \
                --useHRF "${TR}" --covModel "${CovModel}" --dofCorrection "${DOFCorrection}" \
                --nThreads "${ProfumoThreads}" --lowRankData "${LowRankData}" --randomSeed "${RandomSeed}" \
                --multiStartIterations "${MultiStartIterations}" ${LoadSequentiallyArg} ${InitialMapsArg})
            log_Msg "running command: ${cmd[*]}"
            "${cmd[@]}"
            
            #Cleanup WF files
            if [[ "$NumWishart" -gt 0 ]]
            then
                if ((KeepWishartBool))
                then
                    log_Msg "Keeping Wishart filtered files in ${WFDir}"
                else
                    log_Msg "Cleaning up Wishart filtered files"
                    rm -rf "${WFDir}"  2>/dev/null || true # ignore errors due to nfs silly renamed files, or similar
                fi
            fi          
            ;;
            
        (PostPROFUMO)
            log_Msg "Running PROFUMO postprocessing"
            PFM_PATH="${PFMFolder}/Analysis.pfm"
            RESULTS_PATH="${PFMFolder}/Results.ppp"
            REAL_REF_IMAGE=$(readlink -f "${RefImage}")

            # Remove any existing Results.ppp directory 
            # so postprocess_results.py writes fresh output to Results.ppp
            if [[ -d "${PFMFolder}/Results.ppp" ]]
            then
                log_Warn "Results.ppp folder ${PFMFolder}/Results.ppp already exists, clearing before postprocessing"
                rm -rf "${PFMFolder}"/Results.ppp 2>/dev/null || true # ignore errors due to nfs silly renamed files, or similar
            fi

            cmd=(apptainer exec --bind $(dirname "${StudyFolder}") \
                --env PROFUMODIR=/opt/profumo \
                --env PYTHONNOUSERSITE=1 \
                "${ProfumoSingularity}" \
                /opt/fsl/fslpython/envs/profumo/bin/python3 /opt/profumo/Python/postprocess_results.py \
                --web-report \
                "${PFM_PATH}" \
                "${RESULTS_PATH}" \
                "${REAL_REF_IMAGE}")
            log_Msg "Running command: ${cmd[*]}"
            "${cmd[@]}"

            log_Msg "Running PostPROFUMO step"
            "$HCPPIPEDIR"/PFM/scripts/PostPROFUMO.sh \
                --study-folder="$StudyFolder" \
                --subject-list="$SubjlistRaw" \
                --fmri-names="$fMRINames" \
                --concat-name="$ConcatName" \
                --proc-string="_Atlas${RegString}_${fMRIProcSTRING}" \
                --output-fmri-name="$OutputfMRIName" \
                --output-string="$OutputSTRING" \
                --surf-reg-name="$RegName" \
                --low-res-mesh="$LowResMesh" \
                --profumo-tr="$TR" \
                --pfm-folder="$PFMFolder" \
                --matlab-run-mode="$MatlabMode"
            ;;
        (RSNRegression)
            log_Msg "Running RSNRegression step"
            
            # Set up template paths            
            for Subject in "${Subjlist[@]}"
            do
                if [[ "$ConcatName" != "" ]]
                then
                    fMRINamesForSub="${ConcatName}"
                else 
                    # Build list of existing fMRI files for this subject (same logic as your example)
                    fMRINamesForSub=""
                    for fMRIName in "${fMRINamesArray[@]}"
                    do
                        if [[ -f "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas${RegString}_${fMRIProcSTRING}.dtseries.nii" ]]
                        then
                            if [[ "$fMRINamesForSub" != "" ]]
                            then
                                fMRINamesForSub="${fMRINamesForSub}@${fMRIName}"
                            else
                                fMRINamesForSub="${fMRIName}"
                            fi
                        fi
                    done
                fi

                if [[ "$fMRINamesForSub" == "" ]]
                then
                    log_Warn "No valid fMRI runs found for subject $Subject, skipping"
                    continue
                fi
                
                # Set maps for dual regression
                GroupMaps="${PFMFolder}/Results.ppp/Maps/Group.dscalar.nii"
                
                # Build RSN regression command 
                rsn_cmd=("$HCPPIPEDIR"/global/scripts/RSNregression.sh
                    --study-folder="$StudyFolder"
                    --subject="$Subject"
                    --subject-timeseries="$fMRINamesForSub" # "$fMRINamesForSub"
                    --surf-reg-name="$RegName"
                    --low-res="$LowResMesh"
                    --proc-string="_$fMRIProcSTRING"
                    --method="dual"
                    --output-string="$OutputSTRING"
                    --output-spectra="$RunsXNumTimePoints"
                    --volume-template-cifti="$VolumeTemplateFile"
                    --output-z=1
                    --fix-legacy-bias="$FixLegacyBias"
                    --scale-factor="$ScaleFactor"
                    --group-maps="$GroupMaps"
                )
                
                # Queue parallel job
                par_addjob "${rsn_cmd[@]}"
            done
            
            # Run the jobs
            par_runjobs "$parLimit"
            ;;
        (GroupPFMs)
            log_Msg "Running GroupPFMs step"
            "$HCPPIPEDIR"/PFM/scripts/GroupPFMs.sh \
                --study-folder="$StudyFolder" \
                --subject-list="$SubjlistRaw" \
                --pfm-dimension="$PFMdim" \
                --output-string="$OutputSTRING" \
                --surf-reg-name="$RegName" \
                --low-res-mesh="$LowResMesh" \
                --runs-timepoints="$RunsXNumTimePoints" \
                --pfm-folder="$PFMFolder" \
                --matlab-run-mode="$MatlabMode"
            ;;
        (*) #NOTE: this case MUST be last
            log_Err_Abort "internal error: unimplemented pipeline step '$stepName'"
            ;;
    esac
    log_Msg "step $stepName complete"
done
