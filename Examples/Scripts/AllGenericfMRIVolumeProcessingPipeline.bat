Subjlist="792564"
# Need to call SetUpHCPPipeline.sh (to set up appropriate paths)
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

######################################### DO WORK ##########################################

Tasklist="EMOTION1_RL EMOTION2_LR"
PhaseEncodinglist="x x-"

#set -xv
for Subject in $Subjlist ; do
  i=1
  for Task in $Tasklist ; do
    UnwarpDir=`echo $PhaseEncodinglist | cut -d " " -f $i`
    if [ -z `echo $Task | grep REST` ] ; then
      Type="tfMRI"
    else
      Type="rfMRI"
    fi
    DIR=`pwd`
    cd "$StudyFolder"/"$Subject"
    length=`ls . | grep BOLD_${Task}_fnc | sed 's/_/ /g' | wc -w`
    Session=`ls . | grep BOLD_${Task}_fnc | cut -d "_" -f "$length"`
    SubjectStem=`echo $Subject | cut -d "_" -f 1`
    fMRIFolder="BOLD_${Task}_${Session}"
    FieldMapImageFolder="SpinEchoFieldMap1_${Session}" #Either Standard Field Map or Folder with Both Spin Echo Images In it
    ScoutFolder="BOLD_${Task}_SBRef_${Session}"
    InputNameOffMRI="${SubjectStem}_${Session}_BOLD_${Task}.nii.gz"
    OutputNameOffMRI="${Type}_`echo ${Task} | cut -d "_" -f 1`"
    MagnitudeInputName="${SubjectStem}_${Session}_BOLD_LR_SB_SE.nii.gz" #Expects 4D Magnitude volume with two 3D timepoints or First Spin Echo Phase Encoding Direction LR
    PhaseInputName="${SubjectStem}_${Session}_BOLD_RL_SB_SE.nii.gz" #Expects a 3D Phase volume or Second Spin Echo Plase Encoding Direction RL
    ScoutInputName="${SubjectStem}_${Session}_BOLD_${Task}_SBRef.nii.gz" #Can be set to NONE, to fake, but this is not recommended
    DwellTime="0.00058" #from ConnectomeDB
    TE="2.46" #0.00246 for 3T, 0.00102 for 7T 
    UnwarpDir="$UnwarpDir" #U min empirical 
    FinalFMRIResolution="2"
    PipelineScripts="${GitRepo}/fMRIVolume/scripts"
    GlobalScripts="${GitRepo}/global/scripts"
    DistortionCorrection="TOPUP" #FIELDMAP or TOPUP
    GradientDistortionCoeffs="${GitRepo}/global/config/coeff_SC72C_Skyra.grad"
    FNIRTConfig="NONE" #Put a FNIRT config to use approximate zblip distortion correction otherwise NONE to turn that off
    TopUpConfig="${GitRepo}/global/config/b02b0.cnf" #Put a Topup Config if DistortionCorrection="TOPUP" is set
    GlobalBinaries="${GitRepo}/global/binaries"
    cd $DIR

    if [ -e "$StudyFolder"/"$Subject"/"$fMRIFolder"/"$InputNameOffMRI" ] ; then
	${FSLDIR}/bin/fsl_sub $QUEUE \
	    ${GitRepo}/fMRIVolume/GenericfMRIVolumeProcessingPipeline.sh \
	    --path=$StudyFolder \
	    --subject=$Subject \
	    --fmridir=$fMRIFolder \
	    --fmapdir=$FieldMapImageFolder \
	    --scoutdir=$ScoutFolder \
	    --fmriinname=$InputNameOffMRI \
	    --fmrioutname=$OutputNameOffMRI \
	    --fmapmag=$MagnitudeInputName \
	    --fmapphase=$PhaseInputName \
	    --scoutin=$ScoutInputName \
	    --echospacing=$DwellTime \
	    --echodiff=$TE \
	    --unwarpdir=$UnwarpDir \
	    --fmrires=$FinalFMRIResolution \
	    --dcmethod=$DistortionCorrection \
	    --gdcoeffs=$GradientDistortionCoeffs \
	    --fnirtconfig=$FNIRTConfig \
	    --topupconfig=$TopUpConfig \
	    --printcom=$PRINTCOM
	    #$PipelineScripts \
	    #$GlobalScripts \
	    #$GlobalBinaries
	
      #echo "set -- $StudyFolder $Subject $fMRIFolder $FieldMapImageFolder $ScoutFolder $InputNameOffMRI $OutputNameOffMRI $MagnitudeInputName $PhaseInputName $ScoutInputName $DwellTime $TE $UnwarpDir $FinalFcMRIResolution $PipelineScripts $GlobalScripts $DistortionCorrection $GradientDistortionCoeffs $FNIRTConfig $TopUpConfig $GlobalBinaries"
	sleep 1
    else
	echo "fMRI Run ""$StudyFolder""/""$Subject""/""$fMRIFolder""/""$InputNameOffMRI"" Not Found"
    fi
    i=`echo "$i + 1" | bc`
  done
done


