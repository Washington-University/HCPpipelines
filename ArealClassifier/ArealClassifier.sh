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
$log_ToolName: classifies functional areas in a single subject enabled by multiple versions of the areal classifier, including the mlp classifier designed in Glasser 2016, DOI 10.1038/nature18933

Usage: $log_ToolName PARAMETER...

PARAMETERs are [ ] = optional; < > = user supplied value
"
    #automatic argument descriptions
    opts_ShowArguments
}

#arguments to opts_Add*: switch, variable to set, name for inside of <> in help text, description, [default value if AddOptional], [compatibility flag, ...]
#help info for option gets printed like "--foo=<$3> - $4"
opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject' 'Subject' 'subject ID' ""
opts_AddMandatory '--subject-rfmri' 'rfMRINames' 'fmri@fmri@fmri...' "the timeseries fmri names to use as resting state data"
opts_AddOptional '--multirun-fix-concat-name' 'mrFIXExtractConcatName' 'name' "fmri name used for concatinated MR+FIX output" 'NONE'
opts_AddMandatory '--output-rfmri' 'OutrfMRIName' 'name' "fmri name to use when making concatenated intermediates"
opts_AddOptional '--surf-reg-name' 'RegName' 'name' "the registration string corresponding to the input files" 'NONE'
opts_AddOptional '--template-folder' 'TemplateFolder' 'folder' "the folder containing the topographic templates" "$HCPPIPEDIR/ArealClassifier/data/topography"
opts_AddMandatory '--proc-string' 'ProcString' 'string' "part of filename describing processing, like '_hp2000_clean'"
opts_AddOptional '--group-data' 'GroupDataString' 'YES or NO' "whether this 'subject' is group data (MIGP), default NO" 'NO'
opts_AddOptional '--regress-template' 'RegressTemplateFolder' 'folder' "folder containing alternate sICA templates" "$HCPPIPEDIR/global/templates/MSMAll"
opts_AddOptional '--regress-dim' 'Dim' 'number' 'alternate dimensionality to use for the RSN ICA' '76'
opts_AddOptional '--regress-lowdims' 'LowDims' 'num@num@num...' 'alternate low dimensionalities to use to estimate regions of poor alignment' '7@8@9@10@11@12@13@14@15@16@17@18@19@20@21'
opts_AddMandatory '--regress-outstring' 'RegressOutString' 'string' "part of filename for regression intermediates"
opts_AddOptional '--regress-method' 'RegressMethod' 'string' "PFM_weighted"
opts_AddOptional '--regress-spectra' 'OutputSpectra' 'number' 'number of frequency bins for spectra (usually number of input timepoints)'
opts_AddOptional '--regress-template-folder-pattern' 'RegressTemplatePattern' 'prefix@postfix' "string to set the folder names to inside of the regress template folder, use @ instead of the dimensionality" 'rfMRI_REST_Atlas_MSMAll_hp2000_clean_rclean_tclean_PCA_WF6.ica_d@_ROW_vn'
opts_AddOptional '--output-suffix' 'FeatureOutputName' 'name' "suffix for output files, like NoTask"
opts_AddMandatory '--classifier-training' 'TrainedFolder' 'path' "classifier training weights"
opts_AddMandatory '--classifier-version' 'ClassifierVersion' 'string' "either the matlab version 'MATLAB' or the python version 'ARENA_v1', 'ARENA_v2'"
# opts_AddOptional '--python-singularity' 'PythonSingularity' 'string' "the file path of the singularity" "$HCPPIPEDIR/ArealClassifier/singularity/hcp_python_singularity.simg"
opts_AddOptional '--only-inference' 'OnlyInferenceString' 'YES or NO' "whether to use for inference only, default NO" 'NO'

#FIXME: compiled matlab not implemented
opts_AddOptional '--matlab-run-mode' 'matlab_mode' '0, 1, 2' "defaults to 1
0 = use compiled matlab (not implemented)
1 = use interpreted matlab
2 = use interpreted octave" '1'
opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

OnlyInference=$(opts_StringToBool "$OnlyInferenceString")

case "$matlab_mode" in
    (0)
        log_Err_Abort "compiled matlab mode not implemented"
        ;;
    (1 | 2)
        ;;
    (*)
        log_Err_Abort "unrecognized matlab mode: $matlab_mode"
        ;;
esac

# check RSN type
if [[ "$RegressMethod" != "PFM_weighted" ]]; then
    log_Err_Abort "Only weighted regression is supported!"
fi

# check classifier version
if [[ "$ClassifierVersion" == "MATLAB" || "$ClassifierVersion" == "ARENA_v1" || "$ClassifierVersion" == "ARENA_v2" ]]; then
    log_Msg "ClassifierVersion is ${ClassifierVersion}."
else
    log_Err_Abort "ClassifierVersion must be one of the followings, 'MATLAB', 'ARENA_v1', 'ARENA_v2' but gets ${ClassifierVersion}"
fi

# # check if python singularity is needed
# if echo "$ClassifierVersion" | grep -q "ARENA"
# then
#     if [ ! -f "$PythonSingularity" ]; then
#         log_Err_Abort "the singularity container doesn't exists under python version: $PythonSingularity"
#     fi

#     if command -v singularity &> /dev/null; then
#         log_Msg "Singularity is installed."
#     else
#         log_Err_Abort "Singularity is not installed or not in PATH."
#     fi
# fi

GroupData=$(opts_StringToBool "$GroupDataString")

RegString=""
if [[ "$RegName" != "NONE" ]]
then
    RegString="_$RegName"
fi

#topographic regression doesn't put the regname in automatically
LongProcString=_Atlas"${RegString}$ProcString"

#Handle MR+FIX case
if [[ ${mrFIXExtractConcatName} = "NONE" ]] ; then
  rfMRINamesToUse=${rfMRINames}
else
  rfMRINamesToUse=${mrFIXExtractConcatName}
fi

#hardcode
ResultLocation="PartialCorrelationTopography"

#the matlab code hardcodes the details of the 91k grayordinates, this must NOT be changed
LowResMesh="32"
Caret7_Command="wb_command"

LeftAreaBorder="$TemplateFolder/L_V1_ROI.32k_fs_LR.border"
RightAreaBorder="$TemplateFolder/R_V1_ROI.32k_fs_LR.border"

#hardcode
AreaName="V1_ROI"
AreaIINames="NONE"
AxisOneBorder="Meridians3New_line_Gradient_ROI" #In ROIs Folder
AxisTwoBorder="Eccentricity3New_line_Gradient_ROI" #In ROIs Folder
AxisOneLeftParameters="-3@-2@-1%(-Var-3)"
AxisOneRightParameters="3@2@1%(-Var+3)"
AxisTwoLeftParameters="1@1.5@2%(Var-1)"
AxisTwoRightParameters="1@1.5@2%(Var-1)"
LinearGradientSmoothingFWHM="2"
GradientSmoothingFWHM=`echo "1 * ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l` #Default is Sigma=1mm
DilationAmount="50"
GenerateGradients="YES" #YES or NO
ReRun="YES" #YES or NO

#hardcode
AxisOnePalette="MODE_USER_SCALE@-pos-user_0_180_-neg-user_0_-180_-interpolate_true_-disp-pos_true_-disp-neg_true_-disp-zero_true_-palette-name_RBGYR20"
AxisTwoPalette="MODE_USER_SCALE@-pos-user_0_1_-interpolate_true_-disp-pos_true_-disp-neg_false_-disp-zero_true_-palette-name_RBGYR20P"
numit="0"
AxisOneFactor="90"
AxisTwoFactor="1"
GroupROILocation="$TemplateFolder"
NuisanceROIBorder="NONE" #In ROIs Folder or NONE
SaveDCONN="NO" #YES or NO
BC="NONE"

AreaIINames=`echo "${AreaIINames}" | sed 's/ /@/g'`

# handling the incomplete run cases
fMRINamesForSub=""
for fMRIName in `echo ${rfMRINames} | sed 's/@/ /g'` ; do
    if [ -e ${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_Atlas_${RegName}${ProcString}.dtseries.nii ] ; then
        if [ ! ${fMRINamesForSub} = "" ] ; then
            fMRINamesForSub=`echo "${fMRINamesForSub}@${fMRIName}"`
        else
            fMRINamesForSub=`echo "${fMRINamesForSub}${fMRIName}"`
        fi
    fi
done
fMRINamesForSub=`echo ${fMRINamesForSub} | sed 's/@@/@/g'`
rfMRINamesFinal=${fMRINamesForSub}

if [[ ${mrFIXExtractConcatName} = "NONE" ]] ; then
  rfMRINamesToUse=${rfMRINamesFinal}
else
  rfMRINamesToUse=${mrFIXExtractConcatName}
fi

if ((! OnlyInference))
then
    "$HCPPIPEDIR"/ArealClassifier/scripts/TopographicRegression.sh "$StudyFolder" "$Subject" "$GroupData" "$rfMRINamesToUse" "$OutrfMRIName" "$LowResMesh" "$Caret7_Command" "$ResultLocation" "$RegName" "$LongProcString" "$LeftAreaBorder" "$RightAreaBorder" "$AreaName" "$AreaIINames" "$AxisOneBorder" "$AxisTwoBorder" "$AxisOneLeftParameters" "$AxisOneRightParameters" "$AxisTwoLeftParameters" "$AxisTwoRightParameters" "$GradientSmoothingFWHM" "$LinearGradientSmoothingFWHM" "$DilationAmount" "$GenerateGradients" "$ReRun" "$AxisOnePalette" "$AxisTwoPalette" "$numit" "$AxisOneFactor" "$AxisTwoFactor" "$GroupROILocation" "$BC" "$NuisanceROIBorder" "$SaveDCONN"
fi

#handle folder pattern
GroupMaps="$RegressTemplateFolder/$(echo "$RegressTemplatePattern" | sed "s/@/$Dim/g")/melodic_oIC.dscalar.nii"
LowDimTemplate="$RegressTemplateFolder/$(echo "$RegressTemplatePattern" | sed "s/@/REPLACEDIM/g")/melodic_oIC.dscalar.nii"

MethodStr="PFM_WR" # only PFM_WR is supported
#take "weights" from same folder as group maps
RSNToUseFile="$RegressTemplateFolder/$(echo "$RegressTemplatePattern" | sed "s/@/$Dim/g")/Weights.txt"

if ((! OnlyInference))
then
    #unimplemented "norm" output mode is for MSMAll script, not areal classifier
    # group sICA
    "$HCPPIPEDIR"/global/scripts/RSNregression.sh \
        --study-folder="$StudyFolder" \
        --subject="$Subject" \
        --group-maps="$GroupMaps" \
        --subject-timeseries="$rfMRINamesToUse" \
        --surf-reg-name="$RegName" \
        --low-res="$LowResMesh" \
        --proc-string="$ProcString" \
        --method="$RegressMethod" \
        --low-ica-dims="$LowDims" \
        --low-ica-template-name="$LowDimTemplate" \
        --output-string="$RegressOutString" \
        --output-spectra="$OutputSpectra" \
        --output-z=1 \
        --scale-factor=0.01
fi
#putamen and veins
#hardcode?  32k is hardcoded into the other
SmoothingFWHM="2"
FinalfMRIResolution="2"
BrainOrdinatesResolution="2"

if ((! OnlyInference))
then
    "$HCPPIPEDIR"/ArealClassifier/scripts/PutamenAndVeinEffects.sh \
        --study-folder="$StudyFolder" \
        --subject="$Subject" \
        --surf-reg-name="$RegName" \
        --low-res="$LowResMesh" \
        --smoothing-fwhm="$SmoothingFWHM" \
        --fmri-res="$FinalfMRIResolution" \
        --grayordinates-res="$BrainOrdinatesResolution"
fi
#stdev and mgt beta
#hardcode?
StatsSTRING="_BC"
ResultsFolder="${StudyFolder}/${Subject}/MNINonLinear/Results"

#procstring should probably be whatever we fed to TopographicRegression (what about StatsSTRING?)
#need to redo concatenation of input dtseries, like in TopographicRegression
IFS=@ read -a fmriarraytouse <<<"$rfMRINamesToUse"
inputdtseriestxt="$(mktemp --tmpdir XXXXXX.txt)"
tempfiles_add "$inputdtseriestxt"
for rfMRIName in "${fmriarraytouse[@]}"
do
    echo "${ResultsFolder}/${rfMRIName}/${rfMRIName}${LongProcString}.dtseries.nii" >> "${inputdtseriestxt}"
done

if ((! OnlyInference))
then
    case "$matlab_mode" in
        (0)
            log_Err_Abort "compiled matlab mode not implemented"
            ;;
        (1 | 2)
            if ((matlab_mode == 1))
            then
                interpreter=(matlab -nojvm -nodisplay -nosplash)
            else
                interpreter=(octave-cli -q --no-window-system)
            fi
            mPath="${HCPPIPEDIR}/ArealClassifier/scripts"
            mGlobalPath="${HCPPIPEDIR}/global/matlab"

            #maybe _$RegName should be $RegString, but needs fixing in combine, too
            #CHECK INPUT NAME, currently assuming TopographicRegression magically makes it
            matlabCode="addpath '$mPath'; addpath '$mGlobalPath';
            computeMisc('${inputdtseriestxt}', \
                '${ResultsFolder}/${OutrfMRIName}/${OutrfMRIName}${LongProcString}${StatsSTRING}_mgtrbeta.dscalar.nii', \
                '${ResultsFolder}/${OutrfMRIName}/${OutrfMRIName}${LongProcString}${StatsSTRING}_std.dscalar.nii');"

            log_Msg "Run matlab: $matlabCode"
            "${interpreter[@]}" <<<"$matlabCode"
            #matlab likes to leave a prompt without newline on the terminal, so echo to make a newline
            echo
            ;;
        (*)
            log_Err_Abort "unrecognized matlab mode: $matlab_mode"
            ;;
    esac
fi
#average dropouts across runs, map to surface, put in cifti, since nothing else uses them this way
#these temp names are a bit messy, but who cares
volmerged="$(mktemp --tmpdir XXXXXX.dropouts.nii.gz)"
leftdropouts="$volmerged.left.func.gii"
rightdropouts="$volmerged.right.func.gii"
tempfiles_add "$volmerged" "$leftdropouts" "$rightdropouts"

IFS=@ read -a fmriarray <<<"$rfMRINamesFinal"
mergeargs=()
for rfMRIName in "${fmriarray[@]}"
do
    mergeargs+=(-volume "${ResultsFolder}/${rfMRIName}/${rfMRIName}_dropouts.nii.gz")
done

if ((! OnlyInference))
then
    wb_command -volume-merge \
        "$volmerged" \
        "${mergeargs[@]}"
    wb_command -volume-reduce \
        "$volmerged" \
        MEAN \
        "${ResultsFolder}/${OutrfMRIName}/${OutrfMRIName}_dropouts_avg.nii.gz"

    #dilate 0 means to neighbors only, to fix only the issues caused by tiny native mesh triangles
    #this script is immune to problems from the volume containing exact zeros
    #default is 32k, MSMAll
    basecommand=("$HCPPIPEDIR"/global/scripts/MapVolumeToSurface.sh \
        --study-folder="$StudyFolder" \
        --subject="$Subject" \
        --input-vol="${ResultsFolder}/${OutrfMRIName}/${OutrfMRIName}_dropouts_avg.nii.gz" \
        --native-dilate=0 \
        --surf-reg-name="$RegName")

    "${basecommand[@]}" \
        --hemisphere="L" \
        --out-metric="$leftdropouts"
    "${basecommand[@]}" \
        --hemisphere="R" \
        --out-metric="$rightdropouts"
    wb_command -cifti-create-dense-from-template \
        "$HCPPIPEDIR"/global/templates/91282_Greyordinates/91282_Greyordinates.dscalar.nii \
        "${ResultsFolder}/${OutrfMRIName}/${OutrfMRIName}_Atlas_MSMAll_dropouts.dscalar.nii" \
        -metric CORTEX_LEFT "$leftdropouts" \
        -metric CORTEX_RIGHT "$rightdropouts"
    wb_command -set-map-names \
        "${ResultsFolder}/${OutrfMRIName}/${OutrfMRIName}_Atlas_MSMAll_dropouts.dscalar.nii" \
        -map 1 "$Subject"_dropouts

    #combine features
    TopographySTRING="PartialCorrelationTopography/${OutrfMRIName}_Atlas_${RegName}${ProcString}_resultsregression_0"

    "$HCPPIPEDIR"/ArealClassifier/scripts/CreateMultiModalFeatureSpace.sh \
        --study-folder="$StudyFolder" \
        --subject="$Subject" \
        --low-res="$LowResMesh" \
        --surf-reg-name="$RegName" \
        --rfmri-name="$OutrfMRIName" \
        --rfmri-proc-string="$ProcString" \
        --ica-string="${RegressOutString}_${MethodStr}" \
        --topography-string="$TopographySTRING" \
        --stats-string="$StatsSTRING" \
        --output-name="$FeatureOutputName" \
        --rsn-columns-file="$RSNToUseFile"
fi

#classifier
AtlasFolder="$StudyFolder/$Subject/MNINonLinear"
DownSampleFolder="$AtlasFolder/fsaverage_LR${LowResMesh}k"

ClassifierOutFolderRaw="$DownSampleFolder/ArealClassifier_${ClassifierVersion}" #maybe move to /tmp if we save all the gradient files elsewhere?
#ClassifierOutFolder="$(mktemp -d --tmpdir ClassifierOutput.XXXXXX)"

suffix=""
if [[ "$FeatureOutputName" != "" ]]
then
    suffix="_$FeatureOutputName"
fi

# loop over original version and subregion version
for LabelTableString in "" Subregions
do

    parcel_type=""
    ClassifierOutFolderTmp=${ClassifierOutFolderRaw}
    ParcellationName="CorticalAreas_dil_${ClassifierVersion}${suffix}"

    # override params for subregion output
    if [ "$LabelTableString" = "Subregions" ]; then
        parcel_type="${LabelTableString}"
        ClassifierOutFolderTmp=${ClassifierOutFolderRaw}_${parcel_type}
        ParcellationName="CorticalAreasAndSubRegions_dil_${ClassifierVersion}${suffix}"
    fi

    ClassifierOutFolder=${ClassifierOutFolderTmp}/${Subject}
        
    mkdir -p "${ClassifierOutFolder}"

    for Hem in L R
    do
        LabelTable="$HCPPIPEDIR/ArealClassifier/data/$Hem.table.txt"
        if [ "$LabelTableString" = "Subregions" ]; then
            LabelTable="$HCPPIPEDIR/ArealClassifier/data/$Hem.${parcel_type}_table.txt"
        fi

        InputDilROIs="$HCPPIPEDIR/ArealClassifier/data/ROIs_dil.$Hem.32k_fs_LR.dscalar.nii"
        #InputFeatureTypes="$HCPPIPEDIR/ArealClassifier/data/feature_types.$Hem.txt" # raw version in Glasser 2016
        InputFeatureTypes="$HCPPIPEDIR/ArealClassifier/data/feature_types.${Hem}_90.txt"

        AreaNamesTemp="$(mktemp --tmpdir XXXXXX.areanames.txt)"
        tempfiles_add "$AreaNamesTemp"
        sed -n 'p;n' "$LabelTable" > "$AreaNamesTemp"
        
        InputDense="${DownSampleFolder}/${Subject}.${Hem}.MultiModal_Features${suffix}_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii"
        InputDenseGrad="${DownSampleFolder}/${Subject}.${Hem}.MultiModal_Features${suffix}_grad_${RegName}.${LowResMesh}k_fs_LR.dscalar.nii"
            
        if [[ "$ClassifierVersion" == "ARENA_v1" ]]
        then
            UseModel="XGBOOST"
        elif [[ "$ClassifierVersion" == "ARENA_v2" ]]
        then
            UseModel="XGBOOST_2ND_PROB"
        fi

        # python version uses gifti as inputs
        tempfiles_create multimodal_features_XXXXXX.func.gii GiftiMultimodalFeatureFile
        if [[ "$Hem" == "L" ]]
        then
            wb_command -cifti-separate ${InputDense} \
            COLUMN -metric CORTEX_LEFT ${GiftiMultimodalFeatureFile}
        else
            wb_command -cifti-separate ${InputDense} \
            COLUMN -metric CORTEX_RIGHT ${GiftiMultimodalFeatureFile}
        fi
        # HCP-YA
        # hard coded to bind /media/myelin, TODO: change the hard-coded path
        # pythonCode=(
        #     "singularity exec --bind $StudyFolder,$HCPPIPEDIR,/media/myelin $PythonSingularity python3 $HCPPIPEDIR/ArealClassifier/ApplyClassifier.py"
        #     "--input_dense=$GiftiMultimodalFeatureFile"
        #     "--trained_folder=$TrainedFolder"
        #     "--area_names_file=$AreaNamesTemp"
        #     "--input_feature_types=$InputFeatureTypes"
        #     "--output_folder=$ClassifierOutFolder"
        #     "--model=$UseModel"
        #     "--hcp_pipe_dir=$HCPPIPEDIR"
        # )
        # # HCP-Lifespan
        # due to the folder of Lifespan data being saved on a remote server, here's the solution to find the right path
        # pythonCode=(
        #     "singularity exec --bind /mnt,/media $PythonSingularity python3 $HCPPIPEDIR/ArealClassifier/ApplyClassifier.py"
        #     "--input_dense=$GiftiMultimodalFeatureFile"
        #     "--trained_folder=$TrainedFolder"
        #     "--area_names_file=$AreaNamesTemp"
        #     "--input_feature_types=$InputFeatureTypes"
        #     "--output_folder=$ClassifierOutFolder"
        #     "--model=$UseModel"
        # )

        # HCP-YA not using singularity anymore
        pythonCode=(
            "python3 $HCPPIPEDIR/ArealClassifier/ApplyClassifier.py"
            "--input_dense=$GiftiMultimodalFeatureFile"
            "--trained_folder=$TrainedFolder"
            "--area_names_file=$AreaNamesTemp"
            "--input_feature_types=$InputFeatureTypes"
            "--output_folder=$ClassifierOutFolder"
            "--model=$UseModel"
            "--hcp_pipe_dir=$HCPPIPEDIR"
        )

        cmd="${pythonCode[*]}"
        log_Msg "Run python: $cmd"
        eval "$cmd"

        # only use for python classifier to convert back to cifti
        if [[ "$Hem" == "L" ]]
        then
            tmpString="-left-metric"
            roiString="-roi-left $HCPPIPEDIR/ArealClassifier/data/L.atlasroi.32k_fs_LR.shape.gii"

        else
            tmpString="-right-metric"
            roiString="-roi-right $HCPPIPEDIR/ArealClassifier/data/R.atlasroi.32k_fs_LR.shape.gii"
        fi
        i=1
        AreaString="$(cat "$AreaNamesTemp" | tr '\n' ' ')"
        for Area in ${AreaString}
        do
            wb_command -cifti-create-dense-scalar "$ClassifierOutFolder/${i}_${Area}_final_area.dscalar.nii" ${tmpString} "$ClassifierOutFolder/${i}_${Area}_final_area.shape.gii" ${roiString}
            ((++i))
        done

        
        #clean up noisiness in classification, resolve overlaps
        cleanupworkdir="$(mktemp -d --tmpdir ClassificationCleanup.XXXXXX)"

        "$HCPPIPEDIR"/ArealClassifier/scripts/ClassificationCleanup.sh \
            --study-folder="$StudyFolder" \
            --subject="$Subject" \
            --low-res="$LowResMesh" \
            --surf-reg-name="$RegName" \
            --workdir="$cleanupworkdir" \
            --classifier-folder="$ClassifierOutFolder" \
            --area-names="$(cat "$AreaNamesTemp" | tr '\n' ' ')" \
            --hemisphere="$Hem" \
            --label-table="$LabelTable" \
            --parcellation="$ParcellationName" \
            --output-folder="$StudyFolder/$Subject/MNINonLinear/fsaverage_LR${LowResMesh}k" \
            --matlab-run-mode="$matlab_mode"
        
        rm -rf "$cleanupworkdir"
    done

    #merge the dlabel across hemispheres
    #WARNING: this assumes 32k
    mergeCmd=("wb_command -cifti-create-dense-from-template"
        "${HCPPIPEDIR}/global/templates/91282_Greyordinates/91282_Greyordinates.dscalar.nii"
        "${StudyFolder}/$Subject/MNINonLinear/fsaverage_LR${LowResMesh}k/$Subject.${ParcellationName}_Individual.${LowResMesh}k_fs_LR.dlabel.nii"
        "-cifti ${StudyFolder}/$Subject/MNINonLinear/fsaverage_LR${LowResMesh}k/$Subject.L.${ParcellationName}_Individual.${LowResMesh}k_fs_LR.dlabel.nii"
        "-cifti ${StudyFolder}/$Subject/MNINonLinear/fsaverage_LR${LowResMesh}k/$Subject.R.${ParcellationName}_Individual.${LowResMesh}k_fs_LR.dlabel.nii -label-collision LEGACY"
        )

    cmd="${mergeCmd[*]}"
    log_Msg "merge the dlabel across hemispheres: $cmd"
    eval "$cmd"

done
#don't delete the classifier output folder, it has the gradient output in it
