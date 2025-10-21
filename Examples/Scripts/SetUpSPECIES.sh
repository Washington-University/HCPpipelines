#! /bin/bash

# Species specific config file 

# Takuya Hayashi, RIKEN Japan
# Akiko Uematsu, RIKEN, Japan
# Yuki Hori, RIKEN Japan
# Chad Donahue, Washington University St. Louis, USA
# Matthew F Glasser, Washington University St. Louis, USA
# Copyright (c) 2016-2023
# All rights reserved.

## Species specific variables
if [[ "$SPECIES" == *Human* ]] ; then

    BrainScaleFactor="1"
    CorticalScaleFactor="1"

    #PreFreeSurferPipeLineBatch.sh
    BrainExtract="${BrainExtract:-INVIVO}"
    BrainSize="150"              #BrainSize in mm, distance bewteen top of FOV and bottom of brain
    Defacing="TRUE"
    betcenter="45,55,39"         # comma separated voxel coordinates in T1wTemplate2mm
    betradius="75"               # brain radius for bet
    betbiasfieldcor="TRUE"
    betfraction="0.3"            # fractional intensity threshold for bet
    bettop2center="86"           # Distance between top of FOV and center of brain
    betspecieslabel="0"          # bet4animal species label

    StrucRes=${StrucRes:-0.7}
    FNIRTConfig="${HCPPIPEDIR_Config}/T1_2_NHP_NNP_Human_2mm.cnf" #FNIRT 2mm T1w Config
    TopupConfig="${HCPPIPEDIR_Config}/b02b0.cnf" #Config for topup or "NONE" if not used
    UnwarpDir="${UnwarpDir:-z}" # z appears to be best or "NONE" if not used, read from Read.direction in Seriesinfo.txt (PA:y, AP:y-, RL:x, LR:x-, FH:z, HF:z-)
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
    
    # fMRI & ICAFIX
    MotionCorrectionMethod="MCFLIRT"
    TopUpConfig="${HCPPIPEDIR_Config}/b02b0_HCP_fMRI.cnf" #Topup config if using TOPUP, set to NONE if using regular FIELDMAP
    FinalFMRIResolution=2
    def_FIXTHR=10
    def_volwisharts=2
    def_ciftiwisharts=3
    TrainingData="HCP_Style_Single_Multirun_Dedrift"
    G_DEFAULT_LOW_RES_MESH=32

    # dMRI
    GrayordinatesResolutions="1.25" #Needs to match what is in PostFreeSurfer. 
    DiffTopupConfig="${HCPPIPEDIR_Config}/b02b0_HCP_dMRI.cnf"
    FSBBRDIFF=TRUE
    DiffWMProjAbs="2"

    # MakeAverageDataset
    PreGradientSmoothingSigma="$(echo "1/${CorticalScaleFactor}" | bc -l)"

    #Tractography
    StandardResolution=2
    LowResMesh=32
    PATHLENGTH=2000
    
elif [[ "$SPECIES" == *Chimp* ]] ; then

    BrainScaleFactor="1.25"
    CorticalScaleFactor="2"

    #PreFreeSurferPipeLineBatch.sh
    BrainExtract="${BrainExtract:-INVIVO}"
    BrainSize="60"               # BrainSize in mm, distance bewteen top of FOV and bottom of brain
    Defacing="NONE"
    betcenter="46,53,52"         # comma separated voxel coordinates in T1wTemplate2mm
    betbiasfieldcor="TRUE"
    betradius="45"               # brain radius for bet
    betfraction="0.3"            # fractional intensity threshold for bet
    bettop2center="60"           # Distance between top of FOV and center of brain
    betspecieslabel="1"          # bet4animal species label

    StrucRes=${StrucRes:-0.8}
    FNIRTConfig="${HCPPIPEDIR_Config}/T1_2_NHP_NNP_Chimp_1mm.cnf" #FNIRT 2mm T1w Config  High resolution warping, optimized regularization
    TopupConfig="${HCPPIPEDIR_Config}/b02b0_chimp_fMRI.cnf" #Config for topup or "NONE" if not used
    UnwarpDir="${UnwarpDir:-z-}" # z appears to be best or "NONE" if not used
    BiasFieldSmoothingSigma="4.0"
    T1wTemplate="${HCPPIPEDIR_Templates}/ChimpYerkes29_T1w_${StrucRes}mm.nii.gz"  
    T1wTemplateBrain="${HCPPIPEDIR_Templates}/ChimpYerkes29_T1w_${StrucRes}mm_brain.nii.gz" 
    T1wTemplate2mm="${HCPPIPEDIR_Templates}/ChimpYerkes29_T1w_1.6mm.nii.gz"  
    T1wTemplate2mmBrain="${HCPPIPEDIR_Templates}/ChimpYerkes29_T1w_1.6mm_brain.nii.gz" 
    T2wTemplate="${HCPPIPEDIR_Templates}/ChimpYerkes29_T2w_${StrucRes}mm.nii.gz"  
    T2wTemplate2mmBrain="${HCPPIPEDIR_Templates}/ChimpYerkes29_T2w_1.6mm_brain.nii.gz" 
    T2wTemplateBrain="${HCPPIPEDIR_Templates}/ChimpYerkes29_T2w_${StrucRes}mm_brain.nii.gz" 
    T2wTemplate2mm="${HCPPIPEDIR_Templates}/ChimpYerkes29_T2w_1.6mm.nii.gz" 
    TemplateMask="${HCPPIPEDIR_Templates}/ChimpYerkes29_T1w_${StrucRes}mm_brain_mask.nii.gz" 
    Template2mmMask="${HCPPIPEDIR_Templates}/ChimpYerkes29_T1w_1.6mm_brain_mask.nii.gz" 

    #PostFreeSurferPipeLineBatch.sh
    MyelinMappingFWHM="4" # based on median cortical thickenss of owl
    SurfaceSmoothingFWHM="4" # 4 by default 
    CorrectionSigma=6
    SurfaceAtlasDIR="${HCPPIPEDIR_Templates}/standard_mesh_atlases_chimp"
    GrayordinatesSpaceDIR="${HCPPIPEDIR_Templates}/standard_mesh_atlases_chimp"
    ReferenceMyelinMaps="${HCPPIPEDIR_Templates}/standard_mesh_atlases_chimp/ChimpYerkes29.MyelinMap_BC.164k_fs_LR.dscalar.nii"
    LowResMeshes="32@20" #Needs to match what is in PostFreeSurfer
    FinalfMRIResolution="1.6" #Needs to match what is in fMRIVolume
    SmoothingFWHM="1.6" #Recommended to be roughly the voxel size
    GrayordinatesResolution="1.6" #should be either 1 (7T) or 2 (3T) for human. 

    # fMRI & ICAFIX
    MotionCorrectionMethod="MCFLIRT"
    TopUpConfig="${HCPPIPEDIR_Config}/b02b0_chimp_fMRI.cnf" #Topup config if using TOPUP, set to NONE if using regular FIELDMAP
    G_DEFAULT_LOW_RES_MESH=32

    # dMRI
    GrayordinatesResolutions="1.2" #Needs to match what is in PostFreeSurfer. 
    DiffTopupConfig="${HCPPIPEDIR_Config}/b02b0_chimp_dMRI.cnf"
    FSBBRDIFF=TRUE
    DiffWMProjAbs="1"

    # MakeAverageDataset
    PreGradientSmoothingSigma="$(echo "1/${CorticalScaleFactor}" | bc -l)"

elif [[ "$SPECIES" == *Macaque* ]] ; then

    BrainScaleFactor="2"
    CorticalScaleFactor="3"

    #PreFreeSurferPipeLineBatch.sh
    BrainExtract="${BrainExtract:-INVIVO}"
    BrainSize="60"               # BrainSize in mm, distance bewteen top of FOV and bottom of brain
    Defacing="NONE"

    FNIRTConfig="${HCPPIPEDIR_Config}/T1_2_NHP_NNP_Macaque_1mm.cnf" #FNIRT 2mm T1w Config  High resolution warping, optimized regularization
    TopupConfig="${HCPPIPEDIR_Config}/b02b0_macaque_fMRI.cnf" #Config for topup or "NONE" if not used
    UnwarpDir="${UnwarpDir:-z-}" # z appears to be best or "NONE" if not used
    BiasFieldSmoothingSigma="3.5"

    betspecieslabel="2"          # bet4animal species label

    if [[ "$SPECIES" == *Mac30BS* ]] ; then     # Rhesus and Cyno hybrid template

        betcenter="48,56,51"         # comma separated voxel coordinates in T1wTemplate2mm
        betradius="35"
        betbiasfieldcor="TRUE"
        betfraction="0.2"
        bettop2center="30"           # distance in mm from the top of FOV to the center of brain in robustroi

        BrainTemplate="Mac30BS"
        T1wTemplate="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore.nii.gz" 
        T1wTemplateBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_brain.nii.gz" 
        T1wTemplate2mm="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_1.0mm.nii.gz" 
        T1wTemplate2mmBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_1.0mm_brain.nii.gz" 
        T2wTemplate="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_restore.nii.gz" 
        T2wTemplateBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_restore_brain.nii.gz" 
        T2wTemplate2mm="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_1.0mm.nii.gz" 
        T2wTemplate2mmBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_1.0mm_brain.nii.gz" 
        TemplateMask="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_brain_mask.nii.gz" 
        Template2mmMask="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_1.0mm_brain_mask.nii.gz"
        SurfaceAtlasDIR="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/standard_mesh_atlases"
        GrayordinatesSpaceDIR="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/standard_mesh_atlases"
        ReferenceMyelinMaps="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/standard_mesh_atlases/MacaqueRIKEN16.Parial.MyelinMap_GroupCorr.164k_fs_LR.dscalar.nii"

    elif [[ "$SPECIES" == *Cyno* ]] ; then

        betcenter="48,56,47"         # comma separated voxel coordinates in T1wTemplate2mm
        betradius="30"
        betbiasfieldcor="TRUE"
        betfraction="0.3"
        bettop2center="34"

        BrainTemplate="Mac25Cyno"
        StrucRes=${StrucRes:-0.5}
        #StrucRes=0.25  # D99 template
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

    elif [[ "$SPECIES" == *Rhesus* ]] ; then
    
        betcenter="48,56,51"         # comma separated voxel coordinates in T1wTemplate2mm
        betradius="35"
        betbiasfieldcor="TRUE"
        betfraction="0.2"
        bettop2center="30"           # distance in mm from the top of FOV to the center of brain in robustroi

        #BrainTemplate="MacaqueYerkes19"
        #T1wTemplate="${HCPPIPEDIR_Templates}/${BrainTemplate}_T1w_0.5mm_dedrift.nii.gz" #MacaqueYerkes0.5mm template 
        #T1wTemplateBrain="${HCPPIPEDIR_Templates}/${BrainTemplate}_T1w_0.5mm_dedrift_brain.nii.gz" #Brain extracted MacaqueYerkes0.5mm template
        #T1wTemplate2mm="${HCPPIPEDIR_Templates}/${BrainTemplate}_T1w_1.0mm_dedrift" #MacaqueYerkes1.0mm template brain modified by Takuya Hayshi on Oct 24th 2015. 
        #T2wTemplate="${HCPPIPEDIR_Templates}/${BrainTemplate}_T2w_0.5mm_dedrift.nii.gz" #MacaqueYerkes0.5mm T2wTemplate 
        #T2wTemplateBrain="${HCPPIPEDIR_Templates}/${BrainTemplate}_T2w_0.5mm_dedrift_brain.nii.gz" #Brain extracted MacaqueYerkes0.5mm T2wTemplate
        #T2wTemplate2mm="${HCPPIPEDIR_Templates}/${BrainTemplate}_T2w_1.0mm_dedrift" #MacaqueYerkes1.0mm T2wTemplate brain, modified by Takuya Hayashi on Oct 24th 2015.
        #TemplateMask="${HCPPIPEDIR_Templates}/${BrainTemplate}_T1w_0.5mm_brain_mask_dedrift.nii.gz" #Brain mask MacaqueYerkes0.5mm template
        #Template2mmMask="${HCPPIPEDIR_Templates}/${BrainTemplate}_T1w_1.0mm_brain_mask_dedrift.nii.gz" #MacaqueYerkes1.0mm template
        #Template2mmBrain="${HCPPIPEDIR_Templates}/${BrainTemplate}_T1w_1.0mm_brain.nii.gz" #MacaqueYerkes1.0mm brain template

        BrainTemplate="Mac25Rhesus"
        StrucRes=${StrucRes:-0.5}
        #StrucRes=0.25  # D99 template NMT v2.0 (SARM)template 
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

    elif [[ "$SPECIES" == *Snow* ]] ; then

        betcenter="48,56,51"        # comma separated voxel coordinates in T1wTemplate2mm
        betradius="40"
        betbiasfieldcor="TRUE"
        betfraction=0.3
        bettop2center="30"    

        BrainTemplate="Mac6Snow"
        T1wTemplate="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore.nii.gz"
        T1wTemplateBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_brain.nii.gz"
        T1wTemplate2mm="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_1.0mm.nii.gz"
        T1wTemplate2mmBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_1.0mm_brain.nii.gz"
        T2wTemplate="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_restore.nii.gz"
        T2wTemplateBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_restore_brain.nii.gz"
        T2wTemplate2mm="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_restore_1.0mm.nii.gz"
        T2wTemplate2mmBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_restore_1.0mm_brain.nii.gz"
        TemplateMask="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_brain_mask.nii.gz"
        Template2mmMask="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_1.0mm_brain_mask.nii.gz"

        SurfaceAtlasDIR="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/standard_mesh_atlases"
        GrayordinatesSpaceDIR="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/standard_mesh_atlases"
        ReferenceMyelinMaps="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/standard_mesh_atlases/MacaqueRIKEN16.Parial.MyelinMap_GroupCorr.164k_fs_LR.dscalar.nii"
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

    # fMRI & ICAFIX
    MotionCorrectionMethod="MCFLIRT"
    TopUpConfig="${HCPPIPEDIR_Config}/b02b0_macaque_fMRI.cnf"
    FinalFMRIResolution=1.2  # Changed from 1.25 to 1.2 to make low-resolution volume symmetrical between left and right with respect to the center - TH Mar 2025.
    def_FIXTHR=10
    def_volwisharts=1
    def_ciftiwisharts=2
    MION=${MION:-0}
    if [ ! "$FSL_FIXDIR" = $FSLDIR/bin ] ; then
        TrainingData="NHPHCP_Macaque_RIKEN30MRFIX"
        if [ "$MION" = 1 ] ; then 
            TrainingData=NHPHCP_Macaque.USPIO
        fi
    else
        TrainingData="NHPHCP_Macaque_RIKEN30MRFIX"
        if [ "$MION" = 1 ] ; then 
            TrainingData=/mnt/pub/PROJ/NHP_NNP/MacaqueRhesus/NHPHCP_Macaque.USPIO.pyfix/NHPHCP_Macaque.USPIO
        fi
    fi
    G_DEFAULT_LOW_RES_MESH=10

    # dMRI
    GrayordinatesResolutions="0.5@1.2" #Needs to match what is in PostFreeSurfer. 
    DiffTopupConfig="${HCPPIPEDIR_Config}/b02b0_macaque_dMRI.cnf"
    FSBBRDIFF=TRUE
    DiffWMProjAbs="0.7"

    #Tractography
    StandardResolution=0.5
    LowResMesh=32
    PATHLENGTH=200

    # MakeAverageDataset
    PreGradientSmoothingSigma="$(echo "1/${CorticalScaleFactor}" | bc -l)"

elif [[ "$SPECIES" = Marmoset ]] ; then

    BrainScaleFactor="5"
    CorticalScaleFactor="10"

    #PreFreeSurferPipeLineBatch.sh
    BrainExtract="${BrainExtract:-INVIVO}"
    BrainSize="50"               # BrainSize in mm, distance bewteen top of FOV and bottom of brain
    Defacing="NONE"
    betcenter="50,40,30"         # comma separated voxel coordinates in T1wTemplate2mm
    betradius="12"
    betfraction="0.5"
    betbiasfieldcor="FALSE"
    bettop2center="12"           # distance in mm from the top of FOV to the center of brain in robustroi
    betspecieslabel="3"          # bet4animal species label

    FNIRTConfig="${HCPPIPEDIR_Config}/T1_2_NHP_NNP_Marmoset_0.4mm.cnf" #FNIRT 2mm T1w Config
    TopupConfig="${HCPPIPEDIR_Config}/b02b0_marmoset_fMRI.cnf" #Config for topup or "NONE" if not used
    UnwarpDir="${UnwarpDir:-z-}" # z appears to be best or "NONE" if not used
    BiasFieldSmoothingSigma="1.5" 
    BrainTemplate="MarmosetRIKEN25"
    #BrainTemplate="MarmosetRIKEN20"

    StrucRes=${StrucRes:-0.2}
    #StrucRes=0.15 # SAM template
    #StrucRes=0.1  # bmaV2, Nencki-Monash
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
    
    # fMRI & ICAFIX
    MotionCorrectionMethod="FLIRT"
    TopUpConfig="${HCPPIPEDIR_Config}/b02b0_marmoset_fMRI.cnf"
    FinalFMRIResolution=0.8
    def_FIXTHR=10
    def_volwisharts=3
    def_ciftiwisharts=5
    if [ ! "$FSL_FIXDIR" = $FSLDIR/bin ] ; then
        CustomTrainingData="NHPHCP_Marmoset"
        if [ "$MION" = 1 ] ; then 
            TrainingData=NHPHCP_Macaque.USPIO
        fi
    else
        CustomTrainingData="NHPHCP_Marmoset"
        if [ "$MION" = 1 ] ; then 
            TrainingData=/mnt/pub/PROJ/NHP_NNP/MacaqueRhesus/NHPHCP_Macaque.USPIO.pyfix/NHPHCP_Macaque.USPIO
        fi
    fi

    G_DEFAULT_LOW_RES_MESH=4

    # dMRI
    GrayordinatesResolutions="0.2@0.5@0.8" #Needs to match what is in PostFreeSurfer. 
    DiffTopupConfig="${HCPPIPEDIR_Config}/b02b0_marmoset_dMRI.cnf"
    FSBBRDIFF=TRUE
    DiffWMProjAbs="0.5"

    #Tractography
    StandardResolution=0.2
    LowResMesh=32
    PATHLENGTH=80
    
    # MakeAverageDataset
    PreGradientSmoothingSigma="$(echo "1/${CorticalScaleFactor}" | bc -l)"

elif [[ "$SPECIES" = NightMonkey ]] ; then #NightMokey added by Takuya Hayashi, Takuro Ikeda on Aug 2020

    BrainScaleFactor="4"
    CorticalScaleFactor="5"

    #PreFreeSurferPipeLineBatch.sh
    BrainExtract="${BrainExtract:-INVIVO}"
    BrainSize="40"               # BrainSize in mm, distance bewteen top of FOV and bottom of brain
    Defacing="NONE"
    betcenter="48,60,42"         # comma separated voxel coordinates in T1wTemplate2mm
    betbiasfieldcor="FALSE"
    betradius="20"
    betfraction="0.4"
    bettop2center="16"
    betspecieslabel="4"          # bet4animal species label

    FNIRTConfig="${HCPPIPEDIR_Config}/T1_2_NHP_NNP_Marmoset_0.4mm.cnf" #FNIRT 2mm T1w Config
    TopupConfig="${HCPPIPEDIR_Config}/b02b0_marmoset_fMRI.cnf" #Config for topup or "NONE" if not used
    UnwarpDir="${UnwarpDir:-z-}" # z appears to be best or "NONE" if not used
     BiasFieldSmoothingSigma="2.5"
    BrainTemplate="NightMonkey9"
    T1wTemplate="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_0.25mm.nii.gz"
    T1wTemplateBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_0.25mm_brain.nii.gz"
    T1wTemplate2mm="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_0.5mm.nii.gz"
    T2wTemplate="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_restore_0.25mm.nii.gz"
    T2wTemplateBrain="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_restore_0.25mm_brain.nii.gz"
    T2wTemplate2mm="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T2w_restore_0.5mm.nii.gz"
    TemplateMask="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_T1w_restore_0.25mm_brain_mask.nii.gz"
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
    
    # fMRI & ICAFIX
    MotionCorrectionMethod="MCFLIRT"
    TopUpConfig="${HCPPIPEDIR_Config}/b02b0_marmoset_fMRI.cnf"
    FinalFMRIResolution=1.0 
    def_FIXTHR=10
    def_volwisharts=1
    def_ciftiwisharts=2
    TrainingData=NHPHCP_Marmoset
    G_DEFAULT_LOW_RES_MESH=10

    # dMRI
    GrayordinatesResolutions="0.5@1.2" #Needs to match what is in PostFreeSurfer. 
    DiffTopupConfig="${HCPPIPEDIR_Config}/b02b0_marmoset_dMRI.cnf"
    FSBBRDIFF=TRUE
    DiffWMProjAbs="0.5"

    # MakeAverageDataset
    PreGradientSmoothingSigma="$(echo "1/${CorticalScaleFactor}" | bc -l)"

else

    echo "Warning: Not yet supported species: $SPECIES"

fi
