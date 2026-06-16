#!/bin/bash
set -euE

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/tempfiles.shlib"

#this function gets called by opts_ParseArguments when --help is specified
function usage()
{
    #header text
    echo "
$log_ToolName: combines various types of data into single-hemisphere files ready for MPM classification

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
opts_AddMandatory '--low-res' 'LowResMesh' 'number' "mesh resolution for fMRI processing, probably '32'"
#existing script did not allow NONE for RegName, so it is mandatory for now
opts_AddMandatory '--surf-reg-name' 'RegName' 'name' "the registration string corresponding to the input files"
opts_AddMandatory '--rfmri-name' 'OutrfMRIName' 'name' "the resting state data base name, like rfMRI_REST"
opts_AddMandatory '--rfmri-proc-string' 'rfMRIProcSTRING' 'name' "the processing string for rfMRI data, like _hp2000_clean_nobias_vn"
opts_AddMandatory '--ica-string' 'ICASTRING' 'name' "the base name for the individualized ICA networks, like individual_RSNs_d137_WR_norm"
opts_AddMandatory '--topography-string' 'TopographySTRING' 'name' "partial path to topographic regression results"
opts_AddMandatory '--stats-string' 'StatsSTRING' 'name' "processing-related string, generally _BC"
opts_AddOptional '--rsn-columns-file' 'RSNWeights' 'file' "text file containing column indices to use from the resting state networks"
opts_AddOptional '--output-name' 'NameString' 'name' "name suffix for outputs, like NoTask"
opts_AddOptional '--task-ica-dim' 'TaskICAdim' 'number' "task ICA dimentionality, to not use task data, use NONE or don't specify this option" 'NONE'
opts_AddOptional '--all-tasks-name' 'AllTasksOutputName' 'name' "the string for the concatenated task data, like tfMRI_ALLTASKS"
opts_AddOptional '--task-highpass' 'TemporalFilter' 'number' "the temporal high pass filter value used for task data"
opts_AddOptional '--task-fwhm' 'SmoothingFWHM' 'number' "the smoothing kernel used for task data, in mm FWHM"
opts_AddOptional '--tfmri-proc-string' 'tfMRIProcSTRING' 'name' "the processing string for tfMRI data, like _hp2000_clean"
opts_AddOptional '--task-columns-file' 'tfMRIWeights' 'file' "text file containing which task columns to use"
opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

function restrict_hem()
{
    local hem="$1"
    local input="$2"
    local output="$3"
    
    tempfiles_add "$output"
    
    #currently written only for 91k grayordinates
    if [[ "$hem" == "L" ]]
    then
        wb_command -cifti-restrict-dense-map "$input" COLUMN "$output" -left-roi "$HCPPIPEDIR/global/templates/91282_Greyordinates/L.atlasroi.32k_fs_LR.shape.gii"
    else
        wb_command -cifti-restrict-dense-map "$input" COLUMN "$output" -right-roi "$HCPPIPEDIR/global/templates/91282_Greyordinates/R.atlasroi.32k_fs_LR.shape.gii"
    fi
}

#Since we can handle empty string, stop with the NONE stuff for strings and filenames
if [[ "${NameString}" != "" ]]
then
    NameString="_${NameString}"
    #if [[ ${RSNWeights} != "" ]]
    #then
    #  NameString="${NameString}_SO"
    #fi
fi

AtlasFolder="${StudyFolder}/${Subject}/MNINonLinear"
DownSampleFolder="${AtlasFolder}/fsaverage_LR${LowResMesh}k"
ResultsFolder="${AtlasFolder}/Results"

for Hemisphere in L R
do
    if [[ "${Hemisphere}" == "L" ]]
    then
        hemisphereword="left"
    else
        hemisphereword="right"
    fi

    ###Make feature type identity vector
    restrict_hem "$Hemisphere" "${DownSampleFolder}/${Subject}.corrThickness_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii" "${DownSampleFolder}/${Subject}.${Hemisphere}.corrThickness_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii"
    NumThickness=`wb_command -file-information ${DownSampleFolder}/${Subject}.${Hemisphere}.corrThickness_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii -only-number-of-maps`

    restrict_hem "$Hemisphere" "${DownSampleFolder}/${Subject}.MyelinMap_BC_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii" "${DownSampleFolder}/${Subject}.${Hemisphere}.MyelinMap_BC_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii"
    NumMyelin=`wb_command -file-information ${DownSampleFolder}/${Subject}.${Hemisphere}.MyelinMap_BC_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii -only-number-of-maps`

    restrict_hem "$Hemisphere" "${DownSampleFolder}/${Subject}.curvature_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii" "${DownSampleFolder}/${Subject}.${Hemisphere}.curvature_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii"
    NumCurv=`wb_command -file-information ${DownSampleFolder}/${Subject}.${Hemisphere}.curvature_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii -only-number-of-maps`

    if [[ "${TaskICAdim}" != "NONE" ]]
    then
        if [[ "$AllTasksOutputName" == "" ]]
        then
            log_Err_Abort "when using task data, you must specify the --all-tasks-name option"
        fi

        restrict_hem "$Hemisphere" "${ResultsFolder}/${AllTasksOutputName}/${Subject}_${AllTasksOutputName}_level2_beta_norm_hp${TemporalFilter}_s${SmoothingFWHM}_${RegName}${tfMRIProcSTRING}_mean.dscalar.nii" "${ResultsFolder}/${AllTasksOutputName}/${Subject}_${Hemisphere}_${AllTasksOutputName}_level2_beta_norm_hp${TemporalFilter}_s${SmoothingFWHM}_${RegName}${tfMRIProcSTRING}_mean.dscalar.nii"
        NumTaskMean=`wb_command -file-information ${ResultsFolder}/${AllTasksOutputName}/${Subject}_${Hemisphere}_${AllTasksOutputName}_level2_beta_norm_hp${TemporalFilter}_s${SmoothingFWHM}_${RegName}${tfMRIProcSTRING}_mean.dscalar.nii -only-number-of-maps`

        restrict_hem "$Hemisphere" "${ResultsFolder}/${AllTasksOutputName}/${Subject}_${AllTasksOutputName}_level2_beta_norm_hp${TemporalFilter}_s${SmoothingFWHM}_d${TaskICAdim}_${RegName}${tfMRIProcSTRING}.dscalar.nii" "${ResultsFolder}/${AllTasksOutputName}/${Subject}_${Hemisphere}_${AllTasksOutputName}_level2_beta_norm_hp${TemporalFilter}_s${SmoothingFWHM}_d${TaskICAdim}_${RegName}${tfMRIProcSTRING}.dscalar.nii"
        NumTask=`wb_command -file-information ${ResultsFolder}/${AllTasksOutputName}/${Subject}_${Hemisphere}_${AllTasksOutputName}_level2_beta_norm_hp${TemporalFilter}_s${SmoothingFWHM}_d${TaskICAdim}_${RegName}${tfMRIProcSTRING}.dscalar.nii -only-number-of-maps`

        if [[ "${tfMRIWeights}" != "" ]]
        then
            Weights=`cat ${tfMRIWeights}`
            TaskMergeArray=(-cifti "${ResultsFolder}/${AllTasksOutputName}/${Subject}_${Hemisphere}_${AllTasksOutputName}_level2_beta_norm_hp${TemporalFilter}_s${SmoothingFWHM}_${RegName}${tfMRIProcSTRING}_mean.dscalar.nii")
            i=0
            for Weight in ${Weights} ; do
                i=$((${i}+1))
                TaskMergeArray+=(-cifti "${ResultsFolder}/${AllTasksOutputName}/${Subject}_${Hemisphere}_${AllTasksOutputName}_level2_beta_norm_hp${TemporalFilter}_s${SmoothingFWHM}_d${TaskICAdim}_${RegName}${tfMRIProcSTRING}.dscalar.nii" -column "${Weight}")
            done
            NumTask=${i}
        else
            TaskMergeArray=(-cifti "${ResultsFolder}/${AllTasksOutputName}/${Subject}_${Hemisphere}_${AllTasksOutputName}_level2_beta_norm_hp${TemporalFilter}_s${SmoothingFWHM}_${RegName}${tfMRIProcSTRING}_mean.dscalar.nii" -cifti "${ResultsFolder}/${AllTasksOutputName}/${Subject}_${Hemisphere}_${AllTasksOutputName}_level2_beta_norm_hp${TemporalFilter}_s${SmoothingFWHM}_d${TaskICAdim}_${RegName}${tfMRIProcSTRING}.dscalar.nii")
        fi
    fi

    restrict_hem "$Hemisphere" "${DownSampleFolder}/${Subject}.${ICASTRING}_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii" "${DownSampleFolder}/${Subject}_${Hemisphere}_${ICASTRING}_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii"
    NumRSNs=`wb_command -file-information ${DownSampleFolder}/${Subject}_${Hemisphere}_${ICASTRING}_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii -only-number-of-maps`
    if [[ ${RSNWeights} != "" ]]
    then
        Weights=`cat ${RSNWeights}`
        RSNMergeArray=()
        i=0
        for Weight in ${Weights}
        do
            i=$((${i}+1))
            RSNMergeArray+=(-cifti "${DownSampleFolder}/${Subject}_${Hemisphere}_${ICASTRING}_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii" -column "${Weight}")
        done
        NumRSNs=${i}
    else
        RSNMergeArray=(-cifti "${DownSampleFolder}/${Subject}_${Hemisphere}_${ICASTRING}_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii")
    fi

    restrict_hem "$Hemisphere" "${DownSampleFolder}/${Subject}.T1wDividedByT2w_vein_effects_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii" "${DownSampleFolder}/${Subject}.${Hemisphere}.T1wDividedByT2w_vein_effects_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii"
    NumVein=`wb_command -file-information ${DownSampleFolder}/${Subject}.${Hemisphere}.T1wDividedByT2w_vein_effects_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii -only-number-of-maps`

    restrict_hem "$Hemisphere" "${ResultsFolder}/${OutrfMRIName}/${OutrfMRIName}_Atlas_${RegName}_dropouts.dscalar.nii" "${ResultsFolder}/${OutrfMRIName}/${OutrfMRIName}_Atlas_${RegName}_dropouts_${Hemisphere}.dscalar.nii"
    NumDropOut=`wb_command -file-information ${ResultsFolder}/${OutrfMRIName}/${OutrfMRIName}_Atlas_${RegName}_dropouts_${Hemisphere}.dscalar.nii -only-number-of-maps`

    restrict_hem "$Hemisphere" "${DownSampleFolder}/${Subject}.PialPutamen_Effects_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii" "${DownSampleFolder}/${Subject}.${Hemisphere}.PialPutamen_Effects_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii"
    NumPP=`wb_command -file-information ${DownSampleFolder}/${Subject}.${Hemisphere}.PialPutamen_Effects_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii -only-number-of-maps`

    restrict_hem "$Hemisphere" "${ResultsFolder}/${OutrfMRIName}/${OutrfMRIName}_Atlas_${RegName}${rfMRIProcSTRING}${StatsSTRING}_std.dscalar.nii" "${ResultsFolder}/${OutrfMRIName}/${OutrfMRIName}_Atlas_${RegName}${rfMRIProcSTRING}${StatsSTRING}_std_${Hemisphere}.dscalar.nii"
    NumStd=`wb_command -file-information ${ResultsFolder}/${OutrfMRIName}/${OutrfMRIName}_Atlas_${RegName}${rfMRIProcSTRING}${StatsSTRING}_std_${Hemisphere}.dscalar.nii -only-number-of-maps`

    restrict_hem "$Hemisphere" "${ResultsFolder}/${OutrfMRIName}/${OutrfMRIName}_Atlas_${RegName}${rfMRIProcSTRING}${StatsSTRING}_mgtrbeta.dscalar.nii" "${ResultsFolder}/${OutrfMRIName}/${OutrfMRIName}_Atlas_${RegName}${rfMRIProcSTRING}${StatsSTRING}_mgtrbeta_${Hemisphere}.dscalar.nii"
    NumMGTRBeta=`wb_command -file-information ${ResultsFolder}/${OutrfMRIName}/${OutrfMRIName}_Atlas_${RegName}${rfMRIProcSTRING}${StatsSTRING}_mgtrbeta_${Hemisphere}.dscalar.nii -only-number-of-maps`

    restrict_hem "$Hemisphere" "${ResultsFolder}/${OutrfMRIName}/${TopographySTRING}_gradvectowardDOT.dscalar.nii" "${ResultsFolder}/${OutrfMRIName}/${TopographySTRING}_gradvectowardDOT_${Hemisphere}.dscalar.nii"
    NumTopographicVectorsTowardDOT=`wb_command -file-information ${ResultsFolder}/${OutrfMRIName}/${TopographySTRING}_gradvectowardDOT_${Hemisphere}.dscalar.nii -only-number-of-maps`

    wb_command -cifti-merge ${DownSampleFolder}/${Subject}.${Hemisphere}.MultiModal_Features${NameString}_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii -cifti ${DownSampleFolder}/${Subject}.${Hemisphere}.corrThickness_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii -cifti ${DownSampleFolder}/${Subject}.${Hemisphere}.MyelinMap_BC_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii -cifti ${DownSampleFolder}/${Subject}.${Hemisphere}.curvature_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii ${TaskMergeArray[@]+"${TaskMergeArray[@]}"} "${RSNMergeArray[@]}" -cifti ${DownSampleFolder}/${Subject}.${Hemisphere}.T1wDividedByT2w_vein_effects_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii -cifti ${ResultsFolder}/${OutrfMRIName}/${OutrfMRIName}_Atlas_${RegName}_dropouts_${Hemisphere}.dscalar.nii -cifti ${DownSampleFolder}/${Subject}.${Hemisphere}.PialPutamen_Effects_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii -cifti ${ResultsFolder}/${OutrfMRIName}/${OutrfMRIName}_Atlas_${RegName}${rfMRIProcSTRING}${StatsSTRING}_std_${Hemisphere}.dscalar.nii -cifti ${ResultsFolder}/${OutrfMRIName}/${OutrfMRIName}_Atlas_${RegName}${rfMRIProcSTRING}${StatsSTRING}_mgtrbeta_${Hemisphere}.dscalar.nii -cifti ${ResultsFolder}/${OutrfMRIName}/${TopographySTRING}_gradvectowardDOT_${Hemisphere}.dscalar.nii

    wb_command -cifti-gradient ${DownSampleFolder}/${Subject}.${Hemisphere}.MultiModal_Features${NameString}_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii COLUMN ${DownSampleFolder}/${Subject}.${Hemisphere}.MultiModal_Features${NameString}_grad_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii -${hemisphereword}-surface ${DownSampleFolder}/${Subject}.${Hemisphere}.midthickness.${LowResMesh}k_fs_LR.surf.gii -surface-presmooth 1
done


if [[ "${TaskICAdim}" != "NONE" ]]
then
    Types="${NumThickness} ${NumMyelin} ${NumCurv} ${NumTaskMean} ${NumTask} ${NumRSNs} ${NumVein} ${NumDropOut} ${NumPP} ${NumStd} ${NumMGTRBeta} ${NumTopographicVectorsTowardDOT}"
else
    Types="${NumThickness} ${NumMyelin} ${NumCurv} ${NumRSNs} ${NumVein} ${NumDropOut} ${NumPP} ${NumStd} ${NumMGTRBeta} ${NumTopographicVectorsTowardDOT}"
fi

FeatureMask=""
i=1
for Type in ${Types}
do
    for ((n = 1; n <= Type; ++n))
    do
        FeatureMask="${FeatureMask} ${i}"
    done
    ((++i))
done

for Hemisphere in L R ; do
    echo ${FeatureMask} > ${DownSampleFolder}/${Subject}.${Hemisphere}.MultiModal_Features${NameString}_${RegName}.${LowResMesh}k_fs_LR.txt
done

