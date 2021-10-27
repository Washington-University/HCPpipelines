#!/bin/bash
set -eu
# skeleton grabbed from ComputerGroupTICA.sh

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/tempfiles.shlib"
#FIXME: no compiled matlab support
g_matlab_default_mode=1

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
opts_AddMandatory '--out-group-name' 'GroupAverageName' 'string' 'name to use for the group output folder'
opts_AddMandatory '--subject-list' 'SubjListRaw' '100206@100307...' 'list of subject IDs separated by @s'
opts_AddMandatory '--fmri-list' 'fMRIListRaw' 'rfMRI_REST1_RL@rfMRI_REST1_LR...' 'list of runs used in sICA, in the SAME ORDER, separated by @s'
opts_AddMandatory '--fmri-output-name' 'OutputfMRIName' 'string' "name for the output fMRI data, like 'rfMRI_REST_7T'"
opts_AddMandatory '--ica-dim' 'tICAdims' 'integer' "number of temporal ICA components"
opts_AddMandatory '--proc-string' 'ProcString' 'string' "preprocessing already done, like '_hp0_clean', '_hp2000_clean_reclean'"
opts_AddMandatory '--tica-proc-string' 'tICAProcString' 'string' "name part to use for some outputs, like 'rfMRI_REST_d84_WF6_GROUPAVERAGENAME_WR'"
opts_AddMandatory '--fmri-resolution' 'fMRIResolution' 'string' "resolution of data, like '2' or '1.60' "
opts_AddMandatory '--surf-reg-name' 'RegName' 'MSMAll' "the registration string corresponding to the input files"
opts_AddMandatory '--low-res' 'LowResMesh' 'meshnum' "mesh resolution, like '32' for 32k_fs_LR"

# DVARS and GS related
opts_AddMandatory '--melodic-high-pass' 'HighPass' 'integer' 'the high pass value that was used when running FIX'
opts_AddOptional '--mrfix-concat-name' 'MRFixConcatName' 'rfMRI_REST' "if MR FIX was used, you must specify the concat name with this option"
opts_AddOptional '--reclean-mode' 'RecleanModeString' 'YES or NO' 'whether the data should use ReCleanSignal.txt for DVARS' 'NO'

# other 
opts_AddOptional '--save-features' 'ToSaveFeatures' 'YES or NO' 'whether to save feature spreadsheet' 'YES'
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

#FIXME: hardcoded naming conventions, move these to high level script when ready
OutputFolder="$StudyFolder/$GroupAverageName/MNINonLinear/Results/$OutputfMRIName/tICA_d$tICAdims"

RegString=""
if [[ "$RegName" != "" && "$RegName" != "MSMSulc" ]]
then
    RegString="_$RegName"
fi

case "$MatlabMode" in
    (0)
        log_Err_Abort "FIXME: compiled matlab support not yet implemented"
        ;;
    (1)
        #NOTE: figure() is required by the spectra option, and -nojvm prevents using figure()
        matlab_interpreter=(matlab -nodisplay -nosplash)
        ;;
    (2)
        matlab_interpreter=(octave-cli -q --no-window-system)
        ;;
    (*)
        log_Err_Abort "unrecognized matlab mode '$MatlabMode', use 0, 1, or 2"
        ;;
esac

IFS='@' read -a SubjList <<<"$SubjListRaw"
IFS='@' read -a fMRIList <<<"$fMRIListRaw"

SubjListName="$OutputFolder/SubjectList.txt"
fMRIListName="$OutputFolder/fMRIList.txt"

#FIXME: default files
CorticalParcellationFile="$HCPPIPEDIR/global/templates/tICA/Q1-Q6_RelatedValidation210.CorticalAreas_dil_Final_Final_Areas_Group_Colors.32k_fs_LR.dlabel.nii"
ParcelReorderFile="$HCPPIPEDIR/global/templates/tICA/rfMRI_REST_Atlas_MSMAll_2_d41_WRN_DeDrift_hp2000_clean_tclean_nobias_vn_BC_CorticalAreas_dil_210V_MPM_Group_group_z_mean_TestII.txt"
NiftiTemplateFile="$HCPPIPEDIR/global/templates/tICA/Nifti_Template.1.60.nii.gz"
VascularTerritoryFile="$HCPPIPEDIR/global/templates/tICA/Vascular_Territory.1.60.nii.gz"

CorticalParcellationFileName="$OutputFolder/CorticalParcellationFile.txt"
ParcelReorderFileName="$OutputFolder/ParcelReorderFile.txt"
NiftiTemplateFileName="$OutputFolder/NiftiTemplateFile.txt"
VascularTerritoryFileName="$OutputFolder/VascularTerritoryFile.txt"

tempfiles_add "$SubjListName" "$fMRIListName" "$CorticalParcellationFileName" "$ParcelReorderFileName" "$NiftiTemplateFileName" "$VascularTerritoryFileName"

rm -f -- "$SubjListName" "$fMRIListName" "$CorticalParcellationFileName" "$ParcelReorderFileName" "$NiftiTemplateFileName" "$VascularTerritoryFileName"

for Subject in "${SubjList[@]}"
do
    echo "$Subject" >> "$SubjListName"
done

for fMRIName in "${fMRIList[@]}"
do
    echo "${fMRIName}" >> "$fMRIListName"
done

echo "${CorticalParcellationFile}" >> "$CorticalParcellationFileName"
echo "${ParcelReorderFile}" >> "$ParcelReorderFileName"
echo "${NiftiTemplateFile}" >> "$NiftiTemplateFileName"
echo "${VascularTerritoryFile}" >> "$VascularTerritoryFileName"

matlabcode="
    addpath('$HCPPIPEDIR/global/matlab');
    addpath('$HCPPIPEDIR/global/templates');
    addpath('$HCPPIPEDIR/tICA/scripts/feature_helpers');
    addpath('$HCPPIPEDIR/tICA/scripts');
    ComputeTICAFeatures('$StudyFolder', '$GroupAverageName', '$SubjListName', '$fMRIListName','$OutputfMRIName', '$tICAdims', '$ProcString', '$tICAProcString', '$fMRIResolution', '$RegString', '$LowResMesh', '$ToSaveFeatures', '$HighPass', '$MRFixConcatName', '$RecleanModeString', '$CorticalParcellationFileName', '$ParcelReorderFileName', '$NiftiTemplateFileName', '$VascularTerritoryFileName');"

log_Msg "running matlab code: $matlabcode"
"${matlab_interpreter[@]}" <<<"$matlabcode"
echo

