#!/bin/bash
set -e
echo -e "\n START: PostProcMatrix1"

Caret7_command=${CARET7DIR}/wb_command

if [ "$4" == "" ];then
    echo ""
    echo "usage: $0 <StudyFolder> <Subject> <GrayOrdinates_Templatedir> <Nrepeats>"
    echo "Converts the merged.dot file to .dconn.nii"
    exit 1
fi

StudyFolder=$1          # "$1" #Path to Generic Study folder
Subject=$2              # "$2" #SubjectID
TemplateFolder=$3
Nrepeats=$4             # How many dot files existed

ResultsFolder="${StudyFolder}"/"${Subject}"/MNINonLinear/Results/Tractography

#Save files before deleting 
if [ -s  $ResultsFolder/merged_matrix1.dot ]; then
    cp  $ResultsFolder/Mat1_track_0001/coords_for_fdt_matrix1 $ResultsFolder/coords_for_fdt_matrix1
   
    rm -f $ResultsFolder/Mat1_waytotal
    rm -f $ResultsFolder/Mat1_waytotal_list
    waytotal=0
    for ((i=1;i<=${Nrepeats};i++));do
	n=`zeropad $i 4`
	wayp=`cat $ResultsFolder/Mat1_track_${n}/waytotal`
	echo ${wayp} >> $ResultsFolder/Mat1_waytotal_list
	waytotal=$((${waytotal} + ${wayp}))
    done
    echo ${waytotal} >> $ResultsFolder/Mat1_waytotal
    
    rm -rf ${ResultsFolder}/Mat1_track_????
fi

${Caret7_command} -probtrackx-dot-convert ${ResultsFolder}/merged_matrix1.dot ${ResultsFolder}/Mat1.dconn.nii -row-cifti ${TemplateFolder}/91282_Greyordinates.dscalar.nii COLUMN -col-cifti ${TemplateFolder}/91282_Greyordinates.dscalar.nii COLUMN
${Caret7_command} -cifti-transpose ${ResultsFolder}/Mat1.dconn.nii ${ResultsFolder}/Mat1_transp.dconn.nii
${Caret7_command} -cifti-average ${ResultsFolder}/Conn1.dconn.nii -cifti ${ResultsFolder}/Mat1.dconn.nii -cifti ${ResultsFolder}/Mat1_transp.dconn.nii
#Do we need to multiply by 2? Keep the average, so that the numbers are consistent with waytotal
if [ -s  $ResultsFolder/Conn1.dconn.nii ]; then
    rm -f ${ResultsFolder}/Mat1.dconn.nii
    rm -f ${ResultsFolder}/Mat1_transp.dconn.nii
    rm -f ${ResultsFolder}/merged_matrix1.dot
fi  

gzip $ResultsFolder/Conn1.dconn.nii --fast

echo -e "\n END: PostProcMatrix1"
