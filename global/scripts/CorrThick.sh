#!/bin/bash
set -eu

pipedirguessed=0
if [[ ""$HCPPIPEDIR:-"" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/.."
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"

#description of script/command
opts_SetScriptDescription "Run curvature corrected thickness python script and save curvatures, regression coefficients, and curvature-corrected thickness"

opts_AddMandatory '--subject-dir' 'SubjectDir' 'path' "folder containing all subjects"
opts_AddMandatory '--subject' 'Subject' 'subject ID' "subject-id"
opts_AddOptional '--regname' 'RegName' 'my reg' "set the registration name, default MSMSulc" "MSMSulc"
opts_AddOptional '--hemi' 'Hemi' 'hemisphere' "provide hemisphere for regression calculation, L=Left, R=Right, default 'L R' or B=Both" "B"
opts_AddOptional '--surf' 'Surface' 'surface' "provide surface for regression calculation, white or midthickness, default midthickness" "midthickness"
opts_AddOptional '--patch-size' 'PatchSize' 'patch size' "provide patch size for regression, default 6" "6"
opts_AddOptional '--surf-smooth' 'SurfSmooth' 'surf smooth' "provide surface smoothing fwhm, default 2.14" "2.14"
opts_AddOptional '--metric-smooth' 'MetricSmooth' 'metric smooth' "provide metric smoothing fwhm, default 2.52" "2.52"

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

#set paths
NonlinearFolder="$SubjectDir"/"$Subject"/MNINonLinear
NativeFolder="$NonlinearFolder"/Native
T1wFolder="$SubjectDir"/"$Subject"/T1w/Native

#Make intermediate directory to save intermediate files
mkdir -p "$NativeFolder"/CorrThick

#Loop through left and right hemispheres
if [[ "$Hemi" == *B* ]]
then
	Hemi="L R"
fi

MapListFunc="MRcorrThickness MRcorrThickness_curvs MRcorrThickness_coeffs MRcorrThickness_normcoeffs MRcorrThickness_intercept"
LowResMesh="32"
HighResMesh="164"

for Hemisphere in $Hemi ; do

	if [[ "$Hemisphere" == "L" ]] ; then
		Structure="CORTEX_LEFT"
	elif [[ "$Hemisphere" == "R" ]] ; then
		Structure="CORTEX_RIGHT"
	fi
	
	(
	  cd "$HCPPIPEDIR"/global/scripts/
	  python CorrThick.py "$SubjectDir" "$Subject" "$Structure" "$Hemisphere" "$Surface" "$PatchSize" "$SurfSmooth" "$MetricSmooth"
	)
	
	#Resample to HighResMesh and LowResMesh
	if [ "$RegName" = "MSMSulc" ] ; then
	  RegSphere=""$NativeFolder"/"$Subject"."$Hemisphere".sphere.MSMSulc.native.surf.gii"
	else
	  RegSphere=""$NativeFolder"/"$Subject"."$Hemisphere".sphere.reg.reg_LR.native.surf.gii"
	fi
	
	for Map in $MapListFunc ; do
	  wb_command -metric-resample "$NativeFolder"/"$Subject"."$Hemisphere"."$Map".native.shape.gii "$RegSphere" "$NonlinearFolder"/"$Subject"."$Hemisphere".sphere."$HighResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$NonlinearFolder"/"$Subject"."$Hemisphere"."$Map"."$HighResMesh"k_fs_LR.shape.gii -area-surfs "$T1wFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii "$NonlinearFolder"/"$Subject"."$Hemisphere".midthickness."$HighResMesh"k_fs_LR.surf.gii -current-roi "$NativeFolder"/"$Subject"."$Hemisphere".roi.native.shape.gii
	  wb_command -metric-resample "$NativeFolder"/"$Subject"."$Hemisphere"."$Map".native.shape.gii "$RegSphere" "$NonlinearFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere".sphere."$LowResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$NonlinearFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere"."$Map"."$LowResMesh"k_fs_LR.shape.gii -area-surfs "$T1wFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii "$NonlinearFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii -current-roi "$NativeFolder"/"$Subject"."$Hemisphere".roi.native.shape.gii
	done
done

#Create CIFTI Files in Native, HighResMesh, and LowResMesh
if [[ "$Hemi" == *L* && "$Hemi" == *R* ]] ; then
	for STRING in "$NativeFolder"@native "$NonlinearFolder"@"$HighResMesh"k_fs_LR "$NonlinearFolder/fsaverage_LR"$LowResMesh"k@"$LowResMesh"k_fs_LR" ; do
	  Folder=`echo $STRING | cut -d "@" -f 1`
	  Mesh=`echo $STRING | cut -d "@" -f 2`

	  for Map in $MapListFunc ; do
		wb_command -cifti-create-dense-scalar "$Folder"/"$Subject"."$Map"."$Mesh".dscalar.nii -left-metric "$Folder"/"$Subject".L."$Map"."$Mesh".shape.gii -right-metric "$Folder"/"$Subject".R."$Map"."$Mesh".shape.gii
	  done
	done
fi

#Remove preliminary directory and all its contents
rm -rf "$NativeFolder"/CorrThick

