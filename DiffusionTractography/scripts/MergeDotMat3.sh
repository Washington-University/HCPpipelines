#!/bin/bash
set -e
echo -e "\n START: MergeDotMat3"

bindir=/home/stam/fsldev/ptx2 #Eventually FSLDIR (use custom probtrackx2 and fdt_matrix_merge for now)
Caret7_command=${CARET7DIR}/wb_command

if [ "$5" == "" ];then
    echo ""
    echo "usage: $0 <StudyFolder> <Subject> <count> <GrayOrdinates_Templatedir> <Nrepeats>"
    echo "Merge dot files and convert the merged.dot file to .dconn.nii"
    exit 1
fi

StudyFolder=$1          # "$1" #Path to Generic Study folder
Subject=$2              # "$2" #SubjectID
count=$3                # Which Part of Matrix3 to process (1 for LH to All, 2 for RH to All, 3 for Subxortex to All) 
TemplateFolder=$4
Nrepeats=$5             # How many dot files to merge

ResultsFolder="$StudyFolder"/"$Subject"/MNINonLinear/Results/Tractography

#Merge results from individual probtrackx runs 
$bindir/fdt_matrix_merge $ResultsFolder/Mat3_${count}_list.txt $ResultsFolder/merged_matrix3_${count}.dot

#Save files before deleting 
if [ -f  $ResultsFolder/merged_matrix3_${count}.dot ]; then
    imcp $ResultsFolder/Mat3_track_${count}_0001/tract_space_coords_for_fdt_matrix3 $ResultsFolder/tract_space_coords_for_fdt_matrix3_${count}
    cp  $ResultsFolder/Mat3_track_${count}_0001/coords_for_fdt_matrix3 $ResultsFolder/coords_for_fdt_matrix3_${count}
   
    rm -f $ResultsFolder/Mat3_waytotal_${count}
    rm -f $ResultsFolder/Mat3_waytotal_list_${count}
    waytotal=0
    for ((i=1;i<=${Nrepeats};i++));do
	n=`zeropad $i 4`
	wayp=`cat $ResultsFolder/Mat3_track_${count}_${n}/waytotal`
	echo ${wayp} >> $ResultsFolder/Mat3_waytotal_list_${count}
	waytotal=$((${waytotal} + ${wayp}))
    done
    echo ${waytotal} >> $ResultsFolder/Mat3_waytotal_${count}
    
    rm -rf ${ResultsFolder}/Mat3_track_${count}_????
fi

#Each of the next three wb_commands take for count=1/2
# i)13 minutes and 13 GB of RAM 
# ii) 4 minutes and 11 GB of RAM 
# iii) 2 minutes and 1 GB of RAM 
# And for count=3
# i) 21 minutes and 26GB  of RAM 
# ii) 4 minutes and 12GB of RAM 
# iii) 2 minutes and 1GB of RAM 

if [ ${count} -eq 1 ]; then
    ${Caret7_command} -probtrackx-dot-convert ${ResultsFolder}/merged_matrix3_${count}.dot ${ResultsFolder}/merged_matrix3_${count}.dconn.nii -row-cifti ${TemplateFolder}/91282_Greyordinates.dscalar.nii COLUMN -col-surface ${TemplateFolder}/L.atlasroi.32k_fs_LR.shape.gii
elif [ ${count} -eq 2 ]; then
    ${Caret7_command} -probtrackx-dot-convert ${ResultsFolder}/merged_matrix3_${count}.dot ${ResultsFolder}/merged_matrix3_${count}.dconn.nii -row-cifti ${TemplateFolder}/91282_Greyordinates.dscalar.nii COLUMN -col-surface ${TemplateFolder}/R.atlasroi.32k_fs_LR.shape.gii
elif [ ${count} -eq 3 ]; then
    ${Caret7_command} -probtrackx-dot-convert ${ResultsFolder}/merged_matrix3_${count}.dot ${ResultsFolder}/merged_matrix3_${count}.dconn.nii -row-cifti ${TemplateFolder}/91282_Greyordinates.dscalar.nii COLUMN -col-voxels ${TemplateFolder}/Atlas_ROIs.2.voxel_list.txt ${TemplateFolder}/Atlas_ROIs.2.nii.gz
fi

if [ -s ${ResultsFolder}/merged_matrix3_${count}.dconn.nii ]; then 
    rm -f ${ResultsFolder}/merged_matrix3_${count}.dot	
fi


echo -e "\n END: MergeDotMat3"
