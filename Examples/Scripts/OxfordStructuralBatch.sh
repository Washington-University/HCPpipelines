#!/bin/bash

# This script contains example code to use the HCP Pipelines for processing
# of structural images following the OxfordStructural fork.
#
# The HCP Pipelines come with their own set of Examples (in the
# Pipelines/Examples/Scripts folder). They contain three *Batch.sh scripts
# for Pre-, FreeSurfer-, and Post- processing of structural images. This
# scripts contains example code to rename your original images according to
# HCP naming conventions and to run the three structural processing
# batches.

# specify the data
StudyFolder=/vols/username/studyname/data
SubjList="S01 S02 S03" # "S01 S02 S03 S04"
Scanner="3T"

# specify the task
Task="RENAME" # "RENAME" "PRE" "FREE" "POST"

# specify the batch scripts folder
BatchFolder=/vols/username/scripts/Pipelines/Examples/Scripts

# run the "RENAME" task
if [[ $Task = "RENAME" ]] ; then
  for subj in $SubjList ; do
    echo " "
    echo "Subject: $subj"

    # set base folder and original filename filters
    base="$StudyFolder/${subj}/unprocessed/${Scanner}"
    img_magn=$(echo $base/orig/images_*_grefieldmapping*1001.nii.gz)
    img_phas=$(echo $base/orig/images_*_grefieldmapping*2001.nii.gz)
    img_T1w="$base/orig/images_*_t1mprage*1001*.nii.gz"
    img_T2w="$base/orig/images_*_t2spc*1001*.nii.gz"

    # start with clean T1 and T2 folders
    for folder in $base/T1w_MPR* ; do rm -rf $folder/ ; done
    for folder in $base/T2w_SPC* ; do rm -rf $folder/ ; done

    # copy and rename the gradient echo readout distortion fieldmap magnitude image
    if [[ -e $img_magn ]] ; then
      echo "  copy and reorient GRE-field magnitude image: $img_magn"
      mkdir -p $base/T1w_MPR1/
      $FSLDIR/bin/fslreorient2std $img_magn $base/T1w_MPR1/${subj}_${Scanner}_FieldMap_Magnitude.nii.gz
    else
      echo "  GRE-field magnitude image not found: $img_magn"
    fi

    # copy and rename the gradient echo readout distortion fieldmap phase image
    if [[ -e $img_phas ]] ; then
      echo "  copy and reorient GRE-field phase image: $img_phas"
      mkdir -p $base/T1w_MPR1/
      $FSLDIR/bin/fslreorient2std $img_phas $base/T1w_MPR1/${subj}_${Scanner}_FieldMap_Phase.nii.gz
    else
      echo "  GRE-field phase image not found: $img_phas"
    fi

    # copy, orient2std, and rename the T1-MPRAGE image(s)
    c=1
    for img in $img_T1w ; do
      [[ ! -e $img ]] && echo " T1-MPRAGE not found: $img" && break
      echo "  copy and reorient T1-MPRAGE: $img"
      mkdir -p $base/T1w_MPR${c}/
      $FSLDIR/bin/fslreorient2std $img $base/T1w_MPR${c}/${subj}_${Scanner}_T1w_MPR${c}
      ((c++))
    done

    # copy, orient2std, and rename the T2-SpinEcho image(s)
    c=1
    for img in $img_T2w ; do
      [[ ! -e $img ]] && echo " T2-SPC not found: $img" && break
      echo "  copy and reorient T2-SPC: $img"
      mkdir -p $base/T2w_SPC${c}/
      $FSLDIR/bin/fslreorient2std $img $base/T2w_SPC${c}/${subj}_${Scanner}_T2w_SPC${c}
      ((c++))
    done

  done

  echo " "
  echo "MRI structural images are prepared and ready for the HCP pipeline."
fi


# replace spaces by "@"
SubjListSafe="${SubjList// /@}"


# run the "PRE-FREESURFER" task
if [[ $Task = "PRE" ]] ; then
  $BatchFolder/PreFreeSurferPipelineBatch.sh \
  --StudyFolder="$StudyFolder" \
  --SubjList="$SubjListSafe"
fi


# run the "FREESURFER" task
if [[ $Task = "FREE" ]] ; then
  $BatchFolder/FreeSurferPipelineBatch.sh \
  --StudyFolder="$StudyFolder" \
  --SubjList="$SubjListSafe"
  # you could add the "--noT2w" option to enforce skipping T2w image
  # processing, but if these images do not exist it will detect so
  # automatically.
fi


# run the "POST-FREESURFER" task
if [[ $Task = "POST" ]] ; then
  $BatchFolder/PostFreeSurferPipelineBatch.sh \
  --StudyFolder="$StudyFolder" \
  --SubjList="$SubjListSafe"
fi
