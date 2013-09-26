#!/bin/bash

StudyFolder="$1"
Subject="$2"
DownSampleNameI="$3"
DiffusionResolution="$4"
Caret7_Command="$5"
HemisphereSTRING="$6" #L@R or L or R or Whole
MatrixNumber="$7"
PD="$8"
StepSize="$9"


#NamingConventions
T1wFolder="T1w"
BedpostXFolder="Diffusion.bedpostX"
NativeFolder="Native"
DownSampleFolder="fsaverage_LR${DownSampleNameI}k"
ROIsFolder="ROIs"
ResultsFolder="Results"

HemisphereSTRING=`echo "$HemisphereSTRING" | sed 's/@/ /g'`

#PD
if [ $PD = "YES" ] ; then
  PDDir="_pd"
else
  PDDir=""
fi

#Make Paths
T1wFolder="${StudyFolder}/${Subject}/${T1wFolder}"
BedpostXFolder="${T1wFolder}/${BedpostXFolder}"
NativeFolder="${T1wFolder}/${NativeFolder}"
DownSampleFolder="${T1wFolder}/${DownSampleFolder}"
ROIsFolder="${T1wFolder}/${ROIsFolder}"
ResultsFolder="${T1wFolder}/${ResultsFolder}"

if [ ! $HemisphereSTRING = "Whole" ] ; then
  for Hemisphere in $HemisphereSTRING ; do
    if [ $Hemisphere = "L" ] ; then
      metrichemisphere="-left-metric"
    elif [ $Hemisphere = "R" ] ; then
      metrichemisphere="-right-metric"
    fi
    if [ $MatrixNumber = "1" ] ; then
      MakeSymmetric=""
    elif [ $MatrixNumber = "3" ] ; then
      MakeSymmetric="-make-symmetric"
    fi
    Dir="${ResultsFolder}/${Hemisphere}_Trajectory_Matrix${MatrixNumber}${PDDir}_${StepSize}"
    trajectory="${Hemisphere}_Cerebral_Trajectory"
    $Caret7_Command -probtrackx-dot-convert ${Dir}/fdt_matrix${MatrixNumber}.dot ${Dir}/fdt_matrix"$MatrixNumber".dconn.nii -row-surface ${Dir}/SeedSpaceMetric.func.gii -col-surface ${Dir}/SeedSpaceMetric.func.gii -transpose ${MakeSymmetric}
    $Caret7_Command -convert-matrix4-to-workbench-sparse ${Dir}/fdt_matrix4_1.mtx ${Dir}/fdt_matrix4_2.mtx ${Dir}/fdt_matrix4_3.mtx ${BedpostXFolder}/Whole_Brain_Trajectory_${DiffusionResolution}.fiberTEMP.nii ${Dir}/tract_space_coords_for_fdt_matrix4 -surface-seeds ${Dir}/SeedSpaceMetric.func.gii ${Dir}/fdt_matrix4.trajTEMP.wbsparse
    $Caret7_Command -convert-matrix4-to-matrix2 ${Dir}/fdt_matrix4.trajTEMP.wbsparse ${Dir}/fdt_matrix2.dconn.nii
  done
else
  ###Whole NOT YET IMPLEMENTED### 
  echo "1+1=2" > /dev/null
fi

