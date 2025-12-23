#!/bin/bash

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    export HCPPIPEDIR="$(dirname -- "$0")/../.."
fi

# Species specific config file 

# Takuya Hayashi, RIKEN Japan
# Akiko Uematsu, RIKEN, Japan
# Yuki Hori, RIKEN Japan
# Chad Donahue, Washington University St. Louis, USA
# Matthew F Glasser, Washington University St. Louis, USA
# Copyright (c) 2016-2023
# All rights reserved.

#HACK: don't pass arguments on to shlibs, to disable the "While running:" part of error messages
source "$HCPPIPEDIR/global/scripts/newopts.shlib"     #also sources log.shlib
source "$HCPPIPEDIR/global/scripts/debug.shlib"

opts_SetScriptDescription "This file should be sourced from an NHP batch launch script, not run by itself, because it sets a bunch of variables to be used by a pipeline call."
#HACK: sourcing leaves $0 set to the outer script name, so let's make log messages a little more obvious by telling the logger what name to use
#we have already sourced log.shlib via newopts.shlib
log_SetToolName "SetUpSPECIES.sh"

opts_AddMandatory '--species' 'SPECIES' 'species' 'species name'
opts_AddMandatory '--structres' 'StrucRes' 'structres' 'structural resolution'
opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

## Species specific variables
if [[ "$SPECIES" == *Human* ]] ; then

    BrainScaleFactor="1"
    CorticalScaleFactor="1"

    #PreFreeSurferPipeLineBatch.sh
    BrainSize="150"              #BrainSize in mm, distance bewteen top of FOV and bottom of brain
    betcenter="45,55,39"         # comma separated voxel coordinates in T1wTemplate2mm
    betradius="75"               # brain radius for bet
    betbiasfieldcor="TRUE"       # indicates whether to correct bias field for BET (TRUE or FALSE)
    betfraction="0.3"            # fractional intensity threshold for bet
    bettop2center="86"           # Distance between top of FOV and center of brain

    FNIRTConfig=${FSLDIR}/etc/flirtsch/T1_2_MNI152_2mm.cnf #FNIRT 2mm T1w Config
    TopupConfig="${HCPPIPEDIR_Config}/b02b0.cnf" #Config for topup or "NONE" if not used
    BiasFieldSmoothingSigma="5.0"
    T1wTemplate="${HCPPIPEDIR_Templates}/MNI152_T1_${StrucRes}mm.nii.gz"  
    T1wTemplateBrain="${HCPPIPEDIR_Templates}/MNI152_T1_${StrucRes}mm_brain.nii.gz" 
    T1wTemplate2mm="${HCPPIPEDIR_Templates}/MNI152_T1_2mm"  
    T1wTemplate2mmBrain="${HCPPIPEDIR_Templates}/MNI152_T1_2mm_brain.nii.gz" 
    T2wTemplate="${HCPPIPEDIR_Templates}/MNI152_T2_${StrucRes}mm.nii.gz"  
    T2wTemplate2mmBrain="${HCPPIPEDIR_Templates}/MNI152_T2_2mm_brain.nii.gz" 
    T2wTemplateBrain="${HCPPIPEDIR_Templates}/MNI152_T2_${StrucRes}mm_brain" 
    T2wTemplate2mm="${HCPPIPEDIR_Templates}/MNI152_T2_2mm" 
    TemplateMask="${HCPPIPEDIR_Templates}/MNI152_T1_${StrucRes}mm_brain_mask.nii.gz" 
    Template2mmMask="${HCPPIPEDIR_Templates}/MNI152_T1_2mm_brain_mask_dil.nii.gz" 

    #PostFreeSurferPipeLineBatch.sh
    MyelinMappingFWHM="5" 
    SurfaceSmoothingFWHM="4"
    CorrectionSigma="7"
    SurfaceAtlasDIR="${HCPPIPEDIR_Templates}/standard_mesh_atlases"
    GrayordinatesSpaceDIR="${HCPPIPEDIR_Templates}/standard_mesh_atlases"
    ReferenceMyelinMaps="${HCPPIPEDIR_Templates}/standard_mesh_atlases/Conte69.MyelinMap_BC.164k_fs_LR.dscalar.nii"
    LowResMeshes="32" #Needs to match what is in PostFreeSurfer
    FinalfMRIResolution="2" #Needs to match what is in fMRIVolume
    SmoothingFWHM="2" #Recommended to be roughly the voxel size
    GrayordinatesResolution="2" #should be either 1 (7T) or 2 (3T) for human. 
    InflateScale="1"
    FlatMapRootName="colin.cerebral"
    
elif [[ "$SPECIES" == *Chimp* ]] ; then

    BrainScaleFactor="1.25"
    CorticalScaleFactor="2"

    #PreFreeSurferPipeLineBatch.sh
    BrainSize="60"               # BrainSize in mm, distance bewteen top of FOV and bottom of brain
    betcenter="46,53,52"         # comma separated voxel coordinates in T1wTemplate2mm
    betbiasfieldcor="TRUE"       # indicates whether to correct bias field for BET (TRUE or FALSE)
    betradius="45"               # brain radius for bet
    betfraction="0.3"            # fractional intensity threshold for bet
    bettop2center="60"           # Distance between top of FOV and center of brain

    FNIRTConfig=${FSLDIR}/etc/flirtsch/T1_2_MNI152_2mm.cnf #FNIRT 2mm T1w Config  High resolution warping, optimized regularization
    TopupConfig="${HCPPIPEDIR_Config}/b02b0_Chimp_fMRI.cnf" #Config for topup or "NONE" if not used
    BiasFieldSmoothingSigma="4.0"
    T1wTemplate="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_${StrucRes}mm.nii.gz"  
    T1wTemplateBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_${StrucRes}mm_brain.nii.gz" 
    T1wTemplate2mm="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_1.6mm.nii.gz"  
    T1wTemplate2mmBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_1.6mm_brain.nii.gz" 
    T2wTemplate="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_${StrucRes}mm.nii.gz"  
    T2wTemplate2mmBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_1.6mm_brain.nii.gz" 
    T2wTemplateBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_${StrucRes}mm_brain.nii.gz" 
    T2wTemplate2mm="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_1.6mm.nii.gz" 
    TemplateMask="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_${StrucRes}mm_brain_mask.nii.gz" 
    Template2mmMask="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_1.6mm_brain_mask.nii.gz" 

    #PostFreeSurferPipeLineBatch.sh
    MyelinMappingFWHM="4" # based on median cortical thickenss of owl
    SurfaceSmoothingFWHM="4" # 4 by default 
    CorrectionSigma=6
    SurfaceAtlasDIR="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/standard_mesh_atlases"
    GrayordinatesSpaceDIR="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/standard_mesh_atlases"
    ReferenceMyelinMaps="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/standard_mesh_atlases/ChimpYerkes29.MyelinMap_BC.164k_fs_LR.dscalar.nii"
    LowResMeshes="32@20" #Needs to match what is in PostFreeSurfer
    FinalfMRIResolution="1.6" #Needs to match what is in fMRIVolume
    SmoothingFWHM="1.6" #Recommended to be roughly the voxel size
    GrayordinatesResolution="1.6" #should be either 1 (7T) or 2 (3T) for human. 

elif [[ "$SPECIES" == *Macaque* ]] ; then

    BrainScaleFactor="2"
    CorticalScaleFactor="3"

    #PreFreeSurferPipeLineBatch.sh
    BrainSize="60"               # BrainSize in mm, distance bewteen top of FOV and bottom of brain

    FNIRTConfig="${HCPPIPEDIR_Config}/T1_2_NHP_NNP_Macaque_1mm.cnf" #FNIRT 2mm T1w Config  High resolution warping, optimized regularization
    TopupConfig="${HCPPIPEDIR_Config}/b02b0_macaque_fMRI.cnf" #Config for topup or "NONE" if not used
    BiasFieldSmoothingSigma="3.5"

	is_valid_macaque_species=0

    if [[ "$SPECIES" == *Mac30BS* ]] ; then     # Rhesus and Cyno hybrid template

        betcenter="48,56,51"         # comma separated voxel coordinates in T1wTemplate2mm
        betradius="35"               # brain radius for bet
        betbiasfieldcor="TRUE"       # indicates whether to correct bias field for BET (TRUE or FALSE)
        betfraction="0.2"            # fractional intensity threshold for bet
        bettop2center="30"           # distance in mm from the top of FOV to the center of brain in robustroi

        BrainTemplate="Mac30BS"
        T1wTemplate="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_${StrucRes}mm.nii.gz" 
        T1wTemplateBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_${StrucRes}mm_brain.nii.gz" 
        T1wTemplate2mm="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_1.0mm.nii.gz" 
        T1wTemplate2mmBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_1.0mm_brain.nii.gz" 
        T2wTemplate="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_restore_${StrucRes}mm.nii.gz" 
        T2wTemplateBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_restore_${StrucRes}mm_brain.nii.gz" 
        T2wTemplate2mm="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_1.0mm.nii.gz" 
        T2wTemplate2mmBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_1.0mm_brain.nii.gz" 
        TemplateMask="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_${StrucRes}mm_brain_mask.nii.gz" 
        Template2mmMask="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_1.0mm_brain_mask.nii.gz"
        SurfaceAtlasDIR="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/standard_mesh_atlases"
        GrayordinatesSpaceDIR="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/standard_mesh_atlases"
        ReferenceMyelinMaps="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/standard_mesh_atlases/MacaqueRIKEN16.Parial.MyelinMap_GroupCorr.164k_fs_LR.dscalar.nii"

		is_valid_macaque_species=$((is_valid_macaque_species + 1))

    elif [[ "$SPECIES" == *Cyno* ]] ; then

        betcenter="48,56,47"         # comma separated voxel coordinates in T1wTemplate2mm
        betradius="30"               # brain radius for bet
        betbiasfieldcor="TRUE"       # indicates whether to correct bias field for BET (TRUE or FALSE)
        betfraction="0.3"            # fractional intensity threshold for bet
        bettop2center="34"           # Distance between top of FOV and center of brain

        BrainTemplate="Mac25Cyno"
        T1wTemplate="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_${StrucRes}mm.nii.gz"
        T1wTemplateBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_${StrucRes}mm_brain.nii.gz"
        T2wTemplate="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_restore_${StrucRes}mm.nii.gz"
        T2wTemplateBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_restore_${StrucRes}mm_brain.nii.gz"
        TemplateMask="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_${StrucRes}mm_brain_mask.nii.gz"

        T1wTemplate2mm="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_1.0mm.nii.gz"
        T1wTemplate2mmBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_1.0mm_brain.nii.gz"
        T2wTemplate2mm="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_restore_1.0mm.nii.gz"
        T2wTemplate2mmBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_restore_1.0mm_brain.nii.gz"
        Template2mmMask="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_1.0mm_brain_mask.nii.gz"
        SurfaceAtlasDIR="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/standard_mesh_atlases"
        GrayordinatesSpaceDIR="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/standard_mesh_atlases"
        ReferenceMyelinMaps="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/standard_mesh_atlases/Mac25Cyno_v3.Partial.MyelinMap_GroupCorr.164k_fs_LR.dscalar.nii"

		is_valid_macaque_species=$((is_valid_macaque_species + 1))

    elif [[ "$SPECIES" == *Rhesus* ]] ; then
    
        betcenter="48,56,51"         # comma separated voxel coordinates in T1wTemplate2mm
        betradius="35"               # brain radius for bet
        betbiasfieldcor="TRUE"       # indicates whether to correct bias field for BET (TRUE or FALSE)
        betfraction="0.2"            # fractional intensity threshold for bet
        bettop2center="30"           # distance in mm from the top of FOV to the center of brain in robustroi

        #BrainTemplate="MacaqueYerkes19"
        #T1wTemplate="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}_T1w_0.5mm_dedrift.nii.gz" #MacaqueYerkes0.5mm template 
        #T1wTemplateBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}_T1w_0.5mm_dedrift_brain.nii.gz" #Brain extracted MacaqueYerkes0.5mm template
        #T1wTemplate2mm="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}_T1w_1.0mm_dedrift" #MacaqueYerkes1.0mm template brain modified by Takuya Hayshi on Oct 24th 2015. 
        #T2wTemplate="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}_T2w_0.5mm_dedrift.nii.gz" #MacaqueYerkes0.5mm T2wTemplate 
        #T2wTemplateBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}_T2w_0.5mm_dedrift_brain.nii.gz" #Brain extracted MacaqueYerkes0.5mm T2wTemplate
        #T2wTemplate2mm="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}_T2w_1.0mm_dedrift" #MacaqueYerkes1.0mm T2wTemplate brain, modified by Takuya Hayashi on Oct 24th 2015.
        #TemplateMask="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}_T1w_0.5mm_brain_mask_dedrift.nii.gz" #Brain mask MacaqueYerkes0.5mm template
        #Template2mmMask="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}_T1w_1.0mm_brain_mask_dedrift.nii.gz" #MacaqueYerkes1.0mm template
        #Template2mmBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}_T1w_1.0mm_brain.nii.gz" #MacaqueYerkes1.0mm brain template

        BrainTemplate="Mac25Rhesus"
        T1wTemplate="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_${StrucRes}mm.nii.gz"
        T1wTemplateBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_${StrucRes}mm_brain.nii.gz"
        T2wTemplate="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_restore_${StrucRes}mm.nii.gz"
        T2wTemplateBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_restore_${StrucRes}mm_brain.nii.gz"
        TemplateMask="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_${StrucRes}mm_brain_mask.nii.gz"

        T1wTemplate2mm="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_1.0mm.nii.gz"
        T1wTemplate2mmBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_1.0mm_brain.nii.gz"
        T2wTemplate2mm="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_restore_1.0mm.nii.gz"
        T2wTemplate2mmBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_restore_1.0mm_brain.nii.gz"
        Template2mmMask="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_1.0mm_brain_mask.nii.gz"

        SurfaceAtlasDIR="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/standard_mesh_atlases"
        GrayordinatesSpaceDIR="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/standard_mesh_atlases"
        ReferenceMyelinMaps="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/standard_mesh_atlases/Mac25Rhesus_v5.Partial.MyelinMap_GroupCorr.164k_fs_LR.dscalar.nii"

		is_valid_macaque_species=$((is_valid_macaque_species + 1))

    elif [[ "$SPECIES" == *Snow* ]] ; then

        betcenter="48,56,51"        # comma separated voxel coordinates in T1wTemplate2mm
        betradius="40"              # brain radius for bet
        betbiasfieldcor="TRUE"      # indicates whether to correct bias field for BET (TRUE or FALSE)
        betfraction=0.3             # fractional intensity threshold for bet
        bettop2center="30"          # Distance between top of FOV and center of brain

        BrainTemplate="Mac6Snow"
        T1wTemplate="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_${StrucRes}mm.nii.gz"
        T1wTemplateBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_${StrucRes}mm_brain.nii.gz"
        T1wTemplate2mm="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_1.0mm.nii.gz"
        T1wTemplate2mmBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_1.0mm_brain.nii.gz"
        T2wTemplate="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_restore_${StrucRes}mm.nii.gz"
        T2wTemplateBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_restore_${StrucRes}mm_brain.nii.gz"
        T2wTemplate2mm="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_restore_1.0mm.nii.gz"
        T2wTemplate2mmBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_restore_1.0mm_brain.nii.gz"
        TemplateMask="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_${StrucRes}mm_brain_mask.nii.gz"
        Template2mmMask="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_1.0mm_brain_mask.nii.gz"

        SurfaceAtlasDIR="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/standard_mesh_atlases"
        GrayordinatesSpaceDIR="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/standard_mesh_atlases"
        ReferenceMyelinMaps="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/standard_mesh_atlases/MacaqueRIKEN16.Parial.MyelinMap_GroupCorr.164k_fs_LR.dscalar.nii"

		is_valid_macaque_species=$((is_valid_macaque_species + 1))
    fi

	if [ $is_valid_macaque_species != 1 ]; then
		echo "Error: Invalid macaque species & template: $SPECIES. Please specify macaque species, such as RhesusMacaque, CynoMacaque, SnowMacaque. You can also use MacaqueMac30BS (Rhesus and Cyno hybrid template)."
		exit 1
	fi
	
    #PostFreeSurferPipeLineBatch.sh
    MyelinMappingFWHM="3" # based on median cortical thickness of macaque
    SurfaceSmoothingFWHM="2" # 4 by default
    CorrectionSigma="5"
    LowResMeshes="32@10"        #Needs to match what is in PostFreesurfer
    FinalfMRIResolution="1.2" #Needs to match what is in fMRIVolume. Changed from 1.25 to 1.2 to make low-resolution volume symmetrical between left and right with respect to the center - TH Mar 2025. 
    SmoothingFWHM="1.2" #Recommended to be roughly the voxel size TH - changed from 1.25 to 1.2 Mar 2025
    GrayordinatesResolution="1.2" #Needs to match what is in PostFreeSurfer. 
    InflateScale="1"
    MSMSulcConf="MSMSulcStrainFinalconfMacaque"
    FlatMapRootName="$BrainTemplate"

elif [[ "$SPECIES" = Marmoset ]] ; then

    BrainScaleFactor="5"
    CorticalScaleFactor="10"

    #PreFreeSurferPipeLineBatch.sh
    BrainSize="50"               # BrainSize in mm, distance bewteen top of FOV and bottom of brain
    betcenter="50,40,30"         # comma separated voxel coordinates in T1wTemplate2mm
    betradius="12"               # brain radius for bet
    betfraction="0.5"            # fractional intensity threshold for bet
    betbiasfieldcor="FALSE"      # indicates whether to correct bias field for BET (TRUE or FALSE)
    bettop2center="12"           # distance in mm from the top of FOV to the center of brain in robustroi

    FNIRTConfig="${HCPPIPEDIR_Config}/T1_2_NHP_NNP_Marmoset_0.4mm.cnf" #FNIRT 2mm T1w Config
    TopupConfig="${HCPPIPEDIR_Config}/b02b0_marmoset_fMRI.cnf" #Config for topup or "NONE" if not used
    BiasFieldSmoothingSigma="1.5" 
    BrainTemplate="MarmosetRIKEN25"
    #BrainTemplate="MarmosetRIKEN20"


    T1wTemplate="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_${StrucRes}mm.nii.gz"
    T1wTemplateBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_${StrucRes}mm_brain.nii.gz" 
    T2wTemplate="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_restore_${StrucRes}mm.nii.gz" 
    T2wTemplateBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_restore_${StrucRes}mm_brain.nii.gz"
    TemplateMask="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_${StrucRes}mm_brain_mask.nii.gz"

    T1wTemplate2mm="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_0.4mm.nii.gz" 
    T1wTemplate2mmBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_0.4mm_brain.nii.gz" 
    T2wTemplate2mm="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_restore_0.4mm.nii.gz"
    T2wTemplate2mmBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_restore_0.4mm_brain.nii.gz"
    Template2mmMask="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_0.4mm_brain_mask_dilM.nii.gz"

    SurfaceAtlasDIR="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/standard_mesh_atlases"
    GrayordinatesSpaceDIR="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/standard_mesh_atlases"
    ReferenceMyelinMaps="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/standard_mesh_atlases/MyelinMap_B0B1TxBC.164k_fs_LR.dscalar.nii"
    MyelinMappingFWHM="1" # based on median cortical thickness of marmoset
    SurfaceSmoothingFWHM="1" # 4 by default
    CorrectionSigma="3"
    LowResMeshes="32@10@4"        # Needs to match what is in PostFreeSurfer. The last two is used for dMRI & fMRI 
    FinalfMRIResolution="0.8" #Needs to match what is in fMRIVolume
    SmoothingFWHM="0.8" #Recommended to be roughly the voxel size
    GrayordinatesResolution="0.8" #Needs to match what is in PostFreeSurfer. 
    InflateScale="1"
    MSMSulcConf=MSMSulcStrainFinalconfMacaque
    FlatMapRootName="$BrainTemplate"

elif [[ "$SPECIES" = NightMonkey ]] ; then #NightMokey added by Takuya Hayashi, Takuro Ikeda on Aug 2020

    BrainScaleFactor="4"
    CorticalScaleFactor="5"

    #PreFreeSurferPipeLineBatch.sh
    BrainSize="40"               # BrainSize in mm, distance bewteen top of FOV and bottom of brain
    betcenter="48,60,42"         # comma separated voxel coordinates in T1wTemplate2mm
    betbiasfieldcor="FALSE"      # indicates whether to correct bias field for BET (TRUE or FALSE)
    betradius="20"               # brain radius for bet
    betfraction="0.4"            # fractional intensity threshold for bet
    bettop2center="16"           # Distance between top of FOV and center of brain

    FNIRTConfig="${HCPPIPEDIR_Config}/T1_2_NHP_NNP_Marmoset_0.4mm.cnf" #FNIRT 2mm T1w Config
    TopupConfig="${HCPPIPEDIR_Config}/b02b0_marmoset_fMRI.cnf" #Config for topup or "NONE" if not used
    BiasFieldSmoothingSigma="2.5"
    BrainTemplate="NightMonkey9"
    T1wTemplate="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_${StrucRes}mm.nii.gz"
    T1wTemplateBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_${StrucRes}mm_brain.nii.gz"
    T1wTemplate2mm="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_0.5mm.nii.gz"
    T2wTemplate="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_restore_${StrucRes}mm.nii.gz"
    T2wTemplateBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_restore_${StrucRes}mm_brain.nii.gz"
    T2wTemplate2mm="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_restore_0.5mm.nii.gz"
    TemplateMask="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_${StrucRes}mm_brain_mask.nii.gz"
    Template2mmMask="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_0.5mm_brain_mask.nii.gz"

    SurfaceAtlasDIR="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/standard_mesh_atlases"
    GrayordinatesSpaceDIR="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/standard_mesh_atlases"
    ReferenceMyelinMaps="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/standard_mesh_atlases/MyelinMap_BC.164k_fs_LR.dscalar.nii"
    MyelinMappingFWHM="1.5" # based on median cortical thickenss of owl
    SurfaceSmoothingFWHM="1.5" # 4 by default 
    CorrectionSigma="4"
    LowResMeshes="32@10" #Needs to match what is in PostFreeSurfer
    FinalfMRIResolution="1.0" #Needs to match what is in fMRIVolume
    SmoothingFWHM="1.0" #Recommended to be roughly the voxel size
    GrayordinatesResolution="1.0" #Needs to match what is in PostFreeSurfer. 
    InflateScale="2.5"
    MSMSulcConf=MSMSulcStrainFinalconfMacaque

else

    echo "Warning: Not yet supported species: $SPECIES"

fi
