#!/bin/bash
set -e

# Tractography Pipeline for creating Matrix1-based full connectomes. Assumes a CPU cluster and submits to the queue.
# Stamatios Sotiropoulos, Saad Jbabdi, Analysis Group, FMRIB Centre, 2013.


if [ "$2" == "" ];then
    echo ""
    echo "usage: $0 <StudyFolder> <Subject>"
    echo ""
    exit 1
fi

StudyFolder=$1          # "$1" #Path to Generic Study folder
Subject=$2              # "$2" #SubjectID

bindir=/home/stam/fsldev/ptx2  #Eventually FSLDIR (use custom probtrackx2 and fdt_matrix_merge for now)
scriptsdir=${HCPPIPEDIR_dMRITract}
TemplateFolder="${HCPPIPEDIR_Template}/91282_Greyordinates"

# Hard-coded variables for now
Nsamples=100
Nrepeats=100

ResultsFolder="$StudyFolder"/"$Subject"/MNINonLinear/Results/Tractography
BedpostxFolder="$StudyFolder"/"$Subject"/T1w/Diffusion.bedpostX
RegFolder="$StudyFolder"/"$Subject"/MNINonLinear/xfms
ROIsFolder="$StudyFolder"/"$Subject"/MNINonLinear/ROIs
if [ ! -e ${ResultsFolder} ] ; then
  mkdir ${ResultsFolder}
fi

#Use BedpostX samples
BedpostxFolder="${StudyFolder}"/"${Subject}"/T1w/Diffusion.bedpostX
DtiMask=${BedpostxFolder}/nodif_brain_mask
#Or RubiX samples
#BedpostxFolder="$StudyFolder"/"$Subject"/T1w/Diffusion.rubiX
#DtiMask=$BedpostxFolder/HRbrain_mask


#Temporarily here, should be in Prepare_Seeds
rm -rf $ResultsFolder/stop
rm -rf $ResultsFolder/volseeds
rm -rf $ResultsFolder/Mat1_seeds

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

echo $ResultsFolder/white.L.asc >> $ResultsFolder/Mat1_seeds
echo $ResultsFolder/white.R.asc >> $ResultsFolder/Mat1_seeds
cat $ResultsFolder/volseeds >> $ResultsFolder/Mat1_seeds

#Define Generic Options
generic_options=" --loopcheck --forcedir --fibthresh=0.01 -c 0.2 --sampvox=2 --randfib=1 -P ${Nsamples} -S 2000 --steplength=0.5"
o=" -s ${BedpostxFolder}/merged -m ${DtiMask} --meshspace=caret"

#Define Seed
Seed="$ResultsFolder/Mat1_seeds"
StdRef=$FSLDIR/data/standard/MNI152_T1_2mm_brain_mask
o=" $o -x ${Seed} --seedref=${StdRef}"
o=" $o --xfm=`echo ${RegFolder}/standard2acpc_dc` --invxfm=`echo ${RegFolder}/acpc_dc2standard`"

#Define Targets
o=" $o --stop=${ResultsFolder}/stop"
o=" $o --omatrix1"

rm -rf $ResultsFolder/commands_Mat1.txt
rm -rf $ResultsFolder/Mat1_logs
#rm -rf $ResultsFolder/Mat1_track_????
mkdir -p $ResultsFolder/Mat1_logs
rm -f  $ResultsFolder/Mat1_list.txt

for ((n=1;n<=${Nrepeats};n++)); do
    trackdir=${ResultsFolder}/Mat1_track_`zeropad $n 4`
    out=" --dir=$trackdir"
    echo ${bindir}/probtrackx2 ${generic_options} $o $out --rseed=$n >> $ResultsFolder/commands_Mat1.txt
    echo ${trackdir}/fdt_matrix1.dot >> $ResultsFolder/Mat1_list.txt
done

#Do Tractography
#N100: ~4h, 4GB RAM, 1.2 GB on disk
echo "Queueing Probtrackx" 
ptx_id=`${FSLDIR}/bin/fsl_sub -T 480 -R 6000 -l ${ResultsFolder}/Mat1_logs -N ptx2_Mat1 -t ${ResultsFolder}/commands_Mat1.txt`

#Merge Results from invidual Runs (~7 hours, 20 GB RAM)
ptx_merged_id=`${FSLDIR}/bin/fsl_sub -T 720 -R 30000 -j ${ptx_id} -l ${ResultsFolder}/Mat1_logs -N Mat1_merge ${bindir}/fdt_matrix_merge ${ResultsFolder}/Mat1_list.txt ${ResultsFolder}/merged_matrix1.dot`

#Create CIFTI file=Mat1+Mat1_transp (1.5 hours, 36 GB)
${FSLDIR}/bin/fsl_sub -T 180 -R 45000 -j ${ptx_merged_id} -l ${ResultsFolder}/Mat1_logs -N Mat1_conn ${scriptsdir}/PostProcMatrix1.sh ${StudyFolder} ${Subject} ${TemplateFolder} ${Nrepeats}