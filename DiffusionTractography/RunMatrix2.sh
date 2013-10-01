#!/bin/bash
set -e

# Tractography Pipeline for creating Matrix2-based full connectomes. Assumes a CPU cluster and GPU nodes and submits to the queues.
# Stamatios Sotiropoulos, Moises Hernandez, Saad Jbabdi, Analysis Group, FMRIB Centre, 2013.

if [ "$4" == "" ];then
    echo ""
    echo "usage: $0 <StudyFolder> <Subject> <DistanceThreshold> <DownsampleMat2Target>"
    echo "<DistanceThreshold> in mm (e.g. 4), defines the max distance allowed from the pial surface and the cubcortex"
    echo "                    for a voxel to be considered in Mat2 Target mask. Use -1 to avoid any stripping"
    echo "if flag <DownsampleMat2Target> is set to 1, the mask is downsampled to 3mm isotropic"
    echo ""
    exit 1
fi

StudyFolder=$1          # "$1" #Path to Generic Study folder
Subject=$2              # "$2" #SubjectID
DistanceThreshold=$3
DownsampleMat2Target=$4

bindir=/home/stam/fsldev/ptx2  #Eventually FSLDIR (use custom probtrackx2 and fdt_matrix_merge for now)
scriptsdir=${HCPPIPEDIR_dMRITract}
TemplateFolder="${HCPPIPEDIR_Template}/91282_Greyordinates"

# Hard-coded variables for now
Nsamples=100
Nrepeats=50

if [ $DownsampleMat2Target -eq 0 ]; then
    echo "Warning!! Not downsampling the target mask requires large amounts of memory and may crash the current scripts!"
fi

ResultsFolder="$StudyFolder"/"$Subject"/MNINonLinear/Results/Tractography
BedpostxFolder="$StudyFolder"/"$Subject"/T1w/Diffusion.bedpostX
RegFolder="$StudyFolder"/"$Subject"/MNINonLinear/xfms
ROIsFolder="$StudyFolder"/"$Subject"/MNINonLinear/ROIs
if [ ! -e ${ResultsFolder} ] ; then
  mkdir ${ResultsFolder}
fi

#Use BedpostX samples
BedpostxFolder="$StudyFolder"/"$Subject"/T1w/Diffusion.bedpostX
DtiMask=$BedpostxFolder/nodif_brain_mask
#Or RubiX samples
#BedpostxFolder="$StudyFolder"/"$Subject"/T1w/Diffusion.rubiX
#DtiMask=$BedpostxFolder/HRbrain_mask


#Temporarily here, should be in Prepare_Seeds
rm -rf $ResultsFolder/stop
rm -rf $ResultsFolder/volseeds
rm -rf $ResultsFolder/Mat2_seeds

echo $ResultsFolder/L.roi.asc >> $ResultsFolder/stop
echo $ResultsFolder/R.roi.asc >> $ResultsFolder/stop

echo $ResultsFolder/CIFTI_STRUCTURE_ACCUMBENS_LEFT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_ACCUMBENS_RIGHT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_AMYGDALA_LEFT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_AMYGDALA_RIGHT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_BRAIN_STEM >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_CAUDATE_LEFT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_CAUDATE_RIGHT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_CEREBELLUM_LEFT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_CEREBELLUM_RIGHT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_DIENCEPHALON_VENTRAL_LEFT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_DIENCEPHALON_VENTRAL_RIGHT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_HIPPOCAMPUS_LEFT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_HIPPOCAMPUS_RIGHT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_PALLIDUM_LEFT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_PALLIDUM_RIGHT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_PUTAMEN_LEFT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_PUTAMEN_RIGHT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_THALAMUS_LEFT >> $ResultsFolder/volseeds
echo $ResultsFolder/CIFTI_STRUCTURE_THALAMUS_RIGHT >> $ResultsFolder/volseeds

echo $ResultsFolder/white.L.asc >> $ResultsFolder/Mat2_seeds
echo $ResultsFolder/white.R.asc >> $ResultsFolder/Mat2_seeds
cat $ResultsFolder/volseeds >> $ResultsFolder/Mat2_seeds

#Define Generic Options
generic_options=" --loopcheck --forcedir --fibthresh=0.01 -c 0.2 --sampvox=2 --randfib=1 -P ${Nsamples} -S 2000 --steplength=0.5"
o=" -s $BedpostxFolder/merged -m $DtiMask --meshspace=caret"

#Define Seed
Seed="$ResultsFolder/Mat2_seeds"
StdRef=$FSLDIR/data/standard/MNI152_T1_2mm_brain_mask
o=" $o -x $Seed --seedref=$StdRef"
o=" $o --xfm=`echo $RegFolder/standard2acpc_dc` --invxfm=`echo $RegFolder/acpc_dc2standard`"

#Define Targets
if [ "$DistanceThreshold" == "-1" ]; then
    ${FSLDIR}/bin/imcp $ROIsFolder/Whole_Brain_Trajectory_ROI_2 ${ResultsFolder}/Mat2_target
else 
######Create mask stripped from deep WM...
    $FSLDIR/bin/surf2volume $ResultsFolder/L.roi.asc $StdRef $ResultsFolder/Lsurf_pial caret
    $FSLDIR/bin/surf2volume $ResultsFolder/R.roi.asc $StdRef $ResultsFolder/Rsurf_pial caret

    $FSLDIR/bin/fslmaths $ResultsFolder/Lsurf_pial -add $ResultsFolder/Rsurf_pial -add $ResultsFolder/CIFTI_STRUCTURE_ACCUMBENS_RIGHT -add $ResultsFolder/CIFTI_STRUCTURE_AMYGDALA_RIGHT -add $ResultsFolder/CIFTI_STRUCTURE_BRAIN_STEM -add $ResultsFolder/CIFTI_STRUCTURE_CAUDATE_RIGHT -add $ResultsFolder/CIFTI_STRUCTURE_CEREBELLUM_RIGHT -add $ResultsFolder/CIFTI_STRUCTURE_DIENCEPHALON_VENTRAL_RIGHT -add $ResultsFolder/CIFTI_STRUCTURE_HIPPOCAMPUS_RIGHT -add $ResultsFolder/CIFTI_STRUCTURE_PALLIDUM_RIGHT -add $ResultsFolder/CIFTI_STRUCTURE_PUTAMEN_RIGHT -add $ResultsFolder/CIFTI_STRUCTURE_THALAMUS_RIGHT -add $ResultsFolder/CIFTI_STRUCTURE_ACCUMBENS_LEFT -add $ResultsFolder/CIFTI_STRUCTURE_AMYGDALA_LEFT -add $ResultsFolder/CIFTI_STRUCTURE_BRAIN_STEM -add $ResultsFolder/CIFTI_STRUCTURE_CAUDATE_LEFT -add $ResultsFolder/CIFTI_STRUCTURE_CEREBELLUM_LEFT -add $ResultsFolder/CIFTI_STRUCTURE_DIENCEPHALON_VENTRAL_LEFT -add $ResultsFolder/CIFTI_STRUCTURE_HIPPOCAMPUS_LEFT -add $ResultsFolder/CIFTI_STRUCTURE_PALLIDUM_LEFT -add $ResultsFolder/CIFTI_STRUCTURE_PUTAMEN_LEFT -add $ResultsFolder/CIFTI_STRUCTURE_THALAMUS_LEFT $ResultsFolder/LRsurfvols
    ${FSLDIR}/bin/distancemap -m ${StdRef} -i ${ResultsFolder}/LRsurfvols -o ${ResultsFolder}/dist.nii.gz
    ${FSLDIR}/bin/fslmaths ${ResultsFolder}/dist.nii.gz -uthr $DistanceThreshold -bin -mul $ROIsFolder/Whole_Brain_Trajectory_ROI_2 ${ResultsFolder}/Mat2_target
    ${FSLDIR}/bin/imrm ?surf_pial
    ${FSLDIR}/bin/imrm LRsurfvols
######...Finished creating mask
fi

#Downsample Target mask
if [ "$DownsampleMat2Target" == "1" ]; then   
    $FSLDIR/bin/immv ${ResultsFolder}/Mat2_target ${ResultsFolder}/Mat2_target_orig
    $FSLDIR/bin/flirt -in ${ResultsFolder}/Mat2_target_orig -ref $StdRef -out $ResultsFolder/Mat2_target -applyisoxfm 3 -interp nearestneighbour
fi

o=" $o --stop=$ResultsFolder/stop"
o=" $o --omatrix2 --target2=$ResultsFolder/Mat2_target"

rm -rf $ResultsFolder/commands_Mat2.txt
rm -rf $ResultsFolder/Mat2_logs
#rm -rf $ResultsFolder/Mat2_track_????
mkdir -p $ResultsFolder/Mat2_logs
rm -f  $ResultsFolder/Mat2_list.txt

for ((n=1;n<=${Nrepeats};n++)); do
    trackdir=$ResultsFolder/Mat2_track_`zeropad $n 4`
    out=" --dir=$trackdir"
    echo $bindir/probtrackx2 $generic_options $o $out --rseed=$n >> $ResultsFolder/commands_Mat2.txt
    echo $trackdir/fdt_matrix2.dot >> $ResultsFolder/Mat2_list.txt
done

#Do Tractography
#With downsampled Target to 3mm, no stripping
#N10: 22 minutes, 3.5 GB RAM
#N50: 1:54 h, 3.5 GB RAM
#N100: 3:49 h, 4.2 GB RAM, 1.8 GB on disk
#With downsampled Target to 3mm, 4mm Distance stripping
#N100: 3:45 h, 3.9 GB RAM, 1.2 GB on disk
echo "Queueing Probtrackx" 
ptx_id=`fsl_sub -T 420 -R 8000 -l $ResultsFolder/Mat2_logs -N ptx2_Mat2 -t $ResultsFolder/commands_Mat2.txt`

#Merge Results from invidual Runs (4 hours, 15 GB) (2.5 hours, 10 GB with stripped target mask)
ptx_merged_id=`fsl_sub -T 420 -R 25000 -j ${ptx_id} -l $ResultsFolder/Mat2_logs -N Mat2_merge $bindir/fdt_matrix_merge $ResultsFolder/Mat2_list.txt $ResultsFolder/merged_matrix2.dot`

#Perform Mat2 squaring on the GPU (~4 hours, <2.5 hours for stripped target)
${scriptsdir}/CreateMat2GPUSub.sh $ResultsFolder #Create submission script to the GPU queue
gpu_id=`qsub $ResultsFolder/Mat2GPUSub.sh -W depend=afterok:${ptx_merged_id} -o $ResultsFolder/Mat2_logs/Mat2GPU.o -e $ResultsFolder/Mat2_logs/Mat2GPU.e`

#(~60 minutes, ~32 GB)
fsl_sub -T 240 -R 40000 -j ${gpu_id} -l $ResultsFolder/Mat2_logs -N Mat2_conn $scriptsdir/PostProcMatrix2.sh $StudyFolder $Subject $TemplateFolder $Nrepeats