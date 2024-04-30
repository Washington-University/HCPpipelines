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
opts_SetScriptDescription "Run MSMSulc registration and save distortion outputs"

opts_AddMandatory '--subject-dir' 'SubjectDir' 'path' "folder containing all subjects"
opts_AddMandatory '--subject' 'Subject' 'subject ID' "subject-id"
opts_AddMandatory '--regname' 'RegName' 'my reg' "set a new registration name"
opts_AddOptional '--msm-conf' 'ConfFile' 'conf file' "provide the name of the configuration file, default MSMSulcStrainFinalconf" "$MSMCONFIGDIR"/MSMSulcStrainFinalconf
opts_AddOptional '--hemi' 'Hemi' 'hemisphere' "provide hemisphere for registration, L=Left, R=Right, default B=Both" "B"
opts_AddOptional '--refmesh' 'RefMesh' 'ref mesh' "provide alternate standard sphere, default 164k_fs_LR, use .HEMISPHERE. instead of .L. or .R."
opts_AddOptional '--refdata' 'RefData' 'ref data' "provide alternate reference data, use .HEMISPHERE. instead of .L. or .R."

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

#display the parsed/default values
opts_ShowValues

#set paths
SurfaceTemplateFolder="$HCPPIPEDIR"/global/templates/standard_mesh_atlases
NonlinearFolder="$SubjectDir"/"$Subject"/MNINonLinear
NativeFolder="$NonlinearFolder"/Native

#if user provided --refmesh but not --refdata, scream
if [[ "$RefMesh" != "" && "$RefData" == "" ]]
then
	log_Err_Abort "Non-default standard sphere provided, but no non-default reference data"
fi

if [[ "$RefMesh" == "" ]]
then
	RefMesh="$SurfaceTemplateFolder"/fsaverage.HEMISPHERE_LR.spherical_std.164k_fs_LR.surf.gii
fi

if [[ "$RefData" == "" ]]
then
	RefData="$SurfaceTemplateFolder"/HEMISPHERE.refsulc.164k_fs_LR.shape.gii
fi

#Make MSMSulc Directory
mkdir -p "$NativeFolder"/"$RegName"

#Loop through left and right hemispheres
if [[ "$Hemi" == *B* ]]
then
	Hemi="L R"
fi

for Hemisphere in $Hemi ; do

	if [[ "$Hemisphere" == "L" ]] ; then
		Structure="CORTEX_LEFT"
	elif [[ "$Hemisphere" == "R" ]] ; then
		Structure="CORTEX_RIGHT"
	else
		log_Err_Abort "unrecognized hemisphere identifier '$Hemisphere', use L, R, or B for both"
	fi
	  
	#convert relative to absolute for correctness after cd, restrict HEMISPHERE replacement to filename only
	RefMeshFile=$(basename -- "$RefMesh")
	ReferenceMesh="$(cd "$(dirname -- "$RefMesh")"; pwd)/${RefMeshFile/HEMISPHERE/$Hemisphere}"
	RefDataFile=$(basename -- "$RefData")
	ReferenceData="$(cd "$(dirname -- "$RefData")"; pwd)/${RefDataFile/HEMISPHERE/$Hemisphere}"
	(
		cd "$NativeFolder"/"$RegName"

		#Register using FreeSurfer Sulc Folding Map Using MSM Algorithm Configured for Reduced Distortion
		"$MSMBINDIR"/msm --conf="$ConfFile" --inmesh="$NativeFolder"/"$Subject"."$Hemisphere".sphere.rot.native.surf.gii --refmesh="$ReferenceMesh" --indata="$NativeFolder"/"$Subject"."$Hemisphere".sulc.native.shape.gii --refdata="$ReferenceData" --out="$NativeFolder"/"$RegName"/"$Hemisphere". --verbose
	)

	cp "$ConfFile" "$NativeFolder"/"$RegName"/"$Hemisphere".logdir/conf
	cp "$NativeFolder"/"$RegName"/"$Hemisphere".sphere.reg.surf.gii "$NativeFolder"/"$Subject"."$Hemisphere".sphere."$RegName".native.surf.gii
	
	wb_command -set-structure "$NativeFolder"/"$Subject"."$Hemisphere".sphere."$RegName".native.surf.gii "$Structure"

	wb_command -surface-distortion "$NativeFolder"/"$Subject"."$Hemisphere".sphere.native.surf.gii "$NativeFolder"/"$Subject"."$Hemisphere".sphere."$RegName".native.surf.gii "$NativeFolder"/"$Subject"."$Hemisphere".ArealDistortion_"$RegName".native.shape.gii
	wb_command -set-map-names "$NativeFolder"/"$Subject"."$Hemisphere".ArealDistortion_"$RegName".native.shape.gii -map 1 "$Subject"_"$Hemisphere"_Areal_Distortion_"$RegName"
	wb_command -metric-palette "$NativeFolder"/"$Subject"."$Hemisphere".ArealDistortion_"$RegName".native.shape.gii MODE_AUTO_SCALE -palette-name ROY-BIG-BL -thresholding THRESHOLD_TYPE_NORMAL THRESHOLD_TEST_SHOW_OUTSIDE -1 1

	wb_command -surface-distortion "$NativeFolder"/"$Subject"."$Hemisphere".sphere.native.surf.gii "$NativeFolder"/"$Subject"."$Hemisphere".sphere."$RegName".native.surf.gii "$NativeFolder"/"$Subject"."$Hemisphere".EdgeDistortion_"$RegName".native.shape.gii -edge-method
	wb_command -surface-distortion "$NativeFolder"/"$Subject"."$Hemisphere".sphere.native.surf.gii "$NativeFolder"/"$Subject"."$Hemisphere".sphere."$RegName".native.surf.gii "$NativeFolder"/"$Subject"."$Hemisphere".Strain_"$RegName".native.shape.gii -local-affine-method -log2

	wb_command -metric-merge "$NativeFolder"/"$Subject"."$Hemisphere".StrainJ_"$RegName".native.shape.gii -metric "$NativeFolder"/"$Subject"."$Hemisphere".Strain_"$RegName".native.shape.gii -column 1
	wb_command -metric-merge "$NativeFolder"/"$Subject"."$Hemisphere".StrainR_"$RegName".native.shape.gii -metric "$NativeFolder"/"$Subject"."$Hemisphere".Strain_"$RegName".native.shape.gii -column 2

	rm "$NativeFolder"/"$Subject"."$Hemisphere".Strain_"$RegName".native.shape.gii
done

if [[ "$Hemi" == *L* && "$Hemi" == *R* ]] ; then
	#Create CIFTI Files
	wb_command -cifti-create-dense-scalar "$NativeFolder"/"$Subject".ArealDistortion_"$RegName".native.dscalar.nii -left-metric "$NativeFolder"/"$Subject".L.ArealDistortion_"$RegName".native.shape.gii -right-metric "$NativeFolder"/"$Subject".R.ArealDistortion_"$RegName".native.shape.gii
	wb_command -set-map-names "$NativeFolder"/"$Subject".ArealDistortion_"$RegName".native.dscalar.nii -map 1 "$Subject"_ArealDistortion_"$RegName"
	wb_command -cifti-palette "$NativeFolder"/"$Subject".ArealDistortion_"$RegName".native.dscalar.nii MODE_USER_SCALE "$NativeFolder"/"$Subject".ArealDistortion_"$RegName".native.dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false

	wb_command -cifti-create-dense-scalar "$NativeFolder"/"$Subject".EdgeDistortion_"$RegName".native.dscalar.nii -left-metric "$NativeFolder"/"$Subject".L.EdgeDistortion_"$RegName".native.shape.gii -right-metric "$NativeFolder"/"$Subject".R.EdgeDistortion_"$RegName".native.shape.gii
	wb_command -set-map-names "$NativeFolder"/"$Subject".EdgeDistortion_"$RegName".native.dscalar.nii -map 1 "$Subject"_EdgeDistortion_"$RegName"
	wb_command -cifti-palette "$NativeFolder"/"$Subject".EdgeDistortion_"$RegName".native.dscalar.nii MODE_USER_SCALE "$NativeFolder"/"$Subject".EdgeDistortion_"$RegName".native.dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false

	wb_command -cifti-create-dense-scalar "$NativeFolder"/"$Subject".StrainJ_"$RegName".native.dscalar.nii -left-metric "$NativeFolder"/"$Subject".L.StrainJ_"$RegName".native.shape.gii -right-metric "$NativeFolder"/"$Subject".R.StrainJ_"$RegName".native.shape.gii
	wb_command -set-map-names "$NativeFolder"/"$Subject".StrainJ_"$RegName".native.dscalar.nii -map 1 "$Subject"_StrainJ_"$RegName"
	wb_command -cifti-palette "$NativeFolder"/"$Subject".StrainJ_"$RegName".native.dscalar.nii MODE_USER_SCALE "$NativeFolder"/"$Subject".StrainJ_"$RegName".native.dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false

	wb_command -cifti-create-dense-scalar "$NativeFolder"/"$Subject".StrainR_"$RegName".native.dscalar.nii -left-metric "$NativeFolder"/"$Subject".L.StrainR_"$RegName".native.shape.gii -right-metric "$NativeFolder"/"$Subject".R.StrainR_"$RegName".native.shape.gii
	wb_command -set-map-names "$NativeFolder"/"$Subject".StrainR_"$RegName".native.dscalar.nii -map 1 "$Subject"_StrainR_"$RegName"
	wb_command -cifti-palette "$NativeFolder"/"$Subject".StrainR_"$RegName".native.dscalar.nii MODE_USER_SCALE "$NativeFolder"/"$Subject".StrainR_"$RegName".native.dscalar.nii -pos-user 0 1 -neg-user 0 -1 -interpolate true -palette-name ROY-BIG-BL -disp-pos true -disp-neg true -disp-zero false
fi

