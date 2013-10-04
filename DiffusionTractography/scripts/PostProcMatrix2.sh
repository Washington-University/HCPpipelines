#!/bin/bash
set -e
echo -e "\n START: PostProcMatrix2"

Caret7_command=${CARET7DIR}/wb_command

if [ "$4" == "" ];then
    echo ""
    echo "usage: $0 <StudyFolder> <Subject> <GrayOrdinates_Templatedir> <Nrepeats>"
    echo "Convert the merged.dot file to .dconn.nii"
    exit 1
fi

StudyFolder=$1          # "$1" #Path to Generic Study folder
Subject=$2              # "$2" #SubjectID
TemplateFolder=$3
Nrepeats=$4             # How many dot files existed

ResultsFolder="$StudyFolder"/"$Subject"/MNINonLinear/Results/Tractography

#Save files before deleting 
if [ -s  $ResultsFolder/merged_matrix2.dot ]; then
    cp $ResultsFolder/Mat2_track_0001/tract_space_coords_for_fdt_matrix2 $ResultsFolder/tract_space_coords_for_fdt_matrix2
    cp  $ResultsFolder/Mat2_track_0001/coords_for_fdt_matrix2 $ResultsFolder/coords_for_fdt_matrix2
    imcp $ResultsFolder/Mat2_track_0001/lookup_tractspace_fdt_matrix2 $ResultsFolder/lookup_tractspace_fdt_matrix2

    rm -f $ResultsFolder/Mat2_waytotal
    rm -f $ResultsFolder/Mat2_waytotal_list
    waytotal=0
    for ((i=1;i<=${Nrepeats};i++));do
	n=`zeropad $i 4`
	wayp=`cat $ResultsFolder/Mat2_track_${n}/waytotal`
	echo ${wayp} >> $ResultsFolder/Mat2_waytotal_list
	waytotal=$((${waytotal} + ${wayp}))
    done
    echo ${waytotal} >> $ResultsFolder/Mat2_waytotal
    
    rm -rf ${ResultsFolder}/Mat2_track_????
fi

#33 GB of memory, ~15 minutes. Generate a template.dconn cifti file
${Caret7_command} -cifti-correlation ${TemplateFolder}/91282_Greyordinates.dscalar.nii ${ResultsFolder}/template.dconn.nii 
${Caret7_command} -cifti-convert -to-gifti-ext ${ResultsFolder}/template.dconn.nii ${ResultsFolder}/template.dconn.gii

${Caret7_command} -cifti-convert -from-gifti-ext ${ResultsFolder}/template.dconn.gii ${ResultsFolder}/Conn2.dconn.nii -replace-binary ${ResultsFolder}/Conn2.data -transpose
if [ -s  $ResultsFolder/Conn2.dconn.nii ]; then
    rm -f ${ResultsFolder}/Conn2.data
    rm -f ${ResultsFolder}/merged_matrix2.dot
    rm -f ${ResultsFolder}/template.dconn.*
fi  

gzip $ResultsFolder/Conn2.dconn.nii --fast

echo -e "\n END: PostProcMatrix2"
