#! /bin/bash

# Takuya Hayashi, RIKEN Brain Connectomics Imaging Laboratory, Kobe
# Tim Coalson, Washington University in St. Louis

set -eu

pipedirguessed=0
if [[ "${HCPPIPEDIR:-}" == "" ]]
then
    pipedirguessed=1
    #fix this if the script is more than one level below HCPPIPEDIR
    export HCPPIPEDIR="$(dirname -- "$0")/../../"
fi

source "$HCPPIPEDIR/global/scripts/newopts.shlib" "$@"
source "$HCPPIPEDIR/global/scripts/debug.shlib" "$@"

# Usage
opts_SetScriptDescription "CORRECT VOLUME ORIENTATION
This script corrects or changes orientation of the NIFTI volume. It is useful to 
correct the orientation information of the NIFTI header, for example, 1) when the 
data was collected with the 'Patient position' incorrectly entered in the scanner 
or 2) when the true patient position can not be entered by the scanner (e.g. the 
patient or animal is in sphinx position, while the scanner cannot accept it). 
True patient positions available are 'head-first-sphinx (HFSx)', 
'foot-first-sphinx (FFSx)', 'head-first-supine (HFS)' and 'foot-first-supine (FFS)'.

Example protocols and usages:

Ex) #1. the simplest usage is when an MRI volume (MRI.nii.gz) is scanned in the 
true position of HFSx but the scanner's Patient Position is set to HFP.

$ CorrectVolumeOrientation --in=MRI.nii.gz --tposition=HFSx --sposition=HFP 
  --out=MRI2reorient.nii.gz

Ex) #2. structural MRI scanned in true position of HFS on day1 (T1w_d1_HFS) and 
fMRI scanned in true position in HFSx on day2 (fMRI_d2_HFSx) and additional fast 
T1w scanned for registration purpose on day2 (T1w_d2_HFSx), where scanner's 
patient orientation is set to HFS on day1 and HFP on day2. In this case, the 
fast T1w scanned on day2 is corrected for the head orientation and registered to 
the T1w on day1, then the fMRI data on day2 is corrected for head orientation 
and initialized for head position using fast T1w scanned on day2. In this case, 
the option --ref is useful to 'fake' the output volume as if it were scanned on 
the same position as in day1.

$ CorrectVolumeOrientation --in=T1w_d2_HFSx.nii.gz --tposition=HFSx 
  --sposition=HFP --ref=T1w_d1_HFS.nii.gz --out=T1w_d2_reorient.nii.gz
$ CorrectVolumeOrientation --in=fMRI_d2_HFSx.nii.gz --tposition=HFSx 
  --sposition=HFP --init=T1w_d2_reorient2ref.world.mat 
  --out=fMRI_d2_reorient2ref.nii.gz

Please confirm that the registration is successful by viewing T1w_d1 and 
T1w_d2_reorient2ref. If this is not the case, please goto Ex) #4.

Ex) #3. structural MRI on day1, function MRI and fast structural scan on day 2 
all scanned in true position of HFSx, where scanner's patient orientation is set 
to HFP. In this case, the structural MRI scan in day1 must be corrected for the 
head orientation first, then the structural and functional MRI in day2 are 
treated as in #1.

$ CorrectVolumeOrientation --in=T1w_d1_HFSx.nii.gz --tposition=HFSx 
  --sposition=HFP --out=T1w_d1_reorient.nii.gz
$ CorrectVolumeOrientation --in=T1w_d2_HFSx.nii.gz --tposition=HFSx 
  --sposition=HFP --ref=T1w_d1_reorient.nii.gz --out=T1w_d2_reorient.nii.gz
$ CorrectVolumeOrientation --in=fMRI_d2_HFSx.nii.gz --tposition=HFSx 
  --sposition=HFP --init=T1w_d2_reorient2ref.world.mat 
  --out=fMRI_d2_reorient2ref.nii.gz

Please confirm that the registration is successful by viewing T1w_d1_reorient and 
T1w_d2_reorient2ref. If this is not the case, please goto Ex) #4.

Ex) #4. if registration with --ref is not working, please consider doing 
registration by tuning options flirt, e.g.,

$ flirt -in T1w_d2_reorient.nii.gz -ref <reference volume> -dof 6 
  -omat T1w_d2_reorient2ref.mat <flirt options>
$ wb_command -convert-affine T1w_d2_reorient2ref.mat T1w_d2_reorient.nii.gz 
  <reference volume> -to-world T1w_d2_reorient2ref.world.mat

"

opts_AddMandatory '--in'               'volin'           'volume'                 "input volume scanned with a true patient position in the scanner."
opts_AddMandatory '--tposition'        'TruePosition'    'HFSx, FFSx, HFS, HFP, FFS, FFP' "true patient position in the scanner"
opts_AddMandatory '--sposition'        'PatientPosition' 'HFS, HFP, FFS, FFP, NONE'    "patient position entered in the scanner, described in the tag (0018,5100) in the standard DICOM. If specified NONE, it does not change sform unless specified --init option."
opts_AddMandatory '--out'              'out'             'volume'                 "output volume filename." 
opts_AddOptional  '--omat'             'omat'            'TRUE or FALSE (default)' "output transformation matrix for reorientation. Outputs are <out>_reorient.world.mat (in world format) and <out>_reorient.mat (FSL flirt format)." "FALSE"
opts_AddOptional  '--reorient2std'     'reorient2std'    'TRUE (default) or FALSE' "reorient to RPI ('radiological') convention." 'TRUE'
opts_AddOptional  '--ref'              'ref'             'volume'                 "run a rigid-body registration to reference volume, save transformation matrix as <out>2ref.world.mat and <out>2ref.mat and registrated volume as <out>2ref.nii.gz." 'NONE'
opts_AddOptional  '--init'             'affine'          'matrix'                 "apply a rigid-body transformation matrix (in world format) to sform of <out>.nii.gz" 'NONE'

opts_ParseArguments "$@"

if ((pipedirguessed))
then
    log_Err_Abort "HCPPIPEDIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

if [ -z "$CARET7DIR" ] ; then
    log_Err_Abort "CARET7DIR is not set, you must first source your edited copy of Examples/Scripts/SetUpHCPPipeline.sh"
fi

# sanity check the input arguments

omat=$(opts_StringToBool "$omat")
reorient2std=$(opts_StringToBool "$reorient2std")
# Display the parsed/default values
opts_ShowValues

# Run
in=$(imglob -extension $volin)
out=$(remove_ext $out)

if [[ ! -e $in ]] ; then
  log_Err_Abort "cannot find $volin"
fi
if [ $ref != NONE ] ; then
  if [ ! -e $ref  ] ; then
                log_Err_Abort "cannnot find volume: $ref"
  else
    ref=$(remove_ext $ref)
  fi
fi
if [ $affine != NONE ] ; then
  if [ ! -e $affine ] ; then
    log_Err_Abort "cannnot find affine"
  fi
fi

function readsform () {
"${CARET7DIR}"/wb_command -nifti-information -print-header "$1" | grep --text -A 3 "effective sform" | tail -n 3 | awk '{printf "%.8f\t%.8f\t%.8f\t%.8f\n",$1,$2,$3,$4}' > "$2"
echo "0 0 0 1" | awk '{printf "%.8f\t%.8f\t%.8f\t%.8f\n",$1,$2,$3,$4}' >> "$2"
}

tmp=${out}_$$
# matrix is inferred by Nudge, makerot using inputs of a structure volume and a reference volume

if [ $TruePosition = HFSx ] ; then
  echo " 1  0  0  0" >  ${tmp}_reorient_I.world.mat
  echo " 0  1  0  0" >> ${tmp}_reorient_I.world.mat
  echo " 0  0  1  0" >> ${tmp}_reorient_I.world.mat
  echo " 0  0  0  1" >> ${tmp}_reorient_I.world.mat
elif [ $TruePosition = FFSx ] ; then
  # rotation x=180, y=180
  echo "-1  0  0  0" >  ${tmp}_reorient_I.world.mat
  echo " 0 -1  0  0" >> ${tmp}_reorient_I.world.mat
  echo " 0  0  1  0" >> ${tmp}_reorient_I.world.mat
  echo " 0  0  0  1" >> ${tmp}_reorient_I.world.mat
elif [ $TruePosition = HFS ] ; then
  # rotate x=-90, z=180
  echo "-1  0  0  0" >  ${tmp}_reorient_I.world.mat
  echo " 0  0  1  0" >> ${tmp}_reorient_I.world.mat
  echo " 0  1  0  0" >> ${tmp}_reorient_I.world.mat
  echo " 0  0  0  1" >> ${tmp}_reorient_I.world.mat
elif [ $TruePosition = HFP ] ; then
  # rotation x=-90
  echo " 1  0  0  0" >  ${tmp}_reorient_I.world.mat
  echo " 0  0 -1  0" >> ${tmp}_reorient_I.world.mat
  echo " 0  1  0  0" >> ${tmp}_reorient_I.world.mat
  echo " 0  0  0  1" >> ${tmp}_reorient_I.world.mat
elif [ $TruePosition = FFS ] ; then
  # rotation x=90
  echo " 1  0  0  0" >  ${tmp}_reorient_I.world.mat
  echo " 0  0  1  0" >> ${tmp}_reorient_I.world.mat
  echo " 0 -1  0  0" >> ${tmp}_reorient_I.world.mat
  echo " 0  0  0  1" >> ${tmp}_reorient_I.world.mat
elif [ $TruePosition = FFP ] ; then
  # rotation x=90, z=180
  echo "-1  0  0  0" >  ${tmp}_reorient_I.world.mat
  echo " 0  0 -1  0" >> ${tmp}_reorient_I.world.mat
  echo " 0 -1  0  0" >> ${tmp}_reorient_I.world.mat
  echo " 0  0  0  1" >> ${tmp}_reorient_I.world.mat
else
  log_Err_Abort "unknown position: $TruePosition"
fi

if [ $PatientPosition = HFP ] ; then
  # rotation x=-90
  echo " 1  0  0  0" >  ${tmp}_reorient_II.world.mat
  echo " 0  0 -1  0" >> ${tmp}_reorient_II.world.mat
  echo " 0  1  0  0" >> ${tmp}_reorient_II.world.mat
  echo " 0  0  0  1" >> ${tmp}_reorient_II.world.mat
elif [ $PatientPosition = HFS ] ; then
  # rotation x=-90, z=180
  echo "-1  0  0  0" >  ${tmp}_reorient_II.world.mat
  echo " 0  0  1  0" >> ${tmp}_reorient_II.world.mat
  echo " 0  1  0  0" >> ${tmp}_reorient_II.world.mat
  echo " 0  0  0  1" >> ${tmp}_reorient_II.world.mat
elif [ $PatientPosition = FFS ] ; then
  # rotation x=90
  echo " 1  0  0  0" >  ${tmp}_reorient_II.world.mat
  echo " 0  0  1  0" >> ${tmp}_reorient_II.world.mat
  echo " 0 -1  0  0" >> ${tmp}_reorient_II.world.mat
  echo " 0  0  0  1" >> ${tmp}_reorient_II.world.mat
elif [ $PatientPosition = FFP ] ; then
  # rotation x=90, z=180
  echo "-1  0  0  0" >  ${tmp}_reorient_II.world.mat
  echo " 0  0 -1  0" >> ${tmp}_reorient_II.world.mat
  echo " 0 -1  0  0" >> ${tmp}_reorient_II.world.mat
  echo " 0  0  0  1" >> ${tmp}_reorient_II.world.mat
elif [ $PatientPosition = NONE ] ; then
  # rotation x=0, z=0
  echo " 1  0  0  0" >  ${tmp}_reorient_II.world.mat
  echo " 0  1  0  0" >> ${tmp}_reorient_II.world.mat
  echo " 0  0  1  0" >> ${tmp}_reorient_II.world.mat
  echo " 0  0  0  1" >> ${tmp}_reorient_II.world.mat
  cp ${tmp}_reorient_II.world.mat ${tmp}_reorient_I.world.mat
else
  log_Err_Abort "unknown Patient position: $PatientPosition"
fi

# Correct orientation
readsform ${in} ${tmp}_sform.mat
convert_xfm -omat ${tmp}_reorient_II_inv.world.mat -inverse ${tmp}_reorient_II.world.mat
#undo the scanner-applied patient orientation transform to get bore coordinates, then apply the true patient orientation transform
convert_xfm -omat ${tmp}_reorient.world.mat -concat ${tmp}_reorient_I.world.mat ${tmp}_reorient_II_inv.world.mat
#apply combined transform to sform
convert_xfm -omat ${tmp}_newsform.mat -concat ${tmp}_reorient.world.mat ${tmp}_sform.mat
${CARET7DIR}/wb_command -volume-set-space ${in} ${tmp}.nii.gz -sform $(cat ${tmp}_newsform.mat | head -3)

# Reorient to standard RPI space
if [ $reorient2std = TRUE ] ; then
  ${CARET7DIR}/wb_command -volume-reorient ${tmp}.nii.gz RPI ${tmp}.nii.gz
fi

# Run rigid-body registration to reference volume if requested
if [ $ref != NONE ] ; then
  flirt -in ${tmp}.nii.gz -ref $ref -dof 6 -omat ${out}2ref.mat
  ${CARET7DIR}/wb_command -convert-affine -from-flirt ${out}2ref.mat ${tmp}.nii.gz $(imglob -extension ${ref}) -to-world ${out}2ref.world.mat
  affine=${out}2ref.world.mat
  cp ${tmp}.nii.gz ${out}2ref.nii.gz
  applytrans=${out}2ref
else
  applytrans=${tmp}
fi

# Apply transformation to sform if requested
if [ $affine != NONE ] ; then
  readsform ${applytrans}.nii.gz ${tmp}_sform.mat
  convert_xfm -omat ${tmp}_newsform.mat -concat ${affine} ${tmp}_sform.mat
  ${CARET7DIR}/wb_command -volume-set-space ${applytrans}.nii.gz ${applytrans}.nii.gz -sform $(cat ${tmp}_newsform.mat | head -3)
  convert_xfm -omat ${tmp}_world.mat -concat ${affine} ${tmp}_reorient.world.mat
  mv ${tmp}_world.mat ${tmp}_reorient.world.mat
fi

${CARET7DIR}/wb_command -convert-affine -from-world ${tmp}_reorient.world.mat -to-flirt ${tmp}_reorient.mat ${in} ${applytrans}.nii.gz

if (($omat)) ; then
  mv ${tmp}_reorient.mat ${out}_reorient.mat
  mv ${tmp}_reorient.world.mat ${out}_reorient.world.mat
else
  rm ${tmp}_reorient.world.mat ${tmp}_reorient.mat
fi
mv ${tmp}.nii.gz ${out}.nii.gz
rm ${tmp}_sform.mat ${tmp}_newsform.mat ${tmp}_reorient_I.world.mat ${tmp}_reorient_II.world.mat ${tmp}_reorient_II_inv.world.mat

exit 0
