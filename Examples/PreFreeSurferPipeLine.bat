#Subjlist="CP10051_v3 CP10079_v2 CP10081_v3 CP10081_v6 CP10098_v2 CP10101_v1 CP10102_v1 CP10103_v1 CP10103_v4 CP10104_v1 CP10105_v1 CP10105_v4 CP10107_v1 CP10107_v4"
Subjlist="CP10101_v1"
#Subjlist="CP10107_v1 CP10107_v4"

for Subject in $Subjlist ; do
  #Input Variables
  StudyFolder="/media/myelin/brainmappers/Connectome_Project/ParcellationPilot" #Path to subject's data folder
  TemplateFolder="/media/2TBB/Connectome_Project/Pipelines/global/templates" #Template Path
  ConfigFolder="/media/2TBB/Connectome_Project/Pipelines/global/config" #Config Path
  Subject="$Subject" #SubjectID
  T1wInputImages="${StudyFolder}/${Subject}/T1w/${Subject}_T1w1.nii.gz@${StudyFolder}/${Subject}/T1w/${Subject}_T1w2.nii.gz" #T1w1@T1w2@etc..
  T2wInputImages="${StudyFolder}/${Subject}/T2w/${Subject}_T2w1.nii.gz@${StudyFolder}/${Subject}/T2w/${Subject}_T2w2.nii.gz" #T2w1@T2w2@etc..
  T1wTemplate="${TemplateFolder}/MNI152_T1_0.8mm.nii.gz" #MNI0.8mm template
  T1wTemplateBrain="${TemplateFolder}/MNI152_T1_0.8mm_brain.nii.gz" #Brain extracted MNI0.8mm template
  T1wTemplate2mm="${TemplateFolder}/MNI152_T1_2mm.nii.gz" #MNI2mm template
  T2wTemplate="${TemplateFolder}/MNI152_T2_0.8mm.nii.gz" #MNI0.8mm T2wTemplate
  T2wTemplateBrain="${TemplateFolder}/MNI152_T2_0.8mm_brain.nii.gz" #Brain extracted MNI0.8mm T2wTemplate
  T2wTemplate2mm="${TemplateFolder}/MNI152_T2_2mm.nii.gz" #MNI2mm T2wTemplate
  TemplateMask="${TemplateFolder}/MNI152_T1_0.8mm_brain_mask.nii.gz" #Brain mask MNI0.8mm template
  Template2mmMask="${TemplateFolder}/MNI152_T1_2mm_brain_mask_dil.nii.gz" #MNI2mm template
  StandardFOVMask="${TemplateFolder}/std_fov.nii.gz" #StandardFOV mask for averaging structurals
  FNIRTConfig="${ConfigFolder}/T1_2_MNI152_2mm.cnf" #FNIRT 2mm T1w Config
  FieldMapImageFolder="${StudyFolder}/${Subject}/FieldMap_`echo $Subject | cut -d "_" -f 2`" #Get session from SubjectID or "NONE" if not used
  MagnitudeInputName="${Subject}_FieldMap_Mag.nii.gz" #Expects 4D magitude volume with two 3D timepoints or "NONE" if not used
  PhaseInputName="${Subject}_FieldMap_Pha.nii.gz" #Expects 3D phase difference volume or "NONE" if not used
  TE="2.46" #delta in ms TE for field map or "NONE" if not used
  T1wSampleSpacing="0.0000078" #DICOM field (0019,1018) = 7800/10^9 in s or "NONE" if not used
  T2wSampleSpacing="0.0000021" #DICOM field (0019,1018) = 2100/10^9 in s or "NONE" if not used
  UnwarpDir="z" #z appears to be best or "NONE" if not used
  PipelineScripts="/media/2TBB/Connectome_Project/Pipelines/PreFreeSurfer/scripts" #Location where the pipeline modules are
  Caret5_Command="/usr/bin/caret_command" #Location of Caret5 caret_command
  GlobalScripts="/media/2TBB/Connectome_Project/Pipelines/global/scripts" #Location where the global pipeline modules are
  GradientDistortionCoeffs="${ConfigFolder}/coeff_SC72C_Skyra.grad" #Location of Coeffs file or "NONE" to skip
  AvgrdcSTRING="FIELDMAP" #Averaging and readout distortion correction methods: "NONE" = average any repeats with no readout correction "FIELDMAP" = average any repeats and use field map for readout correction "TOPUP" = average and distortion correct at the same time with topup/applytopup only works for 2 images currently
  TopupConfig="NONE" #Config for topup or "NONE" if not used

  fsl_sub -q veryshort.q /media/2TBB/Connectome_Project/Pipelines/PreFreeSurfer/PreFreeSurferPipeline.sh "$StudyFolder" "$Subject" "$T1wInputImages" "$T2wInputImages" "$T1wTemplate" "$T1wTemplateBrain" "$T1wTemplate2mm" "$T2wTemplate" "$T2wTemplateBrain" "$T2wTemplate2mm" "$TemplateMask" "$Template2mmMask" "$StandardFOVMask" "$FNIRTConfig" "$FieldMapImageFolder" "$MagnitudeInputName" "$PhaseInputName" "$TE" "$T1wSampleSpacing" "$T2wSampleSpacing" "$UnwarpDir" "$PipelineScripts" "$Caret5_Command" "$GlobalScripts" "$GradientDistortionCoeffs" "$AvgrdcSTRING" "$TopupConfig" 
  #set -- "$StudyFolder" "$Subject" "$T1wInputImages" "$T2wInputImages" "$T1wTemplate" "$T1wTemplateBrain" "$T1wTemplate2mm" "$T2wTemplate" "$T2wTemplateBrain" "$T2wTemplate2mm" "$TemplateMask" "$Template2mmMask" "$StandardFOVMask" "$FNIRTConfig" "$FieldMapImageFolder" "$MagnitudeInputName" "$PhaseInputName" "$TE" "$T1wSampleSpacing" "$T2wSampleSpacing" "$UnwarpDir" "$PipelineScripts" "$Caret5_Command" "$GlobalScripts" "$GradientDistortionCoeffs" "$AvgrdcSTRING" "$TopupConfig"
  #echo "$StudyFolder" "$Subject" "$T1wInputImages" "$T2wInputImages" "$T1wTemplate" "$T1wTemplateBrain" "$T1wTemplate2mm" "$T2wTemplate" "$T2wTemplateBrain" "$T2wTemplate2mm" "$TemplateMask" "$Template2mmMask" "$StandardFOVMask" "$FNIRTConfig" "$FieldMapImageFolder" "$MagnitudeInputName" "$PhaseInputName" "$TE" "$T1wSampleSpacing" "$T2wSampleSpacing" "$UnwarpDir" "$PipelineScripts" "$Caret5_Command" "$GlobalScripts" "$GradientDistortionCoeffs" "$AvgrdcSTRING" "$TopupConfig"
  sleep 10
done

