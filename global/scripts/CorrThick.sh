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
opts_AddMandatory '--regname' 'RegName' 'my reg' "set the desired registration name(s) separated by @, 'string' 'RegName@RegName@RegName@...etc.' use MSMSulc as default"
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

RegNames=`echo "$RegName" | sed s/"@"/" "/g`

LowResMesh="32"
HighResMesh="164"
MapListFunc="MRcorrThickness MRcorrThickness_intercept MRcorrThickness_normcoeffs MRcorrThickness_curvs MRcorrThickness_coeffs"

#Generate MRcorrThickness in Native Space
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
done	

#Set the Color Palette(s) and Resample to HighResMesh and LowResMesh
for Hemisphere in $Hemi ; do

	for Map in $MapListFunc ; do
		if [[ "$Map" == MRcorrThickness || "$Map" == MRcorrThickness_intercept ]] ; then
			wb_command -metric-palette "$NativeFolder"/"$Subject"."$Hemisphere"."$Map".native.shape.gii MODE_AUTO_SCALE_PERCENTAGE -pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false -normalization NORMALIZATION_SELECTED_MAP_DATA
		elif [[ "$Map" == MRcorrThickness_normcoeffs ]] ; then
			wb_command -metric-palette "$NativeFolder"/"$Subject"."$Hemisphere"."$Map".native.shape.gii MODE_AUTO_SCALE_ABSOLUTE_PERCENTAGE -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false -normalization NORMALIZATION_ALL_MAP_DATA
		else
			wb_command -metric-palette "$NativeFolder"/"$Subject"."$Hemisphere"."$Map".native.shape.gii MODE_AUTO_SCALE_ABSOLUTE_PERCENTAGE -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false -normalization NORMALIZATION_SELECTED_MAP_DATA
		fi
	done 
	
	for RegName in $RegNames ; do
		RegSphere=""$NativeFolder"/"$Subject"."$Hemisphere".sphere."$RegName".native.surf.gii"

		if [[ "$RegName" == "MSMSulc" ]] ; then
			RegString=""
		else
			RegString="_"$RegName""
		fi
		for Map in $MapListFunc ; do
			wb_command -metric-resample "$NativeFolder"/"$Subject"."$Hemisphere"."$Map".native.shape.gii "$RegSphere" "$NonlinearFolder"/"$Subject"."$Hemisphere".sphere."$HighResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$NonlinearFolder"/"$Subject"."$Hemisphere"."$Map""$RegString"."$HighResMesh"k_fs_LR.shape.gii -area-surfs "$T1wFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii "$NonlinearFolder"/"$Subject"."$Hemisphere".midthickness."$HighResMesh"k_fs_LR.surf.gii -current-roi "$NativeFolder"/"$Subject"."$Hemisphere".roi.native.shape.gii
			wb_command -metric-mask "$NonlinearFolder"/"$Subject"."$Hemisphere"."$Map""$RegString"."$HighResMesh"k_fs_LR.shape.gii "$NonlinearFolder"/"$Subject"."$Hemisphere".atlasroi."$HighResMesh"k_fs_LR.shape.gii "$NonlinearFolder"/"$Subject"."$Hemisphere"."$Map""$RegString"."$HighResMesh"k_fs_LR.shape.gii
			wb_command -metric-resample "$NativeFolder"/"$Subject"."$Hemisphere"."$Map".native.shape.gii "$RegSphere" "$NonlinearFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere".sphere."$LowResMesh"k_fs_LR.surf.gii ADAP_BARY_AREA "$NonlinearFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere"."$Map""$RegString"."$LowResMesh"k_fs_LR.shape.gii -area-surfs "$T1wFolder"/"$Subject"."$Hemisphere".midthickness.native.surf.gii "$NonlinearFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere".midthickness."$LowResMesh"k_fs_LR.surf.gii -current-roi "$NativeFolder"/"$Subject"."$Hemisphere".roi.native.shape.gii
			wb_command -metric-mask "$NonlinearFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere"."$Map""$RegString"."$LowResMesh"k_fs_LR.shape.gii "$NonlinearFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere".atlasroi."$LowResMesh"k_fs_LR.shape.gii "$NonlinearFolder"/fsaverage_LR"$LowResMesh"k/"$Subject"."$Hemisphere"."$Map""$RegString"."$LowResMesh"k_fs_LR.shape.gii
		done
	done
done

#Create CIFTI Files in Native, HighResMesh, and LowResMesh
if [[ "$Hemi" == *L* && "$Hemi" == *R* ]] ; then
	for STRING in "$NativeFolder"@native@roi "$NonlinearFolder"@"$HighResMesh"k_fs_LR@atlasroi "$NonlinearFolder/fsaverage_LR"$LowResMesh"k@"$LowResMesh"k_fs_LR@atlasroi" ; do
		Folder=`echo $STRING | cut -d "@" -f 1`
		Mesh=`echo $STRING | cut -d "@" -f 2`
		ROI=`echo $STRING | cut -d "@" -f 3`
	  
		for RegName in $RegNames ; do
			if [[ "$RegName" == "MSMSulc" || "$Folder" == "$NativeFolder" ]] ; then
				RegString=""
			else
				RegString="_"$RegName""
			fi
	
			for Map in $MapListFunc ; do
				wb_command -cifti-create-dense-scalar "$Folder"/"$Subject"."$Map""$RegString"."$Mesh".dscalar.nii -left-metric "$Folder"/"$Subject".L."$Map""$RegString"."$Mesh".shape.gii -roi-left "$Folder"/"$Subject".L."$ROI"."$Mesh".shape.gii -right-metric "$Folder"/"$Subject".R."$Map""$RegString"."$Mesh".shape.gii -roi-right "$Folder"/"$Subject".R."$ROI"."$Mesh".shape.gii
				if [[ "$Map" == MRcorrThickness || "$Map" == MRcorrThickness_intercept ]] ; then
					wb_command -cifti-palette "$Folder"/"$Subject"."$Map""$RegString"."$Mesh".dscalar.nii MODE_AUTO_SCALE_PERCENTAGE "$Folder"/"$Subject"."$Map""$RegString"."$Mesh".dscalar.nii -pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false -normalization NORMALIZATION_SELECTED_MAP_DATA
				elif [[ "$Map" == MRcorrThickness_normcoeffs ]] ; then
					wb_command -cifti-palette "$Folder"/"$Subject"."$Map""$RegString"."$Mesh".dscalar.nii MODE_AUTO_SCALE_ABSOLUTE_PERCENTAGE "$Folder"/"$Subject"."$Map""$RegString"."$Mesh".dscalar.nii -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false -normalization NORMALIZATION_ALL_MAP_DATA
				else
					wb_command -cifti-palette "$Folder"/"$Subject"."$Map""$RegString"."$Mesh".dscalar.nii MODE_AUTO_SCALE_ABSOLUTE_PERCENTAGE "$Folder"/"$Subject"."$Map""$RegString"."$Mesh".dscalar.nii -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false -normalization NORMALIZATION_SELECTED_MAP_DATA
				fi
			done
			if [[ "$Folder" == "$NativeFolder" ]] ; then
				break
			fi
		done
	done
fi

#Remove preliminary directory and all its contents
rm -rf "$NativeFolder"/CorrThick

