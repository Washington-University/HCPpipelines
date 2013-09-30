#!/bin/bash


# Tractography Pipeline for creating Matrix3-based full connectomes. Assumes a CPU cluster and submits to the queue.
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
Nsamples=25
Nrepeats=40

ResultsFolder="$StudyFolder"/"$Subject"/MNINonLinear/Results/Tractography
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

#Define Generic Options
generic_options=" --loopcheck --forcedir --fibthresh=0.01 -c 0.2 --sampvox=2 --randfib=1 -P ${Nsamples} -S 2000 --steplength=0.5"
oG=" -s $BedpostxFolder/merged -m $DtiMask --meshspace=caret"

#Define Seed
Seed=$ROIsFolder/Whole_Brain_Trajectory_ROI_2
StdRef=$FSLDIR/data/standard/MNI152_T1_2mm_brain_mask
oG=" $oG -x $Seed --seedref=$StdRef"
oG=" $oG --xfm=`echo $RegFolder/standard2acpc_dc` --invxfm=`echo $RegFolder/acpc_dc2standard`"

#Define Targets
oG=" $oG --stop=$ResultsFolder/stop"  #Rethink stop mask, should we include an exclusion along the midsagittal plane (without the CC and the commisures).
Targets="$ResultsFolder/white.L.asc $ResultsFolder/white.R.asc $ResultsFolder/volseeds" 
Target_Mat4="$StudyFolder"/"$Subject"/T1w/Whole_Brain_Trajectory_1.25 #In diffusion space



########### Run Mat3 in 3 blocks ###################
########### Left Hemisphere to ALL #################
########### Right Hemisphere to ALL ################
########### Subcortex Hemisphere to ALL ############
rm -f $ResultsFolder/commands_Mat3*.txt
rm -f $ResultsFolder/Mat3_targets
rm -rf $ResultsFolder/Mat3_logs
#rm -rf $ResultsFolder/Mat3_track_?_????

echo $ResultsFolder/white.L.asc >> $ResultsFolder/Mat3_targets
echo $ResultsFolder/white.R.asc >> $ResultsFolder/Mat3_targets
cat $ResultsFolder/volseeds >> $ResultsFolder/Mat3_targets
mkdir -p $ResultsFolder/Mat3_logs
count=1
for i in $Targets 
do
    if [ ! -s $ResultsFolder/merged_matrix3_${count}_trans.dscalar.nii ]; then
	o=" $oG --omatrix3 --target3=$ResultsFolder/Mat3_targets --lrtarget3=$i"
	rm -f  $ResultsFolder/Mat3_${count}_list.txt
	for ((n=1;n<=${Nrepeats};n++)); do
	    trackdir=$ResultsFolder/Mat3_track_"${count}"_`zeropad $n 4`
	    out=" --dir=$trackdir"
	    if [ ! -s $trackdir/fdt_matrix3.dot ]; then #if already processed, do not process again
		echo $bindir/probtrackx2 $generic_options $o $out --rseed=$n >> $ResultsFolder/commands_Mat3_${count}.txt
	    fi
	    echo $trackdir/fdt_matrix3.dot >> $ResultsFolder/Mat3_${count}_list.txt
	done
	echo "Queueing Probtrackx Part${count}" 
	ptx2_id=`fsl_sub -T 720 -R 12000 -l $ResultsFolder/Mat3_logs -N ptx2_Mat3 -t $ResultsFolder/commands_Mat3_${count}.txt`
	ptx2_post_id=`fsl_sub -T 720 -R 40000 -j ${ptx2_id} -l $ResultsFolder/Mat3_logs -N Mat3_merge $scriptsdir/MergeDotMat3.sh $StudyFolder $Subject $count $TemplateFolder $Nrepeats`
    fi
    count=$(($count + 1))
done

#The following dependency assumes that merging of Mat3_3 will be the last to complete and that Mat3_1 and Mat3_2 merging will have finished by now. It will fail if that is not true
#To do this correctly ptx2_post_id should be joined in an array. Qsub can do that but not fsl_sub.
fsl_sub -T 180 -R 35000 -j ${ptx2_post_id} -l $ResultsFolder/Mat3_logs -N Mat3_conn $scriptsdir/PostProcMatrix3.sh $StudyFolder $Subject
