StudyFolder="$1"
Subject="$2"
DownSampleNameI="$3"
DiffusionResolution="$4"
Caret7_Command="$5"
HemisphereSTRING="$6" #L@R or L or R or Whole
NumberOfSamples="$7" #1 sample then 2 and calculate total time required per sample
StepSize="$8" #1/4 diffusion resolution recommended
Curvature="$9" #Inverse cosine of this value is the angle, default 0.2=~78 degrees, 0=90 degrees
DistanceThreshold="${10}" #Start at zero?
GlobalBinaries="${11}"
PD="${12}"


#NamingConventions
T1wFolder="T1w"
BedpostXFolder="Diffusion.bedpostX"
NativeFolder="Native"
DownSampleFolder="fsaverage_LR${DownSampleNameI}k"
ROIsFolder="ROIs"
ResultsFolder="Results"

HemisphereSTRING=`echo "$HemisphereSTRING" | sed 's/@/ /g'`

#Make Paths
T1wFolder="${StudyFolder}/${Subject}/${T1wFolder}"
BedpostXFolder="${T1wFolder}/${BedpostXFolder}"
NativeFolder="${T1wFolder}/${NativeFolder}"
DownSampleFolder="${T1wFolder}/${DownSampleFolder}"
ROIsFolder="${T1wFolder}/${ROIsFolder}"
ResultsFolder="${T1wFolder}/${ResultsFolder}"

#Probtrackx Options
Options="--forcedir --meshspace=caret --nsteps=2000 --fibthresh=0.05 --loopcheck --randfib=2 --forcefirststep --opd --omatrix3 --omatrix4 --sampvox=${DiffusionResolution} --verbose=1"
Arguments="--nsamples=${NumberOfSamples} --cthr=${Curvature} --steplength=${StepSize} --distthresh3=${DistanceThreshold} --distthresh=${DistanceThreshold}"

#Probtrackx Paths
Samples="--samples=${BedpostXFolder}/merged"

#PD
if [ $PD = "YES" ] ; then
  PDDir="_pd"
  PDFlag="--pd"
else
  PDDir=""
  PDFlag=""
fi

if [ ! $HemisphereSTRING = "Whole" ] ; then
  for Hemisphere in $HemisphereSTRING ; do
    if [ $Hemisphere = "L" ] ; then
      Number="2"
    elif [ $Hemisphere = "R" ] ; then
      Number="41"
    fi
    #HemiPaths
    trajectory="${Hemisphere}_Cerebral_Trajectory"
    Mask="--mask=${T1wFolder}/${trajectory}_${DiffusionResolution}.nii.gz"
    if [ ! -e ${ROIsFolder}/${Subject}.${Hemisphere}.white_${DiffusionResolution}.nii.gz ] ; then
      fslmaths ${T1wFolder}/${trajectory}_${DiffusionResolution}.nii.gz -thr ${Number} -uthr ${Number} ${ROIsFolder}/${Subject}.${Hemisphere}.white_${DiffusionResolution}.nii.gz
    fi  
    Seed="--seed=${ROIsFolder}/${Subject}.${Hemisphere}.white_${DiffusionResolution}.nii.gz"
    Waypoints="--waypoints=${DownSampleFolder}/${Subject}.${Hemisphere}.white.${DownSampleNameI}k_fs_LR.surf.gii"
    Stop="--stop=${DownSampleFolder}/${Subject}.${Hemisphere}.pial.${DownSampleNameI}k_fs_LR.surf.gii"
    #echo "${DownSampleFolder}/${Subject}.${Hemisphere}.white.${DownSampleNameI}k_fs_LR.surf.gii" > ${ROIsFolder}/${Hemisphere}_Trajectory_Matrix3_Stop.txt
    #echo "${DownSampleFolder}/${Subject}.${Hemisphere}.pial.${DownSampleNameI}k_fs_LR.surf.gii" >> ${ROIsFolder}/${Hemisphere}_Trajectory_Matrix3_Stop.txt
    #Stop="--stop=${ROIsFolder}/${Hemisphere}_Trajectory_Matrix3_Stop.txt"
    #Avoid="--avoid=${ROIsFolder}/${trajectory}_invROI_${DiffusionResolution}.nii.gz"
    DIR="${ResultsFolder}/${Hemisphere}_Trajectory_Matrix1${PDDir}_${StepSize}"
    Dir="--dir=${DIR}"
    TargetThree="--target3=${DownSampleFolder}/${Subject}.${Hemisphere}.white.${DownSampleNameI}k_fs_LR.surf.gii"
    TargetFour="--target4=${T1wFolder}/${trajectory}_${DiffusionResolution}.nii.gz"
    ColMask="--colmask4=${DownSampleFolder}/${Subject}.${Hemisphere}.white.${DownSampleNameI}k_fs_LR.surf.gii" #Colmask is a surface
    SeedRef="--seedref=${T1wFolder}/${trajectory}_${DiffusionResolution}.nii.gz"
    HemiPaths="${Mask} ${Seed} ${Waypoints} ${Stop} ${Avoid} ${Dir} ${TargetThree} ${TargetFour} ${SeedRef} ${ColMask}"
    
    probtrackx_args="${Samples} ${HemiPaths} ${Arguments} ${Options} ${PDFlag}"
    
    if [ -e $DIR ] ; then
      rm -r $DIR
    fi
    mkdir $DIR    
    $Caret7_Command -signed-distance-to-surface ${DownSampleFolder}/${Subject}.${Hemisphere}.white.${DownSampleNameI}k_fs_LR.surf.gii ${DownSampleFolder}/${Subject}.${Hemisphere}.pial.${DownSampleNameI}k_fs_LR.surf.gii ${DIR}/SeedSpaceMetric.func.gii
    $Caret7_Command -metric-math "(var * 0) + 1" ${DIR}/SeedSpaceMetric.func.gii -var var ${DIR}/SeedSpaceMetric.func.gii

    echo "${GlobalBinaries}/probtrackx2 ${probtrackx_args}"
    time ${GlobalBinaries}/probtrackx2 ${probtrackx_args}
    
  done
else
  ###Whole NOT YET IMPLEMENTED### 
  echo "1+1=2" > /dev/null
fi


