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
opts_AddMandatory '--study-folder' 'StudyFolder' 'path' "folder containing all subjects"
opts_AddMandatory '--subject' 'Subject' 'subject ID' ""
opts_AddMandatory '--low-res' 'LowResMesh' 'number' "mesh resolution of classification data, probably '32'"
opts_AddOptional '--surf-reg-name' 'RegName' 'name' "the registration string corresponding to the input files"
opts_AddMandatory '--workdir' 'workdir' 'path' "folder for temporary files"
opts_AddMandatory '--classifier-folder' 'ClassifierFolder' 'name' "the folder containing the classifier output"
opts_AddMandatory '--area-names' 'AreaNamesString' 'name name ...' "list of all area names, in order, with hemisphere prefix"
opts_AddMandatory '--hemisphere' 'Hem' 'L or R' "which hemisphere to process"
opts_AddMandatory '--label-table' 'AreaColorsFile' 'file' "text file in the format for -cifti-import-label to use"
opts_AddMandatory '--parcellation' 'Parcellation' 'name' "file name part for parcellation, like CorticalAreas_dil"
opts_AddMandatory '--output-folder' 'OutputFolder' 'path' "folder for outputing the results"

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

# #probably leave this hardcoded
# OutputFolder="$StudyFolder/$Subject/MNINonLinear/fsaverage_LR${LowResMesh}k"

#processing code goes here
case "$Hem" in
    (L)
        hemisphereword="left"
        Structure="CORTEX_LEFT"
        ;;
    (R)
        hemisphereword="right"
        Structure="CORTEX_RIGHT"
        ;;
    (*)
        log_Err_Abort "--hemisphere must be 'L' or 'R', but was given '$Hem'"
        ;;
esac

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

if [[ "$RegName" == "" ]]
then
    RegSTRING=""
else
    RegSTRING="_$RegName"
fi

#hardcode some things that used to be parameters
ErodeDilateDistance="2"

T1wDownSampleFolder="$StudyFolder/$Subject/T1w/fsaverage_LR${LowResMesh}k"

tempbase="$Subject.$Hem.$Parcellation" #TODO: naming?
dscalarend="${LowResMesh}k_fs_LR.dscalar.nii"
dlabelend="${LowResMesh}k_fs_LR.dlabel.nii"
metricend="${LowResMesh}k_fs_LR.func.gii"

mergeargs=()
i=1
for Area in ${AreaNamesString}
do
    #FIXME?: currently expects Area to contain L_ and _ROI
    mergeargs+=(-cifti "$ClassifierFolder/${i}_${Area}_final_area.dscalar.nii" -column 1)
    ((++i))
done

#merge area classes on lowres mesh
wb_command -cifti-merge "$workdir/${tempbase}_AreaClasses.$dscalarend" "${mergeargs[@]}"

#Compute regions that have less than 50% probability for all areas as potential Area "Holes" and Max Probability
wb_command -cifti-reduce "$workdir/${tempbase}_AreaClasses.$dscalarend" MAX "$workdir/${tempbase}_Area_Max.$dscalarend"
wb_command -cifti-math "var < 0.5" "$workdir/${tempbase}_Area_Holes.$dscalarend" -var var "$workdir/${tempbase}_Area_Max.$dscalarend"
wb_command -set-map-names "$workdir/${tempbase}_Area_Max.$dscalarend" -map 1 ${Subject}_Area_Max
wb_command -set-map-names "$workdir/${tempbase}_Area_Holes.$dscalarend" -map 1 ${Subject}_Area_Holes

#Find The Biggest (FTB) area, make initial label file, and convert labels to ROIs
wb_command -cifti-reduce "$workdir/${tempbase}_AreaClasses.$dscalarend" INDEXMAX "$workdir/${tempbase}_AreaClasses_ftb.$dscalarend"
wb_command -cifti-label-import "$workdir/${tempbase}_AreaClasses_ftb.$dscalarend" ${AreaColorsFile} "$workdir/${tempbase}_AreaClasses_ftb.$dlabelend"
wb_command -cifti-all-labels-to-rois "$workdir/${tempbase}_AreaClasses_ftb.$dlabelend" 1 "$workdir/${tempbase}_Areas_raw.$dscalarend"

#Erode everything a little to make "core areas" 2mm
wb_command -cifti-math "(var - 1) * -1" "$workdir/${tempbase}_Areas_rawinv.$dscalarend" -var var "$workdir/${tempbase}_Areas_raw.$dscalarend" 
wb_command -cifti-dilate "$workdir/${tempbase}_Areas_rawinv.$dscalarend" COLUMN ${ErodeDilateDistance} ${ErodeDilateDistance} "$workdir/${tempbase}_Areas_core_inv.$dscalarend" -${hemisphereword}-surface "${T1wDownSampleFolder}/${Subject}.${Hem}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii" -nearest
wb_command -cifti-math "(var - 1) * -1" "$workdir/${tempbase}_Areas_core.$dscalarend" -var var "$workdir/${tempbase}_Areas_core_inv.$dscalarend"
wb_command -cifti-reduce "$workdir/${tempbase}_Areas_core.$dscalarend" MAX "$workdir/${tempbase}_Areas_core_roi.$dscalarend"

#Find clusters at 25mm on Raw, find number of clusters
wb_command -cifti-find-clusters "$workdir/${tempbase}_Areas_raw.$dscalarend" 0.99 25 0.99 125 COLUMN "$workdir/${tempbase}_Areas_raw_fc.$dscalarend" -${hemisphereword}-surface "${T1wDownSampleFolder}/${Subject}.${Hem}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii"

#Mask Raw clusters with Raw Clusters FC
wb_command -cifti-math "var * (ROI > 0)" "$workdir/${tempbase}_Areas_raw_masked.$dscalarend" -var var "$workdir/${tempbase}_Areas_raw.$dscalarend" -var ROI "$workdir/${tempbase}_Areas_raw_fc.$dscalarend"

#Dilate and Erode to connect to connect things 4mm
wb_command -cifti-dilate "$workdir/${tempbase}_Areas_raw.$dscalarend" COLUMN $((${ErodeDilateDistance}*2)) $((${ErodeDilateDistance}*2)) "$workdir/${tempbase}_Areas_dil$((${ErodeDilateDistance}*2)).$dscalarend" -${hemisphereword}-surface "${T1wDownSampleFolder}/${Subject}.${Hem}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii" -nearest
wb_command -cifti-math "(var - 1) * -1" "$workdir/${tempbase}_Areas_dil$((${ErodeDilateDistance}*2))inv.$dscalarend" -var var "$workdir/${tempbase}_Areas_dil$((${ErodeDilateDistance}*2)).$dscalarend" 
wb_command -cifti-dilate "$workdir/${tempbase}_Areas_dil$((${ErodeDilateDistance}*2))inv.$dscalarend" COLUMN $((${ErodeDilateDistance}*2)) $((${ErodeDilateDistance}*2)) "$workdir/${tempbase}_Areas_dil$((${ErodeDilateDistance}*2))inv_ero$((${ErodeDilateDistance}*2)).$dscalarend" -${hemisphereword}-surface "${T1wDownSampleFolder}/${Subject}.${Hem}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii" -nearest
wb_command -cifti-math "(var - 1) * -1" "$workdir/${tempbase}_Areas_dil$((${ErodeDilateDistance}*2))_ero$((${ErodeDilateDistance}*2)).$dscalarend" -var var "$workdir/${tempbase}_Areas_dil$((${ErodeDilateDistance}*2))inv_ero$((${ErodeDilateDistance}*2)).$dscalarend"

#Mask out core ROI from all areas and then add core back in for each area
wb_command -cifti-math "(dilero * (((coreroi > 0) - 1) * -1)) + (raw * (coreroi > 0))" "$workdir/${tempbase}_Areas_joined.$dscalarend" -var raw "$workdir/${tempbase}_Areas_raw.$dscalarend" -var dilero "$workdir/${tempbase}_Areas_dil$((${ErodeDilateDistance}*2))_ero$((${ErodeDilateDistance}*2)).$dscalarend" -var coreroi "$workdir/${tempbase}_Areas_core_roi.$dscalarend" -select 1 1 -repeat

#Find clusters at 25mm on Joined, find number of clusters
wb_command -cifti-find-clusters "$workdir/${tempbase}_Areas_joined.$dscalarend" 0.99 25 0.99 125 COLUMN "$workdir/${tempbase}_Areas_joined_fc.$dscalarend" -${hemisphereword}-surface "${T1wDownSampleFolder}/${Subject}.${Hem}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii"

#Mask Joined Clusters by Joined Clusters FC to Exclude Small Pieces
wb_command -cifti-math "var * (ROI > 0)" "$workdir/${tempbase}_Areas_joined_masked.$dscalarend" -var var "$workdir/${tempbase}_Areas_joined.$dscalarend" -var ROI "$workdir/${tempbase}_Areas_joined_fc.$dscalarend"

#Find clusters on raw to remove small pieces (in order to identify potential holes)
wb_command -cifti-find-clusters "$workdir/${tempbase}_Areas_raw.$dscalarend" 0.99 25 0.99 125 COLUMN "$workdir/${tempbase}_Areas_raw_fcsmall.$dscalarend" -${hemisphereword}-surface "${T1wDownSampleFolder}/${Subject}.${Hem}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii"

#Find fillable holes
wb_command -cifti-separate "$workdir/${tempbase}_Areas_raw_fcsmall.$dscalarend" COLUMN -metric ${Structure} "$workdir/${tempbase}_Areas_raw_fcsmall.$metricend"
wb_command -metric-math "Var > 0" "$workdir/${tempbase}_Areas_raw_fcsmall.$metricend" -var Var "$workdir/${tempbase}_Areas_raw_fcsmall.$metricend"
wb_command -metric-fill-holes "${T1wDownSampleFolder}/${Subject}.${Hem}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii" "$workdir/${tempbase}_Areas_raw_fcsmall.$metricend" "$workdir/${tempbase}_Areas_raw_fcsmall_fillableholes.$metricend"
wb_command -metric-math "Output > Input" "$workdir/${tempbase}_Areas_raw_fcsmall_fillableholes.$metricend" -var Input "$workdir/${tempbase}_Areas_raw_fcsmall.$metricend" -var Output "$workdir/${tempbase}_Areas_raw_fcsmall_fillableholes.$metricend"
wb_command -cifti-create-dense-from-template "$workdir/${tempbase}_Areas_raw_fcsmall.$dscalarend" "$workdir/${tempbase}_Areas_raw_fcsmall_fillableholes.$dscalarend" -metric ${Structure} "$workdir/${tempbase}_Areas_raw_fcsmall_fillableholes.$metricend"
wb_command -cifti-reduce "$workdir/${tempbase}_Areas_raw_fcsmall_fillableholes.$dscalarend" MAX "$workdir/${tempbase}_Areas_raw_fcsmall_fillableholes.$dscalarend"

#find parts that were zeroed by find clusters
wb_command -cifti-math "((Var > 0) - (Varfcsmall > 0)) * Fillable" "$workdir/${tempbase}_Areas_raw_fcsmallholesall.$dscalarend" -var Var "$workdir/${tempbase}_Areas_raw.$dscalarend" -var Varfcsmall "$workdir/${tempbase}_Areas_raw_fcsmall.$dscalarend" -var Fillable "$workdir/${tempbase}_Areas_raw_fcsmall_fillableholes.$dscalarend" -select 1 1 -repeat

#reduce this to get single map mask
wb_command -cifti-reduce "$workdir/${tempbase}_Areas_raw_fcsmallholesall.$dscalarend" MAX "$workdir/${tempbase}_Areas_raw_fcsmallholes.$dscalarend"

#Mask joined_fc by the removed pieces from above find clusters to identify conflict areas
wb_command -cifti-math "(Var * Holes)" "$workdir/${tempbase}_Areas_raw_fcsmallholesconflicts.$dscalarend" -var Var "$workdir/${tempbase}_Areas_joined.$dscalarend" -var Holes "$workdir/${tempbase}_Areas_raw_fcsmallholes.$dscalarend" -select 1 1 -repeat

#reduce by sum to count number of conflicts at each ordinate
wb_command -cifti-reduce "$workdir/${tempbase}_Areas_raw_fcsmallholesconflicts.$dscalarend" SUM "$workdir/${tempbase}_Areas_raw_fcsmallholesconflicts.$dscalarend"

#add joinedFC maps to raw maps everywhere there are 2 competing areas, and mask out the per-map potential holes where there are two competing areas
wb_command -cifti-math "(Raw || ((Conflicts == 2) * Joined)) * (1 - (HolesAll * (Conflicts == 2)))" "$workdir/${tempbase}_Areas_raw_new.$dscalarend" -var Joined "$workdir/${tempbase}_Areas_joined.$dscalarend" -var Raw "$workdir/${tempbase}_Areas_raw.$dscalarend" -var Conflicts "$workdir/${tempbase}_Areas_raw_fcsmallholesconflicts.$dscalarend" -select 1 1 -repeat -var HolesAll "$workdir/${tempbase}_Areas_raw_fcsmallholesall.$dscalarend"

#Find clusters at 25mm on Raw, find number of clusters
wb_command -cifti-find-clusters "$workdir/${tempbase}_Areas_raw_new.$dscalarend" 0.99 25 0.99 125 COLUMN "$workdir/${tempbase}_Areas_raw_new_fc.$dscalarend" -${hemisphereword}-surface "${T1wDownSampleFolder}/${Subject}.${Hem}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii"

#Mask Raw clusters with Raw Clusters FC
wb_command -cifti-math "var * (ROI > 0)" "$workdir/${tempbase}_Areas_raw_new_masked.$dscalarend" -var var "$workdir/${tempbase}_Areas_raw_new.$dscalarend" -var ROI "$workdir/${tempbase}_Areas_raw_new_fc.$dscalarend"

#Erode everything a little to make "core areas" 2mm
wb_command -cifti-math "(var - 1) * -1" "$workdir/${tempbase}_Areas_raw_newinv.$dscalarend" -var var "$workdir/${tempbase}_Areas_raw_new.$dscalarend" 
wb_command -cifti-dilate "$workdir/${tempbase}_Areas_raw_newinv.$dscalarend" COLUMN ${ErodeDilateDistance} ${ErodeDilateDistance} "$workdir/${tempbase}_Areas_core_new_inv.$dscalarend" -${hemisphereword}-surface "${T1wDownSampleFolder}/${Subject}.${Hem}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii" -nearest
wb_command -cifti-math "(var - 1) * -1" "$workdir/${tempbase}_Areas_core_new.$dscalarend" -var var "$workdir/${tempbase}_Areas_core_new_inv.$dscalarend"
wb_command -cifti-reduce "$workdir/${tempbase}_Areas_core_new.$dscalarend" MAX "$workdir/${tempbase}_Areas_core_new_roi.$dscalarend"

#Dilate and Erode to connect to connect things 4mm
wb_command -cifti-dilate "$workdir/${tempbase}_Areas_raw_new.$dscalarend" COLUMN $((${ErodeDilateDistance}*2)) $((${ErodeDilateDistance}*2)) "$workdir/${tempbase}_Areas_dil$((${ErodeDilateDistance}*2))_new.$dscalarend" -${hemisphereword}-surface "${T1wDownSampleFolder}/${Subject}.${Hem}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii" -nearest
wb_command -cifti-math "(var - 1) * -1" "$workdir/${tempbase}_Areas_dil$((${ErodeDilateDistance}*2))inv_new.$dscalarend" -var var "$workdir/${tempbase}_Areas_dil$((${ErodeDilateDistance}*2))_new.$dscalarend" 
wb_command -cifti-dilate "$workdir/${tempbase}_Areas_dil$((${ErodeDilateDistance}*2))inv_new.$dscalarend" COLUMN $((${ErodeDilateDistance}*2)) $((${ErodeDilateDistance}*2)) "$workdir/${tempbase}_Areas_dil$((${ErodeDilateDistance}*2))inv_ero$((${ErodeDilateDistance}*2))_new.$dscalarend" -${hemisphereword}-surface "${T1wDownSampleFolder}/${Subject}.${Hem}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii" -nearest
wb_command -cifti-math "(var - 1) * -1" "$workdir/${tempbase}_Areas_dil$((${ErodeDilateDistance}*2))_ero$((${ErodeDilateDistance}*2))_new.$dscalarend" -var var "$workdir/${tempbase}_Areas_dil$((${ErodeDilateDistance}*2))inv_ero$((${ErodeDilateDistance}*2))_new.$dscalarend"

#Mask out core ROI from all areas and then add core back in for each area
wb_command -cifti-math "(dilero * (((coreroi > 0) - 1) * -1)) + (raw * (coreroi > 0))" "$workdir/${tempbase}_Areas_joined_new.$dscalarend" -var raw "$workdir/${tempbase}_Areas_raw_new.$dscalarend" -var dilero "$workdir/${tempbase}_Areas_dil$((${ErodeDilateDistance}*2))_ero$((${ErodeDilateDistance}*2))_new.$dscalarend" -var coreroi "$workdir/${tempbase}_Areas_core_new_roi.$dscalarend" -select 1 1 -repeat

#Find clusters at 25mm on Joined, find number of clusters
wb_command -cifti-find-clusters "$workdir/${tempbase}_Areas_joined_new.$dscalarend" 0.99 25 0.99 125 COLUMN "$workdir/${tempbase}_Areas_joined_new_fc.$dscalarend" -${hemisphereword}-surface "${T1wDownSampleFolder}/${Subject}.${Hem}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii"

#Mask Joined Clusters by Joined Clusters FC to Exclude Small Pieces
wb_command -cifti-math "var * (ROI > 0)" "$workdir/${tempbase}_Areas_joined_new_masked.$dscalarend" -var var "$workdir/${tempbase}_Areas_joined_new.$dscalarend" -var ROI "$workdir/${tempbase}_Areas_joined_new_fc.$dscalarend"

#Find number of clusters for each area, if Joined > Raw, then mask out Joined from all areas and insert Joined into the correct area location.  Also, check for overlap between Joined areas and mask out any overlapping vertices
Raw="$workdir/${tempbase}_Areas_raw_new_masked.$dscalarend"
Joined="$workdir/${tempbase}_Areas_joined_new_masked.$dscalarend"
JoinedFC="$workdir/${tempbase}_Areas_joined_new_fc.$dscalarend"
RawFC="$workdir/${tempbase}_Areas_raw_new_fc.$dscalarend"
RobustJoinedOutput="$workdir/${tempbase}_Areas_robustjoined.${LowResMesh}k_fs_LR"
VA="$workdir/${Subject}.${Hem}.midthickness${RegSTRING}_va.$dscalarend"
Surface="${T1wDownSampleFolder}/${Subject}.${Hem}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii"

#Temp Create Hemisphere Vertex Areas
wb_command -cifti-separate "${T1wDownSampleFolder}/${Subject}.midthickness${RegSTRING}_va.$dscalarend" COLUMN -metric ${Structure} "$workdir/temp.func.gii" -roi "$workdir/temproi.func.gii"
wb_command -cifti-create-dense-scalar "$VA" -${hemisphereword}-metric "$workdir/temp.func.gii" -roi-${hemisphereword} "$workdir/temproi.func.gii"

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

        matlabCode="addpath '$mPath'; addpath '$mGlobalPath';
            ProcessArealClassification('${Raw}', '${Joined}', '${JoinedFC}', '${RawFC}', '${RobustJoinedOutput}', '${VA}', '${Surface}', '${hemisphereword}');"
        
        log_Msg "Run matlab: $matlabCode"
        "${interpreter[@]}" <<<"$matlabCode"
        ;;
    (*)
        log_Err_Abort "unrecognized matlab mode: $matlab_mode"
        ;;
esac

#Find clusters at 25mm on RobustJoined
wb_command -cifti-find-clusters "$workdir/${tempbase}_Areas_robustjoined.$dscalarend" 0.99 25 0.99 125 COLUMN "$workdir/${tempbase}_Areas_robustjoined_fc.$dscalarend" -size-ratio 0.33 0.33 -distance 30 30 -${hemisphereword}-surface "${T1wDownSampleFolder}/${Subject}.${Hem}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii"
wb_command -cifti-math "var > 0" "$workdir/${tempbase}_Areas_robustjoined_fcroi.$dscalarend" -var var "$workdir/${tempbase}_Areas_robustjoined_fc.$dscalarend"

#Erode and Dilate
wb_command -cifti-math "(var - 1) * -1" "$workdir/${tempbase}_Areas_robustjoined_fcroiinv.$dscalarend" -var var "$workdir/${tempbase}_Areas_robustjoined_fcroi.$dscalarend" 
wb_command -cifti-dilate "$workdir/${tempbase}_Areas_robustjoined_fcroiinv.$dscalarend" COLUMN ${ErodeDilateDistance} ${ErodeDilateDistance} "$workdir/${tempbase}_Areas_robustjoined_fcroi_ero${ErodeDilateDistance}_inv.$dscalarend" -${hemisphereword}-surface "${T1wDownSampleFolder}/${Subject}.${Hem}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii" -nearest
wb_command -cifti-math "(var - 1) * -1" "$workdir/${tempbase}_Areas_robustjoined_fcroi_ero${ErodeDilateDistance}.$dscalarend" -var var "$workdir/${tempbase}_Areas_robustjoined_fcroi_ero${ErodeDilateDistance}_inv.$dscalarend"
wb_command -cifti-dilate "$workdir/${tempbase}_Areas_robustjoined_fcroi_ero${ErodeDilateDistance}.$dscalarend" COLUMN ${ErodeDilateDistance} ${ErodeDilateDistance} "$workdir/${tempbase}_Areas_robustjoined_fcroi_ero${ErodeDilateDistance}_dil${ErodeDilateDistance}.$dscalarend" -${hemisphereword}-surface "${T1wDownSampleFolder}/${Subject}.${Hem}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii" -nearest

cp "$workdir/${tempbase}_Areas_robustjoined_fcroi_ero${ErodeDilateDistance}_dil${ErodeDilateDistance}.$dscalarend" "$workdir/${tempbase}_Areas_Last.$dscalarend"


#Find The Biggest (FTB) area
wb_command -cifti-reduce "$workdir/${tempbase}_Areas_Last.$dscalarend" INDEXMAX "$workdir/${tempbase}_Areas_Last_ftb.$dscalarend"
wb_command -cifti-reduce "$workdir/${tempbase}_Areas_Last.$dscalarend" MAX "$workdir/${tempbase}_Areas_Last_max.$dscalarend"
wb_command -cifti-math "var * (ROI > 0)" "$workdir/${tempbase}_Areas_Last_ftb.$dscalarend" -var var "$workdir/${tempbase}_Areas_Last_ftb.$dscalarend" -var ROI "$workdir/${tempbase}_Areas_Last_max.$dscalarend"

#Find robust area holes
wb_command -cifti-math "var > 0" "$workdir/${tempbase}_Areas_Last_ftb_roi.$dscalarend" -var var "$workdir/${tempbase}_Areas_Last_ftb.$dscalarend"
wb_command -cifti-dilate "$workdir/${tempbase}_Areas_Last_ftb_roi.$dscalarend" COLUMN ${ErodeDilateDistance} ${ErodeDilateDistance} "$workdir/${tempbase}_Robust_Area_Holes.$dscalarend" -${hemisphereword}-surface "${T1wDownSampleFolder}/${Subject}.${Hem}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii" -nearest
wb_command -cifti-math "(var - 1) * -1" "$workdir/${tempbase}_Robust_Area_Holes.$dscalarend" -var var "$workdir/${tempbase}_Robust_Area_Holes.$dscalarend"
wb_command -cifti-dilate "$workdir/${tempbase}_Robust_Area_Holes.$dscalarend" COLUMN ${ErodeDilateDistance} ${ErodeDilateDistance} "$workdir/${tempbase}_Robust_Area_Holes.$dscalarend" -${hemisphereword}-surface "${T1wDownSampleFolder}/${Subject}.${Hem}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii" -nearest
wb_command -cifti-find-clusters "$workdir/${tempbase}_Robust_Area_Holes.$dscalarend" 0.99 25 0.99 125 COLUMN "$workdir/${tempbase}_Robust_Area_Holes.$dscalarend" -${hemisphereword}-surface "${T1wDownSampleFolder}/${Subject}.${Hem}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii"
wb_command -cifti-math "var > 0" "$workdir/${tempbase}_Robust_Area_Holes.$dscalarend" -var var "$workdir/${tempbase}_Robust_Area_Holes.$dscalarend"   
wb_command -set-map-names "$workdir/${tempbase}_Robust_Area_Holes.$dscalarend" -map 1 ${Subject}_Robust_Area_Holes

#Finish Dilating, make final label file, and convert labels to ROIs
###Fixed Dilation 10mm --> 20mm to make sure dilation is complete in larger holes 5/22/17 w/ Tim to solve holes in parcellation
wb_command -cifti-dilate "$workdir/${tempbase}_Areas_Last_ftb.$dscalarend" COLUMN 20 20 "$workdir/${tempbase}_Areas_Last_ftb.$dscalarend" -${hemisphereword}-surface "${T1wDownSampleFolder}/${Subject}.${Hem}.midthickness${RegSTRING}.${LowResMesh}k_fs_LR.surf.gii" -nearest
wb_command -cifti-label-import "$workdir/${tempbase}_Areas_Last_ftb.$dscalarend" ${AreaColorsFile} "$workdir/${tempbase}_Individual.$dlabelend"
wb_command -cifti-all-labels-to-rois "$workdir/${tempbase}_Individual.$dlabelend" 1 "$workdir/${tempbase}_Areas.$dscalarend"

#main outputs
cp "$workdir/${tempbase}_Individual.$dlabelend" "$workdir/${tempbase}_Areas.$dscalarend" "$OutputFolder"

#Find classifications that changed from Raw to Final
wb_command -cifti-math "(abs(Final - Raw)) > 0" "$workdir/${tempbase}_Areas_MisClassified.$dscalarend" -var Final "$workdir/${tempbase}_Areas_Last_ftb.$dscalarend" -var Raw "$workdir/${tempbase}_AreaClasses_ftb.$dscalarend"
wb_command -set-map-names "$workdir/${tempbase}_Areas_MisClassified.$dscalarend" -map 1 ${Subject}_Area_MisClassified

#Find greater than 50% classifications that changed from Raw to Final
wb_command -cifti-math "Var * ((ROI - 1) * -1)" "$workdir/${tempbase}_Areas_StronglyMisClassified.$dscalarend" -var Var "$workdir/${tempbase}_Areas_MisClassified.$dscalarend" -var ROI "$workdir/${tempbase}_Area_Holes.$dscalarend"
wb_command -set-map-names "$workdir/${tempbase}_Areas_StronglyMisClassified.$dscalarend" -map 1 ${Subject}_Area_StronglyMisClassified

#Merge Stats
wb_command -cifti-merge "$workdir/${tempbase}_AreaClasses_Stats.$dscalarend" -cifti "$workdir/${tempbase}_Area_Max.$dscalarend" -cifti "$workdir/${tempbase}_Area_Holes.$dscalarend" -cifti "$workdir/${tempbase}_Robust_Area_Holes.$dscalarend" -cifti "$workdir/${tempbase}_Areas_MisClassified.$dscalarend" -cifti "$workdir/${tempbase}_Areas_StronglyMisClassified.$dscalarend"

cp "$workdir/${tempbase}_AreaClasses_Stats.$dscalarend" "$workdir/${tempbase}_Area_Max.$dscalarend"  "$workdir/${tempbase}_Area_Holes.$dscalarend" "$workdir/${tempbase}_Robust_Area_Holes.$dscalarend"  "$workdir/${tempbase}_Areas_MisClassified.$dscalarend" "$workdir/${tempbase}_Areas_StronglyMisClassified.$dscalarend" "$OutputFolder"
