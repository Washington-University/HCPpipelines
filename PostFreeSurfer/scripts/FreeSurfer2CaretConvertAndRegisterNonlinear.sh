#!/bin/bash
set -e
echo -e "\n START: FS2CaretConvertRegisterNonlinear"

StudyFolder="$1"
Subject="$2"
T1wFolder="$3"
AtlasSpaceFolder="$4"
NativeFolder="$5"
FreeSurferFolder="$6"
FreeSurferInput="$7"
FinalTemplateSpace="$8"
T1wImage="$9"
T2wImage="${10}"
CaretAtlasSpaceFolder="${11}"
DownSampleI="${12}"
DownSampleNameI="${13}"
Caret5_Command="${14}"
Caret7_Command="${15}"
AtlasTransform="${16}"
InverseAtlasTransform="${17}"
AtlasSpaceT1wImage="${18}"
AtlasSpaceT2wImage="${19}"
T1wImageBrainMask="${20}"
PipelineScripts="${21}"
GlobalScripts="${22}"

Species="Human"

#Make some folders for this and later scripts
if [ ! -e "$T1wFolder"/"$NativeFolder" ] ; then
  mkdir -p "$T1wFolder"/"$NativeFolder"
fi
if [ ! -e "$AtlasSpaceFolder"/ROIs ] ; then
  mkdir -p "$AtlasSpaceFolder"/ROIs
fi
if [ ! -e "$AtlasSpaceFolder"/Results ] ; then
  mkdir "$AtlasSpaceFolder"/Results
fi
if [ ! -e "$AtlasSpaceFolder"/"$NativeFolder" ] ; then
  mkdir "$AtlasSpaceFolder"/"$NativeFolder"
fi
if [ ! -e "$AtlasSpaceFolder"/fsaverage ] ; then
  mkdir "$AtlasSpaceFolder"/fsaverage
fi
if [ ! -e "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k ] ; then
  mkdir "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k
fi


#Find c_ras offset between FreeSurfer surface and volume and generate matrix to transform surfaces
MatrixX=`mri_info "$FreeSurferFolder"/mri/brain.finalsurfs.mgz | grep "c_r" | cut -d "=" -f 5 | sed s/" "/""/g`
MatrixY=`mri_info "$FreeSurferFolder"/mri/brain.finalsurfs.mgz | grep "c_a" | cut -d "=" -f 5 | sed s/" "/""/g`
MatrixZ=`mri_info "$FreeSurferFolder"/mri/brain.finalsurfs.mgz | grep "c_s" | cut -d "=" -f 5 | sed s/" "/""/g`
Matrix1=`echo "1 0 0 ""$MatrixX"`
Matrix2=`echo "0 1 0 ""$MatrixY"`
Matrix3=`echo "0 0 1 ""$MatrixZ"`
Matrix4=`echo "0 0 0 1"`
Matrix=`echo "$Matrix1"" ""$Matrix2"" ""$Matrix3"" ""$Matrix4"`
echo $Matrix

#Create FreeSurfer Brain Mask
mri_convert -rt nearest -rl "$T1wFolder"/"$T1wImage".nii.gz "$FreeSurferFolder"/mri/wmparc.mgz "$T1wFolder"/wmparc_1mm.nii.gz
applywarp --interp=nn -i "$T1wFolder"/wmparc_1mm.nii.gz -r "$FinalTemplateSpace" --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$T1wFolder"/wmparc.nii.gz
applywarp --interp=nn -i "$T1wFolder"/wmparc_1mm.nii.gz -r "$FinalTemplateSpace" -w "$AtlasTransform" -o "$AtlasSpaceFolder"/wmparc.nii.gz
fslmaths "$T1wFolder"/wmparc_1mm.nii.gz -bin -dilD -dilD -dilD -ero -ero -mul 255 "$T1wFolder"/"$T1wImageBrainMask"_1mm.nii.gz
$Caret5_Command -volume-fill-holes "$T1wFolder"/"$T1wImageBrainMask"_1mm.nii.gz "$T1wFolder"/"$T1wImageBrainMask"_1mm.nii.gz
fslmaths "$T1wFolder"/"$T1wImageBrainMask"_1mm.nii.gz -bin "$T1wFolder"/"$T1wImageBrainMask"_1mm.nii.gz
applywarp --interp=nn -i "$T1wFolder"/"$T1wImageBrainMask"_1mm.nii.gz -r "$FinalTemplateSpace" --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$T1wFolder"/"$T1wImageBrainMask".nii.gz
applywarp --interp=nn -i "$T1wFolder"/"$T1wImageBrainMask"_1mm.nii.gz -r "$FinalTemplateSpace" -w "$AtlasTransform" -o "$AtlasSpaceFolder"/"$T1wImageBrainMask".nii.gz


#Loop through left and right hemispheres
for Hemisphere in L R ; do
  #Set a bunch of different ways of saying left and right
  if [ $Hemisphere = "L" ] ; then 
    hemisphere="l"
    HEMISPHERE="LEFT"
    hemispherew="left"
    Structure="CORTEX_LEFT"
  elif [ $Hemisphere = "R" ] ; then 
    hemisphere="r"
    hemispherew="right"
    HEMISPHERE="RIGHT"
    Structure="CORTEX_RIGHT"
  fi
  
  #native Mesh Processing
  #Make caret5 spec files for linear and nonlinearly transformed datasets (in MNI space)
  DIR=`pwd`
  cd "$T1wFolder"/"$NativeFolder"
    $Caret5_Command -spec-file-create $Species $Subject $hemispherew OTHER -category Individual -spec-file-name "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.c5.spec
  cd $DIR
  cd "$AtlasSpaceFolder"/"$NativeFolder"
    $Caret5_Command -spec-file-create $Species $Subject $hemispherew OTHER -category Individual -spec-file-name "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.c5.spec
  cd $DIR
  #Convert and volumetrically register white and pial surfaces makign linear and nonlinear copies, add each to the appropriate spec file
  for Surface in pial white ; do
    $Caret5_Command -file-convert -sc -is FSS "$FreeSurferFolder"/surf/"$hemisphere"h."$Surface" -os CARET "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Surface".native.coord.gii "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.topo.gii FIDUCIAL CLOSED -struct $hemispherew
    $Caret5_Command -surface-apply-transformation-matrix "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Surface".native.coord.gii "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.topo.gii "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Surface".native.coord.gii -matrix $Matrix
    $Caret5_Command -spec-file-add "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.c5.spec FIDUCIALcoord_file "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Surface".native.coord.gii
    "$GlobalScripts"/NonlinearSurfaceWarpHackGeneric.sh "$StudyFolder"/"$Subject" "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Surface".native.coord.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Surface".native.coord.gii "$T1wFolder"/"$T1wImage".nii.gz "$FinalTemplateSpace" "$InverseAtlasTransform" "$GlobalScripts" "$Caret5_Command"
    $Caret5_Command -spec-file-add "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.c5.spec FIDUCIALcoord_file "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Surface".native.coord.gii
  done
  #Add some other files to linear spec file and create linear midthickness surface by averaging white and pial surfaces
  $Caret5_Command -spec-file-add "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.c5.spec volume_anatomy_file "$T1wFolder"/"$T2wImage".nii.gz
  $Caret5_Command -spec-file-add "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.c5.spec volume_anatomy_file "$T1wFolder"/"$T1wImage".nii.gz
  $Caret7_Command -add-to-spec-file "$T1wFolder"/"$NativeFolder"/"$Subject".native.wb.spec INVALID "$T1wFolder"/"$T2wImage".nii.gz
  $Caret7_Command -add-to-spec-file "$T1wFolder"/"$NativeFolder"/"$Subject".native.wb.spec INVALID "$T1wFolder"/"$T1wImage".nii.gz
  $Caret5_Command -spec-file-add "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.c5.spec CLOSEDtopo_file "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.topo.gii
  $Caret5_Command -surface-average "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".midthickness.native.coord.gii "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial.native.coord.gii "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white.native.coord.gii
  $Caret5_Command -spec-file-add "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.c5.spec FIDUCIALcoord_file "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".midthickness.native.coord.gii
  $Caret5_Command -surface-generate-inflated "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".midthickness.native.coord.gii "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.topo.gii -iterations-scale 2.5 -generate-inflated -generate-very-inflated -output-spec "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.c5.spec -output-inflated-file-name "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".inflated.native.coord.gii -output-very-inflated-file-name "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".very_inflated.native.coord.gii
  Types="VERY_INFLATED ANATOMICAL@MIDTHICKNESS ANATOMICAL@GRAY_WHITE ANATOMICAL@PIAL INFLATED"
  i=1
  for Surface in very_inflated midthickness white pial inflated ; do
    Type=`echo "$Types" | cut -d " " -f $i`
    Secondary=`echo "$Type" | cut -d "@" -f 2`
    Type=`echo "$Type" | cut -d "@" -f 1`
    if [ ! $Secondary = $Type ] ; then
      Secondary=`echo " -surface-secondary-type ""$Secondary"`
    else
      Secondary=""
    fi
    $Caret5_Command -file-convert -sc -is CARET "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Surface".native.coord.gii "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.topo.gii -os GS "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Surface".native.surf.gii
    $Caret7_Command -set-structure "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Surface".native.surf.gii $Structure -surface-type $Type$Secondary
    $Caret7_Command -add-to-spec-file "$T1wFolder"/"$NativeFolder"/"$Subject".native.wb.spec $Structure "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Surface".native.surf.gii
    i=$(($i+1))
  done
  
  #Convert original and registered spherical surfaces, make sure they are centered on 0,0,0 and add them to the nonlinear spec file
  for Surface in sphere.reg sphere ; do
    $Caret5_Command -file-convert -sc -is FSS "$FreeSurferFolder"/surf/"$hemisphere"h."$Surface" -os CARET "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Surface".native.coord.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.topo.gii SPHERICAL CLOSED -struct $hemispherew
    $Caret5_Command -surface-sphere "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Surface".native.coord.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.topo.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Surface".native.coord.gii
    $Caret5_Command -spec-file-add "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.c5.spec SPHERICALcoord_file "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Surface".native.coord.gii
    $Caret5_Command -file-convert -sc -is CARET "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Surface".native.coord.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.topo.gii -os GS "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Surface".native.surf.gii
    $Caret7_Command -set-structure "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Surface".native.surf.gii $Structure -surface-type SPHERICAL
  done
  
  #Make FreeSurfer Registration Areal Distortion Maps
  if [ -e "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".ArealDistortion.native.shape.gii ] ; then
    rm "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".ArealDistortion.native.shape.gii
  fi
  $Caret5_Command -surface-distortion "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".sphere.native.surf.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".sphere.reg.native.coord.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.topo.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".ArealDistortion.native.shape.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".ArealDistortion.native.shape.gii -generate-areal-distortion
  $Caret5_Command -metric-set-column-name "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".ArealDistortion.native.shape.gii 1 "$Subject"_"$Hemisphere"_Areal_Distortion
  $Caret7_Command -set-structure "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".ArealDistortion.native.shape.gii $Structure
  $Caret7_Command -metric-palette "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".ArealDistortion.native.shape.gii MODE_AUTO_SCALE -palette-name ROY-BIG-BL -thresholding THRESHOLD_TYPE_NORMAL THRESHOLD_TEST_SHOW_OUTSIDE -1 1
  
  #Add more files to the spec file and convert other FreeSurfer surface data to metric/GIFTI including sulc, curv, and thickness.
  $Caret5_Command -spec-file-add "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.c5.spec volume_anatomy_file "$AtlasSpaceFolder"/"$AtlasSpaceT2wImage".nii.gz
  $Caret5_Command -spec-file-add "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.c5.spec volume_anatomy_file "$AtlasSpaceFolder"/"$AtlasSpaceT1wImage".nii.gz
  $Caret5_Command -spec-file-add "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.c5.spec CLOSEDtopo_file "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.topo.gii
  $Caret5_Command -file-convert -fsc2c "$FreeSurferFolder"/surf/"$hemisphere"h.sulc "$FreeSurferFolder"/surf/"$hemisphere"h.white "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".sulc.native.shape.gii
  $Caret5_Command -spec-file-add "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.c5.spec surface_shape_file "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".sulc.native.shape.gii
  $Caret5_Command -metric-set-column-name "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".sulc.native.shape.gii 1 "$Subject"_"$Hemisphere"_Sulc
  $Caret7_Command -set-structure "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".sulc.native.shape.gii $Structure
  $Caret7_Command -add-to-spec-file "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject".native.wb.spec $Structure "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".sulc.native.shape.gii
  $Caret7_Command -metric-palette "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".sulc.native.shape.gii MODE_AUTO_SCALE_PERCENTAGE -pos-percent 2 98 -palette-name Gray_Interp -disp-pos true -disp-neg true -disp-zero true
  cp "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".sulc.native.shape.gii "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".sulc.native.shape.gii
  $Caret7_Command -add-to-spec-file "$T1wFolder"/"$NativeFolder"/"$Subject".native.wb.spec $Structure "$T1wFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".sulc.native.shape.gii
  $Caret5_Command -file-convert -fsc2c "$FreeSurferFolder"/surf/"$hemisphere"h.thickness "$FreeSurferFolder"/surf/"$hemisphere"h.white "$AtlasSpaceFolder"/"$NativeFolder"/temp.shape.gii
  $Caret5_Command -metric-math "$AtlasSpaceFolder"/"$NativeFolder"/temp.shape.gii "$AtlasSpaceFolder"/"$NativeFolder"/temp.shape.gii 1 "abs[@1@]"
  $Caret5_Command -metric-composite-identified-columns "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".thickness.native.shape.gii "$AtlasSpaceFolder"/"$NativeFolder"/temp.shape.gii 1; rm "$AtlasSpaceFolder"/"$NativeFolder"/temp.shape.gii
  $Caret5_Command -spec-file-add "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.c5.spec metric_file "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".thickness.native.shape.gii
  $Caret7_Command -set-structure "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".thickness.native.shape.gii $Structure
  $Caret7_Command -add-to-spec-file "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject".native.wb.spec $Structure "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".thickness.native.shape.gii
  $Caret5_Command -file-convert -fsc2c "$FreeSurferFolder"/surf/"$hemisphere"h.curv "$FreeSurferFolder"/surf/"$hemisphere"h.white "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".curvature.native.shape.gii
  $Caret5_Command -spec-file-add "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.c5.spec metric_file "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".curvature.native.shape.gii
  $Caret7_Command -set-structure "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".curvature.native.shape.gii $Structure
  $Caret7_Command -add-to-spec-file "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject".native.wb.spec $Structure "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".curvature.native.shape.gii

  mris_convert --annot "$FreeSurferFolder"/label/"$hemisphere"h.aparc.annot "$FreeSurferFolder"/surf/"$hemisphere"h.white "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".aparc.native.label.gii
  $Caret5_Command -spec-file-add "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.c5.spec paint_file "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".aparc.native.label.gii
  $Caret7_Command -set-structure "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".aparc.native.label.gii $Structure
  $Caret7_Command -add-to-spec-file "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject".native.wb.spec $Structure "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".aparc.native.label.gii
  mris_convert --annot "$FreeSurferFolder"/label/"$hemisphere"h.aparc.a2009s.annot "$FreeSurferFolder"/surf/"$hemisphere"h.white "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".aparc.a2009s.native.label.gii
  $Caret5_Command -spec-file-add "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.c5.spec paint_file "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".aparc.a2009s.native.label.gii
  $Caret7_Command -set-structure "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".aparc.a2009s.native.label.gii $Structure
  $Caret7_Command -add-to-spec-file "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject".native.wb.spec $Structure "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".aparc.a2009s.native.label.gii
  mris_convert --annot "$FreeSurferFolder"/label/"$hemisphere"h.BA.annot "$FreeSurferFolder"/surf/"$hemisphere"h.white "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".BA.native.label.gii
  $Caret5_Command -spec-file-add "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.c5.spec paint_file "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".BA.native.label.gii
  $Caret7_Command -set-structure "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".BA.native.label.gii $Structure
  $Caret7_Command -add-to-spec-file "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject".native.wb.spec $Structure "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".BA.native.label.gii

  #Create nonlinear midthickness surface, add to nonlinear spec file, and generate Caret style inflated surfaces
  $Caret5_Command -surface-average "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".midthickness.native.coord.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".pial.native.coord.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".white.native.coord.gii
  $Caret5_Command -spec-file-add "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.c5.spec FIDUCIALcoord_file "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".midthickness.native.coord.gii
  $Caret5_Command -surface-generate-inflated "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".midthickness.native.coord.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.topo.gii -iterations-scale 2.5 -generate-inflated -generate-very-inflated -output-spec "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.c5.spec -output-inflated-file-name "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".inflated.native.coord.gii -output-very-inflated-file-name "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".very_inflated.native.coord.gii
  Types="VERY_INFLATED ANATOMICAL@MIDTHICKNESS ANATOMICAL@GRAY_WHITE ANATOMICAL@PIAL INFLATED SPHERICAL"
  i=1
  for Surface in very_inflated midthickness white pial inflated sphere ; do
    Type=`echo "$Types" | cut -d " " -f $i`
    Secondary=`echo "$Type" | cut -d "@" -f 2`
    Type=`echo "$Type" | cut -d "@" -f 1`
    if [ ! $Secondary = $Type ] ; then
      Secondary=`echo " -surface-secondary-type ""$Secondary"`
    else
      Secondary=""
    fi
    $Caret5_Command -file-convert -sc -is CARET "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Surface".native.coord.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.topo.gii -os GS "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Surface".native.surf.gii
    $Caret7_Command -set-structure "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Surface".native.surf.gii $Structure -surface-type $Type$Secondary
    $Caret7_Command -add-to-spec-file "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject".native.wb.spec $Structure "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Surface".native.surf.gii
    i=$(($i+1))
  done
  $Caret7_Command -add-to-spec-file "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject".native.wb.spec INVALID "$AtlasSpaceFolder"/"$AtlasSpaceT2wImage".nii.gz
  $Caret7_Command -add-to-spec-file "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject".native.wb.spec INVALID "$AtlasSpaceFolder"/"$AtlasSpaceT1wImage".nii.gz

  #Copy fsaverage data to subject's folder, ensure spheres are properly centered
  cp "$CaretAtlasSpaceFolder"/fs_"$Hemisphere"/fsaverage."$Hemisphere".closed.164k_fs_"$Hemisphere".topo "$AtlasSpaceFolder"/fsaverage/"$Subject"."$Hemisphere".164k_fs_"$Hemisphere".topo.gii
  cp "$CaretAtlasSpaceFolder"/fs_"$Hemisphere"/fsaverage."$Hemisphere".sphere.164k_fs_"$Hemisphere".coord "$AtlasSpaceFolder"/fsaverage/"$Subject"."$Hemisphere".sphere.164k_fs_"$Hemisphere".coord.gii

  cp "$CaretAtlasSpaceFolder"/fs_"$Hemisphere"/fs_"$Hemisphere"-to-fs_LR_fsaverage."$Hemisphere"_LR.spherical_std.164k_fs_"$Hemisphere".coord "$AtlasSpaceFolder"/fsaverage/"$Subject"."$Hemisphere".def_sphere.164k_fs_"$Hemisphere".coord.gii
  $Caret5_Command -surface-sphere "$AtlasSpaceFolder"/fsaverage/"$Subject"."$Hemisphere".def_sphere.164k_fs_"$Hemisphere".coord.gii "$AtlasSpaceFolder"/fsaverage/"$Subject"."$Hemisphere".164k_fs_"$Hemisphere".topo.gii "$AtlasSpaceFolder"/fsaverage/"$Subject"."$Hemisphere".def_sphere.164k_fs_"$Hemisphere".coord.gii
  $Caret5_Command -surface-sphere "$AtlasSpaceFolder"/fsaverage/"$Subject"."$Hemisphere".sphere.164k_fs_"$Hemisphere".coord.gii "$AtlasSpaceFolder"/fsaverage/"$Subject"."$Hemisphere".164k_fs_"$Hemisphere".topo.gii "$AtlasSpaceFolder"/fsaverage/"$Subject"."$Hemisphere".sphere.164k_fs_"$Hemisphere".coord.gii

  #Copy fs_LR data to subject's folder, ensure spheres are properly centered
  cp "$CaretAtlasSpaceFolder"/fsaverage."$Hemisphere".closed.164k_fs_LR.topo "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".164k_fs_LR.topo.gii
  cp "$CaretAtlasSpaceFolder"/fsaverage."$Hemisphere"_LR.spherical_std.164k_fs_LR.coord "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".sphere.164k_fs_LR.coord.gii
  $Caret5_Command -surface-sphere "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".sphere.164k_fs_LR.coord.gii "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".164k_fs_LR.topo.gii "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".sphere.164k_fs_LR.coord.gii

  #Create native to fs_LR and inverse deformation maps by concatinating native to fs_L|R and fs_L|R to fs_LR registrations
  $Caret5_Command -surface-sphere-project-unproject "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".sphere.reg.native.coord.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.topo.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".sphere.reg.reg_LR.native.coord.gii "$AtlasSpaceFolder"/fsaverage/"$Subject"."$Hemisphere".sphere.164k_fs_"$Hemisphere".coord.gii "$AtlasSpaceFolder"/fsaverage/"$Subject"."$Hemisphere".def_sphere.164k_fs_"$Hemisphere".coord.gii "$AtlasSpaceFolder"/fsaverage/"$Subject"."$Hemisphere".164k_fs_"$Hemisphere".topo.gii
  $Caret5_Command -deformation-map-create SPHERE "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".sphere.reg.reg_LR.native.coord.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.topo.gii "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".sphere.164k_fs_LR.coord.gii "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".164k_fs_LR.topo.gii "$AtlasSpaceFolder"/native2164k_fs_LR."$Hemisphere".deform_map
  $Caret5_Command -deformation-map-create SPHERE "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".sphere.164k_fs_LR.coord.gii "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".164k_fs_LR.topo.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".sphere.reg.reg_LR.native.coord.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.topo.gii "$AtlasSpaceFolder"/164k_fs_LR2native."$Hemisphere".deform_map

  $Caret5_Command -deformation-map-path "$AtlasSpaceFolder"/native2164k_fs_LR."$Hemisphere".deform_map ./Native .
  $Caret5_Command -deformation-map-path "$AtlasSpaceFolder"/164k_fs_LR2native."$Hemisphere".deform_map . ./Native

  $Caret5_Command -file-convert -sc -is CARET "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".sphere.reg.reg_LR.native.coord.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.topo.gii -os GS "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".sphere.reg.reg_LR.native.surf.gii
  $Caret7_Command -set-structure "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".sphere.reg.reg_LR.native.surf.gii $Structure -surface-type SPHERICAL

  #Create and populate fs_LR spec file.  Deform surfaces and other data according to native to fs_LR deformation map.  Regenerate inflated surfaces.
  DIR=`pwd`
  cd $AtlasSpaceFolder
      $Caret5_Command -spec-file-create $Species $Subject $hemispherew OTHER -category Individual -spec-file-name "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".164k_fs_LR.c5.spec
  cd $DIR
  $Caret5_Command -spec-file-add "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".164k_fs_LR.c5.spec CLOSEDtopo_file "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".164k_fs_LR.topo.gii
  $Caret5_Command -spec-file-add "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".164k_fs_LR.c5.spec SPHERICALcoord_file "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".sphere.164k_fs_LR.coord.gii
  $Caret5_Command -spec-file-add "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".164k_fs_LR.c5.spec volume_anatomy_file "$AtlasSpaceFolder"/"$AtlasSpaceT2wImage".nii.gz
  $Caret5_Command -spec-file-add "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".164k_fs_LR.c5.spec volume_anatomy_file "$AtlasSpaceFolder"/"$AtlasSpaceT1wImage".nii.gz
  for Surface in white midthickness pial ; do
    cd $AtlasSpaceFolder
    $Caret5_Command -deformation-map-apply "$AtlasSpaceFolder"/native2164k_fs_LR."$Hemisphere".deform_map COORDINATE "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Surface".native.coord.gii "$AtlasSpaceFolder"/"$Subject"."$Hemisphere"."$Surface".164k_fs_LR.coord.gii 
    cd $DIR
    $Caret5_Command -spec-file-add "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".164k_fs_LR.c5.spec FIDUCIALcoord_file "$AtlasSpaceFolder"/"$Subject"."$Hemisphere"."$Surface".164k_fs_LR.coord.gii
  done
  cd $AtlasSpaceFolder
  $Caret5_Command -deformation-map-apply "$AtlasSpaceFolder"/native2164k_fs_LR."$Hemisphere".deform_map METRIC_AVERAGE_TILE "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".sulc.native.shape.gii "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".sulc.164k_fs_LR.shape.gii
  cd $DIR
  $Caret5_Command -spec-file-add "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".164k_fs_LR.c5.spec surface_shape_file "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".sulc.164k_fs_LR.shape.gii
  $Caret7_Command -set-structure "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".sulc.164k_fs_LR.shape.gii $Structure 
  $Caret7_Command -add-to-spec-file "$AtlasSpaceFolder"/"$Subject".164k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".sulc.164k_fs_LR.shape.gii

  cd $AtlasSpaceFolder
  $Caret5_Command -deformation-map-apply "$AtlasSpaceFolder"/native2164k_fs_LR."$Hemisphere".deform_map METRIC_AVERAGE_TILE "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".ArealDistortion.native.shape.gii "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".ArealDistortion.164k_fs_LR.shape.gii
  cd $DIR
  $Caret7_Command -set-structure "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".ArealDistortion.164k_fs_LR.shape.gii $Structure 

  cd $AtlasSpaceFolder
  $Caret5_Command -deformation-map-apply "$AtlasSpaceFolder"/native2164k_fs_LR."$Hemisphere".deform_map PAINT "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".aparc.native.label.gii "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".aparc.164k_fs_LR.label.gii
  cd $DIR
  $Caret5_Command -spec-file-add "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".164k_fs_LR.c5.spec paint_file "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".aparc.164k_fs_LR.label.gii
  $Caret7_Command -set-structure "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".aparc.164k_fs_LR.label.gii $Structure 
  $Caret7_Command -add-to-spec-file "$AtlasSpaceFolder"/"$Subject".164k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".aparc.164k_fs_LR.label.gii
  cd $AtlasSpaceFolder
  $Caret5_Command -deformation-map-apply "$AtlasSpaceFolder"/native2164k_fs_LR."$Hemisphere".deform_map PAINT "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".aparc.a2009s.native.label.gii "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".aparc.a2009s.164k_fs_LR.label.gii
  cd $DIR
  $Caret5_Command -spec-file-add "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".164k_fs_LR.c5.spec paint_file "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".aparc.a2009s.164k_fs_LR.label.gii
  $Caret7_Command -set-structure "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".aparc.a2009s.164k_fs_LR.label.gii $Structure 
  $Caret7_Command -add-to-spec-file "$AtlasSpaceFolder"/"$Subject".164k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".aparc.a2009s.164k_fs_LR.label.gii
  cd $AtlasSpaceFolder
  $Caret5_Command -deformation-map-apply "$AtlasSpaceFolder"/native2164k_fs_LR."$Hemisphere".deform_map PAINT "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".BA.native.label.gii "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".BA.164k_fs_LR.label.gii
  cd $DIR
  $Caret5_Command -spec-file-add "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".164k_fs_LR.c5.spec paint_file "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".BA.164k_fs_LR.label.gii
  $Caret7_Command -set-structure "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".BA.164k_fs_LR.label.gii $Structure 
  $Caret7_Command -add-to-spec-file "$AtlasSpaceFolder"/"$Subject".164k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".BA.164k_fs_LR.label.gii
  
  $Caret7_Command -add-to-spec-file "$AtlasSpaceFolder"/"$Subject".164k_fs_LR.wb.spec INVALID "$AtlasSpaceFolder"/"$AtlasSpaceT2wImage".nii.gz
  $Caret7_Command -add-to-spec-file "$AtlasSpaceFolder"/"$Subject".164k_fs_LR.wb.spec INVALID "$AtlasSpaceFolder"/"$AtlasSpaceT1wImage".nii.gz
  $Caret5_Command -surface-generate-inflated "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".midthickness.164k_fs_LR.coord.gii "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".164k_fs_LR.topo.gii -iterations-scale 2.5 -generate-inflated -generate-very-inflated -output-spec "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".164k_fs_LR.c5.spec -output-inflated-file-name "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".inflated.164k_fs_LR.coord.gii -output-very-inflated-file-name "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".very_inflated.164k_fs_LR.coord.gii
  i=1
  for Surface in very_inflated midthickness white pial inflated sphere ; do
    Type=`echo "$Types" | cut -d " " -f $i`
    Secondary=`echo "$Type" | cut -d "@" -f 2`
    Type=`echo "$Type" | cut -d "@" -f 1`
    if [ ! $Secondary = $Type ] ; then
      Secondary=`echo " -surface-secondary-type ""$Secondary"`
    else
      Secondary=""
    fi
    $Caret5_Command -file-convert -sc -is CARET "$AtlasSpaceFolder"/"$Subject"."$Hemisphere"."$Surface".164k_fs_LR.coord.gii "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".164k_fs_LR.topo.gii -os GS "$AtlasSpaceFolder"/"$Subject"."$Hemisphere"."$Surface".164k_fs_LR.surf.gii
    $Caret7_Command -set-structure "$AtlasSpaceFolder"/"$Subject"."$Hemisphere"."$Surface".164k_fs_LR.surf.gii $Structure -surface-type $Type$Secondary
    $Caret7_Command -add-to-spec-file "$AtlasSpaceFolder"/"$Subject".164k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/"$Subject"."$Hemisphere"."$Surface".164k_fs_LR.surf.gii
    i=$(($i+1))
  done
done

$Caret5_Command -surface-create-spheres $DownSampleI "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject".R.sphere."$DownSampleNameI"k_fs_LR.coord.gii "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject".R."$DownSampleNameI"k_fs_LR.topo.gii "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject".L.sphere."$DownSampleNameI"k_fs_LR.coord.gii "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject".L."$DownSampleNameI"k_fs_LR.topo.gii

for Hemisphere in L R ; do
  #Set a bunch of different ways of saying left and right
  if [ $Hemisphere = "L" ] ; then 
    hemisphere="l"
    HEMISPHERE="LEFT"
    hemispherew="left"
    Structure="CORTEX_LEFT"
  elif [ $Hemisphere = "R" ] ; then 
    hemisphere="r"
    hemispherew="right"
    HEMISPHERE="RIGHT"
    Structure="CORTEX_RIGHT"
  fi

  #Create fs_LR 164k to fs_LR "$DownSampleNameI"k and inverse deformation maps
  $Caret5_Command -deformation-map-create SPHERE "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere".sphere."$DownSampleNameI"k_fs_LR.coord.gii "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$DownSampleNameI"k_fs_LR.topo.gii "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".sphere.164k_fs_LR.coord.gii "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".164k_fs_LR.topo.gii "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$DownSampleNameI"k_fs_LR2164k_fs_LR."$Hemisphere".deform_map
  $Caret5_Command -deformation-map-create SPHERE "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".sphere.164k_fs_LR.coord.gii "$AtlasSpaceFolder"/"$Subject"."$Hemisphere".164k_fs_LR.topo.gii "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere".sphere."$DownSampleNameI"k_fs_LR.coord.gii "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$DownSampleNameI"k_fs_LR.topo.gii "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/164k_fs_LR2"$DownSampleNameI"k_fs_LR."$Hemisphere".deform_map

  $Caret5_Command -deformation-map-path "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$DownSampleNameI"k_fs_LR2164k_fs_LR."$Hemisphere".deform_map . ..
  $Caret5_Command -deformation-map-path "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/164k_fs_LR2"$DownSampleNameI"k_fs_LR."$Hemisphere".deform_map .. .
  
  #Create native to fs_LR "$DownSampleNameI"k and inverse deformation maps
  $Caret5_Command -deformation-map-create SPHERE "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".sphere.reg.reg_LR.native.coord.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.topo.gii "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere".sphere."$DownSampleNameI"k_fs_LR.coord.gii "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$DownSampleNameI"k_fs_LR.topo.gii "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/native2"$DownSampleNameI"k_fs_LR."$Hemisphere".deform_map
  $Caret5_Command -deformation-map-create SPHERE "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere".sphere."$DownSampleNameI"k_fs_LR.coord.gii "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$DownSampleNameI"k_fs_LR.topo.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".sphere.reg.reg_LR.native.coord.gii "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".native.topo.gii "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$DownSampleNameI"k_fs_LR2native."$Hemisphere".deform_map

  $Caret5_Command -deformation-map-path "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/native2"$DownSampleNameI"k_fs_LR."$Hemisphere".deform_map ../Native .
  $Caret5_Command -deformation-map-path "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$DownSampleNameI"k_fs_LR2native."$Hemisphere".deform_map . ../Native

  #Create downsampled fs_LR spec file.  This is set to 32k for 2mm average node spacing (roughly the fMRI and diffusion data resolutions).  
  DIR=`pwd`
  cd "$AtlasSpaceFolder"
    $Caret5_Command -spec-file-create $Species $Subject $hemispherew OTHER -category Individual -spec-file-name "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$DownSampleNameI"k_fs_LR.c5.spec
  cd $DIR
  for Surface in white midthickness pial ; do
    cd "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k
    $Caret5_Command -deformation-map-apply "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/native2"$DownSampleNameI"k_fs_LR."$Hemisphere".deform_map COORDINATE "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere"."$Surface".native.coord.gii "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$Surface"."$DownSampleNameI"k_fs_LR.coord.gii 
    cd $DIR
    $Caret5_Command -spec-file-add "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$DownSampleNameI"k_fs_LR.c5.spec FIDUCIALcoord_file "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$Surface"."$DownSampleNameI"k_fs_LR.coord.gii
  done
  $Caret5_Command -spec-file-add "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$DownSampleNameI"k_fs_LR.c5.spec CLOSEDtopo_file "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$DownSampleNameI"k_fs_LR.topo.gii
  $Caret5_Command -spec-file-add "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$DownSampleNameI"k_fs_LR.c5.spec SPHERICALcoord_file "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere".sphere."$DownSampleNameI"k_fs_LR.coord.gii
  $Caret5_Command -surface-generate-inflated "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere".midthickness."$DownSampleNameI"k_fs_LR.coord.gii "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$DownSampleNameI"k_fs_LR.topo.gii -iterations-scale 0.75 -generate-inflated -generate-very-inflated -output-spec "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$DownSampleNameI"k_fs_LR.c5.spec -output-inflated-file-name "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere".inflated."$DownSampleNameI"k_fs_LR.coord.gii -output-very-inflated-file-name "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere".very_inflated."$DownSampleNameI"k_fs_LR.coord.gii
  i=1
  for Surface in very_inflated midthickness white pial inflated sphere ; do
    Type=`echo "$Types" | cut -d " " -f $i`
    Secondary=`echo "$Type" | cut -d "@" -f 2`
    Type=`echo "$Type" | cut -d "@" -f 1`
    if [ ! $Secondary = $Type ] ; then
      Secondary=`echo " -surface-secondary-type ""$Secondary"`
    else
      Secondary=""
    fi
    $Caret5_Command -file-convert -sc -is CARET "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$Surface"."$DownSampleNameI"k_fs_LR.coord.gii "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$DownSampleNameI"k_fs_LR.topo.gii -os GS "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$Surface"."$DownSampleNameI"k_fs_LR.surf.gii
    $Caret7_Command -set-structure "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$Surface"."$DownSampleNameI"k_fs_LR.surf.gii $Structure -surface-type $Type$Secondary
    $Caret7_Command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$DownSampleNameI"k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$Surface"."$DownSampleNameI"k_fs_LR.surf.gii
    i=$(($i+1))
  done
  cd "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k
  $Caret5_Command -deformation-map-apply "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/native2"$DownSampleNameI"k_fs_LR."$Hemisphere".deform_map METRIC_AVERAGE_TILE "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".sulc.native.shape.gii "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere".sulc."$DownSampleNameI"k_fs_LR.shape.gii
  cd $DIR
  $Caret7_Command -set-structure "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere".sulc."$DownSampleNameI"k_fs_LR.shape.gii $Structure
  $Caret5_Command -spec-file-add "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$DownSampleNameI"k_fs_LR.c5.spec surface_shape_file "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere".sulc."$DownSampleNameI"k_fs_LR.shape.gii
  $Caret7_Command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$DownSampleNameI"k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere".sulc."$DownSampleNameI"k_fs_LR.shape.gii

  cd "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k
  $Caret5_Command -deformation-map-apply "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/native2"$DownSampleNameI"k_fs_LR."$Hemisphere".deform_map PAINT "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".aparc.native.label.gii "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere".aparc."$DownSampleNameI"k_fs_LR.label.gii
  cd $DIR
  $Caret7_Command -set-structure "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere".aparc."$DownSampleNameI"k_fs_LR.label.gii $Structure
  $Caret5_Command -spec-file-add "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$DownSampleNameI"k_fs_LR.c5.spec paint_file "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere".aparc."$DownSampleNameI"k_fs_LR.label.gii
  $Caret7_Command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$DownSampleNameI"k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere".aparc."$DownSampleNameI"k_fs_LR.label.gii
  cd "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k
  $Caret5_Command -deformation-map-apply "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/native2"$DownSampleNameI"k_fs_LR."$Hemisphere".deform_map PAINT "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".aparc.a2009s.native.label.gii "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere".aparc.a2009s."$DownSampleNameI"k_fs_LR.label.gii
  cd $DIR
  $Caret7_Command -set-structure "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere".aparc.a2009s."$DownSampleNameI"k_fs_LR.label.gii $Structure
  $Caret5_Command -spec-file-add "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$DownSampleNameI"k_fs_LR.c5.spec paint_file "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere".aparc.a2009s."$DownSampleNameI"k_fs_LR.label.gii
  $Caret7_Command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$DownSampleNameI"k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere".aparc.a2009s."$DownSampleNameI"k_fs_LR.label.gii
  cd "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k
  $Caret5_Command -deformation-map-apply "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/native2"$DownSampleNameI"k_fs_LR."$Hemisphere".deform_map PAINT "$AtlasSpaceFolder"/"$NativeFolder"/"$Subject"."$Hemisphere".BA.native.label.gii "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere".BA."$DownSampleNameI"k_fs_LR.label.gii
  cd $DIR
  $Caret7_Command -set-structure "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere".BA."$DownSampleNameI"k_fs_LR.label.gii $Structure
  $Caret5_Command -spec-file-add "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$DownSampleNameI"k_fs_LR.c5.spec paint_file "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere".BA."$DownSampleNameI"k_fs_LR.label.gii
  $Caret7_Command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$DownSampleNameI"k_fs_LR.wb.spec $Structure "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere".BA."$DownSampleNameI"k_fs_LR.label.gii

  $Caret5_Command -spec-file-add "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$DownSampleNameI"k_fs_LR.c5.spec volume_anatomy_file "$AtlasSpaceFolder"/"$AtlasSpaceT2wImage".nii.gz
  $Caret5_Command -spec-file-add "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$Hemisphere"."$DownSampleNameI"k_fs_LR.c5.spec volume_anatomy_file "$AtlasSpaceFolder"/"$AtlasSpaceT1wImage".nii.gz
  $Caret7_Command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$DownSampleNameI"k_fs_LR.wb.spec INVALID "$AtlasSpaceFolder"/"$AtlasSpaceT2wImage".nii.gz
  $Caret7_Command -add-to-spec-file "$AtlasSpaceFolder"/fsaverage_LR"$DownSampleNameI"k/"$Subject"."$DownSampleNameI"k_fs_LR.wb.spec INVALID "$AtlasSpaceFolder"/"$AtlasSpaceT1wImage".nii.gz
done

#Remove fsaverage folder as it is no longer needed.
#rm -r "$AtlasSpaceFolder"/fsaverage

echo -e "\n END: FS2CaretConvertRegisterNonlinear"


