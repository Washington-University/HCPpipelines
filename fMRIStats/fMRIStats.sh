StudyFolder="${1}"
Subject="${2}"
fMRIName="${3}"
RegName="${4}"
HighPass="${5}"
ProcSTRING="${6}"
ProcessVolume="${7}"
CleanUpEffects="${8}"
Caret7_Command="${9}"
GitRepo="${10}"

if [ "${RegName}" != "NONE" ] ; then
	RegString="_${RegName}"
else
	RegString=""
fi

fMRIFolder="${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}"

MeanCIFTI="${fMRIFolder}/${fMRIName}_Atlas${RegString}_mean.dscalar.nii"
MeanVolume="${fMRIFolder}/${fMRIName}_mean.nii.gz"
sICATCS="${fMRIFolder}/${fMRIName}_hp${HighPass}.ica/filtered_func_data.ica/melodic_mix.sdseries.nii"
if [ -e ${fMRIFolder}/${fMRIName}_hp${HighPass}.ica/HandSignal.txt ] ; then
  Signal="${fMRIFolder}/${fMRIName}_hp${HighPass}.ica/HandSignal.txt"
else
  Signal="${fMRIFolder}/${fMRIName}_hp${HighPass}.ica/Signal.txt"
fi
OrigCIFTITCS="${fMRIFolder}/${fMRIName}_Atlas${RegString}.dtseries.nii"
OrigVolumeTCS="${fMRIFolder}/${fMRIName}.nii.gz"
CleanedCIFTITCS="${fMRIFolder}/${fMRIName}_Atlas${RegString}${ProcSTRING}.dtseries.nii"
CleanedVolumeTCS="${fMRIFolder}/${fMRIName}${ProcSTRING}.nii.gz"
CIFTIOutput="${fMRIFolder}/${fMRIName}_Atlas${RegString}${ProcSTRING}_fMRIStats.dscalar.nii"
VolumeOutput="${fMRIFolder}/${fMRIName}${ProcSTRING}_fMRIStats.nii.gz"

matlab -nodisplay -nosplash <<M_PROG
addpath('${GitRepo}/fMRIStats/scripts'); fMRIStats('${MeanCIFTI}','${MeanVolume}','${sICATCS}','${Signal}','${OrigCIFTITCS}','${OrigVolumeTCS}','${CleanedCIFTITCS}','${CleanedVolumeTCS}','${CIFTIOutput}','${VolumeOutput}','${CleanUpEffects}','${ProcessVolume}','${Caret7_Command}');
M_PROG
echo "addpath('${GitRepo}/fMRIStats/scripts'); fMRIStats('${MeanCIFTI}','${MeanVolume}','${sICATCS}','${Signal}','${OrigCIFTITCS}','${OrigVolumeTCS}','${CleanedCIFTITCS}','${CleanedVolumeTCS}','${CIFTIOutput}','${VolumeOutput}','${CleanUpEffects}','${ProcessVolume}','${Caret7_Command}');"


