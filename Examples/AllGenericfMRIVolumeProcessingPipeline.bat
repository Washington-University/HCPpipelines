#Subjlist="CP10051_v3 CP10079_v2 CP10081_v3 CP10081_v6 CP10098_v2 CP10101_v1 CP10102_v1 CP10103_v1 CP10103_v4 CP10104_v1 CP10105_v1 CP10105_v4 CP10107_v1 CP10107_v4"
Subjlist="CP10101_v1"
Path="/media/myelin/brainmappers/Connectome_Project/ParcellationPilot"


#Tasklist="REST1 BIOMOTION1 LANG1 LANG2 MOTOR1 SOCIAL1 SOCIAL2 WM1 WM2 WM3 WM4"
#Tasklist="REST1"
#Tasklist="BIOMOTION1"
Tasklist="BIOMOTION1 MOTOR1"

for Subject in $Subjlist ; do
  for Task in $Tasklist ; do
    if [ -z `echo $Task | grep REST` ] ; then
      Type="tfMRI"
    else
      Type="rfMRI"
    fi
    cd "$Path"/"$Subject"
    Session=`ls . | grep ${Type}_${Task}_v | cut -d "_" -f 3`
    SubjectStem=`echo $Subject | cut -d "_" -f 1`
    fMRIFolder="${Type}_${Task}_${Session}"
    FieldMapImageFolder="FieldMap_${Session}"
    ScoutFolder="${Type}_${Task}_SB_${Session}"
    InputNameOffMRI="${SubjectStem}_${Session}_BOLD_${Task}.nii.gz"
    OutputNameOffMRI="${Type}_${Task}"
    MagnitudeInputName="${SubjectStem}_${Session}_FieldMap_Mag.nii.gz" #Expects 4D volume with two 3D timepoints
    PhaseInputName="${SubjectStem}_${Session}_FieldMap_Pha.nii.gz"
    ScoutInputName="${SubjectStem}_${Session}_BOLD_${Task}_SB.nii.gz" #Can be set to NONE, to fake, but this is not recommended
    DwellTime="0.00055" #from Eddie's formula: 1/(17.153*106)
    TE="2.46" #0.00246 for 3T, 0.00102 for 7T 
    UnwarpDir="y" #U min empirical 
    FinalFcMRIResolution="2"
    PipelineScripts="/media/2TBB/Connectome_Project/Pipelines/fMRIVolume/scripts"
    GlobalScripts="/media/2TBB/Connectome_Project/Pipelines/global/scripts"
    DistortionCorrection="FIELDMAP"
    GradientDistortionCoeffs="/media/2TBB/Connectome_Project/Pipelines/global/config/coeff_SC72C_Skyra.grad"
    FNIRTConfig="/media/2TBB/Connectome_Project/Pipelines/global/config/T1_2_MNI152_2mm.cnf" #Put a FNIRT config to use approximate zblip distortion correction otherwise NONE to turn that off
    
    fsl_sub -q long.q /media/2TBB/Connectome_Project/Pipelines/fMRIVolume/GenericfMRIVolumeProcessingPipeline.sh $Path $Subject $fMRIFolder $FieldMapImageFolder $ScoutFolder $InputNameOffMRI $OutputNameOffMRI $MagnitudeInputName $PhaseInputName $ScoutInputName $DwellTime $TE $UnwarpDir $FinalFcMRIResolution $PipelineScripts $GlobalScripts $DistortionCorrection $GradientDistortionCoeffs $FNIRTConfig
    #echo "set -- $Path $Subject $fMRIFolder $FieldMapImageFolder $ScoutFolder $InputNameOffMRI $OutputNameOffMRI $MagnitudeInputName $PhaseInputName $ScoutInputName $DwellTime $TE $UnwarpDir $FinalFcMRIResolution $PipelineScripts $GlobalScripts $DistortionCorrection $GradientDistortionCoeffs $FNIRTConfig"
  done
done


