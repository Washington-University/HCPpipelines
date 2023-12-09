SubjectFolder="${1}"
Subject="${2}"
fMRIName="${3}"
HighPass="${4}"
Resolution="${5}"
SmoothingFWHM="${6}"
Caret7_command="${7}"

SmoothingSigma=`echo "$SmoothingFWHM / (2 * sqrt(2 * l(2)))" | bc -l`

${Caret7_command} -volume-label-import ${SubjectFolder}/MNINonLinear/ROIs/VolumeSmoothROIs.${Resolution}.nii.gz "" ${SubjectFolder}/MNINonLinear/ROIs/VolumeSmoothROIs.${Resolution}.nii.gz
${Caret7_command} -volume-parcel-smoothing ${SubjectFolder}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}.ica/filtered_func_data.ica/melodic_oIC.nii.gz ${SubjectFolder}/MNINonLinear/ROIs/VolumeSmoothROIs.${Resolution}.nii.gz ${SmoothingSigma} ${SubjectFolder}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}.ica/filtered_func_data.ica/melodic_oIC_s4.nii.gz

