Subjlist="792564"
# Need to call SetUpHCPPipeline.sh (to set up appropriate paths)
. SOMEPATH/SetUpHCPPipeline.sh
GitRepo=${HCPPIPEDIR}
StudyFolder=${HCPPIPEDIR}/Examples

# Requirements for this script
#  installed versions of: FSL5.0.1 or higher , FreeSurfer (version 5 or higher) , gradunwarp (python code from MGH)
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET5DIR , CARET7DIR , PATH (for gradient_unwarp.py)

# Log the originating call
echo "$@"

if [ X$SGE_ROOT != X ] ; then
    QUEUE="-q long.q"
fi

PRINTCOM=""
#PRINTCOM="echo"
#QUEUE="-q veryshort.q"


########################################## INPUTS ########################################## 

# NB: Scripts called by this script do NOT assume anything about the form of the input names or paths, so the only place requiring modification of input names is this script

# ${StudyFolder}/${Subject}/T1w/${Subject}_${Session}_T1w_MPR1${Suffix}.nii.gz
# ${StudyFolder}/${Subject}/T1w/${Subject}_${Session}_T1w_MPR2${Suffix}.nii.gz
#  e.g. in the Example : 792564_strc_T1w_MPR1.nii.gz

# ${StudyFolder}/${Subject}/T2w/${Subject}_${Session}_T2w_SPC1${Suffix}.nii.gz
# ${StudyFolder}/${Subject}/T2w/${Subject}_${Session}_T2w_SPC2${Suffix}.nii.gz
#  e.g. in the Example : 792564_strc_T2w_SPC1.nii.gz


######################################### DO WORK ##########################################


for Subject in $Subjlist ; do
  echo $Subject
  #Input Variables
  TemplateFolder="${GitRepo}/global/templates" #Template Path
  ConfigFolder="${GitRepo}/global/config" #Config Path
  Subject="$Subject" #SubjectID
  Session=`ls ${StudyFolder}/${Subject}/T1w | grep T1w_MPR1 | grep nii.gz | sed s@${Subject}_@@g | sed s/_T1w_MPR1//g | sed s/.nii.gz//g | cut -d "_" -f 1`
  if [ -z `ls ${StudyFolder}/${Subject}/T1w | grep T1w_MPR1.nii.gz` ] ; then
    Suffix=`ls ${StudyFolder}/${Subject}/T1w | grep T1w_MPR1 | grep nii.gz | sed s@${Subject}_@@g | sed s/_T1w_MPR1//g | sed s/.nii.gz//g | cut -d "_" -f 2`
    Suffix=`echo "_${Suffix}"`
  else
    Suffix=""
  fi
  T1wInputImages="${StudyFolder}/${Subject}/T1w/${Subject}_${Session}_T1w_MPR1${Suffix}.nii.gz@${StudyFolder}/${Subject}/T1w/${Subject}_${Session}_T1w_MPR2${Suffix}.nii.gz" #T1w1@T1w2@etc..
  T2wInputImages="${StudyFolder}/${Subject}/T2w/${Subject}_${Session}_T2w_SPC1${Suffix}.nii.gz@${StudyFolder}/${Subject}/T2w/${Subject}_${Session}_T2w_SPC2${Suffix}.nii.gz" #T1w1@T1w2@etc..
  T1wTemplate="${TemplateFolder}/MNI152_T1_0.7mm.nii.gz" #MNI0.7mm template
  T1wTemplateBrain="${TemplateFolder}/MNI152_T1_0.7mm_brain.nii.gz" #Brain extracted MNI0.7mm template
  T1wTemplate2mm="${TemplateFolder}/MNI152_T1_2mm.nii.gz" #MNI2mm template
  T2wTemplate="${TemplateFolder}/MNI152_T2_0.7mm.nii.gz" #MNI0.7mm T2wTemplate
  T2wTemplateBrain="${TemplateFolder}/MNI152_T2_0.7mm_brain.nii.gz" #Brain extracted MNI0.7mm T2wTemplate
  T2wTemplate2mm="${TemplateFolder}/MNI152_T2_2mm.nii.gz" #MNI2mm T2wTemplate
  TemplateMask="${TemplateFolder}/MNI152_T1_0.7mm_brain_mask.nii.gz" #Brain mask MNI0.7mm template
  Template2mmMask="${TemplateFolder}/MNI152_T1_2mm_brain_mask_dil.nii.gz" #MNI2mm template
  BrainSize="150" #BrainSize in mm
  FNIRTConfig="${FSLDIR}/etc/flirtsch/T1_2_MNI152_2mm.cnf" #FNIRT 2mm T1w Config
  FieldMapImageFolder="${StudyFolder}/${Subject}/FieldMap_${Session}" #Get session from SubjectID or "NONE" if not used
  MagnitudeInputName="${Subject}_${Session}_FieldMap_Magnitude.nii.gz" #Expects 4D magitude volume with two 3D timepoints or "NONE" if not used
  PhaseInputName="${Subject}_${Session}_FieldMap_Phase.nii.gz" #Expects 3D phase difference volume or "NONE" if not used
  TE="2.46" #delta TE in ms for field map or "NONE" if not used
  T1wSampleSpacing="0.0000074" #DICOM field (0019,1018) in s or "NONE" if not used
  T2wSampleSpacing="0.0000021" #DICOM field (0019,1018) in s or "NONE" if not used
  UnwarpDir="z" #z appears to be best or "NONE" if not used
  GradientDistortionCoeffs="${ConfigFolder}/coeff_SC72C_Skyra.grad" #Location of Coeffs file or "NONE" to skip
  AvgrdcSTRING="FIELDMAP" #Averaging and readout distortion correction methods: "NONE" = average any repeats with no readout correction "FIELDMAP" = average any repeats and use field map for readout correction "TOPUP" = average and distortion correct at the same time with topup/applytopup only works for 2 images currently
  TopupConfig="NONE" #Config for topup or "NONE" if not used

  ${FSLDIR}/bin/fsl_sub ${QUEUE} \
     ${GitRepo}/PreFreeSurfer/PreFreeSurferPipeline.sh \
      --path="$StudyFolder" \
      --subject="$Subject" \
      --t1="$T1wInputImages" \
      --t2="$T2wInputImages" \
      --t1template="$T1wTemplate" \
      --t1templatebrain="$T1wTemplateBrain" \
      --t1template2mm="$T1wTemplate2mm" \
      --t2template="$T2wTemplate" \
      --t2templatebrain="$T2wTemplateBrain" \
      --t2template2mm="$T2wTemplate2mm" \
      --templatemask="$TemplateMask" \
      --template2mmmask="$Template2mmMask" \
      --brainsize="$BrainSize" \
      --fnirtconfig="$FNIRTConfig" \
      --fmapdir="$FieldMapImageFolder" \
      --fmapmag="$MagnitudeInputName" \
      --fmapphase="$PhaseInputName" \
      --echospacing="$TE" \
      --t1samplespacing="$T1wSampleSpacing" \
      --t2samplespacing="$T2wSampleSpacing" \
      --unwarpdir="$UnwarpDir" \
      --gdcoeffs="$GradientDistortionCoeffs" \
      --avgrdcmethod="$AvgrdcSTRING" \
      --topupconfig="$TopupConfig" \
      --printcom=$PRINTCOM
#      --path="$PipelineScripts" \
#      --path="$Caret5_Command" \
#      --path="$GlobalScripts" \

  # The following line could be used (if sourced and not echoed) to set the positional parameters: $1 $2 $3 ...

  #echo "set -- $StudyFolder $Subject $T1wInputImages $T2wInputImages $T1wTemplate $T1wTemplateBrain $T1wTemplate2mm $T2wTemplate $T2wTemplateBrain $T2wTemplate2mm $TemplateMask $Template2mmMask $BrainSize $FNIRTConfig $FieldMapImageFolder $MagnitudeInputName $PhaseInputName $TE $T1wSampleSpacing $T2wSampleSpacing $UnwarpDir $PipelineScripts $Caret5_Command $GlobalScripts $GradientDistortionCoeffs $AvgrdcSTRING $TopupConfig"
done

