#! /bin/bash

# Species specific config file for recon-all.v6.hiresNHP

# Takuya Hayashi, RIKEN Japan 
# Akiko Uematsu, RIKEN Japan 
# Chad Donahue, Washington University St. Louis, USA
# Matthew F Glasser, Washington University St. Louis, USA
# Copyright (c) 2018-2024
# All rights reserved.

SkullStripMethod=PreFS                                             # PreFS or FS. PreFS method is recommended for NHP - TH Feb 2024

SPECIES="$1"
isFLAIR="$2"    #NOTE: must be "0" or "1"

if [[ "$SPECIES" == *Human* ]] ; then

  IntensityCor="FAST"
  TemplateWMSkeleton="NONE"
  ScaleFactor=1
  mri_segment_args=""
  mri_fill_args="-C 0 0 27"
  T2normSigma=""
  VariableSigma=""
  PialSigma=""
  SmoothNiter=""
  NSigmaAbove=""
  NSigmaBelow=""    
  WMProjAbs="2"
  VariableSigmaFS5="8"                                        # FS5.3.0 HighResPial  
  MaxThickness="6"                                            # FS5.3.0 HighResPial   
  GreySigma="5"                                               # FS5.3.0 HighResPial 
  BiasFieldFastSmoothingSigma=""  # = 20*$ScaleFactor
  GCAdir="${FREESURFER_HOME}/average"
  GCA="RB_all_2016-05-10.vc700.gca"
  AvgCurvTif="average.curvature.filled.buckner40.tif"

  # FS BBR in DiffusionPreprocPipeline
  FSBBRDIFF=TRUE
  DiffWMProjAbs="2"

elif [[ "$SPECIES" == *Chimp* ]] ; then

  IntensityCor="FAST"
  TemplateWMSkeleton="NONE"
  ScaleFactor="1.25"
  BiasFieldFastSmoothingSigma="25"                            # = 20*ScaleFactor
  StrongBias_args="-s"                                        # strong bias in T1w
  mri_normalize_args="-sigma 10 -gentle"                      # = 8*ScaleFactor.
  mri_segment_args=""    
  initcc="128 110 125"                                        # FS5.3.0 voxel coordinate in orig.mgz and wm.mgz
  mri_fill_args="-C 0 -8 21"                                  # mm coordinate in orig.mgz and wm.mgz
  mris_inflate1_args="-n 250"                                  # set higher # of iterations (default=10) to avoid "white surface short cut"
  T1normSigma=""
  T2normSigma="20"
  VariableSigma="3"
  PialSigma="2"
  SmoothNiter="1"
  if ((isFLAIR)) ; then                                  # control T2 pial
    NSigmaAbove="3"                                      # 2: FS6 default
    NSigmaBelow="3"                                      # 3: FS6 default
  else
    NSigmaAbove="3"                                      # 3: FS6 default
    NSigmaBelow="3"                                      # 3: FS6 default
  fi
  WMProjAbs="1"    
  MaxThickness="8"                                            # FS6 conf2hires       
  CopyBiasFromConf="TRUE"                                     # FS6 conf2hires

  VariableSigmaFS5="8"                                        # FS5.3.0 HighResPial  
  MaxThicknessFS5="5"                                         # FS5.3.0 HighResPial    
  GreySigmaFS5="5"                                            # FS5.3.0 HighResPial
  GCAdir="${HCPPIPEDIR_Templates}/ChimpYerkes29"
  GCA="RB_all_2008-03-26.gca"
  AvgCurvTif="average.curvature.filled.buckner40.tif"

  # FS BBR in DiffusionPreprocPipeline
  FSBBRDIFF=TRUE
  DiffWMProjAbs="1"

elif [[ "$SPECIES" == *Macaque* ]] ; then                            # tuned by TH and AU

  # IntensityCor
  IntensityCor="FAST"
  ScaleFactor="2"
  BiasFieldFastSmoothingSigma="40"                            # = 20*ScaleFactor
  StrongBias_args="-s"                                        # strong bias in T1w

  # recon-all.v6.hiresNHP 
  mri_normalize_args="-sigma 16 -gentle"                      # = 8*ScaleFactor. FS6 default sigma=8

  mris_make_surfaces_args=""
  initcc="128 98 124"                                         # FS5.3.0 voxel coordinate in orig.mgz and wm.mgz
  mri_fill_args="-C 0 -3 8 -fillven 1 -topofix norm.mgz"      # mm coordinate in orig.mgz and wm.mgz
  mris_inflate1_args="-n 250"                                 # set higher # of iterations (default=10) to avoid "white surface short cut"
  mris_sphere_args=" -RADIUS 55 -remove_negative 1"

  if [[ "$SPECIES" == *30BS* ]] ; then                          # Rhesus and Cyno hybrid template

    BrainTemplate="Mac30BS"
    GCAdir="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/fsaverage" #Template Dir with FreeSurfer NHP GCA and TIF files
    TemplateWMSkeleton="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_wmskeleton.nii.gz"

  elif [[ "$SPECIES" == *Cyno* ]] ; then                        # Cynomolgus (Macaca fascicularis)

    #WMSeg_wlo="95"                                      # suppress white matter surface invasion to cortical ribbon  e.g. M174
    #mri_segment_args="-wlo $WMSeg_wlo" 
    BrainTemplate="Mac25Cyno"
    GCAdir="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/fsaverage"
    TemplateWMSkeleton="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_wmskeleton_0.5mm.nii.gz"

  elif [[ "$SPECIES" == *Rhesus* ]] ; then                      # Rhesus (Macaca mulatta)

    BrainTemplate="Mac25Rhesus"
    GCAdir="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/fsaverage"
    TemplateWMSkeleton="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_wmskeleton_0.5mm.nii.gz"

  elif [[ "$SPECIES" == *Snow* ]] ; then                        # Japanese snow monkey (Macaca fuscata)

    BrainTemplate="Mac6Snow"
    GCAdir="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/fsaverage"
    TemplateWMSkeleton="NONE"                                 # wmskeleton is not effective for snow monkey 

  else
    echo "No Macaque subspecies matched the provided species name: $SPECIES" 1>&2
    exit 1
  fi

  GCA="RB_all_2016-05-10.vc700.gca"
  GCASkull="RB_all_withskull_2016-05-10.vc700.gca"
  AvgCurvTif="average.curvature.filled.buckner40.tif"

  # conf2hires () {
  T1normSigma=""
  T2normSigma="50"                                            # FS6 default=8, NHP has bias with larger sigma 
  #T2normSigma="20"                                            # FS6 default=8, NHP has bias with larger sigma 

  VariableSigma="6"                                           # FS6 default=3, larger value needed for smaller brain, in-vivo: 5, ex-vivo:6  
  PialSigma="2"                                               # control pial w/o T2 (woT2pial). FS6 default=2,
  WhiteSigma="2"                                              
  SmoothNiter="1"                                             # default: 2, 1 for hires
  SmoothNiterPial=""                                          # for woT2pial & pial                                            

  if ((isFLAIR)) ; then                                       # control T2 pial
    NSigmaAbove="0"                                           # 2: FS6 default
    NSigmaBelow="3"                                           # 3: FS6 default
  else                                                        # control T2-FLAIR pial
    NSigmaAbove="3"                                           # T2w/FLAIR version, default=3 
    NSigmaBelow="4"                                           # T2w/FLAIR version, default=3  
  fi    
  WMProjAbs="0.7"                                             # effective for bbregister
  MaxThickness="8"                                            # FS6 conf2hires       
  CopyBiasFromConf="TRUE"                                     # FS6 conf2hires
  #} #conf2hires

  VariableSigmaFS5="8"                                        # FS5.3.0 HighResPial  
  MaxThicknessFS5="4"                                         # FS5.3.0 HighResPial    
  GreySigmaFS5="5"                                            # FS5.3.0 HighResPial

  # FS BBR in DiffusionPreprocPipeline
  FSBBRDIFF=TRUE
  DiffWMProjAbs="0.7"

elif [[ "$SPECIES" = Marmoset ]] ; then                            # tuned by AU and TH

  IntensityCor="FAST"
  ScaleFactor="5"
  BiasFieldFastSmoothingSigma="100"                           # = 20*ScaleFactor
  mri_normalize_args="-sigma 50 -gentle"                      #  
  #WMSeg_wlo="70"                                             # set smaller value to suppress "pial-inflation failure" e.g. 70
  #WMSeg_ghi="95"                                             # 
  #mri_segment_args="-wlo $WMSeg_wlo -ghi $WMSeg_ghi"

  initcc="128 106 122"                                        # FS5.3.0 voxel coordinate in orig.mgz and wm.mgz
  mri_fill_args="-C 0 -3 3 -fillven 1 -topofix norm.mgz"
  mris_inflate1_args="-n 250"                                 # set higher # of iterations (default=10) to suppress "white surface short cut"
  mris_sphere_args=" -RADIUS 15 -remove_negative 1"

  mris_make_surfaces_args=""                                  # recon-all, init white (e.g. white.preaparc)
  # conf2hires () {
  T1normSigma=""                                              # sigma used in conf2hires
  T2normSigma="50"                                            # sigma used in conf2hires, FS6 default=8, NHP has bias with larger sigma 

  #MIN_GRAY_AT_WHITE_BORDER="24"                               # min_gray_at_white_border = gray_mean-gray_std ;
  #MAX_GRAY_AT_CSF_BORDER="24"                                 # max_gray_at_csf_border = gray_mean-0.5*gray_std ;# A180309 gray_mean=48, gray_std=6
  #MIN_GRAY_AT_CSF_BORDER="8"                                  # min_gray_at_csf_border = gray_mean - variablesigma*gray_std ; 
  #MAX_GRAY="80"                                               # max_gray = white_mean-white_std  # A18030902 white_mean=95, white_std=15
  #MAX_CSF="$MIN_GRAY_AT_CSF_BORDER"                           # max_csf = gray_mean - variablesigma*gray_std 

  VariableSigma="9"                                           # set larger value to suppress "pial-inflation failure" in small brain 
  PialSigma="4"                                               # set larger value to suppress "pial-inflation failure" in small brain
  WhiteSigma="2"                                                
  SmoothNiter="2"                                             # for white in conf2hires 
  SmoothNiterPial="2"                                         # for woT2pial & pial in conf2hires                                           
  if ((isFLAIR)) ; then                                       # control T2 pial
    NSigmaAbove="0"
    NSigmaBelow="1"
  else                                                        # control T2-FLAIR pial
    NSigmaAbove="1"
    NSigmaBelow="1"
  fi    
  WMProjAbs="0.2"
  MaxThickness="20"                                           # FS6 conf2hires       
  CopyBiasFromConf="TRUE"                                     # FS6 conf2hires
  #} # conf2hires 

  VariableSigmaFS5="12"                                       # FS5.3.0 HighResPial  
  MaxThicknessFS5="3"                                         # FS5.3.0 HighResPial       
  GreySigmaFS5="5"                                            # FS5.3.0 HighResPial
  mris_register_args="-dist 20 -max_degrees 30"               # to suppress surface registration failure in lissencephalic brain
  BrainTemplate="MarmosetRIKEN25"
  TemplateWMSkeleton="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_wmskeleton_0.2mm.nii.gz"
  GCAdir="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/fsaverage"
  GCA="MarmosetRIKEN25_2025-08-23.gca"
  GCASkull="MarmosetRIKEN25_2025-08-23.gca"
  #AvgCurvTif="average.curvature.filled.buckner40.tif"
  AvgCurvTif="MarmosetRIKEN25_2025-08-26.tif"
  GCSdir="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/fsaverage"
  GCS="MarmosetRIKEN25_2025-08-26.gcs"
  
  # FS BBR in DiffusionPreprocPipeline
  FSBBRDIFF=TRUE
  DiffWMProjAbs="0.5"

elif [[ "$SPECIES" = NightMonkey ]] ; then                         # tuned by TH, TI in Aug 2020

  IntensityCor="FAST"
  ScaleFactor="4"
  BiasFieldFastSmoothingSigma="80"                            # = 20*ScaleFactor
  mri_normalize_args="-sigma 32 -gentle"                      # = 8*ScaleFactor
  #WMSeg_wlo="95"      
  #WMSeg_ghi="100"  
  #mri_segment_args="-wlo $WMSeg_wlo -ghi $WMSeg_ghi"
  initcc="128 100 124"                                        # FS5.3.0 voxel coordinate in orig.mgz and wm.mgz
  mri_fill_args="-C 0 -15 21 -fillven 1 -topofix norm.mgz"
  mris_inflate1_args="-n 250"                                 # set higher # of iterations (default=10) to avoid "white surface short cut"
  mris_sphere_args=" -RADIUS 35 -remove_negative 1"
  T1normSigma=""
  T2normSigma="50"                                            # FS6 default=8, NHP has bias with larger sigma 
  VariableSigma="9"                                           # larger value needed for smaller brain 
  PialSigma="4"                                               # larger value needed for smaller brain
  SmoothNiter="2"
  SmoothNiterPial="2"                                         # for woT2pial & pial                                            
  if ((isFLAIR)) ; then                        				  # control T2 pial
    NSigmaAbove="1"                                           # 2: FS6 default
    NSigmaBelow="3"                                           # 2: FS6 default
  else                                                        # control T2-FLAIR pial
    NSigmaAbove="3"
    NSigmaBelow="2"
  fi    
  WMProjAbs="0.3"
  MaxThickness="10"                                           # FS6 conf2hires       
  CopyBiasFromConf="TRUE"                                     # FS6 conf2hires

  VariableSigmaFS5="10"                                       # FS5.3.0 HighResPial  
  MaxThicknessFS5="4"                                         # FS5.3.0 HighResPial    
  GreySigmaFS5="5"                                            # FS5.3.0 HighResPial
  BrainTemplate="NightMonkeyRIKEN9"
  TemplateWMSkeleton="${HCPPIPEDIR_Templates}/NHP_NNP/${BrainTemplate}/MNINonLinear/${BrainTemplate}_Averagewmskeleton.nii.gz"
  GCAdir="$HCPPIPEDIR/global/templates/NHP_NNP/${BrainTemplate}/fsaverage"
  GCA="RB_all_2016-05-10.vc700.gca"
  GCASkull="RB_all_withskull_2016-05-10.gca"
  AvgCurvTif="average.curvature.filled.buckner40.tif"

  # FS BBR in DiffusionPreprocPipeline
  FSBBRDIFF=TRUE
  DiffWMProjAbs="0.3"

else

  echo "Warning: Not yet supported species: $SPECIES"

fi
