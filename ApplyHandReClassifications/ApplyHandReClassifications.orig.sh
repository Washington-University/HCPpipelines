Path="$1"
Subject="$2"
rfMRIName="$3"
HighPass="$4"

#Naming Conventions
AtlasFolder="${Path}/${Subject}/MNINonLinear"
ResultsFolder="${AtlasFolder}/Results/${rfMRIName}"
ICAFolder="${ResultsFolder}/${rfMRIName}_hp${HighPass}.ica/filtered_func_data.ica"
FIXFolder="${ResultsFolder}/${rfMRIName}_hp${HighPass}.ica"

OriginalFixSignal="${FIXFolder}/Signal.txt"
OriginalFixNoise="${FIXFolder}/Noise.txt"
ReclassifyAsSignal="${ResultsFolder}/ReclassifyAsSignal.txt"
ReclassifyAsNoise="${ResultsFolder}/ReclassifyAsNoise.txt"
HandSignalName="${FIXFolder}/HandSignal.txt"
HandNoiseName="${FIXFolder}/HandNoise.txt"
TrainingLabelsName="${FIXFolder}/hand_labels_noise.txt"

NumICAs=`fslval ${ICAFolder}/melodic_oIC.nii.gz dim4`

#Merge/edit Signal.txt with ReclassifyAsSignal.txt and ReclassifyAsNoise.txt
matlab <<M_PROG
MergeEditClassifications('${OriginalFixSignal}','${OriginalFixNoise}','${ReclassifyAsSignal}','${ReclassifyAsNoise}','${HandSignalName}','${HandNoiseName}','${TrainingLabelsName}',${NumICAs});
M_PROG
echo "MergeEditClassifications('${OriginalFixSignal}','${OriginalFixNoise}','${ReclassifyAsSignal}','${ReclassifyAsNoise}','${HandSignalName}','${HandNoiseName}','${TrainingLabelsName}',${NumICAs});"
  

